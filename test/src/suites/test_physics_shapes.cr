# =============================================================================
# LibGodot Test Suite: Physics Bodies & Collision Shapes (2D & 3D)
# =============================================================================

include Lapis::Test

test_physics "CircleShape2D and RectangleShape2D geometric metrics" do
  circle = Godot.create(Godot::CircleShape2D)
  circle.set_radius(32.0_f64)
  assert_approx_eq circle.get_radius.to_f32, 32.0_f32

  rect = Godot.create(Godot::RectangleShape2D)
  rect.set_size(Godot::Vector2.new(64.0, 128.0))
  assert_approx_eq rect.get_size.x, 64.0_f32
  assert_approx_eq rect.get_size.y, 128.0_f32

  circle.destroy
  rect.destroy
end

test_physics "CapsuleShape2D and SegmentShape2D geometry" do
  cap2d = Godot.create(Godot::CapsuleShape2D)
  cap2d.set_radius(16.0_f64)
  cap2d.set_height(48.0_f64)
  assert_approx_eq cap2d.get_radius.to_f32, 16.0_f32
  assert_approx_eq cap2d.get_height.to_f32, 48.0_f32

  seg = Godot.create(Godot::SegmentShape2D)
  seg.set_a(Godot::Vector2.new(-50.0, 0.0))
  seg.set_b(Godot::Vector2.new(50.0, 0.0))
  assert_approx_eq seg.get_a.x, -50.0_f32
  assert_approx_eq seg.get_b.x, 50.0_f32

  cap2d.destroy
  seg.destroy
end

test_physics "CollisionShape2D shape assignment and disabled flag" do
  cs2d = Godot.create(Godot::CollisionShape2D)
  circle = Godot.create(Godot::CircleShape2D)
  cs2d.set_shape(circle)

  ret_shape = cs2d.get_shape
  assert_not_nil ret_shape
  assert_false ret_shape.pointer.null?
  ret_shape.destroy

  cs2d.set_disabled(true)
  assert_true cs2d.is_disabled

  cs2d.destroy
  circle.destroy
end

test_physics "RigidBody2D mass, gravity, and freeze mode" do
  rb2d = Godot.create(Godot::RigidBody2D)
  rb2d.set_mass(15.5_f64)
  assert_approx_eq rb2d.get_mass.to_f32, 15.5_f32

  rb2d.set_gravity_scale(2.0_f64)
  assert_approx_eq rb2d.get_gravity_scale.to_f32, 2.0_f32

  rb2d.set_freeze_enabled(true)
  assert_true rb2d.is_freeze_enabled
  rb2d.destroy
end

test_physics "BoxShape3D, SphereShape3D, CapsuleShape3D dimensions" do
  box = Godot.create(Godot::BoxShape3D)
  box.set_size(Godot::Vector3.new(2.0, 3.0, 4.0))
  assert_approx_eq box.get_size.x, 2.0_f32
  assert_approx_eq box.get_size.y, 3.0_f32

  sph = Godot.create(Godot::SphereShape3D)
  sph.set_radius(1.75_f64)
  assert_approx_eq sph.get_radius.to_f32, 1.75_f32

  cap3d = Godot.create(Godot::CapsuleShape3D)
  cap3d.set_radius(0.5_f64)
  cap3d.set_height(2.0_f64)
  assert_approx_eq cap3d.get_radius.to_f32, 0.5_f32

  box.destroy
  sph.destroy
  cap3d.destroy
end

test_physics "CollisionShape3D shape assignment and debug color" do
  cs3d = Godot.create(Godot::CollisionShape3D)
  box = Godot.create(Godot::BoxShape3D)
  cs3d.set_shape(box)

  ret = cs3d.get_shape
  assert_not_nil ret
  assert_false ret.pointer.null?
  ret.destroy

  cs3d.set_disabled(false)
  assert_false cs3d.is_disabled

  cs3d.destroy
  box.destroy
end

test_physics "RigidBody3D dynamics parameters" do
  rb3d = Godot.create(Godot::RigidBody3D)
  rb3d.set_mass(50.0_f64)
  assert_approx_eq rb3d.get_mass.to_f32, 50.0_f32

  rb3d.set_gravity_scale(1.5_f64)
  assert_approx_eq rb3d.get_gravity_scale.to_f32, 1.5_f32

  rb3d.set_linear_damp(0.2_f64)
  assert_approx_eq rb3d.get_linear_damp.to_f32, 0.2_f32

  rb3d.set_angular_damp(0.5_f64)
  assert_approx_eq rb3d.get_angular_damp.to_f32, 0.5_f32
  rb3d.destroy
end

test_physics "VehicleBody3D and VehicleWheel3D motor and suspension parameters" do
  vb = Godot.create(Godot::VehicleBody3D)
  vw = Godot.create(Godot::VehicleWheel3D)
  vb.add_child(vw)

  vb.set_engine_force(1200.0_f64)
  assert_approx_eq vb.get_engine_force.to_f32, 1200.0_f32

  vb.set_brake(25.0_f64)
  assert_approx_eq vb.get_brake.to_f32, 25.0_f32

  vw.set_use_as_traction(true)
  assert_true vw.is_used_as_traction

  vw.set_use_as_steering(true)
  assert_true vw.is_used_as_steering

  vw.set_suspension_stiffness(5.8_f64)
  assert_approx_eq vw.get_suspension_stiffness.to_f32, 5.8_f32

  vb.remove_child(vw)
  vw.destroy
  vb.destroy
end

test_physics "RayCast3D and ShapeCast3D null-safe get_collider? queries" do
  rc3d = Godot.create(Godot::RayCast3D)
  assert_nil rc3d.get_collider?, "RayCast3D get_collider? must return nil when not colliding"

  sc3d = Godot.create(Godot::ShapeCast3D)
  assert_nil sc3d.get_collider?(0), "ShapeCast3D get_collider? must return nil when not colliding"

  rc2d = Godot.create(Godot::RayCast2D)
  assert_nil rc2d.get_collider?, "RayCast2D get_collider? must return nil when not colliding"

  sc2d = Godot.create(Godot::ShapeCast2D)
  assert_nil sc2d.get_collider?(0), "ShapeCast2D get_collider? must return nil when not colliding"

  rc3d.destroy
  sc3d.destroy
  rc2d.destroy
  sc2d.destroy
end
