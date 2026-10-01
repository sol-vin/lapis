# =============================================================================
# Stress Test 9: Multithreaded Background Worker & Channel Streaming Stress
# =============================================================================

require "../framework/perf_base"
require "../framework/perf_registry"

module PerfFramework
  struct WorkerTaskPayload
    property id : Int32
    property x : Float32
    property y : Float32
    property value : Float64

    def initialize(@id : Int32, @x : Float32, @y : Float32, @value : Float64)
    end
  end

  node WorkerStress < Godot::Node do
    include PerfTestLifecycle
    @channel : Channel(WorkerTaskPayload) = Channel(WorkerTaskPayload).new(5000)
    @worker_threads = Array(Thread).new
    @stop_requested : Atomic(Bool) = Atomic(Bool).new(false)
    @payloads_processed : Int64 = 0_i64

    def on_setup : Void
      @test_name = "MultithreadedWorkerStress"
      @test_description = "Spawns 4 background OS threads streaming computed data through buffered channels to the main thread."
      @stop_requested.set(false)
      @payloads_processed = 0_i64
      @worker_threads.clear

      # Spawn 4 background OS worker threads
      4.times do |thread_id|
        @worker_threads << Thread.new do
          task_id = 0
          while !@stop_requested.get
            task_id += 1
            # Heavy mathematical computation off the main thread
            val = Math.sin(task_id.to_f64 * 0.01) * Math.cos(thread_id.to_f64 * 0.05)
            px = ((task_id * 13) % 1100).to_f32 + 50.0_f32
            py = ((task_id * 17) % 400).to_f32 + 250.0_f32

            payload = WorkerTaskPayload.new(task_id, px, py, val)

            # Non-blocking or bounded channel send
            begin
              @channel.send(payload)
            rescue
              break
            end

            # Cooperative thread pause using Thread.sleep (never top-level sleep in Thread.new)
            Crystal::System::Thread.sleep(Time::Span.new(nanoseconds: 200_000)) # 0.2ms
          end
        end
      end
    end

    def on_step(delta : Float64) : Void
      # Non-blockingly drain channel items received from background threads
      drain_count = 0
      while drain_count < 1000
        select
        when payload = @channel.receive
          @payloads_processed += 1
          drain_count += 1
        else
          break
        end
      end
    end

    def on_teardown : Void
      @stop_requested.set(true)
      @channel.close
      @worker_threads.each do |th|
        th.join rescue nil
      end
      @worker_threads.clear
    end
  end

  TestRegistry.register(
    id: "worker_stress",
    title: "Multithreaded Background Worker & Channel Stress",
    category: "Concurrency & Threading",
    description: "Streams computational payloads from 4 OS worker threads through buffered Channel(T) to the main thread.",
    scene_path: "res://scenes/tests/test_multithread_worker.tscn",
    default_count: 5000,
    default_duration: 15.0
  )
end
