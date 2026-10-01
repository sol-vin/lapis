# =============================================================================
# Lapis - Diagnostic Log Viewer (TUI)
# =============================================================================
# Interactive full-screen log viewer featuring multi-channel log switching,
# real-time tailing, regex search, and severity level filtering.
# =============================================================================

require "opal"
require "../core/env"
require "../core/logger"

module Lapis
  module TUI
    class LogViewer
      enum LevelFilter
        All
        Error
        Warn
        Info
        Debug
        Trace
      end

      getter? running : Bool = true
      property selected_channel_idx : Int32 = 0
      property level_filter : LevelFilter = LevelFilter::All
      property scroll_offset : Int32 = 0
      property? auto_follow : Bool = true
      property search_query : String = ""
      property? search_mode : Bool = false

      LOG_CHANNELS = [
        {"editor", "log/editor.log"},
        {"game", "log/game.log"},
        {"build", "log/build.log"},
        {"test", "log/test.log"},
        {"bridge", "log/bridge.log"},
        {"crash", "log/crash.log"},
      ]

      property lines : Array(String) = [] of String
      @last_file_mtime : Time? = nil
      @last_file_size : Int64 = 0_i64

      def initialize(initial_channel : String? = nil)
        if initial_channel
          idx = LOG_CHANNELS.index { |name, _| name.downcase == initial_channel.downcase }
          @selected_channel_idx = idx if idx
        end
        reload_active_log
      end

      def self.run(initial_channel : String? = nil) : Nil
        new(initial_channel).run
      end

      def run : Nil
        return unless STDOUT.tty?

        driver = Opal::Terminal.default_driver
        driver.raw_mode do
          driver.enter_alternate_screen
          driver.hide_cursor
          diff_renderer = Opal::UI::DiffRenderer.new(driver)
          begin
            while @running
              check_file_updates if @auto_follow
              render(driver, diff_renderer)
              ev = driver.poll_event(50)
              handle_input(ev, diff_renderer) if ev
            end
          ensure
            driver.show_cursor
            driver.exit_alternate_screen
          end
        end
      end

      private def active_log_path : Path
        rel_path = LOG_CHANNELS[@selected_channel_idx][1]
        Core::Env::ROOT_DIR.join(rel_path)
      end

      private def reload_active_log
        path = active_log_path
        if File.exists?(path)
          info = File.info(path)
          @last_file_mtime = info.modification_time
          @last_file_size = info.size
          @lines = File.read_lines(path) rescue ["(Failed to read log file: #{path})"]
        else
          @lines = ["(Log file does not exist yet: #{path})"]
          @last_file_mtime = nil
          @last_file_size = 0_i64
        end

        scroll_to_bottom if @auto_follow
      end

      private def check_file_updates
        path = active_log_path
        return unless File.exists?(path)

        info = File.info(path)
        if info.modification_time != @last_file_mtime || info.size != @last_file_size
          @last_file_mtime = info.modification_time
          @last_file_size = info.size
          @lines = File.read_lines(path) rescue @lines
          scroll_to_bottom if @auto_follow
        end
      end

      private def filtered_lines : Array(String)
        res = @lines

        # Level filter
        case @level_filter
        when LevelFilter::Error
          res = res.select { |l| l.includes?("ERROR") || l.includes?("FATAL") || l.includes?("ERR") }
        when LevelFilter::Warn
          res = res.select { |l| l.includes?("WARN") || l.includes?("ERROR") || l.includes?("FATAL") }
        when LevelFilter::Info
          res = res.reject { |l| l.includes?("DEBUG") || l.includes?("TRACE") }
        when LevelFilter::Debug
          res = res.reject { |l| l.includes?("TRACE") }
        when LevelFilter::Trace, LevelFilter::All
          # All lines
        end

        # Search query filter
        unless @search_query.empty?
          regex = Regex.new(@search_query, Regex::Options::IGNORE_CASE) rescue nil
          if regex
            res = res.select { |l| l =~ regex }
          else
            res = res.select { |l| l.downcase.includes?(@search_query.downcase) }
          end
        end

        res
      end

      @view_height : Int32 = 24

      private def scroll_to_bottom
        visible_lines = filtered_lines
        view_h = Math.max(5, @view_height - 7)
        @scroll_offset = Math.max(0, visible_lines.size - view_h)
      end

      def render_to_buffer(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        @view_height = height

        # 1. Header Banner & Channels Tabs
        buffer.put_string(2, 1, ":: LAPIS DIAGNOSTIC LOG VIEWER ::", fg: Opal::Color.bright_cyan, bold: true)
        channel_name, rel_path = LOG_CHANNELS[@selected_channel_idx]
        buffer.put_string(36, 1, "│ Active: #{rel_path}", fg: Opal::Color.bright_black)

        # Channel Tabs
        tab_x = 2
        LOG_CHANNELS.each_with_index do |(name, _), idx|
          selected = (idx == @selected_channel_idx)
          badge = " [ #{name} ] "
          fg = selected ? Opal::Color.bright_white : Opal::Color.bright_black
          bg = selected ? Opal::Color.hex("#3B4252") : Opal::Color.none
          buffer.put_string(tab_x, 3, badge, fg: fg, bg: bg, bold: selected)
          tab_x += badge.size + 1
        end

        # Level Pill Bar
        lvl_x = width - 42
        lvl_str = "Level: [1:ALL 2:ERR 3:WRN 4:INF 5:DBG]"
        buffer.put_string(lvl_x, 3, lvl_str, fg: Opal::Color.yellow)

        buffer.put_string(2, 4, "─" * (width - 4), fg: Opal::Color.bright_black)

        # 2. Log Viewport
        fl = filtered_lines
        view_h = height - 8
        view_y = 5

        slice = fl[@scroll_offset, view_h]? || [] of String
        slice.each_with_index do |line, idx|
          y = view_y + idx
          fg = Opal::Color.white
          bold = false

          if line.includes?("ERROR") || line.includes?("FATAL")
            fg = Opal::Color.bright_red
            bold = true
          elsif line.includes?("WARN")
            fg = Opal::Color.yellow
          elsif line.includes?("INFO")
            fg = Opal::Color.bright_blue
          elsif line.includes?("DEBUG")
            fg = Opal::Color.magenta
          elsif line.includes?("TRACE")
            fg = Opal::Color.bright_black
          end

          # Highlight search query if active
          buffer.put_string(2, y, line, fg: fg, bold: bold, max_width: width - 4)
        end

        # 3. Footer & Controls
        footer_y = height - 2
        buffer.put_string(2, footer_y - 1, "─" * (width - 4), fg: Opal::Color.bright_black)

        follow_badge = @auto_follow ? "[FOLLOW: ON]" : "[FOLLOW: OFF]"
        follow_fg = @auto_follow ? Opal::Color.green : Opal::Color.bright_black

        if @search_mode
          prompt = "Search regex: /#{@search_query}█"
          buffer.put_string(2, footer_y, prompt, fg: Opal::Color.yellow, bold: true)
        else
          info = "Tab/Shift+Tab: Channel │ 1-5: Level (#{@level_filter}) │ f: #{follow_badge} │ /: Search │ Esc/Q: Back"
          buffer.put_string(2, footer_y, info, fg: Opal::Color.cyan)
          buffer.put_string(width - 20, footer_y, "#{fl.size} lines", fg: Opal::Color.bright_black)
        end
      end

      private def render(driver : Opal::Terminal::Driver, diff_renderer : Opal::UI::DiffRenderer)
        w, h = driver.size
        width = Math.max(40, w)
        height = Math.max(16, h)
        buffer = Opal::UI::Buffer.new(width, height)
        render_to_buffer(buffer, width, height)
        diff_renderer.render(buffer)
      end

      private def handle_input(ev : Opal::Terminal::KeyEvent | Opal::Terminal::MouseEvent | Opal::Terminal::ResizeEvent, diff_renderer : Opal::UI::DiffRenderer)
        if ev.is_a?(Opal::Terminal::ResizeEvent)
          diff_renderer.invalidate!
          return
        end

        return unless ev.is_a?(Opal::Terminal::KeyEvent)

        if @search_mode
          handle_search_input(ev)
          return
        end

        # Global command palette shortcut
        if ev.char == '~' || ev.char == '`' || ev.matches?("ctrl+p")
          @running = false
          return
        end

        case ev.name
        when "escape", "esc"
          @running = false
        when "tab"
          @selected_channel_idx = (@selected_channel_idx + 1) % LOG_CHANNELS.size
          reload_active_log
        when "up"
          @auto_follow = false
          @scroll_offset = Math.max(0, @scroll_offset - 1)
        when "down"
          view_h = Opal::Terminal.default_driver.size[1] - 8
          max_scroll = Math.max(0, filtered_lines.size - view_h)
          @scroll_offset = Math.min(max_scroll, @scroll_offset + 1)
          @auto_follow = true if @scroll_offset >= max_scroll
        when "pageup", "page_up"
          @auto_follow = false
          @scroll_offset = Math.max(0, @scroll_offset - 10)
        when "pagedown", "page_down"
          view_h = Opal::Terminal.default_driver.size[1] - 8
          max_scroll = Math.max(0, filtered_lines.size - view_h)
          @scroll_offset = Math.min(max_scroll, @scroll_offset + 10)
          @auto_follow = true if @scroll_offset >= max_scroll
        when "home"
          @auto_follow = false
          @scroll_offset = 0
        when "end"
          scroll_to_bottom
          @auto_follow = true
        else
          if ch = ev.char
            case ch
            when 'q', 'Q'
              @running = false
            when 'f', 'F'
              @auto_follow = !@auto_follow
              scroll_to_bottom if @auto_follow
            when '/'
              @search_mode = true
            when 'c', 'C'
              @search_query = ""
            when '1'
              @level_filter = LevelFilter::All
            when '2'
              @level_filter = LevelFilter::Error
            when '3'
              @level_filter = LevelFilter::Warn
            when '4'
              @level_filter = LevelFilter::Info
            when '5'
              @level_filter = LevelFilter::Debug
            end
          end
        end
      end

      private def handle_search_input(ev : Opal::Terminal::KeyEvent)
        case ev.name
        when "escape", "esc", "enter"
          @search_mode = false
        when "backspace"
          @search_query = @search_query[0...-1] if @search_query.size > 0
        else
          if ch = ev.char
            @search_query += ch
          end
        end
      end
    end
  end
end
