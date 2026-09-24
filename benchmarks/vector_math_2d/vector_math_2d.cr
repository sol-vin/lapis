# 2D Vector Math Benchmark in Crystal
# Measures Vector2 lerp, dot, distance, and normalization across 500,000 ops

require "../../src/lapis"

count = (ARGV[0]? || "500000").to_i

start_time = Time.instant
v1 = Godot::Vector2.new(10.5_f32, 20.25_f32)
v2 = Godot::Vector2.new(-5.0_f32, 12.0_f32)
sum = 0.0_f64

count.times do |i|
  weight = (i % 100).to_f32 * 0.01_f32
  lerped = v1.lerp(v2, weight)
  dot = v1.dot(lerped)
  dist = v1.distance_to(lerped)
  norm = lerped.normalized
  sum += (dot + dist + norm.x + norm.y).to_f64
  v1 = lerped
end

elapsed = (Time.instant - start_time).total_milliseconds
puts "VectorMath2D #{count} operations: #{elapsed.round(2)} ms (sum=#{sum.round(2)})"
puts "ELAPSED_MS: #{elapsed.round(2)}"
