# tools/lapis/spec/tui_views_spec.cr
require "./spec_helper"
require "opal"

# Helper to verify no emojis exist in rendered string
def assert_no_emojis(rendered_text : String, context : String)
  # Check for common emoji unicode blocks:
  # Miscellaneous Symbols and Pictographs (0x1F300 - 0x1F5FF)
  # Emoticons (0x1F600 - 0x1F64F)
  # Transport and Map Symbols (0x1F680 - 0x1F6FF)
  # Supplemental Symbols and Pictographs (0x1F900 - 0x1F9FF)
  rendered_text.each_char do |ch|
    cp = ch.ord
    is_emoji = (0x1F300..0x1F5FF).includes?(cp) ||
               (0x1F600..0x1F64F).includes?(cp) ||
               (0x1F680..0x1F6FF).includes?(cp) ||
               (0x1F900..0x1F9FF).includes?(cp) ||
               ((0x2600..0x26FF).includes?(cp) && ![0x263A, 0x263B].includes?(cp) && ch != '─' && ch != '│' && ch != '┌' && ch != '┐' && ch != '└' && ch != '┘')
    if is_emoji
      fail("Found emoji '#{ch}' (U+#{cp.to_s(16).upcase}) in #{context} rendered text! TUIs must strictly use ASCII or text symbols.")
    end
  end
end

describe "Lapis::TUI Views & Modal Specifications" do
  describe Lapis::TUI::Hub do
    it "renders header, menu items, shortcut key badges, and footer" do
      hub = Lapis::TUI::Hub.new
      buffer = Opal::UI::Buffer.new(100, 30)
      hub.render_to_buffer(buffer, 100, 30)
      rendered = buffer.render_to_string(with_ansi: false)

      rendered.should contain("LAPIS CLI TERMINAL HUB")
      rendered.should contain("Pure Crystal Engine Toolchain")
      rendered.should contain("New Project / Addon Wizard")
      rendered.should contain("Launch Godot Editor")
      rendered.should contain("Packaging & Export Center")
      rendered.should contain("Radare2 Native Debugger")
      rendered.should contain("Diagnostic Log Viewer")
      rendered.should contain("Benchmark Visualizer")
      rendered.should contain("Run Game (Performance Monitor)")
      rendered.should contain("Test Suites Dashboard")
      rendered.should contain("Toolchain Doctor")
      rendered.should contain("Exit")
      rendered.should contain("[ Q ]")
      rendered.should contain("[ N ]")
      rendered.should contain("[ E ]")

      assert_no_emojis(rendered, "Hub view")
    end

    it "renders floating command palette when palette_open is true" do
      hub = Lapis::TUI::Hub.new
      hub.palette_open = true
      buffer = Opal::UI::Buffer.new(100, 30)
      hub.render_to_buffer(buffer, 100, 30)
      rendered = buffer.render_to_string(with_ansi: false)

      rendered.should contain("Type a command")
      assert_no_emojis(rendered, "Hub command palette")
    end
  end

  describe Lapis::TUI::NewWizard do
    it "renders Step::SelectType, Step::EnterDetails, and Step::PreviewAndCreate" do
      wiz = Lapis::TUI::NewWizard.new
      buffer = Opal::UI::Buffer.new(90, 25)

      # 1. SelectType
      wiz.current_step = Lapis::TUI::NewWizard::Step::SelectType
      wiz.render_to_buffer(buffer, 90, 25)
      rendered1 = buffer.render_to_string(with_ansi: false)
      rendered1.should contain("SCAFFOLDING WIZARD")
      rendered1.should contain("Standalone Game")
      rendered1.should contain("GDExtension Addon")
      rendered1.should contain("Showcase Example")
      assert_no_emojis(rendered1, "NewWizard Step::SelectType")

      # 2. EnterDetails
      wiz.current_step = Lapis::TUI::NewWizard::Step::EnterDetails
      wiz.project_name = "awesome_quest"
      wiz.author = "LapisDev"
      buffer.clear
      wiz.render_to_buffer(buffer, 90, 25)
      rendered2 = buffer.render_to_string(with_ansi: false)
      rendered2.should contain("Project Name:")
      rendered2.should contain("awesome_quest")
      rendered2.should contain("Author:")
      rendered2.should contain("LapisDev")
      assert_no_emojis(rendered2, "NewWizard Step::EnterDetails")

      # 3. PreviewAndCreate
      wiz.current_step = Lapis::TUI::NewWizard::Step::PreviewAndCreate
      buffer.clear
      wiz.render_to_buffer(buffer, 90, 25)
      rendered3 = buffer.render_to_string(with_ansi: false)
      rendered3.should contain("Preview & Confirm Creation")
      rendered3.should contain("Type:")
      rendered3.should contain("awesome_quest")
      assert_no_emojis(rendered3, "NewWizard Step::PreviewAndCreate")
    end
  end

  describe Lapis::TUI::EditorLauncher do
    it "renders supervisor header, process status pane, and log stream" do
      launcher = Lapis::TUI::EditorLauncher.new(".")
      buffer = Opal::UI::Buffer.new(100, 28)
      launcher.render_to_buffer(buffer, 100, 28)
      rendered = buffer.render_to_string(with_ansi: false)

      rendered.should contain("EDITOR SUPERVISOR & LIVE LOG WATCHER")
      rendered.should contain("Process Status")
      rendered.should contain("Log Stream")
      rendered.should contain("STOPPED")
      rendered.should contain("Build & Hot Reload")
      rendered.should contain("Graceful Kill")

      assert_no_emojis(rendered, "EditorLauncher")
    end
  end

  describe Lapis::TUI::PackageForm do
    it "renders available targets matching current platform and settings form" do
      form = Lapis::TUI::PackageForm.new
      buffer = Opal::UI::Buffer.new(100, 26)
      form.render_to_buffer(buffer, 100, 26)
      rendered = buffer.render_to_string(with_ansi: false)

      rendered.should contain("PACKAGING & EXPORT CENTER")
      rendered.should contain("Target Artifact:")
      rendered.should contain("Playable Game")
      rendered.should contain("Portable Executable")
      rendered.should contain("GDExtension Addon")
      rendered.should contain("Lapis Toolchain")
      rendered.should contain("Release Mode:")
      rendered.should contain("Destination Dir:")

      {% if flag?(:windows) %}
        rendered.should contain("Windows Installer")
      {% elsif flag?(:linux) %}
        rendered.should contain("Debian Package")
      {% elsif flag?(:darwin) %}
        rendered.should contain("macOS App Bundle")
      {% end %}

      assert_no_emojis(rendered, "PackageForm form mode")
    end

    it "renders build progress when building is active" do
      form = Lapis::TUI::PackageForm.new
      form.building = true
      form.build_logs << "Compiling game binary with --release -O3..."
      form.build_logs << "Packaging standalone assets into zip..."
      buffer = Opal::UI::Buffer.new(100, 26)
      form.render_to_buffer(buffer, 100, 26)
      rendered = buffer.render_to_string(with_ansi: false)

      rendered.should contain("BUILDING PACKAGE")
      rendered.should contain("Compiling game binary")
      rendered.should contain("Building distribution")

      assert_no_emojis(rendered, "PackageForm build progress")
    end
  end

  describe Lapis::TUI::DebuggerView do
    it "renders binary picker and dashboard panes" do
      dbg = Lapis::TUI::DebuggerView.new(auto_analyze: false)
      buffer = Opal::UI::Buffer.new(110, 30)

      # 1. File picker mode
      dbg.choosing_file = true
      dbg.render_to_buffer(buffer, 110, 30)
      rendered1 = buffer.render_to_string(with_ansi: false)
      rendered1.should contain("SELECT TARGET BINARY TO DEBUG")
      assert_no_emojis(rendered1, "DebuggerView file picker")

      # 2. Dashboard mode
      dbg.choosing_file = false
      buffer.clear
      dbg.render_to_buffer(buffer, 110, 30)
      rendered2 = buffer.render_to_string(with_ansi: false)
      rendered2.should contain("RADARE2 NATIVE DEBUGGER")
      rendered2.should contain("Disassembly (pdf)")
      rendered2.should contain("Pseudo-C (pdc)")
      rendered2.should contain("Crystal Source (cl)")
      rendered2.should contain("CPU Registers (dr)")
      assert_no_emojis(rendered2, "DebuggerView dashboard")

      # 3. Crystal Source tab
      dbg.active_tab = Lapis::TUI::DebuggerView::Tab::CrystalSource
      dbg.crystal_source_lines << "# Target: entry0 | Source Location: src/main.cr:42"
      dbg.crystal_source_lines << "=>   42 |   run_game"
      buffer.clear
      dbg.render_to_buffer(buffer, 110, 30)
      rendered3 = buffer.render_to_string(with_ansi: false)
      rendered3.should contain("Crystal Source (cl)")
      rendered3.should contain("src/main.cr:42")
      rendered3.should contain("run_game")
      assert_no_emojis(rendered3, "DebuggerView CrystalSource tab")
    end
  end

  describe Lapis::TUI::BenchViewer do
    it "renders benchmark visualization dashboard and language comparison" do
      bench = Lapis::TUI::BenchViewer.new
      buffer = Opal::UI::Buffer.new(110, 30)

      # 1. When empty/no metrics, renders empty state notice
      bench.metrics.clear
      bench.choosing_file = false
      bench.render_to_buffer(buffer, 110, 30)
      rendered1 = buffer.render_to_string(with_ansi: false)
      rendered1.should contain("BENCHMARK SUITE VISUALIZER")
      rendered1.should contain("NO BENCHMARK RESULTS AVAILABLE")
      assert_no_emojis(rendered1, "BenchViewer empty state")

      # 2. When metrics populated, renders full visualization panels
      bench.metrics << Lapis::Commands::Benchmarks::BenchmarkMetric.new(
        name: "AStar2D",
        category: Lapis::Commands::Benchmarks::Category::EngineCore,
        crystal_ms: 1.0,
        gdscript_ms: 10.0,
        speedup: 10.0,
        description: "AStar2D Pathfinding"
      )
      buffer.clear
      bench.render_to_buffer(buffer, 110, 30)
      rendered2 = buffer.render_to_string(with_ansi: false)

      rendered2.should contain("BENCHMARK SUITE VISUALIZER")
      rendered2.should contain("Multi-Language Bar")
      rendered2.should contain("Top Speedups")
      rendered2.should contain("Category Donut")
      assert_no_emojis(rendered2, "BenchViewer dashboard")
    end
  end

  describe Lapis::TUI::LogViewer do
    it "renders channel tabs, log levels, viewport, and footer info" do
      logv = Lapis::TUI::LogViewer.new
      logv.lines = [
        "[INFO] Initializing Godot Engine 4.3",
        "[DEBUG] Loading GDExtension crystal_bridge.dll",
        "[WARN] Deprecated property accessed: speed",
        "[ERROR] NullReferenceException in physics tick"
      ]

      buffer = Opal::UI::Buffer.new(100, 26)
      logv.render_to_buffer(buffer, 100, 26)
      rendered = buffer.render_to_string(with_ansi: false)

      rendered.should contain("DIAGNOSTIC LOG VIEWER")
      rendered.should contain("editor")
      rendered.should contain("game")
      rendered.should contain("Level: [1:ALL 2:ERR 3:WRN 4:INF 5:DBG]")
      rendered.should contain("Initializing Godot Engine")
      rendered.should contain("NullReferenceException")
      rendered.should contain("4 lines")

      assert_no_emojis(rendered, "LogViewer")
    end
  end

  describe Lapis::TUI::RunMonitor do
    it "renders performance graphs, telemetry stats, and process status" do
      mon = Lapis::TUI::RunMonitor.new("bin/game.exe", spawn_process: false)
      buffer = Opal::UI::Buffer.new(100, 26)
      mon.render_to_buffer(buffer, 100, 26)
      rendered = buffer.render_to_string(with_ansi: false)

      rendered.should contain("RUNTIME PERFORMANCE MONITOR")
      rendered.should contain("Target: bin/game.exe")
      rendered.should contain("FPS:")
      rendered.should contain("RAM:")
      rendered.should contain("STOPPED")
      rendered.should contain("Gracefully Kill Process")

      assert_no_emojis(rendered, "RunMonitor")
    end
  end

  describe "Modular Test Runner Views" do
    it "renders BreakdownView with both empty and populated states" do
      canvas = Lapis::TUI::Canvas.new(100, 20)
      state = Lapis::TUI::TestRunState.new

      # Empty state
      Lapis::TUI::Views::BreakdownView.draw(canvas, state, 0, 0, 100, 20)
      rendered_empty = canvas.render_to_string
      rendered_empty.should contain("COMPLETE TEST SUITE BREAKDOWN")
      rendered_empty.should contain("No test suites registered")
      assert_no_emojis(rendered_empty, "BreakdownView empty")

      # Populated state
      p1 = Lapis::TUI::PhaseItem.new("core", "[CORE]", "Core Bindings Suite", "Core")
      p1.status = Lapis::TUI::PhaseStatus::Passed
      p1.duration = 0.42
      p2 = Lapis::TUI::PhaseItem.new("physics", "[PHYS]", "Physics 2D/3D Suite", "Physics")
      p2.status = Lapis::TUI::PhaseStatus::Failed
      p2.duration = 1.15
      state.phases << p1
      state.phases << p2

      canvas.clear
      Lapis::TUI::Views::BreakdownView.draw(canvas, state, 0, 0, 100, 20)
      rendered_pop = canvas.render_to_string
      rendered_pop.should contain("2 Suites Registered")
      rendered_pop.should contain("Core Bindings Suite")
      rendered_pop.should contain("Physics 2D/3D Suite")
      rendered_pop.should contain("PASS")
      rendered_pop.should contain("FAIL")
      assert_no_emojis(rendered_pop, "BreakdownView populated")
    end

    it "renders FailuresView with no failures and multiple failures" do
      canvas = Lapis::TUI::Canvas.new(100, 20)
      state = Lapis::TUI::TestRunState.new

      # No failures
      Lapis::TUI::Views::FailuresView.draw(canvas, state, 0, 0, 100, 20)
      rendered_none = canvas.render_to_string
      rendered_none.should contain("TEST FAILURES & ERROR TRIAGE")
      rendered_none.should contain("No test failures detected")
      assert_no_emojis(rendered_none, "FailuresView no failures")

      # With failures
      p = Lapis::TUI::PhaseItem.new("shader", "[SHAD]", "Shader Pipeline", "Shaders")
      p.status = Lapis::TUI::PhaseStatus::Failed
      p.add_log_line("ERROR: Fragment shader failed compilation at line 14: syntax error")
      state.phases << p

      canvas.clear
      Lapis::TUI::Views::FailuresView.draw(canvas, state, 0, 0, 100, 20)
      rendered_fails = canvas.render_to_string
      rendered_fails.should contain("1 Failed Phases")
      rendered_fails.should contain("Shader Pipeline")
      rendered_fails.should contain("Fragment shader failed compilation")
      assert_no_emojis(rendered_fails, "FailuresView with failures")
    end

    it "renders TelemetryView with engine and GC metrics" do
      canvas = Lapis::TUI::Canvas.new(90, 15)
      state = Lapis::TUI::TestRunState.new
      Lapis::TUI::Views::TelemetryView.draw(canvas, state, 0, 0, 90, 15)
      rendered = canvas.render_to_string

      rendered.should contain("TEST RUN TELEMETRY & PERFORMANCE METRICS")
      rendered.should contain("Total Time:")
      rendered.should contain("Completed:")
      rendered.should contain("Assertions:")
      assert_no_emojis(rendered, "TelemetryView")
    end

    it "renders DetailModal inspecting selected phase logs" do
      canvas = Lapis::TUI::Canvas.new(90, 20)
      state = Lapis::TUI::TestRunState.new
      p = Lapis::TUI::PhaseItem.new("mesh", "[MESH]", "Mesh Generation", "3D")
      p.status = Lapis::TUI::PhaseStatus::Passed
      p.add_log_line("Generated 4096 vertices in 1.4ms")
      p.add_log_line("SurfaceTool commit successful")
      state.phases << p
      state.selected_phase_index = 0

      Lapis::TUI::Views::DetailModal.draw(canvas, state, 90, 20)
      rendered = canvas.render_to_string

      rendered.should contain("PHASE INSPECTION: MESH GENERATION")
      rendered.should contain("[LOG] PHASE LOG OUTPUT")
      rendered.should contain("Generated 4096 vertices")
      rendered.should contain("SurfaceTool commit successful")
      assert_no_emojis(rendered, "DetailModal")
    end
  end
end
