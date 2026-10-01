# tools/lapis/spec/analyze_spec.cr
require "./spec_helper"
require "json"

describe "Lapis Analyze Command" do
  it "displays help banner with --help" do
    res = LapisSpecHelper.run_lapis(["analyze", "--help"])
    res.success?.should be_true
    res.output.should contain("Lapis: Binary Analysis & Hardening Auditor")
    res.output.should contain("Usage: lapis analyze <binary>")
    res.output.should contain("--json")
    res.output.should contain("--budget-check")
  end

  it "displays help banner with -h" do
    res = LapisSpecHelper.run_lapis(["analyze", "-h"])
    res.success?.should be_true
    res.output.should contain("Usage: lapis analyze <binary>")
  end

  it "returns error when target binary does not exist" do
    res = LapisSpecHelper.run_lapis(["analyze", "non_existent_binary_xyz.dll"])
    res.success?.should be_false
    res.all_output.should contain("Target binary does not exist")
  end

  r2_available = !Process.find_executable("radare2").nil? || !Process.find_executable("r2").nil?

  it "analyzes crystal_bridge.dll and prints formatted terminal report" do
    bridge_path = LapisSpecHelper.repo_root.join("bin", Lapis::Core::Env.bridge_file)
    if File.exists?(bridge_path) && r2_available
      res = LapisSpecHelper.run_lapis(["analyze", bridge_path.to_s, "--quick"])
      res.success?.should be_true
      res.output.should contain("LAPIS BINARY ANALYSIS REPORT")
      res.output.should contain("GDExtension & Symbol Health")
      res.output.should contain("Memory & GC Architecture")
      res.output.should contain("Space Efficiency & Section Budgets")
      res.output.should contain("Security & Platform Hardening")
    end
  end

  it "generates valid machine-readable JSON output with --json" do
    bridge_path = LapisSpecHelper.repo_root.join("bin", Lapis::Core::Env.bridge_file)
    if File.exists?(bridge_path) && r2_available
      res = LapisSpecHelper.run_lapis(["analyze", bridge_path.to_s, "--json", "--quick"])
      res.success?.should be_true
      # Validate JSON parsing
      json_data = JSON.parse(res.output)
      json_data["target_path"].should_not be_nil
      json_data["arch"].should_not be_nil
      json_data["gc"].should_not be_nil
      json_data["symbols"].should_not be_nil
      json_data["efficiency"].should_not be_nil
      json_data["hardening"].should_not be_nil
    end
  end
end
