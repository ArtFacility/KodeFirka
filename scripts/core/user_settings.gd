extends Node

const SETTINGS_PATH = "user://settings.cfg"
var config: ConfigFile = ConfigFile.new()

var startup_action: Dictionary = {}

func _ready() -> void:
	config.load(SETTINGS_PATH)

func get_recent_projects() -> Array:
	return config.get_value("history", "recent_projects", [])

func add_recent_project(path: String) -> void:
	var recents = get_recent_projects()
	if path in recents:
		recents.erase(path)
	recents.insert(0, path)
	if recents.size() > 10:
		recents.resize(10)
	config.set_value("history", "recent_projects", recents)
	config.save(SETTINGS_PATH)

func clear_recent_project(path: String) -> void:
	var recents = get_recent_projects()
	if path in recents:
		recents.erase(path)
		config.set_value("history", "recent_projects", recents)
		config.save(SETTINGS_PATH)
