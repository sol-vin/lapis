require "./spec_helper"

describe "Godot Editor Live Reload & Inspector Node Selection" do
  ext = {% if flag?(:windows) %}
          "dll"
        {% elsif flag?(:darwin) %}
          "dylib"
        {% else %}
          "so"
        {% end %}

  it "preserves ClassDB metadata across live reloads without crashing on node inspection" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    next unless godot && File.exists?(godot)
    next unless File.exists?("bin/crystal_bridge.#{ext}") && File.exists?("bin/game.#{ext}")

    res = Lapis::Test::EditorDriver.run_editor_reload_tests(project: ".", cycles: 2)
    res.passed?.should be_true, "Editor reload test failed (exit #{res.exit_code}):\n#{res.output}"
    res.output.should contain("SUCCESS: Completed all 2 reload cycles!")
    res.output.should contain("SUCCESS: edit_node on edited_root completed cleanly!")
  end

  it "cycles node selection in editor inspector without ClassDB lookup null pointer faults" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    next unless godot && File.exists?(godot)
    next unless File.exists?("bin/crystal_bridge.#{ext}") && File.exists?("bin/game.#{ext}")

    res = Lapis::Test::EditorDriver.run_editor_reload_tests(project: ".", cycles: 1)
    res.passed?.should be_true, "Editor reload test failed (exit #{res.exit_code}):\n#{res.output}"
    res.output.should contain("SUCCESS: Completed all 1 reload cycles!")
    res.output.should contain("SUCCESS: edit_node on edited_root completed cleanly!")
  end
end
