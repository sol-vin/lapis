extends SceneTree

# Node Lifecycle Benchmark in GDScript
# Measures instantiating 20,000 Node2D instances, mutating properties, mounting, removing, and freeing

func _init():
	var args = OS.get_cmdline_user_args()
	var count = 20000
	if args.size() > 0:
		count = int(args[0])

	var root = Node2D.new()
	var start_time = Time.get_ticks_usec()

	for i in range(count):
		var child = Node2D.new()
		child.position = Vector2(i, i * 2)
		child.rotation = 0.5
		child.scale = Vector2(1.5, 1.5)
		child.visible = true
		root.add_child(child)
		root.remove_child(child)
		child.free()

	var elapsed = (Time.get_ticks_usec() - start_time) / 1000.0
	print("NodeLifecycle %d operations: %.2f ms" % [count, elapsed])
	print("ELAPSED_MS: %.2f" % elapsed)
	root.free()
	quit(0)
