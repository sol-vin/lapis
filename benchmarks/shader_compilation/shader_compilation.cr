# =============================================================================
# Shader Compilation Throughput Benchmark (Crystal)
# =============================================================================
# Measures creating Shaders, setting shader code for CanvasItem and Spatial
# stages across 1,000 permutations, and binding to ShaderMaterial.

require "../../src/lapis"

count = (ARGV[0]? || "1000").to_i

start_time = Time.instant
materials = Array(Godot::ShaderMaterial).new(count)

count.times do |i|
  shader = Godot::Shader.new
  stage_type = (i % 2 == 0) ? "canvas_item" : "spatial"
  speed = (1.0 + (i % 50).to_f64 * 0.1).round(2)
  code = <<-GLSL
  shader_type #{stage_type};
  uniform float u_speed = #{speed};
  void fragment() {
      COLOR = vec4(0.2, 0.5, 0.8, 1.0);
  }
  GLSL
  shader.code = code

  mat = Godot::ShaderMaterial.new
  mat.shader = shader
  materials << mat
end

elapsed = (Time.instant - start_time).total_milliseconds
throughput = elapsed > 0 ? (count.to_f64 / (elapsed / 1000.0)).round(1) : 0.0

puts "ShaderCompilation #{count} shaders: #{elapsed.round(2)} ms (#{throughput} shaders/sec)"
puts "METRIC: shaders_per_sec=#{throughput}"
puts "ELAPSED_MS: #{elapsed.round(2)}"
materials.clear
