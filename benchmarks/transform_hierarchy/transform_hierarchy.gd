extends SceneTree

# Transform Hierarchy Benchmark in GDScript
# Evaluates 15,000 Node3D hierarchical transformations and global position resolution

func _init():
	var args = OS.get_cmdline_user_args()
	var count = 15000
	if args.size() > 0:
		count = int(args[0])

	var root = Node3D.new()
	var current = root
	var nodes = []
	nodes.resize(count)

	for i in range(count):
		var node = Node3D.new()
		node.position = Vector3(1.0, 0.5, 0.2)
		current.add_child(node)
		nodes[i] = node
		if i % 50 == 0:
			current = node

	var start_time = Time.get_ticks_usec()
	var sum_x: float = 0.0

	for i in range(count):
		var node = nodes[i]
		node.rotation_degrees = Vector3(float(i) * 0.1, 45.0, 0.0)
		var g_pos = node.global_position
		sum_x += g_pos.x

	var elapsed = (Time.get_ticks_usec() - start_time) / 1000.0
	print("TransformHierarchy %d nodes: %.2f ms (sum=%.2f)" % [count, elapsed, sum_x])
	print("ELAPSED_MS: %.2f" % elapsed)
	root.free()
	quit(0)
