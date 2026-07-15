class_name BattleFoes
extends RefCounted

const SPECIAL_ORDER := ["runner", "healer", "shooter", "banner", "thrower", "shaman", "rattan", "ram", "cata", "warden", "bomber", "assassin", "pavise"]

const SPECIALS := {
	"runner":   {"name": "奔袭", "min_wave": 3,  "base_ch": 0.06,  "growth": 0.006, "cap": 0.20, "lv_min": 0,  "hp_mul": 0.5, "speed_mul": 2.2,  "r": 14, "xp_mul": 1.0, "dmg": 1},
	"healer":   {"name": "巫医", "min_wave": 6,  "base_ch": 0.03,  "growth": 0.005, "cap": 0.12, "lv_min": 0,  "hp_mul": 1.6, "speed_mul": 0.7,  "r": 21, "xp_mul": 3.0, "dmg": 2},
	"shooter":  {"name": "弓贼", "min_wave": 7,  "base_ch": 0.03,  "growth": 0.005, "cap": 0.12, "lv_min": 0,  "hp_mul": 1.9, "speed_mul": 0.85, "r": 23, "xp_mul": 3.0, "dmg": 2},
	"banner":   {"name": "旗手", "min_wave": 8,  "base_ch": 0.03,  "growth": 0.004, "cap": 0.10, "lv_min": 0,  "hp_mul": 2.2, "speed_mul": 0.8,  "r": 21, "xp_mul": 3.0, "dmg": 2},
	"thrower":  {"name": "投石兵", "min_wave": 9, "base_ch": 0.025, "growth": 0.004, "cap": 0.10, "lv_min": 0,  "hp_mul": 2.2, "speed_mul": 0.7,  "r": 23, "xp_mul": 3.0, "dmg": 2},
	"shaman":   {"name": "妖术师", "min_wave": 10,"base_ch": 0.02,  "growth": 0.004, "cap": 0.09, "lv_min": 0,  "hp_mul": 1.8, "speed_mul": 0.75, "r": 21, "xp_mul": 3.0, "dmg": 2},
	"rattan":   {"name": "藤甲兵", "min_wave": 4, "base_ch": 0.03,  "growth": 0.004, "cap": 0.10, "lv_min": 16, "hp_mul": 3.0, "speed_mul": 0.8,  "r": 21, "xp_mul": 3.0, "dmg": 2},
	"ram":      {"name": "锤车", "min_wave": 5,   "base_ch": 0.02,  "growth": 0.003, "cap": 0.08, "lv_min": 24, "hp_mul": 3.5, "speed_mul": 0.5,  "r": 27, "xp_mul": 3.0, "dmg": 4},
	"cata":     {"name": "投石车", "min_wave": 10,"base_ch": 0.02,  "growth": 0.004, "cap": 0.12, "lv_min": 24, "hp_mul": 1.2, "speed_mul": 0.6,  "r": 22, "xp_mul": 3.0, "dmg": 1},
	"warden":   {"name": "督军", "min_wave": 6,   "base_ch": 0.02,  "growth": 0.003, "cap": 0.08, "lv_min": 32, "hp_mul": 2.5, "speed_mul": 0.75, "r": 21, "xp_mul": 3.0, "dmg": 2},
	"bomber":   {"name": "爆竹兵", "min_wave": 5, "base_ch": 0.035, "growth": 0.005, "cap": 0.13, "lv_min": 20, "hp_mul": 0.9, "speed_mul": 1.1,  "r": 18, "xp_mul": 3.0, "dmg": 2},
	"assassin": {"name": "刺客", "min_wave": 7,   "base_ch": 0.03,  "growth": 0.005, "cap": 0.12, "lv_min": 28, "hp_mul": 1.4, "speed_mul": 1.6,  "r": 16, "xp_mul": 3.0, "dmg": 2},
	"pavise":   {"name": "橹楯车", "min_wave": 6, "base_ch": 0.025, "growth": 0.004, "cap": 0.10, "lv_min": 36, "hp_mul": 2.8, "speed_mul": 0.65, "r": 25, "xp_mul": 3.0, "dmg": 2},
}

const AFFIXES := {
	"shield": {"name": "铁盾"},
	"split": {"name": "分裂"},
	"frenzy": {"name": "狂暴"},
	"regen": {"name": "回春"},
}

const KIT_NAMES := {
	"summon": "召援",
	"firepot": "火罐",
	"volley": "乱箭",
	"split": "裂变",
	"sealwave": "群封",
	"thunder": "天雷",
	"affixlord": "词缀首领",
	"avatar": "天公化神",
}

func roll_special(rng, wave: int, city: Dictionary, mutation) -> Variant:
	var ranged_multiplier := float(city.get("rangedMul", 1.0)) * (4.0 if str(mutation) == "volley" else 1.0)
	var theme_id := str(city.get("weekTheme", city.get("week_theme", city.get("theme", ""))))
	var theme_multiplier := 1.6 if theme_id == "yunchou" else 1.0
	var level_index := int(city.get("lvIdx", city.get("idx", 0)))
	for key in SPECIAL_ORDER:
		var definition: Dictionary = SPECIALS[key]
		var ranged: bool = key == "shooter" or key == "thrower"
		var min_wave: int = mini(int(definition.min_wave), 5) if ranged and str(mutation) == "volley" else int(definition.min_wave)
		var level_ok := int(definition.lv_min) <= 0 or level_index >= int(definition.lv_min)
		if (key == "ram" or key == "cata") and wave >= 12:
			level_ok = true
		if wave < min_wave or not level_ok:
			continue
		var chance: float = clampf(float(definition.base_ch) + wave * float(definition.growth), 0.0, float(definition.cap))
		chance = minf(0.6, chance * (ranged_multiplier if ranged else 1.0) * theme_multiplier)
		if rng.next_float() < chance:
			return key
	return null

func make_spec(key: String, hp: int, speed: float, base_xp: float, enemy_class: String, delay: float, tri: String) -> Dictionary:
	var definition: Dictionary = SPECIALS[key]
	return {
		"delay": delay,
		"hp": roundi(hp * float(definition.hp_mul)),
		"speed": speed * float(definition.speed_mul),
		"r": int(definition.r),
		"cls": enemy_class,
		"big": false,
		"affix": null,
		"special": key,
		"tri": tri,
		"xp": base_xp * float(definition.xp_mul),
		"dmg": int(definition.dmg),
	}
