class_name BattleRun
extends RefCounted

const BattleCardsScript = preload("res://src/battle/battle_cards.gd")
const BattleTeamScript = preload("res://src/battle/battle_team.gd")
const BattleLordScript = preload("res://src/battle/battle_lord.gd")
const BattleFoeLordScript = preload("res://src/battle/battle_foe_lord.gd")
const BattleUltsScript = preload("res://src/battle/battle_ults.gd")
const BattleFoesScript = preload("res://src/battle/battle_foes.gd")
const BattleEnvironmentScript = preload("res://src/battle/battle_environment.gd")
const BattleRecordsScript = preload("res://src/progression/battle_records.gd")

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
const GRANARY_G0 := 0.8
const GRANARY_G1 := 0.12
const GRANARY_STAR_MULTIPLIER := 1.6
const GRANARY_WAVE_CAP := 30
const GRANARY_STAR_COST := 1.8
const DAMAGE_CATEGORIES := {
	"lord": {"key": "@lord", "icon": "👑", "name": "主公"},
	"fan": {"key": "@fan", "icon": "🛡️", "name": "盾反"},
	"fire": {"key": "@fire", "icon": "🔥", "name": "火燎"},
	"rock": {"key": "@rock", "icon": "🪨", "name": "乱石"},
	"relic": {"key": "@relic", "icon": "🧿", "name": "遗宝"},
	"field": {"key": "@field", "icon": "🌋", "name": "地形"},
	"misc": {"key": "@misc", "icon": "🎲", "name": "其他"},
}
const ENDLESS_RULES := [
	{"key": "smoke", "name": "烟瘴弥漫", "tip": "弓兵射程-35%", "mod": {"archerRngMul": 0.65}},
	{"key": "mud", "name": "泥沼遍地", "tip": "骑兵冲锋只有一半远", "mod": {"cavChargeMul": 0.55}},
	{"key": "crossbow", "name": "连弩贼", "tip": "弓贼投石兵成倍地来", "mod": {"rangedMul": 2.2}},
	{"key": "rush", "name": "急行军", "tip": "敌人跑快15%", "mod": {"spdMul": 1.15}},
	{"key": "shift", "name": "换皮妖法", "tip": "贼换了怕的属性，看预告", "mod": {}},
]

var catalog
var rng
var card_system
var team
var lord_system
var foe_system
var ult_system
var foe_behavior
var environment
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
var wall_shield := 0
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
var granary_offered := false
var egg_offered := false
var shen_dry := 0
var gewu_auto_timer := 0.0
var gewu_auto_index := -1
var dance_time := 0.0
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
var wall_hurt := false
var stars := 0
var win_wave := 0
var endless := false
var endless_mod: Dictionary = {}
var endless_pending: Dictionary = {}
var endless_foes: Dictionary = {}
var scored_wave := 0
var score_revision := 0
var total_damage := 0.0
var counter_damage := 0.0
var max_hit := 0
var damage_book: Dictionary = {}
var bond_ever := false
var run_gold := 0.0
var band_gold := 0
var gold_committed := 0
var kills_committed := 0
var clear_settled := false
var over_settled := false
var field_events: Array = []
var dragon_count := 0
var dragon_waves: Array = []
var farm_stars := 0
var achievement_events: Array = []
var known_achievement_ids: Array = []
var battle_floaters: Array = []
var grid: Array = []
var obstacles: Dictionary = {}
var traits: Dictionary = {}
var mutations: Dictionary = {}
var enemies: Array = []
var projectiles: Array = []
var homers: Array = []
var charges: Array = []
var ripples: Array = []
var skill_lines: Array = []
var enemy_projectiles: Array = []
var enemy_lobs: Array = []
var enemy_wall_lobs: Array = []
var cata_volley_time := 0.0
var focus_target: Dictionary = {}
var focus_time := 0.0
var ult_events: Array = []
var ults_used := 0
var blockade: Dictionary = {}
var palisades: Array = []
var traps: Array = []
var fire_pits: Array = []
var friendly_lobs: Array = []
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
	foe_behavior = BattleFoesScript.new()
	environment = BattleEnvironmentScript.new()

func start(level_data: Dictionary, selected_ruler_id: String, opening_hero_id: String, selected_ruler_level := 1, selected_hero_levels: Dictionary = {}, selected_shen_period := 0, selected_shen_ids: Array = []) -> void:
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
	shen_period = int(selected_shen_period)
	shen_ids = selected_shen_ids.duplicate()
	speed = 2
	wall = int(city.wall)
	wall_max = wall
	wall_shield = 0
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
	granary_offered = false
	egg_offered = false
	shen_dry = 0
	gewu_auto_timer = 0.0
	gewu_auto_index = -1
	dance_time = 0.0
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
	var wall_level: int = lord_system.passive_level(self, "wall")
	if wall_level > 0:
		wall += wall_level
		wall_max += wall_level
	xp += lord_system.passive_level(self, "vet") * 10.0
	buffs.xpGain = 1.0 + lord_system.passive_level(self, "farm") * 0.04
	wall_shield += lord_system.passive_level(self, "pick") * 2
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
	wall_hurt = false
	stars = 0
	win_wave = 0
	endless = false
	endless_mod = {}
	endless_pending = {}
	endless_foes = {}
	scored_wave = 0
	score_revision = 0
	total_damage = 0.0
	counter_damage = 0.0
	max_hit = 0
	damage_book = {}
	bond_ever = false
	run_gold = 0.0
	band_gold = 0
	gold_committed = 0
	kills_committed = 0
	clear_settled = false
	over_settled = false
	field_events = []
	dragon_count = 0
	dragon_waves = []
	farm_stars = 0
	achievement_events = []
	battle_floaters = []
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
	homers = []
	charges = []
	ripples = []
	skill_lines = []
	enemy_projectiles = []
	enemy_lobs = []
	enemy_wall_lobs = []
	cata_volley_time = 0.0
	focus_target = {}
	focus_time = 0.0
	ult_events = []
	ults_used = 0
	blockade = {}
	palisades = []
	traps = []
	fire_pits = []
	friendly_lobs = []
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
	environment.setup(self)

func advance_real(delta: float) -> void:
	if status != "play":
		return
	if awaiting_card_choice:
		game_time += delta
		_update_battle_floaters(delta)
		_advance_paused_card_visuals(delta)
		return
	for step in speed:
		_update_step(delta)

func advance_visual_only(delta: float) -> void:
	game_time += delta
	_update_battle_floaters(delta)
	_advance_paused_card_visuals(delta)
	_decay_visual_events(field_events, delta)
	_decay_visual_events(skill_lines, delta)
	_decay_visual_events(ult_events, delta)
	_decay_visual_events(lord_command_events, delta)
	_update_ripples(delta)
	_update_lord_visuals(delta)
	for lob in friendly_lobs:
		if bool(lob.get("dead", false)) or float(lob.get("damage", 0.0)) > 0.0 or not lob.get("pit", {}).is_empty():
			continue
		lob.t = float(lob.get("t", 0.0)) + delta
		if float(lob.t) >= float(lob.get("dur", 0.0)):
			lob.dead = true
	for index in range(friendly_lobs.size() - 1, -1, -1):
		if bool(friendly_lobs[index].get("dead", false)):
			friendly_lobs.remove_at(index)

func _advance_paused_card_visuals(delta: float) -> void:
	dance_time = maxf(0.0, dance_time - delta)
	if not awaiting_card_choice or not bool(permanent_tactics.get("gewu", false)) or dance_time > 0.0:
		return
	if gewu_auto_index < 0 and not card_choices.is_empty():
		var safe_indices := []
		for index in card_choices.size():
			if not ["seppuku", "dance"].has(str(card_choices[index].kind)):
				safe_indices.append(index)
		gewu_auto_index = 0
		if not safe_indices.is_empty():
			gewu_auto_index = int(safe_indices[int(floor(rng.next_float() * safe_indices.size()))])
	gewu_auto_timer += delta
	if gewu_auto_timer >= 1.5 and not card_choices.is_empty():
		choose_card(gewu_auto_index)

func _decay_visual_events(events: Array, delta: float) -> void:
	for event in events:
		event.t = float(event.get("t", 0.0)) - delta
	for index in range(events.size() - 1, -1, -1):
		if float(events[index].get("t", 0.0)) <= 0.0:
			events.remove_at(index)

static func triangle_multiplier(attacker_tri: String, enemy_tri: String) -> float:
	if not attacker_tri or not enemy_tri:
		return 1.0
	if TRI_KE.get(attacker_tri, "") == enemy_tri:
		return 1.5
	if TRI_KE.get(enemy_tri, "") == attacker_tri:
		return 0.6
	return 1.0

func damage_enemy(enemy: Dictionary, amount: float, attacker_tri := "", source = "") -> int:
	if bool(enemy.get("dead", false)):
		return 0
	if bool(enemy.get("_guarded", false)):
		amount *= 0.7
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
	max_hit = maxi(max_hit, damage)
	var actual_damage := minf(damage, maxf(0.0, float(enemy.get("shield", 0.0))) + maxf(0.0, float(enemy.get("hp", 0.0))))
	record_damage(source, actual_damage)
	total_damage += damage
	if is_equal_approx(triangle, 1.5): counter_damage += damage
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
		if bool(enemy.get("boss", false)) and ["thunder", "avatar"].has(str(enemy.get("kit", ""))) and not bool(enemy.get("revived", false)):
			enemy.revived = true
			enemy.hp = round(float(enemy.hp_max) * 0.4)
			return damage
		var drowned := enemy_in_flood(enemy)
		enemy.dead = true
		kills += 1
		environment.on_enemy_death(self, enemy)
		var xp_multiplier := 1.0
		if ruler_id == "sunquan":
			xp_multiplier = 2.0 if drowned else 1.3
		elif ruler_id == "gongsunzan" and damage_source_key(source) == "@lord":
			xp_multiplier = 3.0
		elif ruler_id == "dongzhuo" and float(enemy.get("burnT", 0.0)) > 0:
			xp_multiplier = 2.0
		gain_xp(float(enemy.get("xp", 0.0)) * xp_multiplier)
		if kills >= int(city.get("killTarget", 450)) and not endless:
			finish("win")
		elif bool(enemy.get("boss", false)):
			queue_relic_draft()
		_on_enemy_death(enemy)
		var index := enemies.find(enemy)
		if index >= 0:
			enemies.remove_at(index)
	return damage

func damage_source_key(source) -> String:
	if source is Dictionary and source.has("hero"):
		return str(source.hero.get("id", "@misc"))
	var alias := str(source).trim_prefix("@")
	return str(DAMAGE_CATEGORIES.get(alias, DAMAGE_CATEGORIES.misc).key)

func record_damage(source, amount: float) -> void:
	if amount <= 0.0:
		return
	var key := damage_source_key(source)
	var icon := ""
	var name := ""
	if source is Dictionary and source.has("hero"):
		name = str(source.hero.get("name", "其他"))
		source.damage_dealt = float(source.get("damage_dealt", 0.0)) + amount
	else:
		var category: Dictionary = DAMAGE_CATEGORIES.get(key.trim_prefix("@"), DAMAGE_CATEGORIES.misc)
		icon = str(category.icon)
		name = str(category.name)
	var entry: Dictionary = damage_book.get(key, {"icon": icon, "name": name, "total": 0.0, "log": []})
	entry.total = float(entry.total) + amount
	var second := floori(game_time)
	var log: Array = entry.log
	if not log.is_empty() and int(log[-1][0]) == second:
		log[-1][1] = float(log[-1][1]) + amount
	else:
		log.append([second, amount])
	while not log.is_empty() and int(log[0][0]) < second - 10:
		log.pop_front()
	entry.log = log
	damage_book[key] = entry

func finish(result: String) -> void:
	if status != "play": return
	status = result
	if result == "win":
		stars = BattleRecordsScript.calc_stars(wall_hurt, unit_deaths)
		win_wave = wave
	enemy_projectiles.clear()
	enemy_lobs.clear()
	enemy_wall_lobs.clear()
	homers.clear()
	friendly_lobs.clear()
	skill_lines.clear()

func continue_endless() -> bool:
	if status != "win" or win_wave <= 0: return false
	endless = true
	status = "play"
	return true

func _endless_rule_tick(next_wave: int) -> void:
	if not endless_mod.is_empty() and next_wave > int(endless_mod.get("until", 0)):
		endless_mod = {}
		endless_foes = {}
	if not endless_pending.is_empty() and next_wave % 5 == 0:
		endless_mod = endless_pending.duplicate(true)
		endless_mod.until = next_wave + 4
		endless_pending = {}
		if str(endless_mod.key) == "shift":
			var base_tri := str(city.get("foes", {}).get("tri", ""))
			if not base_tri.is_empty():
				endless_foes = {"tri": _pick(TRI_KEYS.filter(func(key): return str(key) != base_tri))}
			else:
				endless_foes = {}
		else:
			endless_foes = {}
	elif endless_pending.is_empty() and (next_wave + 1) % 5 == 0 and next_wave >= 4:
		var current_key := str(endless_mod.get("key", ""))
		var candidates: Array = ENDLESS_RULES.filter(func(rule): return str(rule.key) != current_key)
		endless_pending = _pick(candidates).duplicate(true)

func endless_mod_value(key: String, fallback := 1.0) -> float:
	return float(endless_mod.get("mod", {}).get(key, fallback))

func foe_tenacity() -> float:
	var extra := maxi(0, wave - win_wave - 5) if endless and win_wave > 0 else 0
	return maxf(0.12, pow(0.93, extra)) if extra > 0 else 1.0

func effective_archer_range(hero: Dictionary) -> float:
	var attack_range := float(hero.get("rng", 0.0))
	if str(hero.get("cls", "")) == "archer":
		var field: Dictionary = catalog.by_id("fields", str(city.get("field", "")))
		attack_range *= float(field.get("archerRng", 1.0)) * float(city.get("archerRngMul", 1.0)) * endless_mod_value("archerRngMul")
	return attack_range

func gain_xp(amount: float) -> void:
	var field: Dictionary = catalog.by_id("fields", str(city.get("field", "")))
	xp += amount * float(buffs.get("xpGain", 1.0)) * float(field.get("xpMul", 1.0))
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
	gewu_auto_index = -1
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
	_update_battle_floaters(delta)
	dance_time = maxf(0.0, dance_time - delta)
	_update_focus(delta)
	for event in field_events:
		event.t = float(event.t) - delta
	for index in range(field_events.size() - 1, -1, -1):
		if float(field_events[index].t) <= 0: field_events.remove_at(index)
	if relic_ids.has("qixing") and wall < wall_max:
		wall_regen_timer -= delta
		if wall_regen_timer <= 0:
			wall = mini(wall_max, wall + 1)
			wall_regen_timer += 30.0
	var field_clear := spawn_queue.is_empty() and enemies.is_empty()
	if field_clear:
		if endless and win_wave > 0 and scored_wave != wave:
			scored_wave = wave
			score_revision += 1
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
	environment.update(self, delta)
	_update_enemies(delta)
	_update_units(delta)
	_update_ultimate_effects(delta)
	_update_projectiles(delta)
	_update_homers(delta)
	_update_enemy_attacks(delta)
	_update_charges(delta)
	_update_ripples(delta)
	_update_foe_lord(delta)
	_update_lord_command(delta)
	_update_lord_auto_attack(delta)
	_update_lord_visuals(delta)

func _update_ultimate_effects(delta: float) -> void:
	for line in skill_lines:
		line.t = float(line.t) - delta
	for index in range(skill_lines.size() - 1, -1, -1):
		if float(skill_lines[index].t) <= 0.0:
			skill_lines.remove_at(index)
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
	_update_friendly_lobs(delta)
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
		if str(mutations.get(wave, "")) == "rainstorm":
			continue
		for enemy in enemies:
			if bool(enemy.get("dead", false)) or Vector2(float(pit.x), float(pit.y)).distance_squared_to(Vector2(float(enemy.x), float(enemy.y))) > pow(float(pit.r), 2):
				continue
			enemy.burnT = maxf(float(enemy.get("burnT", 0.0)), 0.8)
			enemy.burnDmg = maxf(float(enemy.get("burnDmg", 0.0)), float(pit.damage))
			enemy.burnSrc = pit.get("owner", {})
	for index in range(fire_pits.size() - 1, -1, -1):
		if float(fire_pits[index].t) <= 0: fire_pits.remove_at(index)

func _update_friendly_lobs(delta: float) -> void:
	for lob in friendly_lobs:
		if bool(lob.get("dead", false)):
			continue
		lob.t = float(lob.t) + delta
		if float(lob.t) < float(lob.dur):
			continue
		lob.dead = true
		if float(lob.get("damage", 0.0)) > 0.0:
			for enemy in enemies.duplicate():
				if bool(enemy.get("dead", false)):
					continue
				if Vector2(float(lob.x1), float(lob.y1)).distance_squared_to(Vector2(float(enemy.x), float(enemy.y))) <= pow(float(lob.get("splash", 0.0)) + float(enemy.r), 2):
					damage_enemy_from_unit(enemy, float(lob.damage), str(lob.element), lob.get("owner", {}))
		var pit: Dictionary = lob.get("pit", {})
		if not pit.is_empty():
			fire_pits.append({"x": float(lob.x1), "y": float(lob.y1), "r": float(pit.r), "t": float(pit.t), "tick": 0.0, "damage": float(pit.damage), "owner": lob.get("owner", {})})
	for index in range(friendly_lobs.size() - 1, -1, -1):
		if bool(friendly_lobs[index].get("dead", false)):
			friendly_lobs.remove_at(index)

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
	var extra := maxi(0, wave - win_wave - 5) if endless and win_wave > 0 else 0
	return (1.3 if foe_rage_time > 0 else 1.0) * (pow(1.10, extra) if extra > 0 else 1.0)

func cavalry_crowd_multiplier() -> float:
	var active_enemies := 0
	for enemy in enemies:
		if not bool(enemy.get("dead", false)) and float(enemy.get("y", -999.0)) > -10.0:
			active_enemies += 1
	return 1.0 + minf(0.35, 0.02 * maxf(0.0, float(active_enemies - 10)))

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
	var enemy_speed := float(spec.speed)
	var x_min := 40.0
	var x_max := 440.0
	if bool(spec.get("apply_field", true)):
		var field: Dictionary = catalog.by_id("fields", str(city.get("field", "")))
		if field.has("hpMul"): hp = round(hp * float(field.hpMul))
		if field.has("spdMul"): enemy_speed *= float(field.spdMul)
		if bool(field.get("narrow", false)):
			x_min = 480.0 * 0.28
			x_max = 480.0 * 0.72
	var enemy := spec.duplicate(true)
	enemy["x"] = _randf(x_min, x_max) if spec.get("x") == null else float(spec.x)
	enemy["y"] = -40.0 if spec.get("y") == null else float(spec.y)
	enemy["hp"] = hp
	enemy["hp_max"] = hp
	enemy["base_speed"] = enemy_speed
	enemy["dead"] = false
	var shield: float = round(hp * 0.6) if str(spec.get("affix", "")) == "shield" else 0.0
	enemy["shield"] = shield
	enemy["shield_max"] = shield
	enemy["boss"] = bool(spec.get("boss", false))
	enemy["big"] = bool(spec.get("big", false))
	enemy["summoner"] = bool(spec.get("summoner", false))
	enemy["kit"] = spec.get("kit", null)
	enemy["kitSplit"] = int(spec.get("kitSplit", 0))
	enemy["summonT"] = 3.5 if ["summon", "avatar"].has(str(enemy.kit)) else 6.0
	enemy["auraT"] = 0.0
	enemy["sealCastT"] = 0.0
	enemy["regenTick"] = 0.0
	enemy["silencedT"] = float(enemy.get("silencedT", 0.0))
	enemy["stunT"] = float(enemy.get("stunT", 0.0))
	enemy["fearT"] = float(enemy.get("fearT", 0.0))
	enemy["sleepT"] = float(enemy.get("sleepT", 0.0))
	enemy["charmT"] = float(enemy.get("charmT", 0.0))
	enemy["slowT"] = float(enemy.get("slowT", 0.0))
	enemy["burnT"] = float(enemy.get("burnT", 0.0))
	enemy["burnDmg"] = float(enemy.get("burnDmg", 0.0))
	enemy["burnTick"] = float(enemy.get("burnTick", 0.0))
	enemies.append(enemy)

func _update_enemies(delta: float) -> void:
	cata_volley_time = maxf(0.0, cata_volley_time - delta)
	var control_delta := delta / foe_tenacity()
	var banners := enemies.filter(func(other): return str(other.get("special", "")) == "banner" and not bool(other.get("dead", false)) and float(other.get("silencedT", 0.0)) <= 0)
	var wardens := enemies.filter(func(other): return str(other.get("special", "")) == "warden" and not bool(other.get("dead", false)) and float(other.get("silencedT", 0.0)) <= 0)
	for enemy in enemies.duplicate():
		if bool(enemy.get("dead", false)): continue
		if float(enemy.get("burnT", 0.0)) > 0:
			enemy.burnT = maxf(0.0, float(enemy.burnT) - delta)
			enemy.burnTick = float(enemy.get("burnTick", 0.0)) - delta
			if float(enemy.burnTick) <= 0:
				enemy.burnTick = 0.5
				damage_enemy(enemy, float(enemy.get("burnDmg", 0.0)) * environment.burn_multiplier(self), "", enemy.get("burnSrc", "fire"))
				if bool(enemy.get("dead", false)): continue
		var slowed := float(enemy.get("slowT", 0.0)) > 0
		if slowed: enemy.slowT = maxf(0.0, float(enemy.slowT) - control_delta)
		if float(enemy.get("armorBreakT", 0.0)) > 0: enemy.armorBreakT = maxf(0.0, float(enemy.armorBreakT) - delta)
		for status_key in ["charmT", "sleepT", "fearT", "silencedT"]:
			if float(enemy.get(status_key, 0.0)) > 0: enemy[status_key] = maxf(0.0, float(enemy.get(status_key, 0.0)) - control_delta)
		for status_key in ["jianjunT", "duelT"]:
			if float(enemy.get(status_key, 0.0)) > 0: enemy[status_key] = maxf(0.0, float(enemy.get(status_key, 0.0)) - delta)
		if str(enemy.get("special", "")) == "ram":
			enemy.fearT = 0.0
			enemy.sleepT = 0.0
			enemy.charmT = 0.0
			enemy.slowT = maxf(0.0, float(enemy.get("slowT", 0.0)) - control_delta)
			enemy.stunT = maxf(0.0, float(enemy.get("stunT", 0.0)) - control_delta)
			enemy.kb = minf(float(enemy.get("kb", 0.0)), 10.0)
		_update_enemy_abilities(enemy, delta)
		if bool(enemy.get("dead", false)): continue
		enemy._guarded = false
		var banner_multiplier := 1.0
		if enemy.get("special") == null:
			for banner in banners:
				if Vector2(float(enemy.x), float(enemy.y)).distance_squared_to(Vector2(float(banner.x), float(banner.y))) < 120.0 * 120.0:
					banner_multiplier = 1.35
					break
			for warden in wardens:
				if Vector2(float(enemy.x), float(enemy.y)).distance_squared_to(Vector2(float(warden.x), float(warden.y))) < 130.0 * 130.0:
					enemy._guarded = true
					break
		var frenzy := (str(enemy.get("affix", "")) == "frenzy" or str(enemy.get("kit", "")) == "affixlord") and float(enemy.hp) < float(enemy.hp_max) * 0.4
		var speed_now: float = float(enemy.base_speed) * (0.55 if slowed else 1.0) * environment.movement_multiplier(self, enemy) * (0.6 if enemy_in_flood(enemy) else 1.0) * banner_multiplier * (1.6 if frenzy else 1.0)
		if float(enemy.get("kb", 0.0)) > 0:
			var knock_step := minf(float(enemy.kb), 300.0 * delta)
			enemy.y = maxf(-30.0, float(enemy.y) - knock_step)
			enemy.kb = float(enemy.kb) - knock_step
		if float(enemy.get("stunT", 0.0)) > 0:
			enemy.stunT = maxf(0.0, float(enemy.stunT) - control_delta)
			continue
		if float(enemy.get("sleepT", 0.0)) > 0: continue
		if float(enemy.get("turncoatT", 0.0)) > 0:
			enemy.turncoatT = maxf(0.0, float(enemy.turncoatT) - delta)
			enemy.turncoatTick = float(enemy.get("turncoatTick", 0.0)) - delta
			if float(enemy.turncoatTick) <= 0:
				enemy.turncoatTick = 0.8
				var victims := enemies.filter(func(other): return other != enemy and not bool(other.get("dead", false)) and float(other.get("turncoatT", 0.0)) <= 0 and Vector2(float(enemy.x), float(enemy.y)).distance_squared_to(Vector2(float(other.x), float(other.y))) < 160.0 * 160.0)
				victims.sort_custom(func(a, b): return Vector2(float(enemy.x), float(enemy.y)).distance_squared_to(Vector2(float(a.x), float(a.y))) < Vector2(float(enemy.x), float(enemy.y)).distance_squared_to(Vector2(float(b.x), float(b.y))))
				if not victims.is_empty(): damage_enemy(victims[0], maxf(3.0, float(enemy.get("hp_max", 100.0)) * 0.08), "", enemy.get("turncoatOwner", ""))
			continue
		if float(enemy.get("fearT", 0.0)) > 0:
			enemy.y = maxf(-30.0, float(enemy.y) - speed_now * 0.8 * delta)
			continue
		if _apply_ultimate_blockers(enemy, delta): continue
		var blocker := _find_lane_blocker(enemy)
		if not blocker.is_empty():
			var target_x := GRID_X + int(blocker.col) * CELL + CELL / 2.0
			if absf(target_x - float(enemy.x)) > 4.0: enemy.x = move_toward(float(enemy.x), target_x, 130.0 * delta)
		var special := str(enemy.get("special", ""))
		if special == "assassin" and float(enemy.y) > GRID_Y - 170.0:
			_update_assassin(enemy, delta)
		elif special == "shooter" and float(enemy.get("silencedT", 0.0)) <= 0 and not enemy_in_flood(enemy) and not blocker.is_empty() and float(blocker.stop_y) - float(enemy.y) < 300.0 and float(enemy.y) < float(blocker.stop_y):
			enemy.y = minf(float(blocker.stop_y), float(enemy.y) + speed_now * 0.4 * delta)
			enemy.shootT = float(enemy.get("shootT", 0.9)) - delta
			if float(enemy.shootT) <= 0:
				enemy.shootT = 2.2
				var shooter_hit := roundi(7.0 * (1.0 + wave * 0.06) * foe_damage_multiplier())
				_shoot_enemy_arrow(enemy, blocker.unit, maxi(1, roundi(shooter_hit * 0.9)), 260.0)
		elif special == "thrower" and float(enemy.get("silencedT", 0.0)) <= 0 and not enemy_in_flood(enemy) and not blocker.is_empty() and float(enemy.y) > GRID_Y - 340.0 and float(enemy.y) < float(blocker.stop_y):
			enemy.y = minf(float(blocker.stop_y), float(enemy.y) + speed_now * 0.35 * delta)
			enemy.throwT = float(enemy.get("throwT", 1.4)) - delta
			if float(enemy.throwT) <= 0:
				enemy.throwT = 4.0
				_throw_enemy_lob(enemy, 0.8)
		elif special == "cata" and float(enemy.y) > GRID_Y - 220.0:
			if float(enemy.get("silencedT", 0.0)) <= 0 and not enemy_in_flood(enemy):
				enemy.lobT = maxf(-0.5, float(enemy.get("lobT", 4.0)) - delta)
				if float(enemy.lobT) <= 0 and cata_volley_time <= 0 and not enemy.has("cataWind"):
					enemy.cataWind = 2.0
					cata_volley_time = 4.0
				if enemy.has("cataWind"):
					enemy.cataWind = float(enemy.cataWind) - delta
					if float(enemy.cataWind) <= 0:
						enemy.erase("cataWind")
						enemy.lobT = 10.0
						enemy.cataHit = 1.4
						enemy_wall_lobs.append({"x0": float(enemy.x), "y0": float(enemy.y) + float(enemy.r) * 0.6, "x1": clampf(float(enemy.x) + _randf(-24.0, 24.0), 20.0, 460.0), "y1": DEFENSE_LINE - 4.0, "t": 0.0, "dur": 1.4, "source": enemy, "visual_only": true, "dead": false})
			elif enemy.has("cataWind"):
				enemy.erase("cataWind")
				enemy.lobT = 1.0
			if enemy.has("cataHit"):
				enemy.cataHit = float(enemy.cataHit) - delta
				if float(enemy.cataHit) <= 0:
					enemy.erase("cataHit")
					damage_wall(1)
		elif not blocker.is_empty():
			_update_enemy_melee(enemy, blocker, speed_now, delta)
		else:
			enemy.y = float(enemy.y) + speed_now * delta
		if float(enemy.y) > DEFENSE_LINE - 6.0:
			var wall_damage := int(enemy.dmg)
			if relic_ids.has("lianhuan"): wall_damage = maxi(1, wall_damage - 1)
			damage_wall(wall_damage)
			enemy.dead = true
	for index in range(enemies.size() - 1, -1, -1):
		if bool(enemies[index].get("dead", false)): enemies.remove_at(index)

func _update_enemy_abilities(enemy: Dictionary, delta: float) -> void:
	var silenced := float(enemy.get("silencedT", 0.0)) > 0
	var special := str(enemy.get("special", ""))
	if special == "healer" and not silenced:
		enemy.auraT = float(enemy.get("auraT", 0.0)) - delta
		if float(enemy.auraT) <= 0:
			enemy.auraT = 1.5
			for other in enemies:
				if other == enemy or bool(other.get("dead", false)) or float(other.hp) >= float(other.hp_max): continue
				if Vector2(float(enemy.x), float(enemy.y)).distance_squared_to(Vector2(float(other.x), float(other.y))) < 110.0 * 110.0:
					other.hp = minf(float(other.hp_max), float(other.hp) + round(float(other.hp_max) * 0.06))
	if special == "shaman" and float(enemy.y) > 60.0 and not silenced:
		enemy.sealCastT = float(enemy.get("sealCastT", 0.0)) - delta
		if float(enemy.sealCastT) <= 0:
			enemy.sealCastT = 7.0
			var targets := units().filter(func(unit): return float(unit.get("sealedT", 0.0)) <= 0)
			if not targets.is_empty():
				var target: Dictionary = _pick(targets)
				target.sealedT = 3.0
	if bool(enemy.get("summoner", false)) and not silenced:
		enemy.summonT = float(enemy.get("summonT", 6.0)) - delta
		if float(enemy.summonT) <= 0:
			var fast := ["summon", "avatar"].has(str(enemy.get("kit", "")))
			enemy.summonT = 3.5 if fast else 6.0
			for index in (4 if fast else 3):
				_spawn_child_enemy(enemy, {
					"hp_ratio": 0.04, "speed_mul": 1.8, "r": 13, "big": false,
					"xp": 1.0, "dmg": 1, "x_spread": 50.0, "behind": true,
					"random_class": true, "inherit_tri": false,
				})
	if (str(enemy.get("affix", "")) == "regen" or str(enemy.get("kit", "")) == "affixlord") and float(enemy.hp) < float(enemy.hp_max):
		enemy.regenTick = float(enemy.get("regenTick", 0.0)) - delta
		if float(enemy.regenTick) <= 0:
			enemy.regenTick = 1.0
			enemy.hp = minf(float(enemy.hp_max), float(enemy.hp) + maxf(1.0, round(float(enemy.hp_max) * 0.02)))
	if not bool(enemy.get("boss", false)) or silenced: return
	if wave >= 10 and not enemy_in_flood(enemy):
		enemy.bossThrowT = float(enemy.get("bossThrowT", 5.0)) - delta
		if float(enemy.bossThrowT) <= 0 and not units().is_empty():
			enemy.bossThrowT = 5.0
			_throw_enemy_lob(enemy, 0.8)
	var kit := str(enemy.get("kit", ""))
	if kit == "firepot":
		enemy.kitT = float(enemy.get("kitT", 5.0)) - delta
		if float(enemy.kitT) <= 0 and not units().is_empty():
			enemy.kitT = 4.5
			_throw_enemy_lob(enemy, 1.25)
			_throw_enemy_lob(enemy, 1.25)
	elif kit == "volley":
		enemy.kitT = float(enemy.get("kitT", 4.0)) - delta
		if float(enemy.kitT) <= 0 and not units().is_empty():
			enemy.kitT = 3.5
			for index in 4:
				_shoot_enemy_arrow(enemy, {}, roundi(9.0 * (1.0 + wave * 0.06)), 280.0, 12.0)
	if kit == "sealwave" or kit == "avatar":
		enemy.sealKitT = float(enemy.get("sealKitT", 8.0)) - delta
		if float(enemy.sealKitT) <= 0:
			enemy.sealKitT = 9.0
			var seal_targets := units().filter(func(unit): return float(unit.get("sealedT", 0.0)) <= 0)
			for index in mini(2, seal_targets.size()):
				var chosen_index := int(floor(rng.next_float() * seal_targets.size()))
				var sealed: Dictionary = seal_targets.pop_at(chosen_index)
				sealed.sealedT = 2.5
	if kit == "thunder" or kit == "avatar":
		enemy.thunderKitT = float(enemy.get("thunderKitT", 7.0)) - delta
		if float(enemy.thunderKitT) <= 0 and not units().is_empty():
			enemy.thunderKitT = 7.0
			var target: Dictionary = _pick(units())
			var position := _find_unit_position(target)
			if not position.is_empty(): hurt_unit(target, roundi(12.0 + wave), int(position.row), int(position.col))

func _update_assassin(enemy: Dictionary, delta: float) -> void:
	if not bool(enemy.get("leaped", false)):
		var target: Dictionary = {}
		for row in range(GRID_ROWS - 1, -1, -1):
			var candidates := []
			for col in GRID_COLS:
				if grid[row][col] != null: candidates.append({"unit": grid[row][col], "row": row, "col": col})
			if candidates.is_empty(): continue
			var soft := candidates.filter(func(candidate): return ["archer", "support", "granary", "egg"].has(str(candidate.unit.hero.cls)))
			target = _pick(soft if not soft.is_empty() else candidates)
			break
		if target.is_empty():
			enemy.y = float(enemy.y) + float(enemy.base_speed) * delta
			return
		var center := slot_center(int(target.row), int(target.col))
		enemy.x = center.x + _randf(-14.0, 14.0)
		enemy.y = center.y - 30.0
		enemy.leaped = true
		enemy.assR = int(target.row)
		enemy.assC = int(target.col)
	var row := int(enemy.get("assR", -1))
	var col := int(enemy.get("assC", -1))
	var unit = grid[row][col] if row >= 0 and row < GRID_ROWS and col >= 0 and col < GRID_COLS else null
	if unit == null or float(unit.hp) <= 0:
		enemy.leaped = false
		return
	enemy.atkT = float(enemy.get("atkT", 0.5)) - delta
	if float(enemy.atkT) <= 0:
		enemy.atkT = 0.85
		hurt_unit(unit, roundi(9.0 * (1.0 + wave * 0.06) * foe_damage_multiplier()), row, col)

func _update_enemy_melee(enemy: Dictionary, blocker: Dictionary, speed_now: float, delta: float) -> void:
	var stop_y := float(blocker.stop_y)
	if float(enemy.y) < stop_y:
		enemy.y = minf(stop_y, float(enemy.y) + speed_now * delta)
		return
	enemy.y = stop_y
	enemy.atkT = float(enemy.get("atkT", 0.0)) - delta
	if float(enemy.atkT) > 0: return
	enemy.atkT = 1.6 if bool(enemy.get("boss", false)) else 1.2
	var base_damage := 30.0 if bool(enemy.get("boss", false)) else (16.0 if bool(enemy.get("big", false)) else 7.0)
	var hit_damage := roundi(base_damage * (1.0 + wave * 0.06) * foe_damage_multiplier())
	hurt_unit(blocker.unit, hit_damage, int(blocker.row), int(blocker.col))
	if str(blocker.unit.hero.cls) != "shield" or bool(enemy.get("dead", false)): return
	var reflect_multiplier := 2.0 if float(blocker.unit.get("reflectT", 0.0)) > 0 else 1.0
	var reflect := roundi(float(blocker.unit.hp_max) * (0.04 + float(buffs.get("shieldReflect", 0.0))) * reflect_multiplier)
	if reflect > 0: damage_enemy(enemy, reflect, "", "fan")
	if str(blocker.unit.hero.id) == "yanyan": enemy.slowT = maxf(float(enemy.get("slowT", 0.0)), 1.5)
	gain_xp(1.0)

func _shoot_enemy_arrow(enemy: Dictionary, default_target: Dictionary, damage: int, projectile_speed: float, x_spread := 0.0) -> void:
	var attacker_position := Vector2(float(enemy.x), float(enemy.y))
	var target := _enemy_taunt_target(attacker_position)
	var shot_x := float(enemy.x) + (_randf(-x_spread, x_spread) if x_spread > 0 else 0.0)
	if target.is_empty(): target = _pick(units()) if default_target.is_empty() else default_target
	enemy_projectiles.append({"x": shot_x, "y": float(enemy.y) + float(enemy.r) * 0.5, "target": target, "speed": projectile_speed, "damage": damage, "dead": false})

func _throw_enemy_lob(enemy: Dictionary, multiplier: float) -> void:
	var occupied := units()
	if occupied.is_empty(): return
	var target: Dictionary = _enemy_taunt_target(Vector2(float(enemy.x), float(enemy.y)))
	if target.is_empty(): target = _pick(occupied)
	var position := _find_unit_position(target)
	if position.is_empty(): return
	var center := slot_center(int(position.row), int(position.col))
	var base_damage := 30.0 if bool(enemy.get("boss", false)) else 16.0
	var hit_damage := roundi(base_damage * (1.0 + wave * 0.06) * foe_damage_multiplier())
	enemy_lobs.append({"x0": float(enemy.x), "y0": float(enemy.y), "x1": center.x + _randf(-14.0, 14.0), "y1": center.y + _randf(-8.0, 8.0), "t": 0.0, "dur": 1.1, "damage": maxi(1, roundi(hit_damage * multiplier)), "dead": false})

func _enemy_taunt_target(attacker_position: Vector2) -> Dictionary:
	if rng.next_float() >= 0.7: return {}
	var shields := units().filter(func(unit): return str(unit.hero.cls) == "shield")
	if shields.is_empty(): return {}
	var nearest: Dictionary = shields[0]
	var nearest_distance := INF
	for shield in shields:
		var position := _find_unit_position(shield)
		if position.is_empty(): continue
		var distance := attacker_position.distance_squared_to(slot_center(int(position.row), int(position.col)))
		if distance < nearest_distance:
			nearest = shield
			nearest_distance = distance
	return nearest

func _update_enemy_attacks(delta: float) -> void:
	for projectile in enemy_projectiles:
		if bool(projectile.get("dead", false)): continue
		var position := _find_unit_position(projectile.target)
		if position.is_empty() or float(projectile.target.get("hp", 0.0)) <= 0:
			projectile.dead = true
			continue
		var target_point := slot_center(int(position.row), int(position.col)) - Vector2(0, 10)
		var current := Vector2(float(projectile.x), float(projectile.y))
		var distance := current.distance_to(target_point)
		if distance < 14.0:
			projectile.dead = true
			hurt_unit(projectile.target, int(projectile.damage), int(position.row), int(position.col))
			continue
		var next := current.move_toward(target_point, float(projectile.speed) * delta)
		projectile.x = next.x
		projectile.y = next.y
	for index in range(enemy_projectiles.size() - 1, -1, -1):
		if bool(enemy_projectiles[index].get("dead", false)): enemy_projectiles.remove_at(index)
	for lob in enemy_lobs:
		lob.t = float(lob.t) + delta
		if float(lob.t) < float(lob.dur): continue
		lob.dead = true
		for row in GRID_ROWS:
			for col in GRID_COLS:
				var unit = grid[row][col]
				if unit == null: continue
				if slot_center(row, col).distance_squared_to(Vector2(float(lob.x1), float(lob.y1))) > 70.0 * 70.0: continue
				var damage := int(lob.damage)
				if str(unit.hero.cls) != "shield" and _shield_cover(row, col): damage = roundi(damage * (0.35 if relic_ids.has("hufu") else 0.5))
				hurt_unit(unit, damage, row, col)
	for index in range(enemy_lobs.size() - 1, -1, -1):
		if bool(enemy_lobs[index].get("dead", false)): enemy_lobs.remove_at(index)
	for lob in enemy_wall_lobs:
		var source: Dictionary = lob.get("source", {})
		if source.is_empty() or bool(source.get("dead", false)) or not enemies.has(source):
			lob.dead = true
			continue
		lob.t = float(lob.t) + delta
		if float(lob.t) < float(lob.dur): continue
		lob.dead = true
		if bool(lob.get("visual_only", false)): continue
		damage_wall(1)
	for index in range(enemy_wall_lobs.size() - 1, -1, -1):
		if bool(enemy_wall_lobs[index].get("dead", false)): enemy_wall_lobs.remove_at(index)

func _find_unit_position(target: Dictionary) -> Dictionary:
	for row in GRID_ROWS:
		for col in GRID_COLS:
			if grid[row][col] == target: return {"row": row, "col": col}
	return {}

func damage_wall(amount: int) -> int:
	var remaining := maxi(0, amount)
	if wall_shield > 0 and remaining > 0:
		var absorbed := mini(wall_shield, remaining)
		wall_shield -= absorbed
		remaining -= absorbed
	if remaining > 0:
		wall = maxi(0, wall - remaining)
		wall_hurt = true
		if wall <= 0:
			finish("over")
	return remaining

func focus_enemy(enemy: Dictionary) -> bool:
	if enemy.is_empty() or bool(enemy.get("dead", false)) or not enemies.has(enemy):
		return false
	focus_target = enemy
	focus_time = 3.0
	return true

func focus_priority_catapult() -> Dictionary:
	var catapults: Array = enemies.filter(func(enemy): return not bool(enemy.get("dead", false)) and str(enemy.get("special", "")) == "cata")
	if catapults.is_empty():
		return {}
	catapults.sort_custom(func(a, b):
		var a_winding: bool = a.has("cataWind")
		var b_winding: bool = b.has("cataWind")
		if a_winding != b_winding:
			return a_winding
		return float(a.get("lobT", 9.0)) < float(b.get("lobT", 9.0))
	)
	return catapults[0]

func _update_focus(delta: float) -> void:
	if focus_target.is_empty():
		focus_time = 0.0
		return
	focus_time = maxf(0.0, focus_time - delta)
	if focus_time <= 0.0 or bool(focus_target.get("dead", false)) or not enemies.has(focus_target):
		focus_target = {}
		focus_time = 0.0

func _focused_target_for_unit(unit: Dictionary, center: Vector2, attack_range: float) -> Dictionary:
	if focus_target.is_empty() or focus_time <= 0.0 or bool(focus_target.get("dead", false)):
		return {}
	var hero_class := str(unit.get("hero", {}).get("cls", ""))
	if ["shield", "egg", "granary", "support"].has(hero_class):
		return {}
	if hero_class == "dragon" and float(focus_target.get("y", -20.0)) < 20.0:
		return {}
	if ["cav", "dragon"].has(hero_class) or attack_range <= 0.0:
		return focus_target
	return focus_target if center.distance_squared_to(Vector2(float(focus_target.x), float(focus_target.y))) <= attack_range * attack_range else {}

func _on_enemy_death(enemy: Dictionary) -> void:
	if int(enemy.get("kitSplit", 0)) > 0:
		for index in 2:
			_spawn_child_enemy(enemy, {"hp_ratio": 0.4, "speed_mul": 1.25, "r": maxi(22, int(enemy.r) - 12), "big": true, "xp": maxf(2.0, round(float(enemy.get("xp", 0.0)) * 0.25)), "dmg": 3, "kitSplit": int(enemy.kitSplit) - 1, "x_spread": 36.0, "y_spread": 10.0})
	if str(enemy.get("special", "")) == "bomber":
		var blast_damage := roundi(14.0 + wave)
		for row in GRID_ROWS:
			for col in GRID_COLS:
				var unit = grid[row][col]
				if unit == null or slot_center(row, col).distance_squared_to(Vector2(float(enemy.x), float(enemy.y))) > 135.0 * 135.0: continue
				var damage := blast_damage
				if str(unit.hero.cls) != "shield" and _shield_cover(row, col): damage = roundi(damage * (0.35 if relic_ids.has("hufu") else 0.5))
				hurt_unit(unit, damage, row, col)
	if str(enemy.get("affix", "")) == "split":
		for index in 2:
			_spawn_child_enemy(enemy, {"hp_ratio": 0.2, "speed_mul": 1.5, "r": 13, "big": false, "xp": 1.0, "dmg": 1, "x_spread": 24.0, "y_spread": 10.0})

func _spawn_child_enemy(parent: Dictionary, options: Dictionary) -> void:
	var child_hp := maxf(1.0, round(float(parent.hp_max) * float(options.hp_ratio)))
	var x_spread := float(options.get("x_spread", 24.0))
	var child_x := clampf(float(parent.x) + _randf(-x_spread, x_spread), 16.0, 464.0)
	var child_y := maxf(-20.0, float(parent.y) - _randf(10.0, 40.0)) if bool(options.get("behind", false)) else float(parent.y) + _randf(-float(options.get("y_spread", 10.0)), float(options.get("y_spread", 10.0)))
	var child_class := str(_pick(ENEMY_CLASSES)) if bool(options.get("random_class", false)) else str(parent.get("cls", "spear"))
	var child_tri := str(parent.get("tri", "")) if bool(options.get("inherit_tri", true)) else ""
	_spawn_enemy({
		"x": child_x,
		"y": child_y,
		"hp": child_hp,
		"speed": float(parent.base_speed) * float(options.speed_mul),
		"r": int(options.r),
		"cls": child_class,
		"big": bool(options.big),
		"boss": false,
		"affix": null,
		"special": null,
		"tri": child_tri,
		"xp": float(options.xp),
		"dmg": int(options.dmg),
		"summoner": false,
		"kit": null,
		"kitSplit": int(options.get("kitSplit", 0)),
		"apply_field": false,
	})

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
		damage = roundi(damage * (0.65 if relic_ids.has("hufu") else 0.75))
	damage = maxi(1, damage)
	unit.hp = float(unit.hp) - damage
	if str(unit.hero.cls) == "shield" and float(unit.hp) > 0.0:
		unit.tanked = float(unit.get("tanked", 0.0)) + damage
		if float(unit.tanked) >= float(unit.hp_max) * 0.6:
			var counter_damage := roundi(float(unit.tanked) * 0.8)
			unit.tanked = 0.0
			var center := slot_center(row, col)
			var hit_count := 0
			for enemy in enemies.duplicate():
				if bool(enemy.get("dead", false)):
					continue
				if absf(float(enemy.get("x", 0.0)) - center.x) < CELL * 1.6 and absf(float(enemy.get("y", 0.0)) - center.y) < CELL * 1.6:
					damage_enemy_from_unit(enemy, counter_damage, "", unit)
					hit_count += 1
			if hit_count > 0:
				field_events.append({"kind": "shield_counter", "label": "蓄势反击!", "x": center.x, "y": center.y, "t": 0.55})
			else:
				unit.tanked = roundi(float(unit.hp_max) * 0.6)
	if float(unit.hp) <= 0:
		unit.hp = 0.0
		if row >= 0 and row < GRID_ROWS and col >= 0 and col < GRID_COLS and grid[row][col] == unit:
			grid[row][col] = null
			if not ["granary", "egg"].has(str(unit.hero.cls)):
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

func _shield_cover(row: int, col: int) -> bool:
	for other_row in row:
		var unit = grid[other_row][col]
		if unit != null and str(unit.hero.cls) == "shield": return true
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
		var hero: Dictionary = unit.hero
		var hero_class := str(hero.cls)
		if hero_class == "granary":
			_update_granary(unit, delta)
			continue
		if hero_class == "egg":
			unit.eggT = float(unit.get("eggT", 1.0)) - delta
			if float(unit.eggT) <= 0:
				unit.eggT += 1.0
				gain_xp((0.6 + 0.1 * mini(wave, 25)) * int(unit.level) * (1.0 + 0.02 * ruler_level))
			continue
		ult_system.update_unit(self, unit, delta)
		unit.cd = float(unit.cd) - delta
		if float(unit.cd) > 0:
			continue
		if hero_class == "dragon":
			_update_dragon(unit)
			continue
		var mods: Dictionary = team.unit_mods(self, unit)
		if hero_class == "support":
			unit.cd = maxf(0.4, team.unit_rate(unit, mods))
			_cast_ripple(unit)
			continue
		if hero_class == "shield" or float(hero.get("dmg", 0.0)) <= 0:
			unit.cd = maxf(0.4, team.unit_rate(unit, mods))
			continue
		var center := slot_center(int(unit.row), int(unit.col))
		var attack_range := effective_archer_range(hero)
		var target: Dictionary = _focused_target_for_unit(unit, center - Vector2(0, 18), attack_range)
		var front_y := -INF
		if target.is_empty():
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
				"lock_target": target if focus_target == target and focus_time > 0.0 else {},
				"hit": [],
				"dead": false,
			})
		elif hero_class == "cav":
			charges.append({
				"x": float(focus_target.x) if focus_target == target and focus_time > 0.0 else center.x,
				"y": center.y - 20.0,
				"y0": center.y - 20.0,
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
			var lock_target: Dictionary = projectile.get("lock_target", {})
			if not lock_target.is_empty() and not bool(lock_target.get("dead", false)) and enemy != lock_target:
				continue
			var hit_radius := float(projectile.r) + float(enemy.r)
			if Vector2(float(projectile.x), float(projectile.y)).distance_squared_to(Vector2(float(enemy.x), float(enemy.y))) <= hit_radius * hit_radius:
				projectile.hit.append(enemy)
				if str(projectile.get("owner", {}).get("hero", {}).get("id", "")) == "sunshangxiang" and not bool(enemy.get("boss", false)):
					enemy.kb = minf(60.0, float(enemy.get("kb", 0.0)) + 14.0)
				if bool(projectile.get("burn", false)) and str(mutations.get(wave, "")) != "rainstorm":
					enemy.burnT = maxf(float(enemy.get("burnT", 0.0)), 2.5)
					enemy.burnDmg = maxf(float(enemy.get("burnDmg", 0.0)), maxf(1.0, round(float(projectile.damage) * 0.12)) * (2.0 if str(mutations.get(wave, "")) == "eastwind" else 1.0))
					enemy.burnSrc = projectile.get("owner", enemy.get("burnSrc", "fire"))
				var projectile_damage := float(projectile.damage) * (0.25 if str(enemy.get("special", "")) == "pavise" else 1.0)
				_hit_enemy(enemy, projectile_damage, str(projectile.tri), float(projectile.crit), projectile.get("owner", {}))
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

func _update_homers(delta: float) -> void:
	for homer in homers:
		if bool(homer.get("dead", false)):
			continue
		homer.life = float(homer.life) - delta
		if float(homer.life) <= 0.0:
			homer.dead = true
			continue
		var target: Dictionary = homer.get("target", {})
		if target.is_empty() or bool(target.get("dead", false)) or not enemies.has(target):
			var living := enemies.filter(func(enemy): return not bool(enemy.get("dead", false)))
			living.sort_custom(func(a, b): return Vector2(float(homer.x), float(homer.y)).distance_squared_to(Vector2(float(a.x), float(a.y))) < Vector2(float(homer.x), float(homer.y)).distance_squared_to(Vector2(float(b.x), float(b.y))))
			if living.is_empty():
				homer.dead = true
				continue
			target = living[0]
			homer.target = target
		var position := Vector2(float(homer.x), float(homer.y))
		var target_position := Vector2(float(target.x), float(target.y))
		var distance := position.distance_to(target_position)
		if distance < 14.0:
			damage_enemy_from_unit(target, float(homer.damage), str(homer.element), homer.get("owner", {}))
			if not bool(target.get("dead", false)) and str(mutations.get(wave, "")) != "rainstorm":
				target.burnT = maxf(float(target.get("burnT", 0.0)), 2.5)
				target.burnDmg = maxf(float(target.get("burnDmg", 0.0)), maxf(2.0, round(float(homer.damage) * 0.15)))
				target.burnSrc = homer.get("owner", {})
			homer.dead = true
			continue
		var velocity := Vector2(float(homer.vx), float(homer.vy)) + position.direction_to(target_position) * 900.0 * delta
		velocity = velocity.normalized() * float(homer.speed)
		homer.vx = velocity.x
		homer.vy = velocity.y
		homer.x = position.x + velocity.x * delta
		homer.y = position.y + velocity.y * delta
	for index in range(homers.size() - 1, -1, -1):
		if bool(homers[index].get("dead", false)):
			homers.remove_at(index)

func _update_charges(delta: float) -> void:
	for charge in charges:
		if bool(charge.dead):
			continue
		charge.y = float(charge.y) + float(charge.vy) * delta
		if not charge.has("y0"): charge.y0 = float(charge.y) - float(charge.vy) * delta
		var charge_limit := float(city.get("cavChargeMul", endless_mod_value("cavChargeMul", 0.0)))
		if charge_limit > 0.0 and float(charge.vy) < 0.0 and not bool(charge.get("boulder", false)) and float(charge.y0) - float(charge.y) >= (float(charge.y0) - 30.0) * charge_limit:
			charge.dead = true
			continue
		if (float(charge.vy) < 0 and float(charge.y) < 30.0) or (float(charge.vy) > 0 and float(charge.y) > DEFENSE_LINE + 20.0):
			charge.dead = true
			continue
		for enemy in enemies.duplicate():
			if bool(enemy.get("dead", false)) or charge.hit.has(enemy):
				continue
			if absf(float(enemy.x) - float(charge.x)) < float(charge.width) + float(enemy.r) * 0.5 and absf(float(enemy.y) - float(charge.y)) < float(enemy.r) + 14.0:
				charge.hit.append(enemy)
				_hit_enemy(enemy, float(charge.damage), str(charge.tri), float(charge.crit), charge.get("owner", {}))
				var knockback_mul := float(charge.get("kb_mul", 1.0)) * (1.5 if relic_ids.has("madeng") and not bool(charge.get("boulder", false)) else 1.0)
				var push := (14.0 if bool(enemy.get("boss", false)) else (42.0 if bool(enemy.get("big", false)) or enemy.get("affix") != null else 72.0)) * knockback_mul
				enemy.kb = minf(130.0 * (1.5 if relic_ids.has("madeng") else 1.0), float(enemy.get("kb", 0.0)) + push)
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

func move_or_swap_unit(source_row: int, source_col: int, target_row: int, target_col: int) -> bool:
	if not placement_error(source_row, source_col, target_row, target_col).is_empty():
		return false
	var source = grid[source_row][source_col]
	var target = grid[target_row][target_col]
	grid[target_row][target_col] = source
	grid[source_row][source_col] = target
	source.row = target_row
	source.col = target_col
	source.bounce = 0.6
	if target != null:
		target.row = source_row
		target.col = source_col
		target.bounce = 0.6
	team.recompute(self)
	return true

func placement_error(source_row: int, source_col: int, target_row: int, target_col: int) -> String:
	if source_row < 0 or source_row >= GRID_ROWS or source_col < 0 or source_col >= GRID_COLS:
		return "invalid_source"
	if target_row < 0 or target_row >= GRID_ROWS or target_col < 0 or target_col >= GRID_COLS:
		return "invalid_target"
	if source_row == target_row and source_col == target_col:
		return "same_cell"
	var source = grid[source_row][source_col]
	if source == null:
		return "missing_source"
	var target_key := _cell_key(target_row, target_col)
	if obstacles.has(target_key) and str(source.hero.get("id", "")) != "dengai":
		return "target_obstacle"
	var target = grid[target_row][target_col]
	if target != null and obstacles.has(_cell_key(source_row, source_col)) and str(target.hero.get("id", "")) != "dengai":
		return "swap_obstacle"
	return ""

func sell_unit(row: int, col: int) -> bool:
	if row < 0 or row >= GRID_ROWS or col < 0 or col >= GRID_COLS:
		return false
	if grid[row][col] == null or units().size() <= 1:
		return false
	grid[row][col] = null
	team.recompute(self)
	return true

func _hit_enemy(enemy: Dictionary, amount: float, attacker_tri: String, critical_chance: float, source_unit: Dictionary = {}) -> int:
	var final_amount := amount
	if baihu_ready or (critical_chance > 0 and rng.next_float() < critical_chance):
		baihu_ready = false
		final_amount *= 3.0 if relic_ids.has("qinggang") else 2.0
	if relic_ids.has("guding") and (bool(enemy.get("boss", false)) or enemy.get("affix") != null):
		final_amount *= 1.25
	if not source_unit.is_empty() and str(source_unit.get("hero", {}).get("cls", "")) == "spear" and relic_ids.has("shemao") and not bool(enemy.get("boss", false)) and rng.next_float() < 0.2:
		enemy.kb = minf(130.0, float(enemy.get("kb", 0.0)) + 72.0)
	return damage_enemy(enemy, final_amount, attacker_tri, source_unit)

func damage_enemy_from_unit(enemy: Dictionary, amount: float, attacker_tri: String, source_unit: Dictionary = {}) -> int:
	return damage_enemy(enemy, amount, attacker_tri, source_unit)

func egg_hatch_bonus() -> float:
	return 0.2 if relic_ids.has("longxian") else 0.0

func egg_hatch_chance(egg: Dictionary) -> float:
	var chance := 0.6 + float(egg.get("hatchBonus", 0.0)) + egg_hatch_bonus()
	if str(traits.get(_cell_key(int(egg.row), int(egg.col)), "")) == "elem": chance += 0.1
	if float(egg.get("rbuffs", {}).get("farm", 0.0)) > 0: chance += 0.15
	if ruler_id == "liubiao": chance += 0.01 * ruler_level
	return minf(0.9, chance)

func granary_rate(unit: Dictionary) -> float:
	return (GRANARY_G0 + GRANARY_G1 * mini(wave, GRANARY_WAVE_CAP)) \
		* pow(GRANARY_STAR_MULTIPLIER, int(unit.get("level", 1)) - 1) \
		* (1.5 if float(unit.get("rbuffs", {}).get("farm", 0.0)) > 0.0 else 1.0) \
		* (1.0 + 0.03 * ruler_level if ruler_id == "caocao" else 1.0)

func granary_star_need() -> float:
	return xp_need * GRANARY_STAR_COST

func add_battle_floater(x: float, y: float, text: String, color: String, size: int) -> void:
	battle_floaters.append({"x": x, "y": y, "text": text, "color": color, "size": size, "life": 1.0})

func _update_battle_floaters(delta: float) -> void:
	for floater in battle_floaters:
		floater.y = float(floater.y) - 34.0 * delta
		floater.life = float(floater.life) - delta * 0.9
	for index in range(battle_floaters.size() - 1, -1, -1):
		if float(battle_floaters[index].life) <= 0.0:
			battle_floaters.remove_at(index)

func unlock_achievement_event(achievement_id: String) -> void:
	if known_achievement_ids.has(achievement_id) or achievement_events.has(achievement_id):
		return
	achievement_events.append(achievement_id)
	known_achievement_ids.append(achievement_id)
	var achievement: Dictionary = catalog.by_id("achievements", achievement_id)
	if not achievement.is_empty():
		add_battle_floater(240.0, 300.0, "🏆「%s」达成！%d💰待领" % [str(achievement.name), int(achievement.gold)], "#ffd24a", 21)

func granary_feed_target(row: int, col: int) -> Dictionary:
	var best: Dictionary = {}
	for near_row in range(maxi(0, row - 1), mini(GRID_ROWS - 1, row + 1) + 1):
		for near_col in range(maxi(0, col - 1), mini(GRID_COLS - 1, col + 1) + 1):
			if near_row == row and near_col == col:
				continue
			var unit = grid[near_row][near_col]
			if unit == null or int(unit.get("level", 1)) >= 15 or ["granary", "egg", "dragon"].has(str(unit.hero.cls)):
				continue
			if best.is_empty() or int(unit.level) < int(best.unit.level):
				best = {"unit": unit, "row": near_row, "col": near_col}
	return best

func _update_granary(unit: Dictionary, delta: float) -> void:
	unit.farmT = float(unit.get("farmT", 4.0)) - delta
	var target := granary_feed_target(int(unit.row), int(unit.col))
	if target.is_empty():
		if float(unit.farmT) <= 0.0:
			unit.farmT = 4.0
		return
	unit.farmAcc = float(unit.get("farmAcc", 0.0)) + granary_rate(unit) * delta
	var need := granary_star_need()
	if float(unit.farmAcc) >= need:
		unit.farmAcc = float(unit.farmAcc) - need
		var fed: Dictionary = target.unit
		fed.level = int(fed.level) + 1
		fed.bounce = 1.0
		fed.hp_max = _unit_max_hp(fed.hero, int(fed.level))
		fed.hp = fed.hp_max
		farm_stars += 1
		if farm_stars >= 5:
			unlock_achievement_event("granary40")
	if float(unit.farmT) <= 0.0:
		unit.farmT = 4.0

func dragon_damage(unit: Dictionary) -> int:
	var mods: Dictionary = team.unit_mods(self, unit)
	var fighter_levels: Array = units().filter(func(other): return not ["dragon", "egg", "granary"].has(str(other.hero.cls))).map(func(other): return int(other.level))
	var top_level := 5
	for fighter_level in fighter_levels:
		top_level = maxi(top_level, int(fighter_level))
	var phoenix := relic_ids.has("fenghuang")
	var star_ratio: float = team._star_damage_multiplier(top_level, phoenix) / team._star_damage_multiplier(5, phoenix)
	return roundi((300.0 + wave * 55.0) * (1.0 + 0.25 * (int(unit.get("dragonRank", 1)) - 1)) * maxf(1.0, star_ratio) * float(mods.dmgMul))

func _update_dragon(unit: Dictionary) -> void:
	var target: Dictionary = _focused_target_for_unit(unit, slot_center(int(unit.row), int(unit.col)), 0.0)
	var best_score := -INF
	if target.is_empty():
		for enemy in enemies:
			if bool(enemy.get("dead", false)) or float(enemy.get("y", -20.0)) < 20.0: continue
			var caster := bool(enemy.get("summoner", false)) or enemy.get("kit") != null or ["shooter", "thrower", "shaman", "healer", "banner"].has(str(enemy.get("special", "")))
			var score := float(enemy.hp_max) * (0.25 if caster and float(enemy.get("silencedT", 0.0)) > 1.0 else 1.0)
			if score > best_score:
				best_score = score
				target = enemy
	if target.is_empty():
		unit.cd = 0.4
		return
	unit.cd = 2.8
	var damage := dragon_damage(unit)
	target.silencedT = maxf(float(target.get("silencedT", 0.0)), 3.2)
	_hit_enemy(target, damage * 3.0, "", 0.0, unit)
	var center := Vector2(float(target.x), float(target.y))
	for enemy in enemies.duplicate():
		if enemy == target or bool(enemy.get("dead", false)) or center.distance_squared_to(Vector2(float(enemy.x), float(enemy.y))) > pow(130.0 + float(enemy.r), 2): continue
		_hit_enemy(enemy, damage, "", 0.0, unit)
	for enemy in enemies:
		if bool(enemy.get("dead", false)) or str(mutations.get(wave, "")) == "rainstorm": continue
		if enemy != target and center.distance_squared_to(Vector2(float(enemy.x), float(enemy.y))) > pow(130.0 + float(enemy.r), 2): continue
		enemy.burnT = maxf(float(enemy.get("burnT", 0.0)), 2.5)
		enemy.burnDmg = maxf(float(enemy.get("burnDmg", 0.0)), maxf(2.0, round(damage * 0.12)))
		enemy.burnSrc = unit
	ult_events.append({"name": "应龙吐息", "type": "dmg", "t": 0.5})

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
	if endless:
		_endless_rule_tick(wave + 1)
	next_queue = build_wave(wave + 1)
	var counts := {"spear": 0, "cav": 0, "archer": 0}
	var affixes := {}
	var specials := {}
	var boss := ""
	for spec in next_queue:
		counts[spec.cls] += 1
		if spec.get("affix") != null:
			var affix_id := str(spec.affix)
			affixes[affix_id] = int(affixes.get(affix_id, 0)) + 1
		if spec.get("special") != null:
			var special_id := str(spec.special)
			specials[special_id] = int(specials.get(special_id, 0)) + 1
		if bool(spec.get("boss", false)):
			boss = str(spec.get("bossName", ""))
	var foe_tri := _foe_tri_for_wave(wave + 1)
	next_wave_preview = {
		"counts": counts,
		"affixes": affixes,
		"specials": specials,
		"boss": boss,
		"themeElems": [foe_tri] if foe_tri else [],
		"weakElem": _counter_of(foe_tri),
		"mutation": mutations.get(wave + 1),
	}

func build_wave(number: int) -> Array:
	var queue := []
	var mutation = _mutation_for_wave(number)
	var foe_tri := _foe_tri_for_wave(number)
	var count := mini(96, 10 + int(floor(number * 3.3)))
	if mutation == "horde":
		count = mini(130, int(round(count * 1.7)))
	var hp_scale := 0.7 if mutation == "horde" else 1.0
	var raw_count := count
	if count > 72 and mutation != "horde":
		count = 72
		hp_scale *= raw_count / float(count)
	var speed_scale := 1.35 if mutation == "frenzy" else 1.0
	var endless_hp := BattleRecordsScript.endless_hp_multiplier(number, win_wave) if endless and win_wave > 0 else 1.0
	var hp := int(round(12.0 * pow(float(city.hpGrow), number - 1) * float(city.hpMul) * hp_scale * endless_hp))
	var base_speed: float = clampf(30.0 + number * 2.0, 30.0, 96.0) * float(city.spdMul) * speed_scale * endless_mod_value("spdMul")
	var base_xp := float(2 + int(floor(number / 8.0))) * 0.65 * (2.0 if mutation == "fat" else 1.0)
	for index in count:
		var enemy_class: String = _pick(ENEMY_CLASSES)
		var special = foe_behavior.roll_special(rng, number, city, mutation, endless_mod_value("rangedMul"))
		if special != null:
			var special_delay := 0.0 if index == 0 else _randf(0.3, maxf(0.35, 1.0 - number * 0.03))
			queue.append(foe_behavior.make_spec(str(special), hp, base_speed, base_xp, enemy_class, special_delay, _roll_tri(foe_tri)))
			continue
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
			"summoner": number >= 10 or ["summon", "avatar"].has(str(city.get("bossKit", ""))),
			"kit": city.get("bossKit", null) if not str(city.get("bossKit", "")).is_empty() else null,
			"kitSplit": 2 if str(city.get("bossKit", "")) == "split" else 0,
		}
		queue.append(boss_spec)
		if bool(city.get("eliteWave", false)):
			var shadow: Dictionary = boss_spec.duplicate(true)
			shadow.delay = 2.5
			shadow.hp = roundi(float(boss_spec.hp) * 0.75)
			shadow.bossName = boss_name + "·影"
			queue.append(shadow)
	return queue

func _foe_tri_for_wave(number: int) -> String:
	var source: Dictionary = endless_foes if not endless_foes.is_empty() else city.get("foes", {})
	var foe_tri := str(source.get("tri", ""))
	if mutations.get(number) == "ironhide" and not foe_tri.is_empty():
		foe_tri = str(TRI_KE[foe_tri])
	return foe_tri

func _mutation_for_wave(number: int):
	if mutations.has(number): return mutations[number]
	if number >= 18:
		mutations[number] = _pick(MUTATION_KEYS) if rng.next_float() < 0.25 else ""
		return mutations[number]
	return null

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
	var meta_level := int(hero_levels.get(str(hero.id), 1))
	var starting_stars := 1 + (1 if meta_level >= 4 else 0) + (1 if meta_level >= 10 else 0) + (1 if meta_level >= 20 else 0) + (1 if meta_level >= 30 else 0)
	var rarity := str(catalog.content.get("hero_tiers", {}).get(str(hero.id), "common"))
	if shen_ids.has(str(hero.id)):
		starting_stars += int({"common": 3, "uncommon": 2, "rare": 1, "epic": 0}.get(rarity, 0))
	starting_stars = mini(15, starting_stars + kin_gift_stars(str(hero.id)))
	var max_hp := _unit_max_hp(hero, starting_stars)
	var unit := {
		"hero": hero,
		"row": row,
		"col": col,
		"level": starting_stars,
		"hp": max_hp,
		"hp_max": max_hp,
		"cd": _randf(0.0, 0.3),
		"rbuffs": {},
		"sealedT": 0.0,
		"damage_dealt": 0.0,
		"ultCd": 0.0,
		"guardT": 0.0,
		"reflectT": 0.0,
		"tanked": 0.0,
		"ultT": 0.0,
		"auraTick": 0.0,
	}
	unit.ultCd = ult_system.initial_cooldown(self, str(hero.id))
	return unit

func kin_gift_stars(hero_id: String) -> int:
	var kin_ids: Array = catalog.content.get("lord_kin", {}).get(ruler_id, [])
	if hero_id != "jiaxu" and not kin_ids.has(hero_id):
		return 0
	var rarity := str(catalog.content.get("hero_tiers", {}).get(hero_id, "common"))
	return 2 if ["common", "uncommon"].has(rarity) else 1

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
	var hero_level_multiplier := 1.0 + (int(hero_levels.get(str(hero.id), 1)) - 1) * 0.08
	return int(round(base * (1.0 + (stars - 1) * 0.25) * shield_scale * bond_hp * hero_level_multiplier))

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
