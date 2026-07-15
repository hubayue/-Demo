extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	if not _expect(main.BATTLE_MUTE_RECT == Rect2(402, 102, 64, 32), "mute button geometry must match Web v7.19.14"):
		return
	if not _expect(main.BATTLE_QUIT_RECT == Rect2(402, 140, 64, 32), "quit button geometry must match Web v7.19.14"):
		return
	if not _expect(main.BATTLE_DMG_RECT == Rect2(402, 456, 64, 30), "damage button geometry must match Web v7.19.14"):
		return
	main.advance_from_title()
	main.select_city(0)
	main.select_ruler("liubei")
	main.select_opening_hero("zhaoyun")
	var muted_before: bool = main.sound_enabled
	main._handle_pointer(main.BATTLE_MUTE_RECT.get_center())
	if not _expect(main.sound_enabled != muted_before, "mute button must toggle local sound state"):
		return
	main._handle_pointer(main.BATTLE_DMG_RECT.get_center())
	if not _expect(main.damage_panel_visible, "damage button must toggle output panel state"):
		return
	main._handle_pointer(main.BATTLE_QUIT_RECT.get_center())
	if not _expect(main.quit_armed, "first quit click must arm confirmation"):
		return
	main._handle_pointer(main.BATTLE_QUIT_RECT.get_center())
	if not _expect(main.phase == "map" and main.battle_run == null, "second quit click must return to the map"):
		return
	print("Godot v7.19.14 battle HUD controls: PASS")
	quit(0)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
