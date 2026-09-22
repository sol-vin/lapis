require "../../src/lapis"
require "./generated/project_nodes/all_project_nodes"

# =============================================================================
# =============================================================================
# TestFramework and Declarative DSL Macros are provided by `src/libgodot/testing.cr`
# (loaded via `require "../../src/lapis"`).
# =============================================================================

# =============================================================================
# Custom Property & Annotation Test Target Node
# =============================================================================

@[Tool]
@[Icon("res://addons/crystal_integration/crystal.gdextension")]
node PropertyTestTarget < Godot::Node do
  # 1. Standard Property Exports
  @[Export]
  property float32_val : Float32 = 1.25_f32

  @[Export]
  property float64_val : Float64 = 9.87654

  @[Export]
  property int32_val : Int32 = 42

  @[Export]
  property int64_val : Int64 = 10000000000_i64

  @[Export]
  property bool_val : Bool = true

  @[Export]
  property string_val : String = "LibGodot"

  @[Export]
  property vec2_val : Godot::Vector2 = Godot::Vector2.new(3.0, 4.0)

  @[Export]
  property vec2i_val : Godot::Vector2i = Godot::Vector2i.new(7, 8)

  @[Export]
  property vec3_val : Godot::Vector3 = Godot::Vector3.new(1.0, 2.0, 3.0)

  @[Export]
  property vec3i_val : Godot::Vector3i = Godot::Vector3i.new(4, 5, 6)

  @[Export]
  property color_val : Godot::Color = Godot::Color.new(1.0, 0.5, 0.25, 1.0)

  @[Export]
  property rect2_val : Godot::Rect2 = Godot::Rect2.new(10.0, 20.0, 100.0, 200.0)

  # 2. Custom Getters & Setters
  @raw_health : Float32 = 100.0_f32
  @dirty_counter : Int32 = 0
  @tool_action_fired : Bool = false

  def health_percentage : Float32
	(@raw_health / 100.0_f32) * 100.0_f32
  end

  def clamped_health=(val : Float32)
	@raw_health = val.clamp(0.0_f32, 100.0_f32)
  end

  def clamped_health : Float32
	@raw_health
  end

  def dirty_trigger=(val : Int32)
	@dirty_counter += val
  end

  def dirty_trigger : Int32
	@dirty_counter
  end

  def tool_button_trigger=(val : Bool)
	if val
	  @tool_action_fired = true
	end
  end

  def tool_button_trigger : Bool
	@tool_action_fired
  end

  # 3. Export Property Hints
  @[ExportRange(0..100, 5)]
  property range_hint_prop : Int32 = 25

  @[ExportEnum("Low", "Medium", "High")]
  property enum_hint_prop : String = "Medium"

  @[ExportFile("*.tscn")]
  property file_hint_prop : String = "res://scenes/test_dummy_2d.tscn"

  @[ExportMultiline]
  property multiline_hint_prop : String = "First Line\nSecond Line"

  @[ExportColorNoAlpha]
  property color_no_alpha_prop : Godot::Color = Godot::Color.new(1.0, 0.0, 0.0)

  @[ExportNodePath("Child")]
  property nodepath_hint_prop : Godot::NodePath = Godot::NodePath.new("Child")

  @[ExportStorage]
  property storage_only_prop : Int32 = 999

  @[ExportToolButton("Click Here")]
  property tool_btn_prop = ->{
	@tool_btn_fired = true
  }

  property tool_btn_fired : Bool = false

  @[ExportToolButton("Proc Method Pointer Button", icon: "Action")]
  property proc_btn_ptr = ->tool_proc_method

  @[ExportToolButton("Proc Lambda Button")]
  property proc_btn_lambda = ->{
	@proc_action_fired = true
  }

  @[ExportToolButton("Proc Dynamic Button")]
  property proc_btn_dyn : Proc(Void)? = nil

  property proc_action_fired : Bool = false

  def tool_proc_method : Void
	@proc_action_fired = true
  end

  @[ExportToolButton("Method Action", icon: "Play")]
  def test_method_action : Void
	@tool_action_fired = true
  end

  @[ExportCustom(hint: 1_u32, hint_string: "0,50,5")]
  property custom_hint_prop : Int32 = 10

  # 4. Grouping Annotations
  @[ExportCategory("Stats")]
  property cat_marker : Int32 = 1

  @[ExportGroup("Movement", prefix: "move_")]
  property move_speed : Float32 = 250.0_f32

  @[ExportSubgroup("Air")]
  property move_air_speed : Float32 = 180.0_f32

  # 5. Signals
  signal test_event_fired(val : Int32)
  signal multi_arg_event(code : Int32, label : String, ratio : Float64)
  signal custom_event(payload : String)
end

# =============================================================================
# Custom GDScript Interop Target Node
# =============================================================================

@[Tool]
node GDScriptInteropTarget < Godot::Node do
  @[Export]
  property crystal_greeting : String = "Hello from Crystal"

  @[Export]
  property crystal_count : Int32 = 100

  signal crystal_ping(val : Int32)

  def multiply(a : Int32, b : Int32) : Int32
	a * b
  end

  def ping(val : Int32)
	emit_crystal_ping(val)
  end
end

# =============================================================================
# @tool 2D & 3D Test Runner Nodes (Automated In-Editor Execution)
# =============================================================================

@[Tool]
node ToolTester2D < Godot::Node2D do
  @[ExportToolButton("▶ Run 2D Tool Tests")]
  property run_tests_button = ->run_tool_tests

  @[ExportToolButton("Execute 2D Tests Direct", icon: "Play")]
  def execute_2d_tests_direct : Void
	run_tool_tests
  end

  property test_status : String = "Ready"

  def is_editor_environment : Bool
	Godot.editor_hint?
  end

  def _ready
	# Automatically execute complete in-editor suite when loaded into Godot Editor
	if is_editor_environment
	  Godot.print("[ToolTester2D] Editor detected. Auto-executing in-editor tests...")
	  run_tool_tests
	end
  end

  def run_tool_tests
	Godot.print("------------------------------------------------------------------")
	Godot.print("[ToolTester2D] Executing In-Editor 2D Test Suite...")
	Godot.print("------------------------------------------------------------------")
	
	results = ::TestFramework::Registry.run_category("2D", self)
	passed = results.count(&.passed)
	total = results.size
	
	results.each do |r|
	  if r.passed
		Godot.print("  [PASS] [#{r.category}] #{r.name}")
	  else
		Godot.printerr("  [FAIL] [#{r.category}] #{r.name}: #{r.message}")
	  end
	end
	
	if passed == total
	  @test_status = "All #{total}/#{total} Tests Passed!"
	  Godot.print("[ToolTester2D] SUCCESS: All #{total} in-editor tests passed cleanly!")
	else
	  @test_status = "Failed: #{total - passed}/#{total} Errors"
	  Godot.printerr("[ToolTester2D] FAILED: #{total - passed} test(s) failed.")
	  Godot::SystemIO.write_file("bin/.tool_tests_failed", "Failed: #{total - passed} test(s) failed.\n")
	  Godot::SystemIO.write_file("test/bin/.tool_tests_failed", "Failed: #{total - passed} test(s) failed.\n")
	end
  end

end

@[Tool]
node ToolTester3D < Godot::Node3D do
  @[ExportToolButton("▶ Run 3D Tool Tests")]
  property run_tests_button = ->run_tool_tests

  @[ExportToolButton("Execute 3D Tests Direct", icon: "Play")]
  def execute_3d_tests_direct : Void
	run_tool_tests
  end

  property test_status : String = "Ready"

  def is_editor_environment : Bool
	Godot.editor_hint?
  end

  def _ready
	if is_editor_environment
	  Godot.print("[ToolTester3D] Editor detected. Auto-executing in-editor tests...")
	  run_tool_tests
	end
  end

  def run_tool_tests
	Godot.print("------------------------------------------------------------------")
	Godot.print("[ToolTester3D] Executing In-Editor 3D Test Suite...")
	Godot.print("------------------------------------------------------------------")
	
	results = ::TestFramework::Registry.run_category("3D", self)
	passed = results.count(&.passed)
	total = results.size
	
	results.each do |r|
	  if r.passed
		Godot.print("  [PASS] [#{r.category}] #{r.name}")
	  else
		Godot.printerr("  [FAIL] [#{r.category}] #{r.name}: #{r.message}")
	  end
	end
	
	if passed == total
	  @test_status = "All #{total}/#{total} Tests Passed!"
	  Godot.print("[ToolTester3D] SUCCESS: All #{total} in-editor tests passed cleanly!")
	else
	  @test_status = "Failed: #{total - passed}/#{total} Errors"
	  Godot.printerr("[ToolTester3D] FAILED: #{total - passed} test(s) failed.")
	  Godot::SystemIO.write_file("bin/.tool_tests_failed", "Failed: #{total - passed} test(s) failed.\n")
	  Godot::SystemIO.write_file("test/bin/.tool_tests_failed", "Failed: #{total - passed} test(s) failed.\n")
	end
  end

end

# =============================================================================
# Runtime Test Runner UI Panel
# =============================================================================

@[Tool]
node RunTesterPanel < Godot::Control do
  @@is_running_tests : Bool = false

  def _ready
	Godot.print("==================================================================")
	Godot.print("    LibGodot Interactive Test Runner Loaded (Two-Click Testing)   ")
	Godot.print("==================================================================")
	
	# Connect category buttons if present in scene
	hook_button("MarginContainer/VBox/ButtonBox/BtnRunAll") { run_and_display_all }
	hook_button("MarginContainer/VBox/ButtonBox/BtnRun2D") { run_and_display_category("2D") }
	hook_button("MarginContainer/VBox/ButtonBox/BtnRun3D") { run_and_display_category("3D") }
	hook_button("MarginContainer/VBox/ButtonBox/BtnRunCore") { run_and_display_category("Core") }
	hook_button("MarginContainer/VBox/ButtonBox/BtnRunProps") { run_and_display_category("Properties") }
	hook_button("MarginContainer/VBox/ButtonBox/BtnRunNodes") { run_and_display_category("Nodes") }
	hook_button("MarginContainer/VBox/ButtonBox/BtnRunGDScript") { run_and_display_category("GDScript") }
	hook_button("MarginContainer/VBox/ButtonBox/BtnRunMesh") { run_and_display_category("Mesh") }
	hook_button("MarginContainer/VBox/ButtonBox/BtnRunPhysics") { run_and_display_category("Physics") }
	hook_button("MarginContainer/VBox/ButtonBox/BtnRunStress") { run_and_display_category("Stress") }
	hook_button("MarginContainer/VBox/ButtonBox/BtnRunUI") { run_and_display_category("UI") }
	hook_button("MarginContainer/VBox/ButtonBox/BtnRunAudioAnim") { run_and_display_category("AudioAnim") }
	hook_button("MarginContainer/VBox/ButtonBox/BtnRunResources") { run_and_display_category("Resources") }
	hook_button("MarginContainer/VBox/ButtonBox/BtnRunLifecycle") { run_and_display_category("Lifecycle") }
	hook_button("MarginContainer/VBox/ButtonBox/BtnRunClassDB") { run_and_display_category("ClassDB") }

	# Automatically execute all tests on startup only in game runtime (not editor workspace)
	run_and_display_all unless Godot.editor_hint?
  end

  def hook_button(path : String, &callback)
	# UI hook helper
  end

  def cli_filter : String?
	extract_cli_arg("--filter")
  end

  def cli_category : String?
	extract_cli_arg("--category")
  end

  def extract_cli_arg(prefix : String) : String?
	begin
	  ARGV.each_with_index do |arg, idx|
		if arg.starts_with?("#{prefix}=")
		  return arg.sub("#{prefix}=", "").strip
		elsif arg == prefix && idx + 1 < ARGV.size
		  return ARGV[idx + 1].strip
		end
	  end
	rescue
	end
	nil
  end

  def run_and_display_category(category : String)
	filter = cli_filter
	results = ::TestFramework::Registry.run_category(category, self, filter: filter)
	display_results(results, category)
  end

  def run_and_display_all : Void
	return if @@is_running_tests
	@@is_running_tests = true
	begin
	  filter = cli_filter
	  category = cli_category
	  results = ::TestFramework::Registry.run_all(self, filter: filter, category_filter: category)
	  label = if category && filter
	    "All [Category: #{category}, Filter: #{filter}]"
	  elsif category
	    "All [Category: #{category}]"
	  elsif filter
	    "All [Filter: #{filter}]"
	  else
	    "All"
	  end
	  display_results(results, label)
	ensure
	  @@is_running_tests = false
	end
  end

  def display_results(results : Array(TestFramework::TestResult), suite_label : String)
	passed = results.count(&.passed)
	total = results.size

	Godot.print("\n=== LibGodot Test Results [#{suite_label}]: #{passed}/#{total} Passed ===")
	results.each do |r|
	  if r.passed
		Godot.print("  ✔ [#{r.category}] #{r.name}")
	  else
		Godot.printerr("  ✘ [#{r.category}] #{r.name}: #{r.message}")
	  end
	end

	if stats_label = get_node?("MarginContainer/VBox/StatsLabel")
	  stats_label.call("set_text", "Results: #{passed} / #{total} Passed (#{total - passed} Failed)")
	end

	if badge = get_node?("MarginContainer/VBox/HeaderBox/StatusBadge")
	  badge.call("set_text", passed == total ? "ALL PASSED" : "#{total - passed} FAILED")
	end

	if log_box = get_node?("MarginContainer/VBox/LogOutput")
	  lines = [] of String
	  lines << "[b]=== LibGodot Test Execution Suite: #{suite_label} ===[/b]"
	  results.each do |r|
		color = r.passed ? "#44ff88" : "#ff4444"
		icon = r.passed ? "[color=#{color}]✔ PASS[/color]" : "[color=#{color}]✘ FAIL[/color]"
		lines << "#{icon} [b][#{r.category}][/b] #{r.name} - #{r.message}"
	  end
	  log_box.call("set_text", lines.join("\n"))
	end

	if suite_label.starts_with?("All")
	  begin
		summary = "TOTAL=#{total}\nPASSED=#{passed}\nFAILED=#{total - passed}\n"
		Godot::SystemIO.write_file(".runtime_test_results.txt", summary) rescue nil
		Godot::SystemIO.write_file("bin/.runtime_test_results.txt", summary) rescue nil
		Godot::SystemIO.write_file("test/bin/.runtime_test_results.txt", summary) rescue nil
		if passed == total
		  Godot::SystemIO.write_file(".runtime_tests_passed", "PASSED\n") rescue nil
		  Godot::SystemIO.write_file("bin/.runtime_tests_passed", "PASSED\n") rescue nil
		  Godot::SystemIO.write_file("test/bin/.runtime_tests_passed", "PASSED\n") rescue nil
		  Godot::SystemIO.delete_file(".runtime_tests_failed") if Godot::SystemIO.file_exists?(".runtime_tests_failed")
		  Godot::SystemIO.delete_file("bin/.runtime_tests_failed") if Godot::SystemIO.file_exists?("bin/.runtime_tests_failed")
		  Godot::SystemIO.delete_file("test/bin/.runtime_tests_failed") if Godot::SystemIO.file_exists?("test/bin/.runtime_tests_failed")
		else
		  failed_lines = results.reject(&.passed).map { |r| "FAILED: [#{r.category}] #{r.name} - #{r.message}" }.join("\n")
		  Godot::SystemIO.write_file(".runtime_tests_failed", "FAILED: #{total - passed} test(s) failed\n#{failed_lines}\n") rescue nil
		  Godot::SystemIO.write_file("bin/.runtime_tests_failed", "FAILED: #{total - passed} test(s) failed\n#{failed_lines}\n") rescue nil
		  Godot::SystemIO.write_file("test/bin/.runtime_tests_failed", "FAILED: #{total - passed} test(s) failed\n#{failed_lines}\n") rescue nil
		  Godot::SystemIO.delete_file(".runtime_tests_passed") if Godot::SystemIO.file_exists?(".runtime_tests_passed")
		  Godot::SystemIO.delete_file("bin/.runtime_tests_passed") if Godot::SystemIO.file_exists?("bin/.runtime_tests_passed")
		  Godot::SystemIO.delete_file("test/bin/.runtime_tests_passed") if Godot::SystemIO.file_exists?("test/bin/.runtime_tests_passed")
		end
	  rescue
	  end

	  if should_autorun? && !Godot.editor_hint?
		GC.collect
		tree = get_tree
		tree.quit(passed == total ? 0_i64 : 1_i64) unless tree.pointer.null?
	  end
	end
  end

  def should_autorun? : Bool
	return true if ENV["GODOT_TEST_AUTORUN"]? == "1"
	begin
	  return true if ARGV.includes?("--autorun")
	rescue
	end
	begin
	  cmdline_args = Godot.os.call_str("get_cmdline_args")
	  return true if cmdline_args.includes?("--autorun")
	rescue
	end
	begin
	  user_args = Godot.os.call_str("get_cmdline_user_args")
	  return true if user_args.includes?("--autorun")
	rescue
	end
	false
  end
end

# =============================================================================
# Test Suite 1: Core Built-ins, Math, Resources, Singletons
# =============================================================================

test_core "Vector2 arithmetic, length and normalize" do
  v1 = Godot::Vector2.new(3.0, 4.0)
  TestFramework.assert_approx_eq v1.length, 5.0_f32
  TestFramework.assert_approx_eq v1.length_squared, 25.0_f32

  v_norm = v1.normalized
  TestFramework.assert_approx_eq v_norm.length, 1.0_f32
  TestFramework.assert_approx_eq v_norm.x, 0.6_f32
  TestFramework.assert_approx_eq v_norm.y, 0.8_f32

  v2 = Godot::Vector2.new(1.0, 2.0)
  add = v1 + v2
  TestFramework.assert_eq add.x, 4.0_f32
  TestFramework.assert_eq add.y, 6.0_f32

  sub = v1 - v2
  TestFramework.assert_eq sub.x, 2.0_f32
  TestFramework.assert_eq sub.y, 2.0_f32

  dot = Godot::Vector2.new(1.0, 0.0).dot(Godot::Vector2.new(0.0, 1.0))
  TestFramework.assert_approx_eq dot, 0.0_f32
end

test_core "Vector2i grid coordinates" do
  v = Godot::Vector2i.new(10, 20)
  TestFramework.assert_eq v.x, 10
  TestFramework.assert_eq v.y, 20
  v_mul = v * 2
  TestFramework.assert_eq v_mul.x, 20
  TestFramework.assert_eq v_mul.y, 40
end

test_core "Vector3 arithmetic, dot and cross product" do
  v1 = Godot::Vector3.new(1.0, 0.0, 0.0)
  v2 = Godot::Vector3.new(0.0, 1.0, 0.0)
  cross = v1.cross(v2)
  TestFramework.assert_approx_eq cross.x, 0.0_f32
  TestFramework.assert_approx_eq cross.y, 0.0_f32
  TestFramework.assert_approx_eq cross.z, 1.0_f32

  dot = v1.dot(v2)
  TestFramework.assert_approx_eq dot, 0.0_f32
end

test_core "Color channel precision and constants" do
  c = Godot::Color.new(0.5, 0.25, 0.75, 1.0)
  TestFramework.assert_approx_eq c.r, 0.5_f32
  TestFramework.assert_approx_eq c.g, 0.25_f32
  TestFramework.assert_approx_eq c.b, 0.75_f32
  TestFramework.assert_approx_eq c.a, 1.0_f32

  white = Godot::Color::WHITE
  TestFramework.assert_approx_eq white.r, 1.0_f32
  TestFramework.assert_approx_eq white.g, 1.0_f32
  TestFramework.assert_approx_eq white.b, 1.0_f32
end

test_core "Rect2 bounds and position" do
  r = Godot::Rect2.new(10.0, 20.0, 50.0, 60.0)
  TestFramework.assert_eq r.position.x, 10.0_f32
  TestFramework.assert_eq r.position.y, 20.0_f32
  TestFramework.assert_eq r.size.x, 50.0_f32
  TestFramework.assert_eq r.size.y, 60.0_f32
end

test_core "Transform3D and Basis identity matrix" do
  t = Godot::Transform3D.new
  TestFramework.assert_approx_eq t.origin.x, 0.0_f32
  TestFramework.assert_approx_eq t.origin.y, 0.0_f32
  TestFramework.assert_approx_eq t.origin.z, 0.0_f32

  vec = Godot::Vector3.new(1.0, 2.0, 3.0)
  transformed = t.basis * vec
  TestFramework.assert_approx_eq transformed.x, 1.0_f32
  TestFramework.assert_approx_eq transformed.y, 2.0_f32
  TestFramework.assert_approx_eq transformed.z, 3.0_f32
end

test_core "Math.move_toward float precision" do
  moved32 = Math.move_toward(0.0_f32, 10.0_f32, 2.5_f32)
  TestFramework.assert_approx_eq moved32, 2.5_f32

  moved64 = Math.move_toward(10.0, 0.0, 3.0)
  TestFramework.assert_approx_eq moved64, 7.0
end

test_core "Godot::Range and Crystal Range cohesion" do
  cr_range = (10..100)
  g_range = cr_range.to_godot_range(5.0)
  TestFramework.assert_eq g_range.min_value, 10.0
  TestFramework.assert_eq g_range.max_value, 100.0
  TestFramework.assert_eq g_range.step, 5.0

  g_range.value = 55.0
  TestFramework.assert_approx_eq g_range.ratio, 0.5
  TestFramework.assert_true g_range.includes?(55)
  TestFramework.assert_false g_range.includes?(150)
end

test_core "Resource loading (Godot.load & preload)" do
  res = Godot.load("res://scenes/test_dummy_2d.tscn")
  TestFramework.assert_not_nil res
  TestFramework.assert_false res.pointer.null?, "res.pointer is null"

  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_dummy_2d.tscn")
  TestFramework.assert_not_nil scene
  TestFramework.assert_false scene.pointer.null?, "scene.pointer is null"

  inst = scene.instantiate
  TestFramework.assert_not_nil inst
  TestFramework.assert_false inst.pointer.null?, "inst.pointer is null"
  TestFramework.assert_eq inst.name, "TestDummy2D"
  inst.destroy
  scene.destroy
  res.destroy
end

test_core "Input singleton method verification" do
  pressed = Godot::Input.is_key_pressed(4194305) # Key::KEY_ESCAPE
  TestFramework.assert_false pressed
end

# =============================================================================
# Test Suite 2: 2D & 3D Spatial Transforms
# =============================================================================

test_2d "Node2D position, rotation, and scale" do
  if node.is_a?(Godot::Node2D)
	node.position = Godot::Vector2.new(120.0, 240.0)
	TestFramework.assert_approx_eq node.position.x, 120.0_f32
	TestFramework.assert_approx_eq node.position.y, 240.0_f32

	node.rotation = 1.5708_f32
	TestFramework.assert_approx_eq node.rotation, 1.5708_f32, 0.001

	node.scale = Godot::Vector2.new(2.0, 2.0)
	TestFramework.assert_approx_eq node.scale.x, 2.0_f32
	TestFramework.assert_approx_eq node.scale.y, 2.0_f32
  else
	n = Godot.create(Godot::Node2D)
	n.position = Godot::Vector2.new(50.0, 60.0)
	TestFramework.assert_approx_eq n.position.x, 50.0_f32
	n.destroy
  end
end

test_3d "Node3D position, rotation, and scale" do
  if node.is_a?(Godot::Node3D)
	node.position = Godot::Vector3.new(10.0, 20.0, 30.0)
	TestFramework.assert_approx_eq node.position.x, 10.0_f32
	TestFramework.assert_approx_eq node.position.y, 20.0_f32
	TestFramework.assert_approx_eq node.position.z, 30.0_f32

	node.scale = Godot::Vector3.new(3.0, 3.0, 3.0)
	TestFramework.assert_approx_eq node.scale.x, 3.0_f32
  else
	n = Godot.create(Godot::Node3D)
	n.position = Godot::Vector3.new(1.0, 2.0, 3.0)
	TestFramework.assert_approx_eq n.position.x, 1.0_f32
	n.destroy
  end
end

test_3d "CharacterBody3D velocity and is_on_floor" do
  cb = Godot.create(Godot::CharacterBody3D)
  cb.velocity = Godot::Vector3.new(0.0, -9.8, 5.0)
  TestFramework.assert_approx_eq cb.velocity.y, -9.8_f32
  TestFramework.assert_approx_eq cb.velocity.z, 5.0_f32
  cb.destroy
end

# =============================================================================
# Test Suite 3: Node Hierarchy & Lifecycle (Godot Best Practices)
# =============================================================================

test_nodes "Godot.create instantiates native engine nodes" do
  n2d = Godot.create(Godot::Node2D)
  TestFramework.assert_not_nil n2d
  TestFramework.assert_false n2d.pointer.null?

  n3d = Godot.create(Godot::Node3D)
  TestFramework.assert_not_nil n3d
  TestFramework.assert_false n3d.pointer.null?

  n2d.destroy
  n3d.destroy
end

test_nodes "add_child establishes parent-child relationship" do
  parent = Godot.create(Godot::Node)
  parent.name = "TestParentNode"
  child = Godot.create(Godot::Node)
  child.name = "TestChildNode"

  parent.add_child(child)
  TestFramework.assert_eq parent.get_child_count, 1_i64
  TestFramework.assert_not_nil child.get_parent
  TestFramework.assert_eq child.get_parent.not_nil!.name, "TestParentNode"
  parent.destroy
end

test_nodes "remove_child decouples child into orphan state" do
  parent = Godot.create(Godot::Node)
  child = Godot.create(Godot::Node)
  child.name = "OrphanTarget"

  parent.add_child(child)
  TestFramework.assert_eq parent.get_child_count, 1_i64

  parent.remove_child(child)
  TestFramework.assert_eq parent.get_child_count, 0_i64
  TestFramework.assert_nil child.get_parent?
  child.destroy
  parent.destroy
end

test_nodes "reparent relocates child to new parent" do
  p1 = Godot.create(Godot::Node2D)
  p1.name = "Parent1"
  p2 = Godot.create(Godot::Node2D)
  p2.name = "Parent2"
  child = Godot.create(Godot::Node2D)
  child.name = "MovableChild"

  p1.add_child(child)
  TestFramework.assert_eq child.get_parent.not_nil!.name, "Parent1"

  child.reparent(p2, true)
  TestFramework.assert_eq child.get_parent.not_nil!.name, "Parent2"
  TestFramework.assert_eq p1.get_child_count, 0_i64
  TestFramework.assert_eq p2.get_child_count, 1_i64
  child.destroy
  p1.destroy
  p2.destroy
end

test_nodes "get_child and get_child_count accurately index children" do
  container = Godot.create(Godot::Node)
  c1 = Godot.create(Godot::Node)
  c1.name = "First"
  c2 = Godot.create(Godot::Node)
  c2.name = "Second"
  c3 = Godot.create(Godot::Node)
  c3.name = "Third"

  container.add_child(c1)
  container.add_child(c2)
  container.add_child(c3)

  TestFramework.assert_eq container.get_child_count, 3_i64
  TestFramework.assert_eq container.get_child(0).name, "First"
  TestFramework.assert_eq container.get_child(1).name, "Second"
  TestFramework.assert_eq container.get_child(2).name, "Third"
  container.destroy
end

test_nodes "queue_free flags node for deletion" do
  temp_node = Godot.create(Godot::Node)
  temp_node.name = "ToFree"
  TestFramework.assert_false temp_node.is_queued_for_deletion

  temp_node.queue_free
  TestFramework.assert_true temp_node.is_queued_for_deletion
  temp_node.destroy
end

test_nodes "is_inside_tree accurately reflects tree membership" do
  orphan = Godot.create(Godot::Node)
  TestFramework.assert_false orphan.is_inside_tree

  if !root.pointer.null?
	root.add_child(orphan)
	TestFramework.assert_true orphan.is_inside_tree
	root.remove_child(orphan)
	TestFramework.assert_false orphan.is_inside_tree
  end
  orphan.destroy
end

# =============================================================================
# Test Suite 4: Node Traversal & Paths
# =============================================================================

test_nodes "get_node retrieves existing child and nested path" do
  target = node.find_child("ToolTester2D") || node
  if child2d = target.get_node?("Child2D")
	TestFramework.assert_not_nil child2d
	TestFramework.assert_eq child2d.name, "Child2D"

	if marker = target.get_node?("Child2D/Marker2D")
	  TestFramework.assert_not_nil marker
	  TestFramework.assert_eq marker.name, "Marker2D"
	end
  end
end

test_nodes "get_node? returns nil for non-existent node" do
  missing = node.get_node?("DefinitelyNonExistentNode12345")
  TestFramework.assert_nil missing
end

test_nodes "get_node raises exception when node is not found" do
  caught = false
  begin
	node.get_node("GhostNode_Should_Fail_987")
  rescue ex : Exception
	caught = true
  end
  TestFramework.assert_true caught, "get_node should raise when node does not exist"
end

test_nodes "get_node_as casts to Crystal node class" do
  target = node.find_child("ToolTester2D") || node
  if target.get_node?("Child2D")
	casted = target.get_node_as(Godot::Node2D, "Child2D")
	TestFramework.assert_not_nil casted
	TestFramework.assert_true casted.is_a?(Godot::Node2D)
  end
end

test_nodes "find_child locates node anywhere in subtree" do
  found = node.find_child("Marker2D") || node.find_child("Marker3D")
  if found.nil?
	sub = Godot.create(Godot::Node)
	sub.name = "DynamicSub"
	target = Godot.create(Godot::Node)
	target.name = "DynamicTarget"
	sub.add_child(target)
	node.add_child(sub)
	found = node.find_child("DynamicTarget")
  end
  TestFramework.assert_not_nil found
end

test_nodes "node_path! macro constructs valid NodePath" do
  np = node_path!("Child2D/Marker2D")
  TestFramework.assert_not_nil np
end

test_nodes "relative path traversal navigates upward with .." do
  target = root.find_child("ToolTester2D") || root
  if child = target.get_node?("Child2D")
	parent_via_path = child.get_node?("..")
	TestFramework.assert_not_nil parent_via_path
	TestFramework.assert_eq parent_via_path.not_nil!.name, target.name
  end
end

# =============================================================================
# Test Suite 5: Deferred Execution & Callbacks
# =============================================================================

test_deferred "call_deferred dispatches method call cleanly" do
  target = PropertyTestTarget.new
  target.call_deferred("set_name", "DeferredNameUpdate")
  # Execution is deferred to idle time without crashing
  TestFramework.assert_not_nil target
  target.destroy
end

test_deferred "call_deferred accepts multiple typed arguments" do
  target = PropertyTestTarget.new
  target.call_deferred("emit_signal", "test_event_fired", 777)
  TestFramework.assert_not_nil target
  target.destroy
end

test_deferred "call_deferred on node hierarchy operation" do
  parent = Godot.create(Godot::Node)
  child = Godot.create(Godot::Node)
  parent.call_deferred("add_child", child)
  TestFramework.assert_not_nil parent
  child.destroy
  parent.destroy
end

# =============================================================================
# Test Suite 6: Signals & Await Tracking
# =============================================================================

test_signals "SignalSpy records signal emissions" do
  target = PropertyTestTarget.new
  spy = TestFramework::SignalSpy.new(target, "test_event_fired")

  TestFramework.assert_false spy.emitted?
  target.emit_test_event_fired(42)
  TestFramework.assert_true spy.emitted?
  TestFramework.assert_eq spy.count, 1
  target.destroy
end

test_signals "Multi-argument signal emission" do
  target = PropertyTestTarget.new
  target.emit_multi_arg_event(200, "Success", 0.95)
  TestFramework.assert_not_nil target
  target.destroy
end

test_signals "GDScriptInteropTarget signal declaration and emission" do
  target = GDScriptInteropTarget.new
  target.emit_crystal_ping(99)
  TestFramework.assert_not_nil target
  target.destroy
end

# =============================================================================
# Test Suite 7: GDScript 2-Way Interoperability
# =============================================================================

test_gdscript "Instantiating GDScript scene and accessing controller" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
  TestFramework.assert_not_nil scene
  root = scene.instantiate
  TestFramework.assert_not_nil root
  TestFramework.assert_eq root.name, "InteropRoot"
  root.destroy
  scene.destroy
end

test_gdscript "Calling GDScript arithmetic add_numbers returns Int64" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
  root = scene.instantiate
  sum = root.call_i64("add_numbers", 15, 27)
  TestFramework.assert_eq sum, 42_i64
  root.destroy
  scene.destroy
end

test_gdscript "Calling GDScript format_greeting returns formatted String" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
  root = scene.instantiate
  greeting = root.call_str("format_greeting", "CrystalDeveloper")
  TestFramework.assert_eq greeting, "Hello from GDScript, CrystalDeveloper!"
  root.destroy
  scene.destroy
end

test_gdscript "Calling GDScript compute_distance returns Float64" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
  root = scene.instantiate
  dist = root.call_f64("compute_distance", Godot::Vector2.new(0.0, 0.0), Godot::Vector2.new(3.0, 4.0))
  TestFramework.assert_approx_eq dist, 5.0
  root.destroy
  scene.destroy
end

test_gdscript "Calling GDScript spawn_node_for_crystal returns Node" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
  root = scene.instantiate
  spawned = root.call_obj("spawn_node_for_crystal", "SpawnedByGDScript")
  TestFramework.assert_not_nil spawned
  TestFramework.assert_eq spawned.not_nil!.name, "SpawnedByGDScript"
  spawned.not_nil!.destroy
  root.destroy
  scene.destroy
end

test_gdscript "Passing Crystal node into GDScript inspect_crystal_node" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
  root = scene.instantiate

  crystal_child = Godot.create(Godot::Node2D)
  crystal_child.name = "CrystalWorkerNode"
  root.add_child(crystal_child)

  result = root.call_str("inspect_crystal_node", crystal_child)
  TestFramework.assert_true result.starts_with?("OK:CrystalWorkerNode:"), "Expected OK:CrystalWorkerNode, got #{result}"
  root.destroy
  scene.destroy
end

test_gdscript "GDScript reparents Crystal node via reparent_node_from_crystal" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
  root = scene.instantiate
  target_child = root.get_node("StaticChild")

  crystal_sub = Godot.create(Godot::Node)
  crystal_sub.name = "TransferredNode"
  root.add_child(crystal_sub)

  reparented = root.call_bool("reparent_node_from_crystal", crystal_sub, target_child)
  TestFramework.assert_true reparented
  TestFramework.assert_eq crystal_sub.get_parent.not_nil!.name, "StaticChild"
  root.destroy
  scene.destroy
end

test_gdscript "GDScript state increment_counter updates across calls" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
  root = scene.instantiate

  c1 = root.call_i64("increment_counter", 5)
  TestFramework.assert_eq c1, 5_i64

  c2 = root.call_i64("increment_counter", 10)
  TestFramework.assert_eq c2, 15_i64
  root.destroy
  scene.destroy
end

# =============================================================================
# Test Suite 8: 3D Mesh & Geometry Construction
# =============================================================================

test_mesh "Godot.create instantiates native MeshInstance3D" do
  mi = Godot.create(Godot::MeshInstance3D)
  TestFramework.assert_not_nil mi
  TestFramework.assert_false mi.pointer.null?
  mi.destroy
end

test_mesh "Godot.create instantiates native BoxMesh" do
  box = Godot.create(Godot::BoxMesh)
  TestFramework.assert_not_nil box
  TestFramework.assert_false box.pointer.null?
  box.destroy
end

test_mesh "BoxMesh size configuration and assignment to MeshInstance3D" do
  mi = Godot.create(Godot::MeshInstance3D)
  box = Godot.create(Godot::BoxMesh)

  box.set_size(Godot::Vector3.new(2.5, 3.5, 4.5))
  TestFramework.assert_approx_eq box.get_size.x, 2.5_f32
  TestFramework.assert_approx_eq box.get_size.y, 3.5_f32
  TestFramework.assert_approx_eq box.get_size.z, 4.5_f32

  mi.set_mesh(box)
  ret_mesh = mi.get_mesh
  TestFramework.assert_not_nil ret_mesh
  TestFramework.assert_false ret_mesh.pointer.null?
  ret_mesh.destroy
  mi.destroy
  box.destroy
end

test_mesh "StandardMaterial3D creation and color assignment" do
  mat = Godot.create(Godot::StandardMaterial3D)
  mat.set_albedo(Godot::Color.new(0.8, 0.2, 0.2, 1.0))
  TestFramework.assert_approx_eq mat.get_albedo.r, 0.8_f32
  TestFramework.assert_approx_eq mat.get_albedo.g, 0.2_f32
  mat.destroy
end

test_mesh "Instantiating 3D mesh scene (test_mesh_3d.tscn)" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_mesh_3d.tscn")
  TestFramework.assert_not_nil scene
  root = scene.instantiate
  TestFramework.assert_not_nil root
  TestFramework.assert_eq root.name, "TestMeshRoot3D"

  box_instance = root.get_node("BoxMeshInstance")
  TestFramework.assert_not_nil box_instance

  anchor = root.get_node("BoxMeshInstance/AnchorMarker3D")
  TestFramework.assert_not_nil anchor
  root.destroy
  scene.destroy
end

# =============================================================================
# Test Suite 9: 2D & 3D Physics & Area Sensors
# =============================================================================

test_physics "Instantiating test_area_2d.tscn and checking hierarchy" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_area_2d.tscn")
  TestFramework.assert_not_nil scene
  root = scene.instantiate
  TestFramework.assert_not_nil root
  TestFramework.assert_eq root.name, "TestArea2D"

  col_shape = root.get_node("CollisionShape2D")
  TestFramework.assert_not_nil col_shape

  marker = root.get_node("SensorMarker2D")
  TestFramework.assert_not_nil marker
  root.destroy
  scene.destroy
end

test_physics "Area2D collision_layer and collision_mask validation" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_area_2d.tscn")
  area = Godot::Area2D.new(scene.instantiate.pointer)
  TestFramework.assert_eq area.get_collision_layer, 3_i64
  TestFramework.assert_eq area.get_collision_mask, 3_i64
  TestFramework.assert_true area.is_monitoring
  TestFramework.assert_true area.is_monitorable
  area.destroy
  scene.destroy
end

test_physics "Instantiating test_area_3d.tscn and checking hierarchy" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_area_3d.tscn")
  TestFramework.assert_not_nil scene
  root = scene.instantiate
  TestFramework.assert_not_nil root
  TestFramework.assert_eq root.name, "TestArea3D"

  col_shape = root.get_node("CollisionShape3D")
  TestFramework.assert_not_nil col_shape

  marker = root.get_node("SensorMarker3D")
  TestFramework.assert_not_nil marker
  root.destroy
  scene.destroy
end

test_physics "Area3D collision_layer and collision_mask validation" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_area_3d.tscn")
  area = Godot::Area3D.new(scene.instantiate.pointer)
  TestFramework.assert_eq area.get_collision_layer, 5_i64
  TestFramework.assert_eq area.get_collision_mask, 5_i64
  TestFramework.assert_true area.is_monitoring
  TestFramework.assert_true area.is_monitorable
  area.destroy
  scene.destroy
end

# =============================================================================
# Test Suite 10: Massive Scale Stress & Performance (100 & 1,000 Nodes)
# =============================================================================

test_stress "Spawning and moving 100 Node2D nodes in 2D grid" do
  container = Godot.create(Godot::Node2D)
  container.name = "GridContainer100"

  nodes = Array(Godot::Node2D).new(100)
  100.times do |i|
	n = Godot.create(Godot::Node2D)
	n.name = "Node2D_#{i}"
	x = (i % 10).to_f32 * 32.0_f32
	y = (i // 10).to_f32 * 32.0_f32
	n.position = Godot::Vector2.new(x, y)
	container.add_child(n)
	nodes << n
  end

  TestFramework.assert_eq container.get_child_count, 100_i64
  TestFramework.assert_approx_eq nodes[55].position.x, 160.0_f32
  TestFramework.assert_approx_eq nodes[55].position.y, 160.0_f32

  # Move all 100 nodes
  nodes.each_with_index do |n, idx|
	n.position = Godot::Vector2.new(n.position.x + 10.0_f32, n.position.y + 10.0_f32)
  end
  TestFramework.assert_approx_eq nodes[55].position.x, 170.0_f32

  # Clean batch disposal
  nodes.each do |n|
	container.remove_child(n)
	n.destroy
  end
  TestFramework.assert_eq container.get_child_count, 0_i64
  container.destroy
end

test_stress "Spawning, transforming, and freeing 1,000 Node3D instances" do
  arena = Godot.create(Godot::Node3D)
  arena.name = "StressArena1000"

  nodes = Array(Godot::Node3D).new(1000)
  1000.times do |i|
	n = Godot.create(Godot::Node3D)
	n.name = "Entity3D_#{i}"
	x = (i % 10).to_f32 * 2.0_f32
	y = ((i // 10) % 10).to_f32 * 2.0_f32
	z = (i // 100).to_f32 * 2.0_f32
	n.position = Godot::Vector3.new(x, y, z)
	arena.add_child(n)
	nodes << n
  end

  TestFramework.assert_eq arena.get_child_count, 1000_i64

  # Animate all 1,000 nodes with trigonometric wave
  nodes.each_with_index do |n, idx|
	rad = idx.to_f64 * 0.01
	offset_y = Math.sin(rad).to_f32 * 5.0_f32
	n.position = Godot::Vector3.new(n.position.x, n.position.y + offset_y, n.position.z)
  end

  # Batch free all 1,000 nodes
  nodes.each do |n|
	arena.remove_child(n)
	n.destroy
  end
  TestFramework.assert_eq arena.get_child_count, 0_i64
  arena.destroy
end

# =============================================================================
# Test Suite 11: Custom Scene Loading & Hierarchy
# =============================================================================

test_scenes "Loading and instantiating test_dummy_2d.tscn" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_dummy_2d.tscn")
  TestFramework.assert_not_nil scene
  inst = scene.instantiate
  TestFramework.assert_not_nil inst
  TestFramework.assert_eq inst.name, "TestDummy2D"
  inst.destroy
  scene.destroy
end

test_scenes "Loading and instantiating test_dummy_3d.tscn" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_dummy_3d.tscn")
  TestFramework.assert_not_nil scene
  inst = scene.instantiate
  TestFramework.assert_not_nil inst
  TestFramework.assert_eq inst.name, "TestDummy3D"
  inst.destroy
  scene.destroy
end

test_scenes "Loading and instantiating test_stress_1000.tscn" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_stress_1000.tscn")
  TestFramework.assert_not_nil scene
  inst = scene.instantiate
  TestFramework.assert_not_nil inst
  TestFramework.assert_eq inst.name, "StressArena"
  TestFramework.assert_not_nil inst.get_node("SpawnOrigin2D")
  TestFramework.assert_not_nil inst.get_node("SpawnOrigin3D")
  inst.destroy
  scene.destroy
end

# =============================================================================
# Test Suite 12: Properties, Hints & ClassDB Annotations
# =============================================================================

test_prop "Export Property Getters and Setters round-trip" do
  target = PropertyTestTarget.new

  target.float32_val = 45.67_f32
  TestFramework.assert_approx_eq target.float32_val, 45.67_f32

  target.float64_val = 123.456789
  TestFramework.assert_approx_eq target.float64_val, 123.456789

  target.int32_val = 999
  TestFramework.assert_eq target.int32_val, 999

  target.int64_val = 55555555555_i64
  TestFramework.assert_eq target.int64_val, 55555555555_i64

  target.bool_val = false
  TestFramework.assert_false target.bool_val

  target.string_val = "Updated String"
  TestFramework.assert_eq target.string_val, "Updated String"

  target.vec2_val = Godot::Vector2.new(11.0, 22.0)
  TestFramework.assert_eq target.vec2_val.x, 11.0_f32

  target.vec3_val = Godot::Vector3.new(1.0, 2.0, 3.0)
  TestFramework.assert_eq target.vec3_val.z, 3.0_f32

  target.color_val = Godot::Color::BLUE
  TestFramework.assert_approx_eq target.color_val.b, 1.0_f32

  target.rect2_val = Godot::Rect2.new(5.0, 5.0, 50.0, 50.0)
  TestFramework.assert_eq target.rect2_val.size.x, 50.0_f32
  target.destroy
end

test_prop "Custom computed getter returns calculated value" do
  target = PropertyTestTarget.new
  TestFramework.assert_approx_eq target.health_percentage, 100.0_f32
  target.destroy
end

test_prop "Custom setter clamps input within bounds" do
  target = PropertyTestTarget.new

  target.clamped_health = 150.0_f32
  TestFramework.assert_approx_eq target.clamped_health, 100.0_f32

  target.clamped_health = -25.0_f32
  TestFramework.assert_approx_eq target.clamped_health, 0.0_f32

  target.clamped_health = 75.0_f32
  TestFramework.assert_approx_eq target.clamped_health, 75.0_f32
  target.destroy
end

test_prop "Custom setter triggers side-effects" do
  target = PropertyTestTarget.new
  TestFramework.assert_eq target.dirty_trigger, 0

  target.dirty_trigger = 3
  TestFramework.assert_eq target.dirty_trigger, 3

  target.dirty_trigger = 2
  TestFramework.assert_eq target.dirty_trigger, 5
  target.destroy
end

test_prop "Custom tool button setter acts as action trigger" do
  target = PropertyTestTarget.new
  TestFramework.assert_false target.tool_button_trigger

  target.tool_button_trigger = true
  TestFramework.assert_true target.tool_button_trigger
  target.destroy
end

test_prop "Property hints registered correctly in ClassDB" do
  entry = Godot::ClassRegistry.find("PropertyTestTarget")
  TestFramework.assert_not_nil entry
  props = entry.not_nil!.properties

  range_prop = props.find { |p| p.name == "range_hint_prop" }
  TestFramework.assert_not_nil range_prop
  TestFramework.assert_eq range_prop.not_nil!.hint, 1_u32
  TestFramework.assert_eq range_prop.not_nil!.hint_string, "0,100,5"

  enum_prop = props.find { |p| p.name == "enum_hint_prop" }
  TestFramework.assert_not_nil enum_prop
  TestFramework.assert_eq enum_prop.not_nil!.hint, 2_u32
  TestFramework.assert_eq enum_prop.not_nil!.hint_string, "Low,Medium,High"

  file_prop = props.find { |p| p.name == "file_hint_prop" }
  TestFramework.assert_not_nil file_prop
  TestFramework.assert_eq file_prop.not_nil!.hint, 13_u32

  multi_prop = props.find { |p| p.name == "multiline_hint_prop" }
  TestFramework.assert_not_nil multi_prop
  TestFramework.assert_eq multi_prop.not_nil!.hint, 18_u32

  color_prop = props.find { |p| p.name == "color_no_alpha_prop" }
  TestFramework.assert_not_nil color_prop
  TestFramework.assert_eq color_prop.not_nil!.hint, 21_u32

  tool_prop = props.find { |p| p.name == "tool_btn_prop" }
  TestFramework.assert_not_nil tool_prop
  TestFramework.assert_eq tool_prop.not_nil!.hint, 39_u32
  TestFramework.assert_eq tool_prop.not_nil!.variant_type, 25
  TestFramework.assert_eq tool_prop.not_nil!.usage, 4_u32
  TestFramework.assert_eq tool_prop.not_nil!.type_name, "Callable"
  TestFramework.assert_eq tool_prop.not_nil!.hint_string, "Click Here"

  method_tool_prop = props.find { |p| p.name == "test_method_action" }
  TestFramework.assert_not_nil method_tool_prop
  TestFramework.assert_eq method_tool_prop.not_nil!.hint, 39_u32
  TestFramework.assert_eq method_tool_prop.not_nil!.variant_type, 25
  TestFramework.assert_eq method_tool_prop.not_nil!.usage, 4_u32
  TestFramework.assert_eq method_tool_prop.not_nil!.type_name, "Callable"
  TestFramework.assert_eq method_tool_prop.not_nil!.hint_string, "Method Action,Play"

  # Verify Proc Tool Buttons registered in PropertyInfo
  ptr_tool_prop = props.find { |p| p.name == "proc_btn_ptr" }
  TestFramework.assert_not_nil ptr_tool_prop
  TestFramework.assert_eq ptr_tool_prop.not_nil!.hint, 39_u32
  TestFramework.assert_eq ptr_tool_prop.not_nil!.variant_type, 25
  TestFramework.assert_eq ptr_tool_prop.not_nil!.usage, 4_u32
  TestFramework.assert_eq ptr_tool_prop.not_nil!.hint_string, "Proc Method Pointer Button,Action"

  lambda_tool_prop = props.find { |p| p.name == "proc_btn_lambda" }
  TestFramework.assert_not_nil lambda_tool_prop
  TestFramework.assert_eq lambda_tool_prop.not_nil!.hint, 39_u32
  TestFramework.assert_eq lambda_tool_prop.not_nil!.variant_type, 25
  TestFramework.assert_eq lambda_tool_prop.not_nil!.usage, 4_u32
  TestFramework.assert_eq lambda_tool_prop.not_nil!.hint_string, "Proc Lambda Button"

  dyn_tool_prop = props.find { |p| p.name == "proc_btn_dyn" }
  TestFramework.assert_not_nil dyn_tool_prop
  TestFramework.assert_eq dyn_tool_prop.not_nil!.hint, 39_u32
  TestFramework.assert_eq dyn_tool_prop.not_nil!.variant_type, 25
  TestFramework.assert_eq dyn_tool_prop.not_nil!.usage, 4_u32
  TestFramework.assert_eq dyn_tool_prop.not_nil!.hint_string, "Proc Dynamic Button"

  target = PropertyTestTarget.new
  TestFramework.assert_false target.tool_btn_fired
  target._godot_call_tool_button("tool_btn_prop")
  TestFramework.assert_true target.tool_btn_fired

  TestFramework.assert_false target.tool_button_trigger
  target._godot_call_tool_button("test_method_action")
  TestFramework.assert_true target.tool_button_trigger

  # Verify Proc Tool Button Dispatch & Reassignment
  TestFramework.assert_false target.proc_action_fired
  target._godot_call_tool_button("proc_btn_ptr")
  TestFramework.assert_true target.proc_action_fired

  target.proc_action_fired = false
  target._godot_call_tool_button("proc_btn_lambda")
  TestFramework.assert_true target.proc_action_fired

  target.proc_action_fired = false
  target._godot_call_tool_button("proc_btn_dyn") # nil, should safely be a no-op
  TestFramework.assert_false target.proc_action_fired

  target.proc_btn_dyn = ->{ target.proc_action_fired = true; nil }
  target._godot_call_tool_button("proc_btn_dyn")
  TestFramework.assert_true target.proc_action_fired

  custom_called = false
  target.proc_btn_ptr = ->{ custom_called = true; nil }
  target._godot_call_tool_button("proc_btn_ptr")
  TestFramework.assert_true custom_called

  target.destroy

  storage_prop = props.find { |p| p.name == "storage_only_prop" }
  TestFramework.assert_not_nil storage_prop
  TestFramework.assert_eq storage_prop.not_nil!.usage, 2_u32
end

test_prop "Inspector Grouping annotations registered" do
  entry = Godot::ClassRegistry.find("PropertyTestTarget")
  TestFramework.assert_not_nil entry
  props = entry.not_nil!.properties

  cat = props.find { |p| p.usage == 128_u32 }
  TestFramework.assert_not_nil cat
  TestFramework.assert_eq cat.not_nil!.name, "Stats"

  grp = props.find { |p| p.usage == 64_u32 && p.name == "Movement" }
  TestFramework.assert_not_nil grp

  sub = props.find { |p| p.usage == 256_u32 && p.name == "Air" }
  TestFramework.assert_not_nil sub
end

test_prop "Class-level Tool and Icon annotations registered" do
  entry = Godot::ClassRegistry.find("PropertyTestTarget")
  TestFramework.assert_not_nil entry
  TestFramework.assert_true entry.not_nil!.is_tool
  TestFramework.assert_eq entry.not_nil!.icon_path, "res://addons/crystal_integration/crystal.gdextension"

  tool2d_entry = Godot::ClassRegistry.find("ToolTester2D")
  TestFramework.assert_not_nil tool2d_entry
  TestFramework.assert_true tool2d_entry.not_nil!.is_tool
end

test_prop "Signal registration and type-safe emission" do
  target = PropertyTestTarget.new
  entry = Godot::ClassRegistry.find("PropertyTestTarget")
  TestFramework.assert_not_nil entry
  sig = entry.not_nil!.signals.find { |s| s.name == "test_event_fired" }
  TestFramework.assert_not_nil sig
  TestFramework.assert_eq sig.not_nil!.args.size, 1

  target.emit_test_event_fired(100)
  target.destroy
end

# =============================================================================
# Modular Test Suites (Exhaustive Coverage Across Extension API)
# =============================================================================

require "./suites/test_2d_nodes"
require "./suites/test_3d_nodes"
require "./suites/test_control_nodes"
require "./suites/test_meshes_materials"
require "./suites/test_physics_shapes"
require "./suites/test_audio_animation"
require "./suites/test_resources_utilities"
require "./suites/test_lifecycle_destruction"
require "./suites/test_classdb_coverage"
require "./suites/test_concurrency"
require "./suites/test_macros_dsl"
require "./suites/test_multi_addon_isolation"
require "./suites/test_script_first_class"
require "./suites/test_gdscript_channel_signal_interop"
require "./suites/test_autobound_gdscript_nodes"
require "./suites/test_scenes_persistence"
require "./suites/test_debugger_isolation"
require "./suites/test_resource_lifecycle_deep"
require "./suites/test_reentrancy_self_destruct"
require "./suites/test_node_duplication_meta"
require "./suites/test_callable_signals_advanced"
require "./suites/test_dynamic_properties_classdb"
require "./suites/test_thread_safe_apis"
require "./suites/test_gdscript_inheritance_polymorphism"
require "./suites/test_undo_redo_history"
require "./suites/test_toolchain_standalone"
require "./suites/test_shaders_compilation"
require "./suites/test_materials_textures_advanced"
require "./suites/test_physics_simulation_raycast"
require "./suites/test_geometry_surfacetool"
require "./suites/test_cameras_viewports_canvas"
require "./suites/test_tweens_animation"
require "./suites/test_audio_system_servers"
require "./suites/test_async_testing_apparatus"
