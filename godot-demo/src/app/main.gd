extends Control

const VIEW_SIZE := Vector2(480.0, 800.0)
const GOLD := Color("ffe45a")
const PALE_GOLD := Color("e8c86a")
const INK := Color("17120c")
const PANEL := Color("241c10")
const PANEL_2 := Color("332714")
const MUTED := Color("8a7d5a")
const GREEN := Color("7ad86a")
const BLUE := Color("62b8ff")
const RED := Color("ff8a6a")

const RULERS := [
    ["caocao", "曹操", "三才破敌 · 屯田制"],
    ["liubei", "刘备", "桃园义 · 双股剑气"],
    ["sunquan", "孙权", "截江断流 · 水军都督"],
    ["yuanshao", "袁绍", "门生故吏 · 五选一"],
    ["liubiao", "刘表", "冰封 · 养龙术"],
    ["gongsunzan", "公孙瓒", "白马义从 · 斩将记功"],
    ["dongzhuo", "董卓", "火烧雒阳 · 燃魂"],
    ["yuanshu", "袁术", "僭号称帝 · 帝业吃人"],
]

const HEROES := [
    ["jiangwei", "姜维", "良谋系 · 骑兵"],
    ["zhangliao", "张辽", "良谋系 · 骑兵"],
    ["xuchu", "许褚", "霸道系 · 枪兵"],
]

const CITY_POSITIONS := [
    Vector2(155, 630), Vector2(340, 610), Vector2(80, 550), Vector2(245, 535),
    Vector2(390, 500), Vector2(125, 455), Vector2(285, 435), Vector2(70, 365),
    Vector2(225, 350), Vector2(385, 335), Vector2(145, 270), Vector2(315, 250),
    Vector2(80, 185), Vector2(235, 170), Vector2(385, 160), Vector2(300, 95),
]

var phase := "title"
var selected_city := -1
var selected_ruler := ""
var selected_hero := ""
var battle_time := 0.0
var battle_tick := 0.0
var kills := 0
var level := 1

func _ready() -> void:
    set_process(true)
    queue_redraw()

func advance_from_title() -> void:
    phase = "map"
    queue_redraw()

func select_city(index: int) -> void:
    selected_city = index
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
            if point.distance_to(CITY_POSITIONS[0]) <= 42.0:
                select_city(0)
        "ruler":
            if point.x >= 16.0 and point.x <= 464.0 and point.y >= 144.0 and point.y < 728.0:
                var index := int((point.y - 144.0) / 73.0)
                if index >= 0 and index < RULERS.size():
                    select_ruler(RULERS[index][0])
        "pick":
            if point.y >= 278.0 and point.y <= 510.0:
                var index := int(point.x / 160.0)
                if index >= 0 and index < HEROES.size():
                    select_opening_hero(HEROES[index][0])

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), INK)
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

func _draw_title() -> void:
    _text_center("不一样三国  2.0", 278, 43, GOLD)
    _text_center("守城塔防 · 肉鸽点将", 340, 26, PALE_GOLD)
    _text_center("天下争夺 · 每周一全服换图 · 64座城池逐城攻取", 430, 15, Color("d5c9a8"))
    _text_center("克制这城贼的那一系才打得疼", 470, 17, GREEN)
    _text_center("贼军不等人：下一波会直接压上来", 510, 16, RED)
    _text_center("破城后可继续讨伐，十大功绩计入势力", 550, 16, BLUE)
    _text_center("点击空白处出征", 690, 24, PALE_GOLD)
    _text_center("Godot 4.7 纵向切片", 760, 12, MUTED)

func _draw_map() -> void:
    _text_center("讨城地图 · 第3期", 45, 28, GOLD)
    _text_center("运营帷幄：特种多 · 勤放主公技", 74, 15, PALE_GOLD)
    _text_center("四区各16城 · 当前东部 0/16", 103, 14, Color("d5c9a8"))
    for index in CITY_POSITIONS.size():
        var unlocked := index == 0
        var color := GOLD if unlocked else Color("5a513e")
        draw_circle(CITY_POSITIONS[index], 27.0, PANEL_2)
        draw_arc(CITY_POSITIONS[index], 28.0, 0.0, TAU, 48, color, 3.0)
        var label := "交州" if index == 0 else "城"
        draw_string(_font(), CITY_POSITIONS[index] + Vector2(-22, 6), label, HORIZONTAL_ALIGNMENT_CENTER, 44, 14, color)
    _panel(Rect2(16, 715, 106, 42), PANEL_2, GOLD)
    _panel(Rect2(128, 715, 106, 42), PANEL_2, MUTED)
    _panel(Rect2(240, 715, 106, 42), PANEL_2, MUTED)
    _panel(Rect2(352, 715, 112, 42), PANEL_2, MUTED)
    _text("东部", Vector2(52, 742), 15, GOLD)
    _text("南部", Vector2(164, 742), 15, MUTED)
    _text("西部", Vector2(276, 742), 15, MUTED)
    _text("北部", Vector2(388, 742), 15, MUTED)

func _draw_rulers() -> void:
    _text_center("点主公", 48, 32, GOLD)
    _text_center("只能带一位，他的招牌技和被动就是这局底牌", 78, 14, Color("d5c9a8"))
    _text_center("交州贼是仁德，良谋克他", 108, 15, GREEN)
    for index in RULERS.size():
        var rect := Rect2(16, 144 + index * 73, 448, 64)
        _panel(rect, PANEL_2, Color("5d513c"), 1.5)
        _text(RULERS[index][1], Vector2(30, rect.position.y + 27), 21, GOLD)
        _text(RULERS[index][2], Vector2(132, rect.position.y + 26), 14, Color("c9b69a"))
        _text("Lv.1", Vector2(30, rect.position.y + 49), 12, BLUE)

func _draw_pick() -> void:
    _text_center("交州 · 汝南剿匪 · 赤壁水岸", 48, 24, GOLD)
    _text_center("敌人过江慢40%，火烧+50%", 78, 14, Color("d5c9a8"))
    _text_center("挑个武将开局", 235, 26, PALE_GOLD)
    for index in HEROES.size():
        var rect := Rect2(8 + index * 158, 278, 148, 232)
        _panel(rect, Color("3a2c17"), BLUE if index < 2 else GREEN, 3.0)
        draw_circle(Vector2(rect.get_center().x, 335), 28, PANEL)
        draw_arc(Vector2(rect.get_center().x, 335), 29, 0, TAU, 48, BLUE if index < 2 else GREEN, 2)
        _text_centered_in_rect(HEROES[index][1], Rect2(rect.position.x, 329, rect.size.x, 28), 18, PALE_GOLD)
        _text_centered_in_rect(HEROES[index][2], Rect2(rect.position.x, 382, rect.size.x, 32), 13, Color("d5c9a8"))
        _text_centered_in_rect("图鉴 1级", Rect2(rect.position.x, 430, rect.size.x, 24), 13, BLUE)
    _draw_grid(515)

func _text_centered_in_rect(text: String, rect: Rect2, size: int, color: Color) -> void:
    draw_string(_font(), Vector2(rect.position.x, rect.position.y + size), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)

func _draw_grid(top: float) -> void:
    for row in 3:
        for col in 5:
            var rect := Rect2(40 + col * 80, top + row * 72, 70, 62)
            draw_rect(rect, Color("332a1c"), true)
            draw_rect(rect, Color("54462f"), false, 1.0)
    draw_rect(Rect2(0, top + 216, 480, 69), Color("5b4024"), true)
    _text_center("主公立于城墙 · 阵地15格", top + 258, 14, PALE_GOLD)

func _draw_battle() -> void:
    _text("Lv.%d" % level, Vector2(18, 36), 24, GOLD)
    _text("第1波", Vector2(18, 69), 20, PALE_GOLD)
    _text("击破 %d / 450" % kills, Vector2(170, 34), 17, Color.WHITE)
    draw_rect(Rect2(170, 43, 280, 12), Color("433b31"), true)
    draw_rect(Rect2(170, 43, min(280.0, kills / 450.0 * 280.0), 12), GREEN, true)
    _text("赤壁水岸", Vector2(18, 114), 14, BLUE)
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
    _text(selected_hero if selected_hero else "武将", hero_pos + Vector2(-22, 6), 13, Color.WHITE)
    _text("自动迎敌 · 2倍速", Vector2(270, 755), 14, PALE_GOLD)
    _text("主公：%s" % selected_ruler, Vector2(18, 780), 12, MUTED)
