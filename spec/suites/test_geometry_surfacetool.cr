# =============================================================================
# LibGodot Test Suite: Procedural Geometry, SurfaceTool & ImmediateMesh
# =============================================================================

include Lapis::Test

test_suite "Geometry" do
  test "SurfaceTool procedural triangle construction, normal generation and ArrayMesh commit" do
  st = Godot.create(Godot::SurfaceTool)

  # Begin building surface using Godot::Mesh::PrimitiveType::PrimitiveTriangles directly
  st.begin(Godot::Mesh::PrimitiveType::PrimitiveTriangles)

  # Verify SurfaceTool tracked the correct primitive mode
  assert_eq st.get_primitive_type, Godot::Mesh::PrimitiveType::PrimitiveTriangles.value

  # Vertex 0
  st.set_color(Godot::Color.new(1.0, 0.0, 0.0, 1.0))
  st.set_uv(Godot::Vector2.new(0.0, 0.0))
  st.set_normal(Godot::Vector3.new(0.0, 1.0, 0.0))
  st.add_vertex(Godot::Vector3.new(-1.0, 0.0, -1.0))

  # Vertex 1
  st.set_color(Godot::Color.new(0.0, 1.0, 0.0, 1.0))
  st.set_uv(Godot::Vector2.new(1.0, 0.0))
  st.set_normal(Godot::Vector3.new(0.0, 1.0, 0.0))
  st.add_vertex(Godot::Vector3.new(1.0, 0.0, -1.0))

  # Vertex 2
  st.set_color(Godot::Color.new(0.0, 0.0, 1.0, 1.0))
  st.set_uv(Godot::Vector2.new(0.5, 1.0))
  st.set_normal(Godot::Vector3.new(0.0, 1.0, 0.0))
  st.add_vertex(Godot::Vector3.new(0.0, 0.0, 1.0))

  # Indices
  st.add_index(0_i64)
  st.add_index(1_i64)
  st.add_index(2_i64)

  # Generate tangents and normal attributes
  st.generate_tangents

  # Commit to ArrayMesh
  # flags: 0_i64 specifies default uncompressed format (no mesh compression flags)
  compression_flags = 0_i64 # Mesh::ARRAY_COMPRESS_FLAGS_BASE / default uncompressed
  target_mesh = Godot.create(Godot::ArrayMesh)
  mesh = st.commit(target_mesh, compression_flags)

  assert_not_nil mesh
  assert_false mesh.pointer.null?
  assert_eq mesh.get_surface_count, 1_i64
  assert_eq mesh.surface_get_primitive_type(0_i64), Godot::Mesh::PrimitiveType::PrimitiveTriangles.value

  # Test SurfaceTool clear state
  st.clear
end

  test "ArrayMesh surface naming, blend shapes and lifecycle management" do
  st = Godot.create(Godot::SurfaceTool)
  st.begin(Godot::Mesh::PrimitiveType::PrimitiveTriangles)

  # Quad (2 triangles, 4 vertices)
  st.add_vertex(Godot::Vector3.new(-1.0, 0.0, -1.0))
  st.add_vertex(Godot::Vector3.new(1.0, 0.0, -1.0))
  st.add_vertex(Godot::Vector3.new(1.0, 0.0, 1.0))
  st.add_vertex(Godot::Vector3.new(-1.0, 0.0, 1.0))

  st.add_index(0_i64)
  st.add_index(1_i64)
  st.add_index(2_i64)
  st.add_index(0_i64)
  st.add_index(2_i64)
  st.add_index(3_i64)

  # flip: false = preserve existing face winding direction
  st.generate_normals(false)

  # 0_i64 = default uncompressed flags
  target_mesh = Godot.create(Godot::ArrayMesh)
  mesh = st.commit(target_mesh, 0_i64)
  assert_eq mesh.get_surface_count, 1_i64

  # Surface naming
  mesh.surface_set_name(0_i64, "ProceduralQuadSurface")

  # Verify ArrayType enum constants are correctly mapped in ClassDB
  assert_eq Godot::Mesh::ArrayType::ArrayVertex.value, 0_i64
  assert_eq Godot::Mesh::ArrayType::ArrayNormal.value, 1_i64
  assert_eq Godot::Mesh::ArrayType::ArrayColor.value, 3_i64
  assert_eq Godot::Mesh::ArrayType::ArrayIndex.value, 12_i64
  assert_eq Godot::Mesh::ArrayType::ArrayMax.value, 13_i64

  # Blend shape tracking on ArrayMesh (blend shapes must be defined before surfaces in Godot)
  blend_mesh = Godot.create(Godot::ArrayMesh)
  assert_eq blend_mesh.get_blend_shape_count, 0_i64
  blend_mesh.add_blend_shape("MouthOpen")
  assert_eq blend_mesh.get_blend_shape_count, 1_i64
  blend_mesh.clear_blend_shapes
  assert_eq blend_mesh.get_blend_shape_count, 0_i64

  # Clear surfaces from ArrayMesh
  mesh.clear_surfaces
  assert_eq mesh.get_surface_count, 0_i64

  st.clear
end

  test "ImmediateMesh dynamic surface creation, vertex emission and surface clearing" do
  imm = Godot.create(Godot::ImmediateMesh)
  assert_eq imm.get_surface_count, 0_i64

  # Begin drawing triangle using PrimitiveTriangles enum directly
  imm.surface_begin(Godot::Mesh::PrimitiveType::PrimitiveTriangles)
  imm.surface_set_color(Godot::Color.new(1.0, 1.0, 0.0, 1.0))
  imm.surface_add_vertex(Godot::Vector3.new(0.0, 0.0, 0.0))
  imm.surface_add_vertex(Godot::Vector3.new(2.0, 0.0, 0.0))
  imm.surface_add_vertex(Godot::Vector3.new(1.0, 2.0, 0.0))
  imm.surface_end

  assert_eq imm.get_surface_count, 1_i64

  # Clear surfaces
  imm.clear_surfaces
  assert_eq imm.get_surface_count, 0_i64
end

end
