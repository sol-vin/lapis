# =============================================================================
# LibGodot Test Suite: Cameras, SubViewports & Canvas Projection
# =============================================================================

include Lapis::Test

test_camera "Camera3D projection, FOV, clipping planes & ray unprojection" do
  cam = Godot.create(Godot::Camera3D)

  cam.set_projection(0_i64) # PROJECTION_PERSPECTIVE
  cam.set_fov(75.0_f64)
  cam.set_near(0.1_f64)
  cam.set_far(1500.0_f64)

  assert_eq cam.get_projection, 0_i64
  assert_approx_eq cam.get_fov.to_f32, 75.0_f32
  assert_approx_eq cam.get_near.to_f32, 0.1_f32
  assert_approx_eq cam.get_far.to_f32, 1500.0_f32

  # Attach to tree for projection calculations
  root.call("add_child", cam)

  # Test ray origin and normal projections
  screen_center = Godot::Vector2.new(320.0, 240.0)
  ray_origin = cam.project_ray_origin(screen_center)
  ray_normal = cam.project_ray_normal(screen_center)

  # Ray normal should be a unit vector
  assert_approx_eq ray_normal.length, 1.0_f32, 0.01

  root.call("remove_child", cam)
  cam.destroy
end

test_camera "Camera2D zoom, offset, position smoothing and viewport limits" do
  cam2d = Godot.create(Godot::Camera2D)

  cam2d.set_zoom(Godot::Vector2.new(2.5, 2.5))
  cam2d.set_offset(Godot::Vector2.new(100.0, -50.0))

  assert_approx_eq cam2d.get_zoom.x, 2.5_f32
  assert_approx_eq cam2d.get_zoom.y, 2.5_f32
  assert_approx_eq cam2d.get_offset.x, 100.0_f32
  assert_approx_eq cam2d.get_offset.y, -50.0_f32

  # Limits: Left (0), Top (1), Right (2), Bottom (3)
  cam2d.set_limit(0_i64, -2000_i64)
  cam2d.set_limit(2_i64, 4000_i64)
  assert_eq cam2d.get_limit(0_i64), -2000_i64
  assert_eq cam2d.get_limit(2_i64), 4000_i64

  cam2d.destroy
end

test_viewport "SubViewport render target texture, dimensions and update modes" do
  vp = Godot.create(Godot::SubViewport)
  vp.set_size(Godot::Vector2i.new(256, 256))
  vp.set_update_mode(2_i64) # UPDATE_ALWAYS
  vp.set_clear_mode(0_i64)  # CLEAR_MODE_ALWAYS

  assert_eq vp.get_size.x, 256
  assert_eq vp.get_size.y, 256
  assert_eq vp.get_update_mode, 2_i64
  assert_eq vp.get_clear_mode, 0_i64

  # Query ViewportTexture
  vp_tex = vp.get_texture
  assert_not_nil vp_tex
  assert_false vp_tex.pointer.null?
  assert_eq vp_tex.get_width, 256_i64
  assert_eq vp_tex.get_height, 256_i64

  vp.destroy
end

test_viewport "CanvasItem redraw queuing and tree visibility inspection" do
  ctrl = Godot.create(Godot::Control)
  ctrl.set_visible(true)
  assert_true ctrl.is_visible

  ctrl.queue_redraw
  ctrl.set_visible(false)
  assert_false ctrl.is_visible

  ctrl.destroy
end
