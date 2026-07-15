class_name LocalProfile
extends RefCounted

const PROFILE_VERSION := 1
const RULER_IDS := ["caocao", "liubei", "sunquan", "yuanshao", "liubiao", "gongsunzan", "dongzhuo", "yuanshu"]
const LORD_LEVEL_MAX := 20
const WEEK_BAND_COUNT := 6

static func defaults(week: int) -> Dictionary:
	var rulers := {}
	for ruler_id in RULER_IDS:
		rulers[ruler_id] = {"lv": 1, "xp": 0}
	return {
		"version": PROFILE_VERSION,
		"week": week,
		"gold": 0,
		"wins": 0,
		"endless_best": 0,
		"week_clears": {},
		"week_stars": {},
		"week_best": {},
		"week_tech": {},
		"week_bands": 0,
		"rulers": rulers,
		"heroes": {},
	}

static func load_from(path: String, week: int) -> Dictionary:
	if not FileAccess.file_exists(path): return defaults(week)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return defaults(week)
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK: return defaults(week)
	var parsed = parser.data
	if not parsed is Dictionary: return defaults(week)
	return sanitize(parsed, week)

static func save_to(path: String, profile: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(profile, "  "))
	file.close()
	return OK

static func sanitize(source: Dictionary, week: int) -> Dictionary:
	var result := defaults(week)
	result.gold = maxi(0, int(source.get("gold", 0)))
	result.wins = maxi(0, int(source.get("wins", 0)))
	result.endless_best = maxi(0, int(source.get("endless_best", 0)))
	var rulers: Dictionary = source.get("rulers", {}) if source.get("rulers", {}) is Dictionary else {}
	for ruler_id in RULER_IDS:
		var ruler: Dictionary = rulers.get(ruler_id, {}) if rulers.get(ruler_id, {}) is Dictionary else {}
		result.rulers[ruler_id] = {"lv": clampi(int(ruler.get("lv", 1)), 1, LORD_LEVEL_MAX), "xp": maxi(0, int(ruler.get("xp", 0)))}
	var heroes: Dictionary = source.get("heroes", {}) if source.get("heroes", {}) is Dictionary else {}
	for hero_id in heroes:
		if heroes[hero_id] is Dictionary:
			result.heroes[str(hero_id)] = {"lv": maxi(1, int(heroes[hero_id].get("lv", 1))), "rb": clampi(int(heroes[hero_id].get("rb", 0)), 0, 3)}
	if int(source.get("week", week)) == week:
		for field in ["week_clears", "week_stars", "week_best", "week_tech"]:
			if source.get(field, {}) is Dictionary: result[field] = source[field].duplicate(true)
		result.week_bands = clampi(int(source.get("week_bands", 0)), 0, WEEK_BAND_COUNT)
	return result

static func ruler_level(profile: Dictionary, ruler_id: String) -> int:
	return int(profile.get("rulers", {}).get(ruler_id, {}).get("lv", 1))

static func hero_levels(profile: Dictionary) -> Dictionary:
	var result := {}
	for hero_id in profile.get("heroes", {}):
		result[str(hero_id)] = int(profile.heroes[hero_id].get("lv", 1))
	return result

static func lord_xp_need(level: int) -> int:
	return 30 + 15 * level

static func add_ruler_xp(profile: Dictionary, ruler_id: String, amount: int) -> Dictionary:
	if not profile.rulers.has(ruler_id): profile.rulers[ruler_id] = {"lv": 1, "xp": 0}
	var ruler: Dictionary = profile.rulers[ruler_id]
	var before := int(ruler.lv)
	ruler.xp = int(ruler.xp) + maxi(0, amount)
	while int(ruler.lv) < LORD_LEVEL_MAX and int(ruler.xp) >= lord_xp_need(int(ruler.lv)):
		ruler.xp = int(ruler.xp) - lord_xp_need(int(ruler.lv))
		ruler.lv = int(ruler.lv) + 1
	if int(ruler.lv) >= LORD_LEVEL_MAX:
		ruler.xp = mini(int(ruler.xp), lord_xp_need(LORD_LEVEL_MAX))
	return {"from": before, "to": int(ruler.lv), "xp": int(ruler.xp), "gain": maxi(0, amount)}
