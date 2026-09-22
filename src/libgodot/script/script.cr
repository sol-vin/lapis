module Lapis
  include Godot
  # Exported script property descriptor for Godot's Inspector
  struct ScriptProperty
    property name : String
    property type_name : String
    property variant_type : Int32
    property hint : UInt32
    property hint_string : String
    property usage : UInt32
    property default_value : String

    def initialize(
      @name : String,
      @type_name : String,
      variant_type : Number = 0,
      hint : Number = 0,
      @hint_string : String = "",
      usage : Number = 6, # PROPERTY_USAGE_DEFAULT
      @default_value : String = ""
    )
      @variant_type = variant_type.to_i32
      @hint = hint.to_u32
      @usage = usage.to_u32
    end
  end

  # Represents a standalone .cr file as a first-class Godot Script resource.
  # Bridges source text, AST reflection, and Inspector property presentation.
  @[Tool]
  @[Icon("res://addons/crystal_integration/crystal_icon.svg")]
  node CrystalScript < ScriptExtension do
    @script_path : String = ""
    @source_code : String = ""
    @script_class_name : String = ""
    @script_base_type : String = "Node"
    @is_tool_script : Bool = false
    @properties : Array(ScriptProperty) = [] of ScriptProperty
    @signals : Array(String) = [] of String
    @methods : Array(String) = [] of String
    @doc_comments : Hash(String, String) = {} of String => String

    def script_path : String; @script_path; end
    def script_path=(v : String)
      @script_path = v
      if !@pointer.null? && !v.empty?
        take_over_path(v) rescue (call("take_over_path", v) rescue nil)
      end
    end

    def source_code : String; @source_code; end
    def source_code=(v : String)
      @source_code = v
      if !@pointer.null?
        call("set_source_code", v) rescue nil
      end
    end

    def script_class_name : String; @script_class_name; end
    def script_class_name=(v : String); @script_class_name = v; end

    def script_base_type : String; @script_base_type; end
    def script_base_type=(v : String); @script_base_type = v; end

    def is_tool_script : Bool; @is_tool_script; end
    def is_tool_script=(v : Bool); @is_tool_script = v; end

    def properties : Array(ScriptProperty); @properties; end
    def properties=(v : Array(ScriptProperty)); @properties = v; end

    def signals : Array(String); @signals; end
    def signals=(v : Array(String)); @signals = v; end

    def methods : Array(String); @methods; end
    def methods=(v : Array(String)); @methods = v; end

    def doc_comments : Hash(String, String); @doc_comments; end
    def doc_comments=(v : Hash(String, String)); @doc_comments = v; end

    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end

    def initialize(path : String, source : String = "", pointer : Void* = Pointer(Void).null)
      super(pointer)
      set_script_path(path) unless path.empty?
      set_source_code(source) unless source.empty?
    end

    def class_name : String
      @script_class_name
    end

    def base_type : String
      @script_base_type
    end

    def set_script_path(p : String) : Void
      @script_path = p
      if !@pointer.null? && !p.empty?
        take_over_path(p) rescue (call("take_over_path", p) rescue nil)
      end
    end

    def set_source_code(code : String) : Void
      @source_code = code
      parse_source_metadata
    end

    def self._godot_has_virtual_method(method_name : String) : Bool
      norm = method_name.starts_with?('_') ? method_name : "_#{method_name}"
      case norm
      when "_can_instantiate", "_has_source_code", "_get_source_code", "_set_source_code",
           "_get_instance_base_type", "_get_global_name", "_is_tool", "_is_valid", "_is_abstract",
           "_get_language", "_has_method", "_has_static_method",
           "_get_script_method_argument_count", "_get_method_info", "_get_base_script",
           "_inherits_script", "_has_script_signal", "_has_property_default_value",
           "_get_property_default_value", "_update_exports", "_editor_can_reload_from_file",
           "_reload", "_instance_create", "_placeholder_instance_create", "_placeholder_erased",
           "_instance_has",
           "_get_documentation", "_get_doc_class_name", "_get_class_icon_path",
           "_get_script_signal_list", "_get_script_method_list", "_get_script_property_list",
           "_get_member_line", "_get_constants", "_get_members",
           "_is_placeholder_fallback_enabled", "_get_rpc_config"
        true
      else
        false
      end
    end

    def _godot_call_virtual_with_data(method_name : String, args : Void**, ret : Void*) : Void
      norm = method_name.starts_with?('_') ? method_name : "_#{method_name}"
      case norm
      when "_can_instantiate"
        ret.as(UInt8*).value = 1_u8
      when "_has_source_code"
        ret.as(UInt8*).value = 1_u8
      when "_get_source_code"
        if @source_code.empty?
          p = @script_path
          if p.empty? && !@pointer.null?
            p = call_str("get_path") rescue ""
            @script_path = p unless p.empty?
          end
          if !p.empty?
            resolved = ResourceFormatLoaderCrystal.resolve_file_path(p)
            if !resolved.empty? && File.exists?(resolved)
              @source_code = File.read(resolved)
              parse_source_metadata
            end
          end
        end
        Bridge.ret_string(ret, @source_code)
      when "_set_source_code"
        new_code = (!args.null? && !args[0].null?) ? Bridge.arg_to_string(args[0]) : ""
        @source_code = new_code
        parse_source_metadata
      when "_get_instance_base_type"
        b_type = @script_base_type.empty? ? "Node" : @script_base_type
        Bridge.ret_string_name(ret, b_type)
      when "_get_global_name"
        Bridge.ret_string_name(ret, @script_class_name)
      when "_is_tool"
        ret.as(UInt8*).value = @is_tool_script ? 1_u8 : 0_u8
      when "_is_valid"
        ret.as(UInt8*).value = 1_u8
      when "_is_abstract"
        ret.as(UInt8*).value = 0_u8
      when "_get_language"
        lang = CrystalLanguage.singleton_instance
        Bridge.ret_object(ret, lang.pointer)
      when "_has_method"
        m_name = Bridge.arg_to_string_name(args[0])
        has_m = @methods.includes?(m_name)
        ret.as(UInt8*).value = has_m ? 1_u8 : 0_u8
      when "_has_static_method"
        ret.as(UInt8*).value = 0_u8
      when "_get_script_method_argument_count"
        Bridge.ret_variant_nil(ret)
      when "_get_method_info"
        Bridge.ret_dictionary_empty(ret)
      when "_get_base_script"
        Bridge.ret_ref(ret, Pointer(Void).null)
      when "_inherits_script"
        ret.as(UInt8*).value = 0_u8
      when "_has_script_signal"
        s_name = Bridge.arg_to_string_name(args[0])
        has_s = @signals.includes?(s_name)
        ret.as(UInt8*).value = has_s ? 1_u8 : 0_u8
      when "_has_property_default_value"
        ret.as(UInt8*).value = 0_u8
      when "_get_property_default_value"
        Bridge.ret_variant_nil(ret)
      when "_update_exports"
        # No-op
      when "_editor_can_reload_from_file"
        ret.as(UInt8*).value = 1_u8
      when "_reload"
        keep_state = args[0].as(UInt8*).value != 0_u8
        if !@script_path.empty? && Godot::SystemIO.file_exists?(@script_path)
          set_source_code(Godot::SystemIO.read_file(@script_path))
        end
        ret.as(Int32*).value = 0_i32 # OK
      when "_instance_create"
        owner_ptr = args[0]
        # If running in game and owner is already a native registered Crystal class instance,
        # return null so Godot directly dispatches virtual methods on the native GDExtension object
        if !Godot.editor_hint? && !owner_ptr.null? && Bridge.find_alive_instance(owner_ptr)
          ret.as(Void**).value = Pointer(Void).null
          return
        end

        lang = CrystalLanguage.singleton_instance
        if !lang.pointer.null?
          inst = Bridge.placeholder_script_instance_create(lang.pointer, @pointer, owner_ptr)
          ret.as(Void**).value = inst
        else
          ret.as(Void**).value = Pointer(Void).null
        end
      when "_placeholder_instance_create"
        lang = CrystalLanguage.singleton_instance
        if !lang.pointer.null?
          inst = Bridge.placeholder_script_instance_create(lang.pointer, @pointer, args[0])
          ret.as(Void**).value = inst
        else
          ret.as(Void**).value = Pointer(Void).null
        end
      when "_instance_has"
        ret.as(UInt8*).value = 1_u8
      when "_get_documentation"
        Bridge.ret_array_empty(ret)
      when "_get_doc_class_name"
        Bridge.ret_string_name(ret, @script_class_name)
      when "_placeholder_erased"
        return
      when "_get_class_icon_path"
        Bridge.ret_string(ret, "res://addons/crystal_integration/crystal_icon.svg")
      when "_get_script_signal_list", "_get_script_method_list", "_get_script_property_list"
        Bridge.ret_array_empty(ret)
      when "_get_member_line"
        ret.as(Int32*).value = 0_i32
      when "_get_constants"
        Bridge.ret_dictionary_empty(ret)
      when "_get_members"
        Bridge.ret_array_empty(ret)
      when "_is_placeholder_fallback_enabled"
        ret.as(UInt8*).value = 0_u8
      when "_get_rpc_config"
        Bridge.ret_variant_nil(ret)
      else
        super
      end
    end

    def reload(keep_state : Bool = true) : Int32
      if Godot::SystemIO.file_exists?(@script_path)
        @source_code = Godot::SystemIO.read_file(@script_path)
        parse_source_metadata
      end
      0 # OK
    end

    # Fast, pure-Crystal AST scanner to extract class name, base type,
    # exported properties, signals, and doc comments directly from .cr source.
    def parse_source_metadata : Void
      @properties.clear
      @signals.clear
      @methods.clear
      @doc_comments.clear
      @is_tool_script = false

      lines = @source_code.split("\n")
      current_doc = ""
      in_node = false
      pending_export_args = ""

      lines.each do |line|
        trimmed = line.strip

        # Doc comments
        if trimmed.starts_with?("#") && !trimmed.starts_with?("#!")
          comment_text = trimmed.sub(/^#\s*/, "")
          if current_doc.empty?
            current_doc = comment_text
          else
            current_doc += "\n" + comment_text
          end
          next
        end

        # Standalone @[Export(...)] annotation on preceding line
        if trimmed =~ /^@\[Export(?:\(([^\]]*)\))?\]$/
          pending_export_args = $1? || ""
          next
        end

        # Tool annotation
        if trimmed.includes?("@[Tool]") || trimmed == "tool"
          @is_tool_script = true
        end

        # Node declaration: node ClassName < BaseName do
        if trimmed =~ /(?:^|\s)node\s+([A-Za-z0-9_]+)(?:\s*<\s*([A-Za-z0-9_:]+))?\s+do/
          @script_class_name = $1
          if $2? && !$2.empty?
            @script_base_type = $2.split("::").last
          else
            @script_base_type = "Node"
          end
          in_node = true
          current_doc = ""
          pending_export_args = ""
          next
        end

        # Signal declaration: signal name(args...)
        if trimmed =~ /(?:^|\s)signal\s+([A-Za-z0-9_]+)/
          sig_name = $1
          @signals << sig_name
          @doc_comments[sig_name] = current_doc unless current_doc.empty?
          current_doc = ""
          pending_export_args = ""
          next
        end

        # Method definition: def _ready / def method_name
        if trimmed =~ /(?:^|\s)def\s+([A-Za-z0-9_?!]+)/
          m_name = $1
          @methods << m_name
          @doc_comments[m_name] = current_doc unless current_doc.empty?
          current_doc = ""
          pending_export_args = ""
          next
        end

        # Exported property: @[Export...] property name : Type = default
        if trimmed =~ /(?:@\[Export(?:\(([^\]]*)\))?\]\s*)?(?:property|getter|setter)\s+([A-Za-z0-9_]+)\s*:\s*([A-Za-z0-9_:]+)(?:\s*=\s*(.+))?/
          inline_args = $1?
          export_args = inline_args ? inline_args : pending_export_args
          pending_export_args = ""
          p_name = $2
          p_type = $3.split("::").last
          p_default = ($4? || "").strip

          v_type = variant_type_from_string(p_type)
          hint = 0
          hint_str = ""

          # Parse Export hints like range: 1..100, step: 1
          if export_args.includes?("range:")
            hint = 1 # PROPERTY_HINT_RANGE
            if export_args =~ /range:\s*([0-9.]+)(?:_[a-z0-9]+)?\.\.([0-9.]+)(?:_[a-z0-9]+)?(?:,\s*step:\s*([0-9.]+)(?:_[a-z0-9]+)?)?/
              min_v = $1
              max_v = $2
              step_v = $3? ? ",#{$3}" : ""
              hint_str = "#{min_v},#{max_v}#{step_v}"
            end
          end

          @properties << ScriptProperty.new(
            name: p_name,
            type_name: p_type,
            variant_type: v_type,
            hint: hint,
            hint_string: hint_str,
            usage: 6, # PROPERTY_USAGE_DEFAULT
            default_value: p_default
          )
          @doc_comments[p_name] = current_doc unless current_doc.empty?
          current_doc = ""
          next
        end

        # Clear doc comment if non-comment, non-matching code is encountered
        current_doc = "" if !trimmed.empty?
      end

      # Cross-reference with live ClassDB if the class is already compiled
      if !@script_class_name.empty?
        ClassRegistry.entries.each do |entry|
          if entry.class_name == @script_class_name
            @script_base_type = entry.parent_name unless entry.parent_name.empty?
            @is_tool_script = true if entry.is_tool
            # Merge compiled property hints
            entry.properties.each do |cp|
              existing = @properties.find { |p| p.name == cp.name }
              if existing
                idx = @properties.index(existing).not_nil!
                @properties[idx] = ScriptProperty.new(
                  name: cp.name,
                  type_name: cp.type_name,
                  variant_type: cp.variant_type,
                  hint: cp.hint,
                  hint_string: cp.hint_string,
                  usage: cp.usage,
                  default_value: existing.default_value
                )
              else
                @properties << ScriptProperty.new(
                  name: cp.name,
                  type_name: cp.type_name,
                  variant_type: cp.variant_type,
                  hint: cp.hint,
                  hint_string: cp.hint_string,
                  usage: cp.usage
                )
              end
            end
            break
          end
        end
      end
    end

    def variant_type_from_string(type_str : String) : Int32
      case type_str
      when "Bool"
        1 # BOOL
      when "Int32", "Int64", "Int", "UInt32", "UInt64"
        2 # INT
      when "Float32", "Float64", "Float"
        3 # FLOAT
      when "String"
        4 # STRING
      when "Vector2"
        5 # VECTOR2
      when "Vector2i"
        6 # VECTOR2I
      when "Rect2"
        7 # RECT2
      when "Vector3"
        9 # VECTOR3
      when "Vector3i"
        10 # VECTOR3I
      when "Transform2D"
        11 # TRANSFORM2D
      when "Plane"
        13 # PLANE
      when "Quaternion"
        14 # QUATERNION
      when "AABB"
        15 # AABB
      when "Basis"
        16 # BASIS
      when "Transform3D"
        17 # TRANSFORM3D
      when "Color"
        20 # COLOR
      when "NodePath"
        22 # NODE_PATH
      else
        24 # OBJECT
      end
    end
  end
end

alias ScriptProperty = Lapis::ScriptProperty
alias CrystalScript = Lapis::CrystalScript

module Godot
  alias ScriptProperty = ::Lapis::ScriptProperty
  alias CrystalScript = ::Lapis::CrystalScript
end
