class_name BattleLord
extends RefCounted

const OpeningPicker = preload("res://src/progression/opening_picker.gd")

const ATTACKS := {
	"caocao": {"name": "掷戟", "mul": 1.0, "color": "ffd24a"},
	"yuanshao": {"name": "门客暗箭", "mul": 1.0, "color": "c9a8ff"},
	"yuanshu": {"name": "玉玺砸人", "mul": 1.0, "color": "ffd24a"},
	"sunquan": {"name": "楼船连弩", "mul": 1.6, "color": "4ab0ff"},
	"liubiao": {"name": "寒江霜箭", "mul": 1.6, "color": "8ad2ff"},
	"liubei": {"name": "双股剑气", "mul": 1.5, "color": "ffe8c0"},
	"dongzhuo": {"name": "火油瓶", "mul": 1.5, "color": "ff8a3a"},
	"gongsunzan": {"name": "城头强弩", "mul": 1.4, "color": "e8dcc0"},
}

const COMMANDS := {
	"wuxing": {"name": "三才破敌", "cd": 30.0},
	"taoyuan": {"name": "桃园义", "cd": 55.0},
	"jiejiang": {"name": "截江断流", "cd": 32.0},
	"mensheng": {"name": "门生故吏", "cd": 48.0},
	"bingfeng": {"name": "冰封", "cd": 30.0},
	"baima": {"name": "白马义从", "cd": 30.0},
	"fenluo": {"name": "火烧雒阳", "cd": 28.0},
	"jianhao": {"name": "僭号称帝", "cd": 45.0},
}

func skill_level(ruler_level: int) -> int:
	return mini(3, 1 + int(floor((ruler_level - 1) / 8.0)))

func cooldown_max(run) -> float:
	var command: Dictionary = COMMANDS.get(run.lord_skill_id, {})
	if command.is_empty():
		return 0.0
	var cooldown := float(command.cd)
	if run.lord_skill_id == "jianhao":
		cooldown += mini(6, int(run.jianhao_count)) * 12.0
	cooldown *= 1.0 - passive_level(run, "supply") * 0.04
	if run.relic_ids.has("sunzi"):
		cooldown *= 0.75
	if run.relic_ids.has("yushan"):
		cooldown *= 0.85
	return cooldown

func passive_level(run, passive_id: String) -> int:
	var ruler: Dictionary = run.catalog.by_id("rulers", run.ruler_id)
	var result := 0
	for passive in ruler.get("passives", []):
		if str(passive.get("id", "")) != passive_id:
			continue
		for threshold in passive.get("at", []):
			if run.ruler_level >= int(threshold):
				result += 1
	return result

func auto_ready(run) -> bool:
	var live: Array = _live_enemies(run)
	match run.lord_skill_id:
		"wuxing": return live.size() >= 8
		"bingfeng": return live.size() >= 6
		"taoyuan":
			return run.taoyuan_time <= 0 and not live.is_empty() and (
				run.units().any(func(unit): return not ["granary", "egg", "dragon"].has(str(unit.hero.cls)) and float(unit.hp) < float(unit.hp_max) * 0.55)
				or live.any(func(enemy): return float(enemy.y) > run.DEFENSE_LINE - 150.0)
			)
		"jiejiang": return live.filter(func(enemy): return float(enemy.y) > 300.0 and float(enemy.y) < 430.0).size() >= 4
		"mensheng": return run.wide_picks <= 0 and run.wave >= 2
		"baima": return live.any(func(enemy): return _is_special(enemy) or bool(enemy.get("boss", false))) or live.size() >= 8
		"fenluo": return live.size() >= 6 and run.wall >= 5
		"jianhao": return not jianhao_target(run).is_empty()
		_: return not live.is_empty()

func cast_command(run) -> bool:
	if bool(run.permanent_tactics.get("gewu", false)) or run.lord_command_cd > 0 or run.lord_skill_id.is_empty():
		return false
	var live := _live_enemies(run)
	if ["wuxing", "taoyuan", "jiejiang", "bingfeng", "baima", "fenluo"].has(run.lord_skill_id) and live.is_empty():
		return false
	if run.lord_skill_id == "taoyuan" and run.taoyuan_time > 0:
		return false
	if run.lord_skill_id == "mensheng" and run.wide_picks > 0 and not (run.awaiting_card_choice and not run.picking_relic and run.card_choices.size() < 5):
		return false
	if run.lord_skill_id == "fenluo" and run.wall < 3:
		return false
	if run.lord_skill_id == "jianhao" and jianhao_target(run).is_empty():
		return false
	run.lord_command_cd_total = cooldown_max(run)
	run.lord_command_cd = run.lord_command_cd_total
	run.lord_command_used += 1
	var level := int(run.lord_skill_level)
	match run.lord_skill_id:
		"wuxing":
			run.wuxing_time = (6.0 + level * 2.0) * kin_power(run)
		"bingfeng":
			var duration := (1.0 + level * 0.7) * kin_power(run)
			for enemy in live:
				enemy.stunT = maxf(float(enemy.get("stunT", 0.0)), duration * (0.6 if bool(enemy.get("boss", false)) else 1.0))
				var slow_duration := (duration + 2.0) * (1.3 if run.relic_ids.has("jiaowei") else 1.0)
				enemy.slowT = maxf(float(enemy.get("slowT", 0.0)), slow_duration)
		"taoyuan":
			run.taoyuan_time = (4.0 + level * 2.0) * kin_power(run)
			run.taoyuan_absorb = 0.0
		"jiejiang":
			run.flood = {"y1": 330.0, "y2": 415.0, "amp": (0.2 + level * 0.1) * kin_power(run), "t": 5.0 + level * 2.0}
		"mensheng":
			run.wide_picks += level
			if run.awaiting_card_choice and not run.picking_relic and run.card_choices.size() < 5:
				run.card_system.widen_current(run, run.card_choices, 5)
				run.wide_picks = maxi(0, run.wide_picks - 1)
		"baima":
			var power := kin_power(run)
			run.lord_mount = {
				"x": 240.0, "y": run.DEFENSE_LINE + 16.0,
				"t": (5.0 + level * 2.0) * power,
				"hitT": 0.0,
				"damage": (20.0 + run.wave * 2.5) * (1.1 + level * 0.3) * power,
			}
		"fenluo":
			run.wall = maxi(1, run.wall - 2)
			run.tyranny += 8.0
			var damage: float = (35.0 + float(run.wave) * 4.0) * (0.8 + level * 0.2) * kin_power(run)
			var lord_y: float = float(run.DEFENSE_LINE) + 28.0
			for enemy in live:
				var dx := float(enemy.x) - 240.0
				var dy: float = lord_y - float(enemy.y)
				if dy <= 0 or absf(dx) > dy * 1.25:
					continue
				run.damage_enemy(enemy, damage)
				enemy.burnT = maxf(float(enemy.get("burnT", 0.0)), 3.0)
				enemy.burnDmg = maxf(float(enemy.get("burnDmg", 0.0)), 6.0 + run.wave)
		"jianhao":
			_cast_jianhao(run, level)
	run.lord_command_events.append({"id": run.lord_skill_id, "t": 0.8})
	return true

func update_command(run, delta: float) -> void:
	if run.lord_command_cd > 0:
		run.lord_command_cd = maxf(0.0, run.lord_command_cd - delta)
	update_effects(run, delta)
	if run.lord_command_cd <= 0 and auto_ready(run):
		cast_command(run)

func update_effects(run, delta: float) -> void:
	run.wuxing_time = maxf(0.0, run.wuxing_time - delta)
	if not run.flood.is_empty():
		run.flood.t = float(run.flood.t) - delta
		if float(run.flood.t) <= 0:
			run.flood = {}
	var taoyuan_before := float(run.taoyuan_time)
	run.taoyuan_time = maxf(0.0, taoyuan_before - delta)
	if taoyuan_before > 0 and run.taoyuan_time <= 0 and run.taoyuan_absorb > 0:
		var counter_damage := maxf(1.0, round(run.taoyuan_absorb))
		run.taoyuan_absorb = 0.0
		var dealt_total := 0.0
		for enemy in _live_enemies(run).duplicate():
			var hp_before := float(enemy.hp)
			run.damage_enemy(enemy, counter_damage)
			dealt_total += maxf(0.0, hp_before - maxf(0.0, float(enemy.hp)))
			if not bool(enemy.get("dead", false)):
				enemy.stunT = maxf(float(enemy.get("stunT", 0.0)), 0.5 if bool(enemy.get("boss", false)) else 1.0)
				enemy.kb = minf(160.0, float(enemy.get("kb", 0.0)) + (22.5 if bool(enemy.get("boss", false)) else 90.0))
		if dealt_total > 0:
			run.gain_xp(maxf(1.0, round(dealt_total * 0.08)))
	if not run.lord_mount.is_empty():
		_update_mount(run, delta)
	for event in run.lord_command_events:
		event.t = float(event.t) - delta
	for index in range(run.lord_command_events.size() - 1, -1, -1):
		if float(run.lord_command_events[index].t) <= 0:
			run.lord_command_events.remove_at(index)

func jianhao_target(run) -> Dictionary:
	var fighters: Array = run.units().filter(func(unit): return not ["granary", "egg", "dragon"].has(str(unit.hero.cls)))
	if fighters.size() < 5:
		return {}
	var candidates: Array = fighters.filter(func(unit): return int(unit.level) <= 3)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a, b):
		if int(a.level) != int(b.level):
			return int(a.level) < int(b.level)
		return int(run.hero_levels.get(str(a.hero.id), 1)) < int(run.hero_levels.get(str(b.hero.id), 1))
	)
	return candidates[0]

func _cast_jianhao(run, level: int) -> void:
	var target := jianhao_target(run)
	if target.is_empty():
		return
	var target_level := int(target.level)
	var target_row := -1
	var target_col := -1
	for row in run.GRID_ROWS:
		for col in run.GRID_COLS:
			if run.grid[row][col] == target:
				target_row = row
				target_col = col
				break
		if target_row >= 0:
			break
	if target_row >= 0:
		run.grid[target_row][target_col] = null
	run.team.recompute(run)
	var level_ups: int = (3 if level >= 2 else 2) + target_level
	var field: Dictionary = run.catalog.by_id("fields", str(run.city.get("field", "")))
	var xp_multiplier := maxf(0.01, float(run.buffs.get("xpGain", 1.0)) * float(field.get("xpMul", 1.0)))
	var target_run_level: int = int(run.level) + level_ups
	var guard := 0
	while run.level < target_run_level and guard < 200:
		run.gain_xp(maxf(1.0, run.xp_need - run.xp) / xp_multiplier)
		guard += 1
	var power := kin_power(run)
	if power > 1.0:
		run.gain_xp(run.xp_need * (power - 1.0) * 0.8 / xp_multiplier)
	run.jianhao_count += 1

func _update_mount(run, delta: float) -> void:
	var mount: Dictionary = run.lord_mount
	mount.t = float(mount.t) - delta
	if float(mount.t) <= 0:
		run.lord_mount = {}
		return
	var target: Dictionary = {}
	var best_score := -INF
	for enemy in _live_enemies(run):
		if float(enemy.y) < -10.0:
			continue
		var score := (3000.0 if _is_special(enemy) else 0.0) + (2000.0 if bool(enemy.get("boss", false)) else 0.0) + float(enemy.get("dmg", 0.0)) * 50.0 \
			- Vector2(float(enemy.x), float(enemy.y)).distance_to(Vector2(float(mount.x), float(mount.y))) * 0.5
		if score > best_score:
			best_score = score
			target = enemy
	if target.is_empty():
		return
	var mount_pos := Vector2(float(mount.x), float(mount.y))
	var target_pos := Vector2(float(target.x), float(target.y))
	var distance := mount_pos.distance_to(target_pos)
	if distance > float(target.r) + 14.0:
		mount_pos = mount_pos.move_toward(target_pos, 300.0 * delta)
		mount.x = mount_pos.x
		mount.y = mount_pos.y
	mount.hitT = float(mount.hitT) - delta
	if distance <= float(target.r) + 24.0 and float(mount.hitT) <= 0:
		mount.hitT = 0.35
		run.damage_enemy(target, float(mount.damage), "", "lord")

func _live_enemies(run) -> Array:
	return run.enemies.filter(func(enemy): return not bool(enemy.get("dead", false)))

func kin_power(run) -> float:
	var lord_kin: Dictionary = run.catalog.content.get("lord_kin", {})
	var count := 0
	for unit in run.units():
		if OpeningPicker.is_kin(str(unit.hero.id), run.ruler_id, lord_kin):
			count += 1
	return minf(1.8, 1.0 + count * 0.2)

func update_auto_attack(run, delta: float) -> void:
	if run.status != "play" or run.ruler_id.is_empty():
		return
	if run.ruler_id != "gongsunzan" and bool(run.permanent_tactics.get("gewu", false)):
		return
	var attack: Dictionary = ATTACKS.get(run.ruler_id, {})
	if attack.is_empty():
		return
	var present: Array = run.enemies.filter(func(enemy): return not bool(enemy.get("dead", false)))
	if present.is_empty():
		return
	run.lord_attack_timer -= delta
	if run.lord_attack_timer > 0:
		return
	var live: Array = present.filter(func(enemy): return float(enemy.get("y", -1.0)) > 0.0)
	if live.is_empty():
		return
	live.sort_custom(func(a, b): return float(a.y) > float(b.y))
	var haste := float(run.lord_atk_gap) * (0.8 if run.relic_ids.has("yushan") else 1.0)
	if run.ruler_id == "gongsunzan":
		run.lord_attack_timer = 2.5 * haste
		_hit_crossbow(run, live[0], attack)
		return
	run.lord_attack_timer = 3.0 * haste
	var target: Dictionary = live[0]
	match run.ruler_id:
		"sunquan":
			for index in mini(3, live.size()):
				_hit(run, live[index], 1.0, attack)
		"liubiao":
			for enemy in live:
				if Vector2(float(enemy.x), float(enemy.y)).distance_to(Vector2(float(target.x), float(target.y))) > 80.0:
					continue
				_hit(run, enemy, 1.0 if enemy == target else 0.6, attack)
				enemy.slowT = maxf(float(enemy.get("slowT", 0.0)), 1.2)
			_append_ring(run, target, 80.0, "8ad2ff")
		"liubei":
			var cut := 0
			for enemy in live:
				if absf(float(enemy.y) - float(target.y)) > 40.0 or absf(float(enemy.x) - float(target.x)) > 90.0 or cut >= 4:
					continue
				_hit(run, enemy, 1.0 if enemy == target else 0.7, attack)
				cut += 1
		"dongzhuo":
			for enemy in live:
				if Vector2(float(enemy.x), float(enemy.y)).distance_to(Vector2(float(target.x), float(target.y))) > 65.0:
					continue
				_hit(run, enemy, 0.9 if enemy == target else 0.55, attack)
				enemy.burnT = maxf(float(enemy.get("burnT", 0.0)), 2.0)
				enemy.burnDmg = maxf(float(enemy.get("burnDmg", 0.0)), 2.0 + run.wave * 0.4)
			_append_ring(run, target, 65.0, "ff8a3a")
		_:
			_hit(run, target, 1.0, attack)

func _hit(run, enemy: Dictionary, coefficient: float, attack: Dictionary) -> void:
	var lord_modifier: float = (1.0 + 0.02 * float(run.ruler_level)) * kin_power(run) * float(attack.mul)
	var amount: float = ((7.0 + float(run.wave) * 0.75) * (1.0 + float(run.lord_atk_buff)) + float(enemy.hp_max) * 0.03) * coefficient * lord_modifier
	_append_trace(run, enemy, str(attack.color))
	run.damage_enemy(enemy, amount, "", "lord")

func _is_special(enemy: Dictionary) -> bool:
	var special = enemy.get("special", null)
	return special != null and not str(special).is_empty()

func _hit_crossbow(run, enemy: Dictionary, attack: Dictionary) -> void:
	var wall_ratio := float(run.wall) / maxf(1.0, float(run.wall_max))
	var amount: float = ((6.0 + float(run.wave) * 1.2) * (1.0 + float(run.lord_atk_buff)) + float(enemy.hp_max) * 0.03) \
		* wall_ratio * (1.0 + 0.03 * float(run.ruler_level)) * float(attack.mul)
	_append_trace(run, enemy, str(attack.color))
	run.damage_enemy(enemy, amount, "", "lord")

func _append_trace(run, enemy: Dictionary, color: String) -> void:
	run.lord_attack_traces.append({
		"x1": 240.0,
		"y1": run.DEFENSE_LINE + 28.0,
		"x2": float(enemy.x),
		"y2": float(enemy.y),
		"color": color,
		"t": 0.28,
	})

func _append_ring(run, enemy: Dictionary, radius: float, color: String) -> void:
	run.lord_effect_rings.append({
		"x": float(enemy.x),
		"y": float(enemy.y),
		"radius": radius,
		"color": color,
		"t": 0.35,
	})
