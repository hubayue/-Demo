extends SceneTree

const ContentCatalog = preload("res://src/content/content_catalog.gd")
const LocalProfile = preload("res://src/progression/local_profile.gd")
const HeroProgression = preload("res://src/progression/hero_progression.gd")
const VisitSystem = preload("res://src/progression/visit_system.gd")
const AchievementProgress = preload("res://src/progression/achievement_progress.gd")
const Mulberry32 = preload("res://src/core/mulberry32.gd")

func _init() -> void:
	var catalog = ContentCatalog.new()
	if not _expect(catalog.load_from("res://data/content-v7.19.2.json") == OK, "Catalog must load"):
		return
	var profile := LocalProfile.defaults(2948)
	HeroProgression.ensure_roster(profile, catalog.list("heroes"))
	var board: Array = VisitSystem.board(2948)
	if not _expect(board.size() == 20, "Visit board must contain 20 cells"):
		return
	for pair in [["gold", 3], ["gift", 2], ["hxp", 4], ["lxp", 4], ["luck", 4], ["tupo", 2], ["kuang", 1]]:
		if not _expect(board.count(pair[0]) == pair[1], "Visit board composition must match Web v7.19.2"):
			return
	profile.items.visitToken = 1
	var before := _resource_total(profile)
	var result: Dictionary = VisitSystem.roll(profile, catalog, 2948, Mulberry32.new(12345), 1000000)
	if not _expect(int(result.get("dice", 0)) in range(1, 7) and int(profile.items.visitToken) == 0, "Visit roll must spend one token and move 1-6 cells"):
		return
	if not _expect(int(profile.visit_pos) == int(result.dice) and _resource_total(profile) > before, "Landing must persist board position and grant a real reward"):
		return

	profile.wins = 10
	profile.week_clears = {"0": 1, "1": 1, "2": 1, "3": 1, "4": 1, "5": 1, "6": 1, "7": 1}
	profile.heroes.daqiao.lv = 10
	var unlocked: Array = AchievementProgress.sweep(profile, catalog.list("achievements"))
	if not _expect(unlocked.has("wins10") and unlocked.has("weekclear8") and unlocked.has("hero10"), "Local measurable achievements must unlock from profile facts"):
		return
	var gold_before: int = profile.gold
	var claimed: Dictionary = AchievementProgress.claim(profile, "wins10", catalog.list("achievements"))
	if not _expect(int(claimed.get("gold", 0)) == 300 and int(profile.gold) == gold_before + 300 and profile.ach_claimed.has("wins10"), "Claiming an unlocked achievement must pay exactly once"):
		return
	if not _expect(AchievementProgress.claim(profile, "wins10", catalog.list("achievements")).is_empty(), "An achievement reward must not be claimable twice"):
		return

	print("Godot v7.19.2 offline visits and achievements: PASS")
	quit(0)

func _resource_total(profile: Dictionary) -> int:
	var hero_xp := 0
	for hero in profile.heroes.values(): hero_xp += int(hero.xp)
	var lord_xp := 0
	for ruler in profile.rulers.values(): lord_xp += int(ruler.xp)
	return int(profile.gold) + int(profile.items.tupo) + int(profile.items.visitToken) + hero_xp + lord_xp

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
