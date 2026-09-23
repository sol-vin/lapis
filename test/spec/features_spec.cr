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

  @[RPC(mode: :any_peer, sync: :call_local, transfer_mode: :reliable, channel: 1)]
  def attack_target(target_id : Int32)
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

    it "omits undocumented engine lifecycle callbacks from generated XML methods" do
      docs = Godot::EditorDocRegistry.xml_documents
      lc_doc = docs.find { |d| d.includes?("SpecLifecycleDocNode") }
      lc_doc.should_not be_nil
      lc_doc.not_nil!.includes?("<method ").should be_false
    end
  end

  describe "Global Enums & Tool Script Annotations" do
    it "maps Godot global key enums" do
      Godot::Key::Space.value.should eq(32_i64)
      Godot::Key::Escape.value.should eq(4194305_i64)
      Godot::Key::Enter.value.should eq(4194309_i64)
    end

    it "registers tool scripts using @[Tool] prefix and inside node annotations" do
      prefix_entry = Godot::ClassRegistry.find("SpecToolPrefixNode")
      prefix_entry.should_not be_nil
      prefix_entry.not_nil!.is_tool.should be_true

      anno_entry = Godot::ClassRegistry.find("SpecToolAnnotationNode")
      anno_entry.should_not be_nil
      anno_entry.not_nil!.is_tool.should be_true
    end
  end

  describe "Annotation Suite Metadata & Inspector Grouping" do
    it "records class icon and abstract metadata" do
      entry = Godot::ClassRegistry.find("SpecAnnotationsSuite").not_nil!
      entry.icon_path.should eq("res://icons/player.svg")
      entry.is_abstract.should be_true
    end

    it "records categories, groups, and subgroups in properties" do
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
end
