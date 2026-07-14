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
	await process_frame
	await process_frame
	var map_image := root.get_viewport().get_texture().get_image()
	if not _capture_is_valid(map_image):
		push_error("Map capture requires a non-empty 480x800 rendered window; do not use --headless")
		quit(1)
		return
	var map_error := map_image.save_png(output_directory.path_join("v7.19.2-week-map.png"))
	if map_error != OK:
		push_error("Unable to capture weekly map: %s" % error_string(map_error))
		quit(1)
		return
	main.open_city(0)
	await process_frame
	await process_frame
	var popup_image := root.get_viewport().get_texture().get_image()
	if not _capture_is_valid(popup_image):
		push_error("City popup capture requires a non-empty 480x800 rendered window; do not use --headless")
		quit(1)
		return
	var popup_error := popup_image.save_png(output_directory.path_join("v7.19.2-city-popup.png"))
	if popup_error != OK:
		push_error("Unable to capture city popup: %s" % error_string(popup_error))
		quit(1)
		return
	print("Godot weekly map screenshots: PASS")
	quit(0)

func _capture_is_valid(image: Image) -> bool:
	return image != null and not image.is_empty() and image.get_size() == Vector2i(480, 800)
