extends SceneTree

# =============================================================================
# Shader Compilation Throughput Benchmark (GDScript)
# =============================================================================
# Measures creating Shaders, setting shader code for CanvasItem and Spatial
# stages across 1,000 permutations, and binding to ShaderMaterial.

func _init():
	var args = OS.get_cmdline_user_args()
	var count = 1000
	if args.size() > 0:
		count = int(args[0])

	var start_time = Time.get_ticks_usec()
	var materials = []

	for i in range(count):
		var shader = Shader.new()
		var stage_type = "canvas_item" if (i % 2 == 0) else "spatial"
		var speed = 1.0 + float(i % 50) * 0.1
		var code = """
shader_type %s;
uniform float u_speed = %f;
void fragment() {
    COLOR = vec4(0.2, 0.5, 0.8, 1.0);
}
""" % [stage_type, speed]
		shader.code = code

		var mat = ShaderMaterial.new()
		mat.shader = shader
		materials.append(mat)

	var elapsed = (Time.get_ticks_usec() - start_time) / 1000.0
	var throughput = (float(count) / (elapsed / 1000.0)) if elapsed > 0 else 0.0

	print("ShaderCompilation %d shaders: %.2f ms (%.1f shaders/sec)" % [count, elapsed, throughput])
	print("METRIC: shaders_per_sec=%.1f" % throughput)
	print("ELAPSED_MS: %.2f" % elapsed)
	materials.clear()
	quit(0)
