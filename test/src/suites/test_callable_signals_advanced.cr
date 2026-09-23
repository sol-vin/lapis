# =============================================================================
# LibGodot Test Suite: Advanced Signal Dynamics, One-Shot & Dynamic Unsubscribe
# Replicating godot-rust's callable_test.rs and signal_disconnect_test.rs
# =============================================================================

include Lapis::Test

node AdvancedSignalTargetNode < Godot::Node do
  signal action_triggered(code : Int32, tag : String)
  signal numeric_alert(value : Float64)

  def fire_action(code : Int32, tag : String) : Void
    emit_action_triggered(code, tag)
  end

  def fire_numeric(value : Float64) : Void
    emit_numeric_alert(value)
  end
end

test_suite "CallableAdv" do
  test "One-shot signal connection fires exactly once and unregisters" do
  node = Godot.create(AdvancedSignalTargetNode)
  fire_count = 0
  last_code = 0

  node.on_action_triggered_once do |code, _tag|
    fire_count += 1
    last_code = code
  end

  # First emission: listener should execute
  node.fire_action(101, "FirstRun")
  assert_eq fire_count, 1
  assert_eq last_code, 101

  # Second emission: one-shot listener must not fire
  node.fire_action(102, "SecondRun")
  assert_eq fire_count, 1, "One-shot listener must not execute a second time"
  assert_eq last_code, 101

  node.destroy
end

  test "Active self-unsubscribe during signal callback preserves subscriber array" do
  node = Godot.create(AdvancedSignalTargetNode)
  fire_count = 0

  sub = nil.as(Godot::SignalSubscription?)
  sub = node.on_numeric_alert do |val|
    fire_count += 1
    sub.not_nil!.unsubscribe
  end

  # First emission: fires and self-unsubscribes
  node.fire_numeric(3.14159)
  assert_eq fire_count, 1

  # Second emission: must not fire
  node.fire_numeric(2.71828)
  assert_eq fire_count, 1, "Unsubscribed callback must not fire again"

  node.destroy
end

  test "Multiple concurrent listeners: selective unsubscription leaves sibling intact" do
  node = Godot.create(AdvancedSignalTargetNode)
  count_a = 0
  count_b = 0

  sub_a = node.on_action_triggered do |_code, _tag|
    count_a += 1
  end

  sub_b = node.on_action_triggered do |_code, _tag|
    count_b += 1
  end

  # Both fire on emission 1
  node.fire_action(1, "Emit1")
  assert_eq count_a, 1
  assert_eq count_b, 1

  # Unsubscribe A only
  sub_a.unsubscribe

  # Emission 2: Only B should fire
  node.fire_action(2, "Emit2")
  assert_eq count_a, 1, "Unsubscribed listener A must not increment"
  assert_eq count_b, 2, "Active listener B must continue receiving emissions"

  sub_b.unsubscribe
  node.destroy
end

  test "Object disconnect clears all active signal subscriptions" do
    node = Godot.create(AdvancedSignalTargetNode)
    count = 0

    node.on_action_triggered do |_code, _tag|
      count += 1
    end

    node.fire_action(10, "Test")
    assert_eq count, 1

    node.disconnect("action_triggered")

    node.fire_action(20, "Test2")
    assert_eq count, 1, "No listeners should remain after node.disconnect"

    node.destroy
  end

  test "Signal ergonomics: << operator, once helper, 0-arg blocks, and connection queries" do
    node = Godot.create(AdvancedSignalTargetNode)
    sig = node.action_triggered

    assert_false sig.connected?
    assert_eq sig.connection_count, 0

    # 1. Test operator << with typed args
    typed_fired = 0
    sub_stream = (sig << ->(code : Int32, tag : String) {
      typed_fired += code
    })
    assert_true sig.connected?
    assert_eq sig.connection_count, 1

    # 2. Test 0-argument block on a signal with arguments
    no_arg_fired = 0
    sub_no_arg = sig.connect do
      no_arg_fired += 1
    end
    assert_eq sig.connection_count, 2

    # 3. Test `once` shorthand with 0 arguments
    once_fired = 0
    sig.once do
      once_fired += 1
    end
    assert_eq sig.connection_count, 3

    # 4. Test 0-arg node-level `on_action_triggered` helper
    node_on_fired = 0
    sub_node = node.on_action_triggered do
      node_on_fired += 1
    end
    assert_eq sig.connection_count, 4

    # First emission
    node.fire_action(5, "Ergo")
    assert_eq typed_fired, 5
    assert_eq no_arg_fired, 1
    assert_eq once_fired, 1
    assert_eq node_on_fired, 1
    # `once` should have auto-unregistered
    assert_eq sig.connection_count, 3

    # Second emission
    node.fire_action(10, "Ergo2")
    assert_eq typed_fired, 15
    assert_eq no_arg_fired, 2
    assert_eq once_fired, 1, "once listener should not fire a second time"
    assert_eq node_on_fired, 2

    # Cleanup
    sub_stream.unsubscribe
    sub_no_arg.unsubscribe
    sub_node.unsubscribe
    assert_false sig.connected?
    assert_eq sig.connection_count, 0

    node.destroy
  end
end
