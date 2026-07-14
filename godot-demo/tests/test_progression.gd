extends SceneTree

const Progression = preload("res://src/core/progression.gd")

func _init() -> void:
    assert(Progression.star_parts(1) == {"t2": 0, "hi": 0, "lo": 1})
    assert(Progression.star_parts(5) == {"t2": 0, "hi": 0, "lo": 5})
    assert(Progression.star_parts(6) == {"t2": 0, "hi": 1, "lo": 4})
    assert(Progression.star_parts(10) == {"t2": 0, "hi": 5, "lo": 0})
    assert(Progression.star_parts(11) == {"t2": 1, "hi": 4, "lo": 0})
    assert(Progression.star_parts(15) == {"t2": 5, "hi": 0, "lo": 0})
    assert(is_equal_approx(Progression.star_damage_multiplier(1, false), 1.0))
    assert(is_equal_approx(Progression.star_damage_multiplier(6, false), pow(1.9, 4) * 1.4))
    assert(is_equal_approx(
        Progression.star_damage_multiplier(11, false),
        pow(1.9, 4) * pow(1.4, 5) * 1.3,
    ))
    assert(is_equal_approx(
        Progression.star_damage_multiplier(11, true),
        pow(1.9, 4) * pow(1.5, 5) * 1.4,
    ))
    print("Godot progression parity: PASS")
    quit(0)
