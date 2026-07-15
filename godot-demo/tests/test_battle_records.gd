extends SceneTree

const BattleRecords = preload("res://src/progression/battle_records.gd")
const LocalProfile = preload("res://src/progression/local_profile.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _test_score_formulas(): return
	if not _test_best_records_merge_independent_axes(): return
	if not _test_profile_round_trip_and_recovery(): return
	if not _test_ruler_xp(): return
	print("Godot v7.19.2 results, suppression, and local meta: PASS")
	quit(0)

func _test_score_formulas() -> bool:
	if not _expect(BattleRecords.week_level_base(0) == 100 and BattleRecords.week_level_base(15) == 1541, "prosperity must match the Web east-region curve"): return false
	if not _expect(BattleRecords.calc_stars(false, 0) == 3 and BattleRecords.calc_stars(true, 0) == 2 and BattleRecords.calc_stars(true, 1) == 1, "prestige stars must use wall damage and unit deaths"): return false
	if not _expect(BattleRecords.city_progress(0, 3) == 150, "three-star progress must be prosperity x1.5"): return false
	if not _expect(BattleRecords.city_suppression(0, 3, 4) == 150, "four suppression waves must add one full three-star prosperity amount"): return false
	if not _expect(BattleRecords.attempt_score(0, 3, 4) == 300, "attempt score must equal progress plus suppression"): return false
	if not _expect(BattleRecords.attempt_score(3, 2, 1, true) == 287, "attempt score must round once after applying guest-adjusted suppression like the Web runtime"): return false
	if not _expect(BattleRecords.week_guest_lords(2948) == ["dongzhuo", "liubiao"], "week 2948 must reproduce the Web's deterministic pair of guest rulers"): return false
	var records := {}
	for city in 11:
		records[city] = {"stars": 1, "endless": city + 1}
	var progress_total := 0
	var suppression_values := []
	for city in 11:
		progress_total += BattleRecords.city_progress(city, 1)
		suppression_values.append(BattleRecords.city_suppression(city, 1, city + 1))
	suppression_values.sort_custom(func(a, b): return a > b)
	var top_ten: int = int(suppression_values.slice(0, 10).reduce(func(total, value): return total + value, 0))
	if not _expect(BattleRecords.week_score(records) == progress_total + top_ten, "force score must include every city progress value but only the ten best suppression values"): return false
	if not _expect(BattleRecords.tech_score(0, 0.5, 1.0, true) == 156, "strategy score must match counter damage, wall fraction, and theme fit multipliers"): return false
	if not _expect(is_equal_approx(BattleRecords.endless_hp_multiplier(20, 15), 1.0) and is_equal_approx(BattleRecords.endless_hp_multiplier(21, 15), 1.06), "the first five endless waves must be warm-up before 1.06 pressure starts"): return false
	var expected_ramp := 1.06 * 1.09 * 1.12 * 1.15 * 1.18
	if not _expect(is_equal_approx(BattleRecords.endless_hp_multiplier(25, 15), expected_ramp), "deep suppression must use the four-stage ramp then constant x1.18"): return false
	return _expect(is_equal_approx(BattleRecords.endless_gold_multiplier(18, 15), pow(0.88, 3)), "suppression gold must decay by x0.88 per wave after clear")

func _test_best_records_merge_independent_axes() -> bool:
	var old := {"stars": 3, "endless": 2}
	var deeper := BattleRecords.merge_city_best(old, 2, 7)
	if not _expect(int(deeper.stars) == 3 and int(deeper.endless) == 7, "a deeper two-star run must retain the old three-star prestige while updating depth"): return false
	var prettier := BattleRecords.merge_city_best(deeper, 3, 4)
	return _expect(int(prettier.stars) == 3 and int(prettier.endless) == 7, "a shallower prestige run must not erase the deeper suppression record")

func _test_profile_round_trip_and_recovery() -> bool:
	var path := "user://codex-v7192-profile-test.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var profile := LocalProfile.defaults(2948)
	profile.gold = 321
	profile.wins = 9
	profile.week_clears["3"] = 1
	profile.week_best["3"] = {"stars": 3, "endless": 6, "score": 999}
	profile.week_bands = 2
	profile.rulers.caocao = {"lv": 2, "xp": 7}
	profile.heroes.zhangfei = {"lv": 4, "rb": 0}
	if not _expect(LocalProfile.save_to(path, profile) == OK, "local profile must save to user storage"): return false
	var loaded := LocalProfile.load_from(path, 2948)
	if not _expect(int(loaded.gold) == 321 and int(loaded.wins) == 9 and int(loaded.week_best["3"].endless) == 6 and int(loaded.week_bands) == 2, "local profile must round-trip score and claimed-band data"): return false
	if not _expect(int(loaded.rulers.caocao.lv) == 2 and int(loaded.heroes.zhangfei.lv) == 4, "local profile must round-trip ruler and hero growth"): return false
	var rolled := LocalProfile.load_from(path, 2949)
	if not _expect(rolled.week_best.is_empty() and int(rolled.week_bands) == 0 and int(rolled.gold) == 321, "a new week must reset weekly records and bands while preserving account growth"): return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var recovered := LocalProfile.load_from(path, 2948)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return _expect(int(recovered.gold) == 0 and recovered.week_best.is_empty(), "corrupt local data must recover to safe defaults")

func _test_ruler_xp() -> bool:
	var profile := LocalProfile.defaults(2948)
	var result := LocalProfile.add_ruler_xp(profile, "caocao", 50)
	if not _expect(int(profile.rulers.caocao.lv) == 2 and int(profile.rulers.caocao.xp) == 5, "ruler level one must need 45 XP"): return false
	if not _expect(int(result.from) == 1 and int(result.to) == 2, "ruler XP settlement must report level changes"): return false
	LocalProfile.add_ruler_xp(profile, "caocao", 100000)
	return _expect(int(profile.rulers.caocao.lv) == 20 and int(profile.rulers.caocao.xp) <= 330, "ruler growth must cap at level twenty")

func _expect(condition: bool, message: String) -> bool:
	if condition: return true
	push_error(message)
	quit(1)
	return false
