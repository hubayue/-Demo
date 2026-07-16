extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const LocalProfile = preload("res://src/progression/local_profile.gd")
const BattleCards = preload("res://src/battle/battle_cards.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var output_directory := ProjectSettings.globalize_path("res://../output/godot")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var main = MainScene.instantiate()
	root.add_child(main)
	main.profile = LocalProfile.defaults(main.CURRENT_WEEK)
	main.advance_from_title()
	main.select_city(0)
	main.select_ruler("liubei")
	main.select_opening_hero("zhaoyun")
	var run = main.battle_run
	run.clear_formation()
	run.obstacles = {"0,0": true, "0,4": true, "2,0": true, "2,4": true}
	run.traits.clear()
	for row in 3:
		for column in 5:
			run.traits["%d,%d" % [row, column]] = "haste"
	run.add_unit_at("zhaoyun", 2, 2)
	run.add_unit_at("zhangfei", 1, 2)
	run.enemies = []
	run.foe_events = []
	run.spawn_queue = []
	run.wave = 1
	run.wave_timer = 2.0
	run.wave_clock = 0.0
	run.wave_budget = 20.0
	run.kills = 0
	run.level = 1
	run.xp = 0.0
	run.xp_need = 10.0
	main.battle_field_banner_time = 9.0
	main.set_process(false)
	main.queue_redraw()
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != Vector2i(480, 800):
		push_error("Battle shell capture requires a non-empty 480x800 rendered window")
		quit(1)
		return
	var path := output_directory.path_join("v7.19.14-battle-shell.png")
	var error := image.save_png(path)
	if error != OK:
		push_error("Unable to save %s: %s" % [path, error_string(error)])
		quit(1)
		return
	var original_rules: Array = run.city.get("rules", []).duplicate()
	run.city.rules = ["smoke", "mud"]
	main.battle_field_banner_time = 9.0
	if not await _capture(main, output_directory, "v7.19.14-battle-multi-rule-banner.png"):
		return
	run.city.rules = original_rules
	main.battle_field_banner_time = 0.0
	run.lord_command_cd = 0.0
	run.lord_command_cd_total = run.lord_command_cooldown_max()
	main.player_lord_popup = true
	main.queue_redraw()
	await process_frame
	await process_frame
	image = root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != Vector2i(480, 800):
		push_error("Player lord popup capture requires a non-empty 480x800 rendered window")
		quit(1)
		return
	path = output_directory.path_join("v7.19.14-player-lord-popup.png")
	error = image.save_png(path)
	if error != OK:
		push_error("Unable to save %s: %s" % [path, error_string(error)])
		quit(1)
		return
	main.player_lord_popup = false
	run.clear_formation()
	run.obstacles.clear()
	run.traits.clear()
	run.level = 7
	run.wave = 8
	run.kills = 123
	run.xp = 7.0
	run.xp_need = 20.0
	run.wave_timer = 2.2
	run.wave_budget = 10.0
	run.wave_clock = 4.2
	run.enemies.clear()
	run.spawn_queue.clear()
	run.next_wave_preview = {"themeElems": ["badao"], "mutation": null, "boss": "张梁", "affixes": {"shield": 2}, "specials": {"cata": 1}}
	if not await _capture(main, output_directory, "v7.19.14-battle-empty-rest.png"):
		return
	run.next_wave_preview.clear()
	var hero: Dictionary = main.catalog.by_id("heroes", "zhaoyun")
	for row in 3:
		for column in 5:
			run.grid[row][column] = run._make_unit(hero, row, column)
	run.team.recompute(run)
	if not await _capture(main, output_directory, "v7.19.14-battle-full-grid.png"):
		return
	run.clear_formation()
	run.add_unit_at("daqiao", 0, 1)
	run.add_unit_at("xiaoqiao", 0, 3)
	run.grid[2][1] = run._make_unit(BattleCards.GRANARY_TYPE, 2, 1)
	run.add_unit_at("zhaoyun", 2, 2)
	run.team.recompute(run)
	if not await _capture(main, output_directory, "v7.19.14-battle-support-links.png"):
		return
	print("Godot v7.19.14 battle shell screenshot: PASS")
	quit(0)

func _capture(main, output_directory: String, filename: String) -> bool:
	main.queue_redraw()
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != Vector2i(480, 800):
		push_error("%s capture requires a non-empty 480x800 rendered window" % filename)
		quit(1)
		return false
	var path := output_directory.path_join(filename)
	var error := image.save_png(path)
	if error != OK:
		push_error("Unable to save %s: %s" % [path, error_string(error)])
		quit(1)
		return false
	return true
