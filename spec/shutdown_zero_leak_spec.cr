require "./spec_helper"
require "../src/libgodot/editor/toolchain"

describe "Shutdown Zero-Leak Verification (--verbose --quit)" do
  ext = {% if flag?(:windows) %}
          "dll"
        {% elsif flag?(:darwin) %}
          "dylib"
        {% else %}
          "so"
        {% end %}

  it "exits examples/basic_demo cleanly under --headless --verbose --quit with zero ObjectDB, Resource, RID, or StringName leaks" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    next unless godot && File.exists?(godot)
    next unless File.exists?("examples/basic_demo/bin/crystal_bridge.#{ext}") && File.exists?("examples/basic_demo/bin/game.#{ext}")

    out_io = IO::Memory.new
    err_io = IO::Memory.new
    status = Process.run(
      godot,
      ["--headless", "--verbose", "--quit", "--path", "examples/basic_demo"],
      output: out_io,
      error: err_io
    )

    combined = "#{out_io}\n#{err_io}"
    status.exit_code.should eq(0), "Godot crashed or exited non-zero (#{status.exit_code}):\n#{combined}"
    combined.includes?("ObjectDB instances were leaked at exit").should be_false, "Leaked ObjectDB instances:\n#{combined}"
    combined.includes?("resources still in use at exit").should be_false, "Leaked resources at exit:\n#{combined}"
    combined.includes?("were leaked at exit").should be_false, "Leaked server RIDs at exit:\n#{combined}"
    combined.includes?("RIDs of type").should be_false, "Leaked RenderingDevice/Server RIDs:\n#{combined}"
    combined.includes?("Unreferenced static string to 0").should be_false, "StringName static string underflow:\n#{combined}"
  end

  it "exits template cleanly under --headless --verbose --quit with zero ObjectDB, Resource, RID, or StringName leaks" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    next unless godot && File.exists?(godot)
    next unless File.exists?("template/bin/crystal_bridge.#{ext}") && File.exists?("template/bin/game.#{ext}")

    out_io = IO::Memory.new
    err_io = IO::Memory.new
    status = Process.run(
      godot,
      ["--headless", "--verbose", "--quit", "--path", "template"],
      output: out_io,
      error: err_io
    )

    combined = "#{out_io}\n#{err_io}"
    status.exit_code.should eq(0), "Godot crashed or exited non-zero (#{status.exit_code}):\n#{combined}"
    combined.includes?("ObjectDB instances were leaked at exit").should be_false, "Leaked ObjectDB instances:\n#{combined}"
    combined.includes?("resources still in use at exit").should be_false, "Leaked resources at exit:\n#{combined}"
    combined.includes?("were leaked at exit").should be_false, "Leaked server RIDs at exit:\n#{combined}"
    combined.includes?("RIDs of type").should be_false, "Leaked RenderingDevice/Server RIDs:\n#{combined}"
    combined.includes?("Unreferenced static string to 0").should be_false, "StringName static string underflow:\n#{combined}"
  end

  it "exits the root LibGodot 40+ suite test runner cleanly under GODOT_TEST_AUTORUN=1 --headless --verbose with zero leaks" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    next unless godot && File.exists?(godot)
    next unless File.exists?("bin/crystal_bridge.#{ext}") && File.exists?("bin/game.#{ext}")

    out_io = IO::Memory.new
    err_io = IO::Memory.new
    env = ENV.to_h
    env["GODOT_TEST_AUTORUN"] = "1"
    status = Process.run(
      godot,
      ["--headless", "--verbose", "--path", "."],
      env: env,
      output: out_io,
      error: err_io
    )

    combined = "#{out_io}\n#{err_io}"
    status.exit_code.should eq(0), "Godot test runner crashed or exited non-zero (#{status.exit_code}):\n#{combined}"
    combined.includes?("ObjectDB instances were leaked at exit").should be_false, "Leaked ObjectDB instances:\n#{combined}"
    combined.includes?("resources still in use at exit").should be_false, "Leaked resources at exit:\n#{combined}"
    combined.includes?("were leaked at exit").should be_false, "Leaked server RIDs at exit:\n#{combined}"
    combined.includes?("RIDs of type").should be_false, "Leaked RenderingDevice/Server RIDs:\n#{combined}"
    combined.includes?("Unreferenced static string to 0").should be_false, "StringName static string underflow:\n#{combined}"
  end
end
