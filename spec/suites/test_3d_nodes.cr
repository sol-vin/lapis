# =============================================================================
# LibGodot Test Suite: 3D Nodes & Spatial Components
# =============================================================================

include Lapis::Test

test_suite "3D" do
  test "Camera3D projection, fov, clipping planes, and priority" do
  cam = Godot.create(Godot::Camera3D)
  assert_not_nil cam

  cam.set_fov(85.0_f64)
  assert_approx_eq cam.get_fov.to_f32, 85.0_f32

  cam.set_near(0.05_f64)
  assert_approx_eq cam.get_near.to_f32, 0.05_f32

  cam.set_far(2500.0_f64)
  assert_approx_eq cam.get_far.to_f32, 2500.0_f32

  cam.set_current(true)
  assert_true cam.is_current
  cam.clear_current(false)
  assert_false cam.is_current

  cam.destroy
end

  test "Marker3D spatial gizmo extents" do
  marker = Godot.create(Godot::Marker3D)
  marker.set_gizmo_extents(3.5_f64)
  assert_approx_eq marker.get_gizmo_extents.to_f32, 3.5_f32
  marker.destroy
end

  test "RayCast3D and ShapeCast3D 3D space intersection targeting" do
  ray = Godot.create(Godot::RayCast3D)
  ray.set_target_position(Godot::Vector3.new(0.0, -10.0, 0.0))
  assert_approx_eq ray.get_target_position.y, -10.0_f32

  ray.set_enabled(true)
  assert_true ray.is_enabled

  ray.set_collide_with_areas(true)
  assert_true ray.is_collide_with_areas_enabled

  sc = Godot.create(Godot::ShapeCast3D)
  sc.set_target_position(Godot::Vector3.new(0.0, 0.0, -5.0))
  assert_approx_eq sc.get_target_position.z, -5.0_f32
  sc.set_max_results(8_i64)
  assert_eq sc.get_max_results, 8_i64

  ray.destroy
  sc.destroy
end

  test "SpringArm3D third-person camera boom collision" do
  arm = Godot.create(Godot::SpringArm3D)
  arm.set_length(6.0_f64)
  assert_approx_eq arm.get_length.to_f32, 6.0_f32

  arm.set_margin(0.25_f64)
  assert_approx_eq arm.get_margin.to_f32, 0.25_f32
  arm.destroy
end

  test "Decal projector bounds and fade distances" do
  decal = Godot.create(Godot::Decal)
  decal.set_size(Godot::Vector3.new(4.0, 4.0, 4.0))
  assert_approx_eq decal.get_size.x, 4.0_f32

  decal.set_normal_fade(0.35_f64)
  assert_approx_eq decal.get_normal_fade.to_f32, 0.35_f32
  decal.destroy
end

  test "DirectionalLight3D sun properties and shadows" do
  sun = Godot.create(Godot::DirectionalLight3D)
  sun.set_param(Godot::Light3D::Param::ParamEnergy.to_i64, 2.5_f64)
  assert_approx_eq sun.get_param(Godot::Light3D::Param::ParamEnergy.to_i64).to_f32, 2.5_f32

  sun.set_shadow(true)
  assert_true sun.has_shadow
  sun.destroy
end

  test "OmniLight3D spherical range and attenuation" do
  omni = Godot.create(Godot::OmniLight3D)
  omni.set_param(Godot::Light3D::Param::ParamRange.to_i64, 15.0_f64)
  assert_approx_eq omni.get_param(Godot::Light3D::Param::ParamRange.to_i64).to_f32, 15.0_f32

  omni.set_param(Godot::Light3D::Param::ParamAttenuation.to_i64, 1.8_f64)
  assert_approx_eq omni.get_param(Godot::Light3D::Param::ParamAttenuation.to_i64).to_f32, 1.8_f32
  omni.destroy
end

  test "SpotLight3D cone angle and angular attenuation" do
  spot = Godot.create(Godot::SpotLight3D)
  spot.set_param(Godot::Light3D::Param::ParamRange.to_i64, 25.0_f64)
  assert_approx_eq spot.get_param(Godot::Light3D::Param::ParamRange.to_i64).to_f32, 25.0_f32

  spot.set_param(Godot::Light3D::Param::ParamSpotAngle.to_i64, 42.0_f64)
  assert_approx_eq spot.get_param(Godot::Light3D::Param::ParamSpotAngle.to_i64).to_f32, 42.0_f32
  spot.destroy
end

  test "Path3D and PathFollow3D trajectory progression" do
  path = Godot.create(Godot::Path3D)
  follow = Godot.create(Godot::PathFollow3D)
  path.add_child(follow)

  follow.set_progress(120.0_f64)
  assert_approx_eq follow.get_progress.to_f32, 120.0_f32

  follow.set_loop(false)
  assert_false follow.has_loop

  path.remove_child(follow)
  follow.destroy
  path.destroy
end

  test "AudioListener3D spatial audio receiver" do
  al = Godot.create(Godot::AudioListener3D)
  al.make_current
  assert_true al.is_current
  al.clear_current
  assert_false al.is_current
  al.destroy
end

  test "Skeleton3D bone hierarchy and count" do
  skel = Godot.create(Godot::Skeleton3D)
  assert_eq skel.get_bone_count, 0_i64
  skel.set_motion_scale(1.25_f64)
  assert_approx_eq skel.get_motion_scale.to_f32, 1.25_f32
  skel.destroy
end

end
