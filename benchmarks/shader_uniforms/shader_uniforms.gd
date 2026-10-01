extends SceneTree

# =============================================================================
# Shader Uniform Parameters Benchmark (GDScript)
# =============================================================================
# Measures high-frequency uniform updates (50,000 updates of float, Vector2,
# Vector3, and Color) on ShaderMaterial via set_shader_parameter.

func _init():
	var args = OS.get_cmdline_user_args()
	var count = 50000
	if args.size() > 0:
		count = int(args[0])

	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float u_speed = 1.0;
uniform vec2 u_offset = vec2(0.0, 0.0);
uniform vec3 u_tint = vec3(1.0, 1.0, 1.0);
uniform vec4 u_color = vec4(1.0, 1.0, 1.0, 1.0);
void fragment() {
    COLOR = u_color;
}
"""

	var mat = ShaderMaterial.new()
	mat.shader = shader

	var start_time = Time.get_ticks_usec()

	for i in range(count):
		var idx = float(i)
		mat.set_shader_parameter("u_speed", 1.0 + idx * 0.01)
		mat.set_shader_parameter("u_offset", Vector2(idx, idx * 2.0))
		mat.set_shader_parameter("u_tint", Vector3(0.1, 0.5, 0.9))
		mat.set_shader_parameter("u_color", Color(0.2, 0.4, 0.8, 1.0))

	var elapsed = (Time.get_ticks_usec() - start_time) / 1000.0
	var total_updates = count * 4
	var rate = (float(total_updates) / (elapsed / 1000.0)) if elapsed > 0 else 0.0

	print("ShaderUniforms %d cycles (%d updates): %.2f ms (%.1f updates/sec)" % [count, total_updates, elapsed, rate])
	print("METRIC: uniform_updates_per_sec=%.1f" % rate)
	print("ELAPSED_MS: %.2f" % elapsed)
	quit(0)
