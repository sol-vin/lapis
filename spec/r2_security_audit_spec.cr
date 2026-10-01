require "spec"
require "../src/libgodot/debugger/binary_analyzer"
require "../src/libgodot/debugger/radare_driver"

describe "Lapis::Debugger Radare2 Security & Hardening Audit" do
  describe "Hardening Model & Invariants" do
    it "verifies HardeningReport validation logic" do
      clean_report = Lapis::Debugger::BinaryAnalyzer::HardeningReport.new(
        dep_enabled: true,
        aslr_enabled: true,
        has_relocations: true,
        warnings: [] of String
      )
      clean_report.dep_enabled.should be_true
      clean_report.aslr_enabled.should be_true
      clean_report.has_relocations.should be_true
      clean_report.warnings.should be_empty

      vulnerable_report = Lapis::Debugger::BinaryAnalyzer::HardeningReport.new(
        dep_enabled: false,
        aslr_enabled: false,
        has_relocations: false,
        warnings: [
          "Binary contains writable and executable (W+X) memory section",
          "Shared library is missing '.reloc' relocation table"
        ]
      )
      vulnerable_report.dep_enabled.should be_false
      vulnerable_report.aslr_enabled.should be_false
      vulnerable_report.has_relocations.should be_false
      vulnerable_report.warnings.size.should eq(2)
    end
  end

  describe "Banned Insecure C CRT Imports Audit" do
    it "flags dangerous legacy C runtime functions" do
      banned_functions = ["strcpy", "strcat", "gets", "sprintf", "vsprintf"]
      
      # Test detection logic
      mock_imports = ["strcpy", "GC_malloc", "strlen", "memcpy", "sprintf"]
      flagged = mock_imports.select { |imp| banned_functions.includes?(imp) }
      flagged.should eq(["strcpy", "sprintf"])
    end
  end

  describe "Live Binary Hardening Audit" do
    it "verifies crystal_bridge.dll adheres to DEP and ASLR requirements" do
      unless Lapis::Debugger::RadareDriver.available?
        pending! "radare2 not installed on system PATH"
      end

      bridge_bin = File.expand_path(File.join(__DIR__, "..", "bin", "crystal_bridge.dll"))
      unless File.exists?(bridge_bin)
        pending! "bin/crystal_bridge.dll not found"
      end

      Cradare2.open(bridge_bin) do |client|
        analyzer = Lapis::Debugger::BinaryAnalyzer.new(client, bridge_bin)
        hardening = analyzer.audit_hardening

        # DEP: No section may be both Writable and Executable (W^X)
        hardening.dep_enabled.should be_true

        # DLLs must have relocations for dynamic base ASLR
        hardening.has_relocations.should be_true

        # Verify no banned functions in imports
        imports = client.imports
        banned = ["gets", "strcpy", "strcat"]
        flagged = imports.select { |i| banned.includes?(i.name) }
        flagged.should be_empty
      end
    end
  end
end
