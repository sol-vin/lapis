require "spec"
require "../src/main"

describe MainNode do
  it "registers with Godot ClassRegistry" do
    entry = Godot::ClassRegistry.find("MainNode")
    entry.should_not be_nil
    entry.not_nil!.parent_name.should eq("Node3D")
  end

  it "declares exported properties" do
    entry = Godot::ClassRegistry.find("MainNode")
    props = entry.not_nil!.properties.map(&.name)
    props.should contain("welcome_message")
    props.should contain("say_text")
  end

  it "declares custom signals" do
    entry = Godot::ClassRegistry.find("MainNode")
    sigs = entry.not_nil!.signals.map(&.name)
    sigs.should contain("initialized")
  end
end

describe PlayerController do
  it "registers with Godot ClassRegistry" do
    entry = Godot::ClassRegistry.find("PlayerController")
    entry.should_not be_nil
    entry.not_nil!.parent_name.should eq("CharacterBody3D")
  end

  it "declares speed and health properties" do
    entry = Godot::ClassRegistry.find("PlayerController")
    props = entry.not_nil!.properties.map(&.name)
    props.should contain("speed")
    props.should contain("max_health")
    props.should contain("current_health")
  end

  it "declares health_changed and player_moved signals" do
    entry = Godot::ClassRegistry.find("PlayerController")
    sigs = entry.not_nil!.signals.map(&.name)
    sigs.should contain("health_changed")
    sigs.should contain("player_moved")
  end
end

describe GameHUD do
  it "registers with Godot ClassRegistry" do
    entry = Godot::ClassRegistry.find("GameHUD")
    entry.should_not be_nil
    entry.not_nil!.parent_name.should eq("Control")
  end

  it "declares title property" do
    entry = Godot::ClassRegistry.find("GameHUD")
    props = entry.not_nil!.properties.map(&.name)
    props.should contain("title")
  end
end

describe MyCrystalNode do
  it "registers with Godot ClassRegistry" do
    entry = Godot::ClassRegistry.find("MyCrystalNode")
    entry.should_not be_nil
    entry.not_nil!.parent_name.should eq("Node")
  end

  it "declares exported properties" do
    entry = Godot::ClassRegistry.find("MyCrystalNode")
    props = entry.not_nil!.properties.map(&.name)
    props.should contain("my_var")
    props.should contain("greeting")
  end
end
