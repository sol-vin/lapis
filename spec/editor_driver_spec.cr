require "./spec_helper"

describe Lapis::Test::EditorDriver do
  it "resolves the Godot executable on the system or workspace" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    godot.should_not be_nil
  end

  it "executes headless in-editor tool tests via EditorDriver" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    if godot && File.exists?(godot)
      # Ensure bridge and game DLLs exist before running driver
      if File.exists?("bin/crystal_bridge.dll") && File.exists?("bin/game.dll")
        res = Lapis::Test::EditorDriver.run_tool_tests(project: ".", quit_frames: 40)
        res.passed?.should be_true
      else
        pending "bin/crystal_bridge.dll or bin/game.dll not yet compiled; skipping live editor test"
      end
    else
      pending "Godot binary not found on host; skipping live editor test"
    end
  end

  it "executes headless runtime test suites via EditorDriver" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    if godot && File.exists?(godot)
      if File.exists?("bin/crystal_bridge.dll") && File.exists?("bin/game.dll")
        # Run a fast single category via runtime runner
        res = Lapis::Test::EditorDriver.run_runtime_tests(project: ".", category: "Core", quit_frames: 60)
        res.passed?.should be_true
      else
        pending "bin/crystal_bridge.dll or bin/game.dll not yet compiled; skipping live runtime test"
      end
    else
      pending "Godot binary not found on host; skipping live runtime test"
    end
  end
end
