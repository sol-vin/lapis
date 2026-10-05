# =============================================================================
# Lapis - Action Driver TUI Controller & Live Visual Inspector
# =============================================================================
# Full-screen terminal dashboard providing an interactive command console,
# live Godot Editor DOM tree hierarchy browser, and AI visual capture dispatch.
# =============================================================================

require "opal"
require "socket"
require "json"
require "../core/env"
require "../core/logger"
require "../commands/driver"

module Lapis
  module TUI
    class DriverView
      getter? running : Bool = true
      getter log_entries : Array(String) = [] of String
      getter dom_lines : Array(String) = [] of String
      property input_buffer : String = ""
      property status_msg : String = "Ready"
      property? connected : Bool = false
      property port : Int32 = 9095

      def initialize(@port : Int32 = 9095)
        check_connection
        refresh_dom
      end

      def self.run : Nil
        new.run
      end

      def check_connection : Void
        res = Commands::Driver.send_ipc({"action" => JSON::Any.new("ping")}, "127.0.0.1", @port)
        @connected = !res.nil?
        if @connected
          @status_msg = "Connected to Godot Editor (PID: #{res.not_nil!["pid"]? || "unknown"})"
        else
          @status_msg = "Disconnected (Godot Editor not running or IPC port #{@port} inactive)"
        end
      end

      def refresh_dom : Void
        return unless @connected
        res = Commands::Driver.send_ipc({"action" => JSON::Any.new("dump_dom"), "depth" => JSON::Any.new(6_i64)}, "127.0.0.1", @port)
        if res && (dom = res["dom"]?.try(&.as_s?))
          @dom_lines = dom.split("\n")
        end
      end

      def execute_command(cmd_str : String) : Void
        return if cmd_str.strip.empty?
        tokens = cmd_str.strip.split(/\s+/)
        action = tokens[0]
        args = tokens[1..-1]

        timestamp = ::Time.local.to_s("%H:%M:%S")
        @log_entries << "[#{timestamp}] > #{cmd_str}"

        case action
        when "click"
          target = args[0]? || "Build"
          res = Commands::Driver.send_ipc({"action" => JSON::Any.new("click"), "selector" => JSON::Any.new(target)}, "127.0.0.1", @port)
          msg = res ? (res["message"]? || "OK").to_s : "Failed"
          @log_entries << "  \e[32m✔\e[0m #{msg}"
        when "type"
          target = args[0]? || ""
          txt = args[1..-1].join(" ")
          res = Commands::Driver.send_ipc({"action" => JSON::Any.new("type"), "selector" => JSON::Any.new(target), "text" => JSON::Any.new(txt)}, "127.0.0.1", @port)
          msg = res ? (res["message"]? || "OK").to_s : "Failed"
          @log_entries << "  \e[32m✔\e[0m #{msg}"
        when "build"
          res = Commands::Driver.send_ipc({"action" => JSON::Any.new("trigger_build")}, "127.0.0.1", @port)
          @log_entries << "  \e[32m✔\e[0m Triggered Crystal Build"
        when "screenshot"
          path = args[0]? || "reports/screenshots/editor.png"
          res = Commands::Driver.send_ipc({"action" => JSON::Any.new("screenshot"), "path" => JSON::Any.new(path)}, "127.0.0.1", @port)
          @log_entries << "  \e[32m✔\e[0m Screenshot captured to #{path}"
        when "crop"
          target = args[0]? || "Build"
          path = args[1]? || "reports/elements/#{target}.png"
          res = Commands::Driver.send_ipc({"action" => JSON::Any.new("crop"), "selector" => JSON::Any.new(target), "path" => JSON::Any.new(path)}, "127.0.0.1", @port)
          @log_entries << "  \e[32m✔\e[0m Cropped #{target} -> #{path}"
        when "vision"
          res = Commands::Driver.send_ipc({"action" => JSON::Any.new("vision"), "output_dir" => JSON::Any.new("reports/ai_vision")}, "127.0.0.1", @port)
          cnt = res ? res["element_count"]? : 0
          @log_entries << "  \e[32m✔\e[0m Generated AI Vision Manifest (#{cnt} elements)"
        when "refresh"
          check_connection
          refresh_dom
          @log_entries << "  \e[32m✔\e[0m Refreshed DOM Tree"
        else
          @log_entries << "  \e[31m✘\e[0m Unknown command '#{action}'"
        end
      end

      def run : Nil
        return unless STDOUT.tty?

        driver = Opal::Terminal.default_driver
        driver.raw_mode do
          driver.enter_alternate_screen
          driver.hide_cursor
          diff_renderer = Opal::UI::DiffRenderer.new(driver)

          while @running
            render(diff_renderer)

            ev = driver.poll_event(50)
            next unless ev

            if ev.is_a?(Opal::Terminal::ResizeEvent)
              diff_renderer.invalidate!
              next
            end

            next unless ev.is_a?(Opal::Terminal::KeyEvent)

            if ev.matches?("ctrl+c") || ev.matches?("escape")
              @running = false
            elsif ev.matches?("enter")
              execute_command(@input_buffer)
              @input_buffer = ""
              diff_renderer.invalidate!
            elsif ev.matches?("backspace")
              @input_buffer = @input_buffer[0...-1] if @input_buffer.size > 0
              diff_renderer.invalidate!
            elsif ch = ev.char
              if ch == 'b' && @input_buffer.empty?
                execute_command("build")
              elsif ch == 's' && @input_buffer.empty?
                execute_command("screenshot")
              elsif ch == 'v' && @input_buffer.empty?
                execute_command("vision")
              elsif ch == 'r' && @input_buffer.empty?
                execute_command("refresh")
              elsif ch == 'q' && @input_buffer.empty?
                @running = false
              else
                @input_buffer += ch
              end
              diff_renderer.invalidate!
            end
          end

          driver.show_cursor
          driver.exit_alternate_screen
        end
      end

      private def render(diff_renderer : Opal::UI::DiffRenderer) : Void
        driver = diff_renderer.driver
        w, h = driver.size
        width = Math.max(40, w)
        height = Math.max(16, h)

        buffer = Opal::UI::Buffer.new(width, height)
        render_to_buffer(buffer, width, height)
        diff_renderer.render(buffer)
      end

      def render_to_buffer(buffer : Opal::UI::Buffer, width : Int32, height : Int32) : Void
        # Header bar
        header_text = " LAPIS ACTION DRIVER CONTROLLER | [Status: #{@status_msg}]"
        buffer.put_string(0, 0, header_text.ljust(width), fg: Opal::Color.bright_magenta, bold: true)

        # Split pane (left: DOM tree, right: logs)
        half_w = (width / 2).to_i
        view_h = height - 4

        # Left: DOM Explorer
        buffer.put_string(1, 1, "=== EDITOR DOM TREE HIERARCHY ===", fg: Opal::Color.bright_cyan, bold: true)
        @dom_lines.each_with_index do |line, idx|
          break if idx >= view_h - 1
          buffer.put_string(1, 2 + idx, line, max_width: half_w - 2)
        end

        # Separator
        0.upto(view_h) do |y|
          buffer.put_string(half_w, 1 + y, "│", fg: Opal::Color.bright_black)
        end

        # Right: Log & Actions
        buffer.put_string(half_w + 2, 1, "=== ACTION TRACE & COMMAND LOG ===", fg: Opal::Color.yellow, bold: true)
        recent_logs = @log_entries.last(view_h - 1)
        recent_logs.each_with_index do |entry, idx|
          buffer.put_string(half_w + 2, 2 + idx, entry, max_width: width - half_w - 4)
        end

        # Bottom Command Input Bar
        input_y = height - 2
        buffer.put_string(0, input_y, " > #{@input_buffer}_".ljust(width), fg: Opal::Color.green, bold: true)

        # Footer hotkeys
        footer = " [Enter] Run  [b] Build  [s] Screenshot  [v] AI Vision  [r] Refresh  [q] Exit"
        buffer.put_string(0, height - 1, footer.ljust(width), fg: Opal::Color.bright_black)
      end
    end
  end
end
