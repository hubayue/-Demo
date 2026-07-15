class_name BattleUlts
extends RefCounted

const VISUAL_EFFECTS := {
	"zhangfei": "shock", "zhaoyun": "fan", "machao": "lightning", "huangzhong": "snipe",
	"xiahouyuan": "ricochet", "luxun": "fire_pit", "guanyu": "lane", "lvbu": "bounce",
	"zhangliao": "fear", "taishici": "arrow_rain", "dianwei": "cleave", "sunce": "charge",
	"xuchu": "barricade", "weiyan": "trap", "ganning": "bombard", "diaochan": "charm",
	"zhouyu": "fire_beam", "jiangwei": "homing", "zhugeliang": "link", "caoren": "shock",
	"zhoutai": "reflect", "huatuo": "heal", "xiaoqiao": "haste", "lusu": "army_buff",
	"huanggai": "immolate", "xuhuang": "palisade", "daqiao": "ice_wave", "huangyueying": "turret_deploy",
	"caiwenji": "sleep", "gaoshun": "gather_lines", "zhanghe": "multi_charge", "zhurong": "fan",
	"wutugu": "poison", "simayi": "clock_links", "pangde": "lane", "yanliang": "execute",
	"sunshangxiang": "fan", "yanyan": "frost", "caohong": "guard", "xushu": "sunder",
	"jiaxu": "charm", "zuoci": "sheep", "dengai": "row", "menghuo": "fear", "wenchou": "duel",
}

const DEFINITIONS := {
	"zhangfei": {"name": "燕人怒喝", "type": "ctrl", "cd": 13, "condition": "range", "need": 3},
	"zhaoyun": {"name": "七探盘蛇", "type": "dmg", "cd": 10, "condition": "range", "need": 1},
	"machao": {"name": "雷光分驰", "type": "dmg", "cd": 12, "condition": "range", "need": 2},
	"huangzhong": {"name": "百步穿杨", "type": "exec", "cd": 9, "condition": "elite", "need": 1},
	"xiahouyuan": {"name": "连珠掠阵", "type": "dmg", "cd": 11, "condition": "enemies", "need": 5},
	"luxun": {"name": "火烧连营", "type": "dmg", "cd": 15, "condition": "enemies", "need": 8},
	"guanyu": {"name": "青龙偃月斩", "type": "dmg", "cd": 12, "condition": "column", "need": 2},
	"lvbu": {"name": "无双戟舞", "type": "dmg", "cd": 18, "condition": "enemies", "need": 6},
	"zhangliao": {"name": "威震逍遥津", "type": "ctrl", "cd": 14, "condition": "near", "need": 1, "distance": 130},
	"taishici": {"name": "箭雨遮天", "type": "dmg", "cd": 11, "condition": "cluster", "need": 5, "radius": 130},
	"dianwei": {"name": "双戟破阵", "type": "dmg", "cd": 14, "condition": "range", "need": 3},
	"sunce": {"name": "霸王冲阵", "type": "dmg", "cd": 10, "condition": "column", "need": 3},
	"xuchu": {"name": "虎痴拒马", "type": "def", "cd": 18, "condition": "near", "need": 3, "distance": 150},
	"weiyan": {"name": "子午伏兵", "type": "dmg", "cd": 12, "condition": "enemies", "need": 3},
	"ganning": {"name": "锦帆乱掷", "type": "dmg", "cd": 14, "condition": "enemies", "need": 5},
	"diaochan": {"name": "闭月迷心", "type": "ctrl", "cd": 15, "condition": "special_or_enemies", "need": 5},
	"zhouyu": {"name": "业火横江", "type": "dmg", "cd": 13, "condition": "enemies", "need": 6},
	"jiangwei": {"name": "麒麟火矢", "type": "dmg", "cd": 16, "condition": "enemies", "need": 4},
	"zhugeliang": {"name": "八阵锁敌", "type": "util", "cd": 18, "condition": "enemies", "need": 5},
	"caoren": {"name": "铁壁震荡", "type": "ctrl", "cd": 16, "condition": "range", "need": 1},
	"zhoutai": {"name": "冰棘迸发", "type": "def", "cd": 14, "condition": "self_hp", "ratio": 0.6},
	"huatuo": {"name": "青囊济世", "type": "util", "cd": 15, "condition": "ally_hp", "ratio": 0.7},
	"xiaoqiao": {"name": "东风助阵", "type": "util", "cd": 20, "condition": "enemies", "need": 6},
	"lusu": {"name": "天降粮草", "type": "util", "cd": 18, "condition": "enemies", "need": 8},
	"huanggai": {"name": "苦肉诈降", "type": "dmg", "cd": 16, "condition": "huang_gai", "need": 5, "ratio": 0.35},
	"xuhuang": {"name": "钉阵拒马", "type": "def", "cd": 17, "condition": "near", "need": 2, "distance": 160},
	"daqiao": {"name": "寒江凝波", "type": "util", "cd": 18, "condition": "enemies", "need": 5},
	"huangyueying": {"name": "连弩机关", "type": "dmg", "cd": 18, "condition": "enemies", "need": 4},
	"caiwenji": {"name": "胡笳十八拍", "type": "ctrl", "cd": 18, "condition": "enemies", "need": 6},
	"gaoshun": {"name": "陷阵无前", "type": "dmg", "cd": 14, "condition": "column", "need": 3},
	"zhanghe": {"name": "雷骑掠阵", "type": "dmg", "cd": 16, "condition": "enemies", "need": 8},
	"zhurong": {"name": "火神降世", "type": "dmg", "cd": 15, "condition": "enemies", "need": 6},
	"wutugu": {"name": "藤甲毒瘴", "type": "dmg", "cd": 18, "condition": "range", "need": 2},
	"pangde": {"name": "抬棺冲杀", "type": "dmg", "cd": 14, "condition": "column", "need": 2},
	"yanliang": {"name": "斩将夺旗", "type": "exec", "cd": 15, "condition": "special_elite", "need": 1},
	"sunshangxiang": {"name": "翻身背射", "type": "dmg", "cd": 13, "condition": "enemies", "need": 5},
	"yanyan": {"name": "断头怒喝", "type": "ctrl", "cd": 16, "condition": "front", "need": 3, "distance": 220},
	"caohong": {"name": "毁家纾难", "type": "def", "cd": 16, "condition": "ally_hp", "ratio": 0.6},
	"xushu": {"name": "破敌机先", "type": "util", "cd": 17, "condition": "enemies", "need": 6},
	"simayi": {"name": "天命在我", "type": "util", "cd": 16, "condition": "units", "need": 5},
	"jiaxu": {"name": "乱武", "type": "ctrl", "cd": 16, "condition": "ordinary", "need": 6},
	"zuoci": {"name": "群羊变", "type": "ctrl", "cd": 15, "condition": "ordinary", "need": 3},
	"dengai": {"name": "凿山", "type": "dmg", "cd": 14, "condition": "enemies", "need": 5},
	"menghuo": {"name": "南蛮战吼", "type": "ctrl", "cd": 15, "condition": "enemies", "need": 6},
	"wenchou": {"name": "阵前枭首", "type": "exec", "cd": 13, "condition": "duel", "need": 1},
}

func definition(hero_id: String) -> Dictionary:
	return DEFINITIONS.get(hero_id, {})

func initial_cooldown(run, hero_id: String) -> float:
	var ult := definition(hero_id)
	if ult.is_empty():
		return 0.0
	var meta_level := int(run.hero_levels.get(hero_id, 1))
	if meta_level >= 25:
		return 0.0
	var low := 0.08 if meta_level >= 15 else 0.4
	var high := 0.22 if meta_level >= 15 else 0.7
	return float(ult.cd) * run._randf(low, high)

func cooldown_max(run, unit: Dictionary) -> float:
	var hero_id := str(unit.hero.id)
	var ult := definition(hero_id)
	if ult.is_empty():
		return 0.0
	var result := float(ult.cd)
	if int(run.hero_levels.get(hero_id, 1)) >= 7:
		result *= 0.85
	if run.relic_ids.has("mengde"):
		result *= 0.72
	result *= maxf(0.5, 1.0 - float(run.buffs.get("ultHaste", 0.0)))
	if run.team.active_bonds.has("sanfen"):
		result *= 0.8
	if str(run.city.get("weekTheme", run.city.get("theme", ""))) == "yunchou":
		result *= 0.75
	return result

func update_unit(run, unit: Dictionary, delta: float) -> void:
	var hero_id := str(unit.hero.id)
	if not DEFINITIONS.has(hero_id):
		return
	var rate := 1.7 if float(unit.rbuffs.get("cdr", 0.0)) > 0 else 1.0
	unit.ultCd = maxf(0.0, float(unit.get("ultCd", 0.0)) - delta * rate)
	if float(unit.ultCd) <= 0 and not run.enemies.is_empty() and is_ready(run, unit):
		cast(run, unit)
		unit.ultCd = cooldown_max(run, unit)

func is_ready(run, unit: Dictionary) -> bool:
	var ult := definition(str(unit.hero.id))
	if ult.is_empty():
		return false
	var living := _alive(run)
	match str(ult.condition):
		"range": return _in_range(run, unit).size() >= int(ult.need)
		"column": return _in_column(run, unit).size() >= int(ult.need)
		"enemies": return living.size() >= int(ult.need)
		"near": return _near_wall(run, float(ult.distance)).size() >= int(ult.need)
		"front": return _near_wall(run, float(ult.distance)).size() >= int(ult.need)
		"elite": return living.filter(func(enemy): return bool(enemy.get("boss", false)) or enemy.get("affix") != null).size() >= int(ult.need)
		"cluster":
			var cluster := _densest(living, float(ult.radius))
			return not cluster.is_empty() and int(cluster.n) >= int(ult.need)
		"special_or_enemies": return living.size() >= int(ult.need) or living.any(func(enemy): return enemy.get("special") != null or bool(enemy.get("boss", false)))
		"special_elite": return living.any(func(enemy): return not bool(enemy.get("boss", false)) and (enemy.get("special") != null or enemy.get("affix") != null))
		"self_hp": return float(unit.hp) < float(unit.hp_max) * float(ult.ratio)
		"ally_hp": return run.units().any(func(ally): return float(ally.hp) < float(ally.hp_max) * float(ult.ratio))
		"huang_gai": return living.size() >= int(ult.need) and float(unit.hp) > float(unit.hp_max) * float(ult.ratio)
		"units": return run.units().size() >= int(ult.need)
		"ordinary": return living.filter(func(enemy): return enemy.get("special") == null and not bool(enemy.get("boss", false))).size() >= int(ult.need)
		"duel": return living.any(func(enemy): return float(enemy.get("duelT", 0.0)) > 0)
	return false

func cast(run, unit: Dictionary) -> bool:
	var hero_id := str(unit.hero.id)
	var ult := definition(hero_id)
	if ult.is_empty():
		return false
	run.ults_used += 1
	var duration := 1.6
	run.ult_events.append({
		"hero_id": hero_id,
		"name": str(ult.name),
		"type": str(ult.type),
		"effect": visual_effect(hero_id),
		"origin": _center(run, unit) - Vector2(0, 18),
		"duration": duration,
		"t": duration,
	})
	var base := float(run.team.unit_damage(run, unit, run.team.unit_mods(run, unit)))
	if run.relic_ids.has("jiuhu"):
		base *= 1.5
	match hero_id:
		"zhangfei": _zhangfei(run, unit, base)
		"zhaoyun": _fan_projectiles(run, unit, base, 14, 1.6, 99, 420.0, false)
		"machao": _machao(run, unit, base)
		"huangzhong": _huangzhong(run, unit, base)
		"xiahouyuan": _wall_bounce_arrow(run, unit, base)
		"luxun": _luxun(run, unit, base)
		"guanyu": _lane_damage(run, unit, base * 3.5, 20.0, "7aff9a", 3.0, 50.0)
		"lvbu": _bouncing_halberd(run, unit, base)
		"zhangliao":
			for enemy in _alive(run): enemy.fearT = maxf(float(enemy.get("fearT", 0.0)), 1.2 if bool(enemy.get("boss", false)) else 2.5)
		"taishici": _arrow_rain(run, unit, base * 2.8, 130.0)
		"dianwei": _dianwei(run, unit, base)
		"sunce": _add_charge(run, unit, base * 2.5, str(unit.hero.get("elem", "")), 60.0 + float(run.buffs.get("cavWide", 0.0)), 2.0)
		"xuchu": _xuchu(run)
		"weiyan": _weiyan(run, unit, base)
		"ganning": _bombard(run, unit, base * 2.2, 5, 70.0)
		"diaochan": _diaochan(run)
		"zhouyu": _zhouyu(run, unit, base)
		"jiangwei": _homing_barrage(run, unit, base * 2.0, 8)
		"zhugeliang": _zhugeliang(run, unit)
		"caoren":
			var caoren_damage: float = round((16.0 + int(run.wave) * 4.0) * (1.0 + int(unit.level) * 0.3) * (1.5 if run.relic_ids.has("jiuhu") else 1.0))
			_shock(run, unit, caoren_damage, 280.0, 1.0, 0.0)
		"zhoutai": _zhoutai(run, unit, base)
		"huatuo": _huatuo(run)
		"xiaoqiao": run.army_haste = {"t": 5.0, "mul": 1.4}
		"lusu":
			run.gain_xp(roundi(_alive(run).size() * 1.2))
			run.army_buff = {"t": 6.0, "mul": 1.3}
		"huanggai": _huanggai(run, unit)
		"xuhuang": _xuhuang(run)
		"daqiao": _daqiao(run)
		"huangyueying": _huangyueying(run, unit)
		"caiwenji":
			for enemy in _alive(run): enemy.sleepT = maxf(float(enemy.get("sleepT", 0.0)), 1.5 if bool(enemy.get("boss", false)) else 3.0)
		"gaoshun": _gaoshun(run, unit, base)
		"zhanghe": _zhanghe(run, unit, base)
		"zhurong": _fan_projectiles(run, unit, base, 5, 2.2, 2, 420.0, true)
		"wutugu":
			unit.ultT = 8.0
			unit.auraTick = 0.0
		"pangde": _lane_damage(run, unit, base * 2.4, 40.0, "e8dcc0", 4.0, 46.0)
		"yanliang": _yanliang(run, unit, base)
		"sunshangxiang": _fan_projectiles(run, unit, base, 10, 1.5, 0, 520.0, true)
		"yanyan": _yanyan(run, unit)
		"caohong":
			unit.hp = minf(float(unit.hp_max), float(unit.hp) + float(unit.hp_max) * 0.35)
			unit.guardT = 3.0
		"xushu":
			for enemy in _alive(run): enemy.armorBreakT = maxf(float(enemy.get("armorBreakT", 0.0)), 9.0 if run.relic_ids.has("shuijingshu") else 5.0)
		"simayi":
			var simayi_origin := _center(run, unit) - Vector2(0, 18)
			for ally in run.units():
				if ally != unit:
					ally.ultCd = maxf(0.0, float(ally.get("ultCd", 0.0)) - 10.0)
					_add_skill_line(run, simayi_origin, _center(run, ally), 0.35, "c9a8ff", 1.5, "beam")
			run.gain_xp(20.0)
		"jiaxu": _jiaxu(run, unit)
		"zuoci": _zuoci(run)
		"dengai": _dengai(run, unit, base)
		"menghuo": _menghuo(run, unit)
		"wenchou": _wenchou(run, unit, base)
	return true

func visual_effect(hero_id: String) -> String:
	return str(VISUAL_EFFECTS.get(hero_id, ""))

func _alive(run) -> Array:
	return run.enemies.filter(func(enemy): return not bool(enemy.get("dead", false)))

func _center(run, unit: Dictionary) -> Vector2:
	return run.slot_center(int(unit.row), int(unit.col))

func _in_range(run, unit: Dictionary) -> Array:
	var center := _center(run, unit) - Vector2(0, 18)
	var radius := float(unit.hero.get("rng", 0.0))
	return _alive(run).filter(func(enemy): return center.distance_squared_to(Vector2(float(enemy.x), float(enemy.y))) <= radius * radius)

func _in_column(run, unit: Dictionary) -> Array:
	var lane_x: float = float(run.GRID_X) + int(unit.col) * float(run.CELL) + float(run.CELL) / 2.0
	return _alive(run).filter(func(enemy): return absf(float(enemy.x) - lane_x) < 60.0)

func _near_wall(run, distance: float) -> Array:
	return _alive(run).filter(func(enemy): return float(enemy.y) > run.GRID_Y - distance)

func _densest(living: Array, radius: float) -> Dictionary:
	var best := {}
	for enemy in living:
		var n := living.filter(func(other): return Vector2(float(enemy.x), float(enemy.y)).distance_squared_to(Vector2(float(other.x), float(other.y))) < radius * radius).size()
		if best.is_empty() or n > int(best.n):
			best = {"x": float(enemy.x), "y": float(enemy.y), "n": n}
	return best

func _deal(run, unit: Dictionary, enemy: Dictionary, amount: float) -> void:
	if bool(enemy.get("dead", false)):
		return
	run.damage_enemy_from_unit(enemy, amount, str(unit.hero.get("elem", "")), unit)

func _zhangfei(run, unit: Dictionary, base: float) -> void:
	var center := _center(run, unit) - Vector2(0, 10)
	var radius := float(unit.hero.get("rng", 0.0)) + 60.0
	for enemy in _alive(run):
		if center.distance_squared_to(Vector2(float(enemy.x), float(enemy.y))) <= radius * radius:
			_deal(run, unit, enemy, base * 1.2)
			enemy.kb = maxf(float(enemy.get("kb", 0.0)), 140.0)
			enemy.fearT = maxf(float(enemy.get("fearT", 0.0)), 1.2)
	run.ripples.append({"x": center.x, "y": center.y, "r": 20.0, "max": radius, "kind": "fear"})

func _fan_projectiles(run, unit: Dictionary, base: float, count: int, multiplier: float, pierce: int, speed: float, burn: bool) -> void:
	var center := _center(run, unit) - Vector2(0, 18)
	var mods: Dictionary = run.team.unit_mods(run, unit)
	for index in count:
		var angle := -PI / 2.0 + (index - (count - 1) / 2.0) * (PI * 0.9 / count)
		run.projectiles.append({
			"x": center.x, "y": center.y, "vx": cos(angle) * speed, "vy": sin(angle) * speed,
			"damage": round(base * multiplier), "tri": str(unit.hero.elem), "r": 6.0 + int(unit.level),
			"distance": 0.0, "life": 2.2, "crit": float(mods.crit), "pierce": pierce,
			"burn": burn, "owner": unit, "hit": [], "dead": false,
		})

func _wall_bounce_arrow(run, unit: Dictionary, base: float) -> void:
	var center := _center(run, unit) - Vector2(0, 18)
	var direction := 1.0 if center.x < 240.0 else -1.0
	var mods: Dictionary = run.team.unit_mods(run, unit)
	run.projectiles.append({
		"x": center.x, "y": center.y, "vx": direction * 430.0, "vy": -115.0,
		"damage": round(base * 2.5), "tri": str(unit.hero.elem), "r": 9.0,
		"distance": 0.0, "life": 5.0, "wall_bounce": 6, "crit": float(mods.crit),
		"pierce": 999, "burn": false, "owner": unit, "hit": [], "dead": false,
	})

func _bouncing_halberd(run, unit: Dictionary, base: float) -> void:
	var living := _alive(run)
	if living.is_empty(): return
	var center := _center(run, unit) - Vector2(0, 18)
	living.sort_custom(func(a, b): return center.distance_squared_to(Vector2(float(a.x), float(a.y))) < center.distance_squared_to(Vector2(float(b.x), float(b.y))))
	var direction := center.direction_to(Vector2(float(living[0].x), float(living[0].y)))
	var mods: Dictionary = run.team.unit_mods(run, unit)
	run.projectiles.append({
		"x": center.x, "y": center.y, "vx": direction.x * 520.0, "vy": direction.y * 520.0,
		"damage": round(base * 6.0), "tri": str(unit.hero.elem), "r": 13.0,
		"distance": 0.0, "life": 3.5, "bounces": 9, "crit": float(mods.crit),
		"pierce": 0, "burn": false, "owner": unit, "hit": [], "dead": false,
	})

func _machao(run, unit: Dictionary, base: float) -> void:
	var center := _center(run, unit) - Vector2(0, 18)
	var search_radius := float(unit.hero.get("rng", 0.0)) + 40.0
	var targets := _alive(run).filter(func(enemy): return center.distance_squared_to(Vector2(float(enemy.x), float(enemy.y))) <= search_radius * search_radius)
	targets.sort_custom(func(a, b): return float(a.hp) > float(b.hp))
	if targets.is_empty(): return
	var main: Dictionary = targets[0]
	var main_point := Vector2(float(main.x), float(main.y))
	_add_skill_line(run, center, main_point, 0.32, "ffd24a", 2.0, "beam")
	_deal(run, unit, main, base * 7.0)
	var branches := _alive(run).filter(func(enemy): return enemy != main and Vector2(float(enemy.x), float(enemy.y)).distance_squared_to(Vector2(float(main.x), float(main.y))) < 200.0 * 200.0)
	branches.sort_custom(func(a, b): return Vector2(float(a.x), float(a.y)).distance_squared_to(Vector2(float(main.x), float(main.y))) < Vector2(float(b.x), float(b.y)).distance_squared_to(Vector2(float(main.x), float(main.y))))
	for index in mini(3, branches.size()):
		var branch: Dictionary = branches[index]
		_add_skill_line(run, main_point, Vector2(float(branch.x), float(branch.y)), 0.32, "ffd24a", 1.4, "beam")
		_deal(run, unit, branch, base * 3.0)

func _huangzhong(run, unit: Dictionary, base: float) -> void:
	var targets := _alive(run).filter(func(enemy): return bool(enemy.get("boss", false)) or enemy.get("affix") != null)
	if targets.is_empty(): targets = _alive(run)
	targets.sort_custom(func(a, b): return float(a.hp) > float(b.hp))
	if not targets.is_empty():
		var target: Dictionary = targets[0]
		_add_skill_line(run, _center(run, unit) - Vector2(0, 18), Vector2(float(target.x), float(target.y)), 0.35, "ffd24a", 2.5, "beam")
		_deal(run, unit, target, base * 16.0)

func _luxun(run, unit: Dictionary, base: float) -> void:
	var targets := _alive(run).duplicate()
	for index in 3:
		var target: Dictionary = run._pick(targets) if not targets.is_empty() else {}
		if not target.is_empty(): targets.erase(target)
		var x := clampf(float(target.get("x", 120.0 + index * 120.0)) + run._randf(-30.0, 30.0), 40.0, 440.0)
		var y := clampf(float(target.get("y", 360.0)) + run._randf(-20.0, 20.0), 100.0, run.GRID_Y - 60.0)
		var origin := _center(run, unit) - Vector2(0, 18)
		run.friendly_lobs.append({"x0": origin.x, "y0": origin.y, "x1": x, "y1": y, "t": 0.0, "dur": 0.7 + index * 0.12, "damage": 0.0, "splash": 0.0, "element": str(unit.hero.elem), "owner": unit, "icon": "🏺", "color": "ff7a3a", "pit": {"r": 85.0, "t": 7.0 if run.relic_ids.has("huoyou") else 5.0, "damage": maxf(4.0, round(base * 0.72))}, "dead": false})

func _lane_damage(run, unit: Dictionary, damage: float, top_y: float, color: String, width: float, hit_half_width: float) -> void:
	var lane_x: float = float(run.GRID_X) + int(unit.col) * float(run.CELL) + float(run.CELL) / 2.0
	var origin := _center(run, unit) - Vector2(0, 18)
	_add_skill_line(run, Vector2(lane_x, origin.y), Vector2(lane_x, top_y), 0.35, color, width, "beam")
	for enemy in _alive(run).duplicate():
		if absf(float(enemy.x) - lane_x) < hit_half_width:
			_deal(run, unit, enemy, damage)

func _cluster_damage(run, unit: Dictionary, damage: float, radius: float) -> void:
	var cluster := _densest(_alive(run), radius)
	if cluster.is_empty(): return
	for enemy in _alive(run).duplicate():
		if Vector2(float(enemy.x), float(enemy.y)).distance_squared_to(Vector2(float(cluster.x), float(cluster.y))) < radius * radius:
			_deal(run, unit, enemy, damage)

func _arrow_rain(run, unit: Dictionary, damage: float, radius: float) -> void:
	var cluster := _densest(_alive(run), radius)
	if cluster.is_empty():
		return
	var center := Vector2(float(cluster.x), float(cluster.y))
	for enemy in _alive(run).duplicate():
		if Vector2(float(enemy.x), float(enemy.y)).distance_squared_to(center) < radius * radius:
			_deal(run, unit, enemy, damage)
	for index in 10:
		var angle: float = run._randf(0.0, TAU)
		var spread: float = run._randf(0.0, 120.0)
		var landing: Vector2 = center + Vector2(cos(angle), sin(angle)) * spread
		run.friendly_lobs.append({"x0": landing.x + run._randf(-30.0, 30.0), "y0": -20.0, "x1": landing.x, "y1": landing.y, "t": 0.0, "dur": run._randf(0.25, 0.5), "damage": 0.0, "splash": 0.0, "element": str(unit.hero.elem), "owner": unit, "icon": "🏹", "color": "ffd24a", "pit": {}, "dead": false})

func _dianwei(run, unit: Dictionary, base: float) -> void:
	var center := _center(run, unit) - Vector2(0, 18)
	var search_radius := float(unit.hero.get("rng", 0.0)) + 40.0
	var targets := _alive(run).filter(func(enemy): return center.distance_squared_to(Vector2(float(enemy.x), float(enemy.y))) <= search_radius * search_radius)
	targets.sort_custom(func(a, b): return float(a.y) > float(b.y))
	if targets.is_empty(): return
	var target: Dictionary = targets[0]
	var point := Vector2(float(target.x), float(target.y))
	_add_skill_line(run, center, point, 0.18, "d5c9a8", 6.0, "slash")
	_deal(run, unit, target, base * 4.0)
	for enemy in _alive(run).duplicate():
		if enemy != target and point.distance_squared_to(Vector2(float(enemy.x), float(enemy.y))) < pow(120.0 + float(enemy.r), 2):
			_deal(run, unit, enemy, base * 2.0)

func _add_charge(run, unit: Dictionary, damage: float, tri: String, width: float, kb_mul := 0.0) -> void:
	var center := _center(run, unit)
	run.charges.append({"x": center.x, "y": center.y - 20.0, "vy": -340.0, "width": width, "damage": damage, "tri": tri, "crit": 0.0, "owner": unit, "hit": [], "dead": false, "kb_mul": kb_mul})

func _weiyan(run, unit: Dictionary, base: float) -> void:
	var targets := _alive(run)
	var count := 5 if run.relic_ids.has("jiguan") else 3
	for index in count:
		var enemy: Dictionary = run._pick(targets) if not targets.is_empty() else {}
		var x := clampf(float(enemy.get("x", run._randf(60.0, 420.0))) + run._randf(-50.0, 50.0), 30.0, 450.0)
		var y := clampf(float(enemy.get("y", run._randf(200.0, 380.0))) + run._randf(50.0, 110.0), 120.0, run.GRID_Y - 60.0)
		run.traps.append({"x": x, "y": y, "r": 26.0, "damage": round(base * 3.0), "splash": 80.0, "tri": str(unit.hero.elem), "owner": unit, "t": 10.0})
	while run.traps.size() > (15 if run.relic_ids.has("jiguan") else 9): run.traps.pop_front()

func _xuchu(run) -> void:
	var bond_multiplier := 2.0 if run.team.active_bonds.has("juma") else 1.0
	var duration := (6.0 if run.relic_ids.has("jili") else 4.0) * bond_multiplier
	var hp := (18.0 if run.relic_ids.has("jili") else 14.0) * bond_multiplier
	run.blockade = {"t": duration, "y": run.GRID_Y - 30.0, "hp": hp, "hp_max": hp}

func _bombard(run, unit: Dictionary, damage: float, count: int, radius: float) -> void:
	for index in count:
		var living := _alive(run)
		if living.is_empty(): return
		var target: Dictionary = run._pick(living)
		var x := clampf(float(target.x) + run._randf(-46.0, 46.0), 30.0, 450.0)
		var y := clampf(float(target.y) + run._randf(-36.0, 36.0), 80.0, run.GRID_Y - 50.0)
		var origin := _center(run, unit) - Vector2(0, 18)
		run.friendly_lobs.append({"x0": origin.x, "y0": origin.y, "x1": x, "y1": y, "t": 0.0, "dur": 0.55 + index * 0.1, "damage": round(damage), "splash": radius, "element": str(unit.hero.elem), "owner": unit, "icon": "🧨", "color": "ffd24a", "pit": {}, "dead": false})

func _diaochan(run) -> void:
	for enemy in _alive(run):
		if enemy.get("special") != null or bool(enemy.get("boss", false)):
			enemy.silencedT = 7.0 if run.relic_ids.has("chensha") else 5.0
	var mobs := _alive(run).filter(func(enemy): return enemy.get("special") == null and not bool(enemy.get("boss", false)))
	mobs.sort_custom(func(a, b): return float(a.y) > float(b.y))
	for index in mini(5, mobs.size()): mobs[index].charmT = maxf(float(mobs[index].get("charmT", 0.0)), 4.0)

func _zhouyu(run, unit: Dictionary, base: float) -> void:
	var living := _alive(run)
	var best_y := 0.0
	var best_n := 0
	for enemy in living:
		var n := living.filter(func(other): return absf(float(other.y) - float(enemy.y)) < 45.0).size()
		if n > best_n: best_n = n; best_y = float(enemy.y)
	if best_n > 0:
		_add_skill_line(run, Vector2(0.0, best_y), Vector2(480.0, best_y), 0.4, "ff7a3a", 3.0, "beam")
	for enemy in living.duplicate():
		if absf(float(enemy.y) - best_y) < 45.0:
			_deal(run, unit, enemy, base * 2.9)
			if not bool(enemy.get("dead", false)) and str(run.mutations.get(run.wave, "")) != "rainstorm":
				enemy.burnT = maxf(float(enemy.get("burnT", 0.0)), 4.0)
				var burn_damage := maxf(2.0, round(base * 0.5))
				if str(run.mutations.get(run.wave, "")) == "eastwind":
					burn_damage *= 2.0
				enemy.burnDmg = maxf(float(enemy.get("burnDmg", 0.0)), burn_damage)
				enemy.burnSrc = unit

func _homing_barrage(run, unit: Dictionary, damage: float, count: int) -> void:
	var living := _alive(run)
	if living.is_empty():
		return
	var center := _center(run, unit) - Vector2(0, 18)
	for index in count:
		run.homers.append({
			"x": center.x + run._randf(-14.0, 14.0), "y": center.y,
			"vx": run._randf(-180.0, 180.0), "vy": -240.0,
			"target": living[index % living.size()], "speed": 340.0,
			"damage": round(damage), "element": str(unit.hero.elem), "owner": unit,
			"life": 4.0, "color": "ff7a3a", "dead": false,
		})

func _zhugeliang(run, unit: Dictionary) -> void:
	var targets := _alive(run)
	targets.sort_custom(func(a, b): return float(a.hp) > float(b.hp))
	targets = targets.slice(0, mini(7 if run.relic_ids.has("xuantie") else 5, targets.size()))
	if targets.size() >= 2: run.death_link = {"members": targets, "t": 7.0, "owner": unit}

func _shock(run, unit: Dictionary, damage: float, radius: float, stun: float, knockback: float) -> void:
	var center := _center(run, unit)
	for enemy in _alive(run).duplicate():
		if center.distance_squared_to(Vector2(float(enemy.x), float(enemy.y))) <= radius * radius:
			_deal(run, unit, enemy, damage)
			enemy.stunT = maxf(float(enemy.get("stunT", 0.0)), stun)
			enemy.kb = maxf(float(enemy.get("kb", 0.0)), knockback)
	run.ripples.append({"x": center.x, "y": center.y, "r": 20.0, "max": radius, "kind": "shock"})

func _zhoutai(run, unit: Dictionary, _base: float) -> void:
	unit.hp = minf(float(unit.hp_max), float(unit.hp) + float(unit.hp_max) * 0.45)
	unit.reflectT = 3.0
	var spike_damage: float = round((10.0 + int(run.wave) * 3.0) * (1.0 + int(unit.level) * 0.3) * (1.5 if run.relic_ids.has("jiuhu") else 1.0))
	_shock(run, unit, spike_damage, 180.0, 0.0, 0.0)

func _huatuo(run) -> void:
	for ally in run.units():
		ally.hp = minf(float(ally.hp_max), float(ally.hp) + float(ally.hp_max) * 0.35)
		ally.sealedT = 0.0
		ally.rbuffs["heal"] = maxf(float(ally.rbuffs.get("heal", 0.0)), 6.0)

func _huanggai(run, unit: Dictionary) -> void:
	unit.hp = maxf(1.0, float(unit.hp) - round(float(unit.hp) * 0.4))
	var count := 0
	for enemy in _alive(run):
		count += 1
		enemy.burnT = maxf(float(enemy.get("burnT", 0.0)), 4.0)
		enemy.burnDmg = maxf(float(enemy.get("burnDmg", 0.0)), maxf(2.0, round((1.0 + run.wave * 0.5) * (1.0 + int(unit.level) * 0.2))))
	run.gain_xp(maxi(4, roundi(count * 0.8)))

func _xuhuang(run) -> void:
	var living := _alive(run)
	living.sort_custom(func(a, b): return float(a.y) > float(b.y))
	var x1 := clampf(float(living[0].x) if not living.is_empty() else 240.0, 100.0, 380.0)
	var cluster := _densest(living, 120.0)
	var x2 := clampf(float(cluster.get("x", 480.0 - x1)), 100.0, 380.0)
	if absf(x2 - x1) < 140.0: x2 = clampf(x1 + 190.0 if x1 < 240.0 else x1 - 190.0, 100.0, 380.0)
	var bond_multiplier := 2.0 if run.team.active_bonds.has("juma") else 1.0
	var hp := (16.0 if run.relic_ids.has("jili") else 12.0) * bond_multiplier
	var duration := (6.5 if run.relic_ids.has("jili") else 5.5) * bond_multiplier
	run.palisades.append({"x": x1, "width": 108.0, "y": run.GRID_Y - 36.0, "t": duration, "hp": hp, "hp_max": hp})
	run.palisades.append({"x": x2, "width": 108.0, "y": run.GRID_Y - 108.0, "t": duration, "hp": hp, "hp_max": hp})

func _daqiao(run) -> void:
	for enemy in _alive(run): enemy.slowT = maxf(float(enemy.get("slowT", 0.0)), 4.0)
	for ally in run.units(): ally.hp = minf(float(ally.hp_max), float(ally.hp) + float(ally.hp_max) * 0.12)
	run.ripples.append({"x": 240.0, "y": 300.0, "r": 20.0, "max": 640.0, "kind": "ice"})

func _huangyueying(run, unit: Dictionary) -> void:
	var cluster := _densest(_alive(run), 140.0)
	var x: float
	var y: float
	if not run.obstacles.is_empty():
		var obstacle_keys: Array = run.obstacles.keys()
		var best_key := str(obstacle_keys[0])
		var best_distance := INF
		for obstacle_key in obstacle_keys:
			var parts := str(obstacle_key).split(",")
			var point: Vector2 = run.slot_center(int(parts[0]), int(parts[1]))
			var distance: float = point.distance_squared_to(Vector2(float(cluster.get("x", point.x)), float(cluster.get("y", point.y))))
			if distance < best_distance:
				best_distance = distance
				best_key = str(obstacle_key)
		var best_parts := best_key.split(",")
		var obstacle_point: Vector2 = run.slot_center(int(best_parts[0]), int(best_parts[1]))
		x = obstacle_point.x
		y = obstacle_point.y - 8.0
	else:
		x = clampf(float(cluster.get("x", 240.0)), 60.0, 420.0)
		y = run.GRID_Y - 90.0
	var life := 13.0 if run.relic_ids.has("jiguan") else 10.0
	var damage := maxf(4.0, round((5.0 + run.wave * 1.6) * (1.0 + (int(unit.level) - 1) * 0.35) * float(run.buffs.dmg)))
	run.turrets.append({"x": x, "y": y, "t": life, "t_max": life, "cd": 0.2, "range": 420.0, "rate": 0.32, "damage": damage, "tri": str(unit.hero.elem), "owner": unit})
	var origin := _center(run, unit) - Vector2(0, 18)
	run.friendly_lobs.append({"x0": origin.x, "y0": origin.y, "x1": x, "y1": y, "t": 0.0, "dur": 0.5, "damage": 0.0, "splash": 0.0, "element": str(unit.hero.elem), "owner": unit, "icon": "⚙️", "color": "ffd24a", "pit": {}, "dead": false})

func _add_skill_line(run, from: Vector2, to: Vector2, duration: float, color: String, width: float, kind: String) -> void:
	run.skill_lines.append({"from": from, "to": to, "t": duration, "t_max": duration, "color": color, "width": width, "kind": kind})

func _gaoshun(run, unit: Dictionary, base: float) -> void:
	var lane_x: float = float(run.GRID_X) + int(unit.col) * float(run.CELL) + float(run.CELL) / 2.0
	var center := _center(run, unit) - Vector2(0, 18)
	var targets := _alive(run).filter(func(enemy): return absf(float(enemy.x) - lane_x) < run.CELL * 1.5 + 30.0 and center.distance_squared_to(Vector2(float(enemy.x), float(enemy.y))) < 400.0 * 400.0)
	if targets.is_empty(): return
	var gy := 0.0
	for enemy in targets: gy += float(enemy.y)
	gy = clampf(gy / targets.size(), 80.0, run.GRID_Y - 60.0)
	for enemy in targets:
		var point := Vector2(float(enemy.x), float(enemy.y)).move_toward(Vector2(lane_x, gy), 30.0 if bool(enemy.get("boss", false)) else 90.0)
		point.x = clampf(point.x, float(enemy.r), 480.0 - float(enemy.r))
		enemy.x = point.x; enemy.y = point.y
		_add_skill_line(run, center, point, 0.25, "d5c9a8", 1.3, "beam")
	for enemy in _alive(run).duplicate():
		if Vector2(float(enemy.x), float(enemy.y)).distance_squared_to(Vector2(lane_x, gy)) < pow(90.0 + float(enemy.r), 2): _deal(run, unit, enemy, base * 2.5)

func _zhanghe(run, unit: Dictionary, base: float) -> void:
	var lanes := []
	for col in run.GRID_COLS:
		var x: float = float(run.GRID_X) + col * float(run.CELL) + float(run.CELL) / 2.0
		lanes.append({"x": x, "n": _alive(run).filter(func(enemy): return absf(float(enemy.x) - x) < 60.0).size()})
	lanes.sort_custom(func(a, b): return int(a.n) > int(b.n))
	for lane in lanes.slice(0, mini(3, lanes.size())):
		if int(lane.n) > 0:
			run.charges.append({"x": float(lane.x), "y": _center(run, unit).y - 20.0, "vy": -340.0, "width": 34.0 + float(run.buffs.get("cavWide", 0.0)), "damage": round(base * 0.6), "tri": str(unit.hero.elem), "crit": 0.0, "owner": unit, "hit": [], "dead": false})

func _yanliang(run, unit: Dictionary, base: float) -> void:
	var targets := _alive(run).filter(func(enemy): return not bool(enemy.get("boss", false)) and (enemy.get("special") != null or enemy.get("affix") != null))
	targets.sort_custom(func(a, b): return float(a.hp) > float(b.hp))
	if targets.is_empty(): return
	var target: Dictionary = targets[0]
	_deal(run, unit, target, base * 4.5)
	if not bool(target.get("dead", false)) and float(target.hp) < float(target.hp_max) * 0.25: _deal(run, unit, target, float(target.hp) + 99.0)

func _yanyan(run, unit: Dictionary) -> void:
	var center := _center(run, unit)
	for enemy in _alive(run):
		if center.distance_squared_to(Vector2(float(enemy.x), float(enemy.y))) <= 210.0 * 210.0: enemy.slowT = maxf(float(enemy.get("slowT", 0.0)), 4.0)
	unit.hp = minf(float(unit.hp_max), float(unit.hp) + float(unit.hp_max) * 0.2)

func _jiaxu(run, unit: Dictionary) -> void:
	var candidates := _alive(run).filter(func(enemy): return enemy.get("special") == null and not bool(enemy.get("boss", false)) and enemy.get("affix") == null and not bool(enemy.get("big", false)))
	candidates.sort_custom(func(a, b): return float(a.hp_max) > float(b.hp_max))
	for index in mini(4, candidates.size()):
		candidates[index].turncoatT = 3.0
		candidates[index].turncoatTick = 0.0
		candidates[index].turncoatOwner = unit

func _zuoci(run) -> void:
	var targets := _alive(run).filter(func(enemy): return enemy.get("special") == null and not bool(enemy.get("boss", false)))
	targets.sort_custom(func(a, b): return float(a.hp_max) > float(b.hp_max))
	for index in mini(3, targets.size()):
		targets[index].stunT = maxf(float(targets[index].get("stunT", 0.0)), 5.0)
		targets[index].jianjunT = 5.0
		targets[index].jianjunAmp = 0.3
		targets[index].face_override = "羊"

func _dengai(run, unit: Dictionary, base: float) -> void:
	var row_y := _center(run, unit).y
	_add_skill_line(run, Vector2(10.0, row_y), Vector2(470.0, row_y), 0.22, "c9b69a", 8.0, "slash")
	var on_rock: bool = run.obstacles.has("%d,%d" % [int(unit.row), int(unit.col)])
	for enemy in _alive(run).duplicate():
		if absf(float(enemy.y) - row_y) <= 70.0:
			_deal(run, unit, enemy, base * (5.0 if on_rock else 3.0))
			enemy.stunT = maxf(float(enemy.get("stunT", 0.0)), 0.6)

func _menghuo(run, unit: Dictionary) -> void:
	for enemy in _alive(run):
		if enemy.get("special") == null and not bool(enemy.get("boss", false)): enemy.fearT = maxf(float(enemy.get("fearT", 0.0)), 1.5)
	unit.hp = minf(float(unit.hp_max), float(unit.hp) + round(float(unit.hp_max) * 0.3))

func _wenchou(run, unit: Dictionary, base: float) -> void:
	var targets := _alive(run).filter(func(enemy): return float(enemy.get("duelT", 0.0)) > 0)
	targets.sort_custom(func(a, b): return float(a.hp_max) > float(b.hp_max))
	if not targets.is_empty():
		var target: Dictionary = targets[0]
		_add_skill_line(run, _center(run, unit) - Vector2(0, 18), Vector2(float(target.x), float(target.y)), 0.2, "ff8a5a", 7.0, "slash")
		_deal(run, unit, target, base * 8.0)
