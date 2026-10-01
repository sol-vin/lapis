# =============================================================================
# VisualShader Node Graph Construction Benchmark (Crystal)
# =============================================================================
# Measures procedurally constructing 100 VisualShader nodes, configuring
# constants, and connecting node ports.

require "../../src/lapis"

count = (ARGV[0]? || "200").to_i

start_time = Time.instant
total_nodes = 0

count.times do
  vs = Godot::VisualShader.new
  vs.set_mode(Godot::Shader::Mode::ModeCanvasItem)

  # Add and connect a chain of color and math nodes
  color_node = Godot::VisualShaderNodeColorConstant.new
  color_node.constant = Godot::Color.new(0.8_f32, 0.4_f32, 0.2_f32, 1.0_f32)
  vs.add_node(Godot::VisualShader::Type::TypeFragment, color_node, Godot::Vector2.new(100.0_f32, 100.0_f32), 2_i64)

  vec_op = Godot::VisualShaderNodeVectorOp.new
  vs.add_node(Godot::VisualShader::Type::TypeFragment, vec_op, Godot::Vector2.new(250.0_f32, 100.0_f32), 3_i64)

  vs.connect_nodes(Godot::VisualShader::Type::TypeFragment, 2_i64, 0_i64, 3_i64, 0_i64)
  vs.connect_nodes(Godot::VisualShader::Type::TypeFragment, 3_i64, 0_i64, 0_i64, 0_i64)

  total_nodes += 3
end

elapsed = (Time.instant - start_time).total_milliseconds
rate = elapsed > 0 ? (total_nodes.to_f64 / (elapsed / 1000.0)).round(1) : 0.0

puts "VisualShader #{count} graphs (#{total_nodes} nodes): #{elapsed.round(2)} ms (#{rate} nodes/sec)"
puts "METRIC: vs_nodes_per_sec=#{rate}"
puts "ELAPSED_MS: #{elapsed.round(2)}"
