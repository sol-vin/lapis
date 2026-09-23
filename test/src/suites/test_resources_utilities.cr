# =============================================================================
# LibGodot Test Suite: Core Data Resources & RefCounted Engine Utilities
# =============================================================================

include Lapis::Test


test_resources "ConfigFile key/value persistence and sections" do
  cfg = Godot.create(Godot::ConfigFile)
  cfg.set_value("audio", "master_volume", 1.0_f64)
  assert_true cfg.has_section("audio")
  assert_true cfg.has_section?("audio")
  assert_true cfg.has_section_key("audio", "master_volume")
  assert_true cfg.has_section_key?("audio", "master_volume")
  assert_approx_eq cfg.get_value_f64("audio", "master_volume"), 1.0_f64

  # Indexer brackets ergonomics
  cfg["display", "fullscreen"] = true
  assert_true cfg.has_section?("display")
  assert_true cfg.has_section_key?("display", "fullscreen")
  assert_true cfg.get_value_bool("display", "fullscreen")

  cfg.erase_section("audio")
  assert_false cfg.has_section("audio")
  assert_false cfg.has_section?("audio")
  cfg.destroy
end

test_resources "AStar2D graph pathfinding point registration and connection" do
  astar = Godot.create(Godot::AStar2D)
  astar.add_point(1_i64, Godot::Vector2.new(0.0, 0.0), 1.0_f64)
  astar.add_point(2_i64, Godot::Vector2.new(10.0, 0.0), 1.0_f64)

  assert_true astar.has_point(1_i64)
  assert_true astar.has_point?(1_i64)
  assert_false astar.has_point(99_i64)
  assert_false astar.has_point?(99_i64)

  astar.connect_points(1_i64, 2_i64, true)
  assert_true astar.are_points_connected(1_i64, 2_i64, true)
  assert_true astar.points_connected?(1_i64, 2_i64, true)

  p1 = astar.get_point_position(1_i64)
  assert_approx_eq p1.x, 0.0_f32

  astar.clear
  assert_false astar.has_point?(1_i64)
  astar.destroy
end

test_resources "AStar3D graph pathfinding point registration and connectivity" do
  astar3d = Godot.create(Godot::AStar3D)
  astar3d.add_point(10_i64, Godot::Vector3.new(0.0, 0.0, 0.0), 1.0_f64)
  astar3d.add_point(20_i64, Godot::Vector3.new(0.0, 10.0, 0.0), 1.0_f64)

  assert_true astar3d.has_point(10_i64)
  assert_true astar3d.has_point?(10_i64)
  assert_false astar3d.has_point(99_i64)
  assert_false astar3d.has_point?(99_i64)

  astar3d.connect_points(10_i64, 20_i64, true)
  assert_true astar3d.are_points_connected(10_i64, 20_i64, true)
  assert_true astar3d.points_connected?(10_i64, 20_i64, true)

  astar3d.clear
  assert_false astar3d.has_point?(10_i64)
  astar3d.destroy
end

test_resources "FastNoiseLite procedural noise sampling and frequencies" do
  fnl = Godot.create(Godot::FastNoiseLite)
  fnl.set_seed(4242_i64)
  assert_eq fnl.get_seed, 4242_i64

  fnl.set_frequency(0.05_f64)
  assert_approx_eq fnl.get_frequency.to_f32, 0.05_f32

  n1 = fnl.get_noise_2d(10.0_f64, 20.0_f64)
  n2 = fnl.get_noise_2d(10.0_f64, 20.0_f64)
  assert_approx_eq n1.to_f32, n2.to_f32 # Deterministic

  fnl.destroy
end

test_resources "RandomNumberGenerator deterministic seeding and random ranges" do
  rng = Godot.create(Godot::RandomNumberGenerator)
  rng.set_seed(987654321_i64)

  r_int = rng.randi_range(1_i64, 100_i64)
  assert_true r_int >= 1_i64 && r_int <= 100_i64

  r_float = rng.randf_range(10.0_f64, 20.0_f64)
  assert_true r_float >= 10.0 && r_float <= 20.0
  rng.destroy
end

test_resources "StyleBoxFlat margins and background color" do
  sbf = Godot.create(Godot::StyleBoxFlat)
  sbf.set_bg_color(Godot::Color.new(0.2, 0.2, 0.2, 1.0))
  assert_approx_eq sbf.get_bg_color.r, 0.2_f32

  sbf.set_border_width(Godot::Side::Left.to_i64, 4_i64)
  assert_eq sbf.get_border_width(Godot::Side::Left.to_i64), 4_i64
  sbf.destroy
end

test_resources "Environment ambient lighting and glow settings" do
  env = Godot.create(Godot::Environment)
  env.set_ambient_light_color(Godot::Color.new(0.05, 0.05, 0.1, 1.0))
  assert_approx_eq env.get_ambient_light_color.b, 0.1_f32

  env.set_glow_enabled(true)
  assert_true env.is_glow_enabled
  env.destroy
end

# Custom Resource declared using DSL macro
resource CustomGameItem < Resource do
  @[Export]
  property item_name : String = "Excalibur"

  @[Export]
  property power : Int32 = 120

  @[Export]
  property cost : Float64 = 850.0

  @[Export]
  property is_rare : Bool = true
end

test_resources "Instantiating and mutating custom Resource subclass in Crystal" do
  item = Godot.create(CustomGameItem)
  assert_not_nil item, "CustomGameItem should be instantiated via Godot.create"
  assert_true item.alive?, "CustomGameItem should be alive in ObjectDB"

  # Verify default exported properties
  assert_eq item.item_name, "Excalibur"
  assert_eq item.power, 120
  assert_approx_eq item.cost, 850.0
  assert_true item.is_rare

  # Mutate properties in Crystal
  item.item_name = "Mjolnir"
  item.power = 250
  item.cost = 1500.0
  item.is_rare = false

  assert_eq item.item_name, "Mjolnir"
  assert_eq item.power, 250
  assert_approx_eq item.cost, 1500.0
  assert_false item.is_rare
  item.destroy
end

test_resources "Instantiating and configuring built-in engine resources in Crystal" do
  # StandardMaterial3D - using typed property setters and getters
  mat = Godot.create(Godot::StandardMaterial3D)
  mat.roughness = 0.65_f32
  assert_true mat.alive?
  assert_approx_eq mat.roughness.to_f64, 0.65

  # Curve - using strongly-typed method bindings
  curve = Godot.create(Godot::Curve)
  curve.add_point(Godot::Vector2.new(0.0, 0.0))
  curve.add_point(Godot::Vector2.new(1.0, 1.0))
  val = curve.sample(0.5_f64)
  assert_true val >= 0.0 && val <= 1.0, "Curve sample should be valid interpolated float"

  # Gradient - using strongly-typed method bindings
  grad = Godot.create(Godot::Gradient)
  grad.set_color(0_i64, Godot::Color.new(1.0, 0.0, 0.0, 1.0))
  assert_true grad.alive?

  mat.destroy
  curve.destroy
  grad.destroy
end

test_resources "Saving custom resource to disk via ResourceSaver and loading back via ResourceLoader" do
  item = Godot.create(CustomGameItem)
  item.item_name = "AegisShield"
  item.power = 180

  save_path = "user://test_custom_item.tres"
  err = Godot.resource_saver.save(item, save_path)
  assert_true err == Godot::Error::Ok || err.value == 0_i64, "ResourceSaver.save should return 0 (OK)"

  # Load the resource back using ResourceLoader / Godot.load
  loaded = Godot.load(save_path, cache_mode: 0_i64)
  assert_not_nil loaded, "ResourceLoader should load saved .tres file"
  assert_true loaded.alive?, "Loaded resource must be alive"

  # Verify persisted properties on loaded resource
  loaded_name = loaded.call_str("get", "item_name")
  loaded_power = loaded.call_i64("get", "power")
  assert_eq loaded_name, "AegisShield", "Loaded resource must retain item_name"
  assert_eq loaded_power, 180_i64, "Loaded resource must retain power"

  item.take_over_path("")
  item.destroy
  loaded.take_over_path("")
  loaded.destroy
end

test_resources "Passing custom Resource to GDScript, verifying properties, and mutating across boundary" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
  controller = scene.instantiate
  root.add_child(controller)

  item = Godot.create(CustomGameItem)
  item.item_name = "ShadowDagger"
  item.power = 75

  # GDScript reads resource name and power
  gd_name = controller.call_str("inspect_resource_name", item)
  gd_power = controller.call_i64("inspect_resource_power", item)
  assert_eq gd_name, "ShadowDagger", "GDScript should read item_name from Crystal resource"
  assert_eq gd_power, 75_i64, "GDScript should read power from Crystal resource"

  # GDScript modifies resource power
  success = controller.call_bool("modify_resource_power", item, 140_i64)
  assert_true success, "GDScript modify_resource_power should succeed"
  assert_eq item.power, 140, "Crystal resource power must reflect mutation made by GDScript"

  # Save to disk from Crystal, then load from disk in GDScript
  save_path = "user://gdscript_read_test.tres"
  Godot.resource_saver.save(item, save_path)
  disk_power = controller.call_i64("load_resource_from_disk_and_get_power", save_path)
  assert_eq disk_power, 140_i64, "GDScript ResourceLoader should read serialized power from disk"

  root.remove_child(controller)
  controller.destroy
  scene.destroy
  item.take_over_path("")
  item.destroy
end
