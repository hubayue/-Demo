extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const BattleCards = preload("res://src/battle/battle_cards.gd")

var main
var output_directory := ""

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	output_directory = ProjectSettings.globalize_path("res://../output/godot")
	DirAccess.make_dir_recursive_absolute(output_directory)
	main = MainScene.instantiate()
	root.add_child(main)
	main.advance_from_title()
	main.select_city(0)
	main.select_ruler("caocao")
	main.select_opening_hero("zhaoyun")
	var run = main.battle_run
	run.clear_formation()
	run.obstacles.clear()
	run.traits.clear()
	run.enemies.clear()
	run.spawn_queue.clear()
	run.next_wave_preview.clear()
	run.foe_events.clear()
	run.field_events.clear()
	run.wave = 10
	run.wave_timer = 2.0
	run.level = 1
	run.xp = 0.0
	run.xp_need = 20.0
	main.battle_field_banner_time = 0.0
	main.set_process(false)

	var fighter: Dictionary = run._make_unit(main.catalog.by_id("heroes", "zhaoyun"), 1, 1)
	fighter.level = 6
	fighter.hp_max = run._unit_max_hp(fighter.hero, 6)
	fighter.hp = fighter.hp_max
	run.grid[1][1] = fighter
	var granary := _put_special(BattleCards.GRANARY_TYPE, 2)
	granary.farmAcc = 9.0
	run.traits["1,2"] = "guard"
	if not await _capture("v7.19.14-granary-info.png", granary): return

	run.ruler_id = "liubiao"
	run.ruler_level = 5
	run.relic_ids = ["longxian"]
	var egg := _put_special(BattleCards.EGG_TYPE, 2)
	egg.hatchBonus = 0.2
	egg.rbuffs = {"farm": 5.0}
	run.traits["1,2"] = "elem"
	if not await _capture("v7.19.14-egg-info.png", egg): return

	var dragon := _put_special(BattleCards.DRAGON_TYPE, 1)
	dragon.dragonRank = 2
	run.dragon_count = 1
	run.traits["1,2"] = "heal"
	if not await _capture("v7.19.14-dragon-info.png", dragon): return
	print("Godot v7.19.14 special unit info screenshots: PASS")
	quit(0)

func _put_special(hero: Dictionary, level: int) -> Dictionary:
	var run = main.battle_run
	var unit: Dictionary = run._make_unit(hero.duplicate(true), 1, 2)
	unit.level = level
	unit.hp_max = run._unit_max_hp(unit.hero, level)
	unit.hp = unit.hp_max
	run.grid[1][2] = unit
	run.team.recompute(run)
	return unit

func _capture(filename: String, unit: Dictionary) -> bool:
	main.unit_info_popup = {"unit": unit, "row": 1, "col": 2}
	main.queue_redraw()
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != Vector2i(480, 800):
		push_error("Special-unit capture requires a non-empty 480x800 rendered window")
		quit(1)
		return false
	var error := image.save_png(output_directory.path_join(filename))
	if error != OK:
		push_error("Unable to save %s: %s" % [filename, error_string(error)])
		quit(1)
		return false
	return true
