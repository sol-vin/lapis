# =============================================================================
# LibGodot Test Runner Application & Suite Entry Point
# =============================================================================

require "../../src/lapis"
require "./generated/project_nodes/all_project_nodes"
require "./fixtures/test_target_nodes"

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

    # Master "Run All" button
    hook_button("MarginContainer/VBox/ButtonBox/BtnRunAll") { run_and_display_all }

    # Dynamically build and connect category buttons from Registry.categories
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
          button_box.add_child(btn)
          btn.signal("pressed").connect do
            run_and_display_category(target_cat)
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
# Modular Test Suites (Exhaustive Coverage Across Extension API)
# =============================================================================

# Core and Built-ins
require "./suites/test_core_builtins"
require "./suites/test_2d_nodes"
require "./suites/test_3d_nodes"
require "./suites/test_control_nodes"
require "./suites/test_node_hierarchy"
require "./suites/test_deferred_execution"
require "./suites/test_scale_stress"

# Graphics, Meshes, Shaders & Materials
require "./suites/test_meshes_materials"
require "./suites/test_shaders_compilation"
require "./suites/test_materials_textures_advanced"
require "./suites/test_geometry_surfacetool"
require "./suites/test_cameras_viewports_canvas"

# Physics, Collision & Raycasting
require "./suites/test_physics_shapes"
require "./suites/test_physics_simulation_raycast"

# Audio, Animation & Tweens
require "./suites/test_audio_animation"
require "./suites/test_audio_system_servers"
require "./suites/test_tweens_animation"

# Resources, Scenes & Persistence
require "./suites/test_resources_utilities"
require "./suites/test_scenes_persistence"
require "./suites/test_resource_lifecycle_deep"

# Lifecycle, Dead-Pointer & Memory Safety
require "./suites/test_lifecycle_destruction"
require "./suites/test_dead_pointer_safety"
require "./suites/test_reentrancy_self_destruct"

# Concurrency, Threads, Channels & Fibers
require "./suites/test_concurrency"
require "./suites/test_thread_safe_apis"

# Signals, Callables & Events
require "./suites/test_callable_signals_advanced"

# ClassDB, Macros, Reflection & Properties
require "./suites/test_classdb_coverage"
require "./suites/test_macros_dsl"
require "./suites/test_dynamic_properties_classdb"
require "./suites/test_node_duplication_meta"

# GDScript Interoperability & Polymorphism
require "./suites/test_gdscript_channel_signal_interop"
require "./suites/test_autobound_gdscript_nodes"
require "./suites/test_gdscript_inheritance_polymorphism"

# Testing Apparatus, Toolchain & Addon Isolation
require "./suites/test_async_testing_apparatus"
require "./suites/test_undo_redo_history"
require "./suites/test_toolchain_standalone"
require "./suites/test_multi_addon_isolation"
require "./suites/test_script_first_class"
require "./suites/test_debugger_isolation"

# Deep Engine Bindings & Safety Expansion Suites
require "./suites/test_packed_arrays_containers"
require "./suites/test_variant_math_deep"
require "./suites/test_memory_cyclic_refcounting"
require "./suites/test_servers_low_level_rid"
require "./suites/test_virtual_methods_dispatch"
require "./suites/test_concurrency_multi_thread_gc"
