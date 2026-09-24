extends SceneTree

# Scene Tree Traversal Benchmark in GDScript
# Builds 20,000 branched Node instances and traverses the hierarchy evaluating properties

func _init():
	var args = OS.get_cmdline_user_args()
	var target_nodes = 20000
	if args.size() > 0:
		target_nodes = int(args[0])

	var root = Node.new()
	root.name = "Root"

	var counter = [1]
	_build_branch(root, 9, 4, target_nodes, counter)

	var start_time = Time.get_ticks_usec()
	var total_len = _traverse_dfs(root)
	var elapsed = (Time.get_ticks_usec() - start_time) / 1000.0

	print("TreeTraversal %d nodes: %.2f ms (sum=%d)" % [counter[0], elapsed, total_len])
	print("ELAPSED_MS: %.2f" % elapsed)
	root.free()
	quit(0)

func _build_branch(parent: Node, depth: int, branch_factor: int, target: int, counter: Array):
	if depth <= 0 or counter[0] >= target:
		return
	for b in range(branch_factor):
		if counter[0] >= target:
			break
		var child = Node.new()
		child.name = "N_%d_%d" % [depth, b]
		parent.add_child(child)
		counter[0] += 1
		_build_branch(child, depth - 1, branch_factor, target, counter)

func _traverse_dfs(node: Node) -> int:
	var s: int = node.name.length()
	for i in range(node.get_child_count()):
		var child = node.get_child(i)
		s += _traverse_dfs(child)
	return s
