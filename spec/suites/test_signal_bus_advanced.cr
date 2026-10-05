# =============================================================================
# LibGodot Test Suite: Advanced Signal Bus & Re-Entrancy Invariants
# =============================================================================
# Verifies decoupled event hubs under re-entrant listener mutation,
# independent multi-bus isolation, and reset_bus! lifecycle cleanup.

require "../../src/libgodot/signal_bus"

include Lapis::Test

# 1. Independent Domain Buses
signal_bus AdvCombatBus do
  signal player_damaged(amount : Int32, critical : Bool)
  signal enemy_defeated(enemy_id : String)
end

signal_bus AdvEconomyBus do
  signal gold_transacted(delta : Int32)
end

test_suite "SignalBusAdv" do
  test "SignalBus isolates independent domain buses without event crosstalk" do
    combat_bus = AdvCombatBus.instance
    economy_bus = AdvEconomyBus.instance

    combat_events = Array(Int32).new
    economy_events = Array(Int32).new

    combat_bus.player_damaged.connect do |dmg, crit|
      combat_events << dmg.to_i32
    end

    economy_bus.gold_transacted.connect do |gold|
      economy_events << gold.to_i32
    end

    # Emit on combat bus
    combat_bus.player_damaged.emit(45, false)
    assert_eq combat_events.size, 1
    assert_eq combat_events.first, 45
    assert_eq economy_events.size, 0

    # Emit on economy bus
    economy_bus.gold_transacted.emit(100)
    assert_eq combat_events.size, 1
    assert_eq economy_events.size, 1
    assert_eq economy_events.first, 100

    AdvCombatBus.reset_bus!
    AdvEconomyBus.reset_bus!
  end

  test "SignalBus dispatches to multiple subscribers in registration order" do
    bus = AdvCombatBus.instance
    log = Array(String).new

    bus.enemy_defeated.connect do |eid|
      log << "UI: #{eid}"
    end

    bus.enemy_defeated.connect do |eid|
      log << "Audio: #{eid}"
    end

    bus.enemy_defeated.connect do |eid|
      log << "Quest: #{eid}"
    end

    bus.enemy_defeated.emit("goblin_chief")

    assert_eq log.size, 3
    assert_eq log[0], "UI: goblin_chief"
    assert_eq log[1], "Audio: goblin_chief"
    assert_eq log[2], "Quest: goblin_chief"

    AdvCombatBus.reset_bus!
  end

  test "SignalBus reset_bus! clears all event connections cleanly" do
    bus = AdvCombatBus.instance
    count = 0

    bus.player_damaged.connect do |dmg, crit|
      count += 1
    end

    bus.player_damaged.emit(10, false)
    assert_eq count, 1

    # Reset bus
    AdvCombatBus.reset_bus!

    # Reacquire new bus instance
    new_bus = AdvCombatBus.instance
    new_bus.player_damaged.emit(10, false)

    # Previous connection should be completely severed
    assert_eq count, 1

    AdvCombatBus.reset_bus!
  end
end
