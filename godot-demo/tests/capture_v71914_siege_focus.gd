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
	main.select_ruler("caocao")
	main.select_opening_hero("huangzhong")
	var run = main.battle_run
	run.clear_formation()
	run.obstacles = {"0,0": true, "0,4": true, "2,0": true, "2,4": true}
	run.traits.clear()
	run.add_unit_at("huangzhong", 2, 2)
	run.add_unit_at("zhaoyun", 1, 1)
	run.add_unit_at("guanyu", 1, 3)
	run.enemies = []
	run._spawn_enemy({"x": 180.0, "y": 292.0, "hp": 220.0, "speed": 0.0, "r": 22, "cls": "archer", "big": true, "boss": false, "affix": null, "special": "cata", "tri": "badao", "xp": 0.0, "dmg": 1})
	run._spawn_enemy({"x": 300.0, "y": 320.0, "hp": 140.0, "speed": 0.0, "r": 18, "cls": "spear", "big": false, "boss": false, "affix": null, "special": null, "tri": "rende", "xp": 0.0, "dmg": 1})
	var cata: Dictionary = run.enemies[0]
	cata.lobT = 0.0
	run._update_enemies(0.65)
	run.focus_enemy(cata)
	main.set_process(false)
	main.queue_redraw()
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != Vector2i(480, 800):
		push_error("Siege focus capture requires a non-empty 480x800 rendered window")
		quit(1)
		return
	var path := output_directory.path_join("v7.19.14-siege-focus.png")
	var error := image.save_png(path)
	if error != OK:
		push_error("Unable to save siege focus capture: %s" % error_string(error))
		quit(1)
		return
	print("Godot v7.19.14 siege focus screenshot: %s" % path)
	quit(0)
