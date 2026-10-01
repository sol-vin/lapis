# tools/lapis/src/tui/docs_viewer.cr
require "opal"
require "../docs/model"
require "../docs/indexer"
require "../core/env"

module Lapis
  module TUI
    class DocsViewer
      getter? running : Bool = true
      property search_query : String = ""
      property? searching : Bool = false
      property selected_idx : Int32 = 0
      property active_context : Docs::Context? = nil
      property doc_scroll_offset : Int32 = 0

      getter indexer : Docs::Indexer
      getter filtered_symbols : Array(Docs::DocSymbol) = [] of Docs::DocSymbol

      def initialize(initial_query : String? = nil, context : Docs::Context? = nil)
        @active_context = context
        @indexer = Docs::Indexer.build
        @search_query = initial_query || ""
        update_filtered_symbols
      end

      def self.run(initial_query : String? = nil, context : Docs::Context? = nil) : Nil
        new(initial_query, context).run
      end

      def update_filtered_symbols : Nil
        @filtered_symbols = if @search_query.empty?
                              if ctx = @active_context
                                @indexer.symbols_by_context[ctx]? || [] of Docs::DocSymbol
                              else
                                @indexer.symbols.values
                              end
                            else
                              @indexer.lookup(@active_context, @search_query)
                            end
        @selected_idx = @selected_idx.clamp(0, Math.max(0, @filtered_symbols.size - 1))
        @doc_scroll_offset = 0
      end

      def run : Nil
        return unless STDOUT.tty?

        driver = Opal::Terminal.default_driver
        driver.raw_mode do
          driver.enter_alternate_screen
          driver.hide_cursor
          begin
            while @running
              render(driver)
              handle_input(driver)
            end
          ensure
            driver.show_cursor
            driver.exit_alternate_screen
          end
        end
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

      def render_to_buffer(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        # 1. Header & Search Bar
        buffer.put_string(2, 1, ":: LAPIS UNIFIED DOCUMENTATION EXPLORER ::", fg: Opal::Color.bright_cyan, bold: true)
        total_syms = @indexer.symbols.size
        buffer.put_string(48, 1, "│ Indexed: #{total_syms} symbols", fg: Opal::Color.bright_black)

        # Context pills
        pills = [
          {nil, "[ 1: All ]"},
          {Docs::Context::Godot, "[ 2: Godot (GD) ]"},
          {Docs::Context::Crystal, "[ 3: Crystal (CR) ]"},
          {Docs::Context::Guide, "[ 4: Guides (DOC) ]"},
          {Docs::Context::Stdlib, "[ 5: Stdlib (STD) ]"},
        ]

        pill_x = 2
        pills.each do |c_tuple|
          ctx, label = c_tuple
          is_active = (ctx == @active_context)
          fg = is_active ? Opal::Color.bright_white : Opal::Color.bright_black
          bg = is_active ? Opal::Color.hex("#3B4252") : Opal::Color.none
          buffer.put_string(pill_x, 2, label, fg: fg, bg: bg, bold: is_active)
          pill_x += label.size + 1
        end

        search_str = @searching ? "Search: [#{@search_query}_]" : "Search: [#{@search_query}] (Press '/' to search)"
        buffer.put_string(2, 3, search_str, fg: @searching ? Opal::Color.bright_yellow : Opal::Color.cyan, bold: @searching)
        buffer.put_string(2, 4, "─" * (width - 4), fg: Opal::Color.bright_black)

        # 2. Split Layout: Left (Symbols List - 34 cols), Right (Doc Viewport)
        left_w = Math.min(36, (width * 0.38).to_i)
        right_x = left_w + 3
        right_w = width - right_x - 2

        # Vertical Divider
        (5...(height - 3)).each do |y|
          buffer.put_string(left_w + 1, y, "│", fg: Opal::Color.bright_black)
        end

        # Left List
        buffer.put_string(2, 5, "SYMBOLS (#{@filtered_symbols.size} MATCHES)", fg: Opal::Color.bright_white, bold: true)

        if @filtered_symbols.empty?
          buffer.put_string(2, 7, "No matching symbols found.", fg: Opal::Color.bright_black)
          buffer.put_string(2, 8, "Try searching for:", fg: Opal::Color.yellow)
          buffer.put_string(2, 9, "  - CharacterBody3D", fg: Opal::Color.cyan)
          buffer.put_string(2, 10, "  - move_and_slide", fg: Opal::Color.cyan)
          buffer.put_string(2, 11, "  - Channel", fg: Opal::Color.cyan)
          buffer.put_string(2, 12, "  - Concurrency", fg: Opal::Color.cyan)
        else
          max_list_items = height - 9
          start_idx = Math.max(0, @selected_idx - (max_list_items // 2))

          @filtered_symbols[start_idx, max_list_items]?.try &.each_with_index do |sym, offset|
            idx = start_idx + offset
            y = 7 + offset
            is_sel = (idx == @selected_idx)

            cursor = is_sel ? "►" : " "
            badge = "[#{sym.context.to_badge}:#{sym.kind.to_badge}]"
            badge_color = case sym.context
                          when Docs::Context::Godot   then Opal::Color.cyan
                          when Docs::Context::Crystal then Opal::Color.bright_green
                          when Docs::Context::Guide   then Opal::Color.yellow
                          when Docs::Context::Stdlib  then Opal::Color.magenta
                          else                             Opal::Color.white
                          end

            fg = is_sel ? Opal::Color.bright_white : Opal::Color.white
            bg = is_sel ? Opal::Color.hex("#2A2B3D") : Opal::Color.none

            label = sprintf("%s %-8s %s", cursor, badge, sym.name)
            buffer.put_string(2, y, label[0...left_w], fg: fg, bg: bg, bold: is_sel)
          end
        end

        # Right: Documentation Reader
        if current_sym = @filtered_symbols[@selected_idx]?
          render_documentation(buffer, current_sym, right_x, right_w, height)
        end

        # Footer
        footer_y = height - 2
        buffer.put_string(2, footer_y - 1, "─" * (width - 4), fg: Opal::Color.bright_black)
        controls = "↑/↓: Select │ PgUp/PgDn: Scroll Doc │ 1-5: Filter Context │ /: Search │ Esc/Q: Exit"
        buffer.put_string(2, footer_y, controls, fg: Opal::Color.bright_white)
      end

      private def render_documentation(buffer : Opal::UI::Buffer, sym : Docs::DocSymbol, x : Int32, w : Int32, h : Int32)
        cur_y = 5

        # Header Badge and Title
        ctx_title = case sym.context
                    when Docs::Context::Godot   then "[Godot 4.x Engine API]"
                    when Docs::Context::Crystal then "[Crystal Project Node / Class]"
                    when Docs::Context::Guide   then "[Lapis Architectural Guide]"
                    when Docs::Context::Stdlib  then "[Crystal Core Standard Library]"
                    end

        buffer.put_string(x, cur_y, "#{ctx_title} #{sym.full_query}", fg: Opal::Color.bright_yellow, bold: true)
        cur_y += 1

        # File and Line location
        if file = sym.file_path
          loc_str = "Defined in: #{file}#{sym.line_number ? ":#{sym.line_number}" : ""}"
          buffer.put_string(x, cur_y, loc_str, fg: Opal::Color.bright_black)
          cur_y += 1
        end

        # Inheritance
        if !sym.inheritance.empty?
          inh_str = "Inherits: #{sym.inheritance.join(" < ")}"
          buffer.put_string(x, cur_y, inh_str, fg: Opal::Color.cyan)
          cur_y += 1
        end

        cur_y += 1
        # Signature Block
        buffer.put_string(x, cur_y, "SIGNATURE:", fg: Opal::Color.bright_white, bold: true)
        cur_y += 1
        sig_bg = Opal::Color.hex("#1E1E2E")
        buffer.put_string(x, cur_y, "  #{sym.signature}", fg: Opal::Color.bright_green, bg: sig_bg, bold: true)
        cur_y += 2

        # Parameters
        if !sym.params.empty?
          buffer.put_string(x, cur_y, "PARAMETERS:", fg: Opal::Color.bright_white, bold: true)
          cur_y += 1
          sym.params.each do |param|
            p_str = "  • #{param.name} : #{param.type_str}"
            p_str += " = #{param.default_value}" if param.default_value
            buffer.put_string(x, cur_y, p_str, fg: Opal::Color.white)
            cur_y += 1
          end
          cur_y += 1
        end

        # Return Value
        if ret = sym.return_type
          buffer.put_string(x, cur_y, "RETURNS: #{ret}", fg: Opal::Color.bright_cyan)
          cur_y += 2
        end

        # Description
        buffer.put_string(x, cur_y, "DESCRIPTION:", fg: Opal::Color.bright_white, bold: true)
        cur_y += 1

        desc_lines = sym.description.lines
        desc_lines = sym.summary.lines if desc_lines.empty?

        # Scroll window for description
        max_desc_lines = h - cur_y - 3
        visible_lines = desc_lines[@doc_scroll_offset, max_desc_lines]? || [] of String

        visible_lines.each do |line|
          buffer.put_string(x, cur_y, line, fg: Opal::Color.bright_white, max_width: w - 2)
          cur_y += 1
        end
      end

      private def handle_input(driver : Opal::Terminal::Driver)
        ev = driver.read_event
        return unless ev.is_a?(Opal::Terminal::KeyEvent)

        if @searching
          if ev.matches?("escape") || ev.matches?("enter")
            @searching = false
          elsif ev.matches?("backspace")
            @search_query = @search_query[0...-1] if @search_query.size > 0
            update_filtered_symbols
          elsif ch = ev.char
            @search_query += ch
            update_filtered_symbols
          end
          return
        end

        case ev.name
        when "escape", "esc", "q"
          @running = false
        when "up", "k"
          @selected_idx = Math.max(0, @selected_idx - 1)
          @doc_scroll_offset = 0
        when "down", "j"
          @selected_idx = Math.min(Math.max(0, @filtered_symbols.size - 1), @selected_idx + 1)
          @doc_scroll_offset = 0
        when "pageup", "u"
          @doc_scroll_offset = Math.max(0, @doc_scroll_offset - 8)
        when "pagedown", "d"
          @doc_scroll_offset += 8
        when "/"
          @searching = true
        when "1"
          @active_context = nil
          update_filtered_symbols
        when "2"
          @active_context = Docs::Context::Godot
          update_filtered_symbols
        when "3"
          @active_context = Docs::Context::Crystal
          update_filtered_symbols
        when "4"
          @active_context = Docs::Context::Guide
          update_filtered_symbols
        when "5"
          @active_context = Docs::Context::Stdlib
          update_filtered_symbols
        end
      end
    end
  end
end
