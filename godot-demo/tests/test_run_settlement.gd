extends SceneTree

const ContentCatalog = preload("res://src/content/content_catalog.gd")
const Mulberry32 = preload("res://src/core/mulberry32.gd")
const BattleRun = preload("res://src/battle/battle_run.gd")
const LocalProfile = preload("res://src/progression/local_profile.gd")
const RunSettlement = preload("res://src/progression/run_settlement.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog := ContentCatalog.new()
	if not _expect(catalog.load_from("res://data/content-v7.19.2.json") == OK, "content must load"): return
	var profile := LocalProfile.defaults(2948)
	var run = BattleRun.new(catalog, Mulberry32.new(7192))
	var city := {"k": 0, "week": 2948, "ch": 1, "wall": 20, "theme": "tuanjie", "field": "", "hpMul": 1.0, "spdMul": 1.0, "hpGrow": 1.1, "affixAdd": 0.0, "killTarget": 450, "obstacles": 0, "firstGold": 210, "foes": {"tri": "badao"}}
	run.start(city, "caocao", "zhangfei")
	run.wave = 7
	run.run_gold = 35.4
	run.kills = 120
	run.total_damage = 100.0
	run.counter_damage = 50.0
	run.finish("win")
	var result: Dictionary = RunSettlement.settle_clear(profile, run, 0, true)
	if not _expect(int(profile.wins) == 1 and int(profile.gold) == 245, "clear settlement must bank rounded battle gold plus the first-clear reward once"): return
	if not _expect(int(profile.week_clears["0"]) == 1 and int(profile.week_best["0"].stars) == 3, "clear settlement must persist city clear and prestige"): return
	if not _expect(int(result.first_clear_gold) == 210 and int(result.tech_score) == 156, "clear settlement must report first reward and strategy score"): return
	if not _expect(int(profile.rulers.caocao.xp) == 12, "city zero three-star clear must grant the active ruler 6 + city + stars x2 XP"): return
	if not _expect(int(profile.rulers.liubei.xp) == 6, "the seven reserve rulers must receive half training XP"): return
	if not _expect(int(profile.items.visitToken) == 3 and int(result.visit_tokens) == 3, "each clear must grant three offline visit tokens within the daily cap"): return
	if not _expect(int(profile.total_kills) == 120 and int(profile.perfect_wins) == 1 and int(profile.gold_total) == 245, "settlement must persist locally verifiable achievement counters"): return
	var empty_run = BattleRun.new(catalog, Mulberry32.new(7193))
	empty_run.start(city, "caocao", "zhangfei")
	empty_run.finish("win")
	var empty_profile := LocalProfile.defaults(2948)
	var empty_result: Dictionary = RunSettlement.settle_clear(empty_profile, empty_run, 0, false)
	if not _expect(int(empty_result.tech_score) == 72, "a themed city with no dealt damage must score zero counter share rather than the neutral no-weakness fallback"): return
	var band_run = BattleRun.new(catalog, Mulberry32.new(7194))
	band_run.start(city, "caocao", "zhangfei")
	band_run.finish("win")
	var band_profile := LocalProfile.defaults(2948)
	var band_result: Dictionary = RunSettlement.settle_clear(band_profile, band_run, 15, false)
	if not _expect(int(band_result.band_gold) == 500 and int(band_profile.week_bands) == 1 and int(band_profile.gold) == 710, "crossing the first 2000-force weekly band must immediately grant its 500 gold reward"): return
	run.continue_endless()
	run.scored_wave = 11
	run.run_gold = 44.9
	var suppression: Dictionary = RunSettlement.record_suppression(profile, run, 0)
	if not _expect(int(profile.gold) == 255, "suppression sync must bank only newly earned gold without duplicating clear gold"): return
	if not _expect(int(profile.week_best["0"].endless) == 4 and int(suppression.waves) == 4, "suppression sync must record only fully cleared waves after the clear wave"): return
	if not _expect(int(profile.endless_best) == 11, "local honor record must retain the deepest absolute wave reached"): return
	run.scored_wave = 12
	var taofa: Dictionary = RunSettlement.record_suppression(profile, run, 0)
	if not _expect(int(taofa.taofa_tokens) == 3 and int(profile.items.visitToken) == 6, "each new five-wave suppression depth must grant three visit tokens within the daily cap"): return
	run.status = "play"
	run.finish("over")
	RunSettlement.settle_over(profile, run, 0)
	if not _expect(int(profile.gold) == 255, "endless defeat must not duplicate already banked gold"): return
	print("Godot v7.19.2 local run settlement: PASS")
	quit(0)

func _expect(condition: bool, message: String) -> bool:
	if condition: return true
	push_error(message)
	quit(1)
	return false
