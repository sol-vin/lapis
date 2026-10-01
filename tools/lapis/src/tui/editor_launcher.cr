# =============================================================================
# Lapis - Persistent Editor Launcher & Live Log Watcher (TUI)
# =============================================================================
# Persistent terminal supervisor that launches the Godot Editor, keeps the TUI
# open, monitors process health, and streams real-time diagnostic engine logs.
# =============================================================================

require "opal"
require "../core/env"
require "../core/godot_finder"
require "../core/process_runner"
require "../commands/build"

module Lapis
  module TUI
    class EditorLauncher
      getter project_path : String
      getter? running : Bool = true
      getter? picking_folder : Bool = false
      getter logs : Array(String) = [] of String
      getter max_logs : Int32 = 1000
      getter file_dialog : Opal::UI::FileDialog
      getter? auto_scroll : Bool = true
      getter log_scroll : Int32 = 0
      property editor_pid : Int64? = nil
      property? editor_alive : Bool = false
      property start_time : Time::Instant? = nil
      property reload_count : Int32 = 0

      def initialize(path : String? = nil)
        curr = path ? File.expand_path(path) : File.expand_path(".")
        if File.exists?(File.join(curr, "project.godot"))
          @project_path = curr
          @file_dialog = Opal::UI::FileDialog.new(initial_path: curr, mode: :open_dir)
        else
          @project_path = curr
          @picking_folder = true
          @file_dialog = Opal::UI::FileDialog.new(initial_path: curr, mode: :open_dir)
        end
      end

      def self.run(path : String? = nil) : Nil
        new(path).run
      end

      def run : Nil
        return unless STDOUT.tty?

        driver = Opal::Terminal.default_driver
        driver.raw_mode do
          driver.enter_alternate_screen
          driver.hide_cursor
          begin
            if @picking_folder
              pick_project_loop(driver)
              return if @project_path.empty? || !File.exists?(File.join(@project_path, "project.godot"))
            end

            spawn_editor_and_watch_logs
            event_loop(driver)
          ensure
            driver.show_cursor
            driver.exit_alternate_screen
          end
        end
      end

      private def pick_project_loop(driver : Opal::Terminal::Driver)
        while @picking_folder && @running
          w, h = driver.size
          width = Math.max(80, w)
          height = Math.max(24, h)
          buffer = Opal::UI::Buffer.new(width, height)

          buffer.put_string(2, 1, "[DIR] SELECT GODOT PROJECT DIRECTORY", fg: Opal::Color.bright_yellow, bold: true)
          buffer.put_string(2, 2, "No project.godot found in current folder. Choose a project directory to launch:", fg: Opal::Color.bright_black)
          buffer.put_string(2, 3, "─" * (width - 4), fg: Opal::Color.bright_black)

          @file_dialog.render(buffer, 2, 4, width - 4, height - 7)

          y = height - 2
          buffer.put_string(2, y, "─" * (width - 4), fg: Opal::Color.bright_black)
          buffer.put_string(2, y + 1, "↑/↓: Browse │ Enter: Open Folder │ Space: Select Project │ Esc: Cancel", fg: Opal::Color.cyan)

          driver.write(Opal::Terminal::Screen.move_to(1, 1))
          driver.write(buffer.render_to_string(with_ansi: true))
          driver.flush

          ev = driver.read_event
          next unless ev.is_a?(Opal::Terminal::KeyEvent)

          if ev.matches?("escape")
            @running = false
            @picking_folder = false
          elsif @file_dialog.handle_key(ev)
            if @file_dialog.confirmed?
              selected = @file_dialog.selected_path || @file_dialog.current_path
              if File.exists?(File.join(selected, "project.godot"))
                @project_path = selected
                @picking_folder = false
              else
                @logs << "Selected folder does not contain project.godot: #{selected}"
              end
            end
          elsif ev.matches?("space")
            selected = @file_dialog.current_path
            if File.exists?(File.join(selected, "project.godot"))
              @project_path = selected
              @picking_folder = false
            else
              @logs << "Selected folder does not contain project.godot: #{selected}"
            end
          end
        end
      end

      private def spawn_editor_and_watch_logs
        godot_exe = Core::GodotFinder.resolve(nil, @project_path)
        unless godot_exe
          @logs << "Error: Godot engine executable not found on host!"
          return
        end

        @logs << "Starting Godot Editor for '#{File.basename(@project_path)}'..."
        @start_time = Time.instant

        # Launch Godot editor process asynchronously
        process = Process.new(
          godot_exe,
          ["--editor", "--path", @project_path],
          output: Process::Redirect::Pipe,
          error: Process::Redirect::Pipe,
          chdir: @project_path
        )

        @editor_pid = process.pid.to_i64
        @editor_alive = true
        @logs << "Godot Editor spawned successfully (PID: #{@editor_pid})"

        # Background fiber to pump stdout logs
        spawn do
          if out_io = process.output?
            while line = out_io.gets
              @logs << line.chomp
              @logs.shift if @logs.size > @max_logs
            end
          end
        end

        # Background fiber to pump stderr logs
        spawn do
          if err_io = process.error?
            while line = err_io.gets
              @logs << "[STDERR] #{line.chomp}"
              @logs.shift if @logs.size > @max_logs
            end
          end
        end

        # Background fiber to await termination
        spawn do
          status = process.wait
          @editor_alive = false
          @logs << "Godot Editor process terminated with exit code #{status.exit_code}."
        end
      end

      private def event_loop(driver : Opal::Terminal::Driver)
        while @running
          render(driver)
          if ev = driver.read_event
            handle_input(ev)
          end
        end
      end

      def render_to_buffer(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        # Top Header
        proj_name = File.basename(@project_path)
        buffer.put_string(2, 1, ":: LAPIS EDITOR SUPERVISOR & LIVE LOG WATCHER ::", fg: Opal::Color.bright_cyan, bold: true)
        buffer.put_string(width - 25, 1, "Project: #{proj_name}", fg: Opal::Color.bright_white)
        buffer.put_string(2, 2, "─" * (width - 4), fg: Opal::Color.bright_black)

        # Split Panes: Left (Status, 32 cols), Right (Logs, remaining)
        left_w = 32
        right_w = width - left_w - 6

        render_status_pane(buffer, 2, 4, left_w, height - 7)
        render_log_pane(buffer, left_w + 4, 4, right_w, height - 7)

        # Footer
        y = height - 2
        buffer.put_string(2, y, "─" * (width - 4), fg: Opal::Color.bright_black)
        hints = "R: Recompile & Reload │ K: Kill Editor │ Space: Scroll Lock │ Esc: Return to Hub"
        buffer.put_string(2, y + 1, hints, fg: Opal::Color.cyan)
      end

      private def render(driver : Opal::Terminal::Driver)
        w, h = driver.size
        width = Math.max(80, w)
        height = Math.max(24, h)
        buffer = Opal::UI::Buffer.new(width, height)
        render_to_buffer(buffer, width, height)

        driver.write(Opal::Terminal::Screen.move_to(1, 1))
        driver.write(buffer.render_to_string(with_ansi: true))
        driver.flush
      end

      private def render_status_pane(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32)
        buffer.put_string(x, y, "┌─ Process Status ────────┐", fg: Opal::Color.bright_black)

        status_str = @editor_alive ? "[RUNNING]" : "[STOPPED]"
        status_fg = @editor_alive ? Opal::Color.green : Opal::Color.red
        buffer.put_string(x + 2, y + 2, "State:      #{status_str}", fg: status_fg, bold: true)

        pid_str = @editor_pid ? @editor_pid.to_s : "None"
        buffer.put_string(x + 2, y + 4, "PID:        #{pid_str}", fg: Opal::Color.white)

        uptime_str = if st = @start_time
                       sec = (Time.instant - st).total_seconds.round.to_i
                       "#{sec}s"
                     else
                       "0s"
                     end
        buffer.put_string(x + 2, y + 6, "Uptime:     #{uptime_str}", fg: Opal::Color.cyan)
        buffer.put_string(x + 2, y + 8, "Reloads:    #{@reload_count}", fg: Opal::Color.yellow)

        buffer.put_string(x, y + 10, "├─ Quick Actions ─────────┤", fg: Opal::Color.bright_black)
        buffer.put_string(x + 2, y + 12, "[ R ] Build & Hot Reload", fg: Opal::Color.bright_white)
        buffer.put_string(x + 2, y + 14, "[ K ] Graceful Kill", fg: Opal::Color.red)
        buffer.put_string(x + 2, y + 16, "[ C ] Clear Log Stream", fg: Opal::Color.bright_black)

        h.times do |row|
          buffer.put_char(x + w, y + row, '│', fg: Opal::Color.bright_black)
        end
      end

      private def render_log_pane(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32)
        scroll_badge = @auto_scroll ? "[Auto-Scroll: ON]" : "[Scroll Locked]"
        buffer.put_string(x, y, "Log Stream #{scroll_badge} (#{@logs.size} lines)", fg: Opal::Color.bright_black)

        visible_lines = h - 2
        start_idx = if @auto_scroll
                      Math.max(0, @logs.size - visible_lines)
                    else
                      Math.max(0, Math.min(@logs.size - visible_lines, @log_scroll))
                    end

        visible_lines.times do |i|
          log_idx = start_idx + i
          break if log_idx >= @logs.size
          line = @logs[log_idx]

          line_fg = if line.includes?("ERROR") || line.includes?("[STDERR]")
                      Opal::Color.red
                    elsif line.includes?("WARN")
                      Opal::Color.yellow
                    elsif line.includes?("INFO")
                      Opal::Color.cyan
                    else
                      Opal::Color.white
                    end

          # Truncate to pane width
          rendered = line.size > w ? line[0...w - 1] : line
          buffer.put_string(x, y + 1 + i, rendered, fg: line_fg)
        end
      end

      private def handle_input(ev : Opal::Terminal::KeyEvent | Opal::Terminal::MouseEvent)
        return unless ev.is_a?(Opal::Terminal::KeyEvent)

        # Global command palette shortcut
        if ev.char == '~' || ev.char == '`' || ev.matches?("ctrl+p")
          @running = false
          return
        end

        case ev.name
        when "escape", "esc"
          @running = false
        when "up"
          @auto_scroll = false
          @log_scroll = Math.max(0, @log_scroll - 1)
        when "down"
          @log_scroll = Math.min(@logs.size - 1, @log_scroll + 1)
        when "space"
          @auto_scroll = !@auto_scroll
        else
          if ch = ev.char
            case ch
            when 'c', 'C'
              @logs.clear
            when 'r', 'R'
              trigger_rebuild
            when 'k', 'K'
              kill_editor
            when 'q', 'Q'
              @running = false
            end
          end
        end
      end

      private def trigger_rebuild
        @logs << "--- [Lapis] Triggering game.dll rebuild for hot reloading ---"
        spawn do
          res = Commands::Build.run(["-p", @project_path])
          if res == 0
            @reload_count += 1
            @logs << "--- [Lapis] Build succeeded! Press F5/F6 in Godot to hot reload ---"
          else
            @logs << "--- [Lapis] Build failed with exit code #{res} ---"
          end
        end
      end

      private def kill_editor
        if pid = @editor_pid
          @logs << "Sending termination signal to Godot Editor (PID: #{pid})..."
          Process.signal(Signal::TERM, pid.to_i32) rescue nil
        end
      end
    end
  end
end
