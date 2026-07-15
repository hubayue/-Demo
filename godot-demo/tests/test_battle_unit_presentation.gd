extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	if not _expect(main.has_method("_unit_visual_spec"), "battle UI must expose one shared Web unit visual specification"):
		return
	if not _expect(main.has_method("_battle_render_layers"), "battle UI must expose its deterministic render order"):
		return
	var layers: Array = main._battle_render_layers()
	if not _expect(layers.find("projectiles") > layers.find("formation") and layers.find("projectiles") < layers.find("skill_fx") and layers.find("skill_fx") < layers.find("hud"), "live projectiles and skill effects must render above formation cells and below HUD"):
		return
	main.advance_from_title()
	main.select_city(0)
	main.select_ruler("liubei")
	main.select_opening_hero("zhaoyun")
	var unit: Dictionary = main.battle_run.units()[0]
	var spec: Dictionary = main._unit_visual_spec(unit)
	if not _expect(spec.body_radius == 21.0 and spec.aura_radius == 25.0 and spec.ult_radius == 30.0, "unit disc radii must match Web drawUnit"):
		return
	if not _expect(spec.aura_color == Color("ffd24a"), "Zhao Yun must use epic rarity gold for the outer aura"):
		return
	if not _expect(spec.class_icon == "🔱" and spec.class_color == Color("6fd44e") and spec.class_center == Vector2(19, -18), "spear badge must match Web geometry and color"):
		return
	if not _expect(spec.element_icon == "✋" and spec.element_color == Color("7ad86a") and spec.element_center == Vector2(-19, 18), "Rende badge must match Web geometry and color"):
		return
	if not _expect(spec.star_y == 27.0 and spec.health_rect == Rect2(-20, 31, 40, 5), "star row and conditional health bar must match Web geometry"):
		return
	if not _expect(not spec.health_visible, "full-health units must not draw a health bar"):
		return
	unit.hp = float(unit.hp_max) * 0.4
	spec = main._unit_visual_spec(unit)
	if not _expect(spec.health_visible and spec.health_color == Color("ffd24a"), "damaged units must use the Web threshold health color"):
		return
	print("Godot v7.19.14 battle unit presentation: PASS")
	quit(0)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
