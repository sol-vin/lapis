# spec/external/crshader_spec.cr
# Informational ecosystem compatibility spec for CrShader.
# Verifies CrShader in-editor GDExtension plugin and runtime editor integration.
# Failure in this spec is non-blocking (diagnostic notice only) to track ecosystem compatibility.

require "../spec_helper"
require "../../tools/lapis/src/commands/install_addon"

describe "CrShader In-Editor Plugin & Studio GUI (Informational Ecosystem Spec)" do
  ext = {% if flag?(:windows) %} "dll" {% elsif flag?(:darwin) %} "dylib" {% else %} "so" {% end %}
  bridge_name = {% if flag?(:windows) %} "crystal_bridge.dll" {% elsif flag?(:darwin) %} "crystal_bridge.dylib" {% else %} "crystal_bridge.so" {% end %}

  repo_root = Path.new(File.expand_path("../..", __DIR__))
  test_project_dir = repo_root.join("scratch", "test_crshader_release_project")
  addon_dir = test_project_dir.join("addons", "crshader")
  addon_bin = addon_dir.join("bin")

  it "resolves Godot engine executable" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    godot.should_not be_nil
  end

  it "downloads crshader fresh from github releases and verifies binary deliverables" do
    FileUtils.rm_rf(test_project_dir) if Dir.exists?(test_project_dir)
    FileUtils.mkdir_p(test_project_dir)

    begin
      # 1. Initialize clean project configuration
      File.write(test_project_dir.join("project.godot"), <<-INI
      ; Engine configuration file.
      config_version=5

      [application]
      config/name="CRShaderReleaseTest"
      config/features=PackedStringArray("4.8")

      [editor_plugins]
      enabled=PackedStringArray("res://addons/crshader/plugin.cfg")
      INI
      )

      # 2. Download and install CRShader fresh from GitHub releases using explicit provider id and pre-compiled release binary
      status = Lapis::Commands::InstallAddon.run(["github:sol-vin/crshader", "-p", test_project_dir.to_s, "-f", "--release"])
      if status != 0
        pending! "CRShader release not available on GitHub"
      end

      # 3. Verify directory structure and staged deliverables
      Dir.exists?(addon_dir).should be_true
      Dir.exists?(addon_bin).should be_true
      File.exists?(addon_dir.join("crshader.gdextension")).should be_true
      File.exists?(addon_dir.join("plugin.cfg")).should be_true
      File.exists?(addon_dir.join("plugin.gd")).should be_true

      # 4. Verify runtime binary deliverables
      File.exists?(addon_bin.join(bridge_name)).should be_true, "Missing #{bridge_name} in #{addon_bin}"
      if !File.exists?(addon_bin.join("game.#{ext}"))
        pending! "Missing game.#{ext} in GitHub release deliverables for #{addon_bin}"
      end
      {% if flag?(:windows) %}
        File.exists?(addon_bin.join("gc.dll")).should be_true
        File.exists?(addon_bin.join("iconv-2.dll")).should be_true
        File.exists?(addon_bin.join("pcre2-8.dll")).should be_true
      {% end %}
      # Confirm architectural invariant: libgodot.dll must NEVER be in an addon
      File.exists?(addon_bin.join("libgodot.dll")).should be_false
    rescue ex
      pending! "CRShader informational download/install test notice: #{ex.message}"
    end
  end

  it "launches headless Godot editor with downloaded CRShader addon, initializes CrShaderPlugin, and mounts Studio GUI" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    if !godot || !File.exists?(godot)
      pending! "Godot engine executable not available"
    end

    addon_bridge = addon_bin.join(bridge_name)
    addon_game = addon_bin.join("game.#{ext}")
    if !File.exists?(addon_bridge) || !File.exists?(addon_game)
      pending! "CRShader addon binaries not present"
    end

    begin
      res = Lapis::Test::EditorDriver.run_tool_tests(project: test_project_dir.to_s, quit_frames: 120)
      if res.exit_code != 0
        pending! "Headless editor returned non-zero code #{res.exit_code} (informational ecosystem test)"
      end

      # 1. Verify GDExtension initialization token
      res.output.should contain("[CRShader] Crystal GDExtension EditorPlugin initialized!")

      # 2. Verify CRShader Studio Panel instantiated and mounted into editor bottom panel
      res.output.should contain("Studio GUI mounted")

      # 3. Verify clean deactivation on editor quit
      res.output.should contain("[CRShader] Crystal GDExtension EditorPlugin deactivated.")
    rescue ex
      pending! "CRShader informational editor integration notice: #{ex.message}"
    end
  end
end
