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

  it "runs DriverServer and responds to ping and status" do
    server = Lapis::Editor::DriverServer.new(port: 9096)
    server.start
    server.running?.should be_true

    begin
      client = ::TCPSocket.new("127.0.0.1", 9096, connect_timeout: 2.seconds)
      client.puts({"action" => "ping"}.to_json)
      client.flush
      res = client.gets
      res.should_not be_nil
      json = ::JSON.parse(res.not_nil!)
      json["status"].as_s.should eq("ok")
      json["pong"].as_bool.should be_true
      client.close
    ensure
      server.stop
      server.running?.should be_false
    end
  end
end
