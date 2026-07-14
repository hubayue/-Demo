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
		for expected_unit in case_data.units:
			var actual_fx: Dictionary = run.team.bond_fx(run, str(expected_unit.id))
			if not _expect(_dictionary_equal_approx(actual_fx, expected_unit.bondFx), "%s %s bond effects must match browser runtime" % [case_data.id, expected_unit.id]):
				return
	print("Godot v7.19.2 battle team state: PASS")
	quit(0)

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
