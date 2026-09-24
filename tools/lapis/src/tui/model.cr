module Lapis
  module TUI
    enum PhaseStatus
      Pending
      Running
      Passed
      Failed
      Skipped
    end

    enum OverallStatus
      Idle
      Running
      Passed
      Failed
      Aborted
    end

    enum ViewMode
      Dashboard
      PhaseDetail
      Help
    end

    class PhaseItem
      property id : String
      property tag : String
      property name : String
      property category : String
      property status : PhaseStatus = PhaseStatus::Pending
      property duration : Float64 = 0.0
      property exit_code : Int32 = 0
      property passed_count : Int32 = 0
      property failed_count : Int32 = 0
      property current_test : String? = nil
      property error_excerpt : String? = nil
      property log_lines : Deque(String) = Deque(String).new(1000)

      def initialize(@id : String, @tag : String, @name : String, @category : String)
      end

      def add_log_line(line : String, max_size : Int32 = 1000)
        @log_lines.shift if @log_lines.size >= max_size
        @log_lines << line
      end
    end

    class TestRunState
      property title : String = "Lapis Test Suite Runner"
      property godot_version : String = "Unknown"
      property crystal_version : String = Crystal::VERSION
      property platform_name : String = ""
      property start_time : Time::Instant = Time.instant
      property overall_status : OverallStatus = OverallStatus::Idle
      property phases = [] of PhaseItem
      property active_phase_index : Int32 = 0
      property selected_phase_index : Int32 = 0
      property global_logs : Deque(String) = Deque(String).new(2000)
      property current_view : ViewMode = ViewMode::Dashboard
      property log_scroll_offset : Int32 = 0
      property detail_scroll_offset : Int32 = 0

      def initialize(
        @title : String = "Lapis Test Suite Runner",
        @platform_name : String = "",
        @godot_version : String = ""
      )
        @start_time = Time.instant
      end

      def elapsed_seconds : Float64
        (Time.instant - @start_time).total_seconds
      end

      def total_phases : Int32
        @phases.size
      end

      def completed_phases : Int32
        @phases.count { |p| p.status == PhaseStatus::Passed || p.status == PhaseStatus::Failed || p.status == PhaseStatus::Skipped }
      end

      def passed_phases : Int32
        @phases.count { |p| p.status == PhaseStatus::Passed }
      end

      def failed_phases : Int32
        @phases.count { |p| p.status == PhaseStatus::Failed }
      end

      def total_assertions_passed : Int32
        @phases.sum(&.passed_count)
      end

      def total_assertions_failed : Int32
        @phases.sum(&.failed_count)
      end

      def progress_ratio : Float64
        return 0.0 if @phases.empty?
        completed_phases.to_f64 / total_phases.to_f64
      end

      def selected_phase : PhaseItem?
        return nil if @phases.empty?
        idx = Math.min(Math.max(@selected_phase_index, 0), @phases.size - 1)
        @phases[idx]
      end

      def active_phase : PhaseItem?
        return nil if @phases.empty? || @active_phase_index >= @phases.size
        @phases[@active_phase_index]
      end

      def add_global_log(line : String)
        @global_logs.shift if @global_logs.size >= 2000
        @global_logs << line
      end

      def select_prev_phase
        if @selected_phase_index > 0
          @selected_phase_index -= 1
          @detail_scroll_offset = 0
        end
      end

      def select_next_phase
        if @selected_phase_index < @phases.size - 1
          @selected_phase_index += 1
          @detail_scroll_offset = 0
        end
      end
    end
  end
end
