# Cellular Voronoi Noise Benchmark in Crystal
# Evaluates FastNoiseLite Cellular (Voronoi) noise across 500x500 grid (250,000 samples)

require "../../src/lapis"

grid_size = (ARGV[0]? || "500").to_i

noise = Godot::FastNoiseLite.new
noise.set_noise_type(Godot::FastNoiseLite::NoiseType::TypeCellular)
noise.set_seed(9999_i64)
noise.set_frequency(0.03_f64)
noise.set_cellular_distance_function(Godot::FastNoiseLite::CellularDistanceFunction::DistanceEuclidean)
noise.set_cellular_return_type(Godot::FastNoiseLite::CellularReturnType::ReturnDistance)
noise.set_cellular_jitter(0.45_f64)

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
puts "CellularNoise #{grid_size * grid_size} samples: #{elapsed.round(2)} ms (sum=#{total.round(4)})"
puts "ELAPSED_MS: #{elapsed.round(2)}"
