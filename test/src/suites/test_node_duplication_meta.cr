# =============================================================================
# LibGodot Test Suite: Node & Resource Duplication Flags and Metadata CRUD
# Replicating godot-rust's gd_duplicate_test.rs and godot's test_object.cpp
# =============================================================================

include Lapis::Test

test_suite "Duplication" do
  test "Node duplication with GROUPS flag preserves group membership" do
  node = Godot.create(Godot::Node2D)
  node.name = "GroupSourceNode"
  node.add_to_group("test_group_alpha")
  node.add_to_group("test_group_beta")

  assert_true node.is_in_group("test_group_alpha")
  assert_true node.is_in_group("test_group_beta")

  # 1. Duplicate with GROUPS flag
  groups_flag = Godot::Node::DuplicateFlags::DuplicateGroups.to_i64
  dup_grouped = Godot::Node2D.new(node.duplicate(groups_flag).pointer)

  assert_not_nil dup_grouped
  assert_true dup_grouped.is_in_group("test_group_alpha"), "Duplicate with GROUPS flag must keep group alpha"
  assert_true dup_grouped.is_in_group("test_group_beta"), "Duplicate with GROUPS flag must keep group beta"

  # 2. Duplicate without GROUPS flag (flags: 0)
  dup_ungrouped = Godot::Node2D.new(node.duplicate(0_i64).pointer)
  assert_not_nil dup_ungrouped
  assert_false dup_ungrouped.is_in_group("test_group_alpha"), "Duplicate without GROUPS flag must not retain group alpha"
  assert_false dup_ungrouped.is_in_group("test_group_beta"), "Duplicate without GROUPS flag must not retain group beta"

  dup_ungrouped.destroy
  dup_grouped.destroy
  node.destroy
end

  test "Node duplication preserves spatial transform properties" do
  source = Godot.create(Godot::Node2D)
  source.position = Godot::Vector2.new(123.0_f32, 456.0_f32)
  source.rotation = 1.57_f32
  source.scale = Godot::Vector2.new(2.5_f32, 3.0_f32)

  clone = Godot::Node2D.new(source.duplicate(0_i64).pointer)
  assert_approx_eq clone.position.x, 123.0_f32, 0.01
  assert_approx_eq clone.position.y, 456.0_f32, 0.01
  assert_approx_eq clone.rotation, 1.57_f32, 0.01
  assert_approx_eq clone.scale.x, 2.5_f32, 0.01
  assert_approx_eq clone.scale.y, 3.0_f32, 0.01

  clone.destroy
  source.destroy
end

  test "Node duplication preserves child hierarchy with unique instance IDs" do
  parent = Godot.create(Godot::Node2D)
  parent.name = "RootParent"
  child1 = Godot.create(Godot::Node2D)
  child1.name = "ChildOne"
  child1.position = Godot::Vector2.new(10.0_f32, 20.0_f32)
  child2 = Godot.create(Godot::Node2D)
  child2.name = "ChildTwo"
  parent.add_child(child1)
  parent.add_child(child2)

  # Duplicate entire subtree
  clone_parent = Godot::Node2D.new(parent.duplicate(0_i64).pointer)
  assert_not_nil clone_parent
  assert_eq clone_parent.get_child_count, 2_i64

  c1 = clone_parent.get_child(0_i64)
  c2 = clone_parent.get_child(1_i64)
  assert_not_nil c1
  assert_not_nil c2
  assert_eq c1.not_nil!.name, "ChildOne"
  assert_eq c2.not_nil!.name, "ChildTwo"
  assert_true c1.not_nil!.instance_id != child1.instance_id, "Cloned child must have unique instance ID"
  assert_true c2.not_nil!.instance_id != child2.instance_id, "Cloned child must have unique instance ID"

  clone_parent.destroy
  parent.destroy
end

  test "Object metadata CRUD operations across diverse Variant types" do
  obj = Godot.create(Godot::Node2D)

  assert_false obj.has_meta("health")
  obj.call("set_meta", "health", 100_i64)
  assert_true obj.has_meta("health")
  assert_eq obj.call_i64("get_meta", "health"), 100_i64

  # Complex Variant metadata
  obj.call("set_meta", "label", "SpawnPointAlpha")
  assert_eq obj.call_str("get_meta", "label"), "SpawnPointAlpha"

  # Remove metadata
  obj.remove_meta("health")
  assert_false obj.has_meta("health")

  # Removing nonexistent metadata does not error or crash
  obj.remove_meta("nonexistent_meta_key")

  obj.destroy
end

  test "Node duplication preserves and isolates object metadata" do
  source = Godot.create(Godot::Node2D)
  source.call("set_meta", "health", 100_i64)
  source.call("set_meta", "team", "Blue")

  clone = Godot::Node2D.new(source.duplicate(0_i64).pointer)
  assert_true clone.has_meta("health"), "Cloned node must inherit metadata keys"
  assert_true clone.has_meta("team"), "Cloned node must inherit string metadata"
  assert_eq clone.call_i64("get_meta", "health"), 100_i64
  assert_eq clone.call_str("get_meta", "team"), "Blue"

  # Mutating clone metadata does not affect source
  clone.call("set_meta", "health", 50_i64)
  assert_eq source.call_i64("get_meta", "health"), 100_i64, "Source metadata must remain unchanged"
  assert_eq clone.call_i64("get_meta", "health"), 50_i64, "Clone metadata must be mutated independently"

  clone.destroy
  source.destroy
end

end
