# =============================================================================
# Template Custom Benchmark Example (GDScript)
# =============================================================================
extends SceneTree

func _init() -> void:
	var count: int = 50000
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		count = int(args[0])

	var start_time: int = Time.get_ticks_usec()
	var total: float = 0.0
	for i in range(count):
		var distance: float = float(i % 100)
		var armor: float = float((i * 3) % 50)
		var raw_damage: float = 150.0
		var effective_damage: float = (raw_damage / (1.0 + armor * 0.05)) * exp(-distance * 0.02)
		total += effective_damage

	var elapsed_ms: float = float(Time.get_ticks_usec() - start_time) / 1000.0
	print("DamageCalculation %d iterations: %.2f" % [count, total])
	print("ELAPSED_MS: %.2f" % elapsed_ms)
	quit()
