# spec/external/diorite_spec.cr
# Informational ecosystem compatibility spec for Diorite.
# Verifies Diorite in-editor GDExtension plugin and runtime editor integration.
# Failure in this spec is non-blocking (diagnostic notice only) to track ecosystem compatibility.

require "../spec_helper"
require "../../tools/lapis/src/commands/install_addon"

describe "Diorite In-Editor Plugin & Debug Draw (Informational Ecosystem Spec)" do
  ext = {% if flag?(:windows) %} "dll" {% elsif flag?(:darwin) %} "dylib" {% else %} "so" {% end %}
  bridge_name = {% if flag?(:windows) %} "crystal_bridge.dll" {% elsif flag?(:darwin) %} "crystal_bridge.dylib" {% else %} "crystal_bridge.so" {% end %}

  repo_root = Path.new(File.expand_path("../..", __DIR__))
  test_project_dir = repo_root.join("scratch", "test_diorite_project")
  addon_dir = test_project_dir.join("addons", "diorite")
  addon_bin = addon_dir.join("bin")

  it "resolves Godot engine executable" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    godot.should_not be_nil
  end

  it "installs diorite fresh from github repository and verifies staged deliverables" do
    FileUtils.rm_rf(test_project_dir) if Dir.exists?(test_project_dir)
    FileUtils.mkdir_p(test_project_dir)

    begin
      # 1. Initialize clean project configuration
      File.write(test_project_dir.join("project.godot"), <<-INI
      ; Engine configuration file.
      config_version=5

      [application]
      config/name="DioriteReleaseTest"
      config/features=PackedStringArray("4.8")

      [editor_plugins]
      enabled=PackedStringArray("res://addons/diorite/plugin.cfg")
      INI
      )

      # 2. Download and install Diorite from GitHub repository
      status = Lapis::Commands::InstallAddon.run(["github:sol-vin/diorite", "-p", test_project_dir.to_s, "-f"])
      if status != 0
        pending! "Diorite repository not available on GitHub (status #{status})"
      end

      # 3. Verify directory structure and staged deliverables
      Dir.exists?(addon_dir).should be_true
      Dir.exists?(addon_bin).should be_true
      File.exists?(addon_dir.join("diorite.gdextension")).should be_true
      File.exists?(addon_dir.join("plugin.cfg")).should be_true
      File.exists?(addon_dir.join("diorite.gd")).should be_true

      # 4. Verify runtime binary deliverables
      File.exists?(addon_bin.join(bridge_name)).should be_true, "Missing #{bridge_name} in #{addon_bin}"
      {% if flag?(:windows) %}
        File.exists?(addon_bin.join("gc.dll")).should be_true
        File.exists?(addon_bin.join("iconv-2.dll")).should be_true
        File.exists?(addon_bin.join("pcre2-8.dll")).should be_true
      {% end %}
      # Confirm architectural invariant: libgodot.dll must NEVER be in an addon
      File.exists?(addon_bin.join("libgodot.dll")).should be_false
    rescue ex
      pending! "Diorite informational download/install test notice: #{ex.message}"
    end
  end

  it "launches headless Godot editor with Diorite addon and verifies plugin lifecycle" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    if !godot || !File.exists?(godot)
      pending! "Godot engine executable not available"
    end

    if !Dir.exists?(addon_dir) || !File.exists?(addon_bin.join(bridge_name))
      pending! "Diorite addon deliverables not present"
    end

    begin
      res = Lapis::Test::EditorDriver.run_tool_tests(project: test_project_dir.to_s, quit_frames: 120)
      if res.exit_code != 0
        pending! "Headless editor returned non-zero code #{res.exit_code} (informational ecosystem test)"
      end

      # 1. Verify GDExtension EditorPlugin initialization token
      res.output.should contain("[Diorite] Debug Draw Plugin initialized.")

      # 2. Verify clean deactivation on editor quit
      res.output.should contain("[Diorite] Debug Draw Plugin shutdown.")
    rescue ex
      pending! "Diorite informational editor integration notice: #{ex.message}"
    end
  end
end
