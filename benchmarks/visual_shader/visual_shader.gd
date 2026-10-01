extends SceneTree

# =============================================================================
# VisualShader Node Graph Construction Benchmark (GDScript)
# =============================================================================
# Measures procedurally constructing 100 VisualShader nodes, configuring
# constants, and connecting node ports.

func _init():
	var args = OS.get_cmdline_user_args()
	var count = 200
	if args.size() > 0:
		count = int(args[0])

	var start_time = Time.get_ticks_usec()
	var total_nodes = 0

	for i in range(count):
		var vs = VisualShader.new()
		vs.set_mode(Shader.MODE_CANVAS_ITEM)

		var color_node = VisualShaderNodeColorConstant.new()
		color_node.constant = Color(0.8, 0.4, 0.2, 1.0)
		vs.add_node(VisualShader.TYPE_FRAGMENT, color_node, Vector2(100.0, 100.0), 2)

		var vec_op = VisualShaderNodeVectorOp.new()
		vs.add_node(VisualShader.TYPE_FRAGMENT, vec_op, Vector2(250.0, 100.0), 3)

		vs.connect_nodes(VisualShader.TYPE_FRAGMENT, 2, 0, 3, 0)
		vs.connect_nodes(VisualShader.TYPE_FRAGMENT, 3, 0, 0, 0)

		total_nodes += 3

	var elapsed = (Time.get_ticks_usec() - start_time) / 1000.0
	var rate = (float(total_nodes) / (elapsed / 1000.0)) if elapsed > 0 else 0.0

	print("VisualShader %d graphs (%d nodes): %.2f ms (%.1f nodes/sec)" % [count, total_nodes, elapsed, rate])
	print("METRIC: vs_nodes_per_sec=%.1f" % rate)
	print("ELAPSED_MS: %.2f" % elapsed)
	quit(0)
