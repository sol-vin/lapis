extends SceneTree

# Node Groups Benchmark in GDScript
# Manages 20,000 nodes categorized into 10 groups, executing group assignment and membership queries

func _init():
	var args = OS.get_cmdline_user_args()
	var count = 20000
	if args.size() > 0:
		count = int(args[0])

	var root = Node.new()
	var nodes = []
	nodes.resize(count)

	var groups = []
	for g in range(10):
		groups.append("group_%d" % g)

	for i in range(count):
		var n = Node.new()
		n.name = "Entity_%d" % i
		root.add_child(n)
		nodes[i] = n

	var start_time = Time.get_ticks_usec()

	for i in range(count):
		var grp = groups[i % 10]
		nodes[i].add_to_group(grp)

	var membership_hits: int = 0
	for i in range(count):
		if nodes[i].is_in_group("group_3"):
			membership_hits += 1

	var elapsed = (Time.get_ticks_usec() - start_time) / 1000.0
	print("NodeGroups %d nodes (10 groups): %.2f ms (hits=%d)" % [count, elapsed, membership_hits])
	print("ELAPSED_MS: %.2f" % elapsed)
	root.free()
	quit(0)
