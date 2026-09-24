# tools/lapis/src/tui/canvas.cr

module Lapis
  module TUI
    struct Style
      property fg : String? = nil
      property bg : String? = nil
      property bold : Bool = false
      property dim : Bool = false
      property reverse : Bool = false

      def initialize(
        @fg : String? = nil,
        @bg : String? = nil,
        @bold : Bool = false,
        @dim : Bool = false,
        @reverse : Bool = false
      )
      end

      def self.none : Style
        Style.new
      end

      def ==(other : Style) : Bool
        @fg == other.fg &&
          @bg == other.bg &&
          @bold == other.bold &&
          @dim == other.dim &&
          @reverse == other.reverse
      end

      def to_ansi : String
        parts = [] of String
        parts << "1" if @bold
        parts << "2" if @dim
        parts << "7" if @reverse
        parts << @fg.not_nil! if @fg
        parts << @bg.not_nil! if @bg
        return "\e[0m" if parts.empty?
        "\e[0;" + parts.join(";") + "m"
      end
    end

    struct Cell
      property char : Char = ' '
      property style : Style = Style.none
      property wide : Bool = false
      property continuation : Bool = false

      def initialize(
        @char : Char = ' ',
        @style : Style = Style.none,
        @wide : Bool = false,
        @continuation : Bool = false
      )
      end
    end

    class Canvas
      getter width : Int32
      getter height : Int32
      @grid : Array(Array(Cell))

      def initialize(@width : Int32, @height : Int32)
        @width = Math.max(1, @width)
        @height = Math.max(1, @height)
        @grid = Array(Array(Cell)).new(@height) do
          Array(Cell).new(@width) { Cell.new }
        end
      end

      def clear(char : Char = ' ', style : Style = Style.none) : Nil
        (0...@height).each do |r|
          (0...@width).each do |c|
            @grid[r][c] = Cell.new(char: char, style: style)
          end
        end
      end

      # Determine display width of a single character
      def self.char_width(c : Char) : Int32
        ord = c.ord
        return 0 if ord < 32 || (ord >= 127 && ord < 160)
        # Emojis and miscellaneous symbols
        return 2 if ord >= 0x1F300 && ord <= 0x1FAFF
        return 2 if ord == 0x23F3 # ⏳
        return 2 if ord == 0x231B # ⌛
        return 2 if ord == 0x26FD # ⛽
        # CJK Ideographs
        return 2 if ord >= 0x2E80 && ord <= 0x9FFF
        return 2 if ord >= 0xFF01 && ord <= 0xFF60
        1
      end

      # Determine display width of a string (stripping ANSI escapes)
      def self.display_width(text : String) : Int32
        w = 0
        reader = Char::Reader.new(text)
        while reader.has_next?
          c = reader.current_char
          if c == '\e'
            reader.next_char
            if reader.has_next?
              if reader.current_char == '['
                reader.next_char
                # Consume parameter and intermediate characters (0x20..0x3F, like ?, ;, 0-9)
                while reader.has_next? && (reader.current_char.ord >= 0x20 && reader.current_char.ord <= 0x3F)
                  reader.next_char
                end
                # Consume final character (0x40..0x7E, like m, H, J, K, etc.)
                if reader.has_next? && (reader.current_char.ord >= 0x40 && reader.current_char.ord <= 0x7E)
                  reader.next_char
                end
              else
                reader.next_char
              end
            end
          else
            w += char_width(c)
            reader.next_char
          end
        end
        w
      end

      # Safely write a cell at (x, y)
      def set_cell(x : Int32, y : Int32, char : Char, style : Style = Style.none, wide : Bool = false, continuation : Bool = false) : Nil
        return if y < 0 || y >= @height || x < 0 || x >= @width
        @grid[y][x] = Cell.new(char, style, wide, continuation)
      end

      # Fill a rectangular region
      def fill_rect(x : Int32, y : Int32, w : Int32, h : Int32, char : Char = ' ', style : Style = Style.none) : Nil
        (y...(y + h)).each do |row|
          next if row < 0 || row >= @height
          (x...(x + w)).each do |col|
            next if col < 0 || col >= @width
            @grid[row][col] = Cell.new(char: char, style: style)
          end
        end
      end

      # Draw a box with single or double borders
      def draw_box(
        x : Int32,
        y : Int32,
        w : Int32,
        h : Int32,
        title : String? = nil,
        double_border : Bool = false,
        border_style : Style = Style.none,
        title_style : Style = Style.none
      ) : Nil
        return if w < 2 || h < 2
        return if x >= @width || y >= @height
        right = Math.min(@width - 1, x + w - 1)
        bottom = Math.min(@height - 1, y + h - 1)

        tl = double_border ? '╔' : '┌'
        tr = double_border ? '╗' : '┐'
        bl = double_border ? '╚' : '└'
        br = double_border ? '╝' : '┘'
        h_line = double_border ? '═' : '─'
        v_line = double_border ? '║' : '│'

        # Corners
        set_cell(x, y, tl, border_style)
        set_cell(right, y, tr, border_style)
        set_cell(x, bottom, bl, border_style)
        set_cell(right, bottom, br, border_style)

        # Top and bottom horizontal lines
        ((x + 1)...right).each do |col|
          set_cell(col, y, h_line, border_style)
          set_cell(col, bottom, h_line, border_style)
        end

        # Left and right vertical lines
        ((y + 1)...bottom).each do |row|
          set_cell(x, row, v_line, border_style)
          set_cell(right, row, v_line, border_style)
        end

        # Optional Title on top border
        if title && !title.empty?
          t_w = Canvas.display_width(title)
          avail_w = w - 4
          if avail_w > 0
            start_x = x + 2
            # Center title if space permits
            if avail_w > t_w
              start_x = x + (w - t_w) // 2
            end
            draw_text(start_x, y, title, max_w: avail_w, default_style: title_style)
          end
        end
      end

      # Draw text supporting inline ANSI codes, wide unicode, and strict column bounds
      def draw_text(
        x : Int32,
        y : Int32,
        text : String,
        max_w : Int32? = nil,
        default_style : Style = Style.none
      ) : Int32
        return 0 if y < 0 || y >= @height || x >= @width
        limit_x = max_w ? Math.min(@width, x + max_w) : @width

        curr_x = x
        curr_style = default_style

        reader = Char::Reader.new(text)

        while reader.has_next? && curr_x < limit_x
          c = reader.current_char
          if c == '\e'
            reader.next_char
            if reader.has_next? && reader.current_char == '['
              seq_buf = IO::Memory.new
              reader.next_char
              while reader.has_next? && (reader.current_char.ascii_number? || reader.current_char == ';')
                seq_buf << reader.current_char
                reader.next_char
              end
              if reader.current_char == 'm'
                curr_style = parse_ansi_style(seq_buf.to_s, curr_style)
                reader.next_char
                next
              end
            end
          else
            cw = Canvas.char_width(c)
            if cw > 0
              if curr_x + cw <= limit_x
                if cw == 2
                  set_cell(curr_x, y, c, curr_style, wide: true, continuation: false)
                  set_cell(curr_x + 1, y, ' ', curr_style, wide: false, continuation: true)
                  curr_x += 2
                else
                  set_cell(curr_x, y, c, curr_style, wide: false, continuation: false)
                  curr_x += 1
                end
              else
                break
              end
            end
            reader.next_char
          end
        end

        curr_x - x
      end

      # Draw a horizontal progress bar
      def draw_bar(
        x : Int32,
        y : Int32,
        w : Int32,
        ratio : Float64,
        filled_char : Char = '█',
        empty_char : Char = '░',
        filled_style : Style = Style.none,
        empty_style : Style = Style.none
      ) : Nil
        return if w <= 0 || y < 0 || y >= @height
        clamped_ratio = Math.max(0.0, Math.min(1.0, ratio))
        filled_w = (clamped_ratio * w).round.to_i

        (0...filled_w).each do |offset|
          col = x + offset
          break if col >= @width
          set_cell(col, y, filled_char, filled_style)
        end

        (filled_w...w).each do |offset|
          col = x + offset
          break if col >= @width
          set_cell(col, y, empty_char, empty_style)
        end
      end

      # Render each row as a styled line string (useful for testing, inspection, or static rendering)
      def render_lines : Array(String)
        lines = Array(String).new(@height)
        (0...@height).each do |row|
          line_buf = IO::Memory.new
          last_style = Style.none
          has_active_style = false

          (0...@width).each do |col|
            cell = @grid[row][col]
            next if cell.continuation

            if cell.style != last_style
              line_buf << cell.style.to_ansi
              last_style = cell.style
              has_active_style = (cell.style != Style.none)
            end

            line_buf << cell.char
          end

          line_buf << "\e[0m" if has_active_style
          lines << line_buf.to_s
        end
        lines
      end

      # Render the 2D grid into an atomic ANSI escape string buffer for full-screen terminal display.
      # Uses absolute row positioning \e[<row>;1H and erase-line \e[K with NO newlines (\n) to prevent viewport scrolling.
      def render_to_string : String
        buffer = IO::Memory.new

        # Move to top-left home position, hide cursor, disable auto-wrap
        buffer << "\e[?25l\e[?7l\e[H"

        last_style = Style.none
        has_active_style = false

        (0...@height).each do |row|
          buffer << "\e[" << (row + 1) << ";1H"

          (0...@width).each do |col|
            cell = @grid[row][col]

            # Skip continuation cells for wide characters (terminal already advanced)
            next if cell.continuation

            if cell.style != last_style
              buffer << cell.style.to_ansi
              last_style = cell.style
              has_active_style = (cell.style != Style.none)
            end

            buffer << cell.char
          end

          # Reset styling at the end of the line
          if has_active_style
            buffer << "\e[0m"
            last_style = Style.none
            has_active_style = false
          end

          # Clear any remaining cells to the right margin to prevent ghost characters
          buffer << "\e[K"
        end

        buffer << "\e[0m"
        buffer.to_s
      end

      private def parse_ansi_style(seq : String, current : Style) : Style
        new_style = current
        parts = seq.split(';')

        idx = 0
        while idx < parts.size
          code = parts[idx].to_i? || 0
          case code
          when 0 # Reset
            new_style = Style.none
          when 1 # Bold
            new_style.bold = true
          when 2 # Dim
            new_style.dim = true
          when 7 # Reverse
            new_style.reverse = true
          when 22 # Normal intensity
            new_style.bold = false
            new_style.dim = false
          when 27 # Reverse off
            new_style.reverse = false
          when 30..37 # 16-color foreground
            new_style.fg = code.to_s
          when 38 # Extended foreground: 38;5;N or 38;2;R;G;B
            if idx + 2 < parts.size && parts[idx + 1] == "5"
              color_idx = parts[idx + 2]
              new_style.fg = "38;5;#{color_idx}"
              idx += 2
            elsif idx + 4 < parts.size && parts[idx + 1] == "2"
              r = parts[idx + 2]
              g = parts[idx + 3]
              b = parts[idx + 4]
              new_style.fg = "38;2;#{r};#{g};#{b}"
              idx += 4
            end
          when 39 # Default foreground
            new_style.fg = nil
          when 40..47 # 16-color background
            new_style.bg = code.to_s
          when 48 # Extended background: 48;5;N or 48;2;R;G;B
            if idx + 2 < parts.size && parts[idx + 1] == "5"
              color_idx = parts[idx + 2]
              new_style.bg = "48;5;#{color_idx}"
              idx += 2
            elsif idx + 4 < parts.size && parts[idx + 1] == "2"
              r = parts[idx + 2]
              g = parts[idx + 3]
              b = parts[idx + 4]
              new_style.bg = "48;2;#{r};#{g};#{b}"
              idx += 4
            end
          when 49 # Default background
            new_style.bg = nil
          when 90..97 # High-intensity foreground
            new_style.fg = code.to_s
          when 100..107 # High-intensity background
            new_style.bg = code.to_s
          end
          idx += 1
        end

        new_style
      end
    end
  end
end
