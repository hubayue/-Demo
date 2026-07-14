extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var main = MainScene.instantiate()
    root.add_child(main)
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

    print("Godot main input and runtime flow: PASS")
    quit(0)

func _click(main: Control, position: Vector2) -> void:
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.position = position
    event.pressed = true
    main._gui_input(event)

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
