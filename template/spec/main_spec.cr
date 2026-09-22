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
    props.should contain("say_text")
  end

  it "declares custom signals" do
    entry = Godot::ClassRegistry.find("MainNode")
    sigs = entry.not_nil!.signals.map(&.name)
    sigs.should contain("initialized")
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
  end
end
