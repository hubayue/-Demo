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
	if not _expect(main._battle_backdrop_color_at(0.0) == Color("2a2012") and main._battle_backdrop_color_at(400.0) == Color("3a2c18") and main._battle_backdrop_color_at(496.0) == Color("44341e") and main._battle_backdrop_color_at(800.0) == Color("2a2012"), "battle backdrop must retain all four Web gradient stops through the formation area"):
		return
	if not _expect(main._battle_wall_color_at(744.0) == Color("5a4832") and main._battle_wall_color_at(800.0) == Color("3a2e1e"), "city wall must retain the exact Web top and bottom gradient colors"):
		return
	var layers: Array = main._battle_render_layers()
	if not _expect(layers.find("projectiles") > layers.find("formation") and layers.find("projectiles") < layers.find("skill_fx") and layers.find("skill_fx") < layers.find("hud"), "live projectiles and skill effects must render above formation cells and below HUD"):
		return
	if not _expect(layers.find("field_banner") > layers.find("growth_cards") and layers.find("field_banner") > layers.find("foe_popup") and layers.find("field_banner") > layers.find("cata_bar"), "field banner must render above every Web battle overlay whose input it intercepts"):
		return
	main.advance_from_title()
	main.select_city(0)
	main.select_ruler("liubei")
	main.select_opening_hero("zhaoyun")
	var unit: Dictionary = main.battle_run.units()[0]
	var spec: Dictionary = main._unit_visual_spec(unit)
	if not _expect(spec.get("name_text", "") == "赵云" and int(spec.get("name_font_size", 0)) == 16 and spec.get("name_color", Color.TRANSPARENT) == Color("ffe8b0"), "unit disc must render the complete Web name with the two-character radius-21 font mapping"):
		return
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
