require "./spec_helper"
require "../src/libgodot/debugger/binary_analyzer"
require "../src/libgodot/debugger/radare_driver"

describe "radare2 Security Hardening & Platform Hygiene Audit" do
  it "verifies Data Execution Prevention (DEP / W^X) in compiled DLL" do
    unless Lapis::Debugger::RadareDriver.available?
      pending! "radare2 not installed on system PATH"
    end

    game_dll = File.join(__DIR__, "..", "bin", "game.dll")
    unless File.exists?(game_dll)
      pending! "bin/game.dll not found for hardening audit"
    end

    Cradare2.open(game_dll) do |client|
      analyzer = Lapis::Debugger::BinaryAnalyzer.new(client, game_dll)
      report = analyzer.audit_hardening

      # DEP must be enabled (no writable and executable sections)
      report.dep_enabled.should be_true
    end
  end

  it "verifies relocation table (.reloc) is present for ASLR in shared libraries" do
    unless Lapis::Debugger::RadareDriver.available?
      pending! "radare2 not installed on system PATH"
    end

    bridge_dll = File.join(__DIR__, "..", "bin", "crystal_bridge.dll")
    unless File.exists?(bridge_dll)
      pending! "bin/crystal_bridge.dll not found for hardening audit"
    end

    Cradare2.open(bridge_dll) do |client|
      analyzer = Lapis::Debugger::BinaryAnalyzer.new(client, bridge_dll)
      report = analyzer.audit_hardening

      # Shared library on Windows must support dynamic rebasing via relocations
      report.has_relocations.should be_true
    end
  end
end
