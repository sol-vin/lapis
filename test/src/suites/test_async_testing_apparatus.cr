# =============================================================================
# LibGodot Test Suite: Testing Apparatus Verification (Frames, Signals & Timeouts)
# =============================================================================

test_async_testing "skip_frames cooperatively steps idle process frames" do
  steps = 0
  spawn do
    3.times do
      steps += 1
      Fiber.yield
    end
  end
  TestFramework.skip_frames(3)
  TestFramework.assert_true steps >= 1, "Expected cooperative fibers to advance during skip_frames"
end

test_async_testing "skip_physics_frames cooperatively steps physics ticks" do
  steps = 0
  spawn do
    2.times do
      steps += 1
      Fiber.yield
    end
  end
  TestFramework.skip_physics_frames(2)
  TestFramework.assert_true steps >= 1, "Expected cooperative fibers to advance during skip_physics_frames"
end

test_async_testing "await_signal successfully resolves when signal is emitted" do
  node = Godot.create(Godot::Node)
  root.call("add_child", node)

  # Spawn delayed signal emission
  spawn do
    TestFramework.skip_frames(2)
    if node.alive?
      node.call("emit_signal", "tree_entered")
    end
  end

  args = TestFramework.await_signal(node, "tree_entered", timeout_sec: 2.0)
  TestFramework.assert_not_nil args

  root.call("remove_child", node)
  node.destroy
end

test_async_testing "await_signal raises TimeoutError when deadline is exceeded" do
  node = Godot.create(Godot::Node)

  # Signal that is never emitted must raise TimeoutError within 0.1s
  ex = TestFramework.assert_raises(TestFramework::TimeoutError) do
    TestFramework.await_signal(node, "non_existent_signal", timeout_sec: 0.1)
  end

  TestFramework.assert_true ex.message.not_nil!.includes?("Timed out after 0.1s"), "Error message should mention timeout duration"
  TestFramework.assert_true ex.message.not_nil!.includes?("non_existent_signal"), "Error message should mention signal name"

  node.destroy
end

test_async_testing "assert_emits validates signal firing within timeout window" do
  node = Godot.create(Godot::Node)
  root.call("add_child", node)

  TestFramework.assert_emits(node, "renamed", timeout_sec: 1.0) do
    node.call("set_name", "NewNodeName")
  end

  TestFramework.assert_eq node.get_name, "NewNodeName"
  root.call("remove_child", node)
  node.destroy
end

test_async_testing "assert_no_emit confirms silence during observation window" do
  node = Godot.create(Godot::Node)

  TestFramework.assert_no_emit(node, "renamed", duration_sec: 0.1) do
    # Do something unrelated that does not trigger renamed
    node.call("get_instance_id")
  end

  node.destroy
end

test_async_testing "SignalSpy records emission history, counts and parameters accurately" do
  node = Godot.create(Godot::Node)
  root.call("add_child", node)
  spy = TestFramework::SignalSpy.new(node, "renamed")

  TestFramework.assert_false spy.emitted?
  TestFramework.assert_eq spy.count, 0

  node.call("set_name", "FirstRename")
  node.call("set_name", "SecondRename")

  TestFramework.assert_true spy.emitted?
  TestFramework.assert_eq spy.count, 2

  spy.clear
  TestFramework.assert_false spy.emitted?
  TestFramework.assert_eq spy.count, 0

  spy.disconnect
  root.call("remove_child", node)
  node.destroy
end

test_async_testing "Assertion matchers: assert_between, assert_in_delta, assert_approx_eq" do
  TestFramework.assert_between(42, 10, 50)
  TestFramework.assert_between(3.14, 3.0, 4.0)

  TestFramework.assert_raises(TestFramework::AssertionError) do
    TestFramework.assert_between(100, 10, 50)
  end

  TestFramework.assert_in_delta(10.05, 10.0, 0.1)
  TestFramework.assert_approx_eq(1.0002_f32, 1.0001_f32, 0.001)
end
