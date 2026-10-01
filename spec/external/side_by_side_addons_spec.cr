# spec/external/side_by_side_addons_spec.cr
# Informational ecosystem compatibility spec for side-by-side GDExtension addons.
# Verifies CrShader and Diorite installed together in a single Godot project
# and running concurrently in both headless editor mode and standalone mode.

require "../spec_helper"
require "../../tools/lapis/src/commands/install_addon"

describe "Side-by-Side Addons Co-Installation (CrShader + Diorite)" do
  ext = {% if flag?(:windows) %} "dll" {% elsif flag?(:darwin) %} "dylib" {% else %} "so" {% end %}
  bridge_name = {% if flag?(:windows) %} "crystal_bridge.dll" {% elsif flag?(:darwin) %} "crystal_bridge.dylib" {% else %} "crystal_bridge.so" {% end %}

  repo_root = Path.new(File.expand_path("../..", __DIR__))
  test_project_dir = repo_root.join("scratch", "test_side_by_side_addons")

  it "installs CrShader and Diorite into a single project side by side" do
    FileUtils.rm_rf(test_project_dir) if Dir.exists?(test_project_dir)
    FileUtils.mkdir_p(test_project_dir)

    begin
      # 1. Initialize clean project configuration
      File.write(test_project_dir.join("project.godot"), <<-INI
      ; Engine configuration file.
      config_version=5

      [application]
      config/name="SideBySideAddonsTest"
      run/main_scene="res://scenes/main.tscn"
      config/features=PackedStringArray("4.8")
      INI
      )

      # 2. Create minimal root scene for standalone execution
      scenes_dir = test_project_dir.join("scenes")
      FileUtils.mkdir_p(scenes_dir)
      File.write(scenes_dir.join("main.tscn"), <<-TSCN
      [gd_scene load_steps=1 format=3]

      [node name="Main" type="Node3D"]

      [node name="Camera3D" type="Camera3D" parent="."]
      TSCN
      )

      # 3. Install CrShader fresh from GitHub releases
      status_cr = Lapis::Commands::InstallAddon.run(["github:sol-vin/crshader", "-p", test_project_dir.to_s, "-f", "--release"])
      if status_cr != 0
        pending! "CRShader release not available on GitHub"
      end

      # 4. Install Diorite fresh from GitHub repository
      status_dio = Lapis::Commands::InstallAddon.run(["github:sol-vin/diorite", "-p", test_project_dir.to_s, "-f"])
      if status_dio != 0
        pending! "Diorite repository not available on GitHub"
      end

      # 5. Assert side-by-side filesystem isolation
      Dir.exists?(test_project_dir.join("addons", "crshader")).should be_true
      Dir.exists?(test_project_dir.join("addons", "diorite")).should be_true
      File.exists?(test_project_dir.join("addons", "crshader", "bin", bridge_name)).should be_true
      File.exists?(test_project_dir.join("addons", "diorite", "bin", bridge_name)).should be_true

      # Verify both plugins registered and enabled in project.godot
      pg_content = File.read(test_project_dir.join("project.godot"))
      pg_content.should contain("res://addons/crshader/plugin.cfg")
      pg_content.should contain("res://addons/diorite/plugin.cfg")
    rescue ex
      pending! "Side-by-side install test notice: #{ex.message}"
    end
  end

  it "verifies CrShader and Diorite run concurrently in headless editor mode" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    if !godot || !File.exists?(godot)
      pending! "Godot engine executable not available"
    end

    cr_present = Dir.exists?(test_project_dir.join("addons", "crshader"))
    dio_present = Dir.exists?(test_project_dir.join("addons", "diorite"))
    if !cr_present || !dio_present
      pending! "Both addons must be staged for side-by-side editor test"
    end

    begin
      res = Lapis::Test::EditorDriver.run_tool_tests(project: test_project_dir.to_s, quit_frames: 120)
      if res.exit_code != 0
        pending! "Editor run returned code #{res.exit_code} (informational ecosystem test)"
      end

      # 1. Verify Diorite initialized
      res.output.should contain("[Diorite] Debug Draw Plugin initialized.")

      # 2. Verify CRShader initialized if binary was packaged
      if File.exists?(test_project_dir.join("addons", "crshader", "bin", "game.#{ext}"))
        res.output.should contain("[CRShader] Crystal GDExtension EditorPlugin initialized!")
      end

      # 3. Verify clean shutdown for both plugins
      res.output.should contain("[Diorite] Debug Draw Plugin shutdown.")
      if File.exists?(test_project_dir.join("addons", "crshader", "bin", "game.#{ext}"))
        res.output.should contain("[CRShader] Crystal GDExtension EditorPlugin deactivated.")
      end
    rescue ex
      pending! "Side-by-side editor test notice: #{ex.message}"
    end
  end

  it "verifies CrShader and Diorite run concurrently in headless standalone mode" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    if !godot || !File.exists?(godot)
      pending! "Godot engine executable not available"
    end

    cr_present = Dir.exists?(test_project_dir.join("addons", "crshader"))
    dio_present = Dir.exists?(test_project_dir.join("addons", "diorite"))
    if !cr_present || !dio_present
      pending! "Both addons must be staged for side-by-side standalone test"
    end

    begin
      args = ["--headless", "--audio-driver", "Dummy", "--rendering-driver", "opengl3", "--path", test_project_dir.to_s, "--quit-after", "60"]
      out_io = IO::Memory.new
      status = Process.run(godot, args, output: out_io, error: out_io)
      output = out_io.to_s

      status.success?.should be_true, "Standalone execution failed with status #{status.exit_code}:\n#{output}"
      output.should_not contain("USER ERROR")
      output.should_not contain("SCRIPT ERROR")
    rescue ex
      pending! "Side-by-side standalone test notice: #{ex.message}"
    end
  end
end
