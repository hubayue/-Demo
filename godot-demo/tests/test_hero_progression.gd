extends SceneTree

const ContentCatalog = preload("res://src/content/content_catalog.gd")
const HeroProgression = preload("res://src/progression/hero_progression.gd")
const LocalProfile = preload("res://src/progression/local_profile.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog := ContentCatalog.new()
	if not _expect(catalog.load_from("res://data/content-v7.19.2.json") == OK, "content must load"): return
	var profile := LocalProfile.defaults(2948)
	HeroProgression.ensure_roster(profile, catalog.list("heroes"))
	if not _expect(profile.heroes.size() == 45 and int(profile.heroes.zhangfei.lv) == 1, "the offline codex must initialize all 45 heroes at account level one"): return
	if not _test_costs(catalog): return
	if not _test_upgrade_gate_rebirth_and_reset(catalog, profile): return
	if not _test_experience_autolevel(catalog): return
	if not _test_profile_round_trip(profile): return
	print("Godot v7.19.2 hero codex progression: PASS")
	quit(0)

func _test_costs(catalog) -> bool:
	var tiers: Dictionary = catalog.content.hero_tiers
	var rarities: Dictionary = catalog.content.rarities
	if not _expect(HeroProgression.upgrade_cost(2, "daqiao", tiers, rarities) == 100, "a common hero's level-two price must round to 100 gold"): return false
	if not _expect(HeroProgression.upgrade_cost(2, "zhangfei", tiers, rarities) == 160, "a rare hero's level-two price must round to 160 gold"): return false
	return _expect(HeroProgression.upgrade_cost(2, "guanyu", tiers, rarities) == 210, "an epic hero's level-two price must round to 210 gold")

func _test_upgrade_gate_rebirth_and_reset(catalog, profile: Dictionary) -> bool:
	var tiers: Dictionary = catalog.content.hero_tiers
	var rarities: Dictionary = catalog.content.rarities
	profile.gold = 1000
	if not _expect(HeroProgression.upgrade(profile, "zhangfei", tiers, rarities), "a funded hero upgrade must succeed"): return false
	if not _expect(int(profile.heroes.zhangfei.lv) == 2 and int(profile.gold) == 840, "hero upgrade must spend the exact rarity-adjusted gold price"): return false
	profile.heroes.zhangfei.lv = 10
	profile.gold = 100000
	if not _expect(not HeroProgression.upgrade(profile, "zhangfei", tiers, rarities), "level ten must stop at the one-stone breakthrough gate"): return false
	profile.items.tupo = 1
	if not _expect(HeroProgression.upgrade(profile, "zhangfei", tiers, rarities) and int(profile.items.tupo) == 0 and int(profile.heroes.zhangfei.lv) == 11, "one breakthrough stone must open levels ten to eleven"): return false
	profile.heroes.zhangfei.lv = 30
	profile.items.tupo = 5
	if not _expect(HeroProgression.rebirth(profile, "zhangfei") and int(profile.heroes.zhangfei.rb) == 1 and HeroProgression.level_cap(profile.heroes.zhangfei) == 40, "five stones at level thirty must unlock first rebirth and a level-forty cap"): return false
	var preview: Dictionary = HeroProgression.reset_preview(profile, "zhangfei", tiers, rarities)
	var gold_before := int(profile.gold)
	if not _expect(int(preview.stones) >= 8 and int(preview.gold) > 0, "reset preview must refund breakthrough and rebirth stones plus all upgrade gold"): return false
	HeroProgression.reset(profile, "zhangfei", tiers, rarities)
	return _expect(int(profile.heroes.zhangfei.lv) == 1 and int(profile.heroes.zhangfei.rb) == 0 and int(profile.gold) == gold_before + int(preview.gold), "reset must return the hero to level one and pay the previewed refund")

func _test_experience_autolevel(catalog) -> bool:
	var profile := LocalProfile.defaults(2948)
	HeroProgression.ensure_roster(profile, catalog.list("heroes"))
	var tiers: Dictionary = catalog.content.hero_tiers
	var rarities: Dictionary = catalog.content.rarities
	var result: Dictionary = HeroProgression.add_xp(profile, "daqiao", 1000000, tiers, rarities)
	return _expect(int(result.to) == 10 and int(profile.heroes.daqiao.lv) == 10 and int(profile.heroes.daqiao.xp) > 0, "free hero experience must auto-level but stop before the level-ten stone gate")

func _test_profile_round_trip(profile: Dictionary) -> bool:
	var path := "user://codex-v7192-hero-profile-test.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	profile.items.visitToken = 7
	profile.items.tupo = 4
	profile.heroes.daqiao = {"lv": 6, "rb": 0, "xp": 321}
	if not _expect(LocalProfile.save_to(path, profile) == OK, "expanded hero profile must save"): return false
	var loaded := LocalProfile.load_from(path, 2948)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return _expect(int(loaded.items.visitToken) == 7 and int(loaded.items.tupo) == 4 and int(loaded.heroes.daqiao.xp) == 321, "items and hero experience must round-trip through local storage")

func _expect(condition: bool, message: String) -> bool:
	if condition: return true
	push_error(message)
	quit(1)
	return false
