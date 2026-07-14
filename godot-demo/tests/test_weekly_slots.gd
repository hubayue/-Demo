extends SceneTree

const ContentCatalog = preload("res://src/content/content_catalog.gd")
const WeeklyMap = preload("res://src/progression/weekly_map.gd")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var catalog = ContentCatalog.new()
    if not _expect(catalog.load_from("res://data/content-v7.19.2.json") == OK, "content must load"):
        return
    var fixture_file := FileAccess.open("res://tests/fixtures/v7.19.2-week-2948-slots.json", FileAccess.READ)
    if not _expect(fixture_file != null, "weekly fixture must load"):
        return
    var fixture = JSON.parse_string(fixture_file.get_as_text())
    var weekly = WeeklyMap.new(catalog)
    var slots: Array = weekly.make_slots(int(fixture.week))
    if not _expect(slots.size() == 64, "weekly map must contain 64 slots"):
        return
    for expected_slot in fixture.slots:
        var expected: Dictionary = expected_slot
        var actual: Dictionary = slots[int(expected.k)]
        if not _expect(actual.ch == expected.ch, "chapter mismatch at k=%d" % expected.k):
            return
        if not _expect(actual.tri == expected.tri, "triangle mismatch at k=%d" % expected.k):
            return
        if not _expect(actual.field == expected.field, "field mismatch at k=%d: %s != %s" % [expected.k, actual.field, expected.field]):
            return
        if not _expect(actual.rules == expected.rules, "rules mismatch at k=%d" % expected.k):
            return
    var themes := []
    for region in 4:
        themes.append(weekly.theme_of(int(fixture.week), region).id)
    if not _expect(themes == fixture.themes, "four region themes must match Web runtime"):
        return
    print("Godot v7.19.2 weekly slots: PASS")
    quit(0)

func _expect(condition: bool, message: String) -> bool:
    if condition:
        return true
    push_error(message)
    quit(1)
    return false
