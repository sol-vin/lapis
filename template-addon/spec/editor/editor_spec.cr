require "spec"
require "lapis"

include Lapis::Test

# =============================================================================
# Addon In-Editor Test Suite (spec/editor/editor_spec.cr)
# =============================================================================
# These tests are registered into Lapis::Test::Registry and executed live
# inside the Godot Editor through the Crystal Hub dock (Unit Test Runner tab)
# without opening or switching scenes.

test_suite "Nodes" do
  test "CrystalAddonBanner is registered as Control" do
    entry = Godot::ClassRegistry.find("CrystalAddonBanner")
    assert_not_nil entry, "Expected CrystalAddonBanner to be registered"
    assert_eq entry.not_nil!.parent_name, "Control"
    props = entry.not_nil!.properties.map(&.name)
    assert_includes props, "message"
    assert_includes props, "text_color"
  end
end

test_case "Editor", "CrystalAddonPlugin is marked as tool" do
  entry = Godot::ClassRegistry.find("CrystalAddonPlugin")
  assert_not_nil entry, "Expected CrystalAddonPlugin to be registered"
  assert_true entry.not_nil!.is_tool, "CrystalAddonPlugin must have is_tool == true"
end

describe "Addon In-Editor Test Suite" do
  it "registers addon in-editor tests with Lapis::Test" do
    tests = Registry.all_tests
    tests.should_not be_empty
  end
end
