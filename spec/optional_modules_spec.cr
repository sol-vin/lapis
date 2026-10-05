require "./spec_helper"
require "../src/lapis/math"
require "../src/lapis/fsm"

class FsmMonster
  getter history : Array(String) = [] of String

  fsm :state, initial: :idle do
    state :idle do
      enter { @history << "idle_enter" }
      update { |dt| @history << "idle_update_#{dt}" }
      exit { @history << "idle_exit" }
    end

    state :chase do
      enter { @history << "chase_enter" }
      update { |dt| @history << "chase_update_#{dt}" }
      exit { @history << "chase_exit" }
    end
  end
end

describe "Optional Standalone Modules" do
  describe "lapis/math" do
    it "smoothly approaches target without overshooting" do
      val = 5.0
      val = val.approach(10.0, 2.0)
      val.should eq(7.0)

      val = val.approach(10.0, 4.0)
      val.should eq(10.0)

      # Negative approach
      val2 = 10.0
      val2 = val2.approach(5.0, 3.0)
      val2.should eq(7.0)
      val2 = val2.approach(5.0, 3.0)
      val2.should eq(5.0)
    end

    it "converts between degrees and radians" do
      180.degrees.should be_close(Math::PI, 1e-5)
      90.degrees.should be_close(Math::PI / 2.0, 1e-5)
      Math::PI.to_degrees.should be_close(180.0, 1e-5)
    end

    it "generates random Vector2 direction and points in circle" do
      dir = Godot::Vector2.random_dir
      dir.length.should be_close(1.0, 1e-4)

      point = Godot::Vector2.random_in_circle(5.0)
      (point.length <= 5.001).should be_true
    end

    it "generates random Vector3 direction and points in sphere" do
      dir = Godot::Vector3.random_dir
      dir.length.should be_close(1.0, 1e-4)

      point = Godot::Vector3.random_in_sphere(10.0)
      (point.length <= 10.001).should be_true
    end
  end

  describe "lapis/fsm" do
    it "initializes in starting state and runs enter callback on transition" do
      m = FsmMonster.new
      m.state.should eq(:idle)
      m.current_state.should eq(:idle)
      m.in_state?(:idle).should be_true
      m.in_state?(:chase).should be_false

      m.update_state(0.016)
      m.history.should eq(["idle_update_0.016"])

      # Transition to chase
      m.transition_to(:chase)
      m.state.should eq(:chase)
      m.in_state?(:chase).should be_true
      m.history.should eq(["idle_update_0.016", "idle_exit", "chase_enter"])

      m.update_state(0.033)
      m.history.last.should eq("chase_update_0.033")
    end

    it "invokes on_state_changed transition listener" do
      m = FsmMonster.new
      transitions = [] of Tuple(Symbol, Symbol)

      m.on_state_changed do |from, to|
        transitions << {from, to}
      end

      m.transition_to(:chase)
      m.transition_to(:idle)

      transitions.should eq([{:idle, :chase}, {:chase, :idle}])
    end
  end
end
