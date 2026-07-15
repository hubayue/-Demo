extends SceneTree

const ContentCatalog = preload("res://src/content/content_catalog.gd")
const Mulberry32 = preload("res://src/core/mulberry32.gd")
const BattleRun = preload("res://src/battle/battle_run.gd")
const BattleFoes = preload("res://src/battle/battle_foes.gd")

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
	if not _test_authority_definitions(): return
	if not _test_wave_generation(catalog): return
	if not _test_spawn_state(catalog): return
	if not _test_auras_and_affixes(catalog): return
	if not _test_ranged_and_siege(catalog): return
	if not _test_shield_cover(catalog): return
	if not _test_death_behaviors(catalog): return
	if not _test_boss_kits(catalog): return
	print("Godot v7.19.2 special foes: PASS")
	quit(0)

func _test_authority_definitions() -> bool:
	var defs: Dictionary = BattleFoes.SPECIALS
	var expected := ["runner", "healer", "shooter", "banner", "thrower", "shaman", "rattan", "ram", "cata", "warden", "bomber", "assassin", "pavise"]
	if not _expect(defs.size() == 13 and BattleFoes.SPECIAL_ORDER == expected, "all thirteen Web special foes must exist in authority order"): return false
	if not _expect(int(defs.runner.min_wave) == 3 and is_equal_approx(float(defs.runner.hp_mul), 0.5) and is_equal_approx(float(defs.runner.speed_mul), 2.2), "runner thresholds and multipliers must match Web"): return false
	if not _expect(int(defs.cata.lv_min) == 24 and int(defs.cata.r) == 22 and int(defs.cata.dmg) == 1, "catapult campaign gate and combat stats must match Web"): return false
	if not _expect(int(defs.pavise.lv_min) == 36 and is_equal_approx(float(defs.pavise.hp_mul), 2.8), "pavise gate and durability must match Web"): return false
	var cata_spec: Dictionary = BattleFoes.new().make_spec("cata", 100, 50.0, 2.0, "archer", 0.3, "rende")
	if not _expect(int(cata_spec.hp) == 120 and is_equal_approx(float(cata_spec.speed), 30.0) and is_equal_approx(float(cata_spec.xp), 6.0), "special stat conversion must apply Web HP, speed, and XP multipliers"): return false
	var behavior = BattleFoes.new()
	if not _expect(behavior.roll_special(SequenceRng.new([0.1]), 3, {"idx": 0, "theme": ""}, null) == null, "ordinary week must retain the base runner rate"): return false
	if not _expect(str(behavior.roll_special(SequenceRng.new([0.1]), 3, {"idx": 0, "theme": "yunchou"}, null)) == "runner", "Yunchou week must multiply special rates by 1.6"): return false
	if not _expect(str(behavior.roll_special(SequenceRng.new([1.0, 0.0]), 5, {"idx": 0, "theme": ""}, "volley")) == "shooter", "volley mutation must bring shooters forward to wave five at fourfold rate"): return false
	return _expect(BattleFoes.AFFIXES.keys().all(func(key): return ["shield", "split", "frenzy", "regen"].has(key)) and BattleFoes.AFFIXES.size() == 4, "all four elite affixes must be defined")

func _test_wave_generation(catalog) -> bool:
	var run = BattleRun.new(catalog, Mulberry32.new(7192))
	var city := _city("avatar")
	city.lvIdx = 64
	run.start(city, "caocao", "guanyu")
	run.mutations[15] = null
	run.rng = Mulberry32.new(19)
	var queue := run.build_wave(15)
	if not _expect(queue.any(func(spec): return spec.get("special") != null), "deep campaign waves must roll real special foes"): return false
	var base_hp := roundi(12.0 * pow(1.1, 14.0))
	var base_speed := 60.0
	for spec in queue:
		var special = spec.get("special")
		if special == null: continue
		var definition: Dictionary = BattleFoes.SPECIALS[str(special)]
		if not _expect(int(spec.r) == int(definition.r) and int(spec.hp) == roundi(base_hp * float(definition.hp_mul)) and is_equal_approx(float(spec.speed), base_speed * float(definition.speed_mul)), "special radius, HP, and speed multipliers must come from authority data"): return false
	var boss: Dictionary = queue.filter(func(spec): return bool(spec.get("boss", false)))[0]
	if not _expect(bool(boss.summoner) and str(boss.kit) == "avatar" and int(boss.kitSplit) == 0, "boss wave specs must carry summoner and boss-kit state"): return false
	run.wave = 14
	run.next_queue = []
	run.rng = Mulberry32.new(19)
	run.prepare_next_wave()
	var expected_specials := {}
	for spec in run.next_queue:
		if spec.get("special") != null: expected_specials[str(spec.special)] = int(expected_specials.get(str(spec.special), 0)) + 1
	return _expect(run.next_wave_preview.specials == expected_specials and str(run.next_wave_preview.boss) == "张角", "next-wave preview must expose special counts and the incoming boss")

func _test_spawn_state(catalog) -> bool:
	var run = _make_run(catalog)
	run._spawn_enemy({"hp": 100.0, "speed": 20.0, "r": 26, "cls": "spear", "big": true, "boss": true, "bossName": "张角", "affix": "shield", "special": null, "tri": "badao", "xp": 1.0, "dmg": 6, "summoner": true, "kit": "avatar", "kitSplit": 0})
	var enemy: Dictionary = run.enemies[0]
	if not _expect(is_equal_approx(float(enemy.shield), 60.0) and is_equal_approx(float(enemy.shield_max), 60.0), "shield affix must spawn with sixty percent max-HP shield"): return false
	if not _expect(bool(enemy.summoner) and is_equal_approx(float(enemy.summonT), 3.5) and str(enemy.kit) == "avatar", "spawned boss must initialize fast summoning and kit timers"): return false
	var field_run = _make_run(catalog)
	field_run.city.field = "nizhao"
	field_run._spawn_enemy({"x": 200.0, "hp": 100.0, "speed": 20.0, "r": 20, "cls": "spear", "affix": "shield", "special": null, "tri": "", "xp": 0.0, "dmg": 1})
	if not _expect(is_equal_approx(float(field_run.enemies[0].hp), 110.0) and is_equal_approx(float(field_run.enemies[0].shield), 66.0), "mud field must scale spawned HP before shield initialization"): return false
	field_run.enemies = []
	field_run.city.field = "changban"
	field_run._spawn_enemy({"x": 200.0, "hp": 100.0, "speed": 20.0, "r": 20, "cls": "spear", "affix": null, "special": null, "tri": "", "xp": 0.0, "dmg": 1})
	if not _expect(is_equal_approx(float(field_run.enemies[0].base_speed), 22.4), "Changban field must multiply spawned movement speed by 1.12"): return false
	field_run.enemies = []
	field_run.city.field = "hulao"
	field_run._spawn_enemy({"hp": 100.0, "speed": 20.0, "r": 20, "cls": "spear", "affix": null, "special": null, "tri": "", "xp": 0.0, "dmg": 1})
	return _expect(float(field_run.enemies[0].x) >= 480.0 * 0.28 and float(field_run.enemies[0].x) <= 480.0 * 0.72, "Hulao field must narrow the random enemy spawn corridor")

func _test_auras_and_affixes(catalog) -> bool:
	var run = _make_run(catalog)
	var healer := _enemy("healer", 150.0, 200.0, 0.0)
	var patient := _enemy("", 180.0, 210.0, 0.0)
	patient.hp = 50.0
	var banner := _enemy("banner", 250.0, 200.0, 0.0)
	var marcher := _enemy("", 260.0, 210.0, 100.0)
	var warden := _enemy("warden", 350.0, 200.0, 0.0)
	var guarded := _enemy("", 360.0, 210.0, 0.0)
	run.enemies = [healer, patient, banner, marcher, warden, guarded]
	run._update_enemies(1.51)
	if not _expect(is_equal_approx(float(patient.hp), 56.0), "healer must restore six percent max HP every 1.5 seconds"): return false
	if not _expect(float(marcher.y) > 210.0 + 100.0 * 1.51, "banner aura must speed nearby ordinary foes by thirty-five percent"): return false
	var hp_before := float(guarded.hp)
	run.damage_enemy(guarded, 100.0)
	if not _expect(is_equal_approx(float(guarded.hp), hp_before - 70.0), "warden aura must reduce nearby ordinary-foe damage by thirty percent"): return false
	var elite := _enemy("", 80.0, 100.0, 100.0)
	elite.affix = "regen"
	elite.hp = 30.0
	elite.regenTick = 0.0
	run.enemies = [elite]
	run._update_enemies(0.1)
	if not _expect(is_equal_approx(float(elite.hp), 32.0), "regeneration affix must heal two percent max HP each second"): return false
	elite.affix = "frenzy"
	elite.y = 100.0
	var y_before := float(elite.y)
	run._update_enemies(0.1)
	if not _expect(float(elite.y) >= y_before + 15.9, "frenzy affix must gain sixty percent speed below forty percent HP"): return false
	var shaman_run = _make_run(catalog)
	var shaman := _enemy("shaman", 240.0, 100.0, 0.0)
	shaman.sealCastT = 0.0
	shaman_run.enemies = [shaman]
	shaman_run._update_enemies(0.01)
	if not _expect(float(shaman_run.units()[0].sealedT) > 0.0, "shaman must seal a formation unit for three seconds"): return false
	var ram := _enemy("ram", 240.0, 100.0, 0.0)
	ram.fearT = 2.0; ram.sleepT = 2.0; ram.charmT = 2.0; ram.stunT = 2.0; ram.kb = 100.0
	shaman_run.enemies = [ram]
	shaman_run._update_enemies(0.1)
	return _expect(is_zero_approx(float(ram.fearT)) and is_zero_approx(float(ram.sleepT)) and is_zero_approx(float(ram.charmT)) and float(ram.stunT) < 1.8 and float(ram.kb) <= 10.0, "ram must ignore mind control and rapidly shake off physical control")

func _test_ranged_and_siege(catalog) -> bool:
	var shooter_run = _make_run(catalog)
	shooter_run.clear_formation()
	shooter_run.obstacles.clear()
	shooter_run.add_unit_at("zhangfei", 0, 2)
	var shooter := _enemy("shooter", BattleRun.slot_center(0, 2).x, BattleRun.GRID_Y - 200.0, 0.0)
	shooter.shootT = 0.0
	shooter_run.enemies = [shooter]
	shooter_run._update_enemies(0.01)
	if not _expect(shooter_run.enemy_projectiles.size() == 1, "shooter must launch a real homing arrow at a lane blocker"): return false
	var target: Dictionary = shooter_run.units()[0]
	var hp_before := float(target.hp)
	for step in 120: shooter_run._update_enemy_attacks(0.02)
	if not _expect(float(target.hp) < hp_before, "enemy homing arrow must reach and damage its target"): return false

	var thrower_run = _make_run(catalog)
	thrower_run.clear_formation()
	thrower_run.obstacles.clear()
	thrower_run.add_unit_at("zhangfei", 0, 2)
	var thrower := _enemy("thrower", BattleRun.slot_center(0, 2).x, BattleRun.GRID_Y - 200.0, 0.0)
	thrower.throwT = 0.0
	thrower_run.enemies = [thrower]
	thrower_run._update_enemies(0.01)
	if not _expect(thrower_run.enemy_lobs.size() == 1, "thrower must launch a real area lob"): return false
	hp_before = float(thrower_run.units()[0].hp)
	thrower_run._update_enemy_attacks(1.2)
	if not _expect(float(thrower_run.units()[0].hp) < hp_before, "enemy area lob must damage units near its landing point"): return false

	var cata_run = _make_run(catalog)
	cata_run.wave = 12
	var cata := _enemy("cata", 240.0, BattleRun.GRID_Y - 300.0, 0.0)
	var cata_two := _enemy("cata", 300.0, BattleRun.GRID_Y - 280.0, 0.0)
	cata.lobT = 0.0
	cata_two.lobT = 0.0
	cata_run.enemies = [cata, cata_two]
	var wall_before: int = cata_run.wall
	cata_run._update_enemies(0.01)
	if not _expect(cata_run.enemy_wall_lobs.size() == 1, "catapult must create a marked 1.4-second wall shot and obey the global two-second volley gap"): return false
	cata_run._update_enemy_attacks(1.4)
	if not _expect(cata_run.wall == wall_before - 1, "catapult wall shot must remove one wall point on landing"): return false
	var cancel_run = _make_run(catalog)
	cancel_run.wave = 12
	var doomed_cata := _enemy("cata", 240.0, BattleRun.GRID_Y - 300.0, 0.0)
	doomed_cata.lobT = 0.0
	cancel_run.enemies = [doomed_cata]
	cancel_run._update_enemies(0.01)
	wall_before = cancel_run.wall
	cancel_run.damage_enemy(doomed_cata, 999.0)
	cancel_run._update_enemy_attacks(1.4)
	if not _expect(cancel_run.wall == wall_before and cancel_run.enemy_wall_lobs.is_empty(), "killing a catapult during its warning arc must cancel the pending wall hit"): return false

	var taunt_run = _make_run(catalog)
	taunt_run.clear_formation(); taunt_run.obstacles.clear()
	taunt_run.add_unit_at("caoren", 0, 0); taunt_run.add_unit_at("yanyan", 2, 4); taunt_run.add_unit_at("huangzhong", 1, 2)
	var default_target: Dictionary = taunt_run.grid[1][2]
	var nearest_shield: Dictionary = taunt_run.grid[2][4]
	var archer_foe := _enemy("shooter", BattleRun.slot_center(2, 4).x, 300.0, 0.0)
	taunt_run.rng = SequenceRng.new([0.0])
	taunt_run._shoot_enemy_arrow(archer_foe, default_target, 10, 260.0)
	if not _expect(taunt_run.enemy_projectiles[0].target == nearest_shield, "seventy-percent taunt must redirect to the shield nearest the attacker"): return false

	var assassin_run = _make_run(catalog)
	assassin_run.clear_formation()
	assassin_run.obstacles.clear()
	assassin_run.add_unit_at("huangzhong", 2, 2)
	var assassin := _enemy("assassin", 240.0, BattleRun.GRID_Y - 100.0, 0.0)
	assassin.atkT = 0.0
	assassin_run.enemies = [assassin]
	var rear: Dictionary = assassin_run.units()[0]
	hp_before = float(rear.hp)
	assassin_run._update_enemies(0.01)
	return _expect(bool(assassin.leaped) and int(assassin.assR) == 2 and float(rear.hp) < hp_before, "assassin must leap to and stab the deepest soft formation target")

func _test_shield_cover(catalog) -> bool:
	var front_run = _make_run(catalog)
	front_run.clear_formation(); front_run.obstacles.clear()
	front_run.add_unit_at("caoren", 0, 2); front_run.add_unit_at("huangzhong", 2, 2)
	var protected: Dictionary = front_run.grid[2][2]
	var hp_before := float(protected.hp)
	var landing := BattleRun.slot_center(2, 2)
	front_run.enemy_lobs = [{"x0": 0.0, "y0": 0.0, "x1": landing.x, "y1": landing.y, "t": 0.0, "dur": 1.0, "damage": 40, "dead": false}]
	front_run._update_enemy_attacks(1.0)
	if not _expect(is_equal_approx(float(protected.hp), hp_before - 20.0), "same-column shield in a forward row must halve lob damage even when not adjacent"): return false
	var side_run = _make_run(catalog)
	side_run.clear_formation(); side_run.obstacles.clear()
	side_run.add_unit_at("caoren", 2, 1); side_run.add_unit_at("huangzhong", 2, 2)
	protected = side_run.grid[2][2]
	hp_before = float(protected.hp)
	landing = BattleRun.slot_center(2, 2)
	side_run.enemy_lobs = [{"x0": 0.0, "y0": 0.0, "x1": landing.x, "y1": landing.y, "t": 0.0, "dur": 1.0, "damage": 40, "dead": false}]
	side_run._update_enemy_attacks(1.0)
	if not _expect(is_equal_approx(float(protected.hp), hp_before - 30.0), "side shield must grant only ordinary adjacent protection, not forward lob cover"): return false
	var hufu_run = _make_run(catalog)
	hufu_run.clear_formation(); hufu_run.obstacles.clear(); hufu_run.relic_ids = ["hufu"]
	hufu_run.add_unit_at("caoren", 0, 2); hufu_run.add_unit_at("huangzhong", 2, 2)
	protected = hufu_run.grid[2][2]
	hp_before = float(protected.hp)
	landing = BattleRun.slot_center(2, 2)
	hufu_run.enemy_lobs = [{"x0": 0.0, "y0": 0.0, "x1": landing.x, "y1": landing.y, "t": 0.0, "dur": 1.0, "damage": 40, "dead": false}]
	hufu_run._update_enemy_attacks(1.0)
	return _expect(is_equal_approx(float(protected.hp), hp_before - 14.0), "Hufu must improve forward lob cover from one-half to thirty-five percent")

func _test_death_behaviors(catalog) -> bool:
	var run = _make_run(catalog)
	run.clear_formation()
	run.obstacles.clear()
	run.add_unit_at("zhangfei", 0, 2)
	var center := BattleRun.slot_center(0, 2)
	var bomber := _enemy("bomber", center.x, center.y - 20.0, 0.0)
	bomber.hp = 1.0
	run.enemies = [bomber]
	var hp_before := float(run.units()[0].hp)
	run.damage_enemy(bomber, 2.0)
	if not _expect(float(run.units()[0].hp) < hp_before, "bomber death must damage nearby formation units"): return false

	var splitter := _enemy("", 200.0, 220.0, 20.0)
	splitter.affix = "split"
	splitter.hp = 1.0
	splitter.hp_max = 100.0
	run.enemies = [splitter]
	run.damage_enemy(splitter, 2.0)
	if not _expect(run.enemies.size() == 2 and run.enemies.all(func(enemy): return is_equal_approx(float(enemy.hp), 20.0) and int(enemy.r) == 13), "split affix death must create two twenty-percent minions"): return false

	var pavise := _enemy("pavise", 240.0, 300.0, 0.0)
	run.enemies = [pavise]
	run.projectiles = [{"x": 240.0, "y": 300.0, "vx": 0.0, "vy": 0.0, "damage": 40.0, "tri": "", "r": 4.0, "distance": 0.0, "max_distance": 10.0, "crit": 0.0, "pierce": 0, "owner": {}, "hit": [], "dead": false}]
	run._update_projectiles(0.01)
	return _expect(is_equal_approx(float(pavise.hp), 90.0), "pavise must take only twenty-five percent damage from projectiles")

func _test_boss_kits(catalog) -> bool:
	var revive_run = _make_run(catalog)
	var thunder := _enemy("", 240.0, 180.0, 0.0)
	thunder.boss = true
	thunder.kit = "thunder"
	thunder.hp = 1.0
	revive_run.enemies = [thunder]
	revive_run.damage_enemy(thunder, 2.0)
	if not _expect(not bool(thunder.dead) and bool(thunder.revived) and is_equal_approx(float(thunder.hp), 40.0), "thunder boss must revive once at forty percent HP"): return false

	var summon_run = _make_run(catalog)
	summon_run.city.field = "nizhao"
	var summoner := _enemy("", 240.0, 180.0, 0.0)
	summoner.boss = true
	summoner.summoner = true
	summoner.kit = "summon"
	summoner.summonT = 0.0
	summon_run.enemies = [summoner]
	summon_run._update_enemies(0.01)
	if not _expect(summon_run.enemies.size() == 5, "summon boss must call four reinforcements every 3.5 seconds"): return false
	var reinforcements: Array = summon_run.enemies.filter(func(enemy): return enemy != summoner)
	if not _expect(reinforcements.all(func(child): return is_equal_approx(float(child.hp), 4.0) and str(child.tri).is_empty() and float(child.y) <= float(summoner.y) - 10.0), "reinforcements must ignore field re-scaling, carry no triangle, and spawn behind the boss"): return false
	var fire_run = _make_run(catalog)
	var firepot := _enemy("", 240.0, 180.0, 0.0)
	firepot.boss = true; firepot.kit = "firepot"; firepot.kitT = 0.0
	fire_run.enemies = [firepot]
	fire_run._update_enemies(0.01)
	if not _expect(fire_run.enemy_lobs.size() == 2, "firepot boss must throw two 1.25x area lobs every 4.5 seconds"): return false
	var volley_run = _make_run(catalog)
	var volley := _enemy("", 240.0, 180.0, 0.0)
	volley.boss = true; volley.kit = "volley"; volley.kitT = 0.0
	volley_run.enemies = [volley]
	volley_run._update_enemies(0.01)
	var volley_xs: Array = volley_run.enemy_projectiles.map(func(projectile): return snappedf(float(projectile.x), 0.001))
	if not _expect(volley_run.enemy_projectiles.size() == 4 and volley_xs.duplicate().filter(func(value): return volley_xs.count(value) == 1).size() >= 2, "volley boss must launch four visibly spread targeted arrows every 3.5 seconds"): return false
	var split_run = _make_run(catalog)
	var split_boss := _enemy("", 240.0, 180.0, 0.0)
	split_boss.boss = true; split_boss.kit = "split"; split_boss.kitSplit = 2; split_boss.hp = 1.0
	split_run.enemies = [split_boss]
	split_run.damage_enemy(split_boss, 2.0)
	if not _expect(split_run.enemies.size() == 2 and split_run.enemies.all(func(child): return int(child.kitSplit) == 1 and bool(child.big)), "split boss must create two large children that can split once more"): return false
	var seal_run = _make_run(catalog)
	seal_run.clear_formation(); seal_run.obstacles.clear(); seal_run.add_unit_at("zhangfei", 0, 1); seal_run.add_unit_at("zhaoyun", 0, 2)
	var sealwave := _enemy("", 240.0, 180.0, 0.0)
	sealwave.boss = true; sealwave.kit = "sealwave"; sealwave.sealKitT = 0.0
	seal_run.enemies = [sealwave]
	seal_run._update_enemies(0.01)
	if not _expect(seal_run.units().all(func(unit): return float(unit.sealedT) > 0.0), "seal-wave boss must seal two different units for 2.5 seconds"): return false
	var affix_run = _make_run(catalog)
	var affixlord := _enemy("", 240.0, 100.0, 100.0)
	affixlord.boss = true; affixlord.kit = "affixlord"; affixlord.hp = 30.0; affixlord.regenTick = 0.0
	affix_run.enemies = [affixlord]
	affix_run._update_enemies(0.1)
	if not _expect(is_equal_approx(float(affixlord.hp), 32.0) and float(affixlord.y) >= 115.9, "affix-lord boss must combine regeneration and low-HP frenzy"): return false

	var kit_run = _make_run(catalog)
	kit_run.clear_formation()
	kit_run.obstacles.clear()
	kit_run.add_unit_at("zhangfei", 0, 2)
	var avatar := _enemy("", 240.0, 180.0, 0.0)
	avatar.boss = true
	avatar.kit = "avatar"
	avatar.sealKitT = 0.0
	avatar.thunderKitT = 0.0
	kit_run.enemies = [avatar]
	var unit: Dictionary = kit_run.units()[0]
	var hp_before := float(unit.hp)
	kit_run._update_enemies(0.01)
	if not _expect(float(unit.sealedT) > 0.0 and float(unit.hp) < hp_before, "avatar must execute both seal-wave and thunder boss skills"): return false
	kit_run.enemy_projectiles = [{"dead": false}]
	kit_run.enemy_lobs = [{"dead": false}]
	kit_run.enemy_wall_lobs = [{"dead": false}]
	kit_run.finish("over")
	return _expect(kit_run.enemy_projectiles.is_empty() and kit_run.enemy_lobs.is_empty() and kit_run.enemy_wall_lobs.is_empty(), "battle settlement must clear every enemy projectile family")

func _make_run(catalog):
	var run = BattleRun.new(catalog, Mulberry32.new(7192))
	run.start(_city(""), "caocao", "guanyu")
	run.spawn_queue = []
	run.next_queue = []
	run.wave_budget = 999.0
	return run

func _city(kit: String) -> Dictionary:
	return {"ch": 1, "idx": 64, "lvIdx": 64, "wall": 30, "theme": "", "field": "", "hpMul": 1.0, "spdMul": 1.0, "hpGrow": 1.1, "affixAdd": 0.0, "killTarget": 9999, "obstacles": 0, "foes": {"tri": ""}, "bossName": "张角", "bossKit": kit}

func _enemy(special: String, x: float, y: float, speed: float) -> Dictionary:
	return {"x": x, "y": y, "r": 18, "base_speed": speed, "hp": 100.0, "hp_max": 100.0, "shield": 0.0, "shield_max": 0.0, "tri": "", "xp": 0.0, "dmg": 1, "dead": false, "big": false, "boss": false, "affix": null, "special": special if not special.is_empty() else null, "silencedT": 0.0, "stunT": 0.0, "fearT": 0.0, "sleepT": 0.0, "charmT": 0.0, "slowT": 0.0, "summoner": false, "kit": null, "kitSplit": 0}

func _expect(condition: bool, message: String) -> bool:
	if condition: return true
	push_error(message)
	quit(1)
	return false
