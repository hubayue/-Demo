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
	var bonus_multiplier := 1.3 if str(run.city.get("theme", "")) == "tuanjie" else 1.0
	if not is_equal_approx(bonus_multiplier, 1.0):
		result.dmg = 1.0 + (float(result.dmg) - 1.0) * bonus_multiplier
		result.rate = 1.0 + (float(result.rate) - 1.0) * bonus_multiplier
		result.hp = 1.0 + (float(result.hp) - 1.0) * bonus_multiplier
		result.rippleRad = float(result.rippleRad) * bonus_multiplier
	return result

func _reset() -> void:
	counts = {}
	for key in CLASS_KEYS:
		counts[key] = 0
	active_bonds = {}
