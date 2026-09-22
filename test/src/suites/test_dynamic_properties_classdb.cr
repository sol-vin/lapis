# =============================================================================
# LibGodot Test Suite: Dynamic Property Validation, Hints & ClassDB Reflection
# Replicating godot-rust's validate_property_test.rs and get_property_list_test.rs
# =============================================================================

include Lapis::Test

node DynamicPropertyTargetNode < Godot::Node do
  @[ExportRange(0..100, step: 5)]
  property dynamic_range : Int32 = 50

  @[ExportEnum("Easy", "Normal", "Hard", "Nightmare")]
  property difficulty : String = "Normal"

  @[ExportStorage]
  property internal_secret : String = "HiddenFromEditor"

  @[ExportFile("*.svg")]
  property avatar_path : String = "res://icon.svg"

  @[ExportColorNoAlpha]
  property base_color : Godot::Color = Godot::Color.new(0.2_f32, 0.4_f32, 0.8_f32, 1.0_f32)

  @[ExportCategory("PlayerStats")]
  property stat_marker : Int32 = 1

  @[ExportGroup("Combat")]
  property attack_power : Float32 = 35.0_f32
  property defense_power : Float32 = 20.0_f32
end

test_dynamic_props "ClassDB registers typed property hints and valid hint strings for custom properties" do
  entry = Godot::ClassRegistry.find("DynamicPropertyTargetNode")
  assert_not_nil entry, "DynamicPropertyTargetNode must be registered in ClassRegistry"

  props = entry.not_nil!.properties

  range_prop = props.find { |p| p.name == "dynamic_range" }
  assert_not_nil range_prop
  assert_eq range_prop.not_nil!.hint, 1_u32, "Hint must be PROPERTY_HINT_RANGE"
  assert_eq range_prop.not_nil!.hint_string, "0,100,5"

  enum_prop = props.find { |p| p.name == "difficulty" }
  assert_not_nil enum_prop
  assert_eq enum_prop.not_nil!.hint, 2_u32, "Hint must be PROPERTY_HINT_ENUM"
  assert_eq enum_prop.not_nil!.hint_string, "Easy,Normal,Hard,Nightmare"

  file_prop = props.find { |p| p.name == "avatar_path" }
  assert_not_nil file_prop
  assert_eq file_prop.not_nil!.hint, 13_u32, "Hint must be PROPERTY_HINT_FILE"
  assert_eq file_prop.not_nil!.hint_string, "*.svg"
end

test_dynamic_props "Storage-only property is registered with PROPERTY_USAGE_STORAGE without EDITOR flag" do
  entry = Godot::ClassRegistry.find("DynamicPropertyTargetNode")
  assert_not_nil entry

  props = entry.not_nil!.properties
  secret_prop = props.find { |p| p.name == "internal_secret" }
  assert_not_nil secret_prop

  # PROPERTY_USAGE_STORAGE is 2_u32; PROPERTY_USAGE_EDITOR is 4_u32
  usage = secret_prop.not_nil!.usage
  assert_eq (usage & 2_u32), 2_u32, "Usage must include PROPERTY_USAGE_STORAGE"
  assert_eq (usage & 4_u32), 0_u32, "Usage must NOT include PROPERTY_USAGE_EDITOR"
end

test_dynamic_props "Inspector categories and groups register proper usage bitmasks" do
  entry = Godot::ClassRegistry.find("DynamicPropertyTargetNode")
  assert_not_nil entry

  props = entry.not_nil!.properties

  cat = props.find { |p| p.name == "PlayerStats" }
  assert_not_nil cat
  assert_eq (cat.not_nil!.usage & 128_u32), 128_u32, "Category usage must include PROPERTY_USAGE_CATEGORY"

  grp = props.find { |p| p.name == "Combat" }
  assert_not_nil grp
  assert_eq (grp.not_nil!.usage & 64_u32), 64_u32, "Group usage must include PROPERTY_USAGE_GROUP"
end

test_dynamic_props "Property reflection round-trip: set and get via dynamic string dispatch" do
  node = Godot.create(DynamicPropertyTargetNode)

  # Initial value verification
  assert_eq node.dynamic_range, 50
  assert_eq node.difficulty, "Normal"
  assert_approx_eq node.attack_power, 35.0_f32, 0.01

  # Modify properties via reflection dispatches
  node.call("set", "dynamic_range", 75_i64)
  node.call("set", "difficulty", "Nightmare")
  node.call("set", "attack_power", 99.5_f64)

  # Verify reflected get
  val_range = node.call_i64("get", "dynamic_range")
  val_diff = node.call_str("get", "difficulty")
  val_atk = node.call_f64("get", "attack_power")

  assert_eq val_range, 75_i64
  assert_eq val_diff, "Nightmare"
  assert_approx_eq val_atk, 99.5, 0.01

  # Verify native getters reflect the mutated state
  assert_eq node.dynamic_range, 75
  assert_eq node.difficulty, "Nightmare"
  assert_approx_eq node.attack_power, 99.5_f32, 0.01

  node.destroy
end
