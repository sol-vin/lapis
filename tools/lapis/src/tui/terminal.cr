module Lapis
  module TUI
    module Terminal
      {% if flag?(:windows) %}
        lib WinConsole
          STD_INPUT_HANDLE  = (-10_i32).to_u32!
          STD_OUTPUT_HANDLE = (-11_i32).to_u32!

          ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004_u32
          ENABLE_PROCESSED_INPUT             = 0x0001_u32
          ENABLE_LINE_INPUT                  = 0x0002_u32
          ENABLE_ECHO_INPUT                  = 0x0004_u32
          ENABLE_VIRTUAL_TERMINAL_INPUT      = 0x0200_u32

          struct COORD
            x : Int16
            y : Int16
          end

          struct SMALL_RECT
            left : Int16
            top : Int16
            right : Int16
            bottom : Int16
          end

          struct CONSOLE_SCREEN_BUFFER_INFO
            dwSize : COORD
            dwCursorPosition : COORD
            wAttributes : UInt16
            srWindow : SMALL_RECT
            dwMaximumWindowSize : COORD
          end

          fun GetConsoleScreenBufferInfo(hConsoleOutput : LibC::HANDLE, lpConsoleScreenBufferInfo : CONSOLE_SCREEN_BUFFER_INFO*) : LibC::BOOL
        end

        @@orig_in_mode : UInt32 = 0_u32
        @@orig_out_mode : UInt32 = 0_u32
        @@in_handle : LibC::HANDLE? = nil
        @@out_handle : LibC::HANDLE? = nil
      {% end %}

      @@is_alternate_screen : Bool = false
      @@is_raw_mode : Bool = false

      # Strip ANSI escape sequences from a string
      def self.strip_ansi(text : String) : String
        text.gsub(/\e\[[0-9;]*[a-zA-Z]/, "")
      end

      # Keys recognized by the TUI input reader
      enum Key
        None
        Char
        Up
        Down
        Left
        Right
        Enter
        Tab
        Backspace
        Escape
        PageUp
        PageDown
        Home
        End
      end

      record KeyEvent, key : Key, char : Char = '\0', ctrl : Bool = false

      def self.init : Nil
        {% if flag?(:windows) %}
          h_out = LibC.GetStdHandle(WinConsole::STD_OUTPUT_HANDLE)
          h_in = LibC.GetStdHandle(WinConsole::STD_INPUT_HANDLE)
          @@out_handle = h_out
          @@in_handle = h_in

          if LibC.GetConsoleMode(h_out, out out_mode) != 0
            @@orig_out_mode = out_mode
            # Enable ANSI escape code processing on Windows console
            LibC.SetConsoleMode(h_out, out_mode | WinConsole::ENABLE_VIRTUAL_TERMINAL_PROCESSING)
          end

          if LibC.GetConsoleMode(h_in, out in_mode) != 0
            @@orig_in_mode = in_mode
          end
        {% end %}
      end

      def self.enter_alternate_screen : Nil
        return if @@is_alternate_screen
        init
        print "\e[?1049h\e[?25l\e[?7l\e[2J\e[H"
        STDOUT.flush
        @@is_alternate_screen = true
      end

      def self.exit_alternate_screen : Nil
        return unless @@is_alternate_screen
        print "\e[?7h\e[?25h\e[?1049l"
        STDOUT.flush
        disable_raw_mode
        @@is_alternate_screen = false
      end

      def self.enable_raw_mode : Nil
        return if @@is_raw_mode
        {% if flag?(:windows) %}
          if h = @@in_handle
            # Raw mode: disable line input and echo
            raw_mode = @@orig_in_mode & ~(WinConsole::ENABLE_LINE_INPUT | WinConsole::ENABLE_ECHO_INPUT)
            raw_mode |= WinConsole::ENABLE_VIRTUAL_TERMINAL_INPUT
            LibC.SetConsoleMode(h, raw_mode)
          end
        {% else %}
          STDIN.raw! rescue nil
        {% end %}
        @@is_raw_mode = true
      end

      def self.disable_raw_mode : Nil
        return unless @@is_raw_mode
        {% if flag?(:windows) %}
          if h = @@in_handle
            LibC.SetConsoleMode(h, @@orig_in_mode)
          end
        {% else %}
          STDIN.cooked! rescue nil
        {% end %}
        @@is_raw_mode = false
      end

      # Non-blocking or timed read of next key event
      def self.read_key_nonblocking : KeyEvent?
        return nil unless STDIN.responds_to?(:read_byte)
        byte = STDIN.read_byte rescue nil
        return nil unless byte

        case byte
        when 3 # Ctrl+C
          KeyEvent.new(Key::Char, 'c', ctrl: true)
        when 13, 10 # Enter
          KeyEvent.new(Key::Enter)
        when 9 # Tab
          KeyEvent.new(Key::Tab)
        when 8, 127 # Backspace
          KeyEvent.new(Key::Backspace)
        when 27 # Escape sequence
          # Peek or short read for arrow keys \e[A, \e[B, etc.
          second = STDIN.read_byte rescue nil
          if second == '['.ord
            third = STDIN.read_byte rescue nil
            case third
            when 'A'.ord then KeyEvent.new(Key::Up)
            when 'B'.ord then KeyEvent.new(Key::Down)
            when 'C'.ord then KeyEvent.new(Key::Right)
            when 'D'.ord then KeyEvent.new(Key::Left)
            when 'H'.ord then KeyEvent.new(Key::Home)
            when 'F'.ord then KeyEvent.new(Key::End)
            when '5'.ord
              STDIN.read_byte rescue nil # consume '~'
              KeyEvent.new(Key::PageUp)
            when '6'.ord
              STDIN.read_byte rescue nil # consume '~'
              KeyEvent.new(Key::PageDown)
            else
              KeyEvent.new(Key::Escape)
            end
          else
            KeyEvent.new(Key::Escape)
          end
        else
          char = byte.chr
          KeyEvent.new(Key::Char, char)
        end
      end

      # Resolves terminal size (columns and rows)
      def self.size : {cols: Int32, rows: Int32}
        {% if flag?(:windows) %}
          h = @@out_handle || LibC.GetStdHandle(WinConsole::STD_OUTPUT_HANDLE)
          if WinConsole.GetConsoleScreenBufferInfo(h, out csbi) != 0
            cols = (csbi.srWindow.right - csbi.srWindow.left + 1).to_i32
            rows = (csbi.srWindow.bottom - csbi.srWindow.top + 1).to_i32
            return {cols: Math.max(cols, 40), rows: Math.max(rows, 15)}
          end
        {% end %}

        env_cols = ENV["COLUMNS"]?.try(&.to_i?)
        env_rows = ENV["LINES"]?.try(&.to_i?)
        {
          cols: env_cols || 100,
          rows: env_rows || 30,
        }
      end

      def self.clear : Nil
        print "\e[2J\e[H"
      end

      def self.move_to(row : Int32, col : Int32) : Nil
        print "\e[#{row};#{col}H"
      end
    end
  end
end
