extends SceneTree

# Signals Connection & Emission Benchmark in GDScript
# Measures connecting a callable and emitting signals 50,000 times

func _init():
	var args = OS.get_cmdline_user_args()
	var count = 50000
	if args.size() > 0:
		count = int(args[0])

	var emitter = Node.new()
	var received = [0]
	emitter.renamed.connect(func(): received[0] += 1)

	var start_time = Time.get_ticks_usec()
	for i in range(count):
		emitter.renamed.emit()

	var elapsed = (Time.get_ticks_usec() - start_time) / 1000.0
	print("Signals %d emissions: %d received (%.2f ms)" % [count, received[0], elapsed])
	print("ELAPSED_MS: %.2f" % elapsed)
	emitter.free()
	quit(0)
