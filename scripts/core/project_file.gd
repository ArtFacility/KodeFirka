extends RefCounted
class_name ProjectFile

## Handles .kfirka save/load.
## A .kfirka file is a ZIP archive containing:
##  - manifest.json: canvas size, palette name, version, metadata
##  - data/frame_0.bin: raw sub-pixel data (intensity, color, override_char)


static func save_project(path: String, canvas: CanvasData, palette_name: String, bg_color: Color) -> Error:
	var writer = ZIPPacker.new()
	var err = writer.open(path)
	if err != OK:
		push_error("Failed to open file for writing: ", path)
		return err
	
	# ── manifest.json ──
	var manifest = {
		"version": "0.1",
		"width": canvas.width,
		"height": canvas.height,
		"palette": palette_name,
		"bg_color": bg_color.to_html(),
		"color_space": canvas.color_space
	}
	writer.start_file("manifest.json")
	writer.write_file(JSON.stringify(manifest, "\t").to_utf8_buffer())
	writer.close_file()
	
	# ── data/frame_0.bin ──
	# Pack: intensity (float32) + color (4xfloat32 per sub-pixel) + override_char (int32 per cell)
	var sub_count = canvas.width * 2 * canvas.height * 3
	var cell_count = canvas.width * canvas.height
	
	# Calculate total bytes:
	# intensity: sub_count * 4
	# color: sub_count * 16 (4 floats * 4 bytes)
	# override_char: cell_count * 4
	var buf = PackedByteArray()
	
	# Write intensity as raw float32 bytes
	buf.append_array(canvas.intensity.to_byte_array())
	
	# Write colors as raw bytes (PackedColorArray → each Color is 4 floats = 16 bytes)
	buf.append_array(canvas.color.to_byte_array())
	
	# Write override_char as raw int32 bytes
	buf.append_array(canvas.override_char.to_byte_array())
	
	writer.start_file("data/frame_0.bin")
	writer.write_file(buf)
	writer.close_file()
	
	writer.close()
	return OK


static func load_project(path: String) -> Dictionary:
	## Returns {"canvas": CanvasData, "palette_name": String} or empty dict on failure
	var reader = ZIPReader.new()
	var err = reader.open(path)
	if err != OK:
		push_error("Failed to open .kfirka file: ", path)
		return {}
	
	# Read manifest
	var manifest_bytes = reader.read_file("manifest.json")
	if manifest_bytes.is_empty():
		push_error("Missing manifest.json in .kfirka file")
		reader.close()
		return {}
	
	var json = JSON.new()
	var parse_err = json.parse(manifest_bytes.get_string_from_utf8())
	if parse_err != OK:
		push_error("Failed to parse manifest.json")
		reader.close()
		return {}
	
	var manifest = json.data
	var w: int = manifest.get("width", 80)
	var h: int = manifest.get("height", 40)
	var palette_name: String = manifest.get("palette", "Standard ASCII")
	var bg_color_html: String = manifest.get("bg_color", "0d0d0fff")
	var bg_color: Color = Color(bg_color_html)
	var color_space: String = manifest.get("color_space", "true_color")
	
	# Read binary data
	var bin_data = reader.read_file("data/frame_0.bin")
	reader.close()
	
	if bin_data.is_empty():
		push_error("Missing data/frame_0.bin in .kfirka file")
		return {}
	
	var canvas = CanvasData.new(w, h, color_space)
	var sub_count = w * 2 * h * 3
	var cell_count = w * h
	
	var offset = 0
	
	# Read intensity (float32 array)
	var intensity_bytes = sub_count * 4
	if offset + intensity_bytes > bin_data.size():
		push_error("Corrupt .kfirka: not enough data for intensity")
		return {}
	canvas.intensity = bin_data.slice(offset, offset + intensity_bytes).to_float32_array()
	offset += intensity_bytes
	
	# Read color (PackedColorArray = float32 * 4 per color)
	var color_bytes = sub_count * 16
	if offset + color_bytes > bin_data.size():
		push_error("Corrupt .kfirka: not enough data for color")
		return {}
	# PackedColorArray from bytes: each Color is 4 floats
	var color_floats = bin_data.slice(offset, offset + color_bytes).to_float32_array()
	canvas.color.resize(sub_count)
	for i in range(sub_count):
		canvas.color[i] = Color(
			color_floats[i * 4],
			color_floats[i * 4 + 1],
			color_floats[i * 4 + 2],
			color_floats[i * 4 + 3]
		)
	offset += color_bytes
	
	# Read override_char (int32 array)
	var override_bytes = cell_count * 4
	if offset + override_bytes > bin_data.size():
		push_error("Corrupt .kfirka: not enough data for override_char")
		return {}
	canvas.override_char = bin_data.slice(offset, offset + override_bytes).to_int32_array()
	
	# Mark everything dirty so it gets re-translated on load
	canvas.dirty.fill(1)
	
	return {"canvas": canvas, "palette_name": palette_name, "bg_color": bg_color, "color_space": color_space}
