# =============================================================================
# LibGodot Test Suite: Testing Apparatus Verification (Frames, Signals & Timeouts)
# =============================================================================

include Lapis::Test

test_suite "AsyncTesting" do
  test "skip_frames cooperatively steps idle process frames" do
  steps = 0
  spawn do
    3.times do
      steps += 1
      Fiber.yield
    end
  end
  skip_frames(3)
  assert_true steps >= 1, "Expected cooperative fibers to advance during skip_frames"
end

  test "skip_physics_frames cooperatively steps physics ticks" do
  steps = 0
  spawn do
    2.times do
      steps += 1
      Fiber.yield
    end
  end
  skip_physics_frames(2)
  assert_true steps >= 1, "Expected cooperative fibers to advance during skip_physics_frames"
end

  test "await_signal successfully resolves when signal is emitted" do
  node = Godot.create(Godot::Node)
  root.call("add_child", node)

  # Spawn delayed signal emission
  spawn do
    skip_frames(2)
    if node.alive?
      node.call("emit_signal", "tree_entered")
    end
  end

  args = await_signal(node, "tree_entered", timeout_sec: 2.0)
  assert_not_nil args

  root.call("remove_child", node)
  node.destroy
end

  test "await_signal raises TimeoutError when deadline is exceeded" do
  node = Godot.create(Godot::Node)

  # Signal that is never emitted must raise TimeoutError within 0.1s
  ex = assert_raises(TimeoutError) do
    await_signal(node, "non_existent_signal", timeout_sec: 0.1)
  end

  assert_true ex.message.not_nil!.includes?("Timed out after 0.1s"), "Error message should mention timeout duration"
  assert_true ex.message.not_nil!.includes?("non_existent_signal"), "Error message should mention signal name"

  node.destroy
end

  test "assert_emits validates signal firing within timeout window" do
  node = Godot.create(Godot::Node)
  root.call("add_child", node)

  assert_emits(node, "renamed", timeout_sec: 1.0) do
    node.call("set_name", "NewNodeName")
  end

  assert_eq node.get_name, "NewNodeName"
  root.call("remove_child", node)
  node.destroy
end

  test "assert_no_emit confirms silence during observation window" do
  node = Godot.create(Godot::Node)

  assert_no_emit(node, "renamed", duration_sec: 0.1) do
    # Do something unrelated that does not trigger renamed
    node.call("get_instance_id")
  end

  node.destroy
end

  test "SignalSpy records emission history, counts and parameters accurately" do
  node = Godot.create(Godot::Node)
  root.call("add_child", node)
  spy = SignalSpy.new(node, "renamed")

  assert_false spy.emitted?
  assert_eq spy.count, 0

  node.call("set_name", "FirstRename")
  node.call("set_name", "SecondRename")

  assert_true spy.emitted?
  assert_eq spy.count, 2

  spy.clear
  assert_false spy.emitted?
  assert_eq spy.count, 0

  spy.disconnect
  root.call("remove_child", node)
  node.destroy
end

  test "Assertion matchers: assert_between, assert_in_delta, assert_approx_eq" do
    assert_between(42, 10, 50)
    assert_between(3.14, 3.0, 4.0)

    assert_raises(AssertionError) do
      assert_between(100, 10, 50)
    end

    assert_in_delta(10.05, 10.0, 0.1)
    assert_approx_eq(1.0002_f32, 1.0001_f32, 0.001)
  end

  test "Extended comparison and range assertions: assert_ne, assert_gt, assert_not_between" do
    assert_ne 10, 20
    assert_gt 50, 20
    assert_gte 50, 50
    assert_lt 10, 20
    assert_lte 20, 20
    assert_not_between 5, 10, 20

    assert_raises(AssertionError) do
      assert_ne 10, 10
    end
    assert_raises(AssertionError) do
      assert_gt 10, 20
    end
    assert_raises(AssertionError) do
      assert_not_between 15, 10, 20
    end
  end

  test "Extended string and collection assertions" do
    assert_string_contains "Godot Engine Integration", "Engine"
    assert_string_starts_with "Godot Engine Integration", "Godot"
    assert_string_ends_with "Godot Engine Integration", "Integration"

    assert_empty [] of Int32
    assert_not_empty [1, 2, 3]

    assert_raises(AssertionError) do
      assert_string_contains "Hello World", "Missing"
    end
    assert_raises(AssertionError) do
      assert_empty [1]
    end
  end

  test "Object identity, types, and lifecycle assertions" do
    n1 = autofree(Godot.create(Godot::Node))
    n2 = autofree(Godot.create(Godot::Node))

    assert_same n1, n1
    assert_not_same n1, n2
    assert_is_a n1, Godot::Node
    assert_alive n1
    assert_not_freed n1

    n_dead = Godot.create(Godot::Node)
    n_dead.destroy
    assert_disposed n_dead
    assert_freed n_dead
  end

  test "Signal assertion helpers and SignalSpy integration" do
    emitter = autofree(Godot.create(Godot::Node))
    root.call("add_child", emitter)
    assert_has_signal emitter, "renamed"

    spy = SignalSpy.new(emitter, "renamed")
    assert_signal_not_emitted spy

    emitter.call("set_name", "TargetName")
    assert_signal_emitted spy
    assert_signal_emit_count spy, 1

    spy.disconnect
    root.call("remove_child", emitter)
  end

  test "autofree and autoqfree cleanly destroy nodes without leaking" do
    assert_no_leak(max_delta_objects: 0, name: "Autofree Cleanup") do
      node = autofree(Godot.create(Godot::Node))
      assert_alive node
      Lapis::Test.autofree_all
      assert_freed node
    end
  end

  test "assert_no_new_orphans validates scene tree hygiene" do
    assert_no_new_orphans do
      node = Godot.create(Godot::Node)
      root.call("add_child", node)
      root.call("remove_child", node)
      node.destroy
    end
  end

  test "simulate advances process ticks deterministically" do
    node = autofree(Godot.create(Godot::Node2D))
    root.call("add_child", node)
    simulate(node, frames: 3, delta: 0.016)
    root.call("remove_child", node)
  end

  test "InputFactory creates valid input event resources" do
    key_ev = autofree(InputFactory.key_down(Godot::Key::Enter))
    assert_not_nil key_ev
    assert_eq key_ev.keycode, Godot::Key::Enter.to_i64

    action_ev = autofree(InputFactory.action_down("ui_accept"))
    assert_not_nil action_ev
    assert_true action_ev.pressed
  end

  test "InputSender queues and dispatches input sequence" do
    sender = input_sender
    sender.action_down("ui_left").wait_frames(1).action_up("ui_left").send
  end

  test "pending and skip_if control flow" do
    # Verify skip_if with false condition continues normally
    skip_if(false, "Should not skip")

    # Verify assert_raises can catch SkipTestException and PendingTestException
    assert_raises(SkipTestException) do
      skip_if(true, "Deliberately skipped")
    end

    assert_raises(PendingTestException) do
      pending("Feature work in progress")
    end
  end

  test "parameterized speed limits", params: [10, 25, 50] do |node, speed|
    assert_gt speed, 0
    assert_lte speed, 100
  end

end

