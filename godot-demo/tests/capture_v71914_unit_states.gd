extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const LocalProfile = preload("res://src/progression/local_profile.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var output_directory := ProjectSettings.globalize_path("res://../output/godot")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var main = MainScene.instantiate()
	root.add_child(main)
	main.profile = LocalProfile.defaults(main.CURRENT_WEEK)
	main.profile.heroes["zhaoyun"] = {"lv": 10, "xp": 0, "rb": 2}
	main.profile.heroes["yanyan"] = {"lv": 1, "xp": 0, "rb": 0}
	main.profile.heroes["zhoutai"] = {"lv": 1, "xp": 0, "rb": 1}
	main.profile.heroes["zhangfei"] = {"lv": 1, "xp": 0, "rb": 0}
	main.advance_from_title()
	main.select_city(0)
	main.select_ruler("liubei")
	main.select_opening_hero("zhaoyun")
	var run = main.battle_run
	run.clear_formation()
	run.obstacles.clear()
	run.traits.clear()
	run.shen_ids = ["zhaoyun"]
	run.add_unit_at("yanyan", 1, 0)
	run.add_unit_at("zhaoyun", 1, 1)
	run.add_unit_at("zhoutai", 1, 3)
	run.add_unit_at("zhangfei", 2, 2)
	var zhao: Dictionary = run.grid[1][1]
	var zhou: Dictionary = run.grid[1][3]
	var zhang: Dictionary = run.grid[2][2]
	zhao.level = 12
	zhao.rbuffs = {"heal": 4.0, "haste": 4.0, "dmg": 4.0, "crit": 4.0, "cdr": 4.0, "farm": 4.0}
	zhou.reflectT = 3.0
	zhang.sealedT = 3.0
	run.taoyuan_time = 3.0
	run.army_buff = {"t": 3.0, "mul": 1.3}
	run.army_haste = {"t": 3.0, "mul": 1.4}
	run.game_time = 1.2
	run.wave = 8
	run.wave_timer = 3.0
	run.kills = 123
	run.level = 7
	run.xp = 7.0
	run.xp_need = 20.0
	run.enemies.clear()
	run.spawn_queue.clear()
	run.foe_lord = {}
	run.next_wave_preview = {"themeElems": ["liangmou"], "mutation": null, "boss": null, "affixes": {}, "specials": {}}
	run.foe_events.clear()
	run.field_events.clear()
	run.battle_floaters.clear()
	main.battle_field_banner_time = 0.0
	main.set_process(false)
	main.queue_redraw()
	await process_frame
	await process_frame
	var path := output_directory.path_join("v7.19.14-unit-states.png")
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != Vector2i(480, 800):
		push_error("Unit-state capture requires a non-empty 480x800 rendered window")
		quit(1)
		return
	var error := image.save_png(path)
	if error != OK:
		push_error("Unable to save unit-state capture: %s" % error_string(error))
		quit(1)
		return
	print("Godot v7.19.14 unit-state screenshot: %s" % path)
	quit(0)
