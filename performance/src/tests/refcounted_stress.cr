# =============================================================================
# Stress Test 7: RefCounted & Resource Reference Lifecycle Stress
# =============================================================================

require "../framework/perf_base"
require "../framework/perf_registry"

module PerfFramework
  node RefcountedStress < Godot::Node do
    include PerfTestLifecycle
    @batch_per_step : Int32 = 200
    @retained_resources = Array(Godot::RefCounted).new
    @max_retained : Int32 = 1000

    def on_setup : Void
      @test_name = "RefCountedResourceCycle"
      @test_description = "Creates and cycles thousands of Godot RefCounted objects to stress atomic reference counting and GC finalization."
      @retained_resources.clear
    end

    def on_step(delta : Float64) : Void
      # 1. Allocate a burst of RefCounted objects
      @batch_per_step.times do
        # Instantiate a standard Godot RefCounted instance
        res = Godot.create(Godot::RefCounted)
        @retained_resources << res
      end

      # 2. Trim excess retained objects to let GC collect them
      if @retained_resources.size > @max_retained
        # Discard oldest half
        drop_count = @retained_resources.size - @max_retained
        @retained_resources.shift(drop_count)
      end
    end

    def on_teardown : Void
      @retained_resources.clear
      GC.collect
    end
  end

  TestRegistry.register(
    id: "refcounted",
    title: "RefCounted & Resource Lifecycle",
    category: "Memory Management",
    description: "Allocates and discards thousands of RefCounted objects to stress Godot reference counting and GC finalizers.",
    scene_path: "res://scenes/tests/test_refcounted_resource.tscn",
    default_count: 5000,
    default_duration: 15.0
  )
end
