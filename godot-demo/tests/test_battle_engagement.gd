extends SceneTree

const ContentCatalog = preload("res://src/content/content_catalog.gd")
const Mulberry32 = preload("res://src/core/mulberry32.gd")
const BattleRun = preload("res://src/battle/battle_run.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog = ContentCatalog.new()
	if not _expect(catalog.load_from("res://data/content-v7.19.2.json") == OK, "content must load"):
		return
	if not _test_same_column_interception(catalog):
		return
	if not _test_attack_cadence_and_scaling(catalog):
		return
	if not _test_unit_death_opens_the_lane(catalog):
		return
	if not _test_shield_retaliation(catalog):
		return
	if not _test_shield_counter_charge(catalog):
		return
	if not _test_taoyuan_absorption(catalog):
		return
	print("Godot v7.19.2 enemy engagement: PASS")
	quit(0)

func _test_same_column_interception(catalog) -> bool:
	var run = _make_run(catalog, "zhangfei", 0, 2)
	var unit: Dictionary = run.grid[0][2]
	unit.cd = 99.0
	var center := BattleRun.slot_center(0, 2)
	var stop_y := BattleRun.GRID_Y + 6.0 - 15.0 * 0.4
	var enemy := _enemy(center.x, stop_y - 1.0, 15.0, 100.0)
	run.enemies = [enemy]
	run.advance_real(0.01)
	if not _expect(is_equal_approx(float(enemy.y), stop_y), "an enemy must stop at the first living unit in its own column"):
		return false
	if not _expect(float(unit.hp) < float(unit.hp_max), "an intercepted enemy must attack the blocking unit instead of walking through it"):
		return false

	var other_lane = _enemy(BattleRun.slot_center(0, 3).x, stop_y - 1.0, 15.0, 100.0)
	run.enemies = [other_lane]
	var y_before := float(other_lane.y)
	run.advance_real(0.1)
	return _expect(float(other_lane.y) > y_before, "an empty column must remain open instead of pulling an enemy across lanes")

func _test_attack_cadence_and_scaling(catalog) -> bool:
	var run = _make_run(catalog, "zhangfei", 0, 2)
	run.wave = 5
	var unit: Dictionary = run.grid[0][2]
	unit.cd = 99.0
	var stop_y := BattleRun.GRID_Y + 6.0 - 15.0 * 0.4
	var enemy := _enemy(BattleRun.slot_center(0, 2).x, stop_y, 15.0, 100.0)
	run.enemies = [enemy]
	var hp_before := float(unit.hp)
	run._update_enemies(0.01)
	if not _expect(is_equal_approx(float(unit.hp), hp_before - 9.0), "wave-five ordinary melee damage must be round(7 * (1 + wave * 0.06))"):
		return false
	var after_first := float(unit.hp)
	run._update_enemies(1.19)
	if not _expect(is_equal_approx(float(unit.hp), after_first), "ordinary enemies must wait 1.2 seconds between melee hits"):
		return false
	run._update_enemies(0.02)
	return _expect(float(unit.hp) < after_first, "ordinary enemy melee must become ready after its 1.2-second cadence")

func _test_unit_death_opens_the_lane(catalog) -> bool:
	var run = _make_run(catalog, "zhangfei", 0, 2)
	var unit: Dictionary = run.grid[0][2]
	unit.hp = 1.0
	if not _expect(run.hurt_unit(unit, 7, 0, 2) == 7, "hurt_unit must report the real damage applied"):
		return false
	if not _expect(run.grid[0][2] == null and run.units().is_empty(), "a dead unit must leave its formation cell immediately"):
		return false
	var enemy := _enemy(BattleRun.slot_center(0, 2).x, BattleRun.GRID_Y - 1.0, 15.0, 100.0)
	run.enemies = [enemy]
	var y_before := float(enemy.y)
	run._update_enemies(0.1)
	return _expect(float(enemy.y) > y_before, "a lane must reopen after its blocker dies")

func _test_shield_retaliation(catalog) -> bool:
	var run = _make_run(catalog, "caoren", 0, 2)
	var shield: Dictionary = run.grid[0][2]
	shield.cd = 99.0
	var stop_y := BattleRun.GRID_Y + 6.0 - 15.0 * 0.4
	var enemy := _enemy(BattleRun.slot_center(0, 2).x, stop_y, 15.0, 1000.0)
	run.enemies = [enemy]
	run._update_enemies(0.01)
	var expected: float = 1000.0 - round(float(shield.hp_max) * 0.04)
	return _expect(is_equal_approx(float(enemy.hp), expected), "a shield blocker must retaliate for 4% of its maximum HP on every melee block")

func _test_shield_counter_charge(catalog) -> bool:
	var run = _make_run(catalog, "caoren", 0, 2)
	var shield: Dictionary = run.grid[0][2]
	var center := BattleRun.slot_center(0, 2)
	var enemy := _enemy(center.x, center.y - 40.0, 15.0, 1000.0)
	run.enemies = [enemy]
	var hit := roundi(float(shield.hp_max) * 0.3)
	run.hurt_unit(shield, hit, 0, 2)
	if not _expect(is_equal_approx(float(shield.get("tanked", 0.0)), float(hit)), "shield damage must fill the Web counter-charge meter"):
		return false
	run.hurt_unit(shield, hit, 0, 2)
	var expected_counter := roundi(float(hit * 2) * 0.8)
	if not _expect(is_equal_approx(float(shield.get("tanked", -1.0)), 0.0) and is_equal_approx(float(enemy.hp), 1000.0 - expected_counter), "a sixty-percent shield charge must counter nearby enemies for eighty percent of banked damage"):
		return false
	if not _expect(run.field_events.size() == 1, "a successful shield counter must emit one visible Web feedback event"):
		return false
	var event: Dictionary = run.field_events[0]
	return _expect(str(event.get("kind", "")) == "shield_counter" and str(event.get("label", "")) == "蓄势反击!" and is_equal_approx(float(event.get("x", -1.0)), center.x) and is_equal_approx(float(event.get("y", -1.0)), center.y), "shield counter feedback must burst at the shield and preserve the exact first-hit label")

func _test_taoyuan_absorption(catalog) -> bool:
	var run = _make_run(catalog, "zhangfei", 0, 2)
	var unit: Dictionary = run.grid[0][2]
	var hp_before := float(unit.hp)
	run.taoyuan_time = 2.0
	if not _expect(run.hurt_unit(unit, 11, 0, 2) == 0, "Taoyuan must make formation units immune while active"):
		return false
	return _expect(is_equal_approx(float(unit.hp), hp_before) and is_equal_approx(run.taoyuan_absorb, 11.0), "Taoyuan must bank every prevented point for its ending counterattack")

func _make_run(catalog, hero_id: String, row: int, col: int):
	var run = BattleRun.new(catalog, Mulberry32.new(7192))
	run.start(_base_city(), "caocao", hero_id)
	run.clear_formation()
	run.obstacles.clear()
	run.add_unit_at(hero_id, row, col)
	run.spawn_queue = []
	run.next_queue = []
	run.wave_budget = 0.0
	return run

func _enemy(x: float, y: float, radius: float, hp: float) -> Dictionary:
	return {
		"x": x, "y": y, "r": radius, "base_speed": 100.0,
		"hp": hp, "hp_max": hp, "tri": "badao", "xp": 0.0,
		"dmg": 1, "dead": false, "big": false, "boss": false,
	}

func _base_city() -> Dictionary:
	return {"ch": 1, "wall": 20, "theme": "", "field": "", "hpMul": 1.0, "spdMul": 1.0, "hpGrow": 1.1, "affixAdd": 0.0, "killTarget": 450, "obstacles": 0, "foes": {"tri": ""}}

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
