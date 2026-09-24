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

    res = Lapis::Test::EditorDriver.run_tool_tests(project: ".", quit_frames: 40)
    res.passed?.should be_true
  end

  it "executes headless runtime test suites via EditorDriver" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    next unless godot && File.exists?(godot)
    next unless File.exists?("bin/crystal_bridge.#{ext}") && File.exists?("bin/game.#{ext}")

    res = Lapis::Test::EditorDriver.run_runtime_tests(project: ".", category: "Core", quit_frames: 60)
    res.passed?.should be_true
  end
end
