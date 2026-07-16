extends SceneTree

const ContentCatalog = preload("res://src/content/content_catalog.gd")
const Mulberry32 = preload("res://src/core/mulberry32.gd")
const BattleRun = preload("res://src/battle/battle_run.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog = ContentCatalog.new()
	if not _expect(catalog.load_from("res://data/content-v7.19.14.json") == OK, "v7.19.14 content must load"):
		return
	if not _test_single_target_formula(catalog):
		return
	if not _test_attack_patterns(catalog):
		return
	if not _test_gongsunzan_wall_scaled_crossbow(catalog):
		return
	if not _test_kin_power_and_interval(catalog):
		return
	if not _test_command_identity_and_initial_cooldown(catalog):
		return
	if not _test_opening_passives(catalog):
		return
	if not _test_wuxing_and_bingfeng(catalog):
		return
	if not _test_taoyuan_and_jiejiang(catalog):
		return
	if not _test_mensheng_and_baima(catalog):
		return
	if not _test_fenluo_and_jianhao(catalog):
		return
	if not _test_gewu_lockout(catalog):
		return
	print("Godot v7.19.14 ruler auto attacks: PASS")
	quit(0)

func _test_single_target_formula(catalog) -> bool:
	for ruler_id in ["caocao", "yuanshao", "yuanshu"]:
		var run = _make_run(catalog, ruler_id)
		var rear := _enemy(120.0, 260.0)
		var deepest := _enemy(220.0, 400.0)
		run.enemies = [rear, deepest]
		run.lord_attack_timer = 0.0
		run._update_lord_auto_attack(0.01)
		if not _expect(is_equal_approx(float(deepest.hp), 959.0), "%s must deal round(((7 + wave*.75) + 3%% max HP) * 1.02) at ruler level 1" % ruler_id):
			return false
		if not _expect(is_equal_approx(float(rear.hp), 1000.0), "%s must hit only the deepest enemy" % ruler_id):
			return false
	return true

func _test_attack_patterns(catalog) -> bool:
	var sunquan = _make_run(catalog, "sunquan")
	var sun_targets := [_enemy(80, 410), _enemy(180, 390), _enemy(280, 370), _enemy(380, 350)]
	sunquan.enemies = sun_targets
	sunquan.lord_attack_timer = 0.0
	sunquan._update_lord_auto_attack(0.01)
	if not _expect(_damaged_count(sun_targets) == 3 and is_equal_approx(float(sun_targets[3].hp), 1000.0), "Sun Quan must fire three full-damage water bolts at the three deepest enemies"):
		return false

	var liubiao = _make_run(catalog, "liubiao")
	var frost_targets := [_enemy(200, 400), _enemy(250, 430), _enemy(360, 400)]
	liubiao.enemies = frost_targets
	liubiao.lord_attack_timer = 0.0
	liubiao._update_lord_auto_attack(0.01)
	if not _expect(_damaged_count(frost_targets) == 2 and float(frost_targets[0].slowT) == 1.2 and float(frost_targets[1].slowT) == 1.2, "Liu Biao must damage and slow enemies inside the target's 80px frost burst"):
		return false

	var liubei = _make_run(catalog, "liubei")
	var slash_targets := [_enemy(220, 440), _enemy(270, 420), _enemy(310, 430), _enemy(150, 405), _enemy(220, 330)]
	liubei.enemies = slash_targets
	liubei.lord_attack_timer = 0.0
	liubei._update_lord_auto_attack(0.01)
	if not _expect(_damaged_count(slash_targets) == 4 and is_equal_approx(float(slash_targets[4].hp), 1000.0), "Liu Bei must sweep at most four enemies within 90px horizontally and 40px vertically"):
		return false

	var dongzhuo = _make_run(catalog, "dongzhuo")
	var fire_targets := [_enemy(220, 400), _enemy(260, 430), _enemy(360, 400)]
	dongzhuo.enemies = fire_targets
	dongzhuo.lord_attack_timer = 0.0
	dongzhuo._update_lord_auto_attack(0.01)
	if not _expect(_damaged_count(fire_targets) == 2 and float(fire_targets[0].burnT) == 2.0 and float(fire_targets[1].burnDmg) == 3.6, "Dong Zhuo must splash within 65px and apply the Web two-second burn"):
		return false
	var hp_after_impact := float(fire_targets[0].hp)
	dongzhuo._update_enemies(0.01)
	return _expect(float(fire_targets[0].hp) == hp_after_impact - 4.0, "a fresh lord burn must tick immediately for round(burnDmg), then every 0.5 seconds")

func _test_gongsunzan_wall_scaled_crossbow(catalog) -> bool:
	var run = _make_run(catalog, "gongsunzan")
	run.wall = 10
	run.wall_max = 20
	var target := _enemy(220, 400)
	run.enemies = [target]
	run.lord_attack_timer = 0.0
	run._update_lord_auto_attack(0.01)
	if not _expect(is_equal_approx(float(target.hp), 971.0), "Gongsun Zan crossbow damage must scale by current wall ratio and its x1.4 multiplier"):
		return false
	if not _expect(is_equal_approx(run.lord_attack_timer, 2.5), "Gongsun Zan must use the 2.5-second crossbow interval"):
		return false
	var bounty := _enemy(220, 400)
	bounty.hp = 1.0
	bounty.xp = 2.0
	run.enemies = [bounty]
	run.lord_attack_timer = 0.0
	run._update_lord_auto_attack(0.01)
	return _expect(is_equal_approx(run.xp, 6.0), "a strong-crossbow execution must grant Gongsun Zan's x3 lord-kill XP")

func _test_kin_power_and_interval(catalog) -> bool:
	var run = _make_run(catalog, "caocao")
	run.add_unit_at("caoren", 0, 0)
	run.add_unit_at("jiaxu", 0, 1)
	if not _expect(is_equal_approx(run.lord_kin_power(), 1.4), "two ruler kin, including universal Jia Xu, must provide x1.4 lord power"):
		return false
	run.lord_atk_gap = 0.75
	run.enemies = [_enemy(220, 400)]
	run.lord_attack_timer = 0.0
	run._update_lord_auto_attack(0.01)
	return _expect(is_equal_approx(run.lord_attack_timer, 2.25), "lord attack haste must multiply the normal three-second interval")

func _test_command_identity_and_initial_cooldown(catalog) -> bool:
	var expected := {
		"caocao": "wuxing", "liubei": "taoyuan", "sunquan": "jiejiang", "yuanshao": "mensheng",
		"liubiao": "bingfeng", "gongsunzan": "baima", "dongzhuo": "fenluo", "yuanshu": "jianhao",
	}
	for ruler_id in expected:
		var run = _make_run(catalog, ruler_id)
		if not _expect(run.lord_skill_id == expected[ruler_id] and run.lord_skill_level == 1, "%s must start with its current level-one signature command" % ruler_id):
			return false
		if not _expect(is_equal_approx(run.lord_command_cd, 18.0), "every ruler command must start on the Web 18-second opening cooldown"):
			return false
	var leveled = BattleRun.new(catalog, Mulberry32.new(7192))
	leveled.start(_base_city(), "caocao", "zhangfei", 17)
	if not _expect(leveled.lord_skill_level == 3, "ruler meta levels 1/9/17 must map signature power to levels 1/2/3"):
		return false
	leveled.lord_command_cd = 0.0
	return _expect(is_equal_approx(leveled.lord_command_cooldown_max(), 25.2), "Cao Cao level 17 must unlock four Supply ranks and reduce a 30-second command cooldown by 16%")

func _test_opening_passives(catalog) -> bool:
	var liubei = BattleRun.new(catalog, Mulberry32.new(71914))
	liubei.start(_base_city(), "liubei", "zhangfei", 1)
	if not _expect(liubei.wall == 21 and liubei.wall_max == 21, "level-one Liu Bei must apply one rank of City Defense to the opening wall"):
		return false
	var yuanshao = BattleRun.new(catalog, Mulberry32.new(71915))
	yuanshao.start(_base_city(), "yuanshao", "zhangfei", 2)
	if not _expect(is_equal_approx(yuanshao.xp, 10.0) and is_equal_approx(float(yuanshao.buffs.xpGain), 1.04), "Yuan Shao opening passives must apply Veteran XP and Farm XP gain"):
		return false
	var sunquan = BattleRun.new(catalog, Mulberry32.new(71916))
	sunquan.start(_base_city(), "sunquan", "zhangfei", 4)
	return _expect(sunquan.wall_shield == 2, "Sun Quan level four must apply one rank of opening wall shield")

func _test_wuxing_and_bingfeng(catalog) -> bool:
	var caocao = _make_run(catalog, "caocao")
	caocao.enemies = _enemy_line(8)
	caocao.lord_command_cd = 0.0
	if not _expect(caocao.lord_command_auto_ready(), "Wuxing must auto-ready at eight living enemies"):
		return false
	caocao.lord_system.update_command(caocao, 0.01)
	if not _expect(is_equal_approx(caocao.wuxing_time, 8.0) and is_equal_approx(caocao.lord_command_cd, 30.0), "level-one Wuxing must auto-cast, open an eight-second window, and lock the shared cooldown for 30 seconds"):
		return false
	var countered: Dictionary = caocao.enemies[0]
	countered.tri = "badao"
	var dealt: int = caocao.damage_enemy(countered, 10.0, "liangmou")
	if not _expect(dealt == 12, "Wuxing must remove the x0.6 countered penalty and then add 15% damage"):
		return false
	var neutral := _enemy(160, 340)
	neutral.tri = "badao"
	caocao.enemies.append(neutral)
	if not _expect(caocao.damage_enemy(neutral, 10.0, "badao") == 12, "Wuxing must add 15% to same-element damage too"):
		return false
	var advantaged := _enemy(220, 340)
	advantaged.tri = "badao"
	caocao.enemies.append(advantaged)
	if not _expect(caocao.damage_enemy(advantaged, 10.0, "rende") == 17, "Wuxing must preserve a real x1.5 counter and add 15% on top"):
		return false

	var liubiao = _make_run(catalog, "liubiao")
	liubiao.enemies = _enemy_line(6)
	liubiao.enemies[0].boss = true
	liubiao.lord_command_cd = 0.0
	if not _expect(liubiao.lord_command_auto_ready() and liubiao.cast_lord_command(), "Bingfeng must auto-cast at six living enemies"):
		return false
	return _expect(is_equal_approx(float(liubiao.enemies[0].stunT), 1.02) and is_equal_approx(float(liubiao.enemies[1].stunT), 1.7), "level-one Bingfeng must stun ordinary enemies 1.7s and bosses for 60% duration")

func _test_taoyuan_and_jiejiang(catalog) -> bool:
	var liubei = _make_run(catalog, "liubei")
	liubei.add_unit_at("caoren", 0, 2)
	var unit: Dictionary = liubei.grid[0][2]
	unit.hp = float(unit.hp_max) * 0.5
	liubei.enemies = [_enemy(220, 300)]
	var boss := _enemy(300, 300)
	boss.boss = true
	liubei.enemies.append(boss)
	liubei.lord_command_cd = 0.0
	if not _expect(liubei.lord_command_auto_ready() and liubei.cast_lord_command(), "Taoyuan must auto-ready when a fighter drops below 55% HP"):
		return false
	if not _expect(is_equal_approx(liubei.taoyuan_time, 6.0), "level-one Taoyuan must grant six seconds of formation immunity"):
		return false
	liubei.hurt_unit(unit, 11, 0, 2)
	var enemy_hp := float(liubei.enemies[0].hp)
	liubei.lord_system.update_effects(liubei, 6.01)
	if not _expect(is_equal_approx(float(liubei.enemies[0].hp), enemy_hp - 11.0) and float(liubei.enemies[0].stunT) == 1.0, "Taoyuan expiry must return all absorbed damage to every enemy and stun them for one second"):
		return false
	if not _expect(is_equal_approx(float(liubei.enemies[0].get("kb", 0.0)), 90.0) and is_equal_approx(float(boss.get("kb", 0.0)), 22.5), "Taoyuan counter must knock ordinary enemies back 90px and bosses by one quarter"):
		return false

	var sunquan = _make_run(catalog, "sunquan")
	var river_enemy := _enemy(220, 370)
	sunquan.enemies = [river_enemy, _enemy(120, 350), _enemy(320, 390), _enemy(400, 410)]
	sunquan.lord_command_cd = 0.0
	if not _expect(sunquan.lord_command_auto_ready() and sunquan.cast_lord_command(), "Jiejiang must auto-ready when four enemies enter the river band"):
		return false
	if not _expect(is_equal_approx(float(sunquan.flood.t), 7.0) and is_equal_approx(float(sunquan.flood.amp), 0.3), "level-one Jiejiang must create a seven-second, +30% damage river"):
		return false
	if not _expect(sunquan.damage_enemy(river_enemy, 10.0) == 13, "an enemy inside Jiejiang must take 30% extra damage"):
		return false
	var empty_river = _make_run(catalog, "sunquan")
	empty_river.lord_command_cd = 0.0
	return _expect(empty_river.cast_lord_command() and not empty_river.flood.is_empty(), "manual Jiejiang must follow Web and allow laying the river before enemies enter")

func _test_mensheng_and_baima(catalog) -> bool:
	var yuanshao = _make_run(catalog, "yuanshao")
	yuanshao.wave = 2
	yuanshao.lord_command_cd = 0.0
	if not _expect(yuanshao.lord_command_auto_ready() and yuanshao.cast_lord_command(), "Mensheng must auto-ready from wave two when no widened draft is banked"):
		return false
	if not _expect(yuanshao.wide_picks == 1, "level-one Mensheng must bank one five-choice growth draft"):
		return false
	yuanshao.gain_xp(10.0)
	if not _expect(yuanshao.card_choices.size() == 5 and yuanshao.wide_picks == 0, "a banked Mensheng use must make the next growth draft five choices and then consume itself"):
		return false

	var gongsunzan = _make_run(catalog, "gongsunzan")
	gongsunzan.wave = 4
	var special := _enemy(80, 180)
	special.special = "shooter"
	var ordinary := _enemy(240, 400)
	ordinary.special = null
	gongsunzan.enemies = [ordinary]
	if not _expect(not gongsunzan.lord_command_auto_ready(), "a real ordinary enemy with special=null must not trigger Baima"):
		return false
	gongsunzan.enemies = [ordinary, special]
	gongsunzan.lord_command_cd = 0.0
	if not _expect(gongsunzan.lord_command_auto_ready() and gongsunzan.cast_lord_command(), "Baima must prioritize the presence of a special enemy"):
		return false
	if not _expect(is_equal_approx(float(gongsunzan.lord_mount.t), 7.0) and is_equal_approx(float(gongsunzan.lord_mount.damage), 42.0), "level-one Baima must last seven seconds and use (20 + wave*2.5) * 1.4 damage"):
		return false
	gongsunzan.lord_mount.x = float(special.x)
	gongsunzan.lord_mount.y = float(special.y)
	var hp_before := float(special.hp)
	gongsunzan.lord_system.update_effects(gongsunzan, 0.01)
	if not _expect(float(special.hp) == hp_before - 42.0, "Baima must attack a reached special target on its 0.35-second strike cadence"):
		return false
	var bounty := _enemy(float(gongsunzan.lord_mount.x), float(gongsunzan.lord_mount.y))
	bounty.hp = 1.0
	bounty.xp = 2.0
	bounty.special = "shooter"
	gongsunzan.enemies = [bounty]
	gongsunzan.lord_mount.hitT = 0.0
	gongsunzan.lord_system.update_effects(gongsunzan, 0.01)
	return _expect(is_equal_approx(gongsunzan.xp, 6.0), "a Baima execution must grant Gongsun Zan's x3 lord-kill XP")

func _test_fenluo_and_jianhao(catalog) -> bool:
	var dongzhuo = _make_run(catalog, "dongzhuo")
	dongzhuo.enemies = _enemy_line(6)
	dongzhuo.wall = 10
	dongzhuo.lord_command_cd = 0.0
	if not _expect(dongzhuo.lord_command_auto_ready() and dongzhuo.cast_lord_command(), "Fenluo must auto-ready with six enemies and at least five wall HP"):
		return false
	if not _expect(dongzhuo.wall == 8 and is_equal_approx(dongzhuo.tyranny, 8.0), "Fenluo must burn two wall HP and grant a permanent +8% army damage tyranny mark"):
		return false
	if not _expect(dongzhuo.enemies.all(func(enemy): return float(enemy.burnT) == 3.0), "Fenluo must ignite every enemy inside its wall-origin cone for three seconds"):
		return false

	var yuanshu = _make_run(catalog, "yuanshu")
	for index in 5:
		yuanshu.add_unit_at(["zhangfei", "zhaoyun", "machao", "huangzhong", "xiahouyuan"][index], index / 5, index % 5)
	var sacrifice: Dictionary = yuanshu.grid[0][0]
	sacrifice.level = 1
	# Jianhao promises exact level counts even when both farm and battlefield XP bonuses are active.
	yuanshu.buffs.xpGain = 1.2
	yuanshu.city.field = "guandu"
	yuanshu.xp = 2.5
	yuanshu.lord_command_cd = 0.0
	if not _expect(yuanshu.lord_command_auto_ready() and yuanshu.cast_lord_command(), "Jianhao must require five fighters and a sacrifice at three stars or below"):
		return false
	if not _expect(yuanshu.units().size() == 4 and yuanshu.level == 4 and yuanshu.jianhao_count == 1, "level-one Jianhao must consume a one-star fighter and grant exactly three levels despite XP multipliers"):
		return false
	yuanshu.lord_command_cd = 0.0
	if not _expect(is_equal_approx(yuanshu.lord_command_cooldown_max(), 57.0), "each Jianhao sacrifice must add twelve seconds to its next cooldown"):
		return false

	var sorted = BattleRun.new(catalog, Mulberry32.new(7192))
	sorted.start(_base_city(), "yuanshu", "zhangfei", 1, {
		"zhangfei": 9, "zhaoyun": 8, "machao": 7, "huangzhong": 6, "xiahouyuan": 1,
	})
	sorted.clear_formation()
	for index in 5:
		sorted.add_unit_at(["zhangfei", "zhaoyun", "machao", "huangzhong", "xiahouyuan"][index], index / 5, index % 5)
	return _expect(str(sorted.lord_system.jianhao_target(sorted).hero.id) == "xiahouyuan", "Jianhao equal-star ties must sacrifice the lowest out-of-run hero level")

func _test_gewu_lockout(catalog) -> bool:
	var run = _make_run(catalog, "caocao")
	run.enemies = _enemy_line(8)
	run.lord_command_cd = 0.0
	run.lord_attack_timer = 0.0
	var unit: Dictionary = run.units()[0] if not run.units().is_empty() else {}
	if unit.is_empty():
		run.add_unit_at("zhangfei", 0, 0)
		unit = run.units()[0]
	var base_damage: float = float(run.team.unit_mods(run, unit).dmgMul)
	run.permanent_tactics.gewu = true
	if not _expect(not run.cast_lord_command(), "Gewu must reject direct and automatic lord commands"):
		return false
	var hp_before := float(run.enemies[0].hp)
	run._update_lord_auto_attack(0.1)
	if not _expect(float(run.enemies[0].hp) == hp_before, "Gewu must stop the seven ordinary ruler auto attacks"):
		return false
	if not _expect(is_equal_approx(float(run.team.unit_mods(run, unit).dmgMul), base_damage * 1.3), "Gewu must multiply real army damage by 1.3"):
		return false
	var yuanshu = _make_run(catalog, "yuanshu")
	for index in 5:
		yuanshu.add_unit_at(["zhangfei", "zhaoyun", "machao", "huangzhong", "xiahouyuan"][index], index / 5, index % 5)
	yuanshu.permanent_tactics.gewu = true
	yuanshu.lord_command_cd = 0.0
	return _expect(yuanshu.cast_lord_command(), "Web v7.19.12 must keep Jianhao available during Gewu so its auto-draft economy still has fuel")

func _make_run(catalog, ruler_id: String):
	var run = BattleRun.new(catalog, Mulberry32.new(7192))
	run.start(_base_city(), ruler_id, "zhangfei", 1)
	run.clear_formation()
	run.obstacles.clear()
	run.traits.clear()
	run.wave = 4
	return run

func _enemy(x: float, y: float) -> Dictionary:
	return {
		"x": x, "y": y, "r": 18.0, "base_speed": 0.0,
		"hp": 1000.0, "hp_max": 1000.0, "tri": "badao", "xp": 0.0,
		"dmg": 1, "dead": false, "big": false, "boss": false,
		"slowT": 0.0, "burnT": 0.0, "burnDmg": 0.0,
	}

func _enemy_line(count: int) -> Array:
	var result := []
	for index in count:
		result.append(_enemy(40.0 + index * 50.0, 340.0 + index * 4.0))
	return result

func _damaged_count(targets: Array) -> int:
	return targets.filter(func(enemy): return float(enemy.hp) < float(enemy.hp_max)).size()

func _base_city() -> Dictionary:
	return {"ch": 1, "wall": 20, "theme": "", "field": "", "hpMul": 1.0, "spdMul": 1.0, "hpGrow": 1.1, "affixAdd": 0.0, "killTarget": 450, "obstacles": 0, "foes": {"tri": ""}}

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
