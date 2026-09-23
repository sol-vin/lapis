# tools/lapis/spec/commands_spec.cr
require "./spec_helper"

describe "Lapis Subcommands" do
  describe "scaffold" do
    it "scaffolds a complete game project with valid structure" do
      LapisSpecHelper.with_temp_dir("scaffold_game_test") do |dir|
        target_dir = dir.join("cool_game")
        res = LapisSpecHelper.run_lapis(["new", "game", "cool_game", "-t", target_dir.to_s, "--skip-godot", "--local"])
        res.success?.should be_true

        File.exists?(target_dir.join("project.godot")).should be_true
        File.exists?(target_dir.join("shard.yml")).should be_true
        File.exists?(target_dir.join("Makefile")).should be_true
        File.exists?(target_dir.join("src/main.cr")).should be_true
        File.exists?(target_dir.join("scenes/main.tscn")).should be_true

        # Verify project title in project.godot
        p_godot = File.read(target_dir.join("project.godot"))
        p_godot.should contain("config/name=\"Cool Game\"")
        p_godot.should contain("config_version=5")

        # Verify shard.yml
        shard = File.read(target_dir.join("shard.yml"))
        shard.should contain("name: cool_game")
        shard.should contain("targets:")
        shard.should contain("main: src/main.cr")
      end
    end

    it "does not pollute parent directory when scaffolding from an isolated directory" do
      LapisSpecHelper.with_temp_dir("scaffold_isolation_test") do |isolated_dir|
        res = LapisSpecHelper.run_lapis(
          ["new", "game", "this_is_my_game", "--skip-godot"],
          chdir: isolated_dir
        )
        res.success?.should be_true

        entries = Dir.children(isolated_dir).sort
        entries.should eq(["this_is_my_game"])

        game_dir = isolated_dir.join("this_is_my_game")
        File.exists?(game_dir.join("project.godot")).should be_true
        File.exists?(game_dir.join("shard.yml")).should be_true
        File.exists?(game_dir.join("src/main.cr")).should be_true
        File.exists?(game_dir.join("bin")).should be_true

        shard_content = File.read(game_dir.join("shard.yml"))
        shard_content.should contain("github: sol-vin/lapis")
      end
    end

    it "scaffolds a redistributable addon project with valid structure" do
      LapisSpecHelper.with_temp_dir("scaffold_addon_test") do |dir|
        target_addon = dir.join("custom_inventory")
        res = LapisSpecHelper.run_lapis(
          ["new", "addon", "custom_inventory", "-t", target_addon.to_s, "-a", "GameDev", "-d", "Item management plugin"]
        )
        res.success?.should be_true

        Dir.exists?(target_addon).should be_true
        File.exists?(target_addon.join("custom_inventory.gdextension")).should be_true
        File.exists?(target_addon.join("shard.yml")).should be_true
        File.exists?(target_addon.join("src/main.cr")).should be_true
        File.exists?(target_addon.join("spec/main_spec.cr")).should be_true
        File.exists?(target_addon.join("spec/editor/editor_spec.cr")).should be_true

        shard = File.read(target_addon.join("shard.yml"))
        shard.should contain("name: custom_inventory")
        shard.should contain("GameDev")
        shard.should contain("Item management plugin")
      end
    end

    it "prevents overwriting a non-empty directory unless --force is specified" do
      LapisSpecHelper.with_temp_dir("scaffold_force_test") do |dir|
        target_dir = dir.join("existing_game")
        FileUtils.mkdir_p(target_dir)
        File.write(target_dir.join("pre_existing.txt"), "keep me")

        # Without --force, should fail
        res = LapisSpecHelper.run_lapis(["new", "game", "existing_game", "-t", target_dir.to_s, "--skip-godot"])
        res.success?.should be_false
        res.all_output.should contain("not empty")

        # With --force, should succeed
        res_forced = LapisSpecHelper.run_lapis(["new", "game", "existing_game", "-t", target_dir.to_s, "--skip-godot", "--force"])
        res_forced.success?.should be_true
        File.exists?(target_dir.join("project.godot")).should be_true
      end
    end
  end

  describe "dirs" do
    it "ensures output directories exist" do
      res = LapisSpecHelper.run_lapis(["dirs"])
      res.success?.should be_true
      res.output.should contain("Ensured all output directories exist")
    end
  end

  describe "install and uninstall" do
    it "installs and uninstalls to an explicit target directory" do
      LapisSpecHelper.with_temp_dir("install_test") do |target_dir|
        target_exe_name = "lapis" + (Lapis::Core::Env.windows? ? ".exe" : "")
        target_bin = target_dir.join(target_exe_name)

        # 1. Install to target_dir
        res_install = LapisSpecHelper.run_lapis(["install", "--dir", target_dir.to_s])
        res_install.success?.should be_true
        File.exists?(target_bin).should be_true

        # Verify installed binary works
        out_io = IO::Memory.new
        status = Process.run(target_bin.to_s, ["--version"], output: out_io)
        status.success?.should be_true
        out_io.to_s.should contain("Lapis v#{Lapis::VERSION}")

        # 2. Uninstall from target_dir
        res_uninstall = LapisSpecHelper.run_lapis(["uninstall", "--dir", target_dir.to_s])
        res_uninstall.success?.should be_true
        File.exists?(target_bin).should be_false
      end
    end
  end

  describe "ide setup" do
    it "configures VS Code workspace with settings, tasks, launch, and extensions" do
      LapisSpecHelper.with_temp_dir("ide_vscode_test") do |dir|
        res = LapisSpecHelper.run_lapis(["ide", "setup", "vscode", "-p", dir.to_s, "-f"])
        res.success?.should be_true

        vscode_dir = dir.join(".vscode")
        File.exists?(vscode_dir.join("settings.json")).should be_true
        File.exists?(vscode_dir.join("tasks.json")).should be_true
        File.exists?(vscode_dir.join("launch.json")).should be_true
        File.exists?(vscode_dir.join("extensions.json")).should be_true

        settings = File.read(vscode_dir.join("settings.json"))
        settings.should contain("crystal-lang.server")
        settings.should contain("--stdio")

        launch = File.read(vscode_dir.join("launch.json"))
        launch.should contain("lldb")

        tasks = File.read(vscode_dir.join("tasks.json"))
        tasks.should contain("lapis")

        extensions = File.read(vscode_dir.join("extensions.json"))
        extensions.should contain("crystal-lang.crystal-lang")
        extensions.should contain("geequlim.godot-tools")
      end
    end

    it "configures Zed workspace with crystalline --stdio" do
      LapisSpecHelper.with_temp_dir("ide_zed_test") do |dir|
        res = LapisSpecHelper.run_lapis(["ide", "setup", "zed", "-p", dir.to_s, "-f"])
        res.success?.should be_true

        zed_file = dir.join(".zed/settings.json")
        File.exists?(zed_file).should be_true
        content = File.read(zed_file)
        content.should contain("crystalline")
        content.should contain("--stdio")
      end
    end

    it "configures Neovim workspace with .lapis_nvim.lua" do
      LapisSpecHelper.with_temp_dir("ide_nvim_test") do |dir|
        res = LapisSpecHelper.run_lapis(["ide", "setup", "neovim", "-p", dir.to_s, "-f"])
        res.success?.should be_true

        nvim_file = dir.join(".lapis_nvim.lua")
        File.exists?(nvim_file).should be_true
        content = File.read(nvim_file)
        content.should contain("crystalline")
        content.should contain("--stdio")
      end
    end
  end

  describe "doctor" do
    it "checks all required tools and displays diagnostic summary" do
      res = LapisSpecHelper.run_lapis(["doctor"])
      res.success?.should be_true
      res.output.should contain("Diagnosing Lapis development environment")
      res.output.should contain("Crystal Compiler")
      res.output.should contain("Native Debugger (LLDB)")
    end
  end
end

