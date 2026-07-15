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
const HOME_BACK_RECT := Rect2(24, 22, 66, 34)
const HOME_PREV_RECT := Rect2(28, 744, 116, 38)
const HOME_NEXT_RECT := Rect2(336, 744, 116, 38)
const HERO_UPGRADE_RECT := Rect2(34, 620, 198, 46)
const HERO_REBIRTH_RECT := Rect2(248, 620, 198, 46)
const HERO_RESET_RECT := Rect2(141, 690, 198, 40)
const VISIT_ROLL_RECT := Rect2(156, 306, 168, 54)
const LORD_COMMAND_ICONS := {"wuxing": "☯", "taoyuan": "🍑", "jiejiang": "🌊", "mensheng": "📜", "bingfeng": "🧊", "baima": "🐎", "fenluo": "🔥", "jianhao": "🪙"}
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
var battle_drag = BattleDragControllerSource.new()
var sound_enabled := true
var damage_panel_visible := false
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
	if quit_armed:
		quit_arm_time = maxf(0.0, quit_arm_time - delta)
		if quit_arm_time <= 0:
			quit_armed = false
	if phase != "battle" or battle_run == null:
		return
	battle_run.advance_real(delta)
	_sync_battle_result()
	queue_redraw()

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
	if foe_lord_popup or battle_run.awaiting_card_choice or bool(battle_run.permanent_tactics.get("gewu", false)):
		return false
	var cell := BattleDragControllerSource.cell_at(point)
	if cell == Vector2i(-1, -1):
		return false
	if battle_run.grid[cell.y][cell.x] == null:
		return false
	return battle_drag.begin(cell, point)

func _finish_battle_drag(point: Vector2) -> void:
	var result: Dictionary = battle_drag.finish(point)
	if str(result.get("action", "")) == "drop":
		var source: Vector2i = result.source
		var target: Vector2i = result.target
		battle_run.move_or_swap_unit(source.y, source.x, target.y, target.x)
	elif str(result.get("action", "")) == "sell":
		var source: Vector2i = result.source
		battle_run.sell_unit(source.y, source.x)
	queue_redraw()

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
			if _cata_warning_rect().has_point(point):
				var urgent_cata: Dictionary = battle_run.focus_priority_catapult()
				if not urgent_cata.is_empty():
					battle_run.focus_enemy(urgent_cata)
					queue_redraw()
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
			var clicked_enemy: Dictionary = _enemy_at_point(point)
			if not clicked_enemy.is_empty():
				battle_run.focus_enemy(clicked_enemy)
				queue_redraw()
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
			if HOME_PREV_RECT.has_point(point):
				lord_page = maxi(0, lord_page - 1)
			elif HOME_NEXT_RECT.has_point(point):
				lord_page = mini(1, lord_page + 1)
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
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), INK, true)
	match home_overlay:
		"codex": _draw_codex()
		"hero": _draw_hero_detail()
		"lords": _draw_lord_house()
		"visit": _draw_visit()
		"bag": _draw_bag()
		"achievements": _draw_achievements()
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
	_text_center("主公府", 48, 27, GOLD)
	_text_center("主公经验随出征成长 · 被动等级直接带入战斗", 75, 12, Color("d5c9a8"))
	var visible_ids: Array = lord_page_ruler_ids()
	for index in visible_ids.size():
		var ruler_id := str(visible_ids[index])
		var ruler: Dictionary = catalog.by_id("rulers", ruler_id)
		var entry: Dictionary = profile.rulers[ruler_id]
		var rect := Rect2(24, 104 + index * 144, 432, 124)
		_panel(rect, Color("241c10"), PALE_GOLD, 1.5)
		_text(str(ruler.name), Vector2(42, rect.position.y + 29), 21, GOLD)
		var skill_tier := mini(3, 1 + int(floor((int(entry.lv) - 1) / 8.0)))
		_text("Lv.%d / 20 · 经验 %d/%d · 号令%d阶" % [int(entry.lv), int(entry.xp), LocalProfileSource.lord_xp_need(int(entry.lv)), skill_tier], Vector2(158, rect.position.y + 27), 12, BLUE)
		_text(_short_text(str(ruler.desc), 25), Vector2(42, rect.position.y + 56), 12, Color("d5c9a8"))
		var labels := PackedStringArray()
		for passive in ruler.get("passives", []):
			var unlocked := 0
			for at_level in passive.get("at", []):
				if int(entry.lv) >= int(at_level): unlocked += 1
			var tech: Dictionary = catalog.by_id("techs", str(passive.id))
			labels.append("%s %d/%d" % [str(tech.get("name", passive.id)), unlocked, passive.get("at", []).size()])
		var first_line := PackedStringArray()
		var second_line := PackedStringArray()
		for label_index in labels.size():
			if label_index < 2: first_line.append(labels[label_index])
			else: second_line.append(labels[label_index])
		_text(" · ".join(first_line), Vector2(42, rect.position.y + 83), 11, GREEN)
		_text(" · ".join(second_line), Vector2(42, rect.position.y + 104), 11, GREEN)
		_text("出征结算获得主公经验", Vector2(298, rect.position.y + 116), 9, MUTED)
	_panel(HOME_PREV_RECT, Color("302718"), PALE_GOLD if lord_page > 0 else MUTED, 1.5)
	_text_centered_in_rect("上一页", HOME_PREV_RECT, 14, Color.WHITE if lord_page > 0 else MUTED)
	_text_center("第 %d / 2 页" % (lord_page + 1), 770, 13, PALE_GOLD)
	_panel(HOME_NEXT_RECT, Color("302718"), PALE_GOLD if lord_page < 1 else MUTED, 1.5)
	_text_centered_in_rect("下一页", HOME_NEXT_RECT, 14, Color.WHITE if lord_page < 1 else MUTED)

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
		var is_guest := guests.has(ruler_id)
		_panel(rect, Color("ffffff0d"), Color("786e5a59"), 1.2)
		var disc_center := Vector2(rect.position.x + 32, rect.position.y + rect.size.y / 2.0)
		draw_circle(disc_center, 20, Color("2b2115"))
		draw_arc(disc_center, 21, 0, TAU, 32, GOLD, 2.0)
		_text_centered_in_rect(str(ruler.name).left(1), Rect2(disc_center.x - 18, disc_center.y - 10, 36, 22), 15, GOLD)
		var tx := rect.position.x + 62
		_text("%s · %s" % [str(ruler.name), str(ruler.title)], Vector2(tx, rect.position.y + 20), 15, GOLD)
		var badge_x := rect.end.x - 8.0
		if hints.has(ruler_id):
			_text("👍对题", Vector2(badge_x - 54, rect.position.y + 20), 10, GOLD)
			badge_x -= 62
		if is_guest:
			_text("🍵客卿·讨伐+30%", Vector2(badge_x - 103, rect.position.y + 20), 10, GREEN)
		var level := LocalProfileSource.ruler_level(profile, ruler_id)
		var command: Dictionary = BattleLordSource.COMMANDS.get(str(ruler.skill), {})
		var special_text := str(LORD_SPECIAL_LABELS.get(str(ruler.get("special", "")), ""))
		var second_special := str(LORD_SPECIAL_LABELS.get(str(ruler.get("special2", "")), ""))
		var attack: Dictionary = BattleLordSource.ATTACKS.get(ruler_id, {})
		var kin_names := PackedStringArray()
		for hero_id in catalog.content.get("lord_kin", {}).get(ruler_id, []):
			kin_names.append(str(catalog.by_id("heroes", str(hero_id)).get("name", "")))
		var line2 := "Lv.%d　%s%s%s%s　%s%s%s　🤝%s" % [level, LORD_COMMAND_ICONS.get(str(ruler.skill), ""), command.get("name", ""), "　" if not special_text.is_empty() else "", special_text + second_special, LORD_ATTACK_ICONS.get(ruler_id, ""), attack.get("name", ""), "↑" if float(attack.get("mul", 1.0)) > 1.0 else "", "·".join(kin_names)]
		_text(_short_text(line2, 55), Vector2(tx, rect.position.y + 39), 10, BLUE)
		_text(_short_text(str(ruler.desc), 58), Vector2(tx, rect.position.y + 58), 9, Color("c9b69a"))
	_panel(RULER_BACK_RECT, Color("5a4a3a"), Color("8a7d66"), 1.0)
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
	_draw_battle_backdrop()
	_draw_battle_entities()
	_draw_battle_formation()
	_draw_player_projectiles()
	_draw_battle_skill_events()
	# The Web battlefield spawns enemies above the playfield. Keep that motion,
	# but paint the opaque HUD last so newly spawned units cannot obscure it.
	draw_rect(Rect2(10, 10, 460, 84), Color("00000059"), true)
	_text("Lv.%d" % battle_run.level, Vector2(24, 34), 16, GOLD)
	_text("⚔ 第 %d 波" % maxi(battle_run.wave, 1), Vector2(24, 60), 15, PALE_GOLD)
	_text("%s%s" % [str(city.get("icon", "⚡")), str(city.get("tag", city.get("name", "")))], Vector2(88, 34), 12, Color(str(city.get("color", "ffb84a"))))
	_text("击破 %d / %s" % [battle_run.kills, "∞" if battle_run.endless else str(city.killTarget)], Vector2(130, 28), 13, Color.WHITE)
	draw_rect(Rect2(130, 34, 330, 10), Color("ffffff26"), true)
	draw_rect(Rect2(130, 34, minf(330.0, battle_run.kills / float(city.killTarget) * 330.0), 10), Color("9aff5a"), true)
	_text("EXP", Vector2(130, 62), 12, Color("8ad2ff"))
	draw_rect(Rect2(164, 53, 296, 10), Color("ffffff26"), true)
	draw_rect(Rect2(164, 53, minf(296.0, battle_run.xp / maxf(1.0, battle_run.xp_need) * 296.0), 10), Color("4ab0ff"), true)
	var battle_field: Dictionary = catalog.by_id("fields", str(city.get("field", "")))
	draw_rect(Rect2(10, 98, 118, 19), Color("00000059"), true)
	_text("%s%s" % [battle_field.get("icon", ""), battle_field.get("name", "")], Vector2(16, 112), 12, Color("c9e0a0"))
	var foe_offset := 46.0 if not battle_run.foe_lord.is_empty() else 0.0
	if foe_offset > 0:
		_draw_foe_lord_status()
	var field_clear: bool = battle_run.spawn_queue.is_empty() and battle_run.enemies.is_empty()
	draw_rect(Rect2(128, 130 + foe_offset, 224, 27), Color("17120ce6"), true)
	if battle_run.wave == 0 and battle_run.enemies.is_empty():
		_text_center("黄巾来袭 %.1fs" % maxf(0.0, battle_run.wave_timer), 150 + foe_offset, 16, PALE_GOLD)
		_draw_battle_field_banner()
	elif field_clear:
		var threat := _next_wave_threat_text()
		_text_center(_short_text("下波 %.1fs%s" % [maxf(0.0, battle_run.wave_timer), " · " + threat if not threat.is_empty() else ""], 34), 150 + foe_offset, 14, PALE_GOLD)
	else:
		var pressure_left := maxf(0.0, battle_run.wave_budget - battle_run.wave_clock)
		var pressure_note := ""
		if not battle_run.endless_mod.is_empty(): pressure_note = " · 军令「%s」" % str(battle_run.endless_mod.name)
		elif battle_run.foe_tenacity() < 0.999: pressure_note = " · 攻坚·控效%d%%" % roundi(battle_run.foe_tenacity() * 100.0)
		_text_center(_short_text("第%d波 · 催战 %.1fs%s" % [battle_run.wave, pressure_left, pressure_note], 34), 150 + foe_offset, 14, RED if pressure_left < 5.0 else MUTED)
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
	if battle_run.awaiting_card_choice:
		_draw_growth_cards()
	elif foe_lord_popup_is_visible():
		_draw_foe_lord_popup()
	elif battle_run.status != "play":
		_draw_result()

func _draw_battle_backdrop() -> void:
	draw_rect(Rect2(0, 0, 480, 260), Color("2a2012"), true)
	draw_rect(Rect2(0, 260, 480, 232), Color("3a2c18"), true)
	for index in 26:
		var x := fmod(index * 137.5, 480.0)
		var y := fmod(index * 89.3 + float(battle_run.game_time) * 6.0, 432.0)
		draw_rect(Rect2(x, y, 2, 2), Color("ffdc9624"), true)

func _draw_battle_side_controls() -> void:
	_panel(BATTLE_MUTE_RECT, Color("3a5a6a") if sound_enabled else Color("5a3a3a"), Color("ffffff4d"), 1.5)
	_text_centered_in_rect("🔊音效" if sound_enabled else "🔇静音", BATTLE_MUTE_RECT, 12, Color.WHITE)
	_panel(BATTLE_QUIT_RECT, Color("8a3a2a") if quit_armed else Color("4a4048"), Color("ffffff4d"), 1.5)
	_text_centered_in_rect("真退?" if quit_armed else "🚪退出", BATTLE_QUIT_RECT, 12, Color.WHITE)
	_panel(BATTLE_DMG_RECT, Color("5a7a3a") if damage_panel_visible else Color("3a4a5a"), Color("ffffff4d"), 1.5)
	_text_centered_in_rect("📊输出", BATTLE_DMG_RECT, 11, Color.WHITE)
	var ruler: Dictionary = catalog.by_id("rulers", battle_run.ruler_id)
	_panel(Rect2(410, 178, 64, 24), Color("140e06d9"), Color("ffd74a99"), 1.2)
	_text_centered_in_rect("👑%s" % ruler.get("name", ""), Rect2(410, 178, 64, 24), 11, GOLD)

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
	var rect := Rect2(8, 138, 392, 112)
	draw_rect(rect, Color("120d07e8"), true)
	draw_rect(rect, Color("e8c86acc"), false, 2.0)
	_text_centered_in_rect("⚡ %s · %s" % [city.get("name", "本州"), field.get("name", "")], Rect2(8, 150, 392, 24), 16, GOLD)
	_text_centered_in_rect(str(field.get("desc", "")), Rect2(16, 182, 376, 22), 11, Color("d5c9a8"))
	var tri: Dictionary = TRI_DISPLAY.get(str(city.get("foes", {}).get("tri", "badao")), TRI_DISPLAY.badao)
	var counter: Dictionary = TRI_DISPLAY.get(str(tri.counter), TRI_DISPLAY.rende)
	_text_centered_in_rect("这州的贼是 %s%s　带 %s%s 克他" % [tri.icon, tri.name, counter.icon, counter.name], Rect2(16, 206, 376, 22), 12, GREEN)
	var rules: Array = city.get("rules", [])
	if not rules.is_empty():
		_text_centered_in_rect("⚠ 本关：%s" % _rule_names(rules), Rect2(16, 228, 376, 18), 10, Color("ff9a6a"))

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
	return ["backdrop", "entities", "formation", "projectiles", "skill_fx", "hud", "overlays"]

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
			var rect := Rect2(BattleRunSource.GRID_X + col * BattleRunSource.CELL + 2, BattleRunSource.GRID_Y + row * BattleRunSource.CELL + 2, BattleRunSource.CELL - 4, BattleRunSource.CELL - 4)
			draw_rect(rect, Color("30281d"), true)
			draw_rect(rect, Color("54462f"), false, 1.0)
			if battle_run.traits.has(key):
				_text(str(battle_run.traits[key]).left(1).to_upper(), rect.position + Vector2(5, 14), 9, MUTED)
			if battle_run.obstacles.has(key):
				draw_rect(rect, Color("3c32248c"), true)
				_text_centered_in_rect("🪨" if (row + col) % 2 else "🌲", Rect2(rect.position.x, rect.position.y + 20, rect.size.x, 32), 26, Color.WHITE)
				continue
			var unit = battle_run.grid[row][col]
			if unit == null:
				continue
			if battle_drag.is_dragging() and battle_drag.source_cell == Vector2i(col, row):
				continue
			_draw_battle_unit(unit, rect.get_center(), 1.0, row, col)
	_draw_battle_drag_preview()
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
	var wall_text := "🏯 %d/%d" % [battle_run.wall, battle_run.wall_max]
	if battle_run.wall_shield > 0:
		wall_text += " +🛡️%d" % battle_run.wall_shield
	_text(wall_text, Vector2(365, 774), 12, RED if battle_run.wall <= 4 else Color("ffd8a0"))
	var command: Dictionary = BattleLordSource.COMMANDS.get(battle_run.lord_skill_id, {})
	if not command.is_empty():
		var command_ready: bool = battle_run.lord_command_cd <= 0 and not bool(battle_run.permanent_tactics.get("gewu", false))
		var auto_ready: bool = command_ready and battle_run.lord_command_auto_ready()
		var command_center := LORD_COMMAND_RECT.get_center()
		draw_circle(command_center, 27, Color("25311f") if command_ready else Color("352e26"))
		draw_arc(command_center, 28, 0, TAU, 36, GREEN if command_ready else MUTED, 2.0)
		_text_centered_in_rect(str(LORD_COMMAND_ICONS.get(battle_run.lord_skill_id, "令")), Rect2(LORD_COMMAND_RECT.position.x, LORD_COMMAND_RECT.position.y + 8, LORD_COMMAND_RECT.size.x, 20), 16, GOLD if command_ready else PALE_GOLD)
		_text_centered_in_rect(_short_text(str(command.name), 4), Rect2(LORD_COMMAND_RECT.position.x, LORD_COMMAND_RECT.position.y + 30, LORD_COMMAND_RECT.size.x, 16), 9, Color.WHITE)
		var cooldown_text := "自动待发" if auto_ready else ("点击施放" if command_ready else ("CD %.1fs" % battle_run.lord_command_cd if battle_run.lord_command_cd > 0 else "号令罢工"))
		_text_centered_in_rect(_short_text(cooldown_text, 6), Rect2(LORD_COMMAND_RECT.position.x, LORD_COMMAND_RECT.position.y + 44, LORD_COMMAND_RECT.size.x, 12), 7, GREEN if command_ready else MUTED)

func _draw_battle_drag_preview() -> void:
	if not battle_drag.is_active():
		return
	var source: Vector2i = battle_drag.source_cell
	var source_rect := BattleDragControllerSource.cell_rect(source)
	draw_rect(source_rect, Color("18140faa"), true)
	draw_rect(source_rect, GOLD, false, 2.0)
	if not battle_drag.is_dragging():
		return
	var unit = battle_run.grid[source.y][source.x]
	if unit == null:
		return
	var hover: Vector2i = battle_drag.hover_cell
	if hover != Vector2i(-1, -1):
		_draw_drag_range_preview(unit, hover)
		var hover_rect := BattleDragControllerSource.cell_rect(hover)
		var blocked: bool = battle_run.obstacles.has("%d,%d" % [hover.y, hover.x])
		draw_rect(hover_rect, Color("74d96826") if not blocked else Color("ff654026"), true)
		draw_rect(hover_rect, GREEN if not blocked else RED, false, 3.0)
	var pointer: Vector2 = battle_drag.pointer_position
	if pointer.y < BattleRunSource.GRID_Y - 40.0:
		var sell_text := "最后一个武将不能卖" if battle_run.units().size() <= 1 else "🗑 松手卖掉%s，腾出一格（不退经验）" % str(unit.hero.name)
		_text_centered_in_rect(sell_text, Rect2(clampf(pointer.x - 150, 8, 172), pointer.y - 78, 300, 22), 13, RED)
	_draw_battle_unit(unit, pointer - Vector2(0, 24), 1.15)

func _drag_preview_spec(unit: Dictionary, target: Vector2i) -> Dictionary:
	var hero: Dictionary = unit.hero
	var anchor := BattleRunSource.slot_center(target.y, target.x)
	var class_display: Dictionary = BATTLE_CLASS_DISPLAY.get(str(hero.cls), {"color": Color("cfd6dc")})
	var result := {"kind": "global", "anchor": anchor, "radius": 0.0, "width": 0.0, "color": class_display.color}
	match str(hero.cls):
		"cav":
			result.kind = "corridor"
			result.width = (46.0 if float(hero.get("splash", 0.0)) > 0 else 34.0) + float(battle_run.buffs.get("cavWide", 0.0))
		"support":
			result.kind = "ripple"
			result.radius = battle_run.team.ripple_max(battle_run, unit)
		_:
			var radius := float(hero.get("rng", 0.0))
			if radius > 0:
				result.kind = "range"
				result.radius = radius
	return result

func _draw_drag_range_preview(unit: Dictionary, target: Vector2i) -> void:
	if unit == null:
		return
	var spec := _drag_preview_spec(unit, target)
	var anchor: Vector2 = spec.anchor
	var color: Color = spec.color
	match str(spec.kind):
		"corridor":
			var width := float(spec.width)
			draw_rect(Rect2(anchor.x - width, 30, width * 2.0, anchor.y - 78.0), Color(color, 0.14), true)
			draw_rect(Rect2(anchor.x - width, 30, width * 2.0, anchor.y - 78.0), Color(color, 0.65), false, 2.0)
			_text_centered_in_rect("🐎 左中右挑贼多的道冲", Rect2(anchor.x - 110, anchor.y - 78, 220, 20), 11, color)
		"ripple":
			draw_circle(anchor - Vector2(0, 18), float(spec.radius), Color(color, 0.06))
			draw_arc(anchor - Vector2(0, 18), float(spec.radius), 0, TAU, 64, Color(color, 0.65), 2.0)
		"range":
			draw_circle(anchor - Vector2(0, 18), float(spec.radius), Color(color, 0.06))
			draw_arc(anchor - Vector2(0, 18), float(spec.radius), 0, TAU, 64, Color(color, 0.65), 2.0)
		"global":
			_text_centered_in_rect("🏹 全场都能射", Rect2(anchor.x - 80, anchor.y - 72, 160, 20), 12, color)
	if str(unit.hero.cls) == "spear":
		for row in range(maxi(0, target.y - 1), mini(BattleRunSource.GRID_ROWS - 1, target.y + 1) + 1):
			for col in range(maxi(0, target.x - 1), mini(BattleRunSource.GRID_COLS - 1, target.x + 1) + 1):
				if row == target.y and col == target.x:
					continue
				var ally = battle_run.grid[row][col]
				if ally != null and ally != unit:
					var rect := BattleDragControllerSource.cell_rect(Vector2i(col, row))
					draw_rect(rect, Color("6fd44e38"), true)
	var trait_id := str(battle_run.traits.get("%d,%d" % [target.y, target.x], ""))
	if not trait_id.is_empty() and not battle_run.obstacles.has("%d,%d" % [target.y, target.x]):
		_text_centered_in_rect("地利 %s" % trait_id, Rect2(anchor.x - 90, anchor.y - 58, 180, 18), 10, GOLD)

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
	return {
		"body_radius": 21.0,
		"aura_radius": 25.0,
		"ult_radius": 30.0,
		"aura_color": Color(str(rarity.get("color", "#cfd6dc"))),
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
	_text_centered_in_rect(str(hero.get("char", str(hero.get("name", "将")).left(1))), Rect2(-21, -12, 42, 22), 16, Color("ffe8c0"))
	_text_centered_in_rect(str(hero.get("name", "")), Rect2(-25, 7, 50, 14), 8, Color("d5c9a8"))
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
