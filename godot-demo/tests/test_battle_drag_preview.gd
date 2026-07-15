extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	if not _expect(main.has_method("_drag_preview_spec"), "battle drag must expose the Web placement preview model"):
		return
	main.advance_from_title()
	main.select_city(0)
	main.select_ruler("liubei")
	main.select_opening_hero("zhaoyun")
	var run = main.battle_run
	run.clear_formation()
	run.obstacles.clear()
	run.add_unit_at("zhaoyun", 2, 2)
	var spec: Dictionary = main._drag_preview_spec(run.units()[0], Vector2i(2, 1))
	if not _expect(spec.kind == "range" and spec.radius == run.effective_archer_range(run.units()[0].hero) and spec.anchor == run.slot_center(1, 2), "ranged spear preview must anchor its effective attack radius to the drop cell"):
		return
	if not _expect(str(spec.get("label", "")).contains("打半场"), "range preview must expose the Web range label"):
		return
	run.traits["1,2"] = "atk"
	spec = main._drag_preview_spec(run.units()[0], Vector2i(2, 1))
	if not _expect(str(spec.get("trait_text", "")) == "⚔️沃土 伤害+15%", "placement preview must translate terrain ids into the exact visible Web trait copy"):
		return
	run.traits["1,2"] = "crit"
	spec = main._drag_preview_spec(run.units()[0], Vector2i(2, 1))
	if not _expect(str(spec.get("trait_text", "")) == "🎯高台 多10%机会双倍暴击", "ordinary high-ground preview must keep the Web double-crit wording"):
		return
	run.relic_ids.append("qinggang")
	spec = main._drag_preview_spec(run.units()[0], Vector2i(2, 1))
	if not _expect(str(spec.get("trait_text", "")) == "🎯高台 多10%机会三倍暴击", "Qinggang must change high-ground preview copy to the Web triple-crit wording"):
		return
	main.unit_info_popup = {"unit": run.units()[0], "row": 2, "col": 2}
	run.traits["2,2"] = "crit"
	run.units()[0].rbuffs = {"crit": 0.1}
	var qinggang_info: Dictionary = main.unit_info_popup_spec()
	if not _expect(str(qinggang_info.trait_text).contains("三倍暴击") and str(qinggang_info.status_text).contains("💧更容易三倍暴击"), "Qinggang must keep the unit terrain and water-wave crit wording consistent with triple damage"):
		return
	run.relic_ids.erase("qinggang")
	var ordinary_crit_info: Dictionary = main.unit_info_popup_spec()
	if not _expect(str(ordinary_crit_info.trait_text).contains("双倍暴击") and str(ordinary_crit_info.status_text).contains("💧更容易双倍暴击"), "ordinary unit terrain and water-wave crit wording must return to the Web double-crit baseline"):
		return
	run.traits.erase("2,2")
	run.clear_formation()
	run.add_unit_at("guanyu", 2, 2)
	spec = main._drag_preview_spec(run.units()[0], Vector2i(2, 1))
	if not _expect(spec.kind == "corridor" and spec.width >= 34.0 and spec.get("adjacent_corridors", []).size() == 2, "cavalry preview must show the main and two adjacent Web charge corridors"):
		return
	run.clear_formation()
	run.add_unit_at("huangzhong", 2, 2)
	spec = main._drag_preview_spec(run.units()[0], Vector2i(2, 1))
	if not _expect(spec.kind == "global", "zero-range archer must preview full-field reach"):
		return
	run.clear_formation()
	run.add_unit_at("huatuo", 2, 2)
	spec = main._drag_preview_spec(run.units()[0], Vector2i(2, 1))
	if not _expect(spec.kind == "ripple" and spec.radius > 0.0 and not str(spec.get("label", "")).is_empty(), "support preview must expose its water-ripple radius and support-specific copy"):
		return
	run.clear_formation()
	run.add_unit_at("zhaoyun", 1, 2)
	run.add_unit_at("zhangfei", 1, 1)
	spec = main._drag_preview_spec(run.grid[1][2], Vector2i(2, 1))
	if not _expect(spec.get("spear_beneficiaries", []).has(Vector2i(1, 1)), "spear preview must mark adjacent attacking allies that receive its aura"):
		return
	if not _expect(main.has_method("unit_ultimate_presentation"), "the unit panel must expose one presentation source for all 45 normal heroes"):
		return
	for hero in main.catalog.list("heroes"):
		var hero_id := str(hero.id)
		if run.ult_system.definition(hero_id).is_empty():
			continue
		var presentation: Dictionary = main.unit_ultimate_presentation(hero_id)
		if not _expect(not str(presentation.get("desc", "")).is_empty() and not str(presentation.get("condition", "")).is_empty(), "unit panel must preserve exact ultimate description and condition for %s" % hero_id):
			return
	main.unit_info_popup = {"unit": run.grid[1][2], "row": 1, "col": 2}
	var info: Dictionary = main.unit_info_popup_spec()
	if not _expect(str(info.status_text).contains("🔱攻击+10%"), "unit panel must show the live adjacent-spear attack bonus seen in Web"):
		return
	run.clear_formation()
	run.add_unit_at("zhangfei", 2, 2)
	run.add_unit_at("caoren", 1, 2)
	run.add_unit_at("xuchu", 2, 1)
	var kin_spear: Dictionary = run.grid[2][2]
	kin_spear.sealedT = 2.0
	run.army_buff = {"t": 3.0, "mul": 1.3}
	run.army_haste = {"t": 3.0, "mul": 1.4}
	run.wuxing_time = 2.0
	main.unit_info_popup = {"unit": kin_spear, "row": 2, "col": 2}
	info = main.unit_info_popup_spec()
	for expected in ["🌾全军加攻", "🌬️全军提速", "🤝主公亲军", "☯️三才破敌", "🛡️有盾护着", "🧱盾墙挡投石", "🌀被封住了"]:
		if not _expect(str(info.status_text).contains(expected), "unit panel must expose live Web status: %s" % expected):
			return
	run.clear_formation()
	run.add_unit_at("guanyu", 2, 2)
	run.enemies.clear()
	for index in 20:
		run.enemies.append({"dead": false, "y": 100.0, "hp": 100.0})
	main.unit_info_popup = {"unit": run.grid[2][2], "row": 2, "col": 2}
	info = main.unit_info_popup_spec()
	if not _expect(str(info.play_note).contains("现+20%"), "cavalry play note must show the live Web crowd multiplier"):
		return
	run.clear_formation()
	run.enemies.clear()
	run.add_unit_at("caoren", 2, 2)
	var shield: Dictionary = run.grid[2][2]
	shield.tanked = float(shield.hp_max) * 0.3
	run.buffs.shieldReflect = 0.01
	main.unit_info_popup = {"unit": shield, "row": 2, "col": 2}
	info = main.unit_info_popup_spec()
	if not _expect(str(info.play_note).contains("反弹%d点" % roundi(float(shield.hp_max) * 0.05)) and str(info.play_note).contains("怒气50%"), "shield play note must show live reflection and counter-charge values"):
		return
	run.clear_formation()
	run.add_unit_at("dengai", 2, 2)
	main.unit_info_popup = {"unit": run.grid[2][2], "row": 2, "col": 2}
	info = main.unit_info_popup_spec()
	if not _expect(str(info.get("ultimate_line", "")) == "大招【凿山】同排贼全挨一记重锤，站石头上砸得更狠（石头不碎，接着占高地）", "long ultimate copy must remain complete instead of being character-truncated"):
		return
	print("Godot v7.19.14 battle drag previews: PASS")
	quit(0)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
