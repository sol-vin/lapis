# tools/lapis/spec/scaffold_addon_spec.cr
require "./spec_helper"
require "compress/zip"

describe "Lapis Addon Scaffolding & Packaging Lifecycle" do
  describe "In-Project Addon Scaffolding" do
    it "scaffolds a complete addon inside an existing Godot project" do
      LapisSpecHelper.with_temp_dir("scaffold_in_proj") do |project_dir|
        # 1. Create minimal project.godot to simulate existing Godot project
        File.write(project_dir.join("project.godot"), <<-INI
; Engine configuration file.
config_version=5

[application]
config/name="HostGame"
INI
        )

        # 2. Run lapis scaffold addon test_hud
        res = LapisSpecHelper.run_lapis(
          ["scaffold", "addon", "test_hud", "-a", "AddonAuthor", "-d", "Test HUD Overlay", "--no-git"],
          chdir: project_dir
        )
        res.success?.should be_true, "Expected scaffold to succeed, output:\n#{res.all_output}"

        # 3. Assert directory structure
        addon_dir = project_dir.join("addons", "test_hud")
        Dir.exists?(addon_dir).should be_true
        File.exists?(addon_dir.join("plugin.cfg")).should be_true
        File.exists?(addon_dir.join("plugin.gd")).should be_true
        File.exists?(addon_dir.join("test_hud.gdextension")).should be_true
        File.exists?(addon_dir.join("shard.yml")).should be_true
        File.exists?(addon_dir.join("src", "main.cr")).should be_true
        File.exists?(addon_dir.join("spec", "main_spec.cr")).should be_true
        File.exists?(addon_dir.join("spec", "editor", "editor_spec.cr")).should be_true
        Dir.exists?(addon_dir.join("bin")).should be_true

        # 4. Verify customized file contents
        cfg = File.read(addon_dir.join("plugin.cfg"))
        cfg.should contain("name=\"Test Hud\"")
        cfg.should contain("author=\"AddonAuthor\"")
        cfg.should contain("description=\"Test HUD Overlay\"")
        cfg.should contain("script=\"plugin.gd\"")

        gd = File.read(addon_dir.join("plugin.gd"))
        gd.should contain("@tool")
        gd.should contain("extends TestHudPlugin")

        gdm = File.read(addon_dir.join("test_hud.gdextension"))
        gdm.should contain("entry_symbol = \"crystal_library_init\"")
        gdm.should contain("res://addons/test_hud/bin/crystal_bridge")

        main_cr = File.read(addon_dir.join("src", "main.cr"))
        main_cr.should contain("node TestHudPlugin < EditorPlugin")
        main_cr.should contain("node TestHudNode < Node")
        main_cr.should contain("signal triggered(text : String)")

        # 5. Verify auto-registration in project.godot
        p_godot = File.read(project_dir.join("project.godot"))
        p_godot.should contain("[editor_plugins]")
        p_godot.should contain("res://addons/test_hud/plugin.cfg")
      end
    end
  end

  describe "Standalone Addon Project Scaffolding" do
    it "scaffolds an independent exportable addon repository when no project.godot is present" do
      LapisSpecHelper.with_temp_dir("scaffold_standalone") do |workspace_dir|
        res = LapisSpecHelper.run_lapis(
          ["scaffold", "addon", "combat_system", "-a", "Studio Dev", "-d", "Turn-based combat framework", "--no-git"],
          chdir: workspace_dir
        )
        res.success?.should be_true, "Expected standalone scaffold to succeed, output:\n#{res.all_output}"

        addon_proj = workspace_dir.join("combat_system")
        Dir.exists?(addon_proj).should be_true
        File.exists?(addon_proj.join("project.godot")).should be_true
        File.exists?(addon_proj.join("Makefile")).should be_true
        File.exists?(addon_proj.join("shard.yml")).should be_true
        File.exists?(addon_proj.join("README.md")).should be_true
        File.exists?(addon_proj.join("src", "main.cr")).should be_true

        # Verify addon files inside addons/combat_system/
        inner_addon = addon_proj.join("addons", "combat_system")
        Dir.exists?(inner_addon).should be_true
        File.exists?(inner_addon.join("plugin.cfg")).should be_true
        File.exists?(inner_addon.join("combat_system.gdextension")).should be_true

        # Verify Makefile contains combat_system slug
        mf = File.read(addon_proj.join("Makefile"))
        mf.should contain("combat_system")

        # Verify shard.yml targets addon
        shard = File.read(addon_proj.join("shard.yml"))
        shard.should contain("name: combat_system")
        shard.should contain("targets:")
        shard.should contain("addon:")

        # Verify project.godot title and plugin enablement
        p_godot = File.read(addon_proj.join("project.godot"))
        p_godot.should contain("Combat System Test Runner")
        p_godot.should contain("res://addons/combat_system/plugin.cfg")
      end
    end
  end

  describe "Name Normalization & Collision Handling" do
    it "normalizes kebab-case, snake_case, and PascalCase names consistently" do
      LapisSpecHelper.with_temp_dir("norm_test") do |project_dir|
        File.write(project_dir.join("project.godot"), "; Config\nconfig_version=5\n")

        # Test PascalCase
        res1 = LapisSpecHelper.run_lapis(
          ["scaffold", "addon", "QuestLog", "--no-git"],
          chdir: project_dir
        )
        res1.success?.should be_true

        cfg1 = File.read(project_dir.join("addons", "quest_log", "plugin.cfg"))
        cfg1.should contain("name=\"Quest Log\"")
        gd1 = File.read(project_dir.join("addons", "quest_log", "plugin.gd"))
        gd1.should contain("extends QuestLogPlugin")

        # Test kebab-case
        res2 = LapisSpecHelper.run_lapis(
          ["scaffold", "addon", "fast-travel", "--no-git"],
          chdir: project_dir
        )
        res2.success?.should be_true

        cfg2 = File.read(project_dir.join("addons", "fast_travel", "plugin.cfg"))
        cfg2.should contain("name=\"Fast Travel\"")
        gd2 = File.read(project_dir.join("addons", "fast_travel", "plugin.gd"))
        gd2.should contain("extends FastTravelPlugin")
      end
    end

    it "refuses to overwrite an existing non-empty addon directory without --force" do
      LapisSpecHelper.with_temp_dir("collision_test") do |project_dir|
        File.write(project_dir.join("project.godot"), "; Config\nconfig_version=5\n")

        res1 = LapisSpecHelper.run_lapis(
          ["scaffold", "addon", "dialogue_ui", "--no-git"],
          chdir: project_dir
        )
        res1.success?.should be_true

        # Attempt to scaffold again without --force
        res2 = LapisSpecHelper.run_lapis(
          ["scaffold", "addon", "dialogue_ui", "--no-git"],
          chdir: project_dir
        )
        res2.success?.should be_false
        res2.exit_code.should eq(1)
        res2.all_output.should contain("already exists")

        # Now scaffold with --force
        res3 = LapisSpecHelper.run_lapis(
          ["scaffold", "addon", "dialogue_ui", "--force", "--no-git"],
          chdir: project_dir
        )
        res3.success?.should be_true
      end
    end
  end

  describe "Addon Packaging (`lapis package addon`)" do
    it "packages redistributable zip with correct layout and excludes forbidden binaries" do
      LapisSpecHelper.with_temp_dir("package_addon_test") do |project_dir|
        File.write(project_dir.join("project.godot"), "; Config\nconfig_version=5\n")

        # 1. Scaffold addon
        scaffold_res = LapisSpecHelper.run_lapis(
          ["scaffold", "addon", "inventory_pack", "--no-git"],
          chdir: project_dir
        )
        scaffold_res.success?.should be_true

        addon_bin = project_dir.join("addons", "inventory_pack", "bin")
        FileUtils.mkdir_p(addon_bin)

        # Stage mock library binaries to simulate a compiled addon
        ext = Lapis::Core::Env.dll_ext
        File.write(addon_bin.join("crystal_bridge.#{ext}"), "fake_bridge")
        File.write(addon_bin.join("game.#{ext}"), "fake_game")
        File.write(addon_bin.join("inventory_pack.#{ext}"), "fake_addon_dll")
        File.write(addon_bin.join("libgodot.#{ext}"), "fake_libgodot_must_be_excluded")

        # 2. Package addon
        pkg_res = LapisSpecHelper.run_lapis(
          ["package", "addon", "-p", project_dir.to_s, "-n", "inventory_pack"],
          chdir: project_dir
        )
        pkg_res.success?.should be_true, "Package failed:\n#{pkg_res.all_output}"

        plat = Lapis::Core::Env.current_platform
        zip_path = project_dir.join("dist", "inventory_pack-#{plat}.zip")
        zip_path = project_dir.join("dist", "inventory_pack.zip") unless File.exists?(zip_path)
        File.exists?(zip_path).should be_true, "Expected packaged zip at #{zip_path}"

        # 3. Inspect zip entries
        entries = [] of String
        Compress::Zip::Reader.open(zip_path.to_s) do |reader|
          reader.each_entry do |entry|
            entries << entry.filename
          end
        end

        # Must include plugin files
        entries.any? { |e| e.includes?("addons/inventory_pack/plugin.cfg") }.should be_true
        entries.any? { |e| e.includes?("addons/inventory_pack/plugin.gd") }.should be_true
        entries.any? { |e| e.includes?("addons/inventory_pack/inventory_pack.gdextension") }.should be_true

        # Must include bridge and game/addon libraries
        entries.any? { |e| e.includes?("crystal_bridge") }.should be_true
        entries.any? { |e| e.includes?("inventory_pack") || e.includes?("game") }.should be_true

        # Invariant: Must NEVER package libgodot (engine host binary)
        entries.any? { |e| e.includes?("libgodot") }.should be_false

        # Invariant: Must NEVER package source code or internal makefiles
        entries.any? { |e| e.starts_with?("src/") || e.includes?("/src/") }.should be_false
        entries.any? { |e| e == "Makefile" || e.ends_with?("/Makefile") }.should be_false
      end
    end
  end
end
