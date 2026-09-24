extends SceneTree

# Image Processing Benchmark in GDScript
# 512x512 Image procedural pixel computation and mutation

func _init():
	var args = OS.get_cmdline_user_args()
	var dim = 512
	if args.size() > 0:
		dim = int(args[0])

	var img = Image.create(dim, dim, false, Image.FORMAT_RGBA8)
	var start_time = Time.get_ticks_usec()

	for y in range(dim):
		var y_norm = float(y) / float(dim)
		for x in range(dim):
			var x_norm = float(x) / float(dim)
			var r = pow(x_norm, 2.2)
			var g = pow(y_norm, 2.2)
			var b = pow((x_norm + y_norm) * 0.5, 2.2)
			img.set_pixel(x, y, Color(r, g, b, 1.0))

	var elapsed = (Time.get_ticks_usec() - start_time) / 1000.0
	print("ImageProcessing %dx%d (%d pixels): %.2f ms" % [dim, dim, dim * dim, elapsed])
	print("ELAPSED_MS: %.2f" % elapsed)
	quit(0)
