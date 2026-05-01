extends Label
class_name AsciiRevealLabel

@export var scramble_chars: String = ".,-=*+:%$#@"
@export var reveal_speed: float = 30.0 # columns per second

var target_lines: PackedStringArray = []
var reveal_progress: float = 0.0 # goes from 0 to max_cols
var max_cols: int = 0
var _is_revealing: bool = false

func start_reveal(final_text: String) -> void:
	target_lines = final_text.split("\n")
	max_cols = 0
	for line in target_lines:
		if line.length() > max_cols:
			max_cols = line.length()
			
	reveal_progress = 0.0
	_is_revealing = true
	set_process(true)

func _process(delta: float) -> void:
	if not _is_revealing:
		return
		
	reveal_progress += reveal_speed * delta
	var progress_col = int(reveal_progress)
	
	if progress_col >= max_cols:
		text = "\n".join(target_lines)
		_is_revealing = false
		set_process(false)
		return
		
	var drawn_lines = PackedStringArray()
	for line in target_lines:
		var new_line = ""
		for x in range(line.length()):
			var ch = line[x]
			if ch in [" ", "\t", "\r"]:
				new_line += ch
			elif x <= progress_col:
				new_line += ch
			else:
				new_line += scramble_chars[randi() % scramble_chars.length()]
		drawn_lines.append(new_line)
		
	text = "\n".join(drawn_lines)
