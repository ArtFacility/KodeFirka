extends Control

signal project_confirmed(width: int, height: int, palette_name: String, color_space: String)

@onready var width_spinbox: SpinBox = $Panel/MarginContainer/VBox/WidthRow/WidthSpinBox
@onready var height_spinbox: SpinBox = $Panel/MarginContainer/VBox/HeightRow/HeightSpinBox
@onready var palette_option: OptionButton = $Panel/MarginContainer/VBox/PaletteRow/PaletteOption
@onready var color_space_option: OptionButton = $Panel/MarginContainer/VBox/ColorSpaceRow/ColorSpaceOption
@onready var create_button: Button = $Panel/MarginContainer/VBox/ButtonRow/CreateButton
@onready var cancel_button: Button = $Panel/MarginContainer/VBox/ButtonRow/CancelButton
@onready var warning_label: Label = %WarningLabel

func _ready() -> void:
	palette_option.add_item("Standard ASCII", 0)
	palette_option.add_item("Unicode Blocks", 1)
	
	color_space_option.add_item("True Color", 0)
	color_space_option.add_item("256 Colors", 1)
	color_space_option.add_item("16 Colors", 2)
	
	create_button.pressed.connect(_on_create)
	cancel_button.pressed.connect(_on_cancel)
	
	width_spinbox.value_changed.connect(_on_values_changed)
	height_spinbox.value_changed.connect(_on_values_changed)
	_update_warning()

func _on_values_changed(_val: float) -> void:
	_update_warning()

func _update_warning() -> void:
	var large = width_spinbox.value >= 500 or height_spinbox.value >= 500
	warning_label.visible = large

func _on_create() -> void:
	var w = int(width_spinbox.value)
	var h = int(height_spinbox.value)
	var pal = "Standard ASCII" if palette_option.selected == 0 else "Unicode Blocks"
	var c_space = ["true_color", "256", "16"][color_space_option.selected]
	project_confirmed.emit(w, h, pal, c_space)
	hide()

func _on_cancel() -> void:
	hide()
