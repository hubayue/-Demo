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
	main.select_opening_hero("zhangfei")
	await create_timer(4.5).timeout
	await process_frame
	await process_frame
	if not _save_capture(output_directory.path_join("v7.19.2-battle-foundation.png")):
		return
	main.foe_lord_popup = true
	main.queue_redraw()
	await process_frame
	await process_frame
	if not _save_capture(output_directory.path_join("v7.19.2-foe-commander-deck.png")):
		return
	main.foe_lord_popup = false
	var run = main.battle_run
	run.gain_xp(maxf(0.0, run.xp_need - run.xp))
	await process_frame
	await process_frame
	if not _save_capture(output_directory.path_join("v7.19.2-first-growth-draft.png")):
		return
	run.choose_card(0)
	run.clear_formation()
	run.obstacles.clear()
	run.add_unit_at("huangzhong", 0, 0)
	run.add_unit_at("yanyan", 2, 4)
	main.set_process(false)
	main.queue_redraw()
	await process_frame
	await process_frame
	if not _save_capture(output_directory.path_join("v7.19.2-active-bond.png")):
		return
	run.card_choices = run.card_system.roll_relics(run)
	run.awaiting_card_choice = true
	run.picking_relic = true
	main.queue_redraw()
	await process_frame
	await process_frame
	if not _save_capture(output_directory.path_join("v7.19.2-relic-draft.png")):
		return
	run.awaiting_card_choice = false
	run.picking_relic = false
	run.card_choices = []
	run.status = "play"
	run.clear_formation()
	run.obstacles.clear()
	run.add_unit_at("caoren", 0, 0)
	run.add_unit_at("zhangfei", 0, 1)
	run.add_unit_at("jiaxu", 1, 2)
	run.enemies = []
	for index in 8:
		run.enemies.append({
			"x": 48.0 + index * 54.0,
			"y": 488.0 if index < 2 else 330.0 + index * 10.0,
			"r": 17.0,
			"base_speed": 45.0,
			"hp": 180.0,
			"hp_max": 180.0,
			"tri": "badao",
			"cls": "spear",
			"xp": 0.0,
			"dmg": 1,
			"dead": false,
			"big": index == 7,
			"boss": false,
			"slowT": 0.0,
			"burnT": 0.0,
			"burnDmg": 0.0,
		})
	run.lord_command_cd = 0.0
	run.lord_system.update_command(run, 0.01)
	run.lord_attack_timer = 0.0
	run._update_lord_auto_attack(0.01)
	run._update_enemies(0.01)
	main.queue_redraw()
	await process_frame
	await process_frame
	if not _save_capture(output_directory.path_join("v7.19.2-ruler-command.png")):
		return
	var zhangfei: Dictionary = run.units().filter(func(unit): return str(unit.hero.id) == "zhangfei")[0]
	run.ult_system.cast(run, zhangfei)
	main.queue_redraw()
	await process_frame
	await process_frame
	if not _save_capture(output_directory.path_join("v7.19.2-hero-ultimate.png")):
		return
	print("Godot battle screenshots: PASS")
	quit(0)

func _save_capture(path: String) -> bool:
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != Vector2i(480, 800):
		push_error("Battle capture requires a non-empty 480x800 rendered window; do not use --headless")
		quit(1)
		return false
	var error := image.save_png(path)
	if error != OK:
		push_error("Unable to save battle capture: %s" % error_string(error))
		quit(1)
		return false
	return true
