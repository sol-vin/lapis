require "./spec_helper"

class ScenePipelineTarget < Godot::Node
  property health : Int32 = 100
  property speed : Float32 = 5.0_f32
  property tag : String = ""
end

class ScenePipelineChild < Godot::Node
  property power : Int32 = 42
end

describe "Scene Pipeline and Ergonomics" do
  it "preserves concrete static type T on add_child" do
    parent = Godot::Node.new
    target = ScenePipelineTarget.new

    # Static type check: returned child is ScenePipelineTarget, not Godot::Node
    added = parent.add_child(target)
    added.should be_a(ScenePipelineTarget)
    added.health.should eq(100)
    typeof(added).should eq(ScenePipelineTarget)
  end

  it "configures child inline in add_child block and returns concrete static type" do
    parent = Godot::Node.new
    target = ScenePipelineTarget.new

    added = parent.add_child(target) do |child|
      child.health = 250
      child.tag = "elite"
    end

    added.health.should eq(250)
    added.tag.should eq("elite")
    typeof(added).should eq(ScenePipelineTarget)
  end

  it "preserves concrete static type T on add_sibling" do
    parent = Godot::Node.new
    sibling1 = ScenePipelineTarget.new
    sibling2 = ScenePipelineChild.new

    parent.add_child(sibling1)
    added = sibling1.add_sibling(sibling2) do |s|
      s.power = 99
    end

    added.should be_a(ScenePipelineChild)
    added.power.should eq(99)
    typeof(added).should eq(ScenePipelineChild)
  end

  it "supports fluent inline configuration via Object#build and Object#configure" do
    node = ScenePipelineTarget.new.build do |n|
      n.health = 500
      n.speed = 15.0_f32
      n.tag = "boss"
    end

    node.health.should eq(500)
    node.speed.should eq(15.0_f32)
    node.tag.should eq("boss")
    typeof(node).should eq(ScenePipelineTarget)

    node.configure do |n|
      n.health = 600
    end
    node.health.should eq(600)
  end
end
