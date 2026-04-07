extends RefCounted
class_name CanvasData

var width: int
var height: int

var intensity: PackedFloat32Array
var color: PackedColorArray

# Resolved data per cell
var resolved_chars: PackedByteArray
var fg_colors: PackedColorArray
var bg_colors: PackedColorArray
var override_char: PackedByteArray # 0 = no override

# Flags
var dirty: PackedByteArray # Per-cell flag
var render_dirty: PackedByteArray # Per-cell flag

func _init(w: int, h: int) -> void:
	width = w
	height = h
	
	var sub_count = w * 2 * h * 3
	intensity.resize(sub_count)
	intensity.fill(0.0)
	color.resize(sub_count)
	color.fill(Color.WHITE)
	
	var cell_count = w * h
	resolved_chars.resize(cell_count)
	resolved_chars.fill(0)
	fg_colors.resize(cell_count)
	fg_colors.fill(Color.WHITE)
	bg_colors.resize(cell_count)
	bg_colors.fill(Color.TRANSPARENT)
	override_char.resize(cell_count)
	override_char.fill(0)
	
	dirty.resize(cell_count)
	dirty.fill(0)
	render_dirty.resize(cell_count)
	render_dirty.fill(1) # Start all dirty for first render

func get_cell_index(x: int, y: int) -> int:
	return y * width + x

func mark_cell_dirty(x: int, y: int) -> void:
	var idx = get_cell_index(x, y)
	if idx >= 0 and idx < dirty.size():
		dirty[idx] = 1

func translate_dirty(palette: Palette) -> void:
	for y in range(height):
		for x in range(width):
			var idx = get_cell_index(x, y)
			if dirty[idx] == 1:
				_translate_cell(x, y, palette)
				dirty[idx] = 0
				render_dirty[idx] = 1

func _translate_cell(x: int, y: int, palette: Palette) -> void:
	var cell_idx = get_cell_index(x, y)
	
	if override_char[cell_idx] != 0:
		return

	var i0 = 0.0; var i1 = 0.0; var i2 = 0.0; var i3 = 0.0; var i4 = 0.0; var i5 = 0.0
	var sum_color = Color(0,0,0,0)
	var active_count = 0
	
	for sy in range(3):
		for sx in range(2):
			var sub_idx_local = (y * 3 + sy) * (width * 2) + (x * 2 + sx)
			var sub_inten = intensity[sub_idx_local]
			if sy == 0 and sx == 0: i0 = sub_inten
			elif sy == 0 and sx == 1: i1 = sub_inten
			elif sy == 1 and sx == 0: i2 = sub_inten
			elif sy == 1 and sx == 1: i3 = sub_inten
			elif sy == 2 and sx == 0: i4 = sub_inten
			elif sy == 2 and sx == 1: i5 = sub_inten
			
			if sub_inten > 0.0:
				sum_color += color[sub_idx_local]
				active_count += 1
				
	var avg = (i0 + i1 + i2 + i3 + i4 + i5) / 6.0
	
	if active_count > 0:
		fg_colors[cell_idx] = sum_color / float(active_count)
	else:
		fg_colors[cell_idx] = Color.WHITE

	if avg < 0.05:
		resolved_chars[cell_idx] = 0
		return

	if palette.regional_palette.is_empty():
		# Fallback to old format if regional palette is missing
		var state = 0
		var bit = 0
		var dither = [1.0/7.0, 4.0/7.0, 6.0/7.0, 3.0/7.0, 2.0/7.0, 5.0/7.0]
		for sy in range(3):
			for sx in range(2):
				var sub_i = (y * 3 + sy) * (width * 2) + (x * 2 + sx)
				if intensity[sub_i] >= dither[bit]:
					state |= (1 << bit)
				bit += 1
		if palette.lookup_table.size() > state:
			var li = palette.lookup_table[state]
			resolved_chars[cell_idx] = li
		return

	var top = (i0 + i1) / 2.0
	var bottom = (i4 + i5) / 2.0
	var left = (i0 + i2 + i4) / 3.0
	var right = (i1 + i3 + i5) / 3.0
	
	var vec = Vector2(right - left, bottom - top)
	var out = -vec
	
	var region_str = "middle"
	if vec.length() > 0.15:
		var deg = rad_to_deg(out.angle())
		if deg > -22.5 and deg <= 22.5: region_str = "right"
		elif deg > 22.5 and deg <= 67.5: region_str = "bottom_right"
		elif deg > 67.5 and deg <= 112.5: region_str = "bottom"
		elif deg > 112.5 and deg <= 157.5: region_str = "bottom_left"
		elif deg > 157.5 or deg <= -157.5: region_str = "left"
		elif deg > -157.5 and deg <= -112.5: region_str = "top_left"
		elif deg > -112.5 and deg <= -67.5: region_str = "top"
		elif deg > -67.5 and deg <= -22.5: region_str = "top_right"
	
	var levels = palette.regional_palette.get(region_str, [])
	if levels.is_empty():
		levels = palette.regional_palette.get("middle", [])
		
	if levels.is_empty():
		resolved_chars[cell_idx] = 0
		return
		
	var level_idx = clampi(int(floor(avg * levels.size())), 0, levels.size() - 1)
	var chars_at_level = levels[level_idx]
	
	if chars_at_level.size() > 0:
		var str_idx = (x * 7 + y * 13) % chars_at_level.size()
		var char_str = chars_at_level[str_idx]
		
		var char_code = palette.characters.find(char_str)
		if char_code == -1:
			resolved_chars[cell_idx] = 0
		else:
			resolved_chars[cell_idx] = char_code
	else:
		resolved_chars[cell_idx] = 0
