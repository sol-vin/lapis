# =============================================================================
# Addon Custom Benchmark Example (Crystal)
# =============================================================================

require "lapis"

count = (ARGV[0]? || "50000").to_i

start_time = Time.instant
total = 0.0_f64
count.times do |i|
  # Example addon computation: transform hashing & vector projection
  v = Godot::Vector3.new(i.to_f32, (i * 2).to_f32, (i * 3).to_f32)
  total += v.length.to_f64
end
elapsed_ms = (Time.instant - start_time).total_milliseconds

puts "AddonVectorBenchmark #{count} iterations: #{total.round(2)}"
puts "ELAPSED_MS: #{elapsed_ms.round(2)}"
