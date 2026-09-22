# tools/lapis/spec/cli_extended_spec.cr
require "./spec_helper"

describe "Lapis Extended CLI Commands" do
  describe "doctor command" do
    it "displays system diagnosis header and checks core tools" do
      res = LapisSpecHelper.run_lapis(["doctor"])
      res.success?.should be_true
      res.output.should contain("Diagnosing Lapis development environment")
      res.output.should contain("Crystal Compiler")
      res.output.should contain("Make")
    end

    it "displays doctor help with --help" do
      res = LapisSpecHelper.run_lapis(["doctor", "--help"])
      res.success?.should be_true
      res.output.should contain("=== Lapis: Environment & Toolchain Diagnostics ===")
    end
  end

  describe "init command" do
    it "displays init help with --help" do
      res = LapisSpecHelper.run_lapis(["init", "--help"])
      res.success?.should be_true
      res.output.should contain("=== Lapis: Project Initialization Tool ===")
      res.output.should contain("--name")
      res.output.should contain("--path")
    end

    it "scaffolds a valid new project structure in a temporary directory" do
      scratch_dir = LapisSpecHelper.repo_root.join("scratch", "test_cli_init_project")
      FileUtils.rm_rf(scratch_dir) if Dir.exists?(scratch_dir)
      FileUtils.mkdir_p(scratch_dir)

      begin
        res = LapisSpecHelper.run_lapis(["init", "-n", "TestScaffoldGame", "-p", scratch_dir.to_s])
        res.success?.should be_true
        res.output.should contain("Lapis integration initialized successfully")

        # Verify project files
        File.exists?(scratch_dir.join("project.godot")).should be_true
        File.exists?(scratch_dir.join("shard.yml")).should be_true
        File.exists?(scratch_dir.join("src/main.cr")).should be_true

        # Verify shard.yml contents
        shard_content = File.read(scratch_dir.join("shard.yml"))
        shard_content.should contain("testscaffoldgame")

        # Verify main.cr contents
        main_content = File.read(scratch_dir.join("src/main.cr"))
        (main_content.includes?("require \"lapis\"") || main_content.includes?("require \"libgodot\"")).should be_true
      ensure
        FileUtils.rm_rf(scratch_dir) if Dir.exists?(scratch_dir)
      end
    end
  end

  describe "clean command" do
    it "displays clean help with --help" do
      res = LapisSpecHelper.run_lapis(["clean", "--help"])
      res.success?.should be_true
      res.output.should contain("=== Lapis: Workspace Clean Tool ===")
      res.output.should contain("--dry-run")
      res.output.should contain("--all")
    end

    it "executes dry-run without altering existing files" do
      res = LapisSpecHelper.run_lapis(["clean", "--dry-run"])
      res.success?.should be_true
      res.output.should contain("Dry run complete")
    end
  end

  describe "package command" do
    it "displays package help with --help" do
      res = LapisSpecHelper.run_lapis(["package", "--help"])
      res.success?.should be_true
      res.output.should contain("=== Lapis: Release & Archive Packaging Tool ===")
      res.output.should contain("game")
      res.output.should contain("tests")
      res.output.should contain("lapis")
    end

    it "rejects invalid package targets with exit code 1" do
      res = LapisSpecHelper.run_lapis(["package", "nonexistent_target_xyz"])
      res.success?.should be_false
      res.exit_code.should eq(1)
      res.all_output.should contain("Unknown packaging target")
    end
  end

  describe "setup command" do
    it "displays setup help with --help" do
      res = LapisSpecHelper.run_lapis(["setup", "--help"])
      res.success?.should be_true
      res.output.should contain("=== Lapis: Godot Engine Development Setup ===")
      res.output.should contain("templates")
    end
  end

  describe "ide command" do
    it "displays ide help with --help" do
      res = LapisSpecHelper.run_lapis(["ide", "--help"])
      res.success?.should be_true
      res.output.should contain("=== Lapis: IDE & Editor Configuration Tool ===")
      res.output.should contain("setup")
      res.output.should contain("vscode")
    end

    it "generates VS Code workspace configuration in target directory" do
      scratch_dir = LapisSpecHelper.repo_root.join("scratch", "test_cli_ide_vscode")
      FileUtils.rm_rf(scratch_dir) if Dir.exists?(scratch_dir)
      FileUtils.mkdir_p(scratch_dir)

      begin
        res = LapisSpecHelper.run_lapis(["ide", "setup", "vscode", "-p", scratch_dir.to_s])
        res.success?.should be_true
        res.output.should contain("VS Code workspace configured")

        File.exists?(scratch_dir.join(".vscode/settings.json")).should be_true
        File.exists?(scratch_dir.join(".vscode/tasks.json")).should be_true
        File.exists?(scratch_dir.join(".vscode/launch.json")).should be_true

        settings_json = File.read(scratch_dir.join(".vscode/settings.json"))
        settings_json.should contain("crystal-lang.server")
        settings_json.should contain("crystalline")

        tasks_json = File.read(scratch_dir.join(".vscode/tasks.json"))
        tasks_json.should contain("Lapis: Build Game (F5)")
      ensure
        FileUtils.rm_rf(scratch_dir) if Dir.exists?(scratch_dir)
      end
    end
  end
end
