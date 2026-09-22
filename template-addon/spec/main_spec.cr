require "spec"
require "../src/main"

describe CrystalAddonBanner do
  it "registers with Godot ClassRegistry as Control" do
    entry = Godot::ClassRegistry.find("CrystalAddonBanner")
    entry.should_not be_nil
    entry.not_nil!.parent_name.should eq("Control")
  end

  it "declares exported properties" do
    entry = Godot::ClassRegistry.find("CrystalAddonBanner")
    props = entry.not_nil!.properties.map(&.name)
    props.should contain("message")
    props.should contain("text_color")
  end
end

describe CrystalAddonPlugin do
  it "registers with Godot ClassRegistry as EditorPlugin" do
    entry = Godot::ClassRegistry.find("CrystalAddonPlugin")
    entry.should_not be_nil
    entry.not_nil!.parent_name.should eq("EditorPlugin")
  end

  it "is marked as tool node for editor execution" do
    entry = Godot::ClassRegistry.find("CrystalAddonPlugin")
    entry.should_not be_nil
    entry.not_nil!.is_tool.should be_true
  end
end
