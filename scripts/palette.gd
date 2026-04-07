extends Resource
class_name Palette

@export var name: String = "Default"
@export var characters: PackedStringArray = []
@export var lookup_table: PackedInt32Array = []

# Regional palette structure
# { "region_name": [ ["level1_char"], ["level2_char1", "level2_char2"] ] }
@export var regional_palette: Dictionary = {}

func _init() -> void:
	if lookup_table.size() == 0:
		lookup_table.resize(64)
		lookup_table.fill(0)

