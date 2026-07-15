extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

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
	main.select_opening_hero("jiangwei")
	var run = main.battle_run
	run.clear_formation()
	run.obstacles = {"0,0": true, "0,4": true, "2,0": true, "2,4": true}
	run.traits.clear()
	run.add_unit_at("jiangwei", 2, 2)
	run.enemies = []
	for index in 4:
		run._spawn_enemy({"x": 90.0 + index * 100.0, "y": 260.0 + abs(index - 1.5) * 35.0, "hp": 3000.0, "speed": 0.0, "r": 18, "cls": "spear", "big": false, "boss": false, "affix": null, "special": null, "tri": "badao", "xp": 0.0, "dmg": 1})
	var unit: Dictionary = run.units()[0]
	run.ult_system.cast(run, unit)
	for step in 25:
		run._update_homers(0.02)
	main.set_process(false)
	main.queue_redraw()
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != Vector2i(480, 800):
		push_error("Jiang Wei capture requires a non-empty 480x800 rendered window")
		quit(1)
		return
	var path := output_directory.path_join("v7.19.14-jiangwei-homers.png")
	var error := image.save_png(path)
	if error != OK:
		push_error("Unable to save Jiang Wei capture: %s" % error_string(error))
		quit(1)
		return
	print("Godot v7.19.14 Jiang Wei homers screenshot: %s" % path)
	quit(0)
