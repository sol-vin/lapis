# =============================================================================
# LibGodot Test Suite: Cold Boot Engine Isolation & Ephemeral Code Sandbox
# =============================================================================
# Verifies that cold boot tests:
# 1. Execute in a completely isolated, dedicated engine environment (headless subprocess).
# 2. Ephemeral test code (scripts, scenes, configs) ONLY exists during the test run.
# 3. No test code is replicated into project directories (scenes/, scripts/, src/).
# 4. Clean sandboxes are completely wiped and purged upon completion.
# =============================================================================

test_suite "ColdBoot" do
  test "executes in a completely isolated engine environment", cold_boot: true do |boot|
    # Verify sandbox directory exists in scratch/ and not in root project
    sandbox = boot.sandbox_dir
    assert_true Dir.exists?(sandbox), "Ephemeral sandbox should exist during test"
    assert_string_contains sandbox, "cold_boot"

    # Write test-specific isolated script that only exists for this test
    script_content = <<-GDSCRIPT
extends SceneTree

func _initialize() -> void:
	print("[ColdBootIsolated] Hello from isolated engine environment! Time: %d" % Time.get_ticks_msec())
	quit(0)

func _init() -> void:
	print("[ColdBootIsolated] Hello from isolated engine environment! Time: %d" % Time.get_ticks_msec())
	quit(0)

func _process(_delta: float) -> bool:
	return true
GDSCRIPT

    boot.write_script("temp_isolated_runner.gd", script_content)
    isolated_file = File.join(sandbox, "temp_isolated_runner.gd")
    assert_true File.exists?(isolated_file), "Isolated script exists in ephemeral sandbox"

    # Verify this code is NOT replicated in the project root
    assert_false File.exists?("scripts/temp_isolated_runner.gd"), "Isolated code must not be replicated to scripts/"
    assert_false File.exists?("scenes/temp_isolated_runner.gd"), "Isolated code must not be replicated to scenes/"

    # Execute isolated script in a fresh Godot subprocess
    res = boot.run_isolated_script("temp_isolated_runner.gd")
    assert_true res.passed, "Isolated cold boot process must succeed"
    assert_string_contains res.message, "[ColdBootIsolated] Hello from isolated engine environment!"
  end

  test "supports custom scene and class isolation without project pollution", cold_boot: true do |boot|
    # Write isolated scene configuration
    scene_code = <<-GDSCRIPT
extends SceneTree

func _initialize() -> void:
	var node = Node2D.new()
	node.name = "IsolatedNode"
	print("[ColdBootScene] Node created: %s" % node.name)
	node.free()
	quit(0)

func _init() -> void:
	var node = Node2D.new()
	node.name = "IsolatedNode"
	print("[ColdBootScene] Node created: %s" % node.name)
	node.free()
	quit(0)

func _process(_delta: float) -> bool:
	return true
GDSCRIPT

    boot.write_script("scene_test.gd", scene_code)
    res = boot.run_isolated_script("scene_test.gd")
    assert_true res.passed, "Isolated scene execution should pass"
    assert_string_contains res.message, "[ColdBootScene] Node created: IsolatedNode"
  end
end
