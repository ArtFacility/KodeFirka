extends ConfirmationDialog

signal export_confirmed(format_index: int, scale_factor: int)

@onready var format_option: OptionButton = OptionButton.new()
@onready var scale_slider: SpinBox = SpinBox.new()
@onready var neofetch_warning: Label = Label.new()
@onready var scale_container: HBoxContainer = HBoxContainer.new()

func _ready() -> void:
	title = "Export Project"
	
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	var format_label = Label.new()
	format_label.text = "Format:"
	vbox.add_child(format_label)
	
	format_option.add_item("Plain Text (.txt)", 0)
	format_option.add_item("ANSI Terminal (.ans)", 1)
	format_option.add_item("Neofetch (.txt)", 2)
	format_option.add_item("Fastfetch (.txt)", 3)
	format_option.add_item("Image (.png)", 4)
	vbox.add_child(format_option)
	format_option.item_selected.connect(_on_format_selected)
	
	# Scale container (for PNG only)
	var scale_label = Label.new()
	scale_label.text = "PNG Scale Factor:"
	scale_container.add_child(scale_label)
	
	scale_slider.min_value = 1
	scale_slider.max_value = 10
	scale_slider.value = 1
	scale_container.add_child(scale_slider)
	scale_container.visible = false
	vbox.add_child(scale_container)
	
	# Neofetch warning
	neofetch_warning.text = "Note: Standard Neofetch is limited to 6 dynamic colors (${c1}-${c6}).\nThe 6 most frequent colors will be used. For full true-color without loss, use Fastfetch format."
	neofetch_warning.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	neofetch_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	neofetch_warning.custom_minimum_size = Vector2(300, 0)
	neofetch_warning.visible = false
	vbox.add_child(neofetch_warning)
	
	confirmed.connect(_on_confirmed)

func show_dialog() -> void:
	popup_centered()

func _on_format_selected(idx: int) -> void:
	scale_container.visible = (idx == 4)
	neofetch_warning.visible = (idx == 2)
	reset_size() # Ensure it resizes

func _on_confirmed() -> void:
	export_confirmed.emit(format_option.selected, int(scale_slider.value))
