# Material & Resources Allocation Benchmark in Crystal
# Measures instantiating 10,000 StandardMaterial3D instances, setting properties, duplicating, and cleaning up

require "../../src/lapis"

count = (ARGV[0]? || "10000").to_i

start_time = Time.instant
materials = Array(Godot::StandardMaterial3D).new(count)

count.times do
  mat = Godot::StandardMaterial3D.new
  mat.albedo_color = Godot::Color.new(0.2, 0.5, 0.8, 1.0)
  mat.roughness = 0.35_f32
  mat.metallic = 0.75_f32
  mat.emission_enabled = true
  mat.emission = Godot::Color.new(1.0, 0.9, 0.1, 1.0)
  dup = mat.duplicate
  materials << mat
end

elapsed = (Time.instant - start_time).total_milliseconds
puts "MaterialResources #{count} operations: #{elapsed.round(2)} ms"
puts "ELAPSED_MS: #{elapsed.round(2)}"
materials.clear
