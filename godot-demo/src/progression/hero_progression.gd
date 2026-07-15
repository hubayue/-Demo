class_name HeroProgression
extends RefCounted

const HERO_LEVEL_MAX := 30
const HERO_REBIRTH_MAX := 3
const REBIRTH_STONES := [5, 8, 12]

static func ensure_roster(profile: Dictionary, heroes: Array) -> void:
	if not profile.get("heroes", {}) is Dictionary: profile.heroes = {}
	for hero in heroes:
		var hero_id := str(hero.id)
		if not profile.heroes.has(hero_id): profile.heroes[hero_id] = {"lv": 1, "rb": 0, "xp": 0}
		else:
			var entry: Dictionary = profile.heroes[hero_id]
			entry.lv = clampi(int(entry.get("lv", 1)), 1, HERO_LEVEL_MAX + HERO_REBIRTH_MAX * 10)
			entry.rb = clampi(int(entry.get("rb", 0)), 0, HERO_REBIRTH_MAX)
			entry.xp = maxi(0, int(entry.get("xp", 0)))
			entry.lv = mini(int(entry.lv), level_cap(entry))

static func rarity(hero_id: String, hero_tiers: Dictionary) -> String:
	return str(hero_tiers.get(hero_id, "common"))

static func upgrade_cost(next_level: int, hero_id: String, hero_tiers: Dictionary, rarities: Dictionary) -> int:
	var base := 100.0 * pow(1.22, next_level - 1) if next_level <= HERO_LEVEL_MAX else 100.0 * pow(1.22, HERO_LEVEL_MAX - 1) * pow(1.13, next_level - HERO_LEVEL_MAX)
	var rarity_data: Dictionary = rarities.get(rarity(hero_id, hero_tiers), {})
	return roundi(base * float(rarity_data.get("costMul", 1.0)) / 10.0) * 10

static func gate_stones(current_level: int) -> int:
	return 1 if current_level == 10 else (2 if current_level == 20 else 0)

static func level_cap(entry: Dictionary) -> int:
	return HERO_LEVEL_MAX + clampi(int(entry.get("rb", 0)), 0, HERO_REBIRTH_MAX) * 10

static func upgrade(profile: Dictionary, hero_id: String, hero_tiers: Dictionary, rarities: Dictionary) -> bool:
	if not profile.get("heroes", {}).has(hero_id): return false
	var entry: Dictionary = profile.heroes[hero_id]
	if int(entry.get("lv", 1)) >= level_cap(entry): return false
	var stones := gate_stones(int(entry.lv))
	if int(profile.get("items", {}).get("tupo", 0)) < stones: return false
	var cost := upgrade_cost(int(entry.lv) + 1, hero_id, hero_tiers, rarities)
	if int(profile.get("gold", 0)) < cost: return false
	profile.gold = int(profile.gold) - cost
	if stones > 0: profile.items.tupo = int(profile.items.get("tupo", 0)) - stones
	entry.lv = int(entry.lv) + 1
	add_xp(profile, hero_id, 0, hero_tiers, rarities)
	return true

static func rebirth(profile: Dictionary, hero_id: String) -> bool:
	if not profile.get("heroes", {}).has(hero_id): return false
	var entry: Dictionary = profile.heroes[hero_id]
	var rebirth_count := int(entry.get("rb", 0))
	if int(entry.get("lv", 1)) < level_cap(entry) or rebirth_count >= HERO_REBIRTH_MAX: return false
	var stones: int = int(REBIRTH_STONES[rebirth_count])
	if int(profile.get("items", {}).get("tupo", 0)) < stones: return false
	profile.items.tupo = int(profile.items.tupo) - stones
	entry.rb = rebirth_count + 1
	profile.rebirth_total = int(profile.get("rebirth_total", 0)) + 1
	return true

static func add_xp(profile: Dictionary, hero_id: String, amount: int, hero_tiers: Dictionary, rarities: Dictionary) -> Dictionary:
	if not profile.get("heroes", {}).has(hero_id): return {}
	var entry: Dictionary = profile.heroes[hero_id]
	var before := int(entry.get("lv", 1))
	var xp_before := int(entry.get("xp", 0))
	entry.xp = xp_before + maxi(0, amount)
	while int(entry.lv) < level_cap(entry) and gate_stones(int(entry.lv)) == 0:
		var need := upgrade_cost(int(entry.lv) + 1, hero_id, hero_tiers, rarities)
		if int(entry.xp) < need: break
		entry.xp = int(entry.xp) - need
		entry.lv = int(entry.lv) + 1
	if int(entry.lv) >= HERO_LEVEL_MAX + HERO_REBIRTH_MAX * 10: entry.xp = 0
	var next_need := 0
	if int(entry.lv) < level_cap(entry) and gate_stones(int(entry.lv)) == 0:
		next_need = upgrade_cost(int(entry.lv) + 1, hero_id, hero_tiers, rarities)
	return {"from": before, "to": int(entry.lv), "xp0": xp_before, "xp": int(entry.xp), "need": next_need}

static func reset_preview(profile: Dictionary, hero_id: String, hero_tiers: Dictionary, rarities: Dictionary) -> Dictionary:
	if not profile.get("heroes", {}).has(hero_id): return {}
	var entry: Dictionary = profile.heroes[hero_id]
	var rebirth_count := int(entry.get("rb", 0))
	if int(entry.get("lv", 1)) <= 1 and rebirth_count == 0: return {}
	var gold := 0
	for level in range(2, int(entry.lv) + 1): gold += upgrade_cost(level, hero_id, hero_tiers, rarities)
	var stones := (1 if int(entry.lv) > 10 else 0) + (2 if int(entry.lv) > 20 else 0)
	for index in rebirth_count: stones += int(REBIRTH_STONES[index])
	return {"gold": gold, "stones": stones}

static func reset(profile: Dictionary, hero_id: String, hero_tiers: Dictionary, rarities: Dictionary) -> Dictionary:
	var preview: Dictionary = reset_preview(profile, hero_id, hero_tiers, rarities)
	if preview.is_empty(): return {}
	profile.gold = int(profile.get("gold", 0)) + int(preview.gold)
	profile.items.tupo = int(profile.get("items", {}).get("tupo", 0)) + int(preview.stones)
	profile.heroes[hero_id] = {"lv": 1, "rb": 0, "xp": 0}
	return preview
