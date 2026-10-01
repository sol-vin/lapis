require "spec"
require "../src/libgodot/debugger/gdextension_inspector"
require "../src/libgodot/debugger/radare_driver"

describe Lapis::Debugger::GDExtensionInspector do
  it "inspects binary exports and architecture via cradare2" do
    unless Lapis::Debugger::RadareDriver.available?
      pending! "radare2 not installed on system PATH"
    end

    bridge_bin = File.join(__DIR__, "..", "bin", "crystal_bridge.dll")
    unless File.exists?(bridge_bin)
      pending! "bin/crystal_bridge.dll not found for inspector test"
    end

    check = Lapis::Debugger::GDExtensionInspector.inspect_file(bridge_bin)
    check.exports_count.should be > 0
    check.bits.should eq(64)
    check.arch.should_not be_empty
  end

  it "verifies GDExtensionCheck struct fields accurately" do
    check = Lapis::Debugger::GDExtensionCheck.new(
      valid: true,
      entrypoint_found: true,
      entrypoint_name: "lapis_gdextension_entry",
      exports_count: 42,
      arch: "x86",
      bits: 64,
      warnings: [] of String
    )

    check.valid.should be_true
    check.entrypoint_found.should be_true
    check.entrypoint_name.should eq("lapis_gdextension_entry")
    check.exports_count.should eq(42)
    check.arch.should eq("x86")
    check.bits.should eq(64)
    check.warnings.should be_empty
  end
end
