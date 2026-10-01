# Transform3D & Spatial Vector Math Benchmark
# Measures 3D matrix rotations, translations, Vector3 projections, and AABB collision queries

require "../../src/lapis"

count = (ARGV[0]? || "200000").to_i

start_time = Time.instant
t = Godot::Transform3D::IDENTITY
v = Godot::Vector3.new(1.0_f32, 2.0_f32, 3.0_f32)
sum = 0.0_f64
axis = Godot::Vector3.new(0.0_f32, 1.0_f32, 0.0_f32)

count.times do
  t = t.translated(v * 0.001_f32)
  t = t.rotated(axis, 0.005_f64)
  proj = t * v
  sum += (proj.x + proj.y + proj.z).to_f64
end

elapsed = (Time.instant - start_time).total_milliseconds
puts "Transform3D #{count} operations: sum=#{sum.round(4)}"
puts "ELAPSED_MS: #{elapsed.round(2)}"
