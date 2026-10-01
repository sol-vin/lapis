# =============================================================================
# LibGodot Test Suite: Multi-Frame Physics Simulation (3D Cube Stack Stability)
# =============================================================================
# Spawns a vertical tower of RigidBody3D cubes on a static floor, simulates
# multi-frame physics settling, and asserts stack stability, collision resolution,
# numeric bounds, and zero ObjectDB/node leaks.

include Lapis::Test

test_suite "Physics" do
  test "RigidBody3D cube stack maintains structural integrity over multi-frame physics simulation" do
    assert_no_leak(max_delta_objects: 0, name: "3D Cube Stack Stability") do
      cubes = Array(Godot::RigidBody3D).new
      fixtures = Array(Godot::Node).new

      # 1. Static 3D floor plane
      floor_body = Godot.create(Godot::StaticBody3D)
      floor_shape = Godot.create(Godot::CollisionShape3D)
      floor_box = Godot.create(Godot::BoxShape3D)
      floor_box.set_size(Godot::Vector3.new(40.0, 2.0, 40.0))
      floor_shape.set_shape(floor_box)
      floor_body.set_position(Godot::Vector3.new(0.0, -1.0, 0.0))
      floor_body.add_child(floor_shape)
      root.add_child(floor_body)
      fixtures << floor_body

      # 2. Spawn vertical stack of 10 RigidBody3D cubes
      stack_height = 10
      cube_size = 2.0_f64

      stack_height.times do |i|
        cube = Godot.create(Godot::RigidBody3D)
        cube.set_mass(5.0_f64)
        cube.set_linear_damp(0.1_f64)
        cube.set_angular_damp(0.1_f64)

        cube_shape = Godot.create(Godot::CollisionShape3D)
        box = Godot.create(Godot::BoxShape3D)
        box.set_size(Godot::Vector3.new(cube_size, cube_size, cube_size))
        cube_shape.set_shape(box)
        cube.add_child(cube_shape)

        # Space each cube slightly above the previous one to let gravity settle the stack
        y_pos = 1.0_f64 + i * (cube_size + 0.1_f64)
        cube.set_position(Godot::Vector3.new(0.0, y_pos, 0.0))

        root.add_child(cube)
        cubes << cube
      end

      assert_eq cubes.size, stack_height

      # 3. Simulate multi-frame physics
      # 120 frames provides ample physics ticks for stack compression and settling
      skip_frames(120)

      # 4. Verify stack stability and spatial sanity
      cubes.each_with_index do |cube, idx|
        assert_true cube.alive?, "Cube #{idx} must remain alive"
        pos = cube.get_position

        # Guard against NaN / Infinite coordinates
        assert_false pos.x.nan?, "Cube #{idx} X must not be NaN"
        assert_false pos.y.nan?, "Cube #{idx} Y must not be NaN"
        assert_false pos.z.nan?, "Cube #{idx} Z must not be NaN"

        # Stability: cubes should not explode or fly away to outer space
        assert_gt pos.y, -0.5_f32, "Cube #{idx} fell through the floor"
        assert_lt pos.y, 40.0_f32, "Cube #{idx} launched into space"
        assert_lt pos.x.abs, 15.0_f32, "Cube #{idx} drifted too far along X axis"
        assert_lt pos.z.abs, 15.0_f32, "Cube #{idx} drifted too far along Z axis"
      end

      # 5. Clean teardown of all physics bodies
      cubes.each do |c|
        if c.alive?
          root.remove_child(c) if c.get_parent?
          c.destroy
        end
      end
      cubes.clear

      fixtures.each do |f|
        if f.alive?
          root.remove_child(f) if f.get_parent?
          f.destroy
        end
      end
      fixtures.clear
    end
  end
end
