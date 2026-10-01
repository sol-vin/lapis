require "opal"

module Lapis
  module TUI
    module Terminal
      {% if flag?(:windows) %}
        STD_INPUT_HANDLE  = (-10_i32).to_u32!
        STD_OUTPUT_HANDLE = (-11_i32).to_u32!

        ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004_u32
        ENABLE_PROCESSED_INPUT             = 0x0001_u32
        ENABLE_LINE_INPUT                  = 0x0002_u32
        ENABLE_ECHO_INPUT                  = 0x0004_u32
        ENABLE_VIRTUAL_TERMINAL_INPUT      = 0x0200_u32

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

      record KeyEvent, key : Key, char : Char = '\0', ctrl : Bool = false do
        def to_opal_key_event : Opal::Terminal::KeyEvent
          case key
          when Key::Enter
            Opal::Terminal::KeyEvent.new("enter", '\n')
          when Key::Escape
            Opal::Terminal::KeyEvent.new("escape")
          when Key::Tab
            Opal::Terminal::KeyEvent.new("tab", '\t')
          when Key::Backspace
            Opal::Terminal::KeyEvent.new("backspace")
          when Key::Up
            Opal::Terminal::KeyEvent.new("up")
          when Key::Down
            Opal::Terminal::KeyEvent.new("down")
          when Key::Left
            Opal::Terminal::KeyEvent.new("left")
          when Key::Right
            Opal::Terminal::KeyEvent.new("right")
          when Key::PageUp
            Opal::Terminal::KeyEvent.new("pageup")
          when Key::PageDown
            Opal::Terminal::KeyEvent.new("pagedown")
          when Key::Home
            Opal::Terminal::KeyEvent.new("home")
          when Key::End
            Opal::Terminal::KeyEvent.new("end")
          when Key::Char
            if char == ' '
              Opal::Terminal::KeyEvent.new("space", ' ')
            else
              Opal::Terminal::KeyEvent.new(char.to_s, char, ctrl: ctrl)
            end
          else
            Opal::Terminal::KeyEvent.new("")
          end
        end
      end

      def self.init : Nil
        {% if flag?(:windows) %}
          h_out = LibC.GetStdHandle(STD_OUTPUT_HANDLE)
          h_in = LibC.GetStdHandle(STD_INPUT_HANDLE)
          @@out_handle = h_out
          @@in_handle = h_in

          if LibC.GetConsoleMode(h_out, out out_mode) != 0
            @@orig_out_mode = out_mode
            # Enable ANSI escape code processing on Windows console
            LibC.SetConsoleMode(h_out, out_mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING)
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
            raw_mode = @@orig_in_mode & ~(ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT)
            raw_mode |= ENABLE_VIRTUAL_TERMINAL_INPUT
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
        w, h = Opal::Terminal.default_driver.size
        {
          cols: Math.max(w, 40),
          rows: Math.max(h, 15),
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
