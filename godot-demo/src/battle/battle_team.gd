class_name BattleTeam
extends RefCounted

const CLASS_KEYS := ["spear", "cav", "archer", "shield", "support", "granary", "egg", "dragon"]

var catalog
var counts: Dictionary = {}
var active_bonds: Dictionary = {}

func _init(content_catalog) -> void:
	catalog = content_catalog
	_reset()

func recompute(run) -> void:
	_reset()
	var owned := {}
	for unit in run.units():
		var hero_class := str(unit.hero.get("cls", ""))
		if not counts.has(hero_class):
			counts[hero_class] = 0
		counts[hero_class] += 1
		owned[str(unit.hero.id)] = true
	for bond in catalog.list("bonds"):
		var complete := true
		for hero_id in bond.members:
			if not owned.has(str(hero_id)):
				complete = false
				break
		if complete:
			active_bonds[str(bond.id)] = true

func active_bond_ids() -> Array:
	var result: Array = active_bonds.keys()
	result.sort()
	return result

func bond_fx(run, hero_id: String) -> Dictionary:
	var result := {"dmg": 1.0, "rate": 1.0, "hp": 1.0, "rippleRad": 0.0}
	for bond in catalog.list("bonds"):
		if not active_bonds.has(str(bond.id)) or not bond.members.has(hero_id):
			continue
		var effects: Dictionary = bond.fx
		result.dmg *= float(effects.get("dmg", 1.0))
		result.rate *= float(effects.get("rate", 1.0))
		result.hp *= float(effects.get("hp", 1.0))
		result.rippleRad += float(effects.get("rippleRad", 0.0))
	var bonus_multiplier := 1.0
	if run.relic_ids.has("jinlan"):
		bonus_multiplier *= 1.5
	if str(run.city.get("theme", "")) == "tuanjie":
		bonus_multiplier *= 1.3
	if not is_equal_approx(bonus_multiplier, 1.0):
		result.dmg = 1.0 + (float(result.dmg) - 1.0) * bonus_multiplier
		result.rate = 1.0 + (float(result.rate) - 1.0) * bonus_multiplier
		result.hp = 1.0 + (float(result.hp) - 1.0) * bonus_multiplier
		result.rippleRad = float(result.rippleRad) * bonus_multiplier
	return result

func unit_mods(run, unit: Dictionary) -> Dictionary:
	var buffs: Dictionary = run.buffs
	var hero: Dictionary = unit.hero
	var hero_class := str(hero.cls)
	var damage_multiplier := float(buffs.dmg) * (1.0 + float(run.tyranny) / 100.0)
	if not run.army_buff.is_empty():
		damage_multiplier *= float(run.army_buff.get("mul", 1.0))
	if bool(run.permanent_tactics.get("gewu", false)):
		damage_multiplier *= 1.3
	if float(run.foe_curse_time) > 0:
		damage_multiplier *= 0.75
	var rate_multiplier := float(buffs.rate)
	if not run.army_haste.is_empty() and hero_class != "shield":
		rate_multiplier *= float(run.army_haste.get("mul", 1.0))
	var critical_chance := float(buffs.critCh)
	var pierce_add := 0
	damage_multiplier *= 1.0 + float(buffs.elemBoost.get(str(hero.elem), 0.0))
	if hero_class == "spear":
		damage_multiplier *= 1.65
	elif hero_class == "cav":
		damage_multiplier *= 1.15 * (1.0 + float(buffs.cavDmg))
	elif hero_class == "archer":
		damage_multiplier *= 1.0 + float(buffs.archerDmg)
	var effects := bond_fx(run, str(hero.id))
	damage_multiplier *= float(effects.dmg)
	rate_multiplier *= float(effects.rate)
	if run.relic_ids.has("dilu") and hero_class == "cav":
		damage_multiplier *= 1.3
	if run.relic_ids.has("bagua"):
		rate_multiplier *= 1.1
	var field: Dictionary = catalog.by_id("fields", str(run.city.get("field", "")))
	if hero_class == "cav":
		damage_multiplier *= float(field.get("cavMul", 1.0))
	elif hero_class == "archer":
		damage_multiplier *= float(field.get("archerMul", 1.0))
	var row := int(unit.row)
	var col := int(unit.col)
	if str(hero.id) == "dengai" and run.obstacles.has("%d,%d" % [row, col]):
		damage_multiplier *= 1.4
	var cell_trait := str(run.traits.get("%d,%d" % [row, col], ""))
	if cell_trait == "atk":
		damage_multiplier *= 1.15
	elif cell_trait == "haste":
		rate_multiplier *= 1.12
	elif cell_trait == "crit":
		critical_chance += 0.10
	var adjacent_spears := 0
	for near_row in range(maxi(0, row - 1), mini(run.GRID_ROWS - 1, row + 1) + 1):
		for near_col in range(maxi(0, col - 1), mini(run.GRID_COLS - 1, col + 1) + 1):
			if near_row == row and near_col == col:
				continue
			var neighbour = run.grid[near_row][near_col]
			if neighbour != null and str(neighbour.hero.cls) == "spear":
				adjacent_spears += 1
	if adjacent_spears > 0:
		damage_multiplier *= 1.0 + mini(3, adjacent_spears) * (0.10 + float(buffs.spearAura))
	var class_count := int(counts.get(hero_class, 0))
	if hero_class == "spear":
		if class_count >= 2:
			damage_multiplier *= 1.25
		if class_count >= 4:
			damage_multiplier *= 1.25
	elif hero_class == "archer":
		if class_count >= 2:
			rate_multiplier *= 1.2
		if class_count >= 4:
			rate_multiplier *= 1.2
	elif hero_class == "cav":
		if class_count >= 2:
			pierce_add += 1
		if class_count >= 4:
			damage_multiplier *= 1.4
	elif hero_class == "support":
		if class_count >= 2:
			rate_multiplier *= 1.15
		if class_count >= 4:
			rate_multiplier *= 1.15
	if run.relic_ids.has("liannu"):
		pierce_add += 1
	var ripple_buffs: Dictionary = unit.get("rbuffs", {})
	if float(ripple_buffs.get("dmg", 0.0)) > 0:
		damage_multiplier *= 1.25
	if float(ripple_buffs.get("haste", 0.0)) > 0:
		rate_multiplier *= 1.22
	if float(ripple_buffs.get("crit", 0.0)) > 0:
		critical_chance += 0.15
	return {
		"dmgMul": damage_multiplier,
		"rateMul": rate_multiplier,
		"crit": critical_chance,
		"pierceAdd": pierce_add,
	}

func unit_damage(_run, unit: Dictionary, mods: Dictionary) -> int:
	return roundi(float(unit.hero.get("dmg", 0.0)) * _star_damage_multiplier(int(unit.level)) * float(mods.dmgMul))

func unit_rate(unit: Dictionary, mods: Dictionary) -> float:
	return float(unit.hero.get("rate", 99.0)) * pow(0.93, int(unit.level) - 1) / float(mods.rateMul)

func ripple_max(run, unit: Dictionary) -> float:
	var base := 230.0 if str(unit.hero.get("ripple", "")) == "slow" else 130.0
	return base + float(run.buffs.rippleRad) + float(bond_fx(run, str(unit.hero.id)).rippleRad)

static func _star_damage_multiplier(stars: int) -> float:
	return pow(1.9, mini(stars, 5) - 1) * pow(1.4, maxi(0, mini(stars, 10) - 5)) * pow(1.3, maxi(0, stars - 10))

func _reset() -> void:
	counts = {}
	for key in CLASS_KEYS:
		counts[key] = 0
	active_bonds = {}
