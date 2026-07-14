extends SceneTree

const ContentCatalog = preload("res://src/content/content_catalog.gd")
const Mulberry32 = preload("res://src/core/mulberry32.gd")
const BattleRun = preload("res://src/battle/battle_run.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture := _load_json("res://tests/fixtures/v7.19.2-battle-seed-20260715.json")
	if fixture.is_empty():
		return
	var catalog = ContentCatalog.new()
	if not _expect(catalog.load_from("res://data/content-v7.19.2.json") == OK, "content must load"):
		return
	var seed := int(fixture.seed)
	var run = BattleRun.new(catalog, Mulberry32.new(seed))
	run.start(fixture.city, "caocao", "guanyu")
	if not _expect(run.speed == 2, "battle speed must be fixed at 2x"):
		return
	if not _expect(run.wave == 0 and is_equal_approx(run.wave_timer, 2.0), "run must open with a two-second rest before wave one"):
		return
	if not _expect(run.wall == fixture.city.wall and run.wall_max == fixture.city.wall, "city wall must seed battle durability"):
		return
	if not _expect(run.level == 1 and is_zero_approx(run.xp) and is_equal_approx(run.xp_need, 10.0), "run XP must start at Web values"):
		return
	if not _expect(run.units().size() == 1 and run.units()[0].hero.id == "guanyu", "chosen opening hero must enter the formation"):
		return
	if not _expect(_sorted_keys(run.obstacles) == fixture.layout.obstacles, "seeded obstacle layout must match browser runtime"):
		return
	if not _expect(run.traits == fixture.layout.traits, "all fifteen seeded cell traits must match browser runtime"):
		return
	for row in BattleRun.GRID_ROWS:
		var free_cells := 0
		for col in BattleRun.GRID_COLS:
			if not run.obstacles.has("%d,%d" % [row, col]):
				free_cells += 1
		if not _expect(free_cells >= 2, "each formation row must retain at least two legal cells"):
			return
	var opening: Dictionary = run.units()[0]
	if not _expect(not run.obstacles.has("%d,%d" % [opening.row, opening.col]), "opening hero must occupy a legal cell"):
		return

	# The browser fixture resets Math.random immediately before buildWave(1).
	run.rng = Mulberry32.new(seed)
	run.prepare_next_wave()
	if not _expect(run.next_queue.size() == 13, "wave one must contain thirteen enemies"):
		return
	for index in fixture.wave1.size():
		if not _expect_enemy(run.next_queue[index], fixture.wave1[index], index):
			return
	if not _expect(run.next_wave_preview.themeElems == fixture.waveMeta.themeElems and run.next_wave_preview.weakElem == fixture.waveMeta.weakElem, "wave triangle preview must match browser runtime"):
		return
	if not _test_fixed_speed_scheduler(catalog, fixture.city, seed):
		return
	if not _test_triangle_damage_and_xp(catalog, fixture.city, seed):
		return
	if not _test_spear_auto_attack(catalog, fixture.city, seed):
		return
	if not _test_ranged_and_cavalry_entities(catalog, fixture.city, seed):
		return
	print("Godot v7.19.2 battle run: PASS")
	quit(0)

func _test_fixed_speed_scheduler(catalog, city: Dictionary, seed: int) -> bool:
	var run = BattleRun.new(catalog, Mulberry32.new(seed))
	run.start(city, "caocao", "guanyu")
	run.advance_real(0.5)
	if not _expect(is_equal_approx(run.game_time, 1.0) and is_equal_approx(run.wave_timer, 1.0), "fixed 2x must advance two game seconds per real second"):
		return false
	run.advance_real(0.5)
	if not _expect(run.wave == 1, "wave one must start after two game seconds"):
		return false
	if not _expect(run.enemies.is_empty() and run.spawn_queue.size() == 13, "opening the wave must arm the queue before spawning"):
		return false
	run.advance_real(0.01)
	if not _expect(run.enemies.size() == 1 and run.spawn_queue.size() == 12, "wave start must spawn the zero-delay first enemy"):
		return false
	var enemy: Dictionary = run.enemies[0]
	var y_before := float(enemy.y)
	run.advance_real(0.1)
	if not _expect(float(enemy.y) > y_before, "spawned enemies must march toward the wall"):
		return false
	var wall_before: int = run.wall
	run.spawn_queue = []
	run.enemies = [{
		"x": 240.0, "y": BattleRun.DEFENSE_LINE - 5.0, "r": 15,
		"base_speed": 0.0, "dmg": 3, "dead": false, "hp": 999.0, "hp_max": 999.0,
	}]
	run.advance_real(0.01)
	if not _expect(run.wall == wall_before - 3 and run.enemies.is_empty(), "an enemy crossing the defense line must damage the wall once and disappear"):
		return false
	run.wall = 3
	run.enemies = [{
		"x": 240.0, "y": BattleRun.DEFENSE_LINE - 5.0, "r": 15,
		"base_speed": 0.0, "dmg": 3, "dead": false, "hp": 999.0, "hp_max": 999.0,
	}]
	run.advance_real(0.01)
	if not _expect(run.status == "over" and run.wall == 0, "losing the last wall point must end the run"):
		return false
	run.status = "play"
	run.wall = wall_before
	run.enemies = [{
		"x": 240.0, "y": 100.0, "r": 15, "base_speed": 0.0,
		"dmg": 1, "dead": false, "hp": 999.0, "hp_max": 999.0,
	}]
	run.spawn_queue = []
	run.next_queue = []
	run.wave_budget = 0.05
	run.wave_clock = 0.0
	run.advance_real(0.03)
	if not _expect(run.wave == 2, "wave budget exhaustion must press the next wave without waiting for a clear field"):
		return false
	return true

func _test_triangle_damage_and_xp(catalog, city: Dictionary, seed: int) -> bool:
	var run = BattleRun.new(catalog, Mulberry32.new(seed))
	var one_kill_city := city.duplicate(true)
	one_kill_city.killTarget = 1
	run.start(one_kill_city, "caocao", "guanyu")
	if not _expect(is_equal_approx(BattleRun.triangle_multiplier("rende", "badao"), 1.5), "correct triangle answer must deal x1.5"):
		return false
	if not _expect(is_equal_approx(BattleRun.triangle_multiplier("liangmou", "badao"), 0.6), "countered triangle answer must deal x0.6"):
		return false
	if not _expect(is_equal_approx(BattleRun.triangle_multiplier("badao", "badao"), 1.0), "same triangle must deal normal damage"):
		return false
	var enemy := {
		"x": 240.0, "y": 300.0, "r": 15, "base_speed": 0.0,
		"hp": 15.0, "hp_max": 15.0, "tri": "badao", "xp": 10.0,
		"dmg": 1, "dead": false,
	}
	run.enemies = [enemy]
	run.damage_enemy(enemy, 10.0, "rende")
	if not _expect(run.kills == 1 and run.enemies.is_empty(), "a lethal hit must remove one enemy and increment kills"):
		return false
	if not _expect(run.status == "win", "reaching the city kill target must finish the battle"):
		return false
	if not _expect(run.level == 2 and is_zero_approx(run.xp) and is_equal_approx(run.xp_need, 22.0), "kill XP must follow the Web level curve"):
		return false
	if not _expect(run.awaiting_card_choice, "level-up must pause battle for an in-run card choice"):
		return false
	var wall_before: int = run.wall
	run.advance_real(1.0)
	if not _expect(run.wall == wall_before, "battle simulation must stay paused while choosing a card"):
		return false
	return true

func _test_spear_auto_attack(catalog, city: Dictionary, seed: int) -> bool:
	var run = BattleRun.new(catalog, Mulberry32.new(seed))
	run.start(city, "caocao", "zhangfei")
	var unit: Dictionary = run.units()[0]
	unit.cd = 0.0
	var center: Vector2 = BattleRun.slot_center(int(unit.row), int(unit.col))
	var enemy := {
		"x": center.x, "y": center.y - 100.0, "r": 15, "base_speed": 0.0,
		"hp": 100.0, "hp_max": 100.0, "tri": "badao", "xp": 1.0,
		"dmg": 1, "dead": false,
	}
	run.enemies = [enemy]
	run.spawn_queue = []
	run.advance_real(0.01)
	if not _expect(float(enemy.hp) < 100.0, "an in-range spear hero must auto-attack the frontmost enemy"):
		return false
	if not _expect(float(unit.cd) > 0.0, "auto-attack must reset the hero attack cooldown"):
		return false
	return true

func _test_ranged_and_cavalry_entities(catalog, city: Dictionary, seed: int) -> bool:
	var archer_run = BattleRun.new(catalog, Mulberry32.new(seed))
	archer_run.start(city, "caocao", "huangzhong")
	var archer: Dictionary = archer_run.units()[0]
	archer.cd = 0.0
	var archer_center: Vector2 = BattleRun.slot_center(int(archer.row), int(archer.col))
	var archer_target := {
		"x": archer_center.x, "y": 120.0, "r": 18, "base_speed": 0.0,
		"hp": 100.0, "hp_max": 100.0, "tri": "badao", "xp": 1.0,
		"dmg": 1, "dead": false,
	}
	archer_run.enemies = [archer_target]
	archer_run.advance_real(0.01)
	if not _expect(archer_run.projectiles.size() == 1, "archers must launch a visible projectile instead of applying instant damage"):
		return false
	for step in 12:
		archer_run.advance_real(0.05)
	if not _expect(float(archer_target.hp) < 100.0, "an archer projectile must damage its collision target"):
		return false

	var cavalry_run = BattleRun.new(catalog, Mulberry32.new(seed))
	cavalry_run.start(city, "caocao", "guanyu")
	var cavalry: Dictionary = cavalry_run.units()[0]
	cavalry.cd = 0.0
	var cavalry_center: Vector2 = BattleRun.slot_center(int(cavalry.row), int(cavalry.col))
	var cavalry_target := {
		"x": cavalry_center.x, "y": cavalry_center.y - 120.0, "r": 18, "base_speed": 0.0,
		"hp": 100.0, "hp_max": 100.0, "tri": "badao", "xp": 1.0,
		"dmg": 1, "dead": false,
	}
	cavalry_run.enemies = [cavalry_target]
	cavalry_run.advance_real(0.01)
	if not _expect(cavalry_run.charges.size() == 1, "cavalry must create a lane charge entity"):
		return false
	for step in 8:
		cavalry_run.advance_real(0.05)
	if not _expect(float(cavalry_target.hp) < 100.0, "a cavalry charge must damage enemies in its lane"):
		return false
	return true

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not _expect(file != null, "fixture must open"):
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not _expect(parsed is Dictionary, "fixture must contain a JSON object"):
		return {}
	return parsed

func _sorted_keys(values: Dictionary) -> Array:
	var keys := values.keys()
	keys.sort()
	return keys

func _expect_enemy(actual: Dictionary, expected: Dictionary, index: int) -> bool:
	for key in ["hp", "r", "cls", "big", "affix", "special", "tri", "dmg"]:
		if not _expect(actual.get(key) == expected.get(key), "wave enemy %d field %s must match Web" % [index, key]):
			return false
	for key in ["delay", "speed", "xp"]:
		if not _expect(is_equal_approx(float(actual.get(key)), float(expected.get(key))), "wave enemy %d field %s must match Web" % [index, key]):
			return false
	return true

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
