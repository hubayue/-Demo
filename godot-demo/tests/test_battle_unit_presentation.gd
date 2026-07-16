extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const BattleCards = preload("res://src/battle/battle_cards.gd")

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
	main.battle_run.clear_formation()
	main.battle_run.obstacles.clear()
	main.profile.heroes["zhaoyun"].rb = 2
	main.battle_run.shen_ids = ["zhaoyun"]
	main.battle_run.add_unit_at("yanyan", 0, 0)
	main.battle_run.add_unit_at("zhaoyun", 1, 1)
	unit = main.battle_run.grid[1][1]
	unit.level = 4
	unit.rbuffs = {"heal": 4.0, "haste": 4.0, "dmg": 4.0, "crit": 4.0, "cdr": 4.0, "farm": 4.0}
	unit.reflectT = 3.0
	unit.sealedT = 3.0
	main.battle_run.taoyuan_time = 3.0
	main.battle_run.army_buff = {"t": 3.0, "mul": 1.3}
	main.battle_run.army_haste = {"t": 3.0, "mul": 1.4}
	main.battle_run.next_wave_preview = {"themeElems": ["liangmou"]}
	spec = main._unit_visual_spec(unit)
	if not _expect(main._active_lord_effect_text().is_empty() and main.has_method("taoyuan_overlay_spec"), "Taoyuan must use only the Web full-screen gold overlay instead of adding a second centered status banner"):
		return
	var taoyuan_overlay: Dictionary = main.taoyuan_overlay_spec()
	if not _expect(taoyuan_overlay.rect == Rect2(5, 5, 470, 790) and taoyuan_overlay.border_width == 10.0 and taoyuan_overlay.baseline == 236.0 and taoyuan_overlay.font_size == 21 and str(taoyuan_overlay.text).begins_with("🍑 桃园金身"), "Taoyuan overlay geometry, text and baseline must match the frozen Web full-screen treatment"):
		return
	main.battle_run.status = "win"
	if not _expect(not bool(main._unit_visual_spec(unit).get("resistance_hint_visible", true)) and main.taoyuan_overlay_spec().is_empty(), "next-wave resistance and Taoyuan overlays must disappear outside the Web play phase"):
		return
	main.battle_run.status = "play"
	if not _expect(bool(spec.get("shen_badge_visible", false)) and spec.get("shen_badge_position", Vector2.ZERO) == Vector2(-22, -18), "this-period Shen heroes must keep the Web angel badge at the upper-left of the disc"):
		return
	if not _expect(bool(spec.get("taoyuan_ring_visible", false)) and float(spec.get("taoyuan_ring_radius", 0.0)) == 30.0, "Taoyuan immunity must draw the Web gold protection ring around every eligible unit"):
		return
	if not _expect(bool(spec.get("resistance_hint_visible", false)) and float(spec.get("resistance_hint_radius", 0.0)) == 28.0 and str(spec.get("resistance_hint_label", "")) == "打不动" and spec.get("resistance_hint_label_position", Vector2.ZERO) == Vector2(22, -20), "a next wave that counters the unit must show the Web dashed red ring and label"):
		return
	if not _expect(spec.get("buff_icons", []) == ["💗", "⚡", "⚔️", "🎯", "🕐", "🌾", "🌾", "🌬️"] and float(spec.get("buff_icons_y", 0.0)) == -33.0, "ripple and army buffs must preserve the exact Web icon order on the shared top row"):
		return
	if not _expect(bool(spec.get("reflect_active", false)) and float(spec.get("reflect_inner_radius", 0.0)) == 24.0 and float(spec.get("reflect_outer_radius", 0.0)) == 31.0, "Zhou Tai-style reflect must expose the rotating eight-spike Web ring geometry"):
		return
	if not _expect(bool(spec.get("adjacent_shield", false)) and spec.get("shield_protect_position", Vector2.ZERO) == Vector2(-21, -28) and bool(spec.get("sealed", false)), "adjacent shield protection and sealing must remain simultaneously visible"):
		return
	var visual_method: Dictionary = main.get_method_list().filter(func(method): return str(method.name) == "_unit_visual_spec")[0]
	if not _expect(visual_method.args.size() == 3, "unit presentation must accept an explicit draw position so dragged cards do not inherit grid-only hints"):
		return
	var dragged_spec: Dictionary = main._unit_visual_spec(unit, -1, -1)
	if not _expect(not bool(dragged_spec.adjacent_shield) and not bool(dragged_spec.resistance_hint_visible), "a dragged Web unit must hide adjacent-shield and next-wave grid hints until it is placed"):
		return
	if not _expect(int(spec.get("rebirth", 0)) == 2 and str(spec.get("rebirth_label", "")) == " 2转" and spec.get("rebirth_color", Color.TRANSPARENT) == Color("c96aff") and spec.get("star_colors", []) == [Color("c96aff"), Color("c96aff"), Color("c96aff"), Color("c96aff")], "reborn heroes must recolor ordinary stars and append the Web N-turn label"):
		return
	unit.level = 12
	spec = main._unit_visual_spec(unit)
	if not _expect(spec.get("star_colors", []) == [Color("3a9aff"), Color("3a9aff"), Color("ff7a3a"), Color("ff7a3a"), Color("ff7a3a")], "eleven-to-fifteen-star units must use the Web blue second-ascension then orange first-ascension sequence"):
		return
	var shield_spec: Dictionary = main._unit_visual_spec(main.battle_run.grid[0][0])
	if not _expect(bool(shield_spec.get("shield_skin_visible", false)) and shield_spec.get("shield_top", Vector2.ZERO) == Vector2(0, -31) and shield_spec.get("shield_heart_center", Vector2.ZERO) == Vector2(0, -17), "shield units must expose the Web tower-shield silhouette and element-colored heart anchor"):
		return
	if not _expect(main.has_method("_shield_skin_spec") and main.has_method("_unit_star_row_spec") and main.has_method("_draw_reflect_spikes"), "battle rendering must expose focused helpers for the Web tower shield, ascension star row, and reflect spikes"):
		return
	var shield_skin: Dictionary = main._shield_skin_spec(shield_spec)
	if not _expect(shield_skin.rivets == [Vector2(-11, -25), Vector2(11, -25), Vector2(-11, -11), Vector2(11, -11)] and shield_skin.heart_center == Vector2(0, -17) and shield_skin.heart_radius == 4.5, "tower shield rivets and element heart must retain the exact Web anchors"):
		return
	var star_row: Array = main._unit_star_row_spec(spec)
	if not _expect(star_row.size() == 5 and star_row[0].color == Color("3a9aff") and star_row[0].size == 14 and star_row[4].color == Color("ff7a3a") and star_row[4].size == 14, "the rendered ascension row must retain Web star colors and the two-pixel ascension size increase"):
		return
	unit.buffT = 2.0
	if not _expect(main._unit_visual_spec(unit).ult_buff_active, "the frozen Web generic ultimate-buff lightning badge must remain renderable when its state is active"):
		return
	var wutugu: Dictionary = main.battle_run._make_unit(main.catalog.by_id("heroes", "wutugu"), 0, 2)
	if not _expect(main._unit_visual_spec(wutugu).poison_aura_radius == 90.0, "Wutugu must keep his persistent ninety-pixel poison range ring"):
		return
	if not _expect(main._unit_visual_spec(wutugu, -1, -1).poison_aura_radius == 0.0, "a dragged Wutugu must hide the grid-only poison range ring just like the frozen Web draw path"):
		return
	wutugu.ultT = 2.0
	if not _expect(is_equal_approx(float(main._unit_visual_spec(wutugu).poison_aura_radius), 198.0), "Wutugu's active ultimate must expand the visible poison ring by the Web 2.2 multiplier"):
		return
	var egg: Dictionary = main.battle_run._make_unit(BattleCards.EGG_TYPE, 0, 3)
	egg.level = 3
	var dragon: Dictionary = main.battle_run._make_unit(BattleCards.DRAGON_TYPE, 0, 4)
	if not _expect(main._unit_visual_spec(egg).egg_ready_glow and main._unit_visual_spec(dragon).dragon_glow and not main._unit_visual_spec(egg).taoyuan_ring_visible, "max-rank eggs and dragons need their Web glows while eggs remain excluded from Taoyuan rings"):
		return
	print("Godot v7.19.14 battle unit presentation: PASS")
	quit(0)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
