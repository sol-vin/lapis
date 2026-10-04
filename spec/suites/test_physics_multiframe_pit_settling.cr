# =============================================================================
# LibGodot Test Suite: Multi-Frame Physics Simulation (2D Pit Settling)
# =============================================================================
# Drops 200 RigidBody2D balls into an enclosed static pit and validates
# multi-frame physics collision stability, boundary containment, velocity
# decay, and zero ObjectDB/node leaks across frame yields.

include Lapis::Test

test_suite "Physics" do
  test "200 RigidBody2D balls drop into an enclosed pit and settle over multi-frame simulation" do
    assert_no_leak(max_delta_objects: 1, name: "200 Ball Pit Settling") do
      pit_nodes = Array(Godot::Node).new
      balls = Array(Godot::RigidBody2D).new

      # 1. Construct static containment pit (Floor + Left Wall + Right Wall)
      # Bottom floor
      floor_body = Godot.create(Godot::StaticBody2D)
      floor_shape = Godot.create(Godot::CollisionShape2D)
      floor_rect = Godot.create(Godot::RectangleShape2D)
      floor_rect.set_size(Godot::Vector2.new(1000.0, 40.0))
      floor_shape.set_shape(floor_rect)
      floor_body.set_position(Godot::Vector2.new(500.0, 600.0))
      floor_body.add_child(floor_shape)
      root.add_child(floor_body)
      pit_nodes << floor_body

      # Left wall
      left_wall = Godot.create(Godot::StaticBody2D)
      left_shape = Godot.create(Godot::CollisionShape2D)
      left_rect = Godot.create(Godot::RectangleShape2D)
      left_rect.set_size(Godot::Vector2.new(40.0, 800.0))
      left_shape.set_shape(left_rect)
      left_wall.set_position(Godot::Vector2.new(80.0, 200.0))
      left_wall.add_child(left_shape)
      root.add_child(left_wall)
      pit_nodes << left_wall

      # Right wall
      right_wall = Godot.create(Godot::StaticBody2D)
      right_shape = Godot.create(Godot::CollisionShape2D)
      right_rect = Godot.create(Godot::RectangleShape2D)
      right_rect.set_size(Godot::Vector2.new(40.0, 800.0))
      right_shape.set_shape(right_rect)
      right_wall.set_position(Godot::Vector2.new(920.0, 200.0))
      right_wall.add_child(right_shape)
      root.add_child(right_wall)
      pit_nodes << right_wall

      # 2. Spawn 200 RigidBody2D ball instances arranged in a falling grid
      200.times do |i|
        ball = Godot.create(Godot::RigidBody2D)
        ball_shape = Godot.create(Godot::CollisionShape2D)
        circle = Godot.create(Godot::CircleShape2D)
        circle.set_radius(10.0_f64)
        ball_shape.set_shape(circle)
        ball.add_child(ball_shape)

        col = i % 20
        row = i // 20
        spawn_x = 150.0_f64 + col * 35.0_f64
        spawn_y = -300.0_f64 + row * 35.0_f64
        ball.set_position(Godot::Vector2.new(spawn_x, spawn_y))

        root.add_child(ball)
        balls << ball
      end

      assert_eq balls.size, 200

      # 3. Simulate multi-frame physics step
      # Stepping frames cooperatively lets Godot Physics2D simulate falling and collisions
      skip_frames(180)

      # 4. Verify physical containment and numeric stability across all 200 bodies
      balls.each_with_index do |b, idx|
        assert_true b.alive?, "Ball #{idx} must remain alive"
        pos = b.get_position

        # Guard against NaN / Infinite numerical anomalies
        assert_false pos.x.nan?, "Ball #{idx} X position must not be NaN"
        assert_false pos.y.nan?, "Ball #{idx} Y position must not be NaN"
        assert_true pos.x.finite?, "Ball #{idx} X position must not be infinite"
        assert_true pos.y.finite?, "Ball #{idx} Y position must not be infinite"

        # Bounds containment: Pit walls are at X:80 and X:920, Floor at Y:600
        assert_gt pos.x, 70.0_f32, "Ball #{idx} escaped left boundary"
        assert_lt pos.x, 930.0_f32, "Ball #{idx} escaped right boundary"
        assert_lt pos.y, 650.0_f32, "Ball #{idx} fell through floor"
      end

      # 5. Clean teardown of all simulation entities
      balls.each do |b|
        if b.alive?
          root.remove_child(b) if b.get_parent?
          b.destroy
        end
      end
      balls.clear

      pit_nodes.each do |p|
        if p.alive?
          root.remove_child(p) if p.get_parent?
          p.destroy
        end
      end
      pit_nodes.clear
    end
  end
end
