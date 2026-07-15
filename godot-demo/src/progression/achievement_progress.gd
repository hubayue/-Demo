class_name AchievementProgress
extends RefCounted

const BattleRecords = preload("res://src/progression/battle_records.gd")

static func progress(profile: Dictionary, achievement_id: String) -> Dictionary:
	var current := 0
	var need := 0
	match achievement_id:
		"win": current = int(profile.get("wins", 0)); need = 1
		"wins10": current = int(profile.get("wins", 0)); need = 10
		"wins30": current = int(profile.get("wins", 0)); need = 30
		"wins100": current = int(profile.get("wins", 0)); need = 100
		"kills1k": current = int(profile.get("total_kills", 0)); need = 1000
		"kills5000": current = int(profile.get("total_kills", 0)); need = 5000
		"kills20k": current = int(profile.get("total_kills", 0)); need = 20000
		"kills60k": current = int(profile.get("total_kills", 0)); need = 60000
		"boss10": current = int(profile.get("boss_kills", 0)); need = 10
		"boss50": current = int(profile.get("boss_kills", 0)); need = 50
		"weekclear1": current = profile.get("week_clears", {}).size(); need = 1
		"weekclear8": current = profile.get("week_clears", {}).size(); need = 8
		"weekclear16": current = profile.get("week_clears", {}).size(); need = 16
		"weekclear32": current = profile.get("week_clears", {}).size(); need = 32
		"weekclear48": current = profile.get("week_clears", {}).size(); need = 48
		"weekclear64": current = profile.get("week_clears", {}).size(); need = 64
		"perfect10": current = int(profile.get("perfect_wins", 0)); need = 10
		"star3first": current = int(profile.get("perfect_wins", 0)); need = 1
		"wscore5k": current = BattleRecords.week_score(profile.get("week_best", {})); need = 4000
		"wscore20k": current = BattleRecords.week_score(profile.get("week_best", {})); need = 12000
		"wscore45k": current = BattleRecords.week_score(profile.get("week_best", {})); need = 25000
		"wave20": current = int(profile.get("endless_best", 0)); need = 20
		"wave35": current = int(profile.get("endless_best", 0)); need = 35
		"hero5": current = _hero_max(profile); need = 5
		"hero10": current = _hero_max(profile); need = 10
		"hero20": current = _hero_max(profile); need = 20
		"hero30": current = _hero_max(profile); need = 30
		"gold10k": current = int(profile.get("gold_total", 0)); need = 10000
		"gold50k": current = int(profile.get("gold_total", 0)); need = 50000
		"gold200k": current = int(profile.get("gold_total", 0)); need = 200000
		"tech5": current = _lord_total(profile); need = 12
		"tech20": current = _lord_total(profile); need = 40
		"tech60": current = _lord_total(profile); need = 100
		"rebirth1": current = int(profile.get("rebirth_total", 0)); need = 1
		_:
			return {"supported": false, "current": 0, "need": 0, "complete": profile.get("achievements", []).has(achievement_id)}
	return {"supported": true, "current": current, "need": need, "complete": current >= need}

static func sweep(profile: Dictionary, definitions: Array) -> Array:
	if not profile.get("achievements", []) is Array: profile.achievements = []
	var unlocked: Array = []
	for definition in definitions:
		var achievement_id := str(definition.id)
		if profile.achievements.has(achievement_id): continue
		var state: Dictionary = progress(profile, achievement_id)
		if bool(state.supported) and bool(state.complete):
			profile.achievements.append(achievement_id)
			unlocked.append(achievement_id)
	return unlocked

static func claim(profile: Dictionary, achievement_id: String, definitions: Array) -> Dictionary:
	if not profile.get("achievements", []).has(achievement_id) or profile.get("ach_claimed", []).has(achievement_id): return {}
	for definition in definitions:
		if str(definition.id) != achievement_id: continue
		var gold := int(definition.get("gold", 0))
		profile.gold = int(profile.get("gold", 0)) + gold
		profile.gold_total = int(profile.get("gold_total", 0)) + gold
		profile.ach_claimed.append(achievement_id)
		return {"id": achievement_id, "gold": gold}
	return {}

static func claimable_count(profile: Dictionary) -> int:
	var count := 0
	for achievement_id in profile.get("achievements", []):
		if not profile.get("ach_claimed", []).has(achievement_id): count += 1
	return count

static func _hero_max(profile: Dictionary) -> int:
	var maximum := 1
	for entry in profile.get("heroes", {}).values(): maximum = maxi(maximum, int(entry.get("lv", 1)))
	return maximum

static func _lord_total(profile: Dictionary) -> int:
	var total := 0
	for entry in profile.get("rulers", {}).values(): total += int(entry.get("lv", 1))
	return total
