# =============================================================================
# LibGodot Test Suite: 3D Node Coverage & Multi-Frame Kinematic Simulation
# =============================================================================

include Lapis::Test

test_suite "Nodes3DMultiFrame" do
  test "CharacterBody3D descends under gravity and lands at target floor level" do
    assert_no_leak(max_delta_objects: 5, name: "CharacterBody3D Floor Landing") do
      body = Godot.create(Godot::CharacterBody3D)
      body_shape = Godot.create(Godot::CollisionShape3D)
      cube = Godot.create(Godot::BoxShape3D)
      cube.set_size(Godot::Vector3.new(1.0, 2.0, 1.0))
      body_shape.set_shape(cube)
      body.add_child(body_shape)
      body.set_position(Godot::Vector3.new(0.0, 0.4, 0.0))
      body.set_velocity(Godot::Vector3.new(0.0, 0.0, 0.0))
      root.add_child(body)

      floor_level = 0.0_f32
      landed = false
      gravity_accel = 9.8_f64

      20.times do
        vel = body.get_velocity
        new_vy = vel.y - gravity_accel * 0.016_f64
        body.set_velocity(Godot::Vector3.new(0.0_f32, new_vy.to_f32, 0.0_f32))
        new_pos = body.get_position + body.get_velocity * 0.016_f64
        if new_pos.y <= floor_level
          body.set_position(Godot::Vector3.new(new_pos.x, floor_level, new_pos.z))
          body.set_velocity(Godot::Vector3.new(0.0_f32, 0.0_f32, 0.0_f32))
          landed = true
          break
        else
          body.set_position(new_pos)
        end
        skip_frames(1)
      end

      assert_true landed, "CharacterBody3D must land at floor level under gravity"
      assert_approx_eq body.get_position.y, floor_level, epsilon: 0.1_f64

      root.remove_child(body)
      body.destroy
    end
  end

  test "CharacterBody3D moves and steps kinematic trajectory across frames with velocity damping in 3D" do
    assert_no_leak(max_delta_objects: 5, name: "CharacterBody3D Trajectory Damping") do
      body = Godot.create(Godot::CharacterBody3D)
      body_shape = Godot.create(Godot::CollisionShape3D)
      sphere = Godot.create(Godot::SphereShape3D)
      sphere.set_radius(1.0_f64)
      body_shape.set_shape(sphere)
      body.add_child(body_shape)
      body.set_position(Godot::Vector3.new(0.0, 5.0, 0.0))
      body.set_velocity(Godot::Vector3.new(10.0, 0.0, 0.0))
      root.add_child(body)

      initial_x = body.get_position.x
      10.times do
        vel = body.get_velocity
        body.set_position(body.get_position + vel * 0.016_f64)
        body.set_velocity(vel * 0.85_f64)
        skip_frames(1)
      end

      assert_gt body.get_position.x, initial_x, "CharacterBody3D must advance along X axis"
      assert_lt body.get_velocity.x, 3.0_f32, "Velocity must damp over frames"

      root.remove_child(body)
      body.destroy
    end
  end

  test "Path3D and PathFollow3D spatial spline progression across frame steps" do
    assert_no_leak(max_delta_objects: 5, name: "Path3D Spline Progress") do
      path = Godot.create(Godot::Path3D)
      curve = Godot.create(Godot::Curve3D)
      curve.add_point(Godot::Vector3.new(0.0, 0.0, 0.0), Godot::Vector3.new(0.0, 0.0, 0.0), Godot::Vector3.new(0.0, 0.0, 0.0), -1_i64)
      curve.add_point(Godot::Vector3.new(5.0, 2.0, 5.0), Godot::Vector3.new(0.0, 0.0, 0.0), Godot::Vector3.new(0.0, 0.0, 0.0), -1_i64)
      curve.add_point(Godot::Vector3.new(10.0, 4.0, 10.0), Godot::Vector3.new(0.0, 0.0, 0.0), Godot::Vector3.new(0.0, 0.0, 0.0), -1_i64)
      path.set_curve(curve)

      follow = Godot.create(Godot::PathFollow3D)
      path.add_child(follow)
      root.add_child(path)

      follow.set_progress_ratio(0.0_f64)
      assert_approx_eq follow.get_position.x, 0.0_f32, epsilon: 0.1_f64

      follow.set_progress_ratio(0.5_f64)
      skip_frames(1)
      pos_mid = follow.get_position
      assert_gt pos_mid.x, 2.0_f32
      assert_lt pos_mid.x, 8.0_f32

      follow.set_progress_ratio(1.0_f64)
      skip_frames(1)
      pos_end = follow.get_position
      assert_approx_eq pos_end.x, 10.0_f32, epsilon: 0.5_f64

      root.remove_child(path)
      follow.destroy
      path.destroy
    end
  end

  test "AnimatableBody3D linear kinematic displacement over multi-frame stepping" do
    assert_no_leak(max_delta_objects: 5, name: "AnimatableBody3D Displacement") do
      platform = Godot.create(Godot::AnimatableBody3D)
      platform.set_sync_to_physics(false)
      shape = Godot.create(Godot::CollisionShape3D)
      box = Godot.create(Godot::BoxShape3D)
      box.set_size(Godot::Vector3.new(4.0, 0.5, 4.0))
      shape.set_shape(box)
      platform.add_child(shape)
      platform.set_position(Godot::Vector3.new(0.0, 1.0, 0.0))
      root.add_child(platform)

      10.times do |i|
        platform.set_position(Godot::Vector3.new(0.0, 1.0 + (i + 1) * 0.2, 0.0))
        skip_frames(1)
      end

      assert_approx_eq platform.get_position.y, 3.0_f32, epsilon: 0.05_f64

      root.remove_child(platform)
      platform.destroy
    end
  end

  test "AudioStreamPlayer3D spatial attenuation and bus settings" do
    assert_no_leak(max_delta_objects: 5, name: "AudioStreamPlayer3D Configuration") do
      asp = Godot.create(Godot::AudioStreamPlayer3D)
      asp.set_unit_size(15.0_f64)
      assert_approx_eq asp.get_unit_size.to_f32, 15.0_f32

      asp.set_max_distance(100.0_f64)
      assert_approx_eq asp.get_max_distance.to_f32, 100.0_f32

      asp.set_bus("Master")
      assert_eq asp.get_bus.to_s, "Master"

      root.add_child(asp)
      skip_frames(2)
      root.remove_child(asp)
      asp.destroy
    end
  end
end
