extends SceneTree

# Mandelbrot 2D Fractal Rasterization Benchmark in GDScript

func _init():
	var args = OS.get_cmdline_user_args()
	var size = 500
	if args.size() > 0:
		size = int(args[0])

	var w = size
	var h = size
	var iter = 50
	var limit_sq = 4.0
	var checksum: int = 0

	var start_time = Time.get_ticks_usec()
	for y in range(h):
		for x in range(w):
			var zr = 0.0
			var zi = 0.0
			var cr = 2.0 * x / w - 1.5
			var ci = 2.0 * y / h - 1.0

			var i = 0
			var tr = 0.0
			var ti = 0.0
			while i < iter and (tr + ti <= limit_sq):
				zi = 2.0 * zr * zi + ci
				zr = tr - ti + cr
				tr = zr * zr
				ti = zi * zi
				i += 1

			if tr + ti <= limit_sq:
				checksum += 1

	var elapsed_ms = (Time.get_ticks_usec() - start_time) / 1000.0
	print("Mandelbrot %dx%d points inside: %d" % [w, h, checksum])
	print("RESULT: %d" % checksum)
	print("ELAPSED_MS: %.2f" % elapsed_ms)

	var dir = DirAccess.open("res://")
	if dir:
		dir.make_dir_recursive("benchmarks/results")
		var file = FileAccess.open("res://benchmarks/results/mandelbrot_gdscript_timing.json", FileAccess.WRITE)
		if file:
			var json_str = '{\n  "benchmark": "mandelbrot",\n  "language": "gdscript",\n  "elapsed_ms": %.2f,\n  "result": "%d"\n}\n' % [elapsed_ms, checksum]
			file.store_string(json_str)
			file.close()

	quit(0)
