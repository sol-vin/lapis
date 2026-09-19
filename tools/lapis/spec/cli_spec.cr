# tools/lapis/spec/cli_spec.cr
require "./spec_helper"

describe "Lapis CLI" do
  describe "version and global flags" do
    it "displays version with --version" do
      res = LapisSpecHelper.run_lapis(["--version"])
      res.success?.should be_true
      res.output.should contain("Lapis v#{Lapis::VERSION}")
    end

    it "displays version with -v" do
      res = LapisSpecHelper.run_lapis(["-v"])
      res.success?.should be_true
      res.output.should contain("Lapis v#{Lapis::VERSION}")
    end

    it "displays help banner with --help" do
      res = LapisSpecHelper.run_lapis(["--help"])
      res.success?.should be_true
      res.output.should contain("Lapis: Unified Crystal Engine Toolchain for Godot")
      res.output.should contain("Usage:")
      res.output.should contain("dirs")
      res.output.should contain("build")
      res.output.should contain("scaffold")
    end

    it "displays help banner with -h" do
      res = LapisSpecHelper.run_lapis(["-h"])
      res.success?.should be_true
      res.output.should contain("Usage:")
    end

    it "displays help banner when no arguments are provided" do
      res = LapisSpecHelper.run_lapis([] of String)
      res.success?.should be_true
      res.output.should contain("Usage:")
    end

    it "returns exit code 1 on unknown subcommand" do
      res = LapisSpecHelper.run_lapis(["unknown_subcommand_xyz"])
      res.success?.should be_false
      res.exit_code.should eq(1)
      res.all_output.should contain("Unknown command: 'unknown_subcommand_xyz'")
    end

    it "accepts --verbose flag with commands" do
      res = LapisSpecHelper.run_lapis(["--verbose", "dirs"])
      res.success?.should be_true
    end

    it "accepts -q / --quiet flag with commands" do
      res = LapisSpecHelper.run_lapis(["-q", "dirs"])
      res.success?.should be_true
    end
  end

  describe "subcommand help dispatch" do
    it "handles 'lapis help' without args" do
      res = LapisSpecHelper.run_lapis(["help"])
      res.success?.should be_true
      res.output.should contain("Usage:")
    end

    it "handles 'lapis help dirs'" do
      res = LapisSpecHelper.run_lapis(["help", "dirs"])
      res.success?.should be_true
      res.output.should contain("Usage: lapis dirs")
    end

    it "handles 'lapis help deps' and 'lapis deps --help'" do
      res1 = LapisSpecHelper.run_lapis(["help", "deps"])
      res1.success?.should be_true
      res1.output.should contain("Runtime Dependencies Manager")

      res2 = LapisSpecHelper.run_lapis(["deps", "--help"])
      res2.success?.should be_true
      res2.output.should contain("Runtime Dependencies Manager")
    end

    it "handles 'lapis help sync' and 'lapis sync --help'" do
      res1 = LapisSpecHelper.run_lapis(["help", "sync"])
      res1.success?.should be_true
      res1.output.should contain("Synchronizer")

      res2 = LapisSpecHelper.run_lapis(["sync", "--help"])
      res2.success?.should be_true
      res2.output.should contain("Synchronizer")
    end

    it "handles 'lapis help build' and 'lapis build --help'" do
      res1 = LapisSpecHelper.run_lapis(["help", "build"])
      res1.success?.should be_true
      res1.output.should contain("Crystal Game & Plugin Compiler")

      res2 = LapisSpecHelper.run_lapis(["build", "--help"])
      res2.success?.should be_true
      res2.output.should contain("Crystal Game & Plugin Compiler")
    end

    it "handles 'lapis help bind' and 'lapis bind --help'" do
      res1 = LapisSpecHelper.run_lapis(["help", "bind"])
      res1.success?.should be_true
      res1.output.should contain("Binding Generator")

      res2 = LapisSpecHelper.run_lapis(["bind", "--help"])
      res2.success?.should be_true
      res2.output.should contain("Binding Generator")
    end

    it "handles 'lapis help clean' and 'lapis clean --help'" do
      res1 = LapisSpecHelper.run_lapis(["help", "clean"])
      res1.success?.should be_true
      res1.output.should contain("Clean Tool")

      res2 = LapisSpecHelper.run_lapis(["clean", "--help"])
      res2.success?.should be_true
      res2.output.should contain("Clean Tool")
    end

    it "handles 'lapis help test' and 'lapis test --help'" do
      res1 = LapisSpecHelper.run_lapis(["help", "test"])
      res1.success?.should be_true
      res1.output.should contain("Test Suite Runner")

      res2 = LapisSpecHelper.run_lapis(["test", "--help"])
      res2.success?.should be_true
      res2.output.should contain("Test Suite Runner")
    end

    it "handles 'lapis help editor' and 'lapis editor --help'" do
      res1 = LapisSpecHelper.run_lapis(["help", "editor"])
      res1.success?.should be_true
      res1.output.should contain("Godot Editor & Runtime Launcher")

      res2 = LapisSpecHelper.run_lapis(["editor", "--help"])
      res2.success?.should be_true
      res2.output.should contain("Godot Editor & Runtime Launcher")
    end

    it "handles 'lapis help setup' and 'lapis setup --help'" do
      res1 = LapisSpecHelper.run_lapis(["help", "setup"])
      res1.success?.should be_true
      res1.output.should contain("Godot Engine Development Setup")

      res2 = LapisSpecHelper.run_lapis(["setup", "--help"])
      res2.success?.should be_true
      res2.output.should contain("Godot Engine Development Setup")
    end

    it "handles 'lapis help scaffold' and 'lapis scaffold --help'" do
      res1 = LapisSpecHelper.run_lapis(["help", "scaffold"])
      res1.success?.should be_true
      res1.output.should contain("Project Scaffolding Tool")

      res2 = LapisSpecHelper.run_lapis(["scaffold", "--help"])
      res2.success?.should be_true
      res2.output.should contain("Project Scaffolding Tool")
    end

    it "handles 'lapis help package' and 'lapis package --help'" do
      res1 = LapisSpecHelper.run_lapis(["help", "package"])
      res1.success?.should be_true
      res1.output.should contain("Release & Archive Packaging Tool")

      res2 = LapisSpecHelper.run_lapis(["package", "--help"])
      res2.success?.should be_true
      res2.output.should contain("Release & Archive Packaging Tool")
    end

    it "handles 'lapis help docs' and 'lapis docs --help'" do
      res1 = LapisSpecHelper.run_lapis(["help", "docs"])
      res1.success?.should be_true
      res1.output.should contain("Documentation Generator")

      res2 = LapisSpecHelper.run_lapis(["docs", "--help"])
      res2.success?.should be_true
      res2.output.should contain("Documentation Generator")
    end

    it "handles 'lapis help install' and 'lapis install --help'" do
      res1 = LapisSpecHelper.run_lapis(["help", "install"])
      res1.success?.should be_true
      res1.output.should contain("Toolchain Installation Manager")

      res2 = LapisSpecHelper.run_lapis(["install", "--help"])
      res2.success?.should be_true
      res2.output.should contain("Toolchain Installation Manager")
    end

    it "handles 'lapis help' with unknown command gracefully" do
      res = LapisSpecHelper.run_lapis(["help", "foobar_invalid"])
      res.all_output.should contain("Unknown command for help: 'foobar_invalid'")
      res.output.should contain("Usage:")
    end
  end
end
