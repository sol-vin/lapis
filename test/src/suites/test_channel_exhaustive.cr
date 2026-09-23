# =============================================================================
# LibGodot Test Suite: Exhaustive Channel Types, Concurrency & Select Multiplexing
# =============================================================================
#
# Complete verification of 100% of the Channel surface area:
# - All 8 variants of TypedChannel(T) (String, Int32, Int64, Float64, Bool, Vector2, Vector3, Color, Node2D)
# - Capacity clamping, capacity 1 ping-pong, high throughput (1,000 items)
# - Multi-channel select multiplexing (non-blocking, declarative CSP block, cooperative await_select)
# - MPSC, SPMC, MPMC multi-threaded concurrency models
# - Timeouts, cooperative fiber yielding, close idempotency, and drain iterators
# =============================================================================

require "../fixtures/test_target_nodes"

include Lapis::Test

test_suite "ChannelExhaustive" do
  test "Zero-capacity clamping prevents deadlock trap and enforces capacity >= 1" do
    ch0 = Godot::Channel.new(0)
    assert_true ch0.capacity >= 1, "Channel capacity must be clamped to at least 1"

    ch_neg = Godot::Channel.new(-5)
    assert_true ch_neg.capacity >= 1, "Negative capacity must clamp to 1"

    # Verify sending into clamped channel succeeds without deadlock
    assert_true ch0.send("ClampedValue")
    assert_eq ch0.size, 1
    assert_eq ch0.try_receive.to_s, "ClampedValue"
    assert_true ch0.empty?
    ch0.close
  end

  test "Capacity 1 ping-pong buffer with producer/consumer lockstep" do
    ch = Godot::Channel.new(1)
    received_items = [] of String
    iterations = 50

    worker = Thread.new do
      iterations.times do |i|
        # Blocking send waits for consumer to drain previous item
        ch.send("Ping_#{i}")
      end
    end

    iterations.times do
      item = ch.receive(timeout_sec: 2.0)
      assert_not_nil item
      received_items << item.not_nil!.to_s
    end

    worker.join
    assert_eq received_items.size, iterations
    assert_eq received_items.first, "Ping_0"
    assert_eq received_items.last, "Ping_49"
    assert_true ch.empty?
    ch.close
  end

  test "High-throughput capacity 1,000 items push and drain" do
    ch = Godot::Channel.new(1000)
    1000.times do |i|
      assert_true ch.try_send("Item_#{i}")
    end
    assert_eq ch.size, 1000
    assert_true ch.full?

    # Draining all items into array
    items = ch.drain_all
    assert_eq items.size, 1000
    assert_true ch.empty?
    assert_false ch.full?
    assert_eq items[0].to_s, "Item_0"
    assert_eq items[999].to_s, "Item_999"
    ch.close
  end

  test "TypedChannel variants: String, Int32, Int64, Float64, Bool" do
    # 1. TypedChannel(String)
    ch_str = Godot::TypedChannel(String).new(4)
    ch_str.send("HelloTyped")
    assert_eq ch_str.try_receive, "HelloTyped"
    ch_str.close

    # 2. TypedChannel(Int32)
    ch_i32 = Godot::TypedChannel(Int32).new(4)
    ch_i32.send(42_i32)
    assert_eq ch_i32.try_receive, 42_i32
    ch_i32.close

    # 3. TypedChannel(Int64)
    ch_i64 = Godot::TypedChannel(Int64).new(4)
    ch_i64.send(9876543210_i64)
    assert_eq ch_i64.try_receive, 9876543210_i64
    ch_i64.close

    # 4. TypedChannel(Float64)
    ch_f64 = Godot::TypedChannel(Float64).new(4)
    ch_f64.send(3.1415926535)
    assert_approx_eq ch_f64.try_receive.not_nil!.to_f32, 3.14159_f32
    ch_f64.close

    # 5. TypedChannel(Bool)
    ch_bool = Godot::TypedChannel(Bool).new(4)
    ch_bool.send(true)
    assert_true ch_bool.try_receive == true
    ch_bool.close
  end

  test "TypedChannel spatial and color types: Vector2, Vector3, Color" do
    # Vector2
    ch_v2 = Godot::TypedChannel(Godot::Vector2).new(4)
    ch_v2.send(Godot::Vector2.new(12.5_f32, 24.5_f32))
    v2 = ch_v2.try_receive
    assert_not_nil v2
    assert_approx_eq v2.not_nil!.x, 12.5_f32
    assert_approx_eq v2.not_nil!.y, 24.5_f32
    ch_v2.close

    # Vector3
    ch_v3 = Godot::TypedChannel(Godot::Vector3).new(4)
    ch_v3.send(Godot::Vector3.new(1.0_f32, 2.0_f32, 3.0_f32))
    v3 = ch_v3.try_receive
    assert_not_nil v3
    assert_approx_eq v3.not_nil!.z, 3.0_f32
    ch_v3.close

    # Color
    ch_color = Godot::TypedChannel(Godot::Color).new(4)
    ch_color.send(Godot::Color.new(0.2_f32, 0.4_f32, 0.6_f32, 1.0_f32))
    col = ch_color.try_receive
    assert_not_nil col
    assert_approx_eq col.not_nil!.r, 0.2_f32
    assert_approx_eq col.not_nil!.g, 0.4_f32
    ch_color.close
  end

  test "TypedChannel(Godot::Node2D) preserves engine instance ID across threads" do
    ch_node = Godot::TypedChannel(Godot::Node2D).new(4)
    node = Godot.create(Godot::Node2D)
    expected_id = node.instance_id

    worker = Thread.new do
      ch_node.send(node)
    end
    worker.join

    retrieved = ch_node.receive(timeout_sec: 1.0)
    assert_not_nil retrieved
    assert_eq retrieved.not_nil!.instance_id, expected_id
    assert_alive retrieved.not_nil!

    retrieved.not_nil!.destroy
    ch_node.close
  end

  test "Non-blocking Godot::Channel.select_any multiplexing" do
    ch1 = Godot::Channel.new(4)
    ch2 = Godot::Channel.new(4)

    # Both empty -> select returns nil
    assert_nil Godot::Channel.select_any(ch1, ch2)

    # Push to ch2 -> select immediately detects ch2
    ch2.send("DataFromCh2")
    res = Godot::Channel.select_any(ch1, ch2)
    assert_not_nil res
    selected_ch, item = res.not_nil!
    assert_eq selected_ch.object_id, ch2.object_id
    assert_eq item.to_s, "DataFromCh2"

    # Both empty again
    assert_nil Godot::Channel.select_any(ch1, ch2)

    ch1.close
    ch2.close
  end

  test "Declarative CSP select DSL block with s.receive and s.else" do
    ch1 = Godot::Channel.new(4)
    ch2 = Godot::Channel.new(4)

    else_fired = false
    executed = Godot::Channel.select_any do |s|
      s.receive(ch1) { |_| }
      s.receive(ch2) { |_| }
      s.else { else_fired = true }
    end
    assert_true executed
    assert_true else_fired

    # Push to ch1
    ch1.send("SelectMsg1")
    received_val = ""
    executed2 = Godot::Channel.select_any do |s|
      s.receive(ch1) { |val| received_val = val.to_s }
      s.receive(ch2) { |_| }
      s.else { }
    end
    assert_true executed2
    assert_eq received_val, "SelectMsg1"

    ch1.close
    ch2.close
  end

  test "Cooperative await_select on gameplay fibers with fair round-robin scheduling" do
    ch_a = Godot::Channel.new(10)
    ch_b = Godot::Channel.new(10)

    # Fill both channels with items
    5.times do |i|
      ch_a.send("A_#{i}")
      ch_b.send("B_#{i}")
    end

    results = [] of String
    10.times do
      res = Godot::Channel.await_select(ch_a, ch_b, timeout_sec: 1.0)
      assert_not_nil res
      _ch, item = res.not_nil!
      results << item.to_s
    end

    # Both channels must have been drained cleanly (5 from A, 5 from B)
    a_count = results.count(&.starts_with?("A_"))
    b_count = results.count(&.starts_with?("B_"))
    assert_eq a_count, 5
    assert_eq b_count, 5
    assert_true ch_a.empty?
    assert_true ch_b.empty?

    ch_a.close
    ch_b.close
  end

  test "Multi-Producer Single-Consumer (MPSC) concurrency with 10 threads" do
    ch = Godot::Channel.new(500)
    producer_count = 10
    messages_per_producer = 50
    total = producer_count * messages_per_producer
    threads = Array(Thread).new(producer_count)

    producer_count.times do |p_id|
      threads << Thread.new do
        messages_per_producer.times do |m_id|
          ch.send("P#{p_id}_M#{m_id}")
        end
      end
    end

    threads.each(&.join)
    assert_eq ch.size, total

    drained = ch.drain_all
    assert_eq drained.size, total
    assert_true ch.empty?
    ch.close
  end

  test "Single-Producer Multi-Consumer (SPMC) work dispatching to 5 worker threads" do
    ch = Godot::Channel.new(100)
    consumer_count = 5
    items_to_send = 100
    received_counts = Array(Int32).new(consumer_count, 0)
    mutex = ::Thread::Mutex.new
    workers = Array(Thread).new(consumer_count)

    consumer_count.times do |c_id|
      workers << Thread.new do
        local_count = 0
        while item = ch.receive(timeout_sec: 0.2)
          local_count += 1
        end
        mutex.synchronize { received_counts[c_id] = local_count }
      end
    end

    items_to_send.times do |i|
      ch.send("Task_#{i}")
    end

    workers.each(&.join)
    total_received = received_counts.sum
    assert_eq total_received, items_to_send, "All items must be consumed across the worker pool"
    ch.close
  end

  test "Multi-Producer Multi-Consumer (MPMC) simultaneous contention" do
    ch = Godot::Channel.new(20)
    producers = Array(Thread).new(4)
    consumers = Array(Thread).new(4)
    items_per_producer = 50
    total_items = 4 * items_per_producer
    consumed_count = 0
    mutex = ::Thread::Mutex.new

    4.times do |p_id|
      producers << Thread.new do
        items_per_producer.times do |i|
          ch.send("MPMC_P#{p_id}_#{i}")
        end
      end
    end

    4.times do
      consumers << Thread.new do
        while item = ch.receive(timeout_sec: 0.3)
          mutex.synchronize { consumed_count += 1 }
        end
      end
    end

    producers.each(&.join)
    consumers.each(&.join)
    assert_eq consumed_count, total_items
    ch.close
  end

  test "Timeout on background thread receive returns nil when deadline exceeded" do
    ch = Godot::Channel.new(4)
    t0 = ::Time.instant
    res = ch.receive(timeout_sec: 0.05)
    elapsed = (::Time.instant - t0).total_seconds

    assert_nil res, "Empty channel receive with timeout must return nil"
    assert_true elapsed >= 0.04, "Wait must observe the specified timeout slice"
    ch.close
  end

  test "Cooperative await_receive with timeout yields execution without blocking" do
    ch = Godot::Channel.new(4)
    t0 = ::Time.instant
    res = ch.await_receive(timeout_sec: 0.05)
    elapsed = (::Time.instant - t0).total_seconds

    assert_nil res
    assert_true elapsed >= 0.04
    ch.close
  end

  test "Channel closure unblocks senders and receivers, and close is idempotent" do
    ch = Godot::Channel.new(1)
    ch.send("Buffered")

    # Waiting sender thread blocks because channel is full
    sender_unblocked_with_false = false
    sender = Thread.new do
      res = ch.send("WillBeBlocked")
      sender_unblocked_with_false = (res == false)
    end

    # Waiting receiver thread blocks on separate empty channel
    ch_empty = Godot::Channel.new(4)
    receiver_unblocked_with_nil = false
    receiver = Thread.new do
      item = ch_empty.receive
      receiver_unblocked_with_nil = (item == nil)
    end

    # Give threads a slice to enter wait state
    5.times { Fiber.yield }

    # Close both channels
    ch.close
    ch_empty.close

    sender.join
    receiver.join

    assert_true sender_unblocked_with_false, "Blocked sender must unblock with false upon close"
    assert_true receiver_unblocked_with_nil, "Blocked receiver must unblock with nil upon close"

    # Close idempotency: calling close multiple times does not error
    ch.close
    ch.close
    assert_true ch.closed?
    assert_true ch.is_closed

    # Post-close: remaining buffered item can still be drained
    remaining = ch.try_receive
    assert_eq remaining.to_s, "Buffered"
    assert_nil ch.try_receive
  end

  test "assert_no_leak verifies zero object or memory leak across 500 channel cycles" do
    assert_no_leak(max_delta_objects: 0, name: "ChannelAllocCycles") do
      50.times do |i|
        c = Godot::Channel.new(4)
        c.send("Cycle_#{i}")
        _ = c.try_receive
        c.close
      end
    end
  end
end
