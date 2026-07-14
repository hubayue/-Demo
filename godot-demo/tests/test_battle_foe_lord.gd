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
	if not _test_selection_and_cadence(catalog):
		return
	if not _test_bounded_cards(catalog):
		return
	if not _test_control_and_summons(catalog):
		return
	print("Godot v7.19.2 foe commanders: PASS")
	quit(0)

func _test_selection_and_cadence(catalog) -> bool:
	var run = _make_run(catalog)
	if not _expect(str(run.foe_lord.def.id) == "heyi" and run.foe_lord.deck.size() == 10, "week 2948 city 0 must deterministically seat Heyi with his ten-card deck"):
		return false
	var initial_deck: Array = run.foe_lord.deck.duplicate()
	run.wave = 7
	run.foe_system.update(run, 20.0)
	if not _expect(is_equal_approx(float(run.foe_lord.drawT), 30.0), "foe commander countdown must not move before wave eight"):
		return false
	run.wave = 8
	run.foe_lord.deck = ["rage"]
	run.foe_lord.idx = 0
	run.foe_lord.drawT = 30.0
	run.foe_lord.told = false
	run.foe_system.update(run, 0.1)
	if not _expect(bool(run.foe_lord.told) and str(run.foe_events[-1].kind) == "preview", "the next foe card must be revealed thirty seconds before it resolves"):
		return false
	run.foe_system.update(run, 29.9)
	if not _expect(is_equal_approx(run.foe_rage_time, 12.0) and is_equal_approx(float(run.foe_lord.drawT), 100.0), "the revealed card must resolve and reset the normal draw cadence to 100 seconds"):
		return false
	if not _expect(run.foe_lord.deck.size() == 10 and run.foe_lord.idx == 0, "a consumed ten-card deck must immediately reshuffle with a valid next card"):
		return false
	return _expect(initial_deck.size() == 10, "the original shuffled deck must stay complete")

func _test_bounded_cards(catalog) -> bool:
	var run = _make_run(catalog)
	run.clear_formation()
	run.obstacles.clear()
	for index in 5:
		run.add_unit_at(["zhangfei", "zhaoyun", "machao", "huangzhong", "xiahouyuan"][index], index / 5, index % 5)
	var units: Array = run.units()
	for index in units.size():
		units[index].damage_dealt = float(index * 100)
	var enemies := [_enemy(100.0, 300.0), _enemy(220.0, 320.0)]
	enemies[0].hp = 50.0
	run.enemies = enemies
	run.foe_system.cast_card(run, "heal")
	if not _expect(is_equal_approx(float(enemies[0].hp), 75.0), "Huangtian shelter must heal each living enemy for 25% max HP"):
		return false
	run.foe_system.cast_card(run, "shieldup")
	if not _expect(is_equal_approx(float(enemies[0].shield), 18.0), "Foe armor must grant every living enemy an 18% max-HP shield"):
		return false
	var hp_before := float(enemies[0].hp)
	run.damage_enemy(enemies[0], 10.0)
	if not _expect(is_equal_approx(float(enemies[0].hp), hp_before) and is_equal_approx(float(enemies[0].shield), 8.0), "enemy shields must absorb real incoming damage before HP"):
		return false
	var top: Dictionary = units[-1]
	run.foe_system.cast_card(run, "snipe")
	if not _expect(is_equal_approx(float(top.hp), float(top.hp_max) * 0.55), "Snipe must cut the current HP of the highest-damage fighter by 45%"):
		return false
	top.hp = 1.0
	run.foe_system.cast_card(run, "snipe")
	if not _expect(is_equal_approx(float(top.hp), 1.0), "foe direct-damage cards must never kill a fighter"):
		return false
	var wall_before: int = int(run.wall)
	run.foe_system.cast_card(run, "ramwall")
	if not _expect(run.wall == wall_before - 3, "Ramwall must remove three real wall HP"):
		return false
	run.wall = 2
	run.status = "play"
	run.foe_system.cast_card(run, "ramwall")
	if not _expect(run.wall == 0 and run.status == "play", "Ramwall may reduce the wall to zero but must not call the loss transition by itself"):
		return false
	run.wuxing_time = 5.0
	run.army_buff = {"t": 6.0, "mul": 1.3}
	run.foe_system.cast_card(run, "dispel")
	if not _expect(run.wuxing_time == 0.0 and run.army_buff.is_empty(), "Dispel must clear Wuxing and the active army damage buff"):
		return false
	var base_mods: Dictionary = run.team.unit_mods(run, units[0])
	run.foe_system.cast_card(run, "curse")
	var cursed_mods: Dictionary = run.team.unit_mods(run, units[0])
	if not _expect(is_equal_approx(float(cursed_mods.dmgMul), float(base_mods.dmgMul) * 0.75), "Curse must reduce real army damage by 25% for ten seconds"):
		return false
	run.foe_system.cast_card(run, "rage")
	return _expect(is_equal_approx(run.foe_damage_multiplier(), 1.3), "Rage must multiply real foe attack damage by 1.3")

func _test_control_and_summons(catalog) -> bool:
	var run = _make_run(catalog)
	run.clear_formation()
	run.obstacles.clear()
	for index in 5:
		run.add_unit_at(["zhangfei", "zhaoyun", "machao", "huangzhong", "xiahouyuan"][index], index / 5, index % 5)
	var units: Array = run.units()
	for index in units.size():
		units[index].damage_dealt = float(index * 100)
	var top: Dictionary = units[-1]
	run.foe_system.cast_card(run, "sealone")
	if not _expect(is_equal_approx(float(top.sealedT), 6.0), "Soul capture must seal the highest-damage fighter for six seconds"):
		return false
	var cd_before := float(top.cd)
	run._update_units(1.0)
	if not _expect(is_equal_approx(float(top.sealedT), 5.0) and is_equal_approx(float(top.cd), cd_before), "sealed fighters must lose one second without advancing their attack timer"):
		return false
	for unit in units:
		unit.hp = 100.0
	run.foe_system.cast_card(run, "firerain")
	if not _expect(units.filter(func(unit): return is_equal_approx(float(unit.hp), 70.0)).size() == 3, "Fire rain must hit exactly three fighters for 30% current HP"):
		return false
	var row_run = _make_run(catalog)
	row_run.clear_formation()
	row_run.obstacles.clear()
	for row in 3:
		for col in 5:
			row_run.add_unit_at("zhangfei", row, col)
	row_run.foe_system.cast_card(row_run, "sealrow")
	if not _expect(row_run.units().filter(func(unit): return is_equal_approx(float(unit.sealedT), 3.5)).size() == 5, "Lock formation must seal exactly one complete row for 3.5 seconds"):
		return false
	var event_count: int = row_run.foe_events.size()
	row_run.foe_system.cast_card(row_run, "taunt")
	if not _expect(row_run.foe_events.size() == event_count + 1 and str(row_run.foe_events[-1].card_id) == "taunt", "Taunt must consume a draw and publish only a personality line"):
		return false
	var before: int = run.enemies.size()
	run.wave = 8
	run.foe_system.cast_card(run, "drop")
	var dropped: Array = run.enemies.slice(before)
	if not _expect(dropped.size() == 2 and dropped.all(func(enemy): return str(enemy.special) == "assassin" and float(enemy.y) >= 250.0 and float(enemy.y) <= 340.0), "Drop must place two assassins directly into the middle field"):
		return false
	before = run.enemies.size()
	run.foe_system.cast_card(run, "reinforce")
	run.foe_system.cast_card(run, "ramcall")
	run.foe_system.cast_card(run, "shaman2")
	var summoned: Array = run.enemies.slice(before)
	return _expect(summoned.filter(func(enemy): return str(enemy.special) == "runner").size() == 3 \
		and summoned.filter(func(enemy): return str(enemy.special) == "ram").size() == 2 \
		and summoned.filter(func(enemy): return str(enemy.special) == "shaman").size() == 2, "the three summon cards must create 3 runners, 2 rams, and 2 shamans")

func _make_run(catalog):
	var run = BattleRun.new(catalog, Mulberry32.new(7192))
	run.start(_base_city(), "caocao", "zhangfei")
	run.obstacles.clear()
	return run

func _enemy(x: float, y: float) -> Dictionary:
	return {
		"x": x, "y": y, "r": 18.0, "base_speed": 0.0,
		"hp": 100.0, "hp_max": 100.0, "tri": "badao", "xp": 0.0,
		"dmg": 1, "dead": false, "big": false, "boss": false, "special": null,
		"slowT": 0.0, "burnT": 0.0, "burnDmg": 0.0, "shield": 0.0,
	}

func _base_city() -> Dictionary:
	return {"week": 2948, "k": 0, "ch": 1, "wall": 20, "theme": "", "field": "", "hpMul": 1.0, "spdMul": 1.0, "hpGrow": 1.1, "affixAdd": 0.0, "killTarget": 450, "obstacles": 0, "foes": {"tri": "badao"}}

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
