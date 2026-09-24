# Transform Hierarchy Benchmark in Crystal
# Evaluates 15,000 Node3D hierarchical transformations and global position resolution

require "../../src/lapis"

count = (ARGV[0]? || "15000").to_i

root = Godot::Node3D.new
current = root
nodes = Array(Godot::Node3D).new(count)

count.times do |i|
  node = Godot::Node3D.new
  node.position = Godot::Vector3.new(1.0_f32, 0.5_f32, 0.2_f32)
  current.add_child(node)
  nodes << node
  if i % 50 == 0
    current = node
  end
end

start_time = Time.instant

sum_x = 0.0_f32
nodes.each_with_index do |node, idx|
  node.rotation_degrees = Godot::Vector3.new(idx.to_f32 * 0.1_f32, 45.0_f32, 0.0_f32)
  g_pos = node.global_position
  sum_x += g_pos.x
end

elapsed = (Time.instant - start_time).total_milliseconds
puts "TransformHierarchy #{count} nodes: #{elapsed.round(2)} ms (sum=#{sum_x.round(2)})"
puts "ELAPSED_MS: #{elapsed.round(2)}"

root.free
