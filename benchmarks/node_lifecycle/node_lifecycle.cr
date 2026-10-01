# Node Lifecycle Benchmark in Crystal
# Measures instantiating 20,000 Node2D instances, mutating properties, mounting, removing, and freeing

require "../../src/lapis"

count = (ARGV[0]? || "20000").to_i

root = Godot::Node2D.new
start_time = Time.instant

count.times do |i|
  child = Godot::Node2D.new
  child.position = Godot::Vector2.new(i.to_f32, (i * 2).to_f32)
  child.rotation = 0.5_f32
  child.scale = Godot::Vector2.new(1.5_f32, 1.5_f32)
  child.visible = true
  root.add_child(child)
  root.remove_child(child)
  child.free
end

elapsed = (Time.instant - start_time).total_milliseconds
puts "NodeLifecycle #{count} operations: #{elapsed.round(2)} ms"
puts "ELAPSED_MS: #{elapsed.round(2)}"
root.free
