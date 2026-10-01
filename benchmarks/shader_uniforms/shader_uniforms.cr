# =============================================================================
# Shader Uniform Parameters Benchmark (Crystal)
# =============================================================================
# Measures high-frequency uniform updates (50,000 updates of float, Vector2,
# Vector3, and Color) on ShaderMaterial via set_shader_parameter.

require "../../src/lapis"

count = (ARGV[0]? || "50000").to_i

shader = Godot::Shader.new
shader.code = <<-GLSL
shader_type canvas_item;
uniform float u_speed = 1.0;
uniform vec2 u_offset = vec2(0.0, 0.0);
uniform vec3 u_tint = vec3(1.0, 1.0, 1.0);
uniform vec4 u_color = vec4(1.0, 1.0, 1.0, 1.0);
void fragment() {
    COLOR = u_color;
}
GLSL

mat = Godot::ShaderMaterial.new
mat.shader = shader

start_time = Time.instant

count.times do |i|
  idx = i.to_f64
  mat.call("set_shader_parameter", "u_speed", 1.0_f64 + idx * 0.01_f64)
  mat.call("set_shader_parameter", "u_offset", Godot::Vector2.new(idx.to_f32, (idx * 2.0_f64).to_f32))
  mat.call("set_shader_parameter", "u_tint", Godot::Vector3.new(0.1_f32, 0.5_f32, 0.9_f32))
  mat.call("set_shader_parameter", "u_color", Godot::Color.new(0.2_f32, 0.4_f32, 0.8_f32, 1.0_f32))
end

elapsed = (Time.instant - start_time).total_milliseconds
total_updates = count * 4
rate = elapsed > 0 ? (total_updates.to_f64 / (elapsed / 1000.0)).round(1) : 0.0

puts "ShaderUniforms #{count} cycles (#{total_updates} updates): #{elapsed.round(2)} ms (#{rate} updates/sec)"
puts "METRIC: uniform_updates_per_sec=#{rate}"
puts "ELAPSED_MS: #{elapsed.round(2)}"
