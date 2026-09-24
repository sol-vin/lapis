extends SceneTree

# 2D Vector Math Benchmark in GDScript
# Measures Vector2 lerp, dot, distance, and normalization across 500,000 ops

func _init():
	var args = OS.get_cmdline_user_args()
	var count = 500000
	if args.size() > 0:
		count = int(args[0])

	var start_time = Time.get_ticks_usec()
	var v1 = Vector2(10.5, 20.25)
	var v2 = Vector2(-5.0, 12.0)
	var sum: float = 0.0

	for i in range(count):
		var weight = float(i % 100) * 0.01
		var lerped = v1.lerp(v2, weight)
		var d = v1.dot(lerped)
		var dist = v1.distance_to(lerped)
		var norm = lerped.normalized()
		sum += d + dist + norm.x + norm.y
		v1 = lerped

	var elapsed = (Time.get_ticks_usec() - start_time) / 1000.0
	print("VectorMath2D %d operations: %.2f ms (sum=%.2f)" % [count, elapsed, sum])
	print("ELAPSED_MS: %.2f" % elapsed)
	quit(0)
