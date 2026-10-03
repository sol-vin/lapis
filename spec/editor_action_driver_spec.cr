require "./spec_helper"
require "../src/libgodot/editor/action_driver"
require "../src/libgodot/editor/action_driver_vision"
require "../src/libgodot/editor/action_driver_ipc"

describe Lapis::Editor::ActionDriver do
  it "initializes with mock or base control" do
    base = Godot.create(Godot::Control)
    driver = Lapis::Editor::ActionDriver.new(base)
    driver.base_control.should_not be_nil
    base.destroy
  end

  it "locates controls by class, text, and selector" do
    root = Godot.create(Godot::VBoxContainer)
    btn1 = Godot.create(Godot::Button)
    btn1.name = "Build Crystal"
    root.add_child(btn1)

    btn2 = Godot.create(Godot::Button)
    btn2.name = "BuildButton"
    root.add_child(btn2)

    le = Godot.create(Godot::LineEdit)
    le.name = "SearchFilter"
    root.add_child(le)

    driver = Lapis::Editor::ActionDriver.new(root)

    # By text or name
    driver.find_button("Build Crystal", root).should_not be_nil
    driver.find_button("BuildButton", root).should_not be_nil
    driver.find_line_edit("SearchFilter", root).should_not be_nil

    # By selector
    driver.find_control("Button[text='Build Crystal']", root).should_not be_nil
    driver.find_control("#SearchFilter", root).should_not be_nil

    root.destroy
  end

  it "synthesizes click, type, and tab selection cleanly" do
    root = Godot.create(Godot::VBoxContainer)
    btn = Godot.create(Godot::Button)
    btn.name = "TestBtn"
    root.add_child(btn)

    clicked = false
    btn.connect("pressed") do
      clicked = true
    end

    driver = Lapis::Editor::ActionDriver.new(root)
    driver.click(btn)
    clicked.should be_true

    le = Godot.create(Godot::LineEdit)
    root.add_child(le)
    typed_text = ""
    le.connect("text_changed") do |args|
      typed_text = args[0]?.try(&.to_s) || ""
    end
    driver.type_text(le, "PlayerNode")
    typed_text.should eq("PlayerNode")

    root.destroy
  end

  it "dumps DOM tree hierarchy to indented text" do
    root = Godot.create(Godot::VBoxContainer)
    root.name = "RootContainer"
    btn = Godot.create(Godot::Button)
    btn.name = "ActionBtn"
    root.add_child(btn)

    driver = Lapis::Editor::ActionDriver.new(root)
    dom = driver.dump_dom(root, max_depth: 3)
    dom.should contain("RootContainer")
    dom.should contain("ActionBtn")

    root.destroy
  end

  it "locates Crystal Build button and Crystal Panel via dedicated helper methods" do
    root = Godot.create(Godot::VBoxContainer)
    root.name = "EditorBase"

    # Initially neither exists
    driver = Lapis::Editor::ActionDriver.new(root)
    driver.has_crystal_build_button?.should be_false
    driver.has_crystal_panel?.should be_false

    # Add Build button
    build_btn = Godot.create(Godot::Button)
    build_btn.name = "BuildCrystalToolbarButton"
    build_btn.set_text("Build")
    build_btn.set_tooltip_text("Build Crystal (Quick Recompile)")
    root.add_child(build_btn)

    # Add Crystal panel
    panel = Godot.create(Godot::Panel)
    panel.name = "CrystalPanel"
    root.add_child(panel)

    driver.has_crystal_build_button?.should be_true
    driver.find_crystal_build_button.should_not be_nil
    driver.find_crystal_build_button.not_nil!.name.should eq("BuildCrystalToolbarButton")

    driver.has_crystal_panel?.should be_true
    driver.find_crystal_panel.should_not be_nil
    driver.find_crystal_panel.not_nil!.name.should eq("CrystalPanel")

    # Click helper
    clicked = false
    build_btn.connect("pressed") do
      clicked = true
    end
    driver.click_crystal_build_button.should be_true
    clicked.should be_true

    root.destroy
  end

  it "runs DriverServer and responds to ping, status, and extended commands" do
    server = Lapis::Editor::DriverServer.new(port: 9096)
    server.start
    server.running?.should be_true

    begin
      client = ::TCPSocket.new("127.0.0.1", 9096, connect_timeout: 2.seconds)

      # 1. Ping
      client.puts({"action" => "ping"}.to_json)
      client.flush
      res = client.gets
      res.should_not be_nil
      json = ::JSON.parse(res.not_nil!)
      json["status"].as_s.should eq("ok")
      json["pong"].as_bool.should be_true

      # 2. Status
      client.puts({"action" => "status"}.to_json)
      client.flush
      res2 = client.gets
      res2.should_not be_nil
      json2 = ::JSON.parse(res2.not_nil!)
      json2["status"].as_s.should eq("ok")
      json2["pid"].as_i64.should eq(Process.pid)

      # 3. Find non-existent control
      client.puts({"action" => "find", "selector" => "NonExistentWidget"}.to_json)
      client.flush
      res3 = client.gets
      res3.should_not be_nil
      json3 = ::JSON.parse(res3.not_nil!)
      json3["status"].as_s.should eq("ok")
      json3["found"].as_bool.should be_false

      # 4. Open script without editor interface
      client.puts({"action" => "open_script", "path" => "scripts/patch_docs.cr", "line" => 1, "col" => 0}.to_json)
      client.flush
      res4 = client.gets
      res4.should_not be_nil
      json4 = ::JSON.parse(res4.not_nil!)
      (json4["status"].as_s == "ok" || json4["status"].as_s == "error").should be_true

      # 5. Current script without editor interface
      client.puts({"action" => "current_script"}.to_json)
      client.flush
      res5 = client.gets
      res5.should_not be_nil
      json5 = ::JSON.parse(res5.not_nil!)
      json5["status"].as_s.should eq("ok")

      # 6. Open scripts without editor interface
      client.puts({"action" => "open_scripts"}.to_json)
      client.flush
      res6 = client.gets
      res6.should_not be_nil
      json6 = ::JSON.parse(res6.not_nil!)
      json6["status"].as_s.should eq("ok")
      json6["scripts"].as_a.should be_empty

      client.close
    ensure
      server.stop
      server.running?.should be_false
    end
  end
end
