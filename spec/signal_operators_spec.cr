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
      player.emit_died
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

      player.emit_died
      died_calls.should eq(1)

      sig -= handler
      sig.connected?.should be_false

      player.emit_died
      died_calls.should eq(1)
    end
  end
end
