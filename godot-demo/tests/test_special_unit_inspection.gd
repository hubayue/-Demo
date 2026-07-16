extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const BattleCards = preload("res://src/battle/battle_cards.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	main.advance_from_title()
	main.select_city(0)
	main.select_ruler("caocao")
	main.select_opening_hero("zhaoyun")
	var run = main.battle_run
	run.obstacles.clear()
	run.traits.clear()
	run.wave = 10
	run.xp_need = 20.0

	var granary: Dictionary = run._make_unit(BattleCards.GRANARY_TYPE.duplicate(true), 1, 2)
	granary.level = 2
	granary.farmAcc = 9.0
	run.grid[1][2] = granary
	main.unit_info_popup = {"unit": granary, "row": 1, "col": 2}
	var spec: Dictionary = main.unit_info_popup_spec()
	if not _expect(spec.special_class == "granary" and spec.title == "粮仓 2星", "granary popup must use the Web special title"): return
	if not _expect(spec.badge.contains("站着屯粮") and spec.ultimate_line == "", "granary popup must replace the ordinary ultimate with its range badge and ledger"): return
	if not _expect(spec.special_lines.size() == 3 and str(spec.special_lines[0]).contains("每秒攒") and str(spec.special_lines[0]).contains("喂星进度 25%") and str(spec.special_lines[1]) == "再抽「粮仓扩建」升星：产粮×1.6" and str(spec.special_lines[2]) == "被拆了不算阵亡 · 拖出阵地能卖", "granary popup must show the complete Web production ledger"): return

	run.ruler_id = "liubiao"
	run.ruler_level = 5
	run.relic_ids = ["longxian"]
	var egg: Dictionary = run._make_unit(BattleCards.EGG_TYPE.duplicate(true), 1, 2)
	egg.level = 2
	egg.hatchBonus = 0.2
	egg.rbuffs = {"farm": 5.0}
	run.grid[1][2] = egg
	run.traits["1,2"] = "elem"
	main.unit_info_popup = {"unit": egg, "row": 1, "col": 2}
	spec = main.unit_info_popup_spec()
	if not _expect(spec.special_class == "egg" and spec.title == "龙蛋 2星" and spec.special_lines[0] == "孵到 2/3 阶 · 这次把握 9 成", "egg popup must show real rank and capped hatch chance"): return
	if not _expect(str(spec.special_lines[1]).contains("失败攒的把握+2成") and str(spec.special_lines[1]).contains("灵脉+1成") and str(spec.special_lines[1]).contains("龙涎香+2成") and str(spec.special_lines[1]).contains("鲁肃粮草+1成5"), "egg popup must itemize every active hatch modifier"): return
	if not _expect(spec.trait_text == "", "egg popup must keep elemental terrain in the hatch ledger instead of the ordinary terrain line"): return

	var dragon: Dictionary = run._make_unit(BattleCards.DRAGON_TYPE.duplicate(true), 1, 2)
	dragon.dragonRank = 2
	run.grid[1][2] = dragon
	run.dragon_count = 1
	main.unit_info_popup = {"unit": dragon, "row": 1, "col": 2}
	spec = main.unit_info_popup_spec()
	var damage: int = run.dragon_damage(dragon)
	if not _expect(spec.special_class == "dragon" and spec.title == "应龙" and spec.badge.contains("🐉神兽") and spec.badge.contains("全场横扫") and spec.play_note.begins_with("每2.8秒吐龙息"), "dragon popup must omit stars and use the complete Web class, range and play copy"): return
	if not _expect(spec.special_lines[0] == "重击 %d 伤 · 圈内 %d 伤（跟波次和队伍星级涨）" % [damage * 3, damage] and spec.special_lines[1] == "第2条应龙：伤害多25%" and spec.special_lines[2].begins_with("还能再抽龙蛋"), "dragon ledger must share exact damage and rank data with live combat"): return
	run.traits.erase("1,2")
	var base_damage: int = run.dragon_damage(dragon)
	run.traits["1,2"] = "atk"
	main.unit_info_popup = {"unit": dragon, "row": 1, "col": 2}
	spec = main.unit_info_popup_spec()
	if not _expect(run.dragon_damage(dragon) == roundi(base_damage * 1.15) and spec.trait_text == "", "match Web exactly: attack terrain boosts dragon damage while the special-unit popup still filters that terrain line"): return
	run.farm_stars = 5
	run.dragon_count = 1
	run.dragon_waves = [10]
	var report_rows: Array = main.battle_report_rows()
	if not _expect(report_rows.any(func(row): return str(row.label) == "🌾 屯田喂星" and str(row.value) == "5 颗") and report_rows.any(func(row): return str(row.label) == "🐉 觉醒应龙" and str(row.value).contains("第10波")), "battle report must expose granary-fed stars and dragon awakening waves like Web"): return
	run.achievement_events = ["granary40"]
	main._sync_battle_achievements()
	if not _expect(main.profile.achievements.has("granary40"), "battle event achievements must persist into the local profile before settlement"): return
	print("Godot v7.19.14 special unit inspection: PASS")
	quit(0)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
