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

	main.battle_run.card_choices = _cards(3)
	if not _expect(main.card_draft_heading() == "✨ 升级！挑一张 ✨", "three-card heading must match Web copy"):
		return
	if not _expect(main._growth_card_rect(0) == Rect2(20, 294, 140, 146) and main._growth_card_rect(2) == Rect2(320, 294, 140, 146), "three-card geometry must match Web cardRect"):
		return
	main.battle_run.card_choices = _cards(4)
	if not _expect(main._growth_card_rect(0) == Rect2(9, 294, 108, 146) and main._growth_card_rect(3) == Rect2(363, 294, 108, 146), "four-card geometry must match Web cardRect"):
		return
	main.battle_run.card_choices = _cards(5)
	if not _expect(main._growth_card_rect(0) == Rect2(9, 294, 86, 146) and main._growth_card_rect(4) == Rect2(385, 294, 86, 146), "five-card geometry must match Web cardRect"):
		return
	main.battle_run.card_choices = [{"kind": "unit", "hero_id": "zhangfei", "cls": "spear", "title": "张飞出征", "info": "✊霸道系 · 🔱枪兵", "infoColor": "#ff6b4a", "lvN": 7, "tag": "🤝亲军·登场+1星", "tagBad": false, "desc": "咆哮震敌"}]
	main.growth_card_anim = 0.0
	var entering: Dictionary = main._growth_card_visual_spec(0, main.battle_run.card_choices[0])
	if not _expect(entering.panel_rect == Rect2(8, 260, 464, 198) and entering.rect.position.y == 394, "growth overlay panel and first entrance frame must match Web geometry"):
		return
	if not _expect(entering.top_color == Color("54452a") and entering.bottom_color == Color("3a3020") and entering.border_color == Color("6fd44e"), "unit card gradient and class border must match Web colours"):
		return
	main.growth_card_anim = 1.0
	var settled: Dictionary = main._growth_card_visual_spec(0, main.battle_run.card_choices[0])
	if not _expect(settled.rect.position.y == 294 and settled.tag_rect == Rect2(settled.rect.position.x + 6, 298, 76, 18), "settled card and tag geometry must match Web"):
		return
	if not _expect(main.has_method("_growth_star_tiers"), "growth-card renderer must expose Web star compression"):
		return
	if not _expect(main._growth_star_tiers(5) == [0, 0, 0, 0, 0] and main._growth_star_tiers(6) == [1, 0, 0, 0, 0], "growth-card stars must compress first ascension into five Web stars"):
		return
	if not _expect(main._growth_star_tiers(11) == [2, 1, 1, 1, 1] and main._growth_star_tiers(15) == [2, 2, 2, 2, 2], "growth-card stars must compress second ascension into five Web stars"):
		return
	if not _expect(main.has_method("_sync_growth_card_ui"), "growth draft must expose Web card entrance timing"):
		return

	main.battle_run.speed = 0
	main.battle_run.awaiting_card_choice = true
	main.battle_run.card_choices = _cards(3)
	main._sync_growth_card_ui(0.0)
	main._handle_pointer(main._growth_card_rect(0).get_center())
	if not _expect(main.battle_run.card_choices.size() == 3, "a newly opened draft must ignore clicks during the Web 350ms protection window"):
		return
	main._sync_growth_card_ui(0.34)
	main._handle_pointer(main._growth_card_rect(0).get_center())
	if not _expect(main.battle_run.card_choices.size() == 3, "a draft must remain protected before 350ms elapses"):
		return
	main._sync_growth_card_ui(0.02)
	main._handle_pointer(main._growth_card_rect(0).get_center())
	if not _expect(not main.battle_run.awaiting_card_choice and main.battle_run.card_choices.is_empty(), "a card click must apply after the protection window"):
		return

	main.battle_run.awaiting_card_choice = true
	main.battle_run.card_choices = _cards(3)
	main._sync_growth_card_ui(0.0)
	main._sync_growth_card_ui(0.36)
	main.foe_lord_popup = false
	if not _expect(not main.battle_run.foe_lord.is_empty(), "fixture battle must expose a foe lord for overlay-priority testing"):
		return
	main._handle_pointer(main.FOE_LORD_RECT.get_center())
	if not _expect(main.foe_lord_popup and main.battle_run.card_choices.size() == 3, "foe-lord deck must remain inspectable above an open growth draft"):
		return
	if not _expect(main.has_method("_battle_overlay_layers") and main._battle_overlay_layers() == ["growth", "foe_lord"], "foe-lord popup must render after and above the growth-card layer"):
		return
	main.foe_lord_popup = false
	main.damage_panel_visible = false
	main._handle_pointer(main.BATTLE_DMG_RECT.get_center())
	if not _expect(not main.damage_panel_visible and main.battle_run.card_choices.size() == 3, "an open draft must consume off-card clicks instead of triggering covered battle controls"):
		return

	main.battle_run.awaiting_card_choice = false
	main.battle_run.card_choices = []
	main.battle_run.permanent_tactics.gewu = true
	main.battle_run.dance_time = 2.0
	if not _expect(main.has_method("_dance_overlay_spec") and float(main._dance_overlay_spec().alpha) > 0.0, "active dance must expose the Web full-screen performance overlay"):
		return
	main._handle_pointer(Vector2(240, 520))
	if not _expect(bool(main.battle_run.permanent_tactics.gewu), "clicks during the Web three-second dance must not cancel Gewu"):
		return
	main.battle_run.dance_time = 0.0
	main._handle_pointer(Vector2(240, 520))
	if not _expect(not bool(main.battle_run.permanent_tactics.gewu), "clicks after the dance must wake the player from Gewu"):
		return

	print("Godot v7.19.14 growth card overlay: PASS")
	quit(0)

func _cards(count: int) -> Array:
	var result := []
	for index in count:
		result.append({"kind": "merit", "title": "牌%d" % index, "icon": "📜", "desc": "测试", "value": 1})
	return result

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
