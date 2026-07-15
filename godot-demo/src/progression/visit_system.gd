class_name VisitSystem
extends RefCounted

const Mulberry32 = preload("res://src/core/mulberry32.gd")
const HeroProgression = preload("res://src/progression/hero_progression.gd")
const LocalProfile = preload("res://src/progression/local_profile.gd")

const CELL_BAG := [
	"gold", "gold", "gold", "gift", "gift",
	"hxp", "hxp", "hxp", "hxp",
	"lxp", "lxp", "lxp", "lxp",
	"luck", "luck", "luck", "luck",
	"tupo", "tupo", "kuang",
]
const BUFF_IDS := ["score", "gold", "again"]
const BUFF_DURATION_MS := 30 * 60 * 1000

static func board(week: int) -> Array:
	var rng = Mulberry32.new(week * 771 + 21)
	var result: Array = CELL_BAG.duplicate()
	for index in range(result.size() - 1, 0, -1):
		var other := int(rng.next_float() * (index + 1))
		var swap = result[index]
		result[index] = result[other]
		result[other] = swap
	return result

static func roll(profile: Dictionary, catalog, week: int, rng, now_ms: int, free := false) -> Dictionary:
	if not free:
		if int(profile.get("items", {}).get("visitToken", 0)) < 1:
			return {"error": "no_token", "lines": ["令牌不够——通关战斗可以获得"]}
		profile.items.visitToken = int(profile.items.visitToken) - 1
	var dice := _range(rng, 1, 6)
	profile.visit_pos = posmod(int(profile.get("visit_pos", 0)) + dice, 20)
	var cell := str(board(week)[int(profile.visit_pos)])
	var reward: Dictionary = resolve(profile, catalog, cell, rng, now_ms)
	var result := {"dice": dice, "cell": cell, "position": int(profile.visit_pos), "lines": reward.get("lines", [])}
	result.free_again = rng.next_float() < (0.2 if buff_active(profile, "again", now_ms) else 0.05)
	return result

static func resolve(profile: Dictionary, catalog, cell: String, rng, now_ms: int) -> Dictionary:
	var lines: Array = []
	match cell:
		"gold": _give_gold(profile, rng, 1.0, lines)
		"hxp": _give_hero_xp(profile, catalog, rng, 1.0, lines)
		"lxp": _give_lord_xp(profile, catalog, rng, 1.0, lines)
		"tupo":
			profile.items.tupo = int(profile.items.get("tupo", 0)) + 1
			lines.append("突破石 +1")
		"kuang":
			profile.items.tupo = int(profile.items.get("tupo", 0)) + 3
			lines.append("挖到石矿：突破石 +3")
		"gift":
			_give_gold(profile, rng, 3.0, lines)
			_give_hero_xp(profile, catalog, rng, 1.5, lines)
			_give_lord_xp(profile, catalog, rng, 1.5, lines)
			var gift_roll := _range(rng, 1, 100)
			if gift_roll <= 20:
				profile.items.tupo = int(profile.items.get("tupo", 0)) + 3
				lines.append("大块突破石 +3")
			elif gift_roll <= 70:
				profile.items.tupo = int(profile.items.get("tupo", 0)) + 1
				lines.append("突破石 +1")
			else:
				profile.items.visitToken = int(profile.items.get("visitToken", 0)) + 1
				lines.append("寻访令牌 +1")
		"luck":
			var buff_id: String = str(BUFF_IDS[_range(rng, 0, BUFF_IDS.size() - 1)])
			var current := int(profile.get("visit_buffs", {}).get(buff_id, 0))
			profile.visit_buffs[buff_id] = maxi(now_ms, current) + BUFF_DURATION_MS
			lines.append("黄历奇遇：%s生效30分钟" % buff_id)
	return {"lines": lines}

static func buff_active(profile: Dictionary, buff_id: String, now_ms: int) -> bool:
	return int(profile.get("visit_buffs", {}).get(buff_id, 0)) > now_ms

static func _give_gold(profile: Dictionary, rng, multiplier: float, lines: Array) -> void:
	var amount := roundi(_range(rng, 150, 400) * multiplier)
	profile.gold = int(profile.get("gold", 0)) + amount
	profile.gold_total = int(profile.get("gold_total", 0)) + amount
	lines.append("金币 +%d" % amount)

static func _give_hero_xp(profile: Dictionary, catalog, rng, multiplier: float, lines: Array) -> void:
	var candidates: Array = []
	for hero in catalog.list("heroes"):
		var entry: Dictionary = profile.heroes.get(str(hero.id), {})
		if int(entry.get("lv", 1)) < 60: candidates.append(str(hero.id))
	if candidates.is_empty():
		_give_gold(profile, rng, 1.0, lines)
		return
	var hero_id := str(candidates[_range(rng, 0, candidates.size() - 1)])
	var amount := roundi(_range(rng, 250, 600) * multiplier)
	var result: Dictionary = HeroProgression.add_xp(profile, hero_id, amount, catalog.content.get("hero_tiers", {}), catalog.content.get("rarities", {}))
	var hero: Dictionary = catalog.by_id("heroes", hero_id)
	lines.append("%s 经验 +%d（Lv.%d→%d）" % [str(hero.name), amount, int(result.from), int(result.to)])

static func _give_lord_xp(profile: Dictionary, catalog, rng, multiplier: float, lines: Array) -> void:
	var candidates: Array = []
	for ruler_id in LocalProfile.RULER_IDS:
		if LocalProfile.ruler_level(profile, ruler_id) < LocalProfile.LORD_LEVEL_MAX: candidates.append(ruler_id)
	if candidates.is_empty():
		_give_gold(profile, rng, 1.0, lines)
		return
	var ruler_id := str(candidates[_range(rng, 0, candidates.size() - 1)])
	var amount := roundi(_range(rng, 6, 14) * multiplier)
	var result: Dictionary = LocalProfile.add_ruler_xp(profile, ruler_id, amount)
	var ruler: Dictionary = catalog.by_id("rulers", ruler_id)
	lines.append("%s 主公经验 +%d（Lv.%d→%d）" % [str(ruler.name), amount, int(result.from), int(result.to)])

static func _range(rng, minimum: int, maximum: int) -> int:
	return minimum + int(floor(rng.next_float() * (maximum - minimum + 1)))
