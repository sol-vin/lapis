# =============================================================================
# LibGodot Test Suite: 2D Nodes & Spatial Components
# =============================================================================

include Lapis::Test

test_suite "2D" do
  test "Sprite2D properties and frame manipulation" do
  sprite = Godot.create(Godot::Sprite2D)
  assert_not_nil sprite
  assert_true sprite.alive?

  sprite.set_centered(false)
  assert_false sprite.is_centered

  sprite.set_flip_h(true)
  assert_true sprite.is_flipped_h

  sprite.set_flip_v(true)
  assert_true sprite.is_flipped_v

  sprite.set_offset(Godot::Vector2.new(16.0, 32.0))
  assert_approx_eq sprite.get_offset.x, 16.0_f32
  assert_approx_eq sprite.get_offset.y, 32.0_f32

  sprite.set_hframes(6_i64)
  sprite.set_frame(5_i64)
  assert_eq sprite.get_frame, 5_i64

  sprite.destroy
  assert_true sprite.destroyed?
end

  test "Camera2D zoom, offset, and projection settings" do
  cam = Godot.create(Godot::Camera2D)
  assert_not_nil cam

  cam.set_zoom(Godot::Vector2.new(2.0, 2.0))
  assert_approx_eq cam.get_zoom.x, 2.0_f32
  assert_approx_eq cam.get_zoom.y, 2.0_f32

  cam.set_offset(Godot::Vector2.new(50.0, -25.0))
  assert_approx_eq cam.get_offset.x, 50.0_f32
  assert_approx_eq cam.get_offset.y, -25.0_f32

  cam.set_enabled(true)
  assert_true cam.is_enabled

  cam.set_ignore_rotation(false)
  assert_false cam.is_ignoring_rotation

  cam.destroy
end

  test "Marker2D gizmo configuration" do
  marker = Godot.create(Godot::Marker2D)
  marker.set_gizmo_extents(24.0_f64)
  assert_approx_eq marker.get_gizmo_extents.to_f32, 24.0_f32
  marker.destroy
end

  test "Line2D point array construction and coloring" do
  line = Godot.create(Godot::Line2D)
  assert_eq line.get_point_count, 0_i64

  line.add_point(Godot::Vector2.new(0.0, 0.0), -1_i64)
  line.add_point(Godot::Vector2.new(100.0, 50.0), -1_i64)
  line.add_point(Godot::Vector2.new(200.0, 0.0), -1_i64)

  assert_eq line.get_point_count, 3_i64
  p1 = line.get_point_position(1_i64)
  assert_approx_eq p1.x, 100.0_f32
  assert_approx_eq p1.y, 50.0_f32

  line.set_width(8.0_f64)
  assert_approx_eq line.get_width.to_f32, 8.0_f32

  line.set_default_color(Godot::Color.new(0.2, 0.8, 0.4, 1.0))
  assert_approx_eq line.get_default_color.g, 0.8_f32

  line.clear_points
  assert_eq line.get_point_count, 0_i64
  line.destroy
end

  test "Polygon2D color and geometry definition" do
  poly = Godot.create(Godot::Polygon2D)
  poly.set_color(Godot::Color::RED)
  assert_approx_eq poly.get_color.r, 1.0_f32

  poly.set_offset(Godot::Vector2.new(10.0, 20.0))
  assert_approx_eq poly.get_offset.x, 10.0_f32
  poly.destroy
end

  test "RayCast2D collision targeting and mask" do
  ray = Godot.create(Godot::RayCast2D)
  ray.set_target_position(Godot::Vector2.new(0.0, 150.0))
  assert_approx_eq ray.get_target_position.y, 150.0_f32

  ray.set_enabled(true)
  assert_true ray.is_enabled

  ray.set_collide_with_areas(true)
  assert_true ray.is_collide_with_areas_enabled

  ray.set_collide_with_bodies(true)
  assert_true ray.is_collide_with_bodies_enabled

  ray.set_collision_mask(7_i64)
  assert_eq ray.get_collision_mask, 7_i64
  ray.destroy
end

  test "ShapeCast2D multi-result collision querying" do
  sc = Godot.create(Godot::ShapeCast2D)
  sc.set_target_position(Godot::Vector2.new(50.0, 0.0))
  assert_approx_eq sc.get_target_position.x, 50.0_f32

  sc.set_max_results(16_i64)
  assert_eq sc.get_max_results, 16_i64

  sc.set_enabled(true)
  assert_true sc.is_enabled
  sc.destroy
end

  test "Path2D and PathFollow2D progress tracking" do
  path = Godot.create(Godot::Path2D)
  follow = Godot.create(Godot::PathFollow2D)
  path.add_child(follow)

  follow.set_progress(75.0_f64)
  assert_approx_eq follow.get_progress.to_f32, 75.0_f32

  follow.set_loop(false)
  assert_false follow.has_loop

  follow.set_v_offset(5.0_f64)
  assert_approx_eq follow.get_v_offset.to_f32, 5.0_f32

  path.remove_child(follow)
  follow.destroy
  path.destroy
end

  test "RemoteTransform2D coordinate forwarding" do
  rt = Godot.create(Godot::RemoteTransform2D)
  rt.set_use_global_coordinates(false)
  assert_false rt.get_use_global_coordinates

  rt.set_update_position(true)
  assert_true rt.get_update_position

  rt.set_update_rotation(false)
  assert_false rt.get_update_rotation

  rt.set_update_scale(true)
  assert_true rt.get_update_scale
  rt.destroy
end

  test "ParallaxBackground and ParallaxLayer scrolling motion" do
  bg = Godot.create(Godot::ParallaxBackground)
  layer = Godot.create(Godot::ParallaxLayer)
  bg.add_child(layer)

  layer.set_motion_scale(Godot::Vector2.new(0.5, 0.5))
  assert_approx_eq layer.get_motion_scale.x, 0.5_f32
  assert_approx_eq layer.get_motion_scale.y, 0.5_f32

  layer.set_mirroring(Godot::Vector2.new(1920.0, 1080.0))
  assert_approx_eq layer.get_mirroring.x, 1920.0_f32

  bg.set_scroll_base_offset(Godot::Vector2.new(100.0, 0.0))
  assert_approx_eq bg.get_scroll_base_offset.x, 100.0_f32

  bg.remove_child(layer)
  layer.destroy
  bg.destroy
end

  test "PointLight2D and DirectionalLight2D illumination properties" do
  pt_light = Godot.create(Godot::PointLight2D)
  pt_light.set_energy(1.75_f64)
  assert_approx_eq pt_light.get_energy.to_f32, 1.75_f32

  pt_light.set_color(Godot::Color.new(1.0, 0.9, 0.6, 1.0))
  assert_approx_eq pt_light.get_color.r, 1.0_f32

  pt_light.set_enabled(true)
  assert_true pt_light.is_enabled

  dir_light = Godot.create(Godot::DirectionalLight2D)
  dir_light.set_height(0.5_f64)
  assert_approx_eq dir_light.get_height.to_f32, 0.5_f32

  pt_light.destroy
  dir_light.destroy
end

  test "CanvasModulate ambient color tinting" do
  cm = Godot.create(Godot::CanvasModulate)
  cm.set_color(Godot::Color.new(0.1, 0.1, 0.2, 1.0))
  assert_approx_eq cm.get_color.b, 0.2_f32
  cm.destroy
end

  test "AudioListener2D activation" do
  al = Godot.create(Godot::AudioListener2D)
  al.make_current
  assert_true al.is_current
  al.clear_current
  assert_false al.is_current
  al.destroy
end

end
