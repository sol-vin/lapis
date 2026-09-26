require "./spec_helper"
require "../src/commands/shard_manager"
require "../src/commands/install_addon"

describe "Lapis::Commands::ShardManager" do
  describe "dependency entry formatting" do
    it "formats github dependency with default branch" do
      spec = Lapis::Commands::InstallAddon.parse_spec("github:sol-vin/crshader")
      entry = Lapis::Commands::ShardManager.format_dependency_entry("crshader", spec)
      entry.should contain("crshader:")
      entry.should contain("github: sol-vin/crshader")
      entry.should contain("branch: master")
    end

    it "formats github dependency with specific tag" do
      spec = Lapis::Commands::InstallAddon.parse_spec("github:sol-vin/crshader@v0.2.0")
      entry = Lapis::Commands::ShardManager.format_dependency_entry("crshader", spec, tag: "v0.2.0")
      entry.should contain("crshader:")
      entry.should contain("github: sol-vin/crshader")
      entry.should contain("branch: v0.2.0")
    end

    it "formats github dependency with version constraint" do
      spec = Lapis::Commands::InstallAddon.parse_spec("github:sol-vin/crshader")
      entry = Lapis::Commands::ShardManager.format_dependency_entry("crshader", spec, version: "~> 0.1.0")
      entry.should contain("crshader:")
      entry.should contain("github: sol-vin/crshader")
      entry.should contain("version: \"~> 0.1.0\"")
    end

    it "formats local path dependency" do
      spec = Lapis::Commands::InstallAddon.parse_spec("../../bin/crshader")
      entry = Lapis::Commands::ShardManager.format_dependency_entry("crshader", spec, path_override: "../crshader")
      entry.should contain("crshader:")
      entry.should contain("path: ../crshader")
    end
  end

  describe "shard.yml manipulation" do
    it "initializes shard.yml and adds dependency if file does not exist" do
      temp_dir = Path.new(Dir.tempdir).join("lapis_test_shard_init_#{Time.utc.to_unix_ms}")
      FileUtils.mkdir_p(temp_dir)
      shard_yml = temp_dir.join("shard.yml")

      spec = Lapis::Commands::InstallAddon.parse_spec("github:sol-vin/crshader")
      res = Lapis::Commands::ShardManager.add_dependency(temp_dir, "crshader", spec)
      res.should be_true

      File.exists?(shard_yml).should be_true
      content = File.read(shard_yml)
      content.should contain("dependencies:")
      content.should contain("crshader:")
      content.should contain("github: sol-vin/crshader")

      FileUtils.rm_rf(temp_dir)
    end

    it "adds and removes dependency in existing shard.yml without corrupting other dependencies" do
      temp_dir = Path.new(Dir.tempdir).join("lapis_test_shard_modify_#{Time.utc.to_unix_ms}")
      FileUtils.mkdir_p(temp_dir)
      shard_yml = temp_dir.join("shard.yml")

      File.write(shard_yml, <<-YAML
name: test_game
version: 0.1.0

dependencies:
  lapis:
    github: sol-vin/lapis
    branch: master
YAML
      )

      # Add crshader
      spec = Lapis::Commands::InstallAddon.parse_spec("github:sol-vin/crshader")
      res = Lapis::Commands::ShardManager.add_dependency(temp_dir, "crshader", spec)
      res.should be_true

      content = File.read(shard_yml)
      content.should contain("lapis:")
      content.should contain("crshader:")
      content.should contain("github: sol-vin/crshader")

      # Remove crshader
      del_res = Lapis::Commands::ShardManager.remove_dependency(temp_dir, "crshader")
      del_res.should be_true

      after_content = File.read(shard_yml)
      after_content.should contain("lapis:")
      after_content.should_not contain("crshader:")

      FileUtils.rm_rf(temp_dir)
    end

    it "updates an existing dependency entry cleanly" do
      temp_dir = Path.new(Dir.tempdir).join("lapis_test_shard_update_#{Time.utc.to_unix_ms}")
      FileUtils.mkdir_p(temp_dir)
      shard_yml = temp_dir.join("shard.yml")

      File.write(shard_yml, <<-YAML
name: test_game
version: 0.1.0

dependencies:
  crshader:
    github: sol-vin/crshader
    branch: master
YAML
      )

      # Update to path dependency
      spec = Lapis::Commands::InstallAddon.parse_spec("../../bin/crshader")
      res = Lapis::Commands::ShardManager.add_dependency(temp_dir, "crshader", spec, path_override: "../local_crshader")
      res.should be_true

      content = File.read(shard_yml)
      content.should contain("path: ../local_crshader")
      content.should_not contain("github: sol-vin/crshader")

      FileUtils.rm_rf(temp_dir)
    end

    it "auto-heals ambiguous dependency sources with shard.override.yml" do
      temp_dir = Lapis::Core::Env::ROOT_DIR.join("scratch", "lapis_test_shard_heal_#{Time.utc.to_unix_ms}")
      FileUtils.mkdir_p(temp_dir)
      shard_yml = temp_dir.join("shard.yml")
      root_rel = Path.new(Lapis::Core::Env::ROOT_DIR).relative_to(temp_dir).to_s.gsub('\\', '/')

      File.write(shard_yml, <<-YAML
name: test_heal
version: 0.1.0

dependencies:
  crshader:
    github: sol-vin/crshader
    branch: master
  lapis:
    path: #{root_rel}
YAML
      )

      # Running shards install should trigger auto-healing and create shard.override.yml
      res = Lapis::Commands::ShardManager.run_shards_install(temp_dir)
      res.should be_true

      override_yml = temp_dir.join("shard.override.yml")
      File.exists?(override_yml).should be_true
      File.read(override_yml).should contain("lapis:")
      File.read(override_yml).should contain("path: #{root_rel}")

      FileUtils.rm_rf(temp_dir)
    end
  end

  describe "dual-mode install addon --shard" do
    it "installs addon files and updates shard.yml simultaneously" do
      temp_dir = Path.new(Dir.tempdir).join("lapis_test_dual_install_#{Time.utc.to_unix_ms}")
      FileUtils.mkdir_p(temp_dir)
      project_godot = temp_dir.join("project.godot")
      File.write(project_godot, "config_version=5\n[application]\nconfig/name=\"Test\"\n")
      shard_yml = temp_dir.join("shard.yml")
      File.write(shard_yml, "name: test\nversion: 0.1.0\ndependencies:\n")

      # Create dummy addon zip
      dummy_zip = temp_dir.join("dummy_addon.zip")
      File.open(dummy_zip.to_s, "w") do |file|
        Compress::Zip::Writer.open(file) do |zip|
          zip.add("addons/custom_fx/plugin.cfg", "plugin_content")
          zip.add("addons/custom_fx/plugin.gd", "extends EditorPlugin")
        end
      end

      spec = Lapis::Commands::InstallAddon.parse_spec(dummy_zip.to_s)
      # Force spec name to custom_fx
      spec.repo = "custom_fx"

      code = Lapis::Commands::InstallAddon.install_addon(
        spec,
        temp_dir,
        auto_enable: true,
        force: true,
        also_shard: true,
        path_override: "../local_custom_fx"
      )
      code.should eq(0)

      # Check addon dir
      File.exists?(temp_dir.join("addons/custom_fx/plugin.cfg")).should be_true
      # Check project.godot
      File.read(project_godot).should contain("res://addons/custom_fx/plugin.cfg")
      # Check shard.yml
      File.read(shard_yml).should contain("custom_fx:")
      File.read(shard_yml).should contain("path: ../local_custom_fx")

      # Uninstall with also_shard: true
      un_code = Lapis::Commands::InstallAddon.uninstall_addon("custom_fx", temp_dir, also_shard: true)
      un_code.should eq(0)

      Dir.exists?(temp_dir.join("addons/custom_fx")).should be_false
      File.read(project_godot).should_not contain("res://addons/custom_fx/plugin.cfg")
      File.read(shard_yml).should_not contain("custom_fx:")

      FileUtils.rm_rf(temp_dir)
    end
  end

  describe "CLI commands" do
    it "displays help for install shard" do
      res = LapisSpecHelper.run_lapis(["install", "shard", "--help"])
      res.success?.should be_true
      res.output.should contain("Lapis: Shard Dependency Manager")
      res.output.should contain("lapis install shard <specifier>")
    end

    it "displays help for uninstall shard" do
      res = LapisSpecHelper.run_lapis(["uninstall", "shard", "--help"])
      res.success?.should be_true
      res.output.should contain("Usage: lapis uninstall shard <name>")
    end

    it "shows --shard and --bind options in install addon help" do
      res = LapisSpecHelper.run_lapis(["install", "addon", "--help"])
      res.success?.should be_true
      res.output.should contain("--shard")
      res.output.should contain("--bind")
      res.output.should contain("--path=DIR")
    end
  end
end
