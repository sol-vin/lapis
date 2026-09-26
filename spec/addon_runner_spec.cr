require "./spec_helper"

describe "Addon & Plugin Multi-Target Verification" do
  ext = {% if flag?(:windows) %}
          "dll"
        {% elsif flag?(:darwin) %}
          "dylib"
        {% else %}
          "so"
        {% end %}

  it "resolves Godot engine executable" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    godot.should_not be_nil
  end

  it "verifies template-addon requires zero .tscn files for test execution" do
    # Guarantee the user invariant: no scenes/test_runner.tscn or scenes/ directory needed
    scene_runner = File.join("template-addon", "scenes", "test_runner.tscn")
    File.exists?(scene_runner).should be_false
  end

  it "executes pure-Crystal in-editor test runner and verifies addon activation" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    next unless godot && File.exists?(godot)

    addon_dir = "template-addon"
    next unless Dir.exists?(addon_dir)

    addon_bridge = File.join(addon_dir, "addons", "crystal_addon", "bin", "crystal_bridge.#{ext}")
    addon_game = File.join(addon_dir, "addons", "crystal_addon", "bin", "game.#{ext}")
    next unless File.exists?(addon_bridge) && File.exists?(addon_game)

    res = Lapis::Test::EditorDriver.run_tool_tests(project: addon_dir, quit_frames: 300)
    res.passed?.should be_true, "Addon in-editor tool tests failed (exit #{res.exit_code}):\n#{res.output}"

    # Verify custom addon plugin entered editor tree and emitted its unique verification token
    res.output.should contain("[CRYSTAL_ADDON_VERIFIED_SUCCESS_8A3F1E]")

    # Verify pure-Crystal runner executed in-editor Lapis::Test::Registry suites
    res.output.should contain("[CrystalToolTester]")
    res.output.should contain("[PASS] ALL IN-EDITOR TESTS PASSED CLEANLY!")

    # Verify dynamic ClassDB inspection of custom addon nodes in memory
    res.output.should contain("CrystalAddonBanner")
    res.output.should contain("CrystalAddonPlugin")
  end
end
