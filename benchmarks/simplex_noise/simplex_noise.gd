extends SceneTree

# Simplex Smooth 3D Noise Benchmark in GDScript
# Evaluates FastNoiseLite 3D Simplex Smooth noise across 100,000 samples

func _init():
	var args = OS.get_cmdline_user_args()
	var count = 100000
	if args.size() > 0:
		count = int(args[0])

	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = 4242
	noise.frequency = 0.015
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3

	var start_time = Time.get_ticks_usec()
	var total: float = 0.0

	for i in range(count):
		var coord = float(i) * 0.1
		total += noise.get_noise_3d(coord, coord * 0.5, coord * 0.25)

	var elapsed = (Time.get_ticks_usec() - start_time) / 1000.0
	print("SimplexNoise %d 3D samples: %.2f ms (sum=%.4f)" % [count, elapsed, total])
	print("ELAPSED_MS: %.2f" % elapsed)
	quit(0)
