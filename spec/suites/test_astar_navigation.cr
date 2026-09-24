# =============================================================================
# LibGodot Test Suite: AStar Navigation & Pathfinding
# =============================================================================

include Lapis::Test

test_suite "Navigation" do
  test "AStar2D point registration, connection topology, and shortest path calculation" do
    astar = Godot.create(Godot::AStar2D)
    assert_not_nil astar
    assert_false astar.pointer.null?

    # Register 4 points forming a small diamond / rectangle graph
    # 0 (0,0) --- 1 (10,0)
    #   |           |
    # 2 (0,10) -- 3 (10,10)
    astar.add_point(0_i64, Godot::Vector2.new(0.0_f32, 0.0_f32), 1.0_f64)
    astar.add_point(1_i64, Godot::Vector2.new(10.0_f32, 0.0_f32), 1.0_f64)
    astar.add_point(2_i64, Godot::Vector2.new(0.0_f32, 10.0_f32), 1.0_f64)
    astar.add_point(3_i64, Godot::Vector2.new(10.0_f32, 10.0_f32), 1.0_f64)

    assert_eq astar.get_point_count, 4_i64

    # Connect edges
    astar.connect_points(0_i64, 1_i64, true)
    astar.connect_points(1_i64, 3_i64, true)
    astar.connect_points(0_i64, 2_i64, true)
    astar.connect_points(2_i64, 3_i64, true)

    assert_true astar.are_points_connected(0_i64, 1_i64, true)
    assert_true astar.are_points_connected(1_i64, 3_i64, true)
    assert_false astar.are_points_connected(0_i64, 3_i64, true) # Not direct diagonal

    # Query ID path from 0 to 3
    id_path = astar.get_id_path(0_i64, 3_i64)
    assert_false id_path.null?

    # Disable intermediate point 1 and re-evaluate path
    astar.set_point_disabled(1_i64, true)
    assert_true astar.is_point_disabled(1_i64)

    detour_path = astar.get_id_path(0_i64, 3_i64)
    assert_false detour_path.null?
  end

  test "AStar3D 3D waypoint spatial pathfinding" do
    astar3d = Godot.create(Godot::AStar3D)
    assert_not_nil astar3d

    astar3d.add_point(0_i64, Godot::Vector3.new(0.0_f32, 0.0_f32, 0.0_f32), 1.0_f64)
    astar3d.add_point(1_i64, Godot::Vector3.new(0.0_f32, 5.0_f32, 0.0_f32), 1.0_f64)
    astar3d.add_point(2_i64, Godot::Vector3.new(0.0_f32, 10.0_f32, 0.0_f32), 1.0_f64)

    astar3d.connect_points(0_i64, 1_i64, true)
    astar3d.connect_points(1_i64, 2_i64, true)

    point_path = astar3d.get_point_path(0_i64, 2_i64)
    assert_false point_path.null?
  end
end
