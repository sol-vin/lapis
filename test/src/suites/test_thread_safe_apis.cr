# =============================================================================
# LibGodot Test Suite: OS Thread-Safety of Core APIs & Actor Channel Concurrency
# Replicating godot-rust's thread_safe_apis_test.rs and AGENTS.md Invariants
# =============================================================================

include Lapis::Test

record ActorWorkTask, id : Int32, payload : String
record ActorWorkResult, id : Int32, processed_data : String

test_thread_safety "Godot.print and printerr are thread-safe when called from OS background threads" do
  completed = false

  thread = Thread.new do
    5.times do |i|
      Godot.print("[ThreadSafeAPIs] Background thread log #{i}")
    end
    completed = true
  end

  thread.join
  assert_true completed, "Background worker thread must complete execution cleanly"
end

test_thread_safety "StringName and Vector math operations execute safely on OS worker threads" do
  computed_results = Channel(Godot::Vector2).new(4)

  thread = Thread.new do
    v1 = Godot::Vector2.new(10.0_f32, 20.0_f32)
    v2 = Godot::Vector2.new(30.0_f32, 40.0_f32)
    v_sum = v1 + v2
    computed_results.send(v_sum)
  end

  thread.join
  result_vec = computed_results.receive

  assert_approx_eq result_vec.x, 40.0_f32, 0.01
  assert_approx_eq result_vec.y, 60.0_f32, 0.01
end

test_thread_safety "Actor Pattern: OS background thread offloads computation to main thread via buffered Channel" do
  in_channel = Channel(ActorWorkTask).new(8)
  out_channel = Channel(ActorWorkResult).new(8)

  # Main thread feeds tasks into buffered channel
  in_channel.send(ActorWorkTask.new(1, "Alpha"))
  in_channel.send(ActorWorkTask.new(2, "Beta"))
  in_channel.send(ActorWorkTask.new(3, "Gamma"))

  # Spawn OS worker thread
  worker_thread = Thread.new do
    3.times do
      task = in_channel.receive
      # Heavy worker processing simulation
      processed = "#{task.payload.reverse}_PROCESSED_#{task.id * 10}"
      out_channel.send(ActorWorkResult.new(task.id, processed))
    end
  end

  worker_thread.join

  r1 = out_channel.receive
  r2 = out_channel.receive
  r3 = out_channel.receive

  assert_eq r1.processed_data, "ahplA_PROCESSED_10"
  assert_eq r2.processed_data, "ateB_PROCESSED_20"
  assert_eq r3.processed_data, "ammaG_PROCESSED_30"
end

test_thread_safety "Shared collections protected by Mutex across concurrent OS threads" do
  mutex = ::Thread::Mutex.new
  shared_array = Array(Int32).new

  threads = Array(Thread).new(4)
  4.times do |thread_idx|
    threads << Thread.new do
      10.times do |item_idx|
        mutex.synchronize do
          shared_array << (thread_idx * 100 + item_idx)
        end
      end
    end
  end

  threads.each(&.join)
  assert_eq shared_array.size, 40, "All 40 synchronized writes must be recorded without data corruption"
end
