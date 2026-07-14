extends Control

const ContentCatalogSource = preload("res://src/content/content_catalog.gd")
const WeeklyMapSource = preload("res://src/progression/weekly_map.gd")

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
const OPENING_HERO_IDS := ["jiangwei", "zhangliao", "xuchu"]
const REGION_NAMES := ["东部", "南部", "西部", "北部"]
const CLASS_NAMES := {"cav": "骑兵", "spear": "枪兵", "archer": "弓兵", "mage": "谋士"}
const TRI_DISPLAY := {
	"badao": {"name": "霸道", "icon": "✊", "color": Color("ff6b4a"), "counter": "rende"},
	"liangmou": {"name": "良谋", "icon": "✌", "color": Color("4aa8ff"), "counter": "badao"},
	"rende": {"name": "仁德", "icon": "✋", "color": Color("7ad86a"), "counter": "liangmou"},
}
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

var catalog
var weekly
var phase := "title"
var selected_city := -1
var selected_ruler := ""
var selected_hero := ""
var current_region := 0
var state_popup := -1
var week_clears: Dictionary = {}
var map_message := ""
var battle_time := 0.0
var battle_tick := 0.0
var kills := 0
var level := 1

func _ready() -> void:
	catalog = ContentCatalogSource.new()
	var error: Error = catalog.load_from("res://data/content-v7.19.2.json")
	if error != OK:
		push_error("Unable to load v7.19.2 content catalog: %s" % error_string(error))
		set_process(false)
		return
	weekly = WeeklyMapSource.new(catalog)
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
	phase = "pick"
	queue_redraw()

func select_opening_hero(hero_id: String) -> void:
	selected_hero = hero_id
	phase = "battle"
	battle_time = 0.0
	battle_tick = 0.0
	kills = 0
	level = 1
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
	if phase != "battle":
		return
	battle_time += delta
	battle_tick += delta
	if battle_tick >= 0.45:
		battle_tick -= 0.45
		kills += 1 + int(level / 3)
		if kills >= level * 8:
			level = mini(level + 1, 15)
	queue_redraw()

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
			for index in OPENING_HERO_IDS.size():
				if _hero_card_rect(index).has_point(point):
					select_opening_hero(OPENING_HERO_IDS[index])
					return

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
	_text("已破城 · 本地战绩已记录" if cleared else "尚未破城 · 威望与讨伐记录为空", Vector2(58, 584), 14, GREEN if cleared else MUTED)
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
		_panel(rect, PANEL_2, Color("5d513c"), 1.5)
		_text(str(ruler.name), Vector2(30, rect.position.y + 27), 21, GOLD)
		_text(_short_text(str(ruler.desc), 24), Vector2(126, rect.position.y + 26), 13, Color("c9b69a"))
		_text("Lv.1", Vector2(30, rect.position.y + 49), 12, BLUE)

func _draw_pick() -> void:
	var city: Dictionary = weekly.make_level(CURRENT_WEEK, selected_city)
	var field: Dictionary = catalog.by_id("fields", str(city.field))
	_text_center(str(city.name), 48, 24, GOLD)
	_text_center("%s：%s" % [field.name, field.desc], 78, 13, Color("d5c9a8"))
	_text_center("挑个武将开局", 235, 26, PALE_GOLD)
	for index in OPENING_HERO_IDS.size():
		var hero: Dictionary = catalog.by_id("heroes", OPENING_HERO_IDS[index])
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
	var city: Dictionary = weekly.make_level(CURRENT_WEEK, selected_city)
	var hero: Dictionary = catalog.by_id("heroes", selected_hero)
	_text("Lv.%d" % level, Vector2(18, 36), 24, GOLD)
	_text("第1波", Vector2(18, 69), 20, PALE_GOLD)
	_text("击破 %d / %d" % [kills, city.killTarget], Vector2(170, 34), 17, Color.WHITE)
	draw_rect(Rect2(170, 43, 280, 12), Color("433b31"), true)
	draw_rect(Rect2(170, 43, min(280.0, kills / float(city.killTarget) * 280.0), 12), GREEN, true)
	_text(str(city.name), Vector2(18, 114), 14, BLUE)
	for index in 7:
		var x := 48.0 + float((index * 67) % 390)
		var y := 145.0 + fmod(battle_time * 48.0 + index * 61.0, 260.0)
		draw_circle(Vector2(x, y), 20, Color("4f7f3f"))
		draw_arc(Vector2(x, y), 21, 0, TAU, 32, GREEN, 2)
		_text("兵", Vector2(x - 11, y + 7), 16, Color.WHITE)
	_draw_grid(490)
	var hero_pos := Vector2(150, 638)
	draw_circle(hero_pos, 31, Color("3c5572"))
	draw_arc(hero_pos, 32, 0, TAU, 48, BLUE, 3)
	_text(str(hero.name), hero_pos + Vector2(-22, 6), 13, Color.WHITE)
	_text("自动迎敌 · 2倍速", Vector2(270, 755), 14, PALE_GOLD)
	_text("主公：%s" % catalog.by_id("rulers", selected_ruler).name, Vector2(18, 780), 12, MUTED)
