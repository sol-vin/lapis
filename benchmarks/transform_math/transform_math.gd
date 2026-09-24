extends SceneTree

# Transform3D & Spatial Vector Math Benchmark in GDScript

func _init():
	var args = OS.get_cmdline_user_args()
	var count = 200000
	if args.size() > 0:
		count = int(args[0])

	var start_time = Time.get_ticks_usec()
	var t = Transform3D.IDENTITY
	var v = Vector3(1.0, 2.0, 3.0)
	var axis = Vector3(0.0, 1.0, 0.0)
	var sum: float = 0.0

	for i in range(count):
		t = t.translated(v * 0.001)
		t = t.rotated(axis, 0.005)
		var proj = t * v
		sum += proj.x + proj.y + proj.z

	var elapsed = (Time.get_ticks_usec() - start_time) / 1000.0
	print("Transform3D %d operations: sum=%.4f" % [count, sum])
	print("ELAPSED_MS: %.2f" % elapsed)
	quit(0)
