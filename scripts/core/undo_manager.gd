extends RefCounted
class_name UndoManager

## Command-pattern undo/redo system.
## Stores per-action deltas (only sub-pixels that actually changed).

const MAX_STACK_SIZE: int = 100

var _undo_stack: Array[UndoAction] = []
var _redo_stack: Array[UndoAction] = []


func push_action(action: UndoAction) -> void:
	_undo_stack.append(action)
	_redo_stack.clear()
	if _undo_stack.size() > MAX_STACK_SIZE:
		_undo_stack.remove_at(0)


func can_undo() -> bool:
	return _undo_stack.size() > 0


func can_redo() -> bool:
	return _redo_stack.size() > 0


func undo(canvas: CanvasData) -> void:
	if _undo_stack.is_empty():
		return
	var action = _undo_stack.pop_back()
	action.apply_undo(canvas)
	_redo_stack.append(action)


func redo(canvas: CanvasData) -> void:
	if _redo_stack.is_empty():
		return
	var action = _redo_stack.pop_back()
	action.apply_redo(canvas)
	_undo_stack.append(action)


func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
