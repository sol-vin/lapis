extends SceneTree

# AStar2D Pathfinding Benchmark in GDScript
# Builds 100x100 grid (10,000 points) and runs 500 path queries

func _init():
	var args = OS.get_cmdline_user_args()
	var grid_dim = 100
	var queries = 500
	if args.size() > 0:
		grid_dim = int(args[0])
	if args.size() > 1:
		queries = int(args[1])

	var astar = AStar2D.new()
	var start_time = Time.get_ticks_usec()

	for y in range(grid_dim):
		var y_f = float(y)
		for x in range(grid_dim):
			var id = y * grid_dim + x
			astar.add_point(id, Vector2(float(x), y_f), 1.0)
			if x > 0:
				astar.connect_points(id, id - 1, true)
			if y > 0:
				astar.connect_points(id, id - grid_dim, true)

	var total_steps: int = 0
	var max_id = grid_dim * grid_dim - 1

	for q in range(queries):
		var from_id = (q * 17) % (max_id + 1)
		var to_id = abs((max_id - q * 31) % (max_id + 1))
		var path = astar.get_id_path(from_id, to_id)
		if path.size() > 0:
			total_steps += 1

	var elapsed = (Time.get_ticks_usec() - start_time) / 1000.0
	print("AStar2D %dx%d (%d queries): %.2f ms" % [grid_dim, grid_dim, queries, elapsed])
	print("ELAPSED_MS: %.2f" % elapsed)
	quit(0)
