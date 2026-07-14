extends SceneTree

const ContentCatalog = preload("res://src/content/content_catalog.gd")
const OpeningPicker = preload("res://src/progression/opening_picker.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var picker = OpeningPicker.new(RandomNumberGenerator.new())
	var sample_heroes := [
		{"id": "caoren", "cls": "shield", "elem": "badao"},
		{"id": "counter", "cls": "cav", "elem": "rende"},
		{"id": "huatuo", "cls": "support", "elem": "rende"},
		{"id": "neutral", "cls": "spear", "elem": "badao"},
		{"id": "bad", "cls": "archer", "elem": "liangmou"},
	]
	var sample_ids: Array = picker.pick_ids_with_scores(
		sample_heroes,
		"caocao",
		"badao",
		{"caocao": ["caoren"]},
		[0.5, 0.5, 0.5, 0.5, 0.5],
	)
	if not _expect(sample_ids == ["caoren", "counter", "neutral"], "bias and one-non-DPS cap must match Web ordering"):
		return
	var cosmetic_ids: Array = picker.pick_ids_with_scores(
		[
			{"id": "huatuo", "cls": "cav", "elem": "rende"},
			{"id": "ordinary_counter", "cls": "spear", "elem": "rende"},
			{"id": "neutral_dps", "cls": "archer", "elem": "badao"},
		],
		"yuanshu",
		"badao",
		{},
		[0.5, 0.5, 0.5],
	)
	if not _expect(cosmetic_ids == ["ordinary_counter", "huatuo", "neutral_dps"], "cosmetic heroes must not receive triangle bias"):
		return
	var stable_ids: Array = picker.pick_ids_with_scores(
		[
			{"id": "first", "cls": "cav", "elem": "badao"},
			{"id": "second", "cls": "spear", "elem": "badao"},
			{"id": "third", "cls": "archer", "elem": "badao"},
		],
		"yuanshu",
		"",
		{},
		[0.5, 0.5, 0.5],
	)
	if not _expect(stable_ids == ["first", "second", "third"], "equal scores must preserve catalog order"):
		return
	if not _expect(OpeningPicker.is_kin("jiaxu", "yuanshu", {}) and not OpeningPicker.is_kin("counter", "yuanshu", {}), "Jia Xu must be universal ruler kin"):
		return

	var catalog = ContentCatalog.new()
	if not _expect(catalog.load_from("res://data/content-v7.19.2.json") == OK, "content must load"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260715
	picker = OpeningPicker.new(rng)
	var heroes: Array = catalog.list("heroes")
	var choices: Array = picker.pick_ids(heroes, "caocao", "badao", catalog.content.lord_kin)
	if not _expect(heroes.size() == 45 and choices.size() == 3, "picker must draw three choices from all 45 heroes"):
		return
	if not _expect(choices.duplicate().size() == 3 and _unique_count(choices) == 3, "opening choices must be unique"):
		return
	var non_dps := 0
	for hero_id in choices:
		var hero: Dictionary = catalog.by_id("heroes", hero_id)
		if hero.cls == "shield" or hero.cls == "support":
			non_dps += 1
	if not _expect(non_dps <= 1, "opening choices must contain at least two damage classes"):
		return
	print("Godot v7.19.2 opening picker: PASS")
	quit(0)

func _unique_count(values: Array) -> int:
	var unique := {}
	for value in values:
		unique[value] = true
	return unique.size()

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
