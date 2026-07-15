extends SceneTree

const ContentCatalog = preload("res://src/content/content_catalog.gd")
const Mulberry32 = preload("res://src/core/mulberry32.gd")
const BattleRun = preload("res://src/battle/battle_run.gd")
const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog = ContentCatalog.new()
	if not _expect(catalog.load_from("res://data/content-v7.19.14.json") == OK, "v7.19.14 content must load"):
		return
	if not _test_catapult_pressure(catalog):
		return
	if not _test_focus_order(catalog):
		return
	if not await _test_focus_input():
		return
	print("Godot v7.19.14 siege and focus order: PASS")
	quit(0)

func _test_catapult_pressure(catalog) -> bool:
	var run = _make_run(catalog)
	run.clear_formation()
	var first := _enemy("cata", 180.0, BattleRun.GRID_Y - 221.0, 20.0)
	var second := _enemy("cata", 300.0, BattleRun.GRID_Y - 242.0, 0.0)
	first.lobT = 0.0
	second.lobT = 0.0
	run.enemies = [first, second]
	run._update_enemies(0.1)
	if not _expect(is_equal_approx(float(first.y), BattleRun.GRID_Y - 219.0) and not first.has("cataWind"), "catapult must walk down to the v7.19.6 y=272 stop line before winding"):
		return false
	run._update_enemies(0.01)
	second.y = BattleRun.GRID_Y - 210.0
	if not _expect(float(first.get("cataWind", 0.0)) > 1.98 and run.enemy_wall_lobs.is_empty(), "catapult must visibly wind for two seconds before it throws (wind=%.3f, lobs=%d, volley=%.3f)" % [float(first.get("cataWind", 0.0)), run.enemy_wall_lobs.size(), run.cata_volley_time]):
		return false
	if not _expect(run.cata_volley_time > 3.98 and not second.has("cataWind"), "starting one wind-up must hold every other catapult for four seconds"):
		return false
	for step in 199:
		run._update_enemies(0.01)
	if not _expect(first.get("cataWind") == null and is_equal_approx(float(first.lobT), 10.0), "a fired catapult must reset to the v7.19.9 ten-second interval"):
		return false
	if not _expect(run.enemy_wall_lobs.size() == 1 and float(first.get("cataHit", 0.0)) > 1.38, "the released stone must show a marked 1.4-second arc before wall damage"):
		return false
	run.wall_shield = 1
	var wall_before: int = run.wall
	for step in 140:
		run._update_enemies(0.01)
	if not _expect(run.wall_shield == 0 and run.wall == wall_before, "catapult landing must consume wall shield before wall health"):
		return false
	first.cataHit = 1.4
	for step in 140:
		run._update_enemies(0.01)
	if not _expect(run.wall == wall_before - 1 and run.wall_hurt, "an unshielded landing must remove exactly one wall point"):
		return false
	var cancelled := _enemy("cata", 240.0, BattleRun.GRID_Y - 200.0, 0.0)
	cancelled.lobT = 0.0
	run.enemies = [cancelled]
	run.cata_volley_time = 0.0
	run._update_enemies(0.01)
	cancelled.silencedT = 1.0
	run._update_enemies(0.1)
	return _expect(cancelled.get("cataWind") == null and is_equal_approx(float(cancelled.lobT), 1.0), "silence or flood during winding must slack the string and restart from one second")

func _test_focus_order(catalog) -> bool:
	var run = _make_run(catalog)
	run.clear_formation()
	run.obstacles.clear()
	run.add_unit_at("huangzhong", 2, 2)
	var urgent := _enemy("cata", 110.0, 290.0, 0.0)
	var near_fire := _enemy("cata", 240.0, 300.0, 0.0)
	var front := _enemy("", 240.0, 600.0, 0.0)
	urgent.cataWind = 1.2
	urgent.lobT = 7.0
	near_fire.lobT = 0.2
	run.enemies = [front, near_fire, urgent]
	if not _expect(run.focus_priority_catapult() == urgent, "warning bar must prioritize a winding catapult over one merely close to firing"):
		return false
	if not _expect(run.focus_enemy(urgent) and run.focus_target == urgent and is_equal_approx(run.focus_time, 3.0), "clicking an enemy must issue a three-second focus order"):
		return false
	var archer: Dictionary = run.units()[0]
	archer.cd = 0.0
	run._update_units(0.01)
	if not _expect(run.projectiles.size() == 1 and run.projectiles[0].get("lock_target") == urgent, "an in-range archer projectile must lock to the focused target and pass other enemies"):
		return false
	run.projectiles = [{"x": float(front.x), "y": float(front.y), "vx": 0.0, "vy": 0.0, "damage": 20.0, "tri": "", "r": 4.0, "distance": 0.0, "max_distance": 10.0, "crit": 0.0, "pierce": 0, "owner": {}, "lock_target": urgent, "hit": [], "dead": false}]
	urgent.dead = true
	var front_hp := float(front.hp)
	run._update_projectiles(0.01)
	if not _expect(float(front.hp) < front_hp, "a focused projectile must resume ordinary collision when its locked target dies"):
		return false
	urgent.dead = false
	urgent.y = 10.0
	run.focus_target = urgent
	run.focus_time = 3.0
	var fake_dragon := {"hero": {"cls": "dragon"}}
	if not _expect(run._focused_target_for_unit(fake_dragon, Vector2(240, 600), 0.0).is_empty(), "dragon must ignore a focused target until it enters below Web y=20"):
		return false
	run._update_focus(3.0)
	return _expect(run.focus_target.is_empty() and is_zero_approx(run.focus_time), "focus order must clear itself after three seconds")

func _test_focus_input() -> bool:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	main.advance_from_title()
	main.select_city(0)
	main.select_ruler("caocao")
	main.select_opening_hero("huangzhong")
	# Catapults only enter after the opening field banner has timed out in the Web demo.
	main.battle_field_banner_time = 0.0
	var cata := _enemy("cata", 180.0, 300.0, 0.0)
	var soldier := _enemy("", 320.0, 340.0, 0.0)
	cata.cataWind = 1.0
	main.battle_run.enemies = [soldier, cata]
	var warning_rect: Rect2 = main._cata_warning_rect()
	if not _expect(warning_rect.position.y == 128.0 and warning_rect.size.y == 30.0, "catapult warning button must occupy the Web v7.19.14 y=128 bar"):
		return false
	main._handle_pointer(warning_rect.get_center())
	if not _expect(main.battle_run.focus_target == cata, "clicking the warning bar must focus its most urgent catapult"):
		return false
	main._handle_pointer(Vector2(float(soldier.x), float(soldier.y)))
	if not _expect(main.battle_run.focus_target == soldier, "clicking a visible enemy must move the three-second focus order to it"):
		return false
	var unit: Dictionary = main.battle_run.units()[0]
	var occupied_center := BattleRun.slot_center(int(unit.row), int(unit.col))
	soldier.x = occupied_center.x
	soldier.y = occupied_center.y
	main.battle_run.focus_target = {}
	main.battle_run.focus_time = 0.0
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = occupied_center
	main._gui_input(press)
	var unit_won: bool = main.battle_drag.is_active() and main.battle_run.focus_target.is_empty()
	main.battle_drag.cancel()
	return _expect(unit_won, "an occupied formation cell must keep drag priority when an enemy overlaps it")

func _make_run(catalog):
	var run = BattleRun.new(catalog, Mulberry32.new(71914))
	run.start(_city(), "caocao", "guanyu")
	run.spawn_queue = []
	run.next_queue = []
	run.wave_budget = 999.0
	return run

func _city() -> Dictionary:
	return {"ch": 1, "idx": 64, "lvIdx": 64, "wall": 30, "theme": "", "field": "", "hpMul": 1.0, "spdMul": 1.0, "hpGrow": 1.1, "affixAdd": 0.0, "killTarget": 9999, "obstacles": 0, "foes": {"tri": ""}, "bossName": "张角", "bossKit": ""}

func _enemy(special: String, x: float, y: float, speed: float) -> Dictionary:
	return {"x": x, "y": y, "r": 18, "base_speed": speed, "hp": 100.0, "hp_max": 100.0, "shield": 0.0, "shield_max": 0.0, "tri": "", "cls": "spear", "xp": 0.0, "dmg": 1, "dead": false, "big": false, "boss": false, "affix": null, "special": special if not special.is_empty() else null, "silencedT": 0.0, "stunT": 0.0, "fearT": 0.0, "sleepT": 0.0, "charmT": 0.0, "slowT": 0.0, "summoner": false, "kit": null, "kitSplit": 0}

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
