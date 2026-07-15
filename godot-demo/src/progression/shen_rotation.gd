class_name ShenRotation
extends RefCounted

const Mulberry32Source = preload("res://src/core/mulberry32.gd")

const WEEK0 := 2948
const SHEN_P0 := WEEK0 * 2
const SHEN_COUNT := 6

static func current_period() -> int:
	var local_datetime := Time.get_datetime_dict_from_system(false)
	var local_days := int(floor(float(Time.get_unix_time_from_datetime_dict(local_datetime)) / 86400.0))
	return period_for_local_days(local_days)

static func period_for_local_days(local_days: int) -> int:
	var aligned_days := local_days + 3
	return int(floor(float(aligned_days) / 7.0)) * 2 + (1 if posmod(aligned_days, 7) >= 3 else 0)

static func ids_for_period(period: int, hero_ids: Array) -> Array:
	if period < SHEN_P0:
		return []
	var previous: Array = []
	for current in range(SHEN_P0, period + 1):
		var blocked := {}
		for hero_id in previous:
			blocked[str(hero_id)] = true
		var order: Array = hero_ids.duplicate()
		var seed := Mulberry32Source.imul(current, 668265263) ^ 20260708
		var rng = Mulberry32Source.new(seed)
		for index in range(order.size() - 1, 0, -1):
			var swap_index := int(floor(rng.next_float() * (index + 1)))
			var temporary = order[index]
			order[index] = order[swap_index]
			order[swap_index] = temporary
		previous = []
		for hero_id in order:
			if blocked.has(str(hero_id)):
				continue
			previous.append(str(hero_id))
			if previous.size() >= SHEN_COUNT:
				break
	return previous
