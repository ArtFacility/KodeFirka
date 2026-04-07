extends Control

@onready var canvas_renderer = $Margin1/Interface/HSplit/SubViewportContainer/SubViewport/CanvasRenderer
@onready var brush_slider: HSlider = $Margin1/Interface/HSplit/SideBarPanel/SideBarMargin/SideBar/Panel/MarginContainer/HBox/VBox/BrushSizeMargin/BrushSlider
@onready var brush_label: Label = $Margin1/Interface/HSplit/SideBarPanel/SideBarMargin/SideBar/Panel/MarginContainer/HBox/VBox/BrushSizeMargin/BrushSize
@onready var feather_slider: HSlider = $Margin1/Interface/HSplit/SideBarPanel/SideBarMargin/SideBar/Panel/MarginContainer/HBox/VBox/FeatherMargin/FeatherSlider
@onready var feather_label: Label = $Margin1/Interface/HSplit/SideBarPanel/SideBarMargin/SideBar/Panel/MarginContainer/HBox/VBox/FeatherMargin/FeatherLabel
@onready var opacity_slider: HSlider = $Margin1/Interface/HSplit/SideBarPanel/SideBarMargin/SideBar/Panel/MarginContainer/HBox/VBox/OpacityMargin/OpacitySlider
@onready var opacity_label: Label = $Margin1/Interface/HSplit/SideBarPanel/SideBarMargin/SideBar/Panel/MarginContainer/HBox/VBox/OpacityMargin/OpacityLabel

@onready var brush_preview = $Margin1/Interface/HSplit/SideBarPanel/SideBarMargin/SideBar/Panel/MarginContainer/HBox/BrushPreview
@onready var palette_option_button: OptionButton = $Margin1/Interface/HSplit/SideBarPanel/SideBarMargin/SideBar/Panel/MarginContainer/HBox/VBox/PaletteMargin/VBox/PaletteOptionButton

@onready var file_button = $Margin1/Interface/TopBarPanel/TopBarMargin/TopBar/FileButton
@onready var file_dialog = $FileDialog

func _ready() -> void:
	file_button.get_popup().add_item("Export as .txt", 0)
	file_button.get_popup().id_pressed.connect(_on_file_menu_id_pressed)
	file_dialog.file_selected.connect(_export_to_txt)

	# Palette OptionButton setup
	palette_option_button.add_item("Standard ASCII", 0)
	palette_option_button.add_item("Unicode Blocks", 1)

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
	# Using white for now as default brush color
	brush_preview.update_preview(brush_slider.value, opacity_slider.value, feather_slider.value, Color.WHITE)

func _on_brush_slider_value_changed(_value: float) -> void:
	_update_brush_settings()

func _on_opacity_slider_value_changed(_value: float) -> void:
	_update_brush_settings()

func _on_feather_slider_value_changed(_value: float) -> void:
	_update_brush_settings()

func _on_file_menu_id_pressed(id: int) -> void:
	if id == 0:
		file_dialog.popup_centered()

func _export_to_txt(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		print("Error opening file for write: ", path)
		return
		
	var data = canvas_renderer.canvas
	var pal = canvas_renderer.palette
	for y in range(data.height):
		var line = ""
		for x in range(data.width):
			var cell_idx = data.get_cell_index(x, y)
			var char_idx = data.resolved_chars[cell_idx]
			var ch = pal.characters[char_idx] if char_idx < pal.characters.size() else "?"
			line += ch
		file.store_line(line)
	file.close()

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
