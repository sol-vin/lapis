# =============================================================================
# LibGodot Test Suite: Scene Serialization, Persistence & Instantiation
# =============================================================================

include Lapis::Test

enum PlayerClassEnum
  Warrior = 0
  Mage    = 1
  Rogue   = 2
  Paladin = 3
end

enum WeaponElementEnum
  Physical  = 0
  Fire      = 1
  Ice       = 2
  Lightning = 3
end

enum BossPhaseEnum
  PhaseOne   = 1
  PhaseTwo   = 2
  PhaseThree = 3
end

node ComplexPlayer2D < Godot::CharacterBody2D do
  @[Export]
  property character_name : String = "DefaultHero"

  @[Export]
  property health : Float64 = 100.0

  @[Export]
  property mana : Float32 = 50.0_f32

  @[Export]
  property level : Int32 = 1

  @[Export]
  property experience : Int64 = 0_i64

  @[Export]
  property is_alive : Bool = true

  @[Export]
  property velocity_vector : Godot::Vector2 = Godot::Vector2.new(0.0, 0.0)

  @[Export]
  property grid_coordinates : Godot::Vector2i = Godot::Vector2i.new(0, 0)

  @[Export]
  property aura_color : Godot::Color = Godot::Color.new(1.0, 1.0, 1.0, 1.0)

  @[ExportEnum(PlayerClassEnum)]
  property character_class : PlayerClassEnum = PlayerClassEnum::Warrior

  property enter_tree_count : Int32 = 0
  property ready_count : Int32 = 0
  property process_count : Int32 = 0
  property exit_tree_count : Int32 = 0

  def _enter_tree : Void
    @enter_tree_count += 1
  end

  def _ready : Void
    @ready_count += 1
  end

  def _process(delta : Float64) : Void
    @process_count += 1
  end

  def _exit_tree : Void
    @exit_tree_count += 1
  end
end

node ComplexWeapon2D < Godot::Node2D do
  @[Export]
  property weapon_title : String = "Iron Sword"

  @[Export]
  property attack_power : Float32 = 10.0_f32

  @[Export]
  property durability : Int32 = 50

  @[ExportEnum(WeaponElementEnum)]
  property elemental_type : WeaponElementEnum = WeaponElementEnum::Physical

  @[ExportColorNoAlpha]
  property glow_tint : Godot::Color = Godot::Color.new(1.0, 1.0, 1.0, 1.0)
end

node ComplexEntity3D < Godot::Node3D do
  export_category "Entity Stats" do
    export_group "Attributes", prefix: "attr_" do
      @[Export]
      property attr_name : String = "DefaultBoss"

      @[Export]
      property attr_max_hp : Float64 = 1000.0

      @[Export]
      property attr_defense : Int32 = 50

      @[Export]
      property attr_scale_vector : Godot::Vector3 = Godot::Vector3.new(1.0, 1.0, 1.0)

      @[Export]
      property attr_offset_grid : Godot::Vector3i = Godot::Vector3i.new(0, 0, 0)

      @[Export]
      property attr_theme_color : Godot::Color = Godot::Color.new(1.0, 0.0, 0.0, 1.0)

      @[ExportEnum(BossPhaseEnum)]
      property attr_phase : BossPhaseEnum = BossPhaseEnum::PhaseOne
    end

    @[Export]
    property is_invulnerable : Bool = false
  end
end

node ComplexHitbox3D < Godot::Area3D do
  @[Export]
  property radius : Float32 = 1.0_f32

  @[Export]
  property damage_multiplier : Float64 = 1.0

  @[Export]
  property hitbox_active : Bool = true
end

node ComplexInventoryUI < Godot::Control do
  @[Export]
  property title : String = "Inventory"

  @[Export]
  property capacity : Int32 = 20

  @[Export]
  property gold : Int64 = 100_i64

  @[Export]
  property background_tint : Godot::Color = Godot::Color.new(0.2, 0.2, 0.2, 1.0)

  @[Export]
  property view_bounds : Godot::Rect2 = Godot::Rect2.new(0.0, 0.0, 200.0, 300.0)

  @[Export]
  property is_visible_panel : Bool = true
end

# -----------------------------------------------------------------------------
# Test Cases
# -----------------------------------------------------------------------------

test_scenes "Loading and instantiating test_crystal_player_2d.tscn from disk into Crystal" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_crystal_player_2d.tscn")
  assert_not_nil scene, "PackedScene must load from res://scenes/test_crystal_player_2d.tscn"

  # Instantiate typed as ComplexPlayer2D
  player = scene.instantiate_as(ComplexPlayer2D)
  assert_not_nil player, "Instantiated node must cast to ComplexPlayer2D"
  assert_eq player.name, "HeroPlayer"

  # Verify values loaded from .tscn file
  assert_eq player.character_name, "Arthas"
  assert_approx_eq player.health, 250.0
  assert_approx_eq player.mana.to_f64, 120.0
  assert_eq player.level, 25
  assert_eq player.experience, 75000_i64
  assert_true player.is_alive
  assert_approx_eq player.velocity_vector.x, 200.0_f32
  assert_approx_eq player.velocity_vector.y, -100.0_f32
  assert_eq player.grid_coordinates.x, 14
  assert_eq player.grid_coordinates.y, 28
  assert_eq player.character_class, PlayerClassEnum::Paladin

  # Verify nested Crystal child node (ComplexWeapon2D)
  weapon = player.find_child_as(ComplexWeapon2D, "EquippedWeapon")
  assert_not_nil weapon, "EquippedWeapon child node must exist and cast to ComplexWeapon2D"
  assert_eq weapon.not_nil!.weapon_title, "Frostmourne"
  assert_approx_eq weapon.not_nil!.attack_power.to_f64, 99.5
  assert_eq weapon.not_nil!.durability, 100
  assert_eq weapon.not_nil!.elemental_type, WeaponElementEnum::Ice

  # Verify native Godot child nodes
  col = player.find_child("CollisionShape2D")
  assert_not_nil col, "Native CollisionShape2D child must be instantiated"

  marker = player.find_child("SpawnAnchor")
  assert_not_nil marker, "Native SpawnAnchor Marker2D must be instantiated"

  player.destroy
  scene.destroy
end

test_scenes "Loading and instantiating 3D and UI Crystal scenes from disk" do
  # 1. 3D Scene
  scene_3d = Godot.load_as(Godot::PackedScene, "res://scenes/test_crystal_entity_3d.tscn")
  assert_not_nil scene_3d

  entity = scene_3d.instantiate_as(ComplexEntity3D)
  assert_not_nil entity
  assert_eq entity.name, "DragonBoss"
  assert_eq entity.attr_name, "Smaug"
  assert_approx_eq entity.attr_max_hp, 8888.0
  assert_eq entity.attr_defense, 120
  assert_approx_eq entity.attr_scale_vector.x, 3.0_f32
  assert_approx_eq entity.attr_scale_vector.y, 3.0_f32
  assert_approx_eq entity.attr_scale_vector.z, 3.0_f32
  assert_eq entity.attr_offset_grid.y, 10
  assert_eq entity.attr_phase, BossPhaseEnum::PhaseTwo
  assert_false entity.is_invulnerable

  hitbox = entity.find_child_as(ComplexHitbox3D, "HitboxArea")
  assert_not_nil hitbox
  assert_approx_eq hitbox.not_nil!.radius.to_f64, 4.5
  assert_approx_eq hitbox.not_nil!.damage_multiplier, 2.0
  assert_true hitbox.not_nil!.hitbox_active

  entity.destroy
  scene_3d.destroy

  # 2. UI Control Scene
  scene_ui = Godot.load_as(Godot::PackedScene, "res://scenes/test_crystal_inventory_ui.tscn")
  assert_not_nil scene_ui

  ui = scene_ui.instantiate_as(ComplexInventoryUI)
  assert_not_nil ui
  assert_eq ui.name, "InventoryPanel"
  assert_eq ui.title, "Royal Vault"
  assert_eq ui.capacity, 128
  assert_eq ui.gold, 500000_i64
  assert_true ui.is_visible_panel
  assert_approx_eq ui.view_bounds.position.x, 20.0_f32
  assert_approx_eq ui.view_bounds.size.x, 500.0_f32

  label = ui.find_child("TitleLabel")
  assert_not_nil label

  ui.destroy
  scene_ui.destroy
end

test_scenes "Instantiating composite scene with mixed native and Crystal hierarchy" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_crystal_composite_world.tscn")
  assert_not_nil scene

  root_world = scene.instantiate
  assert_not_nil root_world
  assert_eq root_world.name, "WorldRoot"

  # Traverse to Crystal hero
  hero = root_world.get_node_as(ComplexPlayer2D, "Hero")
  assert_not_nil hero
  assert_eq hero.character_name, "Ranger"
  assert_approx_eq hero.health, 180.0
  assert_eq hero.level, 15
  assert_eq hero.character_class, PlayerClassEnum::Rogue

  # Traverse through intermediate native Node2D to equipped weapon
  bow = root_world.get_node_as(ComplexWeapon2D, "Hero/WeaponMount/EquippedBow")
  assert_not_nil bow
  assert_eq bow.weapon_title, "Windrunner Bow"
  assert_approx_eq bow.attack_power.to_f64, 65.0
  assert_eq bow.elemental_type, WeaponElementEnum::Lightning

  # Traverse to Crystal UI HUD
  hud = root_world.get_node_as(ComplexInventoryUI, "HUD")
  assert_not_nil hud
  assert_eq hud.title, "Quick HUD"
  assert_eq hud.capacity, 16
  assert_eq hud.gold, 2500_i64

  root_world.destroy
  scene.destroy
end

test_scenes "Lifecycle execution and clean unloading of instantiated Crystal scene" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_crystal_player_2d.tscn")
  player = scene.instantiate_as(ComplexPlayer2D)

  # Before adding to tree, lifecycle counters should be 0
  assert_eq player.enter_tree_count, 0
  assert_eq player.ready_count, 0

  # Add to scene tree
  root.add_child(player)
  player._godot_call_virtual("_enter_tree", 0.0)
  player._godot_call_virtual("_ready", 0.0)

  assert_true player.enter_tree_count >= 1, "Enter tree must trigger"
  assert_true player.ready_count >= 1, "Ready must trigger"

  # Process step
  player._godot_call_virtual("_process", 0.016)
  assert_true player.process_count >= 1, "Process must trigger"

  # Clean unload: remove from tree and call _exit_tree
  root.remove_child(player)
  player._godot_call_virtual("_exit_tree", 0.0)
  assert_true player.exit_tree_count >= 1, "Exit tree must trigger"

  # Destruction
  player.destroy
  assert_false player.alive?, "Player must report not alive after destruction"
  scene.destroy
end

test_scenes "Dynamic scene tree construction, PackedScene packing, and ResourceSaver disk save" do
  player = Godot.create(ComplexPlayer2D)
  player.name = "DynamicHero"
  player.character_name = "Geralt of Rivia"
  player.health = 320.5
  player.mana = 180.0_f32
  player.level = 70
  player.experience = 987654321_i64
  player.is_alive = true
  player.velocity_vector = Godot::Vector2.new(45.0, -90.0)
  player.grid_coordinates = Godot::Vector2i.new(21, 42)
  player.aura_color = Godot::Color.new(0.5, 0.2, 0.8, 1.0)
  player.character_class = PlayerClassEnum::Mage

  # Attach child weapon
  weapon = Godot.create(ComplexWeapon2D)
  weapon.name = "SilverBlade"
  weapon.weapon_title = "Aerondight"
  weapon.attack_power = 180.75_f32
  weapon.durability = 250
  weapon.elemental_type = WeaponElementEnum::Fire
  weapon.glow_tint = Godot::Color.new(1.0, 0.5, 0.0, 1.0)

  player.add_child(weapon)
  weapon.owner = player

  # Pack into PackedScene
  packed = Godot.create(Godot::PackedScene)
  pack_result = packed.pack(player)
  assert_eq pack_result, 0_i64, "PackedScene.pack must return OK (0)"

  # Save to user:// sandbox storage
  save_path = "user://test_saved_dynamic_hero.tscn"
  save_err = Godot.resource_saver.save(packed, save_path, 0_i64)
  assert_eq save_err, 0_i64, "ResourceSaver.save must succeed and return OK (0)"

  # Cleanup in-memory source node
  player.destroy
  packed.destroy
end

test_scenes "2x check: Reloading dynamic scene from disk and verifying all serialized values" do
  save_path = "user://test_saved_dynamic_hero.tscn"
  reloaded_scene = Godot.load_as(Godot::PackedScene, save_path)
  assert_not_nil reloaded_scene, "Saved scene must load from #{save_path}"

  reloaded_player = reloaded_scene.instantiate_as(ComplexPlayer2D)
  assert_not_nil reloaded_player
  assert_eq reloaded_player.name, "DynamicHero"

  # 2x Check all serialized root properties
  assert_eq reloaded_player.character_name, "Geralt of Rivia"
  assert_approx_eq reloaded_player.health, 320.5
  assert_approx_eq reloaded_player.mana.to_f64, 180.0
  assert_eq reloaded_player.level, 70
  assert_eq reloaded_player.experience, 987654321_i64
  assert_true reloaded_player.is_alive
  assert_approx_eq reloaded_player.velocity_vector.x, 45.0_f32
  assert_approx_eq reloaded_player.velocity_vector.y, -90.0_f32
  assert_eq reloaded_player.grid_coordinates.x, 21
  assert_eq reloaded_player.grid_coordinates.y, 42
  assert_eq reloaded_player.character_class, PlayerClassEnum::Mage

  # 2x Check all serialized child properties
  weapon = reloaded_player.find_child_as(ComplexWeapon2D, "SilverBlade")
  assert_not_nil weapon, "SilverBlade child node must persist across save/load"
  assert_eq weapon.not_nil!.weapon_title, "Aerondight"
  assert_approx_eq weapon.not_nil!.attack_power.to_f64, 180.75
  assert_eq weapon.not_nil!.durability, 250
  assert_eq weapon.not_nil!.elemental_type, WeaponElementEnum::Fire

  reloaded_player.destroy
  reloaded_scene.destroy
end

test_scenes "Mutation and re-saving scene round-trip verification" do
  # Load original saved scene
  scene = Godot.load_as(Godot::PackedScene, "user://test_saved_dynamic_hero.tscn")
  player = scene.instantiate_as(ComplexPlayer2D)

  # Mutate values
  player.character_name = "Geralt the Ascended"
  player.health = 500.0
  player.level = 100
  player.character_class = PlayerClassEnum::Paladin

  weapon = player.find_child_as(ComplexWeapon2D, "SilverBlade").not_nil!
  weapon.weapon_title = "Aerondight +10"
  weapon.attack_power = 999.0_f32
  weapon.elemental_type = WeaponElementEnum::Lightning

  # Pack and save v2
  packed_v2 = Godot.create(Godot::PackedScene)
  pack_res = packed_v2.pack(player)
  assert_eq pack_res, 0_i64

  save_v2_path = "user://test_saved_dynamic_hero_v2.tscn"
  err = Godot.resource_saver.save(packed_v2, save_v2_path, 0_i64)
  assert_eq err, 0_i64

  player.destroy
  packed_v2.destroy
  scene.destroy

  # Reload v2 and verify mutated values persisted
  scene_v2 = Godot.load_as(Godot::PackedScene, save_v2_path)
  player_v2 = scene_v2.instantiate_as(ComplexPlayer2D)

  assert_eq player_v2.character_name, "Geralt the Ascended"
  assert_approx_eq player_v2.health, 500.0
  assert_eq player_v2.level, 100
  assert_eq player_v2.character_class, PlayerClassEnum::Paladin

  weapon_v2 = player_v2.find_child_as(ComplexWeapon2D, "SilverBlade").not_nil!
  assert_eq weapon_v2.weapon_title, "Aerondight +10"
  assert_approx_eq weapon_v2.attack_power.to_f64, 999.0
  assert_eq weapon_v2.elemental_type, WeaponElementEnum::Lightning

  player_v2.destroy
  scene_v2.destroy
end

test_scenes "Repeated load, instantiate, and unload lifecycle stress test" do
  scene_path = "res://scenes/test_crystal_player_2d.tscn"

  # Perform 10 rapid instantiation, tree attachment, and teardown cycles
  10.times do |i|
    scene = Godot.load_as(Godot::PackedScene, scene_path)
    assert_not_nil scene

    inst = scene.instantiate_as(ComplexPlayer2D)
    assert_not_nil inst
    assert_eq inst.character_name, "Arthas"

    root.add_child(inst)
    inst._godot_call_virtual("_ready", 0.0)

    # Mutate to verify heap isolation per instance
    inst.health = 100.0 + i.to_f64
    assert_approx_eq inst.health, 100.0 + i.to_f64

    root.remove_child(inst)
    inst.destroy
    assert_false inst.alive?
    scene.destroy
  end
end

test_scenes "GDScript scene loading and instantiation interop" do
  scene_interop = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
  controller = scene_interop.instantiate
  root.add_child(controller)

  # Have GDScript load and inspect the Crystal scene
  verified = controller.call_bool("verify_crystal_scene_properties", "res://scenes/test_crystal_player_2d.tscn")
  assert_true verified, "GDScript must load and verify Crystal scene properties"

  root.remove_child(controller)
  controller.destroy
  scene_interop.destroy
end
