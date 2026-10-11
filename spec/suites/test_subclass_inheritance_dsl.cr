# =============================================================================
# LibGodot Test Suite: Subclass Property & Signal Inheritance Deduplication
# =============================================================================
# Verifies that multi-level inheritance hierarchies (Grandparent -> Parent -> Child)
# properly partition exported properties and signals across ClassDB without
# colliding or duplicating members, while preserving polymorphic property dispatch,
# signals, lifecycle callbacks, and zero-leak memory invariants.

include Lapis::Test

node SuiteGrandparentEntity < Godot::Node2D do
  @[Export]
  property entity_id : Int32 = 10

  @[Export]
  property speed : Float32 = 5.0_f32

  signal entity_spawned(id : Int32)

  getter gp_ready_called : Bool = false

  def _ready : Void
    @gp_ready_called = true
  end
end

node SuiteParentEntity < SuiteGrandparentEntity do
  @[Export]
  property faction : String = "cyber"

  @[Export]
  property shields : Int32 = 50

  signal faction_changed(new_faction : String)

  getter parent_ready_called : Bool = false

  def _ready : Void
    super
    @parent_ready_called = true
  end
end

node SuiteChildEntity < SuiteParentEntity do
  @[Export]
  property combat_rating : Float32 = 98.7_f32

  @[Export]
  property stealth_mode : Bool = true

  signal combat_engaged

  getter child_ready_called : Bool = false

  def _ready : Void
    super
    @child_ready_called = true
  end
end

test_suite "SubclassInheritance" do
  test "Pillar 1: ClassRegistry partitions properties and signals without ancestor collisions" do
    gp = Godot::ClassRegistry.find("SuiteGrandparentEntity")
    assert_not_nil gp, "SuiteGrandparentEntity must exist in ClassRegistry"
    gp_props = gp.not_nil!.properties.map(&.name)
    assert_true gp_props.includes?("entity_id")
    assert_true gp_props.includes?("speed")
    assert_eq gp_props.size, 2

    parent = Godot::ClassRegistry.find("SuiteParentEntity")
    assert_not_nil parent, "SuiteParentEntity must exist in ClassRegistry"
    parent_props = parent.not_nil!.properties.map(&.name)
    assert_true parent_props.includes?("faction")
    assert_true parent_props.includes?("shields")
    assert_false parent_props.includes?("entity_id"), "Parent must not duplicate entity_id from Grandparent"
    assert_false parent_props.includes?("speed"), "Parent must not duplicate speed from Grandparent"
    assert_eq parent_props.size, 2

    child = Godot::ClassRegistry.find("SuiteChildEntity")
    assert_not_nil child, "SuiteChildEntity must exist in ClassRegistry"
    child_props = child.not_nil!.properties.map(&.name)
    assert_true child_props.includes?("combat_rating")
    assert_true child_props.includes?("stealth_mode")
    assert_false child_props.includes?("entity_id"), "Child must not duplicate entity_id"
    assert_false child_props.includes?("speed"), "Child must not duplicate speed"
    assert_false child_props.includes?("faction"), "Child must not duplicate faction"
    assert_false child_props.includes?("shields"), "Child must not duplicate shields"
    assert_eq child_props.size, 2

    # Verify signals are cleanly partitioned
    assert_eq gp.not_nil!.signals.map(&.name), ["entity_spawned"]
    assert_eq parent.not_nil!.signals.map(&.name), ["faction_changed"]
    assert_eq child.not_nil!.signals.map(&.name), ["combat_engaged"]
  end

  test "Pillar 2: Native Godot creation, direct mutation, and dynamic Variant reflection" do
    node = Godot.create(SuiteChildEntity)
    assert_true node.alive?, "SuiteChildEntity must be alive in ObjectDB"

    # Default values across all 3 tiers
    assert_eq node.entity_id, 10
    assert_in_delta node.speed, 5.0_f32, 0.001_f32
    assert_eq node.faction, "cyber"
    assert_eq node.shields, 50
    assert_in_delta node.combat_rating, 98.7_f32, 0.001_f32
    assert_true node.stealth_mode

    # Direct mutation
    node.entity_id = 99
    node.speed = 12.5_f32
    node.faction = "sol"
    node.shields = 120
    node.combat_rating = 210.0_f32
    node.stealth_mode = false

    assert_eq node.entity_id, 99
    assert_in_delta node.speed, 12.5_f32, 0.001_f32
    assert_eq node.faction, "sol"
    assert_eq node.shields, 120
    assert_in_delta node.combat_rating, 210.0_f32, 0.001_f32
    assert_false node.stealth_mode

    # Dynamic Variant reflection via get/set across all 3 tiers
    node.call("set", "entity_id", 333_i64)
    node.call("set", "faction", "vanguard")
    node.call("set", "combat_rating", 350.5_f64)
    node.call("set", "stealth_mode", true)

    assert_eq node.entity_id, 333
    assert_eq node.faction, "vanguard"
    assert_in_delta node.combat_rating, 350.5_f32, 0.001_f32
    assert_true node.stealth_mode

    v_id = node.call_i64("get", "entity_id")
    assert_eq v_id, 333_i64

    v_fac = node.call_str("get", "faction")
    assert_eq v_fac, "vanguard"

    v_atk = node.call_f64("get", "combat_rating")
    assert_in_delta v_atk, 350.5_f64, 0.001_f64

    v_stealth = node.call_bool("get", "stealth_mode")
    assert_true v_stealth

    node.destroy
    assert_true node.destroyed?
  end

  test "Pillar 3: Polymorphic multi-tier signal connections and emission" do
    node = Godot.create(SuiteChildEntity)

    spawned_id = 0
    received_faction = ""
    combat_fired = false

    node.entity_spawned.connect do |id|
      spawned_id = id
    end

    node.faction_changed.connect do |f|
      received_faction = f
    end

    node.combat_engaged.connect do
      combat_fired = true
    end

    node.entity_spawned.emit(888)
    node.faction_changed.emit("nebula")
    node.combat_engaged.emit

    assert_eq spawned_id, 888
    assert_eq received_faction, "nebula"
    assert_true combat_fired

    node.destroy
  end

  test "Pillar 4: SceneTree mounting and hierarchical lifecycle execution" do
    root = Godot.create(Godot::Node2D)
    child = Godot.create(SuiteChildEntity)

    assert_false child.gp_ready_called
    assert_false child.parent_ready_called
    assert_false child.child_ready_called

    root.add_child(child)

    # In engine, ready is dispatched when entered tree
    child._ready

    assert_true child.gp_ready_called, "Grandparent _ready must execute"
    assert_true child.parent_ready_called, "Parent _ready must execute via super"
    assert_true child.child_ready_called, "Child _ready must execute"

    root.remove_child(child)
    child.destroy
    root.destroy
  end

  test "Pillar 5: Quantitative zero-leak verification under cyclic subclass instantiation" do
    assert_no_leak do
      nodes = Array(SuiteChildEntity).new(25)
      25.times do
        n = Godot.create(SuiteChildEntity)
        n.entity_id = 7
        n.faction = "temp"
        nodes << n
      end
      nodes.each(&.destroy)
      nodes.clear
    end
  end
end
