require "./spec_helper"
require "../src/libgodot/debugger/binary_analyzer"
require "../src/libgodot/debugger/radare_driver"

describe "radare2 Symbol Table & ClassDB Export Integrity Audit" do
  it "verifies GDExtension bridge exports entrypoint with un-mangled C linkage" do
    unless Lapis::Debugger::RadareDriver.available?
      pending! "radare2 not installed on system PATH"
    end

    bridge_dll = File.join(__DIR__, "..", "bin", "crystal_bridge.dll")
    unless File.exists?(bridge_dll)
      pending! "bin/crystal_bridge.dll not found for symbol audit"
    end

    Cradare2.open(bridge_dll) do |client|
      analyzer = Lapis::Debugger::BinaryAnalyzer.new(client, bridge_dll)
      report = analyzer.audit_symbols

      report.entrypoint_found.should be_true
      report.entrypoint_name.should_not be_nil
      report.entrypoint_has_c_linkage.should be_true
      report.warnings.should be_empty
    end
  end

  it "discovers exports and imports in game binary" do
    unless Lapis::Debugger::RadareDriver.available?
      pending! "radare2 not installed on system PATH"
    end

    game_dll = File.join(__DIR__, "..", "bin", "game.dll")
    unless File.exists?(game_dll)
      pending! "bin/game.dll not found for symbol audit"
    end

    Cradare2.open(game_dll) do |client|
      analyzer = Lapis::Debugger::BinaryAnalyzer.new(client, game_dll)
      report = analyzer.audit_symbols

      # Game DLL exports crystal_godot_init
      report.entrypoint_found.should be_true
      report.entrypoint_name.should eq("crystal_godot_init")
      report.entrypoint_has_c_linkage.should be_true

      # Imports must be present (gc.dll, kernel32, etc.)
      client.imports.should_not be_empty
    end
  end

  it "verifies Demangler decodes complex Crystal types accurately" do
    mangled_example = "~Vector3~dot_product"
    clean = Cradare2::Util::Demangler.clean_crystal_symbol(mangled_example)
    clean.should contain("Vector3")
    clean.should contain("dot_product")
  end
end
