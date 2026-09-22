module Lapis
  include Godot
  # Completion proposal item for Godot's built-in CodeEdit popup
  struct CompletionItem
    property kind : String
    property display_text : String
    property insert_text : String
    property default_value : String

    def initialize(@kind : String, @display_text : String, @insert_text : String = @display_text, @default_value : String = "")
    end
  end

  # Crystal scripting language implementation.
  # Provides language metadata, templates, and code completion to Godot's ScriptServer.
  @[Tool]
  @[Icon("res://addons/crystal_integration/crystal_icon.svg")]
  node CrystalLanguage < ScriptLanguageExtension do
    @@instance : CrystalLanguage? = nil
    @@registered : Bool = false
    @@created_by_us : Bool = false

    def self.ensure_registered : Void
      return if @@registered
      if Bridge.is_language_registered?
        ptr = Bridge.get_language_object
        if !ptr.null?
          @@instance = Godot::CrystalLanguage.new(ptr)
        end
        @@registered = true
        @@created_by_us = false
        return
      end
      eng_ptr = Bridge.get_singleton("Engine")
      return if eng_ptr.null?
      engine = Godot::Engine.new(eng_ptr)

      # Check if CrystalLanguage is already registered in Engine from another addon/host
      begin
        count = engine.get_script_language_count
        count.times do |i|
          existing = engine.get_script_language(i)
          if existing && !existing.pointer.null?
            cls = existing.call_str("get_class") rescue ""
            lname = (existing.call_str("get_name") rescue "")
            lname = (existing.call_str("_get_name") rescue "") if lname.empty?
            lext = (existing.call_str("get_extension") rescue "")
            lext = (existing.call_str("_get_extension") rescue "") if lext.empty?
            if cls == "CrystalLanguage" || lname == "Crystal" || lext == "cr"
              @@instance = Godot::CrystalLanguage.new(existing.pointer)
              @@registered = true
              @@created_by_us = false
              Bridge.set_language_registered(true)
              Bridge.set_language_object(existing.pointer)
              return
            end
          end
        end
      rescue
      end

      if lang = Godot.create(Godot::CrystalLanguage)
        @@instance = lang
        @@created_by_us = true
        err = engine.register_script_language(lang)
        Bridge.set_language_registered(true)
        Bridge.set_language_object(lang.pointer)
        @@registered = true
      else
        Godot.printerr("[CrystalLanguage.ensure_registered] FAILED to create CrystalLanguage instance!")
      end
    end

    def self.unregister : Void
      return unless @@registered
      was_creator = @@created_by_us
      lang = @@instance
      @@instance = nil
      @@registered = false
      @@created_by_us = false

      return unless was_creator
      Bridge.set_language_registered(false)
      Bridge.set_language_object(Pointer(Void).null)

      return unless lang && !lang.pointer.null? && lang.alive?
      eng_ptr = Bridge.get_singleton("Engine")
      unless eng_ptr.null?
        engine = Godot::Engine.new(eng_ptr)
        begin
          if lang.alive?
            engine.unregister_script_language(lang) rescue nil
          end
        rescue
        end
      end
      if lang.alive?
        lang.destroy rescue nil
      end
    end

    def self.singleton_instance : CrystalLanguage
      if inst = @@instance
        return inst
      end
      ensure_registered
      if inst = @@instance
        return inst
      end
      ptr = Bridge.get_language_object
      if !ptr.null?
        inst = Godot::CrystalLanguage.new(ptr)
        @@instance = inst
        return inst
      end
      eng_ptr = Bridge.get_singleton("Engine")
      if !eng_ptr.null?
        engine = Godot::Engine.new(eng_ptr)
        count = engine.call_i64("get_script_language_count") rescue 0_i64
        count.times do |i|
          lang_obj = engine.call_obj("get_script_language", i) rescue nil
          if lang_obj && !lang_obj.pointer.null?
            cls = lang_obj.call_str("get_class") rescue ""
            if cls == "CrystalLanguage" || cls == "ScriptLanguageExtension"
              inst = Godot::CrystalLanguage.new(lang_obj.pointer)
              @@instance = inst
              return inst
            end
          end
        end
      end
      @@instance || new
    end

    def self.instance : CrystalLanguage
      singleton_instance
    end

    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end

    def get_name : String
      "Crystal"
    end

    def get_type : String
      "CrystalScript"
    end

    def get_extension : String
      "cr"
    end

    def get_recognized_extensions : Array(String)
      ["cr"]
    end

    def get_reserved_words : Array(String)
      [
        "node", "resource", "gdclass", "class", "module", "struct", "def", "end", "property", "getter", "setter",
        "signal", "alias", "enum", "lib", "fun", "macro", "onready",
        "if", "else", "elsif", "unless", "while", "until", "for", "in", "case", "when",
        "return", "break", "next", "yield", "begin", "rescue", "ensure", "raise", "do",
        "self", "super", "nil", "true", "false", "await", "spawn", "select"
      ]
    end

    def is_control_flow_keyword(kw : String) : Bool
      [
        "if", "else", "elsif", "unless", "while", "until", "for", "in",
        "case", "when", "return", "break", "next", "yield", "begin", "rescue", "ensure", "raise"
      ].includes?(kw)
    end

    def _get_name : String
      get_name
    end

    def _get_type : String
      get_type
    end

    def _get_extension : String
      get_extension
    end

    def _get_recognized_extensions : Array(String)
      get_recognized_extensions
    end

    def _get_reserved_words : Array(String)
      get_reserved_words
    end

    def _is_control_flow_keyword(kw : String) : Bool
      is_control_flow_keyword(kw)
    end

    def make_template(template : String, class_name : String, base_class_name : String) : String
      c_name = class_name.empty? ? "NewNode" : class_name
      b_name = base_class_name.empty? ? "Node" : base_class_name
      if template == "tool"
        "require \"lapis\"\n\n@[Tool]\nnode #{c_name} < #{b_name} do\n  def _ready : Void\n  end\n\n  def _process(delta : Float64) : Void\n  end\nend\n"
      else
        "require \"lapis\"\n\nnode #{c_name} < #{b_name} do\n  def _ready : Void\n  end\n\n  def _process(delta : Float64) : Void\n  end\nend\n"
      end
    end

    def complete_code(code : String, path : String) : Array(CompletionItem)
      completions = [] of CompletionItem
      completions << CompletionItem.new("macro", "node <Class> < <Parent>", "node ${1:Name} < ${2:Node} do\n  $0\nend")
      completions << CompletionItem.new("annotation", "@[Export]", "@[Export]")
      completions << CompletionItem.new("annotation", "@[Tool]", "@[Tool]")
      completions << CompletionItem.new("keyword", "property <name> : <Type>", "property ${1:name} : ${2:String}")
      completions << CompletionItem.new("keyword", "signal <name>", "signal ${1:name}")
      completions << CompletionItem.new("method", "_ready : Void", "def _ready : Void\n  $0\nend")
      completions << CompletionItem.new("method", "_process(delta : Float64) : Void", "def _process(delta : Float64) : Void\n  $0\nend")
      completions << CompletionItem.new("method", "_physics_process(delta : Float64) : Void", "def _physics_process(delta : Float64) : Void\n  $0\nend")
      completions
    end

    def self._godot_has_virtual_method(method_name : String) : Bool
      norm = method_name.starts_with?('_') ? method_name : "_#{method_name}"
      case norm
      when "_init", "_finish", "_thread_enter", "_thread_exit", "_frame",
           "_get_name", "_get_type", "_get_extension", "_get_recognized_extensions",
           "_get_reserved_words", "_is_control_flow_keyword", "_get_comment_delimiters",
           "_get_doc_comment_delimiters", "_get_string_delimiters", "_make_template",
           "_get_built_in_templates", "_is_using_templates", "_validate", "_validate_path",
           "_create_script", "_has_named_classes", "_supports_builtin_mode",
           "_supports_documentation", "_can_inherit_from_file", "_find_function",
           "_make_function", "_can_make_function",
           "_open_in_external_editor", "_overrides_external_editor",
           "_preferred_file_name_casing", "_complete_code",
           "_lookup_code", "_auto_indent_code", "_handles_global_class_type",
           "_get_global_class_name", "_debug_get_error", "_debug_get_stack_level_count",
           "_debug_get_stack_level_line", "_debug_get_stack_level_function",
           "_debug_get_stack_level_source", "_debug_get_stack_level_locals",
           "_debug_get_stack_level_members", "_debug_get_globals",
           "_debug_get_stack_level_instance", "_debug_parse_stack_level_expression",
           "_debug_get_current_stack_info", "_reload_all_scripts", "_reload_scripts",
           "_reload_tool_script", "_get_public_functions", "_get_public_constants",
           "_get_public_annotations", "_profiling_start", "_profiling_stop",
           "_profiling_set_save_native_calls", "_profiling_get_accumulated_data",
           "_profiling_get_frame_data",
           "_add_global_constant", "_add_named_global_constant", "_remove_named_global_constant"
        true
      else
        false
      end
    end

    def _godot_call_virtual_with_data(method_name : String, args : Void**, ret : Void*) : Void
      norm = method_name.starts_with?('_') ? method_name : "_#{method_name}"
      case norm
      when "_init", "_finish", "_thread_enter", "_thread_exit", "_frame"
        # No-op void lifecycle hooks
        return
      when "_get_name"
        Bridge.ret_string(ret, "Crystal")
      when "_get_type"
        Bridge.ret_string(ret, "CrystalScript")
      when "_get_extension"
        Bridge.ret_string(ret, "cr")
      when "_get_recognized_extensions"
        Bridge.ret_packed_string_array(ret, ["cr"])
      when "_get_reserved_words"
        words = [
          "node", "resource", "gdclass", "class", "module", "struct", "def", "end", "property", "getter", "setter",
          "signal", "alias", "enum", "lib", "fun", "macro", "onready",
          "if", "else", "elsif", "unless", "while", "until", "for", "in", "case", "when",
          "return", "break", "next", "yield", "begin", "rescue", "ensure", "raise", "do",
          "self", "super", "nil", "true", "false", "await", "spawn", "select"
        ]
        Bridge.ret_packed_string_array(ret, words)
      when "_is_control_flow_keyword"
        kw = Bridge.arg_to_string(args[0])
        is_ctrl = [
          "if", "else", "elsif", "unless", "while", "until", "for", "in",
          "case", "when", "return", "break", "next", "yield", "begin", "rescue", "ensure", "raise"
        ].includes?(kw)
        ret.as(UInt8*).value = is_ctrl ? 1_u8 : 0_u8
      when "_get_comment_delimiters"
        Bridge.ret_packed_string_array(ret, ["#"])
      when "_get_doc_comment_delimiters"
        Bridge.ret_packed_string_array(ret, ["##"])
      when "_get_string_delimiters"
        Bridge.ret_packed_string_array(ret, ["\" \"", "' '"])
      when "_make_template"
        begin
          template = (!args.null? && !args[0].null?) ? (Bridge.arg_to_string(args[0]) rescue "") : ""
          c_name = (!args.null? && !args[1].null?) ? (Bridge.arg_to_string(args[1]) rescue "") : ""
          b_name = (!args.null? && !args[2].null?) ? (Bridge.arg_to_string(args[2]) rescue "") : ""
          c_name = "NewNode" if c_name.empty?
          b_name = "Node" if b_name.empty?

          code = if !template.empty?
            template.gsub("_CLASS_", c_name).gsub("_BASE_", b_name)
          else
            "require \"lapis\"\n\n# #{c_name} node\nnode #{c_name} < #{b_name} do\n  def _ready : Void\n    Godot.print(\"#{c_name} initialized\")\n  end\n\n  def _process(delta : Float64) : Void\n  end\nend\n"
          end

          script = Godot.create(Godot::CrystalScript)
          if script && !script.pointer.null?
            script.source_code = code
            Bridge.ret_ref(ret, script.pointer)
          else
            Godot.printerr("[CrystalLanguage._make_template] Error: Failed to create CrystalScript resource!")
            Bridge.ret_ref(ret, Pointer(Void).null)
          end
        rescue ex
          Godot.printerr("[CrystalLanguage._make_template] Exception: #{ex.message}")
          Bridge.ret_ref(ret, Pointer(Void).null)
        end
      when "_get_built_in_templates"
        Bridge.ret_array_empty(ret)
      when "_is_using_templates"
        ret.as(UInt8*).value = 1_u8
      when "_validate"
        Bridge.ret_dictionary_validate(ret, true)
      when "_validate_path"
        Bridge.ret_string(ret, "")
      when "_create_script"
        begin
          script = Godot.create(Godot::CrystalScript)
          if script && !script.pointer.null?
            Bridge.ret_object(ret, script.pointer)
          else
            Bridge.ret_object(ret, Pointer(Void).null)
          end
        rescue ex
          Godot.printerr("[CrystalLanguage._create_script] Exception: #{ex.message}")
          Bridge.ret_object(ret, Pointer(Void).null)
        end
      when "_has_named_classes"
        ret.as(UInt8*).value = 0_u8
      when "_supports_builtin_mode"
        ret.as(UInt8*).value = 0_u8
      when "_supports_documentation"
        ret.as(UInt8*).value = 0_u8
      when "_can_inherit_from_file"
        ret.as(UInt8*).value = 0_u8
      when "_find_function"
        fn = Bridge.arg_to_string(args[0])
        code = Bridge.arg_to_string(args[1])
        target = "def #{fn}"
        line_found = -1
        code.split("\n").each_with_index do |l, idx|
          if l.strip.starts_with?(target)
            line_found = idx + 1
            break
          end
        end
        ret.as(Int32*).value = line_found.to_i32
      when "_make_function"
        c_name = Bridge.arg_to_string(args[0])
        fn = Bridge.arg_to_string(args[1])
        Bridge.ret_string(ret, "def #{fn} : Void\nend\n")
      when "_can_make_function"
        ret.as(UInt8*).value = 1_u8
      when "_open_in_external_editor"
        ret.as(Int32*).value = 2_i32 # ERR_UNAVAILABLE
      when "_overrides_external_editor"
        ret.as(UInt8*).value = 0_u8
      when "_preferred_file_name_casing"
        ret.as(Int32*).value = 2_i32 # SnakeCase
      when "_complete_code"
        Bridge.ret_dictionary_complete_code(ret)
      when "_lookup_code"
        Bridge.ret_dictionary_lookup_code(ret)
      when "_auto_indent_code"
        code = Bridge.arg_to_string(args[0])
        from_line = args[1].as(Int32*).value
        to_line = args[2].as(Int32*).value
        Bridge.ret_string(ret, auto_indent_code(code, from_line, to_line))
      when "_handles_global_class_type"
        t = Bridge.arg_to_string(args[0])
        ret.as(UInt8*).value = (t == "CrystalScript" || t == "Crystal") ? 1_u8 : 0_u8
      when "_get_global_class_name"
        path = Bridge.arg_to_string(args[0])
        if !path.downcase.ends_with?(".cr")
          Bridge.ret_dictionary_empty(ret)
        else
          begin
            normalized_path = path.starts_with?("res://") ? path : "res://#{path.lstrip('/')}"
            entry = ClassRegistry.entries.find do |e|
              e.script_path == path || e.script_path == normalized_path ||
                (!e.script_path.empty? && (path.ends_with?(e.script_path.sub("res://", "")) || e.script_path.ends_with?(path.sub("res://", ""))))
            end
            if entry
              Bridge.ret_dictionary_global_class(ret, entry.class_name, entry.parent_name, entry.icon_path)
            else
              c_name, b_type, icon_path = CrystalLanguage.inspect_file_global_class(path)
              if !c_name.empty?
                Bridge.ret_dictionary_global_class(ret, c_name, b_type, icon_path)
              else
                Bridge.ret_dictionary_empty(ret)
              end
            end
          rescue
            Bridge.ret_dictionary_empty(ret)
          end
        end
      when "_debug_get_error"
        Bridge.ret_string(ret, "")
      when "_debug_get_stack_level_count"
        ret.as(Int32*).value = 0_i32
      when "_debug_get_stack_level_line"
        ret.as(Int32*).value = 0_i32
      when "_debug_get_stack_level_function"
        Bridge.ret_string(ret, "")
      when "_debug_get_stack_level_source"
        Bridge.ret_string(ret, "")
      when "_debug_get_stack_level_locals", "_debug_get_stack_level_members", "_debug_get_globals"
        Bridge.ret_dictionary_empty(ret)
      when "_debug_get_stack_level_instance"
        ret.as(Void**).value = Pointer(Void).null
      when "_debug_parse_stack_level_expression"
        Bridge.ret_string(ret, "")
      when "_debug_get_current_stack_info"
        Bridge.ret_array_empty(ret)
      when "_reload_all_scripts", "_reload_scripts", "_reload_tool_script",
           "_profiling_start", "_profiling_stop", "_profiling_set_save_native_calls",
           "_add_global_constant", "_add_named_global_constant", "_remove_named_global_constant"
        return
      when "_get_public_functions", "_get_public_annotations"
        Bridge.ret_array_empty(ret)
      when "_get_public_constants"
        Bridge.ret_dictionary_empty(ret)
      when "_profiling_get_accumulated_data", "_profiling_get_frame_data"
        ret.as(Int32*).value = 0_i32
      else
        super
      end
    end

    def auto_indent_code(code : String, from_line : Int32, to_line : Int32) : String
      lines = code.split("\n")
      indent_level = 0
      result = [] of String

      lines.each_with_index do |line, idx|
        stripped = line.strip
        if stripped.starts_with?("end") || stripped.starts_with?("else") ||
           stripped.starts_with?("elsif") || stripped.starts_with?("rescue") ||
           stripped.starts_with?("ensure") || stripped.starts_with?("when")
          indent_level = Math.max(0, indent_level - 1)
        end

        if idx >= from_line && idx <= to_line
          result << ("  " * indent_level) + stripped
        else
          result << line
        end

        if stripped.ends_with?(" do") || stripped.starts_with?("def ") ||
           stripped.starts_with?("class ") || stripped.starts_with?("module ") ||
           stripped.starts_with?("struct ") || stripped.starts_with?("if ") ||
           stripped.starts_with?("unless ") || stripped.starts_with?("while ") ||
           stripped.starts_with?("case ") || stripped.starts_with?("begin") ||
           stripped.starts_with?("else") || stripped.starts_with?("elsif ")
          indent_level += 1
        end
      end

      result.join("\n")
    end

    def self.inspect_file_global_class(path : String) : Tuple(String, String, String)
      return {"", "", ""} unless path.downcase.ends_with?(".cr")
      fs_path = ResourceFormatSaverCrystal.resolve_save_path(path)
      if fs_path.empty? || !File.exists?(fs_path)
        fs_path = path.starts_with?("res://") ? path.sub("res://", "") : path
      end
      return {"", "", ""} unless File.exists?(fs_path)
      begin
        content = File.read(fs_path)
        return {"", "", ""} unless content.valid_encoding?
        class_name = ""
        base_type = "Node"
        icon_path = ""
        content.each_line do |line|
          trimmed = line.strip
          if trimmed =~ /@\[Icon\("([^"]+)"\)\]/
            icon_path = $1
          end
          if trimmed =~ /(?:^|\s)node\s+([A-Za-z0-9_]+)(?:\s*<\s*([A-Za-z0-9_:]+))?(?:\s+do|\s*$)/
            class_name = $1
            base_type = $2 ? $2.split("::").last : "Node"
            break
          end
        end
        {class_name, base_type, icon_path}
      rescue
        {"", "", ""}
      end
    end
  end
end

alias CompletionItem = Lapis::CompletionItem
alias CrystalLanguage = Lapis::CrystalLanguage

module Godot
  alias CompletionItem = ::Lapis::CompletionItem
  alias CrystalLanguage = ::Lapis::CrystalLanguage
end
