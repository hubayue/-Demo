extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	if not _expect(main.has_method("_drag_preview_spec"), "battle drag must expose the Web placement preview model"):
		return
	main.advance_from_title()
	main.select_city(0)
	main.select_ruler("liubei")
	main.select_opening_hero("zhaoyun")
	var run = main.battle_run
	run.clear_formation()
	run.obstacles.clear()
	run.add_unit_at("zhaoyun", 2, 2)
	var spec: Dictionary = main._drag_preview_spec(run.units()[0], Vector2i(2, 1))
	if not _expect(spec.kind == "range" and spec.radius == 270.0 and spec.anchor == run.slot_center(1, 2), "ranged spear preview must anchor its exact attack radius to the drop cell"):
		return
	run.clear_formation()
	run.add_unit_at("guanyu", 2, 2)
	spec = main._drag_preview_spec(run.units()[0], Vector2i(2, 1))
	if not _expect(spec.kind == "corridor" and spec.width >= 34.0, "cavalry preview must show the Web charge corridor"):
		return
	run.clear_formation()
	run.add_unit_at("huangzhong", 2, 2)
	spec = main._drag_preview_spec(run.units()[0], Vector2i(2, 1))
	if not _expect(spec.kind == "global", "zero-range archer must preview full-field reach"):
		return
	run.clear_formation()
	run.add_unit_at("huatuo", 2, 2)
	spec = main._drag_preview_spec(run.units()[0], Vector2i(2, 1))
	if not _expect(spec.kind == "ripple" and spec.radius > 0.0, "support preview must expose its water-ripple radius"):
		return
	print("Godot v7.19.14 battle drag previews: PASS")
	quit(0)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
