extends Control

@onready var splash_label: Label = %SplashLabel
@onready var version_label: Label = %VersionLabel
@onready var new_button: Button = %NewButton
@onready var open_button: Button = %OpenButton
@onready var file_dialog: FileDialog = %FileDialog
@onready var recent_container: VBoxContainer = %RecentContainer

var new_project_dialog: Control = null

func _ready() -> void:
	var font = SystemFont.new()
	font.font_names = ["Consolas", "Courier New", "DejaVu Sans Mono", "Liberation Mono", "monospace"]
	splash_label.add_theme_font_override("font", font)
	
	var file = FileAccess.open("res://splashart.txt", FileAccess.READ)
	if file:
		splash_label.start_reveal(file.get_as_text())
	else:
		splash_label.start_reveal("KodeFirka")
		
	version_label.text = "Version " + ProjectSettings.get_setting("application/config/version", "Unknown")
	
	new_button.pressed.connect(_on_new_button_pressed)
	open_button.pressed.connect(_on_open_button_pressed)
	file_dialog.file_selected.connect(_on_file_dialog_file_selected)
	
	_populate_recent()

func _populate_recent() -> void:
	for child in recent_container.get_children():
		child.queue_free()
		
	var recents = UserSettings.get_recent_projects()
	if recents.is_empty():
		var label = Label.new()
		label.text = "No recent projects."
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate = Color(1.0, 1.0, 1.0, 0.5)
		recent_container.add_child(label)
	else:
		for path in recents:
			var btn = Button.new()
			btn.text = path.get_file()
			btn.tooltip_text = path
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			
			var hbox = HBoxContainer.new()
			var container_btn = Button.new()
			container_btn.text = "X"
			container_btn.custom_minimum_size = Vector2(30, 0)
			container_btn.pressed.connect(func(): _remove_recent(path))
			
			btn.pressed.connect(func(): _open_recent(path))
			
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			hbox.add_child(btn)
			hbox.add_child(container_btn)
			recent_container.add_child(hbox)

func _remove_recent(path: String) -> void:
	UserSettings.clear_recent_project(path)
	_populate_recent()

func _open_recent(path: String) -> void:
	if not FileAccess.file_exists(path):
		_populate_recent()
		return
	UserSettings.startup_action = {"type": "open", "path": path}
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_new_button_pressed() -> void:
	if new_project_dialog and is_instance_valid(new_project_dialog):
		new_project_dialog.show()
		return
	var dialog_scene = preload("res://scenes/new_project_dialog.tscn")
	new_project_dialog = dialog_scene.instantiate()
	add_child(new_project_dialog)
	new_project_dialog.project_confirmed.connect(_on_new_project_confirmed)

func _on_new_project_confirmed(width: int, height: int, palette_name: String, color_space: String) -> void:
	UserSettings.startup_action = {"type": "new", "w": width, "h": height, "pal": palette_name, "color_space": color_space}
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_open_button_pressed() -> void:
	file_dialog.popup_centered()

func _on_file_dialog_file_selected(path: String) -> void:
	UserSettings.startup_action = {"type": "open", "path": path}
	get_tree().change_scene_to_file("res://scenes/main.tscn")
