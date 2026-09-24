require "./terminal"
require "./model"
require "./renderer"

module Lapis
  module TUI
    class Controller
      getter state : TestRunState
      getter renderer : Renderer
      @running : Bool = false
      @aborted : Bool = false
      @render_lock = Mutex.new
      @input_channel = Channel(Terminal::KeyEvent).new(32)

      def initialize(title : String, platform_name : String, godot_version : String)
        @state = TestRunState.new(title, platform_name, godot_version)
        @renderer = Renderer.new
      end

      def register_phase(id : String, tag : String, name : String, category : String) : PhaseItem
        item = PhaseItem.new(id, tag, name, category)
        @state.phases << item
        item
      end

      def aborted? : Bool
        @aborted
      end

      def render_frame : Nil
        @render_lock.synchronize do
          @renderer.render(@state)
        end
      end

      def start : Nil
        Terminal.enter_alternate_screen
        Terminal.enable_raw_mode
        @running = true
        @state.overall_status = OverallStatus::Running

        # Background rendering loop (10 FPS)
        spawn do
          while @running
            render_frame
            sleep 0.1.seconds
          end
        end

        # Background keyboard reader loop
        spawn do
          while @running
            if event = Terminal.read_key_nonblocking
              handle_key(event)
            end
            sleep 0.02.seconds
          end
        end
      end

      def stop(final_success : Bool) : Nil
        @state.overall_status = if @aborted
                                  OverallStatus::Aborted
                                elsif final_success
                                  OverallStatus::Passed
                                else
                                  OverallStatus::Failed
                                end
        render_frame
        @running = false
        sleep 0.1.seconds
        Terminal.exit_alternate_screen
      end

      # Spits out the full test run output after exiting the alternate screen,
      # organized by phase, with failure excerpts and logs.
      def dump_results : Nil
        puts
        puts "\e[1;97;48;5;54m 🔮 LIBGODOT TEST SUITE RUN REPORT \e[0m"
        puts

        executed_phases = @state.phases.reject { |p| p.status == PhaseStatus::Pending }
        if executed_phases.empty?
          @state.global_logs.each { |l| puts l }
          return
        end

        executed_phases.each do |phase|
          status_badge = case phase.status
                         when PhaseStatus::Passed
                           "\e[1;32m✔ PASSED\e[0m"
                         when PhaseStatus::Failed
                           "\e[1;31m✘ FAILED (exit code #{phase.exit_code})\e[0m"
                         when PhaseStatus::Skipped
                           "\e[38;5;244m⊘ SKIPPED\e[0m"
                         else
                           "\e[33m○ #{phase.status}\e[0m"
                         end

          puts "\e[1;96m━━━ [#{phase.tag}] #{phase.name} (#{phase.category}) ━━━\e[0m"
          puts "  Result: #{status_badge}  Duration: \e[1;93m#{phase.duration}s\e[0m"

          if phase.status == PhaseStatus::Failed && (err = phase.error_excerpt)
            puts "  \e[1;31mFailure Excerpt:\e[0m"
            err.each_line do |el|
              puts "    \e[31m#{el}\e[0m"
            end
          end

          if phase.log_lines.empty?
            puts "  \e[38;5;242m(No output recorded for this phase)\e[0m"
          else
            puts "  \e[38;5;244mOutput (#{phase.log_lines.size} lines):\e[0m"
            phase.log_lines.each do |line|
              puts "    #{line}"
            end
          end
          puts
        end
      end

      # Line handler called from ProcessRunner streaming TeeIO
      def handle_stream_line(line : String) : Nil
        @state.add_global_log(line)

        if active = @state.active_phase
          active.add_log_line(line)

          # Parse test signals
          clean = line.strip
          if clean.starts_with?("✔ [") || clean.starts_with?("[PASS]")
            active.passed_count += 1
            if m = clean.match(/(?:✔|\[PASS\])\s*(\[[^\]]+\]\s*.+)/)
              active.current_test = m[1]
            end
          elsif clean.starts_with?("✘ [") || clean.starts_with?("[FAIL]") || clean.includes?("Failures:")
            active.failed_count += 1
            active.error_excerpt ||= clean
            if m = clean.match(/(?:✘|\[FAIL\])\s*(\[[^\]]+\]\s*[^:]+)/)
              active.current_test = m[1]
            end
          elsif clean.starts_with?("✓ ")
            active.passed_count += 1
            active.current_test = clean.sub("✓ ", "")
          elsif clean.starts_with?("[Test:") || clean.starts_with?("[Spec")
            active.current_test = clean
          elsif clean =~ /(\d+)\s+examples?,\s+(\d+)\s+failures?,\s+(\d+)\s+errors?/
            examples = $1.to_i? || 0
            failures = $2.to_i? || 0
            errors = $3.to_i? || 0
            active.passed_count += (examples - failures - errors)
            active.failed_count += (failures + errors)
          end
        end
      end

      def begin_phase(index : Int32) : Nil
        @state.active_phase_index = index
        @state.selected_phase_index = index
        if p = @state.active_phase
          p.status = PhaseStatus::Running
        end
        render_frame
      end

      def finish_phase(index : Int32, success : Bool, duration : Float64, exit_code : Int32, error : String? = nil) : Nil
        if p = @state.phases[index]?
          p.status = success ? PhaseStatus::Passed : PhaseStatus::Failed
          p.duration = duration
          p.exit_code = exit_code
          p.error_excerpt ||= error if error
        end
        render_frame
      end

      private def handle_key(event : Terminal::KeyEvent) : Nil
        case event.key
        when Terminal::Key::Up
          @state.select_prev_phase
        when Terminal::Key::Down
          @state.select_next_phase
        when Terminal::Key::Enter
          if @state.current_view == ViewMode::PhaseDetail
            @state.current_view = ViewMode::Dashboard
          else
            @state.current_view = ViewMode::PhaseDetail
          end
        when Terminal::Key::Escape
          @state.current_view = ViewMode::Dashboard
        when Terminal::Key::Char
          case event.char
          when 'k', 'K'
            @state.select_prev_phase
          when 'j', 'J'
            @state.select_next_phase
          when 'q', 'Q'
            @aborted = true
            @running = false
          when '?'
            if @state.current_view == ViewMode::Help
              @state.current_view = ViewMode::Dashboard
            else
              @state.current_view = ViewMode::Help
            end
          when 'c'
            if event.ctrl
              @aborted = true
              @running = false
            end
          end
        else
          # Other keys
        end
      end
    end
  end
end
