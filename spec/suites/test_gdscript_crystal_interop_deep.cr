# =============================================================================
# LibGodot Test Suite: Deep GDScript & Crystal Interoperability
# =============================================================================
#
# Exhaustive cross-language boundary testing:
# - GDScript non-blocking channel select & asynchronous coroutine await_channel_select
# - WorkerThreadPool background producer to Crystal consumer
# - Dynamic property get/set and reflection across language boundaries
# - Bidirectional property manipulation between GDScript and Crystal
# - Dead-pointer protection across language boundaries
# =============================================================================

require "../fixtures/test_target_nodes"

include Lapis::Test

test_suite "GDScriptInteropDeep" do
  test "GDScript non-blocking select_channel_from_pair multiplexes multiple channels" do
    scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
    root = scene.not_nil!.instantiate

    ch1 = Godot::Channel.new(4)
    ch2 = Godot::Channel.new(4)

    # 1. Both empty -> GDScript select returns nil
    sel_empty = root.call_obj_as(Godot::Channel, "select_channel_from_pair", ch1, ch2)
    assert_nil sel_empty

    # 2. Push into ch2 -> GDScript select detects ch2
    ch2.send("Select_From_Ch2")
    sel_ready = root.call_obj_as(Godot::Channel, "select_channel_from_pair", ch1, ch2)
    assert_not_nil sel_ready
    assert_eq sel_ready.not_nil!.instance_id, ch2.instance_id

    # Verify received value recorded by GDScript
    last_val = root.call_str("get", "last_selected_channel_value")
    assert_eq last_val, "Select_From_Ch2"

    # Verify ch2 was consumed by GDScript
    assert_true ch2.empty?

    ch1.close
    ch2.close
    root.destroy
    scene.destroy
  end

  test "GDScript reactive multi-channel listener receives across channels" do
    scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
    root = scene.not_nil!.instantiate

    ch_a = Godot::Channel.new(4)
    ch_b = Godot::Channel.new(4)

    # GDScript sets up reactive listeners on both channels
    root.call("setup_channel_pair_listener", ch_a, ch_b)

    # Crystal sends into ch_b
    ch_b.send("AsyncSelectSuccess")

    # Allow signal to flush
    10.times { Fiber.yield }

    last_val = root.call_str("get", "last_channel_pair_val")
    last_id = root.call_i64("get", "last_channel_pair_id")

    assert_eq last_val, "AsyncSelectSuccess", "GDScript must reactively drain and record item"
    assert_eq last_id.to_u64!, ch_b.instance_id, "Recorded channel ID must match ch_b"
    assert_true ch_b.empty?, "ch_b must be drained by GDScript"

    ch_a.close
    ch_b.close
    root.destroy
    scene.destroy
  end

  test "GDScript WorkerThreadPool produces into GodotChannel drained by Crystal" do
    scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
    root = scene.not_nil!.instantiate

    ch = Godot::Channel.new(100)
    item_count = 50_i64

    # Start GDScript worker thread
    task_id = root.call_i64("start_worker_thread_channel_producer", ch, item_count, "WorkerPoolItem")
    assert_true task_id >= 0_i64

    # Wait for completion in GDScript cooperatively without blocking main loop
    start_wait = Time.instant
    while !root.call_bool("is_worker_task_completed", task_id)
      break if (Time.instant - start_wait).total_seconds > 5.0
      Fiber.yield
    end
    root.call("wait_for_worker_task", task_id)

    # Crystal drains all items
    drained = ch.drain_all
    assert_eq drained.size, item_count
    assert_eq drained.first.to_s, "WorkerPoolItem_0"
    assert_eq drained.last.to_s, "WorkerPoolItem_49"
    assert_true ch.empty?

    ch.close
    root.destroy
    scene.destroy
  end

  test "Cross-language node property reflection and dynamic mutation" do
    scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
    root = scene.not_nil!.instantiate

    target = Godot.create(GDScriptInteropTarget)
    root.add_child(target)

    # Initial value
    assert_eq target.crystal_greeting, "Hello from Crystal"

    # GDScript sets property on Crystal node
    ok = root.call_bool("set_property_val", target, "crystal_greeting", "GDScriptMutatedGreeting")
    assert_true ok

    # Crystal reads back property
    assert_eq target.crystal_greeting, "GDScriptMutatedGreeting"

    root.remove_child(target)
    target.destroy
    root.destroy
    scene.destroy
  end

  test "Bidirectional property manipulation between GDScript and Crystal" do
    scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
    root = scene.not_nil!.instantiate

    target = Godot.create(GDScriptInteropTarget)
    root.add_child(target)

    # GDScript reads exported property from Crystal node
    initial_count = root.call_i64("get_crystal_node_count", target)
    assert_eq initial_count, 100_i64

    # GDScript updates exported property on Crystal node
    updated = root.call_bool("set_crystal_node_count", target, 450_i64)
    assert_true updated

    # Crystal immediately sees updated value in memory
    assert_eq target.crystal_count, 450

    root.remove_child(target)
    target.destroy
    root.destroy
    scene.destroy
  end

  test "Dead pointer defense: GDScript frees node and Crystal safely detects disposed state" do
    scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
    root = scene.not_nil!.instantiate

    # Crystal creates node
    child_node = Godot.create(Godot::Node2D)
    child_id = child_node.instance_id
    assert_true child_node.alive?

    # Pass to GDScript which frees it
    freed = root.call_bool("destroy_node_from_gdscript", child_node)
    assert_true freed

    # Allow engine to process deferred free
    10.times { Fiber.yield }

    # Defensive Crystal wrapper checks
    assert_false Godot::Object.is_instance_id_valid(child_id), "Instance ID must no longer be valid in ObjectDB"
    assert_false child_node.alive?, "Crystal wrapper alive? must return false"
    assert_disposed child_node

    root.destroy
    scene.destroy
  end
end
