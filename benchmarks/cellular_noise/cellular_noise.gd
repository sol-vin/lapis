extends SceneTree

# Cellular Voronoi Noise Benchmark in GDScript
# Evaluates FastNoiseLite Cellular (Voronoi) noise across 500x500 grid (250,000 samples)

func _init():
	var args = OS.get_cmdline_user_args()
	var grid_size = 500
	if args.size() > 0:
		grid_size = int(args[0])

	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.seed = 9999
	noise.frequency = 0.03
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	noise.cellular_jitter = 0.45

	var start_time = Time.get_ticks_usec()
	var total: float = 0.0

	for y in range(grid_size):
		var y_f = float(y)
		for x in range(grid_size):
			total += noise.get_noise_2d(float(x), y_f)

	var elapsed = (Time.get_ticks_usec() - start_time) / 1000.0
	print("CellularNoise %d samples: %.2f ms (sum=%.4f)" % [grid_size * grid_size, elapsed, total])
	print("ELAPSED_MS: %.2f" % elapsed)
	quit(0)
