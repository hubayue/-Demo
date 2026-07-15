extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const LocalProfile = preload("res://src/progression/local_profile.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var output_directory := ProjectSettings.globalize_path("res://../output/godot")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var main = MainScene.instantiate()
	root.add_child(main)
	main.profile = LocalProfile.defaults(main.CURRENT_WEEK)
	main.advance_from_title()
	main.select_city(0)
	main.select_ruler("liubei")
	main.select_opening_hero("zhaoyun")
	var run = main.battle_run
	run.shen_period = 0
	run.shen_ids = []
	run.clear_formation()
	run.obstacles = {"0,0": true, "0,4": true, "2,0": true, "2,4": true}
	run.traits.clear()
	for row in 3:
		for column in 5:
			run.traits["%d,%d" % [row, column]] = "haste"
	run.add_unit_at("zhaoyun", 2, 2)
	run.add_unit_at("zhangfei", 1, 2)
	run.enemies = []
	run.foe_events = []
	run.spawn_queue = []
	run.wave = 1
	run.speed = 0
	var wanted := ["关羽出征", "张飞练兵", "全军猛攻"]
	var choices: Array = []
	for title in wanted:
		for card in run.card_system.build_pool(run):
			if str(card.title) == title:
				choices.append(card)
				break
	if choices.size() != 3:
		push_error("Growth-card capture could not build the three Web parity cards")
		quit(1)
		return
	run.card_choices = choices
	run.awaiting_card_choice = true
	main.growth_card_anim = 1.0
	main.growth_card_age = 1.0
	main.growth_card_signature = "capture"
	main.battle_field_banner_time = 0.0
	main.set_process(false)
	main.queue_redraw()
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != Vector2i(480, 800):
		push_error("Growth-card capture requires a non-empty 480x800 rendered window")
		quit(1)
		return
	var path := output_directory.path_join("v7.19.14-growth-cards.png")
	var error := image.save_png(path)
	if error != OK:
		push_error("Unable to save %s: %s" % [path, error_string(error)])
		quit(1)
		return
	run.card_choices = []
	run.awaiting_card_choice = false
	run.dance_time = 1.5
	run.game_time = 5.0
	main.queue_redraw()
	await process_frame
	await process_frame
	var dance_image := root.get_viewport().get_texture().get_image()
	var dance_path := output_directory.path_join("v7.19.14-gewu-dance.png")
	var dance_error := dance_image.save_png(dance_path)
	if dance_error != OK:
		push_error("Unable to save %s: %s" % [dance_path, error_string(dance_error)])
		quit(1)
		return
	print("Godot v7.19.14 growth-card screenshot: PASS")
	quit(0)
