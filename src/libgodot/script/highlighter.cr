module Lapis
  include Godot
  # Represents a single colored span on a line for Godot's CodeEdit
  struct SyntaxSpan
    property column : Int32
    property r : Float32
    property g : Float32
    property b : Float32
    property a : Float32

    def initialize(@column : Int32, @r : Float32, @g : Float32, @b : Float32, @a : Float32 = 1.0_f32)
    end
  end

  # High-performance, zero-dependency Crystal syntax tokenizer and highlighter.
  # Operates completely independently of any external language servers or daemons.
  @[Tool]
  node CrystalHighlighter < EditorSyntaxHighlighter do
    # Theme color palettes for Godot's script editor
    COLOR_DEFAULT      = {0.85_f32, 0.85_f32, 0.85_f32, 1.0_f32}
    COLOR_KEYWORD      = {0.85_f32, 0.45_f32, 0.90_f32, 1.0_f32} # Magenta / Purple
    COLOR_CONTROL_FLOW = {0.95_f32, 0.40_f32, 0.40_f32, 1.0_f32} # Coral / Red
    COLOR_SPECIAL      = {0.45_f32, 0.65_f32, 0.95_f32, 1.0_f32} # Sky Blue
    COLOR_TYPE         = {0.95_f32, 0.85_f32, 0.35_f32, 1.0_f32} # Bright Gold / Yellow
    COLOR_STRING       = {0.45_f32, 0.85_f32, 0.50_f32, 1.0_f32} # Mint Green
    COLOR_SYMBOL       = {0.30_f32, 0.85_f32, 0.90_f32, 1.0_f32} # Cyan
    COLOR_NUMBER       = {0.95_f32, 0.65_f32, 0.30_f32, 1.0_f32} # Warm Orange
    COLOR_COMMENT      = {0.55_f32, 0.55_f32, 0.55_f32, 1.0_f32} # Muted Gray
    COLOR_ANNOTATION   = {0.95_f32, 0.55_f32, 0.80_f32, 1.0_f32} # Pink / Gold

    KEYWORDS_DEF = Set{
      "node", "resource", "gdclass", "class", "module", "struct", "def", "end", "property", "getter",
      "setter", "signal", "alias", "enum", "lib", "fun", "macro", "onready",
      "abstract_class", "static_unload"
    }

    KEYWORDS_CONTROL = Set{
      "if", "else", "elsif", "unless", "while", "until", "for", "in",
      "case", "when", "then", "return", "break", "next", "yield",
      "begin", "rescue", "ensure", "raise", "do", "select"
    }

    KEYWORDS_SPECIAL = Set{
      "self", "super", "nil", "true", "false", "as", "as?", "is_a?",
      "responds_to?", "sizeof", "instance_sizeof", "typeof", "require",
      "include", "extend", "spawn"
    }

    def self._godot_has_virtual_method(method_name : String) : Bool
      norm = method_name.starts_with?('_') ? method_name : "_#{method_name}"
      case norm
      when "_get_name", "_get_supported_languages", "_get_line_syntax_highlighting",
           "_create", "_clear_highlighting_cache", "_update_cache"
        true
      else
        false
      end
    end

    def _godot_call_virtual_with_data(method_name : String, args : Void**, ret : Void*) : Void
      norm = method_name.starts_with?('_') ? method_name : "_#{method_name}"
      case norm
      when "_get_name"
        Bridge.ret_string(ret, "Crystal")
      when "_get_supported_languages"
        Bridge.ret_packed_string_array(ret, ["Crystal", "cr", "CrystalScript"])
      when "_create"
        hl = Godot.create(Godot::CrystalHighlighter)
        if hl && !hl.pointer.null?
          Bridge.ret_ref(ret, hl.pointer)
        else
          Bridge.ret_ref(ret, Pointer(Void).null)
        end
      when "_clear_highlighting_cache", "_update_cache"
        return
      when "_get_line_syntax_highlighting"
        line_num = args[0].as(Int32*).value.to_i64
        Bridge.ret_dictionary_empty(ret)

        text_edit = get_text_edit
        if text_edit && !text_edit.pointer.null?
          line_text = Bridge.text_edit_get_line(text_edit.pointer, line_num)
          spans = CrystalHighlighter.highlight_line(line_text)
          spans.each do |span|
            Bridge.highlighter_add_span(ret, span.column.to_i64, span.r, span.g, span.b, span.a)
          end
        end
      else
        super
      end
    end

    def _get_name : String
      "Crystal"
    end

    def _get_supported_languages : Array(String)
      ["Crystal", "cr", "CrystalScript"]
    end

    # Tokenizes a single line of Crystal source code into an array of SyntaxSpans
    def self.highlight_line(line : String) : Array(SyntaxSpan)
      spans = [] of SyntaxSpan
      len = line.bytesize
      return spans if len == 0

      i = 0
      bytes = line.to_slice

      while i < len
        c = bytes[i].chr

        # Whitespace
        if c == ' ' || c == '\t' || c == '\r' || c == '\n'
          i += 1
          next
        end

        # Line Comment: # ...
        if c == '#'
          add_span(spans, i, COLOR_COMMENT)
          # Remainder of line is comment
          break
        end

        # Annotation: @[...] or property: @ident
        if c == '@'
          start_col = i
          if i + 1 < len && bytes[i + 1].chr == '['
            # Annotation @[...]
            i += 2
            bracket_depth = 1
            while i < len && bracket_depth > 0
              if bytes[i].chr == '['
                bracket_depth += 1
              elsif bytes[i].chr == ']'
                bracket_depth -= 1
              end
              i += 1
            end
            add_span(spans, start_col, COLOR_ANNOTATION)
            add_span(spans, i, COLOR_DEFAULT)
            next
          else
            # Instance variable or attribute like @pointer
            i += 1
            while i < len && (bytes[i].chr.alphanumeric? || bytes[i].chr == '_')
              i += 1
            end
            add_span(spans, start_col, COLOR_SPECIAL)
            add_span(spans, i, COLOR_DEFAULT)
            next
          end
        end

        # Strings: "...", '...', `...`
        if c == '"' || c == '\'' || c == '`'
          quote_char = c
          start_col = i
          i += 1
          escaped = false
          while i < len
            curr = bytes[i].chr
            if escaped
              escaped = false
            elsif curr == '\\'
              escaped = true
            elsif curr == quote_char
              i += 1
              break
            end
            i += 1
          end
          add_span(spans, start_col, COLOR_STRING)
          add_span(spans, i, COLOR_DEFAULT)
          next
        end

        # Symbols: :symbol_name
        if c == ':' && i + 1 < len && (bytes[i + 1].chr.ascii_letter? || bytes[i + 1].chr == '_')
          start_col = i
          i += 1
          while i < len && (bytes[i].chr.alphanumeric? || bytes[i].chr == '_')
            i += 1
          end
          add_span(spans, start_col, COLOR_SYMBOL)
          add_span(spans, i, COLOR_DEFAULT)
          next
        end

        # Numbers: 123, 0xFF, 0b10, 3.14_f32, etc.
        if c.ascii_number? || (c == '-' && i + 1 < len && bytes[i + 1].chr.ascii_number?)
          start_col = i
          i += 1 if c == '-'
          if i + 1 < len && bytes[i].chr == '0' && (bytes[i + 1].chr == 'x' || bytes[i + 1].chr == 'X')
            i += 2
            while i < len && (bytes[i].chr.ascii_number? || ('a'..'f').includes?(bytes[i].chr.downcase) || bytes[i].chr == '_')
              i += 1
            end
          elsif i + 1 < len && bytes[i].chr == '0' && (bytes[i + 1].chr == 'b' || bytes[i + 1].chr == 'B')
            i += 2
            while i < len && (bytes[i].chr == '0' || bytes[i].chr == '1' || bytes[i].chr == '_')
              i += 1
            end
          else
            while i < len && (bytes[i].chr.ascii_number? || bytes[i].chr == '.' || bytes[i].chr == '_')
              i += 1
            end
            # Check for float suffix like _f32, _f64, _i32, _i64, _u32
            if i < len && bytes[i].chr == '_'
              i += 1
              while i < len && bytes[i].chr.alphanumeric?
                i += 1
              end
            end
          end
          add_span(spans, start_col, COLOR_NUMBER)
          add_span(spans, i, COLOR_DEFAULT)
          next
        end

        # Identifiers & Keywords
        if c.ascii_letter? || c == '_'
          start_col = i
          while i < len && (bytes[i].chr.alphanumeric? || bytes[i].chr == '_' || bytes[i].chr == '?' || bytes[i].chr == '!')
            i += 1
          end
          word = line[start_col...i]

          if KEYWORDS_DEF.includes?(word)
            add_span(spans, start_col, COLOR_KEYWORD)
            add_span(spans, i, COLOR_DEFAULT)
          elsif KEYWORDS_CONTROL.includes?(word)
            add_span(spans, start_col, COLOR_CONTROL_FLOW)
            add_span(spans, i, COLOR_DEFAULT)
          elsif KEYWORDS_SPECIAL.includes?(word)
            add_span(spans, start_col, COLOR_SPECIAL)
            add_span(spans, i, COLOR_DEFAULT)
          elsif word[0].ascii_uppercase?
            # Type name or Class name: Node2D, CharacterBody3D, Int32, String
            add_span(spans, start_col, COLOR_TYPE)
            add_span(spans, i, COLOR_DEFAULT)
          end
          next
        end

        # Operators and punctuation
        i += 1
      end

      spans
    end

    private def self.add_span(spans : Array(SyntaxSpan), col : Int32, color : Tuple(Float32, Float32, Float32, Float32))
      if spans.empty? || spans.last.column != col
        spans << SyntaxSpan.new(col, color[0], color[1], color[2], color[3])
      else
        # Overwrite previous span if on the same column
        spans[spans.size - 1] = SyntaxSpan.new(col, color[0], color[1], color[2], color[3])
      end
    end
  end
end

alias SyntaxSpan = Lapis::SyntaxSpan
alias CrystalHighlighter = Lapis::CrystalHighlighter

module Godot
  alias SyntaxSpan = ::Lapis::SyntaxSpan
  alias CrystalHighlighter = ::Lapis::CrystalHighlighter
end
