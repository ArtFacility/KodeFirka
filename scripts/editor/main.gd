extends Control

@onready var canvas_renderer = $Margin1/Interface/HSplit/CanvasScroll/CanvasCenter/CanvasOverscroll/CanvasRenderer
@onready var canvas_scroll = $Margin1/Interface/HSplit/CanvasScroll
@onready var brush_slider: HSlider = %BrushSlider
@onready var brush_label: Label = %BrushSize
@onready var feather_slider: HSlider = %FeatherSlider
@onready var feather_label: Label = %FeatherLabel
@onready var opacity_slider: HSlider = %OpacitySlider
@onready var opacity_label: Label = %OpacityLabel
@onready var blend_mode_margin: MarginContainer = %BlendModeMargin
@onready var blend_mode_option: OptionButton = %BlendModeOption

@onready var brush_preview = %BrushPreview
@onready var palette_option_button: OptionButton = %PaletteOptionButton
@onready var bg_color_picker: ColorPickerButton = %BgColorPickerButton
@onready var app_name_ver: Label = $Margin1/Interface/TopBarPanel/TopBarMargin/TopBar/AppNameVer

@onready var file_button = $Margin1/Interface/TopBarPanel/TopBarMargin/TopBar/FileButton
@onready var file_dialog = $FileDialog
@onready var zoom_slider: HSlider = $Margin1/Interface/StatusBarPanel/StatusBarMargin/StatusBar/ZoomSlider
@onready var options_button = $Margin1/Interface/TopBarPanel/TopBarMargin/TopBar/OptionsButton

var current_file_action: String = "" # "export_txt", "save", "open"
# current_project_path moved to project_manager
var tool_buttons: Dictionary = {} # Tool enum -> Button
var new_project_dialog: Control = null
var export_dialog: ConfirmationDialog = null
var current_export_format: int = 0
var current_export_scale: int = 1
var is_panning: bool = false
@onready var color_picker_panel: PanelContainer = %ColorPickerPanel
@onready var project_manager: ProjectManager = ProjectManager.new()

func _ready() -> void:
	add_child(project_manager)
	project_manager.project_created.connect(_apply_canvas_to_renderer)
	project_manager.project_loaded.connect(_apply_canvas_to_renderer)
	project_manager.error_occurred.connect(func(msg): print("Project Error: ", msg))

	file_button.get_popup().add_item("New Project", 0)
	file_button.get_popup().add_item("Save Project", 1)
	file_button.get_popup().add_item("Open Project", 2)
	file_button.get_popup().add_separator()
	file_button.get_popup().add_item("Export...", 3)
	file_button.get_popup().id_pressed.connect(_on_file_menu_id_pressed)
	file_dialog.file_selected.connect(_on_file_dialog_file_selected)
	app_name_ver.text = "KodeFirka " + ProjectSettings.get_setting("application/config/version", "Unknown")

	options_button.get_popup().add_item("Back to Project Picker", 0)
	options_button.get_popup().id_pressed.connect(_on_options_menu_id_pressed)

	# Palette OptionButton setup
	palette_option_button.add_item("Standard ASCII", 0)
	palette_option_button.add_item("Unicode Blocks", 1)
	
	# Color picker setup via natively instanced scene
	color_picker_panel.color_changed.connect(_on_color_picker_color_changed)
	
	bg_color_picker.color = canvas_renderer.canvas_bg_color
	bg_color_picker.color_changed.connect(_on_bg_color_picker_color_changed)
	
	# Tool buttons setup via native nodes
	var tools_container = $Margin1/Interface/TopBarPanel/TopBarMargin/TopBar/ToolsContainer
	tool_buttons[CanvasRenderer.Tool.BRUSH] = tools_container.get_node("BrushButton")
	tool_buttons[CanvasRenderer.Tool.ERASER] = tools_container.get_node("EraserButton")
	tool_buttons[CanvasRenderer.Tool.BLUR] = tools_container.get_node("BlurButton")
	tool_buttons[CanvasRenderer.Tool.TEXT] = tools_container.get_node("TextButton")
	tool_buttons[CanvasRenderer.Tool.COLOR] = tools_container.get_node("ColorButton")
	
	for tool in tool_buttons:
		var btn = tool_buttons[tool]
		btn.pressed.connect(func(): _set_tool(tool))
	
	# Connect zoom
	zoom_slider.value_changed.connect(_on_zoom_value_changed)
	
	# Connect scrollbars to renderer to update culling live
	canvas_scroll.get_h_scroll_bar().value_changed.connect(func(_val): if canvas_renderer: canvas_renderer.queue_redraw())
	canvas_scroll.get_v_scroll_bar().value_changed.connect(func(_val): if canvas_renderer: canvas_renderer.queue_redraw())

	# Setup initial slider values
	brush_slider.min_value = 1.0
	brush_slider.max_value = 20.0
	brush_slider.step = 0.5
	brush_slider.value = canvas_renderer.brush_size
	
	opacity_slider.min_value = 0.0
	opacity_slider.max_value = 1.0
	opacity_slider.step = 0.05
	opacity_slider.value = canvas_renderer.brush_opacity
	
	feather_slider.min_value = 0.0
	feather_slider.max_value = 1.0
	feather_slider.step = 0.05
	feather_slider.value = canvas_renderer.brush_feathering
	
	# Initial update for labels and preview
	_update_brush_settings()
	
	if UserSettings.startup_action.has("type"):
		var action = UserSettings.startup_action
		UserSettings.startup_action = {} # consume
		if action["type"] == "new":
			project_manager.create_new_project(action["w"], action["h"], action["pal"], action.get("color_space", "true_color"))
		elif action["type"] == "open":
			project_manager.open_project(action["path"])

func _update_brush_settings() -> void:
	# Sync values to renderer
	canvas_renderer.brush_size = brush_slider.value
	canvas_renderer.brush_opacity = opacity_slider.value
	canvas_renderer.brush_feathering = feather_slider.value
	
	# Update labels
	brush_label.text = "Brush size: %.1f" % brush_slider.value
	opacity_label.text = "Opacity: %.2f" % opacity_slider.value
	feather_label.text = "Feather: %.2f" % feather_slider.value
	
	# Update preview
	brush_preview.update_preview(brush_slider.value, opacity_slider.value, feather_slider.value, canvas_renderer.brush_color)

func _on_zoom_value_changed(value: float) -> void:
	if canvas_renderer:
		canvas_renderer.set_zoom(value)

func _on_brush_slider_value_changed(_value: float) -> void:
	_update_brush_settings()

func _on_opacity_slider_value_changed(_value: float) -> void:
	_update_brush_settings()

func _on_feather_slider_value_changed(_value: float) -> void:
	_update_brush_settings()

func _on_color_picker_color_changed(color: Color) -> void:
	canvas_renderer.brush_color = color
	_update_brush_settings()

func _on_bg_color_picker_color_changed(color: Color) -> void:
	canvas_renderer.canvas_bg_color = color
	canvas_renderer.queue_redraw()

func _on_blend_mode_item_selected(index: int) -> void:
	if canvas_renderer:
		canvas_renderer.blend_mode = index


func _on_file_menu_id_pressed(id: int) -> void:
	match id:
		0: # New Project
			_show_new_project_dialog()
		1: # Save Project
			if project_manager.current_project_path != "":
				project_manager.save_project(project_manager.current_project_path, canvas_renderer.canvas, _get_current_palette_name(), canvas_renderer.canvas_bg_color)
			else:
				current_file_action = "save"
				file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
				file_dialog.filters = PackedStringArray(["*.kfirka ; KodeFirka Project"])
				file_dialog.title = "Save Project"
				file_dialog.current_file = ""
				file_dialog.popup_centered()
		2: # Open Project
			current_file_action = "open"
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			file_dialog.filters = PackedStringArray(["*.kfirka ; KodeFirka Project"])
			file_dialog.title = "Open Project"
			file_dialog.current_file = ""
			file_dialog.popup_centered()
		3: # Export...
			_show_export_dialog()

func _get_current_palette_name() -> String:
	return "Standard ASCII" if palette_option_button.selected == 0 else "Unicode Blocks"

func _on_options_menu_id_pressed(id: int) -> void:
	match id:
		0:
			get_tree().change_scene_to_file("res://scenes/project_picker.tscn")


func _show_new_project_dialog() -> void:
	if new_project_dialog and is_instance_valid(new_project_dialog):
		new_project_dialog.show()
		return
	var dialog_scene = preload("res://scenes/new_project_dialog.tscn")
	new_project_dialog = dialog_scene.instantiate()
	add_child(new_project_dialog)
	new_project_dialog.project_confirmed.connect(_on_new_project_confirmed)


func _on_new_project_confirmed(width: int, height: int, palette_name: String, color_space: String) -> void:
	project_manager.create_new_project(width, height, palette_name, color_space)
	print("New project created: %dx%d" % [width, height])


func _on_file_dialog_file_selected(path: String) -> void:
	match current_file_action:
		"export":
			match current_export_format:
				0: Exporter.export_to_txt(path, canvas_renderer.canvas, canvas_renderer.palette)
				1: Exporter.export_to_ans(path, canvas_renderer.canvas, canvas_renderer.palette, canvas_renderer.canvas_bg_color)
				2: Exporter.export_to_neofetch(path, canvas_renderer.canvas, canvas_renderer.palette)
				3: Exporter.export_to_ans(path, canvas_renderer.canvas, canvas_renderer.palette, canvas_renderer.canvas_bg_color)
				4: Exporter.export_to_png_async(path, canvas_renderer, current_export_scale, self)
		"export_txt":
			Exporter.export_to_txt(path, canvas_renderer.canvas, canvas_renderer.palette)
		"save":
			project_manager.save_project(path, canvas_renderer.canvas, _get_current_palette_name(), canvas_renderer.canvas_bg_color)
		"open":
			project_manager.open_project(path)

func _show_export_dialog() -> void:
	if export_dialog and is_instance_valid(export_dialog):
		export_dialog.show_dialog()
		return
	var dialog_scene = preload("res://scenes/export_dialog.tscn")
	export_dialog = dialog_scene.instantiate()
	add_child(export_dialog)
	export_dialog.export_confirmed.connect(_on_export_confirmed)
	export_dialog.show_dialog()

func _on_export_confirmed(fmt_idx: int, scale_factor: int) -> void:
	export_dialog.hide()
	current_export_format = fmt_idx
	current_export_scale = scale_factor
	
	current_file_action = "export"
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	
	var ext = ""
	match fmt_idx:
		0, 2: # .txt
			ext = "*.txt ; Text File"
		1, 3: # .ans, .txt
			ext = "*.ans, *.txt ; ANSI Text File"
		4: # .png
			ext = "*.png ; Image File"
			
	file_dialog.filters = PackedStringArray([ext])
	file_dialog.title = "Save Exported File"
	file_dialog.current_file = ""
	file_dialog.popup_centered()

# _export_to_txt removed, logic moved to Exporter.gd
# _save_project removed, logic moved to ProjectManager.gd
# _open_project removed, logic moved to ProjectManager.gd


func _apply_canvas_to_renderer(new_canvas: CanvasData, palette_name: String, bg_color: Color) -> void:
	# Apply palette
	match palette_name:
		"Standard ASCII":
			canvas_renderer.palette = load("res://resources/default_palette.tres")
			palette_option_button.selected = 0
		"Unicode Blocks":
			canvas_renderer.palette = load("res://resources/unicode_palette.tres")
			palette_option_button.selected = 1
	
	if canvas_renderer.palette.characters.size() == 0 and canvas_renderer.palette.regional_palette.size() > 0:
		canvas_renderer._populate_characters_from_regional()
	
	# Replace canvas and update renderer dimensions
	canvas_renderer.canvas = new_canvas
	canvas_renderer.canvas_width = new_canvas.width
	canvas_renderer.canvas_height = new_canvas.height
	canvas_renderer.canvas_bg_color = bg_color
	bg_color_picker.color = bg_color
	
	if color_picker_panel and color_picker_panel.has_method("set_color_space"):
		color_picker_panel.set_color_space(new_canvas.color_space)
	
	var pixel_size = Vector2(
		new_canvas.width * canvas_renderer.cell_size.x,
		new_canvas.height * canvas_renderer.cell_size.y
	)
	canvas_renderer.custom_minimum_size = pixel_size
	canvas_renderer.size = pixel_size
	
	# Reset project state
	canvas_renderer.canvas.dirty.fill(1)
	canvas_renderer.canvas.translate_dirty(canvas_renderer.palette)
	canvas_renderer.queue_redraw()
	canvas_renderer.undo_manager.clear()
	
	_deferred_center_scroll()

func _deferred_center_scroll() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if canvas_scroll:
		var max_v = max(0, canvas_scroll.get_v_scroll_bar().max_value - canvas_scroll.size.y)
		var max_h = max(0, canvas_scroll.get_h_scroll_bar().max_value - canvas_scroll.size.x)
		canvas_scroll.scroll_vertical = max_v / 2
		canvas_scroll.scroll_horizontal = max_h / 2


func _on_palette_option_button_item_selected(index: int) -> void:
	match index:
		0:
			canvas_renderer.palette = load("res://resources/default_palette.tres")
		1:
			canvas_renderer.palette = load("res://resources/unicode_palette.tres")
	
	if canvas_renderer.palette and canvas_renderer.palette.characters.size() == 0 and canvas_renderer.palette.regional_palette.size() > 0:
		canvas_renderer._populate_characters_from_regional()
		
	# Force redraw with new palette
	canvas_renderer.canvas.dirty.fill(1)
	canvas_renderer.canvas.translate_dirty(canvas_renderer.palette)
	canvas_renderer.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = event.pressed
			if event.pressed:
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if Input.is_key_pressed(KEY_SPACE):
				is_panning = event.pressed
				if event.pressed:
					get_viewport().set_input_as_handled()
			elif not event.pressed and is_panning:
				is_panning = false

	if is_panning and event is InputEventMouseMotion:
		if canvas_scroll:
			canvas_scroll.scroll_horizontal -= event.relative.x
			canvas_scroll.scroll_vertical -= event.relative.y
			get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
		
	# Spacebar panning (like Photoshop)
	if event.keycode == KEY_SPACE:
		pass # Will be handled in _unhandled_input via input state
		
	# New / Save / Open shortcuts
	if event.keycode == KEY_N and event.ctrl_pressed:
		_show_new_project_dialog()
		get_viewport().set_input_as_handled()
		return
	elif event.keycode == KEY_S and event.ctrl_pressed:
		if project_manager.current_project_path != "":
			project_manager.save_project(project_manager.current_project_path, canvas_renderer.canvas, _get_current_palette_name(), canvas_renderer.canvas_bg_color)
		else:
			_on_file_menu_id_pressed(1) # Trigger save dialog
		get_viewport().set_input_as_handled()
		return
	elif event.keycode == KEY_O and event.ctrl_pressed:
		_on_file_menu_id_pressed(2) # Trigger open dialog
		get_viewport().set_input_as_handled()
		return
	
	# Undo/Redo (always available)
	if event.keycode == KEY_Z and event.ctrl_pressed:
		if event.shift_pressed:
			_do_redo()
		else:
			_do_undo()
		get_viewport().set_input_as_handled()
		return
	elif event.keycode == KEY_Y and event.ctrl_pressed:
		_do_redo()
		get_viewport().set_input_as_handled()
		return
	
	# Tool switching (only when not in text mode, to avoid eating typed chars)
	if canvas_renderer.active_tool != CanvasRenderer.Tool.TEXT:
		match event.keycode:
			KEY_B:
				_set_tool(CanvasRenderer.Tool.BRUSH)
				get_viewport().set_input_as_handled()
			KEY_E:
				_set_tool(CanvasRenderer.Tool.ERASER)
				get_viewport().set_input_as_handled()
			KEY_S:
				_set_tool(CanvasRenderer.Tool.BLUR)
				get_viewport().set_input_as_handled()
			KEY_T:
				_set_tool(CanvasRenderer.Tool.TEXT)
				get_viewport().set_input_as_handled()
			KEY_C:
				_set_tool(CanvasRenderer.Tool.COLOR)
				get_viewport().set_input_as_handled()
	else:
		# In text mode, Escape exits to brush
		if event.keycode == KEY_ESCAPE:
			_set_tool(CanvasRenderer.Tool.BRUSH)
			get_viewport().set_input_as_handled()


func _set_tool(tool: CanvasRenderer.Tool) -> void:
	canvas_renderer.active_tool = tool
	canvas_renderer.text_cursor = Vector2i(-1, -1)
	canvas_renderer.cursor_overlay.queue_redraw() # Instead of queue_redraw()
	_update_tool_buttons()
	blend_mode_margin.visible = (tool == CanvasRenderer.Tool.COLOR)


func _update_tool_buttons() -> void:
	for t in tool_buttons:
		tool_buttons[t].button_pressed = (t == canvas_renderer.active_tool)


func _do_undo() -> void:
	var um = canvas_renderer.undo_manager
	if um.can_undo():
		um.undo(canvas_renderer.canvas)
		canvas_renderer.canvas.translate_dirty(canvas_renderer.palette)
		canvas_renderer.queue_redraw()


func _do_redo() -> void:
	var um = canvas_renderer.undo_manager
	if um.can_redo():
		um.redo(canvas_renderer.canvas)
		canvas_renderer.canvas.translate_dirty(canvas_renderer.palette)
		canvas_renderer.queue_redraw()
