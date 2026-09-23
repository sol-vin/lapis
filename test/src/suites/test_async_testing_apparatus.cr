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

end
