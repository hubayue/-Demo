extends SceneTree

const ContentCatalog = preload("res://src/content/content_catalog.gd")
const ShenRotation = preload("res://src/progression/shen_rotation.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _expect(ShenRotation.period_for_local_days(20649) == 5900 and ShenRotation.period_for_local_days(20650) == 5901, "Shen rotation must turn over at local Thursday midnight"):
		return
	var catalog = ContentCatalog.new()
	if not _expect(catalog.load_from("res://data/content-v7.19.2.json") == OK, "content must load"):
		return
	var hero_ids: Array = catalog.list("heroes").map(func(hero): return str(hero.id))
	var expected := ["zhoutai", "taishici", "yanliang", "machao", "huanggai", "xuhuang"]
	var actual := ShenRotation.ids_for_period(5900, hero_ids)
	if not _expect(actual == expected, "period 5900 Shen roster must match the frozen Web runtime fixture"):
		return
	var previous := ShenRotation.ids_for_period(5899, hero_ids)
	if not _expect(actual.all(func(hero_id): return not previous.has(hero_id)), "consecutive Shen rosters must not repeat heroes"):
		return
	print("Godot v7.19.14 Shen rotation: PASS")
	quit(0)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
