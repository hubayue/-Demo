extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const BattleRun = preload("res://src/battle/battle_run.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var output_directory := ProjectSettings.globalize_path("res://../output/godot")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var main = MainScene.instantiate()
	root.add_child(main)
	main.advance_from_title()
	main.select_city(0)
	main.select_ruler("liubei")
	main.select_opening_hero("zhaoyun")
	var run = main.battle_run
	run.clear_formation()
	run.obstacles = {"0,0": true, "0,4": true, "2,0": true, "2,4": true}
	run.traits.clear()
	run.add_unit_at("zhaoyun", 2, 2)
	run.add_unit_at("zhangfei", 1, 2)
	main.set_process(false)
	var source := BattleRun.slot_center(2, 2)
	var target := BattleRun.slot_center(0, 2)
	main.battle_drag.begin(Vector2i(2, 2), source)
	main.battle_drag.update(target)
	main.queue_redraw()
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != Vector2i(480, 800):
		push_error("Drag capture requires a non-empty 480x800 rendered window")
		quit(1)
		return
	var path := output_directory.path_join("v7.19.14-battle-drag.png")
	var error := image.save_png(path)
	if error != OK:
		push_error("Unable to save drag capture: %s" % error_string(error))
		quit(1)
		return
	print("Godot v7.19.14 drag screenshot: %s" % path)
	quit(0)
