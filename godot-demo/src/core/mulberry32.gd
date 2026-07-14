class_name Mulberry32
extends RefCounted

var _state: int

func _init(seed: int) -> void:
    _state = _signed32(seed)

func next_float() -> float:
    _state = _signed32(_state + 0x6D2B79F5)
    var t := imul(_state ^ (_u32(_state) >> 15), 1 | _state)
    var mixed := _signed32(t + imul(t ^ (_u32(t) >> 7), 61 | t))
    t = _signed32(mixed ^ t)
    return float(_u32(t ^ (_u32(t) >> 14))) / 4294967296.0

static func imul(a: int, b: int) -> int:
    var a_low := _u32(a) & 0xFFFF
    var a_high := (_u32(a) >> 16) & 0xFFFF
    var b_low := _u32(b) & 0xFFFF
    var b_high := (_u32(b) >> 16) & 0xFFFF
    return _signed32(a_low * b_low + ((a_high * b_low + a_low * b_high) << 16))

static func _u32(value: int) -> int:
    return value & 0xFFFFFFFF

static func _signed32(value: int) -> int:
    var unsigned := _u32(value)
    return unsigned - 0x100000000 if unsigned >= 0x80000000 else unsigned
