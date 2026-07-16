extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	if not _expect(main.BATTLE_MUTE_RECT == Rect2(402, 102, 64, 32), "mute button geometry must match Web v7.19.14"):
		return
	if not _expect(main.BATTLE_QUIT_RECT == Rect2(402, 140, 64, 32), "quit button geometry must match Web v7.19.14"):
		return
	if not _expect(main.BATTLE_DMG_RECT == Rect2(402, 456, 64, 30), "damage button geometry must match Web v7.19.14"):
		return
	main.advance_from_title()
	main.select_city(0)
	main.select_ruler("liubei")
	main.select_opening_hero("zhaoyun")
	if not _expect(main.BATTLE_WAVE_FONT_SIZE == 16, "battle wave label must retain the Web bold 16px HUD size"):
		return
	var wall_lord: Dictionary = main.battle_wall_lord_spec()
	if not _expect(wall_lord.center == Vector2(240, main.BattleRunSource.DEFENSE_LINE + 26), "wall lord must stand at the exact Web defense-line anchor"):
		return
	if not _expect(wall_lord.character == "刘" and wall_lord.full_name == "刘备", "wall lord must render the ruler's first character and full name as separate Web rows"):
		return
	if not _expect(wall_lord.character_baseline == wall_lord.center.y + 1.0 and wall_lord.name_baseline == wall_lord.center.y + 13.0, "wall lord character and full-name baselines must match Web"):
		return
	if not _expect(wall_lord.kin_center == wall_lord.center + Vector2(-48, 4) and wall_lord.attack_center == wall_lord.center + Vector2(52, -3), "kin bonus and attack method must be centered around the wall lord instead of left-aligned"):
		return
	main.battle_run.wave = 8
	main.battle_run.wave_timer = 2.2
	main.battle_run.spawn_queue.clear()
	main.battle_run.enemies.clear()
	main.battle_run.next_wave_preview = {"themeElems": ["badao"], "mutation": null, "boss": "张梁", "affixes": {"shield": 2}, "specials": {"cata": 1}}
	var rest_preview: Dictionary = main.next_wave_preview_spec()
	if not _expect(rest_preview.rect.position.y == 130.0 and rest_preview.rect.size.y == 83.0 and rest_preview.rect.size.x >= 260.0 and rest_preview.rect.size.x <= 464.0, "next-wave box must use the Web y anchor, dynamic width and twenty-one-pixel line height"):
		return
	if not _expect(rest_preview.lines.size() == 3 and rest_preview.lines[0].text == "⏳ 第 9 波（3s）", "resting preview must identify the exact next wave and ceil the countdown like Web"):
		return
	if not _expect(str(rest_preview.lines[1].text).contains("贼是✊霸道") and str(rest_preview.lines[1].text).contains("✋仁德打他最疼"), "next-wave preview must expose the enemy element and its counter"):
		return
	if not _expect(str(rest_preview.lines[2].text).contains("👹「张梁」") and str(rest_preview.lines[2].text).contains("🏗️投石车×1") and str(rest_preview.lines[2].text).contains("🛡️铁盾×2"), "next-wave preview must list boss, special and affix threats with Web icons"):
		return
	main.battle_run.spawn_queue = [{"delay": 1.0}]
	main.battle_run.wave_budget = 10.0
	main.battle_run.wave_clock = 4.2
	var pressing_preview: Dictionary = main.next_wave_preview_spec()
	if not _expect(pressing_preview.lines[0].text == "🥁 催战！第 9 波 6s 后压上" and pressing_preview.lines[0].color == Color("ff8a6a"), "active spawning must switch the preview to the Web pressing warning"):
		return
	main.battle_run.spawn_queue.clear()
	main.battle_run.clear_formation()
	main.battle_run.obstacles.clear()
	main.battle_run.foe_lord = {}
	main.battle_run.relic_ids = ["jinlan"]
	main.battle_run.add_unit_at("daqiao", 1, 1)
	main.battle_run.add_unit_at("xiaoqiao", 1, 2)
	var chips: Array = main.battle_left_chip_specs()
	if not _expect(chips.size() == 3 and chips[0].kind == "field" and chips[0].rect == Rect2(10, 98, 118, 19), "the terrain chip must start the Web left-hand status stack"):
		return
	if not _expect(chips[1].kind == "relic" and chips[1].rect.position == Vector2(10, 120) and chips[1].rect.size.y == 22.0, "relic icons must occupy the next compact Web chip instead of a centered banner"):
		return
	if not _expect(chips[2].kind == "bond" and chips[2].text == "🔗江东二乔" and chips[2].rect.position == Vector2(10, 144) and chips[2].rect.size.y == 22.0, "each active bond must remain visible as its own gold Web chip"):
		return
	main.battle_run.relic_ids.clear()
	main.battle_run.clear_formation()
	var rules: Array = main.battle_run.city.get("rules", [])
	var expected_banner_height := 92 + 22 + rules.size() * 17
	if not _expect(main.battle_field_banner_rect() == Rect2(8, 138, 392, expected_banner_height), "field banner height must follow Web foe and rule rows"):
		return
	var original_rules: Array = rules.duplicate()
	main.battle_run.city.rules = ["smoke", "mud"]
	if not _expect(main.battle_field_banner_rect() == Rect2(8, 138, 392, 148), "two-rule field banner must add exactly two Web 17px rows"):
		return
	main.battle_run.city.rules = original_rules
	main.battle_run.wave = 1
	if not _expect(main.battle_field_banner_is_visible(), "field banner must remain visible after wave one begins until its timer or click closes it"):
		return
	main._handle_pointer(main.battle_field_banner_rect().get_center())
	if not _expect(not main.battle_field_banner_is_visible(), "clicking the field banner must dismiss it like Web"):
		return
	main._handle_pointer(Vector2(20, 100))
	if not _expect(main.battle_field_banner_time == 6.0, "clicking the Web field chip hitbox must reopen the banner for six seconds"):
		return
	main.battle_field_banner_time = 0.5
	if not _expect(is_equal_approx(main.battle_field_banner_alpha(), 0.5), "field banner must fade during its final Web second"):
		return
	main._handle_pointer(main.battle_field_banner_rect().get_center())
	main.battle_run.ruler_id = "gongsunzan"
	main.battle_run.wave = 4
	main.battle_run.wall = 10
	main.battle_run.wall_max = 20
	main.battle_run.ruler_level = 1
	main.battle_run.lord_atk_gap = 1.0
	main.battle_run.lord_atk_buff = 0.0
	var crossbow_estimate: Dictionary = main._lord_attack_estimate()
	if not _expect(is_equal_approx(float(crossbow_estimate.per), 7.7868) and is_equal_approx(float(crossbow_estimate.itv), 2.5), "Gongsun Zan HUD estimate must use the Web wall-scaled crossbow formula and 2.5-second interval"):
		return
	var muted_before: bool = main.sound_enabled
	main._handle_pointer(main.BATTLE_MUTE_RECT.get_center())
	if not _expect(main.sound_enabled != muted_before, "mute button must toggle local sound state"):
		return
	main._handle_pointer(main.BATTLE_DMG_RECT.get_center())
	if not _expect(main.damage_panel_visible, "damage button must toggle output panel state"):
		return
	main._handle_pointer(main.BATTLE_QUIT_RECT.get_center())
	if not _expect(main.quit_armed, "first quit click must arm confirmation"):
		return
	main._handle_pointer(main.BATTLE_QUIT_RECT.get_center())
	if not _expect(main.phase == "map" and main.battle_run == null, "second quit click must return to the map"):
		return
	print("Godot v7.19.14 battle HUD controls: PASS")
	quit(0)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
