extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	main.advance_from_title()
	main.select_city(0)
	if not _expect(main.phase == "ruler", "city entry must open ruler selection"):
		return
	if not _expect(main._ruler_rect(0) == Rect2(8, 130, 464, 75), "first ruler row must use Web v7.19.14 compact geometry"):
		return
	if not _expect(main._ruler_rect(7) == Rect2(8, 711, 464, 75), "all eight rulers must fit the 480x800 page"):
		return
	if not _expect(main.has_method("_ruler_visual_spec"), "ruler selection must expose the frozen Web visual geometry"):
		return
	var visual: Dictionary = main._ruler_visual_spec(0)
	if not _expect(visual.corner_radius == 12.0 and visual.disc_radius == 19.0 and visual.disc_center == Vector2(40.0, 167.5) and visual.text_x == 70.0, "compact ruler rows must match Web radius, portrait center, and text origin"):
		return
	if not _expect(visual.line2_start_size == 12 and visual.line2_min_size == 10 and visual.desc_start_size == 12 and visual.desc_min_size == 10, "ruler detail lines must shrink to fit instead of being character-truncated"):
		return
	if not _expect(main._name_disc_font_size("刘备", 19.0) == 15 and main._name_disc_font_size("公孙瓒", 19.0) == 12, "ruler portrait discs must keep complete names and use Web's length-based font sizes"):
		return
	for index in 7:
		if not _expect(not main._ruler_rect(index).intersects(main._ruler_rect(index + 1)), "ruler hit areas must not overlap"):
			return
	main._handle_pointer(Vector2(32, 38))
	if not _expect(main.phase == "map", "Web back button must return ruler selection to the map"):
		return
	print("Godot v7.19.14 ruler selection layout: PASS")
	quit(0)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
