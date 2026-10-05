# =============================================================================
# LibGodot Test Suite: Type-Safe Signal Bus & Event Aggregator
# =============================================================================
# Verifies declarative signal_bus declaration, singleton access, decoupled signal
# emission and reception across independent gameplay nodes.

require "../../src/libgodot/signal_bus"

include Lapis::Test

# Declare test signal bus
signal_bus BusTestSuiteEvents do
  signal quest_completed(quest_id : String, reward_xp : Int32)
  signal player_leveled_up(new_level : Int32)
end

test_suite "SignalBus" do
  test "SignalBus instance manages singleton lifecycle and signal dispatches" do
    bus = BusTestSuiteEvents.instance
    assert_true bus.active?
    assert_eq bus.name, "BusTestSuiteEvents"

    # Emit and listen to bus signals
    received_quest = ""
    received_xp = 0

    bus.quest_completed.connect do |qid, xp|
      received_quest = qid.to_s
      received_xp = xp.to_i32
    end

    bus.quest_completed.emit("dragon_slayer", 500)
    assert_eq received_quest, "dragon_slayer"
    assert_eq received_xp, 500

    # Level up signal
    new_lvl = 0
    bus.player_leveled_up.connect do |lvl|
      new_lvl = lvl.to_i32
    end

    bus.player_leveled_up.emit(10)
    assert_eq new_lvl, 10

    BusTestSuiteEvents.reset_bus!
  end
end
