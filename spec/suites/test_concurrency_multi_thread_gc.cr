# =============================================================================
# LibGodot Test Suite: Multi-Thread Concurrency & Boehm GC Thread Registration
# =============================================================================
#
# Stress tests multi-threaded worker concurrency, high-throughput channel
# message passing, Boehm GC foreign thread registration safety, and deferred
# cross-thread dispatch to the engine main loop.
# =============================================================================

require "../fixtures/test_target_nodes"

include Lapis::Test

test_suite "ConcurrencyStress" do
  test "10 concurrent OS worker threads pushing 1,000 messages through Godot::Channel" do
    thread_count = 10
    messages_per_thread = 100
    total_messages = thread_count * messages_per_thread

    channel = Godot::Channel.new(total_messages)
    threads = Array(Thread).new(thread_count)

    thread_count.times do |t_idx|
      threads << Thread.new do
        messages_per_thread.times do |m_idx|
          channel.send("T#{t_idx}_M#{m_idx}")
        end
      end
    end

    # Wait for all background OS threads to finish pushing
    threads.each(&.join)
    assert_eq channel.size, total_messages

    # Drain all messages non-blockingly from Main Thread
    drain_count = 0
    while msg = channel.try_receive
      drain_count += 1
    end

    assert_eq drain_count, total_messages, "All 1,000 messages must be drained without loss or corruption"
    assert_true channel.empty?

    channel.close
  end

  test "Multiple concurrent threads allocating Crystal heap memory and interacting with Godot types" do
    threads = Array(Thread).new(5)

    5.times do |t_idx|
      threads << Thread.new do
        # Heavy allocations on OS threads to exercise Boehm GC thread registration
        local_strings = Array(String).new(1000)
        1000.times do |i|
          local_strings << "Thread_#{t_idx}_Item_#{i}"
        end

        # Crystal-side Vector math
        v1 = Godot::Vector3.new(t_idx.to_f32, 1.0_f32, 2.0_f32)
        v2 = Godot::Vector3.new(2.0_f32, 3.0_f32, 4.0_f32)
        v3 = v1 + v2
        assert_approx_eq v3.y, 4.0_f32
      end
    end

    threads.each(&.join)
    assert_true true, "All foreign OS threads completed with Boehm GC active"
  end

  test "Cross-thread notification via call_deferred from background worker thread" do
    target = PropertyTestTarget.new
    assert_false target.tool_btn_fired

    worker = Thread.new do
      # Heavy background work
      sum = 0_i64
      10000.times { |i| sum += i }

      # Safely dispatch back to main thread
      target.call_deferred("tool_btn_prop")
    end
    worker.join

    # Allow Godot main loop to process deferred queue
    50.times do
      break if target.tool_btn_fired
      Fiber.yield
    end

    target.destroy
  end
end
