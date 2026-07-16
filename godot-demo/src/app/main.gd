extends Control

const ContentCatalogSource = preload("res://src/content/content_catalog.gd")
const WeeklyMapSource = preload("res://src/progression/weekly_map.gd")
const OpeningPickerSource = preload("res://src/progression/opening_picker.gd")
const Mulberry32Source = preload("res://src/core/mulberry32.gd")
const BattleRunSource = preload("res://src/battle/battle_run.gd")
const BattleLordSource = preload("res://src/battle/battle_lord.gd")
const BattleFoesSource = preload("res://src/battle/battle_foes.gd")
const BattleUltsSource = preload("res://src/battle/battle_ults.gd")
const BattleRecordsSource = preload("res://src/progression/battle_records.gd")
const LocalProfileSource = preload("res://src/progression/local_profile.gd")
const RunSettlementSource = preload("res://src/progression/run_settlement.gd")
const HeroProgressionSource = preload("res://src/progression/hero_progression.gd")
const VisitSystemSource = preload("res://src/progression/visit_system.gd")
const AchievementProgressSource = preload("res://src/progression/achievement_progress.gd")
const BattleDragControllerSource = preload("res://src/input/battle_drag_controller.gd")
const ShenRotationSource = preload("res://src/progression/shen_rotation.gd")

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
const ACH_GROUPS := ["战功", "讨伐", "养成", "奇趣"]
const REGION_NAMES := ["东部", "南部", "西部", "北部"]
const CLASS_NAMES := {"cav": "骑兵", "spear": "枪兵", "archer": "弓兵", "mage": "谋士"}
const CLASS_COLORS := {
	"spear": Color("8b4b3b"), "cav": Color("66502f"), "archer": Color("365d43"),
	"shield": Color("455b73"), "support": Color("65466f"), "granary": Color("76623b"),
}
const BATTLE_CLASS_DISPLAY := {
	"spear": {"icon": "🔱", "color": Color("6fd44e")},
	"cav": {"icon": "🐎", "color": Color("4ab0ff")},
	"archer": {"icon": "🏹", "color": Color("ff6b4a")},
	"shield": {"icon": "🛡", "color": Color("e8c96a")},
	"support": {"icon": "🎐", "color": Color("d97bff")},
	"granary": {"icon": "🌾", "color": Color("e8c86a")},
	"egg": {"icon": "🥚", "color": Color("c9a8ff")},
	"dragon": {"icon": "🐉", "color": Color("8ad2ff")},
}
const TRAIT_DISPLAY := {
	"atk": {"icon": "⚔️", "name": "沃土", "desc": "伤害+15%"},
	"haste": {"icon": "⚡", "name": "风口", "desc": "出手快+12%"},
	"guard": {"icon": "🛡️", "name": "坚岩", "desc": "少挨打20%"},
	"heal": {"icon": "💧", "name": "灵泉", "desc": "回血翻倍"},
	"crit": {"icon": "🎯", "name": "高台", "desc": "多10%机会双倍暴击"},
	"elem": {"icon": "🔮", "name": "灵脉", "desc": "站这打谁都算克制(怕!)"},
}
const DRAG_TRAIT_COPY := {
	"atk": {"icon": "⚔️", "name": "沃土", "desc": "伤害+15%"},
	"haste": {"icon": "⚡", "name": "风口", "desc": "出手快+12%"},
	"guard": {"icon": "🛡️", "name": "坚岩", "desc": "少挨打20%"},
	"heal": {"icon": "💧", "name": "灵泉", "desc": "回血翻倍"},
	"crit": {"icon": "🎯", "name": "高台", "desc": "多10%机会双倍暴击"},
	"elem": {"icon": "🔮", "name": "灵脉", "desc": "站这打谁都算克制(怕!)"},
}
const UNIT_CLASS_COPY := {
	"spear": {"icon": "🔱", "name": "枪兵"},
	"cav": {"icon": "🐎", "name": "骑兵"},
	"archer": {"icon": "🏹", "name": "弓兵"},
	"shield": {"icon": "🛡️", "name": "盾兵"},
	"support": {"icon": "🎐", "name": "辅兵"},
	"granary": {"icon": "🌾", "name": "粮仓"},
	"egg": {"icon": "🥚", "name": "龙蛋"},
	"dragon": {"icon": "🐉", "name": "神兽"},
}
const UNIT_ELEMENT_COPY := {
	"badao": {"icon": "✊", "name": "霸道", "color": Color("ff6b4a")},
	"liangmou": {"icon": "✌️", "name": "良谋", "color": Color("4aa8ff")},
	"rende": {"icon": "✋", "name": "仁德", "color": Color("7ad86a")},
}
const ULT_PRESENTATION := {
	"zhangfei": {"desc": "吼一嗓子推飞一圈", "condition": "跟前敌人≥3"},
	"zhaoyun": {"desc": "扇形连刺14枪", "condition": "跟前有敌人"},
	"machao": {"desc": "一道雷劈中再分两叉", "condition": "跟前敌人≥2"},
	"huangzhong": {"desc": "狙掉场上最肉的", "condition": "场上有大怪"},
	"xiahouyuan": {"desc": "大箭弹墙来回扫", "condition": "敌人≥5"},
	"luxun": {"desc": "丢3个火罐烧3片地", "condition": "敌人≥8"},
	"guanyu": {"desc": "一道刀光劈穿一列", "condition": "这列敌人≥2"},
	"lvbu": {"desc": "画戟弹着连打9个", "condition": "敌人≥6"},
	"zhangliao": {"desc": "吓跑全场2秒", "condition": "敌人冲进阵"},
	"taishici": {"desc": "人最挤处落一片箭", "condition": "敌人扎堆≥5"},
	"dianwei": {"desc": "一锤下去炸一大片", "condition": "跟前敌人≥3"},
	"sunce": {"desc": "巨马冲一列全撞飞", "condition": "这列敌人≥3"},
	"xuchu": {"desc": "放拒马挡路4秒", "condition": "冲进阵敌人≥3"},
	"weiyan": {"desc": "埋3个毒陷阱踩了炸", "condition": "敌人≥3"},
	"ganning": {"desc": "乱丢5颗炸弹", "condition": "敌人≥5"},
	"diaochan": {"desc": "封贼技5秒·迷敌多挨打", "condition": "有贼首特种，或敌人≥5"},
	"zhouyu": {"desc": "一条火线横扫点燃", "condition": "敌人≥6"},
	"jiangwei": {"desc": "放8支追人火箭", "condition": "敌人≥4"},
	"zhugeliang": {"desc": "锁5只怪打一个全掉血", "condition": "敌人≥5"},
	"caoren": {"desc": "地震一圈晕1秒", "condition": "跟前有敌人"},
	"zhoutai": {"desc": "自奶45%冰刺炸一圈", "condition": "自己血少于60%"},
	"huatuo": {"desc": "绿线全军奶35%还持续回", "condition": "有人血少于70%"},
	"xiaoqiao": {"desc": "刮大风全军提速40%", "condition": "敌人≥6"},
	"lusu": {"desc": "天上掉粮白拿经验加攻", "condition": "敌人≥8"},
	"huanggai": {"desc": "扣自己血烧全场还攒经验", "condition": "敌人≥5、自己血还多"},
	"xuhuang": {"desc": "钉两排拒马挡5秒", "condition": "冲进阵敌人≥2"},
	"daqiao": {"desc": "全场冻慢还给全军回血", "condition": "敌人≥5"},
	"huangyueying": {"desc": "架一座连弩塔扫射8秒", "condition": "敌人≥4"},
	"caiwenji": {"desc": "一曲唱睡全场3秒·挨打会醒", "condition": "敌人≥6"},
	"gaoshun": {"desc": "把左右敌人拽成一堆重击", "condition": "这列敌人≥3"},
	"zhanghe": {"desc": "三列同时小冲锋", "condition": "敌人≥8"},
	"zhurong": {"desc": "扇形丢5把飞刀全点着", "condition": "敌人≥6"},
	"wutugu": {"desc": "毒雾变大变毒8秒", "condition": "跟前敌人≥2"},
	"pangde": {"desc": "顺着本列突刺一趟，个个挨扎", "condition": "这列敌人≥2"},
	"yanliang": {"desc": "直取最强的特种/精锐，残了直接枭首", "condition": "场上有特种或精锐"},
	"sunshangxiang": {"desc": "扇面十支火箭，点着还推人", "condition": "敌人≥5"},
	"yanyan": {"desc": "吼冻身边一圈敌人，自己回血", "condition": "阵前敌人≥3"},
	"caohong": {"desc": "自己回血，还替兄弟挨更多的刀（3秒六成）", "condition": "有人残血"},
	"xushu": {"desc": "5秒内全场贼的属性减免失效（被克照样打全额）", "condition": "敌≥6"},
	"simayi": {"desc": "全军大招快转8秒还送经验", "condition": "武将≥5"},
	"jiaxu": {"desc": "血最厚的4个贼倒戈互殴3秒", "condition": "普通贼≥6"},
	"zuoci": {"desc": "最肥的3个贼变羊5秒：不能动还多挨三成打", "condition": "普通贼≥3"},
	"dengai": {"desc": "同排贼全挨一记重锤，站石头上砸得更狠（石头不碎，接着占高地）", "condition": "敌人≥5"},
	"menghuo": {"desc": "吼跑全场普通贼1.5秒，自己回三成血", "condition": "敌人≥6"},
	"wenchou": {"desc": "对单挑目标一刀八倍处决", "condition": "有单挑目标"},
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
const LORD_COMMAND_RECT := Rect2(414, 208, 56, 58)
const LORD_NAME_RECT := Rect2(410, 178, 64, 24)
const PLAYER_LORD_POPUP_RECT := Rect2(65, 150, 350, 288)
const FOE_LORD_RECT := Rect2(208, 108, 64, 43)
const RULER_BACK_RECT := Rect2(14, 22, 90, 34)
const BATTLE_MUTE_RECT := Rect2(402, 102, 64, 32)
const BATTLE_QUIT_RECT := Rect2(402, 140, 64, 32)
const BATTLE_DMG_RECT := Rect2(402, 456, 64, 30)
const RESULT_BTN1 := Rect2(38, 690, 404, 42)
const RESULT_BTN2 := Rect2(38, 744, 404, 42)
const HOME_CODEX_RECT := Rect2(28, 604, 200, 44)
const HOME_LORD_RECT := Rect2(252, 604, 200, 44)
const HOME_VISIT_RECT := Rect2(28, 658, 128, 40)
const HOME_ACH_RECT := Rect2(176, 658, 128, 40)
const HOME_BAG_RECT := Rect2(324, 658, 128, 40)
const HOME_CLOSE_RECT := Rect2(402, 22, 54, 34)
const TECH_PAGE_RECT := Rect2(358, 26, 108, 32)
const HOME_BACK_RECT := Rect2(24, 22, 66, 34)
const HOME_PREV_RECT := Rect2(28, 744, 116, 38)
const HOME_NEXT_RECT := Rect2(336, 744, 116, 38)
const HERO_UPGRADE_RECT := Rect2(34, 620, 198, 46)
const HERO_REBIRTH_RECT := Rect2(248, 620, 198, 46)
const HERO_RESET_RECT := Rect2(141, 690, 198, 40)
const VISIT_ROLL_RECT := Rect2(156, 306, 168, 54)
const LORD_COMMAND_ICONS := {"wuxing": "☯", "taoyuan": "🍑", "jiejiang": "🌊", "mensheng": "📜", "bingfeng": "🧊", "baima": "🐎", "fenluo": "🔥", "jianhao": "🪙"}
const LORD_AUTO_TIPS := {
	"wuxing": "场上贼≥8个", "bingfeng": "场上贼≥6个", "taoyuan": "有兄弟掉到半血，或贼冲到城墙跟前（金身期间不叠）",
	"jiejiang": "江区里贼≥4个", "mensheng": "CD一转好就铺门路", "baima": "有特种/贼首上场，或贼≥8个",
	"fenluo": "贼≥6个且城血≥5（残血不烧）", "jianhao": "场上≥5人且有星≤3的祭品",
}
const LORD_SPECIAL_LABELS := {
	"tuntian": "🌾屯田", "yanglong": "🐉养龙", "qiangnu": "🏹强弩", "lijian": "💔离间",
	"henzheng": "🧧横征", "luoyangchan": "🪏洛阳铲", "qinwang": "🐎勤王", "yishe": "🍚义舍", "shuijun": "⚓水军",
}
const LORD_ATTACK_ICONS := {"caocao": "🗡", "yuanshao": "🏹", "yuanshu": "🪙", "sunquan": "🌊", "liubiao": "❄", "liubei": "⚔", "dongzhuo": "🔥", "gongsunzan": "🏹"}

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
var player_lord_popup := false
var battle_drag = BattleDragControllerSource.new()
var unit_info_popup: Dictionary = {}
var battle_interaction_notice: Dictionary = {}
var sound_enabled := true
var damage_panel_visible := false
var battle_field_banner_time := 0.0
var growth_card_age := 999.0
var growth_card_anim := 0.0
var growth_card_signature := ""
var quit_armed := false
var quit_arm_time := 0.0
var profile_path := "user://v7.19.14-local-profile.json"
var legacy_profile_path := "user://v7.19.2-local-profile.json"
var profile: Dictionary = {}
var settlement_summary: Dictionary = {}
var suppression_summary: Dictionary = {}
var home_overlay := ""
var codex_page := 0
var codex_hero_id := ""
var lord_page := 0
var home_message := ""
var reset_armed := false
var visit_result: Dictionary = {}
var visit_rng
var ach_group := 0
var ach_page := 0

func _ready() -> void:
	catalog = ContentCatalogSource.new()
	var error: Error = catalog.load_from("res://data/content-v7.19.14.json")
	if error != OK:
		push_error("Unable to load v7.19.14 content catalog: %s" % error_string(error))
		set_process(false)
		return
	weekly = WeeklyMapSource.new(catalog)
	opening_picker = OpeningPickerSource.new()
	if not FileAccess.file_exists(profile_path) and FileAccess.file_exists(legacy_profile_path):
		profile = LocalProfileSource.load_from(legacy_profile_path, CURRENT_WEEK)
		LocalProfileSource.save_to(profile_path, profile)
	else:
		profile = LocalProfileSource.load_from(profile_path, CURRENT_WEEK)
	HeroProgressionSource.ensure_roster(profile, catalog.list("heroes"))
	visit_rng = Mulberry32Source.new(CURRENT_WEEK * 771 + int(profile.get("visit_pos", 0)) * 97 + 2026)
	week_clears = profile.week_clears
	set_process(true)
	queue_redraw()

func advance_from_title() -> void:
	home_overlay = ""
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
	city.visitGoldUntil = int(profile.get("visit_buffs", {}).get("gold", 0))
	var seed := CURRENT_WEEK * 1009 + selected_city * 131 + RULER_IDS.find(selected_ruler) * 17
	var shen_period := ShenRotationSource.current_period()
	var hero_ids: Array = catalog.list("heroes").map(func(hero): return str(hero.id))
	var shen_ids := ShenRotationSource.ids_for_period(shen_period, hero_ids)
	battle_run = BattleRunSource.new(catalog, Mulberry32Source.new(seed))
	battle_run.start(city, selected_ruler, selected_hero, LocalProfileSource.ruler_level(profile, selected_ruler), LocalProfileSource.hero_levels(profile), shen_period, shen_ids)
	battle_field_banner_time = 9.0
	foe_lord_popup = false
	player_lord_popup = false
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
	if quit_armed:
		quit_arm_time = maxf(0.0, quit_arm_time - delta)
		if quit_arm_time <= 0:
			quit_armed = false
	if phase != "battle" or battle_run == null:
		return
	_sync_battle_drag_state()
	if not battle_interaction_notice.is_empty():
		battle_interaction_notice.time = maxf(0.0, float(battle_interaction_notice.get("time", 0.0)) - delta)
		if float(battle_interaction_notice.time) <= 0.0:
			battle_interaction_notice = {}
	if battle_run.status == "play" and not battle_run.awaiting_card_choice and not foe_lord_popup and not player_lord_popup_is_visible() and not unit_info_popup_is_visible():
		battle_field_banner_time = maxf(0.0, battle_field_banner_time - delta * 2.0)
	if unit_info_popup_is_visible() or player_lord_popup_is_visible():
		battle_run.advance_visual_only(delta)
	else:
		battle_run.advance_real(delta)
	_sync_growth_card_ui(delta)
	if _sync_battle_achievements():
		_save_profile()
	_sync_battle_result()
	queue_redraw()

func _sync_battle_achievements() -> bool:
	if battle_run == null:
		return false
	if not profile.get("achievements", []) is Array:
		profile.achievements = []
	var changed := false
	for achievement_id in battle_run.achievement_events:
		if not profile.achievements.has(achievement_id):
			profile.achievements.append(achievement_id)
			changed = true
	return changed

func _sync_battle_result() -> void:
	if battle_run.status == "win" and not battle_run.clear_settled:
		settlement_summary = RunSettlementSource.settle_clear(profile, battle_run, selected_city, _theme_fit())
		AchievementProgressSource.sweep(profile, catalog.list("achievements"))
		_save_profile()
	if battle_run.endless and battle_run.score_revision > 0 and int(suppression_summary.get("revision", 0)) < battle_run.score_revision:
		var almanac_active := VisitSystemSource.buff_active(profile, "score", int(Time.get_unix_time_from_system() * 1000.0))
		suppression_summary = RunSettlementSource.record_suppression(profile, battle_run, selected_city, bool(battle_run.city.get("weekGuest", false)), almanac_active)
		suppression_summary.revision = battle_run.score_revision
		AchievementProgressSource.sweep(profile, catalog.list("achievements"))
		_save_profile()
	if battle_run.status == "over" and not battle_run.over_settled:
		var over_summary: Dictionary = RunSettlementSource.settle_over(profile, battle_run, selected_city)
		for key in over_summary: settlement_summary[key] = over_summary[key]
		AchievementProgressSource.sweep(profile, catalog.list("achievements"))
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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _try_begin_battle_drag(event.position):
				accept_event()
				return
			_handle_pointer(event.position)
		elif battle_drag.is_active():
			_finish_battle_drag(event.position)
			accept_event()
	elif event is InputEventMouseMotion and battle_drag.is_active():
		battle_drag.update(event.position)
		queue_redraw()
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			if _try_begin_battle_drag(event.position):
				accept_event()
				return
			_handle_pointer(event.position)
		elif battle_drag.is_active():
			_finish_battle_drag(event.position)
			accept_event()
	elif event is InputEventScreenDrag and battle_drag.is_active():
		battle_drag.update(event.position)
		queue_redraw()
		accept_event()

func _try_begin_battle_drag(point: Vector2) -> bool:
	if phase != "battle" or battle_run == null or battle_run.status != "play":
		return false
	if foe_lord_popup or player_lord_popup_is_visible() or battle_run.awaiting_card_choice or (bool(battle_run.permanent_tactics.get("gewu", false)) and battle_run.dance_time <= 0.0):
		return false
	var cell := BattleDragControllerSource.cell_at(point)
	if cell == Vector2i(-1, -1):
		return false
	if battle_run.grid[cell.y][cell.x] == null:
		return false
	unit_info_popup = {}
	return battle_drag.begin(cell, point)

func _finish_battle_drag(point: Vector2) -> void:
	var pointer_position: Vector2 = battle_drag.pointer_position
	var result: Dictionary = battle_drag.finish(point)
	var action := str(result.get("action", ""))
	if action == "inspect":
		var source: Vector2i = result.source
		if _valid_battle_cell(source):
			var unit = battle_run.grid[source.y][source.x]
			if unit != null and float(unit.get("hp", 0.0)) > 0.0:
				unit_info_popup = {"unit": unit, "row": source.y, "col": source.x}
	elif action == "drop":
		var source: Vector2i = result.source
		var target: Vector2i = result.target
		var placement_error: String = battle_run.placement_error(source.y, source.x, target.y, target.x)
		if placement_error == "target_obstacle":
			_set_battle_interaction_notice("🪨 有石头，站不了", BattleRunSource.slot_center(target.y, target.x) - Vector2(0, 20))
		elif placement_error == "swap_obstacle":
			var target_unit = battle_run.grid[target.y][target.x]
			var target_name := str(target_unit.hero.name) if target_unit != null else "武将"
			_set_battle_interaction_notice("🪨 %s站不了石头，换不成" % target_name, BattleRunSource.slot_center(source.y, source.x) - Vector2(0, 20))
		elif placement_error.is_empty():
			battle_run.move_or_swap_unit(source.y, source.x, target.y, target.x)
	elif action == "sell":
		var source: Vector2i = result.source
		var unit = battle_run.grid[source.y][source.x] if _valid_battle_cell(source) else null
		if unit != null and battle_run.units().size() <= 1:
			_set_battle_interaction_notice("最后一个武将不能卖！", pointer_position, RED)
		elif unit != null:
			var hero_name := str(unit.hero.name)
			if battle_run.sell_unit(source.y, source.x):
				_set_battle_interaction_notice("卖掉%s，腾出一格" % hero_name, pointer_position - Vector2(0, 24))
	queue_redraw()

func _valid_battle_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < BattleRunSource.GRID_COLS and cell.y >= 0 and cell.y < BattleRunSource.GRID_ROWS

func _sync_battle_drag_state() -> void:
	if battle_run == null:
		battle_drag.cancel()
		unit_info_popup = {}
		return
	if battle_drag.is_active():
		var source: Vector2i = battle_drag.source_cell
		var dragged_unit = battle_run.grid[source.y][source.x] if _valid_battle_cell(source) else null
		if dragged_unit == null or float(dragged_unit.get("hp", 0.0)) <= 0.0:
			battle_drag.cancel()
	if not unit_info_popup.is_empty() and not unit_info_popup_is_visible():
		unit_info_popup = {}

func _set_battle_interaction_notice(message: String, position: Vector2, color := Color("c9b69a")) -> void:
	battle_interaction_notice = {"text": message, "position": position, "color": color, "time": 1.1}

func battle_interaction_notice_text() -> String:
	return str(battle_interaction_notice.get("text", ""))

func _handle_pointer(point: Vector2) -> void:
	match phase:
		"title":
			_handle_title_pointer(point)
		"map":
			_handle_map_pointer(point)
		"ruler":
			if RULER_BACK_RECT.has_point(point):
				phase = "map"
				selected_city = -1
				queue_redraw()
				return
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
			if bool(battle_run.permanent_tactics.get("gewu", false)) and battle_run.dance_time <= 0.0:
				battle_run.permanent_tactics.gewu = false
				battle_run.gewu_auto_timer = 0.0
				battle_run.gewu_auto_index = -1
				queue_redraw()
				return
			if battle_field_banner_is_visible() and battle_field_banner_rect().has_point(point):
				battle_field_banner_time = 0.0
				queue_redraw()
				return
			if _battle_field_chip_rect().has_point(point):
				battle_field_banner_time = 6.0
				queue_redraw()
				return
			if _cata_warning_rect().has_point(point):
				var urgent_cata: Dictionary = battle_run.focus_priority_catapult()
				if not urgent_cata.is_empty():
					battle_run.focus_enemy(urgent_cata)
					queue_redraw()
				return
			if foe_lord_popup:
				foe_lord_popup = false
				queue_redraw()
				return
			if FOE_LORD_RECT.has_point(point) and not battle_run.foe_lord.is_empty():
				foe_lord_popup = true
				queue_redraw()
				return
			if player_lord_popup_is_visible():
				var cast_rect: Rect2 = player_lord_popup_spec().get("cast_rect", Rect2())
				player_lord_popup = false
				if cast_rect.has_point(point):
					var blocked_notice := _manual_lord_command_block_notice()
					if not battle_run.cast_lord_command() and not blocked_notice.is_empty():
						_set_battle_interaction_notice(blocked_notice, Vector2(240, 300), PALE_GOLD)
				queue_redraw()
				return
			if LORD_NAME_RECT.has_point(point):
				player_lord_popup = true
				queue_redraw()
				return
			if unit_info_popup_is_visible():
				unit_info_popup = {}
			if battle_run.awaiting_card_choice:
				if growth_card_age < 0.35:
					return
				for index in battle_run.card_choices.size():
					if _growth_card_rect(index).has_point(point):
						battle_run.choose_card(index)
						growth_card_signature = ""
						_sync_growth_card_ui(0.0)
						queue_redraw()
						return
				return
			if BATTLE_MUTE_RECT.has_point(point):
				sound_enabled = not sound_enabled
				queue_redraw()
				return
			if BATTLE_DMG_RECT.has_point(point):
				damage_panel_visible = not damage_panel_visible
				queue_redraw()
				return
			if BATTLE_QUIT_RECT.has_point(point):
				if quit_armed:
					_return_to_map()
				else:
					quit_armed = true
					quit_arm_time = 3.0
				queue_redraw()
				return
			if LORD_COMMAND_RECT.has_point(point):
				player_lord_popup = true
				queue_redraw()
				return
			var clicked_enemy: Dictionary = _enemy_at_point(point)
			if not clicked_enemy.is_empty():
				battle_run.focus_enemy(clicked_enemy)
				queue_redraw()
				return

func _sync_growth_card_ui(delta: float) -> void:
	if battle_run == null or not battle_run.awaiting_card_choice or battle_run.card_choices.is_empty():
		growth_card_age = 999.0
		growth_card_anim = 0.0
		growth_card_signature = ""
		return
	var titles := PackedStringArray()
	for card in battle_run.card_choices:
		titles.append(str(card.get("title", "")))
	var signature := "%s|%s" % ["relic" if battle_run.picking_relic else "growth", "\u001f".join(titles)]
	if signature != growth_card_signature:
		growth_card_signature = signature
		growth_card_age = 0.0
		growth_card_anim = 0.0
		return
	growth_card_age += maxf(0.0, delta)
	growth_card_anim = minf(1.0, growth_card_anim + maxf(0.0, delta) * 4.8)

func _cata_warning_rect() -> Rect2:
	if battle_run == null or battle_run.enemies.filter(func(enemy): return not bool(enemy.get("dead", false)) and str(enemy.get("special", "")) == "cata").is_empty():
		return Rect2()
	return Rect2(62, 128, 356, 30)

func _enemy_at_point(point: Vector2) -> Dictionary:
	if battle_run == null:
		return {}
	var best: Dictionary = {}
	var best_distance := INF
	for enemy in battle_run.enemies:
		if bool(enemy.get("dead", false)):
			continue
		var distance := point.distance_squared_to(Vector2(float(enemy.x), float(enemy.y)))
		var hit_radius := maxf(24.0, float(enemy.r) + 10.0)
		if distance < hit_radius * hit_radius and distance < best_distance:
			best = enemy
			best_distance = distance
	return best

func _handle_title_pointer(point: Vector2) -> void:
	if home_overlay.is_empty():
		if HOME_CODEX_RECT.has_point(point):
			home_overlay = "codex"
			codex_page = 0
		elif HOME_LORD_RECT.has_point(point):
			home_overlay = "lords"
			lord_page = 0
		elif HOME_VISIT_RECT.has_point(point):
			home_overlay = "visit"
			visit_result = {}
		elif HOME_ACH_RECT.has_point(point):
			AchievementProgressSource.sweep(profile, catalog.list("achievements"))
			home_overlay = "achievements"
			ach_group = 0
			ach_page = 0
		elif HOME_BAG_RECT.has_point(point):
			home_overlay = "bag"
		else:
			advance_from_title()
		queue_redraw()
		return
	if home_overlay == "lords":
		if TECH_PAGE_RECT.has_point(point):
			lord_page = (lord_page + 1) % 2
		elif point.y > 710.0:
			home_overlay = ""
		queue_redraw()
		return
	if HOME_CLOSE_RECT.has_point(point):
		home_overlay = ""
		home_message = ""
		reset_armed = false
		queue_redraw()
		return
	match home_overlay:
		"codex":
			if HOME_PREV_RECT.has_point(point):
				codex_page = maxi(0, codex_page - 1)
			elif HOME_NEXT_RECT.has_point(point):
				codex_page = mini(2, codex_page + 1)
			else:
				var visible_ids: Array = codex_page_hero_ids()
				for index in visible_ids.size():
					if codex_hero_rect(index).has_point(point):
						codex_hero_id = str(visible_ids[index])
						home_overlay = "hero"
						home_message = ""
						break
		"hero":
			if HOME_BACK_RECT.has_point(point):
				home_overlay = "codex"
				reset_armed = false
			elif HERO_UPGRADE_RECT.has_point(point):
				var upgraded := HeroProgressionSource.upgrade(profile, codex_hero_id, catalog.content.get("hero_tiers", {}), catalog.content.get("rarities", {}))
				home_message = "升级成功" if upgraded else "金币、突破石不足，或已到等级上限"
				if upgraded:
					AchievementProgressSource.sweep(profile, catalog.list("achievements"))
					_save_profile()
			elif HERO_REBIRTH_RECT.has_point(point):
				var reborn := HeroProgressionSource.rebirth(profile, codex_hero_id)
				home_message = "转生成功，等级上限 +10" if reborn else "需达到当前满级并备齐转生石"
				if reborn:
					AchievementProgressSource.sweep(profile, catalog.list("achievements"))
					_save_profile()
			elif HERO_RESET_RECT.has_point(point):
				if reset_armed:
					var refund: Dictionary = HeroProgressionSource.reset(profile, codex_hero_id, catalog.content.get("hero_tiers", {}), catalog.content.get("rarities", {}))
					home_message = "已重置，返还 %d 金与 %d 突破石" % [int(refund.get("gold", 0)), int(refund.get("stones", 0))] if not refund.is_empty() else "当前武将无需重置"
					reset_armed = false
					if not refund.is_empty(): _save_profile()
				else:
					reset_armed = true
					home_message = "再次点击确认重置（全额返还）"
		"lords":
			pass
		"visit":
			if VISIT_ROLL_RECT.has_point(point):
				_perform_visit_roll()
				AchievementProgressSource.sweep(profile, catalog.list("achievements"))
				_save_profile()
		"achievements":
			for index in ACH_GROUPS.size():
				if _achievement_tab_rect(index).has_point(point):
					ach_group = index
					ach_page = 0
					queue_redraw()
					return
			if HOME_PREV_RECT.has_point(point): ach_page = maxi(0, ach_page - 1)
			elif HOME_NEXT_RECT.has_point(point): ach_page = mini(_achievement_page_count() - 1, ach_page + 1)
			else:
				var definitions: Array = achievement_page_definitions()
				for index in definitions.size():
					if _achievement_row_rect(index).has_point(point):
						var claim: Dictionary = AchievementProgressSource.claim(profile, str(definitions[index].id), catalog.list("achievements"))
						if not claim.is_empty():
							home_message = "领取 %d 金币" % int(claim.gold)
							_save_profile()
						break
	queue_redraw()

func _perform_visit_roll() -> void:
	var now_ms := int(Time.get_unix_time_from_system() * 1000.0)
	visit_result = VisitSystemSource.roll(profile, catalog, CURRENT_WEEK, visit_rng, now_ms)
	if visit_result.has("error"): return
	var combined_lines: Array = visit_result.get("lines", []).duplicate()
	var rerolls := 0
	while bool(visit_result.get("free_again", false)) and rerolls < 8:
		rerolls += 1
		var bonus: Dictionary = VisitSystemSource.roll(profile, catalog, CURRENT_WEEK, visit_rng, now_ms, true)
		combined_lines.append("好手气：免费再寻，掷出%d点" % int(bonus.dice))
		combined_lines.append_array(bonus.get("lines", []))
		visit_result = bonus
	visit_result.lines = combined_lines

func codex_page_hero_ids() -> Array:
	var heroes: Array = catalog.list("heroes")
	var result: Array = []
	var start := codex_page * 15
	for index in range(start, mini(start + 15, heroes.size())):
		result.append(str(heroes[index].id))
	return result

func codex_hero_rect(index: int) -> Rect2:
	var column := index % 3
	var row := int(floor(index / 3.0))
	return Rect2(16 + column * 151, 94 + row * 124, 145, 112)

func lord_page_ruler_ids() -> Array:
	var result: Array = []
	var start := lord_page * 4
	for index in range(start, mini(start + 4, RULER_IDS.size())):
		result.append(RULER_IDS[index])
	return result

func lord_house_rect(index: int) -> Rect2:
	return Rect2(12, 112 + index * 128, 456, 120)

func achievement_page_definitions() -> Array:
	var matching: Array = []
	for definition in catalog.list("achievements"):
		if str(definition.get("grp", "")) == ACH_GROUPS[ach_group]: matching.append(definition)
	var start := ach_page * 6
	return matching.slice(start, mini(start + 6, matching.size()))

func _achievement_page_count() -> int:
	var count := 0
	for definition in catalog.list("achievements"):
		if str(definition.get("grp", "")) == ACH_GROUPS[ach_group]: count += 1
	return maxi(1, int(ceil(count / 6.0)))

func _achievement_tab_rect(index: int) -> Rect2:
	return Rect2(18 + index * 113, 74, 105, 36)

func _achievement_row_rect(index: int) -> Rect2:
	return Rect2(20, 128 + index * 94, 440, 84)

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
	player_lord_popup = false
	battle_drag.cancel()
	damage_panel_visible = false
	quit_armed = false
	quit_arm_time = 0.0

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
		_text_center("正在载入 v7.19.14…", 400, 22, PALE_GOLD)
		return
	match phase:
		"title":
			_draw_title()
			_draw_home_controls()
			if not home_overlay.is_empty(): _draw_home_overlay()
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

func _rounded_panel(rect: Rect2, fill: Color, border: Color, width: float, radius: float) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	var border_width := maxi(1, roundi(width))
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = roundi(radius)
	style.corner_radius_top_right = roundi(radius)
	style.corner_radius_bottom_left = roundi(radius)
	style.corner_radius_bottom_right = roundi(radius)
	draw_style_box(style, rect)

func _fit_font_size(text: String, max_width: float, start_size: int, min_size: int) -> int:
	var size := start_size
	while size > min_size and _font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_width:
		size -= 1
	return size

func _name_disc_font_size(name: String, radius: float) -> int:
	var length := name.length()
	if length >= 4:
		return roundi(radius * 0.48)
	if length == 3:
		return roundi(radius * 0.62)
	if length == 2:
		return roundi(radius * 0.78)
	return roundi(radius * 1.05)

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
	_text_center("Godot 4.7 · v7.19.14 精确复现进行中", 760, 12, MUTED)

func _draw_home_controls() -> void:
	draw_rect(Rect2(0, 562, 480, 162), INK, true)
	_panel(HOME_CODEX_RECT, Color("3b2c16"), PALE_GOLD, 2.0)
	_text_centered_in_rect("武将图鉴 · 45将养成", HOME_CODEX_RECT, 16, Color("fff0bd"))
	_panel(HOME_LORD_RECT, Color("3b2c16"), PALE_GOLD, 2.0)
	_text_centered_in_rect("主公府 · 八方诸侯", HOME_LORD_RECT, 16, Color("fff0bd"))
	_panel(HOME_VISIT_RECT, Color("294637"), GREEN, 1.5)
	_text_centered_in_rect("寻访 ×%d" % int(profile.get("items", {}).get("visitToken", 0)), HOME_VISIT_RECT, 14, Color.WHITE)
	_panel(HOME_ACH_RECT, Color("3c4828"), GREEN if AchievementProgressSource.claimable_count(profile) > 0 else PALE_GOLD, 1.5)
	_text_centered_in_rect("成就%s" % (" · 可领%d" % AchievementProgressSource.claimable_count(profile) if AchievementProgressSource.claimable_count(profile) > 0 else ""), HOME_ACH_RECT, 14, Color.WHITE)
	_panel(HOME_BAG_RECT, Color("3c3527"), PALE_GOLD, 1.5)
	_text_centered_in_rect("背包", HOME_BAG_RECT, 14, Color.WHITE)
	_text_center("本地金币 %d · 势力 %d · 最高讨伐 +%d波" % [int(profile.get("gold", 0)), week_clears.size(), int(profile.get("endless_best", 0))], 582, 13, BLUE)
	_text_center("点击其余空白处出征", 719, 13, PALE_GOLD)

func _draw_home_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("140e06f2") if home_overlay == "lords" else INK, true)
	match home_overlay:
		"codex": _draw_codex()
		"hero": _draw_hero_detail()
		"lords": _draw_lord_house()
		"visit": _draw_visit()
		"bag": _draw_bag()
		"achievements": _draw_achievements()
	if home_overlay != "lords":
		_panel(HOME_CLOSE_RECT, Color("40271e"), RED, 1.5)
		_text_centered_in_rect("关闭", HOME_CLOSE_RECT, 13, Color.WHITE)

func _draw_codex() -> void:
	_text_center("武将图鉴", 48, 27, GOLD)
	_text_center("45名武将 · 每级全属性 +8% · 突破与转生永久保留", 73, 12, Color("d5c9a8"))
	var visible_ids: Array = codex_page_hero_ids()
	for index in visible_ids.size():
		var hero_id := str(visible_ids[index])
		var hero: Dictionary = catalog.by_id("heroes", hero_id)
		var entry: Dictionary = profile.heroes[hero_id]
		var rarity_id := HeroProgressionSource.rarity(hero_id, catalog.content.get("hero_tiers", {}))
		var rarity_data: Dictionary = catalog.content.get("rarities", {}).get(rarity_id, {})
		var rarity_color := Color(str(rarity_data.get("color", "#cfd6dc")))
		var rect := codex_hero_rect(index)
		_panel(rect, Color("241c10"), rarity_color, 2.0)
		_text_centered_in_rect(str(hero.get("char", "将")), Rect2(rect.position.x, rect.position.y + 8, rect.size.x, 26), 20, Color.WHITE)
		_text_centered_in_rect(str(hero.name), Rect2(rect.position.x, rect.position.y + 39, rect.size.x, 23), 15, PALE_GOLD)
		_text_centered_in_rect("Lv.%d%s" % [int(entry.lv), " · 转%d" % int(entry.rb) if int(entry.rb) > 0 else ""], Rect2(rect.position.x, rect.position.y + 65, rect.size.x, 20), 12, BLUE)
		_text_centered_in_rect("%s · %s" % [str(rarity_data.get("name", rarity_id)), CLASS_NAMES.get(hero.cls, hero.cls)], Rect2(rect.position.x, rect.position.y + 87, rect.size.x, 18), 10, rarity_color)
	_panel(HOME_PREV_RECT, Color("302718"), PALE_GOLD if codex_page > 0 else MUTED, 1.5)
	_text_centered_in_rect("上一页", HOME_PREV_RECT, 14, Color.WHITE if codex_page > 0 else MUTED)
	_text_center("第 %d / 3 页" % (codex_page + 1), 770, 13, PALE_GOLD)
	_panel(HOME_NEXT_RECT, Color("302718"), PALE_GOLD if codex_page < 2 else MUTED, 1.5)
	_text_centered_in_rect("下一页", HOME_NEXT_RECT, 14, Color.WHITE if codex_page < 2 else MUTED)

func _draw_hero_detail() -> void:
	var hero: Dictionary = catalog.by_id("heroes", codex_hero_id)
	var entry: Dictionary = profile.heroes.get(codex_hero_id, {"lv": 1, "rb": 0, "xp": 0})
	var rarity_id := HeroProgressionSource.rarity(codex_hero_id, catalog.content.get("hero_tiers", {}))
	var rarity_data: Dictionary = catalog.content.get("rarities", {}).get(rarity_id, {})
	var rarity_color := Color(str(rarity_data.get("color", "#cfd6dc")))
	_panel(HOME_BACK_RECT, Color("302718"), PALE_GOLD, 1.5)
	_text_centered_in_rect("返回", HOME_BACK_RECT, 13, Color.WHITE)
	draw_circle(Vector2(240, 130), 54, PANEL_2)
	draw_arc(Vector2(240, 130), 56, 0, TAU, 64, rarity_color, 4.0)
	_text_centered_in_rect(str(hero.get("char", "将")), Rect2(190, 102, 100, 46), 35, Color.WHITE)
	_text_center(str(hero.get("name", codex_hero_id)), 220, 29, GOLD)
	_text_center("%s · %s · %s" % [str(rarity_data.get("name", rarity_id)), CLASS_NAMES.get(hero.get("cls", ""), hero.get("cls", "")), TRI_DISPLAY.get(hero.get("elem", ""), {}).get("name", "")], 249, 14, rarity_color)
	_text_center("Lv.%d / %d · 转生 %d / 3 · 全属性 +%d%%" % [int(entry.lv), HeroProgressionSource.level_cap(entry), int(entry.rb), maxi(0, int(entry.lv) - 1) * 8], 282, 15, BLUE)
	_text_center(str(hero.get("desc", "")), 312, 13, Color("d5c9a8"))
	var ultimate: Dictionary = BattleUltsSource.DEFINITIONS.get(codex_hero_id, {})
	_text_center("绝技：%s · 基础冷却 %s秒" % [str(ultimate.get("name", "未录入")), str(ultimate.get("cd", "-"))], 333, 12, Color("c9a8ff"))
	_panel(Rect2(30, 342, 420, 216), Color("211a10"), Color("6c5835"), 1.5)
	_text("里程碑", Vector2(48, 370), 17, PALE_GOLD)
	var milestones: Array = catalog.list("milestones")
	for index in milestones.size():
		var milestone: Dictionary = milestones[index]
		var reached := int(entry.lv) >= int(milestone.lv)
		_text("Lv.%d  %s" % [int(milestone.lv), str(milestone.txt)], Vector2(50, 400 + index * 22), 12, GREEN if reached else MUTED)
	var next_cost := 0
	if int(entry.lv) < HeroProgressionSource.level_cap(entry):
		next_cost = HeroProgressionSource.upgrade_cost(int(entry.lv) + 1, codex_hero_id, catalog.content.get("hero_tiers", {}), catalog.content.get("rarities", {}))
	var gate := HeroProgressionSource.gate_stones(int(entry.lv))
	_panel(HERO_UPGRADE_RECT, Color("5a4426"), GOLD, 2.0)
	_text_centered_in_rect("升级 · %d金%s" % [next_cost, " + %d石" % gate if gate > 0 else ""], HERO_UPGRADE_RECT, 15, Color("fff3c4"))
	var rebirth_cost := int(HeroProgressionSource.REBIRTH_STONES[int(entry.rb)]) if int(entry.rb) < 3 else 0
	_panel(HERO_REBIRTH_RECT, Color("3b2b4f"), Color("c896ff"), 2.0)
	_text_centered_in_rect("转生 · %d突破石" % rebirth_cost, HERO_REBIRTH_RECT, 15, Color("f1d9ff"))
	_panel(HERO_RESET_RECT, Color("30271d"), RED if reset_armed else MUTED, 1.5)
	_text_centered_in_rect("确认重置" if reset_armed else "重置（全额返还）", HERO_RESET_RECT, 13, Color.WHITE)
	_text_center("持有：%d 金 · %d 突破石 · 经验 %d" % [int(profile.gold), int(profile.items.tupo), int(entry.xp)], 756, 13, PALE_GOLD)
	if not home_message.is_empty(): _text_center(home_message, 785, 12, GREEN)

func _draw_lord_house() -> void:
	_text_center("👑 主公府 👑", 50, 26, GOLD)
	_text_center("带谁出征谁涨经验——升级涨招牌技威力、解锁兵书被动", 78, 13, Color("d5c9a8"))
	_text_center("各管一类题面，被动只在带他的局里生效——换着用别偏科", 98, 12, MUTED)
	_rounded_panel(TECH_PAGE_RECT, Color("5a4a3a"), Color("8a7d66"), 1.0, 10.0)
	_text_centered_in_rect("第%d/2页 →" % (lord_page + 1), TECH_PAGE_RECT, 13, Color.WHITE)
	var visible_ids: Array = lord_page_ruler_ids()
	for index in visible_ids.size():
		var ruler_id := str(visible_ids[index])
		var ruler: Dictionary = catalog.by_id("rulers", ruler_id)
		var entry: Dictionary = profile.rulers[ruler_id]
		var rect := lord_house_rect(index)
		var level := int(entry.lv)
		var is_max := level >= LocalProfileSource.LORD_LEVEL_MAX
		_rounded_panel(rect, Color("ffffff0d"), GOLD if is_max else Color("5a4a2a"), 1.6, 12.0)
		var name_center := Vector2(rect.position.x + 36, rect.position.y + 42)
		var disc_name := str(ruler.name)
		var disc_size := _name_disc_font_size(disc_name, 24.0)
		draw_string(_font(), Vector2(name_center.x - 24.0, name_center.y + disc_size / 3.0), disc_name, HORIZONTAL_ALIGNMENT_CENTER, 48.0, disc_size, _lord_name_color(level))
		_text("%s·%s" % [str(ruler.name), str(ruler.title)], Vector2(rect.position.x + 70, rect.position.y + 22), 15, GOLD)
		_text("Lv.%d（满级）" % level if is_max else "Lv.%d" % level, Vector2(rect.position.x + 70, rect.position.y + 42), 13, GOLD if is_max else Color("9adf5a"))
		if not is_max:
			var need := LocalProfileSource.lord_xp_need(level)
			var xp := int(entry.xp)
			_rounded_panel(Rect2(rect.position.x + 140, rect.position.y + 33, 130, 9), Color("ffffff1f"), Color.TRANSPARENT, 0.0, 4.0)
			var progress_width := maxf(3.0, 130.0 * minf(1.0, float(xp) / float(need)))
			_rounded_panel(Rect2(rect.position.x + 140, rect.position.y + 33, progress_width, 9), Color("9adf5a"), Color.TRANSPARENT, 0.0, 4.0)
			_text("%d/%d" % [xp, need], Vector2(rect.position.x + 276, rect.position.y + 41), 10, MUTED)
		var skill_tier := mini(3, 1 + int(floor((level - 1) / 8.0)))
		var skill_id := str(ruler.skill)
		var command: Dictionary = BattleLordSource.COMMANDS.get(skill_id, {})
		var skill_line := "%s%s（%d星）%s" % [LORD_COMMAND_ICONS.get(skill_id, ""), str(command.get("name", skill_id)), skill_tier, _lord_skill_desc(skill_id, skill_tier)]
		_text(skill_line, Vector2(rect.position.x + 14, rect.position.y + 64), 12, Color("8ad2ff"))
		var passive_x := rect.position.x + 14
		for passive in ruler.get("passives", []):
			var unlocked := 0
			for at_level in passive.get("at", []):
				if level >= int(at_level): unlocked += 1
			var tech: Dictionary = catalog.by_id("techs", str(passive.id))
			var next_level := 0
			for at_level in passive.get("at", []):
				if level < int(at_level):
					next_level = int(at_level)
					break
			var label := "%s%s%d%s" % [str(tech.get("icon", "")), str(tech.get("name", passive.id)).left(2), unlocked, "(%d级+1)" % next_level if next_level > 0 else ""]
			_text(label, Vector2(passive_x, rect.position.y + 84), 12, PALE_GOLD if unlocked > 0 else Color("c8bea066"))
			passive_x += _font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 10.0
		var special_line := _lord_special_line(ruler, level)
		_text(special_line, Vector2(rect.position.x + 14, rect.position.y + 105), 11, GOLD if ruler.get("special") != null else Color("9a8f70"))
	_text_center("👆 点击底部返回", 770, 15, Color.WHITE)

func _lord_skill_desc(skill_id: String, level: int) -> String:
	match skill_id:
		"wuxing": return "%d秒内被克的亏全免，全军伤害再+15%%" % (6 + level * 2)
		"taoyuan": return "全军金身%d秒刀枪不入（亲兵越多越久）；金身落幕，扛住的伤全额奉还成全场冲击（附1秒眩晕），实伤的8%%再换成经验" % (4 + level * 2)
		"jiejiang": return "拦腰一道大江%d秒：江里的贼变慢40%%、挨打多%d%%，弓贼投石在江里放不了箭" % [5 + level * 2, 20 + level * 10]
		"mensheng": return "接下来 %d 次升级选卡变五选一；手里正摊着牌就当场加宽" % level
		"bingfeng": return "全场定住 %.1f秒" % (1.0 + level * 0.7)
		"baima": return "主公亲自下场%d秒：无敌白马专砍特种兵和贼首（亲兵越多砍得越疼越久）" % (5 + level * 2)
		"fenluo": return "烧掉自家2点城墙血，从主公喷出全场扇形巨焰（点燃；亲兵越多烧得越疼）；每烧1血全军攻击+4%%（本局永久）"
		"jianhao": return "吃掉一个最弱的兵（星≤3、场上≥5人才动口）连升%d级，祭品每有1星再多升1级；每献祭一次，下道号令等得更久（45→57→69…）" % (3 if level >= 2 else 2)
	return ""

func _lord_name_color(level: int) -> Color:
	return GOLD if level >= 10 else Color("ffe8b0")

func _lord_special_line(ruler: Dictionary, level: int) -> String:
	var special_id := str(ruler.get("special", ""))
	match special_id:
		"tuntian": return "🌾屯田制：独家：粮仓卡——产粮喂旁边武将升星，产量+%d%%" % (level * 3)
		"shuijun": return "⚓水军都督：独家·江东通饷：杀敌经验+30%%（江中击杀×2）；每波自动起江%.1f秒（变慢40%%·挨打多%d%%·弓贼哑火）" % [4.5 + level * 0.15, 20 + roundi(level * 0.5)]
		"yanglong": return "🐉养龙术：独家：三选一出龙蛋卡——干孵期间每秒吐纳经验（蛋阶越高越多，+%d%%），觉醒成应龙镇场；温养把握+%d%%" % [level * 2, level]
		"qiangnu": return "🏹城头强弩：独家：城墙自动放箭射最贴近防线的贼（墙越满箭越狠，伤害+%d%%）；首级记功：白马/强弩亲手击杀经验×3" % (level * 3)
		"luoyangchan": return "🪏洛阳铲：独家：开山凿石卡变洛阳铲——铲子存着，点铲子自己挑哪块障碍挖；挖开有三成陪葬金　🧧横征暴敛"
	var desc := str(ruler.get("desc", ""))
	var cut := desc.find("——")
	return desc.left(cut) if cut > 0 else desc

func _visit_cell_position(index: int) -> Vector2:
	var top := 150.0
	var bottom := 570.0
	var left := 42.0
	var right := 438.0
	if index <= 5: return Vector2(lerpf(left, right, index / 5.0), top)
	if index <= 9: return Vector2(right, lerpf(top, bottom, (index - 5) / 5.0))
	if index <= 15: return Vector2(lerpf(right, left, (index - 10) / 5.0), bottom)
	return Vector2(left, lerpf(bottom, top, (index - 15) / 5.0))

func _draw_visit() -> void:
	_text_center("寻访", 48, 27, GOLD)
	_text_center("掷骰走格拿奖励 · 20格构成固定、每周重新排布", 75, 12, Color("d5c9a8"))
	var icons := {"gold": "金", "gift": "礼", "hxp": "将", "lxp": "主", "luck": "签", "tupo": "石", "kuang": "矿"}
	var colors := {"gold": GOLD, "gift": Color("ff8a3a"), "hxp": RED, "lxp": Color("d9a6ff"), "luck": GREEN, "tupo": Color("e8d9b0"), "kuang": Color("6ae8ff")}
	var cells: Array = VisitSystemSource.board(CURRENT_WEEK)
	for index in cells.size():
		var cell := str(cells[index])
		var point := _visit_cell_position(index)
		var here := index == int(profile.get("visit_pos", 0))
		draw_rect(Rect2(point - Vector2(22, 22), Vector2(44, 44)), Color("382d19") if here else Color("241c10"), true)
		draw_rect(Rect2(point - Vector2(22, 22), Vector2(44, 44)), GOLD if here else colors[cell], false, 3.0 if here else 1.5)
		_text_centered_in_rect(str(icons[cell]), Rect2(point.x - 22, point.y - 13, 44, 24), 16, Color.WHITE)
		if here: _text_centered_in_rect("●", Rect2(point.x - 22, point.y + 8, 44, 12), 8, GOLD)
	_text_center("寻访令牌 ×%d" % int(profile.items.visitToken), 286, 15, BLUE)
	_panel(VISIT_ROLL_RECT, Color("5a4426"), GOLD, 2.0)
	_text_centered_in_rect("掷骰子（1令牌）", VISIT_ROLL_RECT, 17, Color("fff3c4"))
	if visit_result.is_empty():
		_text_center("今日通关 %d/30 · 讨伐赏 %d/30" % [int(profile.get("visit_count", 0)), int(profile.get("taofa_got", 0))], 405, 13, MUTED)
	else:
		var heading := "令牌不足" if visit_result.has("error") else "掷出 %d 点 · 落在「%s」" % [int(visit_result.dice), str(visit_result.cell)]
		_text_center(heading, 400, 15, PALE_GOLD)
		var lines: Array = visit_result.get("lines", [])
		for index in mini(5, lines.size()): _text_center(str(lines[index]), 428 + index * 22, 12, GREEN)
	var now_ms := int(Time.get_unix_time_from_system() * 1000.0)
	var buffs := PackedStringArray()
	for buff_id in ["score", "gold", "again"]:
		if VisitSystemSource.buff_active(profile, buff_id, now_ms): buffs.append(str(buff_id))
	_text_center("黄历加成：%s" % ("、".join(buffs) if not buffs.is_empty() else "暂无（奇遇格可获得30分钟加成）"), 628, 12, GREEN if not buffs.is_empty() else MUTED)
	_text_center("突破石 %d · 图鉴经验和主公经验都会直接写入本地存档" % int(profile.items.tupo), 664, 12, PALE_GOLD)
	_text_center("单机版不接广告；令牌来源保留战斗通关与棋盘奖励", 704, 11, MUTED)

func _draw_bag() -> void:
	_text_center("背包", 50, 28, GOLD)
	_text_center("所有道具保存在当前设备，不依赖服务器", 78, 12, Color("d5c9a8"))
	var items: Array = catalog.list("items")
	for index in items.size():
		var item: Dictionary = items[index]
		var rect := Rect2(24, 126 + index * 168, 432, 146)
		_panel(rect, Color("241c10"), PALE_GOLD, 1.8)
		_text("令" if str(item.id) == "visitToken" else "石", Vector2(50, rect.position.y + 49), 25, Color.WHITE)
		_text(str(item.name), Vector2(95, rect.position.y + 38), 20, GOLD)
		_text("持有 ×%d" % int(profile.items.get(str(item.id), 0)), Vector2(330, rect.position.y + 37), 15, BLUE)
		_text(_short_text(str(item.desc), 29), Vector2(95, rect.position.y + 69), 12, Color("d5c9a8"))
		if str(item.id) == "visitToken":
			_text("来源：战斗通关、寻访大礼包", Vector2(95, rect.position.y + 105), 11, GREEN)
		else:
			_text("用途：10/20级突破与三次转生", Vector2(95, rect.position.y + 105), 11, GREEN)
	_text_center("背包只展示资源；使用入口在寻访和武将详情中", 538, 13, MUTED)

func _draw_achievements() -> void:
	_text_center("成就 %d / %d" % [profile.achievements.size(), catalog.list("achievements").size()], 50, 25, GOLD)
	for index in ACH_GROUPS.size():
		var rect := _achievement_tab_rect(index)
		_panel(rect, Color("574323") if index == ach_group else Color("241c10"), GOLD if index == ach_group else MUTED, 1.5)
		_text_centered_in_rect(ACH_GROUPS[index], rect, 13, Color.WHITE if index == ach_group else MUTED)
	var definitions: Array = achievement_page_definitions()
	for index in definitions.size():
		var definition: Dictionary = definitions[index]
		var achievement_id := str(definition.id)
		var rect := _achievement_row_rect(index)
		var unlocked: bool = profile.achievements.has(achievement_id)
		var claimed: bool = profile.ach_claimed.has(achievement_id)
		var state: Dictionary = AchievementProgressSource.progress(profile, achievement_id)
		_panel(rect, Color("20351f") if unlocked and not claimed else Color("241c10"), GREEN if unlocked and not claimed else (PALE_GOLD if claimed else MUTED), 1.5)
		_text(str(definition.name), Vector2(34, rect.position.y + 27), 17, GOLD if unlocked else Color("d5c9a8"))
		_text(_short_text(str(definition.desc), 29), Vector2(34, rect.position.y + 52), 11, Color("c9b69a"))
		var status := "已领取" if claimed else ("点击领取 +%d金" % int(definition.gold) if unlocked else "未达成")
		_text(status, Vector2(326, rect.position.y + 27), 11, GREEN if unlocked and not claimed else MUTED)
		if bool(state.supported):
			_text("进度 %d / %d" % [mini(int(state.current), int(state.need)), int(state.need)], Vector2(34, rect.position.y + 73), 10, BLUE)
		elif not unlocked:
			_text("当前单机版暂未接入该事件统计", Vector2(34, rect.position.y + 73), 10, MUTED)
	_panel(HOME_PREV_RECT, Color("302718"), PALE_GOLD if ach_page > 0 else MUTED, 1.5)
	_text_centered_in_rect("上一页", HOME_PREV_RECT, 14, Color.WHITE if ach_page > 0 else MUTED)
	_text_center("第 %d / %d 页%s" % [ach_page + 1, _achievement_page_count(), " · " + home_message if not home_message.is_empty() else ""], 770, 12, PALE_GOLD)
	_panel(HOME_NEXT_RECT, Color("302718"), PALE_GOLD if ach_page + 1 < _achievement_page_count() else MUTED, 1.5)
	_text_centered_in_rect("下一页", HOME_NEXT_RECT, 14, Color.WHITE if ach_page + 1 < _achievement_page_count() else MUTED)

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
	draw_rect(Rect2(0, 0, 480, 800), Color("140e06f5"), true)
	_text_center("👑 点主公 👑", 46, 26, GOLD)
	_text_center("只能带一位——他的招牌技和被动就是这局的底牌，看好题面再点", 74, 13, Color("d5c9a8"))
	var field: Dictionary = catalog.by_id("fields", str(city.get("field", "")))
	var rules: Array = city.get("rules", [])
	_text_center("这州的贼是 %s%s，%s%s克他 · %s%s%s" % [tri.icon, tri.name, counter.icon, counter.name, field.get("icon", ""), field.get("name", ""), " · ⚠" + _rule_names(rules) if not rules.is_empty() else ""], 96, 13, Color("c9b69a"))
	var theme: Dictionary = weekly.theme_of(CURRENT_WEEK, 1 if selected_city >= 16 else 0)
	_text_center("%s %s军略：%s——%s" % [theme.get("icon", ""), "下篇" if selected_city >= 16 else "上篇", theme.get("name", ""), theme.get("desc", "")], 116, 12, GOLD)
	var guests := BattleRecordsSource.week_guest_lords(CURRENT_WEEK)
	var hints := _ruler_hints(city, week_clears.has(str(selected_city)))
	for index in RULER_IDS.size():
		var ruler_id := str(RULER_IDS[index])
		var ruler: Dictionary = catalog.by_id("rulers", ruler_id)
		var rect := _ruler_rect(index)
		var visual := _ruler_visual_spec(index)
		var is_guest := guests.has(ruler_id)
		_rounded_panel(rect, Color("ffffff0d"), Color("786e5a59"), 1.2, float(visual.corner_radius))
		var disc_center: Vector2 = visual.disc_center
		draw_circle(disc_center, float(visual.disc_radius), Color("2b2115"))
		draw_arc(disc_center, float(visual.disc_radius) + 1.0, 0, TAU, 32, GOLD, 2.0)
		var disc_name := str(ruler.name)
		var disc_font_size := _name_disc_font_size(disc_name, float(visual.disc_radius))
		draw_string(_font(), Vector2(disc_center.x - float(visual.disc_radius), disc_center.y + disc_font_size / 3.0), disc_name, HORIZONTAL_ALIGNMENT_CENTER, float(visual.disc_radius) * 2.0, disc_font_size, GOLD)
		var tx: float = visual.text_x
		_text("%s · %s" % [str(ruler.name), str(ruler.title)], Vector2(tx, rect.position.y + 20), 15, GOLD)
		var badge_x := rect.end.x - 8.0
		if is_guest:
			var guest_text := "🍵客卿·讨伐+30%"
			var guest_width := _font().get_string_size(guest_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			_text(guest_text, Vector2(badge_x - guest_width, rect.position.y + 20), 10, GREEN)
			badge_x -= guest_width + 10.0
		if hints.has(ruler_id):
			var hint_text := "👍对题"
			var hint_width := _font().get_string_size(hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			_text(hint_text, Vector2(badge_x - hint_width, rect.position.y + 20), 10, GOLD)
			badge_x -= hint_width + 10.0
		var level := LocalProfileSource.ruler_level(profile, ruler_id)
		var command: Dictionary = BattleLordSource.COMMANDS.get(str(ruler.skill), {})
		var special_text := str(LORD_SPECIAL_LABELS.get(str(ruler.get("special", "")), ""))
		var second_special := str(LORD_SPECIAL_LABELS.get(str(ruler.get("special2", "")), ""))
		var attack: Dictionary = BattleLordSource.ATTACKS.get(ruler_id, {})
		var kin_names := PackedStringArray()
		for hero_id in catalog.content.get("lord_kin", {}).get(ruler_id, []):
			kin_names.append(str(catalog.by_id("heroes", str(hero_id)).get("name", "")))
		var line2 := "Lv.%d　%s%s%s%s　%s%s%s　🤝%s" % [level, LORD_COMMAND_ICONS.get(str(ruler.skill), ""), command.get("name", ""), "　" if not special_text.is_empty() else "", special_text + second_special, LORD_ATTACK_ICONS.get(ruler_id, ""), attack.get("name", ""), "↑" if float(attack.get("mul", 1.0)) > 1.0 else "", "·".join(kin_names)]
		var line2_size := _fit_font_size(line2, rect.end.x - tx - 8.0, int(visual.line2_start_size), int(visual.line2_min_size))
		_text(line2, Vector2(tx, rect.position.y + 38), line2_size, BLUE)
		var desc := str(ruler.desc)
		var desc_size := _fit_font_size(desc, rect.end.x - tx - 10.0, int(visual.desc_start_size), int(visual.desc_min_size))
		_text(desc, Vector2(tx, rect.position.y + 57), desc_size, Color("c9b69a"))
	_rounded_panel(RULER_BACK_RECT, Color("5a4a3a"), Color("8a7d66"), 1.0, 10.0)
	_text_centered_in_rect("← 选关", RULER_BACK_RECT, 13, Color.WHITE)

func _ruler_hints(city: Dictionary, cleared: bool) -> Array:
	var result := []
	if cleared:
		result.append("liubiao")
	for rule_id in city.get("rules", []):
		match str(rule_id):
			"rush", "crossbow": result.append("sunquan")
			"ruin": result.append("liubei")
			"twinBoss", "elite": result.append("gongsunzan")
			"rocks", "rich": result.append("dongzhuo")
	return result

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
	return Rect2(8, 130 + index * 83, 464, 75)

func _ruler_visual_spec(index: int) -> Dictionary:
	var rect := _ruler_rect(index)
	return {
		"corner_radius": 12.0,
		"disc_radius": 19.0,
		"disc_center": Vector2(rect.position.x + 32.0, rect.position.y + rect.size.y / 2.0),
		"text_x": rect.position.x + 62.0,
		"line2_start_size": 12,
		"line2_min_size": 10,
		"desc_start_size": 12,
		"desc_min_size": 10,
	}

func _hero_card_rect(index: int) -> Rect2:
	return Rect2(8 + index * 158, 278, 148, 232)

func _growth_card_rect(index: int) -> Rect2:
	var count: int = battle_run.card_choices.size() if battle_run != null else 3
	var width: float = 86.0 if count >= 5 else (108.0 if count == 4 else 140.0)
	var gap: float = 8.0 if count >= 5 else 10.0
	var total: float = count * width + (count - 1) * gap
	var start_x: float = (480.0 - total) / 2.0
	return Rect2(start_x + index * (width + gap), 294, width, 146)

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
		return "🎁 挑件宝贝 🎁"
	if battle_run != null and battle_run.card_choices.size() >= 5:
		return "📜 门生故吏！五张里挑%s" % ("（还有%d次）" % battle_run.pending_picks if battle_run.pending_picks else "")
	return "✨ 升级！挑一张 ✨%s" % ("（还有%d次）" % battle_run.pending_picks if battle_run != null and battle_run.pending_picks else "")

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
	_draw_battle_backdrop()
	_draw_battle_entities()
	_draw_battle_formation()
	_draw_player_projectiles()
	_draw_battle_skill_events()
	_draw_dance_overlay()
	# The Web battlefield spawns enemies above the playfield. Keep that motion,
	# but paint the opaque HUD last so newly spawned units cannot obscure it.
	_rounded_panel(Rect2(10, 10, 460, 84), Color("00000059"), Color.TRANSPARENT, 0.0, 12.0)
	_text("Lv.%d" % battle_run.level, Vector2(24, 34), 16, GOLD)
	_text("⚔ 第 %d 波" % maxi(battle_run.wave, 1), Vector2(24, 60), 15, PALE_GOLD)
	_text("%s%s" % [str(city.get("icon", "⚡")), str(city.get("tag", city.get("name", "")))], Vector2(88, 34), 12, Color(str(city.get("color", "ffb84a"))))
	_text("击破 %d / %s" % [battle_run.kills, "∞" if battle_run.endless else str(city.killTarget)], Vector2(130, 28), 13, Color.WHITE)
	_rounded_panel(Rect2(130, 34, 330, 10), Color("ffffff26"), Color.TRANSPARENT, 0.0, 5.0)
	_rounded_panel(Rect2(130, 34, minf(330.0, battle_run.kills / float(city.killTarget) * 330.0), 10), Color("9aff5a"), Color.TRANSPARENT, 0.0, 5.0)
	_text("EXP", Vector2(130, 62), 12, Color("8ad2ff"))
	_rounded_panel(Rect2(164, 53, 296, 10), Color("ffffff26"), Color.TRANSPARENT, 0.0, 5.0)
	_rounded_panel(Rect2(164, 53, minf(296.0, battle_run.xp / maxf(1.0, battle_run.xp_need) * 296.0), 10), Color("4ab0ff"), Color.TRANSPARENT, 0.0, 5.0)
	var battle_field: Dictionary = catalog.by_id("fields", str(city.get("field", "")))
	var foe_offset := 46.0 if not battle_run.foe_lord.is_empty() else 0.0
	if foe_offset > 0:
		_draw_foe_lord_status()
	var field_chip_y := 140.0 if foe_offset > 0 else 112.0
	_rounded_panel(Rect2(10, field_chip_y - 14, 118, 19), Color("00000059"), Color.TRANSPARENT, 0.0, 6.0)
	_text("%s%s" % [battle_field.get("icon", ""), battle_field.get("name", "")], Vector2(16, field_chip_y), 12, Color("c9e0a0"))
	if not battle_run.next_wave_preview.is_empty():
		draw_rect(Rect2(128, 130 + foe_offset, 224, 27), Color("17120ce6"), true)
		var threat := _next_wave_threat_text()
		_text_center(_short_text("下波 %.1fs%s" % [maxf(0.0, battle_run.wave_timer), " · " + threat if not threat.is_empty() else ""], 34), 150 + foe_offset, 14, PALE_GOLD)
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
	_draw_battle_side_controls()
	_draw_cata_warning_bar()
	if damage_panel_visible and battle_run.status == "play":
		_draw_damage_panel()
	for layer in _battle_overlay_layers():
		match layer:
			"growth": _draw_growth_cards()
			"unit_info": _draw_unit_info_popup()
			"foe_lord": _draw_foe_lord_popup()
			"player_lord": _draw_player_lord_popup()
			"result": _draw_result()
	_draw_battle_interaction_notice()
	if battle_field_banner_is_visible():
		_draw_battle_field_banner()

func _battle_overlay_layers() -> Array:
	var layers := []
	if battle_run == null:
		return layers
	if battle_run.awaiting_card_choice:
		layers.append("growth")
	if unit_info_popup_is_visible():
		layers.append("unit_info")
	if foe_lord_popup_is_visible():
		layers.append("foe_lord")
	elif battle_run.status != "play":
		layers.append("result")
	if player_lord_popup_is_visible():
		layers.append("player_lord")
	return layers

func player_lord_popup_is_visible() -> bool:
	return player_lord_popup and battle_run != null and battle_run.status == "play"

func player_lord_popup_spec() -> Dictionary:
	if not player_lord_popup_is_visible():
		return {}
	var ruler: Dictionary = catalog.by_id("rulers", battle_run.ruler_id)
	var command: Dictionary = BattleLordSource.COMMANDS.get(battle_run.lord_skill_id, {})
	var attack_estimate := _lord_attack_estimate()
	var attack: Dictionary = attack_estimate.get("attack", {})
	var attack_buff := "（含卡+%d%%）" % roundi(float(battle_run.lord_atk_buff) * 100.0) if float(battle_run.lord_atk_buff) > 0 else ""
	var power: float = battle_run.lord_kin_power()
	var cooldown_line := "冷却 %d 秒" % roundi(battle_run.lord_command_cooldown_max())
	if battle_run.lord_skill_id != "mensheng":
		cooldown_line += "　🤝亲兵助威 ×%.1f" % power if power > 1.0 else "　🤝亲兵上阵可加威力（最多×1.8）"
	var ready: bool = battle_run.lord_command_cd <= 0.0
	return {
		"rect": PLAYER_LORD_POPUP_RECT,
		"cast_rect": Rect2(297, 374, 100, 30) if ready else Rect2(),
		"title": "👑 %s · %s" % [ruler.get("name", "主公"), ruler.get("title", "")],
		"subtitle": "大招自动释放：CD转好、时机一到主公自己放，不用盯",
		"attack_line": "%s 普攻「%s」每%.1f秒：约%d伤%s+3%%目标血" % [attack.get("icon", ""), attack.get("name", "亲射"), float(attack_estimate.get("itv", 0.0)), roundi(float(attack_estimate.get("per", 0.0))), attack_buff],
		"attack_detail": "%s——选卡遇到🎯御驾亲征/⚙️神机连弩可以养他" % attack.get("how", ""),
		"command_icon": LORD_COMMAND_ICONS.get(battle_run.lord_skill_id, "令"),
		"command_name": command.get("name", "号令"),
		"command_level": battle_run.lord_skill_level,
		"command_desc": _lord_command_description(battle_run.lord_skill_id, battle_run.lord_skill_level),
		"auto_tip": LORD_AUTO_TIPS.get(battle_run.lord_skill_id, "CD一转好就放"),
		"cooldown_line": cooldown_line,
	}

func lord_command_visual_spec() -> Dictionary:
	if battle_run == null:
		return {}
	var command: Dictionary = BattleLordSource.COMMANDS.get(battle_run.lord_skill_id, {})
	if command.is_empty():
		return {}
	var ready: bool = battle_run.lord_command_cd <= 0.0
	var level: int = clampi(int(battle_run.lord_skill_level), 1, 3)
	return {
		"rect": LORD_COMMAND_RECT,
		"center": LORD_COMMAND_RECT.get_center(),
		"ready": ready,
		"auto_ready": ready and battle_run.lord_command_auto_ready(),
		"cooldown_fraction": 0.0 if ready else clampf(float(battle_run.lord_command_cd) / maxf(0.1, float(battle_run.lord_command_cd_total)), 0.0, 1.0),
		"cooldown_label": "" if ready else str(ceili(float(battle_run.lord_command_cd))),
		"icon": LORD_COMMAND_ICONS.get(battle_run.lord_skill_id, "令"),
		"name": command.get("name", "号令"),
		"stars": "●".repeat(level) + "○".repeat(3 - level),
	}

func _lord_command_description(skill_id: String, level: int) -> String:
	match skill_id:
		"wuxing": return "%d秒内被克的亏全免，全军伤害再+15%%" % (6 + level * 2)
		"bingfeng": return "全场定住 %.1f秒" % (1.0 + level * 0.7)
		"taoyuan": return "全军金身%d秒刀枪不入（亲兵越多越久）；金身落幕，扛住的伤全额奉还成全场冲击（附1秒眩晕），实伤的8%%再换成经验" % (4 + level * 2)
		"jiejiang": return "拦腰一道大江%d秒：江里的贼变慢40%%、挨打多%d%%，弓贼投石在江里放不了箭" % [5 + level * 2, 20 + level * 10]
		"mensheng": return "接下来 %d 次升级选卡变五选一；手里正摊着牌就当场加宽" % level
		"baima": return "主公亲自下场%d秒：无敌白马专砍特种兵和贼首（亲兵越多砍得越疼越久）" % (5 + level * 2)
		"fenluo": return "烧掉自家2点城墙血，从主公喷出全场扇形巨焰（点燃；亲兵越多烧得越疼）；每烧1血全军攻击+4%（本局永久）"
		"jianhao": return "吃掉一个最弱的兵（星≤3、场上≥5人才动口）连升%d级，祭品每有1星再多升1级；每献祭一次，下道号令等得更久（45→57→69…）" % (3 if level >= 2 else 2)
		_: return ""

func _manual_lord_command_block_notice() -> String:
	var skill_id := str(battle_run.lord_skill_id)
	var command: Dictionary = BattleLordSource.COMMANDS.get(skill_id, {})
	if bool(battle_run.permanent_tactics.get("gewu", false)) and skill_id != "jianhao":
		return "🍷 乐不思蜀，号令没人接"
	var live: Array = battle_run.enemies.filter(func(enemy): return not bool(enemy.get("dead", false)) and float(enemy.get("y", -999.0)) > -10.0)
	if ["wuxing", "bingfeng", "taoyuan", "baima", "fenluo"].has(skill_id) and live.is_empty():
		return "%s%s：场上没贼，时机一到自动放" % [LORD_COMMAND_ICONS.get(skill_id, ""), command.get("name", "号令")]
	if skill_id == "taoyuan" and battle_run.taoyuan_time > 0.0:
		return "🍑 金身还护着呢，不用叠"
	if skill_id == "mensheng" and battle_run.wide_picks > 0 and not (battle_run.awaiting_card_choice and not battle_run.picking_relic and battle_run.card_choices.size() < 5):
		return "📜 门路还没用完：还有%d次五选一，升级选卡就见" % battle_run.wide_picks
	if skill_id == "fenluo" and battle_run.wall < 3:
		return "🔥 城墙都快塌了，烧不得（城血≥3才能点火）"
	if skill_id == "jianhao" and battle_run.lord_system.jianhao_target(battle_run).is_empty():
		return "🪙 玉玺无处下口：场上不足5人，或没有星≤3的祭品"
	return ""

func unit_info_popup_is_visible() -> bool:
	if battle_run == null or unit_info_popup.is_empty() or battle_run.status != "play":
		return false
	var row := int(unit_info_popup.get("row", -1))
	var col := int(unit_info_popup.get("col", -1))
	if not _valid_battle_cell(Vector2i(col, row)):
		return false
	var unit = battle_run.grid[row][col]
	return unit != null and is_same(unit, unit_info_popup.get("unit")) and float(unit.get("hp", 0.0)) > 0.0

func unit_info_popup_spec() -> Dictionary:
	if not unit_info_popup_is_visible():
		return {}
	var unit: Dictionary = unit_info_popup.unit
	var hero: Dictionary = unit.hero
	var hero_id := str(hero.id)
	var row := int(unit_info_popup.row)
	var col := int(unit_info_popup.col)
	var active_bonds := []
	for bond_id in battle_run.team.active_bond_ids():
		var bond: Dictionary = catalog.by_id("bonds", str(bond_id))
		if bond.get("members", []).has(hero_id):
			active_bonds.append(bond)
	var rect := Rect2(85, 290, 310, 206 + (22 if not active_bonds.is_empty() else 0))
	var account: Dictionary = profile.get("heroes", {}).get(hero_id, {})
	var rebirth := int(account.get("rb", 0))
	var account_level := int(account.get("lv", 1))
	var special_class := str(hero.cls) if ["granary", "egg", "dragon"].has(str(hero.cls)) else ""
	var shen_prefix := "神·" if battle_run.shen_ids.has(hero_id) else ""
	var title_base := "%s%s%s" % [shen_prefix, str(hero.name), "" if special_class == "dragon" else " %d星" % int(unit.get("level", 1))]
	if rebirth > 0:
		title_base += " %d转" % rebirth
	var title := title_base
	if battle_run.ult_system.definition(hero_id).size() > 0:
		title += " · 图鉴%d级" % account_level
	var class_copy: Dictionary = UNIT_CLASS_COPY.get(str(hero.cls), {"icon": "兵", "name": str(hero.cls)})
	var element_copy: Dictionary = UNIT_ELEMENT_COPY.get(str(hero.elem), {"icon": "", "name": str(hero.elem), "color": GOLD})
	var badge := "%s%s系 · %s%s · %s" % [element_copy.icon, element_copy.name, class_copy.icon, class_copy.name, _unit_range_text(hero)]
	if account_level > 1:
		badge += " · %d级" % account_level
	var ult: Dictionary = battle_run.ult_system.definition(hero_id)
	var presentation: Dictionary = unit_ultimate_presentation(hero_id)
	var cooldown_max: float = battle_run.ult_system.cooldown_max(battle_run, unit) if not ult.is_empty() else 1.0
	var cooldown := float(unit.get("ultCd", 0.0))
	var cooldown_progress := 1.0 - clampf(cooldown / maxf(0.01, cooldown_max), 0.0, 1.0)
	var condition_text := str(presentation.get("condition", _unit_ult_condition_copy(ult)))
	var cooldown_text := ("能放了 · %s就放" % condition_text) if cooldown_progress >= 0.999 else ("%d秒后能放 · %s就放" % [ceili(cooldown), condition_text])
	var trait_id := str(battle_run.traits.get("%d,%d" % [row, col], ""))
	var trait_text := ""
	if not special_class.is_empty() and not ["guard", "heal"].has(trait_id):
		trait_id = ""
	if not trait_id.is_empty() and DRAG_TRAIT_COPY.has(trait_id):
		var trait_copy: Dictionary = DRAG_TRAIT_COPY[trait_id]
		trait_text = "宝地：%s%s %s" % [trait_copy.icon, trait_copy.name, _crit_text(str(trait_copy.desc))]
	var status_parts := _unit_status_parts(unit, row, col)
	var status_text := "加成：%s" % ("暂时没有" if status_parts.is_empty() else " ".join(status_parts))
	var bond_parts := PackedStringArray()
	for bond in active_bonds:
		bond_parts.append("🔗%s：%s" % [str(bond.get("name", "")), str(bond.get("desc", ""))])
	var special_lines := _special_unit_ledger(unit, special_class)
	return {
		"rect": rect,
		"unit": unit,
		"hero_id": hero_id,
		"source_cell": Vector2i(col, row),
		"title": title,
		"title_base": title_base,
		"hp_text": "❤️%d/%d" % [ceili(float(unit.hp)), ceili(float(unit.hp_max))],
		"badge": badge,
		"element_color": element_copy.color,
		"play_note": _unit_play_note(hero),
		"ultimate_name": str(ult.get("name", "")),
		"ultimate_desc": str(presentation.get("desc", "")),
		"ultimate_line": "" if not special_class.is_empty() else "大招【%s】%s" % [str(ult.get("name", "")), str(presentation.get("desc", ""))],
		"ultimate_type": str(ult.get("type", "dmg")),
		"cooldown_progress": cooldown_progress,
		"cooldown_text": cooldown_text,
		"trait_text": trait_text,
		"status_text": status_text,
		"bond_text": "　".join(bond_parts),
		"special_class": special_class,
		"special_lines": special_lines,
	}

func _special_unit_ledger(unit: Dictionary, special_class: String) -> PackedStringArray:
	var lines := PackedStringArray()
	match special_class:
		"granary":
			var progress := mini(99, roundi(float(unit.get("farmAcc", 0.0)) / maxf(0.01, battle_run.granary_star_need()) * 100.0))
			lines.append("每秒攒 %.1f 粮 · 喂星进度 %d%%（喂身边星最低的）" % [battle_run.granary_rate(unit), progress])
			lines.append("再抽「粮仓扩建」升星：产粮×1.6" if int(unit.get("level", 1)) < 5 else "满星了！再抽「屯田粮仓」能开新仓")
			lines.append("被拆了不算阵亡 · 拖出阵地能卖")
		"egg":
			var level := int(unit.get("level", 1))
			lines.append("🐉 三阶圆满！抽到「应龙觉醒」就破壳" if level >= 3 else "孵到 %d/3 阶 · 这次把握 %d 成" % [level, roundi(battle_run.egg_hatch_chance(unit) * 10.0)])
			if level < 3:
				var helps := PackedStringArray()
				if float(unit.get("hatchBonus", 0.0)) > 0.0: helps.append("失败攒的把握+%d成" % roundi(float(unit.hatchBonus) * 10.0))
				if str(battle_run.traits.get("%d,%d" % [int(unit.row), int(unit.col)], "")) == "elem": helps.append("灵脉+1成")
				if battle_run.relic_ids.has("longxian"): helps.append("龙涎香+2成")
				if float(unit.get("rbuffs", {}).get("farm", 0.0)) > 0.0: helps.append("鲁肃粮草+1成5")
				lines.append(" · ".join(helps) if not helps.is_empty() else "失败不掉阶，下次把握+2成")
			else:
				lines.append("觉醒后比五星英雄还猛，越往后越猛")
			lines.append("被打碎=白孵 · 放灵脉宝地孵得稳")
		"dragon":
			var damage: int = battle_run.dragon_damage(unit)
			var rank := int(unit.get("dragonRank", 1))
			lines.append("重击 %d 伤 · 圈内 %d 伤（跟波次和队伍星级涨）" % [damage * 3, damage])
			lines.append("第%d条应龙：伤害多%d%%" % [rank, roundi(25.0 * (rank - 1))] if rank > 1 else "被镇住的贼头不敢作法 · 什么抗都烧得动")
			lines.append("还能再抽龙蛋，下一条更猛（一局最多两条）" if battle_run.dragon_count < 2 else "双龙圆满——一局的顶配就是这了")
	return lines

func unit_ultimate_presentation(hero_id: String) -> Dictionary:
	return ULT_PRESENTATION.get(hero_id, {})

func _unit_status_parts(unit: Dictionary, row: int, col: int) -> PackedStringArray:
	var result := PackedStringArray()
	var hero: Dictionary = unit.hero
	var hero_class := str(hero.cls)
	var attacks := float(hero.get("dmg", 0.0)) > 0.0
	var rbuffs: Dictionary = unit.get("rbuffs", {})
	if float(rbuffs.get("dmg", 0.0)) > 0: result.append("💧打得更疼")
	if float(rbuffs.get("haste", 0.0)) > 0: result.append("💧水波放更勤" if hero_class == "support" else "💧出手更快")
	if float(rbuffs.get("crit", 0.0)) > 0: result.append("💧更容易%s" % _crit_word())
	if float(rbuffs.get("heal", 0.0)) > 0: result.append("💗持续回血")
	if float(rbuffs.get("cdr", 0.0)) > 0: result.append("🕐大招转更快")
	if float(rbuffs.get("farm", 0.0)) > 0: result.append("🌾吃了鲁肃的波：喂星快+50%")
	if str(hero.id) == "wutugu" and float(unit.get("ultT", 0.0)) > 0: result.append("☠️毒瘴爆发中")
	if float(unit.get("reflectT", 0.0)) > 0: result.append("❄️反伤翻倍")
	if float(unit.get("buffT", 0.0)) > 0: result.append("✨变强中")
	if not battle_run.army_buff.is_empty() and attacks: result.append("🌾全军加攻")
	if not battle_run.army_haste.is_empty() and hero_class != "shield": result.append("🌬️全军提速")
	var kin_ids: Array = catalog.content.get("lord_kin", {}).get(battle_run.ruler_id, [])
	if str(hero.id) == "jiaxu" or kin_ids.has(str(hero.id)): result.append("🤝主公亲军（登场已带星）")
	if battle_run.wuxing_time > 0 and attacks: result.append("☯️三才破敌：被克免罚+15%伤")
	if attacks:
		var adjacent_spears := 0
		for near_row in range(maxi(0, row - 1), mini(BattleRunSource.GRID_ROWS - 1, row + 1) + 1):
			for near_col in range(maxi(0, col - 1), mini(BattleRunSource.GRID_COLS - 1, col + 1) + 1):
				if near_row == row and near_col == col:
					continue
				var neighbour = battle_run.grid[near_row][near_col]
				if neighbour != null and str(neighbour.hero.cls) == "spear":
					adjacent_spears += 1
		if adjacent_spears > 0:
			var aura_percent := roundi(mini(3, adjacent_spears) * (0.10 + float(battle_run.buffs.get("spearAura", 0.0))) * 100.0)
			result.append("🔱攻击+%d%%" % aura_percent)
	if hero_class != "shield" and battle_run._has_adjacent_shield(row, col): result.append("🛡️有盾护着")
	if hero_class != "shield" and battle_run._shield_cover(row, col): result.append("🧱盾墙挡投石")
	if float(unit.get("sealedT", 0.0)) > 0: result.append("🌀被封住了！")
	if str(battle_run.mutations.get(battle_run.wave, "")) == "rainstorm" and (bool(hero.get("burn", false)) or bool(hero.get("firebrand", false))):
		result.append("🌧️大雨之潮，点不着火")
	return result

func _unit_range_text(hero: Dictionary) -> String:
	match str(hero.get("cls", "")):
		"cav": return "冲一整列"
		"shield": return "保护周围单位"
		"support": return "管一圈"
		"granary": return "站着屯粮"
		"egg": return "干孵着"
		"dragon": return "全场横扫"
	var attack_range := float(hero.get("rng", 0.0))
	if attack_range <= 0.0: return "全场都打"
	return "打近处" if attack_range <= 250.0 else ("打半场" if attack_range <= 380.0 else "打得远")

func _unit_play_note(hero: Dictionary) -> String:
	match str(hero.get("cls", "")):
		"spear": return "%s · 旁边人攻击+%d%%" % [str(hero.get("desc", "")), roundi((0.10 + float(battle_run.buffs.get("spearAura", 0.0))) * 100.0)]
		"cav": return "冲左中右贼多的一列·乱军越多越猛(现+%d%%) · %s" % [roundi((battle_run.cavalry_crowd_multiplier() - 1.0) * 100.0), str(hero.get("desc", ""))]
		"shield":
			var current_unit: Dictionary = unit_info_popup.get("unit", {})
			var hp_max := maxf(1.0, float(current_unit.get("hp_max", 1.0)))
			var reflect := roundi(hp_max * (0.04 + float(battle_run.buffs.get("shieldReflect", 0.0))))
			var charge := roundi(100.0 * float(current_unit.get("tanked", 0.0)) / (hp_max * 0.6))
			return "拉仇恨(远箭七成冲他)·挨刀反弹%d点·怒气%d%%攒满反击" % [reflect, charge]
		"support": return "不打人 · 每隔几秒%s" % str(hero.get("desc", ""))
		"granary": return "不打人 · 产粮喂旁边武将升星，敌人能拆它"
		"egg": return "不打人 · 干孵着等觉醒，被打碎就血本无归"
		"dragon": return "每%s秒吐龙息：重击最强的贼头并镇住它，圈内跟着烧" % str(hero.get("rate", 2.8))
	return "射箭 · %s" % str(hero.get("desc", ""))

func _unit_ult_condition_copy(ult: Dictionary) -> String:
	var need := int(ult.get("need", 1))
	match str(ult.get("condition", "")):
		"range": return "跟前有敌人" if need <= 1 else "跟前敌人≥%d" % need
		"column": return "这列有敌人" if need <= 1 else "这列敌人≥%d" % need
		"enemies": return "场上有敌人" if need <= 1 else "敌人≥%d" % need
		"elite": return "场上有大怪"
		"near": return "敌人冲进阵"
		"cluster": return "敌人扎堆≥%d" % need
		"ally_hp": return "有队友受伤"
		"self_hp": return "自己血量危险"
	return "时机合适"

func _draw_unit_info_popup() -> void:
	var spec := unit_info_popup_spec()
	if spec.is_empty():
		return
	var unit: Dictionary = spec.unit
	var cell: Vector2i = spec.source_cell
	_draw_unit_info_range(unit, cell)
	var source_rect := BattleDragControllerSource.cell_rect(cell).grow(1.0)
	_draw_dashed_rounded_rect(source_rect, 10.0, GOLD, 3.0, 6.0, 4.0)
	var rect: Rect2 = spec.rect
	_rounded_panel(rect, Color("181208f5"), GOLD, 2.5, 14.0)
	var hp_width := _font().get_string_size(str(spec.hp_text), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var title_max_width := rect.size.x - 34.0 - hp_width - 12.0
	var visible_title := str(spec.title)
	if _font().get_string_size(visible_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x > title_max_width:
		visible_title = str(spec.title_base)
	var title_font_size := _fit_font_size(visible_title, title_max_width, 19, 15)
	_text(visible_title, rect.position + Vector2(18, 30), title_font_size, GOLD)
	draw_string(_font(), rect.position + Vector2(rect.size.x - 112, 30), str(spec.hp_text), HORIZONTAL_ALIGNMENT_RIGHT, 96, 13, GREEN if float(unit.hp) >= float(unit.hp_max) * 0.4 else RED)
	var badge_rect := Rect2(rect.position + Vector2(24, 40), Vector2(rect.size.x - 48, 24))
	_rounded_panel(badge_rect, Color("00000066"), spec.element_color, 1.5, 8.0)
	_text_centered_in_rect(str(spec.badge), badge_rect, 13, spec.element_color)
	_text_centered_in_rect(str(spec.play_note), Rect2(rect.position + Vector2(10, 70), Vector2(rect.size.x - 20, 22)), 13, Color("e8dcc0"))
	if str(spec.special_class).is_empty():
		var ult_color: Color = {"dmg": Color("ff8a5a"), "ctrl": Color("8ad2ff"), "def": Color("9adf5a"), "exec": Color("ffd24a"), "util": Color("c9a8ff")}.get(str(spec.ultimate_type), GOLD)
		_text_centered_in_rect(str(spec.ultimate_line), Rect2(rect.position + Vector2(10, 94), Vector2(rect.size.x - 20, 22)), 13, ult_color)
		var cooldown_rect := Rect2(rect.position + Vector2(40, 118), Vector2(rect.size.x - 80, 8))
		_rounded_panel(cooldown_rect, Color("ffffff26"), Color.TRANSPARENT, 0.0, 4.0)
		if float(spec.cooldown_progress) > 0.0:
			_rounded_panel(Rect2(cooldown_rect.position, Vector2(cooldown_rect.size.x * float(spec.cooldown_progress), cooldown_rect.size.y)), ult_color, Color.TRANSPARENT, 0.0, 4.0)
		_text_centered_in_rect(str(spec.cooldown_text), Rect2(rect.position + Vector2(8, 130), Vector2(rect.size.x - 16, 20)), 12, GREEN if float(spec.cooldown_progress) >= 0.999 else Color("c9b69a"))
	else:
		var ledger_color: Color = {"granary": Color("e8c86a"), "egg": Color("c9a8ff"), "dragon": Color("8ad2ff")}.get(str(spec.special_class), GOLD)
		for index in spec.special_lines.size():
			var line := str(spec.special_lines[index])
			var line_size := _fit_font_size(line, rect.size.x - 18.0, 14 if index == 0 else 13, 11)
			_text_centered_in_rect(line, Rect2(rect.position + Vector2(6, 94 + index * 20), Vector2(rect.size.x - 12, 20)), line_size, ledger_color if index == 0 else Color("c9b69a"))
	draw_line(rect.position + Vector2(26, 156), rect.position + Vector2(rect.size.x - 26, 156), Color("ffffff24"), 1.0)
	var status_y := 164.0
	if not str(spec.trait_text).is_empty():
		_text_centered_in_rect(str(spec.trait_text), Rect2(rect.position + Vector2(8, 160), Vector2(rect.size.x - 16, 18)), 12, GOLD)
		status_y = 180.0
	var status_font_size := _fit_font_size(str(spec.status_text), rect.size.x - 24.0, 13, 12)
	_text_centered_in_rect(str(spec.status_text), Rect2(rect.position + Vector2(8, status_y), Vector2(rect.size.x - 16, 18)), status_font_size, GREEN if str(spec.status_text) != "加成：暂时没有" else Color("ffffff73"))
	if not str(spec.bond_text).is_empty():
		var bond_font_size := _fit_font_size(str(spec.bond_text), rect.size.x - 24.0, 13, 12)
		_text_centered_in_rect(str(spec.bond_text), Rect2(rect.position + Vector2(8, status_y + 20), Vector2(rect.size.x - 16, 18)), bond_font_size, GOLD)
	_text_centered_in_rect("点别处关闭（已暂停）", Rect2(rect.position + Vector2(0, rect.size.y + 5), Vector2(rect.size.x, 18)), 12, Color("ffffff8c"))

func _draw_unit_info_range(unit: Dictionary, cell: Vector2i) -> void:
	var spec := _drag_preview_spec(unit, cell)
	var anchor: Vector2 = spec.anchor
	var color: Color = UNIT_ELEMENT_COPY.get(str(unit.hero.elem), {"color": GOLD}).color
	match str(spec.kind):
		"corridor":
			for corridor_x in spec.get("adjacent_corridors", []):
				draw_rect(Rect2(float(corridor_x) - float(spec.width), 30, float(spec.width) * 2.0, anchor.y - 78.0), Color(color, 0.05), true)
			var corridor_rect := Rect2(anchor.x - float(spec.width), 30, float(spec.width) * 2.0, anchor.y - 78.0)
			draw_rect(corridor_rect, Color(color, 0.12), true)
			_draw_dashed_rect(corridor_rect, Color(color, 0.5), 2.0, 10.0, 8.0)
		"ripple", "range":
			draw_circle(anchor - Vector2(0, 18), float(spec.radius), Color(color, 0.07))
			_draw_dashed_arc(anchor - Vector2(0, 18), float(spec.radius), 0.0, TAU, Color(color, 0.55), 2.0, 8.0, 6.0)

func _draw_dashed_arc(center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color, width: float, dash: float, gap: float) -> void:
	if radius <= 0.0 or end_angle <= start_angle:
		return
	var cycle_angle := (dash + gap) / radius
	var dash_angle := dash / radius
	var angle := start_angle
	while angle < end_angle:
		var dash_end := minf(end_angle, angle + dash_angle)
		var points := maxi(2, ceili((dash_end - angle) * radius / 4.0))
		draw_arc(center, radius, angle, dash_end, points, color, width, true)
		angle += cycle_angle

func _draw_dashed_rect(rect: Rect2, color: Color, width: float, dash: float, gap: float) -> void:
	draw_dashed_line(rect.position, Vector2(rect.end.x, rect.position.y), color, width, dash, false, true)
	draw_dashed_line(Vector2(rect.end.x, rect.position.y), rect.end, color, width, dash, false, true)
	draw_dashed_line(rect.end, Vector2(rect.position.x, rect.end.y), color, width, dash, false, true)
	draw_dashed_line(Vector2(rect.position.x, rect.end.y), rect.position, color, width, dash, false, true)

func _draw_dashed_rounded_rect(rect: Rect2, radius: float, color: Color, width: float, dash: float, gap: float) -> void:
	draw_dashed_line(rect.position + Vector2(radius, 0), Vector2(rect.end.x - radius, rect.position.y), color, width, dash, false, true)
	draw_dashed_line(Vector2(rect.end.x, rect.position.y + radius), Vector2(rect.end.x, rect.end.y - radius), color, width, dash, false, true)
	draw_dashed_line(Vector2(rect.end.x - radius, rect.end.y), Vector2(rect.position.x + radius, rect.end.y), color, width, dash, false, true)
	draw_dashed_line(Vector2(rect.position.x, rect.end.y - radius), Vector2(rect.position.x, rect.position.y + radius), color, width, dash, false, true)
	_draw_dashed_arc(rect.position + Vector2(radius, radius), radius, PI, PI * 1.5, color, width, dash, gap)
	_draw_dashed_arc(Vector2(rect.end.x - radius, rect.position.y + radius), radius, PI * 1.5, TAU, color, width, dash, gap)
	_draw_dashed_arc(rect.end - Vector2(radius, radius), radius, 0.0, PI * 0.5, color, width, dash, gap)
	_draw_dashed_arc(Vector2(rect.position.x + radius, rect.end.y - radius), radius, PI * 0.5, PI, color, width, dash, gap)

func _draw_battle_interaction_notice() -> void:
	if battle_interaction_notice.is_empty():
		return
	var position: Vector2 = battle_interaction_notice.position
	var alpha := clampf(float(battle_interaction_notice.time) / 0.35, 0.0, 1.0)
	var color: Color = battle_interaction_notice.color
	color.a *= alpha
	_text_centered_in_rect(str(battle_interaction_notice.text), Rect2(clampf(position.x - 160.0, 6.0, 154.0), position.y - 20.0, 320.0, 24.0), 14, color)

func _dance_overlay_spec() -> Dictionary:
	if battle_run == null or battle_run.dance_time <= 0.0:
		return {"alpha": 0.0, "veil_alpha": 0.0, "center_y": 336.0}
	var fade := minf(1.0, minf((3.0 - battle_run.dance_time) * 3.0, battle_run.dance_time * 2.0))
	return {"alpha": maxf(0.0, fade), "veil_alpha": maxf(0.0, fade) * 0.55, "center_y": 336.0}

func _draw_dance_overlay() -> void:
	var spec := _dance_overlay_spec()
	var alpha := float(spec.alpha)
	if alpha <= 0.0:
		return
	draw_rect(Rect2(0, 0, 480, 800), Color(70.0 / 255.0, 12.0 / 255.0, 40.0 / 255.0, float(spec.veil_alpha)), true)
	var center_y := float(spec.center_y)
	var dancers := [[-120.0, 52, 1.1], [0.0, 96, 0.0], [120.0, 52, 2.3]]
	for dancer in dancers:
		var phase_offset := float(dancer[2])
		var x := 240.0 + float(dancer[0]) + sin(float(battle_run.game_time) * 3.0 + phase_offset) * 12.0
		var y := center_y + sin(float(battle_run.game_time) * 5.0 + phase_offset) * 6.0
		_card_text_center("💃", x, y, int(dancer[1]), Color(1, 1, 1, alpha), float(dancer[1]) * 1.4)
	for index in 12:
		var flower_x := fposmod(float(index * 97 + 41) + sin(float(battle_run.game_time) * 1.5 + index) * 30.0, 480.0)
		var flower_y := fposmod(float(index * 173) + float(battle_run.game_time) * 90.0, 840.0) - 20.0
		_card_text_center("🌸" if index % 3 else "🎵", flower_x, flower_y, 18, Color(1, 1, 1, alpha), 40.0)
	_text_center("此间乐，不思蜀……", center_y + 96.0, 20, Color(1.0, 0.784, 0.878, alpha))
	_text_center("（全军攻击+30%；点击屏幕可重回朝堂）", center_y + 118.0, 12, Color(1, 1, 1, alpha * 0.75))

func _draw_battle_backdrop() -> void:
	for y in range(0, 800, 4):
		draw_rect(Rect2(0, y, 480, 4), _battle_backdrop_color_at(y + 2.0), true)
	for index in 26:
		var x := fmod(index * 137.5, 480.0)
		var y := fmod(index * 89.3 + float(battle_run.game_time) * 6.0, 432.0)
		draw_rect(Rect2(x, y, 2, 2), Color("ffdc9624"), true)

func _battle_backdrop_color_at(y: float) -> Color:
	var clamped_y := clampf(y, 0.0, 800.0)
	if clamped_y <= 400.0:
		return Color("2a2012").lerp(Color("3a2c18"), clamped_y / 400.0)
	if clamped_y <= 496.0:
		return Color("3a2c18").lerp(Color("44341e"), (clamped_y - 400.0) / 96.0)
	return Color("44341e").lerp(Color("2a2012"), (clamped_y - 496.0) / 304.0)

func _draw_battle_side_controls() -> void:
	_rounded_panel(BATTLE_MUTE_RECT, Color("3a5a6a") if sound_enabled else Color("5a3a3a"), Color("ffffff4d"), 1.5, 10.0)
	_text_centered_in_rect("🔊音效" if sound_enabled else "🔇静音", BATTLE_MUTE_RECT, 12, Color.WHITE)
	_rounded_panel(BATTLE_QUIT_RECT, Color("8a3a2a") if quit_armed else Color("4a4048"), Color("ffffff4d"), 1.5, 10.0)
	_text_centered_in_rect("真退?" if quit_armed else "🚪退出", BATTLE_QUIT_RECT, 12, Color.WHITE)
	_rounded_panel(BATTLE_DMG_RECT, Color("5a7a3a") if damage_panel_visible else Color("3a4a5a"), Color("ffffff4d"), 1.5, 10.0)
	_text_centered_in_rect("📊输出", BATTLE_DMG_RECT, 11, Color.WHITE)
	var ruler: Dictionary = catalog.by_id("rulers", battle_run.ruler_id)
	_rounded_panel(LORD_NAME_RECT, Color("140e06d9"), Color("ffd74a99"), 1.2, 8.0)
	_text_centered_in_rect("👑%s" % ruler.get("name", ""), LORD_NAME_RECT, 12, GOLD)

func _draw_player_lord_popup() -> void:
	var spec := player_lord_popup_spec()
	if spec.is_empty():
		return
	var rect: Rect2 = spec.rect
	draw_rect(Rect2(0, 0, 480, 800), Color("00000099"), true)
	_rounded_panel(rect, Color("1e180cf7"), GOLD, 2.0, 14.0)
	_text_centered_in_rect(str(spec.title), Rect2(rect.position.x, rect.position.y + 12, rect.size.x, 28), 22, GOLD)
	_text_centered_in_rect(str(spec.subtitle), Rect2(rect.position.x, rect.position.y + 43, rect.size.x, 20), 13, Color("8a7d5a"))
	_text(str(spec.attack_line), rect.position + Vector2(22, 82), 13, Color("ffb84a"))
	_text(str(spec.attack_detail), rect.position + Vector2(22, 100), 12, Color("c9b69a"))
	var command_y := rect.position.y + 126.0
	var command_rect := Rect2(rect.position.x + 10, command_y - 6, rect.size.x - 20, 140)
	_rounded_panel(command_rect, Color("ffffff0d"), Color.TRANSPARENT, 0.0, 10.0)
	_text("%s %s" % [spec.command_icon, spec.command_name], Vector2(rect.position.x + 22, command_y + 14), 16, GOLD)
	_text("%d星（主公 Lv.%d，局外练主公涨威力）" % [int(spec.command_level), int(battle_run.ruler_level)], Vector2(rect.position.x + 22, command_y + 34), 13, Color("c9a8ff"))
	_draw_wrapped_left(str(spec.command_desc), Vector2(rect.position.x + 22, command_y + 54), rect.size.x - 44, 14, Color("e8dcc0"), 18.0, 2)
	_text("⚙️ 自动时机：%s" % spec.auto_tip, Vector2(rect.position.x + 22, command_y + 92), 12, GREEN)
	_text(str(spec.cooldown_line), Vector2(rect.position.x + 22, command_y + 110), 13, Color("8ad2ff"))
	var cast_rect: Rect2 = spec.cast_rect
	if cast_rect.size != Vector2.ZERO:
		_rounded_panel(cast_rect, Color("6a4a2a"), GOLD, 2.0, 8.0)
		_text_centered_in_rect("⚡立刻施放", cast_rect, 14, Color("ffe8b0"))
	_text_centered_in_rect("点别处关闭（已暂停）", Rect2(rect.position.x, rect.end.y + 5, rect.size.x, 20), 13, Color("ffffff8c"))

func _draw_cata_warning_bar() -> void:
	var rect := _cata_warning_rect()
	if rect.size == Vector2.ZERO:
		return
	var count: int = battle_run.enemies.filter(func(enemy): return not bool(enemy.get("dead", false)) and str(enemy.get("special", "")) == "cata").size()
	var pulse := 0.5 + 0.5 * sin(float(battle_run.game_time) * 5.0)
	draw_rect(rect.grow(3.0 + pulse * 2.0), Color(1.0, 0.2, 0.1, 0.08 + pulse * 0.08), true)
	_panel(rect, Color("480c08f5"), Color(1.0, 0.43, 0.27, 0.7 + pulse * 0.3), 2.0)
	_text_centered_in_rect("🏗️ 投石车×%d 砸墙中——点这条集火!" % count, rect, 15, Color("ffc0a8"))

func _draw_battle_field_banner() -> void:
	var city: Dictionary = battle_run.city
	var field: Dictionary = catalog.by_id("fields", str(city.get("field", "")))
	var rect := battle_field_banner_rect()
	var alpha := battle_field_banner_alpha()
	_rounded_panel(rect, _alpha_multiplied(Color("181208eb"), alpha), _alpha_multiplied(Color("e8c86acc"), alpha), 2.0, 12.0)
	_text_centered_in_rect("%s %s · %s%s" % [city.get("icon", "⚡"), city.get("name", "本州"), field.get("icon", ""), field.get("name", "")], Rect2(rect.position.x, rect.position.y + 11, rect.size.x, 24), 19, _alpha_multiplied(GOLD, alpha))
	_text_centered_in_rect(str(field.get("desc", "")).replace("｜", "，"), Rect2(rect.position.x, rect.position.y + 42, rect.size.x, 22), 13, _alpha_multiplied(Color("e8dcc0"), alpha))
	var tri: Dictionary = TRI_DISPLAY.get(str(city.get("foes", {}).get("tri", "badao")), TRI_DISPLAY.badao)
	var counter: Dictionary = TRI_DISPLAY.get(str(tri.counter), TRI_DISPLAY.rende)
	var baseline_y := rect.position.y + 77
	_text_centered_in_rect("这州的贼是%s%s——带%s%s打他最疼" % [tri.icon, tri.name, counter.icon, counter.name], Rect2(rect.position.x, baseline_y - 13, rect.size.x, 22), 13, _alpha_multiplied(Color("9adf5a"), alpha))
	if not battle_run.foe_lord.is_empty():
		baseline_y += 20
		var foe_def: Dictionary = battle_run.foe_lord.get("def", {})
		_text_centered_in_rect("%s 本关渠帅：%s·%s（第8波起施法）" % [foe_def.get("icon", ""), foe_def.get("name", "渠帅"), foe_def.get("title", "")], Rect2(rect.position.x, baseline_y - 13, rect.size.x, 20), 13, _alpha_multiplied(Color("ff9a8a"), alpha))
	var rules: Array = city.get("rules", [])
	for rule_id in rules:
		baseline_y += 17
		var rule: Dictionary = catalog.by_id("level_rules", str(rule_id))
		_text_centered_in_rect("⚠️ %s：%s" % [rule.get("short", rule_id), rule.get("tip", "")], Rect2(rect.position.x, baseline_y - 11, rect.size.x, 18), 11, _alpha_multiplied(Color("ffb84a"), alpha))
	_text_centered_in_rect("点一下知道了 · 左上角小牌子随时能再看", Rect2(rect.position.x, rect.end.y - 25, rect.size.x, 16), 11, _alpha_multiplied(Color("ffffff80"), alpha))

func _battle_field_chip_rect() -> Rect2:
	# Preserve the Web v7.19.14 hitbox, including its fixed y=96 position.
	return Rect2(10, 96, 120, 22)

func battle_field_banner_rect() -> Rect2:
	if battle_run == null:
		return Rect2(8, 138, 392, 92)
	var city: Dictionary = battle_run.city
	var height := 92
	if not city.get("foes", {}).is_empty():
		height += 22
	height += city.get("rules", []).size() * 17
	return Rect2(8, 138, 392, height)

func battle_field_banner_is_visible() -> bool:
	return battle_run != null and battle_run.status == "play" and battle_field_banner_time > 0.0

func battle_field_banner_alpha() -> float:
	return clampf(battle_field_banner_time, 0.0, 1.0)

static func _alpha_multiplied(color: Color, multiplier: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * multiplier)

func _draw_damage_panel() -> void:
	var rect := Rect2(85, 244, 310, 122)
	draw_rect(rect, Color("0c0904e8"), true)
	draw_rect(rect, Color("8a7d5a"), false, 1.2)
	_text_centered_in_rect("📊 实时输出", Rect2(85, 252, 310, 22), 13, GOLD)
	var rows: Array = battle_run.units().duplicate()
	rows.sort_custom(func(a, b): return float(a.get("damage_dealt", 0.0)) > float(b.get("damage_dealt", 0.0)))
	for index in mini(4, rows.size()):
		var unit: Dictionary = rows[index]
		_text("%s　累计 %.0f" % [unit.hero.name, float(unit.get("damage_dealt", 0.0))], Vector2(102, 290 + index * 18), 10, Color("c9b69a"))

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
	var report_rows := battle_report_rows()
	var report_gap := 20.0 if report_rows.size() > 4 else 29.0
	for index in report_rows.size():
		var report_row: Dictionary = report_rows[index]
		var report_y := 389.0 + index * report_gap
		_text(str(report_row.label), Vector2(48, report_y), 12 if report_rows.size() > 4 else 13, Color("a89a76"))
		var report_value := str(report_row.value)
		var report_value_size := _fit_font_size(report_value, 210.0, 12 if report_rows.size() > 4 else 14, 10)
		draw_string(_font(), Vector2(220, report_y), report_value, HORIZONTAL_ALIGNMENT_RIGHT, 210, report_value_size, report_row.color)

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

func battle_report_rows() -> Array:
	if battle_run == null:
		return []
	var counter_pct := roundi(battle_run.counter_damage / battle_run.total_damage * 100.0) if battle_run.total_damage > 0 else 0
	var rows := [
		{"label": "⚔ 击破", "value": "%d 个贼" % battle_run.kills, "color": GREEN},
		{"label": "💢 最重一击", "value": "%d" % battle_run.max_hit, "color": GREEN},
		{"label": "💥 绝技施放", "value": "%d 次" % battle_run.ults_used, "color": GREEN},
		{"label": "☱ 克制伤害占比", "value": "%d%%" % counter_pct, "color": GREEN if counter_pct >= 35 else PALE_GOLD},
	]
	if battle_run.farm_stars > 0:
		rows.append({"label": "🌾 屯田喂星", "value": "%d 颗" % battle_run.farm_stars, "color": Color("e8c86a")})
	if battle_run.dragon_count > 0:
		var wave_text := "、".join(battle_run.dragon_waves.map(func(value): return str(value)))
		rows.append({"label": "🐉 觉醒应龙", "value": "%d 条（第%s波破壳）" % [battle_run.dragon_count, wave_text], "color": BLUE})
	return rows

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
		var link_alpha := 0.35 + sin(float(battle_run.game_time) * 6.0) * 0.2
		for index in members.size() - 1:
			var from := Vector2(float(members[index].x), float(members[index].y))
			var to := Vector2(float(members[index + 1].x), float(members[index + 1].y))
			draw_line(from, to, Color(Color("c9a8ff"), link_alpha), 2.5)
			_text_centered_in_rect("⛓️", Rect2(from.lerp(to, 0.5) - Vector2(10, 9), Vector2(20, 18)), 12, Color.WHITE)
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
			"shield_counter":
				var counter_age := 1.0 - clampf(float(event.t) / 0.55, 0.0, 1.0)
				var counter_radius := 12.0 + counter_age * 34.0
				draw_circle(event_pos, 18.0 * (1.0 - counter_age), Color(1.0, 0.82, 0.25, 0.28 * (1.0 - counter_age)))
				draw_arc(event_pos, counter_radius, 0, TAU, 28, Color(1.0, 0.82, 0.25, 1.0 - counter_age), 3.0)
				for spoke in 8:
					var direction := Vector2.RIGHT.rotated(TAU * float(spoke) / 8.0)
					draw_line(event_pos + direction * (counter_radius - 5.0), event_pos + direction * (counter_radius + 8.0), Color(1.0, 0.9, 0.45, 1.0 - counter_age), 2.0)
				_text_centered_in_rect(str(event.get("label", "蓄势反击!")), Rect2(event_pos.x - 70.0, event_pos.y - 48.0 - counter_age * 12.0, 140.0, 20.0), 14, GOLD)
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
			elif special == "cata" and enemy.has("cataWind"):
				var wind_progress := clampf(1.0 - float(enemy.cataWind) / 2.0, 0.0, 1.0)
				draw_arc(position, radius + 7.0, -PI / 2.0, -PI / 2.0 + TAU * wind_progress, 36, Color("ff783ce8"), 3.5)
				if wind_progress > 0.72:
					_text_centered_in_rect("🏗️蓄力中!", Rect2(position.x - 58, position.y - radius - 30, 116, 18), 12, Color("ff9a5a"))
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

func _battle_render_layers() -> Array:
	return ["backdrop", "entities", "formation", "projectiles", "skill_fx", "hud", "cata_bar", "growth_cards", "foe_popup", "field_banner"]

func _draw_player_projectiles() -> void:
	for line in battle_run.skill_lines:
		var alpha := clampf(float(line.t) / maxf(0.01, float(line.t_max)), 0.0, 1.0)
		var line_color := Color(str(line.color))
		line_color.a = alpha
		draw_line(line.from, line.to, Color(line_color, alpha * 0.22), float(line.width) + 5.0)
		draw_line(line.from, line.to, line_color, float(line.width))
	for projectile in battle_run.projectiles:
		draw_circle(Vector2(float(projectile.x), float(projectile.y)), maxf(4.0, float(projectile.get("r", 4.0))), GOLD)
	for lob in battle_run.friendly_lobs:
		var progress := clampf(float(lob.t) / maxf(0.01, float(lob.dur)), 0.0, 1.0)
		var lob_position := Vector2(float(lob.x0), float(lob.y0)).lerp(Vector2(float(lob.x1), float(lob.y1)), progress) - Vector2(0, sin(progress * PI) * 80.0)
		var previous_progress := maxf(0.0, progress - 0.08)
		var previous_position := Vector2(float(lob.x0), float(lob.y0)).lerp(Vector2(float(lob.x1), float(lob.y1)), previous_progress) - Vector2(0, sin(previous_progress * PI) * 80.0)
		var lob_color := Color(str(lob.get("color", "ffd24a")))
		draw_line(previous_position, lob_position, Color(lob_color, 0.55), 3.0)
		draw_circle(lob_position, 8.0, Color(lob_color, 0.18))
		draw_circle(lob_position, 4.5, lob_color)
		_text_centered_in_rect(str(lob.get("icon", "●")), Rect2(lob_position.x - 12, lob_position.y - 12, 24, 24), 18, Color(str(lob.get("color", "ffd24a"))))
	for homer in battle_run.homers:
		var homer_position := Vector2(float(homer.x), float(homer.y))
		var homer_velocity := Vector2(float(homer.vx), float(homer.vy))
		draw_line(homer_position - homer_velocity * 0.06, homer_position, Color("ff8c3c99"), 2.5)
		draw_circle(homer_position, 9.0, Color("ff7a3a24"))
		draw_circle(homer_position, 5.5, Color(str(homer.get("color", "ff7a3a"))))
		draw_circle(homer_position, 2.2, Color("ffffdce6"))

func _draw_battle_skill_events() -> void:
	_draw_focus_order()
	for event in battle_run.lord_command_events:
		var command: Dictionary = BattleLordSource.COMMANDS.get(str(event.id), {})
		if not command.is_empty():
			_text_center("主公号令 · %s！" % command.name, 264, 20, GOLD)
	for event in battle_run.ult_events:
		_draw_ult_visual_event(event)
		var event_color: Color = {"dmg": Color("ff9a5a"), "ctrl": Color("8ad2ff"), "def": Color("9adf5a"), "util": Color("c9a8ff"), "exec": GOLD}.get(str(event.type), GOLD)
		_text_center("绝技【%s】" % str(event.name), 238, 20, event_color)

func _draw_focus_order() -> void:
	if battle_run.focus_target.is_empty() or battle_run.focus_time <= 0.0 or bool(battle_run.focus_target.get("dead", false)):
		return
	var target: Dictionary = battle_run.focus_target
	var target_position := Vector2(float(target.x), float(target.y))
	var pulse := 0.5 + 0.5 * sin(float(battle_run.game_time) * 8.0)
	for unit in battle_run.units():
		var center := BattleRunSource.slot_center(int(unit.row), int(unit.col)) - Vector2(0, 14)
		var attack_range: float = battle_run.effective_archer_range(unit.hero)
		if battle_run._focused_target_for_unit(unit, center, attack_range).is_empty():
			continue
		draw_line(center, target_position, Color(1.0, 0.35, 0.3, 0.2 + pulse * 0.08), 1.5)
	draw_arc(target_position, float(target.r) + 7.0, 0, TAU, 36, Color(1.0, 0.31, 0.27, 0.65 + pulse * 0.25), 2.0)
	_text_centered_in_rect("🎯集火", Rect2(target_position.x - 42, target_position.y - float(target.r) - 31, 84, 18), 13, Color("ff8a7a"))

func _draw_ult_visual_event(event: Dictionary) -> void:
	if not event.has("origin"):
		return
	var origin: Vector2 = event.origin
	var duration := maxf(0.01, float(event.get("duration", 1.6)))
	var progress := clampf(1.0 - float(event.get("t", 0.0)) / duration, 0.0, 1.0)
	var color: Color = {"dmg": Color("ff8a5a"), "ctrl": Color("8ad2ff"), "def": Color("9adf5a"), "util": Color("c9a8ff"), "exec": GOLD}.get(str(event.get("type", "")), GOLD)
	var effect := str(event.get("effect", ""))
	match effect:
		"fan":
			for index in 9:
				var angle := -PI / 2.0 + (index - 4) * 0.12
				var length := 70.0 + 130.0 * progress
				draw_line(origin, origin + Vector2(cos(angle), sin(angle)) * length, Color(color, 0.85 - progress * 0.35), 2.0)
		"lightning":
			pass # Ma Chao uses target-locked Web beam entities.
		"lane", "row":
			pass # Guan Yu, Pang De, and Deng Ai use exact Web line geometry.
		"charge", "multi_charge":
			draw_line(origin, Vector2(origin.x, 70), Color(color, 0.25), 34.0)
			draw_line(origin, Vector2(origin.x, 70), color, 3.0)
		"homing":
			pass # Jiang Wei's eight live homers carry the complete Web effect.
		"arrow_rain", "turret_deploy":
			pass # Live lob entities carry the falling-arrow and deployment geometry.
		"fire_beam", "gather_lines", "clock_links":
			pass # Targeted Web beam entities carry these three ultimates.
		"death_links":
			pass # The persistent enemy chain renders from its live member positions.
		"snipe":
			pass # Huang Zhong uses the selected elite's actual endpoint.
		"duel":
			pass # Wen Chou uses the marked target's actual endpoint.
		"ricochet", "bounce", "execute":
			draw_line(origin, origin + Vector2(0, -220), color, 4.0)
			draw_circle(origin + Vector2(0, -220), 8.0 + 12.0 * progress, Color(color, 0.35))
		"fire_pit", "fire_line", "immolate", "bombard":
			draw_circle(origin + Vector2(0, -70), 36.0 + 90.0 * progress, Color(color, 0.12))
			draw_arc(origin + Vector2(0, -70), 36.0 + 90.0 * progress, 0, TAU, 40, color, 2.5)
		"charm":
			for index in 6:
				var angle := progress * TAU + index * TAU / 6.0
				_text_centered_in_rect("💗", Rect2(origin + Vector2(cos(angle), sin(angle)) * (28.0 + 45.0 * progress) - Vector2(9, 9), Vector2(18, 18)), 10, Color.WHITE)
		"trap", "barricade", "palisade", "turret", "gather":
			draw_arc(origin, 30.0 + 110.0 * progress, 0, TAU, 40, color, 2.0)
			draw_line(origin + Vector2(-90, -40), origin + Vector2(90, -40), Color(color, 0.65), 3.0)
		"link":
			for index in 5:
				var point := origin + Vector2((index - 2) * 48.0, -70.0 - abs(index - 2) * 16.0)
				draw_line(origin, point, Color(color, 0.7), 2.0)
				draw_circle(point, 6, color)
		"heal", "haste", "army_buff", "reflect", "guard", "clock":
			draw_arc(origin, 28.0 + 95.0 * progress, 0, TAU, 48, color, 3.0)
			_text_centered_in_rect("✦", Rect2(origin.x - 14, origin.y - 82 - 30 * progress, 28, 28), 18, color)
		"cleave":
			pass # Dian Wei uses a target-locked slash line.
		"poison", "frost", "ice_wave", "fear", "sleep", "sunder", "sheep", "shock", "blast":
			draw_circle(origin, 24.0 + 150.0 * progress, Color(color, 0.08))
			draw_arc(origin, 24.0 + 150.0 * progress, 0, TAU, 48, color, 2.5)

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
			var rect := BattleDragControllerSource.cell_rect(Vector2i(col, row))
			var is_obstacle: bool = battle_run.obstacles.has(key)
			var cell_fill := Color("3c32248c") if is_obstacle else (Color("ffebb417") if (row + col) % 2 == 0 else Color("ffebb40d"))
			_rounded_panel(rect, cell_fill, Color.TRANSPARENT, 0.0, 10.0)
			if battle_run.obstacles.has(key):
				_text_centered_in_rect("🪨" if (row + col) % 2 else "🌲", Rect2(rect.position.x, rect.position.y + 20, rect.size.x, 32), 26, Color.WHITE)
			if battle_run.traits.has(key):
				var trait_data: Dictionary = TRAIT_DISPLAY.get(str(battle_run.traits[key]), {})
				var trait_color := Color("ffffff66") if is_obstacle else Color("ffffffd9")
				draw_string(_font(), Vector2(rect.end.x - 25, rect.end.y - 7), str(trait_data.get("icon", "")), HORIZONTAL_ALIGNMENT_RIGHT, 20, 11, trait_color)
			if is_obstacle:
				continue
			var unit = battle_run.grid[row][col]
			if unit == null:
				continue
			if battle_drag.is_active() and battle_drag.source_cell == Vector2i(col, row):
				continue
			_draw_battle_unit(unit, rect.get_center(), 1.0, row, col)
	_draw_battle_drag_preview()
	var wall_y := BattleRunSource.DEFENSE_LINE - 2.0
	for y in range(int(wall_y), 800, 2):
		draw_rect(Rect2(0, y, 480, 2), _battle_wall_color_at(y), true)
	for x in range(0, 480, 40):
		draw_rect(Rect2(x + 4, wall_y - 8, 24, 8), Color("6a563c"), true)
	for x in range(0, 480, 48):
		draw_line(Vector2(x, wall_y + 8), Vector2(x, 800), Color("00000040"), 1.0)
	draw_line(Vector2(0, wall_y + 14), Vector2(480, wall_y + 14), Color("00000040"), 1.0)
	var ruler: Dictionary = catalog.by_id("rulers", battle_run.ruler_id)
	if battle_run.lord_mount.is_empty():
		var lord_center := Vector2(240, BattleRunSource.DEFENSE_LINE + 26)
		draw_circle(lord_center, 20, Color("6a4a2a"))
		draw_arc(lord_center, 20, 0, TAU, 32, GOLD if battle_run.lord_kin_power() > 1.0 else Color("ffdc9999"), 2.5 if battle_run.lord_kin_power() > 1.0 else 1.5)
		_text_centered_in_rect(str(ruler.name), Rect2(lord_center.x - 26, lord_center.y - 12, 52, 26), 13, Color("ffe8b0"))
		if battle_run.lord_kin_power() > 1.0:
			_text("🤝×%.1f" % battle_run.lord_kin_power(), Vector2(lord_center.x - 48, lord_center.y + 4), 10, GOLD)
		var attack: Dictionary = BattleLordSource.ATTACKS.get(battle_run.ruler_id, {})
		if not attack.is_empty():
			var estimate := _lord_attack_estimate()
			_text("%s%s" % [LORD_ATTACK_ICONS.get(battle_run.ruler_id, ""), attack.get("name", "")], Vector2(lord_center.x + 52, lord_center.y - 3), 10, Color("ffb84a"))
			_text("约%d伤/%.1fs" % [roundi(float(estimate.per)), float(estimate.itv)], Vector2(lord_center.x + 52, lord_center.y + 9), 9, Color("d5c9a8"))
	else:
		var mount_pos := Vector2(float(battle_run.lord_mount.x), float(battle_run.lord_mount.y))
		draw_circle(mount_pos, 21, Color("e8f4ff55"))
		draw_arc(mount_pos, 22, 0, TAU, 32, GOLD, 2.0)
		_text_centered_in_rect("骑", Rect2(mount_pos.x - 16, mount_pos.y - 9, 32, 20), 13, Color.WHITE)
	var wall_text := "🏯 %d/%d" % [battle_run.wall, battle_run.wall_max]
	if battle_run.wall_shield > 0:
		wall_text += " +🛡️%d" % battle_run.wall_shield
	draw_string(_font(), Vector2(316, BattleRunSource.DEFENSE_LINE + 24), wall_text, HORIZONTAL_ALIGNMENT_CENTER, 104, 15, RED if battle_run.wall <= 4 else Color("ffd8a0"))
	var command_visual := lord_command_visual_spec()
	if not command_visual.is_empty():
		var command_center: Vector2 = command_visual.center
		var command_ready: bool = command_visual.ready
		var auto_ready: bool = command_visual.auto_ready
		draw_circle(command_center, 27, Color("6a4a2a") if command_ready else Color("3a3630"))
		var cooldown_fraction := float(command_visual.cooldown_fraction)
		if cooldown_fraction > 0.0:
			var sector_points := PackedVector2Array([command_center])
			var sector_steps := maxi(2, ceili(32.0 * cooldown_fraction))
			for step in range(sector_steps + 1):
				var angle := -PI / 2.0 + TAU * cooldown_fraction * float(step) / float(sector_steps)
				sector_points.append(command_center + Vector2.RIGHT.rotated(angle) * 27.0)
			draw_colored_polygon(sector_points, Color("0000008c"))
		var outline_color := GREEN if auto_ready else (Color("ffd24a") if command_ready else Color("ffffff4d"))
		if command_ready:
			var pulse := 0.55 + 0.25 * sin(float(battle_run.game_time) * 6.0)
			draw_arc(command_center, 30, 0, TAU, 36, Color(outline_color, pulse), 2.0)
		draw_arc(command_center, 27, 0, TAU, 36, outline_color, 3.0 if command_ready else 1.5)
		_text_centered_in_rect(str(command_visual.icon), Rect2(command_center.x - 24, command_center.y - 18, 48, 20), 19, Color.WHITE if command_ready else Color("ffffffa6"))
		_text_centered_in_rect(str(command_visual.name), Rect2(command_center.x - 28, command_center.y + 1, 56, 16), 9, Color("ffe8b0"))
		_text_centered_in_rect(str(command_visual.stars), Rect2(command_center.x - 28, command_center.y + 13, 56, 13), 7, GOLD)
		if not command_ready:
			_text_centered_in_rect(str(command_visual.cooldown_label), Rect2(command_center.x - 20, command_center.y - 10, 40, 20), 12, Color.WHITE)

func _battle_wall_color_at(y: float) -> Color:
	var wall_y := BattleRunSource.DEFENSE_LINE - 2.0
	return Color("5a4832").lerp(Color("3a2e1e"), inverse_lerp(wall_y, 800.0, clampf(y, wall_y, 800.0)))

func _lord_attack_estimate() -> Dictionary:
	if battle_run == null:
		return {}
	var attack: Dictionary = BattleLordSource.ATTACKS.get(battle_run.ruler_id, {})
	if attack.is_empty():
		return {}
	var gap: float = float(battle_run.lord_atk_gap) * (0.8 if battle_run.relic_ids.has("yushan") else 1.0)
	var buff: float = 1.0 + float(battle_run.lord_atk_buff)
	if battle_run.ruler_id == "gongsunzan":
		var wall_ratio: float = float(battle_run.wall) / maxf(1.0, float(battle_run.wall_max))
		return {
			"attack": attack,
			"itv": 2.5 * gap,
			"per": (6.0 + battle_run.wave * 1.2) * wall_ratio * (1.0 + 0.03 * battle_run.ruler_level) * float(attack.get("mul", 1.0)) * buff,
		}
	return {
		"attack": attack,
		"itv": 3.0 * gap,
		"per": (7.0 + battle_run.wave * 0.75) * (1.0 + 0.02 * battle_run.ruler_level) * battle_run.lord_kin_power() * float(attack.get("mul", 1.0)) * buff,
	}

func _draw_battle_drag_preview() -> void:
	if not battle_drag.is_active():
		return
	var source: Vector2i = battle_drag.source_cell
	var unit = battle_run.grid[source.y][source.x]
	if unit == null:
		return
	var hover: Vector2i = battle_drag.hover_cell
	var pointer: Vector2 = battle_drag.pointer_position
	_draw_drag_range_preview(unit, hover, pointer - Vector2(0, 24))
	if hover != Vector2i(-1, -1):
		var hover_rect := BattleDragControllerSource.cell_rect(hover)
		_rounded_panel(hover_rect, Color("74d96826"), GREEN, 3.0, 10.0)
	if battle_drag.is_dragging() and pointer.y < BattleRunSource.GRID_Y - 40.0:
		var sell_text := "最后一个武将不能卖" if battle_run.units().size() <= 1 else "🗑 松手卖掉%s，腾出一格（不退经验）" % str(unit.hero.name)
		_text_centered_in_rect(sell_text, Rect2(clampf(pointer.x - 150, 8, 172), pointer.y - 78, 300, 22), 13, RED)
	_draw_battle_unit(unit, pointer - Vector2(0, 24), 1.15)

func _drag_preview_spec(unit: Dictionary, target: Vector2i, fallback_anchor := Vector2.ZERO) -> Dictionary:
	var hero: Dictionary = unit.hero
	var has_target := _valid_battle_cell(target)
	var anchor := BattleRunSource.slot_center(target.y, target.x) if has_target else fallback_anchor
	var class_display: Dictionary = BATTLE_CLASS_DISPLAY.get(str(hero.cls), {"color": Color("cfd6dc")})
	var result := {
		"kind": "global", "anchor": anchor, "radius": 0.0, "width": 0.0,
		"color": class_display.color, "label": "🏹 全场都能射", "adjacent_corridors": [],
		"trait_text": "", "spear_beneficiaries": [], "reverse_spear_cells": [],
	}
	match str(hero.cls):
		"cav":
			result.kind = "corridor"
			result.width = (46.0 if float(hero.get("splash", 0.0)) > 0 else 34.0) + float(battle_run.buffs.get("cavWide", 0.0))
			result.label = "🐎 左中右挑贼多的道冲"
			for offset in [-BattleRunSource.CELL, BattleRunSource.CELL]:
				var corridor_x := anchor.x + float(offset)
				if corridor_x >= BattleRunSource.GRID_X and corridor_x <= BattleRunSource.GRID_X + BattleRunSource.GRID_COLS * BattleRunSource.CELL:
					result.adjacent_corridors.append(corridor_x)
		"support":
			result.kind = "ripple"
			result.radius = battle_run.team.ripple_max(battle_run, unit)
			match str(hero.get("ripple", "")):
				"slow": result.label = "❄️ 这一圈都冻慢"
				"soothe": result.label = "🎵 这一圈解封回血"
				"cdr": result.label = "🕐 这一圈大招转快"
				_: result.label = "🎐 这一圈都加"
		_:
			var radius: float = battle_run.effective_archer_range(hero)
			if radius > 0:
				result.kind = "range"
				result.radius = radius
				result.label = _unit_range_text(hero)
	var trait_id := str(battle_run.traits.get("%d,%d" % [target.y, target.x], "")) if has_target else ""
	if has_target and not trait_id.is_empty() and not battle_run.obstacles.has("%d,%d" % [target.y, target.x]) and DRAG_TRAIT_COPY.has(trait_id):
		var trait_copy: Dictionary = DRAG_TRAIT_COPY[trait_id]
		result.trait_text = "%s%s %s" % [trait_copy.icon, trait_copy.name, _crit_text(str(trait_copy.desc))]
	if not has_target:
		return result
	for row in range(maxi(0, target.y - 1), mini(BattleRunSource.GRID_ROWS - 1, target.y + 1) + 1):
		for col in range(maxi(0, target.x - 1), mini(BattleRunSource.GRID_COLS - 1, target.x + 1) + 1):
			if row == target.y and col == target.x:
				continue
			var ally = battle_run.grid[row][col]
			if ally == null or ally == unit:
				continue
			if str(hero.cls) == "spear" and float(ally.hero.get("dmg", 0.0)) > 0.0:
				result.spear_beneficiaries.append(Vector2i(col, row))
			if float(hero.get("dmg", 0.0)) > 0.0 and str(ally.hero.get("cls", "")) == "spear":
				result.reverse_spear_cells.append(Vector2i(col, row))
	return result

func _crit_word() -> String:
	return "三倍暴击" if battle_run != null and battle_run.relic_ids.has("qinggang") else "双倍暴击"

func _crit_text(value: String) -> String:
	return value.replace("双倍暴击", "三倍暴击") if battle_run != null and battle_run.relic_ids.has("qinggang") else value

func _draw_drag_range_preview(unit: Dictionary, target: Vector2i, fallback_anchor := Vector2.ZERO) -> void:
	if unit == null:
		return
	var spec := _drag_preview_spec(unit, target, fallback_anchor)
	var anchor: Vector2 = spec.anchor
	var color: Color = spec.color
	match str(spec.kind):
		"corridor":
			var width := float(spec.width)
			for corridor_x in spec.adjacent_corridors:
				draw_rect(Rect2(float(corridor_x) - width, 30, width * 2.0, anchor.y - 78.0), Color(color, 0.06), true)
			var corridor_rect := Rect2(anchor.x - width, 30, width * 2.0, anchor.y - 78.0)
			draw_rect(corridor_rect, Color(color, 0.14), true)
			_draw_dashed_rect(corridor_rect, Color(color, 0.65), 2.0, 10.0, 8.0)
			_text_centered_in_rect(str(spec.label), Rect2(anchor.x - 110, anchor.y - 78, 220, 20), 11, color)
		"ripple":
			draw_circle(anchor - Vector2(0, 18), float(spec.radius), Color(color, 0.06))
			_draw_dashed_arc(anchor - Vector2(0, 18), float(spec.radius), 0.0, TAU, Color(color, 0.65), 2.0, 8.0, 6.0)
			_text_centered_in_rect(str(spec.label), Rect2(anchor.x - 110, anchor.y - 78, 220, 20), 11, color)
		"range":
			draw_circle(anchor - Vector2(0, 18), float(spec.radius), Color(color, 0.06))
			_draw_dashed_arc(anchor - Vector2(0, 18), float(spec.radius), 0.0, TAU, Color(color, 0.65), 2.0, 8.0, 6.0)
		"global":
			_text_centered_in_rect(str(spec.label), Rect2(anchor.x - 80, anchor.y - 72, 160, 20), 12, color)
	var aura_percent := roundi((0.10 + float(battle_run.buffs.get("spearAura", 0.0))) * 100.0)
	for cell in spec.spear_beneficiaries:
		var rect := BattleDragControllerSource.cell_rect(cell)
		draw_rect(rect, Color("6fd44e38"), true)
		_text_centered_in_rect("+%d%%" % aura_percent, Rect2(rect.position.x, rect.position.y - 3, rect.size.x, 18), 10, Color("9aff8a"))
	for spear_cell in spec.reverse_spear_cells:
		var spear_center := BattleRunSource.slot_center(spear_cell.y, spear_cell.x)
		draw_dashed_line(spear_center, anchor, Color("6fd44e99"), 2.0, 4.0)
	if not str(spec.trait_text).is_empty():
		_text_centered_in_rect(str(spec.trait_text), Rect2(anchor.x - 105, anchor.y - 62, 210, 18), 10, GOLD)

func _unit_visual_spec(unit: Dictionary) -> Dictionary:
	var hero: Dictionary = unit.hero
	var rarity_id := HeroProgressionSource.rarity(str(hero.id), catalog.content.get("hero_tiers", {}))
	var rarity: Dictionary = catalog.content.get("rarities", {}).get(rarity_id, {})
	var class_display: Dictionary = BATTLE_CLASS_DISPLAY.get(str(hero.cls), {"icon": "兵", "color": Color("cfd6dc")})
	var element: Dictionary = TRI_DISPLAY.get(str(hero.elem), TRI_DISPLAY.badao)
	var hp_fraction := clampf(float(unit.hp) / maxf(1.0, float(unit.hp_max)), 0.0, 1.0)
	var health_color := Color("7aff5a") if hp_fraction > 0.5 else (Color("ffd24a") if hp_fraction > 0.25 else Color("ff5a3a"))
	var ult: Dictionary = battle_run.ult_system.definition(str(hero.id)) if battle_run != null else {}
	var ult_progress := 0.0
	var ult_color := GOLD
	if not ult.is_empty():
		var ult_max: float = maxf(0.01, battle_run.ult_system.cooldown_max(battle_run, unit))
		ult_progress = 1.0 - clampf(float(unit.get("ultCd", 0.0)) / ult_max, 0.0, 1.0)
		ult_color = {"dmg": Color("ff8a5a"), "ctrl": Color("8ad2ff"), "def": Color("9adf5a"), "util": Color("c9a8ff"), "exec": Color("ffd24a")}.get(str(ult.type), GOLD)
	var name_text := "蛋" if str(hero.cls) == "egg" else ("龍" if str(hero.cls) == "dragon" else str(hero.name))
	var hero_level := int(battle_run.hero_levels.get(str(hero.id), 1)) if battle_run != null else 1
	return {
		"body_radius": 21.0,
		"aura_radius": 25.0,
		"ult_radius": 30.0,
		"aura_color": Color(str(rarity.get("color", "#cfd6dc"))),
		"name_text": name_text,
		"name_font_size": _name_disc_font_size(name_text, 21.0),
		"name_color": GOLD if hero_level >= 10 else Color("ffe8b0"),
		"class_icon": str(class_display.icon),
		"class_color": class_display.color,
		"class_center": Vector2(19, -18),
		"element_icon": str(element.icon),
		"element_color": element.color,
		"element_center": Vector2(-19, 18),
		"star_y": 27.0,
		"health_rect": Rect2(-20, 31, 40, 5),
		"health_visible": hp_fraction < 0.999,
		"health_fraction": hp_fraction,
		"health_color": health_color,
		"ult_progress": ult_progress,
		"ult_color": ult_color,
		"has_ult": not ult.is_empty(),
	}

func _draw_battle_unit(unit: Dictionary, center: Vector2, scale := 1.0, row := -1, col := -1) -> void:
	var hero: Dictionary = unit.hero
	var spec := _unit_visual_spec(unit)
	draw_set_transform(center, 0.0, Vector2(scale, scale))
	draw_circle(Vector2(0, 22), 10, Color("0000004d"))
	draw_arc(Vector2.ZERO, spec.aura_radius, 0, TAU, 36, spec.aura_color, 3.0)
	if spec.has_ult:
		if float(spec.ult_progress) >= 0.999:
			draw_arc(Vector2.ZERO, spec.ult_radius, 0, TAU, 40, spec.ult_color, 4.0)
		elif float(spec.ult_progress) > 0.02:
			draw_arc(Vector2.ZERO, spec.ult_radius, -PI / 2.0, -PI / 2.0 + TAU * float(spec.ult_progress), 32, spec.ult_color, 3.5)
	var bonded := false
	for bond_id in battle_run.team.active_bond_ids():
		var bond: Dictionary = catalog.by_id("bonds", str(bond_id))
		if bond.get("members", []).has(str(hero.id)):
			bonded = true
			break
	if bonded:
		draw_arc(Vector2.ZERO, 30, 0, TAU, 36, Color("ffd24ad9"), 1.6)
		_text_centered_in_rect("🔗", Rect2(-32, 16, 20, 16), 10, Color.WHITE)
	draw_circle(Vector2.ZERO, spec.body_radius, Color("3a3024"))
	draw_string(_font(), Vector2(-21, 1 + int(spec.name_font_size) / 3.0), str(spec.name_text), HORIZONTAL_ALIGNMENT_CENTER, 42, int(spec.name_font_size), spec.name_color)
	var class_center: Vector2 = spec.class_center
	draw_circle(class_center, 11, Color("140e06eb"))
	draw_arc(class_center, 11, 0, TAU, 24, spec.class_color, 2.0)
	_text_centered_in_rect(spec.class_icon, Rect2(class_center.x - 11, class_center.y - 8, 22, 16), 11, Color.WHITE)
	if not ["granary", "egg", "dragon"].has(str(hero.cls)):
		var element_center: Vector2 = spec.element_center
		draw_circle(element_center, 10, Color("140e06eb"))
		draw_arc(element_center, 10, 0, TAU, 24, spec.element_color, 2.0)
		_text_centered_in_rect(spec.element_icon, Rect2(element_center.x - 10, element_center.y - 7, 20, 14), 9, Color.WHITE)
	if str(hero.cls) != "dragon":
		_text_centered_in_rect("★".repeat(int(unit.level)), Rect2(-34, spec.star_y - 10, 68, 14), 9, GOLD)
	if float(unit.get("sealedT", 0.0)) > 0:
		_text_centered_in_rect("🌀", Rect2(-18, -14, 36, 28), 22, Color("e0b0ff"))
	if float(unit.get("hurtFlash", 0.0)) > 0:
		draw_circle(Vector2.ZERO, 23, Color(1.0, 0.29, 0.23, minf(0.45, float(unit.hurtFlash) * 0.45)))
	if spec.health_visible:
		var health_rect: Rect2 = spec.health_rect
		draw_rect(health_rect, Color("00000099"), true)
		draw_rect(Rect2(health_rect.position, Vector2(health_rect.size.x * float(spec.health_fraction), health_rect.size.y)), spec.health_color, true)
	if row >= 0 and col >= 0 and str(hero.cls) != "shield" and battle_run._has_adjacent_shield(row, col):
		_text_centered_in_rect("🛡", Rect2(-32, -37, 22, 16), 10, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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
	var panel_rect := Rect2(8, 260, 464, 198)
	_rounded_panel(panel_rect, Color(0.047, 0.035, 0.016, 0.72), Color(0.91, 0.78, 0.42, 0.35), 1.5, 14.0)
	var heading := card_draft_heading()
	if bool(battle_run.permanent_tactics.get("gewu", false)) and battle_run.gewu_auto_index >= 0:
		heading = "🍷 乐不思蜀·自动抽卡中…" if battle_run.gewu_auto_timer < 1.0 else "🍷 就它了"
	_text_center(heading, 286, 17, Color(1.0, 0.894, 0.353, 0.75 + sin(float(battle_run.game_time) * 5.0) * 0.25))
	var auto_highlight := _growth_card_auto_highlight_index()
	for index in battle_run.card_choices.size():
		var card: Dictionary = battle_run.card_choices[index]
		var spec := _growth_card_visual_spec(index, card)
		var rect: Rect2 = spec.rect
		_draw_rounded_vertical_gradient(rect, spec.top_color, spec.bottom_color, 12.0)
		_rounded_panel(rect, Color(0, 0, 0, 0), spec.border_color, 2.5, 12.0)
		if index == auto_highlight:
			var highlight := Color("ff9ac8") if battle_run.gewu_auto_timer < 1.0 else Color("8df05a")
			_rounded_panel(rect.grow(4.0), Color(0, 0, 0, 0), highlight, 4.0, 14.0)
		_draw_growth_card_content(card, rect)

func _growth_card_visual_spec(index: int, card: Dictionary) -> Dictionary:
	var base_rect := _growth_card_rect(index)
	var entrance_dy := pow(1.0 - clampf(growth_card_anim, 0.0, 1.0), 3.0) * 100.0
	var rect := Rect2(base_rect.position + Vector2(0, entrance_dy), base_rect.size)
	var is_relic := str(card.get("kind", "")) == "relic"
	var class_display: Dictionary = BATTLE_CLASS_DISPLAY.get(str(card.get("cls", "")), {})
	return {
		"panel_rect": Rect2(8, 260, 464, 198),
		"rect": rect,
		"top_color": Color("5a4a22") if is_relic else Color("54452a"),
		"bottom_color": Color("42361a") if is_relic else Color("3a3020"),
		"border_color": Color("ffd24a") if is_relic else class_display.get("color", Color("c9a86a")),
		"tag_rect": Rect2(rect.position.x + 6, rect.position.y + 4, 76, 18),
	}

func _growth_card_auto_highlight_index() -> int:
	if battle_run == null or not bool(battle_run.permanent_tactics.get("gewu", false)) or battle_run.gewu_auto_index < 0 or battle_run.card_choices.is_empty():
		return -1
	if battle_run.gewu_auto_timer < 1.0:
		return int(floor(battle_run.gewu_auto_timer * 8.0)) % battle_run.card_choices.size()
	return battle_run.gewu_auto_index

func _draw_growth_card_content(card: Dictionary, rect: Rect2) -> void:
	var center_x := rect.position.x + rect.size.x / 2.0
	var hero_id := str(card.get("hero_id", ""))
	if not hero_id.is_empty():
		var hero: Dictionary = catalog.by_id("heroes", hero_id)
		var rarity_id := HeroProgressionSource.rarity(hero_id, catalog.content.get("hero_tiers", {}))
		var rarity: Dictionary = catalog.content.get("rarities", {}).get(rarity_id, {})
		var disc_center := Vector2(center_x, rect.position.y + 34)
		draw_circle(disc_center, 20, Color("3a3024"))
		draw_arc(disc_center, 20, 0, TAU, 48, Color(str(rarity.get("color", "#cfd6dc"))), 2.0)
		var hero_name := str(hero.get("name", hero_id))
		var name_size := _name_disc_font_size(hero_name, 20.0)
		draw_string(_font(), Vector2(center_x - 20, rect.position.y + 35 + name_size / 3.0), hero_name, HORIZONTAL_ALIGNMENT_CENTER, 40, name_size, GOLD)
	else:
		_card_text_center(str(card.get("icon", "")), center_x, rect.position.y + 44, 32, Color.WHITE, rect.size.x)
	_card_text_center(str(card.get("title", "")), center_x, rect.position.y + 70, 15, GOLD, rect.size.x - 6)
	if card.has("stars"):
		var has_info := not str(card.get("info", "")).is_empty()
		if has_info:
			_card_text_center(str(card.info), center_x, rect.position.y + 88, 12 if rect.size.x < 120 else 13, Color(str(card.get("infoColor", "#e8dcc0"))), rect.size.x - 6)
		var star_y := rect.position.y + (106 if has_info else 90)
		_draw_growth_star_row(center_x, star_y, int(card.stars))
		_card_text_center(str(card.get("desc", "")), center_x, star_y + 17, 12, Color("e8dcc0"), rect.size.x - 8)
		if card.has("lvN"):
			_card_text_center("图鉴 %d 级" % int(card.lvN), center_x, star_y + 36, 13, Color("8ad2ff"), rect.size.x - 8)
	elif card.has("lvN") and not str(card.get("info", "")).is_empty():
		_card_text_center(str(card.info), center_x, rect.position.y + 90, 12 if rect.size.x < 120 else 14, Color(str(card.get("infoColor", "#e8dcc0"))), rect.size.x - 6)
		_card_text_center("图鉴 %d 级" % int(card.lvN), center_x, rect.position.y + 110, 14, Color("8ad2ff"), rect.size.x - 8)
		_draw_wrapped_centered(str(card.get("desc", "")), center_x, rect.position.y + 128, rect.size.x - 12, 12, Color("c9b69a"), 14, 2)
	else:
		_draw_wrapped_centered(str(card.get("desc", "")), center_x, rect.position.y + 86, rect.size.x - 14, 12, Color("e8dcc0"), 14, 3)
	if not str(card.get("tag", "")).is_empty():
		var tag_rect := Rect2(rect.position.x + 6, rect.position.y + 4, 76, 18)
		var bad := bool(card.get("tagBad", false))
		_rounded_panel(tag_rect, Color("5a2a2a") if bad else Color("2a5a3a"), Color("ff8a6a") if bad else Color("9adf5a"), 1.5, 6.0)
		_card_text_center(str(card.tag), tag_rect.get_center().x, tag_rect.position.y + 13, 10, Color("ffb8a8") if bad else Color("c9f0a0"), tag_rect.size.x)

func _draw_rounded_vertical_gradient(rect: Rect2, top_color: Color, bottom_color: Color, radius: float) -> void:
	var height := maxi(1, roundi(rect.size.y))
	for row in height:
		var local_y := float(row) + 0.5
		var inset := 0.0
		if local_y < radius:
			inset = radius - sqrt(maxf(0.0, radius * radius - pow(radius - local_y, 2.0)))
		elif local_y > rect.size.y - radius:
			inset = radius - sqrt(maxf(0.0, radius * radius - pow(local_y - (rect.size.y - radius), 2.0)))
		var color := top_color.lerp(bottom_color, float(row) / maxf(1.0, rect.size.y - 1.0))
		draw_line(Vector2(rect.position.x + inset, rect.position.y + row), Vector2(rect.end.x - inset, rect.position.y + row), color, 1.2)

func _card_text_center(text: String, center_x: float, baseline_y: float, size: int, color: Color, width: float) -> void:
	draw_string(_font(), Vector2(center_x - width / 2.0, baseline_y), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)

func _draw_growth_star_row(center_x: float, baseline_y: float, stars: int) -> void:
	var tiers := _growth_star_tiers(stars)
	if tiers.is_empty():
		return
	var widths: Array[float] = []
	var padding := 2.0
	var total := -padding
	for tier in tiers:
		var size := 18 if int(tier) > 0 else 16
		var width := _font().get_string_size("★", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		widths.append(width)
		total += width + padding
	var x := center_x - total / 2.0
	for index in tiers.size():
		var tier := int(tiers[index])
		var color := Color("8df05a") if index == tiers.size() - 1 else (Color("3a9aff") if tier == 2 else (Color("ff7a3a") if tier == 1 else Color("ffd24a")))
		var size := 18 if tier > 0 else 16
		draw_string(_font(), Vector2(x, baseline_y), "★", HORIZONTAL_ALIGNMENT_LEFT, widths[index], size, color)
		x += widths[index] + padding

func _growth_star_tiers(stars: int) -> Array:
	var tiers := []
	if stars <= 5:
		for _index in maxi(0, stars):
			tiers.append(0)
	elif stars <= 10:
		for _index in stars - 5:
			tiers.append(1)
		for _index in 10 - stars:
			tiers.append(0)
	else:
		for _index in mini(5, stars - 10):
			tiers.append(2)
		for _index in maxi(0, 15 - stars):
			tiers.append(1)
	return tiers

func _draw_wrapped_centered(text: String, center_x: float, first_baseline: float, max_width: float, size: int, color: Color, line_height: float, max_lines: int) -> void:
	var lines: Array[String] = []
	var current := ""
	for character in text:
		var candidate := current + character
		if not current.is_empty() and _font().get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_width:
			lines.append(current)
			current = character
			if lines.size() >= max_lines:
				break
		else:
			current = candidate
	if lines.size() < max_lines and not current.is_empty():
		lines.append(current)
	for index in lines.size():
		_card_text_center(lines[index], center_x, first_baseline + index * line_height, size, color, max_width)

func _draw_wrapped_left(text: String, first_baseline: Vector2, max_width: float, size: int, color: Color, line_height: float, max_lines: int) -> void:
	var lines: Array[String] = []
	var current := ""
	for character in text:
		var candidate := current + character
		if not current.is_empty() and _font().get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_width:
			lines.append(current)
			current = character
			if lines.size() >= max_lines:
				break
		else:
			current = candidate
	if lines.size() < max_lines and not current.is_empty():
		lines.append(current)
	for index in lines.size():
		_text(lines[index], first_baseline + Vector2(0, index * line_height), size, color)
