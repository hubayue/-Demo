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
	run.clear_formation()
	run.obstacles.clear()
	run.traits.clear()
	run.add_unit_at("zhaoyun", 2, 2)
	run.add_unit_at("guanyu", 1, 2)
	run.wave = 3
	run.wave_timer = 2.0
	run.game_time = 20.0
	run.enemies = [{"x": 240.0, "y": 20.0, "hp": 100.0, "hp_max": 100.0, "r": 16.0, "dead": false, "tri": "", "cls": "spear"}]
	run.foe_events.clear()
	run.spawn_queue.clear()
	run.next_wave_preview.clear()
	run.damage_book = {
		"zhaoyun": {"icon": "", "name": "赵云", "total": 1200.0, "log": [[20, 500.0]]},
		"@lord": {"icon": "👑", "name": "主公", "total": 450.0, "log": [[20, 100.0]]},
		"@fire": {"icon": "🔥", "name": "火燎", "total": 180.0, "log": [[19, 60.0]]},
	}
	main.battle_field_banner_time = 0.0
	main.damage_panel_visible = true
	main.set_process(false)
	main.queue_redraw()
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != Vector2i(480, 800):
		push_error("Damage-panel capture requires a non-empty 480x800 rendered window")
		quit(1)
		return
	var path := output_directory.path_join("v7.19.14-damage-panel.png")
	var error := image.save_png(path)
	if error != OK:
		push_error("Unable to save %s: %s" % [path, error_string(error)])
		quit(1)
		return
	print("Godot v7.19.14 damage panel screenshot: PASS")
	quit(0)
