# =============================================================================
# Stress Test 4: Randomized Lifespan Churn (Breathing & Out-of-Order Deletion)
# =============================================================================

require "../framework/perf_base"
require "../framework/perf_registry"

module PerfFramework
  struct LivingNodeEntry
    property node : Godot::Node2D
    property ttl : Float64
    property velocity : Godot::Vector2

    def initialize(@node : Godot::Node2D, @ttl : Float64, @velocity : Godot::Vector2)
    end
  end

  node NodeLifespanStress < Godot::Node do
    include PerfTestLifecycle
    @container : Godot::Node2D?
    @living_nodes = Array(LivingNodeEntry).new
    @total_spawned : Int64 = 0_i64
    @total_expired : Int64 = 0_i64
    @spawn_rate_per_sec : Int32 = 400
    @spawn_accumulator : Float64 = 0.0

    def on_setup : Void
      @test_name = "NodeLifespanChurn"
      @test_description = "Spawns continuous waves of nodes with randomized lifespans (0.2s - 3.5s) to let them breathe and delete out-of-order."

      c = Godot.create(Godot::Node2D)
      c.call("set_name", "LifespanContainer")
      add_child(c)
      @container = c
      @living_nodes.clear
      @total_spawned = 0_i64
      @total_expired = 0_i64
      @spawn_accumulator = 0.0
    end

    def on_step(delta : Float64) : Void
      return unless cont = @container

      # 1. Update existing living nodes, letting them breathe and run logic
      i = @living_nodes.size - 1
      while i >= 0
        entry = @living_nodes[i]
        entry.ttl -= delta

        if entry.ttl <= 0.0
          # Lifespan expired! Free out-of-order
          node = entry.node
          cont.remove_child(node)
          node.destroy
          @living_nodes.delete_at(i)
          @total_expired += 1
        else
          # Still alive: let it breathe and move
          pos = entry.node.get_position
          new_pos = Godot::Vector2.new(
            (pos.x + entry.velocity.x * delta.to_f32) % 1200.0_f32,
            ((pos.y - 200.0_f32 + entry.velocity.y * delta.to_f32) % 550.0_f32) + 200.0_f32
          )
          entry.node.set_position(new_pos)
          @living_nodes[i] = entry
        end
        i -= 1
      end

      # 2. Spawn new nodes if below population limit
      max_living = @target_count
      @spawn_accumulator += delta * @spawn_rate_per_sec

      while @spawn_accumulator >= 1.0 && @living_nodes.size < max_living
        @spawn_accumulator -= 1.0

        n = Godot.create(Godot::Node2D)
        @total_spawned += 1

        # Randomized lifespan between 0.2s and 3.5s
        rand_ttl = 0.2 + (rand * 3.3)

        # Initial position & random velocity
        start_x = (rand * 1150.0).to_f32 + 20.0_f32
        start_y = (rand * 500.0).to_f32 + 200.0_f32
        n.set_position(Godot::Vector2.new(start_x, start_y))

        vx = ((rand - 0.5) * 120.0).to_f32
        vy = ((rand - 0.5) * 120.0).to_f32

        cont.add_child(n)
        @living_nodes << LivingNodeEntry.new(n, rand_ttl, Godot::Vector2.new(vx, vy))
      end
    end

    def on_teardown : Void
      if cont = @container
        @living_nodes.each do |entry|
          cont.remove_child(entry.node)
          entry.node.destroy
        end
        @living_nodes.clear
        remove_child(cont)
        cont.destroy
        @container = nil
      end
    end
  end

  TestRegistry.register(
    id: "node_lifespan",
    title: "Randomized Lifespan & Breathing Churn",
    category: "Lifecycle Churn",
    description: "Keeps nodes alive for random durations (0.2s - 3.5s), mutating transforms and freeing out-of-order.",
    scene_path: "res://scenes/tests/test_node_lifespan_churn.tscn",
    default_count: 3000,
    default_duration: 20.0
  )
end
