class_name BattleRun
extends RefCounted

const BattleCardsScript = preload("res://src/battle/battle_cards.gd")

const GRID_ROWS := 3
const GRID_COLS := 5
const CELL := 82.0
const GRID_X := (480.0 - GRID_COLS * CELL) / 2.0
const GRID_Y := 492.0
const DEFENSE_LINE := GRID_Y + GRID_ROWS * CELL + 8.0
const ENEMY_CLASSES := ["spear", "cav", "archer"]
const TRI_KEYS := ["badao", "liangmou", "rende"]
const TRI_KE := {"badao": "liangmou", "liangmou": "rende", "rende": "badao"}
const MUTATION_KEYS := ["frenzy", "horde", "volley", "ironhide", "fat", "eastwind", "rainstorm"]
const TRAIT_KEYS := ["atk", "haste", "guard", "heal", "crit", "elem"]

var catalog
var rng
var card_system
var city: Dictionary = {}
var ruler_id := ""
var status := "play"
var shen_period := 0
var shen_ids: Array = []
var speed := 2
var wall := 0
var wall_max := 0
var wave := 0
var wave_timer := 2.0
var game_time := 0.0
var spawn_queue: Array = []
var spawn_timer := 0.0
var wave_budget := 0.0
var wave_clock := 0.0
var level := 1
var xp := 0.0
var xp_need := 10.0
var awaiting_card_choice := false
var pending_picks := 0
var card_choices: Array = []
var card_picks: Dictionary = {}
var buffs: Dictionary = {}
var lord_atk_buff := 0.0
var lord_atk_gap := 1.0
var permanent_tactics: Dictionary = {}
var kills := 0
var grid: Array = []
var obstacles: Dictionary = {}
var traits: Dictionary = {}
var mutations: Dictionary = {}
var enemies: Array = []
var projectiles: Array = []
var charges: Array = []
var next_queue: Array = []
var next_wave_preview: Dictionary = {}

func _init(content_catalog, random_source) -> void:
	catalog = content_catalog
	rng = random_source
	card_system = BattleCardsScript.new(catalog, rng)

func start(level_data: Dictionary, selected_ruler_id: String, opening_hero_id: String) -> void:
	city = level_data.duplicate(true)
	ruler_id = selected_ruler_id
	status = "play"
	shen_period = 0
	shen_ids = []
	speed = 2
	wall = int(city.wall)
	wall_max = wall
	wave = 0
	wave_timer = 2.0
	game_time = 0.0
	spawn_queue = []
	spawn_timer = 0.0
	wave_budget = 0.0
	wave_clock = 0.0
	level = 1
	xp = 0.0
	xp_need = 10.0
	awaiting_card_choice = false
	pending_picks = 0
	card_choices = []
	card_picks = {}
	buffs = {
		"dmg": 1.0,
		"rate": 1.0,
		"xpGain": 1.0,
		"critCh": 0.0,
		"extraShot": 0,
		"ultHaste": 0.0,
		"spearAura": 0.0,
		"cavWide": 0.0,
		"archerDmg": 0.0,
		"cavDmg": 0.0,
		"shieldReflect": 0.0,
		"rippleRad": 0.0,
		"elemBoost": {"badao": 0.0, "liangmou": 0.0, "rende": 0.0},
	}
	lord_atk_buff = 0.0
	lord_atk_gap = 1.0
	permanent_tactics = {}
	kills = 0
	grid = []
	for row in GRID_ROWS:
		var cells := []
		cells.resize(GRID_COLS)
		grid.append(cells)
	obstacles = {}
	traits = {}
	mutations = _roll_mutations()
	enemies = []
	projectiles = []
	charges = []
	next_queue = []
	next_wave_preview = {}
	_roll_layout()
	_place_opening_hero(opening_hero_id)

func advance_real(delta: float) -> void:
	if awaiting_card_choice or status != "play":
		return
	for step in speed:
		_update_step(delta)

static func triangle_multiplier(attacker_tri: String, enemy_tri: String) -> float:
	if not attacker_tri or not enemy_tri:
		return 1.0
	if TRI_KE.get(attacker_tri, "") == enemy_tri:
		return 1.5
	if TRI_KE.get(enemy_tri, "") == attacker_tri:
		return 0.6
	return 1.0

func damage_enemy(enemy: Dictionary, amount: float, attacker_tri := "") -> int:
	if bool(enemy.get("dead", false)):
		return 0
	var damage := maxi(1, int(round(amount * triangle_multiplier(attacker_tri, str(enemy.get("tri", ""))))))
	enemy.hp = float(enemy.hp) - damage
	if float(enemy.hp) <= 0:
		enemy.dead = true
		kills += 1
		gain_xp(float(enemy.get("xp", 0.0)))
		if kills >= int(city.get("killTarget", 450)):
			status = "win"
		var index := enemies.find(enemy)
		if index >= 0:
			enemies.remove_at(index)
	return damage

func gain_xp(amount: float) -> void:
	xp += amount
	while xp >= xp_need:
		xp -= xp_need
		level += 1
		xp_need = round(10.0 + (level - 1) * 9.0 + pow(level, 1.72))
		if awaiting_card_choice:
			pending_picks += 1
		else:
			awaiting_card_choice = true
			card_choices = card_system.roll(self)
			if card_choices.is_empty():
				awaiting_card_choice = false

func choose_card(index: int) -> bool:
	if not awaiting_card_choice or index < 0 or index >= card_choices.size():
		return false
	return card_system.apply(self, card_choices[index])

func _update_step(delta: float) -> void:
	game_time += delta
	var field_clear := spawn_queue.is_empty() and enemies.is_empty()
	if field_clear:
		prepare_next_wave()
		wave_timer -= delta
		if wave_timer <= 0:
			_start_next_wave()
	else:
		wave_clock += delta
		if wave_budget > 0 and wave_clock >= wave_budget:
			_start_next_wave()
		if not spawn_queue.is_empty():
			spawn_timer -= delta
			if spawn_timer <= 0:
				_spawn_enemy(spawn_queue.pop_front())
				spawn_timer = float(spawn_queue[0].delay) if not spawn_queue.is_empty() else 0.0
	_update_enemies(delta)
	_update_units(delta)
	_update_projectiles(delta)
	_update_charges(delta)

func _start_next_wave() -> void:
	prepare_next_wave()
	wave += 1
	spawn_queue = next_queue
	next_queue = []
	next_wave_preview = {}
	spawn_timer = 0.0
	wave_timer = 3.4
	var spawn_duration := 0.0
	var has_boss := false
	for spec in spawn_queue:
		spawn_duration += float(spec.delay)
		has_boss = has_boss or bool(spec.get("boss", false))
	wave_budget = spawn_duration + 14.0 + (6.0 if has_boss else 0.0)
	wave_clock = 0.0

func _spawn_enemy(spec: Dictionary) -> void:
	var hp := float(spec.hp)
	var enemy := spec.duplicate(true)
	enemy["x"] = _randf(40.0, 440.0)
	enemy["y"] = -40.0
	enemy["hp"] = hp
	enemy["hp_max"] = hp
	enemy["base_speed"] = float(spec.speed)
	enemy["dead"] = false
	enemies.append(enemy)

func _update_enemies(delta: float) -> void:
	for enemy in enemies:
		if bool(enemy.get("dead", false)):
			continue
		enemy.y = float(enemy.y) + float(enemy.base_speed) * delta
		if float(enemy.y) > DEFENSE_LINE - 6.0:
			wall = maxi(0, wall - int(enemy.dmg))
			enemy.dead = true
			if wall <= 0:
				status = "over"
	for index in range(enemies.size() - 1, -1, -1):
		if bool(enemies[index].get("dead", false)):
			enemies.remove_at(index)

func _update_units(delta: float) -> void:
	for unit in units():
		unit.cd = float(unit.cd) - delta
		if float(unit.cd) > 0:
			continue
		var hero: Dictionary = unit.hero
		var hero_class := str(hero.cls)
		if hero_class == "shield" or hero_class == "support" or float(hero.get("dmg", 0.0)) <= 0:
			unit.cd = maxf(0.4, float(hero.get("rate", 9.0)))
			continue
		var center := slot_center(int(unit.row), int(unit.col))
		var attack_range := float(hero.get("rng", 0.0))
		var target: Dictionary = {}
		var front_y := -INF
		for enemy in enemies:
			if bool(enemy.get("dead", false)):
				continue
			if attack_range > 0 and center.distance_squared_to(Vector2(float(enemy.x), float(enemy.y))) > attack_range * attack_range:
				continue
			if float(enemy.y) > front_y:
				front_y = float(enemy.y)
				target = enemy
		if target.is_empty():
			continue
		unit.cd = float(hero.rate) * pow(0.93, int(unit.level) - 1)
		var damage := float(hero.dmg) * _star_damage_multiplier(int(unit.level))
		if hero_class == "archer":
			var direction := center.direction_to(Vector2(float(target.x), float(target.y)))
			projectiles.append({
				"x": center.x,
				"y": center.y - 18.0,
				"vx": direction.x * float(hero.speed),
				"vy": direction.y * float(hero.speed),
				"damage": damage,
				"tri": str(hero.elem),
				"r": 4.0 + int(unit.level),
				"distance": 0.0,
				"max_distance": attack_range if attack_range > 0 else 1000.0,
				"dead": false,
			})
		elif hero_class == "cav":
			charges.append({
				"x": center.x,
				"y": center.y - 20.0,
				"vy": -300.0,
				"width": (46.0 if float(hero.get("splash", 0.0)) > 0 else 34.0),
				"damage": damage,
				"tri": str(hero.elem),
				"hit": [],
				"dead": false,
			})
		else:
			damage_enemy(target, damage, str(hero.elem))

func _update_projectiles(delta: float) -> void:
	for projectile in projectiles:
		if bool(projectile.dead):
			continue
		var motion := Vector2(float(projectile.vx), float(projectile.vy)) * delta
		projectile.x = float(projectile.x) + motion.x
		projectile.y = float(projectile.y) + motion.y
		projectile.distance = float(projectile.distance) + motion.length()
		if float(projectile.distance) >= float(projectile.max_distance):
			projectile.dead = true
			continue
		for enemy in enemies.duplicate():
			if bool(enemy.get("dead", false)):
				continue
			var hit_radius := float(projectile.r) + float(enemy.r)
			if Vector2(float(projectile.x), float(projectile.y)).distance_squared_to(Vector2(float(enemy.x), float(enemy.y))) <= hit_radius * hit_radius:
				damage_enemy(enemy, float(projectile.damage), str(projectile.tri))
				projectile.dead = true
				break
	for index in range(projectiles.size() - 1, -1, -1):
		if bool(projectiles[index].dead):
			projectiles.remove_at(index)

func _update_charges(delta: float) -> void:
	for charge in charges:
		if bool(charge.dead):
			continue
		charge.y = float(charge.y) + float(charge.vy) * delta
		if float(charge.y) < 30.0:
			charge.dead = true
			continue
		for enemy in enemies.duplicate():
			if bool(enemy.get("dead", false)) or charge.hit.has(enemy):
				continue
			if absf(float(enemy.x) - float(charge.x)) < float(charge.width) + float(enemy.r) * 0.5 and absf(float(enemy.y) - float(charge.y)) < float(enemy.r) + 14.0:
				charge.hit.append(enemy)
				damage_enemy(enemy, float(charge.damage), str(charge.tri))
	for index in range(charges.size() - 1, -1, -1):
		if bool(charges[index].dead):
			charges.remove_at(index)

static func slot_center(row: int, col: int) -> Vector2:
	return Vector2(GRID_X + col * CELL + CELL / 2.0, GRID_Y + row * CELL + CELL / 2.0)

static func _star_damage_multiplier(stars: int) -> float:
	return pow(1.9, mini(stars, 5) - 1) * pow(1.4, maxi(0, mini(stars, 10) - 5)) * pow(1.3, maxi(0, stars - 10))

func units() -> Array:
	var result := []
	for row in GRID_ROWS:
		for col in GRID_COLS:
			var unit = grid[row][col]
			if unit != null:
				result.append(unit)
	return result

func empty_slots(include_obstacles := false) -> Array:
	var result := []
	for row in GRID_ROWS:
		for col in GRID_COLS:
			if grid[row][col] != null:
				continue
			if not include_obstacles and obstacles.has(_cell_key(row, col)):
				continue
			result.append([row, col])
	return result

func add_unit(hero_id: String) -> bool:
	return add_unit_data(catalog.by_id("heroes", hero_id))

func add_unit_data(hero: Dictionary) -> bool:
	var slots := empty_slots()
	if slots.is_empty():
		return false
	var slot: Array = _pick(slots)
	var unit := _make_unit(hero, int(slot[0]), int(slot[1]))
	grid[unit.row][unit.col] = unit
	return true

func upgrade_hero(hero_id: String) -> bool:
	var target: Dictionary = {}
	for unit in units():
		if str(unit.hero.id) != hero_id or int(unit.level) >= 15:
			continue
		if target.is_empty() or int(unit.level) < int(target.level):
			target = unit
	if target.is_empty():
		return false
	target.level = int(target.level) + 1
	target.hp_max = _unit_max_hp(target.hero, int(target.level))
	target.hp = target.hp_max
	return true

func remove_random_obstacle() -> bool:
	if obstacles.is_empty():
		return false
	var keys := obstacles.keys()
	var key: String = _pick(keys)
	obstacles.erase(key)
	return true

func prepare_next_wave() -> void:
	if not next_queue.is_empty():
		return
	next_queue = build_wave(wave + 1)
	var counts := {"spear": 0, "cav": 0, "archer": 0}
	for spec in next_queue:
		counts[spec.cls] += 1
	var foe_tri := str(city.get("foes", {}).get("tri", ""))
	next_wave_preview = {
		"counts": counts,
		"themeElems": [foe_tri] if foe_tri else [],
		"weakElem": _counter_of(foe_tri),
		"mutation": mutations.get(wave + 1),
	}

func build_wave(number: int) -> Array:
	var queue := []
	var mutation = mutations.get(number)
	var foe_tri := str(city.get("foes", {}).get("tri", ""))
	if mutation == "ironhide" and foe_tri:
		foe_tri = str(TRI_KE[foe_tri])
	var count := mini(96, 10 + int(floor(number * 3.3)))
	if mutation == "horde":
		count = mini(130, int(round(count * 1.7)))
	var hp_scale := 0.7 if mutation == "horde" else 1.0
	var speed_scale := 1.35 if mutation == "frenzy" else 1.0
	var hp := int(round(12.0 * pow(float(city.hpGrow), number - 1) * float(city.hpMul) * hp_scale))
	var base_speed: float = clampf(30.0 + number * 2.0, 30.0, 96.0) * float(city.spdMul) * speed_scale
	var base_xp := float(2 + int(floor(number / 8.0))) * 0.65 * (2.0 if mutation == "fat" else 1.0)
	for index in count:
		var enemy_class: String = _pick(ENEMY_CLASSES)
		var big: bool = rng.next_float() < clampf(0.06 + number * 0.011, 0.0, 0.3)
		var affix = null
		if big and number >= 3 and rng.next_float() < clampf(0.34 + number * 0.025 + float(city.affixAdd), 0.0, 0.9):
			affix = _pick(catalog.content.get("affixes", {}).keys())
		var delay := 0.0 if index == 0 else _randf(0.3, maxf(0.35, 1.0 - number * 0.03))
		var enemy_speed := base_speed * 0.65 if big else base_speed * _randf(0.85, 1.15)
		queue.append({
			"delay": delay,
			"hp": hp * (4.5 if affix != null else 3.2) if big else hp,
			"speed": enemy_speed,
			"r": 26 if big else _randi(15, 19),
			"cls": enemy_class,
			"big": big,
			"affix": affix,
			"special": null,
			"tri": _roll_tri(foe_tri),
			"xp": base_xp * (4.0 if affix != null else 3.0) if big else base_xp,
			"dmg": 3 if big else 1,
		})
	return queue

func _roll_mutations() -> Dictionary:
	var result := {}
	var slots := [[6, 8], [11, 14]] if int(city.ch) == 0 else [[5, 7], [9, 12], [14, 16]]
	for slot in slots:
		var mutation_wave := _randi(int(slot[0]), int(slot[1]))
		var key: String = _pick(MUTATION_KEYS)
		if key == "volley" and mutation_wave < 8:
			key = "frenzy"
		if key == "ironhide" and mutation_wave < 8:
			key = "fat"
		result[mutation_wave] = key
	return result

func _roll_layout() -> void:
	var attempts := 0
	while obstacles.size() < int(city.get("obstacles", 7)) and attempts < 200:
		attempts += 1
		var row := _randi(0, GRID_ROWS - 1)
		var col := _randi(0, GRID_COLS - 1)
		var key := _cell_key(row, col)
		if obstacles.has(key):
			continue
		var row_count := 1
		for other_col in GRID_COLS:
			if obstacles.has(_cell_key(row, other_col)):
				row_count += 1
		if row_count > GRID_COLS - 2:
			continue
		obstacles[key] = true
	for row in GRID_ROWS:
		for col in GRID_COLS:
			traits[_cell_key(row, col)] = _pick(TRAIT_KEYS)

func _place_opening_hero(hero_id: String) -> void:
	add_unit(hero_id)

func _make_unit(hero: Dictionary, row: int, col: int) -> Dictionary:
	var max_hp := _unit_max_hp(hero)
	return {
		"hero": hero,
		"row": row,
		"col": col,
		"level": 1,
		"hp": max_hp,
		"hp_max": max_hp,
		"cd": _randf(0.0, 0.3),
	}

func _unit_max_hp(hero: Dictionary, stars := 1) -> int:
	var base := float(hero.get("hp", 0))
	if base <= 0:
		match str(hero.cls):
			"shield": base = 340
			"spear": base = 120
			"cav": base = 100
			"support": base = 90
			_: base = 60
	var shield_scale := 1.5 if str(hero.cls) == "shield" else 1.0
	return int(round(base * (1.0 + (stars - 1) * 0.25) * shield_scale))

func _roll_tri(main_tri: String) -> String:
	if not main_tri:
		return _pick(TRI_KEYS)
	if rng.next_float() < 0.85:
		return main_tri
	var alternatives := []
	for key in TRI_KEYS:
		if key != main_tri:
			alternatives.append(key)
	return _pick(alternatives)

func _counter_of(enemy_tri: String) -> String:
	for hero_tri in TRI_KEYS:
		if TRI_KE[hero_tri] == enemy_tri:
			return hero_tri
	return ""

func _randf(minimum: float, maximum: float) -> float:
	return minimum + rng.next_float() * (maximum - minimum)

func _randi(minimum: int, maximum: int) -> int:
	return int(floor(_randf(minimum, maximum + 1.0)))

func _pick(values: Array):
	return values[int(floor(rng.next_float() * values.size()))]

func _cell_key(row: int, col: int) -> String:
	return "%d,%d" % [row, col]
