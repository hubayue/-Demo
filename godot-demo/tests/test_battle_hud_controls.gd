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
