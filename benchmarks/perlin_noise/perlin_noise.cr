# Perlin Noise Benchmark in Crystal
# Evaluates FastNoiseLite 2D Perlin noise across 500x500 grid (250,000 samples)

require "../../src/lapis"

grid_size = (ARGV[0]? || "500").to_i

noise = Godot::FastNoiseLite.new
noise.set_noise_type(Godot::FastNoiseLite::NoiseType::TypePerlin)
noise.set_seed(1337_i64)
noise.set_frequency(0.02_f64)
noise.set_fractal_type(Godot::FastNoiseLite::FractalType::FractalFbm)
noise.set_fractal_octaves(4_i64)
noise.set_fractal_lacunarity(2.0_f64)
noise.set_fractal_gain(0.5_f64)

start_time = Time.instant
total = 0.0_f64

grid_size.times do |y|
  y_f = y.to_f64
  grid_size.times do |x|
    x_f = x.to_f64
    total += noise.get_noise_2d(x_f, y_f)
  end
end

elapsed = (Time.instant - start_time).total_milliseconds
puts "PerlinNoise #{grid_size * grid_size} samples: #{elapsed.round(2)} ms (sum=#{total.round(4)})"
puts "ELAPSED_MS: #{elapsed.round(2)}"
