# =============================================================================
# Stress Test 1: Massive Burst Node Spawning
# =============================================================================

require "../framework/perf_base"
require "../framework/perf_registry"

module PerfFramework
  node NodeSpawnStress < Godot::Node do
    include PerfTestLifecycle
    @container : Godot::Node2D?
    @spawned_nodes = Array(Godot::Node2D).new
    @batch_size : Int32 = 500

    def on_setup : Void
      @test_name = "NodeSpawnBurst"
      @test_description = "Allocates thousands of Node2D instances into the SceneTree in rapid bursts."

      c = Godot.create(Godot::Node2D)
      c.call("set_name", "SpawnContainer")
      add_child(c)
      @container = c
      @spawned_nodes.clear
      @batch_size = (@target_count // 20).clamp(100, 2000)
    end

    def on_step(delta : Float64) : Void
      return unless cont = @container
      return if @spawned_nodes.size >= @target_count

      remaining = @target_count - @spawned_nodes.size
      to_spawn = Math.min(@batch_size, remaining)

      to_spawn.times do |i|
        n = Godot.create(Godot::Node2D)
        idx = @spawned_nodes.size + i
        # Offset position in a grid
        gx = (idx % 80) * 15.0_f32
        gy = (idx // 80) * 15.0_f32
        n.set_position(Godot::Vector2.new(gx, gy + 180.0_f32))
        cont.add_child(n)
        @spawned_nodes << n
      end
    end

    def on_teardown : Void
      if cont = @container
        @spawned_nodes.each do |n|
          cont.remove_child(n)
          n.destroy
        end
        @spawned_nodes.clear
        remove_child(cont)
        cont.destroy
        @container = nil
      end
    end
  end

  TestRegistry.register(
    id: "node_spawn",
    title: "Massive Node Spawning Burst",
    category: "Allocation",
    description: "Rapidly instantiates and parents 10,000+ Node2D instances into the active SceneTree.",
    scene_path: "res://scenes/tests/test_node_spawn.tscn",
    default_count: 10000,
    default_duration: 15.0
  )
end
