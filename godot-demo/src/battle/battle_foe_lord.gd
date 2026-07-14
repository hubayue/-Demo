class_name BattleFoeLord
extends RefCounted

const SUMMON_STATS := {
	"runner": [0.5, 2.2, 14, 1],
	"shaman": [1.8, 0.75, 21, 2],
	"ram": [6.0, 0.5, 27, 4],
	"assassin": [1.4, 1.6, 16, 2],
	"bomber": [0.9, 1.1, 18, 2],
}

func setup(run) -> void:
	run.foe_lord = {}
	run.foe_events = []
	if not run.city.has("week"):
		return
	var lords: Array = run.catalog.list("foe_lords")
	if lords.is_empty():
		return
	var seat := posmod(int(run.city.get("week", 0)) * 31 + int(run.city.get("k", 0)) * 7, lords.size())
	var definition: Dictionary = lords[seat]
	run.foe_lord = {
		"def": definition,
		"deck": _shuffle(run, definition.get("deck", [])),
		"idx": 0,
		"drawT": 30.0,
		"told": false,
	}
	run.foe_events.append({"kind": "establish", "text": "%s·%s坐镇" % [definition.name, definition.title], "t": 2.5})

func update(run, delta: float) -> void:
	run.foe_curse_time = maxf(0.0, run.foe_curse_time - delta)
	run.foe_rage_time = maxf(0.0, run.foe_rage_time - delta)
	for event in run.foe_events:
		event.t = float(event.t) - delta
	for index in range(run.foe_events.size() - 1, -1, -1):
		if float(run.foe_events[index].t) <= 0:
			run.foe_events.remove_at(index)
	if run.foe_lord.is_empty() or run.status != "play" or run.wave < 8:
		return
	var state: Dictionary = run.foe_lord
	state.drawT = float(state.drawT) - delta
	if not bool(state.told) and float(state.drawT) <= 30.0:
		state.told = true
		var card_id := next_card_id(run)
		var card: Dictionary = run.catalog.content.get("foe_cards", {}).get(card_id, {})
		run.foe_events.append({"kind": "preview", "card_id": card_id, "text": "亮出「%s」" % card.get("name", card_id), "tip": str(card.get("tip", "")), "t": 2.5})
	if float(state.drawT) > 0:
		return
	state.drawT = 100.0
	state.told = false
	var card_id := next_card_id(run)
	cast_card(run, card_id)
	state.idx = int(state.idx) + 1
	if int(state.idx) >= state.deck.size():
		state.deck = _shuffle(run, state.def.get("deck", []))
		state.idx = 0

func next_card_id(run) -> String:
	if run.foe_lord.is_empty() or run.foe_lord.deck.is_empty():
		return ""
	return str(run.foe_lord.deck[mini(int(run.foe_lord.idx), run.foe_lord.deck.size() - 1)])

func cast_card(run, card_id: String) -> void:
	if card_id.is_empty():
		return
	var definition: Dictionary = run.foe_lord.get("def", {})
	var card: Dictionary = run.catalog.content.get("foe_cards", {}).get(card_id, {})
	if card_id == "taunt":
		var taunts: Array = definition.get("taunts", [])
		var line := "口嗨"
		if not taunts.is_empty():
			line = str(taunts[int(floor(run.rng.next_float() * taunts.size()))])
		run.foe_events.append({"kind": "cast", "card_id": card_id, "text": line, "tip": "", "t": 2.2})
		return
	run.foe_events.append({"kind": "cast", "card_id": card_id, "text": "「%s」" % card.get("name", card_id), "tip": str(card.get("tip", "")), "t": 2.2})
	match card_id:
		"rage":
			run.foe_rage_time = 12.0
		"shieldup":
			for enemy in _living_enemies(run):
				var shield := roundi(float(enemy.hp_max) * 0.18)
				enemy.shield = maxf(float(enemy.get("shield", 0.0)), shield)
				enemy.shieldMax = maxf(float(enemy.get("shieldMax", 0.0)), float(enemy.shield))
		"heal":
			for enemy in _living_enemies(run):
				enemy.hp = minf(float(enemy.hp_max), float(enemy.hp) + roundi(float(enemy.hp_max) * 0.25))
		"curse":
			run.foe_curse_time = 10.0
		"sealone":
			_seal_unit(_top_damage_unit(run), 6.0)
		"sealrow":
			var row := int(floor(run.rng.next_float() * run.GRID_ROWS))
			for col in run.GRID_COLS:
				var unit = run.grid[row][col]
				if unit != null and not ["egg", "granary"].has(str(unit.hero.cls)):
					_seal_unit(unit, 3.5)
		"firerain":
			var candidates := _fighters(run)
			_shuffle_in_place(run, candidates)
			for index in mini(3, candidates.size()):
				_hit_unit_nonlethal(candidates[index], 0.3)
		"snipe":
			_hit_unit_nonlethal(_top_damage_unit(run), 0.45)
		"ramwall":
			run.wall = maxi(0, run.wall - 3)
		"dispel":
			run.army_buff = {}
			run.wuxing_time = 0.0
		"drop":
			_summon(run, "assassin", 2, true)
		"reinforce":
			_summon(run, "runner", 3, false)
		"ramcall":
			_summon(run, "ram", 2, false)
		"shaman2":
			_summon(run, "shaman", 2, false)

func _hit_unit_nonlethal(unit: Dictionary, fraction: float) -> void:
	if unit.is_empty():
		return
	var cut := maxi(1, roundi(float(unit.hp) * fraction))
	unit.hp = maxf(1.0, float(unit.hp) - cut)

func _seal_unit(unit: Dictionary, duration: float) -> void:
	if unit.is_empty():
		return
	unit.sealedT = maxf(float(unit.get("sealedT", 0.0)), duration)

func _top_damage_unit(run) -> Dictionary:
	var best: Dictionary = {}
	var best_total := -1.0
	for unit in _fighters(run):
		var total := float(unit.get("damage_dealt", 0.0))
		if total > best_total:
			best_total = total
			best = unit
	return best

func _fighters(run) -> Array:
	return run.units().filter(func(unit): return not ["egg", "granary"].has(str(unit.hero.cls)))

func _summon(run, special: String, count: int, middle: bool) -> void:
	var wave_specs: Array = run.build_wave(maxi(1, run.wave))
	var base: Dictionary = {}
	for spec in wave_specs:
		if spec.get("special") == null and not bool(spec.get("big", false)):
			base = spec
			break
	if base.is_empty() and not wave_specs.is_empty():
		base = wave_specs[0]
	if base.is_empty():
		return
	var stats: Array = SUMMON_STATS[special]
	for index in count:
		var spec := base.duplicate(true)
		spec.hp = roundi(float(base.hp) * float(stats[0]))
		spec.speed = float(base.speed) * float(stats[1])
		spec.r = int(stats[2])
		spec.dmg = int(stats[3])
		spec.special = special
		spec.xp = float(base.xp)
		if middle:
			spec.x = 60.0 + run.rng.next_float() * 360.0
			spec.y = 250.0 + run.rng.next_float() * 90.0
		else:
			spec.x = null
			spec.y = null
		run._spawn_enemy(spec)

func _living_enemies(run) -> Array:
	return run.enemies.filter(func(enemy): return not bool(enemy.get("dead", false)))

func _shuffle(run, source) -> Array:
	var result: Array = Array(source).duplicate()
	_shuffle_in_place(run, result)
	return result

func _shuffle_in_place(run, values: Array) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other := int(floor(run.rng.next_float() * (index + 1)))
		var temporary = values[index]
		values[index] = values[other]
		values[other] = temporary
