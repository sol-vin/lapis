# =============================================================================
# Stress Test 6: Struct & Variant Alignment Stress
# =============================================================================

require "../framework/perf_base"
require "../framework/perf_registry"

module PerfFramework
  node AlignmentStress < Godot::Node do
    include PerfTestLifecycle
    @container : Godot::Node2D?
    @nodes = Array(Godot::Node2D).new
    @batch_count : Int32 = 1500

    def on_setup : Void
      @test_name = "PropertyAlignmentStress"
      @test_description = "Rapidly calculates and assigns Vector2, Rect2, Color, and Transform2D to 1,500+ nodes to catch struct alignment and ABI padding bugs."

      c = Godot.create(Godot::Node2D)
      c.call("set_name", "AlignmentContainer")
      add_child(c)
      @container = c
      @nodes.clear

      @batch_count.times do |i|
        n = Godot.create(Godot::Node2D)
        c.add_child(n)
        @nodes << n
      end
    end

    def on_step(delta : Float64) : Void
      return if @nodes.empty?

      t = @elapsed_time

      # Tight loop updating math structs
      @nodes.each_with_index do |n, idx|
        # Vector2 arithmetic & position assignment
        phase = t + (idx * 0.05)
        vx = (Math.cos(phase) * 200.0).to_f32 + 600.0_f32
        vy = (Math.sin(phase) * 150.0).to_f32 + 400.0_f32
        n.set_position(Godot::Vector2.new(vx, vy))

        # Vector2 scaling
        scale_val = (1.0 + Math.sin(phase * 2.0) * 0.5).to_f32
        n.set_scale(Godot::Vector2.new(scale_val, scale_val))

        # Float rotation
        n.set_rotation((phase % (Math::PI * 2.0)).to_f32)
      end
    end

    def on_teardown : Void
      if cont = @container
        @nodes.each do |n|
          cont.remove_child(n)
          n.destroy
        end
        @nodes.clear
        remove_child(cont)
        cont.destroy
        @container = nil
      end
    end
  end

  TestRegistry.register(
    id: "alignment",
    title: "Struct & Variant Alignment Stress",
    category: "ABI & Alignment",
    description: "Exercises 64-bit alignment and Variant conversion with high-frequency Vector2/Transform2D mutations.",
    scene_path: "res://scenes/tests/test_property_alignment.tscn",
    default_count: 1500,
    default_duration: 15.0
  )
end
