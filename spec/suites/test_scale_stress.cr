# =============================================================================
# LibGodot Test Suite: Massive Scale Stress & Performance (100 & 1,000 Nodes)
# =============================================================================

require "../fixtures/test_target_nodes"

include Lapis::Test

test_suite "Stress" do
  test "Spawning and moving 100 Node2D nodes in 2D grid" do
    container = Godot.create(Godot::Node2D)
    container.name = "GridContainer100"

    nodes = Array(Godot::Node2D).new(100)
    100.times do |i|
      n = Godot.create(Godot::Node2D)
      n.name = "Node2D_#{i}"
      x = (i % 10).to_f32 * 32.0_f32
      y = (i // 10).to_f32 * 32.0_f32
      n.position = Godot::Vector2.new(x, y)
      container.add_child(n)
      nodes << n
    end

    assert_eq container.get_child_count, 100_i64
    assert_approx_eq nodes[55].position.x, 160.0_f32
    assert_approx_eq nodes[55].position.y, 160.0_f32

    # Move all 100 nodes
    nodes.each do |n|
      n.position = Godot::Vector2.new(n.position.x + 10.0_f32, n.position.y + 10.0_f32)
    end
    assert_approx_eq nodes[55].position.x, 170.0_f32

    # Clean batch disposal
    nodes.each do |n|
      container.remove_child(n)
      n.destroy
    end
    assert_eq container.get_child_count, 0_i64
    container.destroy
  end

  test "Spawning, transforming, and freeing 1,000 Node3D instances" do
    arena = Godot.create(Godot::Node3D)
    arena.name = "StressArena1000"

    nodes = Array(Godot::Node3D).new(1000)
    1000.times do |i|
      n = Godot.create(Godot::Node3D)
      n.name = "Entity3D_#{i}"
      x = (i % 10).to_f32 * 2.0_f32
      y = ((i // 10) % 10).to_f32 * 2.0_f32
      z = (i // 100).to_f32 * 2.0_f32
      n.position = Godot::Vector3.new(x, y, z)
      arena.add_child(n)
      nodes << n
    end

    assert_eq arena.get_child_count, 1000_i64

    # Animate all 1,000 nodes with trigonometric wave
    nodes.each_with_index do |n, idx|
      rad = idx.to_f64 * 0.01
      offset_y = Math.sin(rad).to_f32 * 5.0_f32
      n.position = Godot::Vector3.new(n.position.x, n.position.y + offset_y, n.position.z)
    end

    # Batch free all 1,000 nodes
    nodes.each do |n|
      arena.remove_child(n)
      n.destroy
    end
    assert_eq arena.get_child_count, 0_i64
    arena.destroy
  end
end
