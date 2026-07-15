extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const LocalProfile = preload("res://src/progression/local_profile.gd")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var main = MainScene.instantiate()
    root.add_child(main)
    main.profile_path = "user://codex-main-flow-profile-test.json"
    DirAccess.remove_absolute(ProjectSettings.globalize_path(main.profile_path))
    main.profile = LocalProfile.defaults(main.CURRENT_WEEK)
    main.week_clears = main.profile.week_clears
    if not _expect(main.phase == "title", "Scene must start on title"):
        return

    _click(main, Vector2(240, 400))
    if not _expect(main.phase == "map", "Title click must enter map"):
        return
    if not _expect(main.has_method("select_map_region"), "Map must support four-region switching"):
        return
    if not _expect(main.catalog.version == "7.19.2", "Main scene must load the frozen content catalog"):
        return
    if not _expect(main.weekly.make_slots(main.CURRENT_WEEK).size() == 64, "Main scene must bind all 64 weekly cities"):
        return
    if not _expect(main.current_region == 0, "Map must start in the East region"):
        return
    if not _expect(main.has_method("region_clear_count") and main.has_method("city_is_cleared") and main.has_method("city_is_unlocked"), "Map must expose clear-state presentation helpers"):
        return
    main.week_clears[0] = true
    if not _expect(main.region_clear_count(0) == 1 and main.city_is_cleared(0), "East clear count and city clear state must reflect offline progress"):
        return
    if not _expect(main.city_is_unlocked(1), "Clearing city 0 must unlock city 1"):
        return
    for city in 16:
        main.week_clears[city] = true
    if not _expect(main.region_clear_count(0) == 16 and main.city_is_unlocked(16), "Clearing East must unlock the first South city"):
        return
    main.week_clears.clear()

    _click(main, Vector2(192, 723))
    if not _expect(main.current_region == 1, "South tab click must switch regions"):
        return
    _click(main, Vector2(168, 650))
    if not _expect(main.state_popup == -1, "Locked South city must not open"):
        return
    _click(main, Vector2(94, 723))
    if not _expect(main.current_region == 0, "East tab click must switch back"):
        return
    _click(main, Vector2(168, 650))
    if not _expect(main.phase == "map" and main.state_popup == 0, "First city click must open details without marching"):
        return
    _click(main, Vector2(20, 780))
    if not _expect(main.phase == "map" and main.state_popup == -1, "Popup background click must close details"):
        return
    _click(main, Vector2(168, 650))
    _click(main, Vector2(240, 670))
    if not _expect(main.phase == "ruler", "March button must enter ruler selection"):
        return

    _click(main, Vector2(100, 212))
    if not _expect(main.phase == "ruler", "Gap between ruler rows must not select a ruler"):
        return
    _click(main, Vector2(100, 170))
    if not _expect(main.phase == "pick", "First ruler row must enter opening pick"):
        return
    if not _expect(main.has_method("roll_opening_heroes"), "Ruler selection must use the 45-hero opening picker"):
        return
    if not _expect(main.opening_hero_ids.size() == 3 and _unique_count(main.opening_hero_ids) == 3, "Opening draft must contain three unique heroes"):
        return
    var non_dps := 0
    for hero_id in main.opening_hero_ids:
        var hero: Dictionary = main.catalog.by_id("heroes", hero_id)
        if hero.cls == "shield" or hero.cls == "support":
            non_dps += 1
    if not _expect(non_dps <= 1, "Opening draft must contain at least two damage classes"):
        return
    var first_opening_hero: String = main.opening_hero_ids[0]
    main.profile.wins = 8

    _click(main, Vector2(161, 320))
    if not _expect(main.phase == "pick", "Gap between hero cards must not select a hero"):
        return
    _click(main, Vector2(80, 320))
    if not _expect(main.phase == "battle", "First hero card must enter battle"):
        return

    if not _expect(main.selected_city == 0, "Selected city must be retained"):
        return
    if not _expect(main.selected_ruler == "caocao", "Selected ruler must be retained"):
        return
    if not _expect(main.selected_hero == first_opening_hero, "Selected opening hero must be retained"):
        return

    var battle_run = main.get("battle_run")
    if not _expect(battle_run != null, "Entering battle must construct the authoritative BattleRun model"):
        return
    if not _expect(battle_run.city.k == 0 and battle_run.ruler_id == "caocao", "BattleRun must retain the selected city and ruler"):
        return
    if not _expect(int(battle_run.city.metaWins) == 8, "the playable battle must receive account wins for exact dragon-egg gating"):
        return
    if not _expect(str(battle_run.foe_lord.def.id) == "heyi", "the integrated weekly city must seat its deterministic foe commander"):
        return
    _click(main, Vector2(240, 127))
    if not _expect(main.foe_lord_popup and main.foe_card_rows().size() > 0, "clicking the mirrored foe commander must open its ten-card deck panel"):
        return
    _click(main, Vector2(20, 260))
    if not _expect(not main.foe_lord_popup, "clicking the foe deck panel must close it"):
        return
    battle_run.wave = 8
    battle_run.foe_lord.deck = ["taunt"]
    battle_run.foe_lord.idx = 0
    battle_run.foe_lord.drawT = 90.0
    battle_run.foe_lord.told = false
    if not _expect("下一手" in main.foe_lord_status_text() and "口嗨" not in main.foe_lord_status_text(), "outside the 30-second reveal window the foe HUD must hide the next card's name"):
        return
    battle_run.foe_lord.drawT = 25.0
    battle_run.foe_lord.told = true
    if not _expect("口嗨" in main.foe_lord_status_text(), "inside the reveal window the foe HUD must name the telegraphed card"):
        return
    main.foe_lord_popup = true
    battle_run.status = "win"
    if not _expect(not main.foe_lord_popup_is_visible(), "the foe deck panel must not cover a completed battle result"):
        return
    main.foe_lord_popup = false
    battle_run.status = "play"
    battle_run.wave = 0
    if not _expect(battle_run.units().size() == 1 and battle_run.units()[0].hero.id == first_opening_hero, "BattleRun must place the selected opening hero"):
        return
    if not _expect(battle_run.wave == 0 and is_equal_approx(battle_run.wave_timer, 2.0), "Integrated battle must preserve the two-second opening rest"):
        return
    if not _expect(battle_run.wall == 15 and battle_run.wall_max == 15 and battle_run.city.killTarget == 450, "Integrated HUD values must come from the selected city model"):
        return
    main.set_process(false)
    var time_before: float = battle_run.game_time
    main._process(1.0)
    if not _expect(battle_run.game_time > time_before and battle_run.wave == 1 and battle_run.spawn_queue.size() == 13, "Main processing must start the real first wave after the fixed-speed opening rest"):
        return
    main._process(0.01)
    if not _expect(battle_run.enemies.size() == 1 and battle_run.spawn_queue.size() == 12, "Integrated wave scheduling must spawn the first real enemy"):
        return
    var victim: Dictionary = battle_run.enemies[0]
    victim.xp = 10.0
    victim.hp = 1.0
    battle_run.damage_enemy(victim, 1.0, str(victim.tri))
    if not _expect(battle_run.kills == 1 and battle_run.level == 2, "A real enemy death must feed integrated kills and XP progression"):
        return
    if not _expect(battle_run.awaiting_card_choice and battle_run.card_choices.size() == 3, "Main battle screen must expose the first growth draft"):
        return
    _click(main, Vector2(80, 380))
    if not _expect(not battle_run.awaiting_card_choice, "Clicking a growth card must apply it and resume the battle"):
        return

    battle_run.enemies = _command_enemies(8)
    battle_run.spawn_queue = []
    battle_run.lord_command_cd = 0.0
    _click(main, Vector2(400, 770))
    if not _expect(battle_run.lord_command_used == 1 and battle_run.wuxing_time > 0, "Clicking the ready lord-command panel must cast it manually"):
        return
    battle_run.permanent_tactics.gewu = true
    _click(main, Vector2(20, 260))
    if not _expect(not bool(battle_run.permanent_tactics.get("gewu", false)), "Clicking the battlefield while Gewu is active must return to manual play"):
        return
    battle_run.enemies = []

    battle_run.clear_formation()
    battle_run.obstacles.clear()
    battle_run.add_unit_at("huangzhong", 0, 0)
    battle_run.add_unit_at("yanyan", 2, 4)
    if not _expect(battle_run.team.active_bond_ids() == ["laojiang"], "Integrated formation changes must activate the old-generals bond"):
        return
    if not _expect(main.has_method("active_bond_text"), "Battle UI must expose active bond text"):
        return
    if not _expect("老当益壮" in main.active_bond_text(), "Battle UI must name the active old-generals bond"):
        return
    battle_run.relic_ids = ["jinlan"]
    if not _expect(main.has_method("active_relic_text") and not main.active_relic_text().is_empty(), "Battle UI must expose equipped relics from the run"):
        return
    battle_run.relic_ids.append("yiji")
    battle_run.card_choices = battle_run.card_system.roll(battle_run)
    if not _expect(battle_run.card_choices.size() == 4 and main._growth_card_rect(3).end.x <= 480.0, "Yiji's fourth growth card must remain fully clickable inside the 480px viewport"):
        return
    if not _expect("四选一" in main.card_draft_heading(), "Yiji's expanded growth draft heading must say four choices"):
        return
    battle_run.card_choices = []
    for index in 5:
        battle_run.card_choices.append({"kind": "merit", "title": "门生牌%d" % index, "value": 1})
    battle_run.awaiting_card_choice = true
    if not _expect(main._growth_card_rect(4).end.x <= 480.0 and "五选一" in main.card_draft_heading(), "Mensheng's fifth card must be visible and the draft heading must say five choices"):
        return
    _click(main, main._growth_card_rect(4).get_center())
    if not _expect(int(battle_run.card_picks.get("门生牌4", 0)) == 1, "Mensheng's fifth card must be clickable inside the viewport"):
        return
    battle_run.picking_relic = true
    if not _expect(main.has_method("card_draft_heading") and "遗宝" in main.card_draft_heading(), "a relic draft must identify itself instead of claiming to be a level-up draft"):
        return

    battle_run.picking_relic = false
    battle_run.awaiting_card_choice = false
    battle_run.card_choices = []
    battle_run.status = "play"
    battle_run.clear_formation()
    battle_run.obstacles.clear()
    battle_run.add_unit_at("zhurong", 1, 2)
    battle_run.city.theme = "liaoyuan"
    if not _expect(main._theme_fit(), "Liaoyuan strategy fit must recognize a hero whose ultimate name contains fire even without a burn field"):
        return
    battle_run.wave = 7
    battle_run.wall = battle_run.wall_max
    battle_run.unit_deaths = 0
    battle_run.run_gold = 12.0
    battle_run.finish("win")
    main._process(0.0)
    if not _expect(battle_run.stars == 3 and main.city_is_cleared(0) and not main.settlement_summary.is_empty(), "a real victory must settle prestige and local city progress"):
        return
    _click(main, main.RESULT_BTN1.get_center())
    if not _expect(battle_run.status == "play" and battle_run.endless, "the first victory result button must continue the same run in suppression mode"):
        return
    battle_run.wave = 9
    battle_run.scored_wave = 9
    battle_run.score_revision = 1
    main._process(0.0)
    if not _expect(int(main.profile.week_best["0"].endless) == 2, "cleared suppression waves must persist through the main flow"):
        return
    battle_run.status = "play"
    battle_run.finish("over")
    main._process(0.0)
    _click(main, main.RESULT_BTN1.get_center())
    if not _expect(main.phase == "map" and main.battle_run == null and main.city_is_unlocked(1), "suppression defeat must return to the map with the next city unlocked"):
        return

    DirAccess.remove_absolute(ProjectSettings.globalize_path(main.profile_path))

    print("Godot main input and runtime flow: PASS")
    quit(0)

func _click(main: Control, position: Vector2) -> void:
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.position = position
    event.pressed = true
    main._gui_input(event)

func _command_enemies(count: int) -> Array:
    var result := []
    for index in count:
        result.append({
            "x": 40.0 + index * 50.0, "y": 340.0, "r": 18.0,
            "hp": 1000.0, "hp_max": 1000.0, "tri": "badao", "xp": 0.0,
            "dead": false, "boss": false, "cls": "spear", "slowT": 0.0, "stunT": 0.0,
        })
    return result

func _unique_count(values: Array) -> int:
    var unique := {}
    for value in values:
        unique[value] = true
    return unique.size()

func _expect(condition: bool, message: String) -> bool:
    if condition:
        return true
    push_error(message)
    quit(1)
    return false
