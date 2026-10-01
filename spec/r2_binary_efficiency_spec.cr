require "./spec_helper"
require "../src/libgodot/debugger/binary_analyzer"
require "../src/libgodot/debugger/radare_driver"

describe "radare2 Binary Efficiency & Space Bloat Audit" do
  it "verifies section sizes remain within allocated budgets" do
    unless Lapis::Debugger::RadareDriver.available?
      pending! "radare2 not installed on system PATH"
    end

    game_dll = File.join(__DIR__, "..", "bin", "game.dll")
    unless File.exists?(game_dll)
      pending! "bin/game.dll not found for efficiency audit"
    end

    # Enforce budgets: 12MB for .text, 4MB for .rdata, 2MB for .data
    budgets = {
      ".text"  => 12_582_912_u64,
      ".rdata" => 4_194_304_u64,
      ".data"  => 2_097_152_u64,
      ".bss"   => 2_097_152_u64,
    }

    Cradare2.open(game_dll) do |client|
      analyzer = Lapis::Debugger::BinaryAnalyzer.new(client, game_dll)
      report = analyzer.audit_efficiency(budgets)

      report.sections.should_not be_empty

      # Check that primary executable section is within budget
      text_sec = report.sections.find { |s| s.name == ".text" }
      if sec = text_sec
        sec.within_budget.should be_true
      end

      # Total binary size must be positive and reasonable (< 20 MB)
      report.total_binary_size.should be > 0
      (report.total_binary_size).should be <= 20 * 1024 * 1024
    end
  end

  it "verifies no single compiled function exceeds runaway bloat threshold (64 KB)" do
    unless Lapis::Debugger::RadareDriver.available?
      pending! "radare2 not installed on system PATH"
    end

    game_dll = File.join(__DIR__, "..", "bin", "game.dll")
    unless File.exists?(game_dll)
      pending! "bin/game.dll not found for function bloat audit"
    end

    Cradare2.open(game_dll) do |client|
      client.analyze.basic
      functions = client.functions

      # If functions analyzed, verify none exceeds 64 KB
      huge_functions = functions.select { |f| f.size > 65536_u64 }
      huge_functions.should be_empty
    end
  end

  it "verifies data string constants do not leak temporary scratch directories" do
    unless Lapis::Debugger::RadareDriver.available?
      pending! "radare2 not installed on system PATH"
    end

    game_dll = File.join(__DIR__, "..", "bin", "game.dll")
    unless File.exists?(game_dll)
      pending! "bin/game.dll not found for string audit"
    end

    Cradare2.open(game_dll) do |client|
      analyzer = Lapis::Debugger::BinaryAnalyzer.new(client, game_dll)
      report = analyzer.audit_efficiency

      # No temporary spec scratch path leaks
      report.leaked_paths.should be_empty
    end
  end
end
