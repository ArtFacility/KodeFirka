extends PanelContainer

signal color_changed(color: Color)

@onready var true_color_picker: ColorPicker = %TrueColorPicker
@onready var toggle_wheel_btn: Button = %ToggleWheelBtn
@onready var grid_256: GridContainer = %Grid256
@onready var grid_16: GridContainer = %Grid16

var current_color: Color = Color.WHITE
var current_space: String = "true_color"

func _ready() -> void:
	true_color_picker.picker_shape = ColorPicker.SHAPE_HSV_WHEEL
	true_color_picker.sampler_visible = false
	true_color_picker.color_modes_visible = false
	true_color_picker.sliders_visible = false
	true_color_picker.hex_visible = false
	true_color_picker.presets_visible = false
	true_color_picker.color_changed.connect(_on_true_color_picker_changed)
	
	toggle_wheel_btn.toggled.connect(func(toggled_on: bool):
		true_color_picker.visible = toggled_on
	)

	_generate_16_colors()
	_generate_256_colors()
	set_color_space("true_color")

func set_color_space(space: String) -> void:
	current_space = space
	
	toggle_wheel_btn.visible = (space == "true_color")
	true_color_picker.visible = (space == "true_color" and toggle_wheel_btn.button_pressed)
	
	grid_256.visible = (space == "256")
	grid_16.visible = (space == "16")

func set_color(color: Color) -> void:
	current_color = color
	true_color_picker.color = color

func _on_true_color_picker_changed(color: Color) -> void:
	current_color = color
	color_changed.emit(color)

func _on_grid_color_pressed(color: Color) -> void:
	current_color = color
	color_changed.emit(color)
	true_color_picker.color = color

func _generate_16_colors() -> void:
	# Standard 16 colors (VGA / ANSI style)
	var colors = [
		Color("#000000"), Color("#800000"), Color("#008000"), Color("#808000"),
		Color("#000080"), Color("#800080"), Color("#008080"), Color("#c0c0c0"),
		Color("#808080"), Color("#ff0000"), Color("#00ff00"), Color("#ffff00"),
		Color("#0000ff"), Color("#ff00ff"), Color("#00ffff"), Color("#ffffff")
	]
	for c in colors:
		_add_color_button(grid_16, c, Vector2(24, 24))

func _generate_256_colors() -> void:
	# xterm 256 colors
	# 0-15: standard 16 colors
	# 16-231: 6x6x6 cube
	# 232-255: grayscale
	
	# 0-15
	var standard = [
		"#000000", "#800000", "#008000", "#808000", "#000080", "#800080", "#008080", "#c0c0c0",
		"#808080", "#ff0000", "#00ff00", "#ffff00", "#0000ff", "#ff00ff", "#00ffff", "#ffffff"
	]
	for hex in standard:
		_add_color_button(grid_256, Color(hex), Vector2(10, 10))
		
	# 16-231
	var values = [0, 95, 135, 175, 215, 255]
	for r in values:
		for g in values:
			for b in values:
				var c = Color(r / 255.0, g / 255.0, b / 255.0)
				_add_color_button(grid_256, c, Vector2(10, 10))
				
	# 232-255
	var step = 10.0 / 255.0 # grayscale starts at 8, steps by 10
	var g_val = 8.0 / 255.0
	for i in range(24):
		_add_color_button(grid_256, Color(g_val, g_val, g_val), Vector2(10, 10))
		g_val += step

func _add_color_button(parent: Control, color: Color, size: Vector2) -> void:
	var rect = ColorRect.new()
	rect.custom_minimum_size = size
	rect.color = color
	rect.focus_mode = Control.FOCUS_ALL # Allows receiving GUI input
	rect.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_grid_color_pressed(color)
	)
	rect.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(rect)
