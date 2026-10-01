# Simplex Smooth 3D Noise Benchmark in Crystal
# Evaluates FastNoiseLite 3D Simplex Smooth noise across 100,000 samples

require "../../src/lapis"

count = (ARGV[0]? || "100000").to_i

noise = Godot::FastNoiseLite.new
noise.set_noise_type(Godot::FastNoiseLite::NoiseType::TypeSimplexSmooth)
noise.set_seed(4242_i64)
noise.set_frequency(0.015_f64)
noise.set_fractal_type(Godot::FastNoiseLite::FractalType::FractalFbm)
noise.set_fractal_octaves(3_i64)

start_time = Time.instant
total = 0.0_f64

count.times do |i|
  coord = i.to_f64 * 0.1_f64
  total += noise.get_noise_3d(coord, coord * 0.5_f64, coord * 0.25_f64)
end

elapsed = (Time.instant - start_time).total_milliseconds
puts "SimplexNoise #{count} 3D samples: #{elapsed.round(2)} ms (sum=#{total.round(4)})"
puts "ELAPSED_MS: #{elapsed.round(2)}"
