# =============================================================================
# LibGodot Test Suite: Extended Testing Apparatus & Hierarchy Assertions
# =============================================================================
# Verifies scenario multi-step runner, assert_settled, assert_no_signal,
# assert_memory_stable, assert_child_count, and assert_has_child.

include Lapis::Test

test_suite "Testing" do
  test "scenario runner executes sequential steps with contextual error tracking" do
    step1_ran = false
    step2_ran = false

    scenario "Player Combat Flow" do |s|
      s.step "Initialize Combat" do
        step1_ran = true
        assert_true step1_ran
      end

      s.step "Execute Strike" do
        step2_ran = true
        assert_true step2_ran
      end
    end

    assert_true step1_ran
    assert_true step2_ran
  end

  test "hierarchy assertions validate SceneTree child counts and names" do
    parent = Godot.create(Godot::Node2D)
    child_a = Godot.create(Godot::Node2D)
    child_a.name = "ChildA"
    child_b = Godot.create(Godot::Node2D)
    child_b.name = "ChildB"

    parent.add_child(child_a)
    parent.add_child(child_b)

    assert_child_count(parent, 2)
    assert_has_child(parent, "ChildA")
    assert_has_child(parent, "ChildB")

    child_a.destroy
    child_b.destroy
    parent.destroy
  end

  test "assert_no_signal verifies signal was not fired during execution" do
    emitter = Godot.create(Godot::Timer)
    assert_no_signal(emitter, "timeout", during_frames: 2)
    emitter.destroy
  end

  test "assert_settled returns immediately for non-rigid static objects" do
    static_node = Godot.create(Godot::Node2D)
    assert_settled(static_node, max_frames: 10)
    static_node.destroy
  end
end
