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
end
