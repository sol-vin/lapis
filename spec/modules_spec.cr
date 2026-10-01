require "./spec_helper"

# A reusable damage & health component module
gmodule SpecDamageable do
  signal health_changed(current : Int32, max : Int32)
  signal died

  @[Export(range: 0..500)]
  property health : Int32 = 100

  @[Export]
  property max_health : Int32 = 100

  @[Export]
  property defense : Float32 = 5.0_f32

  @[Export]
  property is_invulnerable : Bool = false

  @[Export]
  property status_name : String = "Normal"

  property ready_hook_called : Bool = false

  def _ready : Void
    super
    self.ready_hook_called = true
  end

  @[ExportToolButton("Reset Stats")]
  def reset_stats : Void
    self.health = self.max_health
    self.is_invulnerable = false
  end

  def take_damage(amount : Int32) : Void
    return if self.is_invulnerable
    actual = Math.max(0, amount - self.defense.to_i32)
    self.health = Math.max(0, self.health - actual)
    emit(health_changed, self.health, self.max_health)
    emit(died) if self.health == 0
  end

  def heal(amount : Int32) : Void
    self.health = Math.min(self.max_health, self.health + amount)
    emit(health_changed, self.health, self.max_health)
  end
end

# An interactive interface module with an abstract method contract
gmodule SpecInteractable do
  signal interacted(actor_name : String)

  @[Export]
  property prompt : String = "Press E to interact"

  abstract def on_interact(actor : String) : Void
end

# A composed module inheriting SpecDamageable
gmodule SpecCombatant < SpecDamageable do
  signal attack_landed(target : String, damage : Int32)

  @[Export]
  property attack_power : Int32 = 25

  def perform_attack(target_name : String) : Int32
    dmg = self.attack_power
    emit(attack_landed, target_name, dmg)
    dmg
  end
end

# A game node mixing in both SpecDamageable and SpecInteractable
node SpecHeroNode < Godot::Node2D do
  include SpecDamageable
  include SpecInteractable

  @[Export]
  property hero_title : String = "Champion"

  property interactions_count : Int32 = 0
  property hero_ready_called : Bool = false

  def _ready : Void
    super
    self.hero_ready_called = true
  end

  def on_interact(actor : String) : Void
    self.interactions_count += 1
    emit(interacted, actor)
  end
end

# A boss node using the composed SpecCombatant module
node SpecBossNode < Godot::Node3D do
  include SpecCombatant

  @[Export]
  property boss_phase : Int32 = 1
end

# A spatial locomotion module
gmodule SpecMovable do
  signal position_shifted(new_x : Float32, new_y : Float32)

  @[Export]
  property move_speed : Float32 = 12.0_f32

  @[Export]
  property velocity : Godot::Vector2 = Godot::Vector2.new(0.0_f32, 0.0_f32)

  def shift_position(dx : Float32, dy : Float32) : Void
    @velocity = Godot::Vector2.new(@velocity.x + dx, @velocity.y + dy)
    emit(position_shifted, @velocity.x, @velocity.y)
  end
end

# An inventory container module
gmodule SpecInventory do
  signal item_stashed(name : String, count : Int32)

  @[Export]
  property max_slots : Int32 = 24

  property items_count : Int32 = 0

  def stash_item(name : String) : Bool
    return false if @items_count >= @max_slots
    @items_count += 1
    emit(item_stashed, name, @items_count)
    true
  end
end

# A tactical coordinator module that cross-calls sibling module methods on the host
gmodule SpecTactician do
  def emergency_retreat : Bool
    if self.health < 20
      self.shift_position(-self.move_speed, 0.0_f32)
      true
    else
      false
    end
  end
end

# A multi-trait hero node including 4 distinct modules
node SpecMultiTraitHero < Godot::Node2D do
  include SpecDamageable
  include SpecMovable
  include SpecInventory
  include SpecTactician

  @[Export]
  property hero_guild : String = "Vanguard"
end

# A subclass node extending SpecHeroNode and adding further exported properties
node SpecAdvancedHeroNode < SpecHeroNode do
  @[Export]
  property prestige_level : Int32 = 5
end

describe "Crystal Modules & Mixins (gmodule)" do
  it "registers module properties into ClassRegistry for including nodes" do
    entry = Godot::ClassRegistry.entries.find { |e| e.class_name == "SpecHeroNode" }
    entry.should_not be_nil
    if e = entry
      prop_names = e.properties.map(&.name)
      prop_names.should contain("hero_title")
      prop_names.should contain("prompt")
      prop_names.should contain("health")
      prop_names.should contain("max_health")
      prop_names.should contain("defense")
      prop_names.should contain("is_invulnerable")
      prop_names.should contain("status_name")
    end
  end

  it "registers module signals into ClassRegistry for including nodes" do
    entry = Godot::ClassRegistry.entries.find { |e| e.class_name == "SpecHeroNode" }
    entry.should_not be_nil
    if e = entry
      sig_names = e.signals.map(&.name)
      sig_names.should contain("interacted")
      sig_names.should contain("health_changed")
      sig_names.should contain("died")
    end
  end

  it "supports composed module inheritance (module inheriting module)" do
    entry = Godot::ClassRegistry.entries.find { |e| e.class_name == "SpecBossNode" }
    entry.should_not be_nil
    if e = entry
      prop_names = e.properties.map(&.name)
      # Direct property
      prop_names.should contain("boss_phase")
      # From SpecCombatant
      prop_names.should contain("attack_power")
      # From SpecDamageable (via SpecCombatant)
      prop_names.should contain("health")
      prop_names.should contain("max_health")
      prop_names.should contain("defense")

      sig_names = e.signals.map(&.name)
      sig_names.should contain("attack_landed")
      sig_names.should contain("health_changed")
      sig_names.should contain("died")
    end
  end

  it "correctly initializes default property values declared in modules" do
    hero = SpecHeroNode.new
    hero.health.should eq(100)
    hero.max_health.should eq(100)
    hero.defense.should eq(5.0_f32)
    hero.is_invulnerable.should be_false
    hero.status_name.should eq("Normal")
    hero.prompt.should eq("Press E to interact")
    hero.hero_title.should eq("Champion")
  end

  it "mutates module properties and executes module gameplay methods" do
    hero = SpecHeroNode.new
    hero.take_damage(25) # 25 - 5 defense = 20 damage
    hero.health.should eq(80)

    hero.heal(10)
    hero.health.should eq(90)

    hero.is_invulnerable = true
    hero.take_damage(50)
    hero.health.should eq(90) # unchanged due to invulnerability
  end

  it "dispatches _godot_set_property and _godot_get_property through module chain" do
    hero = SpecHeroNode.new

    # Set Int32 property from bridge
    new_health = 42_i64
    hero._godot_set_property("health", pointerof(new_health).as(Void*))
    hero.health.should eq(42)

    # Get Int32 property to bridge
    ret_health = 0_i64
    hero._godot_get_property("health", pointerof(ret_health).as(Void*))
    ret_health.should eq(42)

    # Set Float32 property
    new_def = 12.5_f64
    hero._godot_set_property("defense", pointerof(new_def).as(Void*))
    hero.defense.should eq(12.5_f32)

    # Set String property
    new_status = "Poisoned"
    ptr = new_status.to_unsafe
    hero._godot_set_property("status_name", pointerof(ptr).as(Void*))
    hero.status_name.should eq("Poisoned")

    # Set Bool property
    new_invuln = 1_u8
    hero._godot_set_property("is_invulnerable", pointerof(new_invuln).as(Void*))
    hero.is_invulnerable.should be_true
  end

  it "emits and connects to typed signals declared in modules" do
    hero = SpecHeroNode.new
    changes = [] of Tuple(Int32, Int32)
    died_fired = false

    hero.health_changed.connect do |curr, max|
      changes << {curr, max}
    end

    hero.died.connect do
      died_fired = true
    end

    hero.take_damage(25)
    changes.size.should eq(1)
    changes.last.should eq({80, 100})
    died_fired.should be_false

    hero.take_damage(200) # lethal
    hero.health.should eq(0)
    died_fired.should be_true
  end

  it "enforces and executes abstract interface methods on including nodes" do
    hero = SpecHeroNode.new
    interactions = [] of String

    hero.interacted.connect do |actor|
      interactions << actor
    end

    hero.on_interact("Gandalf")
    hero.interactions_count.should eq(1)
    interactions.should eq(["Gandalf"])
  end

  it "registers and invokes ExportToolButton defined within modules" do
    entry = Godot::ClassRegistry.entries.find { |e| e.class_name == "SpecHeroNode" }
    entry.should_not be_nil
    if e = entry
      tb_prop = e.properties.find { |p| p.name == "reset_stats" }
      tb_prop.should_not be_nil
      tb_prop.not_nil!.hint.should eq(39_u32)
    end

    hero = SpecHeroNode.new
    hero.health = 30
    hero.is_invulnerable = true
    hero._godot_call_tool_button("reset_stats")
    hero.health.should eq(100)
    hero.is_invulnerable.should be_false
  end

  it "executes lifecycle hooks in modules cooperatively via super" do
    hero = SpecHeroNode.new
    hero.ready_hook_called.should be_false
    hero.hero_ready_called.should be_false

    hero._ready
    hero.ready_hook_called.should be_true
    hero.hero_ready_called.should be_true
  end

  it "supports multi-trait composition across 4 distinct gmodules in a single node" do
    entry = Godot::ClassRegistry.entries.find { |e| e.class_name == "SpecMultiTraitHero" }
    entry.should_not be_nil
    if e = entry
      prop_names = e.properties.map(&.name)
      prop_names.should contain("hero_guild")
      prop_names.should contain("health")
      prop_names.should contain("max_health")
      prop_names.should contain("defense")
      prop_names.should contain("is_invulnerable")
      prop_names.should contain("status_name")
      prop_names.should contain("move_speed")
      prop_names.should contain("velocity")
      prop_names.should contain("max_slots")

      sig_names = e.signals.map(&.name)
      sig_names.should contain("health_changed")
      sig_names.should contain("died")
      sig_names.should contain("position_shifted")
      sig_names.should contain("item_stashed")
    end
  end

  it "enables cross-module method invocation and state interaction on host node" do
    hero = SpecMultiTraitHero.new
    hero.health = 15
    hero.emergency_retreat.should be_true
    hero.velocity.x.should eq(-12.0_f32)

    hero.health = 50
    hero.emergency_retreat.should be_false
  end

  it "supports signal forwarding across multiple mixed-in traits" do
    hero = SpecMultiTraitHero.new
    shifted_coords = {0.0_f32, 0.0_f32}
    stashed_data = {"", 0}

    hero.position_shifted.connect do |x, y|
      shifted_coords = {x, y}
    end

    hero.item_stashed.connect do |name, count|
      stashed_data = {name, count}
    end

    hero.shift_position(5.0_f32, 2.5_f32)
    shifted_coords.should eq({5.0_f32, 2.5_f32})

    hero.stash_item("Elixir")
    stashed_data.should eq({"Elixir", 1})
  end

  it "preserves and aggregates module properties through subclass inheritance" do
    entry = Godot::ClassRegistry.entries.find { |e| e.class_name == "SpecAdvancedHeroNode" }
    entry.should_not be_nil
    if e = entry
      prop_names = e.properties.map(&.name)
      prop_names.should contain("prestige_level")
      prop_names.should contain("prompt")
      prop_names.should contain("health")
      prop_names.should contain("max_health")

      sig_names = e.signals.map(&.name)
      sig_names.should contain("interacted")
      sig_names.should contain("health_changed")
      sig_names.should contain("died")
    end

    adv_hero = SpecAdvancedHeroNode.new
    adv_hero.prestige_level.should eq(5)
    adv_hero.hero_title.should eq("Champion")
    adv_hero.health.should eq(100)
  end
end
