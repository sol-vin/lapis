# =============================================================================
# LibGodot Test Suite: Thread Safety Enforcement & SceneTree Invariant Guards
# =============================================================================

require "../fixtures/test_target_nodes"

include Lapis::Test

test_suite "ThreadSafety" do
  test "add_child on active SceneTree node from Thread.new raises Godot::ThreadAffinityError" do
    parent = Godot.create(Godot::Node)
    child = Godot.create(Godot::Node)

    Godot::ThreadSafety.scope = Godot::ThreadSafety::Scope::AllNodes

    caught_error : Godot::ThreadAffinityError? = nil
    t = Thread.new do
      begin
        parent.add_child(child)
      rescue ex : Godot::ThreadAffinityError
        caught_error = ex
      end
    end
    t.join

    assert_not_nil caught_error, "add_child from background thread must raise ThreadAffinityError"
    if err = caught_error
      assert_eq err.operation, "add_child"
      assert_eq err.target_class, "Node"
      assert_true err.calling_context.includes?("Thread.new")
      assert_true err.message.not_nil!.includes?("Thread Affinity Violation")
    end

    Godot::ThreadSafety.scope = Godot::ThreadSafety::Scope::TreeOnly
    child.destroy
    parent.destroy
  end

  test "add_child from Fiber::ExecutionContext::Parallel worker raises Godot::ThreadAffinityError" do
    parent = Godot.create(Godot::Node)
    child = Godot.create(Godot::Node)

    Godot::ThreadSafety.scope = Godot::ThreadSafety::Scope::AllNodes

    worker_pool = Fiber::ExecutionContext::Parallel.new("PhysicsWorkers", maximum: 1)
    ch = Channel(Godot::ThreadAffinityError?).new(1)

    worker_pool.spawn(name: "EntitySpawner") do
      begin
        parent.add_child(child)
        ch.send(nil)
      rescue ex : Godot::ThreadAffinityError
        ch.send(ex)
      end
    end

    err = ch.receive
    assert_not_nil err, "add_child from parallel ExecutionContext must raise ThreadAffinityError"
    if e = err
      assert_eq e.operation, "add_child"
      assert_true e.calling_context.includes?("EntitySpawner")
      assert_true e.calling_context.includes?("PhysicsWorkers")
    end

    Godot::ThreadSafety.scope = Godot::ThreadSafety::Scope::TreeOnly
    child.destroy
    parent.destroy
  end

  test "remove_child from Thread.new raises Godot::ThreadAffinityError" do
    parent = Godot.create(Godot::Node)
    child = Godot.create(Godot::Node)
    parent.add_child(child)

    Godot::ThreadSafety.scope = Godot::ThreadSafety::Scope::AllNodes

    caught_error : Godot::ThreadAffinityError? = nil
    t = Thread.new do
      begin
        parent.remove_child(child)
      rescue ex : Godot::ThreadAffinityError
        caught_error = ex
      end
    end
    t.join

    assert_not_nil caught_error, "remove_child from background thread must raise ThreadAffinityError"

    Godot::ThreadSafety.scope = Godot::ThreadSafety::Scope::TreeOnly
    parent.remove_child(child)
    child.destroy
    parent.destroy
  end

  test "reparent from Thread.new raises Godot::ThreadAffinityError" do
    p1 = Godot.create(Godot::Node)
    p2 = Godot.create(Godot::Node)
    child = Godot.create(Godot::Node)
    p1.add_child(child)

    Godot::ThreadSafety.scope = Godot::ThreadSafety::Scope::AllNodes

    caught_error : Godot::ThreadAffinityError? = nil
    t = Thread.new do
      begin
        child.reparent(p2)
      rescue ex : Godot::ThreadAffinityError
        caught_error = ex
      end
    end
    t.join

    assert_not_nil caught_error, "reparent from background thread must raise ThreadAffinityError"

    Godot::ThreadSafety.scope = Godot::ThreadSafety::Scope::TreeOnly
    p1.remove_child(child)
    child.destroy
    p1.destroy
    p2.destroy
  end

  test "add_child on the Main Thread succeeds cleanly without exception" do
    parent = Godot.create(Godot::Node)
    child = Godot.create(Godot::Node)

    parent.add_child(child)
    assert_eq parent.get_child_count, 1_i64
    assert_eq child.get_parent.not_nil!.pointer, parent.pointer

    parent.remove_child(child)
    child.destroy
    parent.destroy
  end

  test "defer_add_child queues child addition via Godot MessageQueue safely" do
    parent = Godot.create(Godot::Node)
    child = Godot.create(Godot::Node)

    t = Thread.new do
      parent.defer_add_child(child)
    end
    t.join

    assert_true parent.alive?
    child.destroy
    parent.destroy
  end

  test "defer_queue_free queues deletion via Godot MessageQueue safely" do
    node = Godot.create(Godot::Node)

    t = Thread.new do
      node.defer_queue_free
    end
    t.join

    assert_true node.alive?
    node.destroy
  end

  test "TreeOnly scope allows off-thread orphan node tree assembly before parenting" do
    Godot::ThreadSafety.scope = Godot::ThreadSafety::Scope::TreeOnly

    orphan_parent = Godot.create(Godot::Node)
    orphan_child = Godot.create(Godot::Node)

    raised = false
    t = Thread.new do
      begin
        orphan_parent.add_child(orphan_child)
      rescue
        raised = true
      end
    end
    t.join

    assert_false raised, "Orphan detached tree construction off-thread must be permitted under TreeOnly scope"
    assert_eq orphan_parent.get_child_count, 1_i64

    orphan_parent.remove_child(orphan_child)
    orphan_child.destroy
    orphan_parent.destroy
  end

  test "queue_free off-thread respects Policy::Raise and Policy::Defer" do
    node = Godot.create(Godot::Node)

    Godot::ThreadSafety.policy = Godot::ThreadSafety::Policy::Defer
    t1 = Thread.new do
      node.queue_free
    end
    t1.join

    assert_true node.alive?

    Godot::ThreadSafety.policy = Godot::ThreadSafety::Policy::Raise
    node.destroy
  end
end
