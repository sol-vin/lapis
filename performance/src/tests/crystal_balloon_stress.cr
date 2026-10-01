# =============================================================================
# Stress Test 10: Crystal Boehm GC Heap & Ballooning Stress
# =============================================================================
# This test specifically exercises the managed Crystal Boehm GC heap.
# It generates high volumes of Crystal-native structures (dynamic Hashes,
# interpolated Strings, Array buffers, closures, and wrapper handles)
# into a sliding queue to verify that the Boehm GC collects discarded
# generations cleanly without memory ballooning or fragmentation creep.
# =============================================================================

require "../framework/perf_base"
require "../framework/perf_registry"

module PerfFramework
  class ManagedDataPayload
    getter id : Int64
    getter tag : String
    getter payload : Array(String)
    getter metadata : Hash(String, Int32)

    def initialize(@id : Int64)
      @tag = "payload_#{@id}_#{Time.utc.to_unix_ms}"
      @payload = Array(String).new(32) { |i| "item_#{i}_#{@id}_" + ("x" * 64) }
      @metadata = Hash(String, Int32).new
      8.times { |i| @metadata["key_#{i}"] = (i * 100) + @id.to_i32 }
    end
  end

  node CrystalBalloonStress < Godot::Node do
    include PerfTestLifecycle

    # Sliding retention queue to force objects across GC collection generations
    @retention_window = Deque(Array(ManagedDataPayload)).new
    @total_objects_churned : Int64 = 0_i64
    @churn_per_frame : Int32 = 400
    @window_depth : Int32 = 6

    def on_setup : Void
      @test_name = "CrystalGCBallooning"
      @test_description = "Allocates thousands of Crystal objects, dynamic hashes, and string buffers per frame across a sliding queue to expose GC leaks."
      @retention_window.clear
      @total_objects_churned = 0_i64
      @churn_per_frame = (@target_count // 20).clamp(100, 2000)
    end

    def on_step(delta : Float64) : Void
      # 1. Allocate a fresh batch of heavy Crystal heap structures
      batch = Array(ManagedDataPayload).new(@churn_per_frame)
      @churn_per_frame.times do |i|
        batch << ManagedDataPayload.new(@total_objects_churned + i.to_i64)
      end
      @total_objects_churned += @churn_per_frame

      # 2. Push into sliding retention window
      @retention_window.push(batch)

      # 3. Pop expired batch from window when depth is exceeded, releasing references for GC
      if @retention_window.size > @window_depth
        old_batch = @retention_window.shift
        old_batch.clear
      end
    end

    def on_teardown : Void
      # Release all retained references so Boehm GC can reclaim 100% of memory
      @retention_window.each(&.clear)
      @retention_window.clear
    end
  end

  TestRegistry.register(
    id: "crystal_balloon_stress",
    title: "Crystal GC Heap Ballooning",
    category: "Memory & GC",
    description: "Allocates high-volume Crystal hashes, strings, and object graphs across a sliding queue to verify Boehm GC reclamation.",
    scene_path: "res://scenes/tests/test_crystal_balloon.tscn",
    default_count: 8000,
    default_duration: 15.0
  )
end
