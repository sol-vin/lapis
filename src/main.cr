# =============================================================================
# Lapis Test Runner Application & Suite Entry Point (Root Host)
# =============================================================================

require "./lapis"
require "./generated/project_nodes/all_project_nodes"
require "../spec/fixtures/test_target_nodes"

include Lapis::Test

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

    results = Registry.run_category("2D", self)
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
      Godot::SystemIO.write_file("bin/.tool_tests_passed", "All #{total}/#{total} Tests Passed!\n")
      Godot::SystemIO.write_file(".tool_tests_passed", "All #{total}/#{total} Tests Passed!\n")
      Godot::SystemIO.delete_file(".tool_tests_failed") if Godot::SystemIO.file_exists?(".tool_tests_failed")
      Godot::SystemIO.delete_file("bin/.tool_tests_failed") if Godot::SystemIO.file_exists?("bin/.tool_tests_failed")
    else
      @test_status = "Failed: #{total - passed}/#{total} Errors"
      Godot.printerr("[ToolTester2D] FAILED: #{total - passed} test(s) failed.")
      Godot::SystemIO.write_file(".tool_tests_failed", "Failed: #{total - passed} test(s) failed.\n")
      Godot::SystemIO.write_file("bin/.tool_tests_failed", "Failed: #{total - passed} test(s) failed.\n")
      Godot::SystemIO.delete_file(".tool_tests_passed") if Godot::SystemIO.file_exists?(".tool_tests_passed")
      Godot::SystemIO.delete_file("bin/.tool_tests_passed") if Godot::SystemIO.file_exists?("bin/.tool_tests_passed")
    end

    begin
      Lapis::Test::JUnitExporter.generate(results, "bin/junit_tool_2d.xml")
      Lapis::Test::JUnitExporter.generate(results, "junit_tool_2d.xml")
    rescue
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

    results = Registry.run_category("3D", self)
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
      Godot::SystemIO.write_file("bin/.tool_tests_passed", "All #{total}/#{total} Tests Passed!\n")
      Godot::SystemIO.write_file(".tool_tests_passed", "All #{total}/#{total} Tests Passed!\n")
      Godot::SystemIO.delete_file(".tool_tests_failed") if Godot::SystemIO.file_exists?(".tool_tests_failed")
      Godot::SystemIO.delete_file("bin/.tool_tests_failed") if Godot::SystemIO.file_exists?("bin/.tool_tests_failed")
    else
      @test_status = "Failed: #{total - passed}/#{total} Errors"
      Godot.printerr("[ToolTester3D] FAILED: #{total - passed} test(s) failed.")
      Godot::SystemIO.write_file(".tool_tests_failed", "Failed: #{total - passed} test(s) failed.\n")
      Godot::SystemIO.write_file("bin/.tool_tests_failed", "Failed: #{total - passed} test(s) failed.\n")
      Godot::SystemIO.delete_file(".tool_tests_passed") if Godot::SystemIO.file_exists?(".tool_tests_passed")
      Godot::SystemIO.delete_file("bin/.tool_tests_passed") if Godot::SystemIO.file_exists?("bin/.tool_tests_passed")
    end

    begin
      Lapis::Test::JUnitExporter.generate(results, "bin/junit_tool_3d.xml")
      Lapis::Test::JUnitExporter.generate(results, "junit_tool_3d.xml")
    rescue
    end
  end
end

# =============================================================================
# Crystal Benchmark Runner Node (In-Engine 1-to-1 Performance Testing)
# =============================================================================

@[Tool]
node CrystalBenchmarkRunner < Godot::Node do
  @[Export]
  property node_count : Int32 = 20000

  @[Export]
  property mat_count : Int32 = 10000

  @[Export]
  property sig_count : Int32 = 50000

  @[Export]
  property node_bench_time : Float64 = 0.0

  @[Export]
  property mat_bench_time : Float64 = 0.0

  @[Export]
  property sig_bench_time : Float64 = 0.0

  @[Export]
  property run_all_benchmarks : Bool = false

  def run_all_benchmarks=(val : Bool)
    return unless val
    @node_bench_time = bench_node_lifecycle(@node_count.to_i64)
    @mat_bench_time = bench_material_resources(@mat_count.to_i64)
    @sig_bench_time = bench_signals(@sig_count.to_i64)
  end

  # 1. Node Lifecycle
  def bench_node_lifecycle(count : Int64) : Float64
    root = Godot.create(Godot::Node2D)
    start_time = ::Time.instant

    count.times do |i|
      child = Godot.create(Godot::Node2D)
      child.set_position(Godot::Vector2.new(i.to_f32, (i * 2).to_f32))
      child.set_rotation(0.5_f64)
      child.set_scale(Godot::Vector2.new(1.5_f32, 1.5_f32))
      child.set_visible(true)
      root.add_child(child)
      root.remove_child(child)
      child.destroy
    end

    dur = (::Time.instant - start_time).total_milliseconds
    root.destroy
    dur
  end

  # 2. Material & Resources Allocation
  def bench_material_resources(count : Int64) : Float64
    start_time = ::Time.instant
    materials = Array(Godot::StandardMaterial3D).new(count.to_i)

    count.times do
      mat = Godot.create(Godot::StandardMaterial3D)
      mat.set_albedo(Godot::Color.new(0.2, 0.5, 0.8, 1.0))
      mat.set_roughness(0.35_f64)
      mat.set_metallic(0.75_f64)
      mat.set_feature(Godot::BaseMaterial3D::Feature::FeatureEmission, true)
      mat.set_emission(Godot::Color.new(1.0, 0.9, 0.1, 1.0))
      dup = mat.call("duplicate")
      materials << mat
    end

    dur = (::Time.instant - start_time).total_milliseconds
    materials.clear
    dur
  end

  # 3. Signals Connection & Emission
  def bench_signals(count : Int64) : Float64
    emitter = Godot.create(Godot::Node)
    received = 0_i64

    emitter.signal("renamed").connect do
      received += 1
    end

    start_time = ::Time.instant
    count.times do
      emitter.call("emit_signal", "renamed")
    end

    dur = (::Time.instant - start_time).total_milliseconds
    emitter.destroy
    dur
  end

  # 4. Transform Math
  def bench_transform_math(count : Int64) : Float64
    start_time = ::Time.instant
    t = Godot::Transform3D::IDENTITY
    v = Godot::Vector3.new(1.0_f32, 2.0_f32, 3.0_f32)
    axis = Godot::Vector3.new(0.0_f32, 1.0_f32, 0.0_f32)
    sum = 0.0_f64

    count.times do
      t = t.translated(v * 0.001_f32)
      t = t.rotated(axis, 0.005_f64)
      proj = t * v
      sum += (proj.x + proj.y + proj.z).to_f64
    end

    dur = (::Time.instant - start_time).total_milliseconds
    dur
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
    Godot.print("    Lapis Interactive Test Runner Loaded (Two-Click Testing)   ")
    Godot.print("==================================================================")

    # Master "Run All" button
    hook_button("MarginContainer/VBox/ButtonBox/BtnRunAll") { run_and_display_all }

    # Dynamically build and connect category buttons from Registry.categories
    unless Godot.editor_hint?
      if button_box = get_node?("MarginContainer/VBox/ButtonBox")
        Registry.categories.sort.each do |cat|
          btn_name = "BtnRun#{cat.gsub(/[^a-zA-Z0-9]/, "")}"
          btn_path = "MarginContainer/VBox/ButtonBox/#{btn_name}"
          target_cat = cat
          if existing_btn = get_node?(btn_path)
            hook_button(btn_path) { run_and_display_category(target_cat) }
          else
            btn = Godot.create(Godot::Button)
            btn.name = btn_name
            btn.text = cat
            button_box.call_deferred("add_child", btn)
            btn.signal("pressed").connect do
              run_and_display_category(target_cat)
            end
          end
        end
      end
    end

    # Automatically execute all tests on startup only in game runtime (not editor workspace)
    run_and_display_all unless Godot.editor_hint?
  end

  def hook_button(path : String, &callback)
    if btn = get_node?(path)
      btn.signal("pressed").connect do
        callback.call
      end
    end
  end

  def cli_filter : String?
    if edit = get_node?("MarginContainer/VBox/FilterBox/FilterInput")
      txt = edit.call_str("get_text").strip
      return txt unless txt.empty?
    end
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
    results = Registry.run_category(category, self, filter: filter)
    display_results(results, category)
  end

  def run_and_display_all : Void
    return if @@is_running_tests
    @@is_running_tests = true
    begin
      filter = cli_filter
      category = cli_category
      results = Registry.run_all(self, filter: filter, category_filter: category)
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

  def display_results(results : Array(TestResult), suite_label : String)
    passed = results.count(&.passed)
    total = results.size

    Godot.print("\n=== Lapis Test Results [#{suite_label}]: #{passed}/#{total} Passed ===")
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
      lines << "[b]=== Lapis Test Execution Suite: #{suite_label} ===[/b]"
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
        if passed == total
          Godot::SystemIO.write_file(".runtime_tests_passed", "PASSED\n") rescue nil
          Godot::SystemIO.write_file("bin/.runtime_tests_passed", "PASSED\n") rescue nil
          Godot::SystemIO.delete_file(".runtime_tests_failed") if Godot::SystemIO.file_exists?(".runtime_tests_failed")
          Godot::SystemIO.delete_file("bin/.runtime_tests_failed") if Godot::SystemIO.file_exists?("bin/.runtime_tests_failed")
        else
          failed_lines = results.reject(&.passed).map { |r| "FAILED: [#{r.category}] #{r.name} - #{r.message}" }.join("\n")
          Godot::SystemIO.write_file(".runtime_tests_failed", "FAILED: #{total - passed} test(s) failed\n#{failed_lines}\n") rescue nil
          Godot::SystemIO.write_file("bin/.runtime_tests_failed", "FAILED: #{total - passed} test(s) failed\n#{failed_lines}\n") rescue nil
          Godot::SystemIO.delete_file(".runtime_tests_passed") if Godot::SystemIO.file_exists?(".runtime_tests_passed")
          Godot::SystemIO.delete_file("bin/.runtime_tests_passed") if Godot::SystemIO.file_exists?("bin/.runtime_tests_passed")
        end

        if junit_path = extract_cli_arg("--junit")
          Lapis::Test::JUnitExporter.generate(results, junit_path) rescue nil
        end
        Lapis::Test::JUnitExporter.generate(results, "junit.xml") rescue nil
        Lapis::Test::JUnitExporter.generate(results, "bin/junit.xml") rescue nil
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
    return true if ENV["CI"]? == "true" || ENV["GITHUB_ACTIONS"]? == "true"
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
# Modular Test Suites (Exhaustive Coverage Across Extension API)
# =============================================================================

# Core and Built-ins
require "../spec/suites/test_core_builtins"
require "../spec/suites/test_2d_nodes"
require "../spec/suites/test_3d_nodes"
require "../spec/suites/test_control_nodes"
require "../spec/suites/test_node_hierarchy"
require "../spec/suites/test_deferred_execution"
require "../spec/suites/test_scale_stress"

# Graphics, Meshes, Shaders & Materials
require "../spec/suites/test_meshes_materials"
require "../spec/suites/test_shaders_compilation"
require "../spec/suites/test_materials_textures_advanced"
require "../spec/suites/test_geometry_surfacetool"
require "../spec/suites/test_cameras_viewports_canvas"

# Physics, Collision & Raycasting
require "../spec/suites/test_physics_shapes"
require "../spec/suites/test_physics_simulation_raycast"

# Audio, Animation & Tweens
require "../spec/suites/test_audio_animation"
require "../spec/suites/test_audio_system_servers"
require "../spec/suites/test_tweens_animation"

# Resources, Scenes & Persistence
require "../spec/suites/test_resources_utilities"
require "../spec/suites/test_scenes_persistence"
require "../spec/suites/test_resource_lifecycle_deep"

# Lifecycle, Dead-Pointer & Memory Safety
require "../spec/suites/test_lifecycle_destruction"
require "../spec/suites/test_dead_pointer_safety"
require "../spec/suites/test_reentrancy_self_destruct"

# Concurrency, Threads, Channels & Fibers
require "../spec/suites/test_concurrency"
require "../spec/suites/test_thread_safe_apis"

# Signals, Callables & Events
require "../spec/suites/test_callable_signals_advanced"

# ClassDB, Macros, Reflection & Properties
require "../spec/suites/test_classdb_coverage"
require "../spec/suites/test_macros_dsl"
require "../spec/suites/test_dynamic_properties_classdb"
require "../spec/suites/test_node_duplication_meta"

# GDScript Interoperability & Polymorphism
require "../spec/suites/test_gdscript_channel_signal_interop"
require "../spec/suites/test_autobound_gdscript_nodes"
require "../spec/suites/test_gdscript_inheritance_polymorphism"

# Testing Apparatus, Toolchain & Addon Isolation
require "../spec/suites/test_async_testing_apparatus"
require "../spec/suites/test_undo_redo_history"
require "../spec/suites/test_toolchain_standalone"
require "../spec/suites/test_multi_addon_isolation"
require "../spec/suites/test_script_first_class"
require "../spec/suites/test_debugger_isolation"

# Deep Engine Bindings & Safety Expansion Suites
require "../spec/suites/test_packed_arrays_containers"
require "../spec/suites/test_variant_math_deep"
require "../spec/suites/test_memory_cyclic_refcounting"
require "../spec/suites/test_servers_low_level_rid"
require "../spec/suites/test_virtual_methods_dispatch"
require "../spec/suites/test_concurrency_multi_thread_gc"
require "../spec/suites/test_channel_exhaustive"
require "../spec/suites/test_gdscript_crystal_interop_deep"
require "../spec/suites/test_cold_boot"

# Procedural Generation, Navigation & System Utilities Suites
require "../spec/suites/test_noise_procedural_generation"
require "../spec/suites/test_astar_navigation"
require "../spec/suites/test_image_pixel_buffer"
require "../spec/suites/test_config_file_serialization"
