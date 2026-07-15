class_name BattleDragController
extends RefCounted

const GRID_ROWS := 3
const GRID_COLS := 5
const CELL := 82.0
const GRID_X := (480.0 - GRID_COLS * CELL) / 2.0
const GRID_Y := 492.0
const DRAG_THRESHOLD := 8.0

var source_cell := Vector2i(-1, -1)
var hover_cell := Vector2i(-1, -1)
var press_position := Vector2.ZERO
var pointer_position := Vector2.ZERO
var active := false
var dragged := false

func begin(cell: Vector2i, point: Vector2) -> bool:
	if active or not _valid_cell(cell):
		return false
	source_cell = cell
	hover_cell = cell
	press_position = point
	pointer_position = point
	active = true
	dragged = false
	return true

func update(point: Vector2) -> void:
	if not active:
		return
	pointer_position = point
	if not dragged and press_position.distance_to(point) >= DRAG_THRESHOLD:
		dragged = true
	hover_cell = cell_at(point)

func finish(point: Vector2) -> Dictionary:
	if not active:
		return {"action": "none", "source": Vector2i(-1, -1), "target": Vector2i(-1, -1)}
	update(point)
	var target := hover_cell
	var action := "cancel"
	if dragged and point.y < GRID_Y - 40.0:
		action = "sell"
	elif dragged and _valid_cell(target):
		action = "drop"
	var result := {
		"action": action,
		"source": source_cell,
		"target": target if action == "drop" else Vector2i(-1, -1),
	}
	reset()
	return result

func cancel() -> void:
	reset()

func reset() -> void:
	source_cell = Vector2i(-1, -1)
	hover_cell = Vector2i(-1, -1)
	press_position = Vector2.ZERO
	pointer_position = Vector2.ZERO
	active = false
	dragged = false

func is_active() -> bool:
	return active

func is_dragging() -> bool:
	return active and dragged

static func cell_at(point: Vector2) -> Vector2i:
	if point.x < GRID_X or point.y < GRID_Y:
		return Vector2i(-1, -1)
	var col := int(floor((point.x - GRID_X) / CELL))
	var row := int(floor((point.y - GRID_Y) / CELL))
	var cell := Vector2i(col, row)
	return cell if _valid_cell(cell) else Vector2i(-1, -1)

static func cell_rect(cell: Vector2i) -> Rect2:
	if not _valid_cell(cell):
		return Rect2()
	return Rect2(GRID_X + cell.x * CELL + 3.0, GRID_Y + cell.y * CELL + 3.0, CELL - 6.0, CELL - 6.0)

static func _valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_COLS and cell.y >= 0 and cell.y < GRID_ROWS
