require "./spec_helper"

node UnifiedSpecTestNode < Godot::Node do
  property process_count : Int32 = 0
  property physics_count : Int32 = 0

  signal health_changed(amount : Int32)
  signal triggered

  def _process(delta : Float64) : Void
    @process_count += 1
  end

  def _physics_process(delta : Float64) : Void
    @physics_count += 1
  end
end

describe "LibGodot Crystal Spec & Testing Apparatus Unification" do
  describe "Custom Spec Matchers" do
    it "matches be_alive and be_freed lifecycle expectations" do
      node = SpecPlayer.new
      node.should be_alive

      # Disposed object
      node.destroy
      node.should be_freed
      node.should be_disposed
    end

    it "matches have_method and have_signal expectations" do
      node = autofree(UnifiedSpecTestNode.new)
      node.should have_method("_process")
      node.should have_method("_physics_process")
      node.should have_signal("health_changed")
      node.should have_signal("triggered")
    end

    it "matches be_between numeric expectation" do
      val = 42
      val.should be_between(10, 50)
      val.should be_between(42, 42)
    end
  end

  describe "Extended Assertions inside it blocks" do
    it "supports extended comparison assertions" do
      assert_eq 10, 10
      assert_ne 10, 20
      assert_gt 50, 20
      assert_gte 50, 50
      assert_lt 10, 20
      assert_lte 20, 20
      assert_between 25, 20, 30
      assert_not_between 5, 20, 30
    end

    it "supports string assertions" do
      assert_string_contains "LibGodot Framework", "Godot"
      assert_string_starts_with "LibGodot Framework", "Lib"
      assert_string_ends_with "LibGodot Framework", "Framework"
    end

    it "supports collection assertions" do
      empty_list = [] of Int32
      full_list = [1, 2, 3]

      assert_empty empty_list
      assert_not_empty full_list
    end

    it "supports identity and type assertions" do
      node1 = autofree(UnifiedSpecTestNode.new)
      node2 = autofree(UnifiedSpecTestNode.new)

      assert_same node1, node1
      assert_not_same node1, node2
      assert_is_a node1, UnifiedSpecTestNode
      assert_is_a node1, Godot::Node
    end
  end

  describe "Deterministic Simulation (simulate)" do
    it "steps process frames deterministically" do
      node = autofree(UnifiedSpecTestNode.new)
      node.process_count.should eq(0)

      simulate(node, frames: 5, delta: 0.016)
      node.process_count.should eq(5)
    end

    it "steps physics process frames deterministically" do
      node = autofree(UnifiedSpecTestNode.new)
      node.physics_count.should eq(0)

      simulate(node, frames: 3, delta: 0.016, physics: true)
      node.physics_count.should eq(3)
    end
  end

  describe "Auto-free Lifecycle Tracking" do
    it "safely tracks and destroys nodes registered via autofree" do
      child = autofree(UnifiedSpecTestNode.new)
      child.should be_alive
      # Will be cleaned up automatically in Spec.after_each
    end
  end
end
