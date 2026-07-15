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
	main.home_overlay = "lords"
	for page in 2:
		main.lord_page = page
		main.queue_redraw()
		await process_frame
		await process_frame
		var image := root.get_viewport().get_texture().get_image()
		if image == null or image.is_empty() or image.get_size() != Vector2i(480, 800):
			push_error("Lord House capture requires a non-empty 480x800 rendered window")
			quit(1)
			return
		var path := output_directory.path_join("v7.19.14-lord-house-page%d.png" % (page + 1))
		var error := image.save_png(path)
		if error != OK:
			push_error("Unable to save %s: %s" % [path, error_string(error)])
			quit(1)
			return
	print("Godot v7.19.14 Lord House screenshots: PASS")
	quit(0)
