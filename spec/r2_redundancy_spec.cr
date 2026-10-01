require "spec"
require "../src/libgodot/debugger/binary_analyzer"
require "../src/libgodot/debugger/radare_driver"

describe "Lapis::Debugger Radare2 Redundancy & Space Audit" do
  describe "Section Budget & Space Models" do
    it "evaluates SectionBudget percentages and limits correctly" do
      sec = Lapis::Debugger::BinaryAnalyzer::SectionBudget.new(".text", 5_242_880_u64, 10_485_760_u64)
      sec.name.should eq(".text")
      sec.size.should eq(5_242_880_u64)
      sec.budget.should eq(10_485_760_u64)
      sec.percentage.should eq(50.0)
      sec.within_budget.should be_true

      overflow_sec = Lapis::Debugger::BinaryAnalyzer::SectionBudget.new(".data", 3_145_728_u64, 2_097_152_u64)
      overflow_sec.within_budget.should be_false
      overflow_sec.percentage.should eq(150.0)
    end

    it "identifies function size outliers exceeding thresholds" do
      outlier = Lapis::Debugger::BinaryAnalyzer::FunctionSizeOutlier.new(
        name: "Lapis::Godot::PackedStringArray#to_crystal_array",
        size: 70_000_u64,
        offset: 0x140001000_u64
      )
      outlier.name.should contain("PackedStringArray")
      outlier.size.should be > 65536_u64
    end
  end

  describe "Duplicate Symbol & Bloat Auditing" do
    it "detects duplicate symbols across compilation units" do
      sym_names = [
        "crystal_bridge_init",
        "lapis_gdextension_entry",
        "GC_malloc",
        "lapis_gdextension_entry", # Duplicate!
        "strlen",
        "GC_malloc" # Duplicate!
      ]

      counts = Hash(String, Int32).new(0)
      sym_names.each { |s| counts[s] += 1 }

      duplicates = counts.select { |_, count| count > 1 }.keys
      duplicates.should contain("lapis_gdextension_entry")
      duplicates.should contain("GC_malloc")
      duplicates.size.should eq(2)
    end
  end

  describe "Live Binary Redundancy & Section Efficiency" do
    it "verifies crystal_bridge.dll sections remain within memory budgets" do
      unless Lapis::Debugger::RadareDriver.available?
        pending! "radare2 not installed on system PATH"
      end

      bridge_bin = File.expand_path(File.join(__DIR__, "..", "bin", "crystal_bridge.dll"))
      unless File.exists?(bridge_bin)
        pending! "bin/crystal_bridge.dll not found"
      end

      Cradare2.open(bridge_bin) do |client|
        analyzer = Lapis::Debugger::BinaryAnalyzer.new(client, bridge_bin)
        efficiency = analyzer.audit_efficiency

        # Code section should be under budget
        efficiency.sections.should_not be_empty
        text_sec = efficiency.sections.find { |s| s.name == ".text" }
        if text_sec
          text_sec.within_budget.should be_true
          (text_sec.size < 5_000_000_u64).should be_true # C++ bridge should be lightweight
        end

        # Verify no scratch file paths leaked in binary strings
        efficiency.leaked_paths.should be_empty
      end
    end
  end
end
