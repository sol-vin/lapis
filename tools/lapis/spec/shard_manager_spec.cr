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

  describe "VersionMatcher" do
    it "matches pessimistic version constraints (~>)" do
      vm = Lapis::Commands::ShardManager::VersionMatcher
      vm.matches?("~> 0.1.0", "0.1.0").should be_true
      vm.matches?("~> 0.1.0", "0.1.9").should be_true
      vm.matches?("~> 0.1.0", "0.2.0").should be_false
      vm.matches?("~> 0.1.0", "1.0.0").should be_false
      vm.matches?("~> 1.2", "1.5.0").should be_true
      vm.matches?("~> 1.2", "2.0.0").should be_false
    end

    it "matches comparison operators (>=, >, <=, <, =)" do
      vm = Lapis::Commands::ShardManager::VersionMatcher
      vm.matches?(">= 1.2.0", "1.2.0").should be_true
      vm.matches?(">= 1.2.0", "1.3.0").should be_true
      vm.matches?(">= 1.2.0", "1.1.9").should be_false

      vm.matches?("> 1.0.0", "1.0.1").should be_true
      vm.matches?("> 1.0.0", "1.0.0").should be_false

      vm.matches?("<= 2.0.0", "2.0.0").should be_true
      vm.matches?("<= 2.0.0", "2.0.1").should be_false

      vm.matches?("< 3.0.0", "2.9.9").should be_true
      vm.matches?("< 3.0.0", "3.0.0").should be_false

      vm.matches?("= 1.0.0", "1.0.0").should be_true
      vm.matches?("= 1.0.0", "1.0.1").should be_false
    end

    it "intersects constraints and finds highest compatible" do
      vm = Lapis::Commands::ShardManager::VersionMatcher
      candidates = ["0.1.0", "0.1.5", "0.2.0", "1.0.0"]
      highest = vm.highest_compatible(["~> 0.1.0", ">= 0.1.2"], candidates)
      highest.should eq("0.1.5")
    end
  end

  describe "addon entry formatting and shard.yml addons section" do
    it "formats addon entry with various providers" do
      spec_gh = Lapis::Commands::InstallAddon.parse_spec("github:sol-vin/crshader")
      entry_gh = Lapis::Commands::ShardManager.format_addon_entry("crshader", spec_gh, version: "~> 0.1.0")
      entry_gh.should contain("crshader:")
      entry_gh.should contain("github: sol-vin/crshader")
      entry_gh.should contain("version: \"~> 0.1.0\"")

      spec_gl = Lapis::Commands::InstallAddon.parse_spec("gitlab:sol-vin/crshader@v1.0.0")
      entry_gl = Lapis::Commands::ShardManager.format_addon_entry("crshader", spec_gl)
      entry_gl.should contain("crshader:")
      entry_gl.should contain("gitlab: sol-vin/crshader")

      spec_git = Lapis::Commands::InstallAddon.parse_spec("git:https://example.com/repo.git@master")
      entry_git = Lapis::Commands::ShardManager.format_addon_entry("custom", spec_git)
      entry_git.should contain("custom:")
      entry_git.should contain("git: https://example.com/repo.git")
    end

    it "adds and reads addons under addons: section in shard.yml" do
      temp_dir = Path.new(Dir.tempdir).join("lapis_test_addon_sec_#{Time.utc.to_unix_ms}")
      FileUtils.mkdir_p(temp_dir)
      shard_yml = temp_dir.join("shard.yml")
      File.write(shard_yml, <<-YAML
name: test_game
version: 0.1.0
dependencies:
  lapis:
    github: sol-vin/lapis
YAML
      )

      spec = Lapis::Commands::InstallAddon.parse_spec("github:sol-vin/crshader")
      res = Lapis::Commands::ShardManager.add_addon(temp_dir, "crshader", spec, version: "~> 0.1.0")
      res.should be_true

      content = File.read(shard_yml)
      content.should contain("addons:")
      content.should contain("crshader:")
      content.should contain("github: sol-vin/crshader")
      content.should contain("version: \"~> 0.1.0\"")

      addons = Lapis::Commands::ShardManager.read_addons(shard_yml)
      addons.has_key?("crshader").should be_true
      req = addons["crshader"]
      req.provider.should eq(:github)
      req.source.should eq("sol-vin/crshader")
      req.version.should eq("~> 0.1.0")

      # Remove addon
      rem_res = Lapis::Commands::ShardManager.remove_addon(temp_dir, "crshader")
      rem_res.should be_true
      File.read(shard_yml).should_not contain("crshader:")

      FileUtils.rm_rf(temp_dir)
    end
  end

  describe "AddonNegotiator" do
    it "resolves compatible requirements into a single canonical version" do
      req1 = Lapis::Commands::ShardManager::AddonRequirement.new(
        name: "crshader",
        provider: :github,
        source: "sol-vin/crshader",
        version: "~> 0.1.0",
        requester: "root"
      )
      req2 = Lapis::Commands::ShardManager::AddonRequirement.new(
        name: "crshader",
        provider: :github,
        source: "sol-vin/crshader",
        version: ">= 0.1.2",
        requester: "addon_a"
      )

      success, resolved, conflicts = Lapis::Commands::ShardManager::AddonNegotiator.negotiate([req1, req2])
      success.should be_true
      conflicts.empty?.should be_true
      resolved.size.should eq(1)
      res = resolved["crshader"]
      res.name.should eq("crshader")
      res.all_requesters.should eq(["root", "addon_a"])
    end

    it "flags incompatible requirements as conflicts" do
      req1 = Lapis::Commands::ShardManager::AddonRequirement.new(
        name: "crshader",
        provider: :github,
        source: "sol-vin/crshader",
        version: "= 0.1.0",
        requester: "addon_a"
      )
      req2 = Lapis::Commands::ShardManager::AddonRequirement.new(
        name: "crshader",
        provider: :github,
        source: "sol-vin/crshader",
        version: "= 0.2.0",
        requester: "addon_b"
      )

      success, resolved, conflicts = Lapis::Commands::ShardManager::AddonNegotiator.negotiate([req1, req2])
      success.should be_false
      conflicts.empty?.should be_false
      conflicts.first.should contain("Version conflict for addon 'crshader'")
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

    it "lists dependencies via lapis shard list and lapis shard ls" do
      res1 = LapisSpecHelper.run_lapis(["shard", "list"])
      res1.success?.should be_true
      res1.output.should contain("Crystal Shard Dependencies")

      res2 = LapisSpecHelper.run_lapis(["shard", "ls"])
      res2.success?.should be_true
      res2.output.should contain("Crystal Shard Dependencies")
    end

    it "reads dependencies accurately using read_dependencies" do
      root_shard = LapisSpecHelper.repo_root.join("shard.yml")
      deps = Lapis::Commands::ShardManager.read_dependencies(root_shard)
      deps.should be_a(Array(Lapis::Commands::ShardManager::ShardDepInfo))
    end

    it "rejects invalid shard subcommands with an error and exit code 1" do
      res = LapisSpecHelper.run_lapis(["shard", "invalid_subcmd_xyz"])
      res.success?.should be_false
      res.exit_code.should eq(1)
      res.all_output.should contain("Unknown shard subcommand: 'invalid_subcmd_xyz'")
    end
  end
end
