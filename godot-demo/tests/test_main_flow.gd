extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
    var main = MainScene.instantiate()
    root.add_child(main)
    assert(main.phase == "title")
    main.advance_from_title()
    assert(main.phase == "map")
    main.select_city(0)
    assert(main.phase == "ruler")
    main.select_ruler("caocao")
    assert(main.phase == "pick")
    main.select_opening_hero("jiangwei")
    assert(main.phase == "battle")
    assert(main.selected_city == 0)
    assert(main.selected_ruler == "caocao")
    assert(main.selected_hero == "jiangwei")
    main._process(0.5)
    if main.kills <= 0:
        push_error("Automatic battle did not advance kills")
        quit(1)
        return
    print("Godot main flow: PASS")
    quit(0)
