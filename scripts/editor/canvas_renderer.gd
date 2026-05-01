extends Control
class_name CanvasRenderer

enum Tool { BRUSH, ERASER, BLUR, TEXT, COLOR }

@export var canvas_width: int = 80
@export var canvas_height: int = 40
@export var base_cell_size: Vector2 = Vector2(8, 16) # Approximate size of a monospace char
@export var base_font_size: int = 14
var cell_size: Vector2 = Vector2(8, 16)
var zoom_level: float = 1.0
@export var brush_size: float = 2.0
@export var brush_opacity: float = 1.0
@export var brush_feathering: float = 0.2
@export var canvas_bg_color: Color = Color(0.05, 0.05, 0.06, 1.0) # Dark default
@export var palette: Palette
var brush_color: Color = Color.WHITE
var blend_mode: int = 0 # 0 = Mix, 1 = Add, 2 = Multiply

var canvas: CanvasData
var undo_manager: UndoManager = UndoManager.new()
var active_tool: Tool = Tool.BRUSH

# State tracking for continuous strokes
var stroke_active: bool = false
var stroke_start_intensity: PackedFloat32Array
var stroke_start_color: PackedColorArray
var stroke_influence: PackedFloat32Array
var last_mouse_pos: Vector2
var cursor_pos: Vector2
var show_cursor: bool = false

# Text insertion cursor
var text_cursor: Vector2i = Vector2i(-1, -1) # cell coords, -1 = hidden

var cursor_overlay: Control

# Use a System monospace font instead of the generic variable-width fallback
var font: SystemFont = SystemFont.new()

func _ready() -> void:
	font.font_names = ["Consolas", "Courier New", "DejaVu Sans Mono", "Liberation Mono", "monospace"]
	canvas = CanvasData.new(canvas_width, canvas_height)
	
	cursor_overlay = Control.new()
	cursor_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_overlay.draw.connect(_draw_cursor_overlay)
	add_child(cursor_overlay)
	cursor_overlay.set_anchors_preset(PRESET_FULL_RECT)
	
	if not palette:
		push_error("CanvasRenderer requires a Palette resource!")
	elif palette.characters.size() == 0 and palette.regional_palette.size() > 0:
		_populate_characters_from_regional()
		
	cell_size = base_cell_size * zoom_level
	custom_minimum_size = Vector2(canvas_width * cell_size.x, canvas_height * cell_size.y)
	mouse_exited.connect(_on_mouse_exited)
	focus_mode = Control.FOCUS_ALL
	queue_redraw()

func set_zoom(val: float) -> void:
	zoom_level = val
	cell_size = base_cell_size * zoom_level
	custom_minimum_size = Vector2(canvas_width * cell_size.x, canvas_height * cell_size.y)
	queue_redraw()



func _on_mouse_exited() -> void:
	show_cursor = false
	if stroke_active:
		_commit_stroke_undo()
		stroke_active = false
	cursor_overlay.queue_redraw()

func _populate_characters_from_regional() -> void:
	var unique = [" "]
	for k in palette.regional_palette:
		for level in palette.regional_palette[k]:
			for ch in level:
				if not unique.has(ch):
					unique.append(ch)
	palette.characters = unique

func _draw() -> void:
	if not canvas or not palette:
		return
		
	# Viewport Culling logic
	var screen_rect = get_viewport_rect()
	var global_transform = get_global_transform()
	var local_top_left = global_transform.affine_inverse() * Vector2.ZERO
	var local_bottom_right = global_transform.affine_inverse() * screen_rect.size
	
	var start_x = clampi(int(local_top_left.x / cell_size.x) - 1, 0, canvas_width)
	var end_x = clampi(int(local_bottom_right.x / cell_size.x) + 2, 0, canvas_width)
	var start_y = clampi(int(local_top_left.y / cell_size.y) - 1, 0, canvas_height)
	var end_y = clampi(int(local_bottom_right.y / cell_size.y) + 2, 0, canvas_height)
	
	# Draw un-styled base background for visible bounds
	var bound_x = start_x * cell_size.x
	var bound_y = start_y * cell_size.y
	draw_rect(Rect2(bound_x, bound_y, (end_x - start_x) * cell_size.x, (end_y - start_y) * cell_size.y), canvas_bg_color)
	
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var cell_idx = canvas.get_cell_index(x, y)
			
			# Draw background if needed
			var bg = canvas.bg_colors[cell_idx]
			if bg.a > 0.01:
				var rect = Rect2(Vector2(x, y) * cell_size, cell_size)
				draw_rect(rect, bg)
			
			# Determine character to display
			var char_text: String
			if canvas.override_char[cell_idx] != 0:
				char_text = char(canvas.override_char[cell_idx])
			else:
				var char_idx = canvas.resolved_chars[cell_idx]
				char_text = palette.characters[char_idx] if char_idx < palette.characters.size() else "?"
			
			var fg = canvas.fg_colors[cell_idx]
			
			# draw_string uses baseline position, so we add cell_size.y minus small offset
			var pos = Vector2(x, y) * cell_size + Vector2(0, cell_size.y * 0.8)
			draw_string(font, pos, char_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(base_font_size * zoom_level), fg)
			
			# Subtle override indicator: thin bottom line
			if canvas.override_char[cell_idx] != 0:
				var line_y = float(y + 1) * cell_size.y - 1.0 * zoom_level
				draw_line(
					Vector2(x * cell_size.x, line_y),
					Vector2((x + 1) * cell_size.x, line_y),
					Color(0.4, 0.8, 1.0, 0.4), max(1.0, 1.0 * zoom_level)
				)

func _draw_cursor_overlay() -> void:
	# Draw text cursor (static block highlight — always visible)
	if active_tool == Tool.TEXT and text_cursor.x >= 0:
		var cx = text_cursor.x * cell_size.x
		var cy = text_cursor.y * cell_size.y
		# Block highlight with border
		cursor_overlay.draw_rect(Rect2(cx, cy, cell_size.x, cell_size.y), Color(1, 1, 1, 0.15))
		cursor_overlay.draw_rect(Rect2(cx, cy, cell_size.x, cell_size.y), Color(1.0, 1.0, 1.0, 0.541), false, 1.0)
	
	# Draw brush/blur cursor
	if show_cursor and active_tool != Tool.TEXT:
		var r = brush_size * (cell_size.x / 2.0)
		var cursor_color = Color(1, 1, 1, 0.5)
		if active_tool == Tool.BLUR:
			cursor_color = Color(0.5, 0.8, 1.0, 0.5)
		cursor_overlay.draw_arc(cursor_pos, r, 0, TAU, 32, cursor_color, max(1.0, 1.0 * zoom_level))

func _gui_input(event: InputEvent) -> void:
	# Grab focus on any mouse click so keyboard events reach us
	if event is InputEventMouseButton and event.pressed:
		grab_focus()
	
	if active_tool == Tool.TEXT:
		_handle_text_input(event)
		return
	
	if event is InputEventMouseMotion:
		cursor_pos = event.position
		show_cursor = true
		cursor_overlay.queue_redraw()
		
	if event is InputEventMouseButton:
		var is_erasing = event.button_index == MOUSE_BUTTON_RIGHT
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				stroke_active = true
				stroke_start_intensity = canvas.intensity.duplicate()
				stroke_start_color = canvas.color.duplicate()
				stroke_influence.resize(canvas.intensity.size())
				stroke_influence.fill(0.0)
				last_mouse_pos = event.position
				if active_tool == Tool.BLUR and not is_erasing:
					_blur_stroke_segment(last_mouse_pos, last_mouse_pos)
				else:
					_paint_stroke_segment(last_mouse_pos, last_mouse_pos, is_erasing or active_tool == Tool.ERASER)
			else:
				if stroke_active:
					_commit_stroke_undo()
				stroke_active = false
				
	elif event is InputEventMouseMotion and stroke_active:
		var is_erasing = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		if active_tool == Tool.BLUR and not is_erasing:
			_blur_stroke_segment(last_mouse_pos, event.position)
		else:
			_paint_stroke_segment(last_mouse_pos, event.position, is_erasing or active_tool == Tool.ERASER)
		last_mouse_pos = event.position


# ── Text Insertion ───────────────────────────────────────────────────

func _handle_text_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		cursor_pos = event.position
		show_cursor = false
		cursor_overlay.queue_redraw()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Place text cursor at clicked cell
		var cell_x = int(event.position.x / cell_size.x)
		var cell_y = int(event.position.y / cell_size.y)
		cell_x = clampi(cell_x, 0, canvas_width - 1)
		cell_y = clampi(cell_y, 0, canvas_height - 1)
		text_cursor = Vector2i(cell_x, cell_y)
		accept_event()
		cursor_overlay.queue_redraw()
	
	if event is InputEventKey and event.pressed:
		# we probably need to check for a canvas size, and also block stuff if the cursor is out of canvas
		if text_cursor.x < 0:
			return
		
		# Accept all key events in text mode to prevent them from reaching menu items
		var handled = true
		
		if event.keycode == KEY_LEFT:
			text_cursor.x = max(0, text_cursor.x - 1)
			cursor_overlay.queue_redraw()
		elif event.keycode == KEY_RIGHT:
			text_cursor.x = min(canvas_width - 1, text_cursor.x + 1)
			cursor_overlay.queue_redraw()
		elif event.keycode == KEY_UP:
			text_cursor.y = max(0, text_cursor.y - 1)
			cursor_overlay.queue_redraw()
		elif event.keycode == KEY_DOWN:
			text_cursor.y = min(canvas_height - 1, text_cursor.y + 1)
			cursor_overlay.queue_redraw()
		elif event.keycode == KEY_BACKSPACE:
			# Move left and clear
			if text_cursor.x > 0:
				text_cursor.x -= 1
			elif text_cursor.y > 0:
				text_cursor.y -= 1
				text_cursor.x = canvas_width - 1
			var cell_idx = canvas.get_cell_index(text_cursor.x, text_cursor.y)
			var old_override = canvas.override_char[cell_idx]
			canvas.override_char[cell_idx] = 0
			canvas.mark_cell_dirty(text_cursor.x, text_cursor.y)
			canvas.translate_dirty(palette)
			_push_override_undo(cell_idx, old_override, 0)
			queue_redraw()
			cursor_overlay.queue_redraw()
		elif event.keycode == KEY_DELETE:
			# Clear current cell
			var cell_idx = canvas.get_cell_index(text_cursor.x, text_cursor.y)
			var old_override = canvas.override_char[cell_idx]
			canvas.override_char[cell_idx] = 0
			canvas.mark_cell_dirty(text_cursor.x, text_cursor.y)
			canvas.translate_dirty(palette)
			_push_override_undo(cell_idx, old_override, 0)
			queue_redraw()
			cursor_overlay.queue_redraw()
		elif event.keycode == KEY_ESCAPE:
			text_cursor = Vector2i(-1, -1)
			cursor_overlay.queue_redraw()
		elif event.unicode > 0 and not event.ctrl_pressed:
			# Printable character — only if cursor is within bounds
			if text_cursor.x >= 0 and text_cursor.x < canvas_width and text_cursor.y >= 0 and text_cursor.y < canvas_height:
				var cell_idx = canvas.get_cell_index(text_cursor.x, text_cursor.y)
				var old_override = canvas.override_char[cell_idx]
				canvas.override_char[cell_idx] = event.unicode
				canvas.render_dirty[cell_idx] = 1
				_push_override_undo(cell_idx, old_override, event.unicode)
				# Advance cursor right, wrapping to next line
				text_cursor.x += 1
				if text_cursor.x >= canvas_width:
					text_cursor.x = 0
					text_cursor.y += 1
					if text_cursor.y >= canvas_height:
						# Reached the very end of canvas, stay at last cell
						text_cursor.x = canvas_width - 1
						text_cursor.y = canvas_height - 1
				queue_redraw()
				cursor_overlay.queue_redraw()
		else:
			handled = false
		
		if handled:
			accept_event()


func _push_override_undo(cell_idx: int, old_val: int, new_val: int) -> void:
	if old_val == new_val:
		return
	var action = UndoAction.new()
	action.override_changes[cell_idx] = {"old": old_val, "new": new_val}
	undo_manager.push_action(action)




# ── Blur Tool ────────────────────────────────────────────────────────

func _blur_stroke_segment(start_pos: Vector2, end_pos: Vector2) -> void:
	var dist_pixels = start_pos.distance_to(end_pos)
	var step_size = 2.0
	var steps = max(1, ceil(dist_pixels / step_size))
	
	var dirty_cells = {}
	var rad_sub = max(1.0, brush_size)
	
	for i in range(steps + 1):
		var t = float(i) / float(steps) if steps > 0 else 0.0
		var p = start_pos.lerp(end_pos, t)
		_blur_dab(p, rad_sub, dirty_cells)
		
	if not dirty_cells.is_empty():
		canvas.translate_dirty(palette)
		queue_redraw()


func _blur_dab(pos: Vector2, rad_sub: float, dirty_cells: Dictionary) -> void:
	var sub_pos_x = (pos.x / cell_size.x) * 2.0
	var sub_pos_y = (pos.y / cell_size.y) * 3.0
	
	var aspect_y = (cell_size.y / 3.0) / (cell_size.x / 2.0)
	var rad_sub_y = rad_sub / aspect_y
	
	var sub_w = canvas_width * 2
	var sub_h = canvas_height * 3
	
	var min_sx = int(max(0, sub_pos_x - rad_sub))
	var max_sx = int(min(sub_w - 1, sub_pos_x + rad_sub))
	var min_sy = int(max(0, sub_pos_y - rad_sub_y))
	var max_sy = int(min(sub_h - 1, sub_pos_y + rad_sub_y))
	
	var feather_dist = rad_sub * brush_feathering
	var inner_radius = max(0.0, rad_sub - feather_dist)
	
	for sy in range(min_sy, max_sy + 1):
		for sx in range(min_sx, max_sx + 1):
			var dx = (sx + 0.5) - sub_pos_x
			var dy = ((sy + 0.5) - sub_pos_y) * aspect_y
			var dist = min(Vector2(dx, dy).length(), rad_sub)
			
			if dist <= rad_sub:
				var falloff: float
				if feather_dist <= 0.001:
					falloff = 1.0 if dist <= rad_sub else 0.0
				else:
					if dist <= inner_radius:
						falloff = 1.0
					elif dist >= rad_sub:
						falloff = 0.0
					else:
						falloff = 1.0 - smoothstep(inner_radius, rad_sub, dist)
				
				var influence = falloff * brush_opacity
				var sub_idx = sy * sub_w + sx
				
				if influence > stroke_influence[sub_idx]:
					stroke_influence[sub_idx] = influence
					
					# Average with neighbors (3x3 kernel)
					var sum_intensity = 0.0
					var count = 0
					for ny in range(max(0, sy - 1), min(sub_h, sy + 2)):
						for nx in range(max(0, sx - 1), min(sub_w, sx + 2)):
							sum_intensity += stroke_start_intensity[ny * sub_w + nx]
							count += 1
					
					var blurred = sum_intensity / float(count)
					canvas.intensity[sub_idx] = lerp(stroke_start_intensity[sub_idx], blurred, influence)
					
					var cell_x = sx / 2
					var cell_y = sy / 3
					canvas.mark_cell_dirty(cell_x, cell_y)
					var cell_idx = canvas.get_cell_index(cell_x, cell_y)
					dirty_cells[cell_idx] = true


# ── Brush / Eraser (existing) ────────────────────────────────────────

func _paint_stroke_segment(start_pos: Vector2, end_pos: Vector2, is_erasing: bool) -> void:
	var dist_pixels = start_pos.distance_to(end_pos)
	# Step size in pixels. 2.0 ensures dense sub-pixel sampling without too much overhead.
	var step_size = 2.0 
	var steps = max(1, ceil(dist_pixels / step_size))
	
	var painted_cells = {}
	var rad_sub = max(1.0, brush_size)
	
	for i in range(steps + 1):
		var t = float(i) / float(steps) if steps > 0 else 0.0
		var p = start_pos.lerp(end_pos, t)
		_draw_brush_dab(p, is_erasing, rad_sub, brush_feathering, brush_opacity, painted_cells)
		
	if not painted_cells.is_empty():
		canvas.translate_dirty(palette)
		queue_redraw()

func _draw_brush_dab(pos: Vector2, is_erasing: bool, rad_sub: float, feathering: float, opacity: float, painted_cells: Dictionary) -> void:
	var sub_pos_x = (pos.x / cell_size.x) * 2.0
	var sub_pos_y = (pos.y / cell_size.y) * 3.0
	
	# Scale distance calculations by aspect ratio to ensure brush is a circle
	var aspect_y = (cell_size.y / 3.0) / (cell_size.x / 2.0)
	var rad_sub_y = rad_sub / aspect_y
	
	var min_sx = int(max(0, sub_pos_x - rad_sub))
	var max_sx = int(min(canvas_width * 2 - 1, sub_pos_x + rad_sub))
	var min_sy = int(max(0, sub_pos_y - rad_sub_y))
	var max_sy = int(min(canvas_height * 3 - 1, sub_pos_y + rad_sub_y))
	
	var feather_dist = rad_sub * feathering
	var inner_radius = max(0.0, rad_sub - feather_dist)
	
	for sy in range(min_sy, max_sy + 1):
		for sx in range(min_sx, max_sx + 1):
			var dx = (sx + 0.5) - sub_pos_x
			var dy = ((sy + 0.5) - sub_pos_y) * aspect_y
			var dist = min(Vector2(dx, dy).length(), rad_sub)
			
			if dist <= rad_sub:
				var falloff: float
				if feather_dist <= 0.001:
					falloff = 1.0 if dist <= rad_sub else 0.0
				else:
					if dist <= inner_radius:
						falloff = 1.0
					elif dist >= rad_sub:
						falloff = 0.0
					else:
						# proper smoothstep: goes 0 to 1 from inner to outer, so we invert it.
						falloff = 1.0 - smoothstep(inner_radius, rad_sub, dist)
				
				var influence = falloff * opacity
				var sub_idx = sy * (canvas_width * 2) + sx
				
				if influence > stroke_influence[sub_idx]:
					stroke_influence[sub_idx] = influence
					
					var cell_x = sx / 2
					var cell_y = sy / 3
					var cell_idx = canvas.get_cell_index(cell_x, cell_y)
					painted_cells[cell_idx] = Vector2i(cell_x, cell_y)
					
					if is_erasing:
						canvas.intensity[sub_idx] = lerp(stroke_start_intensity[sub_idx], 0.0, stroke_influence[sub_idx])
						canvas.override_char[cell_idx] = 0 
					elif active_tool == Tool.BRUSH:
						canvas.intensity[sub_idx] = lerp(stroke_start_intensity[sub_idx], 1.0, stroke_influence[sub_idx])
						canvas.color[sub_idx] = stroke_start_color[sub_idx].lerp(brush_color, stroke_influence[sub_idx])
					elif active_tool == Tool.COLOR:
						if canvas.intensity[sub_idx] > 0.001:
							if blend_mode == 0: # Mix
								canvas.color[sub_idx] = stroke_start_color[sub_idx].lerp(brush_color, stroke_influence[sub_idx])
							elif blend_mode == 1: # Add
								var blended = stroke_start_color[sub_idx] + brush_color
								blended.r = min(1.0, blended.r); blended.g = min(1.0, blended.g); blended.b = min(1.0, blended.b)
								canvas.color[sub_idx] = stroke_start_color[sub_idx].lerp(blended, stroke_influence[sub_idx])
							elif blend_mode == 2: # Multiply
								var blended = stroke_start_color[sub_idx] * brush_color
								canvas.color[sub_idx] = stroke_start_color[sub_idx].lerp(blended, stroke_influence[sub_idx])
					
					canvas.mark_cell_dirty(cell_x, cell_y)


# ── Undo ─────────────────────────────────────────────────────────────

func _commit_stroke_undo() -> void:
	var action = UndoAction.new()
	for i in range(stroke_start_intensity.size()):
		var old_val = stroke_start_intensity[i]
		var new_val = canvas.intensity[i]
		if not is_equal_approx(old_val, new_val):
			action.intensity_changes[i] = {"old": old_val, "new": new_val}
			
		var old_col = stroke_start_color[i]
		var new_col = canvas.color[i]
		if not old_col.is_equal_approx(new_col):
			action.color_changes[i] = {"old": old_col, "new": new_col}
	if not action.is_empty():
		undo_manager.push_action(action)
