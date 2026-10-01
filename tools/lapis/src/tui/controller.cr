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
            if @state.current_view == ViewMode::ColorStudio && @state.use_3d_color_picker
              @state.color_picker_3d.tick(0.1)
            end
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
        puts "\e[1;97;48;5;54m [ #{@state.title.upcase} RUN REPORT ] \e[0m"
        puts

        executed_phases = @state.phases.reject { |p| p.status == PhaseStatus::Pending }
        if executed_phases.empty?
          @state.global_logs.each { |l| puts l }
          return
        end

        executed_phases.each do |phase|
          status_badge = case phase.status
                         when PhaseStatus::Passed
                           "\e[1;32m[OK] PASSED\e[0m"
                         when PhaseStatus::Failed
                           "\e[1;31m[X] FAILED (exit code #{phase.exit_code})\e[0m"
                         when PhaseStatus::Skipped
                           "\e[38;5;244m[-] SKIPPED\e[0m"
                         else
                           "\e[33m[.] #{phase.status}\e[0m"
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

          # Trigger toast notification for milestone progress
          if success
            @state.toasts.add("Phase Passed", "#{p.name} completed in #{sprintf("%.2fs", duration)}", :success, 2500_i64)
          else
            @state.toasts.add("Phase Failed", "#{p.name} failed (code #{exit_code})", :error, 4000_i64)
          end
        end
        render_frame
      end

      private def handle_key(event : Terminal::KeyEvent) : Nil
        # 1. Search Mode Key Handling
        if @state.searching
          case event.key
          when Terminal::Key::Enter
            @state.search_query = @state.search_input.strip.empty? ? nil : @state.search_input.strip
            @state.searching = false
          when Terminal::Key::Escape
            @state.searching = false
          when Terminal::Key::Backspace
            @state.search_input = @state.search_input[0...-1] unless @state.search_input.empty?
          when Terminal::Key::Char
            if event.ctrl && event.char == 'c'
              @state.searching = false
            else
              @state.search_input += event.char
            end
          end
          return
        end

        # 2. Color Studio (Opal ColorPicker & ColorPicker3D) Key Handling
        if @state.current_view == ViewMode::ColorStudio
          case event.key
          when Terminal::Key::Escape
            @state.current_view = ViewMode::Dashboard
            return
          when Terminal::Key::Tab
            @state.use_3d_color_picker = !@state.use_3d_color_picker
            @state.sync_active_color
            return
          when Terminal::Key::Enter
            @state.sync_active_color
            @state.current_view = ViewMode::Dashboard
            @state.toasts.add("Theme Applied", "Accent color set to #{@state.accent_color.to_hex}", :success, 2500_i64)
            return
          when Terminal::Key::Char
            if event.char == '1'
              @state.use_3d_color_picker = false
              @state.sync_active_color
              return
            elsif event.char == '2'
              @state.use_3d_color_picker = true
              @state.sync_active_color
              return
            end
          end

          opal_ev = event.to_opal_key_event
          if @state.use_3d_color_picker
            @state.color_picker_3d.handle_key(opal_ev)
            @state.accent_color = @state.color_picker_3d.selected_color
          else
            @state.color_picker.handle_key(opal_ev)
            @state.accent_color = @state.color_picker.color
          end
          return
        end

        # 3. File Explorer (Opal FileDialog) Key Handling
        if @state.current_view == ViewMode::FileExplorer
          case event.key
          when Terminal::Key::Escape
            @state.current_view = ViewMode::Dashboard
            return
          when Terminal::Key::Enter
            opal_ev = event.to_opal_key_event
            @state.file_dialog.handle_key(opal_ev)
            if @state.file_dialog.confirmed?
              sel = @state.file_dialog.selected_path || @state.file_dialog.current_path
              @state.toasts.add("File Selected", File.basename(sel), :info, 2500_i64)
              @state.current_view = ViewMode::Dashboard
            end
            return
          else
            opal_ev = event.to_opal_key_event
            @state.file_dialog.handle_key(opal_ev)
            return
          end
        end

        # 4. Standard Navigation & Actions
        case event.key
        when Terminal::Key::Up
          case @state.active_tab
          when TabMode::Breakdown
            @state.breakdown_selected_index = Math.max(0, @state.breakdown_selected_index - 1)
          when TabMode::Failures
            @state.failure_selected_index = Math.max(0, @state.failure_selected_index - 1)
          when TabMode::Benchmarks
            @state.benchmark_selected_index = Math.max(0, @state.benchmark_selected_index - 1)
          else
            @state.select_prev_phase
          end
        when Terminal::Key::Down
          case @state.active_tab
          when TabMode::Breakdown
            @state.breakdown_selected_index = Math.min(@state.phases.size - 1, @state.breakdown_selected_index + 1)
          when TabMode::Failures
            @state.failure_selected_index = Math.min(@state.failed_phases_list.size - 1, @state.failure_selected_index + 1)
          when TabMode::Benchmarks
            @state.benchmark_selected_index = Math.min(@state.phases.size - 1, @state.benchmark_selected_index + 1)
          else
            @state.select_next_phase
          end
        when Terminal::Key::Tab
          @state.next_tab
        when Terminal::Key::PageUp
          if @state.current_view == ViewMode::PhaseDetail
            @state.detail_scroll_offset += 6
          else
            @state.follow_mode = false
            @state.log_scroll_offset += 6
          end
        when Terminal::Key::PageDown
          if @state.current_view == ViewMode::PhaseDetail
            @state.detail_scroll_offset = Math.max(0, @state.detail_scroll_offset - 6)
          else
            @state.log_scroll_offset = Math.max(0, @state.log_scroll_offset - 6)
            @state.follow_mode = true if @state.log_scroll_offset == 0
          end
        when Terminal::Key::Enter
          if @state.current_view == ViewMode::PhaseDetail
            @state.current_view = ViewMode::Dashboard
          else
            @state.current_view = ViewMode::PhaseDetail
          end
        when Terminal::Key::Escape
          if @state.search_query
            @state.search_query = nil
          else
            @state.current_view = ViewMode::Dashboard
          end
        when Terminal::Key::Char
          if event.ctrl
            if event.char == 'c'
              @aborted = true
              @running = false
            end
            return
          end

          case event.char
          when '1' then @state.active_tab = TabMode::Dashboard
          when '2' then @state.active_tab = TabMode::Failures
          when '3' then @state.active_tab = TabMode::Breakdown
          when '4' then @state.active_tab = TabMode::Telemetry
          when '5' then @state.active_tab = TabMode::Benchmarks
          when 't', 'T', 'p', 'P'
            @state.toggle_color_studio
          when 'o', 'O'
            @state.toggle_file_explorer
          when 'e', 'E'
            if @state.current_view == ViewMode::PhaseDetail
              if phase = @state.selected_phase
                export_path = "phase_#{phase.tag.gsub(/[^a-zA-Z0-9]/, "_")}.log"
                File.write(export_path, phase.log_lines.join("\n")) rescue nil
                @state.toasts.add("Log Exported", export_path, :success, 3000_i64)
              end
            else
              @state.toggle_file_explorer
            end
          when 'x', 'X'
            fx = @state.next_shader_fx
            @state.toasts.add("Shader FX", fx.display_name, :info, 2000_i64)
          when 'k', 'K'
            case @state.active_tab
            when TabMode::Breakdown
              @state.breakdown_selected_index = Math.max(0, @state.breakdown_selected_index - 1)
            when TabMode::Failures
              @state.failure_selected_index = Math.max(0, @state.failure_selected_index - 1)
            when TabMode::Benchmarks
              @state.benchmark_selected_index = Math.max(0, @state.benchmark_selected_index - 1)
            else
              @state.select_prev_phase
            end
          when 'j', 'J'
            case @state.active_tab
            when TabMode::Breakdown
              @state.breakdown_selected_index = Math.min(@state.phases.size - 1, @state.breakdown_selected_index + 1)
            when TabMode::Failures
              @state.failure_selected_index = Math.min(@state.failed_phases_list.size - 1, @state.failure_selected_index + 1)
            when TabMode::Benchmarks
              @state.benchmark_selected_index = Math.min(@state.phases.size - 1, @state.benchmark_selected_index + 1)
            else
              @state.select_next_phase
            end
          when 'f', 'F'
            @state.follow_mode = !@state.follow_mode
            @state.log_scroll_offset = 0 if @state.follow_mode
          when 'd', 'D'
            @state.breakdown_sort_by_duration = !@state.breakdown_sort_by_duration
            mode_desc = @state.breakdown_sort_by_duration ? "Duration Profile (Longest at Top)" : "Standard Order"
            @state.toasts.add("Breakdown View", mode_desc, :info, 2000_i64)
          when '/'
            @state.searching = true
            @state.search_input = ""
          when 'c', 'C'
            if @state.active_tab == TabMode::Benchmarks
              modes = [:bar, :speedup, :ratio, :log]
              curr_idx = modes.index(@state.benchmark_chart_mode) || 0
              next_mode = modes[(curr_idx + 1) % modes.size]
              @state.benchmark_chart_mode = next_mode
              @state.toasts.add("Chart Mode", next_mode.to_s.upcase, :info, 1500_i64)
            elsif phase = @state.selected_phase
              clip_text = phase.error_excerpt || phase.log_lines.to_a.last(100).join("\n")
              Opal.copy_to_clipboard(clip_text) rescue nil
              @state.toasts.add("Copied to Clipboard", "Phase output copied via OSC 52", :info, 2500_i64)
            end
          when 'q', 'Q'
            @aborted = true
            @running = false
          when '?'
            if @state.current_view == ViewMode::Help
              @state.current_view = ViewMode::Dashboard
            else
              @state.current_view = ViewMode::Help
            end
          end
        else
          # Other keys
        end
      end
    end
  end
end
