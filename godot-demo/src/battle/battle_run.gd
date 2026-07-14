class_name BattleRun
extends RefCounted

const BattleCardsScript = preload("res://src/battle/battle_cards.gd")
const BattleTeamScript = preload("res://src/battle/battle_team.gd")
const BattleLordScript = preload("res://src/battle/battle_lord.gd")
const BattleFoeLordScript = preload("res://src/battle/battle_foe_lord.gd")
const BattleUltsScript = preload("res://src/battle/battle_ults.gd")

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
const BOSS_NAMES := ["程远志", "邓茂", "波才", "张梁", "张宝", "张角"]

var catalog
var rng
var card_system
var team
var lord_system
var foe_system
var ult_system
var city: Dictionary = {}
var ruler_id := ""
var ruler_level := 1
var hero_levels: Dictionary = {}
var lord_skill_id := ""
var lord_skill_level := 1
var lord_command_cd := 18.0
var lord_command_cd_total := 18.0
var lord_command_used := 0
var foe_lord: Dictionary = {}
var foe_events: Array = []
var foe_curse_time := 0.0
var foe_rage_time := 0.0
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
var pending_relic_picks := 0
var picking_relic := false
var card_choices: Array = []
var card_picks: Dictionary = {}
var gewu_auto_timer := 0.0
var buffs: Dictionary = {}
var lord_atk_buff := 0.0
var lord_atk_gap := 1.0
var lord_attack_timer := 1.5
var lord_attack_traces: Array = []
var lord_effect_rings: Array = []
var lord_command_events: Array = []
var wuxing_time := 0.0
var flood: Dictionary = {}
var wide_picks := 0
var lord_mount: Dictionary = {}
var tyranny := 0.0
var jianhao_count := 0
var taoyuan_time := 0.0
var taoyuan_absorb := 0.0
var permanent_tactics: Dictionary = {}
var relic_ids: Array = []
var wall_regen_timer := 30.0
var baihu_ready := false
var kills := 0
var unit_deaths := 0
var grid: Array = []
var obstacles: Dictionary = {}
var traits: Dictionary = {}
var mutations: Dictionary = {}
var enemies: Array = []
var projectiles: Array = []
var charges: Array = []
var ripples: Array = []
var ult_events: Array = []
var ults_used := 0
var blockade: Dictionary = {}
var palisades: Array = []
var traps: Array = []
var fire_pits: Array = []
var turrets: Array = []
var death_link: Dictionary = {}
var army_buff: Dictionary = {}
var army_haste: Dictionary = {}
var _link_propagating := false
var next_queue: Array = []
var next_wave_preview: Dictionary = {}

func _init(content_catalog, random_source) -> void:
	catalog = content_catalog
	rng = random_source
	card_system = BattleCardsScript.new(catalog, rng)
	team = BattleTeamScript.new(catalog)
	lord_system = BattleLordScript.new()
	foe_system = BattleFoeLordScript.new()
	ult_system = BattleUltsScript.new()

func start(level_data: Dictionary, selected_ruler_id: String, opening_hero_id: String, selected_ruler_level := 1, selected_hero_levels: Dictionary = {}) -> void:
	city = level_data.duplicate(true)
	ruler_id = selected_ruler_id
	ruler_level = maxi(1, int(selected_ruler_level))
	hero_levels = selected_hero_levels.duplicate(true)
	var ruler: Dictionary = catalog.by_id("rulers", ruler_id)
	lord_skill_id = str(ruler.get("skill", ""))
	lord_skill_level = lord_system.skill_level(ruler_level)
	lord_command_cd = 18.0
	lord_command_cd_total = 18.0
	lord_command_used = 0
	foe_lord = {}
	foe_events = []
	foe_curse_time = 0.0
	foe_rage_time = 0.0
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
	pending_relic_picks = 0
	picking_relic = false
	card_choices = []
	card_picks = {}
	gewu_auto_timer = 0.0
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
	lord_attack_timer = 1.5
	lord_attack_traces = []
	lord_effect_rings = []
	lord_command_events = []
	wuxing_time = 0.0
	flood = {}
	wide_picks = 0
	lord_mount = {}
	tyranny = 0.0
	jianhao_count = 0
	taoyuan_time = 0.0
	taoyuan_absorb = 0.0
	permanent_tactics = {}
	relic_ids = []
	wall_regen_timer = 30.0
	baihu_ready = false
	kills = 0
	unit_deaths = 0
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
	ripples = []
	ult_events = []
	ults_used = 0
	blockade = {}
	palisades = []
	traps = []
	fire_pits = []
	turrets = []
	death_link = {}
	army_buff = {}
	army_haste = {}
	_link_propagating = false
	next_queue = []
	next_wave_preview = {}
	_roll_layout()
	team.recompute(self)
	_place_opening_hero(opening_hero_id)
	foe_system.setup(self)

func advance_real(delta: float) -> void:
	if status != "play":
		return
	if awaiting_card_choice:
		if bool(permanent_tactics.get("gewu", false)):
			gewu_auto_timer += delta
			if gewu_auto_timer >= 1.5 and not card_choices.is_empty():
				var safe_indices := []
				for index in card_choices.size():
					if not ["seppuku", "dance"].has(str(card_choices[index].kind)):
						safe_indices.append(index)
				var choice_index := 0
				if not safe_indices.is_empty():
					choice_index = int(safe_indices[int(floor(rng.next_float() * safe_indices.size()))])
				choose_card(choice_index)
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

func damage_enemy(enemy: Dictionary, amount: float, attacker_tri := "", source := "") -> int:
	if bool(enemy.get("dead", false)):
		return 0
	var triangle := triangle_multiplier(attacker_tri, str(enemy.get("tri", "")))
	if wuxing_time > 0 and not str(attacker_tri).is_empty():
		if TRI_KE.get(str(enemy.get("tri", "")), "") == attacker_tri:
			triangle = 1.0
		amount *= 1.15
	if is_equal_approx(triangle, 0.6) and float(enemy.get("armorBreakT", 0.0)) > 0:
		if team.active_bonds.has("shuijing"):
			triangle = 1.2
		elif relic_ids.has("shuijingshu"):
			triangle = 1.1
		else:
			triangle = 1.0
	if enemy_in_flood(enemy):
		amount *= 1.0 + float(flood.get("amp", 0.3))
	if float(enemy.get("charmT", 0.0)) > 0:
		amount *= 1.3
	if float(enemy.get("silencedT", 0.0)) > 0 and relic_ids.has("chensha"):
		amount *= 1.15
	if float(enemy.get("jianjunT", 0.0)) > 0:
		amount *= 1.0 + float(enemy.get("jianjunAmp", 0.3))
	if bool(permanent_tactics.get("luojing", false)) and (float(enemy.get("slowT", 0.0)) > 0 or float(enemy.get("stunT", 0.0)) > 0 or float(enemy.get("fearT", 0.0)) > 0 or float(enemy.get("sleepT", 0.0)) > 0 or float(enemy.get("charmT", 0.0)) > 0 or enemy_in_flood(enemy)):
		amount *= 1.3
	var damage := maxi(1, int(round(amount * triangle)))
	var hp_damage := damage
	var shield := float(enemy.get("shield", 0.0))
	if shield > 0:
		var absorbed := minf(shield, hp_damage)
		enemy.shield = shield - absorbed
		hp_damage -= int(absorbed)
	if hp_damage > 0:
		enemy.hp = float(enemy.hp) - hp_damage
		enemy.sleepT = 0.0
		if not _link_propagating and not death_link.is_empty() and float(death_link.get("t", 0.0)) > 0 and death_link.members.has(enemy):
			_link_propagating = true
			var share := maxi(1, roundi(hp_damage * (0.7 if relic_ids.has("xuantie") else 0.55)))
			for member in death_link.members.duplicate():
				if member != enemy and not bool(member.get("dead", false)):
					_hit_enemy(member, share, "", 0.0, death_link.get("owner", {}))
			_link_propagating = false
	if float(enemy.hp) <= 0:
		var drowned := enemy_in_flood(enemy)
		enemy.dead = true
		kills += 1
		var xp_multiplier := 1.0
		if ruler_id == "sunquan":
			xp_multiplier = 2.0 if drowned else 1.3
		elif ruler_id == "gongsunzan" and source == "lord":
			xp_multiplier = 3.0
		elif ruler_id == "dongzhuo" and float(enemy.get("burnT", 0.0)) > 0:
			xp_multiplier = 2.0
		gain_xp(float(enemy.get("xp", 0.0)) * xp_multiplier)
		if kills >= int(city.get("killTarget", 450)):
			status = "win"
		elif bool(enemy.get("boss", false)):
			queue_relic_draft()
		var index := enemies.find(enemy)
		if index >= 0:
			enemies.remove_at(index)
	return damage

func gain_xp(amount: float) -> void:
	xp += amount
	while xp >= xp_need:
		xp -= xp_need
		level += 1
		xp_need = round((10.0 + (level - 1) * 9.0 + pow(level, 1.72)) * (0.88 if relic_ids.has("hanshu") else 1.0))
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
	gewu_auto_timer = 0.0
	return card_system.apply(self, card_choices[index])

func queue_relic_draft() -> void:
	if awaiting_card_choice:
		pending_relic_picks += 1
		return
	card_choices = card_system.roll_relics(self)
	picking_relic = not card_choices.is_empty()
	awaiting_card_choice = picking_relic

func _update_step(delta: float) -> void:
	game_time += delta
	if relic_ids.has("qixing") and wall < wall_max:
		wall_regen_timer -= delta
		if wall_regen_timer <= 0:
			wall = mini(wall_max, wall + 1)
			wall_regen_timer += 30.0
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
	_update_ultimate_effects(delta)
	_update_projectiles(delta)
	_update_charges(delta)
	_update_ripples(delta)
	_update_foe_lord(delta)
	_update_lord_command(delta)
	_update_lord_auto_attack(delta)
	_update_lord_visuals(delta)

func _update_ultimate_effects(delta: float) -> void:
	for event in ult_events:
		event.t = float(event.t) - delta
	for index in range(ult_events.size() - 1, -1, -1):
		if float(ult_events[index].t) <= 0:
			ult_events.remove_at(index)
	for timed in [army_buff, army_haste, death_link, blockade]:
		if not timed.is_empty():
			timed.t = maxf(0.0, float(timed.get("t", 0.0)) - delta)
	if not army_buff.is_empty() and float(army_buff.t) <= 0: army_buff = {}
	if not army_haste.is_empty() and float(army_haste.t) <= 0: army_haste = {}
	if not blockade.is_empty() and (float(blockade.t) <= 0 or float(blockade.get("hp", 0.0)) <= 0): blockade = {}
	if not death_link.is_empty():
		death_link.members = death_link.members.filter(func(enemy): return not bool(enemy.get("dead", false)) and enemies.has(enemy))
		if float(death_link.t) <= 0 or death_link.members.size() < 2: death_link = {}
	for palisade in palisades:
		palisade.t = float(palisade.t) - delta
	for index in range(palisades.size() - 1, -1, -1):
		if float(palisades[index].t) <= 0 or float(palisades[index].hp) <= 0: palisades.remove_at(index)
	_update_traps(delta)
	_update_fire_pits(delta)
	_update_turrets(delta)
	_update_poison_auras(delta)

func _apply_ultimate_blockers(enemy: Dictionary, delta: float) -> bool:
	if not blockade.is_empty() and float(enemy.y) >= float(blockade.y) - float(enemy.r):
		enemy.y = float(blockade.y) - float(enemy.r)
		blockade.hp = float(blockade.hp) - (2.5 if bool(enemy.get("boss", false)) else 1.0) * delta
		return true
	for palisade in palisades:
		if absf(float(enemy.x) - float(palisade.x)) <= float(palisade.width) + float(enemy.r) and float(enemy.y) >= float(palisade.y) - float(enemy.r):
			enemy.y = float(palisade.y) - float(enemy.r)
			palisade.hp = float(palisade.hp) - (2.5 if bool(enemy.get("boss", false)) else 1.0) * delta
			return true
	return false

func _update_traps(delta: float) -> void:
	for trap in traps:
		trap.t = float(trap.t) - delta
		var trigger: Dictionary = {}
		for enemy in enemies:
			if not bool(enemy.get("dead", false)) and Vector2(float(trap.x), float(trap.y)).distance_squared_to(Vector2(float(enemy.x), float(enemy.y))) <= pow(float(trap.r) + float(enemy.r), 2):
				trigger = enemy
				break
		if trigger.is_empty(): continue
		for enemy in enemies.duplicate():
			if not bool(enemy.get("dead", false)) and Vector2(float(trap.x), float(trap.y)).distance_squared_to(Vector2(float(enemy.x), float(enemy.y))) <= pow(float(trap.splash) + float(enemy.r), 2):
				_hit_enemy(enemy, float(trap.damage), str(trap.tri), 0.0, trap.owner)
		trap.t = 0.0
	for index in range(traps.size() - 1, -1, -1):
		if float(traps[index].t) <= 0: traps.remove_at(index)

func _update_fire_pits(delta: float) -> void:
	for pit in fire_pits:
		pit.t = float(pit.t) - delta
		pit.tick = float(pit.get("tick", 0.0)) - delta
		if float(pit.tick) > 0: continue
		pit.tick = 0.5
		for enemy in enemies.duplicate():
			if not bool(enemy.get("dead", false)) and Vector2(float(pit.x), float(pit.y)).distance_squared_to(Vector2(float(enemy.x), float(enemy.y))) <= pow(float(pit.r) + float(enemy.r), 2):
				_hit_enemy(enemy, float(pit.damage), str(pit.owner.hero.elem), 0.0, pit.owner)
	for index in range(fire_pits.size() - 1, -1, -1):
		if float(fire_pits[index].t) <= 0: fire_pits.remove_at(index)

func _update_turrets(delta: float) -> void:
	for turret in turrets:
		turret.t = float(turret.t) - delta
		turret.cd = float(turret.cd) - delta
		if float(turret.cd) > 0: continue
		var targets := enemies.filter(func(enemy): return not bool(enemy.get("dead", false)) and Vector2(float(turret.x), float(turret.y)).distance_squared_to(Vector2(float(enemy.x), float(enemy.y))) <= float(turret.range) * float(turret.range))
		targets.sort_custom(func(a, b): return Vector2(float(turret.x), float(turret.y)).distance_squared_to(Vector2(float(a.x), float(a.y))) < Vector2(float(turret.x), float(turret.y)).distance_squared_to(Vector2(float(b.x), float(b.y))))
		if not targets.is_empty():
			_hit_enemy(targets[0], float(turret.damage), str(turret.tri), 0.0, turret.owner)
			turret.cd = float(turret.rate)
	for index in range(turrets.size() - 1, -1, -1):
		if float(turrets[index].t) <= 0: turrets.remove_at(index)

func _update_poison_auras(delta: float) -> void:
	for unit in units():
		if str(unit.hero.id) != "wutugu": continue
		unit.auraTick = float(unit.get("auraTick", 0.5)) - delta
		if float(unit.auraTick) > 0: continue
		unit.auraTick = 1.0
		var active := float(unit.get("ultT", 0.0)) > 0
		var radius := 90.0 * (2.2 if active else 1.0)
		var damage := (4.0 + wave * 0.5) * (1.0 + (int(unit.level) - 1) * 0.25) * (2.0 if active else 1.0)
		if relic_ids.has("dujing"): damage *= 1.5
		var center := slot_center(int(unit.row), int(unit.col)) - Vector2(0, 10)
		for enemy in enemies.duplicate():
			if not bool(enemy.get("dead", false)) and center.distance_squared_to(Vector2(float(enemy.x), float(enemy.y))) <= radius * radius:
				_hit_enemy(enemy, damage, str(unit.hero.elem), 0.0, unit)

func _update_lord_auto_attack(delta: float) -> void:
	lord_system.update_auto_attack(self, delta)

func _update_lord_command(delta: float) -> void:
	lord_system.update_command(self, delta)

func _update_foe_lord(delta: float) -> void:
	foe_system.update(self, delta)

func foe_damage_multiplier() -> float:
	return 1.3 if foe_rage_time > 0 else 1.0

func lord_command_auto_ready() -> bool:
	return lord_system.auto_ready(self)

func cast_lord_command() -> bool:
	return lord_system.cast_command(self)

func lord_command_cooldown_max() -> float:
	return lord_system.cooldown_max(self)

func lord_kin_power() -> float:
	return lord_system.kin_power(self)

func _update_lord_visuals(delta: float) -> void:
	for trace in lord_attack_traces:
		trace.t = float(trace.t) - delta
	for index in range(lord_attack_traces.size() - 1, -1, -1):
		if float(lord_attack_traces[index].t) <= 0:
			lord_attack_traces.remove_at(index)
	for ring in lord_effect_rings:
		ring.t = float(ring.t) - delta
	for index in range(lord_effect_rings.size() - 1, -1, -1):
		if float(lord_effect_rings[index].t) <= 0:
			lord_effect_rings.remove_at(index)

func _start_next_wave() -> void:
	prepare_next_wave()
	wave += 1
	baihu_ready = relic_ids.has("baihu")
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
	enemy["x"] = _randf(40.0, 440.0) if spec.get("x") == null else float(spec.x)
	enemy["y"] = -40.0 if spec.get("y") == null else float(spec.y)
	enemy["hp"] = hp
	enemy["hp_max"] = hp
	enemy["base_speed"] = float(spec.speed)
	enemy["dead"] = false
	enemies.append(enemy)

func _update_enemies(delta: float) -> void:
	for enemy in enemies.duplicate():
		if bool(enemy.get("dead", false)):
			continue
		if float(enemy.get("burnT", 0.0)) > 0:
			enemy.burnT = maxf(0.0, float(enemy.burnT) - delta)
			enemy.burnTick = float(enemy.get("burnTick", 0.0)) - delta
			if float(enemy.burnTick) <= 0:
				enemy.burnTick = 0.5
				damage_enemy(enemy, float(enemy.get("burnDmg", 0.0)))
				if bool(enemy.get("dead", false)):
					continue
		var slowed := float(enemy.get("slowT", 0.0)) > 0
		if slowed:
			enemy.slowT = maxf(0.0, float(enemy.slowT) - delta)
		if float(enemy.get("armorBreakT", 0.0)) > 0:
			enemy.armorBreakT = maxf(0.0, float(enemy.armorBreakT) - delta)
		for status_key in ["charmT", "sleepT", "fearT", "silencedT", "jianjunT", "duelT"]:
			if float(enemy.get(status_key, 0.0)) > 0:
				enemy[status_key] = maxf(0.0, float(enemy.get(status_key, 0.0)) - delta)
		if str(enemy.get("special", "")) == "shaman" and float(enemy.y) > 60.0 and float(enemy.get("silencedT", 0.0)) <= 0:
			enemy.sealCastT = float(enemy.get("sealCastT", 0.0)) - delta
			if float(enemy.sealCastT) <= 0:
				enemy.sealCastT = 7.0
				var seal_targets := units().filter(func(unit): return float(unit.get("sealedT", 0.0)) <= 0 and not ["egg", "granary"].has(str(unit.hero.cls)))
				if not seal_targets.is_empty():
					var sealed_unit: Dictionary = _pick(seal_targets)
					sealed_unit.sealedT = 3.0
		if str(enemy.get("special", "")) == "ram":
			enemy.fearT = 0.0
			enemy.sleepT = 0.0
			enemy.charmT = 0.0
			enemy.slowT = maxf(0.0, float(enemy.get("slowT", 0.0)) - delta)
			enemy.stunT = maxf(0.0, float(enemy.get("stunT", 0.0)) - delta)
			enemy.kb = minf(float(enemy.get("kb", 0.0)), 10.0)
		if float(enemy.get("kb", 0.0)) > 0:
			var knock_step := minf(float(enemy.kb), 300.0 * delta)
			enemy.y = maxf(-30.0, float(enemy.y) - knock_step)
			enemy.kb = float(enemy.kb) - knock_step
		var stunned := float(enemy.get("stunT", 0.0)) > 0
		if stunned:
			enemy.stunT = maxf(0.0, float(enemy.stunT) - delta)
			continue
		if float(enemy.get("sleepT", 0.0)) > 0:
			continue
		if float(enemy.get("turncoatT", 0.0)) > 0:
			enemy.turncoatT = maxf(0.0, float(enemy.turncoatT) - delta)
			enemy.turncoatTick = float(enemy.get("turncoatTick", 0.0)) - delta
			if float(enemy.turncoatTick) <= 0:
				enemy.turncoatTick = 0.8
				var victims := enemies.filter(func(other): return other != enemy and not bool(other.get("dead", false)) and float(other.get("turncoatT", 0.0)) <= 0)
				victims = victims.filter(func(other): return Vector2(float(enemy.x), float(enemy.y)).distance_squared_to(Vector2(float(other.x), float(other.y))) < 160.0 * 160.0)
				if not victims.is_empty():
					victims.sort_custom(func(a, b): return Vector2(float(enemy.x), float(enemy.y)).distance_squared_to(Vector2(float(a.x), float(a.y))) < Vector2(float(enemy.x), float(enemy.y)).distance_squared_to(Vector2(float(b.x), float(b.y))))
					damage_enemy(victims[0], maxf(3.0, float(enemy.get("hp_max", 100.0)) * 0.08), "", "turncoat")
			continue
		if float(enemy.get("fearT", 0.0)) > 0:
			enemy.y = maxf(-30.0, float(enemy.y) - float(enemy.base_speed) * 0.8 * delta)
			continue
		var flood_slow := enemy_in_flood(enemy)
		var speed_now := float(enemy.base_speed) * (0.55 if slowed else 1.0) * (0.6 if flood_slow else 1.0)
		if _apply_ultimate_blockers(enemy, delta):
			continue
		var blocker := _find_lane_blocker(enemy)
		if not blocker.is_empty():
			var target_x := GRID_X + int(blocker.col) * CELL + CELL / 2.0
			if absf(target_x - float(enemy.x)) > 4.0:
				enemy.x = move_toward(float(enemy.x), target_x, 130.0 * delta)
			var stop_y := float(blocker.stop_y)
			if float(enemy.y) >= stop_y:
				enemy.y = stop_y
				enemy.atkT = float(enemy.get("atkT", 0.0)) - delta
				if float(enemy.atkT) <= 0:
					enemy.atkT = 1.6 if bool(enemy.get("boss", false)) else 1.2
					var base_damage := 30.0 if bool(enemy.get("boss", false)) else (16.0 if bool(enemy.get("big", false)) else 7.0)
					var hit_damage := roundi(base_damage * (1.0 + wave * 0.06) * foe_damage_multiplier())
					hurt_unit(blocker.unit, hit_damage, int(blocker.row), int(blocker.col))
					if str(blocker.unit.hero.cls) == "shield" and not bool(enemy.get("dead", false)):
						var reflect_multiplier := 2.0 if float(blocker.unit.get("reflectT", 0.0)) > 0 else 1.0
						var reflect := roundi(float(blocker.unit.hp_max) * (0.04 + float(buffs.get("shieldReflect", 0.0))) * reflect_multiplier)
						if reflect > 0:
							damage_enemy(enemy, reflect)
						if str(blocker.unit.hero.id) == "yanyan":
							enemy.slowT = maxf(float(enemy.get("slowT", 0.0)), 1.5)
						gain_xp(1.0)
			else:
				enemy.y = minf(stop_y, float(enemy.y) + speed_now * delta)
		else:
			enemy.y = float(enemy.y) + speed_now * delta
		if float(enemy.y) > DEFENSE_LINE - 6.0:
			var wall_damage := int(enemy.dmg)
			if relic_ids.has("lianhuan"):
				wall_damage = maxi(1, wall_damage - 1)
			wall = maxi(0, wall - wall_damage)
			enemy.dead = true
			if wall <= 0:
				status = "over"
	for index in range(enemies.size() - 1, -1, -1):
		if bool(enemies[index].get("dead", false)):
			enemies.remove_at(index)

func hurt_unit(unit: Dictionary, amount: int, row: int, col: int) -> int:
	if unit.is_empty() or float(unit.get("hp", 0.0)) <= 0:
		return 0
	if taoyuan_time > 0:
		taoyuan_absorb += amount
		return 0
	var damage := amount
	if str(unit.hero.id) != "caohong":
		var protector := _adjacent_caohong(row, col)
		if not protector.is_empty():
			var share_ratio := 0.6 if float(protector.get("guardT", 0.0)) > 0 else 0.25
			var share := mini(roundi(damage * share_ratio), maxi(0, roundi(float(protector.hp) - 1.0)))
			if share > 0:
				protector.hp = float(protector.hp) - share
				damage -= share
	if str(traits.get(_cell_key(row, col), "")) == "guard":
		damage = roundi(damage * 0.8)
	if str(unit.hero.cls) != "shield" and _has_adjacent_shield(row, col):
		damage = roundi(damage * 0.75)
	damage = maxi(1, damage)
	unit.hp = float(unit.hp) - damage
	if float(unit.hp) <= 0:
		unit.hp = 0.0
		if row >= 0 and row < GRID_ROWS and col >= 0 and col < GRID_COLS and grid[row][col] == unit:
			grid[row][col] = null
			unit_deaths += 1
			team.recompute(self)
	return damage

func _adjacent_caohong(row: int, col: int) -> Dictionary:
	for other_row in range(maxi(0, row - 1), mini(GRID_ROWS - 1, row + 1) + 1):
		for other_col in range(maxi(0, col - 1), mini(GRID_COLS - 1, col + 1) + 1):
			var protector = grid[other_row][other_col]
			if protector != null and str(protector.hero.id) == "caohong" and float(protector.hp) > 1:
				return protector
	return {}

func _find_lane_blocker(enemy: Dictionary) -> Dictionary:
	var reach := 330.0 if str(enemy.get("special", "")) == "shooter" else (340.0 if str(enemy.get("special", "")) == "thrower" else 150.0)
	if float(enemy.y) <= GRID_Y - reach:
		return {}
	var col := clampi(int(floor((float(enemy.x) - GRID_X) / CELL)), 0, GRID_COLS - 1)
	for row in GRID_ROWS:
		var unit = grid[row][col]
		if unit == null:
			continue
		if str(enemy.get("special", "")) == "ram" and str(unit.hero.cls) != "shield":
			continue
		var stop_y := GRID_Y + row * CELL + 6.0 - float(enemy.r) * 0.4
		if float(enemy.y) > stop_y + 6.0:
			continue
		return {"unit": unit, "row": row, "col": col, "stop_y": stop_y}
	return {}

func _has_adjacent_shield(row: int, col: int) -> bool:
	for other_row in range(maxi(0, row - 1), mini(GRID_ROWS - 1, row + 1) + 1):
		for other_col in range(maxi(0, col - 1), mini(GRID_COLS - 1, col + 1) + 1):
			if other_row == row and other_col == col:
				continue
			var unit = grid[other_row][other_col]
			if unit != null and str(unit.hero.cls) == "shield":
				return true
	return false

func enemy_in_flood(enemy: Dictionary) -> bool:
	return not flood.is_empty() and float(flood.get("t", 0.0)) > 0 and float(enemy.y) > float(flood.y1) and float(enemy.y) < float(flood.y2)

func _update_units(delta: float) -> void:
	for unit in units():
		if float(unit.get("sealedT", 0.0)) > 0:
			unit.sealedT = maxf(0.0, float(unit.sealedT) - delta)
		var ripple_buffs: Dictionary = unit.rbuffs
		for key in ripple_buffs.keys():
			ripple_buffs[key] = float(ripple_buffs[key]) - delta
			if float(ripple_buffs[key]) <= 0:
				ripple_buffs.erase(key)
		if float(ripple_buffs.get("heal", 0.0)) > 0 and float(unit.hp) < float(unit.hp_max):
			unit.hp = minf(float(unit.hp_max), float(unit.hp) + float(unit.hp_max) * 0.02 * delta)
		for status_key in ["guardT", "reflectT", "ultT"]:
			if float(unit.get(status_key, 0.0)) > 0:
				unit[status_key] = maxf(0.0, float(unit.get(status_key, 0.0)) - delta)
		if float(unit.get("sealedT", 0.0)) > 0:
			continue
		ult_system.update_unit(self, unit, delta)
		unit.cd = float(unit.cd) - delta
		if float(unit.cd) > 0:
			continue
		var hero: Dictionary = unit.hero
		var hero_class := str(hero.cls)
		var mods: Dictionary = team.unit_mods(self, unit)
		if hero_class == "support":
			unit.cd = maxf(0.4, team.unit_rate(unit, mods))
			_cast_ripple(unit)
			continue
		if hero_class == "shield" or float(hero.get("dmg", 0.0)) <= 0:
			unit.cd = maxf(0.4, team.unit_rate(unit, mods))
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
		unit.cd = team.unit_rate(unit, mods)
		var damage := float(team.unit_damage(self, unit, mods))
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
				"crit": float(mods.crit),
				"pierce": int(hero.get("pierce", 0)) + int(mods.pierceAdd),
				"owner": unit,
				"hit": [],
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
				"crit": float(mods.crit),
				"owner": unit,
				"hit": [],
				"dead": false,
			})
		else:
			_hit_enemy(target, damage, str(hero.elem), float(mods.crit), unit)
			var pierce_count := int(hero.get("pierce", 0)) + int(mods.pierceAdd)
			if pierce_count > 0:
				var behind := enemies.filter(func(enemy):
					return enemy != target and not bool(enemy.get("dead", false)) and absf(float(enemy.x) - float(target.x)) < 45.0 and float(enemy.y) < float(target.y)
				)
				behind.sort_custom(func(a, b): return float(a.y) > float(b.y))
				for index in mini(pierce_count, behind.size()):
					_hit_enemy(behind[index], damage * 0.8, str(hero.elem), float(mods.crit), unit)

func _update_projectiles(delta: float) -> void:
	for projectile in projectiles:
		if bool(projectile.dead):
			continue
		var motion := Vector2(float(projectile.vx), float(projectile.vy)) * delta
		projectile.x = float(projectile.x) + motion.x
		projectile.y = float(projectile.y) + motion.y
		projectile.distance = float(projectile.distance) + motion.length()
		if projectile.has("life"):
			projectile.life = float(projectile.life) - delta
			if float(projectile.life) <= 0:
				projectile.dead = true
				continue
		elif float(projectile.distance) >= float(projectile.max_distance):
			projectile.dead = true
			continue
		if int(projectile.get("wall_bounce", 0)) > 0:
			var radius := float(projectile.r)
			if (float(projectile.x) <= radius + 2.0 and float(projectile.vx) < 0) or (float(projectile.x) >= 480.0 - radius - 2.0 and float(projectile.vx) > 0):
				projectile.x = clampf(float(projectile.x), radius + 2.0, 480.0 - radius - 2.0)
				projectile.vx = -float(projectile.vx)
				projectile.wall_bounce = int(projectile.wall_bounce) - 1
		if float(projectile.x) < -20.0 or float(projectile.x) > 500.0 or float(projectile.y) < -30.0 or float(projectile.y) > 800.0:
			projectile.dead = true
			continue
		for enemy in enemies.duplicate():
			if bool(enemy.get("dead", false)) or projectile.hit.has(enemy):
				continue
			var hit_radius := float(projectile.r) + float(enemy.r)
			if Vector2(float(projectile.x), float(projectile.y)).distance_squared_to(Vector2(float(enemy.x), float(enemy.y))) <= hit_radius * hit_radius:
				projectile.hit.append(enemy)
				if str(projectile.get("owner", {}).get("hero", {}).get("id", "")) == "sunshangxiang" and not bool(enemy.get("boss", false)):
					enemy.kb = minf(60.0, float(enemy.get("kb", 0.0)) + 14.0)
				if bool(projectile.get("burn", false)) and str(mutations.get(wave, "")) != "rainstorm":
					enemy.burnT = maxf(float(enemy.get("burnT", 0.0)), 2.5)
					enemy.burnDmg = maxf(float(enemy.get("burnDmg", 0.0)), maxf(1.0, round(float(projectile.damage) * 0.12)) * (2.0 if str(mutations.get(wave, "")) == "eastwind" else 1.0))
				_hit_enemy(enemy, float(projectile.damage), str(projectile.tri), float(projectile.crit), projectile.get("owner", {}))
				if int(projectile.pierce) > 0:
					projectile.pierce = int(projectile.pierce) - 1
				elif int(projectile.get("bounces", 0)) > 0:
					projectile.bounces = int(projectile.bounces) - 1
					var next_targets := enemies.filter(func(other): return not bool(other.get("dead", false)) and not projectile.hit.has(other) and Vector2(float(projectile.x), float(projectile.y)).distance_squared_to(Vector2(float(other.x), float(other.y))) < 300.0 * 300.0)
					next_targets.sort_custom(func(a, b): return Vector2(float(projectile.x), float(projectile.y)).distance_squared_to(Vector2(float(a.x), float(a.y))) < Vector2(float(projectile.x), float(projectile.y)).distance_squared_to(Vector2(float(b.x), float(b.y))))
					if next_targets.is_empty():
						projectile.dead = true
					else:
						var speed_now := Vector2(float(projectile.vx), float(projectile.vy)).length()
						var next_direction := Vector2(float(projectile.x), float(projectile.y)).direction_to(Vector2(float(next_targets[0].x), float(next_targets[0].y)))
						projectile.vx = next_direction.x * speed_now
						projectile.vy = next_direction.y * speed_now
						projectile.damage = round(float(projectile.damage) * 0.75)
						projectile.life = maxf(float(projectile.get("life", 0.0)), 0.8)
				else:
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
				_hit_enemy(enemy, float(charge.damage), str(charge.tri), float(charge.crit), charge.get("owner", {}))
				if float(charge.get("kb_mul", 0.0)) > 0:
					enemy.kb = maxf(float(enemy.get("kb", 0.0)), 90.0 * float(charge.kb_mul))
	for index in range(charges.size() - 1, -1, -1):
		if bool(charges[index].dead):
			charges.remove_at(index)

func _update_ripples(delta: float) -> void:
	for ripple in ripples:
		ripple.r = float(ripple.r) + 300.0 * delta
	for index in range(ripples.size() - 1, -1, -1):
		if float(ripples[index].r) >= float(ripples[index].max) + 40.0:
			ripples.remove_at(index)

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
	if str(hero.get("id", "")) == "dengai":
		var rocks := []
		for row in GRID_ROWS:
			for col in GRID_COLS:
				if grid[row][col] == null and obstacles.has(_cell_key(row, col)):
					rocks.append([row, col])
		if not rocks.is_empty():
			slots = rocks
	if slots.is_empty():
		return false
	var slot: Array = _pick(slots)
	var unit := _make_unit(hero, int(slot[0]), int(slot[1]))
	grid[unit.row][unit.col] = unit
	team.recompute(self)
	return true

func clear_formation() -> void:
	for row in GRID_ROWS:
		for col in GRID_COLS:
			grid[row][col] = null
	team.recompute(self)

func add_unit_at(hero_id: String, row: int, col: int) -> bool:
	if row < 0 or row >= GRID_ROWS or col < 0 or col >= GRID_COLS:
		return false
	if grid[row][col] != null:
		return false
	var hero: Dictionary = catalog.by_id("heroes", hero_id)
	if hero.is_empty():
		return false
	if obstacles.has(_cell_key(row, col)) and hero_id != "dengai":
		return false
	grid[row][col] = _make_unit(hero, row, col)
	team.recompute(self)
	return true

func _hit_enemy(enemy: Dictionary, amount: float, attacker_tri: String, critical_chance: float, source_unit: Dictionary = {}) -> int:
	var final_amount := amount
	if baihu_ready or (critical_chance > 0 and rng.next_float() < critical_chance):
		baihu_ready = false
		final_amount *= 3.0 if relic_ids.has("qinggang") else 2.0
	if relic_ids.has("guding") and (bool(enemy.get("boss", false)) or enemy.get("affix") != null):
		final_amount *= 1.25
	var hp_before := float(enemy.get("hp", 0.0)) + float(enemy.get("shield", 0.0))
	var dealt := damage_enemy(enemy, final_amount, attacker_tri)
	if not source_unit.is_empty():
		var hp_after := maxf(0.0, float(enemy.get("hp", 0.0))) + float(enemy.get("shield", 0.0))
		source_unit.damage_dealt = float(source_unit.get("damage_dealt", 0.0)) + maxf(0.0, hp_before - hp_after)
	return dealt

func _cast_ripple(unit: Dictionary) -> void:
	var center := slot_center(int(unit.row), int(unit.col))
	var kind := str(unit.hero.get("ripple", "heal"))
	var radius: float = team.ripple_max(self, unit)
	ripples.append({"x": center.x, "y": center.y - 8.0, "r": 6.0, "max": radius, "kind": kind})
	if kind == "slow" or kind == "sunder":
		for enemy in enemies:
			if bool(enemy.get("dead", false)) or float(enemy.get("y", -20.0)) < -10.0:
				continue
			if center.distance_squared_to(Vector2(float(enemy.x), float(enemy.y) + 8.0)) > radius * radius:
				continue
			if kind == "slow":
				var duration := 2.5 * (1.3 if relic_ids.has("jiaowei") else 1.0)
				enemy.slowT = maxf(float(enemy.get("slowT", 0.0)), duration)
			else:
				var duration := 7.0 if relic_ids.has("shuijingshu") else 4.0
				enemy.armorBreakT = maxf(float(enemy.get("armorBreakT", 0.0)), duration)
		return
	for ally in units():
		var ally_center := slot_center(int(ally.row), int(ally.col))
		if center.distance_squared_to(ally_center) > radius * radius:
			continue
		if kind == "heal":
			ally.hp = minf(float(ally.hp_max), float(ally.hp) + float(ally.hp_max) * 0.12)
			ally.rbuffs["heal"] = maxf(float(ally.rbuffs.get("heal", 0.0)), 4.5)
		elif kind == "soothe":
			ally.sealedT = 0.0
			ally.hp = minf(float(ally.hp_max), float(ally.hp) + float(ally.hp_max) * 0.08)
		elif kind in ["dmg", "haste", "crit", "cdr"]:
			var ally_class := str(ally.hero.cls)
			var attacks := float(ally.hero.get("dmg", 0.0)) > 0
			if (kind == "dmg" or kind == "crit") and not attacks:
				continue
			if kind == "haste" and ally_class == "shield":
				continue
			ally.rbuffs[kind] = maxf(float(ally.rbuffs.get(kind, 0.0)), 5.5)

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
	if number % 5 == 0:
		var boss_name := str(city.get("bossName", ""))
		if boss_name.is_empty():
			boss_name = BOSS_NAMES[mini(number / 5 - 1, BOSS_NAMES.size() - 1)]
		var mega := boss_name.contains("张角")
		var boss_tri: String = foe_tri if not foe_tri.is_empty() else str(_pick(TRI_KEYS))
		var boss_spec := {
			"delay": 1.2,
			"hp": hp * (26 if mega else 16),
			"speed": base_speed * 0.45,
			"r": 46 if mega else 40,
			"cls": _pick(ENEMY_CLASSES),
			"big": true,
			"boss": true,
			"bossName": boss_name,
			"affix": "shield" if mega or str(city.get("bossKit", "")) == "affixlord" else null,
			"special": null,
			"tri": boss_tri,
			"xp": base_xp * (25.0 if mega else 14.0),
			"dmg": 10 if mega else 6,
		}
		queue.append(boss_spec)
		if bool(city.get("eliteWave", false)):
			var shadow: Dictionary = boss_spec.duplicate(true)
			shadow.delay = 2.5
			shadow.hp = roundi(float(boss_spec.hp) * 0.75)
			shadow.bossName = boss_name + "·影"
			queue.append(shadow)
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
	var unit := {
		"hero": hero,
		"row": row,
		"col": col,
		"level": 1,
		"hp": max_hp,
		"hp_max": max_hp,
		"cd": _randf(0.0, 0.3),
		"rbuffs": {},
		"sealedT": 0.0,
		"damage_dealt": 0.0,
		"ultCd": 0.0,
		"guardT": 0.0,
		"reflectT": 0.0,
		"ultT": 0.0,
		"auraTick": 0.0,
	}
	unit.ultCd = ult_system.initial_cooldown(self, str(hero.id))
	return unit

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
	var bond_hp := float(team.bond_fx(self, str(hero.id)).hp)
	return int(round(base * (1.0 + (stars - 1) * 0.25) * shield_scale * bond_hp))

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
