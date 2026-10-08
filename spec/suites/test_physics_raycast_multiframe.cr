# =============================================================================
# LibGodot Test Suite: Multi-Frame Spatial Physics & RayCast / ShapeCast Probing
# =============================================================================

include Lapis::Test

# Probe receiver node tracking raycast collision triggers
node RaycastProbeReceiver < Godot::Node do
  property collided_objects : Array(Godot::Object) = Array(Godot::Object).new
  property hit_count : Int32 = 0

  def on_collision(collider : Godot::Object) : Void
    @collided_objects << collider
    @hit_count += 1
  end

  def on_hit_alert : Void
    @hit_count += 1
  end

  def reset : Void
    @collided_objects.clear
    @hit_count = 0
  end
end

test_suite "RayCastMultiFrame" do
  test "RayCast2D dynamic collision detection and point query across frame stepping" do
    assert_no_leak(max_delta_objects: 5, name: "RayCast2D multi-frame collision") do
      obstacle = Godot.create(Godot::StaticBody2D)
      col_shape = Godot.create(Godot::CollisionShape2D)
      rect = Godot.create(Godot::RectangleShape2D)
      rect.set_size(Godot::Vector2.new(64.0, 64.0))
      col_shape.set_shape(rect)
      obstacle.add_child(col_shape)
      obstacle.set_position(Godot::Vector2.new(200.0, 200.0))
      root.add_child(obstacle)

      ray = Godot.create(Godot::RayCast2D)
      ray.set_position(Godot::Vector2.new(50.0, 200.0))
      ray.set_target_position(Godot::Vector2.new(300.0, 0.0))
      ray.set_enabled(true)
      root.add_child(ray)

      ray.force_raycast_update
      skip_frames(2)

      assert_true ray.is_colliding?, "RayCast2D should detect obstacle along its beam"
      collider = ray.get_collider
      assert_false collider.pointer.null?, "Collider must not be null"
      assert_eq collider.instance_id, obstacle.instance_id

      # Hit point should be at the left edge of obstacle: x = 200 - 32 = 168
      hit_pt = ray.get_collision_point
      assert_true (hit_pt.x - 168.0).abs < 2.0, "Collision point X should be near 168.0, got #{hit_pt.x}"

      normal = ray.get_collision_normal
      assert_true normal.x < -0.9, "Collision normal should point left (-1, 0), got #{normal}"

      # Move ray away from obstacle
      ray.set_position(Godot::Vector2.new(50.0, 500.0))
      ray.force_raycast_update
      skip_frames(2)

      assert_false ray.is_colliding?, "RayCast2D should no longer collide after displacement"

      root.remove_child(ray)
      ray.destroy
      root.remove_child(obstacle)
      obstacle.destroy
    end
  end

  test "RayCast2D collision mask layer filtering over multi-frame stepping" do
    assert_no_leak(max_delta_objects: 5, name: "RayCast2D layer mask filtering") do
      obstacle = Godot.create(Godot::StaticBody2D)
      col_shape = Godot.create(Godot::CollisionShape2D)
      rect = Godot.create(Godot::RectangleShape2D)
      rect.set_size(Godot::Vector2.new(64.0, 64.0))
      col_shape.set_shape(rect)
      obstacle.add_child(col_shape)
      obstacle.set_position(Godot::Vector2.new(200.0, 200.0))
      obstacle.set_collision_layer(4_i64)
      root.add_child(obstacle)

      ray = Godot.create(Godot::RayCast2D)
      ray.set_position(Godot::Vector2.new(50.0, 200.0))
      ray.set_target_position(Godot::Vector2.new(300.0, 0.0))
      ray.set_collision_mask(1_i64)
      ray.set_enabled(true)
      root.add_child(ray)

      ray.force_raycast_update
      skip_frames(2)

      assert_false ray.is_colliding?, "RayCast2D on mask 1 should NOT detect obstacle on layer 4"

      # Reconfigure mask to match obstacle layer
      ray.set_collision_mask(4_i64)
      ray.force_raycast_update
      skip_frames(2)

      assert_true ray.is_colliding?, "RayCast2D on mask 4 SHOULD detect obstacle on layer 4"
      assert_eq ray.get_collider.instance_id, obstacle.instance_id

      root.remove_child(ray)
      ray.destroy
      root.remove_child(obstacle)
      obstacle.destroy
    end
  end

  test "RayCast3D spatial intersection, target position update, and normal resolution over frames" do
    assert_no_leak(max_delta_objects: 5, name: "RayCast3D spatial probing") do
      obstacle3d = Godot.create(Godot::StaticBody3D)
      col_shape3d = Godot.create(Godot::CollisionShape3D)
      box3d = Godot.create(Godot::BoxShape3D)
      box3d.set_size(Godot::Vector3.new(2.0, 2.0, 2.0))
      col_shape3d.set_shape(box3d)
      obstacle3d.add_child(col_shape3d)
      obstacle3d.set_position(Godot::Vector3.new(0.0, 0.0, -5.0))
      root.add_child(obstacle3d)

      ray3d = Godot.create(Godot::RayCast3D)
      ray3d.set_position(Godot::Vector3.new(0.0, 0.0, 0.0))
      ray3d.set_target_position(Godot::Vector3.new(0.0, 0.0, -10.0))
      ray3d.set_enabled(true)
      root.add_child(ray3d)

      ray3d.force_raycast_update
      skip_frames(2)

      assert_true ray3d.is_colliding?, "RayCast3D should detect 3D obstacle directly in front"
      collider3d = ray3d.get_collider
      assert_false collider3d.pointer.null?
      assert_eq collider3d.instance_id, obstacle3d.instance_id

      hit_pt3d = ray3d.get_collision_point
      assert_true (hit_pt3d.z - (-4.0)).abs < 0.2, "Collision point Z should be near -4.0, got #{hit_pt3d.z}"

      normal3d = ray3d.get_collision_normal
      assert_true normal3d.z > 0.9, "Collision normal should point along +Z back to ray origin, got #{normal3d}"

      # Point raycast away
      ray3d.set_target_position(Godot::Vector3.new(0.0, 10.0, 0.0))
      ray3d.force_raycast_update
      skip_frames(2)

      assert_false ray3d.is_colliding?, "RayCast3D pointed up should not detect obstacle at -Z"

      root.remove_child(ray3d)
      ray3d.destroy
      root.remove_child(obstacle3d)
      obstacle3d.destroy
    end
  end

  test "ShapeCast2D multi-target spatial volume sweep across frames" do
    assert_no_leak(max_delta_objects: 5, name: "ShapeCast2D multi-target sweep") do
      obs1 = Godot.create(Godot::StaticBody2D)
      shape1 = Godot.create(Godot::CollisionShape2D)
      circle1 = Godot.create(Godot::CircleShape2D)
      circle1.set_radius(16.0_f64)
      shape1.set_shape(circle1)
      obs1.add_child(shape1)
      obs1.set_position(Godot::Vector2.new(100.0, 0.0))
      root.add_child(obs1)

      cast2d = Godot.create(Godot::ShapeCast2D)
      cast_circle = Godot.create(Godot::CircleShape2D)
      cast_circle.set_radius(12.0_f64)
      cast2d.set_shape(cast_circle)
      cast2d.set_position(Godot::Vector2.new(0.0, 0.0))
      cast2d.set_target_position(Godot::Vector2.new(200.0, 0.0))
      cast2d.set_max_results(8_i64)
      cast2d.set_enabled(true)
      root.add_child(cast2d)

      cast2d.force_shapecast_update
      skip_frames(2)

      assert_true cast2d.is_colliding?, "ShapeCast2D should detect obstacle in swept volume"
      count = cast2d.get_collision_count
      assert_true count >= 1_i64, "ShapeCast2D should register at least 1 collision, got #{count}"
      col = cast2d.get_collider(0_i64)
      assert_false col.pointer.null?
      assert_eq col.instance_id, obs1.instance_id

      root.remove_child(cast2d)
      cast2d.destroy
      root.remove_child(obs1)
      obs1.destroy
    end
  end
end
