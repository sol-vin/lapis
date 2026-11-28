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
    assert_eq id_path.size, 3_i64
    assert_eq id_path[0], 0_i64
    assert_eq id_path[2], 3_i64

    # Disable intermediate point 1 and re-evaluate path
    astar.set_point_disabled(1_i64, true)
    assert_true astar.is_point_disabled(1_i64)

    detour_path = astar.get_id_path(0_i64, 3_i64)
    assert_eq detour_path.size, 3_i64
    assert_eq detour_path[0], 0_i64
    assert_eq detour_path[1], 2_i64
    assert_eq detour_path[2], 3_i64
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
    assert_eq point_path.size, 3_i64
    assert_approx_eq point_path[0].y, 0.0_f32
    assert_approx_eq point_path[1].y, 5.0_f32
    assert_approx_eq point_path[2].y, 10.0_f32
  end

  test "AStarGrid2D TypedArray[Vector2i] get_id_path and PackedVector2Array get_point_path (Issue #10)" do
    grid = Godot.create(Godot::AStarGrid2D)
    grid.region = Godot::Rect2i.new(0, 0, 5, 5)
    grid.cell_size = Godot::Vector2.new(16.0_f32, 16.0_f32)
    grid.diagonal_mode = Godot::AStarGrid2D::DiagonalMode::DiagonalModeNever
    grid.update

    id_path = grid.get_id_path(Godot::Vector2i.new(0, 0), Godot::Vector2i.new(3, 2))
    assert_eq id_path.size, 6_i64
    assert_eq id_path[0], Godot::Vector2i.new(0, 0)
    assert_eq id_path[5], Godot::Vector2i.new(3, 2)

    pt_path = grid.get_point_path(Godot::Vector2i.new(0, 0), Godot::Vector2i.new(3, 2))
    assert_eq pt_path.size, 6_i64
    assert_approx_eq pt_path[0].x, 0.0_f32
    assert_approx_eq pt_path[0].y, 0.0_f32
    assert_approx_eq pt_path[5].x, 48.0_f32
    assert_approx_eq pt_path[5].y, 32.0_f32

    # Dynamic Object#call returning Variant containing TypedArray / PackedVector2Array
    dyn_ids = grid.call("get_id_path", Godot::Vector2i.new(0, 0), Godot::Vector2i.new(2, 0)).as_array_of(Godot::Vector2i)
    assert_eq dyn_ids.size, 3_i64
    assert_eq dyn_ids[2], Godot::Vector2i.new(2, 0)

    dyn_pts = grid.call("get_point_path", Godot::Vector2i.new(0, 0), Godot::Vector2i.new(2, 0)).as_packed_vector2_array
    assert_eq dyn_pts.size, 3_i64
    assert_approx_eq dyn_pts[2].x, 32.0_f32
  end
end
