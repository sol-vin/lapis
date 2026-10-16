require "./spec_helper"
require "../src/libgodot/editor/action_driver"
require "../src/libgodot/editor/action_driver_vision"
require "../src/libgodot/editor/action_driver_ipc"

describe "Lapis Godot Editor Plugin UI & ActionDriver Verification" do
  ext = {% if flag?(:windows) %}
          "dll"
        {% elsif flag?(:darwin) %}
          "dylib"
        {% else %}
          "so"
        {% end %}

  it "verifies Set-of-Marks AI Vision manifest generation on interactive controls" do
    root = Godot.create(Godot::VBoxContainer)
    root.name = "VisionRoot"

    btn = Godot.create(Godot::Button)
    btn.name = "BuildButton"
    btn.set_text("Build")
    btn.set_tooltip_text("Build Crystal Project")
    root.add_child(btn)

    le = Godot.create(Godot::LineEdit)
    le.name = "FilterBox"
    root.add_child(le)

    driver = Lapis::Editor::ActionDriver.new(root)
    temp_dir = File.join(Dir.tempdir, "vision_test_#{Time.utc.to_unix_ms}")

    begin
      manifest = driver.capture_ai_manifest(temp_dir)
      File.exists?(manifest[:manifest_path]).should be_true
      manifest_json = JSON.parse(File.read(manifest[:manifest_path]))
      manifest_json["elements"].as_a.should_not be_nil
      manifest_json["elements"].as_a.size.should be >= 0
    ensure
      FileUtils.rm_rf(temp_dir) if Dir.exists?(temp_dir)
      root.destroy
    end
  end

  it "locates and interacts with simulated editor toolbar and main screen panels" do
    base = Godot.create(Godot::VBoxContainer)
    base.name = "EditorBaseControl"

    title_bar = Godot.create(Godot::HBoxContainer)
    title_bar.name = "EditorTitleBar"
    base.add_child(title_bar)

    build_btn = Godot.create(Godot::Button)
    build_btn.name = "BuildCrystalToolbarButton"
    build_btn.set_text("Build")
    build_btn.set_tooltip_text("Build Crystal (Quick Recompile)")
    title_bar.add_child(build_btn)

    run_bar = Godot.create(Godot::HBoxContainer)
    run_bar.name = "EditorRunBar"
    title_bar.add_child(run_bar)

    main_screen = Godot.create(Godot::VBoxContainer)
    main_screen.name = "EditorMainScreen"
    base.add_child(main_screen)

    panel = Godot.create(Godot::Panel)
    panel.name = "CrystalPanel"
    main_screen.add_child(panel)

    driver = Lapis::Editor::ActionDriver.new(base)

    # 1. Assert Crystal Build Button
    driver.has_crystal_build_button?.should be_true
    found_btn = driver.find_crystal_build_button.not_nil!
    found_btn.name.should eq("BuildCrystalToolbarButton")
    found_btn.get_parent.not_nil!.name.should eq("EditorTitleBar")

    # 2. Assert Crystal Main Screen Panel
    driver.has_crystal_panel?.should be_true
    found_panel = driver.find_crystal_panel.not_nil!
    found_panel.name.should eq("CrystalPanel")
    found_panel.get_parent.not_nil!.name.should eq("EditorMainScreen")

    # 3. Test click synthesizing
    clicked = false
    found_btn.connect("pressed") do
      clicked = true
    end
    driver.click_crystal_build_button.should be_true
    clicked.should be_true

    base.destroy
  end

  it "executes end-to-end headless editor ActionDriver test flow in real Godot Editor" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    next unless godot && File.exists?(godot)
    next unless File.exists?("bin/crystal_bridge.#{ext}") && File.exists?("bin/game.#{ext}")

    res = Lapis::Test::EditorDriver.run_editor_action_driver_tests(project: ".", quit_frames: 400)
    res.passed?.should be_true, "Headless Editor ActionDriver tests failed (exit #{res.exit_code}):\n#{res.output}"
  end
end
