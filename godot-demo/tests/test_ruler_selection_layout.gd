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
