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

    _click(main, Vector2(430, 680))
    if not _expect(main.phase == "map", "Map background must not select a city"):
        return
    _click(main, Vector2(155, 630))
    if not _expect(main.phase == "ruler", "First city click must enter ruler selection"):
        return

    _click(main, Vector2(100, 212))
    if not _expect(main.phase == "ruler", "Gap between ruler rows must not select a ruler"):
        return
    _click(main, Vector2(100, 170))
    if not _expect(main.phase == "pick", "First ruler row must enter opening pick"):
        return

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
    if not _expect(main.selected_hero == "jiangwei", "Selected hero must be retained"):
        return

    var kills_before: int = main.kills
    await create_timer(0.6).timeout
    if not _expect(main.kills > kills_before, "SceneTree processing must advance automatic battle"):
        return

    print("Godot main input and runtime flow: PASS")
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
