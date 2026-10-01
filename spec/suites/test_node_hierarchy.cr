# =============================================================================
# LibGodot Test Suite: Node Hierarchy, Tree Traversal & NodePaths
# =============================================================================

require "../fixtures/test_target_nodes"

include Lapis::Test

test_suite "Nodes" do
  test "add_child establishes parent-child relationship" do
    parent = Godot.create(Godot::Node)
    parent.name = "TestParentNode"
    child = Godot.create(Godot::Node)
    child.name = "TestChildNode"

    parent.add_child(child)
    assert_eq parent.get_child_count, 1_i64
    assert_not_nil child.get_parent
    assert_eq child.get_parent.not_nil!.name, "TestParentNode"
    parent.destroy
  end

  test "remove_child decouples child into orphan state" do
    parent = Godot.create(Godot::Node)
    child = Godot.create(Godot::Node)
    child.name = "OrphanTarget"

    parent.add_child(child)
    assert_eq parent.get_child_count, 1_i64

    parent.remove_child(child)
    assert_eq parent.get_child_count, 0_i64
    assert_nil child.get_parent?
    child.destroy
    parent.destroy
  end

  test "reparent relocates child to new parent" do
    p1 = Godot.create(Godot::Node2D)
    p1.name = "Parent1"
    p2 = Godot.create(Godot::Node2D)
    p2.name = "Parent2"
    child = Godot.create(Godot::Node2D)
    child.name = "MovableChild"

    p1.add_child(child)
    assert_eq child.get_parent.not_nil!.name, "Parent1"

    child.reparent(p2, true)
    assert_eq child.get_parent.not_nil!.name, "Parent2"
    assert_eq p1.get_child_count, 0_i64
    assert_eq p2.get_child_count, 1_i64
    child.destroy
    p1.destroy
    p2.destroy
  end

  test "get_child and get_child_count accurately index children" do
    container = Godot.create(Godot::Node)
    c1 = Godot.create(Godot::Node)
    c1.name = "First"
    c2 = Godot.create(Godot::Node)
    c2.name = "Second"
    c3 = Godot.create(Godot::Node)
    c3.name = "Third"

    container.add_child(c1)
    container.add_child(c2)
    container.add_child(c3)

    assert_eq container.get_child_count, 3_i64
    assert_eq container.get_child(0).name, "First"
    assert_eq container.get_child(1).name, "Second"
    assert_eq container.get_child(2).name, "Third"
    container.destroy
  end

  test "queue_free flags node for deletion" do
    temp_node = Godot.create(Godot::Node)
    temp_node.name = "ToFree"
    assert_false temp_node.is_queued_for_deletion

    temp_node.queue_free
    assert_true temp_node.is_queued_for_deletion
    temp_node.destroy
  end

  test "is_inside_tree accurately reflects tree membership" do
    orphan = Godot.create(Godot::Node)
    assert_false orphan.is_inside_tree

    if !root.pointer.null?
      root.add_child(orphan)
      assert_true orphan.is_inside_tree
      root.remove_child(orphan)
      assert_false orphan.is_inside_tree
    end
    orphan.destroy
  end

  test "get_node retrieves existing child and nested path" do
    target = root.find_child("ToolTester2D") || root
    if child2d = target.get_node?("Child2D")
      assert_not_nil child2d
      assert_eq child2d.name, "Child2D"

      if marker = target.get_node?("Child2D/Marker2D")
        assert_not_nil marker
        assert_eq marker.name, "Marker2D"
      end
    end
  end

  test "get_node? returns nil for non-existent node" do
    missing = root.get_node?("DefinitelyNonExistentNode12345")
    assert_nil missing
  end

  test "get_node raises exception when node is not found" do
    caught = false
    begin
      root.get_node("GhostNode_Should_Fail_987")
    rescue ex : Exception
      caught = true
    end
    assert_true caught, "get_node should raise when node does not exist"
  end

  test "get_node_as casts to Crystal node class" do
    target = root.find_child("ToolTester2D") || root
    if target.get_node?("Child2D")
      casted = target.get_node_as("Child2D", Godot::Node2D)
      assert_not_nil casted
      assert_true casted.is_a?(Godot::Node2D)
    end
  end

  test "find_child locates node anywhere in subtree" do
    found = root.find_child("Marker2D") || root.find_child("Marker3D")
    if found.nil?
      sub = Godot.create(Godot::Node)
      sub.name = "DynamicSub"
      target = Godot.create(Godot::Node)
      target.name = "DynamicTarget"
      sub.add_child(target)
      root.add_child(sub)
      found = root.find_child("DynamicTarget")
    end
    assert_not_nil found
  end

  test "node_path! macro constructs valid NodePath" do
    np = node_path!("Child2D/Marker2D")
    assert_not_nil np
  end

  test "relative path traversal navigates upward with .." do
    target = root.find_child("ToolTester2D") || root
    if child = target.get_node?("Child2D")
      parent_via_path = child.get_node?("..")
      assert_not_nil parent_via_path
      assert_eq parent_via_path.not_nil!.name, target.name
    end
  end

  test "Pattern A: subscript indexer self[String, NodePath, Type] and prefixes" do
    parent = Godot.create(Godot::Node2D)
    parent.name = "ErgoParent"
    child = Godot.create(Godot::Node2D)
    child.name = "ErgoChild"
    parent.add_child(child)

    # String indexer
    c1 = parent["ErgoChild"]
    assert_eq c1.name, "ErgoChild"

    # Prefix indexer with $
    c2 = parent["$ErgoChild"]
    assert_eq c2.name, "ErgoChild"

    # NodePath indexer
    np = node_path!("ErgoChild")
    c3 = parent[np]
    assert_eq c3.name, "ErgoChild"

    # Typed indexer (path, type)
    c4 = parent["ErgoChild", Godot::Node2D]
    assert_true c4.is_a?(Godot::Node2D)

    # Safe indexer []?
    assert_nil parent["NonExistentNode"]?
    assert_nil parent["$NonExistentNode"]?
    assert_nil parent["%NonExistentNode"]?
    assert_not_nil parent["ErgoChild"]?
    assert_not_nil parent["$ErgoChild"]?

    child.destroy
    parent.destroy
  end

  test "Pattern B: operator / and % traversal" do
    parent = Godot.create(Godot::Node2D)
    parent.name = "TreeRoot"
    sub = Godot.create(Godot::Node2D)
    sub.name = "Entities"
    leaf = Godot.create(Godot::Node2D)
    leaf.name = "Actor"
    sub.add_child(leaf)
    parent.add_child(sub)

    # / operator chain with String
    res = parent / "Entities" / "Actor"
    assert_eq res.name, "Actor"

    res_path = parent / "$Entities/Actor"
    assert_eq res_path.name, "Actor"

    # % operator for scene unique name (dynamic fallback)
    res_uniq = parent % "Actor"
    assert_eq res_uniq.name, "Actor"

    res_uniq_percent = parent % "%Actor"
    assert_eq res_uniq_percent.name, "Actor"

    # % operator with official unique_name_in_owner and owner registration
    leaf2 = Godot.create(Godot::Node2D)
    leaf2.name = "UniqueActor"
    leaf2.unique_name_in_owner = true
    sub.add_child(leaf2)
    leaf2.owner = parent

    res_owner_uniq = parent % "UniqueActor"
    assert_eq res_owner_uniq.name, "UniqueActor"

    leaf2.destroy
    leaf.destroy
    sub.destroy
    parent.destroy
  end

  test "Pattern C: type-inferred lookups, TypeCastError, and unique_as" do
    parent = Godot.create(Godot::Node2D)
    parent.name = "TreeRoot"
    node2d = Godot.create(Godot::Node2D)
    node2d.name = "Node2D"
    node2d.unique_name_in_owner = true
    parent.add_child(node2d)
    node2d.owner = parent

    # Type-inferred lookup: self[Type]
    typed_child = parent[Godot::Node2D]
    assert_true typed_child.is_a?(Godot::Node2D)
    assert_eq typed_child.name, "Node2D"

    # Type-inferred safe lookup: self[Type]?
    assert_not_nil parent[Godot::Node2D]?
    assert_nil parent[Godot::Camera3D]?

    # Type mismatch safe lookup: self[path, WrongType]? returns nil
    assert_nil parent["Node2D", Godot::Camera3D]?

    # Type mismatch get_node_as raises TypeCastError
    caught_type_cast = false
    begin
      parent.get_node_as("Node2D", Godot::Camera3D)
    rescue ex : TypeCastError
      caught_type_cast = true
    end
    assert_true caught_type_cast, "get_node_as should raise TypeCastError on type mismatch"

    # Missing node raises NodeNotFoundError
    caught_not_found = false
    begin
      parent["Ghost"]
    rescue ex : Godot::NodeNotFoundError
      caught_not_found = true
    end
    assert_true caught_not_found, "subscript indexer should raise NodeNotFoundError"

    # Typed / and % operators
    slash_typed = parent / Godot::Node2D
    assert_true slash_typed.is_a?(Godot::Node2D)

    pct_typed = parent % Godot::Node2D
    assert_true pct_typed.is_a?(Godot::Node2D)

    # node_as and node_as?
    assert_true parent.node_as("Node2D", Godot::Node2D).is_a?(Godot::Node2D)
    assert_not_nil parent.node_as?("Node2D", Godot::Node2D)
    assert_nil parent.node_as?("Node2D", Godot::Camera3D)

    # unique_as and unique_as?
    assert_true parent.unique_as("Node2D", Godot::Node2D).is_a?(Godot::Node2D)
    assert_nil parent.unique_as?("Node2D", Godot::Camera3D)
    assert_nil parent.unique_as?("NonExistent", Godot::Node2D)

    # String unique_as test with matching identifier
    hud_bar = Godot.create(Godot::Node2D)
    hud_bar.name = "HealthBar"
    hud_bar.unique_name_in_owner = true
    parent.add_child(hud_bar)
    hud_bar.owner = parent

    assert_true parent.unique_as("HealthBar", Godot::Node2D).is_a?(Godot::Node2D)
    assert_not_nil parent.unique_as?("HealthBar", Godot::Node2D)
    hud_bar.destroy

    node2d.destroy
    parent.destroy
  end
end
