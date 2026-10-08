# =============================================================================
# LibGodot Test Suite: Deep Hierarchy & Ergonomics Multi-Level Stress
# =============================================================================

require "../fixtures/test_target_nodes"

include Lapis::Test

test_suite "HierarchyErgonomics" do
  test "add_child supports custom internal modes and automatic unique naming" do
    parent = Godot.create(Godot::Node)
    c1 = Godot.create(Godot::Node)
    c2 = Godot.create(Godot::Node)
    c1.name = "WorkerNode"
    c2.name = "WorkerNode"

    parent.add_child(c1, force_readable_name: true)
    parent.add_child(c2, force_readable_name: true)

    assert_eq parent.get_child_count, 2_i64
    assert_eq c1.name, "WorkerNode"
    # Godot auto-renames identical sibling names to preserve uniqueness
    assert_true c2.name != c1.name, "Expected sibling name to be auto-disambiguated"
    assert_true c2.name.includes?("WorkerNode"), "Expected auto-renamed sibling to maintain name fragment"

    parent.destroy
  end

  test "tree traversal ergonomics: find_child and find_children with patterns" do
    tree_root = Godot.create(Godot::Node2D)
    tree_root.name = "WorldRoot"

    enemies = Godot.create(Godot::Node2D)
    enemies.name = "Enemies"
    tree_root.add_child(enemies)

    goblin = Godot.create(Godot::Node2D)
    goblin.name = "Goblin_01"
    enemies.add_child(goblin)

    orc = Godot.create(Godot::Node2D)
    orc.name = "Orc_Boss"
    enemies.add_child(orc)

    # 1. find_child direct lookup (recursive = true)
    found_goblin = tree_root.find_child("Goblin_01", true, false)
    assert_not_nil found_goblin
    assert_eq found_goblin.not_nil!.name, "Goblin_01"

    # 2. find_child pattern lookup
    found_boss = tree_root.find_child("*_Boss", true, false)
    assert_not_nil found_boss
    assert_eq found_boss.not_nil!.name, "Orc_Boss"

    # 3. get_children collection traversal
    children = enemies.get_children
    assert_eq children.size, 2_i64

    # 4. Typed NodePath resolution
    direct_boss = tree_root.get_node("Enemies/Orc_Boss")
    assert_not_nil direct_boss
    assert_eq direct_boss.not_nil!.name, "Orc_Boss"

    tree_root.destroy
  end

  test "deep recursive hierarchy (50 levels) accumulates transforms and traverses correctly" do
    levels = 50
    nodes = Array(Godot::Node2D).new(levels)

    # Build 50-level chain: node_0 -> node_1 -> node_2 ... -> node_49
    levels.times do |i|
      node = Godot.create(Godot::Node2D)
      node.name = "DeepNode_#{i}"
      node.position = Godot::Vector2.new(2.0_f32, 1.0_f32)
      node.rotation = 0.02_f32
      node.scale = Godot::Vector2.new(1.005_f32, 1.005_f32)

      if i > 0
        nodes[i - 1].add_child(node)
      end
      nodes << node
    end

    top_parent = nodes.first
    leaf = nodes.last

    # 1. Verify upward parent traversal from leaf to root takes exactly 49 hops
    hops = 0
    current : Godot::Node? = leaf
    while p = current.try(&.get_parent?)
      hops += 1
      current = p
    end
    assert_eq hops, levels - 1

    # 2. Verify global transform of leaf is calculated without arithmetic error or crash
    leaf_global = leaf.global_position
    assert_true leaf_global.x > 50.0_f32, "Expected accumulated X position across 50 nodes to be > 50, got #{leaf_global.x}"
    assert_true leaf_global.y > 25.0_f32, "Expected accumulated Y position across 50 nodes to be > 25, got #{leaf_global.y}"

    # 3. Clean destruction of root destroys entire 50-level chain
    top_parent.destroy
  end

  test "cross-branch reparenting preserves global transforms accurately" do
    world = Godot.create(Godot::Node2D)
    world.name = "World"

    branch_a = Godot.create(Godot::Node2D)
    branch_a.name = "BranchA"
    branch_a.position = Godot::Vector2.new(100.0_f32, 50.0_f32)
    branch_a.rotation = 0.5_f32
    world.add_child(branch_a)

    branch_b = Godot.create(Godot::Node2D)
    branch_b.name = "BranchB"
    branch_b.position = Godot::Vector2.new(300.0_f32, -100.0_f32)
    branch_b.rotation = -0.25_f32
    world.add_child(branch_b)

    movable = Godot.create(Godot::Node2D)
    movable.name = "MovableEntity"
    movable.position = Godot::Vector2.new(20.0_f32, 10.0_f32)
    branch_a.add_child(movable)

    initial_global_pos = movable.global_position

    # Reparent with keep_global_transform = true
    movable.reparent(branch_b, true)

    assert_eq movable.get_parent.not_nil!.name, "BranchB"
    assert_eq branch_a.get_child_count, 0_i64
    assert_eq branch_b.get_child_count, 1_i64

    # Verify global position is preserved to within floating-point tolerance
    new_global_pos = movable.global_position
    diff_x = (new_global_pos.x - initial_global_pos.x).abs
    diff_y = (new_global_pos.y - initial_global_pos.y).abs
    assert_true diff_x < 0.01_f32, "Global position X drift (#{diff_x}) exceeded tolerance"
    assert_true diff_y < 0.01_f32, "Global position Y drift (#{diff_y}) exceeded tolerance"

    world.destroy
  end

  test "sibling reordering via move_child updates child index and traversal order" do
    container = Godot.create(Godot::Node)
    a = Godot.create(Godot::Node)
    b = Godot.create(Godot::Node)
    c = Godot.create(Godot::Node)
    d = Godot.create(Godot::Node)
    a.name = "Node_A"
    b.name = "Node_B"
    c.name = "Node_C"
    d.name = "Node_D"

    container.add_child(a)
    container.add_child(b)
    container.add_child(c)
    container.add_child(d)

    assert_eq a.get_index, 0_i64
    assert_eq b.get_index, 1_i64
    assert_eq c.get_index, 2_i64
    assert_eq d.get_index, 3_i64

    # Move 'd' to the very front (index 0)
    container.move_child(d, 0_i64)
    assert_eq d.get_index, 0_i64
    assert_eq a.get_index, 1_i64
    assert_eq b.get_index, 2_i64
    assert_eq c.get_index, 3_i64

    # Move 'b' to the end (index 3)
    container.move_child(b, 3_i64)
    assert_eq d.get_index, 0_i64
    assert_eq a.get_index, 1_i64
    assert_eq c.get_index, 2_i64
    assert_eq b.get_index, 3_i64

    # Child array must match updated order
    children = container.get_children
    assert_eq children[0].name, "Node_D"
    assert_eq children[1].name, "Node_A"
    assert_eq children[2].name, "Node_C"
    assert_eq children[3].name, "Node_B"

    container.destroy
  end

  test "replace_by swaps node in-place while transferring children and groups" do
    root_node = Godot.create(Godot::Node2D)
    old_node = Godot.create(Godot::Node2D)
    new_node = Godot.create(Godot::Node2D)
    sub_child = Godot.create(Godot::Node2D)

    old_node.name = "OriginalTarget"
    old_node.add_to_group("targets")
    new_node.name = "ReplacementTarget"
    sub_child.name = "NestedChild"

    root_node.add_child(old_node)
    old_node.add_child(sub_child)

    assert_eq root_node.get_child(0).name, "OriginalTarget"
    assert_eq old_node.get_child_count, 1_i64

    # Perform in-place replacement (keep_data = true transfers groups & children)
    old_node.replace_by(new_node, true)

    assert_eq root_node.get_child_count, 1_i64
    assert_eq root_node.get_child(0).name, "ReplacementTarget"
    assert_eq new_node.get_child_count, 1_i64
    assert_eq new_node.get_child(0).name, "NestedChild"
    assert_true new_node.is_in_group("targets")

    old_node.destroy
    root_node.destroy
  end

  test "orphan tree assembly and single-call mounting into SceneTree" do
    # Assemble an orphan subtree of 20 nodes
    orphan_root = Godot.create(Godot::Node2D)
    orphan_root.name = "OrphanRoot"

    5.times do |i|
      branch = Godot.create(Godot::Node2D)
      branch.name = "Branch_#{i}"
      orphan_root.add_child(branch)

      3.times do |j|
        leaf = Godot.create(Godot::Node2D)
        leaf.name = "Leaf_#{i}_#{j}"
        branch.add_child(leaf)
      end
    end

    assert_false orphan_root.is_inside_tree
    assert_eq orphan_root.get_child_count, 5_i64

    # Mount onto live test runner root
    root.add_child(orphan_root)
    assert_true orphan_root.is_inside_tree

    # Verify all nested children are now inside tree
    leaf_0_0 = orphan_root.get_node("Branch_0/Leaf_0_0")
    assert_not_nil leaf_0_0
    assert_true leaf_0_0.not_nil!.is_inside_tree

    # Unmount and cleanly destroy
    root.remove_child(orphan_root)
    assert_false orphan_root.is_inside_tree
    orphan_root.destroy
  end

  test "tree duplication produces deep-copied independent hierarchy" do
    original = Godot.create(Godot::Node2D)
    original.name = "Original"
    child = Godot.create(Godot::Node2D)
    child.name = "Child"
    child.position = Godot::Vector2.new(15.0_f32, 25.0_f32)
    original.add_child(child)

    # Duplicate entire subtree
    dup = original.duplicate(Godot::Node::DuplicateFlags::DuplicateSignals.value | Godot::Node::DuplicateFlags::DuplicateGroups.value)
    dup_node = Godot::Node2D.new(dup.pointer)

    assert_not_nil dup_node
    assert_eq dup_node.get_child_count, 1_i64
    assert_eq dup_node.get_child(0).name, "Child"

    # Modify duplicate child position; verify original remains unchanged
    dup_child = Godot::Node2D.new(dup_node.get_child(0).pointer)
    dup_child.position = Godot::Vector2.new(99.0_f32, 88.0_f32)

    assert_eq child.position.x, 15.0_f32
    assert_eq child.position.y, 25.0_f32
    assert_eq dup_child.position.x, 99.0_f32
    assert_eq dup_child.position.y, 88.0_f32

    original.destroy
    dup_node.destroy
  end

  test "assert_no_leak proves zero memory leak across 100 hierarchy churn iterations" do
    assert_no_leak(max_delta_objects: 0, name: "HierarchyChurn") do
      50.times do
        parent = Godot.create(Godot::Node2D)
        parent.name = "ChurnParent"

        c1 = Godot.create(Godot::Node2D)
        c2 = Godot.create(Godot::Node2D)
        c1.name = "C1"
        c2.name = "C2"

        parent.add_child(c1)
        parent.add_child(c2)

        # Reparent c2 under c1
        c2.reparent(c1, false)

        # Swap ordering
        c1.move_child(c2, 0_i64)

        # Destroy entire tree
        parent.destroy
      end
    end
  end

  test "get_nodes wildcard and globstar scene traversal with batch operations" do
    root = Godot.create(Godot::Node2D)
    root.name = "ArenaRoot"

    spawn_container = Godot.create(Godot::Node2D)
    spawn_container.name = "Spawns"
    root.add_child(spawn_container)

    s1 = Godot.create(Godot::Node2D)
    s1.name = "Spawner_Alpha"
    spawn_container.add_child(s1)

    s2 = Godot.create(Godot::Node2D)
    s2.name = "Spawner_Beta"
    spawn_container.add_child(s2)

    m1 = Godot.create(Godot::Marker2D)
    m1.name = "TargetMarker"
    s1.add_child(m1)

    # 1. Single wildcard matching direct children
    spawners = spawn_container.get_nodes("Spawner_*")
    assert_eq spawners.size, 2
    assert_true spawners.all? { |s| s.name.starts_with?("Spawner_") }

    # 2. Mid-path wildcard matching
    markers = root.get_nodes("Spawns/*/TargetMarker")
    assert_eq markers.size, 1
    assert_eq markers.first.name, "TargetMarker"

    # 3. Recursive globstar matching
    all_descendants = root.get_nodes("**")
    assert_eq all_descendants.size, 4

    # 4. Typed query
    typed_markers = root.get_nodes("Spawns/**/TargetMarker", Godot::Marker2D)
    assert_eq typed_markers.size, 1
    assert_true typed_markers.first.is_a?(Godot::Marker2D)

    # 5. Ancestry and sibling navigation
    assert_eq m1.ancestor(Godot::Node2D).name, "Spawner_Alpha"
    assert_eq s2.previous_sibling?.not_nil!.name, "Spawner_Alpha"
    assert_eq s1.next_sibling?.not_nil!.name, "Spawner_Beta"
    assert_eq s1.siblings.size, 1
    assert_eq s1.siblings.first.name, "Spawner_Beta"

    # 6. Streaming operations via each_node
    root.each_node("Spawns/*", Godot::Node2D) do
      add_to_group("active_spawners")
    end
    assert_true s1.in_group?(:active_spawners)
    assert_true s2.in_group?(:active_spawners)

    root.each_node("Spawns/*", Godot::CanvasItem, &.hide)
    assert_false s1.visible
    assert_false s2.visible

    root.each_node("Spawns/*", Godot::CanvasItem, &.show)
    assert_true s1.visible
    assert_true s2.visible

    # 7. Wildcard indexer query returning nil when result array would have been empty
    assert_true root["Spawns/*/TargetMarker", Godot::Marker2D]?.is_a?(Godot::Marker2D)
    assert_nil root["Spawns/*/NonExistent", Godot::Marker2D]?
    assert_nil root["Spawns/*/TargetMarker", Godot::Sprite2D]?
    assert_nil root["Spawns/*/TargetMarker", Array(Godot::Sprite2D)]?

    root.destroy
  end
end
