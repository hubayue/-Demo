class_name BattleEnvironment
extends RefCounted

const BattleRecords = preload("res://src/progression/battle_records.gd")

var volcano_time := 10.0
var tower_time := 5.0
var boulder_time := 8.0
var luanshi_wave := -1
var shuiyan_wave := -1

func setup(run) -> void:
	volcano_time = 10.0
	tower_time = 5.0
	boulder_time = 8.0
	luanshi_wave = -1
	shuiyan_wave = -1
	var field: Dictionary = _field(run)
	var wall_add: int = int(field.get("wallAdd", 0))
	if wall_add > 0:
		run.wall += wall_add
		run.wall_max += wall_add

func update(run, delta: float) -> void:
	var mutation: String = str(run.mutations.get(run.wave, ""))
	if mutation == "rainstorm":
		for enemy in run.enemies:
			enemy.burnT = 0.0
			enemy.burnDmg = 0.0
			enemy.burnTick = 0.0
	_update_field_events(run, delta)
	_update_permanent_tactics(run)

func movement_multiplier(run, enemy: Dictionary) -> float:
	var band: Dictionary = _field(run).get("band", {})
	if band.is_empty():
		return 1.0
	var y: float = float(enemy.get("y", 0.0))
	return float(band.get("slow", 1.0)) if y >= float(band.get("y1", 0.0)) and y <= float(band.get("y2", 0.0)) else 1.0

func burn_multiplier(run) -> float:
	var result := float(_field(run).get("burnMul", 1.0))
	if run.relic_ids.has("huoyou"): result *= 1.5
	if str(run.city.get("theme", "")) == "liaoyuan": result *= 1.5
	if str(run.mutations.get(run.wave, "")) == "eastwind": result *= 1.6
	return result

func on_enemy_death(run, enemy: Dictionary) -> void:
	if bool(run.permanent_tactics.get("huoshao", false)) and float(enemy.get("burnT", 0.0)) > 0 and float(enemy.get("burnDmg", 0.0)) > 0:
		var center: Vector2 = Vector2(float(enemy.x), float(enemy.y))
		for other in run.enemies.duplicate():
			if other == enemy or bool(other.get("dead", false)) or center.distance_squared_to(Vector2(float(other.x), float(other.y))) > 90.0 * 90.0:
				continue
			run.damage_enemy(other, float(enemy.burnDmg) * 3.0, "", str(enemy.get("burnSrc", "fire")))
			if not bool(other.get("dead", false)) and str(run.mutations.get(run.wave, "")) != "rainstorm":
				other.burnT = maxf(float(other.get("burnT", 0.0)), 2.0)
				other.burnDmg = maxf(float(other.get("burnDmg", 0.0)), round(float(enemy.burnDmg) * 0.8))
				other.burnSrc = str(enemy.get("burnSrc", other.get("burnSrc", "fire")))
	var gold_gain: float = 10.0 if bool(enemy.get("boss", false)) else 1.0
	gold_gain *= float(enemy.get("bounty", 1.0))
	if run.relic_ids.has("yuxi"): gold_gain *= 2.0
	gold_gain *= float(run.city.get("goldMul", 1.0))
	if int(run.city.get("visitGoldUntil", 0)) > int(Time.get_unix_time_from_system() * 1000.0): gold_gain *= 1.2
	gold_gain *= float(_field(run).get("goldMul", 1.0))
	var mutation: String = str(run.mutations.get(run.wave, ""))
	if run.relic_ids.has("tongque") and not mutation.is_empty() and not ["fat", "eastwind"].has(mutation):
		gold_gain *= 1.5
	if run.endless and run.win_wave > 0:
		gold_gain *= BattleRecords.endless_gold_multiplier(run.wave, run.win_wave)
	run.run_gold += gold_gain

func _update_field_events(run, delta: float) -> void:
	var field: Dictionary = _field(run)
	if field.has("volcano"):
		volcano_time -= delta
		if volcano_time <= 0 and _has_live(run):
			volcano_time = float(field.volcano)
			_cast_volcano(run)
	if bool(field.get("tower", false)):
		tower_time -= delta
		if tower_time <= 0 and _has_live(run):
			tower_time = 15.0
			_cast_tower(run)
	if field.has("boulder"):
		boulder_time -= delta
		if boulder_time <= 0 and _has_live(run):
			boulder_time = float(field.boulder)
			_cast_boulder(run)

func _update_permanent_tactics(run) -> void:
	var live: Array = run.enemies.filter(func(enemy): return not bool(enemy.get("dead", false)) and float(enemy.get("y", -1.0)) > 0.0)
	if bool(run.permanent_tactics.get("luanshi", false)) and luanshi_wave != run.wave and live.size() >= 5 and not run.obstacles.is_empty():
		luanshi_wave = run.wave
		for key in run.obstacles.keys():
			var parts: PackedStringArray = str(key).split(",")
			var origin: Vector2 = run.slot_center(int(parts[0]), int(parts[1]))
			var targets: Array = live.filter(func(enemy): return not bool(enemy.get("dead", false)))
			if targets.is_empty(): break
			targets.sort_custom(func(a, b): return origin.distance_squared_to(Vector2(float(a.x), float(a.y))) < origin.distance_squared_to(Vector2(float(b.x), float(b.y))))
			var target: Dictionary = targets[0]
			run.damage_enemy(target, (12.0 + run.wave * 2.5) + float(target.hp_max) * 0.04, "", "rock")
	var has_water: bool = bool(run.permanent_tactics.get("shuiyan", false)) or run.ruler_id == "sunquan"
	if has_water and shuiyan_wave != run.wave and run.flood.is_empty() and live.any(func(enemy): return float(enemy.y) > 250.0):
		shuiyan_wave = run.wave
		var both: bool = bool(run.permanent_tactics.get("shuiyan", false)) and run.ruler_id == "sunquan"
		var duration: float = 7.0 if both else (4.0 if bool(run.permanent_tactics.get("shuiyan", false)) else 4.5 + run.ruler_level * 0.15)
		var amp: float = 0.4 if both else (0.25 if bool(run.permanent_tactics.get("shuiyan", false)) else 0.2 + 0.005 * run.ruler_level)
		run.flood = {"y1": 330.0, "y2": 415.0, "amp": amp, "t": duration}
	if bool(run.permanent_tactics.get("zhanshou", false)):
		for enemy in live.duplicate():
			if bool(enemy.get("_qz", false)) or not (bool(enemy.get("boss", false)) or enemy.get("special") != null or bool(enemy.get("big", false)) or enemy.get("affix") != null):
				continue
			enemy._qz = true
			var damage: float = _lord_shot_estimate(run) * 5.0 + float(enemy.hp_max) * 0.05
			run.damage_enemy(enemy, damage, "", "lord")

func _cast_volcano(run) -> void:
	var live: Array = run.enemies.filter(func(enemy): return not bool(enemy.get("dead", false)))
	var center: Vector2 = _densest_center(live, 110.0)
	var damage: float = round(10.0 + run.wave * 2.5)
	for enemy in live.duplicate():
		if center.distance_squared_to(Vector2(float(enemy.x), float(enemy.y))) >= pow(110.0 + float(enemy.r), 2): continue
		run.damage_enemy(enemy, damage, "", "field")
		if not bool(enemy.get("dead", false)) and str(run.mutations.get(run.wave, "")) != "rainstorm":
			enemy.burnT = maxf(float(enemy.get("burnT", 0.0)), 3.0)
			enemy.burnDmg = maxf(float(enemy.get("burnDmg", 0.0)), maxf(2.0, round(damage * 0.2)))
			enemy.burnSrc = "field"
	run.field_events.append({"kind": "volcano", "x": center.x, "y": center.y, "t": 0.8})

func _cast_tower(run) -> void:
	var targets: Array = run.enemies.filter(func(enemy): return not bool(enemy.get("dead", false)))
	targets.sort_custom(func(a, b): return float(a.y) > float(b.y))
	var damage: float = round(8.0 + run.wave * 3.0)
	for index in mini(5, targets.size()):
		var enemy: Dictionary = targets[index]
		run.damage_enemy(enemy, damage, "", "field")
		if not bool(enemy.get("dead", false)) and str(run.mutations.get(run.wave, "")) != "rainstorm":
			enemy.burnT = maxf(float(enemy.get("burnT", 0.0)), 2.0)
			enemy.burnDmg = maxf(float(enemy.get("burnDmg", 0.0)), maxf(2.0, round(damage * 0.15)))
			enemy.burnSrc = "field"
		run.field_events.append({"kind": "tower", "x": float(enemy.x), "y": float(enemy.y), "t": 0.45})

func _cast_boulder(run) -> void:
	var best_col: int = 0
	var best_count: int = -1
	for col in run.GRID_COLS:
		var center_x: float = run.GRID_X + col * run.CELL + run.CELL / 2.0
		var count: int = run.enemies.filter(func(enemy): return not bool(enemy.get("dead", false)) and absf(float(enemy.x) - center_x) < 60.0).size()
		if count > best_count:
			best_count = count
			best_col = col
	var x: float = run.GRID_X + best_col * run.CELL + run.CELL / 2.0
	run.charges.append({"x": x, "y": 42.0, "vy": 300.0, "width": 40.0, "damage": round(12.0 + run.wave * 3.0), "tri": "", "crit": 0.0, "owner": {}, "hit": [], "dead": false, "kb_mul": 0.5, "boulder": true})
	run.field_events.append({"kind": "boulder", "x": x, "y": 70.0, "t": 0.8})

func _lord_shot_estimate(run) -> float:
	var attack: Dictionary = run.lord_system.ATTACKS.get(run.ruler_id, {})
	if attack.is_empty(): return 5.0 + run.wave * 0.6
	if run.ruler_id == "gongsunzan":
		return (6.0 + run.wave * 1.2) * (float(run.wall) / maxf(1.0, float(run.wall_max))) * (1.0 + 0.03 * run.ruler_level) * float(attack.mul) * (1.0 + run.lord_atk_buff)
	return (7.0 + run.wave * 0.75) * (1.0 + 0.02 * run.ruler_level) * run.lord_system.kin_power(run) * float(attack.mul) * (1.0 + run.lord_atk_buff)

func _densest_center(enemies: Array, radius: float) -> Vector2:
	var best: Vector2 = Vector2(240.0, 260.0)
	var best_count: int = -1
	for enemy in enemies:
		var center: Vector2 = Vector2(float(enemy.x), float(enemy.y))
		var count: int = enemies.filter(func(other): return center.distance_squared_to(Vector2(float(other.x), float(other.y))) < radius * radius).size()
		if count > best_count:
			best_count = count
			best = center
	return best

func _field(run) -> Dictionary:
	return run.catalog.by_id("fields", str(run.city.get("field", "")))

func _has_live(run) -> bool:
	return run.enemies.any(func(enemy): return not bool(enemy.get("dead", false)))
