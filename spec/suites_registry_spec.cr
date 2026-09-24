require "./spec_helper"
require "../src/main"

describe "Lapis::Test::Registry Test Suites" do
  it "registers all modular test suites across all domains" do
    cats = Lapis::Test::Registry.categories
    cats.size.should be >= 30

    # Key categories must all be present
    expected_categories = [
      "Core", "2D", "3D", "UI", "Nodes", "Stress",
      "Mesh", "Shaders", "Physics", "AudioAnim", "Tweens",
      "Resources", "Lifecycle", "DeadPointerSafety", "Concurrency",
      "CallableAdv", "ClassDB", "MacrosDSL", "MultiAddon", "GDScript"
    ]

    expected_categories.each do |cat|
      cats.should contain(cat)
      Lapis::Test::Registry.for_category(cat).should_not be_empty
    end
  end

  it "contains test cases with valid source locations" do
    tests = Lapis::Test::Registry.all_tests
    tests.size.should be >= 80

    tests.first.category.should_not be_empty
    tests.first.name.should_not be_empty
    tests.first.file.should_not be_empty
    tests.first.line.should be > 0
  end
end
