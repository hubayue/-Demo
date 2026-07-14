extends SceneTree

const Mulberry32 = preload("res://src/core/mulberry32.gd")

const STREAMS := [
	{
		"seed": -871681291,
		"checkpoints": {
			0: 0.4266689158976078,
			1: 0.3107865620404482,
			2: 0.8306204262189567,
			3: 0.8924713893793523,
			31: 0.34627960645593703,
			63: 0.6531420261599123,
			127: 0.3553830091841519,
			255: 0.7219533130992204,
		},
	},
	{
		"seed": 1702989505,
		"checkpoints": {
			0: 0.17205523746088147,
			1: 0.6768190739676356,
			2: 0.5062527391128242,
			3: 0.41017818450927734,
			31: 0.28922653989866376,
			63: 0.8589908718131483,
			127: 0.2785888300277293,
			255: 0.26112886145710945,
		},
	},
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _expect(Mulberry32.imul(2948, 2654435761) ^ 987654321 == -871681291, "primary week seed must match JavaScript"):
		return
	if not _expect(Mulberry32.imul(2948, 1597334677) ^ 123456789 == 1702989505, "secondary week seed must match JavaScript"):
		return
	for stream in STREAMS:
		var rng = Mulberry32.new(stream.seed)
		for index in 256:
			var actual: float = rng.next_float()
			if not stream.checkpoints.has(index):
				continue
			var expected: float = stream.checkpoints[index]
			if not _expect(is_equal_approx(actual, expected), "seed %d value %d mismatch: %.12f != %.12f" % [stream.seed, index, actual, expected]):
				return
	print("Godot JavaScript-compatible Mulberry32: PASS")
	quit(0)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
