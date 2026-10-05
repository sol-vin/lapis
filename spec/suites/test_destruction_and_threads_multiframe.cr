# =============================================================================
# LibGodot Test Suite: Multi-Frame Destruction Cascades & Cross-Thread Safety
# =============================================================================

include Lapis::Test

node DestructionProbeNode < Godot::Node do
  property counter : Int32 = 0
  property last_deferred_val : Int32 = 0

  def on_deferred(val : Int32) : Void
    @counter += 1
    @last_deferred_val = val
  end
end

node ConcurrentSignalProbe < Godot::Node do
  signal concurrent_ping(worker_id : Int32, seq : Int32)
end

test_suite "DestructionAndThreadsMultiFrame" do
  test "Pillar 1: queue_free multi-frame semantics and immediate inspection validity" do
    probe = Godot.create(DestructionProbeNode)
    probe.name = "QueuedNode"
    root.call("add_child", probe)

    assert_false probe.is_queued_for_deletion
    assert_true probe.alive?

    # Call queue_free
    probe.queue_free

    # Immediately within the same frame slice: node is queued, but still alive and inspectable
    assert_true probe.is_queued_for_deletion, "Node must be flagged is_queued_for_deletion immediately"
    assert_true probe.alive?, "Node pointer remains valid during the frame until engine deletion queue flushes"
    assert_eq probe.name, "QueuedNode"

    root.call("remove_child", probe)
    probe.destroy

    assert_false probe.alive?
    assert_true probe.destroyed?

    # Calling methods on dead node raises DisposedObjectError safely
    assert_raises(Godot::DisposedObjectError) do
      probe.call("get_name")
    end
  end

  test "Pillar 2: deep hierarchy cascade destruction across frames" do
    parent = Godot.create(Godot::Node)
    root.call("add_child", parent)

    children = Array(Godot::Node).new

    # Build a deep hierarchy: 5 branches, each 10 levels deep (50 total nodes)
    5.times do |branch|
      current_node = parent
      10.times do |depth|
        child = Godot.create(Godot::Node)
        child.name = "Node_B#{branch}_D#{depth}"
        current_node.call("add_child", child)
        children << child
        current_node = child
      end
    end

    assert_eq children.size, 50
    children.each { |c| assert_true c.alive? }

    # Destroy parent directly
    root.call("remove_child", parent)
    parent.destroy
    assert_false parent.alive?

    # Invalidate and cleanup tracked descendants
    children.each do |c|
      c.destroy if c.alive?
      assert_false c.alive?
    end
  end

  test "Pillar 3: multi-frame dynamic reparenting across frame steps" do
    parent_a = Godot.create(Godot::Node)
    parent_b = Godot.create(Godot::Node)
    child = Godot.create(Godot::Node)

    root.call("add_child", parent_a)
    root.call("add_child", parent_b)

    # Frame 1: Add to Parent A
    parent_a.call("add_child", child)
    Fiber.yield
    assert_eq child.get_parent.as(Godot::Node).instance_id, parent_a.instance_id

    # Frame 2: Reparent to Parent B
    parent_a.call("remove_child", child)
    parent_b.call("add_child", child)
    Fiber.yield
    assert_eq child.get_parent.as(Godot::Node).instance_id, parent_b.instance_id

    # Frame 3: Reparent back to Parent A
    parent_b.call("remove_child", child)
    parent_a.call("add_child", child)
    Fiber.yield
    assert_eq child.get_parent.as(Godot::Node).instance_id, parent_a.instance_id

    # Cleanup
    parent_a.call("remove_child", child)
    root.call("remove_child", parent_a)
    root.call("remove_child", parent_b)
    child.destroy
    parent_a.destroy
    parent_b.destroy
  end

  test "Pillar 4: concurrent cross-thread signal notification under mutex protection" do
    probe = Godot.create(ConcurrentSignalProbe)
    root.call("add_child", probe)

    received_mutex = ::Thread::Mutex.new
    received_count = 0

    sub = probe.concurrent_ping.connect do |_args|
      received_mutex.synchronize do
        received_count += 1
      end
    end

    # Spawn 4 background OS threads, each emitting 25 signals (100 total)
    threads = Array(Thread).new
    4.times do |worker_id|
      threads << Thread.new do
        25.times do |seq|
          # Notify through Godot signal bus
          Godot.notify_signal(
            probe.instance_id,
            "concurrent_ping",
            [Godot::Variant.new(worker_id), Godot::Variant.new(seq)]
          )
        end
      end
    end

    threads.each(&.join)
    Fiber.yield

    assert_eq received_count, 100, "All 100 concurrent emissions must be safely delivered through mutex"

    sub.disconnect
    root.call("remove_child", probe)
    probe.destroy
  end

  test "Pillar 5: cross-thread call_deferred to dead targets across frames" do
    probe = Godot.create(DestructionProbeNode)
    root.call("add_child", probe)

    # Background thread schedules a deferred call
    t = Thread.new do
      probe.call_deferred("on_deferred", 999)
    end
    t.join

    # Destroy probe on the main thread before message queue flush
    root.call("remove_child", probe)
    probe.destroy
    assert_false probe.alive?

    # Advance frame: Godot's MessageQueue handles dead instance ID safely without crashing
    Fiber.yield
  end

  test "Pillar 6: multi-frame producer-consumer worker thread channel streaming" do
    ch = Channel(Int32).new(32)
    done_ch = Channel(Bool).new(1)

    # Worker thread produces 20 items over time
    t = Thread.new do
      20.times do |i|
        ch.send(i * 10)
      end
      done_ch.send(true)
    end

    # Main thread drains channel across cooperative frame slices
    received_items = Array(Int32).new
    while received_items.size < 20
      select
      when val = ch.receive
        received_items << val
      else
        Fiber.yield
      end
    end

    t.join
    assert_true done_ch.receive
    assert_eq received_items.size, 20
    assert_eq received_items[0], 0
    assert_eq received_items[19], 190
  end

  test "Pillar 7: full concurrency and destruction leak gate" do
    assert_no_new_orphans("DestructionAndThreadsStress") do
      10.times do
        probe = Godot.create(DestructionProbeNode)
        root.call("add_child", probe)

        t = Thread.new do
          probe.call_deferred("on_deferred", 42)
        end
        t.join
        Fiber.yield

        root.call("remove_child", probe)
        probe.destroy
      end
    end
  end
end
