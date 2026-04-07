extends Control
class_name CanvasRenderer

@export var canvas_width: int = 80
@export var canvas_height: int = 40
@export var cell_size: Vector2 = Vector2(8, 16) # Approximate size of a monospace char
@export var brush_size: float = 2.0
@export var brush_opacity: float = 1.0
@export var brush_feathering: float = 0.2
@export var palette: Palette

var canvas: CanvasData

# State tracking for continuous strokes
var stroke_active: bool = false
var stroke_start_intensity: PackedFloat32Array
var stroke_influence: PackedFloat32Array
var last_mouse_pos: Vector2
var cursor_pos: Vector2
var show_cursor: bool = false

# Use a System monospace font instead of the generic variable-width fallback
var font: SystemFont = SystemFont.new()

func _ready() -> void:
	font.font_names = ["Consolas", "Courier New", "DejaVu Sans Mono", "Liberation Mono", "monospace"]
	canvas = CanvasData.new(canvas_width, canvas_height)
	
	if not palette:
		push_error("CanvasRenderer requires a Palette resource!")
	elif palette.characters.size() == 0 and palette.regional_palette.size() > 0:
		_populate_characters_from_regional()
		
	custom_minimum_size = Vector2(canvas_width * cell_size.x, canvas_height * cell_size.y)
	mouse_exited.connect(_on_mouse_exited)
	queue_redraw()

func _on_mouse_exited() -> void:
	show_cursor = false
	if stroke_active:
		stroke_active = false
	queue_redraw()

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
		
	for y in range(canvas_height):
		for x in range(canvas_width):
			var cell_idx = canvas.get_cell_index(x, y)
			
			# Draw background if needed
			var bg = canvas.bg_colors[cell_idx]
			if bg.a > 0.01:
				var rect = Rect2(Vector2(x, y) * cell_size, cell_size)
				draw_rect(rect, bg)
			
			# Draw character
			var char_idx = canvas.resolved_chars[cell_idx]
			var char_text = palette.characters[char_idx] if char_idx < palette.characters.size() else "?"
			var fg = canvas.fg_colors[cell_idx]
			
			# draw_string uses baseline position, so we add cell_size.y minus small offset
			var pos = Vector2(x, y) * cell_size + Vector2(0, cell_size.y * 0.8)
			draw_string(font, pos, char_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, fg)
			
	if show_cursor:
		var r = brush_size * (cell_size.x / 2.0)
		
		# Draw circular representation of cursor
		draw_arc(cursor_pos, r, 0, TAU, 32, Color(1, 1, 1, 0.5), 1.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		cursor_pos = event.position
		show_cursor = true
		queue_redraw()
		
	if event is InputEventMouseButton:
		var is_erasing = event.button_index == MOUSE_BUTTON_RIGHT
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				stroke_active = true
				stroke_start_intensity = canvas.intensity.duplicate()
				stroke_influence.resize(canvas.intensity.size())
				stroke_influence.fill(0.0)
				last_mouse_pos = event.position
				_paint_stroke_segment(last_mouse_pos, last_mouse_pos, is_erasing)
			else:
				stroke_active = false
				
	elif event is InputEventMouseMotion and stroke_active:
		var is_erasing = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		_paint_stroke_segment(last_mouse_pos, event.position, is_erasing)
		last_mouse_pos = event.position

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
					else:
						canvas.intensity[sub_idx] = lerp(stroke_start_intensity[sub_idx], 1.0, stroke_influence[sub_idx])
					
					canvas.mark_cell_dirty(cell_x, cell_y)
