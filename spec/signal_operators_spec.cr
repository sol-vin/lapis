require "./spec_helper"

class SpecCombatListener
  getter hit_count : Int32 = 0
  getter last_hp : Int32 = 0
  getter last_max : Int32 = 0

  def on_damage(hp : Int32, max : Int32) : Void
    @hit_count += 1
    @last_hp = hp
    @last_max = max
  end

  def on_death : Void
    @hit_count += 100
  end

  getter four_arg_called : Bool = false
  getter last_r0 : Int32 = 0
  getter last_r1 : String = ""
  getter last_r2 : Float64 = 0.0
  getter last_r3 : Bool = false

  def on_four_args(a : Int32, b : String, c : Float64, d : Bool) : Void
    @four_arg_called = true
    @last_r0 = a
    @last_r1 = b
    @last_r2 = c
    @last_r3 = d
  end
end

describe "Signal Compound Operators (+= and -=)" do
  describe "TypedSignal(*T)" do
    it "connects typed multi-arg proc using +=" do
      player = SpecPlayer.new
      events = [] of Tuple(Int32, Int32)

      handler = ->(new_hp : Int32, max_hp : Int32) do
        events << {new_hp, max_hp}
      end

      player.health_changed += handler
      player.health_changed.connected?.should be_true
      player.health_changed.connection_count.should eq(1)

      player.take_damage(25)
      player.take_damage(15)

      events.should eq([{75, 100}, {60, 100}])
    end

    it "disconnects typed multi-arg proc using -=" do
      player = SpecPlayer.new
      call_count = 0
      last_hp = 0

      handler = ->(new_hp : Int32, _max_hp : Int32) do
        call_count += 1
        last_hp = new_hp
      end

      player.health_changed += handler
      player.take_damage(20)
      call_count.should eq(1)
      last_hp.should eq(80)

      # Disconnect using -=
      player.health_changed -= handler
      player.health_changed.connected?.should be_false
      player.health_changed.connection_count.should eq(0)

      player.take_damage(20)
      # Must not have been called again
      call_count.should eq(1)
      last_hp.should eq(80)
    end

    it "connects and disconnects zero-argument proc on multi-arg signal using += and -=" do
      player = SpecPlayer.new
      pings = 0

      ping_handler = ->do
        pings += 1
      end

      player.health_changed += ping_handler
      player.take_damage(10)
      pings.should eq(1)

      player.health_changed -= ping_handler
      player.take_damage(10)
      pings.should eq(1)
    end

    it "connects and disconnects zero-argument proc on zero-argument signal using += and -=" do
      player = SpecPlayer.new
      died_count = 0

      death_handler = ->do
        died_count += 1
      end

      player.died += death_handler
      player.died.connected?.should be_true

      # Deal lethal damage
      player.take_damage(100)
      died_count.should eq(1)

      # Disconnect
      player.died -= death_handler
      player.died.connected?.should be_false

      # Emit again directly
      player.died.emit
      died_count.should eq(1)
    end

    it "connects and disconnects method pointer closures using += and -=" do
      player = SpecPlayer.new
      listener = SpecCombatListener.new

      handler = ->listener.on_damage(Int32, Int32)
      player.health_changed += handler

      player.take_damage(30)
      listener.hit_count.should eq(1)
      listener.last_hp.should eq(70)
      listener.last_max.should eq(100)

      # Disconnect via method pointer proc
      player.health_changed -= handler
      player.take_damage(30)

      listener.hit_count.should eq(1)
      listener.last_hp.should eq(70)
    end

    it "supports multiple distinct subscribers and selective disconnection with -=" do
      player = SpecPlayer.new
      sub_a_called = 0
      sub_b_called = 0

      handler_a = ->(_hp : Int32, _max : Int32) { sub_a_called += 1 }
      handler_b = ->(_hp : Int32, _max : Int32) { sub_b_called += 1 }

      player.health_changed += handler_a
      player.health_changed += handler_b
      player.health_changed.connection_count.should eq(2)

      player.take_damage(10)
      sub_a_called.should eq(1)
      sub_b_called.should eq(1)

      # Disconnect only A
      player.health_changed -= handler_a
      player.health_changed.connection_count.should eq(1)

      player.take_damage(10)
      sub_a_called.should eq(1) # unchanged
      sub_b_called.should eq(2) # incremented

      # Disconnect B
      player.health_changed -= handler_b
      player.health_changed.connection_count.should eq(0)
      player.health_changed.connected?.should be_false

      player.take_damage(10)
      sub_a_called.should eq(1)
      sub_b_called.should eq(2)
    end

    it "supports disconnection via SignalSubscription object with -=" do
      player = SpecPlayer.new
      received = 0

      sub = (player.health_changed << ->(hp : Int32, _max : Int32) { received = hp })
      sub.should be_a(Godot::SignalSubscription)
      sub.connected?.should be_true

      player.take_damage(15)
      received.should eq(85)

      # Disconnect with -= sub
      player.health_changed -= sub
      sub.connected?.should be_false

      player.take_damage(15)
      received.should eq(85)
    end

    it "returns the signal instance from += and -= for chaining" do
      player = SpecPlayer.new
      handler = ->{}

      res_add = (player.died += handler)
      res_add.should be_a(Godot::BoundSignal)

      res_sub = (player.died -= handler)
      res_sub.should be_a(Godot::BoundSignal)
    end

    it "handles repeated -='s gracefully when proc is already disconnected" do
      player = SpecPlayer.new
      handler = ->{}

      player.died += handler
      player.died -= handler

      # Repeating -= should not raise
      player.died -= handler
      player.died.connected?.should be_false
    end

    it "safely cleans up signal subscriptions without dangling pointers" do
      player = SpecPlayer.new
      handler = ->{}

      player.died += handler
      player.died.connected?.should be_true

      Godot.clear_signal_subscriptions(player.signal_target_id)
      player.died.connected?.should be_false
      player.died.connection_count.should eq(0)
    end
  end

  describe "Dynamic BoundSignal" do
    it "supports += and -= on dynamic signal variables" do
      player = SpecPlayer.new
      calls = 0

      sig = player.signal("health_changed")
      handler = ->(args : Array(Godot::Variant)) do
        calls += 1
      end

      sig += handler
      sig.connected?.should be_true
      sig.connection_count.should eq(1)

      player.take_damage(10)
      calls.should eq(1)

      sig -= handler
      sig.connected?.should be_false
      sig.connection_count.should eq(0)

      player.take_damage(10)
      calls.should eq(1)
    end

    it "supports 0-argument proc on dynamic BoundSignal" do
      player = SpecPlayer.new
      died_calls = 0

      sig = player.signal("died")
      handler = ->{ died_calls += 1 }

      sig += handler
      sig.connected?.should be_true

      player.died.emit
      died_calls.should eq(1)

      sig -= handler
      sig.connected?.should be_false

      player.died.emit
      died_calls.should eq(1)
    end
  end

  describe "Signal Piping Operator (>>)" do
    it "pipes TypedSignal to a class-specific method pointer proc with exact types" do
      player = SpecPlayer.new
      listener = SpecCombatListener.new

      # Pipe health_changed(Int32, Int32) >> ->listener.on_damage(Int32, Int32)
      sub = (player.health_changed >> ->listener.on_damage(Int32, Int32))
      sub.should be_a(Godot::SignalSubscription)
      sub.connected?.should be_true

      player.take_damage(20)
      listener.hit_count.should eq(1)
      listener.last_hp.should eq(80)
      listener.last_max.should eq(100)

      player.take_damage(15)
      listener.hit_count.should eq(2)
      listener.last_hp.should eq(65)

      # Unsubscribe cleanly
      sub.unsubscribe
      sub.connected?.should be_false

      player.take_damage(10)
      listener.hit_count.should eq(2)
    end

    it "pipes TypedSignal to a 0-argument method pointer proc with adaptive arity trimming" do
      player = SpecPlayer.new
      listener = SpecCombatListener.new

      # Pipe health_changed(Int32, Int32) >> ->listener.on_death (takes 0 arguments!)
      sub = (player.health_changed >> ->listener.on_death)
      sub.connected?.should be_true

      player.take_damage(10)
      listener.hit_count.should eq(100)

      # Disconnect using -= sub
      player.health_changed -= sub
      sub.connected?.should be_false

      player.take_damage(10)
      listener.hit_count.should eq(100)
    end

    it "pipes TypedSignal to another TypedSignal with matching signature" do
      emitter_player = SpecPlayer.new
      forwarder_player = SpecPlayer.new
      received = [] of Tuple(Int32, Int32)

      forwarder_player.health_changed += ->(hp : Int32, max : Int32) { received << {hp, max} }

      # Pipe signal to signal: emitter.health_changed >> forwarder.health_changed
      sub = (emitter_player.health_changed >> forwarder_player.health_changed)
      sub.connected?.should be_true

      emitter_player.take_damage(25)
      received.should eq([{75, 100}])

      emitter_player.take_damage(10)
      received.should eq([{75, 100}, {65, 100}])

      sub.unsubscribe
      emitter_player.take_damage(10)
      received.size.should eq(2)
    end

    it "pipes TypedSignal to a dynamic BoundSignal" do
      emitter_player = SpecPlayer.new
      target_node = Godot.create(Godot::Node)
      received_vals = [] of Array(Godot::Variant)

      target_sig = target_node.signal("renamed")
      target_sig += ->(args : Array(Godot::Variant)) { received_vals << args }

      # Pipe died >> renamed
      sub = (emitter_player.died >> target_sig)
      sub.connected?.should be_true

      emitter_player.died.emit
      received_vals.size.should eq(1)

      sub.unsubscribe
      target_node.destroy
    end

    it "pipes dynamic BoundSignal to a class method pointer proc" do
      player = SpecPlayer.new
      listener = SpecCombatListener.new

      sig = player.signal("health_changed")
      sub = (sig >> ->listener.on_damage(Int32, Int32))
      sub.connected?.should be_true

      player.take_damage(30)
      listener.hit_count.should eq(1)
      listener.last_hp.should eq(70)

      sub.unsubscribe
      player.take_damage(10)
      listener.hit_count.should eq(1)
    end

    it "pipes dynamic BoundSignal to a 0-argument proc" do
      player = SpecPlayer.new
      died_count = 0

      sig = player.signal("died")
      sub = (sig >> ->{ died_count += 1 })
      sub.connected?.should be_true

      player.died.emit
      died_count.should eq(1)

      sub.unsubscribe
      player.died.emit
      died_count.should eq(1)
    end

    it "pipes signal to a receiver-method tuple {receiver, :method_name}" do
      player = SpecPlayer.new
      target_node = Godot.create(Godot::Node)

      # Pipe died >> {target_node, :get_name}
      sub = (player.died >> {target_node, "get_name"})
      sub.connected?.should be_true

      # Should invoke without errors
      player.died.emit

      sub.unsubscribe
      target_node.destroy
    end

    it "pipes 4-argument signal to a 4-argument method pointer proc via >>" do
      target_node = Godot.create(Godot::Node)
      listener = SpecCombatListener.new

      sig = target_node.signal("custom_quad_signal")
      sub = (sig >> ->listener.on_four_args(Int32, String, Float64, Bool))
      sub.connected?.should be_true

      sig.emit(42, "hello", 3.14_f64, true)

      listener.four_arg_called.should be_true
      listener.last_r0.should eq(42)
      listener.last_r1.should eq("hello")
      listener.last_r2.should be_close(3.14, 0.001)
      listener.last_r3.should be_true

      sub.unsubscribe
      target_node.destroy
    end
  end
end

