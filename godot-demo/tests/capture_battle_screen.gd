extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var output_directory := ProjectSettings.globalize_path("res://../output/godot")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var main = MainScene.instantiate()
	root.add_child(main)
	main.advance_from_title()
	main.select_city(0)
	main.select_ruler("caocao")
	main.select_opening_hero("zhangfei")
	await create_timer(4.5).timeout
	await process_frame
	await process_frame
	if not _save_capture(output_directory.path_join("v7.19.2-battle-foundation.png")):
		return
	var run = main.battle_run
	run.gain_xp(maxf(0.0, run.xp_need - run.xp))
	await process_frame
	await process_frame
	if not _save_capture(output_directory.path_join("v7.19.2-first-growth-draft.png")):
		return
	run.choose_card(0)
	run.clear_formation()
	run.obstacles.clear()
	run.add_unit_at("huangzhong", 0, 0)
	run.add_unit_at("yanyan", 2, 4)
	main.set_process(false)
	main.queue_redraw()
	await process_frame
	await process_frame
	if not _save_capture(output_directory.path_join("v7.19.2-active-bond.png")):
		return
	print("Godot battle screenshots: PASS")
	quit(0)

func _save_capture(path: String) -> bool:
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != Vector2i(480, 800):
		push_error("Battle capture requires a non-empty 480x800 rendered window; do not use --headless")
		quit(1)
		return false
	var error := image.save_png(path)
	if error != OK:
		push_error("Unable to save battle capture: %s" % error_string(error))
		quit(1)
		return false
	return true
