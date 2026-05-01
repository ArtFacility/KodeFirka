extends Node
class_name ProjectManager

## Handles project lifecycle: creating, saving, and loading.

signal project_loaded(canvas: CanvasData, palette_name: String, bg_color: Color)
signal project_created(canvas: CanvasData, palette_name: String, bg_color: Color)
signal error_occurred(message: String)

var current_project_path: String = ""

func create_new_project(width: int, height: int, palette_name: String, color_space: String) -> void:
	var new_canvas = CanvasData.new(width, height, color_space)
	var default_bg = Color(0.05, 0.05, 0.06, 1.0)
	current_project_path = ""
	project_created.emit(new_canvas, palette_name, default_bg)

func save_project(path: String, canvas: CanvasData, palette_name: String, bg_color: Color) -> Error:
	var err = ProjectFile.save_project(path, canvas, palette_name, bg_color)
	if err == OK:
		current_project_path = path
		UserSettings.add_recent_project(path)
	else:
		error_occurred.emit("Failed to save project to: " + path)
	return err

func open_project(path: String) -> void:
	var result = ProjectFile.load_project(path)
	if result.is_empty():
		error_occurred.emit("Failed to load project from: " + path)
		return
	
	var loaded_canvas: CanvasData = result["canvas"]
	var palette_name: String = result["palette_name"]
	var bg_color: Color = result.get("bg_color", Color(0.05, 0.05, 0.06, 1.0))
	
	current_project_path = path
	UserSettings.add_recent_project(path)
	project_loaded.emit(loaded_canvas, palette_name, bg_color)
