extends SceneTree

const ContentCatalog = preload("res://src/content/content_catalog.gd")
const Mulberry32 = preload("res://src/core/mulberry32.gd")
const BattleRun = preload("res://src/battle/battle_run.gd")
const BattleTeam = preload("res://src/battle/battle_team.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture := _load_json("res://tests/fixtures/v7.19.2-team-modifiers.json")
	if fixture.is_empty():
		return
	var catalog = ContentCatalog.new()
	if not _expect(catalog.load_from("res://data/content-v7.19.2.json") == OK, "content must load"):
		return
	for case_data in fixture.cases:
		var run = BattleRun.new(catalog, Mulberry32.new(7192))
		run.start(case_data.city, "caocao", str(case_data.heroes[0]))
		if not _expect(run.get("team") != null and run.team.get_script() == BattleTeam, "%s must create a BattleTeam" % case_data.id):
			return
		run.clear_formation()
		run.obstacles.clear()
		run.traits.clear()
		for index in case_data.heroes.size():
			var cell: Array = case_data.cells[index]
			if not _expect(run.add_unit_at(str(case_data.heroes[index]), int(cell[0]), int(cell[1])), "%s hero %d must enter its fixed cell" % [case_data.id, index]):
				return
		if not _expect(_integer_dictionary_equal(run.team.counts, case_data.counts), "%s class counts must match browser runtime: %s != %s" % [case_data.id, run.team.counts, case_data.counts]):
			return
		if not _expect(run.team.active_bond_ids() == case_data.activeBonds, "%s active bonds must match browser runtime" % case_data.id):
			return
		if not _expect(run.team.has_method("unit_mods") and run.team.has_method("unit_damage") and run.team.has_method("unit_rate"), "BattleTeam must expose Web combat modifier calculations"):
			return
		for expected_unit in case_data.units:
			var actual_fx: Dictionary = run.team.bond_fx(run, str(expected_unit.id))
			if not _expect(_dictionary_equal_approx(actual_fx, expected_unit.bondFx), "%s %s bond effects must match browser runtime" % [case_data.id, expected_unit.id]):
				return
			var unit := _find_unit(run.units(), str(expected_unit.id))
			var mods: Dictionary = run.team.unit_mods(run, unit)
			for key in ["dmgMul", "rateMul", "crit", "pierceAdd"]:
				if not _expect(is_equal_approx(float(mods[key]), float(expected_unit[key])), "%s %s %s must match browser runtime" % [case_data.id, expected_unit.id, key]):
					return
			if not _expect(run.team.unit_damage(run, unit, mods) == int(expected_unit.damage), "%s %s damage must match browser runtime" % [case_data.id, expected_unit.id]):
				return
			if not _expect(is_equal_approx(run.team.unit_rate(unit, mods), float(expected_unit.rate)), "%s %s rate must match browser runtime" % [case_data.id, expected_unit.id]):
				return
		if str(case_data.id) == "laojiang":
			if not _expect(run.upgrade_hero("huangzhong"), "bonded Huang Zhong must be upgradeable"):
				return
			var upgraded := _find_unit(run.units(), "huangzhong")
			if not _expect(int(upgraded.hp_max) == 119 and int(upgraded.hp) == 119, "upgrading after bond activation must apply the browser HP multiplier"):
				return
			run.relic_ids = ["jinlan"]
			var jinlan_fx: Dictionary = run.team.bond_fx(run, "huangzhong")
			if not _expect(is_equal_approx(float(jinlan_fx.dmg), 1.8775) and is_equal_approx(float(jinlan_fx.hp), 1.8775), "Jinlan and tuanjie must multiply the active bond bonus like the browser"):
				return
	if not _test_dengai_obstacle(catalog):
		return
	if not _test_erqiao_ripple_radius(catalog):
		return
	print("Godot v7.19.2 battle team state: PASS")
	quit(0)

func _test_dengai_obstacle(catalog) -> bool:
	var run = BattleRun.new(catalog, Mulberry32.new(7192))
	run.start(_base_city(""), "caocao", "zhangfei")
	run.clear_formation()
	run.obstacles = {"1,2": true}
	if not _expect(run.add_unit_at("dengai", 1, 2), "Deng Ai must be the only hero allowed to occupy an obstacle"):
		return false
	var unit: Dictionary = run.units()[0]
	var mods: Dictionary = run.team.unit_mods(run, unit)
	if not _expect(is_equal_approx(float(mods.dmgMul), 1.65 * 1.4), "Deng Ai on an obstacle must gain the browser x1.4 high-ground damage"):
		return false
	var card_run = BattleRun.new(catalog, Mulberry32.new(7192))
	card_run.start(_base_city(""), "caocao", "zhangfei")
	card_run.clear_formation()
	card_run.obstacles = {"0,4": true}
	if not _expect(card_run.add_unit("dengai"), "a Deng Ai unit card must be placeable when only an obstacle is available"):
		return false
	var placed: Dictionary = card_run.units()[0]
	return _expect(int(placed.row) == 0 and int(placed.col) == 4, "a Deng Ai unit card must prioritize an empty obstacle like the browser")

func _test_erqiao_ripple_radius(catalog) -> bool:
	var run = BattleRun.new(catalog, Mulberry32.new(7192))
	run.start(_base_city("tuanjie"), "caocao", "daqiao")
	run.clear_formation()
	run.obstacles.clear()
	run.add_unit_at("daqiao", 1, 1)
	run.add_unit_at("xiaoqiao", 1, 2)
	var daqiao: Dictionary = _find_unit(run.units(), "daqiao")
	return _expect(is_equal_approx(run.team.ripple_max(run, daqiao), 308.0), "Erqiao plus tuanjie must expand Da Qiao's slow ripple from 230 to 308")

func _base_city(theme: String) -> Dictionary:
	return {"ch": 1, "wall": 20, "theme": theme, "field": "", "hpMul": 1.0, "spdMul": 1.0, "hpGrow": 1.1, "affixAdd": 0.0, "killTarget": 450, "obstacles": 0, "foes": {"tri": ""}}

func _dictionary_equal_approx(actual: Dictionary, expected: Dictionary) -> bool:
	if actual.size() != expected.size():
		return false
	for key in expected:
		if not actual.has(key) or not is_equal_approx(float(actual[key]), float(expected[key])):
			return false
	return true

func _integer_dictionary_equal(actual: Dictionary, expected: Dictionary) -> bool:
	if actual.size() != expected.size():
		return false
	for key in expected:
		if not actual.has(key) or int(actual[key]) != int(expected[key]):
			return false
	return true

func _find_unit(units: Array, hero_id: String) -> Dictionary:
	for unit in units:
		if str(unit.hero.id) == hero_id:
			return unit
	return {}

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not _expect(file != null, "fixture must open"):
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not _expect(parsed is Dictionary, "fixture must be a JSON object"):
		return {}
	return parsed

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
