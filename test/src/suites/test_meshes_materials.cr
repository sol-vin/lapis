# =============================================================================
# LibGodot Test Suite: 3D Meshes, Geometry Primitives & Materials
# =============================================================================

include Lapis::Test

test_mesh "SphereMesh radius, height, and rings configuration" do
  sphere = Godot.create(Godot::SphereMesh)
  sphere.set_radius(2.5_f64)
  sphere.set_height(5.0_f64)
  sphere.set_radial_segments(32_i64)
  sphere.set_rings(16_i64)

  assert_approx_eq sphere.get_radius.to_f32, 2.5_f32
  assert_approx_eq sphere.get_height.to_f32, 5.0_f32
  assert_eq sphere.get_radial_segments, 32_i64
  assert_eq sphere.get_rings, 16_i64
  sphere.destroy
end

test_mesh "CylinderMesh radii and height" do
  cyl = Godot.create(Godot::CylinderMesh)
  cyl.set_top_radius(1.0_f64)
  cyl.set_bottom_radius(2.0_f64)
  cyl.set_height(4.0_f64)

  assert_approx_eq cyl.get_top_radius.to_f32, 1.0_f32
  assert_approx_eq cyl.get_bottom_radius.to_f32, 2.0_f32
  assert_approx_eq cyl.get_height.to_f32, 4.0_f32
  cyl.destroy
end

test_mesh "CapsuleMesh radius, height, and segments" do
  cap = Godot.create(Godot::CapsuleMesh)
  cap.set_radius(0.75_f64)
  cap.set_height(2.5_f64)
  assert_approx_eq cap.get_radius.to_f32, 0.75_f32
  assert_approx_eq cap.get_height.to_f32, 2.5_f32
  cap.destroy
end

test_mesh "PrismMesh, PlaneMesh, and QuadMesh sizing" do
  prism = Godot.create(Godot::PrismMesh)
  prism.set_size(Godot::Vector3.new(3.0, 4.0, 5.0))
  assert_approx_eq prism.get_size.y, 4.0_f32

  plane = Godot.create(Godot::PlaneMesh)
  plane.set_size(Godot::Vector2.new(20.0, 20.0))
  plane.set_subdivide_width(8_i64)
  assert_approx_eq plane.get_size.x, 20.0_f32
  assert_eq plane.get_subdivide_width, 8_i64

  quad = Godot.create(Godot::QuadMesh)
  quad.set_size(Godot::Vector2.new(6.0, 8.0))
  assert_approx_eq quad.get_size.y, 8.0_f32

  prism.destroy
  plane.destroy
  quad.destroy
end

test_mesh "TorusMesh ring radii definition" do
  torus = Godot.create(Godot::TorusMesh)
  torus.set_inner_radius(1.2_f64)
  torus.set_outer_radius(3.6_f64)
  assert_approx_eq torus.get_inner_radius.to_f32, 1.2_f32
  assert_approx_eq torus.get_outer_radius.to_f32, 3.6_f32
  torus.destroy
end

test_mesh "TextMesh text string and font size" do
  tm = Godot.create(Godot::TextMesh)
  tm.call("set_text", "3D Text in Engine")
  tm.set_font_size(48_i64)
  assert_eq tm.call_str("get_text"), "3D Text in Engine"
  assert_eq tm.get_font_size, 48_i64
  tm.destroy
end

test_mesh "StandardMaterial3D metallic, roughness, and emission" do
  mat = Godot.create(Godot::StandardMaterial3D)
  mat.set_metallic(0.85_f64)
  mat.set_roughness(0.15_f64)
  mat.set_emission(Godot::Color.new(0.0, 1.0, 0.5, 1.0))

  assert_approx_eq mat.get_metallic.to_f32, 0.85_f32
  assert_approx_eq mat.get_roughness.to_f32, 0.15_f32
  assert_approx_eq mat.get_emission.g, 1.0_f32

  mat.destroy
end

test_mesh "ORMMaterial3D and CanvasItemMaterial properties" do
  orm = Godot.create(Godot::ORMMaterial3D)
  orm.set_shading_mode(0_i64) # SHADING_MODE_UNSHADED
  assert_eq orm.get_shading_mode, 0_i64

  cim = Godot.create(Godot::CanvasItemMaterial)
  cim.set_blend_mode(1_i64) # BLEND_MODE_ADD
  assert_eq cim.get_blend_mode, 1_i64

  orm.destroy
  cim.destroy
end
