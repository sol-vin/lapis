extends SceneTree

# SurfaceTool Mesh Generation Benchmark in GDScript
# Procedurally generates 10,000 triangles with vertex attributes and commits to ArrayMesh

func _init():
	var args = OS.get_cmdline_user_args()
	var triangles = 10000
	if args.size() > 0:
		triangles = int(args[0])

	var start_time = Time.get_ticks_usec()

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(triangles):
		var base_x = float(i % 100)
		var base_z = float(i / 100)

		st.set_color(Color(0.2, 0.8, 0.3, 1.0))
		st.set_uv(Vector2(0.0, 0.0))
		st.set_normal(Vector3(0.0, 1.0, 0.0))
		st.add_vertex(Vector3(base_x, 0.0, base_z))

		st.set_color(Color(0.3, 0.7, 0.4, 1.0))
		st.set_uv(Vector2(1.0, 0.0))
		st.set_normal(Vector3(0.0, 1.0, 0.0))
		st.add_vertex(Vector3(base_x + 1.0, 0.0, base_z))

		st.set_color(Color(0.1, 0.9, 0.2, 1.0))
		st.set_uv(Vector2(0.0, 1.0))
		st.set_normal(Vector3(0.0, 1.0, 0.0))
		st.add_vertex(Vector3(base_x, 0.0, base_z + 1.0))

	var mesh = st.commit()
	var elapsed = (Time.get_ticks_usec() - start_time) / 1000.0
	print("SurfaceTool %d triangles: %.2f ms" % [triangles, elapsed])
	print("ELAPSED_MS: %.2f" % elapsed)
	quit(0)
