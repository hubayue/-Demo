extends SceneTree

const ContentCatalog = preload("res://src/content/content_catalog.gd")
const Mulberry32 = preload("res://src/core/mulberry32.gd")
const BattleRun = preload("res://src/battle/battle_run.gd")
const BattleCards = preload("res://src/battle/battle_cards.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture := _load_json("res://tests/fixtures/v7.19.2-battle-seed-20260715.json")
	if fixture.is_empty():
		return
	var catalog = ContentCatalog.new()
	if not _expect(catalog.load_from("res://data/content-v7.19.2.json") == OK, "content must load"):
		return
	var run = BattleRun.new(catalog, Mulberry32.new(77))
	run.start(fixture.city, "caocao", "zhangfei")
	run.shen_period = int(fixture.growthDraft.shenPeriod)
	run.shen_ids = fixture.growthDraft.shenIds.duplicate()
	var cards = BattleCards.new(catalog, Mulberry32.new(int(fixture.seed)))
	var pool: Array = cards.build_pool(run)
	for title in ["张飞练兵", "全军猛攻", "击鼓进军", "青囊秘术", "招贤纳士", "神机妙算", "战阵精修", "开山凿石", "霸道淬炼", "御驾亲征", "擒贼擒王", "校场演武", "自刎归天", "乐不思蜀"]:
		if not _expect(_find_title(pool, title) != null, "initial card pool must contain %s" % title):
			return
	var draw: Array = cards.roll(run)
	if not _expect(draw.size() == 3 and _unique_titles(draw) == 3, "growth draft must contain three unique card titles"):
		return
	for index in fixture.growthDraft.cards.size():
		var expected: Dictionary = fixture.growthDraft.cards[index]
		var actual: Dictionary = draw[index]
		if not _expect(actual.kind == expected.kind and actual.title == expected.title and is_equal_approx(float(actual.weight), float(expected.weight)), "seeded growth card %d must match browser runtime" % index):
			return
		if expected.get("hero") != null and not _expect(str(actual.get("hero_id", "")) == str(expected.hero), "seeded growth hero %d must match browser runtime" % index):
			return

	if not _test_applications(catalog, fixture.city):
		return
	print("Godot v7.19.2 battle cards: PASS")
	quit(0)

func _test_applications(catalog, city: Dictionary) -> bool:
	var run = BattleRun.new(catalog, Mulberry32.new(991))
	run.start(city, "caocao", "zhangfei")
	var cards = BattleCards.new(catalog, Mulberry32.new(123))
	var pool: Array = cards.build_pool(run)
	var obstacle_count: int = run.obstacles.size()
	cards.apply(run, _find_title(pool, "全军猛攻"))
	if not _expect(is_equal_approx(float(run.buffs.dmg), 1.25), "common damage card must mutate the run buff"):
		return false
	pool = cards.build_pool(run)
	cards.apply(run, _find_title(pool, "霸道淬炼"))
	if not _expect(is_equal_approx(float(run.buffs.elemBoost.badao), 0.3), "element refinement must mutate the owned element buff"):
		return false
	pool = cards.build_pool(run)
	cards.apply(run, _find_title(pool, "开山凿石"))
	if not _expect(run.obstacles.size() == obstacle_count - 1, "terrain card must clear one obstacle"):
		return false
	pool = cards.build_pool(run)
	cards.apply(run, _find_title(pool, "张飞练兵"))
	var zhangfei: Dictionary = run.units().filter(func(unit): return unit.hero.id == "zhangfei")[0]
	if not _expect(zhangfei.level == 2 and zhangfei.hp == zhangfei.hp_max, "upgrade card must raise the lowest-star copy and fully heal it"):
		return false
	pool = cards.build_pool(run)
	var unit_card: Dictionary = {}
	for card in pool:
		if card.kind == "unit":
			unit_card = card
			break
	if not _expect(not unit_card.is_empty(), "pool must retain an unowned hero card"):
		return false
	cards.apply(run, unit_card)
	if not _expect(run.units().size() == 2, "unit card must place a new hero on a legal empty cell"):
		return false
	return true

func _find_title(cards: Array, title: String):
	for card in cards:
		if str(card.title) == title:
			return card
	return null

func _unique_titles(cards: Array) -> int:
	var titles := {}
	for card in cards:
		titles[card.title] = true
	return titles.size()

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
