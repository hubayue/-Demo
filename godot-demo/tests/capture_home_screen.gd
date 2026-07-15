extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const AchievementProgress = preload("res://src/progression/achievement_progress.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var output_directory := ProjectSettings.globalize_path("res://../output/godot")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var main = MainScene.instantiate()
	root.add_child(main)
	await _save(main, output_directory, "v7.19.2-home.png")
	main.home_overlay = "codex"
	main.queue_redraw()
	await _save(main, output_directory, "v7.19.2-codex.png")
	main.codex_hero_id = main.codex_page_hero_ids()[0]
	main.home_overlay = "hero"
	main.queue_redraw()
	await _save(main, output_directory, "v7.19.2-hero-detail.png")
	main.home_overlay = "lords"
	main.queue_redraw()
	await _save(main, output_directory, "v7.19.2-lord-house.png")
	main.profile.items.visitToken = 3
	main.home_overlay = "visit"
	main.queue_redraw()
	await _save(main, output_directory, "v7.19.2-visit.png")
	main.home_overlay = "bag"
	main.queue_redraw()
	await _save(main, output_directory, "v7.19.2-bag.png")
	main.profile.wins = 10
	AchievementProgress.sweep(main.profile, main.catalog.list("achievements"))
	main.home_overlay = "achievements"
	main.queue_redraw()
	await _save(main, output_directory, "v7.19.2-achievements.png")
	print("Godot home meta screenshots: PASS")
	quit(0)

func _save(main: Control, output_directory: String, filename: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != Vector2i(480, 800):
		push_error("Home capture requires a non-empty 480x800 rendered window")
		quit(1)
		return
	var error := image.save_png(output_directory.path_join(filename))
	if error != OK:
		push_error("Unable to save %s: %s" % [filename, error_string(error)])
		quit(1)
