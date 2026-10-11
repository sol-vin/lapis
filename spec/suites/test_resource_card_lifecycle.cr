# =============================================================================
# LibGodot Test Suite: Resource Card Lifecycle & Deep Duplication
# =============================================================================
# Verifies resource_card macro, exported property defaults, deep cloning (clone_card),
# concrete type preservation, and clone mutation isolation.

include Lapis::Test

# 1. Custom Resource Cards
resource_card WeaponDataCard < Godot::Resource do
  @[Export]
  property weapon_name : String = "Iron Sword"
  @[Export]
  property base_damage : Int32 = 25
  @[Export]
  property attack_speed : Float32 = 1.2_f32
end

resource_card ArmorDataCard < Godot::Resource do
  @[Export]
  property defense : Int32 = 40
  @[Export]
  property elemental_resistance : String = "fire"
end

test_suite "ResourceCard" do
  test "resource_card initializes with default properties and accepts configuration" do
    card = Godot.create(WeaponDataCard)
    assert_eq card.weapon_name, "Iron Sword"
    assert_eq card.base_damage, 25
    assert_approx_eq card.attack_speed, 1.2_f32

    card.weapon_name = "Excalibur"
    card.base_damage = 150
    assert_eq card.weapon_name, "Excalibur"
    assert_eq card.base_damage, 150

    card.destroy
  end

  test "clone_card preserves concrete static type and isolates modifications from prototype" do
    proto = Godot.create(WeaponDataCard)
    proto.weapon_name = "Broadsword"
    proto.base_damage = 35

    # Clone the card
    cloned = proto.clone_card
    assert_true cloned.is_a?(WeaponDataCard)
    assert_eq cloned.weapon_name, "Broadsword"
    assert_eq cloned.base_damage, 35

    # Mutate the clone
    cloned.weapon_name = "Flaming Broadsword"
    cloned.base_damage = 65

    # Prototype MUST remain pristine and unaffected!
    assert_eq proto.weapon_name, "Broadsword"
    assert_eq proto.base_damage, 35

    assert_eq cloned.weapon_name, "Flaming Broadsword"
    assert_eq cloned.base_damage, 65

    cloned.destroy
    proto.destroy
  end

  test "resource_card cloning executes with zero memory leaks" do
    proto = Godot.create(ArmorDataCard)
    proto.defense = 50

    assert_memory_stable(cycles: 10, max_delta: 0) do
      50.times do
        c = proto.clone_card
        c.defense = 75
        c.destroy
      end
    end

    proto.destroy
  end
end
