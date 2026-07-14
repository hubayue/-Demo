class_name WeeklyMap
extends RefCounted

const Mulberry32Source = preload("res://src/core/mulberry32.gd")
const WEEK0 := 2948
const WEEK_N := 64
const RULE_POOL := ["smoke", "mud", "crossbow", "rush", "elite", "ruin", "rocks", "twinBoss"]
const TRI_KEYS := ["badao", "liangmou", "rende"]
const TWIN_MIN_K := 10

var catalog
var _cached_week := -1
var _cached_slots: Array = []

func _init(content_catalog) -> void:
    catalog = content_catalog

func make_slots(week: int) -> Array:
    if _cached_week == week:
        return _cached_slots
    var rng = Mulberry32Source.new(Mulberry32Source.imul(week, 2654435761) ^ 987654321)
    var orders := [
        _shuffled(rng, range(8)),
        _shuffled(rng, range(8)),
    ]
    var field_ids := []
    for field in catalog.list("fields"):
        field_ids.append(field.id)
    var field_bag := _field_bag(rng, field_ids)
    var rule_bag := _rule_bag(rng, 6)
    var tri_bag := _tri_bag(rng)

    var rng2 = Mulberry32Source.new(Mulberry32Source.imul(week, 1597334677) ^ 123456789)
    orders.append(_shuffled(rng2, range(8)))
    orders.append(_shuffled(rng2, range(8)))
    var field_bag2 := _field_bag(rng2, field_ids)
    var rule_bag2 := _rule_bag(rng2, 11)
    var tri_bag2 := _tri_bag(rng2)

    var slots := []
    for k in WEEK_N:
        var west := k >= 32
        var bag_k := k - 32 if west else k
        var rules := []
        var active_rule_bag: Array = rule_bag2 if west else rule_bag
        for ignored in _week_rules_n(k):
            var index := _first_rule_index(active_rule_bag, rules, k)
            if index < 0:
                break
            rules.append(active_rule_bag[index])
            active_rule_bag.remove_at(index)
        slots.append({
            "k": k,
            "ch": orders[int(k / 16)][int((k % 16) / 2)],
            "tri": TRI_KEYS[(tri_bag2 if west else tri_bag)[bag_k]],
            "field": (field_bag2 if west else field_bag)[bag_k],
            "rules": rules,
        })
    _cached_week = week
    _cached_slots = slots
    return slots

func theme_of(week: int, region := 0) -> Dictionary:
    var themes: Array = catalog.list("week_themes")
    var first := 0 if week == WEEK0 else int(Mulberry32Source.new(week * 131 + 7).next_float() * themes.size())
    if region == 0:
        return themes[first]
    var shift := 1 + int(Mulberry32Source.new(week * 613 + 29).next_float() * (themes.size() - 1))
    var second := (first + shift) % themes.size()
    if region == 1:
        return themes[second]
    var rest := []
    for index in themes.size():
        if index != first and index != second:
            rest.append(index)
    var order := _shuffled(Mulberry32Source.new(week * 977 + 53), rest)
    return themes[order[region - 2]]

func _field_bag(rng, field_ids: Array) -> Array:
    var source := field_ids.duplicate()
    source.append_array(field_ids)
    source.append_array(_shuffled(rng, field_ids).slice(0, 32 - field_ids.size() * 2))
    return _shuffled(rng, source)

func _rule_bag(rng, copies: int) -> Array:
    var source := []
    for rule in RULE_POOL:
        for ignored in copies:
            source.append(rule)
    return _shuffled(rng, source)

func _tri_bag(rng) -> Array:
    var source := []
    for index in 30:
        source.append(index % 3)
    source.append(int(rng.next_float() * 3))
    source.append(int(rng.next_float() * 3))
    return _shuffled(rng, source)

func _shuffled(rng, source) -> Array:
    var result: Array = source.duplicate()
    for index in range(result.size() - 1, 0, -1):
        var other := int(rng.next_float() * (index + 1))
        var swap = result[index]
        result[index] = result[other]
        result[other] = swap
    return result

func _week_rules_n(k: int) -> int:
    if k < 2:
        return 0
    if k < 8:
        return 1
    if k < 14:
        return 1 + k % 2
    if k < 24:
        return 2
    if k < 48:
        return 2 + k % 2
    return 3

func _first_rule_index(rule_bag: Array, chosen: Array, k: int) -> int:
    for index in rule_bag.size():
        var rule = rule_bag[index]
        if not chosen.has(rule) and (rule != "twinBoss" or k >= TWIN_MIN_K):
            return index
    return -1
