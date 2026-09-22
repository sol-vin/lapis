# =============================================================================
# LibGodot Test Suite: Auto-Bound GDScript Nodes & Methods
# =============================================================================
# Verifies that custom GDScript nodes are automatically introspected at
# compile time and bound into strongly typed Crystal classes with full
# property, method, and signal support.

include Lapis::Test

test_gdscript "Auto-bound ComprehensiveInteropNode instantiation and inheritance" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_comprehensive_interop.tscn")
  assert_not_nil scene, "Test scene must load"
  root = scene.not_nil!.instantiate
  assert_not_nil root, "Scene root must instantiate"

  # Wrap native instance via typed wrapper
  comp = Godot::ComprehensiveInteropNode.from(root)
  assert_not_nil comp, "Wrapper must not be nil"

  # Verify Node2D and Node methods inherited seamlessly
  assert_true comp.is_a?(Godot::Node2D), "ComprehensiveInteropNode must inherit from Node2D"
  assert_true comp.is_a?(Godot::Node), "ComprehensiveInteropNode must inherit from Node"

  # Node2D spatial API
  comp.position = Godot::Vector2.new(12.0_f32, 34.0_f32)
  pos = comp.position
  assert_approx_eq pos.x.to_f64, 12.0, 0.01, "Position X must match"
  assert_approx_eq pos.y.to_f64, 34.0, 0.01, "Position Y must match"

  root.destroy
  scene.destroy
end

test_gdscript "Auto-bound typed properties get and set" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_comprehensive_interop.tscn")
  root = scene.not_nil!.instantiate
  comp = Godot::ComprehensiveInteropNode.from(root)

  # Check default initial values
  assert_eq comp.int_prop, 42_i64, "Default int_prop must be 42"
  assert_approx_eq comp.float_prop, 3.14159, 0.0001, "Default float_prop must be approx 3.14159"
  assert_eq comp.string_prop, "LibGodot AutoBind", "Default string_prop must match"
  assert_true comp.bool_prop, "Default bool_prop must be true"

  # Mutate via strongly typed setters
  comp.int_prop = 999_i64
  comp.float_prop = 2.71828_f64
  comp.string_prop = "CrystalMutated"
  comp.bool_prop = false

  # Verify getters reflect updated values
  assert_eq comp.int_prop, 999_i64, "Mutated int_prop must be 999"
  assert_approx_eq comp.float_prop, 2.71828, 0.0001, "Mutated float_prop must be approx 2.71828"
  assert_eq comp.string_prop, "CrystalMutated", "Mutated string_prop must match"
  assert_false comp.bool_prop, "Mutated bool_prop must be false"

  root.destroy
  scene.destroy
end

test_gdscript "Auto-bound typed arithmetic, string, and boolean methods" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_comprehensive_interop.tscn")
  root = scene.not_nil!.instantiate
  comp = Godot::ComprehensiveInteropNode.from(root)

  # Arithmetic method
  sum = comp.compute_scaled_sum(10_i64, 20_i64, 2.5_f64)
  assert_eq sum, 75_i64, "(10 + 20) * 2.5 = 75"

  # Float calculation
  hypot = comp.calculate_hypotenuse(3.0_f64, 4.0_f64)
  assert_approx_eq hypot, 5.0, 0.001, "sqrt(3^2 + 4^2) = 5.0"

  # String formatting
  msg = comp.format_complex_message("TASK", 42_i64, "COMPLETE")
  assert_eq msg, "TASK #42 -> COMPLETE", "format_complex_message must match expected format"

  # Boolean condition logic
  cond1 = comp.validate_conditions(true, false)
  assert_true cond1, "true and not false must be true"
  cond2 = comp.validate_conditions(true, true)
  assert_false cond2, "true and not true must be false"

  root.destroy
  scene.destroy
end

test_gdscript "Auto-bound vector, color, and node object parameters" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_comprehensive_interop.tscn")
  root = scene.not_nil!.instantiate
  comp = Godot::ComprehensiveInteropNode.from(root)

  # Vector2 parameter
  comp.position = Godot::Vector2.new(10.0_f32, 20.0_f32)
  dist = comp.distance_to_point(Godot::Vector2.new(10.0_f32, 25.0_f32))
  assert_approx_eq dist, 5.0, 0.01, "Distance to (10, 25) must be 5.0"

  # Vector3 parameter
  v1 = Godot::Vector3.new(1.0_f32, 2.0_f32, 3.0_f32)
  v2 = Godot::Vector3.new(4.0_f32, -5.0_f32, 6.0_f32)
  dot = comp.compute_dot3(v1, v2)
  # 1*4 + 2*(-5) + 3*6 = 4 - 10 + 18 = 12
  assert_approx_eq dot, 12.0, 0.01, "Dot product must be 12.0"

  # Color parameter
  c = Godot::Color.new(0.2_f32, 0.4_f32, 0.6_f32, 1.0_f32)
  brightness = comp.color_brightness(c)
  assert_approx_eq brightness, 0.4, 0.01, "Average brightness must be 0.4"

  # Node passing
  sample_node = Godot.create(Godot::Node2D)
  sample_node.name = "InspectMeNode"
  inspection = comp.inspect_incoming_node(sample_node)
  assert_eq inspection, "InspectMeNode:Node2D", "inspect_incoming_node must identify node and class"
  sample_node.destroy

  # Node instantiation from GDScript
  spawned = comp.duplicate_child_node("SpawnedNode")
  assert_not_nil spawned, "duplicate_child_node must return instantiated Node"
  assert_eq spawned.not_nil!.name, "SpawnedNode", "Spawned node name must match"

  root.destroy
  scene.destroy
end

test_gdscript "Auto-bound void method and state mutation" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_comprehensive_interop.tscn")
  root = scene.not_nil!.instantiate
  comp = Godot::ComprehensiveInteropNode.from(root)

  comp.int_prop = 123_i64
  comp.float_prop = 456.78_f64
  comp.string_prop = "WillBeReset"
  comp.bool_prop = true

  comp.perform_state_reset

  assert_eq comp.int_prop, 0_i64, "int_prop must be reset to 0"
  assert_approx_eq comp.float_prop, 0.0, 0.001, "float_prop must be reset to 0.0"
  assert_eq comp.string_prop, "RESET", "string_prop must be reset to 'RESET'"
  assert_false comp.bool_prop, "bool_prop must be reset to false"
  assert_eq comp.internal_reset_count, 1_i64, "internal_reset_count must be incremented to 1"

  root.destroy
  scene.destroy
end

test_gdscript "Auto-bound signals and emission listening" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_comprehensive_interop.tscn")
  root = scene.not_nil!.instantiate
  comp = Godot::ComprehensiveInteropNode.from(root)

  # Check bound signal helpers
  assert_not_nil comp.data_processed, "data_processed signal must exist"
  assert_not_nil comp.state_transitioned, "state_transitioned signal must exist"

  received_old_state = ""
  received_new_state = ""
  transition_received = false

  sub = comp.connect("state_transitioned") do |args|
    if args.size >= 2
      received_old_state = args[0].to_s
      received_new_state = args[1].to_s
      transition_received = true
    end
  end

  comp.trigger_state_transitioned("IdleState", "BattleState")

  assert_true transition_received, "state_transitioned signal callback must fire"
  assert_eq received_old_state, "IdleState", "Old state must match"
  assert_eq received_new_state, "BattleState", "New state must match"
  assert_eq comp.last_transition_old, "IdleState", "GDScript internal state must match"
  assert_eq comp.last_transition_new, "BattleState", "GDScript internal state must match"

  sub.unsubscribe
  root.destroy
  scene.destroy
end
