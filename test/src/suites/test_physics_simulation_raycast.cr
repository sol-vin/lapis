# =============================================================================
# LibGodot Test Suite: Physics Simulation, Raycasting & Collision Detection
# =============================================================================

include Lapis::Test

test_physics "PhysicsRayQueryParameters3D configuration and spatial raycast query" do
  query = Godot.create(Godot::PhysicsRayQueryParameters3D)
  query.set_from(Godot::Vector3.new(0.0, 10.0, 0.0))
  query.set_to(Godot::Vector3.new(0.0, -10.0, 0.0))
  query.set_collision_mask(0xFFFFFFFF_i64)

  assert_not_nil query
  assert_approx_eq query.get_from.y, 10.0_f32
  assert_approx_eq query.get_to.y, -10.0_f32
  assert_eq query.get_collision_mask, 0xFFFFFFFF_i64

  query.set_collide_with_bodies(true)
  query.set_collide_with_areas(true)
  assert_true query.is_collide_with_bodies_enabled
  assert_true query.is_collide_with_areas_enabled
end

test_physics "PhysicsRayQueryParameters2D configuration and planar raycast query" do
  query2d = Godot.create(Godot::PhysicsRayQueryParameters2D)
  query2d.set_from(Godot::Vector2.new(100.0, 0.0))
  query2d.set_to(Godot::Vector2.new(100.0, 500.0))
  query2d.set_collision_mask(1_i64)

  assert_not_nil query2d
  assert_approx_eq query2d.get_from.x, 100.0_f32
  assert_approx_eq query2d.get_to.y, 500.0_f32

  query2d.set_hit_from_inside(true)
  assert_true query2d.is_hit_from_inside_enabled
end

test_physics "Collision layer and mask bitwise flag manipulation (2D & 3D)" do
  body3d = Godot.create(Godot::StaticBody3D)
  body3d.set_collision_layer(0_i64)
  body3d.set_collision_mask(0_i64)

  # Layer 3 and 7 toggling
  body3d.set_collision_layer_value(3_i64, true)
  body3d.set_collision_layer_value(7_i64, true)
  assert_true body3d.get_collision_layer_value(3_i64)
  assert_true body3d.get_collision_layer_value(7_i64)
  assert_false body3d.get_collision_layer_value(1_i64)

  # Mask 2 and 5 toggling
  body3d.set_collision_mask_value(2_i64, true)
  body3d.set_collision_mask_value(5_i64, true)
  assert_true body3d.get_collision_mask_value(2_i64)
  assert_true body3d.get_collision_mask_value(5_i64)
  assert_false body3d.get_collision_mask_value(4_i64)

  body3d.destroy

  # 2D Body bitwise validation
  body2d = Godot.create(Godot::CharacterBody2D)
  body2d.set_collision_layer_value(4_i64, true)
  assert_true body2d.get_collision_layer_value(4_i64)
  assert_false body2d.get_collision_layer_value(2_i64)
  body2d.destroy
end

test_physics "CharacterBody3D move_and_slide velocity and motion properties" do
  char3d = Godot.create(Godot::CharacterBody3D)

  # Velocity configuration
  char3d.set_velocity(Godot::Vector3.new(5.0, -9.8, 3.0))
  assert_approx_eq char3d.get_velocity.x, 5.0_f32
  assert_approx_eq char3d.get_velocity.y, -9.8_f32
  assert_approx_eq char3d.get_velocity.z, 3.0_f32

  # Floor and wall configuration
  char3d.set_max_slides(6_i64)
  char3d.set_floor_stop_on_slope_enabled(true)
  assert_eq char3d.get_max_slides, 6_i64
  assert_true char3d.is_floor_stop_on_slope_enabled

  char3d.destroy
end

test_physics "Area3D and Area2D monitoring and overlap query configuration" do
  area3d = Godot.create(Godot::Area3D)
  area3d.set_monitoring(true)
  area3d.set_monitorable(true)
  assert_true area3d.is_monitoring
  assert_true area3d.is_monitorable

  # Priority and gravity override using SpaceOverride enum directly
  area3d.set_priority(10_i64)
  area3d.set_gravity_space_override_mode(Godot::Area3D::SpaceOverride::SpaceOverrideCombine)
  assert_eq area3d.get_priority, 10_i64
  assert_eq area3d.get_gravity_space_override_mode, Godot::Area3D::SpaceOverride::SpaceOverrideCombine.value

  area3d.destroy

  # 2D Area
  area2d = Godot.create(Godot::Area2D)
  area2d.set_monitoring(true)
  area2d.set_gravity_point_unit_distance(100.0_f64)
  assert_true area2d.is_monitoring
  assert_approx_eq area2d.get_gravity_point_unit_distance.to_f32, 100.0_f32
  area2d.destroy
end

test_physics "RigidBody3D impulse application, mass and linear velocity" do
  rb = Godot.create(Godot::RigidBody3D)
  rb.set_mass(25.0_f64)
  rb.set_linear_damp(0.1_f64)
  rb.set_angular_damp(0.05_f64)

  assert_approx_eq rb.get_mass.to_f32, 25.0_f32
  assert_approx_eq rb.get_linear_damp.to_f32, 0.1_f32
  assert_approx_eq rb.get_angular_damp.to_f32, 0.05_f32

  # Direct velocity assignment
  rb.set_linear_velocity(Godot::Vector3.new(12.0, 0.0, -8.0))
  assert_approx_eq rb.get_linear_velocity.x, 12.0_f32
  assert_approx_eq rb.get_linear_velocity.z, -8.0_f32

  # Impulse application methods
  rb.apply_central_impulse(Godot::Vector3.new(0.0, 50.0, 0.0))
  rb.apply_torque_impulse(Godot::Vector3.new(0.0, 10.0, 0.0))

  rb.destroy
end
