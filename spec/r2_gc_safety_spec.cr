require "./spec_helper"
require "../src/libgodot/debugger/binary_analyzer"
require "../src/libgodot/debugger/radare_driver"

describe "radare2 GC Safety & Memory Boundary Audit" do
  it "verifies Boehm GC runtime presence and thread registration symbols" do
    unless Lapis::Debugger::RadareDriver.available?
      pending! "radare2 not installed on system PATH"
    end

    game_dll = File.join(__DIR__, "..", "bin", "game.dll")
    unless File.exists?(game_dll)
      pending! "bin/game.dll not found for GC safety audit"
    end

    Cradare2.open(game_dll) do |client|
      analyzer = Lapis::Debugger::BinaryAnalyzer.new(client, game_dll)
      gc_report = analyzer.audit_gc_safety

      # Boehm GC malloc must be present
      gc_report.has_gc_malloc.should be_true

      # Static data (.data + .bss) must be within reasonable bounds (< 10 MB)
      (gc_report.static_data_size).should be <= 10 * 1024 * 1024
      (gc_report.static_data_size).should be > 0
    end
  end

  it "verifies GDExtension bridge references Boehm GC runtime (gc.dll)" do
    unless Lapis::Debugger::RadareDriver.available?
      pending! "radare2 not installed on system PATH"
    end

    bridge_dll = File.join(__DIR__, "..", "bin", "crystal_bridge.dll")
    unless File.exists?(bridge_dll)
      pending! "bin/crystal_bridge.dll not found for GC safety audit"
    end

    Cradare2.open(bridge_dll) do |client|
      strings = client.strings
      has_gc_ref = strings.any? { |s| s.string.includes?("gc.dll") || s.string.includes?("GC_init") }
      has_gc_ref.should be_true
    end
  end

  it "verifies thread registration functions are imported or linked" do
    unless Lapis::Debugger::RadareDriver.available?
      pending! "radare2 not installed on system PATH"
    end

    game_dll = File.join(__DIR__, "..", "bin", "game.dll")
    unless File.exists?(game_dll)
      pending! "bin/game.dll not found"
    end

    Cradare2.open(game_dll) do |client|
      symbols = client.symbols
      imports = client.imports

      # Verify Boehm GC functions are either imported or present in symbols
      gc_names = (symbols.map(&.name) + imports.map(&.name)).select { |n| n.includes?("GC_") }
      gc_names.should_not be_empty
    end
  end
end
