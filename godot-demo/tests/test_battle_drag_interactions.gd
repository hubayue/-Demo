extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const BattleRun = preload("res://src/battle/battle_run.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	main.advance_from_title()
	main.select_city(0)
	main.select_ruler("liubei")
	main.select_opening_hero("zhaoyun")
	var run = main.battle_run
	run.clear_formation()
	run.obstacles.clear()
	run.traits.clear()
	run.add_unit_at("zhaoyun", 2, 2)
	run.add_unit_at("guanyu", 2, 3)

	if not _expect(main.has_method("unit_info_popup_is_visible") and main.has_method("unit_info_popup_spec"), "clicking a unit must expose the Web unit-inspection popup model"):
		return
	_mouse_press(main, BattleRun.slot_center(2, 2))
	_mouse_release(main, BattleRun.slot_center(2, 2))
	if not _expect(main.unit_info_popup_is_visible(), "press and release without crossing 14px must inspect the unit"):
		return
	if not _expect(main._battle_overlay_layers().has("unit_info"), "unit inspection must participate in the battle overlay stack"):
		return
	var info: Dictionary = main.unit_info_popup_spec()
	if not _expect(info.get("rect", Rect2()) == Rect2(85, 290, 310, 206), "normal hero inspection must use the Web 310x206 popup geometry"):
		return
	if not _expect(str(info.get("hero_id", "")) == "zhaoyun" and str(info.get("ultimate_name", "")) == "七探盘蛇", "unit inspection must expose the selected hero and exact ultimate"):
		return
	var inspected_unit = run.grid[2][2]
	run.grid[2][2] = inspected_unit.duplicate(true)
	if not _expect(not main.unit_info_popup_is_visible(), "unit inspection must track the exact unit instance, not a value-equal replacement"):
		return
	run.grid[2][2] = inspected_unit

	run.wave_timer = 5.0
	var game_time_before := float(run.game_time)
	main.battle_field_banner_time = 4.0
	run.field_events = [{"kind": "tower", "x": 100.0, "y": 100.0, "t": 1.0}]
	run.skill_lines = [{"from": Vector2.ZERO, "to": Vector2.ONE, "t": 1.0, "t_max": 1.0, "color": "ffffff", "width": 1.0, "kind": "beam"}]
	run.ult_events = [{"name": "visual", "type": "dmg", "t": 1.0}]
	run.ripples = [{"x": 100.0, "y": 100.0, "r": 10.0, "max": 200.0, "kind": "shock"}]
	run.lord_attack_traces = [{"x1": 0.0, "y1": 0.0, "x2": 10.0, "y2": 10.0, "color": "ffffff", "t": 1.0}]
	run.lord_effect_rings = [{"x": 100.0, "y": 100.0, "radius": 10.0, "color": "ffffff", "t": 1.0}]
	run.friendly_lobs = [{"x0": 0.0, "y0": 0.0, "x1": 10.0, "y1": 10.0, "t": 0.0, "dur": 2.0, "damage": 0.0, "pit": {}, "dead": false}]
	main._process(0.25)
	if not _expect(is_equal_approx(float(run.wave_timer), 5.0), "the Web unit popup must pause battle simulation"):
		return
	if not _expect(is_equal_approx(float(main.battle_field_banner_time), 4.0), "the Web unit popup must pause the field-banner countdown with the battle"):
		return
	if not _expect(is_equal_approx(float(run.game_time), game_time_before + 0.25), "the Web unit popup must keep visual time moving while simulation is paused"):
		return
	if not _expect(is_equal_approx(float(run.field_events[0].t), 0.75) and is_equal_approx(float(run.skill_lines[0].t), 0.75) and is_equal_approx(float(run.ult_events[0].t), 0.75), "paused battle must continue fading visual events"):
		return
	if not _expect(is_equal_approx(float(run.ripples[0].r), 85.0) and is_equal_approx(float(run.friendly_lobs[0].t), 0.25), "paused battle must continue pure visual ripple and lob motion"):
		return

	_mouse_press(main, Vector2(240, 120))
	if not _expect(main.unit_info_popup_is_visible() and main.foe_lord_popup and main._battle_overlay_layers() == ["unit_info", "foe_lord"], "clicking the foe commander from unit info must preserve the paused unit layer under the foe deck"):
		return
	_mouse_press(main, Vector2(20, 400))
	if not _expect(main.unit_info_popup_is_visible() and not main.foe_lord_popup, "closing the foe deck must reveal the still-paused unit panel"):
		return
	_mouse_press(main, BattleRun.slot_center(2, 3))
	if not _expect(not main.unit_info_popup_is_visible(), "pressing another unit must close the prior popup and lift the new unit"):
		return
	main.battle_drag.cancel()

	run.permanent_tactics.gewu = true
	run.dance_time = 1.5
	_mouse_press(main, BattleRun.slot_center(2, 2))
	if not _expect(main.battle_drag.is_active(), "Web Gewu dance still allows a unit press and drag while the dance is playing"):
		return
	main.battle_drag.cancel()
	run.dance_time = 0.0
	_mouse_press(main, BattleRun.slot_center(2, 2))
	if not _expect(not main.battle_drag.is_active() and not bool(run.permanent_tactics.get("gewu", false)), "the first press after Gewu dance must wake from auto-play without starting a drag"):
		return

	_mouse_press(main, BattleRun.slot_center(2, 2))
	run.grid[2][2] = null
	main._sync_battle_drag_state()
	if not _expect(not main.battle_drag.is_active(), "a dragged unit that dies or disappears must cancel the drag"):
		return
	run.clear_formation()
	run.add_unit_at("zhaoyun", 2, 2)
	run.add_unit_at("guanyu", 2, 3)

	run.obstacles["0,0"] = true
	_mouse_drag(main, BattleRun.slot_center(2, 2), BattleRun.slot_center(0, 0))
	if not _expect(run.grid[2][2] != null and str(run.grid[2][2].hero.id) == "zhaoyun", "an invalid obstacle drop must leave the source unit in place"):
		return
	if not _expect(main.battle_interaction_notice_text() == "🪨 有石头，站不了", "an invalid obstacle drop must show the exact Web feedback"):
		return

	run.obstacles.clear()
	_mouse_press(main, BattleRun.slot_center(2, 2))
	_mouse_move(main, Vector2(240, 300))
	_mouse_release(main, Vector2(470, 700))
	if not _expect(run.units().size() == 1 and str(run.units()[0].hero.id) == "guanyu", "selling with two units must remove only the dragged unit"):
		return
	if not _expect(main.battle_interaction_notice_text() == "卖掉赵云，腾出一格", "selling must show the exact Web feedback"):
		return
	if not _expect(main.battle_interaction_notice.position == Vector2(240, 276), "sell feedback must use the last move coordinate, not an unrelated release coordinate"):
		return

	_mouse_drag(main, BattleRun.slot_center(2, 3), Vector2(240, 300))
	if not _expect(run.units().size() == 1 and main.battle_interaction_notice_text() == "最后一个武将不能卖！", "the last unit must be protected with the exact Web feedback"):
		return

	run.clear_formation()
	run.add_unit_at("zhaoyun", 2, 2)
	_touch_drag(main, BattleRun.slot_center(2, 2), BattleRun.slot_center(0, 4))
	if not _expect(run.grid[0][4] != null and str(run.grid[0][4].hero.id) == "zhaoyun", "touch drag must move units through the same placement path as mouse drag"):
		return

	print("Godot v7.19.14 battle drag interactions: PASS")
	quit(0)

func _mouse_press(main, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = true
	main._gui_input(event)

func _mouse_release(main, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = false
	main._gui_input(event)

func _mouse_drag(main, source: Vector2, target: Vector2) -> void:
	_mouse_press(main, source)
	_mouse_move(main, target)
	_mouse_release(main, target)

func _mouse_move(main, target: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = target
	main._gui_input(motion)

func _touch_drag(main, source: Vector2, target: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.position = source
	down.pressed = true
	main._gui_input(down)
	var motion := InputEventScreenDrag.new()
	motion.position = target
	main._gui_input(motion)
	var up := InputEventScreenTouch.new()
	up.position = target
	up.pressed = false
	main._gui_input(up)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
