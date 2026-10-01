# tools/lapis/spec/tui_tools_spec.cr
require "./spec_helper"

describe "Lapis CLI TUI Tools & Command Suite" do
  describe "cli / hub command" do
    it "displays hub command overview with --help" do
      res = LapisSpecHelper.run_lapis(["cli", "--help"])
      res.success?.should be_true
      res.output.should contain("=== Lapis: Interactive TUI Terminal Command Center ===")
      res.output.should contain("--new")
      res.output.should contain("--editor")
      res.output.should contain("--package")
    end
  end

  describe "editor command" do
    it "displays editor launcher help with flags for --debug, --log, --quit, --path" do
      res = LapisSpecHelper.run_lapis(["editor", "--help"])
      res.success?.should be_true
      res.output.should contain("=== Lapis: Godot Editor & Runtime Launcher ===")
      res.output.should contain("--path")
      res.output.should contain("--debug")
      res.output.should contain("--log-file")
      res.output.should contain("--quit-after")
    end
  end

  describe "package command" do
    it "displays package help with all export targets and platform options" do
      res = LapisSpecHelper.run_lapis(["package", "--help"])
      res.success?.should be_true
      res.output.should contain("=== Lapis: Release & Archive Packaging Tool ===")
      res.output.should contain("game")
      res.output.should contain("template")
      res.output.should contain("addon")
      res.output.should contain("lapis")
      res.output.should contain("benchmarks")
      res.output.should contain("--release")
      res.output.should contain("--output")
    end

    it "validates required parameters when packaging with unknown target" do
      res = LapisSpecHelper.run_lapis(["package", "unknown_target_xyz"])
      res.success?.should be_false
      res.all_output.should contain("Unknown packaging target: 'unknown_target_xyz'")
    end
  end

  describe "decompile command" do
    it "displays decompile help with radare2, disassembly, source mapping, and crystal options" do
      res = LapisSpecHelper.run_lapis(["decompile", "--help"])
      res.success?.should be_true
      res.output.should contain("=== Lapis: Native Binary Decompiler & Disassembly ===")
      res.output.should contain("--asm")
      res.output.should contain("--side-by-side")
      res.output.should contain("--source")
      res.output.should contain("--crystal")
    end
  end

  describe "bench command" do
    it "displays benchmark help with run and visualization options" do
      res = LapisSpecHelper.run_lapis(["bench", "--help"])
      res.success?.should be_true
      res.output.should contain("=== Lapis: Benchmark Suite & Performance Diagnostics ===")
      res.output.should contain("compare")
      res.output.should contain("export html")
    end
  end

  describe "log command" do
    it "displays log streaming and filtering options" do
      res = LapisSpecHelper.run_lapis(["log", "--help"])
      res.success?.should be_true
      res.output.should contain("lapis log [command] [target] [options]")
      res.output.should contain("--level")
      res.output.should contain("--channel")
      res.output.should contain("--follow")
    end
  end

  describe "run command" do
    it "displays run game monitor options" do
      res = LapisSpecHelper.run_lapis(["run", "--help"])
      res.success?.should be_true
      res.output.should contain("=== Lapis: Godot Editor & Runtime Launcher ===")
      res.output.should contain("--monitor")
      res.output.should contain("--debug")
    end
  end

  describe "sync command" do
    it "displays synchronization help across all consumer projects" do
      res = LapisSpecHelper.run_lapis(["sync", "--help"])
      res.success?.should be_true
      res.output.should contain("=== Lapis: Binary & Addon Synchronizer ===")
      res.output.should contain("--addons-only")
      res.output.should contain("--bins-only")
    end
  end

  describe "docs command" do
    it "displays documentation generator help" do
      res = LapisSpecHelper.run_lapis(["docs", "--help"])
      res.success?.should be_true
      res.output.should contain("=== Lapis: Documentation Generator & Patcher ===")
      res.output.should contain("--output")
      res.output.should contain("--github")
    end
  end
end
