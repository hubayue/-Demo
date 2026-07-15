extends SceneTree

const ContentCatalog = preload("res://src/content/content_catalog.gd")
const Mulberry32 = preload("res://src/core/mulberry32.gd")
const BattleRun = preload("res://src/battle/battle_run.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog = ContentCatalog.new()
	if not _expect(catalog.load_from("res://data/content-v7.19.14.json") == OK, "v7.19.14 content must load"):
		return
	var run = BattleRun.new(catalog, Mulberry32.new(71914))
	if not _expect(run.ult_system.has_method("visual_effect"), "ultimate system must classify every skill into a visual family"):
		return
	for hero in catalog.list("heroes"):
		if not run.ult_system.definition(str(hero.id)).is_empty() and not _expect(not run.ult_system.visual_effect(str(hero.id)).is_empty(), "%s must have a visual family" % str(hero.id)):
			return
	if not _expect(run.ult_system.visual_effect("zhangfei") == "shock" and run.ult_system.visual_effect("machao") == "lightning" and run.ult_system.visual_effect("huatuo") == "heal", "distinct Web geometries must not collapse into one generic banner"):
		return
	if not _expect(run.ult_system.visual_effect("taishici") == "arrow_rain" and run.ult_system.visual_effect("huangyueying") == "turret_deploy", "live lobs must replace Taishi Ci and Huang Yueying's old generic placeholder circles"):
		return
	if not _expect(run.ult_system.visual_effect("zhouyu") == "fire_beam" and run.ult_system.visual_effect("gaoshun") == "gather_lines" and run.ult_system.visual_effect("simayi") == "clock_links", "targeted beam entities must replace Zhou Yu, Gao Shun, and Sima Yi's old caster-centered circles"):
		return
	run.start({"ch": 0, "wall": 13, "foes": {"tri": "badao"}, "theme": "tuanjie", "field": "plain", "rules": []}, "liubei", "zhaoyun")
	var unit: Dictionary = run.units()[0]
	var expected := BattleRun.slot_center(int(unit.row), int(unit.col)) - Vector2(0, 18)
	if not _expect(run.ult_system.cast(run, unit), "Zhao Yun ultimate must cast"):
		return
	var event: Dictionary = run.ult_events.back()
	if not _expect(event.hero_id == "zhaoyun" and event.name == "七探盘蛇" and event.type == "dmg", "visual event must identify the exact hero ultimate"):
		return
	if not _expect(event.has("origin") and event.has("duration") and event.has("effect"), "ultimate event must expose renderable origin, duration, and effect family"):
		return
	if not _expect(event.origin == expected and event.duration == 1.6 and event.t == event.duration, "visual event must carry a stable origin and normalized lifetime"):
		return
	if not _expect(event.effect == "fan", "Zhao Yun must expose his Web fan-projectile visual family"):
		return
	print("Godot v7.19.14 ultimate visual events: PASS")
	quit(0)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
