# =============================================================================
# LibGodot Test Suite: Lifecycle, Destruction, Dead-Pointer Safety & Leak Auditing
# =============================================================================

include Lapis::Test

macro test_lifecycle(name, &block)
  Registry.register("Lifecycle", {{name}}) do |node|
	root = node
	{{block.body}}
  end
end

test_lifecycle "Object creation tracks valid 64-bit instance ID in ObjectDB" do
  obj = Godot.create(Godot::Node2D)
  assert_true obj.alive?
  assert_false obj.destroyed?

  inst_id = obj.instance_id
  assert_true inst_id > 0_u64

  # Query Godot's ObjectDB directly
  assert_true Godot::Object.is_instance_id_valid(inst_id)

  obj.destroy
  assert_true obj.destroyed?
  assert_false Godot::Object.is_instance_id_valid(inst_id)
end

test_lifecycle "Immediate destruction via #destroy invalidates pointer and engine ID" do
  timer = Godot.create(Godot::Timer)
  timer_id = timer.instance_id
  assert_true Godot::Object.is_instance_id_valid(timer_id)

  timer.destroy
  assert_true timer.destroyed?
  assert_false timer.alive?
  assert_false Godot::Object.is_instance_id_valid(timer_id)
end

test_lifecycle "Dead-pointer access raises DisposedObjectError safely instead of segfaulting" do
  dummy = Godot.create(Godot::Node)
  dummy_id = dummy.instance_id
  dummy.destroy

  assert_false dummy.alive?

  caught = false
  begin
    dummy.call("get_name")
  rescue ex : Godot::DisposedObjectError
    caught = true
    assert_eq ex.instance_id, dummy_id
  end
  assert_true caught, "Expected DisposedObjectError when accessing deleted node"
end

test_lifecycle "GDScript destroying node causes Crystal to detect dead pointer and raise DisposedObjectError" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
  interop_root = scene.instantiate

  # Create a Crystal worker node
  victim = Godot.create(Godot::Node2D)
  victim.name = "VictimNode"
  victim_id = victim.instance_id
  interop_root.add_child(victim)

  assert_true victim.alive?
  assert_true Godot::Object.is_instance_id_valid(victim_id)

  # Hand node over to GDScript to be freed via target.free()
  freed_by_gd = interop_root.call_bool("destroy_node_from_gdscript", victim)
  assert_true freed_by_gd

  # Engine ObjectDB should reflect deletion immediately
  assert_false Godot::Object.is_instance_id_valid(victim_id)
  assert_false victim.alive?
  assert_true victim.destroyed?

  # Attempting to call methods on the GDScript-freed node safely raises DisposedObjectError
  caught = false
  begin
    victim.call("get_position")
  rescue ex : Godot::DisposedObjectError
    caught = true
  end
  assert_true caught, "Calling GDScript-freed node must raise DisposedObjectError, not segfault"

  interop_root.destroy
  scene.destroy
end

test_lifecycle "Node hierarchy lifecycle: add_child, reparent, remove_child, and queue_free" do
  parent = Godot.create(Godot::Node2D)
  parent.name = "LifecycleParent"
  child = Godot.create(Godot::Node2D)
  child.name = "LifecycleChild"

  assert_nil child.get_parent?

  parent.add_child(child)
  assert_eq parent.get_child_count, 1_i64
  assert_eq child.get_parent.name, "LifecycleParent"

  parent.remove_child(child)
  assert_eq parent.get_child_count, 0_i64
  assert_nil child.get_parent?

  child.queue_free
  assert_true child.is_queued_for_deletion
  child.destroy

  parent.destroy
end

test_lifecycle "Node get_children, each_child, and get_children_as hierarchy traversal" do
  parent = Godot.create(Godot::Node2D)
  parent.name = "ParentNode"

  child1 = Godot.create(Godot::Node2D)
  child1.name = "ChildNode1"

  child2 = Godot.create(Godot::Sprite2D)
  child2.name = "ChildSprite2"

  assert_true parent.get_children.empty?

  parent.add_child(child1)
  parent.add_child(child2)

  assert_eq parent.get_child_count, 2_i64

  children = parent.get_children
  assert_eq children.size, 2
  assert_eq children[0].name, "ChildNode1"
  assert_eq children[1].name, "ChildSprite2"

  children_no_args = parent.get_children(false)
  assert_eq children_no_args.size, 2

  # Test each_child zero-allocation streaming
  names = [] of String
  parent.each_child do |c|
    names << c.name
  end
  assert_eq names, ["ChildNode1", "ChildSprite2"]

  # Test get_children_as typed filtering
  sprites = parent.get_children_as(Godot::Sprite2D)
  assert_eq sprites.size, 1
  assert_eq sprites[0].name, "ChildSprite2"

  # Test get_child_as
  as_sprite = parent.get_child_as(Godot::Sprite2D, 1)
  assert_not_nil as_sprite
  assert_eq as_sprite.not_nil!.name, "ChildSprite2"

  # Clean up
  child1.destroy
  child2.destroy
  parent.destroy
end

test_lifecycle "RefCounted atomic lifecycle: reference, unreference, and automated deallocation" do
  rc = Godot.create(Godot::RefCounted)
  rc_id = rc.instance_id

  assert_true Godot::Object.is_instance_id_valid(rc_id)
  # Native RefCounted starts with refcount 1
  assert_eq rc.get_reference_count, 1_i64

  # Increment ref count
  rc.reference
  assert_eq rc.get_reference_count, 2_i64

  # Decrement back
  rc.unreference
  assert_eq rc.get_reference_count, 1_i64

  # Final unreference drops refcount to 0, returning true indicating it should be freed
  should_free = rc.unreference
  assert_true should_free
  rc.destroy
  assert_false Godot::Object.is_instance_id_valid(rc_id)
end

test_lifecycle "Quantitative zero-leak verification using Performance monitors and GC.collect" do
  # Query SceneTree node count directly via native typed method
  get_node_count = -> {
    root.get_tree.get_node_count
  }

  baseline_nodes = get_node_count.call

  # Spawn 100 nodes in Crystal and attach to SceneTree
  batch = Array(Godot::Node2D).new(100)
  100.times do |i|
    n = Godot.create(Godot::Node2D)
    n.name = "LeakCheckNode_#{i}"
    root.add_child(n)
    batch << n
  end

  # Verify engine object count increased
  active_nodes = get_node_count.call
  assert_true active_nodes >= baseline_nodes + 100_i64

  # Cleanly detach and destroy all 100 nodes
  batch.each do |n|
    root.remove_child(n)
    n.destroy
  end
  batch.clear

  # Trigger Crystal Boehm GC cycle to reclaim wrappers
  GC.collect

  # Verify node count returned to baseline
  final_nodes = get_node_count.call
  assert_eq final_nodes, baseline_nodes, "Node count must return to baseline after destruction (zero leaks)"
end

test_lifecycle "Engine value equality (==), hashing, and null safety" do
  node_a = Godot.create(Godot::Node2D)
  # Wrap the exact same native engine pointer in a second distinct Crystal wrapper
  node_b = Godot::Node2D.new(node_a.pointer)

  assert_true node_a.alive?
  assert_true node_b.alive?
  assert_false (node_a == nil)
  assert_false (nil == node_a)

  # Value equality
  assert_true (node_a == node_b), "Distinct wrappers of the same engine instance must compare equal via =="
  assert_eq node_a.hash, node_b.hash, "Wrappers of the same engine instance must have identical hash codes"

  # Set deduplication
  set = Set(Godot::Object).new
  set.add(node_a)
  set.add(node_b)
  assert_eq set.size, 1, "Set must deduplicate multiple wrappers referring to the same engine instance"

  # Hash map lookup
  map = Hash(Godot::Object, String).new
  map[node_a] = "found"
  assert_eq map[node_b]?, "found", "Hash lookup with equivalent wrapper must retrieve stored value"

  # Null / uninitialized wrapper
  null_obj = Godot::Object.new
  assert_false null_obj.alive?, "Uninitialized wrapper must report alive? == false"
  assert_false null_obj.is_valid?, "Uninitialized wrapper must report is_valid? == false"
  assert_nil null_obj.if_alive, "Uninitialized wrapper if_alive must return nil"
  assert_true (null_obj == nil), "Null wrapper must equal nil"
  assert_true (nil == null_obj), "Nil must equal null wrapper symmetrically"

  node_a.destroy
end
