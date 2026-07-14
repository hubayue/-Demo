class_name Progression
extends RefCounted

static func star_parts(level: int) -> Dictionary:
    if level <= 5:
        return {"t2": 0, "hi": 0, "lo": level}
    if level <= 10:
        return {"t2": 0, "hi": level - 5, "lo": 10 - level}
    return {"t2": level - 10, "hi": 15 - level, "lo": 0}

static func star_damage_multiplier(level: int, has_phoenix_feather: bool) -> float:
    var ascended := 1.5 if has_phoenix_feather else 1.4
    var ascended_2 := 1.4 if has_phoenix_feather else 1.3
    return pow(1.9, min(level, 5) - 1) \
        * pow(ascended, max(0, min(level, 10) - 5)) \
        * pow(ascended_2, max(0, level - 10))
