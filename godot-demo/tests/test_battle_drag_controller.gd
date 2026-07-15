extends SceneTree

const ContentCatalog = preload("res://src/content/content_catalog.gd")
const Mulberry32 = preload("res://src/core/mulberry32.gd")
const BattleRun = preload("res://src/battle/battle_run.gd")
const BattleDragController = preload("res://src/input/battle_drag_controller.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog = ContentCatalog.new()
	if not _expect(catalog.load_from("res://data/content-v7.19.14.json") == OK, "v7.19.14 content must load"):
		return
	var run = BattleRun.new(catalog, Mulberry32.new(71914))
	run.start({"ch": 0, "wall": 13, "foe": "badao", "foes": {"tri": "badao"}, "theme": "tuanjie", "field": "plain", "rule": "", "boss": ""}, "liubei", "guanyu")
	run.clear_formation()
	run.obstacles.clear()
	run.traits.clear()
	if not _expect(run.add_unit_at("guanyu", 2, 1), "source unit must be placed"):
		return
	if not _expect(run.add_unit_at("zhaoyun", 1, 3), "swap target must be placed"):
		return

	var drag = BattleDragController.new()
	if not _expect(BattleDragController.cell_rect(Vector2i(0, 0)) == Rect2(38, 495, 76, 76), "formation cell geometry must match Web's +3 inset and CELL-6 rounded card"):
		return
	var source_point := BattleRun.slot_center(2, 1)
	var empty_target := BattleRun.slot_center(0, 4)
	if not _expect(drag.begin(Vector2i(1, 2), source_point), "pressing a unit starts a pending drag"):
		return
	if not _expect(not drag.is_dragging(), "press alone must not count as dragging"):
		return
	drag.update(source_point + Vector2(14, 0))
	if not _expect(not drag.is_dragging(), "motion exactly at the Web 14px threshold must remain a click"):
		return
	drag.update(source_point + Vector2(14.01, 0))
	if not _expect(drag.is_dragging(), "motion beyond the Web 14px threshold must start dragging"):
		return
	drag.update(empty_target)
	if not _expect(drag.is_dragging() and drag.hover_cell == Vector2i(4, 0), "drag must follow the pointer into the target cell"):
		return
	var result: Dictionary = drag.finish(empty_target)
	if not _expect(result.action == "drop" and result.source == Vector2i(1, 2) and result.target == Vector2i(4, 0), "release must report source and target"):
		return
	if not _expect(run.move_or_swap_unit(2, 1, 0, 4), "drop on an empty cell must move the unit"):
		return
	if not _expect(run.grid[0][4].hero.id == "guanyu" and run.grid[2][1] == null, "move must update the grid and unit coordinates"):
		return

	if not _expect(drag.begin(Vector2i(4, 0), empty_target), "moved unit must be draggable again"):
		return
	var swap_target := BattleRun.slot_center(1, 3)
	drag.update(swap_target)
	result = drag.finish(swap_target)
	if not _expect(result.action == "drop" and run.move_or_swap_unit(0, 4, 1, 3), "drop on a unit must swap"):
		return
	if not _expect(run.grid[1][3].hero.id == "guanyu" and run.grid[0][4].hero.id == "zhaoyun", "swap must update both units"):
		return

	run.obstacles["2,4"] = true
	if not _expect(not run.move_or_swap_unit(1, 3, 2, 4), "ordinary units cannot enter obstacles"):
		return
	if not _expect(run.grid[1][3].hero.id == "guanyu", "rejected drop must keep the source in place"):
		return

	if not _expect(drag.begin(Vector2i(3, 1), swap_target), "unit press must start another drag"):
		return
	drag.update(Vector2(470, 300))
	result = drag.finish(Vector2(470, 300))
	if not _expect(result.action == "sell" and result.target == Vector2i(-1, -1), "dragging above the formation must request Web sell behavior"):
		return
	if not _expect(run.sell_unit(1, 3), "selling with two units must remove the dragged unit"):
		return
	if not _expect(run.units().size() == 1 and run.units()[0].hero.id == "zhaoyun", "selling must keep the other formation unit and refund nothing"):
		return
	if not _expect(not run.sell_unit(0, 4), "the last formation unit must be protected from selling"):
		return

	drag.reset()
	if not _expect(drag.begin(Vector2i(4, 0), BattleRun.slot_center(0, 4)), "last unit must still accept a press"):
		return
	result = drag.finish(Vector2(240, 300))
	if not _expect(result.action == "inspect" and result.source == Vector2i(4, 0), "release without a move event must inspect instead of inventing a drag from the release point"):
		return

	if not _expect(drag.begin(Vector2i(4, 0), BattleRun.slot_center(0, 4)), "unit must accept another drag"):
		return
	drag.update(Vector2(10, 600))
	result = drag.finish(Vector2(10, 600))
	if not _expect(result.action == "cancel", "release outside the grid but not above the sell boundary must cancel"):
		return

	if not _expect(run.has_method("placement_error"), "BattleRun must expose one authoritative placement rejection reason"):
		return
	run.clear_formation()
	run.obstacles = {"0,0": true}
	run.add_unit_at("zhaoyun", 1, 1)
	if not _expect(run.placement_error(1, 1, 0, 0) == "target_obstacle", "ordinary units must report a blocked target obstacle"):
		return
	run.clear_formation()
	run.add_unit_at("dengai", 0, 0)
	run.add_unit_at("zhaoyun", 1, 1)
	if not _expect(run.placement_error(0, 0, 1, 1) == "swap_obstacle", "a non-Deng Ai swap target must not be moved onto Deng Ai's obstacle"):
		return
	run.clear_formation()
	run.add_unit_at("dengai", 1, 1)
	if not _expect(run.placement_error(1, 1, 0, 0).is_empty() and run.move_or_swap_unit(1, 1, 0, 0), "Deng Ai must be allowed to enter an obstacle"):
		return

	print("Godot v7.19.14 battle drag controller: PASS")
	quit(0)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
