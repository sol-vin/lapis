require "spec"
require "cradare2"
require "../src/libgodot/debugger/r2_godot_plugin"

describe Lapis::Debugger::R2GodotPlugin do
  it "initializes dual dispatchers for godot and lapis prefixes" do
    # Create in-session or offline client using cradare2 Mock / memory
    opts = Cradare2::Options.build do |o|
      o.target = "bin/game.dll"
    end
    client = Cradare2.open(opts)

    plugin = Lapis::Debugger::R2GodotPlugin.new(client)
    plugin.godot_dispatcher.prefix.should eq("godot")
    plugin.lapis_dispatcher.prefix.should eq("lapis")

    # Verify registered godot commands
    plugin.godot_dispatcher.commands.has_key?("detect").should be_true
    plugin.godot_dispatcher.commands.has_key?("object").should be_true
    plugin.godot_dispatcher.commands.has_key?("variant").should be_true
    plugin.godot_dispatcher.commands.has_key?("classdb").should be_true
    plugin.godot_dispatcher.commands.has_key?("types").should be_true

    # Verify registered lapis commands
    plugin.lapis_dispatcher.commands.has_key?("info").should be_true
    plugin.lapis_dispatcher.commands.has_key?("supervisor").should be_true
    plugin.lapis_dispatcher.commands.has_key?("stale-vtables").should be_true
    plugin.lapis_dispatcher.commands.has_key?("dead-pointers").should be_true
    plugin.lapis_dispatcher.commands.has_key?("map").should be_true
  end

  it "dispatches commands via unified dispatch method" do
    opts = Cradare2::Options.build { |o| o.target = "bin/game.dll" }
    client = Cradare2.open(opts)
    plugin = Lapis::Debugger::R2GodotPlugin.new(client)

    # Dispatch "godot detect"
    out_detect = plugin.dispatch("godot detect")
    out_detect.should contain("Godot Engine Integration Status")

    # Dispatch "godot detect -j"
    out_detect_json = plugin.dispatch("godot detect -j")
    out_detect_json.should contain("precision")

    # Dispatch "lapis info"
    out_info = plugin.dispatch("lapis info")
    out_info.should contain("Lapis Engine & Toolchain Telemetry")

    # Dispatch "lapis supervisor status"
    out_sup = plugin.dispatch("lapis supervisor status")
    out_sup.should contain("Editor Supervisor Active")
  end

  describe Lapis::Debugger::SourceIndexer do
    it "statically indexes nodes, exported properties, and signals from source code" do
      sample_code = <<-CRYSTAL
      # Player character entity handling movement and health
      node Player < CharacterBody3D do
        @[Export]
        property speed : Float32 = 5.0_f32

        property max_health : Int32 = 100

        signal health_changed(current : Int32, max : Int32)
        signal died

        def _ready : Void
          Godot.print("Ready")
        end
      end
      CRYSTAL

      indexer = Lapis::Debugger::SourceIndexer.new
      indexer.index_content(sample_code, "src/player.cr")

      indexer.nodes.size.should eq(1)
      indexer.nodes.first.name.should eq("Player")
      indexer.nodes.first.parent_name.should eq("CharacterBody3D")
      indexer.nodes.first.file.should eq("src/player.cr")
      indexer.nodes.first.doc_comment.not_nil!.should contain("Player character entity")

      indexer.properties.size.should eq(2)
      indexer.properties.map(&.name).should eq(["speed", "max_health"])

      indexer.signals.size.should eq(2)
      indexer.signals.map(&.name).should eq(["health_changed", "died"])
    end
  end
end
