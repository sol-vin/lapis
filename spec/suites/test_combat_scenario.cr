# =============================================================================
# LibGodot Test Suite: Multi-Step Behavioral Combat Scenario
# =============================================================================
# Verifies end-to-end combat sequence using the scenario testing DSL:
# - Step-by-step sequential execution with error isolation
# - Negative signal assertion (assert_no_signal on non-lethal damage)
# - Positive signal assertion (assert_emits on lethal damage)
# - Dynamic tree assembly (<< and spawn)
# - Physics settling verification (assert_settled)

include Lapis::Test

node ScenarioDummy < Godot::Node2D do
  property health : Int32 = 100
  signal damaged(remaining_hp : Int32)
  signal died

  def take_damage(amount : Int32) : Void
    @health = Math.max(0, @health - amount)
    damaged.emit(@health)
    if @health <= 0
      died.emit
    end
  end
end

node ScenarioCombatArena < Godot::Node2D do
end

test_suite "CombatScenario" do
  test "end-to-end combat flow executes across sequential scenario steps" do |root|
    arena = Godot.create(ScenarioCombatArena)
    arena.name = "Arena"
    root.add_child(arena)

    scenario(root, "Combat Encounter Flow") do |s|
      dummy = uninitialized ScenarioDummy

      s.step "Assemble arena and spawn target dummy" do
        dummy = arena.spawn(ScenarioDummy) do |d|
          d.name = "TargetDummy"
          d.health = 100
        end

        assert_alive dummy
        assert_child_count arena, 1
        assert_has_child arena, "TargetDummy"
        assert_node_path_exists arena, "TargetDummy"
      end

      s.step "Deliver non-lethal damage and assert death signal does NOT fire" do
        assert_no_signal(dummy, "died") do
          dummy.take_damage(40)
        end
        assert_eq dummy.health, 60
      end

      s.step "Deliver secondary non-lethal hit" do
        assert_no_signal(dummy, "died") do
          dummy.take_damage(30)
        end
        assert_eq dummy.health, 30
      end

      s.step "Deliver lethal damage and verify death signal fires" do
        assert_emits(dummy, "died", timeout_sec: 1.0) do
          dummy.take_damage(50)
        end
        assert_eq dummy.health, 0
      end

      s.step "Verify static stability of arena after combat" do
        assert_settled(arena, max_frames: 10)
      end
    end

    arena.destroy
  end
end
