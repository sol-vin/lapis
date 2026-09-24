# tools/lapis/spec/tui_spec.cr
require "./spec_helper"

describe Lapis::TUI do
  describe Lapis::TUI::Canvas do
    it "computes accurate display widths for ASCII, emojis, and wide characters" do
      Lapis::TUI::Canvas.char_width('a').should eq(1)
      Lapis::TUI::Canvas.char_width('─').should eq(1)
      Lapis::TUI::Canvas.char_width('╔').should eq(1)
      Lapis::TUI::Canvas.char_width('🔮').should eq(2)
      Lapis::TUI::Canvas.char_width('⏳').should eq(2)
    end

    it "computes string display width ignoring ANSI escape codes" do
      plain = "Hello World"
      Lapis::TUI::Canvas.display_width(plain).should eq(11)

      colored = "\e[1;31mHello\e[0m \e[32mWorld\e[0m"
      Lapis::TUI::Canvas.display_width(colored).should eq(11)

      with_emoji = "Test 🔮 Suite"
      Lapis::TUI::Canvas.display_width(with_emoji).should eq(13) # 5 + 2 + 6
    end

    it "draws boxes with exact boundary corners and horizontal lines" do
      canvas = Lapis::TUI::Canvas.new(20, 5)
      canvas.draw_box(0, 0, 20, 5, title: "BOX")

      # Corners
      canvas.@grid[0][0].char.should eq('┌')
      canvas.@grid[0][19].char.should eq('┐')
      canvas.@grid[4][0].char.should eq('└')
      canvas.@grid[4][19].char.should eq('┘')

      # Check top/bottom edges
      canvas.@grid[4][5].char.should eq('─')
      canvas.@grid[2][0].char.should eq('│')
      canvas.@grid[2][19].char.should eq('│')
    end

    it "guarantees every rendered line has strictly uniform display width" do
      canvas = Lapis::TUI::Canvas.new(60, 10)
      canvas.draw_box(0, 0, 60, 10, title: " 🔮 TEST RUNNER ")
      canvas.draw_text(2, 2, "\e[1;32mPASSED ✔\e[0m Some long text that should fit")
      canvas.draw_bar(2, 4, 20, 0.5)

      rendered = canvas.render_to_string
      rendered.includes?("\n").should be_false

      lines = canvas.render_lines
      lines.size.should eq(10)

      lines.each do |line|
        # Each line's visual width must equal the canvas width exactly
        Lapis::TUI::Canvas.display_width(line).should eq(60)
      end
    end
  end

  describe Lapis::TUI::PhaseItem do
    it "initializes with pending status and records logs" do
      phase = Lapis::TUI::PhaseItem.new("specs", "[SPEC]", "Phase 1: Crystal Specifications", "Specs")
      phase.id.should eq("specs")
      phase.tag.should eq("[SPEC]")
      phase.name.should eq("Phase 1: Crystal Specifications")
      phase.category.should eq("Specs")
      phase.status.should eq(Lapis::TUI::PhaseStatus::Pending)
      phase.duration.should eq(0.0)

      phase.status = Lapis::TUI::PhaseStatus::Running
      phase.duration = 1.25
      phase.status = Lapis::TUI::PhaseStatus::Passed

      phase.status.should eq(Lapis::TUI::PhaseStatus::Passed)
      phase.duration.should eq(1.25)

      100.times { |i| phase.add_log_line("Line #{i}") }
      phase.log_lines.size.should eq(100)
      phase.log_lines.first.should eq("Line 0")
      phase.log_lines.last.should eq("Line 99")
    end
  end

  describe Lapis::TUI::TestRunState do
    it "manages phase transitions and overall progress ratio" do
      state = Lapis::TUI::TestRunState.new("Test Runner", "Windows x64", "4.3.0")
      p1 = Lapis::TUI::PhaseItem.new("phase1", "[1]", "First Phase", "Core")
      p2 = Lapis::TUI::PhaseItem.new("phase2", "[2]", "Second Phase", "Editor")
      state.phases << p1
      state.phases << p2

      state.total_phases.should eq(2)
      state.completed_phases.should eq(0)
      state.progress_ratio.should eq(0.0)

      # Start phase 1
      state.active_phase_index = 0
      p1.status = Lapis::TUI::PhaseStatus::Running
      state.active_phase.should eq(p1)

      # Finish phase 1
      p1.status = Lapis::TUI::PhaseStatus::Passed
      p1.passed_count = 10
      state.completed_phases.should eq(1)
      state.passed_phases.should eq(1)
      state.progress_ratio.should eq(0.5)

      # Start and fail phase 2
      state.active_phase_index = 1
      p2.status = Lapis::TUI::PhaseStatus::Failed
      p2.failed_count = 2
      state.completed_phases.should eq(2)
      state.failed_phases.should eq(1)
      state.progress_ratio.should eq(1.0)
      state.total_assertions_passed.should eq(10)
      state.total_assertions_failed.should eq(2)
    end

    it "handles view mode state changes and selection navigation" do
      state = Lapis::TUI::TestRunState.new
      p1 = Lapis::TUI::PhaseItem.new("p1", "[1]", "P1", "Test")
      p2 = Lapis::TUI::PhaseItem.new("p2", "[2]", "P2", "Test")
      state.phases << p1
      state.phases << p2

      state.current_view.should eq(Lapis::TUI::ViewMode::Dashboard)
      state.selected_phase_index.should eq(0)
      state.selected_phase.should eq(p1)

      state.select_next_phase
      state.selected_phase_index.should eq(1)
      state.selected_phase.should eq(p2)

      state.select_prev_phase
      state.selected_phase_index.should eq(0)
      state.selected_phase.should eq(p1)

      state.current_view = Lapis::TUI::ViewMode::PhaseDetail
      state.current_view.should eq(Lapis::TUI::ViewMode::PhaseDetail)
    end
  end

  describe "Stream Line Parsing" do
    it "extracts test statistics and assertion counts from logs" do
      controller = Lapis::TUI::Controller.new("Test Runner", "Windows", "4.3.0")
      p1 = controller.register_phase("specs", "[SPEC]", "Crystal specs", "Specs")
      controller.begin_phase(0)

      controller.handle_stream_line("✔ [MathSpec] Vector3 dot product returns correct scalar")
      p1.passed_count.should eq(1)
      p1.current_test.not_nil!.should contain("MathSpec")

      controller.handle_stream_line("✘ [PhysicsSpec] Raycast did not detect collider: timeout")
      p1.failed_count.should eq(1)
      p1.current_test.not_nil!.should contain("PhysicsSpec")

      controller.handle_stream_line("✓ StringUtils escapes quotes properly")
      p1.passed_count.should eq(2)

      controller.handle_stream_line("40 examples, 2 failures, 0 errors, 0 pending")
      p1.passed_count.should be >= 38
      p1.failed_count.should be >= 2
    end
  end

  describe Lapis::TUI::Terminal do
    it "correctly strips ANSI escape codes" do
      colored = "\e[31mError:\e[0m \e[1;32mTest Passed\e[0m"
      Lapis::TUI::Terminal.strip_ansi(colored).should eq("Error: Test Passed")

      rgb = "\e[38;2;255;100;50mRGB Color\e[0m"
      Lapis::TUI::Terminal.strip_ansi(rgb).should eq("RGB Color")
    end
  end

  describe Lapis::TUI::Renderer do
    it "renders the UI without crashing across standard terminal dimensions" do
      state = Lapis::TUI::TestRunState.new("Lapis Test Suite", "Windows x64", "4.3.0")
      p1 = Lapis::TUI::PhaseItem.new("p1", "[1]", "Unit Tests", "Core")
      p2 = Lapis::TUI::PhaseItem.new("p2", "[2]", "Editor Tests", "Editor")
      state.phases << p1
      state.phases << p2
      state.active_phase_index = 0
      p1.status = Lapis::TUI::PhaseStatus::Running
      p1.current_test = "MathSpec#vector3_dot_product"
      state.add_global_log("Running test: Vector3 operations")

      renderer = Lapis::TUI::Renderer.new

      # Test standard dimensions 80x24 and large 120x40
      [ {80, 24}, {120, 40}, {60, 20} ].each do |cols, rows|
        rendered = renderer.render_to_string(state, cols, rows)
        rendered.should be_a(String)
        rendered.size.should be > 0
        rendered.includes?("LAPIS TEST SUITE").should be_true
        rendered.includes?("Unit Tests").should be_true

        # Verify no newlines exist in full-screen coordinate ANSI stream (prevents terminal auto-scrolling)
        rendered.includes?("\n").should be_false

        # Verify exact line display width across all rows via render_lines
        lines = renderer.render_lines(state, cols, rows)
        expected_width = Math.max(40, cols - 1)
        lines.size.should eq(rows - 1)
        lines.each do |line|
          Lapis::TUI::Canvas.display_width(line).should eq(expected_width)
        end
      end
    end

    it "renders detail modal view when active with uniform line widths" do
      state = Lapis::TUI::TestRunState.new("Lapis Test Suite", "Windows x64", "4.3.0")
      p1 = Lapis::TUI::PhaseItem.new("p1", "[1]", "Failed Phase", "Core")
      state.phases << p1
      p1.status = Lapis::TUI::PhaseStatus::Failed
      p1.add_log_line("Expected 42 but got 0")
      p1.error_excerpt = "Expected 42 but got 0"
      state.selected_phase_index = 0
      state.current_view = Lapis::TUI::ViewMode::PhaseDetail

      renderer = Lapis::TUI::Renderer.new
      rendered = renderer.render_to_string(state, 100, 30)
      rendered.includes?("PHASE INSPECTION").should be_true
      rendered.includes?("FAILED PHASE").should be_true
      rendered.includes?("\n").should be_false

      lines = renderer.render_lines(state, 100, 30)
      lines.size.should eq(29)
      lines.each do |line|
        Lapis::TUI::Canvas.display_width(line).should eq(99)
      end
    end

    it "dumps executed phase results and logs cleanly via controller dump_results" do
      controller = Lapis::TUI::Controller.new("Test Suite", "Windows", "4.3.0")
      p1 = controller.register_phase("p1", "[P1]", "Engine Specs", "Spec")
      controller.begin_phase(0)
      controller.handle_stream_line("✔ [MathSpec] Vector3 dot product works")
      controller.finish_phase(0, true, 1.25, 0)

      # Ensure dump_results completes without error
      controller.dump_results
    end
  end

  describe "CLI Integration" do
    it "displays --tui and --no-tui flags in lapis test --help" do
      res = LapisSpecHelper.run_lapis(["test", "--help"])
      res.exit_code.should eq(0)
      res.output.should contain("--tui")
      res.output.should contain("--no-tui")
    end
  end
end
