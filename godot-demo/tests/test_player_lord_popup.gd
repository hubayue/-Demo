extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	main.advance_from_title()
	main.select_city(0)
	main.select_ruler("liubei")
	main.select_opening_hero("zhaoyun")
	main.set_process(false)
	var run = main.battle_run
	run.clear_formation()
	run.obstacles.clear()
	run.add_unit_at("zhaoyun", 2, 2)
	run.add_unit_at("zhangfei", 1, 2)
	run.wave = 1
	run.lord_command_cd = 0.0
	run.lord_command_cd_total = 55.0
	main.battle_field_banner_time = 0.0

	if not _expect(main.LORD_NAME_RECT == Rect2(410, 178, 64, 24) and main.LORD_COMMAND_RECT == Rect2(414, 208, 56, 58), "player lord nameplate and command hitboxes must match Web v7.19.14"):
		return
	var used_before := int(run.lord_command_used)
	main.unit_info_popup = {"unit": run.grid[2][2], "row": 2, "col": 2}
	main._handle_pointer(main.LORD_NAME_RECT.get_center())
	if not _expect(main.player_lord_popup_is_visible() and int(run.lord_command_used) == used_before and main._battle_overlay_layers() == ["unit_info", "player_lord"], "clicking the lord nameplate must open above an existing unit panel without casting"):
		return
	var spec: Dictionary = main.player_lord_popup_spec()
	if not _expect(spec.rect == Rect2(65, 150, 350, 288) and spec.cast_rect == Rect2(297, 374, 100, 30), "single-command lord panel and ready cast button must use exact Web geometry"):
		return
	if not _expect(str(spec.title) == "👑 刘备 · 仁德载世" and str(spec.subtitle) == "大招自动释放：CD转好、时机一到主公自己放，不用盯", "lord panel heading must preserve the Web title and automation promise"):
		return
	if not _expect(str(spec.attack_line).contains("普攻「双股剑气」每3.0秒") and str(spec.attack_detail).begins_with("群体：横扫剑光"), "lord panel must expose current basic-attack cadence and targeting method"):
		return
	if not _expect(str(spec.command_name) == "桃园义" and str(spec.command_desc).begins_with("全军金身6秒刀枪不入") and str(spec.auto_tip).contains("有兄弟掉到半血"), "lord panel must expose exact command effect and automatic timing"):
		return
	if not _expect(str(spec.cooldown_line).contains("冷却 55 秒") and str(spec.cooldown_line).contains("🤝亲兵助威 ×1.2"), "lord panel must show live cooldown and kin multiplier"):
		return
	var visual: Dictionary = main.lord_command_visual_spec()
	if not _expect(bool(visual.ready) and str(visual.stars) == "●○○" and is_equal_approx(float(visual.cooldown_fraction), 0.0), "ready command HUD must expose Web star track and empty cooldown sector"):
		return

	var wave_timer_before := float(run.wave_timer)
	var game_time_before := float(run.game_time)
	run.field_events = [{"kind": "shield_counter", "label": "蓄势反击!", "x": 240.0, "y": 400.0, "t": 0.5}]
	run.lord_command_events = [{"id": "taoyuan", "t": 0.5}]
	main._process(0.25)
	if not _expect(is_equal_approx(float(run.wave_timer), wave_timer_before) and is_equal_approx(float(run.game_time), game_time_before + 0.25) and is_equal_approx(float(run.field_events[0].t), 0.25) and is_equal_approx(float(run.lord_command_events[0].t), 0.25), "open lord panel must pause combat while every Web visual event continues"):
		return

	main._handle_pointer(Vector2(20, 300))
	if not _expect(not main.player_lord_popup_is_visible() and main.unit_info_popup_is_visible(), "clicking outside the lord panel must close it and reveal the paused unit panel below"):
		return
	main._handle_pointer(main.LORD_COMMAND_RECT.get_center())
	if not _expect(main.player_lord_popup_is_visible() and not main.unit_info_popup_is_visible() and int(run.lord_command_used) == used_before, "clicking the circular command must close unit inspection and open lord inspection instead of direct-casting"):
		return
	run.enemies = [{
		"dead": false, "x": 240.0, "y": 240.0, "r": 16.0,
		"hp": 100.0, "hp_max": 100.0, "tri": "badao", "cls": "spear",
		"big": false, "boss": false, "affix": null, "special": null,
	}]
	main._handle_pointer(main.player_lord_popup_spec().cast_rect.get_center())
	if not _expect(not main.player_lord_popup_is_visible() and int(run.lord_command_used) == used_before + 1 and float(run.lord_command_cd) > 0.0, "only the ready panel button may perform a manual command cast"):
		return
	run.lord_command_events.clear()
	run.enemies.clear()
	run.taoyuan_time = 0.0
	run.lord_skill_id = "taoyuan"
	if not _expect_manual_block(main, run, "🍑桃园义：场上没贼，时机一到自动放"):
		return
	run.enemies = [{"dead": false, "x": 240.0, "y": 240.0, "r": 16.0, "hp": 100.0, "hp_max": 100.0, "tri": "badao", "cls": "spear", "big": false, "boss": false, "affix": null, "special": null}]
	run.taoyuan_time = 2.0
	if not _expect_manual_block(main, run, "🍑 金身还护着呢，不用叠"):
		return
	run.taoyuan_time = 0.0
	run.lord_skill_id = "mensheng"
	run.wide_picks = 1
	if not _expect_manual_block(main, run, "📜 门路还没用完：还有1次五选一，升级选卡就见"):
		return
	run.wide_picks = 0
	run.lord_skill_id = "fenluo"
	run.wall = 2
	if not _expect_manual_block(main, run, "🔥 城墙都快塌了，烧不得（城血≥3才能点火）"):
		return
	run.wall = 20
	run.lord_skill_id = "jianhao"
	if not _expect_manual_block(main, run, "🪙 玉玺无处下口：场上不足5人，或没有星≤3的祭品"):
		return
	run.lord_skill_id = "wuxing"
	run.permanent_tactics.gewu = true
	run.dance_time = 2.0
	if not _expect_manual_block(main, run, "🍷 乐不思蜀，号令没人接"):
		return
	run.permanent_tactics.gewu = false

	# Web keeps updateFx alive under lordPop, including Gewu's timed automatic draft choice.
	run.gain_xp(maxf(1.0, run.xp_need - run.xp))
	if not _expect(run.awaiting_card_choice and not run.card_choices.is_empty(), "test fixture must open a real growth draft for Gewu visual-time coverage"):
		return
	run.permanent_tactics.gewu = true
	run.dance_time = 0.0
	run.gewu_auto_index = -1
	run.gewu_auto_timer = 1.4
	main.player_lord_popup = true
	main._process(0.2)
	if not _expect(not run.awaiting_card_choice and run.card_choices.is_empty(), "lord popup visual time must let Gewu finish its automatic card choice like Web updateFx"):
		return
	run.permanent_tactics.gewu = false
	run.lord_command_cd = 12.5
	visual = main.lord_command_visual_spec()
	if not _expect(not bool(visual.ready) and is_equal_approx(float(visual.cooldown_fraction), 12.5 / 55.0) and str(visual.cooldown_label) == "13", "cooling command HUD must expose the Web clockwise sector fraction and ceiling-second label"):
		return
	main.player_lord_popup = true
	if not _expect(main.player_lord_popup_spec().cast_rect.size == Vector2.ZERO, "cooling lord panel must not expose a manual cast hitbox"):
		return
	var ruler_cases := {
		"caocao": ["wuxing", "8秒内被克的亏全免", "场上贼≥8个"],
		"liubei": ["taoyuan", "全军金身6秒刀枪不入", "有兄弟掉到半血"],
		"sunquan": ["jiejiang", "拦腰一道大江7秒", "江区里贼≥4个"],
		"yuanshao": ["mensheng", "接下来 1 次升级选卡变五选一", "CD一转好就铺门路"],
		"liubiao": ["bingfeng", "全场定住 1.7秒", "场上贼≥6个"],
		"gongsunzan": ["baima", "主公亲自下场7秒", "有特种/贼首上场"],
		"dongzhuo": ["fenluo", "烧掉自家2点城墙血", "贼≥6个且城血≥5"],
		"yuanshu": ["jianhao", "连升2级", "场上≥5人且有星≤3的祭品"],
	}
	for ruler_id in ruler_cases:
		var expected: Array = ruler_cases[ruler_id]
		run.ruler_id = ruler_id
		run.lord_skill_id = str(expected[0])
		run.lord_skill_level = 1
		var ruler_spec: Dictionary = main.player_lord_popup_spec()
		if not _expect(not str(ruler_spec.attack_line).is_empty() and not str(ruler_spec.attack_detail).is_empty(), "%s lord panel must expose its real basic attack" % ruler_id):
			return
		if not _expect(str(ruler_spec.command_desc).contains(str(expected[1])) and str(ruler_spec.auto_tip).contains(str(expected[2])), "%s lord panel must preserve its Web command description and automatic timing" % ruler_id):
			return
	print("Godot v7.19.14 player lord popup: PASS")
	quit(0)

func _expect_manual_block(main, run, expected_notice: String) -> bool:
	run.lord_command_cd = 0.0
	var used_before := int(run.lord_command_used)
	main.battle_interaction_notice = {}
	main.player_lord_popup = true
	var cast_rect: Rect2 = main.player_lord_popup_spec().cast_rect
	main._handle_pointer(cast_rect.get_center())
	return _expect(not main.player_lord_popup_is_visible() and int(run.lord_command_used) == used_before and is_equal_approx(float(run.lord_command_cd), 0.0) and str(main.battle_interaction_notice.get("text", "")) == expected_notice, "blocked manual command must preserve use/CD and show exact Web notice: %s" % expected_notice)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
