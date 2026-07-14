class_name OpeningPicker
extends RefCounted

const TRI_KE := {"badao": "liangmou", "liangmou": "rende", "rende": "badao"}
const NON_DPS_CLASSES := ["shield", "support"]
const ELEM_COSMETIC := {
	"huatuo": true,
	"xiaoqiao": true,
	"lusu": true,
	"daqiao": true,
	"xuhuang": true,
	"caiwenji": true,
	"simayi": true,
	"xushu": true,
	"caohong": true,
	"granary": true,
	"dragonegg": true,
	"yinglong": true,
}

var rng: RandomNumberGenerator

func _init(random_source: RandomNumberGenerator = null) -> void:
	if random_source == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	else:
		rng = random_source

func pick_ids(heroes: Array, ruler_id: String, foe_tri: String, lord_kin: Dictionary) -> Array:
	var scores := []
	for ignored in heroes:
		scores.append(rng.randf())
	return pick_ids_with_scores(heroes, ruler_id, foe_tri, lord_kin, scores)

func pick_ids_with_scores(heroes: Array, ruler_id: String, foe_tri: String, lord_kin: Dictionary, scores: Array) -> Array:
	var ranked := []
	for index in heroes.size():
		var hero: Dictionary = heroes[index]
		ranked.append({
			"hero": hero,
			"order": index,
			"score": float(scores[index]) + _bias(hero, ruler_id, foe_tri, lord_kin),
		})
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if left.score == right.score:
			return left.order < right.order
		return left.score > right.score
	)
	var choices := []
	var non_dps := 0
	for entry in ranked:
		var hero: Dictionary = entry.hero
		if NON_DPS_CLASSES.has(str(hero.cls)):
			if non_dps >= 1:
				continue
			non_dps += 1
		choices.append(str(hero.id))
		if choices.size() >= 3:
			break
	return choices

static func is_kin(hero_id: String, ruler_id: String, lord_kin: Dictionary) -> bool:
	if hero_id == "jiaxu":
		return true
	var ruler_kin = lord_kin.get(ruler_id, [])
	return ruler_kin is Array and ruler_kin.has(hero_id)

static func _bias(hero: Dictionary, ruler_id: String, foe_tri: String, lord_kin: Dictionary) -> float:
	var bias := 0.0
	var hero_id := str(hero.id)
	var hero_tri := str(hero.get("elem", ""))
	if foe_tri and not ELEM_COSMETIC.has(hero_id):
		if TRI_KE.get(hero_tri, "") == foe_tri:
			bias += 0.15
		elif TRI_KE.get(foe_tri, "") == hero_tri:
			bias -= 0.12
	if is_kin(hero_id, ruler_id, lord_kin):
		bias += 0.18
	return bias
