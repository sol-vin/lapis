# =============================================================================
# LibGodot - Fast In-Editor Crystal Syntax & Structure Validator
# =============================================================================
# Ultra-fast, sub-millisecond static analyzer for in-editor script validation.
# Detects unclosed blocks, missing/unexpected 'end' tokens, unclosed strings,
# and unbalanced delimiters to power real-time in-editor red squiggles in Godot.
# =============================================================================

module Lapis
  struct ScriptDiagnostic
    property line : Int32
    property column : Int32
    property message : String
    property severity : Int32 # 1: Error, 2: Warning

    def initialize(@line : Int32, @column : Int32, @message : String, @severity : Int32 = 1)
    end
  end

  struct ValidationResult
    property? valid : Bool
    property errors : Array(ScriptDiagnostic)
    property warnings : Array(ScriptDiagnostic)

    def initialize(
      @valid : Bool,
      @errors : Array(ScriptDiagnostic) = [] of ScriptDiagnostic,
      @warnings : Array(ScriptDiagnostic) = [] of ScriptDiagnostic
    )
    end
  end

  class CrystalValidator
    private struct BlockFrame
      getter type : String
      getter line : Int32
      getter col : Int32

      def initialize(@type : String, @line : Int32, @col : Int32)
      end
    end

    private struct DelimFrame
      getter char : Char
      getter line : Int32
      getter col : Int32

      def initialize(@char : Char, @line : Int32, @col : Int32)
      end
    end

    def self.validate(code : String, path : String = "") : ValidationResult
      new.validate(code, path)
    end

    def validate(code : String, path : String = "") : ValidationResult
      errors = [] of ScriptDiagnostic
      warnings = [] of ScriptDiagnostic

      lines = code.gsub("\r\n", "\n").split('\n')
      block_stack = [] of BlockFrame
      delim_stack = [] of DelimFrame

      in_multiline_string = false
      multiline_delim = '"'

      lines.each_with_index do |raw_line, line_idx|
        line_num = line_idx + 1

        # Strip line comments while respecting strings
        clean_line, string_open = strip_comments_and_track_strings(raw_line, in_multiline_string)
        if string_open
          in_multiline_string = true
        elsif in_multiline_string && !string_open
          in_multiline_string = false
        end

        trimmed = clean_line.strip
        next if trimmed.empty?

        # 1. Delimiter balance tracking (parentheses, brackets, braces)
        clean_line.each_char_with_index do |ch, col_idx|
          case ch
          when '(', '[', '{'
            delim_stack << DelimFrame.new(ch, line_num, col_idx + 1)
          when ')'
            if delim_stack.empty? || delim_stack.last.char != '('
              errors << ScriptDiagnostic.new(line_num, col_idx + 1, "Unexpected closing parenthesis ')'")
            else
              delim_stack.pop
            end
          when ']'
            if delim_stack.empty? || delim_stack.last.char != '['
              errors << ScriptDiagnostic.new(line_num, col_idx + 1, "Unexpected closing bracket ']'")
            else
              delim_stack.pop
            end
          when '}'
            if delim_stack.empty? || delim_stack.last.char != '{'
              errors << ScriptDiagnostic.new(line_num, col_idx + 1, "Unexpected closing brace '}'")
            else
              delim_stack.pop
            end
          end
        end

        # 2. Block keywords tracking
        tokens = tokenize_line(clean_line)
        next if tokens.empty?

        # Check closing 'end'
        tokens.each_with_index do |token, t_idx|
          word = token[:word]
          col = token[:col]

          if word == "end"
            if block_stack.empty?
              errors << ScriptDiagnostic.new(line_num, col, "Unexpected 'end' with no matching block")
            else
              block_stack.pop
            end
          elsif opens_block?(word, t_idx, tokens, trimmed)
            block_stack << BlockFrame.new(word, line_num, col)
          end
        end
      end

      # Check unclosed multiline strings
      if in_multiline_string
        errors << ScriptDiagnostic.new(lines.size, 1, "Unterminated multiline string literal")
      end

      # Check unclosed delimiters
      if unclosed_delim = delim_stack.last?
        expected = case unclosed_delim.char
                   when '(' then "')'"
                   when '[' then "']'"
                   when '{' then "'}'"
                   else "closing delimiter"
                   end
        errors << ScriptDiagnostic.new(
          unclosed_delim.line,
          unclosed_delim.col,
          "Unclosed '#{unclosed_delim.char}', expected #{expected}"
        )
      end

      # Check unclosed blocks
      if unclosed_block = block_stack.last?
        errors << ScriptDiagnostic.new(
          lines.size,
          1,
          "Unexpected end of file: missing 'end' for '#{unclosed_block.type}' opened at line #{unclosed_block.line}"
        )
      end

      ValidationResult.new(errors.empty?, errors, warnings)
    end

    # Determines whether token initiates a new block requiring 'end'
    private def opens_block?(word : String, idx : Int32, tokens : Array(NamedTuple(word: String, col: Int32)), full_trimmed : String) : Bool
      case word
      when "def", "class", "module", "struct", "enum", "lib", "macro", "begin"
        # In Crystal: def, class, module, struct, enum, macro always open blocks
        # (unless single-line abstract def, e.g. 'abstract def foo : Void')
        if word == "def"
          first_word = tokens.first? ? tokens.first[:word] : ""
          return false if first_word == "abstract"
        end
        true
      when "do"
        true
      when "case"
        true
      when "while", "until"
        # Only open block if keyword is at statement start, not postfix modifier (e.g. 'x += 1 while active')
        idx == 0
      when "if", "unless"
        # Only open block if keyword is at start of statement (not postfix e.g. 'return if condition')
        # And not single-line 'if cond; body; end' (handled by token iteration)
        idx == 0
      else
        false
      end
    end

    # Strips comments while ignoring '#' inside strings
    private def strip_comments_and_track_strings(line : String, currently_in_string : Bool) : Tuple(String, Bool)
      sb = String::Builder.new
      in_str = currently_in_string
      str_char = '"'
      escaped = false

      line.each_char do |ch|
        if in_str
          sb << ch
          if escaped
            escaped = false
          elsif ch == '\\'
            escaped = true
          elsif ch == str_char
            in_str = false
          end
        else
          if ch == '#'
            # Rest of line is comment
            break
          elsif ch == '"' || ch == '\''
            in_str = true
            str_char = ch
            sb << ch
          else
            sb << ch
          end
        end
      end

      {sb.to_s, in_str}
    end

    # Splits code into alphanumeric words and special symbols with column positions
    private def tokenize_line(line : String) : Array(NamedTuple(word: String, col: Int32))
      tokens = [] of NamedTuple(word: String, col: Int32)
      i = 0
      len = line.size

      while i < len
        ch = line[i]
        if ch.whitespace?
          i += 1
          next
        end

        col = i + 1
        if ch.ascii_alphanumeric? || ch == '_'
          start_idx = i
          while i < len && (line[i].ascii_alphanumeric? || line[i] == '_' || line[i] == '!' || line[i] == '?')
            i += 1
          end
          word = line[start_idx...i]
          tokens << {word: word, col: col}
        else
          # Single symbol
          tokens << {word: ch.to_s, col: col}
          i += 1
        end
      end

      tokens
    end
  end
end
