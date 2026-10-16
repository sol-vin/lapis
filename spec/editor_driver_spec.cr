require "./spec_helper"
require "../src/libgodot/editor/toolchain"
require "../src/libgodot/editor/async_command_runner"
require "../src/editor/benchmark_graph_control"

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

  it "executes headless in-editor ActionDriver tests via EditorDriver" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    next unless godot && File.exists?(godot)
    next unless File.exists?("bin/crystal_bridge.#{ext}") && File.exists?("bin/game.#{ext}")

    res = Lapis::Test::EditorDriver.run_editor_action_driver_tests(project: ".", quit_frames: 400)
    res.passed?.should be_true, "In-editor ActionDriver tests failed (exit #{res.exit_code}):\n#{res.output}"
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

  it "verifies Lapis::Toolchain argument builders and resolution" do
    b_args = Lapis::Toolchain.build_game_args("src/main.cr", "bin/game.dll", "/DLL", is_release: true)
    b_args.should eq(["build", "--entry", "src/main.cr", "--output", "bin/game.dll", "--link-flags", "/DLL", "--release"])

    bench_args = Lapis::Toolchain.benchmarks_args(iterations: 5, group_name: "Compute", all_languages: true)
    bench_args.should eq(["benchmarks", "run", "html", "-i", "5", "--no-tui", "-g", "Compute", "--all-languages"])

    doc_args = Lapis::Toolchain.doctor_args(autofix: true)
    doc_args.should eq(["doctor", "autofix"])
  end

  it "executes non-blocking commands via AsyncCommandRunner" do
    runner = Lapis::AsyncCommandRunner.instance
    runner.running?.should be_false

    lines = [] of String
    finished = false
    exit_val = -1

    started = runner.run(
      name: "Spec Test Command",
      command: "crystal",
      args: ["--version"],
      on_line: ->(l : String) {
        lines << l
        nil
      }
    ) do |code, _elapsed, _out|
      exit_val = code
      finished = true
    end

    started.should be_true

    # Wait up to 5 seconds for background thread, polling regularly
    timeout = Time.instant + 5.seconds
    while !finished && Time.instant < timeout
      runner.poll
      Fiber.yield
      sleep 10.milliseconds
    end

    runner.poll
    finished.should be_true
    exit_val.should eq(0)
    lines.empty?.should be_false
    lines.first.includes?("Crystal").should be_true
    runner.running?.should be_false
  end

  it "creates BenchmarkComparisonItem with multi-language metrics" do
    item = Lapis::BenchmarkComparisonItem.new(
      name: "Matmul",
      crystal_ms: 1.25,
      gdscript_ms: 45.0,
      cpp_ms: 1.15,
      rust_ms: 1.20,
      speedup: 36.0,
      details: "Compute group"
    )
    item.name.should eq("Matmul")
    item.crystal_ms.should eq(1.25)
    item.gdscript_ms.should eq(45.0)
    item.cpp_ms.should eq(1.15)
    item.rust_ms.should eq(1.20)
    item.speedup.should eq(36.0)
  end

  it "ActionDriver implements console dock inspection methods" do
    driver = Lapis::Editor::ActionDriver.new
    driver.has_crystal_console_dock?.should be_false # Headless runner outside Godot main loop
    driver.find_crystal_console_dock.should be_nil
  end
end
