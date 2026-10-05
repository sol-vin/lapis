# =============================================================================
# LibGodot Test Suite: Hierarchical State Machine (HSM) & Pushdown Automata
# =============================================================================
# Verifies advanced state patterns built on Lapis FSM:
# - Pushdown state stacks (push/pop for nested UI/pause/dialogue states)
# - Data-carrying struct states with parameterized payloads
# - Zero memory leak proof across repeated state transition cycles
# - Exhaustive pattern matching across state unions

require "../../src/libgodot/fsm"

include Lapis::Test

# 1. State Value Structs with Payloads
struct HsmStateIdle; end

struct HsmStateMoving
  getter speed : Float32
  def initialize(@speed : Float32 = 5.0_f32); end
end

struct HsmStateStunned
  getter duration : Float32
  getter damage_over_time : Int32
  def initialize(@duration : Float32 = 1.5_f32, @damage_over_time : Int32 = 10); end
end

struct HsmStatePaused; end

alias HsmHeroState = HsmStateIdle | HsmStateMoving | HsmStateStunned | HsmStatePaused

# 2. Host Node implementing Pushdown Automata atop Lapis FSM
node HsmHeroNode < Godot::Node2D do
  fsm HsmHeroState, initial: HsmStateIdle.new do
    if s.is_a?(HsmStateMoving)
      @move_transition_count += 1
    elsif s.is_a?(HsmStateStunned)
      @stun_count += 1
    end
  end

  property move_transition_count : Int32 = 0
  property stun_count : Int32 = 0
  @state_stack = Array(HsmHeroState).new

  # Pushdown Automata methods
  def push_state(new_state : HsmHeroState) : Void
    @state_stack << state
    transition_to(new_state)
  end

  def pop_state : Bool
    if prev = @state_stack.pop?
      transition_to(prev)
      true
    else
      false
    end
  end

  def stack_depth : Int32
    @state_stack.size
  end
end

test_suite "HSM" do
  test "HSM pushdown automata stacks and restores states cleanly" do
    hero = Godot.create(HsmHeroNode)
    assert_true hero.in_state?(HsmStateIdle)
    assert_eq hero.stack_depth, 0

    # Start moving
    hero.transition_to(HsmStateMoving.new(speed: 7.0_f32))
    assert_true hero.in_state?(HsmStateMoving)

    # Push Pause state (e.g. player opened in-game menu)
    hero.push_state(HsmStatePaused.new)
    assert_true hero.in_state?(HsmStatePaused)
    assert_eq hero.stack_depth, 1

    # Push Stun state while paused (e.g. event triggered)
    hero.push_state(HsmStateStunned.new(duration: 2.0_f32, damage_over_time: 15))
    assert_true hero.in_state?(HsmStateStunned)
    assert_eq hero.stack_depth, 2
    assert_eq hero.stun_count, 1

    # Pop Stun state -> returns to Paused
    assert_true hero.pop_state
    assert_true hero.in_state?(HsmStatePaused)
    assert_eq hero.stack_depth, 1

    # Pop Paused state -> returns to Moving
    assert_true hero.pop_state
    assert_true hero.in_state?(HsmStateMoving)
    assert_eq hero.stack_depth, 0

    # Popping empty stack returns false and stays in Moving
    assert_false hero.pop_state
    assert_true hero.in_state?(HsmStateMoving)

    hero.destroy
  end

  test "HSM payload extraction and exhaustive union handling" do
    hero = Godot.create(HsmHeroNode)
    hero.transition_to(HsmStateStunned.new(duration: 3.5_f32, damage_over_time: 25))

    extracted_dot = 0
    case s = hero.state
    when HsmStateIdle
      extracted_dot = 0
    when HsmStateMoving
      extracted_dot = 0
    when HsmStateStunned
      extracted_dot = s.damage_over_time
    when HsmStatePaused
      extracted_dot = 0
    end

    assert_eq extracted_dot, 25
    hero.destroy
  end

  test "HSM zero memory leak across 1000 rapid transitions" do
    hero = Godot.create(HsmHeroNode)
    assert_memory_stable(cycles: 10, max_delta: 0) do
      100.times do
        hero.transition_to(HsmStateMoving.new(speed: 10.0_f32))
        hero.transition_to(HsmStateStunned.new(duration: 1.0_f32, damage_over_time: 5))
        hero.transition_to(HsmStateIdle.new)
      end
    end
    hero.destroy
  end
end
