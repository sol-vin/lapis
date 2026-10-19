require "./spec_helper"

# Node exercising doc comments and XML generation
node SpecDocPlayer < CharacterBody3D do
  @[Doc("Represents a test player entity in spec")]

  # Movement speed in units per second
  @[Export(range: 10.0_f32..500.0_f32)]
  property speed : Float32 = 250.0_f32

  # Emitted when player dies
  signal player_died

  # Inflicts damage to the entity
  def take_damage(dmg : Int32) : Void
  end
end

node SpecLifecycleDocNode < Godot::Node do
  def _ready : Void
  end

  def _enter_tree : Void
  end

  def _exit_tree : Void
  end
end

enum SpecCharacterRole
  Warrior = 0
  Mage    = 1
  Rogue   = 5
end

@[Flags]
enum SpecCombatSkills
  Slash
  Shoot
  Cast
end

@[Icon("res://icons/player.svg")]
@[Abstract]
node SpecAnnotationsSuite < CharacterBody3D do
  @[ExportEnum(SpecCharacterRole)]
  property role : SpecCharacterRole = SpecCharacterRole::Warrior

  @[ExportFlags(SpecCombatSkills)]
  property skills : SpecCombatSkills = SpecCombatSkills::Slash

  export_category "Profile"
  export_group "Movement", prefix: "move_"
  @[ExportRange(0.0_f32, 500.0_f32, 5.0_f32)]
  property move_speed : Float32 = 250.0_f32

  export_subgroup "Dash", prefix: "dash_"
  @[Export]
  property dash_enabled : Bool = true

  @[ExportFile("*.png")]
  property avatar : String = "avatar.png"

  @[ExportDir]
  property save_folder : String = "saves/"

  @[ExportToolButton("Reset")]
  property btn_reset = -> { }

  @[Export]
  property custom_badge : SpecCustomBadgeResource? = nil

  @[RPC(mode: :any_peer, sync: :call_local, transfer_mode: :reliable, channel: 1)]
  def attack_target(target_id : Int32)
  end
end

node SpecCustomBadgeResource < Resource do
  property badge_id : Int32 = 1
end

node SpecCustomLoaderNode < ResourceFormatLoader do
  def _get_recognized_extensions : PackedStringArray
    PackedStringArray.new
  end
end

@[Tool]
node SpecToolPrefixNode do
  def _ready; end
end

node SpecToolAnnotationNode do
  @[Tool]
  def _ready; end
end

describe "LibGodot Features & Reflection" do
  describe "Compile-time Doc Harvesting & XML Generation" do
    it "extracts doc comments for classes, members, signals, and methods" do
      docs = Godot::EditorDocRegistry.xml_documents
      docs.should_not be_empty

      player_doc = docs.find { |d| d.includes?("SpecDocPlayer") }
      player_doc.should_not be_nil
      doc_text = player_doc.not_nil!

      doc_text.should contain("Represents a test player entity in spec")
      doc_text.should contain("<member name=\"speed\"")
      doc_text.should contain("Movement speed in units per second")
      doc_text.should contain("<signal name=\"player_died\"")
      doc_text.should contain("<method name=\"take_damage\"")
      doc_text.should contain("<return type=\"void\" />")
      doc_text.should contain("<param index=\"0\" name=\"dmg\" type=\"int\" />")
      doc_text.should contain("Inflicts damage to the entity")
    end

    it "omits undocumented lifecycle callbacks from xml methods" do
      docs = Godot::EditorDocRegistry.xml_documents
      lc_doc = docs.find { |d| d.includes?("SpecLifecycleDocNode") }
      lc_doc.should_not be_nil
      lc_doc.not_nil!.should_not contain("<method ")
    end
  end

  describe "Enums and Singletons" do
    it "binds global enums correctly" do
      Godot::Key::Space.value.should eq(32_i64)
      Godot::Key::Escape.value.should eq(4194305_i64)
      Godot::Key::Enter.value.should eq(4194309_i64)
    end

    it "exposes core singletons" do
      Godot::Input.should_not be_nil
      Godot::Engine.should_not be_nil
    end
  end

  describe "Annotations and Grouping" do
    it "registers @[Tool] classes in ClassRegistry" do
      prefix_entry = Godot::ClassRegistry.find("SpecToolPrefixNode")
      prefix_entry.should_not be_nil
      prefix_entry.not_nil!.is_tool.should be_true

      annot_entry = Godot::ClassRegistry.find("SpecToolAnnotationNode")
      annot_entry.should_not be_nil
      annot_entry.not_nil!.is_tool.should be_true
    end

    it "registers class attributes like icon and abstract" do
      entry = Godot::ClassRegistry.find("SpecAnnotationsSuite")
      entry.should_not be_nil
      suite = entry.not_nil!

      suite.icon_path.should eq("res://icons/player.svg")
      suite.is_abstract.should be_true
    end

    it "registers export group and category usage flags" do
      entry = Godot::ClassRegistry.find("SpecAnnotationsSuite").not_nil!

      cat = entry.properties.find { |p| p.name == "Profile" }
      cat.should_not be_nil
      cat.not_nil!.usage.should eq(128_u32)

      grp = entry.properties.find { |p| p.name == "Movement" }
      grp.should_not be_nil
      grp.not_nil!.usage.should eq(64_u32)
      grp.not_nil!.hint_string.should eq("move_")

      sub = entry.properties.find { |p| p.name == "Dash" }
      sub.should_not be_nil
      sub.not_nil!.usage.should eq(256_u32)
      sub.not_nil!.hint_string.should eq("dash_")
    end

    it "registers export types with proper hints" do
      entry = Godot::ClassRegistry.find("SpecAnnotationsSuite").not_nil!

      role_p = entry.properties.find { |p| p.name == "role" }.not_nil!
      role_p.hint_string.should contain("Warrior:0,Mage:1,Rogue:5")

      avatar_p = entry.properties.find { |p| p.name == "avatar" }.not_nil!
      avatar_p.hint_string.should eq("*.png")

      dash_p = entry.properties.find { |p| p.name == "dash_enabled" }.not_nil!
      dash_p.type_name.should eq("Bool")

      badge_p = entry.properties.find { |p| p.name == "custom_badge" }.not_nil!
      badge_p.hint.should eq(17_u32)
      badge_p.hint_string.should eq("SpecCustomBadgeResource")
    end

    it "attaches auto-initialization proc to ResourceFormatLoader subclasses" do
      loader_entry = Godot::ClassRegistry.find("SpecCustomLoaderNode").not_nil!
      loader_entry.init_proc.should_not be_nil
    end

    it "registers RPC multiplayer network annotations" do
      entry = Godot::ClassRegistry.find("SpecAnnotationsSuite").not_nil!
      rpc_method = entry.rpc_methods.find { |m| m[:name] == "attack_target" }.not_nil!
      rpc_method[:rpc_mode].should eq(1) # any_peer
      rpc_method[:channel].should eq(1)
      rpc_method[:call_local].should be_true
    end

    it "extracts file, line, and error summary from compiler output" do
      sample_error = <<-ERR
      Showing last frame. Use --error-trace for full trace.

      In src\\main.cr:16:5

       16 | butt_soup
             ^--------
      Error: undefined local variable or method 'butt_soup' for MainNode
      ERR

      file_path = ""
      line_num = -1
      error_summary = ""

      sample_error.each_line do |line|
        line_strip = line.strip
        if m = line_strip.match(/(?:In|Syntax error in)\s+([^:\r\n]+):(\d+)(?::(\d+))?/)
          file_path = m[1]
          line_num = m[2].to_i? || -1
        elsif line_strip.starts_with?("Error:")
          error_summary = line_strip.sub("Error:", "").strip
        end
      end

      file_path.should eq("src\\main.cr")
      line_num.should eq(16)
      error_summary.should eq("undefined local variable or method 'butt_soup' for MainNode")
    end
  end

  describe "Class-Level Scene Instantiation & Hierarchy Ergonomics" do
    it "responds to self.instantiate on Godot::Node and subclasses" do
      Godot::Node.responds_to?(:instantiate).should be_true
      Godot::Marker2D.responds_to?(:instantiate).should be_true
      Godot::Node2D.responds_to?(:instantiate).should be_true
      Godot::CharacterBody3D.responds_to?(:instantiate).should be_true
      SpecDocPlayer.responds_to?(:instantiate).should be_true
    end

    it "responds to self.instantiate? on Godot::Node and subclasses" do
      Godot::Node.responds_to?(:instantiate?).should be_true
      Godot::Marker2D.responds_to?(:instantiate?).should be_true
      Godot::Node2D.responds_to?(:instantiate?).should be_true
      SpecDocPlayer.responds_to?(:instantiate?).should be_true
    end

    it "returns nil safely with instantiate? on non-existent scene paths" do
      res = Godot::Marker2D.instantiate?("res://non_existent_marker_123.tscn")
      res.should be_nil
    end

    it "supports add_child and add_sibling with positional (path, Type) arguments on Node" do
      parent = Godot::Node.new
      parent.responds_to?(:add_child).should be_true
      parent.responds_to?(:add_sibling).should be_true
    end
  end

  describe "ResourceFormatLoaderCrystal & ExportToolButton Hot-Reload Invariants" do
    it "returns ResourceUID::INVALID_ID (-1) for _get_resource_uid to prevent uid://a collisions" do
      Lapis::ResourceFormatLoaderCrystal._godot_has_virtual_method("_get_resource_uid").should be_true
      Lapis::ResourceFormatLoaderCrystal._godot_has_virtual_method("get_resource_uid").should be_true

      loader = Lapis::ResourceFormatLoaderCrystal.new
      loader._get_resource_uid("res://src/main.cr").should eq(-1_i64)

      ret_val = 0_i64
      loader._godot_call_virtual_with_data("_get_resource_uid", Pointer(Void*).null, pointerof(ret_val).as(Void*))
      ret_val.should eq(-1_i64)
    end

    it "marks @[ExportToolButton] properties with PROPERTY_HINT_TOOL_BUTTON (39) and Callable variant type (25)" do
      entry = Godot::ClassRegistry.find("SpecAnnotationsSuite").not_nil!
      btn_prop = entry.properties.find { |p| p.name == "btn_reset" }
      btn_prop.should_not be_nil
      btn_prop.not_nil!.hint.should eq(39_u32)
      btn_prop.not_nil!.variant_type.should eq(25)
      btn_prop.not_nil!.hint_string.should eq("Reset")
    end
  end

  describe "Object/Resource/Node Export Marshalling, Enum Signals, and Export Suffixes" do
    it "marshals nilable and non-nilable Object, Resource, and Node properties in _godot_set_property and _godot_get_property" do
      holder = SpecSuccExportAndSignalNode.new
      holder.config.should be_nil
      holder.yaw_target.should be_nil

      # Verify _godot_get_property returns null pointer when nil
      out_ptr = Pointer(Void).new(0xDEADBEEF_u64)
      holder._godot_get_property("config", pointerof(out_ptr).as(Void*))
      out_ptr.null?.should be_true

      # Create a live badge resource and register it in Bridge's instance map
      fake_badge_ptr = Pointer(Void).new(0x12345678_u64)
      badge = SpecCustomBadgeResource.new(fake_badge_ptr)
      badge.badge_id = 42
      Godot::Bridge.register_alive_instance(fake_badge_ptr, badge)

      begin
        # Set property via _godot_set_property (simulating Godot Inspector / scene loader)
        in_ptr = fake_badge_ptr
        holder._godot_set_property("config", pointerof(in_ptr).as(Void*))
        holder.config.should be(badge)
        holder.config.not_nil!.badge_id.should eq(42)

        # Get property via _godot_get_property
        got_ptr = Pointer(Void).null
        holder._godot_get_property("config", pointerof(got_ptr).as(Void*))
        got_ptr.should eq(fake_badge_ptr)

        # Set unmapped Node3D pointer and verify wrapper instantiation
        raw_node3d_ptr = Pointer(Void).new(0x87654321_u64)
        holder._godot_set_property("yaw_target", pointerof(raw_node3d_ptr).as(Void*))
        holder.yaw_target.should_not be_nil
        holder.yaw_target.not_nil!.pointer.should eq(raw_node3d_ptr)

        # Clear nilable property with null pointer
        null_ptr = Pointer(Void).null
        holder._godot_set_property("config", pointerof(null_ptr).as(Void*))
        holder.config.should be_nil
        holder._godot_set_property("yaw_target", pointerof(null_ptr).as(Void*))
        holder.yaw_target.should be_nil

        # Also test gmodule property marshalling via included mixin
        holder._godot_set_property("mixin_badge", pointerof(in_ptr).as(Void*))
        holder.mixin_badge.should be(badge)
        holder._godot_set_property("mixin_badge", pointerof(null_ptr).as(Void*))
        holder.mixin_badge.should be_nil
      ensure
        Godot::Bridge.unregister_alive_instance(fake_badge_ptr)
      end
    end

    it "registers Enum, Vector2, Vector3, Color, and Object signal argument types in SignalArgInfo" do
      entry = Godot::ClassRegistry.find("SpecSuccExportAndSignalNode").not_nil!

      sig_state = entry.signals.find { |s| s.name == "movement_state_changed" }.not_nil!
      sig_state.args.size.should eq(2)
      sig_state.args[0].name.should eq("old_state")
      sig_state.args[0].variant_type.should eq(2) # INT (Enum)
      sig_state.args[1].name.should eq("new_state")
      sig_state.args[1].variant_type.should eq(2) # INT (Inner Enum)

      sig_rich = entry.signals.find { |s| s.name == "telemetry_recorded" }.not_nil!
      sig_rich.args.size.should eq(4)
      sig_rich.args[0].variant_type.should eq(5)  # Vector2
      sig_rich.args[1].variant_type.should eq(9)  # Vector3
      sig_rich.args[2].variant_type.should eq(20) # Color
      sig_rich.args[3].variant_type.should eq(24) # Object (Node3D)

      mod_sigs = SpecSuccMixinModule._godot_module_signals
      mod_sig = mod_sigs.find { |s| s.name == "mixin_role_changed" }.not_nil!
      mod_sig.args[0].variant_type.should eq(2)
      mod_sig.args[1].variant_type.should eq(24)
    end

    it "boxes and unboxes Enum values in Variant and TypedSignal" do
      v = Godot::Variant.new(SpecCharacterRole::Rogue)
      v.int?.should be_true
      v.as_i64.should eq(5_i64)
      v.as_t(SpecCharacterRole).should eq(SpecCharacterRole::Rogue)

      Godot::Variant.default_for(SpecCharacterRole).should eq(SpecCharacterRole::Warrior)

      holder = SpecSuccExportAndSignalNode.new
      received = nil
      holder.movement_state_changed.connect do |old_role, new_state|
        received = {old_role, new_state}
      end
      holder.movement_state_changed.emit(SpecCharacterRole::Mage, SpecSuccExportAndSignalNode::InnerMoveState::Sprinting)
      received.should eq({SpecCharacterRole::Mage, SpecSuccExportAndSignalNode::InnerMoveState::Sprinting})
    end

    it "supports suffix: on @[Export] and @[ExportRange] in node and gmodule" do
      entry = Godot::ClassRegistry.find("SpecSuccExportAndSignalNode").not_nil!

      vel_prop = entry.properties.find { |p| p.name == "walk_speed" }.not_nil!
      vel_prop.hint.should eq(0_u32)
      vel_prop.hint_string.should eq("suffix:m/s")

      accel_prop = entry.properties.find { |p| p.name == "acceleration" }.not_nil!
      accel_prop.hint.should eq(1_u32)
      accel_prop.hint_string.should eq("0.0,100.0,0.5,suffix:m/s²")

      mult_prop = entry.properties.find { |p| p.name == "sprint_multiplier" }.not_nil!
      mult_prop.hint.should eq(1_u32)
      mult_prop.hint_string.should eq("1.0,3.0,0.05,suffix:×")

      mod_props = SpecSuccMixinModule._godot_module_properties
      mod_fov = mod_props.find { |p| p.name == "mixin_fov" }.not_nil!
      mod_fov.hint.should eq(1_u32)
      mod_fov.hint_string.should eq("40.0,120.0,1.0,suffix:°")
    end
  end
end

gmodule SpecSuccMixinModule do
  @[Export]
  property mixin_badge : SpecCustomBadgeResource? = nil

  @[ExportRange(40.0_f32, 120.0_f32, 1.0_f32, suffix: "°")]
  property mixin_fov : Float32 = 75.0_f32

  signal mixin_role_changed(role : SpecCharacterRole, badge : SpecCustomBadgeResource)
end

node SpecSuccExportAndSignalNode < Node3D do
  include SpecSuccMixinModule

  enum InnerMoveState
    Idle      = 0
    Walking   = 1
    Sprinting = 2
  end

  @[Export]
  property config : SpecCustomBadgeResource? = nil

  @[Export]
  property yaw_target : Godot::Node3D? = nil

  @[Export(suffix: "m/s")]
  property walk_speed : Float32 = 5.0_f32

  @[Export(range: 0.0_f32..100.0_f32, step: 0.5_f32, suffix: "m/s²")]
  property acceleration : Float32 = 12.0_f32

  @[ExportRange(1.0_f32, 3.0_f32, 0.05_f32, suffix: "×")]
  property sprint_multiplier : Float32 = 1.5_f32

  signal movement_state_changed(old_state : SpecCharacterRole, new_state : InnerMoveState)
  signal telemetry_recorded(uv : Vector2, pos : Vector3, tint : Color, target : Godot::Node3D)
end


