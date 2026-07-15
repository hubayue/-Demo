extends SceneTree

const ContentCatalog = preload("res://src/content/content_catalog.gd")
const Mulberry32 = preload("res://src/core/mulberry32.gd")
const BattleRun = preload("res://src/battle/battle_run.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog := ContentCatalog.new()
	if not _expect(catalog.load_from("res://data/content-v7.19.2.json") == OK, "content must load"): return
	if not _test_prestige_tracking(catalog): return
	if not _test_continue_to_endless(catalog): return
	if not _test_endless_pressure_and_scored_waves(catalog): return
	if not _test_endless_military_orders(catalog): return
	if not _test_deep_control_tenacity(catalog): return
	if not _test_deep_wave_runtime_rules(catalog): return
	print("Godot v7.19.2 battle result and suppression lifecycle: PASS")
	quit(0)

func _test_prestige_tracking(catalog) -> bool:
	var run = _make_run(catalog)
	if not _expect(not run.wall_hurt and run.stars == 0, "a fresh run must start with an unhurt wall and no prestige"): return false
	run.enemies = [_enemy(240.0, run.DEFENSE_LINE - 5.0, 1.0)]
	run._update_enemies(0.1)
	if not _expect(run.wall_hurt, "an enemy reaching the wall must permanently lose the no-wall-damage star"): return false
	run.wave = 7
	run.finish("win")
	return _expect(run.status == "win" and run.stars == 2 and run.win_wave == 7, "victory must freeze two-star prestige and the clear wave")

func _test_continue_to_endless(catalog) -> bool:
	var run = _make_run(catalog)
	run.wave = 6
	run.finish("win")
	if not _expect(run.continue_endless() and run.status == "play" and run.endless, "the victory action must resume the same run in suppression mode"): return false
	var target := _enemy(240.0, 250.0, 0.0)
	target.hp = 1.0
	target.xp = 0.0
	run.kills = int(run.city.killTarget)
	run.enemies = [target]
	run.damage_enemy(target, 2.0)
	return _expect(run.status == "play", "kills beyond the clear target must not reopen victory while suppression is active")

func _test_endless_pressure_and_scored_waves(catalog) -> bool:
	var base = _make_run(catalog)
	base.city.hpGrow = 1.0
	base.city.hpMul = 1.0
	var base_wave: Array = base.build_wave(12)
	var base_ordinary: Dictionary = base_wave.filter(func(spec): return spec.get("special") == null and not bool(spec.get("big", false)))[0]
	var endless = _make_run(catalog)
	endless.city.hpGrow = 1.0
	endless.city.hpMul = 1.0
	endless.endless = true
	endless.win_wave = 6
	var pressured_wave: Array = endless.build_wave(12)
	var pressured_ordinary: Dictionary = pressured_wave.filter(func(spec): return spec.get("special") == null and not bool(spec.get("big", false)))[0]
	if not _expect(is_equal_approx(float(pressured_ordinary.hp), round(float(base_ordinary.hp) * 1.06)), "the sixth wave after clear must start the 1.06 suppression pressure ramp"): return false
	endless.wave = 9
	endless.scored_wave = 8
	endless.spawn_queue = []
	endless.enemies = []
	endless.wave_timer = 99.0
	endless._update_step(0.01)
	return _expect(endless.scored_wave == 9 and endless.score_revision == 1, "clearing an endless wave must expose a durable score revision immediately")

func _test_endless_military_orders(catalog) -> bool:
	var run = _make_run(catalog)
	run.endless = true
	run.win_wave = 1
	run.endless_mod = run.ENDLESS_RULES[0].duplicate(true)
	run.endless_mod.until = 4
	run._endless_rule_tick(4)
	if not _expect(not run.endless_pending.is_empty() and str(run.endless_pending.key) != "smoke", "wave four must preview a different military order for wave five"): return false
	var pending_key := str(run.endless_pending.key)
	run._endless_rule_tick(5)
	if not _expect(run.endless_pending.is_empty() and str(run.endless_mod.key) == pending_key and int(run.endless_mod.until) == 9, "the previewed order must activate for exactly five waves"): return false
	run.endless_mod = {"key": "smoke", "mod": {"archerRngMul": 0.65}, "until": 9}
	if not _expect(is_equal_approx(run.effective_archer_range({"rng": 300.0, "cls": "archer"}), 195.0), "smoke order must reduce real archer range by 35 percent"): return false
	run.endless_mod = {"key": "mud", "mod": {"cavChargeMul": 0.55}, "until": 9}
	var charge := {"x": 240.0, "y": 400.0, "y0": 400.0, "vy": -100.0, "width": 34.0, "damage": 1.0, "tri": "", "crit": 0.0, "owner": {}, "hit": [], "dead": false}
	run.charges = [charge]
	run._update_charges(2.1)
	if not _expect(bool(charge.dead), "mud order must stop a cavalry charge after 55 percent of its lane"): return false
	run.endless_pending = run.ENDLESS_RULES.filter(func(rule): return str(rule.key) == "shift")[0].duplicate(true)
	run.city.foes.tri = "badao"
	run._endless_rule_tick(10)
	return _expect(not run.endless_foes.is_empty() and str(run.endless_foes.tri) != "badao", "shift order must temporarily replace the city's weakness with a different element")

func _test_deep_control_tenacity(catalog) -> bool:
	var run = _make_run(catalog)
	run.endless = true
	run.win_wave = 1
	run.wave = 7
	if not _expect(is_equal_approx(run.foe_tenacity(), 0.93), "the first deep suppression wave must reduce effective control duration to 93 percent"): return false
	var enemy := _enemy(240.0, 250.0, 0.0)
	enemy.stunT = 1.0
	run.enemies = [enemy]
	run._update_enemies(0.93)
	return _expect(float(enemy.stunT) <= 0.001, "deep suppression control timers must consume time using the tenacity multiplier")

func _test_deep_wave_runtime_rules(catalog) -> bool:
	var run = _make_run(catalog)
	run.mutations = {}
	var mutation = run._mutation_for_wave(18)
	if not _expect(run.mutations.has(18) and run._mutation_for_wave(18) == mutation, "wave eighteen and beyond must roll and memoize the Web's live mutation chance"): return false
	run.mutations[30] = ""
	var wave: Array = run.build_wave(30)
	return _expect(wave.size() == 73, "deep non-horde waves must compress 96 bodies into 72 tougher enemies plus the boss")

func _make_run(catalog):
	var run = BattleRun.new(catalog, Mulberry32.new(7192))
	run.start({"ch": 1, "wall": 20, "theme": "", "field": "", "hpMul": 1.0, "spdMul": 1.0, "hpGrow": 1.1, "affixAdd": 0.0, "killTarget": 450, "obstacles": 0, "foes": {"tri": ""}}, "caocao", "zhangfei")
	run.obstacles.clear()
	run.traits.clear()
	return run

func _enemy(x: float, y: float, speed: float) -> Dictionary:
	return {"x": x, "y": y, "hp": 100.0, "hp_max": 100.0, "base_speed": speed, "r": 16, "dmg": 1, "xp": 0.0, "tri": "", "cls": "spear", "dead": false, "boss": false, "big": false, "special": null, "affix": null, "kit": null, "shield": 0.0, "slowT": 0.0, "stunT": 0.0, "fearT": 0.0, "sleepT": 0.0, "charmT": 0.0, "silencedT": 0.0, "burnT": 0.0, "burnDmg": 0.0, "burnTick": 0.0, "kb": 0.0}

func _expect(condition: bool, message: String) -> bool:
	if condition: return true
	push_error(message)
	quit(1)
	return false
