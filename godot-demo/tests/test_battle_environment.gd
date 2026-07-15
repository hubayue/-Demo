extends SceneTree

const ContentCatalog = preload("res://src/content/content_catalog.gd")
const Mulberry32 = preload("res://src/core/mulberry32.gd")
const BattleRun = preload("res://src/battle/battle_run.gd")
const BattleCards = preload("res://src/battle/battle_cards.gd")

class SequenceRng:
	extends RefCounted
	var values: Array
	var index := 0
	func _init(sequence: Array) -> void: values = sequence
	func next_float() -> float:
		var value := float(values[mini(index, values.size() - 1)])
		index += 1
		return value

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog = ContentCatalog.new()
	if not _expect(catalog.load_from("res://data/content-v7.19.2.json") == OK, "content must load"): return
	if not _test_relic_authority(catalog): return
	if not _test_dragon_egg(catalog): return
	if not _test_static_fields(catalog): return
	if not _test_permanent_tactics(catalog): return
	if not _test_timed_fields(catalog): return
	if not _test_weather_and_relic_amplifiers(catalog): return
	print("Godot v7.19.2 relics, tactics, and fields: PASS")
	quit(0)

func _test_relic_authority(catalog) -> bool:
	var catalog_ids: Array = catalog.list("relics").map(func(relic): return str(relic.id))
	if not _expect(catalog_ids.size() == 30, "Web v7.19.2 must define thirty relics"): return false
	if not _expect(BattleCards.ACTIVE_RELIC_IDS.size() == 30 and catalog_ids.all(func(id): return BattleCards.ACTIVE_RELIC_IDS.has(id)), "all thirty relics must participate in the conditional draft pool"): return false
	var run = _make_run(catalog)
	var unit: Dictionary = run.units()[0]
	var base_cd: float = run.ult_system.cooldown_max(run, unit)
	run.relic_ids = ["mengde"]
	if not _expect(is_equal_approx(run.ult_system.cooldown_max(run, unit), base_cd * 0.72), "Mengde New Book must reduce hero ultimate cooldown by twenty-eight percent"): return false
	unit.level = 6
	var mods: Dictionary = run.team.unit_mods(run, unit)
	run.relic_ids = []
	var base_damage: int = run.team.unit_damage(run, unit, mods)
	run.relic_ids = ["fenghuang"]
	var phoenix_damage: int = run.team.unit_damage(run, unit, mods)
	if not _expect(phoenix_damage > base_damage and absf(float(phoenix_damage) / maxf(1.0, float(base_damage)) - 1.5 / 1.4) < 0.02, "Phoenix Feather must replace first ascension scaling with 1.5x"): return false
	run.relic_ids = []
	if not _expect(is_equal_approx(run.egg_hatch_bonus(), 0.0), "base hatch bonus must be zero"): return false
	run.relic_ids.append("longxian")
	return _expect(is_equal_approx(run.egg_hatch_bonus(), 0.2), "Dragon Saliva must expose the Web +20% hatch chance to the egg system")

func _test_static_fields(catalog) -> bool:
	var hulao = BattleRun.new(catalog, Mulberry32.new(1))
	hulao.start(_city("hulao"), "caocao", "zhangfei")
	if not _expect(hulao.wall == 25 and hulao.wall_max == 25, "Hulao must add five starting wall points"): return false
	var guandu = BattleRun.new(catalog, Mulberry32.new(2))
	guandu.start(_city("guandu"), "caocao", "zhangfei")
	guandu.gain_xp(5.0)
	if not _expect(is_equal_approx(guandu.xp, 5.75), "Guandu must multiply kill experience by 1.15"): return false
	var mud = BattleRun.new(catalog, Mulberry32.new(3))
	mud.start(_city("nizhao"), "caocao", "zhangfei")
	var enemy := _enemy(240.0, 420.0, 100.0)
	mud.enemies = [enemy]
	mud._update_enemies(0.1)
	return _expect(float(enemy.y) < 420.0 + 100.0 * 0.1 * 0.7, "mud band must slow only enemies inside its Y range")

func _test_dragon_egg(catalog) -> bool:
	var locked = BattleRun.new(catalog, Mulberry32.new(9))
	locked.start(_city(""), "liubiao", "zhangfei", 1)
	locked.wave = 10
	locked.city.metaWins = 7
	var locked_cards = BattleCards.new(catalog, SequenceRng.new([0.0]))
	if not _expect(not locked_cards.build_pool(locked).any(func(card): return str(card.kind) == "egg"), "dragon eggs must stay locked before eight account wins outside suppression"): return false
	locked.endless = true
	if not _expect(locked_cards.build_pool(locked).any(func(card): return str(card.kind) == "egg"), "entering suppression must reveal the dragon egg even before eight account wins"): return false
	var run = BattleRun.new(catalog, Mulberry32.new(10))
	run.start(_city(""), "liubiao", "zhangfei", 1)
	run.wave = 10
	run.city.metaWins = 8
	run.obstacles.clear(); run.traits.clear()
	var cards = BattleCards.new(catalog, SequenceRng.new([0.75, 0.0, 0.0]))
	var place: Dictionary = cards.build_pool(run).filter(func(card): return str(card.kind) == "egg" and str(card.sub) == "place")[0]
	if not _expect(cards.apply(run, place), "Liu Biao must be able to place a real dragon egg from wave ten"): return false
	var egg: Dictionary = run.units().filter(func(unit): return str(unit.hero.cls) == "egg")[0]
	var xp_before := float(run.xp)
	run._update_units(1.0)
	if not _expect(float(run.xp) > xp_before, "dragon egg must generate experience every second while incubating"): return false
	run.relic_ids = ["longxian"]
	var grow: Dictionary = cards.build_pool(run).filter(func(card): return str(card.kind) == "egg" and str(card.sub) == "grow")[0]
	if not _expect(run.egg_hatch_chance(egg) >= 0.81 and cards.apply(run, grow) and int(egg.level) == 2, "Dragon Saliva must turn a 75% hatch roll into a successful incubation"): return false
	egg.level = 3
	var awaken: Dictionary = cards.build_pool(run).filter(func(card): return str(card.kind) == "egg" and str(card.sub) == "awaken")[0]
	if not _expect(cards.apply(run, awaken), "third-rank egg must awaken through the real card flow"): return false
	var dragon: Dictionary = run.units().filter(func(unit): return str(unit.hero.cls) == "dragon")[0]
	dragon.cd = 0.0
	var threat := _enemy(240.0, 250.0, 0.0)
	threat.hp = 5000.0; threat.hp_max = 5000.0; threat.special = "shaman"
	run.enemies = [threat]
	run._update_units(0.01)
	return _expect(float(threat.hp) < 5000.0 and float(threat.silencedT) >= 3.2, "awakened dragon must breathe on and suppress the highest threat")

func _test_permanent_tactics(catalog) -> bool:
	var pofu = _make_run(catalog)
	var unit: Dictionary = pofu.units()[0]
	var base_mods: Dictionary = pofu.team.unit_mods(pofu, unit)
	pofu.permanent_tactics.pofu = true
	var pofu_mods: Dictionary = pofu.team.unit_mods(pofu, unit)
	if not _expect(is_equal_approx(float(pofu_mods.dmgMul), float(base_mods.dmgMul) * 1.5), "Pofu must be an independent 1.5x team damage multiplier"): return false

	var huoshao = _make_run(catalog)
	huoshao.permanent_tactics.huoshao = true
	var burning := _enemy(220.0, 250.0, 0.0)
	burning.hp = 1.0; burning.burnT = 3.0; burning.burnDmg = 10.0
	var nearby := _enemy(260.0, 250.0, 0.0)
	huoshao.enemies = [burning, nearby]
	huoshao.damage_enemy(burning, 2.0)
	if not _expect(is_equal_approx(float(nearby.hp), 70.0) and float(nearby.burnT) >= 2.0 and is_equal_approx(float(nearby.burnDmg), 8.0), "Huoshao must explode for triple burn and spread eighty-percent fire"): return false

	var tactics = _make_run(catalog)
	tactics.permanent_tactics = {"luanshi": true, "shuiyan": true, "zhanshou": true}
	tactics.wave = 3
	tactics.obstacles = {"0,0": true, "2,4": true}
	for index in 5:
		var foe := _enemy(100.0 + index * 45.0, 280.0, 0.0)
		if index == 0: foe.special = "runner"
		tactics.enemies.append(foe)
	var elite_hp := float(tactics.enemies[0].hp)
	var ordinary_total: float = tactics.enemies.slice(1).reduce(func(total, foe): return total + float(foe.hp), 0.0)
	tactics.environment.update(tactics, 0.01)
	if not _expect(not tactics.flood.is_empty() and is_equal_approx(float(tactics.flood.t), 4.0) and is_equal_approx(float(tactics.flood.amp), 0.25), "Shuiyan must create the four-second +25% river once per wave"): return false
	if not _expect(float(tactics.enemies[0].hp) < elite_hp, "Zhanshou must strike a special enemy on entry"): return false
	var ordinary_after: float = tactics.enemies.slice(1).reduce(func(total, foe): return total + float(foe.hp), 0.0)
	if not _expect(ordinary_after < ordinary_total, "Luanshi must fire every obstacle once when five enemies are in play"): return false
	var after_first := float(tactics.enemies[0].hp)
	tactics.environment.update(tactics, 0.01)
	return _expect(is_equal_approx(float(tactics.enemies[0].hp), after_first), "once-per-wave tactics must not retrigger in the same wave")

func _test_timed_fields(catalog) -> bool:
	var volcano = BattleRun.new(catalog, Mulberry32.new(4))
	volcano.start(_city("huoshan"), "caocao", "zhangfei")
	volcano.wave = 4
	volcano.environment.volcano_time = 0.0
	var hot := _enemy(240.0, 250.0, 0.0)
	volcano.enemies = [hot]
	volcano.environment.update(volcano, 0.01)
	if not _expect(float(hot.hp) < 100.0 and float(hot.burnT) >= 3.0, "volcano must damage and ignite the densest cluster every twenty seconds"): return false

	var tower = BattleRun.new(catalog, Mulberry32.new(5))
	tower.start(_city("fengsui"), "caocao", "zhangfei")
	tower.wave = 4
	tower.environment.tower_time = 0.0
	var tower_foe := _enemy(240.0, 250.0, 0.0)
	tower.enemies = [tower_foe]
	tower.environment.update(tower, 0.01)
	if not _expect(float(tower_foe.hp) < 100.0 and float(tower_foe.burnT) >= 2.0, "beacon tower must fire and ignite up to five leading enemies"): return false

	var boulder = BattleRun.new(catalog, Mulberry32.new(6))
	boulder.start(_city("gunshi"), "caocao", "zhangfei")
	boulder.wave = 4
	boulder.environment.boulder_time = 0.0
	boulder.enemies = [_enemy(BattleRun.slot_center(0, 2).x, 180.0, 0.0)]
	boulder.environment.update(boulder, 0.01)
	return _expect(boulder.charges.size() == 1 and bool(boulder.charges[0].get("boulder", false)) and float(boulder.charges[0].vy) > 0.0, "boulder field must launch a visible downward lane attack every eighteen seconds")

func _test_weather_and_relic_amplifiers(catalog) -> bool:
	var burn = BattleRun.new(catalog, Mulberry32.new(7))
	burn.start(_city("chibi"), "caocao", "luxun")
	burn.wave = 2
	burn.mutations[2] = "eastwind"
	burn.relic_ids = ["huoyou"]
	burn.city.theme = "liaoyuan"
	var target := _enemy(240.0, 250.0, 0.0)
	target.burnT = 2.0; target.burnDmg = 10.0; target.burnTick = 0.0
	burn.enemies = [target]
	burn._update_enemies(0.01)
	if not _expect(is_equal_approx(float(target.hp), 46.0), "burn ticks must combine Chibi, Huoyou, Liaoyuan, and Eastwind multipliers"): return false
	var rain = _make_run(catalog)
	rain.wave = 2; rain.mutations[2] = "rainstorm"
	var wet := _enemy(240.0, 250.0, 0.0)
	wet.burnT = 3.0; wet.burnDmg = 10.0
	rain.enemies = [wet]
	rain.environment.update(rain, 0.01)
	if not _expect(is_zero_approx(float(wet.burnT)) and is_zero_approx(float(wet.burnDmg)), "rainstorm must extinguish active fires"): return false
	var treasure = BattleRun.new(catalog, Mulberry32.new(8))
	treasure.start(_city("guandu"), "caocao", "zhangfei")
	treasure.wave = 2; treasure.mutations[2] = "frenzy"; treasure.relic_ids = ["yuxi", "tongque"]
	var prize := _enemy(240.0, 250.0, 0.0)
	prize.hp = 1.0
	treasure.enemies = [prize]
	treasure.damage_enemy(prize, 2.0)
	if not _expect(is_equal_approx(treasure.run_gold, 4.5), "Yuxi, Guandu, and Tongque must multiply real run gold on a dangerous mutation wave"): return false
	var almanac = _make_run(catalog)
	almanac.city.visitGoldUntil = int(Time.get_unix_time_from_system() * 1000.0) + 60000
	var lucky_prize := _enemy(240.0, 250.0, 0.0)
	lucky_prize.hp = 1.0
	almanac.enemies = [lucky_prize]
	almanac.damage_enemy(lucky_prize, 2.0)
	if not _expect(is_equal_approx(almanac.run_gold, 1.2), "an active Yi-Qiu-Cai almanac card must multiply kill gold by 20 percent"): return false
	var spear: Dictionary = rain.units()[0]
	rain.relic_ids = ["shemao"]
	rain.rng = SequenceRng.new([0.0])
	var pushed := _enemy(240.0, 250.0, 0.0)
	rain.enemies = [pushed]
	rain._hit_enemy(pushed, 1.0, "", 0.0, spear)
	return _expect(float(pushed.kb) >= 72.0, "Iron-Spine Serpent Spear must give spear hits a twenty-percent knockback proc")

func _make_run(catalog):
	var run = BattleRun.new(catalog, Mulberry32.new(7192))
	run.start(_city(""), "caocao", "zhangfei")
	run.obstacles.clear(); run.traits.clear(); run.wave_timer = 999.0
	return run

func _city(field_id: String) -> Dictionary:
	return {"ch": 1, "wall": 20, "theme": "", "field": field_id, "hpMul": 1.0, "spdMul": 1.0, "hpGrow": 1.1, "affixAdd": 0.0, "killTarget": 9999, "obstacles": 0, "foes": {"tri": ""}}

func _enemy(x: float, y: float, speed: float) -> Dictionary:
	return {"x": x, "y": y, "hp": 100.0, "hp_max": 100.0, "base_speed": speed, "r": 16, "dmg": 1, "xp": 0.0, "tri": "", "cls": "spear", "dead": false, "boss": false, "big": false, "special": null, "affix": null, "kit": null, "kitSplit": 0, "shield": 0.0, "slowT": 0.0, "stunT": 0.0, "fearT": 0.0, "sleepT": 0.0, "charmT": 0.0, "silencedT": 0.0, "burnT": 0.0, "burnDmg": 0.0, "burnTick": 0.0, "kb": 0.0}

func _expect(condition: bool, message: String) -> bool:
	if condition: return true
	push_error(message)
	quit(1)
	return false
