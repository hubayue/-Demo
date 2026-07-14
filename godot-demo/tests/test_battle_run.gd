extends SceneTree

const ContentCatalog = preload("res://src/content/content_catalog.gd")
const Mulberry32 = preload("res://src/core/mulberry32.gd")
const BattleRun = preload("res://src/battle/battle_run.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture := _load_json("res://tests/fixtures/v7.19.2-battle-seed-20260715.json")
	if fixture.is_empty():
		return
	var catalog = ContentCatalog.new()
	if not _expect(catalog.load_from("res://data/content-v7.19.2.json") == OK, "content must load"):
		return
	var seed := int(fixture.seed)
	var run = BattleRun.new(catalog, Mulberry32.new(seed))
	run.start(fixture.city, "caocao", "guanyu")
	if not _expect(run.speed == 2, "battle speed must be fixed at 2x"):
		return
	if not _expect(run.wave == 0 and is_equal_approx(run.wave_timer, 2.0), "run must open with a two-second rest before wave one"):
		return
	if not _expect(run.wall == fixture.city.wall and run.wall_max == fixture.city.wall, "city wall must seed battle durability"):
		return
	if not _expect(run.level == 1 and is_zero_approx(run.xp) and is_equal_approx(run.xp_need, 10.0), "run XP must start at Web values"):
		return
	if not _expect(run.units().size() == 1 and run.units()[0].hero.id == "guanyu", "chosen opening hero must enter the formation"):
		return
	if not _expect(_sorted_keys(run.obstacles) == fixture.layout.obstacles, "seeded obstacle layout must match browser runtime"):
		return
	if not _expect(run.traits == fixture.layout.traits, "all fifteen seeded cell traits must match browser runtime"):
		return
	for row in BattleRun.GRID_ROWS:
		var free_cells := 0
		for col in BattleRun.GRID_COLS:
			if not run.obstacles.has("%d,%d" % [row, col]):
				free_cells += 1
		if not _expect(free_cells >= 2, "each formation row must retain at least two legal cells"):
			return
	var opening: Dictionary = run.units()[0]
	if not _expect(not run.obstacles.has("%d,%d" % [opening.row, opening.col]), "opening hero must occupy a legal cell"):
		return

	# The browser fixture resets Math.random immediately before buildWave(1).
	run.rng = Mulberry32.new(seed)
	run.prepare_next_wave()
	if not _expect(run.next_queue.size() == 13, "wave one must contain thirteen enemies"):
		return
	for index in fixture.wave1.size():
		if not _expect_enemy(run.next_queue[index], fixture.wave1[index], index):
			return
	if not _expect(run.next_wave_preview.themeElems == fixture.waveMeta.themeElems and run.next_wave_preview.weakElem == fixture.waveMeta.weakElem, "wave triangle preview must match browser runtime"):
		return
	print("Godot v7.19.2 battle run: PASS")
	quit(0)

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not _expect(file != null, "fixture must open"):
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not _expect(parsed is Dictionary, "fixture must contain a JSON object"):
		return {}
	return parsed

func _sorted_keys(values: Dictionary) -> Array:
	var keys := values.keys()
	keys.sort()
	return keys

func _expect_enemy(actual: Dictionary, expected: Dictionary, index: int) -> bool:
	for key in ["hp", "r", "cls", "big", "affix", "special", "tri", "dmg"]:
		if not _expect(actual.get(key) == expected.get(key), "wave enemy %d field %s must match Web" % [index, key]):
			return false
	for key in ["delay", "speed", "xp"]:
		if not _expect(is_equal_approx(float(actual.get(key)), float(expected.get(key))), "wave enemy %d field %s must match Web" % [index, key]):
			return false
	return true

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
