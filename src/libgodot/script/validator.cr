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
      macro_block_stack = [] of BlockFrame
      delim_stack = [] of DelimFrame

      in_multiline_string = false
      string_delim = '"'
      in_macro_control = false
      macro_control_start = {0, 0}
      in_macro_expr = false
      macro_expr_start = {0, 0}
      macro_expr_brace_depth = 0

      lines.each_with_index do |raw_line, line_idx|
        line_num = line_idx + 1

        # Strip comments, mask string interiors, and extract macro control tokens
        clean_line, macro_line, in_multiline_string, string_delim, in_macro_control, macro_control_start, in_macro_expr, macro_expr_start, macro_expr_brace_depth =
          scan_line_with_macros(
            raw_line,
            line_num,
            in_multiline_string,
            string_delim,
            in_macro_control,
            macro_control_start,
            in_macro_expr,
            macro_expr_start,
            macro_expr_brace_depth
          )

        # 1. Macro control block keywords tracking ({% if/unless/for/begin ... %} ... {% end %})
        unless macro_line.strip.empty?
          macro_tokens = tokenize_line(macro_line)
          macro_tokens.each_with_index do |token, t_idx|
            word = token[:word]
            col = token[:col]

            if word == "end"
              if macro_block_stack.empty?
                errors << ScriptDiagnostic.new(line_num, col, "Unexpected '{% end %}' in macro with no matching macro block")
              else
                macro_block_stack.pop
              end
            elsif opens_macro_block?(word, t_idx, macro_tokens)
              macro_block_stack << BlockFrame.new(word, line_num, col)
            end
          end
        end

        trimmed = clean_line.strip
        next if trimmed.empty?

        # 2. Delimiter balance tracking (parentheses, brackets, braces)
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

        # 3. Block keywords tracking
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

      # Check unclosed macro tags
      if in_macro_control
        errors << ScriptDiagnostic.new(
          macro_control_start[0],
          macro_control_start[1],
          "Unclosed macro control tag '{%', expected '%}'"
        )
      end

      if in_macro_expr
        errors << ScriptDiagnostic.new(
          macro_expr_start[0],
          macro_expr_start[1],
          "Unclosed macro expression '{{', expected '}}'"
        )
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

      # Check unclosed macro control blocks
      if unclosed_macro = macro_block_stack.last?
        errors << ScriptDiagnostic.new(
          lines.size,
          1,
          "Unexpected end of file: missing '{% end %}' for macro '#{unclosed_macro.type}' opened at line #{unclosed_macro.line}"
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
      when "do", "case"
        true
      when "while", "until", "if", "unless"
        # Open block if keyword is at start of statement or right-hand side of assignment/delimiter,
        # not postfix modifier (e.g. 'return if condition')
        statement_start_or_assigned?(idx, tokens)
      else
        false
      end
    end

    # Determines whether a token inside {% ... %} initiates a macro control block requiring 'end'
    private def opens_macro_block?(word : String, idx : Int32, tokens : Array(NamedTuple(word: String, col: Int32))) : Bool
      case word
      when "for", "begin", "do", "case"
        true
      when "if", "unless"
        statement_start_or_assigned?(idx, tokens)
      else
        false
      end
    end

    private def statement_start_or_assigned?(idx : Int32, tokens : Array(NamedTuple(word: String, col: Int32))) : Bool
      return true if idx == 0
      prev = tokens[idx - 1][:word]
      prev == "=" || prev == ";" || prev == "(" || prev == "[" || prev == "{" || prev == ","
    end

    # Scans a single line, stripping comments, masking string interiors, masking {{ ... }} and {% ... %},
    # and extracting the code interior of {% ... %} into macro_line for macro block validation.
    private def scan_line_with_macros(
      line : String,
      line_num : Int32,
      in_str : Bool,
      str_char : Char,
      in_macro_ctrl : Bool,
      macro_ctrl_start : Tuple(Int32, Int32),
      in_macro_expr : Bool,
      macro_expr_start : Tuple(Int32, Int32),
      macro_expr_depth : Int32
    ) : Tuple(String, String, Bool, Char, Bool, Tuple(Int32, Int32), Bool, Tuple(Int32, Int32), Int32)
      clean_sb = String::Builder.new(line.bytesize)
      macro_sb = String::Builder.new(line.bytesize)

      escaped = false
      macro_in_str = false
      macro_str_char = '"'
      macro_escaped = false
      macro_in_comment = false
      prev_ch = '\0'
      prev_non_ws = '\0'

      chars = line.chars
      len = chars.size
      i = 0

      while i < len
        ch = chars[i]
        nxt = (i + 1 < len) ? chars[i + 1] : '\0'

        if in_macro_ctrl
          clean_sb << ' '
          if macro_in_comment
            macro_sb << ' '
          elsif macro_in_str
            macro_sb << ' '
            if macro_escaped
              macro_escaped = false
            elsif ch == '\\'
              macro_escaped = true
            elsif ch == macro_str_char
              macro_in_str = false
            end
          else
            if ch == '%' && nxt == '}'
              clean_sb << ' '
              macro_sb << ';' << ' '
              in_macro_ctrl = false
              prev_ch = '}'
              prev_non_ws = '}'
              i += 2
              next
            elsif ch == '#'
              macro_in_comment = true
              macro_sb << ' '
            elsif ch == '"' || ch == '\''
              macro_in_str = true
              macro_str_char = ch
              macro_sb << ' '
            else
              macro_sb << ch
            end
          end
          i += 1
          next
        end

        if in_macro_expr
          clean_sb << ' '
          macro_sb << ' '
          if macro_in_comment
            # Ignore until end of line
          elsif macro_in_str
            if macro_escaped
              macro_escaped = false
            elsif ch == '\\'
              macro_escaped = true
            elsif ch == macro_str_char
              macro_in_str = false
            end
          else
            if ch == '}' && nxt == '}' && macro_expr_depth == 0
              clean_sb << ' '
              macro_sb << ' '
              in_macro_expr = false
              prev_ch = '}'
              prev_non_ws = '}'
              i += 2
              next
            elsif ch == '{'
              macro_expr_depth += 1
            elsif ch == '}' && macro_expr_depth > 0
              macro_expr_depth -= 1
            elsif ch == '#'
              macro_in_comment = true
            elsif ch == '"' || ch == '\''
              macro_in_str = true
              macro_str_char = ch
            end
          end
          i += 1
          next
        end

        if in_str
          macro_sb << ' '
          if escaped
            clean_sb << ' '
            escaped = false
          elsif ch == '\\'
            clean_sb << ' '
            escaped = true
          elsif ch == str_char
            clean_sb << ch
            in_str = false
            prev_ch = ch
            prev_non_ws = ch
          else
            clean_sb << ' '
          end
          i += 1
          next
        end

        # Normal code state
        if ch == '#'
          break
        elsif ch == '{' && nxt == '%'
          in_macro_ctrl = true
          macro_ctrl_start = {line_num, i + 1}
          macro_in_str = false
          macro_escaped = false
          macro_in_comment = false
          clean_sb << ' ' << ' '
          macro_sb << ' ' << ';'
          i += 2
          next
        elsif ch == '{' && nxt == '{'
          in_macro_expr = true
          macro_expr_start = {line_num, i + 1}
          macro_expr_depth = 0
          macro_in_str = false
          macro_escaped = false
          macro_in_comment = false
          clean_sb << ' ' << ' '
          macro_sb << ' ' << ' '
          i += 2
          next
        elsif ch == '%' && (pct_end = try_scan_percent_literal(chars, i))
          clean_sb << '"'
          macro_sb << ' '
          (pct_end - i - 1).times do
            clean_sb << ' '
            macro_sb << ' '
          end
          clean_sb << '"'
          macro_sb << ' '
          prev_ch = '"'
          prev_non_ws = '"'
          i = pct_end + 1
          next
        elsif ch == '/' && nxt == '/'
          clean_sb << '/' << '/'
          macro_sb << ' ' << ' '
          prev_ch = '/'
          prev_non_ws = '/'
          i += 2
          next
        elsif ch == '/' && (rx_end = try_scan_regex_literal(chars, i, prev_ch, prev_non_ws))
          clean_sb << '"'
          macro_sb << ' '
          (rx_end - i - 1).times do
            clean_sb << ' '
            macro_sb << ' '
          end
          clean_sb << '"'
          macro_sb << ' '
          prev_ch = '"'
          prev_non_ws = '"'
          i = rx_end + 1
          next
        elsif ch == '"' || ch == '\''
          # Handle char literal '\'' or '#' or '{' etc.
          if ch == '\''
            if nxt == '\\' && i + 3 < len && chars[i + 3] == '\''
              clean_sb << '\'' << ' ' << ' ' << '\''
              macro_sb << ' ' << ' ' << ' ' << ' '
              prev_ch = '\''
              prev_non_ws = '\''
              i += 4
              next
            elsif nxt != '\'' && i + 2 < len && chars[i + 2] == '\''
              clean_sb << '\'' << ' ' << '\''
              macro_sb << ' ' << ' ' << ' '
              prev_ch = '\''
              prev_non_ws = '\''
              i += 3
              next
            end
          end
          in_str = true
          str_char = ch
          escaped = false
          clean_sb << ch
          macro_sb << ' '
          prev_ch = ch
          prev_non_ws = ch
        else
          clean_sb << ch
          macro_sb << ' '
          prev_ch = ch
          prev_non_ws = ch unless ch.whitespace?
        end

        i += 1
      end

      {
        clean_sb.to_s,
        macro_sb.to_s,
        in_str,
        str_char,
        in_macro_ctrl,
        macro_ctrl_start,
        in_macro_expr,
        macro_expr_start,
        macro_expr_depth,
      }
    end

    # Attempts to scan a single-line percent literal (e.g. %(...), %q(...), %Q[...], %w{...}, %r(...))
    # starting at index `i` (where `chars[i] == '%'`). Returns the inclusive end index if matched.
    private def try_scan_percent_literal(chars : Array(Char), i : Int32) : Int32?
      len = chars.size
      return nil if i + 2 >= len

      idx = i + 1
      if chars[idx].in?('q', 'Q', 'w', 'i', 'r', 'x')
        idx += 1
        return nil if idx >= len
      end

      open_d = chars[idx]
      close_d = case open_d
                when '(' then ')'
                when '[' then ']'
                when '{' then '}'
                when '<' then '>'
                when '|'
                  # Bare `%|` is only valid with a percent modifier like `%q|...|`
                  return nil if idx == i + 1
                  '|'
                else
                  return nil
                end

      depth = 1
      escaped = false
      j = idx + 1
      while j < len
        c = chars[j]
        if escaped
          escaped = false
        elsif c == '\\'
          escaped = true
        elsif open_d != close_d && c == open_d
          depth += 1
        elsif c == close_d
          depth -= 1
          return j if depth == 0
        end
        j += 1
      end

      nil
    end

    # Attempts to scan a single-line regex literal `/.../` starting at `i` (where `chars[i] == '/'`).
    # Returns the inclusive end index (including trailing regex flags i, m, x) if matched.
    private def try_scan_regex_literal(chars : Array(Char), i : Int32, prev_ch : Char, prev_non_ws : Char) : Int32?
      len = chars.size
      return nil if i + 1 >= len

      nxt = chars[i + 1]
      return nil if nxt == '/' || nxt == ' ' || nxt == '\t' || nxt == '=' || nxt == '\0'

      can_start_regex = prev_non_ws == '\0' ||
                        prev_non_ws.in?('(', ',', '=', ':', ';', '[', '{', '!', '~', '?', '|', '&', '<', '>', '+', '-', '*', '%', '^') ||
                        prev_ch.whitespace?
      return nil unless can_start_regex

      escaped = false
      in_char_class = false
      j = i + 1
      while j < len
        c = chars[j]
        if escaped
          escaped = false
        elsif c == '\\'
          escaped = true
        elsif in_char_class
          in_char_class = false if c == ']'
        elsif c == '['
          in_char_class = true
        elsif c == '/'
          k = j + 1
          while k < len && chars[k].in?('i', 'm', 'x')
            k += 1
          end
          return k - 1
        end
        j += 1
      end

      nil
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
