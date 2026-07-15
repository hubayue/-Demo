class_name RunSettlement
extends RefCounted

const BattleRecords = preload("res://src/progression/battle_records.gd")
const LocalProfile = preload("res://src/progression/local_profile.gd")

static func settle_clear(profile: Dictionary, run, city_index: int, theme_fit: bool) -> Dictionary:
	if run.clear_settled:
		return {}
	run.clear_settled = true
	profile.wins = int(profile.get("wins", 0)) + 1
	var key := str(city_index)
	var first_clear: bool = not profile.week_clears.has(key) and not profile.week_clears.has(city_index)
	profile.week_clears[key] = int(profile.week_clears.get(key, 0)) + 1
	profile.week_stars[key] = maxi(int(profile.week_stars.get(key, 0)), int(run.stars))
	var previous: Dictionary = profile.week_best.get(key, {})
	var best: Dictionary = BattleRecords.finalize_city_best(city_index, previous, int(run.stars), 0)
	profile.week_best[key] = best
	var has_weakness: bool = not str(run.city.get("foes", {}).get("tri", "")).is_empty()
	var counter_fraction := 0.5
	if has_weakness:
		counter_fraction = float(run.counter_damage) / float(run.total_damage) if float(run.total_damage) > 0 else 0.0
	var wall_fraction: float = float(run.wall) / maxf(1.0, float(run.wall_max))
	var strategy: int = BattleRecords.tech_score(city_index, counter_fraction, wall_fraction, theme_fit)
	profile.week_tech[key] = maxi(int(profile.week_tech.get(key, 0)), strategy)
	var first_gold: int = int(run.city.get("firstGold", 0)) if first_clear else 0
	profile.gold = int(profile.get("gold", 0)) + first_gold
	profile.gold_total = int(profile.get("gold_total", 0)) + first_gold
	var banked: int = _commit_gold(profile, run)
	_commit_kills(profile, run)
	var band_gold := _claim_week_bands(profile, run)
	if int(run.stars) >= 3: profile.perfect_wins = int(profile.get("perfect_wins", 0)) + 1
	var visit_tokens := _grant_visit_tokens(profile)
	var lord_gain: int = 6 + city_index + int(run.stars) * 2
	var lord_result: Dictionary = _settle_ruler_xp(profile, run.ruler_id, lord_gain)
	return {
		"first_clear": first_clear,
		"first_clear_gold": first_gold,
		"banked_gold": banked + first_gold + band_gold,
		"band_gold": band_gold,
		"tech_score": strategy,
		"city_score": int(best.score),
		"force_score": BattleRecords.week_score(profile.week_best),
		"lord_xp": lord_result,
		"visit_tokens": visit_tokens,
	}

static func record_suppression(profile: Dictionary, run, city_index: int, guest := false, almanac := false) -> Dictionary:
	if run.win_wave <= 0: return {}
	var waves: int = maxi(0, int(run.scored_wave) - int(run.win_wave))
	var key := str(city_index)
	var previous: Dictionary = profile.week_best.get(key, {})
	var best: Dictionary = BattleRecords.finalize_city_best(city_index, previous, int(run.stars), waves, guest, almanac)
	profile.week_best[key] = best
	profile.endless_best = maxi(int(profile.get("endless_best", 0)), int(run.scored_wave))
	var banked: int = _commit_gold(profile, run)
	_commit_kills(profile, run)
	var band_gold := _claim_week_bands(profile, run)
	var taofa_tokens := _grant_taofa_tokens(profile, city_index, waves)
	return {"waves": waves, "banked_gold": banked + band_gold, "band_gold": band_gold, "taofa_tokens": taofa_tokens, "city_score": int(best.score), "force_score": BattleRecords.week_score(profile.week_best)}

static func settle_over(profile: Dictionary, run, city_index: int) -> Dictionary:
	if run.over_settled: return {}
	run.over_settled = true
	var banked: int = _commit_gold(profile, run)
	_commit_kills(profile, run)
	var lord_gain: int = 2 if int(run.win_wave) > 0 else 3 + int(floor(city_index / 2.0))
	var lord_result: Dictionary = _settle_ruler_xp(profile, run.ruler_id, lord_gain)
	return {"banked_gold": banked, "lord_xp": lord_result}

static func _commit_gold(profile: Dictionary, run) -> int:
	var earned_total: int = maxi(0, roundi(float(run.run_gold)))
	var delta: int = maxi(0, earned_total - int(run.gold_committed))
	if delta > 0:
		profile.gold = int(profile.get("gold", 0)) + delta
		profile.gold_total = int(profile.get("gold_total", 0)) + delta
		run.gold_committed += delta
	return delta

static func _commit_kills(profile: Dictionary, run) -> int:
	var delta: int = maxi(0, int(run.kills) - int(run.kills_committed))
	if delta > 0:
		profile.total_kills = int(profile.get("total_kills", 0)) + delta
		run.kills_committed += delta
	return delta

static func _grant_visit_tokens(profile: Dictionary) -> int:
	var today := Time.get_date_string_from_system()
	if str(profile.get("visit_day", "")) != today:
		profile.visit_day = today
		profile.visit_count = 0
	if int(profile.get("visit_count", 0)) >= 30: return 0
	profile.visit_count = int(profile.get("visit_count", 0)) + 1
	profile.items.visitToken = int(profile.get("items", {}).get("visitToken", 0)) + 3
	return 3

static func _grant_taofa_tokens(profile: Dictionary, city_index: int, waves: int) -> int:
	var today := Time.get_date_string_from_system()
	if str(profile.get("taofa_day", "")) != today:
		profile.taofa_day = today
		profile.taofa_best = {}
		profile.taofa_got = 0
	var key := str(city_index)
	var previous := int(profile.get("taofa_best", {}).get(key, 0))
	if waves <= previous: return 0
	profile.taofa_best[key] = waves
	var units := int(floor(waves / 5.0)) - int(floor(previous / 5.0))
	if units <= 0: return 0
	var give := mini(units * 3, 30 - int(profile.get("taofa_got", 0)))
	if give <= 0: return 0
	profile.taofa_got = int(profile.get("taofa_got", 0)) + give
	profile.items.visitToken = int(profile.get("items", {}).get("visitToken", 0)) + give
	return give

static func _claim_week_bands(profile: Dictionary, run) -> int:
	var claim: Dictionary = BattleRecords.claimable_week_bands(int(profile.get("week_bands", 0)), BattleRecords.week_score(profile.week_best))
	var gold := int(claim.gold)
	profile.week_bands = int(claim.claimed)
	if gold > 0:
		profile.gold = int(profile.get("gold", 0)) + gold
		profile.gold_total = int(profile.get("gold_total", 0)) + gold
		run.band_gold += gold
	return gold

static func _settle_ruler_xp(profile: Dictionary, active_ruler_id: String, gain: int) -> Dictionary:
	var active: Dictionary = LocalProfile.add_ruler_xp(profile, active_ruler_id, gain)
	var reserve_gain: int = maxi(1, roundi(gain / 2.0))
	for ruler_id in LocalProfile.RULER_IDS:
		if ruler_id != active_ruler_id:
			LocalProfile.add_ruler_xp(profile, ruler_id, reserve_gain)
	return {"rid": active_ruler_id, "gain": gain, "from": int(active.from), "to": int(active.to), "xp": int(active.xp)}
