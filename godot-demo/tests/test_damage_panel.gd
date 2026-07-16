extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	main.advance_from_title()
	main.select_city(0)
	main.select_ruler("liubei")
	main.select_opening_hero("zhaoyun")
	var run = main.battle_run
	run.clear_formation()
	run.obstacles.clear()
	run.add_unit_at("zhaoyun", 2, 2)
	run.add_unit_at("guanyu", 1, 2)
	var zhaoyun: Dictionary = run.grid[2][2]
	var target := _enemy(240.0, 220.0, 100.0, 20.0)
	run.game_time = 2.0
	run.damage_enemy_from_unit(target, 9999.0, "", zhaoyun)
	if not _expect(is_equal_approx(float(run.damage_book.zhaoyun.total), 120.0) and is_equal_approx(float(zhaoyun.damage_dealt), 120.0), "ledger must count shield plus HP but exclude overkill for unit damage"): return
	var lord_target := _enemy(240.0, 220.0, 100.0, 0.0)
	run.game_time = 5.0
	run.damage_enemy(lord_target, 20.0, "", "lord")
	run.game_time = 16.0
	run.damage_enemy(lord_target, 10.0, "", "lord")
	if not _expect(is_equal_approx(float(run.damage_book["@lord"].total), 30.0) and run.damage_book["@lord"].log.size() == 1, "system source must aggregate by Web category while pruning samples older than ten seconds"): return
	run.enemies = [_enemy(240.0, 20.0, 100.0, 0.0)]
	var spec: Dictionary = main.damage_panel_spec()
	if not _expect(spec.rect == Rect2(85, 244, 310, 91) and spec.rows.size() == 3, "dynamic damage panel geometry must be 40 plus seventeen pixels per visible row"): return
	if not _expect(spec.rows[0].key == "zhaoyun" and int(spec.rows[0].share_percent) == 80 and spec.rows[1].key == "@lord" and int(spec.rows[1].dps) == 1, "rows must sort by cumulative actual damage and calculate the Web ten-second DPS window"): return
	var guanyu_rows: Array = spec.rows.filter(func(row): return str(row.key) == "guanyu")
	if not _expect(guanyu_rows.size() == 1 and bool(guanyu_rows[0].idle), "in-field attacking heroes with zero damage and no target in range must be listed as out of reach"): return
	if not _expect(main.damage_top_text(3) == "赵云80% · 👑主公20%", "settlement top-three text must use ledger share, not raw unit fields"): return
	var report_rows: Array = main.battle_report_rows()
	var output_rows: Array = report_rows.filter(func(row): return str(row.label) == "📊 输出前三")
	if not _expect(output_rows.size() == 1 and str(output_rows[0].value) == "赵云80% · 👑主公20%", "settlement report must expose the Web output top-three row"): return
	if not _expect(main.format_big_damage(100000.0) == "10.0万" and main.format_big_damage(100000000.0) == "1.0亿", "large damage values must use the Web Chinese abbreviations"): return
	var projectile_target := _enemy(240.0, 300.0, 500.0, 0.0)
	run.enemies = [projectile_target]
	run.projectiles = [{"x": 240.0, "y": 300.0, "vx": 0.0, "vy": 0.0, "damage": 10.0, "tri": "", "r": 4.0, "distance": 0.0, "max_distance": 10.0, "crit": 0.0, "pierce": 0, "owner": zhaoyun, "hit": [], "dead": false, "burn": true}]
	run._update_projectiles(0.01)
	if not _expect(projectile_target.get("burnSrc") == zhaoyun, "burning projectiles must preserve their owner for later damage ticks"): return
	var huanggai: Dictionary = run._make_unit(main.catalog.by_id("heroes", "huanggai"), 0, 0)
	var huanggai_target := _enemy(240.0, 300.0, 500.0, 0.0)
	run.enemies = [huanggai_target]
	run.ult_system._huanggai(run, huanggai)
	if not _expect(huanggai_target.get("burnSrc") == huanggai, "Huang Gai ignition must preserve the casting unit for later damage ticks"): return
	run.ruler_id = "dongzhuo"
	var lord_fire_target := _enemy(240.0, 400.0, 500.0, 0.0)
	run.enemies = [lord_fire_target]
	run.lord_attack_timer = 0.0
	run._update_lord_auto_attack(0.01)
	if not _expect(str(lord_fire_target.get("burnSrc", "")) == "lord", "Dong Zhuo attack ignition must stay attributed to the lord"): return
	var turncoat := _enemy(230.0, 300.0, 500.0, 0.0)
	var turncoat_victim := _enemy(250.0, 300.0, 500.0, 0.0)
	turncoat.turncoatT = 1.0
	turncoat.turncoatTick = 0.0
	turncoat.turncoatOwner = zhaoyun
	run.enemies = [turncoat, turncoat_victim]
	var before_turncoat := float(run.damage_book.zhaoyun.total)
	run._update_enemies(0.01)
	if not _expect(float(run.damage_book.zhaoyun.total) > before_turncoat, "turncoat attacks must remain attributed to Jia Xu instead of the miscellaneous category"): return
	print("Godot v7.19.14 damage panel: PASS")
	quit(0)

func _enemy(x: float, y: float, hp: float, shield: float) -> Dictionary:
	return {"x": x, "y": y, "hp": hp, "hp_max": hp, "base_speed": 0.0, "r": 16, "dmg": 1, "xp": 0.0, "tri": "", "cls": "spear", "dead": false, "boss": false, "big": false, "special": null, "affix": null, "kit": null, "kitSplit": 0, "shield": shield, "slowT": 0.0, "stunT": 0.0, "fearT": 0.0, "sleepT": 0.0, "charmT": 0.0, "silencedT": 0.0, "burnT": 0.0, "burnDmg": 0.0, "burnTick": 0.0, "kb": 0.0}

func _expect(condition: bool, message: String) -> bool:
	if condition: return true
	push_error(message)
	quit(1)
	return false
