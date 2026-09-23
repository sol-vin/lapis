require "lapis"
require "./perf_metrics"

module PerfFramework
  module PerfLifecycleInterface
    def test_name : String
      "StressTest"
    end

    def test_description : String
      "Stress test scenario"
    end

    def target_count : Int32
      0
    end

    def target_cycles : Int32
      0
    end

    def finite_duration : Float64
      0.0
    end

    def is_infinite : Bool
      false
    end

    def elapsed_time : Float64
      0.0
    end

    def completed_cycles : Int32
      0
    end

    def is_running : Bool
      false
    end

    def is_finished : Bool
      false
    end

    def is_paused : Bool
      false
    end

    def start_test(
      target_count : Int32? = nil,
      duration : Float64? = nil,
      infinite : Bool? = nil,
      cycles : Int32? = nil,
    ) : Void
    end

    def toggle_pause : Void
    end

    def process_tick(delta : Float64) : Void
    end

    def stop_and_teardown : Void
    end
  end

  module PerfTestLifecycle
    include PerfLifecycleInterface

    property test_name : String = "StressTest"
    property test_description : String = "Stress test scenario"
    property target_count : Int32 = 5000
    property target_cycles : Int32 = 0        # 0 = infinite cycles
    property finite_duration : Float64 = 15.0 # 0 = infinite duration
    property is_infinite : Bool = false

    getter elapsed_time : Float64 = 0.0
    getter completed_cycles : Int32 = 0
    getter is_running : Bool = false
    getter is_finished : Bool = false
    getter is_paused : Bool = false

    getter initial_snapshot : MetricSnapshot?
    getter final_snapshot : MetricSnapshot?
    getter sampler : MetricsSampler = MetricsSampler.new

    # Custom hooks implemented by individual stress tests
    abstract def on_setup : Void
    abstract def on_step(delta : Float64) : Void
    abstract def on_teardown : Void

    def start_test(
      target_count : Int32? = nil,
      duration : Float64? = nil,
      infinite : Bool? = nil,
      cycles : Int32? = nil,
    ) : Void
      @target_count = target_count if target_count
      @finite_duration = duration if duration
      @is_infinite = infinite if infinite != nil
      @target_cycles = cycles if cycles

      # If duration is <= 0 or inf, mark as infinite
      if @finite_duration <= 0.0
        @is_infinite = true
      end

      @elapsed_time = 0.0
      @completed_cycles = 0
      @is_finished = false
      @is_paused = false

      GC.collect
      @sampler.reset_baseline
      @initial_snapshot = @sampler.sample_now

      Godot.print("------------------------------------------------------------------")
      Godot.print("[PerfTest] Starting: #{@test_name}")
      Godot.print("  Target Count: #{@target_count} | Mode: #{@is_infinite ? "INFINITE" : "#{@finite_duration}s"}")
      init_snap = @initial_snapshot.not_nil!
      Godot.print("  Baseline: Engine RAM=#{init_snap.static_ram_mb.round(2)}MB, Crystal GC Active=#{init_snap.crystal_gc_active_mb.round(2)}MB (Heap=#{init_snap.crystal_gc_heap_mb.round(2)}MB), OS WS=#{init_snap.os_working_set_mb.round(2)}MB, Objects=#{init_snap.object_count}")
      Godot.print("------------------------------------------------------------------")

      on_setup
      @is_running = true
    end

    def toggle_pause : Void
      @is_paused = !@is_paused
      Godot.print("[PerfTest] #{@test_name} is now #{@is_paused ? "PAUSED" : "RESUMED"}")
    end

    def stop_and_teardown : Void
      return unless @is_running || !@is_finished
      @is_running = false
      @is_finished = true

      Godot.print("[PerfTest] Tearing down #{@test_name}...")
      on_teardown

      GC.collect
      @final_snapshot = @sampler.sample_now
      Godot.print("------------------------------------------------------------------")
      Godot.print("[PerfTest] Completed: #{@test_name}")
      Godot.print("  Elapsed Time: #{@elapsed_time.round(2)}s | Completed Cycles: #{@completed_cycles}")
      if init = @initial_snapshot
        final = @final_snapshot.not_nil!
        ram_diff = final.static_ram_mb - init.static_ram_mb
        gc_active_diff = final.crystal_gc_active_mb - init.crystal_gc_active_mb
        gc_heap_diff = final.crystal_gc_heap_mb - init.crystal_gc_heap_mb
        os_ws_diff = final.os_working_set_mb - init.os_working_set_mb
        obj_diff = final.object_count - init.object_count
        node_diff = final.node_count - init.node_count
        orphans = final.orphan_count

        Godot.print("  Engine RAM Diff: #{ram_diff >= 0 ? "+" : ""}#{ram_diff.round(2)}MB (Peak: #{final.peak_ram_mb.round(2)}MB)")
        Godot.print("  Crystal GC Active Diff: #{gc_active_diff >= 0 ? "+" : ""}#{gc_active_diff.round(2)}MB (Final: #{final.crystal_gc_active_mb.round(2)}MB, Heap: #{final.crystal_gc_heap_mb.round(2)}MB [#{gc_heap_diff >= 0 ? "+" : ""}#{gc_heap_diff.round(2)}MB])")
        if final.os_working_set_mb > 0.0
          Godot.print("  OS Working Set: #{final.os_working_set_mb.round(2)}MB (#{os_ws_diff >= 0 ? "+" : ""}#{os_ws_diff.round(2)}MB)")
        end
        Godot.print("  Objects Diff: #{obj_diff >= 0 ? "+" : ""}#{obj_diff} (Nodes: #{node_diff}, Orphans: #{orphans})")

        if gc_active_diff > 2.0
          Godot.printerr("  ⚠️ WARNING: Crystal GC active memory retained +#{gc_active_diff.round(2)}MB after GC.collect (Potential ballooning)!")
        else
          Godot.print("  ✔ Crystal Boehm GC heap cleanly reclaimed (Zero ballooning).")
        end

        if orphans > 0
          Godot.printerr("  ⚠️ WARNING: #{orphans} orphan nodes detected after test completion!")
        else
          Godot.print("  ✔ Zero orphan nodes remaining.")
        end
      end
      Godot.print("------------------------------------------------------------------")
    end

    @last_tick_frame : UInt64 = 0_u64

    def process_tick(delta : Float64) : Void
      frame = Godot.engine.get_process_frames.to_u64 rescue 0_u64
      if frame > 0 && frame == @last_tick_frame
        return
      end
      @last_tick_frame = frame

      return unless @is_running
      return if @is_paused

      @elapsed_time += delta

      # Execute test workload
      on_step(delta)
      @completed_cycles += 1

      # Check completion condition if finite
      if !@is_infinite
        time_done = @finite_duration > 0.0 && @elapsed_time >= @finite_duration
        cycles_done = @target_cycles > 0 && @completed_cycles >= @target_cycles

        if time_done || cycles_done
          stop_and_teardown
        end
      end
    end

    def _process(delta : Float64) : Void
      process_tick(delta)
    end
  end

  alias PerfBase = PerfLifecycleInterface
end

module Godot
  class Object
    include PerfFramework::PerfLifecycleInterface
  end
end
