extends SceneTree

# Binary Trees Benchmark (GC pressure and recursive tree allocation in GDScript)

class TreeNode:
	var left: TreeNode = null
	var right: TreeNode = null
	var item: int = 0

	func _init(p_item: int, p_left: TreeNode = null, p_right: TreeNode = null):
		item = p_item
		left = p_left
		right = p_right

	static func create_tree(p_item: int, depth: int) -> TreeNode:
		if depth > 0:
			return TreeNode.new(
				p_item,
				TreeNode.create_tree(2 * p_item - 1, depth - 1),
				TreeNode.create_tree(2 * p_item, depth - 1)
			)
		else:
			return TreeNode.new(p_item)

	func check() -> int:
		var res = item
		if left != null:
			res += left.check()
		if right != null:
			res -= right.check()
		return res

func _init():
	var args = OS.get_cmdline_user_args()
	var n = 12
	if args.size() > 0:
		n = int(args[0])

	var min_depth = 4
	var max_depth = max(min_depth + 2, n)
	var stretch_depth = max_depth + 1

	var start_time = Time.get_ticks_usec()

	var stretch_check = TreeNode.create_tree(0, stretch_depth).check()
	print("stretch tree of depth %d\t check: %d" % [stretch_depth, stretch_check])

	var long_lived_tree = TreeNode.create_tree(0, max_depth)

	var depth = min_depth
	var total_check = 0
	while depth <= max_depth:
		var iterations = 1 << (max_depth - depth + min_depth)
		var check = 0
		for i in range(1, iterations + 1):
			check += TreeNode.create_tree(i, depth).check()
			check += TreeNode.create_tree(-i, depth).check()
		print("%d\t trees of depth %d\t check: %d" % [iterations * 2, depth, check])
		total_check += check
		depth += 2

	var long_lived_check = long_lived_tree.check()
	print("long lived tree of depth %d\t check: %d" % [max_depth, long_lived_check])
	var total_checksum = stretch_check + total_check + long_lived_check
	print("checksum: %d" % total_checksum)
	print("RESULT: %d" % total_checksum)

	var elapsed_ms = (Time.get_ticks_usec() - start_time) / 1000.0
	print("ELAPSED_MS: %.2f" % elapsed_ms)

	var dir = DirAccess.open("res://")
	if dir:
		dir.make_dir_recursive("benchmarks/results")
		var file = FileAccess.open("res://benchmarks/results/binarytrees_gdscript_timing.json", FileAccess.WRITE)
		if file:
			var json_str = '{\n  "benchmark": "binarytrees",\n  "language": "gdscript",\n  "elapsed_ms": %.2f,\n  "result": "%d"\n}\n' % [elapsed_ms, total_checksum]
			file.store_string(json_str)
			file.close()

	quit(0)
