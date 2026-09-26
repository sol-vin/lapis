# spec/lapis_install_addon_spec.cr
# Verifies Lapis CLI addon management: parse_spec, installation, project.godot registration,
# extension_list.cfg discovery, and GDExtension runtime dependency staging without libgodot.dll.

require "spec"
require "file_utils"
require "compress/zip"
require "../tools/lapis/src/version"
require "../tools/lapis/src/core/env"
require "../tools/lapis/src/core/logger"
require "../tools/lapis/src/commands/deps"
require "../tools/lapis/src/commands/install_addon"

describe "Lapis Addon Package Manager (`lapis install addon`)" do
  repo_root = Path.new(File.expand_path("..", __DIR__))
  ext = {% if flag?(:windows) %} "dll" {% elsif flag?(:darwin) %} "dylib" {% else %} "so" {% end %}
  bridge_name = {% if flag?(:windows) %} "crystal_bridge.dll" {% elsif flag?(:darwin) %} "crystal_bridge.dylib" {% else %} "crystal_bridge.so" {% end %}

  describe "Commands::InstallAddon.parse_spec" do
    it "correctly parses 'github:owner/repo' specifier" do
      spec = Lapis::Commands::InstallAddon.parse_spec("github:sol-vin/crshader")
      spec.type.should eq(:github)
      spec.owner.should eq("sol-vin")
      spec.repo.should eq("crshader")
      spec.name.should eq("crshader")
      spec.tag.should be_nil
    end

    it "correctly parses 'owner/repo@tag' specifier" do
      spec = Lapis::Commands::InstallAddon.parse_spec("sol-vin/crshader@v0.1.0")
      spec.type.should eq(:github)
      spec.owner.should eq("sol-vin")
      spec.repo.should eq("crshader")
      spec.name.should eq("crshader")
      spec.tag.should eq("v0.1.0")
    end

    it "correctly parses local .zip archive path" do
      spec = Lapis::Commands::InstallAddon.parse_spec("dist/crshader-windows.zip")
      spec.type.should eq(:local_file)
      spec.name.should eq("crshader")
    end

    it "correctly parses local directory path" do
      spec = Lapis::Commands::InstallAddon.parse_spec("addons/custom_tool")
      spec.type.should eq(:local_dir)
      spec.name.should eq("custom_tool")
    end
  end

  describe "End-to-End Addon Installation & Lifecycle" do
    it "installs addon, registers plugin, updates extension_list, and stages bridge without libgodot" do
      scratch_dir = repo_root.join("scratch", "test_addon_install_#{Time.utc.to_unix_ms}")
      FileUtils.rm_rf(scratch_dir) if Dir.exists?(scratch_dir)
      FileUtils.mkdir_p(scratch_dir)

      begin
        # 1. Scaffold a minimal target Godot project
        project_dir = scratch_dir.join("game_project")
        FileUtils.mkdir_p(project_dir)
        initial_project_godot = <<-CFG
; Engine configuration file.
[application]
config/name="Test Game"
config/features=PackedStringArray("4.8")
CFG
        File.write(project_dir.join("project.godot"), initial_project_godot)

        # 2. Build a mock addon zip containing plugin.cfg, my_plugin.gdextension, and placeholder game library
        addon_zip_path = scratch_dir.join("test_addon.zip")
        File.open(addon_zip_path.to_s, "w") do |file|
          Compress::Zip::Writer.open(file) do |zip|
            zip.add("addons/mock_addon/plugin.cfg", <<-CFG
[plugin]
name="Mock Addon"
description="Unit test mock addon"
author="Lapis Test"
version="1.0"
script="mock_addon.gd"
CFG
            )
            zip.add("addons/mock_addon/mock_addon.gdextension", <<-CFG
[configuration]
entry_symbol="crystal_library_init"
compatibility_minimum="4.1"

[libraries]
windows.debug.x86_64="res://addons/mock_addon/bin/crystal_bridge.dll"
linux.debug.x86_64="res://addons/mock_addon/bin/crystal_bridge.so"
macos.debug="res://addons/mock_addon/bin/crystal_bridge.dylib"
CFG
            )
            zip.add("addons/mock_addon/bin/game.#{ext}", "DUMMY_GAME_BIN")
          end
        end

        # 3. Execute Lapis::Commands::InstallAddon.install_addon
        spec = Lapis::Commands::InstallAddon.parse_spec(addon_zip_path.to_s)
        exit_code = Lapis::Commands::InstallAddon.install_addon(
          spec: spec,
          project_dir: project_dir,
          auto_enable: true,
          force: true
        )
        exit_code.should eq(0)

        # 4. Verify addon files extracted into addons/mock_addon
        target_addon_dir = project_dir.join("addons", "mock_addon")
        Dir.exists?(target_addon_dir).should be_true
        File.exists?(target_addon_dir.join("plugin.cfg")).should be_true
        File.exists?(target_addon_dir.join("mock_addon.gdextension")).should be_true
        File.exists?(target_addon_dir.join("bin", "game.#{ext}")).should be_true

        # 5. Verify plugin auto-enabled in project.godot
        godot_cfg = File.read(project_dir.join("project.godot"))
        godot_cfg.should contain("res://addons/mock_addon/plugin.cfg")
        godot_cfg.should contain("[editor_plugins]")

        # 6. Verify GDExtension registered in .godot/extension_list.cfg
        ext_list_path = project_dir.join(".godot", "extension_list.cfg")
        File.exists?(ext_list_path).should be_true
        ext_list = File.read(ext_list_path)
        ext_list.should contain("res://addons/mock_addon/mock_addon.gdextension")

        # 7. Verify crystal_bridge and CRT dependencies staged in addons/mock_addon/bin
        bin_dir = target_addon_dir.join("bin")
        File.exists?(bin_dir.join(bridge_name)).should be_true

        {% if flag?(:windows) %}
          File.exists?(bin_dir.join("gc.dll")).should be_true
          File.exists?(bin_dir.join("iconv-2.dll")).should be_true
          File.exists?(bin_dir.join("pcre2-8.dll")).should be_true
        {% end %}

        # 8. CRITICAL INVARIANT: Verify libgodot.dll is NEVER staged into addon bin
        libgodot_file = {% if flag?(:windows) %} "libgodot.dll" {% elsif flag?(:darwin) %} "libgodot.dylib" {% else %} "libgodot.so" {% end %}
        File.exists?(bin_dir.join(libgodot_file)).should be_false
        File.exists?(bin_dir.join("libgodot.lib")).should be_false

        # 9. Verify uninstallation cleans up project.godot, extension_list.cfg, and addon directory
        uninst_code = Lapis::Commands::InstallAddon.uninstall_addon("mock_addon", project_dir)
        uninst_code.should eq(0)

        Dir.exists?(target_addon_dir).should be_false
        updated_godot_cfg = File.read(project_dir.join("project.godot"))
        updated_godot_cfg.should_not contain("res://addons/mock_addon/plugin.cfg")

        updated_ext_list = File.read(ext_list_path)
        updated_ext_list.should_not contain("res://addons/mock_addon/mock_addon.gdextension")

      ensure
        FileUtils.rm_rf(scratch_dir) if Dir.exists?(scratch_dir)
      end
    end
  end
end
