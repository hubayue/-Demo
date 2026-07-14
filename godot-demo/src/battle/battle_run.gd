class_name BattleRun
extends RefCounted

const GRID_ROWS := 3
const GRID_COLS := 5
const ENEMY_CLASSES := ["spear", "cav", "archer"]
const TRI_KEYS := ["badao", "liangmou", "rende"]
const TRI_KE := {"badao": "liangmou", "liangmou": "rende", "rende": "badao"}
const MUTATION_KEYS := ["frenzy", "horde", "volley", "ironhide", "fat", "eastwind", "rainstorm"]
const TRAIT_KEYS := ["atk", "haste", "guard", "heal", "crit", "elem"]

var catalog
var rng
var city: Dictionary = {}
var ruler_id := ""
var speed := 2
var wall := 0
var wall_max := 0
var wave := 0
var wave_timer := 2.0
var level := 1
var xp := 0.0
var xp_need := 10.0
var kills := 0
var grid: Array = []
var obstacles: Dictionary = {}
var traits: Dictionary = {}
var mutations: Dictionary = {}
var enemies: Array = []
var next_queue: Array = []
var next_wave_preview: Dictionary = {}

func _init(content_catalog, random_source) -> void:
	catalog = content_catalog
	rng = random_source

func start(level_data: Dictionary, selected_ruler_id: String, opening_hero_id: String) -> void:
	city = level_data.duplicate(true)
	ruler_id = selected_ruler_id
	speed = 2
	wall = int(city.wall)
	wall_max = wall
	wave = 0
	wave_timer = 2.0
	level = 1
	xp = 0.0
	xp_need = 10.0
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
	next_queue = []
	next_wave_preview = {}
	_roll_layout()
	_place_opening_hero(opening_hero_id)

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
	var slots := empty_slots()
	if slots.is_empty():
		return
	var slot: Array = _pick(slots)
	var hero: Dictionary = catalog.by_id("heroes", hero_id)
	var max_hp := _unit_max_hp(hero)
	var unit := {
		"hero": hero,
		"row": int(slot[0]),
		"col": int(slot[1]),
		"level": 1,
		"hp": max_hp,
		"hp_max": max_hp,
		"cd": _randf(0.0, 0.3),
	}
	grid[unit.row][unit.col] = unit

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
