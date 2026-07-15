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
	run.ult_events = []
	run.clear_formation()
	run.obstacles.clear()
	run.add_unit_at("caoren", 0, 0)
	run.add_unit_at("huangzhong", 2, 2)
	run.add_unit_at("huatuo", 2, 4)
	run.enemies = []
	run.enemy_projectiles = []
	run.enemy_lobs = []
	run.enemy_wall_lobs = []
	run.lord_command_events = []
	run.lord_effect_rings = []
	run.wuxing_time = 0.0
	run.foe_events = []
	run.wave = 15
	var special_rows := [
		["healer", 58.0, 245.0], ["banner", 132.0, 280.0], ["warden", 206.0, 320.0],
		["shooter", 240.0, 355.0], ["cata", 318.0, 230.0], ["pavise", 390.0, 365.0],
	]
	for row in special_rows:
		run._spawn_enemy({"x": row[1], "y": row[2], "hp": 220.0, "speed": 0.0, "r": int(run.foe_behavior.SPECIALS[str(row[0])].r), "cls": "archer", "big": false, "boss": false, "affix": null, "special": row[0], "tri": "liangmou", "xp": 0.0, "dmg": 2})
	run._spawn_enemy({"x": 420.0, "y": 205.0, "hp": 900.0, "speed": 0.0, "r": 40, "cls": "spear", "big": true, "boss": true, "bossName": "张角", "affix": "shield", "special": null, "tri": "badao", "xp": 0.0, "dmg": 6, "summoner": true, "kit": "avatar", "kitSplit": 0})
	for enemy in run.enemies:
		if str(enemy.get("special", "")) == "shooter": enemy.shootT = 0.0
		if str(enemy.get("special", "")) == "cata": enemy.lobT = 0.0
	run._update_enemies(0.01)
	run._update_enemy_attacks(0.35)
	main.queue_redraw()
	await process_frame
	await process_frame
	if not _save_capture(output_directory.path_join("v7.19.2-special-foes.png")):
		return
	run.enemies = []
	run.enemy_projectiles = []
	run.enemy_lobs = []
	run.enemy_wall_lobs = []
	run.charges = []
	run.field_events = []
	run.city.field = "huoshan"
	run.wave = 10
	run.obstacles = {"0,0": true, "0,4": true, "2,0": true, "2,4": true}
	run.permanent_tactics = {"luanshi": true, "huoshao": true, "zhanshou": true, "luojing": true, "shuiyan": true, "pofu": true}
	run.environment.luanshi_wave = -1
	run.environment.shuiyan_wave = -1
	run.environment.volcano_time = 0.0
	for index in 6:
		run._spawn_enemy({"x": 80.0 + index * 64.0, "y": 270.0 + index * 12.0, "hp": 320.0, "speed": 0.0, "r": 18, "cls": "spear", "big": index == 5, "boss": false, "affix": null, "special": "runner" if index == 0 else null, "tri": "badao", "xp": 0.0, "dmg": 2})
	run.environment.update(run, 0.01)
	main.queue_redraw()
	await process_frame
	await process_frame
	if not _save_capture(output_directory.path_join("v7.19.2-tactics-fields.png")):
		return
	run.status = "play"
	run.wave = 15
	run.wall = run.wall_max
	run.unit_deaths = 0
	run.run_gold = 286.0
	run.max_hit = 1860
	run.total_damage = 1000.0
	run.counter_damage = 620.0
	run.finish("win")
	main.profile = LocalProfile.defaults(main.CURRENT_WEEK)
	main.week_clears = main.profile.week_clears
	main.profile.gold = 496
	main.profile.week_clears["0"] = 1
	main.profile.week_best["0"] = {"stars": 3, "endless": 0, "score": 150}
	main.settlement_summary = {"first_clear_gold": 210, "tech_score": 171, "lord_xp": {"gain": 12, "to": 2}}
	main.queue_redraw()
	await process_frame
	await process_frame
	if not _save_capture(output_directory.path_join("v7.19.2-result.png")):
		return
	run.continue_endless()
	run.wave = 20
	run.scored_wave = 19
	run.status = "play"
	run.finish("over")
	main.profile.week_best["0"] = {"stars": 3, "endless": 4, "score": 300}
	main.queue_redraw()
	await process_frame
	await process_frame
	if not _save_capture(output_directory.path_join("v7.19.2-suppression-result.png")):
		return
	main._return_to_map()
	main.state_popup = 0
	main.queue_redraw()
	await process_frame
	await process_frame
	if not _save_capture(output_directory.path_join("v7.19.2-local-record-map.png")):
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
