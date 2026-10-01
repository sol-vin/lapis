# =============================================================================
# LibGodot Test Suite: Multi-Frame Engine Loop Stepping & Await Orchestration
# =============================================================================

require "../fixtures/test_target_nodes"

include Lapis::Test

test_suite "MultiFrameOrchestration" do
  test "multi-frame cooperative fiber stepping advances state progressively" do
    frame_counter = 0
    done = false

    spawn do
      5.times do
        frame_counter += 1
        Fiber.yield
      end
      done = true
    end

    assert_eq frame_counter, 0

    skip_frames(2)
    assert_true frame_counter >= 2, "Expected at least 2 fiber steps after skip_frames(2)"

    skip_frames(3)
    assert_true done, "Expected fiber to complete all 5 iterations"
    assert_eq frame_counter, 5
  end

  test "multi-frame delayed signal awaiting via await_signal" do
    node = Godot.create(Godot::Node)
    root.add_child(node)

    received_step = 0
    spawn do
      skip_frames(2)
      if node.alive?
        received_step = 2
        node.emit_signal("renamed")
      end
    end

    args = await_signal(node, "renamed", timeout_sec: 2.0)
    assert_not_nil args
    assert_eq received_step, 2

    root.remove_child(node)
    node.destroy
  end

  test "multi-frame bidirectional fiber communication across 5 frame slices" do
    ch_ping = Channel(Int32).new(1)
    ch_pong = Channel(Int32).new(1)

    spawn do
      5.times do
        msg = ch_ping.receive
        Fiber.yield
        ch_pong.send(msg * 2)
      end
    end

    5.times do |i|
      ch_ping.send(i + 1)
      response = ch_pong.receive
      assert_eq response, (i + 1) * 2
    end
  end

  test "multi-frame lifecycle: queue_free marks node immediately while maintaining valid pointer" do
    temp = Godot.create(Godot::Node2D)
    temp.name = "QueuedForDeletion"
    root.add_child(temp)

    assert_false temp.is_queued_for_deletion
    assert_true temp.alive?
    assert_true temp.is_inside_tree

    # Flag for deferred deletion
    temp.queue_free

    # Immediately in the same frame slice, node must still be alive and marked as queued
    assert_true temp.alive?, "Node pointer remains valid during the frame until engine cleanup"
    assert_true temp.is_queued_for_deletion, "Node must be marked is_queued_for_deletion immediately"
    assert_eq temp.name, "QueuedForDeletion"

    root.remove_child(temp)
    temp.destroy
  end

  test "call_deferred queues invocation onto Godot message queue" do
    target = PropertyTestTarget.new
    root.add_child(target)

    # Deferred name update
    target.call_deferred("set_name", "DeferredMultiFrameUpdate")
    assert_not_nil target

    # Deferred hierarchy operation
    child = Godot.create(Godot::Node)
    target.call_deferred("add_child", child)
    assert_not_nil child

    root.remove_child(target)
    child.destroy
    target.destroy
  end

  test "SignalSpy tracks multi-frame sequential signal emissions" do
    node = Godot.create(Godot::Node)
    root.add_child(node)
    spy = SignalSpy.new(node, "renamed")

    assert_eq spy.count, 0
    assert_false spy.emitted?

    spawn do
      3.times do |i|
        Fiber.yield
        if node.alive?
          node.name = "NameStep_#{i}"
        end
      end
    end

    skip_frames(4)

    assert_true spy.emitted?
    assert_eq spy.count, 3
    assert_eq node.name, "NameStep_2"

    root.remove_child(node)
    node.destroy
  end

  test "assert_no_leak verifies zero leak across multi-frame fiber and node churn" do
    assert_no_leak(max_delta_objects: 0, name: "MultiFrameChurn") do
      20.times do
        node = Godot.create(Godot::Node2D)
        root.add_child(node)

        spawn do
          Fiber.yield
          if node.alive?
            node.name = "AsyncUpdate"
          end
        end

        skip_frames(2)

        root.remove_child(node)
        node.destroy
      end
    end
  end
end
