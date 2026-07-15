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
	main.select_opening_hero("machao")
	var run = main.battle_run
	run.clear_formation()
	run.obstacles = {"0,0": true, "0,4": true, "2,0": true, "2,4": true}
	run.traits.clear()
	run.add_unit_at("machao", 2, 2)
	run.add_unit_at("taishici", 2, 1)
	run.enemies = []
	for index in 7:
		run._spawn_enemy({"x": 125.0 + (index % 4) * 72.0, "y": 220.0 + (index / 4) * 55.0 + (index % 2) * 18.0, "hp": 4000.0 if index == 2 else 1600.0, "speed": 0.0, "r": 18, "cls": "spear", "big": index == 2, "boss": false, "affix": null, "special": null, "tri": "badao", "xp": 0.0, "dmg": 1})
	var machao: Dictionary = run.units().filter(func(unit): return str(unit.hero.id) == "machao")[0]
	var taishici: Dictionary = run.units().filter(func(unit): return str(unit.hero.id) == "taishici")[0]
	run.ult_system.cast(run, machao)
	run.ult_system.cast(run, taishici)
	run.ult_events.clear()
	for lob in run.friendly_lobs:
		lob.dur = 0.25
	run._update_friendly_lobs(0.19)
	main.set_process(false)
	main.queue_redraw()
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != Vector2i(480, 800):
		push_error("Targeted-skill capture requires a non-empty 480x800 rendered window")
		quit(1)
		return
	var path := output_directory.path_join("v7.19.14-targeted-skill-geometry.png")
	var error := image.save_png(path)
	if error != OK:
		push_error("Unable to save targeted-skill capture: %s" % error_string(error))
		quit(1)
		return
	print("Godot v7.19.14 targeted skill geometry screenshot: %s" % path)
	quit(0)
