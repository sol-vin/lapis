# =============================================================================
# Stress Test 2: Massive Bulk Node Deletion
# =============================================================================

require "../framework/perf_base"
require "../framework/perf_registry"

module PerfFramework
  node NodeDeleteStress < Godot::Node do
    include PerfTestLifecycle
    @container : Godot::Node2D?
    @active_nodes = Array(Godot::Node2D).new
    @phase : Symbol = :spawning
    @wave_size : Int32 = 500

    def on_setup : Void
      @test_name = "NodeDeleteBurst"
      @test_description = "Spawns 10,000+ nodes and tears them down in bulk to test deallocation throughput and GC reclamation."

      c = Godot.create(Godot::Node2D)
      c.call("set_name", "DeleteContainer")
      add_child(c)
      @container = c
      @active_nodes.clear
      @phase = :spawning
      @wave_size = (@target_count // 10).clamp(100, 2000)
    end

    def on_step(delta : Float64) : Void
      return unless cont = @container

      case @phase
      when :spawning
        if @active_nodes.size < @target_count
          to_spawn = Math.min(@wave_size, @target_count - @active_nodes.size)
          to_spawn.times do |i|
            n = Godot.create(Godot::Node2D)
            cont.add_child(n)
            @active_nodes << n
          end
        else
          @phase = :deleting
        end
      when :deleting
        if !@active_nodes.empty?
          to_del = Math.min(@wave_size, @active_nodes.size)
          to_del.times do
            n = @active_nodes.pop
            cont.remove_child(n)
            n.destroy
          end
        else
          # Reset cycle: respawn again if running in infinite mode
          @phase = :spawning
        end
      end
    end

    def on_teardown : Void
      if cont = @container
        @active_nodes.each do |n|
          cont.remove_child(n)
          n.destroy
        end
        @active_nodes.clear
        remove_child(cont)
        cont.destroy
        @container = nil
      end
    end
  end

  TestRegistry.register(
    id: "node_delete",
    title: "Massive Bulk Node Deletion",
    category: "Deallocation",
    description: "Repeatedly fills the tree with thousands of nodes and drains them to verify heap reclamation.",
    scene_path: "res://scenes/tests/test_node_delete.tscn",
    default_count: 10000,
    default_duration: 15.0
  )
end
