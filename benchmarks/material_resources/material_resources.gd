extends SceneTree

# Material & Resources Allocation Benchmark in GDScript
# Measures instantiating 10,000 StandardMaterial3D instances, setting properties, duplicating, and cleaning up

func _init():
	var args = OS.get_cmdline_user_args()
	var count = 10000
	if args.size() > 0:
		count = int(args[0])

	var start_time = Time.get_ticks_usec()
	var materials = []

	for i in range(count):
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.5, 0.8, 1.0)
		mat.roughness = 0.35
		mat.metallic = 0.75
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.9, 0.1, 1.0)
		var dup = mat.duplicate()
		materials.append(mat)

	var elapsed = (Time.get_ticks_usec() - start_time) / 1000.0
	print("MaterialResources %d operations: %.2f ms" % [count, elapsed])
	print("ELAPSED_MS: %.2f" % elapsed)
	materials.clear()
	quit(0)
