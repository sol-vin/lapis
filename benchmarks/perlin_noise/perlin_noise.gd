extends SceneTree

# Perlin Noise Benchmark in GDScript
# Evaluates FastNoiseLite 2D Perlin noise across 500x500 grid (250,000 samples)

func _init():
	var args = OS.get_cmdline_user_args()
	var grid_size = 500
	if args.size() > 0:
		grid_size = int(args[0])

	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = 1337
	noise.frequency = 0.02
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5

	var start_time = Time.get_ticks_usec()
	var total: float = 0.0

	for y in range(grid_size):
		var y_f = float(y)
		for x in range(grid_size):
			total += noise.get_noise_2d(float(x), y_f)

	var elapsed = (Time.get_ticks_usec() - start_time) / 1000.0
	print("PerlinNoise %d samples: %.2f ms (sum=%.4f)" % [grid_size * grid_size, elapsed, total])
	print("ELAPSED_MS: %.2f" % elapsed)
	quit(0)
