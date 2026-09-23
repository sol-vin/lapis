require "../src/lapis"

puts "=== Running New Features Verification (Docs, GDScript, Enums, Singletons) ==="

# 1. Test Node with Doc Comments and XML generation
node TestDocPlayer < CharacterBody3D do
  @[Doc("Represents a test player entity")]

  # Player movement speed in pixels
  @[Export(range: 10.0_f32..500.0_f32)]
  property speed : Float32 = 250.0_f32

  # Emitted on player death
  signal player_died

  # Inflicts damage to the entity
  def take_damage(dmg : Int32) : Void
  end
end

docs = Godot::EditorDocRegistry.xml_documents
abort "Failed: expected EditorDocRegistry to have at least 1 document" if docs.empty?

player_doc = docs.find { |d| d.includes?("TestDocPlayer") }
abort "Failed: TestDocPlayer doc not found in registry" unless player_doc

abort "Failed: missing class description" unless player_doc.includes?("Represents a test player entity")
abort "Failed: missing member speed" unless player_doc.includes?("<member name=\"speed\"")
abort "Failed: missing member speed doc comment" unless player_doc.includes?("Player movement speed in pixels")
abort "Failed: missing signal player_died" unless player_doc.includes?("<signal name=\"player_died\"")
abort "Failed: missing method take_damage" unless player_doc.includes?("<method name=\"take_damage\"")
abort "Failed: missing method take_damage return type" unless player_doc.includes?("<return type=\"void\" />")
abort "Failed: missing method take_damage param" unless player_doc.includes?("<param index=\"0\" name=\"dmg\" type=\"int\" />")
abort "Failed: missing method take_damage doc comment" unless player_doc.includes?("Inflicts damage to the entity")

# Verify undocumented lifecycle callbacks are omitted from <methods>
node TestLifecycleDocNode < Godot::Node do
  def _ready : Void
  end

  def _enter_tree : Void
  end

  def _exit_tree : Void
  end
end

lc_doc = docs.find { |d| d.includes?("TestLifecycleDocNode") }
abort "Failed: TestLifecycleDocNode doc not found in registry" unless lc_doc
abort "Failed: TestLifecycleDocNode should not have method tags for undocumented lifecycle callbacks" if lc_doc.includes?("<method ")

puts "✓ Compile-time Doc Comments and Godot XML DocData generation verified!"

# 3. Test Global Enums and Singletons
abort "Failed: Key::Space enum" unless Godot::Key::Space.value == 32_i64
abort "Failed: Key::Escape enum" unless Godot::Key::Escape.value == 4194305_i64
abort "Failed: Key::Enter enum" unless Godot::Key::Enter.value == 4194309_i64

abort "Failed: Singleton Input exists" unless Godot::Input
abort "Failed: Singleton Engine exists" unless Godot::Engine

puts "✓ Global Enums & Singletons verified!"

# 4. Test Tool Scripts (@[Tool] annotation above node and inside block)
@[Tool]
node TestToolPrefixNode do
  def _ready
  end
end

node TestToolInsideNode do
  @[Tool]

  def _ready
  end
end

entry_prefix = Godot::ClassRegistry.find("TestToolPrefixNode")
abort "Failed: TestToolPrefixNode not registered" unless entry_prefix
abort "Failed: TestToolPrefixNode is_tool should be true" unless entry_prefix.is_tool

entry_inside = Godot::ClassRegistry.find("TestToolInsideNode")
abort "Failed: TestToolInsideNode not registered" unless entry_inside
abort "Failed: TestToolInsideNode is_tool should be true" unless entry_inside.is_tool

puts "✓ Tool scripts verified!"

enum CharacterRole
  Warrior = 0
  Mage    = 1
  Rogue   = 5
end

@[Flags]
enum CombatSkills
  Slash
  Shoot
  Cast
end

# 5. Test Complete Godot 4 Annotations Suite (All Exports, Groups, Classes, OnReady, RPC)
@[Icon("res://icons/player.svg")]
@[Abstract]
node TestAnnotationsSuite < CharacterBody3D do
  @[ExportEnum(CharacterRole)]
  property role : CharacterRole = CharacterRole::Warrior

  @[ExportEnum(CharacterRole)]
  property role_id : Int32 = 0

  @[Export]
  property role_auto : CharacterRole = CharacterRole::Rogue

  @[ExportFlags(CombatSkills)]
  property skills : CombatSkills = CombatSkills::Slash

  # Diagnostic warning ignore
  @[WarningIgnore("unused_variable")]
  warning_ignore "unused_parameter"

  # Inspector Categories & Groups
  export_category "Player Profile"

  export_group "Movement", prefix: "move_"
  @[ExportRange(0.0_f32, 500.0_f32, 5.0_f32)]
  property move_speed : Float32 = 250.0_f32

  @[Export(range: 10.0_f32..100.0_f32, step: 1.0_f32)]
  property move_accel : Float32 = 50.0_f32

  export_subgroup "Dashing", prefix: "dash_"
  @[Export]
  property dash_enabled : Bool = true

  @[ExportEnum("Warrior", "Mage", "Rogue")]
  property class_type : String = "Warrior"

  @[Export(enum: ["Fire", "Water", "Earth"])]
  property element : String = "Fire"

  @[ExportFile("*.png,*.jpg")]
  property avatar_file : String = "avatar.png"

  @[ExportFilePath("*.json")]
  property config_path : String = "settings.json"

  @[ExportDir]
  property save_folder : String = "saves/"

  @[ExportGlobalFile("*.txt")]
  property log_file : String = "C:/logs.txt"

  @[ExportGlobalDir]
  property root_dir : String = "C:/"

  @[ExportMultiline]
  property biography : String = "A brave adventurer."

  @[ExportPlaceholder("Enter player nickname...")]
  property nickname : String = ""

  @[ExportFlags("Attack", "Defend", "Cast", "Flee")]
  property action_flags : Int32 = 1

  @[ExportFlags2DRender]
  property render_mask_2d : Int32 = 0

  @[ExportFlags2DPhysics]
  property phys_layer_2d : Int32 = 1

  @[ExportFlags2DNavigation]
  property nav_layer_2d : Int32 = 1

  @[ExportFlags3DRender]
  property render_mask_3d : Int32 = 0

  @[ExportFlags3DPhysics]
  property phys_layer_3d : Int32 = 1

  @[ExportFlags3DNavigation]
  property nav_layer_3d : Int32 = 1

  @[ExportFlagsAvoidance]
  property avoidance_layer : Int32 = 1

  @[ExportExpEasing]
  property jump_curve : Float32 = 1.0_f32

  @[ExportColorNoAlpha]
  property tint_color : Godot::Color = Godot::Color.new

  @[ExportNodePath("Camera3D")]
  property camera_path : Godot::NodePath = Godot::NodePath.new

  @[ExportStorage]
  property internal_seed : Int64 = 123456_i64

  @[ExportToolButton("Reset Health")]
  property btn_reset = -> {
    @action_counter = 0
  }

  @[ExportToolButton("Method Pointer Button", icon: "Action")]
  property btn_method_ptr = ->action_method

  @[ExportToolButton("Lambda Button")]
  property btn_lambda = -> {
    @action_counter += 10
  }

  @[ExportToolButton("Dynamic Proc Button")]
  property btn_dynamic : Proc(Void)? = nil

  property action_counter : Int32 = 0

  def action_method : Void
    @action_counter += 1
  end

  @[ExportCustom(1, "10,200,2", 6)]
  property custom_prop : Int32 = 50

  # Node Tree Initialization (@[OnReady] and onready macro)
  @[OnReady("Sprite3D")]
  property sprite : Godot::Node?

  @[OnReady]
  property camera_3d : Godot::Node?

  @[ExportToolButton("Regenerate World", icon: "Play")]
  def regenerate_world : Void
    Godot.print("Regenerating world...")
  end

  # Multiplayer Networking (@[RPC])
  @[RPC(mode: :any_peer, sync: :call_local, transfer_mode: :reliable, channel: 1)]
  def attack_peer(target_id : Int32)
    Godot.print("Attacking target: #{target_id}")
  end

  @[RPC]
  def sync_state
  end

  def _ready
  end
end

suite_entry = Godot::ClassRegistry.find("TestAnnotationsSuite")
abort "Failed: TestAnnotationsSuite not found in ClassRegistry" unless suite_entry

# Verify Class metadata
abort "Failed: icon_path not set" unless suite_entry.icon_path == "res://icons/player.svg"
abort "Failed: is_abstract not set" unless suite_entry.is_abstract == true

# Verify Category, Group, and Subgroup
cat_p = suite_entry.properties.find { |p| p.name == "Player Profile" }
abort "Failed: category property missing or wrong usage" unless cat_p && cat_p.usage == 128_u32

grp_p = suite_entry.properties.find { |p| p.name == "Movement" }
abort "Failed: group property missing or wrong usage" unless grp_p && grp_p.usage == 64_u32 && grp_p.hint_string == "move_"

sub_p = suite_entry.properties.find { |p| p.name == "Dashing" }
abort "Failed: subgroup property missing or wrong usage" unless sub_p && sub_p.usage == 256_u32 && sub_p.hint_string == "dash_"

# Helper lambda to check properties
check_prop = ->(name : String, expected_hint : UInt32, expected_hint_str : String, expected_usage : UInt32) {
  p = suite_entry.properties.find { |item| item.name == name }
  abort "Failed: property #{name} not found" unless p
  abort "Failed: #{name} hint expected #{expected_hint}, got #{p.hint}" unless p.hint == expected_hint
  abort "Failed: #{name} hint_string expected #{expected_hint_str}, got #{p.hint_string}" unless p.hint_string == expected_hint_str
  abort "Failed: #{name} usage expected #{expected_usage}, got #{p.usage}" unless p.usage == expected_usage
}

check_prop.call("move_speed", 1_u32, "0.0,500.0,5.0", 6_u32)
check_prop.call("move_accel", 1_u32, "10.0,100.0,1.0", 6_u32)
check_prop.call("dash_enabled", 0_u32, "", 6_u32)
check_prop.call("class_type", 2_u32, "Warrior,Mage,Rogue", 6_u32)
check_prop.call("element", 2_u32, "Fire,Water,Earth", 6_u32)
check_prop.call("avatar_file", 13_u32, "*.png,*.jpg", 6_u32)
check_prop.call("config_path", 44_u32, "*.json", 6_u32)
check_prop.call("save_folder", 14_u32, "", 6_u32)
check_prop.call("log_file", 15_u32, "*.txt", 6_u32)
check_prop.call("root_dir", 16_u32, "", 6_u32)
check_prop.call("biography", 18_u32, "", 6_u32)
check_prop.call("nickname", 20_u32, "Enter player nickname...", 6_u32)
check_prop.call("action_flags", 6_u32, "Attack,Defend,Cast,Flee", 6_u32)
check_prop.call("render_mask_2d", 7_u32, "", 6_u32)
check_prop.call("phys_layer_2d", 8_u32, "", 6_u32)
check_prop.call("nav_layer_2d", 9_u32, "", 6_u32)
check_prop.call("render_mask_3d", 10_u32, "", 6_u32)
check_prop.call("phys_layer_3d", 11_u32, "", 6_u32)
check_prop.call("nav_layer_3d", 12_u32, "", 6_u32)
check_prop.call("avoidance_layer", 37_u32, "", 6_u32)
check_prop.call("jump_curve", 4_u32, "", 6_u32)
check_prop.call("tint_color", 21_u32, "", 6_u32)
check_prop.call("camera_path", 26_u32, "Camera3D", 6_u32)
check_prop.call("internal_seed", 0_u32, "", 2_u32)
check_prop.call("btn_reset", 39_u32, "Reset Health", 4_u32)
check_prop.call("btn_method_ptr", 39_u32, "Method Pointer Button,Action", 4_u32)
check_prop.call("btn_lambda", 39_u32, "Lambda Button", 4_u32)
check_prop.call("btn_dynamic", 39_u32, "Dynamic Proc Button", 4_u32)
check_prop.call("regenerate_world", 39_u32, "Regenerate World,Play", 4_u32)
check_prop.call("custom_prop", 1_u32, "10,200,2", 6_u32)
check_prop.call("role", 2_u32, "Warrior:0,Mage:1,Rogue:5", 6_u32)
check_prop.call("role_id", 2_u32, "Warrior:0,Mage:1,Rogue:5", 6_u32)
check_prop.call("role_auto", 2_u32, "Warrior:0,Mage:1,Rogue:5", 6_u32)
check_prop.call("skills", 6_u32, "Slash,Shoot,Cast", 6_u32)

# Verify Proc-based Tool Button Dispatch & Dynamic Reassignment
tb_test_inst = TestAnnotationsSuite.new
abort "Failed: Initial action_counter must be 0" unless tb_test_inst.action_counter == 0

tb_test_inst._godot_call_tool_button("btn_method_ptr")
abort "Failed: btn_method_ptr did not execute" unless tb_test_inst.action_counter == 1

tb_test_inst._godot_call_tool_button("btn_lambda")
abort "Failed: btn_lambda did not execute" unless tb_test_inst.action_counter == 11

tb_test_inst._godot_call_tool_button("btn_dynamic") # nil proc initially
abort "Failed: nil btn_dynamic should be a no-op" unless tb_test_inst.action_counter == 11

tb_test_inst.btn_dynamic = -> { tb_test_inst.action_counter += 100; nil }
tb_test_inst._godot_call_tool_button("btn_dynamic")
abort "Failed: dynamic proc did not execute" unless tb_test_inst.action_counter == 111

tb_test_inst.btn_method_ptr = -> { tb_test_inst.action_counter += 500; nil }
tb_test_inst._godot_call_tool_button("btn_method_ptr")
abort "Failed: reassigned method proc did not execute" unless tb_test_inst.action_counter == 611

puts "✓ All Export Hints, Grouping annotations & Proc Tool Buttons verified!"

# Verify RPC Methods
abort "Failed: Expected 2 RPC methods" unless suite_entry.rpc_methods.size == 2
rpc_attack = suite_entry.rpc_methods.find { |m| m[:name] == "attack_peer" }
abort "Failed: attack_peer RPC method missing" unless rpc_attack
abort "Failed: attack_peer rpc_mode" unless rpc_attack[:rpc_mode] == 1 # AnyPeer
abort "Failed: attack_peer call_local" unless rpc_attack[:call_local] == true
abort "Failed: attack_peer transfer_mode" unless rpc_attack[:transfer_mode] == 2 # Reliable
abort "Failed: attack_peer channel" unless rpc_attack[:channel] == 1

rpc_sync = suite_entry.rpc_methods.find { |m| m[:name] == "sync_state" }
abort "Failed: sync_state RPC method missing" unless rpc_sync
abort "Failed: sync_state default authority mode" unless rpc_sync[:rpc_mode] == 2 # Authority
abort "Failed: sync_state default call_remote" unless rpc_sync[:call_local] == false
abort "Failed: sync_state default reliable mode" unless rpc_sync[:transfer_mode] == 2 # Reliable
abort "Failed: sync_state default channel 0" unless rpc_sync[:channel] == 0

puts "✓ Multiplayer @[RPC] configurations verified!"

# Instantiate and verify virtual callback dispatch
inst = suite_entry.create_proc.call(Pointer(Void).null).as(TestAnnotationsSuite)
abort "Failed: create_proc returned nil" unless inst
inst._godot_call_virtual("_ready", 0.0_f32)

puts "✓ @[OnReady] dispatch verified!"

# Verify enum getter / setter dispatch
val_to_set = 5_i64 # Rogue
inst._godot_set_property("role", pointerof(val_to_set).as(Void*))
abort "Failed: role not updated to Rogue" unless inst.role == CharacterRole::Rogue

val_read = 0_i64
inst._godot_get_property("role", pointerof(val_read).as(Void*))
abort "Failed: role getter mismatch, expected 5 got #{val_read}" unless val_read == 5_i64

skill_to_set = (CombatSkills::Slash | CombatSkills::Cast).value.to_i64
inst._godot_set_property("skills", pointerof(skill_to_set).as(Void*))
abort "Failed: skills not updated via flags" unless inst.skills == (CombatSkills::Slash | CombatSkills::Cast)

skill_read = 0_i64
inst._godot_get_property("skills", pointerof(skill_read).as(Void*))
abort "Failed: skills getter mismatch" unless skill_read == skill_to_set

puts "✓ Crystal Enum and Flag property dispatch verified!"

# Verify ClassDB constants harvested for enums
abort "Failed: expected constants in suite_entry" if suite_entry.constants.empty?
c_warrior = suite_entry.constants.find { |c| c.name == "Warrior" }
abort "Failed: Warrior constant missing" unless c_warrior && c_warrior.value == 0_i64
c_rogue = suite_entry.constants.find { |c| c.name == "Rogue" }
abort "Failed: Rogue constant missing" unless c_rogue && c_rogue.value == 5_i64
c_cast = suite_entry.constants.find { |c| c.name == "Cast" }
abort "Failed: Cast flag constant missing" unless c_cast && c_cast.value == 4_i64 && c_cast.is_bitfield?

puts "✓ Enum constants harvested for ClassDB registration verified!"

# Verify resource and gdclass macros
resource SpecWeaponResource < Resource do
  @[Export]
  property weapon_name : String = "Excalibur"

  @[Export]
  property damage : Int32 = 150
end

gdclass SpecStateMachine < RefCounted do
  @[Export]
  property state : String = "idle"
end

weapon_entry = Godot::ClassRegistry.find("SpecWeaponResource")
abort "Failed: SpecWeaponResource not found" unless weapon_entry
abort "Failed: SpecWeaponResource parent" unless weapon_entry.parent_name == "Resource"
abort "Failed: SpecWeaponResource properties" unless weapon_entry.properties.any? { |p| p.name == "weapon_name" }

state_entry = Godot::ClassRegistry.find("SpecStateMachine")
abort "Failed: SpecStateMachine not found" unless state_entry
abort "Failed: SpecStateMachine parent" unless state_entry.parent_name == "RefCounted"
abort "Failed: SpecStateMachine properties" unless state_entry.properties.any? { |p| p.name == "state" }

# Verify zero-block and default inheritance macros
resource ShortResource
gdclass ShortClass
node ShortNode

gdclass CustomCharacter < CharacterBody3D do
  @[Export]
  property speed : Float32 = 10.0_f32
end

sr_entry = Godot::ClassRegistry.find("ShortResource")
abort "Failed: ShortResource missing or wrong parent" unless sr_entry && sr_entry.parent_name == "Resource"

sc_entry = Godot::ClassRegistry.find("ShortClass")
abort "Failed: ShortClass missing or wrong parent" unless sc_entry && sc_entry.parent_name == "RefCounted"

sn_entry = Godot::ClassRegistry.find("ShortNode")
abort "Failed: ShortNode missing or wrong parent" unless sn_entry && sn_entry.parent_name == "Node"

cc_entry = Godot::ClassRegistry.find("CustomCharacter")
abort "Failed: CustomCharacter missing or wrong parent" unless cc_entry && cc_entry.parent_name == "CharacterBody3D"

puts "✓ resource, gdclass, and node zero-block and default inheritance verified!"

# Verify compile-time enforcement of no-args proc for ExportToolButton
root_dir = File.expand_path(".")
test_compile_error = ->(source : String, expected_err : String) {
  tmp_path = File.join(root_dir, "spec", "temp_tb_err.cr")
  begin
    File.write(tmp_path, %(require "../src/lapis"\n#{source}))
    output = IO::Memory.new
    status = Process.run("crystal", ["build", "--no-codegen", tmp_path], output: output, error: output)
    abort "Failed: expected compile error but compilation succeeded!" if status.success?
    err_text = output.to_s
    abort "Failed: expected error containing '#{expected_err}', got: #{err_text}" unless err_text.includes?(expected_err)
  ensure
    File.delete(tmp_path) if File.exists?(tmp_path)
  end
}

test_compile_error.call(%(
node FailNode1 < Node do
  @[ExportToolButton("Bad Button")]
  property btn : Proc(Int32, Void)
end
), "must take only a no-args proc: Proc(Void)")

test_compile_error.call(%(
node FailNode2 < Node do
  @[ExportToolButton("Bad Button 2")]
  property btn = ->(x : Int32) { x }
end
), "takes argument(s). Tool buttons must take only a no-args proc")

test_compile_error.call(%(
node FailNode3 < Node do
  @[ExportToolButton("Bad Button 3")]
  property btn = ->take_arg(Int32)

  def take_arg(x : Int32) : Void
  end
end
), "takes 1 argument(s). Tool buttons must take only a no-args proc")

test_compile_error.call(%(
node FailNodeCall < Node do
  @[ExportToolButton("Bad Call Button")]
  property btn = method_without_arrow

  def method_without_arrow : Void
  end
end
), "must be assigned a Proc (e.g. 'property btn = ->some_method' or 'property btn = ->{ ... }'), not a method call 'method_without_arrow'")

test_compile_error.call(%(
node FailNodeString < Node do
  @[ExportToolButton("Build Map", "CollisionShape3D")]
  property build_button : String = "build"
end
), "must be a no-args proc: Proc(Void)")

test_compile_error.call(%(
node FailNodeStringLiteral < Node do
  @[ExportToolButton("Build Map", "CollisionShape3D")]
  property build_button = "build"
end
), "must be a no-args proc: Proc(Void)")

test_compile_error.call(%(
node FailNodeBool < Node do
  @[ExportToolButton("Click Here")]
  property tool_btn_prop : Bool = false
end
), "must be a no-args proc: Proc(Void)")

# Verify valid Proc literal compiles cleanly without error
tmp_good = File.join(root_dir, "spec", "temp_good_tb.cr")
begin
  File.write(tmp_good, %(require "../src/lapis"
node GoodNodeProc < Node do
  @[ExportToolButton("Build Map", "CollisionShape3D")]
  property build_button = ->{ print "my proc" }

  @[ExportToolButton("Pointer Button")]
  property ptr_button = ->do_build

  def do_build : Void
  end
end
))
  good_out = IO::Memory.new
  good_status = Process.run("crystal", ["build", "--no-codegen", tmp_good], output: good_out, error: good_out)
  abort "Failed: valid proc tool button failed to compile: #{good_out}" unless good_status.success?
ensure
  File.delete(tmp_good) if File.exists?(tmp_good)
end

puts "✓ Compile-time rejection of argument-taking and non-proc tool buttons verified!"
puts "✓ Compile-time acceptance of no-arg proc literals and proc pointers verified!"
puts "All new features passed specifications cleanly!"
