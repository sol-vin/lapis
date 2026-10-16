# =============================================================================
# LibGodot Test Suite: 2D Node Coverage & Multi-Frame Kinematic Simulation
# =============================================================================

include Lapis::Test

test_suite "Nodes2DMultiFrame" do
  test "CharacterBody2D moves and steps kinematic trajectory across frames with velocity damping" do
    assert_no_leak(max_delta_objects: 5, name: "CharacterBody2D Trajectory Damping") do
      body = Godot.create(Godot::CharacterBody2D)
      body_shape = Godot.create(Godot::CollisionShape2D)
      circle = Godot.create(Godot::CircleShape2D)
      circle.set_radius(16.0_f64)
      body_shape.set_shape(circle)
      body.add_child(body_shape)
      body.set_position(Godot::Vector2.new(100.0, 200.0))
      body.set_velocity(Godot::Vector2.new(200.0, 0.0))
      root.add_child(body)

      initial_x = body.get_position.x
      # Simulate multi-frame physics motion with velocity damping
      10.times do
        vel = body.get_velocity
        body.set_position(body.get_position + vel * 0.016_f64)
        body.set_velocity(vel * 0.85_f64)
        skip_frames(1)
      end

      assert_gt body.get_position.x, initial_x, "CharacterBody2D must advance along X axis"
      assert_lt body.get_velocity.x, 50.0_f32, "Velocity must damp over frames"

      root.remove_child(body)
      body.destroy
    end
  end

  test "CharacterBody2D falls under gravity and lands at target floor level" do
    assert_no_leak(max_delta_objects: 5, name: "CharacterBody2D Gravity Landing") do
      body = Godot.create(Godot::CharacterBody2D)
      body_shape = Godot.create(Godot::CollisionShape2D)
      box = Godot.create(Godot::RectangleShape2D)
      box.set_size(Godot::Vector2.new(32.0, 32.0))
      body_shape.set_shape(box)
      body.add_child(body_shape)
      body.set_position(Godot::Vector2.new(300.0, 280.0))
      body.set_velocity(Godot::Vector2.new(0.0, 0.0))
      root.add_child(body)

      floor_level = 300.0
      landed_floor = false
      gravity_accel = 500.0_f64

      20.times do
        vel = body.get_velocity
        new_vy = vel.y + gravity_accel * 0.016_f64
        body.set_velocity(Godot::Vector2.new(0.0_f32, new_vy.to_f32))
        new_pos = body.get_position + body.get_velocity * 0.016_f64
        if new_pos.y >= floor_level
          body.set_position(Godot::Vector2.new(new_pos.x, floor_level.to_f32))
          body.set_velocity(Godot::Vector2.new(0.0_f32, 0.0_f32))
          landed_floor = true
          break
        else
          body.set_position(new_pos)
        end
        skip_frames(1)
      end

      assert_true landed_floor, "CharacterBody2D must land at floor level under gravity"
      assert_approx_eq body.get_position.y, floor_level.to_f32, epsilon: 1.0_f64

      root.remove_child(body)
      body.destroy
    end
  end

  test "Path2D and PathFollow2D progress interpolation across frame steps" do
    assert_no_leak(max_delta_objects: 5, name: "Path2D Curve Progress") do
      path = Godot.create(Godot::Path2D)
      curve = Godot.create(Godot::Curve2D)
      curve.add_point(Godot::Vector2.new(0.0, 0.0), Godot::Vector2.new(0.0, 0.0), Godot::Vector2.new(0.0, 0.0), -1_i64)
      curve.add_point(Godot::Vector2.new(100.0, 50.0), Godot::Vector2.new(0.0, 0.0), Godot::Vector2.new(0.0, 0.0), -1_i64)
      curve.add_point(Godot::Vector2.new(200.0, 100.0), Godot::Vector2.new(0.0, 0.0), Godot::Vector2.new(0.0, 0.0), -1_i64)
      path.set_curve(curve)

      follow = Godot.create(Godot::PathFollow2D)
      path.add_child(follow)
      root.add_child(path)

      # Step progress across 5 steps
      follow.set_progress_ratio(0.0_f64)
      pos_start = follow.get_position
      assert_approx_eq pos_start.x, 0.0_f32, epsilon: 1.0_f64

      follow.set_progress_ratio(0.5_f64)
      skip_frames(1)
      pos_mid = follow.get_position
      assert_gt pos_mid.x, 50.0_f32
      assert_lt pos_mid.x, 150.0_f32

      follow.set_progress_ratio(1.0_f64)
      skip_frames(1)
      pos_end = follow.get_position
      assert_approx_eq pos_end.x, 200.0_f32, epsilon: 2.0_f64

      root.remove_child(path)
      follow.destroy
      path.destroy
    end
  end

  test "AnimatableBody2D kinematic displacement across multi-frame stepping" do
    assert_no_leak(max_delta_objects: 5, name: "AnimatableBody2D Kinematic Motion") do
      platform = Godot.create(Godot::AnimatableBody2D)
      platform.set_sync_to_physics(false)
      shape = Godot.create(Godot::CollisionShape2D)
      rect = Godot.create(Godot::RectangleShape2D)
      rect.set_size(Godot::Vector2.new(200.0, 20.0))
      shape.set_shape(rect)
      platform.add_child(shape)
      platform.set_position(Godot::Vector2.new(100.0, 300.0))
      root.add_child(platform)

      # Animate platform position horizontally across 10 frames
      10.times do |i|
        platform.set_position(Godot::Vector2.new(100.0 + (i + 1) * 10.0, 300.0))
        skip_frames(1)
      end

      assert_approx_eq platform.get_position.x, 200.0_f32, epsilon: 0.1_f64
      root.remove_child(platform)
      platform.destroy
    end
  end

  test "VisibleOnScreenNotifier2D rect boundaries and state initialization" do
    assert_no_leak(max_delta_objects: 5, name: "VisibleOnScreenNotifier2D Boundaries") do
      notifier = Godot.create(Godot::VisibleOnScreenNotifier2D)
      notifier.set_rect(Godot::Rect2.new(0.0_f32, 0.0_f32, 80.0_f32, 60.0_f32))
      assert_approx_eq notifier.get_rect.size.x, 80.0_f32
      assert_approx_eq notifier.get_rect.size.y, 60.0_f32

      root.add_child(notifier)
      skip_frames(2)
      root.remove_child(notifier)
      notifier.destroy
    end
  end
end
