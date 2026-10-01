# =============================================================================
# Stress Test 3: Rapid In-and-Out Node Churn (Ballooning Detection)
# =============================================================================

require "../framework/perf_base"
require "../framework/perf_registry"

module PerfFramework
  node NodeChurnStress < Godot::Node do
    include PerfTestLifecycle
    @container : Godot::Node2D?
    @churn_batch : Int32 = 250
    @total_churned : Int64 = 0_i64

    def on_setup : Void
      @test_name = "NodeChurnCycle"
      @test_description = "Creates, attaches, mutates, and deletes 250+ nodes every single frame to catch memory creep."

      c = Godot.create(Godot::Node2D)
      c.call("set_name", "ChurnContainer")
      add_child(c)
      @container = c
      @total_churned = 0_i64
      @churn_batch = (@target_count // 40).clamp(50, 1000)
    end

    def on_step(delta : Float64) : Void
      return unless cont = @container

      batch = Array(Godot::Node2D).new(@churn_batch)
      @churn_batch.times do |i|
        n = Godot.create(Godot::Node2D)
        n.set_position(Godot::Vector2.new((i % 50) * 20.0_f32, (i // 50) * 20.0_f32 + 200.0_f32))
        cont.add_child(n)
        batch << n
      end

      # Immediate frame deallocation
      batch.each do |n|
        cont.remove_child(n)
        n.destroy
      end
      batch.clear

      @total_churned += @churn_batch
    end

    def on_teardown : Void
      if cont = @container
        remove_child(cont)
        cont.destroy
        @container = nil
      end
    end
  end

  TestRegistry.register(
    id: "node_churn",
    title: "Immediate Frame Node Churn",
    category: "Lifecycle Churn",
    description: "Spawns and destroys hundreds of nodes every frame to expose memory ballooning and heap creep.",
    scene_path: "res://scenes/tests/test_node_churn.tscn",
    default_count: 5000,
    default_duration: 15.0
  )
end
