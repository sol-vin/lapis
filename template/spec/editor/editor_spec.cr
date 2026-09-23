require "spec"
require "lapis"

include Lapis::Test

# =============================================================================
# Template In-Editor Test Suite (spec/editor/editor_spec.cr)
# =============================================================================
# These tests are registered into Lapis::Test::Registry and executed live
# inside the Godot Editor through the Crystal Hub dock (Unit Test Runner tab)
# without opening or switching scenes.

test_suite "Nodes" do
  test "MainNode is registered in ClassRegistry" do
    entry = Godot::ClassRegistry.find("MainNode")
    assert_not_nil entry, "Expected MainNode to be registered in ClassRegistry"
    assert_eq entry.not_nil!.parent_name, "Node3D"
  end

  test "MyCrystalNode property defaults" do
    entry = Godot::ClassRegistry.find("MyCrystalNode")
    assert_not_nil entry, "Expected MyCrystalNode to be registered in ClassRegistry"
    props = entry.not_nil!.properties.map(&.name)
    assert_includes props, "my_var"
  end
end

test_case "Editor", "Godot editor environment verification" do
  assert_true Godot.editor_hint?, "Expected Godot.editor_hint? to be true when executing in-editor"
end

describe "In-Editor Test Suite" do
  it "registers in-editor test suites with Lapis::Test" do
    Registry.for_category("Nodes").should_not be_empty
    Registry.for_category("Editor").should_not be_empty
  end
end
