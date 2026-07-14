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
	run.lord_atk_buff = 2.0
	if not _expect(_find_title(cards.build_pool(run), "御驾亲征") == null, "Yujia Qinzhen must leave the pool after reaching its Web +200% cap"):
		return
	run.lord_atk_buff = 0.0
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
	if not _test_gewu_autoplay(catalog, fixture.city):
		return
	if not _test_relic_drops(catalog, fixture.city):
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

func _test_gewu_autoplay(catalog, city: Dictionary) -> bool:
	var run = BattleRun.new(catalog, Mulberry32.new(7192))
	run.start(city, "caocao", "zhangfei")
	run.permanent_tactics.gewu = true
	run.awaiting_card_choice = true
	run.card_choices = [{"kind": "merit", "title": "挂机拍板", "value": 1}]
	run.advance_real(1.49)
	if not _expect(run.awaiting_card_choice, "Gewu autoplay must preserve the Web 1.5-second roulette pause"):
		return false
	run.advance_real(0.02)
	return _expect(not run.awaiting_card_choice and int(run.card_picks.get("挂机拍板", 0)) == 1, "Gewu must automatically choose a safe growth card after 1.5 seconds")

func _test_relic_drops(catalog, city: Dictionary) -> bool:
	var run = BattleRun.new(catalog, Mulberry32.new(7192))
	run.start(city, "caocao", "huangzhong")
	var wave_five: Array = run.build_wave(5)
	if not _expect(wave_five.any(func(spec): return bool(spec.get("boss", false))), "every fifth Web wave must contain a boss that can drop a relic"):
		return false
	var boss_spec: Dictionary = wave_five.filter(func(spec): return bool(spec.get("boss", false)))[0]
	if not _expect(str(boss_spec.bossName) == "程远志", "wave five must use the first Web fallback boss name"):
		return false
	var elite_city := city.duplicate(true)
	elite_city.bossName = "张角"
	elite_city.eliteWave = true
	var elite_run = BattleRun.new(catalog, Mulberry32.new(7192))
	elite_run.start(elite_city, "caocao", "huangzhong")
	var elite_bosses: Array = elite_run.build_wave(5).filter(func(spec): return bool(spec.get("boss", false)))
	if not _expect(elite_bosses.size() == 2 and int(elite_bosses[0].r) == 46 and int(elite_bosses[0].dmg) == 10 and elite_bosses[0].affix == "shield", "Zhang Jiao elite cities must spawn the Web mega boss plus shadow boss"):
		return false
	if not _expect(str(elite_bosses[1].bossName).ends_with("·影") and int(elite_bosses[1].hp) == roundi(float(elite_bosses[0].hp) * 0.75), "elite shadow boss must have the Web 75% HP copy"):
		return false
	var cards = BattleCards.new(catalog, Mulberry32.new(7192))
	var initial_pool: Array = cards.build_relic_pool(run)
	if not _expect(not _ids(initial_pool).has("jinlan"), "conditional Jinlan relic must stay out without an active bond"):
		return false
	run.clear_formation()
	run.obstacles.clear()
	run.add_unit_at("huangzhong", 0, 0)
	run.add_unit_at("yanyan", 2, 4)
	var bonded_pool: Array = cards.build_relic_pool(run)
	if not _expect(_ids(bonded_pool).has("jinlan"), "conditional Jinlan relic must enter the pool when a bond is active"):
		return false
	var relic_draw: Array = cards.roll_relics(run)
	if not _expect(relic_draw.size() == 3 and relic_draw.all(func(card): return card.kind == "relic"), "boss relic draft must offer three relic cards"):
		return false
	var chosen_id := str(relic_draw[0].relic_id)
	run.awaiting_card_choice = true
	run.picking_relic = true
	run.card_choices = relic_draw
	if not _expect(cards.apply(run, relic_draw[0]) and run.relic_ids.has(chosen_id), "selecting a relic card must equip it for the current run"):
		return false
	var effect_run = BattleRun.new(catalog, Mulberry32.new(7192))
	effect_run.start(city, "caocao", "guanyu")
	effect_run.obstacles.clear()
	effect_run.traits.clear()
	var cavalry: Dictionary = effect_run.units()[0]
	var base_mods: Dictionary = effect_run.team.unit_mods(effect_run, cavalry)
	effect_run.relic_ids = ["dilu", "bagua", "yiji", "hanshu"]
	var relic_mods: Dictionary = effect_run.team.unit_mods(effect_run, cavalry)
	if not _expect(is_equal_approx(float(relic_mods.dmgMul), float(base_mods.dmgMul) * 1.3) and is_equal_approx(float(relic_mods.rateMul), float(base_mods.rateMul) * 1.1), "Dilu and Bagua must affect real cavalry combat modifiers"):
		return false
	if not _expect(cards.roll(effect_run).size() == 4, "Yiji must expand a growth draft from three to four cards"):
		return false
	effect_run.gain_xp(10.0)
	if not _expect(effect_run.level == 2 and is_equal_approx(effect_run.xp_need, 20.0), "Hanshu must reduce the real next-level XP requirement by 12%"):
		return false
	var lamp_run = BattleRun.new(catalog, Mulberry32.new(7192))
	lamp_run.start(city, "caocao", "zhangfei")
	lamp_run.relic_ids = ["qixing"]
	lamp_run.wave_timer = 1000.0
	lamp_run._update_step(29.0)
	lamp_run.wall -= 1
	lamp_run._update_step(1.0)
	if not _expect(lamp_run.wall == lamp_run.wall_max - 1, "Qixing timer must not advance while the wall is already full"):
		return false
	lamp_run._update_step(29.0)
	if not _expect(lamp_run.wall == lamp_run.wall_max, "Qixing must heal only after thirty damaged-wall seconds"):
		return false

	var queued = BattleRun.new(catalog, Mulberry32.new(7192))
	queued.start(city, "caocao", "zhangfei")
	queued.gain_xp(10.0)
	var boss := {"hp": 1.0, "hp_max": 1.0, "dead": false, "boss": true, "tri": "", "xp": 0.0}
	queued.enemies = [boss]
	queued.damage_enemy(boss, 1.0)
	if not _expect(queued.pending_relic_picks == 1 and not queued.picking_relic, "a boss relic must queue behind an active growth draft"):
		return false
	queued.choose_card(0)
	if not _expect(queued.picking_relic and queued.card_choices.size() == 3 and queued.card_choices.all(func(card): return card.kind == "relic"), "queued relic draft must open immediately after the growth choice"):
		return false
	var final_city := city.duplicate(true)
	final_city.killTarget = 1
	var final_run = BattleRun.new(catalog, Mulberry32.new(7192))
	final_run.start(final_city, "caocao", "zhangfei")
	var final_boss := {"hp": 1.0, "hp_max": 1.0, "dead": false, "boss": true, "tri": "", "xp": 0.0}
	final_run.enemies = [final_boss]
	final_run.damage_enemy(final_boss, 1.0)
	return _expect(final_run.status == "win" and not final_run.awaiting_card_choice, "a final victory boss must not cover the result with a relic draft")

func _ids(cards: Array) -> Array:
	return cards.map(func(card): return str(card.get("id", card.get("relic_id", ""))))

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
