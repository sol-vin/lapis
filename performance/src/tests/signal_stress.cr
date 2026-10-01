# =============================================================================
# Stress Test 8: Signal Connection & Emission Churn
# =============================================================================

require "../framework/perf_base"
require "../framework/perf_registry"

module PerfFramework
  node SignalEmitterNode < Godot::Node do
    signal data_dispatched(val : Int32, label : String)

    def trigger(val : Int32) : Void
      emit_data_dispatched(val, "Payload_#{val}")
    end
  end

  node SignalStress < Godot::Node do
    include PerfTestLifecycle
    @container : Godot::Node2D?
    @emitters = Array(SignalEmitterNode).new
    @num_emitters : Int32 = 300
    @emission_counter : Int32 = 0

    def on_setup : Void
      @test_name = "SignalConnectionChurn"
      @test_description = "Creates 300 signal emitters, connects dynamic Crystal closures, and fires rapid signal emissions."

      c = Godot.create(Godot::Node2D)
      c.call("set_name", "SignalContainer")
      add_child(c)
      @container = c
      @emitters.clear
      @emission_counter = 0

      @num_emitters.times do |i|
        emitter = Godot.create(SignalEmitterNode)
        emitter.call("set_name", "Emitter_#{i}")
        c.add_child(emitter)
        @emitters << emitter

        # Connect with block closure
        emitter.connect("data_dispatched") do |args|
          @emission_counter += 1
        end
      end
    end

    def on_step(delta : Float64) : Void
      return if @emitters.empty?

      # Fire signals on all emitters
      @emitters.each_with_index do |emitter, idx|
        emitter.trigger(@emission_counter + idx)
      end
    end

    def on_teardown : Void
      if cont = @container
        @emitters.each do |e|
          cont.remove_child(e)
          e.destroy
        end
        @emitters.clear
        remove_child(cont)
        cont.destroy
        @container = nil
      end
    end
  end

  TestRegistry.register(
    id: "signal_churn",
    title: "Signal Connection & Emission Churn",
    category: "Event System",
    description: "Connects hundreds of Crystal closures to Godot signals and fires high-throughput emissions.",
    scene_path: "res://scenes/tests/test_signal_churn.tscn",
    default_count: 300,
    default_duration: 15.0
  )
end
