extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const BattleCards = preload("res://src/battle/battle_cards.gd")
const LocalProfile = preload("res://src/progression/local_profile.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	main.profile = LocalProfile.defaults(main.CURRENT_WEEK)
	main.advance_from_title()
	main.select_city(0)
	main.select_ruler("liubei")
	main.select_opening_hero("zhaoyun")
	var run = main.battle_run
	run.clear_formation()
	run.obstacles.clear()
	run.add_unit_at("zhaoyun", 1, 1)
	run.add_unit_at("guanyu", 1, 2)
	var links: Dictionary = main.formation_link_spec()
	var zhao_center: Vector2 = main.BattleRunSource.slot_center(1, 1)
	var guan_center: Vector2 = main.BattleRunSource.slot_center(1, 2)
	if not _expect(links.spear.size() == 1 and links.spear[0].from == zhao_center and links.spear[0].to == guan_center, "a spear must draw one persistent aura line to each adjacent attacking ally"):
		return
	run.clear_formation()
	var granary: Dictionary = run._make_unit(BattleCards.GRANARY_TYPE, 1, 1)
	run.grid[1][1] = granary
	run.add_unit_at("zhaoyun", 1, 2)
	run.team.recompute(run)
	links = main.formation_link_spec()
	if not _expect(links.granary.size() == 1 and links.granary[0].from == zhao_center and links.granary[0].to == guan_center, "a granary must show its live lowest-star feeding target with the Web straw line"):
		return
	run.clear_formation()
	run.add_unit_at("daqiao", 1, 1)
	run.add_unit_at("xiaoqiao", 1, 2)
	run.team.recompute(run)
	links = main.formation_link_spec()
	if not _expect(links.bond.size() == 1 and links.bond[0].bond_id == "erqiao" and links.bond[0].from == zhao_center and links.bond[0].to == guan_center, "active bond members must be joined by the persistent Web gold chain"):
		return
	if not _expect(run.battle_floaters.any(func(floater): return str(floater.text).contains("羁绊「江东二乔」生效")), "a newly completed bond must emit the Web large activation floater"):
		return
	if not _expect(run.achievement_events.has("swap10") and run.battle_floaters.any(func(floater): return str(floater.text).contains("如鱼得水") and str(floater.text).contains("200")), "first bond activation must unlock and visibly announce the Web achievement"):
		return
	var floater_count: int = run.battle_floaters.size()
	run.team.recompute(run)
	if not _expect(run.battle_floaters.size() == floater_count, "recomputing an unchanged formation must not repeat bond or achievement announcements"):
		return
	run.clear_formation()
	run.add_unit_at("huatuo", 0, 0)
	run.add_unit_at("caiwenji", 0, 1)
	run.add_unit_at("huangzhong", 1, 0)
	run.add_unit_at("yanyan", 1, 1)
	if not _expect(main.active_bond_ids_in_display_order() == ["shenyi", "laojiang"], "multiple bonds must retain the Web BONDS definition order instead of alphabetic dictionary-key order"):
		return
	links = main.formation_link_spec()
	if not _expect(links.bond.size() == 2 and links.bond[0].bond_id == "shenyi" and links.bond[1].bond_id == "laojiang", "multi-bond link layers must follow the same Web definition order as the persistent chips"):
		return
	print("Godot v7.19.14 formation links: PASS")
	quit(0)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
