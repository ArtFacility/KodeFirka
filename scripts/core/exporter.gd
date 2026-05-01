extends RefCounted
class_name Exporter

## Handles exporting the canvas into various formats.

static func export_to_txt(path: String, canvas: CanvasData, palette: Palette) -> Error:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Error opening file for write: ", path)
		return FileAccess.get_open_error()
		
	for y in range(canvas.height):
		var line = ""
		for x in range(canvas.width):
			var cell_idx = canvas.get_cell_index(x, y)
			if canvas.override_char[cell_idx] != 0:
				line += char(canvas.override_char[cell_idx])
			else:
				var char_idx = canvas.resolved_chars[cell_idx]
				var ch = palette.characters[char_idx] if char_idx < palette.characters.size() else "?"
				line += ch
		file.store_line(line)
	
	file.close()
	return OK

static func export_to_ans(path: String, canvas: CanvasData, palette: Palette, default_bg: Color) -> Error:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Error opening file for write: ", path)
		return FileAccess.get_open_error()
		
	for y in range(canvas.height):
		var line = ""
		var last_fg = Color(-1, -1, -1)
		var last_bg = Color(-1, -1, -1)
		
		for x in range(canvas.width):
			var cell_idx = canvas.get_cell_index(x, y)
			var ch = ""
			var fg = default_bg
			var bg = default_bg
			
			if canvas.override_char[cell_idx] != 0:
				ch = char(canvas.override_char[cell_idx])
				fg = Color.WHITE
			else:
				var char_idx = canvas.resolved_chars[cell_idx]
				ch = palette.characters[char_idx] if char_idx < palette.characters.size() else " "
				fg = canvas.fg_colors[cell_idx]
				bg = canvas.bg_colors[cell_idx]
				
			if fg != last_fg:
				line += "\u001b[38;2;%d;%d;%dm" % [int(fg.r * 255), int(fg.g * 255), int(fg.b * 255)]
				last_fg = fg
				
			if bg != last_bg:
				if bg.a < 0.01 or bg == default_bg:
					line += "\u001b[49m" # default terminal bg
				else:
					line += "\u001b[48;2;%d;%d;%dm" % [int(bg.r * 255), int(bg.g * 255), int(bg.b * 255)]
				last_bg = bg
				
			line += ch
		line += "\u001b[0m"
		file.store_line(line)
		
	file.close()
	return OK

static func export_to_neofetch(path: String, canvas: CanvasData, palette: Palette) -> Error:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file: return FileAccess.get_open_error()
	
	var freq = {}
	for y in range(canvas.height):
		for x in range(canvas.width):
			var idx = canvas.get_cell_index(x, y)
			var c_idx = canvas.resolved_chars[idx]
			var ch = " "
			if canvas.override_char[idx] != 0:
				ch = char(canvas.override_char[idx])
			else:
				ch = palette.characters[c_idx] if c_idx < palette.characters.size() else " "
				
			if ch != " ":
				var c = canvas.fg_colors[idx]
				if canvas.override_char[idx] != 0: c = Color.WHITE
				var html = c.to_html(false)
				freq[html] = freq.get(html, 0) + 1
				
	var sorted_colors = freq.keys()
	sorted_colors.sort_custom(func(a, b): return freq[a] > freq[b])
	var top_colors = sorted_colors.slice(0, 6)
	
	var html_to_var = {}
	for i in range(top_colors.size()):
		html_to_var[top_colors[i]] = "${c%d}" % (i + 1)
		
	for y in range(canvas.height):
		var line = ""
		var last_var = ""
		for x in range(canvas.width):
			var idx = canvas.get_cell_index(x, y)
			var ch = " "
			var html = ""
			
			if canvas.override_char[idx] != 0:
				ch = char(canvas.override_char[idx])
				html = Color.WHITE.to_html(false)
			else:
				var c_idx = canvas.resolved_chars[idx]
				ch = palette.characters[c_idx] if c_idx < palette.characters.size() else " "
				html = canvas.fg_colors[idx].to_html(false)
				
			if ch != " ":
				var mapped_var = ""
				if html_to_var.has(html):
					mapped_var = html_to_var[html]
				elif html_to_var.size() > 0:
					var cl_color = Color(html)
					var best_dist = 9999.0
					var best_v = html_to_var.values()[0]
					for k in html_to_var.keys():
						var k_c = Color(k)
						var dist = abs(cl_color.r - k_c.r) + abs(cl_color.g - k_c.g) + abs(cl_color.b - k_c.b)
						if dist < best_dist:
							best_dist = dist
							best_v = html_to_var[k]
					mapped_var = best_v
					html_to_var[html] = mapped_var
				
				if mapped_var != "" and mapped_var != last_var:
					line += mapped_var
					last_var = mapped_var
					
			line += ch
		file.store_line(line)
		
	file.close()
	return OK

static func export_to_png_async(path: String, src_renderer: CanvasRenderer, scale_factor: int, root_node: Node) -> void:
	var vp = SubViewport.new()
	vp.disable_3d = true
	vp.transparent_bg = false
	var cell_size = src_renderer.base_cell_size * float(scale_factor)
	vp.size = Vector2(src_renderer.canvas.width * cell_size.x, src_renderer.canvas.height * cell_size.y)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	var tr = CanvasRenderer.new()
	tr.canvas_width = src_renderer.canvas_width
	tr.canvas_height = src_renderer.canvas_height
	tr.base_cell_size = src_renderer.base_cell_size
	tr.base_font_size = src_renderer.base_font_size
	tr.palette = src_renderer.palette
	tr.canvas_bg_color = src_renderer.canvas_bg_color
	
	vp.add_child(tr)
	root_node.add_child(vp)
	
	# Set canvas AFTER _ready() runs so it is not overwritten by new CanvasData
	tr.canvas = src_renderer.canvas
	
	if tr is Control:
		tr.custom_minimum_size = vp.size
		tr.size = vp.size
		
	tr.set_zoom(float(scale_factor))
	tr.queue_redraw()
	
	await root_node.get_tree().process_frame
	await root_node.get_tree().process_frame
	await root_node.get_tree().process_frame
	
	var img = vp.get_texture().get_image()
	var err = img.save_png(path)
	if err != OK:
		push_error("Failed to save PNG: ", err)
		
	vp.queue_free()
