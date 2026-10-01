# =============================================================================
# LibGodot Test Suite: Deferred Execution & Callbacks
# =============================================================================

require "../fixtures/test_target_nodes"

include Lapis::Test

test_suite "Deferred" do
  test "call_deferred dispatches method call cleanly" do
    target = PropertyTestTarget.new
    target.call_deferred("set_name", "DeferredNameUpdate")
    assert_not_nil target
    target.destroy
  end

  test "call_deferred accepts multiple typed arguments" do
    target = PropertyTestTarget.new
    target.call_deferred("emit_signal", "test_event_fired", 777)
    assert_not_nil target
    target.destroy
  end

  test "call_deferred on node hierarchy operation" do
    parent = Godot.create(Godot::Node)
    child = Godot.create(Godot::Node)
    parent.call_deferred("add_child", child)
    assert_not_nil parent
    child.destroy
    parent.destroy
  end
end
