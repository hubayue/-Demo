extends Control

const ContentCatalogSource = preload("res://src/content/content_catalog.gd")
const WeeklyMapSource = preload("res://src/progression/weekly_map.gd")
const OpeningPickerSource = preload("res://src/progression/opening_picker.gd")
const Mulberry32Source = preload("res://src/core/mulberry32.gd")
const BattleRunSource = preload("res://src/battle/battle_run.gd")
const BattleLordSource = preload("res://src/battle/battle_lord.gd")
const BattleFoesSource = preload("res://src/battle/battle_foes.gd")
const BattleRecordsSource = preload("res://src/progression/battle_records.gd")
const LocalProfileSource = preload("res://src/progression/local_profile.gd")
const RunSettlementSource = preload("res://src/progression/run_settlement.gd")

const VIEW_SIZE := Vector2(480.0, 800.0)
const CURRENT_WEEK := 2948
const GOLD := Color("ffe45a")
const PALE_GOLD := Color("e8c86a")
const INK := Color("17120c")
const PANEL := Color("241c10")
const PANEL_2 := Color("332714")
const MUTED := Color("8a7d5a")
const GREEN := Color("7ad86a")
const BLUE := Color("62b8ff")
const RED := Color("ff8a6a")

const RULER_IDS := ["caocao", "liubei", "sunquan", "yuanshao", "liubiao", "gongsunzan", "dongzhuo", "yuanshu"]
const REGION_NAMES := ["东部", "南部", "西部", "北部"]
const CLASS_NAMES := {"cav": "骑兵", "spear": "枪兵", "archer": "弓兵", "mage": "谋士"}
const CLASS_COLORS := {
	"spear": Color("8b4b3b"), "cav": Color("66502f"), "archer": Color("365d43"),
	"shield": Color("455b73"), "support": Color("65466f"), "granary": Color("76623b"),
}
const TRI_DISPLAY := {
	"badao": {"name": "霸道", "icon": "✊", "color": Color("ff6b4a"), "counter": "rende"},
	"liangmou": {"name": "良谋", "icon": "✌", "color": Color("4aa8ff"), "counter": "badao"},
	"rende": {"name": "仁德", "icon": "✋", "color": Color("7ad86a"), "counter": "liangmou"},
}
const SPECIAL_GLYPHS := {"runner": "奔", "healer": "医", "shooter": "弓", "banner": "旗", "thrower": "投", "shaman": "妖", "rattan": "藤", "ram": "车", "cata": "砲", "warden": "督", "bomber": "爆", "assassin": "刺", "pavise": "楯"}
const SPECIAL_COLORS := {"runner": Color("8ad2ff"), "healer": Color("8aff9a"), "shooter": Color("ffb06a"), "banner": Color("ffd24a"), "thrower": Color("c9b89a"), "shaman": Color("c96aff"), "rattan": Color("7fa34a"), "ram": Color("a48b70"), "cata": Color("c9b89a"), "warden": Color("ff6a5a"), "bomber": Color("ff7a3a"), "assassin": Color("ff9ad2"), "pavise": Color("8aa0b8")}
const CITY_POSITIONS := [
	Vector2(168, 650), Vector2(76, 578), Vector2(356, 630), Vector2(244, 568),
	Vector2(66, 430), Vector2(396, 496), Vector2(282, 476), Vector2(348, 392),
	Vector2(414, 302), Vector2(206, 416), Vector2(118, 336), Vector2(176, 258),
	Vector2(404, 176), Vector2(250, 186), Vector2(322, 250), Vector2(310, 132),
]
const MAP_TAB_RECTS := [
	Rect2(48, 706, 93, 34),
	Rect2(145, 706, 93, 34),
	Rect2(242, 706, 93, 34),
	Rect2(339, 706, 93, 34),
]
const STATE_GO_RECT := Rect2(150, 648, 180, 44)
const LORD_COMMAND_RECT := Rect2(324, 751, 146, 42)
const FOE_LORD_RECT := Rect2(208, 108, 64, 43)
const RESULT_BTN1 := Rect2(38, 690, 404, 42)
const RESULT_BTN2 := Rect2(38, 744, 404, 42)

var catalog
var weekly
var opening_picker
var phase := "title"
var selected_city := -1
var selected_ruler := ""
var selected_hero := ""
var opening_hero_ids: Array = []
var current_region := 0
var state_popup := -1
var week_clears: Dictionary = {}
var map_message := ""
var battle_run
var foe_lord_popup := false
var profile_path := "user://v7.19.2-local-profile.json"
var profile: Dictionary = {}
var settlement_summary: Dictionary = {}
var suppression_summary: Dictionary = {}

func _ready() -> void:
	catalog = ContentCatalogSource.new()
	var error: Error = catalog.load_from("res://data/content-v7.19.2.json")
	if error != OK:
		push_error("Unable to load v7.19.2 content catalog: %s" % error_string(error))
		set_process(false)
		return
	weekly = WeeklyMapSource.new(catalog)
	opening_picker = OpeningPickerSource.new()
	profile = LocalProfileSource.load_from(profile_path, CURRENT_WEEK)
	week_clears = profile.week_clears
	set_process(true)
	queue_redraw()

func advance_from_title() -> void:
	phase = "map"
	current_region = 0
	state_popup = -1
	queue_redraw()

func select_map_region(region: int) -> void:
	current_region = clampi(region, 0, 3)
	state_popup = -1
	map_message = ""
	queue_redraw()

func open_city(index: int) -> void:
	if not city_is_unlocked(index):
		map_message = "🔒 先拿下前一座城，再继续进军"
		queue_redraw()
		return
	state_popup = index
	map_message = ""
	queue_redraw()

func select_city(index: int) -> void:
	selected_city = index
	state_popup = -1
	phase = "ruler"
	queue_redraw()

func select_ruler(ruler_id: String) -> void:
	selected_ruler = ruler_id
	roll_opening_heroes()
	phase = "pick"
	queue_redraw()

func roll_opening_heroes() -> void:
	var city: Dictionary = weekly.make_level(CURRENT_WEEK, selected_city)
	city.metaWins = int(profile.get("wins", 0))
	opening_hero_ids = opening_picker.pick_ids(
		catalog.list("heroes"),
		selected_ruler,
		str(city.foes.tri),
		catalog.content.get("lord_kin", {}),
	)

func select_opening_hero(hero_id: String) -> void:
	selected_hero = hero_id
	phase = "battle"
	var city: Dictionary = weekly.make_level(CURRENT_WEEK, selected_city)
	city.metaWins = int(profile.get("wins", 0))
	city.weekGuest = BattleRecordsSource.week_guest_lords(CURRENT_WEEK).has(selected_ruler)
	var seed := CURRENT_WEEK * 1009 + selected_city * 131 + RULER_IDS.find(selected_ruler) * 17
	battle_run = BattleRunSource.new(catalog, Mulberry32Source.new(seed))
	battle_run.start(city, selected_ruler, selected_hero, LocalProfileSource.ruler_level(profile, selected_ruler), LocalProfileSource.hero_levels(profile))
	foe_lord_popup = false
	settlement_summary = {}
	suppression_summary = {}
	queue_redraw()

func city_is_cleared(index: int) -> bool:
	return week_clears.has(index) or week_clears.has(str(index))

func city_is_unlocked(index: int) -> bool:
	return index == 0 or city_is_cleared(index - 1)

func region_clear_count(region: int) -> int:
	var cleared := 0
	for local_index in 16:
		if city_is_cleared(region * 16 + local_index):
			cleared += 1
	return cleared

func _process(delta: float) -> void:
	if phase != "battle" or battle_run == null:
		return
	battle_run.advance_real(delta)
	_sync_battle_result()
	queue_redraw()

func _sync_battle_result() -> void:
	if battle_run.status == "win" and not battle_run.clear_settled:
		settlement_summary = RunSettlementSource.settle_clear(profile, battle_run, selected_city, _theme_fit())
		_save_profile()
	if battle_run.endless and battle_run.score_revision > 0 and int(suppression_summary.get("revision", 0)) < battle_run.score_revision:
		suppression_summary = RunSettlementSource.record_suppression(profile, battle_run, selected_city, bool(battle_run.city.get("weekGuest", false)))
		suppression_summary.revision = battle_run.score_revision
		_save_profile()
	if battle_run.status == "over" and not battle_run.over_settled:
		var over_summary: Dictionary = RunSettlementSource.settle_over(profile, battle_run, selected_city)
		for key in over_summary: settlement_summary[key] = over_summary[key]
		_save_profile()

func _save_profile() -> void:
	var error := LocalProfileSource.save_to(profile_path, profile)
	if error != OK: push_error("Unable to save local profile: %s" % error_string(error))

func _theme_fit() -> bool:
	match str(battle_run.city.get("theme", "")):
		"tuanjie": return battle_run.bond_ever
		"liaoyuan": return battle_run.units().any(func(unit): return bool(unit.hero.get("burn", false)) or str(battle_run.ult_system.definition(str(unit.hero.id)).get("name", "")).contains("火"))
		"yunchou": return battle_run.lord_command_used > 0
		"jifeng": return int(battle_run.team.counts.get("spear", 0)) + int(battle_run.team.counts.get("cav", 0)) + int(battle_run.team.counts.get("shield", 0)) >= 3
		"jiancheng": return int(battle_run.team.counts.get("archer", 0)) > 0 and battle_run.units().any(func(unit): return float(unit.hero.get("splash", 0.0)) > 0)
	return false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_pointer(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_handle_pointer(event.position)

func _handle_pointer(point: Vector2) -> void:
	match phase:
		"title":
			advance_from_title()
		"map":
			_handle_map_pointer(point)
		"ruler":
			for index in RULER_IDS.size():
				if _ruler_rect(index).has_point(point):
					select_ruler(RULER_IDS[index])
					return
		"pick":
			for index in opening_hero_ids.size():
				if _hero_card_rect(index).has_point(point):
					select_opening_hero(opening_hero_ids[index])
					return
		"battle":
			if battle_run == null:
				return
			if battle_run.status != "play":
				_handle_result_pointer(point)
				return
			if bool(battle_run.permanent_tactics.get("gewu", false)):
				battle_run.permanent_tactics.gewu = false
				battle_run.gewu_auto_timer = 0.0
				queue_redraw()
				return
			if foe_lord_popup:
				foe_lord_popup = false
				queue_redraw()
				return
			if battle_run.awaiting_card_choice:
				for index in battle_run.card_choices.size():
					if _growth_card_rect(index).has_point(point):
						battle_run.choose_card(index)
						queue_redraw()
						return
			elif FOE_LORD_RECT.has_point(point) and not battle_run.foe_lord.is_empty():
				foe_lord_popup = true
				queue_redraw()
				return
			elif LORD_COMMAND_RECT.has_point(point):
				battle_run.cast_lord_command()
				queue_redraw()
				return

func _handle_result_pointer(point: Vector2) -> void:
	if RESULT_BTN1.has_point(point):
		if battle_run.status == "win":
			battle_run.continue_endless()
		else:
			_return_to_map()
	elif RESULT_BTN2.has_point(point):
		if battle_run.status == "win":
			_return_to_map()
		else:
			phase = "title"
			battle_run = null
	queue_redraw()

func _return_to_map() -> void:
	phase = "map"
	current_region = clampi(int(floor(selected_city / 16.0)), 0, 3)
	state_popup = -1
	battle_run = null
	foe_lord_popup = false

func _handle_map_pointer(point: Vector2) -> void:
	if state_popup >= 0:
		if STATE_GO_RECT.has_point(point):
			select_city(state_popup)
		else:
			state_popup = -1
			queue_redraw()
		return
	for region in MAP_TAB_RECTS.size():
		if MAP_TAB_RECTS[region].has_point(point):
			select_map_region(region)
			return
	for local_index in CITY_POSITIONS.size():
		if point.distance_to(CITY_POSITIONS[local_index]) <= 33.0:
			open_city(current_region * 16 + local_index)
			return

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), INK)
	if catalog == null or weekly == null:
		_text_center("正在载入 v7.19.2…", 400, 22, PALE_GOLD)
		return
	match phase:
		"title":
			_draw_title()
		"map":
			_draw_map()
		"ruler":
			_draw_rulers()
		"pick":
			_draw_pick()
		"battle":
			_draw_battle()

func _font() -> Font:
	return get_theme_default_font()

func _text_center(text: String, y: float, size: int, color := Color.WHITE) -> void:
	draw_string(_font(), Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, VIEW_SIZE.x, size, color)

func _text(text: String, position: Vector2, size: int, color := Color.WHITE) -> void:
	draw_string(_font(), position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _panel(rect: Rect2, fill := PANEL_2, border := PALE_GOLD, width := 2.0) -> void:
	draw_rect(rect, fill, true)
	draw_rect(rect, border, false, width)

func _text_centered_in_rect(text: String, rect: Rect2, size: int, color: Color) -> void:
	draw_string(_font(), Vector2(rect.position.x, rect.position.y + size), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)

func _draw_title() -> void:
	_text_center("不一样三国 2.0", 278, 43, GOLD)
	_text_center("守城塔防 · 肉鸽点将", 340, 26, PALE_GOLD)
	_text_center("天下争夺 · 每周全服换图 · 64座城池逐城攻取", 430, 15, Color("d5c9a8"))
	_text_center("克制这城贼的那一系，才打得疼", 470, 17, GREEN)
	_text_center("贼军不等人：下一波会直接压上来", 510, 16, RED)
	_text_center("破城后可继续讨伐，十大功绩计入势力", 550, 16, BLUE)
	_text_center("点击空白处出征", 690, 24, PALE_GOLD)
	_text_center("Godot 4.7 · v7.19.2 单机复现", 760, 12, MUTED)

func _draw_map() -> void:
	var theme: Dictionary = weekly.theme_of(CURRENT_WEEK, current_region)
	_text_center("🗺 讨贼地图 · 第1期", 38, 25, GOLD)
	_text_center("%s %s：%s" % [theme.icon, theme.name, theme.short], 64, 16, Color("ffb84a"))
	_text_center("逐城解锁 · 点城查看敌情与奖励", 88, 13, Color("d5c9a8"))
	draw_polyline(PackedVector2Array(CITY_POSITIONS), Color(1.0, 0.89, 0.35, 0.15), 2.0)
	var state_names: Array = catalog.list("state_names")
	for local_index in CITY_POSITIONS.size():
		var k := current_region * 16 + local_index
		var point: Vector2 = CITY_POSITIONS[local_index]
		var city: Dictionary = weekly.make_level(CURRENT_WEEK, k)
		var unlocked := city_is_unlocked(k)
		var cleared := city_is_cleared(k)
		var border: Color = Color(city.color) if unlocked else Color("5a513e")
		if k == _frontline_city():
			border = GOLD
		elif cleared:
			border = GREEN
		draw_circle(point, 26.0, Color("211a10") if unlocked else Color("1a160f"))
		draw_arc(point, 27.0, 0.0, TAU, 40, border, 3.0 if k == _frontline_city() else 2.0)
		if unlocked:
			_text_centered_in_rect(("👑" if k % 2 == 1 else "") + str(city.icon), Rect2(point.x - 30, point.y - 17, 60, 18), 13, Color.WHITE)
		else:
			_text_centered_in_rect("🔒", Rect2(point.x - 30, point.y - 17, 60, 18), 12, MUTED)
		_text_centered_in_rect(str(state_names[k]), Rect2(point.x - 42, point.y + 1, 84, 18), 12, Color("e8dcc0") if unlocked else MUTED)
		if unlocked:
			_draw_triangle_badge(point + Vector2(21, -21), str(city.foes.tri))
	for region in MAP_TAB_RECTS.size():
		var tab_theme: Dictionary = weekly.theme_of(CURRENT_WEEK, region)
		var active := region == current_region
		_panel(MAP_TAB_RECTS[region], Color("5a4426") if active else Color("211b11"), GOLD if active else Color("665b45"), 2.0 if active else 1.0)
		_text_centered_in_rect("%s%s %d/16" % [REGION_NAMES[region], tab_theme.icon, region_clear_count(region)], MAP_TAB_RECTS[region].grow(-2), 12, Color("ffe8b0") if active else MUTED)
	if map_message:
		_text_center(map_message, 686, 14, RED)
	else:
		_text_center("当前区域：%s · %d/16" % [REGION_NAMES[current_region], region_clear_count(current_region)], 686, 13, PALE_GOLD)
	_text_center("点击城池查看详情", 775, 13, MUTED)
	if state_popup >= 0:
		_draw_state_popup(state_popup)

func _frontline_city() -> int:
	for k in 64:
		if not city_is_cleared(k):
			return k
	return 63

func _draw_triangle_badge(point: Vector2, tri_id: String) -> void:
	var tri: Dictionary = TRI_DISPLAY[tri_id]
	draw_circle(point, 10.0, Color("17120c"))
	draw_arc(point, 10.0, 0.0, TAU, 24, tri.color, 1.6)
	_text_centered_in_rect(str(tri.icon), Rect2(point.x - 10, point.y - 8, 20, 16), 10, Color.WHITE)

func _draw_state_popup(k: int) -> void:
	var city: Dictionary = weekly.make_level(CURRENT_WEEK, k)
	var cleared := city_is_cleared(k)
	var tri: Dictionary = TRI_DISPLAY[str(city.foes.tri)]
	var counter: Dictionary = TRI_DISPLAY[str(tri.counter)]
	var field: Dictionary = catalog.by_id("fields", str(city.field))
	var theme: Dictionary = weekly.theme_of(CURRENT_WEEK, int(floor(k / 16.0)))
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.03, 0.02, 0.01, 0.72), true)
	_panel(Rect2(24, 112, 432, 594), Color("2a2115"), GOLD, 2.5)
	_text_center("%s %s" % [city.icon, city.name], 150, 23, GOLD)
	_text_center("%s · %s" % [theme.name, theme.short], 176, 13, Color("ffb84a"))
	_panel(Rect2(42, 196, 396, 150), Color("211a10"), Color("6c5835"), 1.0)
	_text("⚔ 敌情", Vector2(58, 221), 17, PALE_GOLD)
	_text("贼是 %s%s · 带 %s%s 克他" % [tri.icon, tri.name, counter.icon, counter.name], Vector2(58, 249), 15, GREEN)
	_text("敌血×%s · 杀%d · 城墙%d" % [city.hpMul, city.killTarget, city.wall], Vector2(58, 277), 14, Color("e8dcc0"))
	_text("规则：%s" % _rule_names(city.rules), Vector2(58, 307), 13, Color("ffb84a"))
	if city.bossName:
		_text("👑 贼首：%s" % city.bossName, Vector2(58, 333), 13, RED)
	_panel(Rect2(42, 360, 396, 150), Color("211a10"), Color("6c5835"), 1.0)
	_text("🏙 城池", Vector2(58, 386), 17, PALE_GOLD)
	_text("地形：%s" % field.name, Vector2(58, 417), 14, Color("e8dcc0"))
	_text(str(field.desc), Vector2(58, 444), 13, BLUE)
	if cleared:
		_text("首通大赏：已领取 · 金币倍率×%s" % city.goldMul, Vector2(58, 478), 14, MUTED)
	else:
		_text("首通大赏：%d 金 · 金币倍率×%s" % [city.firstGold, city.goldMul], Vector2(58, 478), 14, GOLD)
	_panel(Rect2(42, 526, 396, 88), Color("211a10"), Color("6c5835"), 1.0)
	_text("🎖 我的战绩", Vector2(58, 552), 17, PALE_GOLD)
	if cleared:
		var best: Dictionary = profile.week_best.get(str(k), {})
		var best_stars := int(best.get("stars", 1))
		var best_waves := int(best.get("endless", 0))
		var top_mark := " · 🏅十大功绩" if BattleRecordsSource.is_top_suppression(profile.week_best, k) else ""
		var guest_mark := " · 客卿" if bool(best.get("guest", false)) else ""
		_text("威望 %s%s · 讨伐 +%d波%s%s" % ["★".repeat(best_stars), "☆".repeat(3 - best_stars), best_waves, guest_mark, top_mark], Vector2(58, 580), 13, GOLD)
		_text("城池贡献 %d 势力" % int(best.get("score", 0)), Vector2(58, 603), 12, BLUE)
	else:
		_text("尚未破城 · 威望与讨伐记录为空", Vector2(58, 584), 14, MUTED)
	_panel(STATE_GO_RECT, Color("5a4426"), GOLD, 2.5)
	_text_centered_in_rect("⚔ 进军", STATE_GO_RECT, 20, Color("fff3c4"))

func _rule_names(rules: Array) -> String:
	if rules.is_empty():
		return "无"
	var names := PackedStringArray()
	for rule_id in rules:
		names.append(str(catalog.by_id("level_rules", str(rule_id)).short))
	return "、".join(names)

func _draw_rulers() -> void:
	var city: Dictionary = weekly.make_level(CURRENT_WEEK, selected_city)
	var tri: Dictionary = TRI_DISPLAY[str(city.foes.tri)]
	var counter: Dictionary = TRI_DISPLAY[str(tri.counter)]
	_text_center("点主公", 48, 32, GOLD)
	_text_center("只能带一位；他的三张主公技就是这局的底牌", 78, 14, Color("d5c9a8"))
	_text_center("%s的贼是%s%s，带%s%s克他" % [city.tag, tri.icon, tri.name, counter.icon, counter.name], 108, 15, GREEN)
	for index in RULER_IDS.size():
		var ruler: Dictionary = catalog.by_id("rulers", RULER_IDS[index])
		var rect := _ruler_rect(index)
		var is_guest := BattleRecordsSource.week_guest_lords(CURRENT_WEEK).has(RULER_IDS[index])
		_panel(rect, PANEL_2, Color("5d513c"), 1.5)
		_text(str(ruler.name) + (" · 客卿" if is_guest else ""), Vector2(30, rect.position.y + 27), 21 if not is_guest else 18, GOLD)
		_text(_short_text(str(ruler.desc), 24), Vector2(126, rect.position.y + 26), 13, Color("c9b69a"))
		_text("Lv.%d%s" % [LocalProfileSource.ruler_level(profile, RULER_IDS[index]), " · 讨伐×1.3" if is_guest else ""], Vector2(30, rect.position.y + 49), 12, BLUE)

func _draw_pick() -> void:
	var city: Dictionary = weekly.make_level(CURRENT_WEEK, selected_city)
	var field: Dictionary = catalog.by_id("fields", str(city.field))
	_text_center(str(city.name), 48, 24, GOLD)
	_text_center("%s：%s" % [field.name, field.desc], 78, 13, Color("d5c9a8"))
	_text_center("挑个武将开局", 235, 26, PALE_GOLD)
	for index in opening_hero_ids.size():
		var hero: Dictionary = catalog.by_id("heroes", opening_hero_ids[index])
		var rect := _hero_card_rect(index)
		var tri: Dictionary = TRI_DISPLAY[str(hero.elem)]
		_panel(rect, Color("3a2c17"), tri.color, 3.0)
		draw_circle(Vector2(rect.get_center().x, 335), 28, PANEL)
		draw_arc(Vector2(rect.get_center().x, 335), 29, 0, TAU, 48, tri.color, 2.0)
		_text_centered_in_rect(str(hero.char), Rect2(rect.position.x, 321, rect.size.x, 28), 20, Color.WHITE)
		_text_centered_in_rect(str(hero.name), Rect2(rect.position.x, 363, rect.size.x, 28), 18, PALE_GOLD)
		_text_centered_in_rect("%s%s · %s" % [tri.icon, tri.name, CLASS_NAMES.get(hero.cls, hero.cls)], Rect2(rect.position.x, 394, rect.size.x, 26), 13, Color("d5c9a8"))
		_text_centered_in_rect(str(hero.desc), Rect2(rect.position.x, 426, rect.size.x, 26), 12, BLUE)
	_draw_grid(515)

func _ruler_rect(index: int) -> Rect2:
	return Rect2(16, 144 + index * 73, 448, 64)

func _hero_card_rect(index: int) -> Rect2:
	return Rect2(8 + index * 158, 278, 148, 232)

func _growth_card_rect(index: int) -> Rect2:
	if battle_run != null and battle_run.card_choices.size() >= 5:
		return Rect2(4 + index * 95, 278, 90, 244)
	if battle_run != null and battle_run.card_choices.size() >= 4:
		return Rect2(4 + index * 119, 278, 114, 244)
	return Rect2(8 + index * 158, 278, 148, 244)

func active_bond_text() -> String:
	if battle_run == null:
		return ""
	var names: Array[String] = []
	for bond_id in battle_run.team.active_bond_ids():
		var bond: Dictionary = catalog.by_id("bonds", str(bond_id))
		if not bond.is_empty():
			names.append(str(bond.name))
	return " · ".join(names)

func active_relic_text() -> String:
	if battle_run == null:
		return ""
	var labels: Array[String] = []
	for relic_id in battle_run.relic_ids:
		var relic: Dictionary = catalog.by_id("relics", str(relic_id))
		if not relic.is_empty():
			labels.append(str(relic.icon) + str(relic.name))
	return " ".join(labels)

func active_tactic_text() -> String:
	if battle_run == null:
		return ""
	var labels: Array[String] = []
	var definitions := {
		"luanshi": "🪨乱石穿空", "huoshao": "🔥火烧连营", "zhanshou": "🎯擒贼擒王",
		"luojing": "🕳落井下石", "shuiyan": "🌊水淹七军", "pofu": "🍳破釜沉舟", "gewu": "💃乐不思蜀",
	}
	for tactic_id in definitions:
		if bool(battle_run.permanent_tactics.get(tactic_id, false)):
			labels.append(str(definitions[tactic_id]))
	return " ".join(labels)

func card_draft_heading() -> String:
	if battle_run != null and battle_run.picking_relic:
		return "遗宝！三选一"
	if battle_run != null and battle_run.card_choices.size() >= 5:
		return "门生故吏！五选一"
	return "升级！四选一" if battle_run != null and battle_run.card_choices.size() >= 4 else "升级！三选一"

func _short_text(text: String, max_characters: int) -> String:
	return text if text.length() <= max_characters else text.left(max_characters) + "…"

func _draw_grid(top: float) -> void:
	for row in 3:
		for col in 5:
			var rect := Rect2(40 + col * 80, top + row * 72, 70, 62)
			draw_rect(rect, Color("332a1c"), true)
			draw_rect(rect, Color("54462f"), false, 1.0)
	draw_rect(Rect2(0, top + 216, 480, 69), Color("5b4024"), true)
	_text_center("主公立于城墙 · 阵地15格", top + 258, 14, PALE_GOLD)

func _draw_battle() -> void:
	if battle_run == null:
		_text_center("战场载入中…", 400, 22, PALE_GOLD)
		return
	var city: Dictionary = battle_run.city
	_draw_battle_entities()
	_draw_battle_formation()
	# The Web battlefield spawns enemies above the playfield. Keep that motion,
	# but paint the opaque HUD last so newly spawned units cannot obscure it.
	draw_rect(Rect2(0, 0, 480, 108), INK, true)
	_text("Lv.%d" % battle_run.level, Vector2(14, 30), 22, GOLD)
	_text("第%d波" % battle_run.wave, Vector2(14, 58), 17, PALE_GOLD)
	_text("城防 %d/%d" % [battle_run.wall, battle_run.wall_max], Vector2(116, 28), 14, RED)
	_text("击破 %d / %d" % [battle_run.kills, city.killTarget], Vector2(278, 28), 14, Color.WHITE)
	draw_rect(Rect2(116, 38, 334, 10), Color("433b31"), true)
	draw_rect(Rect2(116, 38, minf(334.0, battle_run.kills / float(city.killTarget) * 334.0), 10), GREEN, true)
	draw_rect(Rect2(14, 70, 436, 8), Color("433b31"), true)
	draw_rect(Rect2(14, 70, minf(436.0, battle_run.xp / maxf(1.0, battle_run.xp_need) * 436.0), 8), BLUE, true)
	_text("经验 %.1f / %.0f" % [battle_run.xp, battle_run.xp_need], Vector2(14, 96), 12, Color("b9dfff"))
	var battle_field: Dictionary = catalog.by_id("fields", str(city.get("field", "")))
	_text(_short_text("%s · %s" % [str(city.name), str(battle_field.get("name", ""))], 13), Vector2(154, 96), 11, BLUE)
	_text("金 %.0f" % battle_run.run_gold, Vector2(316, 96), 11, GOLD)
	_text("固定 2倍速", Vector2(398, 96), 10, PALE_GOLD)
	var foe_offset := 46.0 if not battle_run.foe_lord.is_empty() else 0.0
	if foe_offset > 0:
		_draw_foe_lord_status()
	var field_clear: bool = battle_run.spawn_queue.is_empty() and battle_run.enemies.is_empty()
	draw_rect(Rect2(128, 109 + foe_offset, 224, 27), Color("17120ce6"), true)
	if battle_run.wave == 0 and battle_run.enemies.is_empty():
		_text_center("黄巾来袭 %.1fs" % maxf(0.0, battle_run.wave_timer), 130 + foe_offset, 16, PALE_GOLD)
	elif field_clear:
		var threat := _next_wave_threat_text()
		_text_center(_short_text("下波 %.1fs%s" % [maxf(0.0, battle_run.wave_timer), " · " + threat if not threat.is_empty() else ""], 34), 130 + foe_offset, 14, PALE_GOLD)
	else:
		var pressure_left := maxf(0.0, battle_run.wave_budget - battle_run.wave_clock)
		var pressure_note := ""
		if not battle_run.endless_mod.is_empty(): pressure_note = " · 军令「%s」" % str(battle_run.endless_mod.name)
		elif battle_run.foe_tenacity() < 0.999: pressure_note = " · 攻坚·控效%d%%" % roundi(battle_run.foe_tenacity() * 100.0)
		_text_center(_short_text("第%d波 · 催战 %.1fs%s" % [battle_run.wave, pressure_left, pressure_note], 34), 130 + foe_offset, 14, RED if pressure_left < 5.0 else MUTED)
	var bond_text := active_bond_text()
	if not bond_text.is_empty():
		draw_rect(Rect2(66, 140 + foe_offset, 348, 25), Color("332714e8"), true)
		_text_center("🔗 羁绊：%s" % bond_text, 158 + foe_offset, 13, GOLD)
	var relic_text := active_relic_text()
	if not relic_text.is_empty():
		draw_rect(Rect2(16, 170 + foe_offset, 448, 23), Color("211b12e8"), true)
		_text_center("遗宝：%s" % _short_text(relic_text, 28), 187 + foe_offset, 12, PALE_GOLD)
	var lord_effect := _active_lord_effect_text()
	if not lord_effect.is_empty():
		draw_rect(Rect2(54, 198 + foe_offset, 372, 25), Color("172334e8"), true)
		_text_center(lord_effect, 216 + foe_offset, 13, Color("b9dfff"))
	var tactic_text := active_tactic_text()
	if not tactic_text.is_empty():
		draw_rect(Rect2(12, 226 + foe_offset, 456, 23), Color("2b2115e8"), true)
		_text_center("战术：%s" % _short_text(tactic_text, 32), 243 + foe_offset, 11, PALE_GOLD)
	for event in battle_run.foe_events:
		var definition: Dictionary = battle_run.foe_lord.get("def", {})
		_text_center("%s%s：%s" % [definition.get("icon", "贼"), definition.get("name", "渠帅"), event.text], 286, 18, RED if str(event.kind) == "cast" else Color("ffb08a"))
		if not str(event.get("tip", "")).is_empty():
			_text_center(str(event.tip), 310, 12, Color("c9a8ff"))
	if battle_run.taoyuan_time > 0:
		draw_rect(Rect2(5, 5, 470, 790), Color("ffd27899"), false, 5.0)
		_text_center("桃园金身 · 全军刀枪不入 %.1fs" % battle_run.taoyuan_time, 246, 18, Color("ffe8b0"))
	if battle_run.awaiting_card_choice:
		_draw_growth_cards()
	elif foe_lord_popup_is_visible():
		_draw_foe_lord_popup()
	elif battle_run.status != "play":
		_draw_result()

func _draw_result() -> void:
	draw_rect(Rect2(0, 0, 480, 800), Color("140e06ed"), true)
	var won: bool = battle_run.status == "win"
	var glory: bool = not won and battle_run.win_wave > 0
	_text_center("🎉 大获全胜" if won else ("🎖 虽败犹荣" if glory else "💀 大败而归"), 76, 36, GOLD if won else (Color("ffb84a") if glory else RED))
	var field: Dictionary = catalog.by_id("fields", str(battle_run.city.get("field", "")))
	var extra_waves := maxi(0, battle_run.scored_wave - battle_run.win_wave)
	_text_center("%s · %s · 第%d波%s" % [str(battle_run.city.name), str(field.get("name", "")), battle_run.wave, " · 讨伐+%d波" % extra_waves if glory else ""], 105, 12, MUTED)

	_panel(Rect2(26, 126, 428, 190), Color("211a10"), Color("6c5835"), 1.5)
	_text_center("—— 成绩 ——", 151, 13, MUTED)
	if won:
		var stars_text := "★".repeat(battle_run.stars) + "☆".repeat(3 - battle_run.stars)
		var verdict := "完美通关" if battle_run.stars == 3 else ("城墙受损" if battle_run.wall_hurt else "有武将阵亡")
		_text_center("%s  %s" % [stars_text, verdict], 184, 20, GOLD)
	var best: Dictionary = profile.week_best.get(str(selected_city), {})
	_text("🏅 本城贡献", Vector2(48, 217), 13, Color("a89a76"))
	_text("%d 势力" % int(best.get("score", 0)), Vector2(326, 217), 14, BLUE)
	_text("⚖ 我的势力值", Vector2(48, 245), 13, Color("a89a76"))
	_text("%d" % BattleRecordsSource.week_score(profile.week_best), Vector2(358, 245), 14, BLUE)
	_text("🧠 韬略分", Vector2(48, 269), 13, Color("a89a76"))
	_text("%d" % int(settlement_summary.get("tech_score", profile.week_tech.get(str(selected_city), 0))), Vector2(358, 269), 14, BLUE)
	_text("💰 金币", Vector2(48, 291), 13, Color("a89a76"))
	_text("+%d · 累计 %d%s" % [roundi(battle_run.run_gold) + int(settlement_summary.get("first_clear_gold", 0)) + battle_run.band_gold, int(profile.gold), " · 含跨段%d" % battle_run.band_gold if battle_run.band_gold > 0 else ""], Vector2(246, 291), 13, Color("ffb84a"))
	var lord_xp: Dictionary = settlement_summary.get("lord_xp", {})
	if not lord_xp.is_empty():
		_text("👑 主公经验", Vector2(48, 312), 12, Color("a89a76"))
		_text("+%d · Lv.%d" % [int(lord_xp.get("gain", 0)), int(lord_xp.get("to", 1))], Vector2(332, 312), 13, Color("c9a8ff"))

	_panel(Rect2(26, 330, 428, 174), Color("211a10"), Color("6c5835"), 1.5)
	_text_center("—— 战报 ——", 355, 13, MUTED)
	_text("⚔ 击破", Vector2(48, 389), 13, Color("a89a76")); _text("%d 个贼" % battle_run.kills, Vector2(352, 389), 14, GREEN)
	_text("💢 最重一击", Vector2(48, 418), 13, Color("a89a76")); _text("%d" % battle_run.max_hit, Vector2(366, 418), 14, GREEN)
	_text("💥 绝技施放", Vector2(48, 447), 13, Color("a89a76")); _text("%d 次" % battle_run.ults_used, Vector2(366, 447), 14, GREEN)
	var counter_pct := roundi(battle_run.counter_damage / battle_run.total_damage * 100.0) if battle_run.total_damage > 0 else 0
	_text("☱ 克制伤害占比", Vector2(48, 476), 13, Color("a89a76")); _text("%d%%" % counter_pct, Vector2(366, 476), 14, GREEN if counter_pct >= 35 else PALE_GOLD)

	_panel(Rect2(26, 518, 428, 150), Color("211a10"), Color("6c5835"), 1.5)
	_text_center("—— 阵容 ——", 543, 13, MUTED)
	var unit_names: Array[String] = []
	for unit in battle_run.units(): unit_names.append("%s%d★" % [str(unit.hero.name), int(unit.level)])
	_text(_short_text("出战  " + "  ".join(unit_names), 42), Vector2(44, 578), 12, PALE_GOLD)
	var relic_names: Array[String] = []
	for relic_id in battle_run.relic_ids:
		var relic: Dictionary = catalog.by_id("relics", str(relic_id))
		relic_names.append(str(relic.icon) + str(relic.name))
	_text(_short_text("遗宝  " + "  ".join(relic_names), 42), Vector2(44, 609), 12, GOLD)
	if extra_waves > 0:
		var guest: bool = bool(battle_run.city.get("weekGuest", false))
		_text("讨伐  +%d波 · 讨伐值 %d%s" % [extra_waves, BattleRecordsSource.city_suppression(selected_city, battle_run.stars, extra_waves, guest), " · 客卿×1.3" if guest else ""], Vector2(44, 640), 12, BLUE)

	_panel(RESULT_BTN1, Color("7a3a2a") if won else Color("3a5a2a"), GOLD if won else GREEN, 2.0)
	_text_centered_in_rect("⚔ 继续讨伐——多撑一波分更高" if won else "🗺 回地图，重整旗鼓", RESULT_BTN1, 15, Color.WHITE)
	_panel(RESULT_BTN2, Color("5a4a3a"), PALE_GOLD, 2.0)
	_text_centered_in_rect("🗺 收兵回城（回地图）" if won else "🏠 返回首页", RESULT_BTN2, 15, Color.WHITE)

func _draw_battle_entities() -> void:
	var field: Dictionary = catalog.by_id("fields", str(battle_run.city.get("field", "")))
	var band: Dictionary = field.get("band", {})
	if not band.is_empty():
		var band_y1 := float(band.get("y1", 0.0))
		var band_y2 := float(band.get("y2", 0.0))
		var band_color := Color("5aaaff30") if str(band.get("type", "")) == "water" else Color("7a5b3a45")
		draw_rect(Rect2(0, band_y1, 480, band_y2 - band_y1), band_color, true)
		draw_line(Vector2(0, band_y1), Vector2(480, band_y1), band_color.lightened(0.35), 1.0)
		draw_line(Vector2(0, band_y2), Vector2(480, band_y2), band_color.lightened(0.35), 1.0)
	if not battle_run.flood.is_empty():
		var river_y1 := float(battle_run.flood.y1)
		var river_y2 := float(battle_run.flood.y2)
		draw_rect(Rect2(0, river_y1, 480, river_y2 - river_y1), Color("5aaaff38"), true)
		_text_center("大江横流 · 挨打多%d%% · %.1fs" % [roundi(float(battle_run.flood.amp) * 100.0), float(battle_run.flood.t)], (river_y1 + river_y2) / 2.0 + 4.0, 12, Color("a0d2ff"))
	for ring in battle_run.lord_effect_rings:
		draw_arc(Vector2(float(ring.x), float(ring.y)), float(ring.radius), 0, TAU, 48, Color(str(ring.color)), 2.5)
	for ripple in battle_run.ripples:
		var ripple_color := Color("ff9a5a")
		match str(ripple.kind):
			"heal": ripple_color = Color("8aff9a")
			"haste", "slow": ripple_color = Color("8ad2ff")
			"crit": ripple_color = Color("ffd24a")
			"soothe": ripple_color = Color("bfe8ff")
			"cdr", "sunder": ripple_color = Color("c9a8ff")
		draw_arc(Vector2(float(ripple.x), float(ripple.y)), float(ripple.r), 0, TAU, 48, ripple_color, 2.0)
	if not battle_run.blockade.is_empty():
		var blockade_y := float(battle_run.blockade.y)
		draw_rect(Rect2(28, blockade_y - 5, 424, 10), Color("b8934f"), true)
		_text_center("🚧 虎痴拒马 %.1fs" % float(battle_run.blockade.t), blockade_y - 10, 11, PALE_GOLD)
	for palisade in battle_run.palisades:
		var pal_rect := Rect2(float(palisade.x) - float(palisade.width), float(palisade.y) - 5, float(palisade.width) * 2.0, 10)
		draw_rect(pal_rect, Color("9f7a45"), true)
		draw_rect(pal_rect, Color("e8c96a"), false, 1.5)
	for trap in battle_run.traps:
		draw_circle(Vector2(float(trap.x), float(trap.y)), float(trap.r), Color("7fa34a44"))
		draw_arc(Vector2(float(trap.x), float(trap.y)), float(trap.r), 0, TAU, 20, Color("9adf5a"), 1.5)
		_text_centered_in_rect("伏", Rect2(float(trap.x) - 10, float(trap.y) - 8, 20, 16), 10, Color("d8efaa"))
	for pit in battle_run.fire_pits:
		draw_circle(Vector2(float(pit.x), float(pit.y)), float(pit.r), Color("ff6a2a22"))
		draw_arc(Vector2(float(pit.x), float(pit.y)), float(pit.r), 0, TAU, 28, Color("ff7a3a"), 1.5)
	for turret in battle_run.turrets:
		var turret_pos := Vector2(float(turret.x), float(turret.y))
		draw_circle(turret_pos, 13, Color("70634d"))
		draw_arc(turret_pos, 14, 0, TAU, 24, GOLD, 2.0)
		_text_centered_in_rect("弩", Rect2(turret_pos.x - 10, turret_pos.y - 8, 20, 16), 10, Color.WHITE)
	if not battle_run.death_link.is_empty() and battle_run.death_link.members.size() >= 2:
		var members: Array = battle_run.death_link.members
		for index in members.size() - 1:
			draw_line(Vector2(float(members[index].x), float(members[index].y)), Vector2(float(members[index + 1].x), float(members[index + 1].y)), Color("c9a8ff"), 2.0)
	for projectile in battle_run.projectiles:
		draw_circle(Vector2(float(projectile.x), float(projectile.y)), 4.0, GOLD)
	for projectile in battle_run.enemy_projectiles:
		draw_circle(Vector2(float(projectile.x), float(projectile.y)), 4.5, RED)
		draw_arc(Vector2(float(projectile.x), float(projectile.y)), 6.0, 0, TAU, 16, Color("ffcf9a"), 1.0)
	for lob in battle_run.enemy_lobs:
		var progress := clampf(float(lob.t) / maxf(0.01, float(lob.dur)), 0.0, 1.0)
		var lob_position := Vector2(float(lob.x0), float(lob.y0)).lerp(Vector2(float(lob.x1), float(lob.y1)), progress) - Vector2(0, sin(progress * PI) * 70.0)
		draw_arc(Vector2(float(lob.x1), float(lob.y1)), 70.0, 0, TAU, 40, Color("ff6a3a66"), 1.5)
		draw_circle(lob_position, 7.0, Color("6f5b47"))
	for lob in battle_run.enemy_wall_lobs:
		var progress := clampf(float(lob.t) / maxf(0.01, float(lob.dur)), 0.0, 1.0)
		var lob_position := Vector2(float(lob.x0), float(lob.y0)).lerp(Vector2(float(lob.x1), float(lob.y1)), progress) - Vector2(0, sin(progress * PI) * 90.0)
		draw_arc(Vector2(float(lob.x1), float(lob.y1)), 22.0 - progress * 8.0, 0, TAU, 32, Color(1.0, 0.35, 0.35, 0.4 + progress * 0.5), 2.0)
		draw_line(Vector2(float(lob.x1) - 10, float(lob.y1)), Vector2(float(lob.x1) + 10, float(lob.y1)), RED, 2.0)
		draw_circle(lob_position, 8.0, Color("b8aa96"))
	for charge in battle_run.charges:
		var charge_pos := Vector2(float(charge.x), float(charge.y))
		if bool(charge.get("boulder", false)):
			draw_circle(charge_pos, 18.0, Color("80705d"))
			draw_arc(charge_pos, 20.0, 0, TAU, 28, Color("d8c29a"), 2.0)
		else:
			draw_circle(charge_pos, 10.0, Color("ffe0a0"))
	for event in battle_run.field_events:
		var event_pos := Vector2(float(event.x), float(event.y))
		match str(event.kind):
			"volcano":
				draw_circle(event_pos, 80.0 * float(event.t), Color("ff5a2a33"))
				draw_arc(event_pos, 110.0, 0, TAU, 40, Color("ff8a4a"), 2.0)
			"tower":
				draw_line(Vector2(240, 108), event_pos, Color("ffb05a"), 2.0)
			"boulder":
				draw_line(Vector2(event_pos.x, 42), Vector2(event_pos.x, battle_run.DEFENSE_LINE), Color("c9b89a55"), 2.0)
	for enemy in battle_run.enemies:
		var position := Vector2(float(enemy.x), float(enemy.y))
		var radius := float(enemy.r)
		var tri: Dictionary = TRI_DISPLAY.get(str(enemy.tri), TRI_DISPLAY.badao)
		var special_value = enemy.get("special", null)
		var special := "" if special_value == null else str(special_value)
		var body_color: Color = Color("394632") if not bool(enemy.get("big", false)) else Color("5a3d29")
		if not special.is_empty(): body_color = SPECIAL_COLORS.get(special, body_color).darkened(0.45)
		if bool(enemy.get("boss", false)): body_color = Color("642a24")
		draw_circle(position, radius, body_color)
		draw_arc(position, radius + 1.0, 0, TAU, 32, tri.color, 2.0)
		var enemy_char: String = {"spear": "枪", "cav": "骑", "archer": "弓"}.get(str(enemy.cls), "兵")
		if not special.is_empty(): enemy_char = str(SPECIAL_GLYPHS.get(special, "特"))
		elif bool(enemy.get("boss", false)): enemy_char = str(enemy.get("bossName", "首")).left(1)
		elif enemy.get("affix") != null: enemy_char = str(BattleFoesSource.AFFIXES.get(str(enemy.affix), {"name": "精"}).name).left(1)
		_text_centered_in_rect(enemy_char, Rect2(position.x - radius, position.y - 9, radius * 2, 20), 13, Color.WHITE)
		_text(str(tri.icon), position + Vector2(radius - 7, -radius + 9), 9, tri.color)
		var hp_width := radius * 2.0
		draw_rect(Rect2(position.x - radius, position.y - radius - 7, hp_width, 3), Color("4a211b"), true)
		draw_rect(Rect2(position.x - radius, position.y - radius - 7, hp_width * maxf(0.0, float(enemy.hp) / maxf(1.0, float(enemy.hp_max))), 3), RED, true)
		if float(enemy.get("shield", 0.0)) > 0:
			draw_arc(position, radius + 4.0, 0, TAU, 30, Color("8ad2ff"), 2.5)
		if bool(enemy.get("_guarded", false)):
			draw_arc(position, radius + 7.0, 0, TAU, 30, Color("ff6a5a99"), 2.0)
		if not special.is_empty() and float(enemy.get("silencedT", 0.0)) <= 0:
			if special == "healer": draw_arc(position, 110.0, 0, TAU, 48, Color("8aff9a44"), 1.0)
			elif special == "banner": draw_arc(position, 120.0, 0, TAU, 48, Color("ffd24a44"), 1.0)
			elif special == "warden": draw_arc(position, 130.0, 0, TAU, 48, Color("ff6a5a44"), 1.0)
		var kit_value = enemy.get("kit", null)
		if bool(enemy.get("boss", false)) and kit_value != null and not str(kit_value).is_empty():
			var kit_name := str(BattleFoesSource.KIT_NAMES.get(str(kit_value), str(kit_value)))
			_text_centered_in_rect(kit_name, Rect2(position.x - 42, position.y + radius + 3, 84, 15), 9, Color("ffb84a"))
		if float(enemy.get("stunT", 0.0)) > 0:
			_text_centered_in_rect("晕", Rect2(position.x - 10, position.y - radius - 24, 20, 16), 10, Color("b9e8ff"))
		elif float(enemy.get("burnT", 0.0)) > 0:
			_text_centered_in_rect("火", Rect2(position.x - 10, position.y - radius - 24, 20, 16), 10, Color("ff9a5a"))
		var control_mark := ""
		var control_color := Color("b9e8ff")
		if float(enemy.get("sleepT", 0.0)) > 0:
			control_mark = "眠"; control_color = Color("bfe8ff")
		elif float(enemy.get("fearT", 0.0)) > 0:
			control_mark = "惧"; control_color = GOLD
		elif float(enemy.get("charmT", 0.0)) > 0:
			control_mark = "魅"; control_color = Color("ff9ad2")
		elif float(enemy.get("silencedT", 0.0)) > 0:
			control_mark = "封"; control_color = Color("c9a8ff")
		if not control_mark.is_empty():
			_text_centered_in_rect(control_mark, Rect2(position.x - 10, position.y - radius - 39, 20, 16), 10, control_color)
	for trace in battle_run.lord_attack_traces:
		draw_line(Vector2(float(trace.x1), float(trace.y1)), Vector2(float(trace.x2), float(trace.y2)), Color(str(trace.color)), 3.0)
	for event in battle_run.lord_command_events:
		var command: Dictionary = BattleLordSource.COMMANDS.get(str(event.id), {})
		if not command.is_empty():
			_text_center("主公号令 · %s！" % command.name, 264, 20, GOLD)

	for event in battle_run.ult_events:
		var event_color: Color = {"dmg": Color("ff9a5a"), "ctrl": Color("8ad2ff"), "def": Color("9adf5a"), "util": Color("c9a8ff"), "exec": GOLD}.get(str(event.type), GOLD)
		_text_center("绝技【%s】" % str(event.name), 238, 20, event_color)

func _next_wave_threat_text() -> String:
	if battle_run == null or battle_run.next_wave_preview.is_empty(): return ""
	var preview: Dictionary = battle_run.next_wave_preview
	var parts := []
	var endless_rule: Dictionary = battle_run.endless_pending if not battle_run.endless_pending.is_empty() else battle_run.endless_mod
	if not endless_rule.is_empty():
		parts.append("下波军令「%s」" % str(endless_rule.name) if not battle_run.endless_pending.is_empty() else "军令「%s」生效" % str(endless_rule.name))
	var mutation_id := str(preview.get("mutation", ""))
	if not mutation_id.is_empty():
		var mutation: Dictionary = catalog.content.get("mutations", {}).get(mutation_id, {})
		parts.append("%s%s%s" % [str(mutation.get("icon", "")), str(mutation.get("name", mutation_id)), "·金+50%" if battle_run.relic_ids.has("tongque") and not bool(mutation.get("good", false)) else ""])
	if battle_run.relic_ids.has("tongque"):
		var warning_id := str(battle_run.mutations.get(battle_run.wave + 2, ""))
		if not warning_id.is_empty():
			var warning: Dictionary = catalog.content.get("mutations", {}).get(warning_id, {})
			if not bool(warning.get("good", false)):
				parts.append("铜雀预警%d波·%s" % [battle_run.wave + 2, str(warning.get("name", warning_id))])
	for special_id in preview.get("specials", {}).keys():
		var special_def: Dictionary = BattleFoesSource.SPECIALS.get(str(special_id), {})
		parts.append("%s×%d" % [special_def.get("name", special_id), int(preview.specials[special_id])])
	for affix_id in preview.get("affixes", {}).keys():
		var affix_def: Dictionary = BattleFoesSource.AFFIXES.get(str(affix_id), {})
		parts.append("%s×%d" % [affix_def.get("name", affix_id), int(preview.affixes[affix_id])])
	if not str(preview.get("boss", "")).is_empty(): parts.append("贼首%s" % str(preview.boss))
	return " / ".join(parts)

func _draw_battle_formation() -> void:
	for row in BattleRunSource.GRID_ROWS:
		for col in BattleRunSource.GRID_COLS:
			var key := "%d,%d" % [row, col]
			var rect := Rect2(BattleRunSource.GRID_X + col * BattleRunSource.CELL + 2, BattleRunSource.GRID_Y + row * BattleRunSource.CELL + 2, BattleRunSource.CELL - 4, BattleRunSource.CELL - 4)
			draw_rect(rect, Color("30281d"), true)
			draw_rect(rect, Color("54462f"), false, 1.0)
			if battle_run.traits.has(key):
				_text(str(battle_run.traits[key]).left(1).to_upper(), rect.position + Vector2(5, 14), 9, MUTED)
			if battle_run.obstacles.has(key):
				draw_circle(rect.get_center(), 24, Color("50493d"))
				draw_arc(rect.get_center(), 25, 0, TAU, 28, Color("756b58"), 2)
				_text_centered_in_rect("岩", Rect2(rect.position.x, rect.position.y + 27, rect.size.x, 24), 16, Color("c4b99f"))
				continue
			var unit = battle_run.grid[row][col]
			if unit == null:
				continue
			var hero: Dictionary = unit.hero
			var tri: Dictionary = TRI_DISPLAY.get(str(hero.elem), TRI_DISPLAY.badao)
			var center := rect.get_center()
			var class_color: Color = CLASS_COLORS.get(str(hero.cls), Color("435064"))
			draw_circle(center, 27, class_color.darkened(0.25))
			draw_arc(center, 28, 0, TAU, 36, tri.color, 2.5)
			var ult: Dictionary = battle_run.ult_system.definition(str(hero.id))
			if not ult.is_empty():
				var ult_max: float = maxf(0.01, battle_run.ult_system.cooldown_max(battle_run, unit))
				var ult_progress := 1.0 - clampf(float(unit.get("ultCd", 0.0)) / ult_max, 0.0, 1.0)
				var ult_color: Color = {"dmg": Color("ff8a5a"), "ctrl": Color("6ad2ff"), "def": Color("9adf5a"), "util": Color("c9a8ff"), "exec": GOLD}.get(str(ult.type), GOLD)
				if ult_progress >= 0.999:
					draw_arc(center, 31, 0, TAU, 40, ult_color, 4.0)
				elif ult_progress > 0.01:
					draw_arc(center, 31, -PI / 2.0, -PI / 2.0 + TAU * ult_progress, 32, ult_color, 3.0)
			_text_centered_in_rect(str(hero.char), Rect2(rect.position.x, rect.position.y + 26, rect.size.x, 24), 18, Color.WHITE)
			_text_centered_in_rect(str(hero.name), Rect2(rect.position.x, rect.position.y + 50, rect.size.x, 17), 10, PALE_GOLD)
			var unit_hp_ratio := maxf(0.0, float(unit.hp) / maxf(1.0, float(unit.hp_max)))
			draw_rect(Rect2(rect.position.x + 6, rect.position.y + 67, rect.size.x - 12, 4), Color("4a211b"), true)
			draw_rect(Rect2(rect.position.x + 6, rect.position.y + 67, (rect.size.x - 12) * unit_hp_ratio, 4), GREEN, true)
			_text("★".repeat(int(unit.level)), rect.position + Vector2(4, 77), 8, GOLD)
			if float(unit.get("sealedT", 0.0)) > 0:
				draw_rect(rect, Color("7f38b855"), true)
				_text_centered_in_rect("🌀封 %.1fs" % float(unit.sealedT), Rect2(rect.position.x, rect.position.y + 25, rect.size.x, 20), 11, Color("e0b0ff"))
	draw_rect(Rect2(0, BattleRunSource.DEFENSE_LINE, 480, 800 - BattleRunSource.DEFENSE_LINE), Color("5b4024"), true)
	var ruler: Dictionary = catalog.by_id("rulers", battle_run.ruler_id)
	if battle_run.lord_mount.is_empty():
		draw_circle(Vector2(240, 772), 18, Color("6a4a2a"))
		draw_arc(Vector2(240, 772), 19, 0, TAU, 32, GOLD if battle_run.lord_kin_power() > 1.0 else PALE_GOLD, 2.0)
		_text_centered_in_rect("主", Rect2(224, 762, 32, 20), 13, Color.WHITE)
	else:
		var mount_pos := Vector2(float(battle_run.lord_mount.x), float(battle_run.lord_mount.y))
		draw_circle(mount_pos, 21, Color("e8f4ff55"))
		draw_arc(mount_pos, 22, 0, TAU, 32, GOLD, 2.0)
		_text_centered_in_rect("骑", Rect2(mount_pos.x - 16, mount_pos.y - 9, 32, 20), 13, Color.WHITE)
	_text("主公：%s Lv.%d" % [ruler.name, battle_run.ruler_level], Vector2(12, 774), 12, PALE_GOLD)
	var command: Dictionary = BattleLordSource.COMMANDS.get(battle_run.lord_skill_id, {})
	if not command.is_empty():
		var command_ready: bool = battle_run.lord_command_cd <= 0 and not bool(battle_run.permanent_tactics.get("gewu", false))
		var auto_ready: bool = command_ready and battle_run.lord_command_auto_ready()
		draw_rect(LORD_COMMAND_RECT, Color("25311f") if command_ready else Color("352e26"), true)
		draw_rect(LORD_COMMAND_RECT, GREEN if command_ready else MUTED, false, 1.5)
		_text_centered_in_rect(str(command.name), Rect2(326, 755, 142, 17), 12, GOLD if command_ready else PALE_GOLD)
		var cooldown_text := "自动待发" if auto_ready else ("点击施放" if command_ready else ("CD %.1fs" % battle_run.lord_command_cd if battle_run.lord_command_cd > 0 else "号令罢工"))
		_text_centered_in_rect(cooldown_text, Rect2(326, 773, 142, 16), 10, GREEN if command_ready else MUTED)

func _active_lord_effect_text() -> String:
	if battle_run == null:
		return ""
	if bool(battle_run.permanent_tactics.get("gewu", false)):
		return "🍷乐不思蜀 · 全军攻击+30% · 自动抽卡 · 点屏回神"
	if battle_run.wuxing_time > 0:
		return "三才破敌 %.1fs · 被克免罚 + 全军伤害+15%%" % battle_run.wuxing_time
	if battle_run.taoyuan_time > 0:
		return "桃园义 %.1fs · 已扛 %.0f 伤" % [battle_run.taoyuan_time, battle_run.taoyuan_absorb]
	if not battle_run.flood.is_empty():
		return "截江断流 %.1fs · 江中减速40%%" % float(battle_run.flood.t)
	if battle_run.wide_picks > 0:
		return "门生故吏 · 五选一 ×%d" % battle_run.wide_picks
	if battle_run.tyranny > 0:
		return "暴政印记 · 全军攻击+%d%%" % roundi(battle_run.tyranny)
	return ""

func _draw_foe_lord_status() -> void:
	var state: Dictionary = battle_run.foe_lord
	var definition: Dictionary = state.def
	draw_rect(Rect2(0, 108, 480, 43), Color("4a2c20"), true)
	for x in range(4, 480, 40):
		draw_rect(Rect2(x, 108, 24, 7), Color("6a4934"), true)
	draw_circle(Vector2(240, 127), 16, Color("642a24"))
	draw_arc(Vector2(240, 127), 17, 0, TAU, 28, RED if battle_run.wave >= 8 and float(state.drawT) <= 10.0 else Color("ffb08a"), 2.0)
	_text_centered_in_rect(str(definition.name).left(1), Rect2(224, 118, 32, 20), 13, Color("ffd2b8"))
	_text("%s %s·%s" % [definition.icon, definition.name, definition.title], Vector2(10, 138), 11, Color("ffd2b8"))
	_text(foe_lord_status_text(), Vector2(310, 130), 10, RED if bool(state.told) else Color("ffc9a8"))
	_text("点渠帅查看10张牌", Vector2(310, 145), 9, MUTED)
	if battle_run.foe_curse_time > 0:
		_text("咒缚 %.1fs" % battle_run.foe_curse_time, Vector2(10, 150), 9, Color("d4a0ff"))
	elif battle_run.foe_rage_time > 0:
		_text("贼胆 %.1fs" % battle_run.foe_rage_time, Vector2(10, 150), 9, RED)

func foe_card_rows() -> Array:
	if battle_run == null or battle_run.foe_lord.is_empty():
		return []
	var counts := {}
	for card_id in battle_run.foe_lord.def.get("deck", []):
		counts[card_id] = int(counts.get(card_id, 0)) + 1
	var rows := []
	for card_id in counts:
		rows.append({"id": str(card_id), "count": int(counts[card_id]), "card": catalog.content.get("foe_cards", {}).get(card_id, {})})
	rows.sort_custom(func(a, b):
		if int(a.count) != int(b.count):
			return int(a.count) > int(b.count)
		return str(a.id) < str(b.id)
	)
	return rows

func foe_lord_status_text() -> String:
	if battle_run == null or battle_run.foe_lord.is_empty():
		return ""
	var state: Dictionary = battle_run.foe_lord
	if battle_run.wave < 8:
		return "第8波开手"
	if not bool(state.told):
		return "下一手 %.0fs" % float(state.drawT)
	var next_card: Dictionary = catalog.content.get("foe_cards", {}).get(battle_run.foe_system.next_card_id(battle_run), {})
	return "%.0fs后「%s」" % [float(state.drawT), next_card.get("name", "未知")]

func foe_lord_popup_is_visible() -> bool:
	return foe_lord_popup and battle_run != null and battle_run.status == "play"

func _draw_foe_lord_popup() -> void:
	var rows := foe_card_rows()
	var height := 104.0 + rows.size() * 26.0
	var rect := Rect2(36, 150, 408, height)
	draw_rect(Rect2(0, 0, 480, 800), Color(0, 0, 0, 0.72), true)
	_panel(rect, Color("17100cee"), Color("ff8a6a"), 2.0)
	var definition: Dictionary = battle_run.foe_lord.def
	_text_center("%s %s·%s" % [definition.icon, definition.name, definition.title], 178, 18, RED)
	_text_center("整套10张·抽完重洗·出牌前30秒亮牌", 204, 11, MUTED)
	var y := 232.0
	for row in rows:
		var card: Dictionary = row.card
		_text("「%s」×%d" % [card.get("name", row.id), row.count], Vector2(54, y), 12, PALE_GOLD)
		_text(str(card.get("tip", "")), Vector2(190, y), 10, Color("b8a888"))
		y += 26.0
	_text_center("点任意处关闭", rect.end.y - 10.0, 10, MUTED)

func _draw_growth_cards() -> void:
	draw_rect(Rect2(0, 0, 480, 800), Color(0, 0, 0, 0.76), true)
	_text_center("🍷 乐不思蜀·自动抽卡中…" if bool(battle_run.permanent_tactics.get("gewu", false)) else card_draft_heading(), 226, 28, GOLD)
	_text_center("战斗已暂停", 252, 13, Color("d5c9a8"))
	for index in battle_run.card_choices.size():
		var card: Dictionary = battle_run.card_choices[index]
		var rect := _growth_card_rect(index)
		_panel(rect, Color("332714"), PALE_GOLD, 2.5)
		_text_centered_in_rect(str(card.get("icon", "策")), Rect2(rect.position.x, rect.position.y + 25, rect.size.x, 40), 28, GOLD)
		_text_centered_in_rect(_short_text(str(card.title), 8), Rect2(rect.position.x + 4, rect.position.y + 78, rect.size.x - 8, 28), 16, Color.WHITE)
		_text_centered_in_rect(_short_text(str(card.get("desc", "")), 11), Rect2(rect.position.x + 8, rect.position.y + 126, rect.size.x - 16, 38), 12, BLUE)
		_text_centered_in_rect("点击选择", Rect2(rect.position.x, rect.end.y - 38, rect.size.x, 24), 12, PALE_GOLD)
