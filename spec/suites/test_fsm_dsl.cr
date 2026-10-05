# =============================================================================
# LibGodot Test Suite: Finite State Machine (FSM) Pattern & DSL
# =============================================================================
# Verifies zero-allocation union-type state machines, compile-time exhaustiveness,
# lifecycle hooks (on_enter, on_exit), transition validity, and state queries.

require "../../src/libgodot/fsm"

include Lapis::Test

# 1. State Value Structs
struct FsmTestIdle; end

struct FsmTestWalking
  getter speed : Float32
  def initialize(@speed : Float32 = 4.0_f32)
  end
end

struct FsmTestJumping
  getter jump_power : Float32
  def initialize(@jump_power : Float32 = 10.0_f32)
  end
end

# 2. State Union Type
alias FsmHeroState = FsmTestIdle | FsmTestWalking | FsmTestJumping

# 3. Host Node with FSM
node FsmHeroNode < Godot::Node2D do
  fsm FsmHeroState, initial: FsmTestIdle.new do
    # enter hook
    if s.is_a?(FsmTestWalking)
      @enter_walk_count += 1
    end
  end

  property enter_walk_count : Int32 = 0
end

test_suite "FSM" do
  test "FSM initializes with initial state and tracks previous_state across transitions" do
    hero = Godot.create(FsmHeroNode)
    assert_true hero.in_state?(FsmTestIdle)
    assert_true hero.state.is_a?(FsmTestIdle)
    assert_nil hero.previous_state

    # Transition to walking
    hero.transition_to(FsmTestWalking.new(speed: 6.5_f32))
    assert_true hero.in_state?(FsmTestWalking)
    assert_true hero.previous_state.try(&.is_a?(FsmTestIdle)) == true
    assert_eq hero.enter_walk_count, 1

    # Transition to jumping
    hero.transition_to(FsmTestJumping.new(jump_power: 12.0_f32))
    assert_true hero.in_state?(FsmTestJumping)
    assert_true hero.previous_state.try(&.is_a?(FsmTestWalking)) == true

    # Transition back to walking
    hero.transition_to(FsmTestWalking.new(speed: 3.0_f32))
    assert_true hero.in_state?(FsmTestWalking)
    assert_eq hero.enter_walk_count, 2

    hero.destroy
  end

  test "FSM zero-allocation state pattern matching exhaustiveness" do
    hero = Godot.create(FsmHeroNode)
    hero.transition_to(FsmTestWalking.new(speed: 8.0_f32))

    handled_speed = 0.0_f32
    case s = hero.state
    when FsmTestIdle
      handled_speed = 0.0_f32
    when FsmTestWalking
      handled_speed = s.speed
    when FsmTestJumping
      handled_speed = s.jump_power
    end

    assert_approx_eq handled_speed, 8.0_f32
    hero.destroy
  end

  test "FSM on_enter and on_exit execute exclusively at respective transition phases" do
    entity = Godot.create(FsmLifecycleNode)
    assert_eq entity.walk_enter_count, 0
    assert_eq entity.walk_exit_count, 0

    # Idle -> Walking: on_enter Walking fires (1), on_exit Walking does NOT fire (0)
    entity.transition_to(FsmTestWalking.new(speed: 5.5_f32))
    assert_eq entity.walk_enter_count, 1
    assert_eq entity.walk_exit_count, 0
    assert_approx_eq entity.last_speed, 5.5_f32

    # Walking -> Jumping: on_exit Walking fires (1), on_enter Jumping fires (1), on_exit Jumping does NOT fire (0)
    entity.transition_to(FsmTestJumping.new(jump_power: 14.0_f32))
    assert_eq entity.walk_exit_count, 1
    assert_eq entity.jump_enter_count, 1
    assert_eq entity.jump_exit_count, 0

    # Jumping -> Walking: on_exit Jumping fires (1), on_enter Walking fires (2)
    entity.transition_to(FsmTestWalking.new(speed: 7.0_f32))
    assert_eq entity.jump_exit_count, 1
    assert_eq entity.walk_enter_count, 2
    assert_eq entity.walk_exit_count, 1

    entity.destroy
  end
end

node FsmLifecycleNode < Godot::Node2D do
  fsm FsmHeroState, initial: FsmTestIdle.new do
    on_enter FsmTestWalking do |walking|
      @walk_enter_count += 1
      @last_speed = walking.speed
    end

    on_exit FsmTestWalking do |_|
      @walk_exit_count += 1
    end

    on_enter FsmTestJumping do |_|
      @jump_enter_count += 1
    end

    on_exit FsmTestJumping do |_|
      @jump_exit_count += 1
    end
  end

  property walk_enter_count : Int32 = 0
  property walk_exit_count : Int32 = 0
  property jump_enter_count : Int32 = 0
  property jump_exit_count : Int32 = 0
  property last_speed : Float32 = 0.0_f32
end
