extends SceneTree

const ContentCatalog = preload("res://src/content/content_catalog.gd")
const Mulberry32 = preload("res://src/core/mulberry32.gd")
const BattleRun = preload("res://src/battle/battle_run.gd")
const BattleUlts = preload("res://src/battle/battle_ults.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog = ContentCatalog.new()
	if not _expect(catalog.load_from("res://data/content-v7.19.2.json") == OK, "content must load"):
		return
	if not _test_authority_definitions():
		return
	if not _test_cooldown_and_conditions(catalog):
		return
	if not _test_damage_control_and_support(catalog):
		return
	if not _test_status_consequences(catalog):
		return
	if not _test_persistent_battle_entities(catalog):
		return
	if not _test_targeted_web_geometries(catalog):
		return
	if not _test_unique_projectile_geometries(catalog):
		return
	if not _test_automatic_cast(catalog):
		return
	print("Godot v7.19.2 hero ultimates: PASS")
	quit(0)

func _test_authority_definitions() -> bool:
	var defs: Dictionary = BattleUlts.DEFINITIONS
	var expected := [
		"zhangfei", "zhaoyun", "machao", "huangzhong", "xiahouyuan", "luxun", "guanyu", "lvbu", "zhangliao",
		"taishici", "dianwei", "sunce", "xuchu", "weiyan", "ganning", "diaochan", "zhouyu", "jiangwei",
		"zhugeliang", "caoren", "zhoutai", "huatuo", "xiaoqiao", "lusu", "huanggai", "xuhuang", "daqiao",
		"huangyueying", "caiwenji", "gaoshun", "zhanghe", "zhurong", "wutugu", "pangde", "yanliang",
		"sunshangxiang", "yanyan", "caohong", "xushu", "simayi", "jiaxu", "zuoci", "dengai", "menghuo", "wenchou",
	]
	if not _expect(defs.size() == 45 and expected.all(func(hero_id): return defs.has(hero_id)), "all forty-five Web ultimate definitions must exist"):
		return false
	return _expect(str(defs.zhangfei.name) == "燕人怒喝" and int(defs.zhangfei.cd) == 13 \
		and str(defs.huangzhong.type) == "exec" and int(defs.xiaoqiao.cd) == 20 \
		and str(defs.wenchou.name) == "阵前枭首", "names, categories, and base cooldowns must match the frozen authority")

func _test_cooldown_and_conditions(catalog) -> bool:
	var run = _make_run(catalog, "guanyu")
	var guanyu: Dictionary = run.units()[0]
	if not _expect(float(guanyu.ultCd) >= 12.0 * 0.4 and float(guanyu.ultCd) <= 12.0 * 0.7, "new fighters must start at forty to seventy percent of base ultimate cooldown"):
		return false
	run.buffs.ultHaste = 0.2
	if not _expect(is_equal_approx(run.ult_system.cooldown_max(run, guanyu), 9.6), "ultimate haste must reduce the real cooldown maximum"):
		return false
	run.enemies = [_enemy(guanyu, 0.0, -160.0), _enemy(guanyu, 20.0, -120.0)]
	if not _expect(run.ult_system.is_ready(run, guanyu), "Guan Yu must ready with two enemies in his column"):
		return false
	run.enemies[1].x += 180.0
	if not _expect(not run.ult_system.is_ready(run, guanyu), "Guan Yu must not ready when only one enemy remains in his column"):
		return false
	var duel = _make_run(catalog, "wenchou")
	duel.enemies = [_enemy(duel.units()[0], 0.0, -100.0)]
	if not _expect(not duel.ult_system.is_ready(duel, duel.units()[0]), "Wen Chou requires a duel target"):
		return false
	duel.enemies[0].duelT = 2.0
	return _expect(duel.ult_system.is_ready(duel, duel.units()[0]), "Wen Chou must ready when a duel target exists")

func _test_damage_control_and_support(catalog) -> bool:
	var sniper = _make_run(catalog, "huangzhong")
	var ordinary := _enemy(sniper.units()[0], -80.0, -120.0)
	var elite := _enemy(sniper.units()[0], 80.0, -160.0)
	elite.affix = "frenzy"
	elite.hp = 1000.0
	elite.hp_max = 1000.0
	var big_only := _enemy(sniper.units()[0], 0.0, -190.0)
	big_only.big = true
	big_only.hp = 2000.0
	big_only.hp_max = 2000.0
	sniper.enemies = [ordinary, elite, big_only]
	sniper.ult_system.cast(sniper, sniper.units()[0])
	if not _expect(float(elite.hp) < 1000.0 and is_equal_approx(float(ordinary.hp), 100.0) and is_equal_approx(float(big_only.hp), 2000.0), "Hundred-Pace Shot must select only boss/affix elites and ignore ordinary big-bodied enemies"):
		return false

	var fear = _make_run(catalog, "zhangliao")
	fear.enemies = [_enemy(fear.units()[0], -50.0, -120.0), _enemy(fear.units()[0], 50.0, -150.0)]
	fear.enemies[1].boss = true
	fear.ult_system.cast(fear, fear.units()[0])
	if not _expect(is_equal_approx(float(fear.enemies[0].fearT), 2.5) and is_equal_approx(float(fear.enemies[1].fearT), 1.2), "Xiaoyao Ford must fear ordinary foes for 2.5 seconds and bosses for 1.2"):
		return false

	var healer = _make_run(catalog, "huatuo")
	healer.add_unit_at("zhangfei", 0, 0)
	var hurt: Dictionary = healer.grid[0][0]
	hurt.hp = float(hurt.hp_max) * 0.4
	hurt.sealedT = 3.0
	healer.ult_system.cast(healer, healer.units().filter(func(unit): return str(unit.hero.id) == "huatuo")[0])
	if not _expect(float(hurt.hp) >= float(hurt.hp_max) * 0.75 and float(hurt.sealedT) == 0.0 and is_equal_approx(float(hurt.rbuffs.heal), 6.0), "Qingnang Relief must heal 35%, clear seals, and apply six seconds of medicine fragrance"):
		return false

	var strategist = _make_run(catalog, "simayi")
	strategist.clear_formation()
	strategist.obstacles.clear()
	for index in 5:
		strategist.add_unit_at(["simayi", "zhangfei", "zhaoyun", "machao", "huangzhong"][index], 0, index)
	for unit in strategist.units():
		unit.ultCd = 12.0
	var simayi: Dictionary = strategist.units().filter(func(unit): return str(unit.hero.id) == "simayi")[0]
	strategist.ult_system.cast(strategist, simayi)
	return _expect(strategist.units().filter(func(unit): return unit != simayi and is_equal_approx(float(unit.ultCd), 2.0)).size() == 4 and strategist.skill_lines.size() == 4 and strategist.skill_lines.all(func(line): return is_equal_approx(float(line.t), 0.35)), "Sima Yi must reduce every ally ultimate cooldown by ten seconds and link to all four real ally positions")

func _test_persistent_battle_entities(catalog) -> bool:
	var defense = _make_run(catalog, "xuchu")
	defense.ult_system.cast(defense, defense.units()[0])
	if not _expect(not defense.blockade.is_empty() and is_equal_approx(float(defense.blockade.t), 4.0), "Tiger Bulwark must create a four-second real blockade"):
		return false
	var traps = _make_run(catalog, "weiyan")
	traps.enemies = [_enemy(traps.units()[0], 0.0, -160.0)]
	traps.ult_system.cast(traps, traps.units()[0])
	if not _expect(traps.traps.size() == 3, "Ziwu Ambush must plant three real traps"):
		return false
	var turret = _make_run(catalog, "huangyueying")
	turret.enemies = [_enemy(turret.units()[0], 0.0, -180.0)]
	turret.ult_system.cast(turret, turret.units()[0])
	if not _expect(turret.turrets.size() == 1 and float(turret.turrets[0].t) >= 10.0, "Repeating Crossbow Device must create a ten-second firing turret"):
		return false
	var bomb_lobs = _make_run(catalog, "ganning")
	var bomb_target := _enemy(bomb_lobs.units()[0], 0.0, -180.0)
	bomb_target.hp = 10000.0
	bomb_target.hp_max = 10000.0
	bomb_lobs.enemies = [bomb_target]
	bomb_lobs.ult_system.cast(bomb_lobs, bomb_lobs.units()[0])
	if not _expect(bomb_lobs.friendly_lobs.size() == 5 and is_equal_approx(float(bomb_target.hp), 10000.0), "Gan Ning must throw five visible bombs before their delayed splash damage"):
		return false
	for step in 50:
		bomb_lobs._update_friendly_lobs(0.02)
	if not _expect(bomb_lobs.friendly_lobs.is_empty() and float(bomb_target.hp) < 10000.0, "Gan Ning bombs must damage only when their parabolic throws land"):
		return false
	var fire_lobs = _make_run(catalog, "luxun")
	var fire_target := _enemy(fire_lobs.units()[0], 0.0, -180.0)
	fire_lobs.enemies = [fire_target]
	fire_lobs.ult_system.cast(fire_lobs, fire_lobs.units()[0])
	if not _expect(fire_lobs.friendly_lobs.size() == 3 and fire_lobs.fire_pits.is_empty(), "Lu Xun must throw three visible fire jars before creating fire pits"):
		return false
	for step in 55:
		fire_lobs._update_friendly_lobs(0.02)
	if not _expect(fire_lobs.friendly_lobs.is_empty() and fire_lobs.fire_pits.size() == 3, "each landed fire jar must create one persistent fire pit"):
		return false
	var fire_hp := float(fire_target.hp)
	fire_lobs._update_fire_pits(0.01)
	if not _expect(is_equal_approx(float(fire_target.hp), fire_hp) and float(fire_target.burnT) >= 0.8, "Lu Xun fire pits must apply the Web burn status instead of placeholder direct ticks"):
		return false
	fire_lobs._update_enemies(0.01)
	if not _expect(float(fire_target.hp) < fire_hp, "fire-pit burn must deal damage through the shared burn tick"):
		return false
	var homing = _make_run(catalog, "jiangwei")
	var homing_target := _enemy(homing.units()[0], 0.0, -180.0)
	homing_target.hp = 10000.0
	homing_target.hp_max = 10000.0
	homing_target.affix = "frenzy"
	homing.enemies = [homing_target]
	homing.relic_ids = ["guding"]
	homing.ult_system.cast(homing, homing.units()[0])
	if not _expect(homing.homers.size() == 8 and is_equal_approx(float(homing_target.hp), 10000.0), "Qilin Fire Arrows must launch eight real homing projectiles instead of dealing instant placeholder damage"):
		return false
	var expected_homing_hit := maxi(1, roundi(float(homing.homers[0].damage) * BattleRun.triangle_multiplier(str(homing.homers[0].element), str(homing_target.tri))))
	homing.baihu_ready = true
	for step in 240:
		homing._update_homers(0.02)
	var homing_loss := roundi(10000.0 - float(homing_target.hp))
	if not _expect(homing.homers.is_empty() and homing_loss > 0 and homing_loss % expected_homing_hit == 0 and float(homing_target.burnT) > 0.0, "homing arrows must steer, hit, and ignite without inheriting ordinary-bullet Guding damage (actual=%d base_hit=%d burn=%.2f)" % [homing_loss, expected_homing_hit, float(homing_target.burnT)]):
		return false
	if not _expect(homing.baihu_ready, "skill homers must not consume Baihu's guaranteed ordinary-projectile critical"):
		return false
	var linked = _make_run(catalog, "zhugeliang")
	var shielded := _enemy(linked.units()[0], -30.0, -140.0)
	var partner := _enemy(linked.units()[0], 30.0, -160.0)
	shielded.shield = 20.0
	linked.enemies = [shielded, partner]
	linked.ult_system.cast(linked, linked.units()[0])
	linked.damage_enemy(shielded, 10.0)
	if not _expect(is_equal_approx(float(partner.hp), 100.0), "Eight Trigrams Link must not propagate damage fully absorbed by the primary target's shield"):
		return false
	linked.damage_enemy(shielded, 20.0)
	return _expect(is_equal_approx(float(partner.hp), 94.0), "Eight Trigrams Link must share fifty-five percent of HP damage after shield absorption")

func _test_status_consequences(catalog) -> bool:
	var run = _make_run(catalog, "diaochan")
	var diaochan: Dictionary = run.units()[0]
	var shaman := _enemy(diaochan, 0.0, -300.0)
	shaman.special = "shaman"
	shaman.y = 100.0
	run.enemies = [shaman]
	run._update_enemies(0.01)
	if not _expect(is_equal_approx(float(diaochan.sealedT), 3.0), "an unsilenced shaman must seal a real fighter"):
		return false
	diaochan.sealedT = 0.0
	shaman.sealCastT = 0.0
	run.ult_system.cast(run, diaochan)
	run._update_enemies(0.1)
	if not _expect(float(shaman.silencedT) > 4.8 and is_equal_approx(float(diaochan.sealedT), 0.0), "Closed Moon must suppress a shaman's real seal ability"):
		return false

	var sleeper := _enemy(diaochan, 0.0, -160.0)
	sleeper.base_speed = 100.0
	sleeper.sleepT = 2.0
	run.enemies = [sleeper]
	var y_before := float(sleeper.y)
	run._update_enemies(0.5)
	if not _expect(is_equal_approx(float(sleeper.y), y_before), "sleep must stop real enemy movement"):
		return false
	run.damage_enemy(sleeper, 1.0)
	if not _expect(is_equal_approx(float(sleeper.sleepT), 0.0), "taking damage must wake a sleeping enemy"):
		return false
	sleeper.charmT = 2.0
	var hp_before := float(sleeper.hp)
	run.damage_enemy(sleeper, 10.0)
	if not _expect(is_equal_approx(float(sleeper.hp), hp_before - 13.0), "charm must make a real enemy take thirty percent more damage"):
		return false

	var guard = _make_run(catalog, "caohong")
	guard.clear_formation()
	guard.obstacles.clear()
	guard.add_unit_at("zhangfei", 0, 0)
	guard.add_unit_at("caohong", 0, 1)
	var protected: Dictionary = guard.grid[0][0]
	var caohong: Dictionary = guard.grid[0][1]
	guard.ult_system.cast(guard, caohong)
	var protector_before := float(caohong.hp)
	var protected_before := float(protected.hp)
	guard.hurt_unit(protected, 100, 0, 0)
	return _expect(is_equal_approx(float(caohong.hp), protector_before - 60.0) and float(protected.hp) >= protected_before - 40.0, "Cao Hong's ultimate must redirect sixty percent of adjacent ally damage without killing himself")

func _test_automatic_cast(catalog) -> bool:
	var run = _make_run(catalog, "zhangfei")
	var unit: Dictionary = run.units()[0]
	run.enemies = [
		_enemy(unit, -20.0, -80.0), _enemy(unit, 15.0, -100.0), _enemy(unit, 35.0, -120.0),
	]
	unit.ultCd = 0.0
	run._update_units(0.01)
	if not _expect(run.ult_events.size() == 1 and str(run.ult_events[0].hero_id) == "zhangfei", "a ready ultimate must auto-cast once when its condition is met"):
		return false
	if not _expect(float(unit.ultCd) > 12.9 and run.ults_used == 1, "an automatic cast must reset cooldown and increment the run counter"):
		return false
	var frozen_cd := float(unit.ultCd)
	unit.sealedT = 1.0
	run._update_units(0.5)
	return _expect(is_equal_approx(float(unit.ultCd), frozen_cd), "sealed fighters must not advance their ultimate cooldown")

func _test_unique_projectile_geometries(catalog) -> bool:
	var zhaoyun = _make_run(catalog, "zhaoyun")
	zhaoyun.ult_system.cast(zhaoyun, zhaoyun.units()[0])
	if not _expect(zhaoyun.projectiles.size() == 14 and zhaoyun.projectiles.all(func(projectile): return int(projectile.pierce) == 99), "Seven Probes must launch fourteen independently colliding high-pierce spears"):
		return false
	var xiahouyuan = _make_run(catalog, "xiahouyuan")
	xiahouyuan.ult_system.cast(xiahouyuan, xiahouyuan.units()[0])
	if not _expect(xiahouyuan.projectiles.size() == 1 and int(xiahouyuan.projectiles[0].wall_bounce) == 6 and is_equal_approx(float(xiahouyuan.projectiles[0].life), 5.0), "Continuous Raid must launch a five-second arrow with six wall bounces"):
		return false
	var lvbu = _make_run(catalog, "lvbu")
	var first_target := _enemy(lvbu.units()[0], 0.0, -100.0)
	var second_target := _enemy(lvbu.units()[0], 40.0, -160.0)
	lvbu.enemies = [first_target, second_target]
	lvbu.ult_system.cast(lvbu, lvbu.units()[0])
	if not _expect(lvbu.projectiles.size() == 1 and int(lvbu.projectiles[0].bounces) == 9, "Peerless Halberd must create a projectile with nine enemy bounces"):
		return false
	for step in 80:
		lvbu._update_projectiles(0.02)
	if not _expect(float(first_target.hp) < 100.0 and float(second_target.hp) < 100.0, "Peerless Halberd must redirect after impact and damage a second nearby enemy"):
		return false
	var ram: Dictionary = _enemy(lvbu.units()[0], 0.0, -100.0)
	lvbu.enemies = [ram]
	ram.special = "ram"
	ram.fearT = 2.0
	ram.sleepT = 2.0
	ram.charmT = 2.0
	ram.slowT = 2.0
	ram.stunT = 2.0
	ram.kb = 100.0
	lvbu._update_enemies(0.1)
	return _expect(is_equal_approx(float(ram.fearT), 0.0) and is_equal_approx(float(ram.sleepT), 0.0) and is_equal_approx(float(ram.charmT), 0.0) and float(ram.kb) <= 10.0 and float(ram.stunT) < 1.9, "ram carts must ignore mind control and shake off physical control twice as fast")

func _test_targeted_web_geometries(catalog) -> bool:
	var lightning = _make_run(catalog, "machao")
	var lightning_unit: Dictionary = lightning.units()[0]
	var primary := _enemy(lightning_unit, 0.0, -150.0)
	primary.hp = 1000.0
	primary.hp_max = 1000.0
	lightning.enemies = [primary, _enemy(lightning_unit, -55.0, -185.0), _enemy(lightning_unit, 50.0, -190.0), _enemy(lightning_unit, 85.0, -130.0)]
	lightning.ult_system.cast(lightning, lightning_unit)
	if not _expect(lightning.skill_lines.size() == 4 and lightning.skill_lines.all(func(line): return is_equal_approx(float(line.t), 0.32)), "Ma Chao must draw one target-locked main lightning beam and three real branch beams"):
		return false
	var lightning_edge = _make_run(catalog, "machao")
	var lightning_edge_unit: Dictionary = lightning_edge.units()[0]
	var edge_target := _enemy(lightning_edge_unit, 0.0, -(float(lightning_edge_unit.hero.rng) + 20.0))
	lightning_edge.enemies = [edge_target]
	lightning_edge.ult_system.cast(lightning_edge, lightning_edge_unit)
	if not _expect(lightning_edge.skill_lines.size() == 1 and float(edge_target.hp) < 100.0, "Ma Chao's main lightning search must use the Web attack range plus forty pixels"):
		return false
	var sniper = _make_run(catalog, "huangzhong")
	var sniper_unit: Dictionary = sniper.units()[0]
	var elite := _enemy(sniper_unit, 70.0, -170.0)
	elite.affix = "frenzy"
	elite.hp = 800.0
	elite.hp_max = 800.0
	sniper.enemies = [elite]
	sniper.ult_system.cast(sniper, sniper_unit)
	if not _expect(sniper.skill_lines.size() == 1 and sniper.skill_lines[0].to == Vector2(float(elite.x), float(elite.y)) and is_equal_approx(float(sniper.skill_lines[0].t), 0.35), "Huang Zhong must draw the Web beam to the actual selected elite"):
		return false
	var guanyu = _make_run(catalog, "guanyu")
	var guanyu_unit: Dictionary = guanyu.units()[0]
	var guanyu_offlane := _enemy(guanyu_unit, 55.0, -150.0)
	guanyu.enemies = [_enemy(guanyu_unit, 0.0, -150.0), guanyu_offlane]
	guanyu.ult_system.cast(guanyu, guanyu_unit)
	if not _expect(guanyu.skill_lines.size() == 1 and is_equal_approx(float(guanyu.skill_lines[0].to.y), 20.0) and is_equal_approx(float(guanyu.skill_lines[0].width), 3.0) and is_equal_approx(float(guanyu_offlane.hp), 100.0), "Guan Yu must draw and damage only within the Web lane half-width of fifty pixels"):
		return false
	var pangde = _make_run(catalog, "pangde")
	var pangde_unit: Dictionary = pangde.units()[0]
	var pangde_offlane := _enemy(pangde_unit, 50.0, -150.0)
	pangde.enemies = [_enemy(pangde_unit, 0.0, -150.0), pangde_offlane]
	pangde.ult_system.cast(pangde, pangde_unit)
	if not _expect(pangde.skill_lines.size() == 1 and is_equal_approx(float(pangde.skill_lines[0].to.y), 40.0) and is_equal_approx(float(pangde.skill_lines[0].width), 4.0) and is_equal_approx(float(pangde_offlane.hp), 100.0), "Pang De must draw and damage only within the Web lane half-width of forty-six pixels"):
		return false
	var cleave = _make_run(catalog, "dianwei")
	var cleave_unit: Dictionary = cleave.units()[0]
	var cleave_target := _enemy(cleave_unit, 0.0, -120.0)
	cleave.enemies = [cleave_target]
	cleave.ult_system.cast(cleave, cleave_unit)
	if not _expect(cleave.skill_lines.size() == 1 and str(cleave.skill_lines[0].kind) == "slash" and cleave.skill_lines[0].to == Vector2(float(cleave_target.x), float(cleave_target.y)) and is_equal_approx(float(cleave.skill_lines[0].t), 0.18), "Dian Wei must slash toward the actual foremost target before the impact burst"):
		return false
	var cleave_edge = _make_run(catalog, "dianwei")
	var cleave_edge_unit: Dictionary = cleave_edge.units()[0]
	var cleave_edge_target := _enemy(cleave_edge_unit, 0.0, -(float(cleave_edge_unit.hero.rng) + 20.0))
	cleave_edge.enemies = [cleave_edge_target]
	cleave_edge.ult_system.cast(cleave_edge, cleave_edge_unit)
	if not _expect(cleave_edge.skill_lines.size() == 1 and float(cleave_edge_target.hp) < 100.0, "Dian Wei's foremost-target search must use the Web attack range plus forty pixels"):
		return false
	var row_strike = _make_run(catalog, "dengai")
	var row_unit: Dictionary = row_strike.units()[0]
	row_strike.enemies = [_enemy(row_unit, 0.0, 0.0)]
	row_strike.ult_system.cast(row_strike, row_unit)
	if not _expect(row_strike.skill_lines.size() == 1 and is_equal_approx(float(row_strike.skill_lines[0].from.x), 10.0) and is_equal_approx(float(row_strike.skill_lines[0].to.x), 470.0) and is_equal_approx(float(row_strike.skill_lines[0].t), 0.22), "Deng Ai must draw the exact full-width row slash at his row height"):
		return false
	var duel = _make_run(catalog, "wenchou")
	var duel_unit: Dictionary = duel.units()[0]
	var duel_target := _enemy(duel_unit, 30.0, -150.0)
	duel_target.duelT = 2.0
	duel.enemies = [duel_target]
	duel.ult_system.cast(duel, duel_unit)
	if not _expect(duel.skill_lines.size() == 1 and str(duel.skill_lines[0].kind) == "slash" and duel.skill_lines[0].to == Vector2(float(duel_target.x), float(duel_target.y)) and is_equal_approx(float(duel.skill_lines[0].t), 0.2), "Wen Chou must draw the duel execution slash to the real marked target"):
		return false
	var fire_line = _make_run(catalog, "zhouyu")
	var fire_unit: Dictionary = fire_line.units()[0]
	var fire_a := _enemy(fire_unit, -80.0, -180.0)
	var fire_b := _enemy(fire_unit, 30.0, -170.0)
	var fire_c := _enemy(fire_unit, 90.0, -80.0)
	fire_line.enemies = [fire_a, fire_b, fire_c]
	fire_line.ult_system.cast(fire_line, fire_unit)
	if not _expect(fire_line.skill_lines.size() == 1 and fire_line.skill_lines[0].from == Vector2(0.0, float(fire_a.y)) and fire_line.skill_lines[0].to == Vector2(480.0, float(fire_a.y)) and is_equal_approx(float(fire_line.skill_lines[0].t), 0.4), "Zhou Yu must draw the Web full-width fire beam across the densest enemy row"):
		return false
	var rainy_fire = _make_run(catalog, "zhouyu")
	var rainy_unit: Dictionary = rainy_fire.units()[0]
	var rainy_target := _enemy(rainy_unit, 0.0, -180.0)
	rainy_fire.enemies = [rainy_target]
	rainy_fire.mutations[rainy_fire.wave] = "rainstorm"
	rainy_fire.ult_system.cast(rainy_fire, rainy_unit)
	if not _expect(float(rainy_target.hp) < 100.0 and is_equal_approx(float(rainy_target.burnT), 0.0), "rainstorm must suppress Zhou Yu's ignition without suppressing the initial fire-line hit"):
		return false
	var gather = _make_run(catalog, "gaoshun")
	var gather_unit: Dictionary = gather.units()[0]
	var edge_boss := _enemy(gather_unit, 0.0, -120.0)
	edge_boss.x = 100.0
	edge_boss.r = 150.0
	edge_boss.boss = true
	gather.enemies = [_enemy(gather_unit, -90.0, -160.0), _enemy(gather_unit, 90.0, -130.0), _enemy(gather_unit, 0.0, -190.0), edge_boss]
	gather.ult_system.cast(gather, gather_unit)
	if not _expect(gather.skill_lines.size() == 4 and gather.skill_lines.all(func(line): return line.from == BattleRun.slot_center(int(gather_unit.row), int(gather_unit.col)) - Vector2(0, 18) and is_equal_approx(float(line.t), 0.25)) and is_equal_approx(float(edge_boss.x), float(edge_boss.r)), "Gao Shun must draw one pull beam per moved target and clamp an edge boss inside its own Web radius boundary (lines=%d x=%.2f r=%.2f)" % [gather.skill_lines.size(), float(edge_boss.x), float(edge_boss.r)]) :
		return false
	var arrows = _make_run(catalog, "taishici")
	var arrow_unit: Dictionary = arrows.units()[0]
	for index in 5:
		arrows.enemies.append(_enemy(arrow_unit, (index - 2) * 20.0, -170.0 + (index % 2) * 15.0))
	arrows.ult_system.cast(arrows, arrow_unit)
	if not _expect(arrows.friendly_lobs.size() == 10 and arrows.friendly_lobs.all(func(lob): return float(lob.y0) == -20.0 and float(lob.dur) >= 0.25 and float(lob.dur) <= 0.5), "Taishi Ci must create ten independently timed falling-arrow trajectories over the densest cluster"):
		return false
	var turret = _make_run(catalog, "huangyueying")
	var turret_unit: Dictionary = turret.units()[0]
	turret.enemies = [_enemy(turret_unit, 0.0, -180.0)]
	turret.ult_system.cast(turret, turret_unit)
	return _expect(turret.turrets.size() == 1 and turret.friendly_lobs.size() == 1 and is_equal_approx(float(turret.friendly_lobs[0].dur), 0.5), "Huang Yueying must visibly throw the repeating-crossbow device to its real deployment point")

func _make_run(catalog, hero_id: String):
	var run = BattleRun.new(catalog, Mulberry32.new(7192))
	run.start(_base_city(), "caocao", hero_id)
	run.obstacles.clear()
	return run

func _enemy(unit: Dictionary, dx: float, dy: float) -> Dictionary:
	var center := BattleRun.slot_center(int(unit.row), int(unit.col))
	return {
		"x": center.x + dx, "y": center.y + dy, "r": 18.0, "base_speed": 0.0,
		"hp": 100.0, "hp_max": 100.0, "tri": "badao", "xp": 0.0,
		"dmg": 1, "dead": false, "big": false, "boss": false, "affix": null, "special": null,
		"slowT": 0.0, "burnT": 0.0, "burnDmg": 0.0, "shield": 0.0, "stunT": 0.0,
		"fearT": 0.0, "sleepT": 0.0, "charmT": 0.0, "silencedT": 0.0, "duelT": 0.0,
	}

func _base_city() -> Dictionary:
	return {"week": 2948, "k": 0, "ch": 1, "wall": 20, "theme": "", "field": "", "hpMul": 1.0, "spdMul": 1.0, "hpGrow": 1.1, "affixAdd": 0.0, "killTarget": 450, "obstacles": 0, "foes": {"tri": "badao"}}

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
