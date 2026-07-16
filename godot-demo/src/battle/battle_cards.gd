class_name BattleCards
extends RefCounted

const TRI_KE := {"badao": "liangmou", "liangmou": "rende", "rende": "badao"}
const NON_ATTACKING := {"shield": true, "support": true, "granary": true, "egg": true, "dragon": true}
const ELEM_COSMETIC := {
	"huatuo": true, "xiaoqiao": true, "lusu": true, "daqiao": true,
	"xuhuang": true, "caiwenji": true, "simayi": true, "xushu": true,
	"caohong": true, "granary": true, "dragonegg": true, "yinglong": true,
}
const ACTIVE_RELIC_IDS := [
	"qinggang", "longxian", "dilu", "shemao", "lianhuan", "jiuhu", "yuxi", "mengde", "qixing", "sunzi",
	"yiji", "bagua", "yushan", "guding", "hanshu", "tongque", "liannu", "baihu", "jiguan", "huoyou",
	"xuantie", "chensha", "madeng", "jili", "dujing", "jiaowei", "shuijingshu", "jinlan", "fenghuang", "hufu",
]
const EGG_MAX := 3
const GRANARY_MAX := 5
const ELEMENT_CARD_META := {
	"badao": {"name": "霸道", "icon": "✊", "color": "#ff6b4a"},
	"liangmou": {"name": "良谋", "icon": "✌️", "color": "#4aa8ff"},
	"rende": {"name": "仁德", "icon": "✋", "color": "#7ad86a"},
}
const CLASS_CARD_META := {
	"spear": {"name": "枪兵", "icon": "🔱"},
	"cav": {"name": "骑兵", "icon": "🐎"},
	"archer": {"name": "弓兵", "icon": "🏹"},
	"shield": {"name": "盾兵", "icon": "🛡️"},
	"support": {"name": "辅兵", "icon": "🎐"},
	"granary": {"name": "粮仓", "icon": "🌾"},
	"egg": {"name": "龙蛋", "icon": "🥚"},
	"dragon": {"name": "神兽", "icon": "🐉"},
}
const GRANARY_TYPE := {"id": "granary", "name": "粮仓", "char": "粮", "cls": "granary", "elem": "rende", "rng": 0, "dmg": 0, "rate": 9.0, "speed": 0, "hp": 260, "desc": "不打人，产粮喂旁边武将升星；敌人能拆它"}
const EGG_TYPE := {"id": "dragonegg", "name": "龙蛋", "char": "蛋", "cls": "egg", "elem": "badao", "dmg": 0, "rate": 9.0, "speed": 0, "hp": 300, "desc": "孵着持续吐纳经验，三阶可觉醒"}
const DRAGON_TYPE := {"id": "yinglong", "name": "应龙", "char": "龍", "cls": "dragon", "elem": "badao", "dmg": 0, "rate": 2.8, "speed": 0, "hp": 520, "desc": "龙息重击并镇压最强威胁"}

var catalog
var rng

func _init(content_catalog, random_source) -> void:
	catalog = content_catalog
	rng = random_source

func build_pool(run) -> Array:
	var pool := []
	var units: Array = run.units()
	var owned := {}
	var counts := {"spear": 0, "cav": 0, "archer": 0, "shield": 0, "support": 0}
	for unit in units:
		owned[str(unit.hero.id)] = true
		var hero_class := str(unit.hero.cls)
		if counts.has(hero_class):
			counts[hero_class] += 1
	if not run.empty_slots().is_empty():
		for hero in catalog.list("heroes"):
			var hero_id := str(hero.id)
			if owned.has(hero_id):
				continue
			var weight := 8.0
			var class_count := int(counts.get(str(hero.cls), 0))
			if class_count == 1 or class_count == 3:
				weight += 4.0
			if not ELEM_COSMETIC.has(hero_id):
				weight += _element_weight(str(hero.elem), str(run.city.get("foes", {}).get("tri", "")))
			if _completes_bond(hero_id, owned):
				weight += 8.0
			var shen: bool = run.shen_ids.has(hero_id)
			if shen:
				weight += 6.0
			if _is_kin(hero_id, run.ruler_id):
				weight += 6.0
			var card := {
				"kind": "unit", "hero_id": hero_id, "weight": maxf(2.0, weight),
				"title": ("神·" if shen else "") + str(hero.name) + "出征",
				"icon": "", "desc": str(hero.desc), "cls": str(hero.cls), "elem": str(hero.elem),
			}
			_add_hero_card_presentation(card, hero, run, shen, _completing_bond_name(hero_id, owned))
			pool.append(card)
	var seen := {}
	for unit in units:
		var hero: Dictionary = unit.hero
		var hero_id := str(hero.id)
		if seen.has(hero_id) or int(unit.level) >= 15 or ["granary", "egg", "dragon"].has(str(hero.cls)):
			continue
		seen[hero_id] = true
		var lowest: Dictionary = unit
		for other in units:
			if str(other.hero.id) == hero_id and int(other.level) < int(lowest.level):
				lowest = other
		var next_star := int(lowest.level) + 1
		var desc := "伤害×1.9"
		if str(hero.cls) == "shield":
			desc = "更耐打，反伤更疼"
		elif str(hero.cls) == "support":
			desc = "水波更勤快，人更耐打"
		elif next_star > 10:
			desc = "二阶升华：伤害×1.3"
		elif next_star > 5:
			desc = "升华星：伤害×1.4"
		var card := {
			"kind": "upgrade", "hero_id": hero_id, "weight": 13.0,
			"title": ("神·" if run.shen_ids.has(hero_id) else "") + str(hero.name) + "练兵",
			"icon": "", "desc": desc, "cls": str(hero.cls), "elem": str(hero.elem), "stars": next_star,
		}
		_add_hero_card_presentation(card, hero, run, run.shen_ids.has(hero_id), "", false)
		pool.append(card)

	var buffs: Dictionary = run.buffs
	_add_capped_buff(pool, buffs.dmg < 3.0, "dmg", 0.25, 9, "全军猛攻", "⚔️", "全军伤害+25%（叠到+200%封顶）")
	_add_capped_buff(pool, buffs.rate < 2.0, "rate", 0.2, 9, "击鼓进军", "🥁", "全军出手快+20%（叠到+100%封顶）")
	_add_capped_buff(pool, buffs.critCh < 0.5, "critCh", 0.1, 7, "青囊秘术", "💥", "多10%机会双倍暴击（叠到50%封顶）")
	_add_capped_buff(pool, buffs.xpGain < 2.0, "xpGain", 0.25, 6, "招贤纳士", "📜", "杀敌经验+25%（叠到+100%封顶）")
	_add_capped_buff(pool, buffs.ultHaste < 0.48, "ultHaste", 0.12, 8, "神机妙算", "🧠", "武将大招转快12%（有封顶）")
	_add_capped_buff(pool, counts.spear >= 1 and buffs.spearAura < 0.2, "spearAura", 0.05, 8, "战阵精修", "🔱", "枪兵带人变强再+5%（有封顶）")
	_add_capped_buff(pool, counts.cav >= 1 and buffs.cavWide < 100.0, "cavWide", 10.0, 8, "铁骑列装", "🐎", "骑兵冲得更宽+10（有封顶）")
	_add_capped_buff(pool, counts.cav >= 1 and buffs.cavDmg < 1.2, "cavDmg", 0.12, 8, "冲势如虹", "🐎", "骑兵伤害+12%（叠到+120%封顶）")
	_add_capped_buff(pool, counts.archer >= 1 and buffs.archerDmg < 1.0, "archerDmg", 0.1, 8, "箭术精修", "🏹", "弓兵伤害+10%（叠到+100%封顶）")
	_add_capped_buff(pool, counts.shield >= 1 and buffs.shieldReflect < 0.1, "shieldReflect", 0.01, 8, "荆棘重甲", "🛡️", "盾兵反弹更疼 +25%（有封顶）")
	_add_capped_buff(pool, counts.support >= 1 and buffs.rippleRad < 175.0, "rippleRad", 35.0, 8, "波纹深远", "🎐", "辅兵那圈更大+35（有封顶）")

	if not run.obstacles.is_empty():
		pool.append({"kind": "terrain", "weight": 16.0 if run.obstacles.size() >= 6 else 8.0, "title": "开山凿石", "icon": "🧹", "desc": "炸掉 1 块石头，露出宝地"})
	else:
		pool.append({"kind": "merit", "weight": 5.0, "value": mini(150, 25 + run.wave), "title": "犒赏三军", "icon": "💰", "desc": "金币落袋为安"})
	if run.ruler_id == "caocao":
		var granaries: Array = units.filter(func(unit): return str(unit.hero.cls) == "granary")
		var unfinished: Array = granaries.filter(func(unit): return int(unit.level) < GRANARY_MAX)
		if not unfinished.is_empty():
			var lowest: Dictionary = unfinished[0]
			for granary in unfinished:
				if int(granary.level) < int(lowest.level): lowest = granary
			pool.append({"kind": "granary", "weight": 13.0, "title": "粮仓扩建", "icon": "🌾", "cls": "granary", "stars": int(lowest.level) + 1, "desc": "产粮×1.6"})
		elif not run.empty_slots().is_empty():
			pool.append({"kind": "granary", "weight": 9.0 if not granaries.is_empty() else 15.0, "title": "屯田粮仓", "icon": "🌾", "cls": "granary", "desc": "产粮喂旁边武将升星，敌人能拆它"})
	if run.ruler_id == "liubiao" and (run.endless or (int(run.city.get("metaWins", 0)) >= 8 and run.wave >= 10)):
		var egg = units.filter(func(unit): return str(unit.hero.cls) == "egg").front() if units.any(func(unit): return str(unit.hero.cls) == "egg") else null
		if egg != null and int(egg.level) >= EGG_MAX:
			pool.append({"kind": "egg", "sub": "awaken", "weight": 14.0, "title": "应龙觉醒", "icon": "🐉", "desc": "破壳觉醒，龙息镇压最强威胁"})
		elif egg != null:
			pool.append({"kind": "egg", "sub": "grow", "weight": 14.0, "title": "温养龙蛋", "icon": "🥚", "desc": "把握%d成，失败后下次+2成" % roundi(run.egg_hatch_chance(egg) * 10.0)})
		elif not run.empty_slots().is_empty() and run.dragon_count < 2:
			pool.append({"kind": "egg", "sub": "place", "weight": 8.0, "title": "天降龙蛋", "icon": "🥚", "desc": "每秒吐纳经验，三阶觉醒应龙"})

	var owned_elements := {}
	for unit in units:
		var hero: Dictionary = unit.hero
		if float(hero.get("dmg", 0.0)) > 0 and not ELEM_COSMETIC.has(str(hero.id)):
			owned_elements[str(hero.elem)] = true
	for element in ["badao", "liangmou", "rende"]:
		if not owned_elements.has(element) or float(buffs.elemBoost[element]) >= 0.9:
			continue
		pool.append({
			"kind": "elem", "elem": element, "value": 0.3,
			"weight": maxf(3.0, 7.0 + _element_weight(element, str(run.city.get("foes", {}).get("tri", "")))),
			"title": _element_name(element) + "淬炼", "icon": _element_icon(element),
			"desc": _element_icon(element) + _element_name(element) + "系伤害 +30%",
		})
	if counts.archer >= 1 and int(buffs.extraShot) < 2:
		_add_capped_buff(pool, true, "extraShot", 1, 4, "万箭齐发", "🌠", "弓兵多射一箭")
	if run.wall < run.wall_max:
		pool.append({"kind": "heal", "weight": 8.0, "title": "修筑城防", "icon": "🏯", "desc": "城墙补3点血"})
	if run.lord_atk_buff < 2.0:
		pool.append({"kind": "lordatk", "weight": 7.0, "title": "御驾亲征", "icon": "🎯", "desc": "主公亲射伤害+40%（叠到+200%封顶）"})
	if run.lord_atk_gap > 0.4:
		pool.append({"kind": "lordhaste", "weight": 5.0, "title": "神机连弩", "icon": "⚙️", "desc": "主公亲射出手快25%"})
	if not run.permanent_tactics.has("luanshi") and not run.obstacles.is_empty():
		pool.append({"kind": "tacperm", "tactic": "luanshi", "weight": 6.0, "title": "乱石穿空", "icon": "🪨", "desc": "此后每波障碍齐射"})
	if not run.permanent_tactics.has("huoshao") and (run.ruler_id == "dongzhuo" or _has_burn_unit(units)):
		pool.append({"kind": "tacperm", "tactic": "huoshao", "weight": 6.0, "title": "火烧连营", "icon": "🔥", "desc": "着火的贼死亡时爆燃传火"})
	if not run.permanent_tactics.has("zhanshou"):
		pool.append({"kind": "tacperm", "tactic": "zhanshou", "weight": 6.0, "title": "擒贼擒王", "icon": "🎯", "desc": "精锐/贼首登场挨主公重击"})
	if not run.permanent_tactics.has("luojing"):
		pool.append({"kind": "tacperm", "tactic": "luojing", "weight": 6.0, "title": "落井下石", "icon": "🕳️", "desc": "受制的贼挨打+30%"})
	if not run.permanent_tactics.has("shuiyan"):
		pool.append({"kind": "tacperm", "tactic": "shuiyan", "weight": 8.0 if run.ruler_id == "sunquan" else 5.0, "title": "水淹七军", "icon": "🌊", "desc": "每波自动起江减速增伤"})
	if run.wall_max > 6 and not run.permanent_tactics.has("pofu"):
		pool.append({"kind": "pofu", "weight": 5.0, "title": "破釜沉舟", "icon": "🍳", "desc": "城墙上限-2，全军伤害×1.5"})
	pool.append({"kind": "reroll", "weight": 5.0, "title": "偷梁换柱", "icon": "🎲", "desc": "这手牌全不要，当场重摸一手"})
	pool.append({"kind": "levelup", "weight": 4.0, "title": "校场演武", "icon": "🎓", "desc": "立刻升一级，当场再摸一手牌"})
	pool.append({"kind": "seppuku", "weight": 3.0, "title": "自刎归天", "icon": "🗡️", "desc": "当场收兵，本局分数+10%"})
	pool.append({"kind": "dance", "weight": 3.0, "title": "乐不思蜀", "icon": "💃", "desc": "全军攻击+30%，自动抽卡挂机"})
	return pool

func roll(run) -> Array:
	var pool := build_pool(run)
	var granary_card: Dictionary = {}
	var egg_card: Dictionary = {}
	var shen_cards: Array = []
	for card in pool:
		if str(card.kind) == "granary" and granary_card.is_empty(): granary_card = card
		if str(card.kind) == "egg" and egg_card.is_empty(): egg_card = card
		if str(card.kind) == "unit" and run.shen_ids.has(str(card.get("hero_id", ""))): shen_cards.append(card)
	for card in pool:
		var picked := int(run.card_picks.get(str(card.title), 0))
		if picked > 0 and str(card.kind) != "egg":
			card.weight = maxf(1.0, float(card.weight) / (1.0 + picked * 0.4))
	var result := []
	var draw_count := 4 if run.relic_ids.has("yiji") else 3
	if run.wide_picks > 0:
		draw_count = 5
		run.wide_picks -= 1
	for draw_index in draw_count:
		if pool.is_empty():
			break
		var total := 0.0
		for card in pool:
			total += float(card.weight)
		var value: float = rng.next_float() * total
		var selected_index := 0
		for index in pool.size():
			value -= float(pool[index].weight)
			if value <= 0:
				selected_index = index
				break
		var selected: Dictionary = pool[selected_index]
		result.append(selected)
		var title := str(selected.title)
		for index in range(pool.size() - 1, -1, -1):
			if str(pool[index].title) == title:
				pool.remove_at(index)
	if not run.granary_offered:
		if result.any(func(card): return str(card.kind) == "granary"):
			run.granary_offered = true
		elif run.wave >= 2 and not granary_card.is_empty() and not result.is_empty():
			result[result.size() - 1] = granary_card
			run.granary_offered = true
	if not run.egg_offered:
		if result.any(func(card): return str(card.kind) == "egg"):
			run.egg_offered = true
		elif run.endless and not egg_card.is_empty() and not result.is_empty():
			var replace_index := result.size() - 1
			while replace_index > 0 and str(result[replace_index].kind) == "granary": replace_index -= 1
			result[replace_index] = egg_card
			run.egg_offered = true
	if result.any(func(card): return str(card.kind) == "unit" and run.shen_ids.has(str(card.get("hero_id", "")))):
		run.shen_dry = 0
	elif not shen_cards.is_empty():
		run.shen_dry += 1
		if run.shen_dry >= 3 and not result.is_empty():
			var replace_index := result.size() - 1
			while replace_index > 0 and ["granary", "egg"].has(str(result[replace_index].kind)): replace_index -= 1
			result[replace_index] = shen_cards[int(floor(rng.next_float() * shen_cards.size()))]
			run.shen_dry = 0
	return result

func widen_current(run, current: Array, target_count: int) -> void:
	var pool := build_pool(run)
	var existing_titles := {}
	for card in current:
		existing_titles[str(card.title)] = true
	for index in range(pool.size() - 1, -1, -1):
		if existing_titles.has(str(pool[index].title)):
			pool.remove_at(index)
	while current.size() < target_count and not pool.is_empty():
		var total := 0.0
		for card in pool:
			total += float(card.weight)
		var value: float = rng.next_float() * total
		var selected_index := pool.size() - 1
		for index in pool.size():
			value -= float(pool[index].weight)
			if value <= 0:
				selected_index = index
				break
		current.append(pool[selected_index])
		pool.remove_at(selected_index)

func build_relic_pool(run) -> Array:
	var result := []
	for relic in catalog.list("relics"):
		var relic_id := str(relic.id)
		if not ACTIVE_RELIC_IDS.has(relic_id) or run.relic_ids.has(relic_id) or not _relic_available(run, relic_id):
			continue
		result.append(relic)
	return result

func roll_relics(run) -> Array:
	var pool := build_relic_pool(run).duplicate()
	for index in range(pool.size() - 1, 0, -1):
		var swap_index := int(floor(rng.next_float() * (index + 1)))
		var temporary = pool[index]
		pool[index] = pool[swap_index]
		pool[swap_index] = temporary
	var result := []
	for index in mini(3, pool.size()):
		var relic: Dictionary = pool[index]
		result.append({
			"kind": "relic", "relic_id": str(relic.id), "title": str(relic.name),
			"icon": str(relic.icon), "desc": str(relic.desc), "info": str(relic.get("who", "")),
		})
	return result

func apply(run, card) -> bool:
	if card == null:
		return false
	var data: Dictionary = card
	run.card_picks[data.title] = int(run.card_picks.get(data.title, 0)) + 1
	var applied := true
	match str(data.kind):
		"unit": applied = run.add_unit(str(data.hero_id))
		"upgrade": applied = run.upgrade_hero(str(data.hero_id))
		"buff": run.buffs[data.buff] = float(run.buffs[data.buff]) + float(data.value)
		"elem": run.buffs.elemBoost[data.elem] = float(run.buffs.elemBoost[data.elem]) + float(data.value)
		"terrain": applied = run.remove_random_obstacle()
		"heal": run.wall = mini(run.wall_max, run.wall + 3)
		"lordatk": run.lord_atk_buff = minf(2.0, run.lord_atk_buff + 0.4)
		"lordhaste": run.lord_atk_gap = maxf(0.4, snappedf(run.lord_atk_gap * 0.75, 0.001))
		"tacperm": run.permanent_tactics[data.tactic] = true
		"pofu":
			run.permanent_tactics.pofu = true
			run.wall_max = maxi(3, run.wall_max - 2)
			run.wall = mini(run.wall, run.wall_max)
		"granary":
			applied = _apply_granary(run)
		"egg": applied = _apply_egg(run, data)
		"levelup":
			run.level += 1
			run.xp_need = round((10.0 + (run.level - 1) * 9.0 + pow(run.level, 1.72)) * (0.88 if run.relic_ids.has("hanshu") else 1.0))
			run.pending_picks += 1
		"seppuku": run.finish("over")
		"dance":
			run.permanent_tactics.gewu = true
			run.dance_time = 3.0
		"merit": run.run_gold += float(data.get("value", 0.0))
		"reroll": run.pending_picks += 1
		"relic":
			var relic_id := str(data.relic_id)
			if run.relic_ids.has(relic_id):
				applied = false
			else:
				run.relic_ids.append(relic_id)
		_: applied = false
	_finish_choice(run)
	return applied

func _apply_egg(run, data: Dictionary) -> bool:
	match str(data.get("sub", "")):
		"place": return run.add_unit_data(EGG_TYPE.duplicate(true))
		"grow":
			var eggs: Array = run.units().filter(func(unit): return str(unit.hero.cls) == "egg" and int(unit.level) < EGG_MAX)
			if eggs.is_empty(): return false
			var egg: Dictionary = eggs[0]
			if rng.next_float() < run.egg_hatch_chance(egg):
				egg.level = int(egg.level) + 1
				egg.hatchBonus = 0.0
				egg.hp_max = run._unit_max_hp(egg.hero, int(egg.level))
				egg.hp = egg.hp_max
			else:
				egg.hatchBonus = float(egg.get("hatchBonus", 0.0)) + 0.2
			return true
		"awaken":
			var ready: Array = run.units().filter(func(unit): return str(unit.hero.cls) == "egg" and int(unit.level) >= EGG_MAX)
			if ready.is_empty(): return false
			var egg: Dictionary = ready[0]
			var row := int(egg.row)
			var col := int(egg.col)
			run.dragon_count += 1
			run.unlock_achievement_event("dragon1")
			if run.dragon_count >= 2: run.unlock_achievement_event("dragon2")
			run.dragon_waves.append(run.wave)
			var dragon: Dictionary = run._make_unit(DRAGON_TYPE.duplicate(true), row, col)
			dragon.dragonRank = run.dragon_count
			run.grid[row][col] = dragon
			run.team.recompute(run)
			return true
	return false

func _apply_granary(run) -> bool:
	var unfinished: Array = run.units().filter(func(unit): return str(unit.hero.cls) == "granary" and int(unit.level) < GRANARY_MAX)
	if unfinished.is_empty():
		return run.add_unit_data(GRANARY_TYPE.duplicate(true))
	var lowest: Dictionary = unfinished[0]
	for granary in unfinished:
		if int(granary.level) < int(lowest.level): lowest = granary
	lowest.level = int(lowest.level) + 1
	lowest.bounce = 1.0
	lowest.hp_max = run._unit_max_hp(lowest.hero, int(lowest.level))
	lowest.hp = lowest.hp_max
	return true

func _finish_choice(run) -> void:
	run.card_choices = []
	run.picking_relic = false
	if run.status != "play":
		run.awaiting_card_choice = false
		run.pending_picks = 0
		run.pending_relic_picks = 0
		return
	if run.pending_relic_picks > 0:
		run.pending_relic_picks -= 1
		run.card_choices = roll_relics(run)
		run.picking_relic = not run.card_choices.is_empty()
		run.awaiting_card_choice = run.picking_relic
	elif run.pending_picks > 0:
		run.pending_picks -= 1
		run.card_choices = roll(run)
		run.awaiting_card_choice = not run.card_choices.is_empty()
	else:
		run.awaiting_card_choice = false

func _relic_available(run, relic_id: String) -> bool:
	var units: Array = run.units()
	var owned := {}
	for unit in units:
		owned[str(unit.hero.id)] = true
	match relic_id:
		"longxian": return units.any(func(unit): return str(unit.hero.cls) == "egg")
		"jiguan": return owned.has("weiyan") or owned.has("huangyueying")
		"huoyou": return units.any(func(unit): return bool(unit.hero.get("burn", false)) or str(unit.hero.id) == "huanggai")
		"xuantie": return owned.has("zhugeliang")
		"chensha": return owned.has("diaochan") or owned.has("zhangliao")
		"madeng": return int(run.team.counts.get("cav", 0)) >= 1
		"jili": return owned.has("xuchu") or owned.has("xuhuang")
		"dujing": return owned.has("wutugu")
		"jiaowei": return owned.has("daqiao")
		"shuijingshu": return owned.has("xushu")
		"jinlan": return not run.team.active_bonds.is_empty()
		"fenghuang": return units.any(func(unit): return int(unit.level) >= 5 and not ["granary", "egg", "dragon"].has(str(unit.hero.cls)))
		"hufu": return int(run.team.counts.get("shield", 0)) >= 1
	return true

func _add_capped_buff(pool: Array, allowed: bool, key: String, value: float, weight: float, title: String, icon: String, desc: String) -> void:
	if allowed:
		pool.append({"kind": "buff", "buff": key, "value": value, "weight": weight, "title": title, "icon": icon, "desc": desc})

func _element_weight(hero_element: String, enemy_element: String) -> float:
	if not enemy_element:
		return 0.0
	if TRI_KE.get(hero_element, "") == enemy_element:
		return 10.0
	if TRI_KE.get(enemy_element, "") == hero_element:
		return -5.0
	return 0.0

func _completes_bond(hero_id: String, owned: Dictionary) -> bool:
	return not _completing_bond_name(hero_id, owned).is_empty()

func _completing_bond_name(hero_id: String, owned: Dictionary) -> String:
	for bond in catalog.list("bonds"):
		if not bond.members.has(hero_id):
			continue
		var complete := true
		for member in bond.members:
			if str(member) != hero_id and not owned.has(str(member)):
				complete = false
				break
		if complete:
			return str(bond.name)
	return ""

func _add_hero_card_presentation(card: Dictionary, hero: Dictionary, run, shen: bool, bond_name := "", include_tag := true) -> void:
	var element: Dictionary = ELEMENT_CARD_META.get(str(hero.elem), {"name": str(hero.elem), "icon": "", "color": "#e8dcc0"})
	var hero_class: Dictionary = CLASS_CARD_META.get(str(hero.cls), {"name": str(hero.cls), "icon": ""})
	card.info = "%s%s系 · %s%s" % [element.icon, element.name, hero_class.icon, hero_class.name]
	card.infoColor = str(element.color)
	card.lvN = int(run.hero_levels.get(str(hero.id), 1))
	if not include_tag:
		return
	if shen:
		card.tag = "👼本期神将!"
	elif not str(bond_name).is_empty():
		card.tag = "🔗成羁绊「%s」!" % bond_name
	elif _is_kin(str(hero.id), run.ruler_id):
		card.tag = "🤝亲军·登场+%d星" % run.kin_gift_stars(str(hero.id))
	else:
		card.tag = ""
	card.tagBad = false

func _is_kin(hero_id: String, ruler_id: String) -> bool:
	if hero_id == "jiaxu":
		return true
	return catalog.content.get("lord_kin", {}).get(ruler_id, []).has(hero_id)

func _has_burn_unit(units: Array) -> bool:
	for unit in units:
		if bool(unit.hero.get("burn", false)) or bool(unit.hero.get("firebrand", false)) or str(unit.hero.id) == "huanggai":
			return true
	return false

func _element_name(element: String) -> String:
	return {"badao": "霸道", "liangmou": "良谋", "rende": "仁德"}.get(element, element)

func _element_icon(element: String) -> String:
	return {"badao": "✊", "liangmou": "✌️", "rende": "✋"}.get(element, "")
