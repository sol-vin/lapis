# AStar2D Pathfinding Benchmark in Crystal
# Builds 100x100 grid (10,000 points) and runs 500 path queries

require "../../src/lapis"

grid_dim = (ARGV[0]? || "100").to_i
queries = (ARGV[1]? || "500").to_i

astar = Godot::AStar2D.new

start_time = Time.instant

# Register points
grid_dim.times do |y|
  y_f = y.to_f32
  grid_dim.times do |x|
    id = (y * grid_dim + x).to_i64
    astar.add_point(id, Godot::Vector2.new(x.to_f32, y_f), 1.0_f64)
    if x > 0
      astar.connect_points(id, id - 1_i64, true)
    end
    if y > 0
      astar.connect_points(id, id - grid_dim.to_i64, true)
    end
  end
end

total_steps = 0_i64
max_id = (grid_dim * grid_dim - 1).to_i64

queries.times do |q|
  from_id = (q.to_i64 * 17_i64) % (max_id + 1_i64)
  to_id = ((max_id - q.to_i64 * 31_i64) % (max_id + 1_i64)).abs
  path = astar.get_id_path(from_id, to_id)
  total_steps += 1_i64 unless path.null?
end

elapsed = (Time.instant - start_time).total_milliseconds
puts "AStar2D #{grid_dim}x#{grid_dim} (#{queries} queries): #{elapsed.round(2)} ms"
puts "ELAPSED_MS: #{elapsed.round(2)}"
