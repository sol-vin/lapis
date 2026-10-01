require "./spec_helper"

describe Lapis::Test::EditorDriver do
  ext = {% if flag?(:windows) %}
          "dll"
        {% elsif flag?(:darwin) %}
          "dylib"
        {% else %}
          "so"
        {% end %}

  it "resolves the Godot executable on the system or workspace" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    godot.should_not be_nil
  end

  it "executes headless in-editor tool tests via EditorDriver" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    next unless godot && File.exists?(godot)
    next unless File.exists?("bin/crystal_bridge.#{ext}") && File.exists?("bin/game.#{ext}")

    res = Lapis::Test::EditorDriver.run_tool_tests(project: ".", quit_frames: 300)
    res.passed?.should be_true, "In-editor tool tests failed (exit #{res.exit_code}):\n#{res.output}"
  end

  it "executes headless runtime test suites via EditorDriver" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    next unless godot && File.exists?(godot)
    next unless File.exists?("bin/crystal_bridge.#{ext}") && File.exists?("bin/game.#{ext}")

    res = Lapis::Test::EditorDriver.run_runtime_tests(project: ".", category: "Core", quit_frames: 600)
    res.passed?.should be_true, "Runtime tests failed (exit #{res.exit_code}):\n#{res.output}"
  end

  it "executes live GDExtension reload tests via EditorDriver" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    next unless godot && File.exists?(godot)
    next unless File.exists?("bin/crystal_bridge.#{ext}") && File.exists?("bin/game.#{ext}")

    res = Lapis::Test::EditorDriver.run_editor_reload_tests(project: ".", cycles: 1)
    res.passed?.should be_true, "Editor reload tests failed (exit #{res.exit_code}):\n#{res.output}"
  end

  it "executes fresh editor open tests cleanly" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    next unless godot && File.exists?(godot)
    next unless File.exists?("bin/crystal_bridge.#{ext}") && File.exists?("bin/game.#{ext}")

    res = Lapis::Test::EditorDriver.run_fresh_editor_test(project: ".", quit_frames: 60)
    res.passed?.should be_true, "Fresh editor open test failed (exit #{res.exit_code}):\n#{res.output}"
  end

  it "scaffolds a fresh standalone project correctly" do
    temp_dir = File.join(Dir.tempdir, "lapis_spec_proj_#{Time.utc.to_unix_ms}")
    begin
      res = Lapis::Test::EditorDriver.test_project_scaffold(temp_dir, "MyDemoGame")
      res.passed?.should be_true
      File.exists?(File.join(temp_dir, "MyDemoGame", "project.godot")).should be_true
      File.exists?(File.join(temp_dir, "MyDemoGame", "shard.yml")).should be_true
      File.exists?(File.join(temp_dir, "MyDemoGame", "src", "main.cr")).should be_true
    ensure
      FileUtils.rm_rf(temp_dir) if Dir.exists?(temp_dir)
    end
  end

  it "scaffolds an addon with dependencies correctly" do
    temp_dir = File.join(Dir.tempdir, "lapis_spec_addon_#{Time.utc.to_unix_ms}")
    begin
      res = Lapis::Test::EditorDriver.test_addon_scaffold(
        temp_dir,
        "custom_audio",
        dependencies: ["github:sol-vin/crshader", "dummy_inventory"]
      )
      res.passed?.should be_true
      cfg_file = File.join(temp_dir, "addons", "custom_audio", "plugin.cfg")
      File.exists?(cfg_file).should be_true
      content = File.read(cfg_file)
      content.includes?("dependencies = [\"github:sol-vin/crshader\", \"dummy_inventory\"]").should be_true
    ensure
      FileUtils.rm_rf(temp_dir) if Dir.exists?(temp_dir)
    end
  end
end
