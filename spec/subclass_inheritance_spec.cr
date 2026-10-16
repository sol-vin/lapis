require "./spec_helper"

# =============================================================================
# Specification: Subclass Property & Signal Inheritance Deduplication
# =============================================================================
# Validates that multi-tier inheritance hierarchies (Grandparent -> Parent -> Child)
# properly partition exported properties and signals across ClassRegistry entries,
# preventing duplicate member registration in Godot's ClassDB.

node InheritSpecGrandparent < Godot::Node do
  @[Export]
  property entity_id : Int32 = 101

  @[Export]
  property display_name : String = "Grandparent"

  signal entity_spawned(id : Int32)
end

node InheritSpecParent < InheritSpecGrandparent do
  @[Export]
  property faction : String = "rebel"

  @[Export]
  property faction_rank : Int32 = 2

  signal faction_changed(new_faction : String)
end

node InheritSpecChild < InheritSpecParent do
  @[Export]
  property combat_rating : Float32 = 94.5_f32

  @[Export]
  property is_active : Bool = true

  signal combat_engaged
end

describe "Subclass Property & Signal Inheritance Deduplication" do
  it "registers exact properties per class in ClassRegistry without duplicating ancestor fields" do
    gp_entry = Godot::ClassRegistry.find("InheritSpecGrandparent")
    gp_entry.should_not be_nil
    gp = gp_entry.not_nil!
    gp_prop_names = gp.properties.map(&.name)
    gp_prop_names.should contain("entity_id")
    gp_prop_names.should contain("display_name")
    gp_prop_names.size.should eq(2)

    parent_entry = Godot::ClassRegistry.find("InheritSpecParent")
    parent_entry.should_not be_nil
    parent = parent_entry.not_nil!
    parent_prop_names = parent.properties.map(&.name)
    parent_prop_names.should contain("faction")
    parent_prop_names.should contain("faction_rank")
    parent_prop_names.should_not contain("entity_id")
    parent_prop_names.should_not contain("display_name")
    parent_prop_names.size.should eq(2)

    child_entry = Godot::ClassRegistry.find("InheritSpecChild")
    child_entry.should_not be_nil
    child = child_entry.not_nil!
    child_prop_names = child.properties.map(&.name)
    child_prop_names.should contain("combat_rating")
    child_prop_names.should contain("is_active")
    child_prop_names.should_not contain("entity_id")
    child_prop_names.should_not contain("display_name")
    child_prop_names.should_not contain("faction")
    child_prop_names.should_not contain("faction_rank")
    child_prop_names.size.should eq(2)
  end

  it "accurately detects properties up the inheritance chain via ClassRegistry.has_ancestor_property?" do
    child_entry = Godot::ClassRegistry.find("InheritSpecChild").not_nil!

    # Ancestor properties (from Grandparent and Parent)
    Godot::ClassRegistry.has_ancestor_property?(child_entry, "entity_id").should be_true
    Godot::ClassRegistry.has_ancestor_property?(child_entry, "display_name").should be_true
    Godot::ClassRegistry.has_ancestor_property?(child_entry, "faction").should be_true
    Godot::ClassRegistry.has_ancestor_property?(child_entry, "faction_rank").should be_true

    # Own properties (defined on Child, so not in ancestors)
    Godot::ClassRegistry.has_ancestor_property?(child_entry, "combat_rating").should be_false
    Godot::ClassRegistry.has_ancestor_property?(child_entry, "is_active").should be_false

    # Non-existent property
    Godot::ClassRegistry.has_ancestor_property?(child_entry, "undefined_field").should be_false
  end

  it "partitions signal declarations per class without duplicating ancestor signals" do
    gp = Godot::ClassRegistry.find("InheritSpecGrandparent").not_nil!
    gp.signals.map(&.name).should eq(["entity_spawned"])

    parent = Godot::ClassRegistry.find("InheritSpecParent").not_nil!
    parent.signals.map(&.name).should eq(["faction_changed"])

    child = Godot::ClassRegistry.find("InheritSpecChild").not_nil!
    child.signals.map(&.name).should eq(["combat_engaged"])
  end

  it "supports polymorphic mutation and accessors on child instances across all inheritance tiers" do
    inst = InheritSpecChild.new

    # Default values from all 3 levels
    inst.entity_id.should eq(101)
    inst.display_name.should eq("Grandparent")
    inst.faction.should eq("rebel")
    inst.faction_rank.should eq(2)
    inst.combat_rating.should eq(94.5_f32)
    inst.is_active.should be_true

    # Mutation at Grandparent level
    inst.entity_id = 555
    inst.display_name = "Grandmaster"
    inst.entity_id.should eq(555)
    inst.display_name.should eq("Grandmaster")

    # Mutation at Parent level
    inst.faction = "syndicate"
    inst.faction_rank = 5
    inst.faction.should eq("syndicate")
    inst.faction_rank.should eq(5)

    # Mutation at Child level
    inst.combat_rating = 180.25_f32
    inst.is_active = false
    inst.combat_rating.should eq(180.25_f32)
    inst.is_active.should be_false
  end

  it "connects and emits signals declared at grandparent, parent, and child levels" do
    inst = InheritSpecChild.new

    spawned_id = 0
    new_faction_received = ""
    engaged_fired = false

    inst.entity_spawned.connect do |id|
      spawned_id = id
    end

    inst.faction_changed.connect do |f|
      new_faction_received = f
    end

    inst.combat_engaged.connect do
      engaged_fired = true
    end

    inst.entity_spawned.emit(777)
    inst.faction_changed.emit("guardians")
    inst.combat_engaged.emit

    spawned_id.should eq(777)
    new_faction_received.should eq("guardians")
    engaged_fired.should be_true
  end
end
