extends SceneTree

# Dictionary Operations Benchmark in GDScript
# 50,000 key-value insertions and random access lookups

func _init():
	var args = OS.get_cmdline_user_args()
	var count = 50000
	if args.size() > 0:
		count = int(args[0])

	var start_time = Time.get_ticks_usec()
	var dict = {}

	for i in range(count):
		var key = "entity_key_%d" % i
		dict[key] = i * 3

	var hits: int = 0
	for i in range(count):
		var lookup_key = "entity_key_%d" % ((i * 7) % count)
		if dict.has(lookup_key):
			hits += 1

	var elapsed = (Time.get_ticks_usec() - start_time) / 1000.0
	print("DictionaryOps %d operations: %.2f ms (hits=%d)" % [count, elapsed, hits])
	print("ELAPSED_MS: %.2f" % elapsed)
	quit(0)
