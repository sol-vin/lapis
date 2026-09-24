# SurfaceTool Mesh Generation Benchmark in Crystal
# Procedurally generates 10,000 triangles with vertex attributes and commits to ArrayMesh

require "../../src/lapis"

triangles = (ARGV[0]? || "10000").to_i

start_time = Time.instant

st = Godot::SurfaceTool.new
st.begin(Godot::Mesh::PrimitiveType::PrimitiveTriangles)

triangles.times do |i|
  base_x = (i % 100).to_f32
  base_z = (i // 100).to_f32

  st.set_color(Godot::Color.new(0.2_f32, 0.8_f32, 0.3_f32, 1.0_f32))
  st.set_uv(Godot::Vector2.new(0.0_f32, 0.0_f32))
  st.set_normal(Godot::Vector3.new(0.0_f32, 1.0_f32, 0.0_f32))
  st.add_vertex(Godot::Vector3.new(base_x, 0.0_f32, base_z))

  st.set_color(Godot::Color.new(0.3_f32, 0.7_f32, 0.4_f32, 1.0_f32))
  st.set_uv(Godot::Vector2.new(1.0_f32, 0.0_f32))
  st.set_normal(Godot::Vector3.new(0.0_f32, 1.0_f32, 0.0_f32))
  st.add_vertex(Godot::Vector3.new(base_x + 1.0_f32, 0.0_f32, base_z))

  st.set_color(Godot::Color.new(0.1_f32, 0.9_f32, 0.2_f32, 1.0_f32))
  st.set_uv(Godot::Vector2.new(0.0_f32, 1.0_f32))
  st.set_normal(Godot::Vector3.new(0.0_f32, 1.0_f32, 0.0_f32))
  st.add_vertex(Godot::Vector3.new(base_x, 0.0_f32, base_z + 1.0_f32))
end

mesh = st.commit
elapsed = (Time.instant - start_time).total_milliseconds
puts "SurfaceTool #{triangles} triangles: #{elapsed.round(2)} ms"
puts "ELAPSED_MS: #{elapsed.round(2)}"
