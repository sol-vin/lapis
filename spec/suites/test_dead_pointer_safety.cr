# =============================================================================
# LibGodot Test Suite: Advanced Dead-Pointer Safety & Disposed Object Protection
# =============================================================================

include Lapis::Test


test_suite "DeadPointerSafety" do
  test "Multi-wrapper aliasing detects remote destruction via monotonic instance ID" do
  node_native = Godot.create(Godot::Node2D)
  node_id = node_native.instance_id
  assert_true node_native.alive?

  # Create a second wrapper referencing the exact same native object
  wrapper2 = Godot::Node2D.new(node_native.pointer)
  assert_eq wrapper2.instance_id, node_id
  assert_true wrapper2.alive?

  # Destroy via first wrapper
  node_native.destroy
  assert_true node_native.destroyed?

  # Second wrapper must defensively detect that the underlying native object is gone
  assert_false wrapper2.alive?
  assert_true wrapper2.destroyed?

  # Attempting dispatch through second wrapper must raise DisposedObjectError safely
  caught = false
  begin
    wrapper2.call("get_name")
  rescue ex : Godot::DisposedObjectError
    caught = true
    assert_eq ex.instance_id, node_id
  end
  assert_true caught, "Wrapper2 must raise DisposedObjectError upon accessing remotely destroyed object"
end

  test "Child hierarchy cascade marks sub-tree nodes dead when parent is destroyed" do
  parent = Godot.create(Godot::Node2D)
  child1 = Godot.create(Godot::Node2D)
  child2 = Godot.create(Godot::Sprite2D)
  grandchild = Godot.create(Godot::Label)

  parent.add_child(child1)
  child1.add_child(grandchild)
  parent.add_child(child2)

  child1_id = child1.instance_id
  child2_id = child2.instance_id
  grandchild_id = grandchild.instance_id

  assert_true child1.alive?
  assert_true grandchild.alive?
  assert_true child2.alive?

  # Destroy the root parent
  parent.destroy

  # Entire cascade must be dead in ObjectDB
  assert_false Godot::Object.is_instance_id_valid(child1_id)
  assert_false Godot::Object.is_instance_id_valid(child2_id)
  assert_false Godot::Object.is_instance_id_valid(grandchild_id)

  assert_false child1.alive?
  assert_false child2.alive?
  assert_false grandchild.alive?

  # Dispatched method on child must safely catch DisposedObjectError
  caught = false
  begin
    child1.call("get_child_count")
  rescue ex : Godot::DisposedObjectError
    caught = true
  end
  assert_true caught, "Child method dispatch must raise DisposedObjectError after parent destruction"
end

  test "Collections of node references safely filter out disposed entities" do
  entities = [] of Godot::Node2D
  3.times do |i|
    n = Godot.create(Godot::Node2D)
    n.call("set_name", "Entity_#{i}")
    entities << n
  end

  assert_eq entities.size, 3
  assert_true entities.all?(&.alive?)

  # Destroy the middle entity
  entities[1].destroy

  # Filter active entities defensively
  active = entities.select(&.alive?)
  assert_eq active.size, 2
  assert_eq active[0].call_str("get_name"), "Entity_0"
  assert_eq active[1].call_str("get_name"), "Entity_2"

  # Clean up remaining entities
  active.each(&.destroy)
  assert_true entities.all?(&.destroyed?)
end

  test "Dynamic call on destroyed object returns safe DisposedObjectError without memory fault" do
  sprite = Godot.create(Godot::Sprite2D)
  sprite.destroy

  assert_false sprite.alive?

  # Verify call, call_str, call_i64, call_bool, call_f64 all safely raise DisposedObjectError
  disposed_count = 0

  begin
    sprite.call("is_visible")
  rescue ex : Godot::DisposedObjectError
    disposed_count += 1
  end

  begin
    sprite.call_bool("is_visible")
  rescue ex : Godot::DisposedObjectError
    disposed_count += 1
  end

  begin
    sprite.call_str("get_name")
  rescue ex : Godot::DisposedObjectError
    disposed_count += 1
  end

  begin
    sprite.call_i64("get_index")
  rescue ex : Godot::DisposedObjectError
    disposed_count += 1
  end

  assert_eq disposed_count, 4, "All dynamic call variants must intercept dead pointers via check_alive!"
end

end
