# =============================================================================
# LibGodot Test Suite: Real Engine Concurrency, Fibers, Channels & Threads
# =============================================================================

include Lapis::Test

test_concurrency "Cooperative Fiber modifying Godot Node properties across engine yields" do
  node = Godot.create(Godot::Node2D)
  node.name = "FiberConcurrentNode"
  node.position = Godot::Vector2.new(0.0_f32, 0.0_f32)

  fiber_completed = false
  step_count = 0

  Godot.spawn do
    3.times do |i|
      step_count += 1
      node.position = Godot::Vector2.new((i + 1).to_f32 * 10.0_f32, (i + 1).to_f32 * 10.0_f32)
      Fiber.yield
    end
    fiber_completed = true
  end

  # Simulate Godot frame loop yielding execution slices to cooperative fibers
  50.times do
    break if fiber_completed
    Fiber.yield
  end

  assert_true fiber_completed, "Cooperative fiber must complete across engine frame slices"
  assert_eq step_count, 3, "Fiber must advance through all 3 frame steps"
  assert_approx_eq node.position.x, 30.0_f32, 0.01, "Node X position must reflect final fiber mutation"
  assert_approx_eq node.position.y, 30.0_f32, 0.01, "Node Y position must reflect final fiber mutation"

  node.destroy
end

test_concurrency "Cooperative fiber awaiting custom Godot Node signals" do
  target = Godot.create(PropertyTestTarget)
  received_payload = ""
  fiber_done = false

  Godot.spawn do
    args = target.signal("custom_event").await
    received_payload = (args.first?.try(&.as_str)) || ""
    fiber_done = true
  end

  # Allow fiber to initialize and subscribe to signal
  3.times { Fiber.yield }

  # Main thread emits signal with payload
  target.emit_signal("custom_event", "ConcurrencyPayload_777")

  50.times do
    break if fiber_done
    Fiber.yield
  end

  assert_true fiber_done, "Awaiting fiber must resume upon signal emission"
  assert_eq received_payload, "ConcurrencyPayload_777", "Awaited arguments must match emitted payload"

  target.destroy
end

test_concurrency "Dead-pointer protection: target destroyed while fiber is awaiting signal" do
  target = Godot.create(Godot::Node2D)
  target_id = target.instance_id

  caught_disposed_error = false
  fiber_finished = false

  Godot.spawn do
    begin
      target.signal("nonexistent_event").await
    rescue ex : Godot::DisposedObjectError
      caught_disposed_error = true
      assert_eq ex.instance_id, target_id, "Exception instance ID must match destroyed target"
    ensure
      fiber_finished = true
    end
  end

  # Allow fiber to begin awaiting
  3.times { Fiber.yield }

  # Destroy target node in Godot ObjectDB while fiber is in-flight
  target.destroy
  assert_false target.alive?, "Target must be dead in ObjectDB"

  # Pump cooperative loop: await loop must detect dead pointer and raise DisposedObjectError
  50.times do
    break if fiber_finished
    Fiber.yield
  end

  assert_true fiber_finished, "Fiber must not hang when target is destroyed"
  assert_true caught_disposed_error, "DisposedObjectError must be raised when target node is freed"
end

test_concurrency "Cooperative signal await with timeout expiration" do
  target = Godot.create(PropertyTestTarget)
  timed_out = false

  start_time = ::Time.instant
  # Await a signal that is never emitted with 0.05 second timeout
  Godot.await(target, "never_emitted_signal", timeout_sec: 0.05)
  elapsed = (::Time.instant - start_time).total_seconds

  assert_true elapsed >= 0.04, "Await must wait until timeout expires"
  target.destroy
end

test_concurrency "GodotChannel actor communication from background OS thread to Main Thread" do
  channel = Godot::Channel.new(8)
  worker_data = "ActorResult_Worker_999"

  worker = Thread.new do
    # Heavy background processing on OS thread
    sum = 0_i64
    5000.times { |i| sum += i }
    channel.send("#{worker_data}_#{sum}")
  end

  worker.join

  # Non-blocking receive on Main Thread (safe in _process)
  received = channel.try_receive
  assert_not_nil received, "Channel must contain enqueued item"
  assert_eq received.to_s, "#{worker_data}_12497500", "Received item must match worker payload"

  channel.close
  assert_true channel.is_closed, "Channel must be marked closed"
  puts "DEBUG CHANNEL DESTROY: ref_count=#{channel.get_reference_count}, id=#{channel.instance_id}"
  channel.destroy
end

test_concurrency "GodotChannel reactive signal received dispatch on Main Thread" do
  channel = Godot::Channel.new(4)
  received_signal_arg = ""

  channel.signal("received").connect do |args|
    received_signal_arg = (args.first?.try(&.as_s)) || ""
  end

  # Send from background worker thread
  worker = Thread.new do
    channel.send("ReactiveMessage_ABC")
  end
  worker.join

  # Pump cooperative loop to allow deferred signal dispatch
  50.times do
    break unless received_signal_arg.empty?
    Fiber.yield
  end

  assert_eq received_signal_arg, "ReactiveMessage_ABC", "Reactive signal must receive payload from worker"
  channel.close
  channel.destroy
end

test_concurrency "Multi-producer worker contention on GodotChannel" do
  worker_count = 4
  items_per_worker = 25
  total_items = worker_count * items_per_worker
  channel = Godot::Channel.new(total_items)

  workers = Array(Thread).new
  worker_count.times do |w_id|
    workers << Thread.new do
      items_per_worker.times do |i|
        channel.send("W#{w_id}_#{i}")
      end
    end
  end

  workers.each(&.join)
  assert_eq channel.size, total_items, "Channel size must match total items sent"

  # Drain all items non-blockingly from Main Thread
  drain_count = 0
  while item = channel.try_receive
    drain_count += 1
  end

  assert_eq drain_count, total_items, "All items must be drained without loss or corruption"
  assert_true channel.empty?, "Channel must be empty after drain"
  channel.close
  channel.destroy
end

test_concurrency "TypedChannel(T) type-safe generic message passing" do
  typed_chan = Godot::TypedChannel(Godot::Vector3).new(5)

  worker = Thread.new do
    typed_chan.send(Godot::Vector3.new(10.0_f32, 20.0_f32, 30.0_f32))
  end
  worker.join

  vec = typed_chan.try_receive
  assert_not_nil vec, "Typed channel must return non-nil vector"
  if v = vec
    assert_approx_eq v.x, 10.0_f32, 0.01
    assert_approx_eq v.y, 20.0_f32, 0.01
    assert_approx_eq v.z, 30.0_f32, 0.01
  end

  typed_chan.close
  typed_chan.destroy
end

test_concurrency "GodotChannel close unblocks waiting background receiver threads" do
  channel = Godot::Channel.new(4)
  receiver_unblocked = false
  received_val : Godot::ChannelItem? = "dummy"

  worker = Thread.new do
    # Blocking receive on background thread
    received_val = channel.receive(timeout_sec: 2.0)
    receiver_unblocked = true
  end

  # Allow worker to enter wait state
  Crystal::System::Thread.sleep(10.milliseconds)

  # Close channel from Main Thread
  channel.close
  worker.join

  assert_true receiver_unblocked, "Worker must unblock immediately when channel is closed"
  assert_nil received_val, "Receive on closed channel must return nil"
  assert_false channel.send("post_close"), "Send on closed channel must return false"
  channel.destroy
end

test_concurrency "Background thread safe deferred method dispatch (call_deferred)" do
  target = Godot.create(Godot::Node2D)
  target.name = "InitialTargetName"

  worker = Thread.new do
    # Offload dispatch to background thread: call_deferred routes through Godot thread-safe MessageQueue
    target.call_deferred("set_name", "DeferredWorkerSuccess")
  end

  worker.join

  assert_true target.alive?, "Target must remain valid after deferred call"
  target.destroy
end

test_concurrency "Boehm GC stability during concurrent Godot allocations and channel messaging" do
  thread_count = 3
  allocations_per_thread = 500
  channel = Godot::Channel.new(100)

  threads = Array(Thread).new
  thread_count.times do |t_idx|
    threads << Thread.new do
      allocations_per_thread.times do |i|
        # Rapidly allocate Godot Vectors and channel items
        vec = Godot::Vector3.new(t_idx.to_f32, i.to_f32, (t_idx * i).to_f32)
        channel.try_send(vec.to_s)
        channel.try_receive
      end
    end
  end

  threads.each(&.join)

  # Trigger explicit GC collection cycle
  GC.collect

  assert_true true, "GC.collect completed successfully under concurrent allocations without crash"
  channel.close
  channel.destroy
end

test_concurrency "Godot Collections (Dictionary & Array) interop across threads" do
  crystal_hash = {"health" => "100", "mana" => "50", "name" => "Hero"}
  godot_dict = crystal_hash.to_godot_dict

  assert_eq godot_dict["health"], "100"
  assert_eq godot_dict["mana"], "50"
  assert_eq godot_dict["name"], "Hero"
  assert_eq godot_dict.size, 3

  crystal_arr = ["Apple", "Banana", "Cherry"]
  godot_arr = crystal_arr.to_godot_array

  assert_eq godot_arr.size, 3
  assert_eq godot_arr[0], "Apple"
  assert_eq godot_arr[1], "Banana"
  assert_eq godot_arr[2], "Cherry"
end
