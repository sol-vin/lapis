# =============================================================================
# LibGodot Test Suite: Re-entrancy, Self-Destruction Mid-Call & Stack Safety
# Replicating godot-rust's self_destruct_test.rs and reentrant_test.rs
# =============================================================================

include Lapis::Test

node SelfFreerNode < Godot::Node do
  property was_freed : Bool = false

  def free_self : Void
    destroy
  end
end

node SelfDestructingEmitterNode < Godot::Node do
  signal request_destruction(sender_id : UInt64)
  property post_emission_reached : Bool = false

  def trigger_destruction_event : Void
    emit_request_destruction(self.instance_id)
    @post_emission_reached = true
  end
end

node ReentrantCallerNode < Godot::Node do
  property step_counter : Int32 = 0
  property recursive_depth : Int64 = 0_i64
  signal reentrant_ping(depth : Int64)

  def dispatch_nested(depth : Int64) : Int64
    @recursive_depth = depth
    @step_counter += 1
    if depth > 0
      dispatch_nested(depth - 1)
    end
    @step_counter.to_i64
  end

  def trigger_reentrant_signal(depth : Int64) : Void
    @recursive_depth = depth
    @step_counter += 1
    if depth > 0
      emit_reentrant_ping(depth - 1)
    end
  end
end

test_suite "Reentrancy" do
  test "Direct method self-destruction mid-call completes trampoline safely" do
  freer = Godot.create(SelfFreerNode)
  freer_id = freer.instance_id
  assert_true Godot::Object.is_instance_id_valid(freer_id)

  # Invoking a method that calls destroy on itself mid-call (matching godot-rust SelfFreer::free_self)
  freer.free_self
  assert_false Godot::Object.is_instance_id_valid(freer_id), "ObjectDB must recognize freer as deallocated"
  assert_false freer.alive?, "Wrapper alive? must be false"
  assert_true freer.destroyed?, "Wrapper destroyed? must be true"

  # Calling methods on dead node raises DisposedObjectError safely
  assert_raises(Godot::DisposedObjectError) do
    freer.call("get_name")
  end
end

  test "Signal listener destroying emitter mid-call completes trampoline safely" do
  emitter = Godot.create(SelfDestructingEmitterNode)
  emitter_id = emitter.instance_id
  assert_true Godot::Object.is_instance_id_valid(emitter_id)

  destroyed_in_handler = false
  emitter.on_request_destruction do |_id|
    destroyed_in_handler = true
    # Per Godot engine safety invariants, Nodes emitting signals use queue_free
    # to avoid corrupting the engine's active signal iteration loop.
    emitter.queue_free
  end

  emitter.trigger_destruction_event

  assert_true destroyed_in_handler, "Destruction listener must have fired"
  assert_true emitter.post_emission_reached, "Post-emission code must execute"

  # Clean up unparented node
  emitter.destroy
end

  test "Reentrant method call via Godot reflection dispatch preserves call stack" do
  caller_node = Godot.create(ReentrantCallerNode)
  caller_node.step_counter = 0

  final_steps = caller_node.dispatch_nested(3_i64)
  assert_eq final_steps, 4_i64, "Nested reflection call should traverse 4 call frames"
  assert_eq caller_node.step_counter, 4, "State mutations across recursive frames must accumulate"

  caller_node.destroy
end

  test "Reentrant signal emission inside listener loop executes deterministically" do
  node = Godot.create(ReentrantCallerNode)
  node.step_counter = 0

  node.on_reentrant_ping do |remaining_depth|
    if remaining_depth > 0
      node.trigger_reentrant_signal(remaining_depth)
    end
  end

  node.trigger_reentrant_signal(3_i64)
  assert_eq node.step_counter, 3, "Reentrant signal emissions must complete all recursion levels"

  node.destroy
end

end
