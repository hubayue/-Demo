extends SceneTree

const ContentCatalog = preload("res://src/content/content_catalog.gd")
const WeeklyMap = preload("res://src/progression/weekly_map.gd")
const OPTIONAL_RULE_FIELDS := ["archerRngMul", "cavChargeMul", "rangedMul"]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog = ContentCatalog.new()
	if not _expect(catalog.load_from("res://data/content-v7.19.2.json") == OK, "content must load"):
		return
	var fixture_file := FileAccess.open("res://tests/fixtures/v7.19.2-week-2948-levels.json", FileAccess.READ)
	if not _expect(fixture_file != null, "level fixture must load"):
		return
	var fixture = JSON.parse_string(fixture_file.get_as_text())
	var weekly = WeeklyMap.new(catalog)
	if not _expect(weekly.has_method("make_level"), "WeeklyMap.make_level must exist"):
		return
	for expected_level in fixture.levels:
		var k := int(expected_level.k)
		var actual: Dictionary = weekly.make_level(int(fixture.week), k)
		for field in expected_level:
			if not _expect(actual.get(field) == expected_level.get(field), "%s mismatch at k=%d: %s != %s" % [field, k, actual.get(field), expected_level.get(field)]):
				return
		for field in OPTIONAL_RULE_FIELDS:
			if not _expect(actual.has(field) == expected_level.has(field), "%s presence mismatch at k=%d" % [field, k]):
				return
	print("Godot v7.19.2 weekly levels: PASS")
	quit(0)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
