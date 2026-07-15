extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	main.profile_path = "user://codex-home-meta-test.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.profile_path))

	if not _expect(main.profile.heroes.size() == 45, "Home profile must initialize all 45 codex heroes"):
		return
	_click(main, main.HOME_CODEX_RECT.get_center())
	if not _expect(main.phase == "title" and main.home_overlay == "codex", "Codex button must open an overlay without starting a run"):
		return
	if not _expect(main.codex_page_hero_ids().size() == 15, "Codex must expose 15 heroes on each full page"):
		return
	var first_page_first: String = main.codex_page_hero_ids()[0]
	_click(main, main.HOME_NEXT_RECT.get_center())
	if not _expect(main.codex_page == 1 and main.codex_page_hero_ids()[0] != first_page_first, "Codex next button must navigate to page two"):
		return
	_click(main, main.HOME_PREV_RECT.get_center())
	_click(main, main.codex_hero_rect(0).get_center())
	if not _expect(main.home_overlay == "hero" and main.codex_hero_id == first_page_first, "Clicking a codex card must open that hero's detail"):
		return

	main.profile.gold = 100000
	var before_gold: int = main.profile.gold
	var before_level: int = main.profile.heroes[first_page_first].lv
	_click(main, main.HERO_UPGRADE_RECT.get_center())
	if not _expect(main.profile.heroes[first_page_first].lv == before_level + 1 and main.profile.gold < before_gold, "Hero detail upgrade must spend gold and raise exactly one level"):
		return
	_click(main, main.HOME_BACK_RECT.get_center())
	if not _expect(main.home_overlay == "codex", "Hero detail back button must return to the codex page"):
		return
	_click(main, main.HOME_CLOSE_RECT.get_center())
	if not _expect(main.home_overlay.is_empty(), "Codex close button must return to the title"):
		return

	_click(main, main.HOME_LORD_RECT.get_center())
	if not _expect(main.home_overlay == "lords" and main.lord_page_ruler_ids().size() == 4, "Lord House must open with four rulers per page"):
		return
	if not _expect(main.lord_house_rect(0) == Rect2(12, 112, 456, 120) and main.lord_house_rect(3) == Rect2(12, 496, 456, 120), "Lord House cards must use the frozen Web v7.19.14 geometry"):
		return
	if not _expect(main.TECH_PAGE_RECT == Rect2(358, 26, 108, 32), "Lord House page control must match the frozen Web top-right button"):
		return
	if not _expect(main._lord_skill_desc("taoyuan", 1).contains("实伤的8%再换成经验"), "Lord House must preserve the complete dynamic command copy instead of a shortened summary"):
		return
	if not _expect(main._lord_name_color(1) == Color("ffe8b0") and main._lord_name_color(10) == main.GOLD, "Lord House names must only turn gold at level ten like Web drawNameDisc"):
		return
	var caocao: Dictionary = main.catalog.by_id("rulers", "caocao")
	if not _expect(main._lord_special_line(caocao, 1) == "🌾屯田制：独家：粮仓卡——产粮喂旁边武将升星，产量+3%", "Lord House must preserve each ruler's complete special-mechanic line"):
		return
	_click(main, main.TECH_PAGE_RECT.get_center())
	if not _expect(main.lord_page == 1 and main.lord_page_ruler_ids()[0] == "liubiao", "Lord House next page must expose the remaining four rulers"):
		return
	_click(main, main.TECH_PAGE_RECT.get_center())
	if not _expect(main.lord_page == 0, "Lord House page button must cycle from page two back to page one"):
		return
	_click(main, Vector2(240, 750))
	if not _expect(main.home_overlay.is_empty(), "Lord House bottom return area must close the overlay"):
		return
	main.profile.items.visitToken = 1
	_click(main, main.HOME_VISIT_RECT.get_center())
	if not _expect(main.home_overlay == "visit", "Visit button must open the offline 20-cell board"):
		return
	_click(main, main.VISIT_ROLL_RECT.get_center())
	if not _expect(int(main.profile.items.visitToken) == 0 and not main.visit_result.is_empty(), "Visit roll button must spend a token and settle its landing reward"):
		return
	_click(main, main.HOME_CLOSE_RECT.get_center())
	_click(main, main.HOME_BAG_RECT.get_center())
	if not _expect(main.home_overlay == "bag", "Backpack button must expose persistent visit tokens and breakthrough stones"):
		return
	_click(main, main.HOME_CLOSE_RECT.get_center())
	main.profile.wins = 10
	_click(main, main.HOME_ACH_RECT.get_center())
	if not _expect(main.home_overlay == "achievements" and main.profile.achievements.has("wins10"), "Achievement button must sweep locally verifiable milestones before display"):
		return
	_click(main, main.HOME_CLOSE_RECT.get_center())
	_click(main, Vector2(240, 400))
	if not _expect(main.phase == "map", "Blank title click must still begin the weekly campaign"):
		return

	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.profile_path))
	print("Godot v7.19.14 home codex and lord house: PASS")
	quit(0)

func _click(main: Control, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = true
	main._gui_input(event)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
