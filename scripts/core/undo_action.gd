extends RefCounted
class_name UndoAction

## Represents a single undoable action.
## Stores only the sub-pixels and cells that actually changed.

# {sub_pixel_index: {old: float, new: float}}
var intensity_changes: Dictionary = {}

# {sub_pixel_index: {old: Color, new: Color}}
var color_changes: Dictionary = {}

# {cell_index: {old: int, new: int}}  — for override_char changes
var override_changes: Dictionary = {}


func apply_undo(canvas: CanvasData) -> void:
	for sub_idx in intensity_changes:
		canvas.intensity[sub_idx] = intensity_changes[sub_idx]["old"]
	for sub_idx in color_changes:
		canvas.color[sub_idx] = color_changes[sub_idx]["old"]
	for cell_idx in override_changes:
		canvas.override_char[cell_idx] = override_changes[cell_idx]["old"]
	_mark_affected_cells_dirty(canvas)


func apply_redo(canvas: CanvasData) -> void:
	for sub_idx in intensity_changes:
		canvas.intensity[sub_idx] = intensity_changes[sub_idx]["new"]
	for sub_idx in color_changes:
		canvas.color[sub_idx] = color_changes[sub_idx]["new"]
	for cell_idx in override_changes:
		canvas.override_char[cell_idx] = override_changes[cell_idx]["new"]
	_mark_affected_cells_dirty(canvas)


func is_empty() -> bool:
	return intensity_changes.is_empty() and override_changes.is_empty() and color_changes.is_empty()


func _mark_affected_cells_dirty(canvas: CanvasData) -> void:
	# Derive cell coords from sub-pixel indices and mark dirty
	var dirty_cells: Dictionary = {}
	for sub_idx in intensity_changes:
		var sx = sub_idx % (canvas.width * 2)
		var sy = sub_idx / (canvas.width * 2)
		var cell_x = sx / 2
		var cell_y = sy / 3
		var cell_idx = canvas.get_cell_index(cell_x, cell_y)
		dirty_cells[cell_idx] = Vector2i(cell_x, cell_y)
	for sub_idx in color_changes:
		var sx = sub_idx % (canvas.width * 2)
		var sy = sub_idx / (canvas.width * 2)
		var cell_x = sx / 2
		var cell_y = sy / 3
		var cell_idx = canvas.get_cell_index(cell_x, cell_y)
		dirty_cells[cell_idx] = Vector2i(cell_x, cell_y)
	for cell_idx in override_changes:
		if not dirty_cells.has(cell_idx):
			var cell_x = cell_idx % canvas.width
			var cell_y = cell_idx / canvas.width
			dirty_cells[cell_idx] = Vector2i(cell_x, cell_y)
	for cell_idx in dirty_cells:
		var pos = dirty_cells[cell_idx]
		canvas.mark_cell_dirty(pos.x, pos.y)
