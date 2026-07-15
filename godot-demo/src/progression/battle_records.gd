class_name BattleRecords
extends RefCounted

const Mulberry32 = preload("res://src/core/mulberry32.gd")
const STAR_MULTIPLIERS := [0.0, 1.0, 1.25, 1.5]
const SUPPRESSION_PER_WAVE := 0.25
const TOP_RECORDS := 10
const ENDLESS_RAMP := [1.06, 1.09, 1.12, 1.15]
const GUEST_POOL := ["liubei", "sunquan", "liubiao", "gongsunzan", "dongzhuo"]
const WEEK_BANDS := [
	{"at": 2000, "gold": 500}, {"at": 6000, "gold": 1200}, {"at": 13000, "gold": 2500},
	{"at": 25000, "gold": 4000}, {"at": 45000, "gold": 6000}, {"at": 80000, "gold": 9000},
]

static func week_guest_lords(week: int) -> Array:
	var seed := Mulberry32.imul(week, 2654435761) ^ 887654321
	var random := Mulberry32.new(seed)
	var first := int(floor(random.next_float() * GUEST_POOL.size()))
	var second := int(floor(random.next_float() * (GUEST_POOL.size() - 1)))
	if second >= first: second += 1
	return [GUEST_POOL[first], GUEST_POOL[second]]

static func claimable_week_bands(claimed: int, score: int) -> Dictionary:
	var next_claimed := clampi(claimed, 0, WEEK_BANDS.size())
	var gold := 0
	while next_claimed < WEEK_BANDS.size() and score >= int(WEEK_BANDS[next_claimed].at):
		gold += int(WEEK_BANDS[next_claimed].gold)
		next_claimed += 1
	return {"claimed": next_claimed, "gold": gold}

static func week_level_base(city_index: int) -> int:
	if city_index <= 15:
		return roundi(100.0 * pow(1.2, city_index))
	if city_index <= 31:
		return roundi(1541.0 * pow(1.15, city_index - 15))
	if city_index <= 47:
		return roundi(14421.0 * pow(1.12, city_index - 31))
	return roundi(88409.0 * pow(1.10, city_index - 47))

static func calc_stars(wall_hurt: bool, unit_deaths: int) -> int:
	return 1 + (0 if wall_hurt else 1) + (0 if unit_deaths > 0 else 1)

static func city_progress(city_index: int, stars: int) -> int:
	return roundi(week_level_base(city_index) * STAR_MULTIPLIERS[clampi(stars, 1, 3)])

static func city_suppression(city_index: int, stars: int, waves: int, guest := false, almanac := false) -> int:
	var multiplier := 1.0
	if guest: multiplier *= 1.3
	if almanac: multiplier *= 1.2
	return roundi(week_level_base(city_index) * STAR_MULTIPLIERS[clampi(stars, 1, 3)] * SUPPRESSION_PER_WAVE * maxi(0, waves) * multiplier)

static func attempt_score(city_index: int, stars: int, waves: int, guest := false, almanac := false) -> int:
	var effective_waves := maxi(0, waves) * (1.3 if guest else 1.0) * (1.2 if almanac else 1.0)
	return roundi(week_level_base(city_index) * STAR_MULTIPLIERS[clampi(stars, 1, 3)] * maxf(1.0, 1.0 + SUPPRESSION_PER_WAVE * effective_waves))

static func merge_city_best(previous: Dictionary, stars: int, waves: int, guest := false, almanac := false) -> Dictionary:
	var best_stars := maxi(stars, int(previous.get("stars", 0)))
	var previous_effective := int(previous.get("endless", 0)) * (1.3 if bool(previous.get("guest", false)) else 1.0) * (1.2 if bool(previous.get("hl", false)) else 1.0)
	var new_effective := waves * (1.3 if guest else 1.0) * (1.2 if almanac else 1.0)
	var result := {"stars": best_stars, "endless": int(previous.get("endless", 0))}
	if new_effective >= previous_effective:
		result.endless = maxi(0, waves)
		if guest and waves > 0: result.guest = 1
		if almanac and waves > 0: result.hl = 1
	else:
		if bool(previous.get("guest", false)): result.guest = 1
		if bool(previous.get("hl", false)): result.hl = 1
	return result

static func finalize_city_best(city_index: int, previous: Dictionary, stars: int, waves: int, guest := false, almanac := false) -> Dictionary:
	var result := merge_city_best(previous, stars, waves, guest, almanac)
	result.score = city_progress(city_index, int(result.stars)) + city_suppression(
		city_index, int(result.stars), int(result.endless), bool(result.get("guest", false)), bool(result.get("hl", false))
	)
	return result

static func week_score(records: Dictionary) -> int:
	var progress_total := 0
	var suppression_values: Array[int] = []
	for key in records:
		var city_index := int(key)
		var record: Dictionary = records[key]
		progress_total += city_progress(city_index, int(record.get("stars", 1)))
		suppression_values.append(city_suppression(
			city_index,
			int(record.get("stars", 1)),
			int(record.get("endless", 0)),
			bool(record.get("guest", false)),
			bool(record.get("hl", false))
		))
	suppression_values.sort_custom(func(a: int, b: int): return a > b)
	var total := progress_total
	for index in mini(TOP_RECORDS, suppression_values.size()):
		total += suppression_values[index]
	return total

static func suppression_cut(records: Dictionary) -> int:
	var values: Array[int] = []
	for key in records:
		var record: Dictionary = records[key]
		var value := city_suppression(int(key), int(record.get("stars", 1)), int(record.get("endless", 0)), bool(record.get("guest", false)), bool(record.get("hl", false)))
		if value > 0: values.append(value)
	values.sort_custom(func(a: int, b: int): return a > b)
	return values[TOP_RECORDS - 1] if values.size() >= TOP_RECORDS else 0

static func is_top_suppression(records: Dictionary, city_index: int) -> bool:
	if not records.has(str(city_index)) and not records.has(city_index): return false
	var record: Dictionary = records.get(str(city_index), records.get(city_index, {}))
	var value := city_suppression(city_index, int(record.get("stars", 1)), int(record.get("endless", 0)), bool(record.get("guest", false)), bool(record.get("hl", false)))
	return value > 0 and value >= suppression_cut(records)

static func tech_score(city_index: int, counter_fraction: float, wall_fraction: float, theme_fit: bool) -> int:
	var fit := 1.3 if theme_fit else 1.0
	return roundi(week_level_base(city_index) * (0.6 + 0.8 * clampf(counter_fraction, 0.0, 1.0)) * (0.6 + 0.6 * clampf(wall_fraction, 0.0, 1.0)) * fit)

static func endless_hp_multiplier(wave: int, win_wave: int) -> float:
	var extra := maxi(0, wave - win_wave - 5)
	var result := 1.0
	for index in extra:
		result *= ENDLESS_RAMP[index] if index < ENDLESS_RAMP.size() else 1.18
	return result

static func endless_gold_multiplier(wave: int, win_wave: int) -> float:
	return pow(0.88, maxi(0, wave - win_wave))
