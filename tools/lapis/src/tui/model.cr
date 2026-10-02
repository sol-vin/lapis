require "opal"
require "opal/asciicast"

class Opal::Asciicast::VCR
  def self.elapsed : Float64
    instance.elapsed
  end

  def self.frame_count : Int32
    instance.frame_count
  end
end

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
      ColorStudio
      FileExplorer
    end

    enum ShaderFxMode
      None
      Crt
      Matrix
      Glitch
      Plasma
      Fire
      Vignette

      def display_name : String
        case self
        when Crt      then "CRT Scanlines"
        when Matrix   then "Matrix Rain"
        when Glitch   then "Glitch FX"
        when Plasma   then "Plasma Waves"
        when Fire     then "Heat FX"
        when Vignette then "Vignette"
        else               "Off"
        end
      end
    end

    enum TabMode
      Dashboard  = 0
      Failures   = 1
      Breakdown  = 2
      Telemetry  = 3
      Benchmarks = 4

      def self.from_index(idx : Int32) : TabMode
        case idx
        when 1 then Failures
        when 2 then Breakdown
        when 3 then Telemetry
        when 4 then Benchmarks
        else        Dashboard
        end
      end
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
      property active_tab : TabMode = TabMode::Dashboard
      property follow_mode : Bool = true
      property search_query : String? = nil
      property searching : Bool = false
      property search_input : String = ""
      property toasts : Opal::UI::ToastManager = Opal::UI::ToastManager.new
      property breakdown_selected_index : Int32 = 0
      property breakdown_sort_by_duration : Bool = true
      property failure_selected_index : Int32 = 0
      property benchmark_selected_index : Int32 = 0
      property benchmark_chart_mode : Symbol = :bar
      property log_scroll_offset : Int32 = 0
      property detail_scroll_offset : Int32 = 0

      # Interactive Opal UI additions (Color Picker, 3D Spatial Picker, File Dialog, Shaders)
      property accent_color : Opal::Color = Opal::Color.hex("#CBA6F7")
      property border_color : Opal::Color = Opal::Color.hex("#89B4FA")
      property color_picker : Opal::UI::ColorPicker = Opal::UI::ColorPicker.new(initial_color: Opal::Color.hex("#CBA6F7"))
      property color_picker_3d : Opal::UI::ColorPicker3D = Opal::UI::ColorPicker3D.new(initial_color: Opal::Color.hex("#CBA6F7"))
      property use_3d_color_picker : Bool = false
      property file_dialog : Opal::UI::FileDialog = Opal::UI::FileDialog.new(initial_path: ".")
      property shader_fx : ShaderFxMode = ShaderFxMode::None

      # Screencast Recording State (Opal Asciicast ScreenRecorder)
      property recording : Bool = false
      property recorder : Opal::Asciicast::ScreenRecorder? = nil
      property recording_start_time : Time::Instant? = nil
      property recording_path : String = ""

      def recording? : Bool
        @recording && !@recorder.nil?
      end

      def recording_elapsed_seconds : Float64
        if start = @recording_start_time
          (Time.instant - start).total_seconds
        else
          0.0_f64
        end
      end

      def recording_elapsed_str : String
        secs = recording_elapsed_seconds.to_i
        m = secs // 60
        s = secs % 60
        sprintf("%02d:%02d", m, s)
      end

      def start_recording(target_path : String? = nil, width : Int32 = 120, height : Int32 = 36) : String
        timestamp = Time.local.to_s("%Y%m%d_%H%M%S")
        out_path = target_path || "recordings/lapis_session_#{timestamp}.cast"
        dir = File.dirname(out_path)
        Dir.mkdir_p(dir) unless dir.empty? || Dir.exists?(dir)

        rec = Opal::Asciicast::ScreenRecorder.new(
          output_path: out_path,
          width: width,
          height: height,
          title: @title
        )
        rec.start
        @recorder = rec
        @recording = true
        @recording_path = out_path
        @recording_start_time = Time.instant
        out_path
      end

      def stop_recording : String
        return @recording_path unless @recording && (rec = @recorder)
        rec.stop
        saved_path = @recording_path
        @recording = false
        @recorder = nil
        @recording_start_time = nil
        saved_path
      end

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

      def next_tab : Nil
        next_idx = (@active_tab.to_i + 1) % 5
        @active_tab = TabMode.from_index(next_idx)
      end

      def prev_tab : Nil
        prev_idx = (@active_tab.to_i - 1 + 5) % 5
        @active_tab = TabMode.from_index(prev_idx)
      end

      def switch_tab(tab : TabMode) : Nil
        @active_tab = tab
      end

      def failed_phases_list : Array(PhaseItem)
        @phases.select { |p| p.status == PhaseStatus::Failed }
      end

      def next_shader_fx : ShaderFxMode
        idx = (@shader_fx.to_i + 1) % 7
        @shader_fx = ShaderFxMode.new(idx)
      end

      def toggle_color_studio : Nil
        @current_view = (@current_view == ViewMode::ColorStudio) ? ViewMode::Dashboard : ViewMode::ColorStudio
      end

      def toggle_file_explorer : Nil
        @current_view = (@current_view == ViewMode::FileExplorer) ? ViewMode::Dashboard : ViewMode::FileExplorer
      end

      def sync_active_color : Nil
        if @use_3d_color_picker
          @accent_color = @color_picker_3d.selected_color
          @color_picker.color = @accent_color
        else
          @accent_color = @color_picker.color
          @color_picker_3d.selected_color = @accent_color
        end
      end
    end
  end
end
