require "./macros/annotations"
require "./macros/node_refs"
require "./macros/signals"
require "./macros/match"

module Godot
  struct PropertyInfo
    getter name : String
    getter type_name : String
    getter variant_type : Int32
    getter hint : UInt32
    getter hint_string : String
    getter usage : UInt32

    def initialize(@name : String, @type_name : String, @variant_type : Int32, @hint : UInt32 = 0_u32, @hint_string : String = "", @usage : UInt32 = 6_u32)
    end
  end

  struct SignalArgInfo
    getter name : String
    getter variant_type : Int32

    def initialize(@name : String, @variant_type : Int32 = 0)
    end
  end

  struct SignalInfo
    getter name : String
    getter args : ::Array(SignalArgInfo)

    def initialize(@name : String, @args : ::Array(SignalArgInfo) = [] of SignalArgInfo)
    end
  end

  class ConstantInfo
    getter enum_name : String
    getter name : String
    getter value : Int64
    getter? is_bitfield : Bool

    def initialize(@enum_name : String, @name : String, @value : Int64, @is_bitfield : Bool = false)
    end
  end

  # Registry to keep track of all user-defined nodes and classes
  class ClassRegistry
    class Entry
      getter class_name : String
      getter parent_name : String
      getter create_proc : (Void* -> Object)
      property is_tool : Bool
      property has_ready : Bool
      property has_process : Bool
      property has_physics_process : Bool
      property has_enter_tree : Bool
      property has_exit_tree : Bool
      property has_input : Bool
      property has_unhandled_input : Bool
      property has_unhandled_key_input : Bool
      property has_shortcut_input : Bool
      property has_gui_input : Bool
      property properties : ::Array(PropertyInfo)
      property signals : ::Array(SignalInfo)
      property constants : ::Array(ConstantInfo)
      property icon_path : String
      property is_abstract : Bool
      property rpc_methods : ::Array(NamedTuple(name: String, rpc_mode: Int32, transfer_mode: Int32, call_local: Bool, channel: Int32))
      property has_virtual_proc : (String -> Bool)? = nil
      property script_path : String = ""

      def has_virtual_method?(name : String) : Bool
        if proc = @has_virtual_proc
          return true if proc.call(name)
        end
        false
      end

      def initialize(
        @class_name : String,
        @parent_name : String,
        @create_proc : (Void* -> Object),
        @is_tool : Bool = false,
        @has_ready : Bool = false,
        @has_process : Bool = false,
        @has_physics_process : Bool = false,
        @has_enter_tree : Bool = false,
        @has_exit_tree : Bool = false,
        @has_input : Bool = false,
        @has_unhandled_input : Bool = false,
        @has_unhandled_key_input : Bool = false,
        @has_shortcut_input : Bool = false,
        @has_gui_input : Bool = false,
        @properties : ::Array(PropertyInfo) = [] of PropertyInfo,
        @signals : ::Array(SignalInfo) = [] of SignalInfo,
        @icon_path : String = "",
        @is_abstract : Bool = false,
        @rpc_methods : ::Array(NamedTuple(name: String, rpc_mode: Int32, transfer_mode: Int32, call_local: Bool, channel: Int32)) = [] of NamedTuple(name: String, rpc_mode: Int32, transfer_mode: Int32, call_local: Bool, channel: Int32),
        @has_virtual_proc : (String -> Bool)? = nil,
        @constants : ::Array(ConstantInfo) = [] of ConstantInfo,
        @script_path : String = "",
      )
      end
    end

    class_getter entries = ::Array(Entry).new
    {% unless flag?(:release) || flag?(:libgodot_addon) || flag?(:no_editor) %}
      @@script_cache = Hash(String, CrystalScript).new

      def self.get_or_load_script(path : String, class_name : String, base_type : String = "Node", is_tool : Bool = false) : CrystalScript?
        return nil if path.empty? || path == "res://" || path == "res:///"
        if script = @@script_cache[path]?
          return script
        end
        # Prefer canonical cached script from Godot's ResourceLoader / ResourceCache
        begin
          res = Godot.load(path)
          if res && !res.pointer.null?
            cs = if alive = Bridge.find_alive_instance(res.pointer)
                   alive.as?(CrystalScript) || CrystalScript.new(res.pointer)
                 else
                   CrystalScript.new(res.pointer)
                 end
            if cs && !cs.pointer.null?
              cs.script_class_name = class_name if cs.script_class_name.empty?
              cs.script_base_type = base_type if cs.script_base_type.empty?
              cs.is_tool_script = is_tool if is_tool
              cs.sync_class_metadata
              @@script_cache[path] = cs
              return cs
            end
          end
        rescue
        end
        source = ""
        fs_path = path.starts_with?("res://") ? path.sub("res://", "") : path
        if !Godot::ProjectSettings.singleton_ptr.null?
          ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
          glob_p = ps.call_str("globalize_path", path).gsub('\\', '/')
          fs_path = glob_p if !glob_p.empty? && File.exists?(glob_p)
        end
        if File.exists?(fs_path)
          source = File.read(fs_path) rescue ""
        end
        script = Godot.create(Godot::CrystalScript)
        return nil unless script
        script.script_path = path
        script.script_class_name = class_name
        script.script_base_type = base_type
        script.is_tool_script = is_tool
        script.source_code = source
        script.sync_class_metadata
        script.take_over_path(path) rescue script.call("take_over_path", path) rescue script.set_path_cache(path) rescue nil
        @@script_cache[path] = script
        script
      end
    {% else %}
      def self.get_or_load_script(path : String, class_name : String, base_type : String = "Node", is_tool : Bool = false) : Nil
        nil
      end
    {% end %}

    def self.register(entry : Entry)
      if existing = find(entry.class_name)
        entry.properties.each do |p|
          existing.properties << p unless existing.properties.any? { |ep| ep.name == p.name }
        end
        entry.signals.each do |s|
          existing.signals << s unless existing.signals.any? { |es| es.name == s.name }
        end
        entry.constants.each do |c|
          existing.constants << c unless existing.constants.any? { |ec| ec.name == c.name }
        end
        entry.rpc_methods.each do |r|
          existing.rpc_methods << r unless existing.rpc_methods.any? { |er| er[:name] == r[:name] }
        end
        existing.is_tool ||= entry.is_tool
        existing.has_ready ||= entry.has_ready
        existing.has_process ||= entry.has_process
        existing.has_physics_process ||= entry.has_physics_process
        existing.has_enter_tree ||= entry.has_enter_tree
        existing.has_exit_tree ||= entry.has_exit_tree
        existing.has_input ||= entry.has_input
        existing.has_unhandled_input ||= entry.has_unhandled_input
        existing.has_unhandled_key_input ||= entry.has_unhandled_key_input
        existing.has_shortcut_input ||= entry.has_shortcut_input
        existing.has_gui_input ||= entry.has_gui_input
        if existing.script_path.empty? && !entry.script_path.empty?
          existing.script_path = entry.script_path
        end
        return
      end
      if parent = find(entry.parent_name)
        entry.is_tool ||= parent.is_tool
        entry.has_ready ||= parent.has_ready
        entry.has_process ||= parent.has_process
        entry.has_physics_process ||= parent.has_physics_process
        entry.has_enter_tree ||= parent.has_enter_tree
        entry.has_exit_tree ||= parent.has_exit_tree
        entry.has_input ||= parent.has_input
        entry.has_unhandled_input ||= parent.has_unhandled_input
        entry.has_unhandled_key_input ||= parent.has_unhandled_key_input
        entry.has_shortcut_input ||= parent.has_shortcut_input
        entry.has_gui_input ||= parent.has_gui_input
      end
      @@entries << entry
    end

    def self.find(name : String) : Entry?
      @@entries.find { |e| e.class_name == name }
    end

    def self.cleanup : Void
      {% unless flag?(:release) || flag?(:libgodot_addon) || flag?(:no_editor) %}
        @@script_cache.clear
      {% end %}
    end
  end
end

# The primary `node` macro:
# Usage:
#   node MyNode
#   node MyNode do
#     # defaults to Godot::Node
#   end
#
#   node Player < CharacterBody3D
#   node Player < CharacterBody3D do
#     # inherits Godot::CharacterBody3D
#   end
# Expressive loader macro to ensure Lapis engine bindings are loaded
# without duplicate require cycles or missing dependency errors
macro ensure_lapis
  {% unless @top_level.has_constant?(:Godot) %}
    require "lapis"
  {% end %}
end

# Instantiates a Godot object or custom node and configures its properties and methods in a block or kwargs.
#
# Supports:
# 1. Keyword properties: `create Sprite2D, position: Vector2.new(10, 20), centered: true`
# 2. Block property setters: `create Sprite2D do position = Vector2.new(10, 20); centered = true end`
# 3. Method dispatches: `create Sprite2D do add_to_group("sprites"); rotate(0.5) end`
# 4. Mixed kwargs and block: `create Sprite2D, centered: true do position = Vector2.new(10, 20) end`
macro create(type, **kwargs, &block)
  %inst = ::Godot.create({{type}})
  {% for k, v in kwargs %}
    %inst.{{k}} = {{v}}
  {% end %}
  {% if block && !block.body.is_a?(Nop) %}
    {% stmts = block.body.is_a?(Expressions) ? block.body.expressions : [block.body] %}
    {% for s in stmts %}
      {% if s.is_a?(Assign) %}
        %inst.{{s.target}} = {{s.value}}
      {% elsif s.is_a?(Call) %}
        %inst.{{s.name}}({{s.args.splat}})
      {% end %}
    {% end %}
  {% end %}
  %inst
end

# Idiomatic alias for `create`
macro build(type, **kwargs, &block)
  create({{type}}, {{kwargs.double_splat}}) {{block}}
end

# Instantiates a node, configures it, and attaches it as a child to the specified parent
# (defaults to `self` if inside a Node method, or current scene / root).
macro spawn_node(type, under = nil, **kwargs, &block)
  %parent = {% if under %}{{under}}{% else %}self{% end %}
  %inst = create({{type}}, {{kwargs.double_splat}}) {{block}}
  %parent.add_child(%inst)
  %inst
end

# Contextual alias for `spawn_node`
macro spawn_child(type, under = nil, **kwargs, &block)
  spawn_node({{type}}, under: {{under}}, {{kwargs.double_splat}}) {{block}}
end

# Declarative alias for `spawn_node`
macro create_child(type, under = nil, **kwargs, &block)
  spawn_node({{type}}, under: {{under}}, {{kwargs.double_splat}}) {{block}}
end

# Loads a PackedScene (.tscn) and instantiates it as wrapper type T with configuration
macro instantiate(path, as type = Godot::Node, **kwargs, &block)
  %scene = ::Godot.load({{path}}).as(::Godot::PackedScene)
  %inst = %scene.instantiate_as({{type}})
  {% for k, v in kwargs %}
    %inst.{{k}} = {{v}}
  {% end %}
  {% if block && !block.body.is_a?(Nop) %}
    {% stmts = block.body.is_a?(Expressions) ? block.body.expressions : [block.body] %}
    {% for s in stmts %}
      {% if s.is_a?(Assign) %}
        %inst.{{s.target}} = {{s.value}}
      {% elsif s.is_a?(Call) %}
        %inst.{{s.name}}({{s.args.splat}})
      {% end %}
    {% end %}
  {% end %}
  %inst
end

# Loads a PackedScene (.tscn), instantiates it as wrapper type T, and attaches it as a child to the parent
macro instantiate_child(path, under = nil, as type = Godot::Node, **kwargs, &block)
  %parent = {% if under %}{{under}}{% else %}self{% end %}
  %inst = instantiate({{path}}, as: {{type}}, {{kwargs.double_splat}}) {{block}}
  %parent.add_child(%inst)
  %inst
end

# Expressive convenience macro for 2D scene nodes defaulting to Godot::Node2D
macro node2d(decl)
  node2d {{decl}} do
  end
end

macro node2d(decl, &block)
  {% if decl.is_a?(Call) && decl.name == "<" %}
    node {{decl}} do
      {{block.body}}
    end
  {% else %}
    {% if decl.resolve? %}
      node {{decl}} do
        {{block.body}}
      end
    {% else %}
      node {{decl}} < Godot::Node2D do
        {{block.body}}
      end
    {% end %}
  {% end %}
end

# Expressive convenience macro for 3D spatial nodes defaulting to Godot::Node3D
macro node3d(decl)
  node3d {{decl}} do
  end
end

macro node3d(decl, &block)
  {% if decl.is_a?(Call) && decl.name == "<" %}
    node {{decl}} do
      {{block.body}}
    end
  {% else %}
    {% if decl.resolve? %}
      node {{decl}} do
        {{block.body}}
      end
    {% else %}
      node {{decl}} < Godot::Node3D do
        {{block.body}}
      end
    {% end %}
  {% end %}
end

macro node(decl)
  node {{decl}} do
  end
end

macro node(decl, &block)
  {% if decl.is_a?(Call) && decl.name == "<" %}
    {% class_name = decl.receiver %}
    {% raw_parent = decl.args[0] %}
    {% if raw_parent.stringify.includes?("::") %}
      {% parent_name = raw_parent %}
      {% base_godot_name = raw_parent.stringify.split("::").last %}
    {% elsif Godot.has_constant?(raw_parent.stringify) %}
      {% parent_name = "Godot::#{raw_parent}".id %}
      {% base_godot_name = raw_parent.stringify %}
    {% else %}
      {% parent_name = raw_parent %}
      {% base_godot_name = raw_parent.stringify %}
    {% end %}
  {% else %}
    {% class_name = decl %}
    {% parent_name = "Godot::Node".id %}
    {% base_godot_name = "Node" %}
  {% end %}
  {% is_reopen = class_name.resolve? != nil %}

  {%
    has_ready = false
    has_process = false
    has_physics_process = false
    has_enter_tree = false
    has_exit_tree = false
    has_build = false
    has_input = false
    has_unhandled_input = false
    has_unhandled_key_input = false
    has_shortcut_input = false
    has_gui_input = false
    has_custom_virtual_with_data = false
    is_tool_class = (base_godot_name == "EditorPlugin" || parent_name.stringify.includes?("EditorPlugin"))
    is_abstract_class = false
    is_static_unload = false
    class_icon_path = ""
    script_path_override = ""
    src_file = if !block.is_a?(Nop) && block.filename
                 block.filename
               elsif !decl.is_a?(Nop) && decl.filename
                 decl.filename
               else
                 __FILE__
               end
    props = [] of Nil
    sigs = [] of Nil
    methods_doc = [] of Nil
    onready_props = [] of Nil
    rpc_methods = [] of Nil
    node_groups = [] of Nil
    user_methods = [] of Nil
    tool_buttons = [] of Nil
    class_constants = [] of Nil
    class_doc = ""
    raw_stmts = if block.is_a?(Nop)
                  [] of Nil
                elsif block.body.is_a?(Expressions)
                  block.body.expressions
                elsif block.body.is_a?(Nop)
                  [] of Nil
                else
                  [block.body]
                end

    stmts_items = [] of Nil
    raw_stmts.each do |s|
      if s.is_a?(Call) && s.name.stringify == "export_category" && s.block && !s.block.is_a?(Nop)
        cat_name = s.args[0].is_a?(StringLiteral) ? s.args[0] : s.args[0].id.stringify
        stmts_items << {:category_start, cat_name}
        inner_cat = s.block.body.is_a?(Expressions) ? s.block.body.expressions : (s.block.body.is_a?(Nop) ? [] of Nil : [s.block.body])
        inner_cat.each do |s2|
          if s2.is_a?(Call) && s2.name.stringify == "export_group" && s2.block && !s2.block.is_a?(Nop)
            grp_name = s2.args[0].is_a?(StringLiteral) ? s2.args[0] : s2.args[0].id.stringify
            pfx = ""
            if s2.named_args
              s2.named_args.each do |na|
                if na.name.stringify == "prefix"
                  pfx = na.value.is_a?(StringLiteral) ? na.value : na.value.id.stringify
                end
              end
            end
            if pfx.empty? && s2.args.size > 1
              pfx = s2.args[1].is_a?(StringLiteral) ? s2.args[1] : s2.args[1].id.stringify
            end
            stmts_items << {:group_start, grp_name, pfx}
            inner_grp = s2.block.body.is_a?(Expressions) ? s2.block.body.expressions : (s2.block.body.is_a?(Nop) ? [] of Nil : [s2.block.body])
            inner_grp.each do |s3|
              if s3.is_a?(Call) && s3.name.stringify == "export_subgroup" && s3.block && !s3.block.is_a?(Nop)
                sub_name = s3.args[0].is_a?(StringLiteral) ? s3.args[0] : s3.args[0].id.stringify
                sub_pfx = ""
                if s3.named_args
                  s3.named_args.each do |sna|
                    if sna.name.stringify == "prefix"
                      sub_pfx = sna.value.is_a?(StringLiteral) ? sna.value : sna.value.id.stringify
                    end
                  end
                end
                if sub_pfx.empty? && s3.args.size > 1
                  sub_pfx = s3.args[1].is_a?(StringLiteral) ? s3.args[1] : s3.args[1].id.stringify
                end
                stmts_items << {:subgroup_start, sub_name, sub_pfx}
                inner_sub = s3.block.body.is_a?(Expressions) ? s3.block.body.expressions : (s3.block.body.is_a?(Nop) ? [] of Nil : [s3.block.body])
                inner_sub.each do |s4|
                  stmts_items << {:stmt, s4}
                end
                stmts_items << {:subgroup_end}
              else
                stmts_items << {:stmt, s3}
              end
            end
            stmts_items << {:group_end}
          else
            stmts_items << {:stmt, s2}
          end
        end
      elsif s.is_a?(Call) && s.name.stringify == "export_group" && s.block && !s.block.is_a?(Nop)
        grp_name = s.args[0].is_a?(StringLiteral) ? s.args[0] : s.args[0].id.stringify
        pfx = ""
        if s.named_args
          s.named_args.each do |na|
            if na.name.stringify == "prefix"
              pfx = na.value.is_a?(StringLiteral) ? na.value : na.value.id.stringify
            end
          end
        end
        if pfx.empty? && s.args.size > 1
          pfx = s.args[1].is_a?(StringLiteral) ? s.args[1] : s.args[1].id.stringify
        end
        stmts_items << {:group_start, grp_name, pfx}
        inner_grp = s.block.body.is_a?(Expressions) ? s.block.body.expressions : (s.block.body.is_a?(Nop) ? [] of Nil : [s.block.body])
        inner_grp.each do |s3|
          if s3.is_a?(Call) && s3.name.stringify == "export_subgroup" && s3.block && !s3.block.is_a?(Nop)
            sub_name = s3.args[0].is_a?(StringLiteral) ? s3.args[0] : s3.args[0].id.stringify
            sub_pfx = ""
            if s3.named_args
              s3.named_args.each do |sna|
                if sna.name.stringify == "prefix"
                  sub_pfx = sna.value.is_a?(StringLiteral) ? sna.value : sna.value.id.stringify
                end
              end
            end
            if sub_pfx.empty? && s3.args.size > 1
              sub_pfx = s3.args[1].is_a?(StringLiteral) ? s3.args[1] : s3.args[1].id.stringify
            end
            stmts_items << {:subgroup_start, sub_name, sub_pfx}
            inner_sub = s3.block.body.is_a?(Expressions) ? s3.block.body.expressions : (s3.block.body.is_a?(Nop) ? [] of Nil : [s3.block.body])
            inner_sub.each do |s4|
              stmts_items << {:stmt, s4}
            end
            stmts_items << {:subgroup_end}
          else
            stmts_items << {:stmt, s3}
          end
        end
        stmts_items << {:group_end}
      elsif s.is_a?(Call) && s.name.stringify == "export_subgroup" && s.block && !s.block.is_a?(Nop)
        sub_name = s.args[0].is_a?(StringLiteral) ? s.args[0] : s.args[0].id.stringify
        sub_pfx = ""
        if s.named_args
          s.named_args.each do |sna|
            if sna.name.stringify == "prefix"
              sub_pfx = sna.value.is_a?(StringLiteral) ? sna.value : sna.value.id.stringify
            end
          end
        end
        if sub_pfx.empty? && s.args.size > 1
          sub_pfx = s.args[1].is_a?(StringLiteral) ? s.args[1] : s.args[1].id.stringify
        end
        stmts_items << {:subgroup_start, sub_name, sub_pfx}
        inner_sub = s.block.body.is_a?(Expressions) ? s.block.body.expressions : (s.block.body.is_a?(Nop) ? [] of Nil : [s.block.body])
        inner_sub.each do |s4|
          stmts_items << {:stmt, s4}
        end
        stmts_items << {:subgroup_end}
      else
        stmts_items << {:stmt, s}
      end
    end
    last_anno = nil

    # Extract source file text to harvest doc comments
    src_file = (!block.is_a?(Nop) && block.filename) ? block.filename : __FILE__
    src_content = read_file(src_file)
    src_lines = src_content.split("\n")
    comment_accum = ""
    in_target_node = false
    node_processed = false
    node_depth = 0
    extracted_prop_docs = {} of StringLiteral => StringLiteral
    extracted_sig_docs = {} of StringLiteral => StringLiteral
    extracted_method_docs = {} of StringLiteral => StringLiteral
    extracted_aliases = {} of StringLiteral => ArrayLiteral(StringLiteral)
    src_lines.each do |al_line|
      al_s = al_line.strip
      if al_s.starts_with?("alias ") && al_s.includes?("=")
        al_parts = al_s.gsub(/^alias\s+/, "").split("=")
        al_name = al_parts[0].strip
        al_rhs = al_parts[1].strip
        if al_rhs.includes?("|")
          al_types = [] of StringLiteral
          al_rhs.split("|").each do |al_tp|
            al_types << al_tp.strip
          end
          extracted_aliases[al_name] = al_types
        end
      end
    end
  %}

  {% for s_line in src_lines %}
    {% if !node_processed %}
      {% s_stripped = s_line.strip %}
      {% if s_stripped.starts_with?("#") %}
        {% s_text = s_stripped.gsub(/^#+\s*/, "") %}
        {% if !s_text.starts_with?("=") && !s_text.starts_with?("-") && !s_text.empty? %}
          {% comment_accum = comment_accum.empty? ? s_text : comment_accum + " " + s_text %}
        {% end %}
      {% elsif s_stripped.empty? %}
        {% comment_accum = "" %}
      {% elsif !in_target_node && (s_stripped.starts_with?("node " + class_name.stringify) || s_stripped.includes?("node " + class_name.stringify + " ") || s_stripped.includes?("node " + class_name.stringify + "<") || s_stripped.starts_with?("resource " + class_name.stringify) || s_stripped.includes?("resource " + class_name.stringify + " ") || s_stripped.includes?("resource " + class_name.stringify + "<") || s_stripped.starts_with?("gdclass " + class_name.stringify) || s_stripped.includes?("gdclass " + class_name.stringify + " ") || s_stripped.includes?("gdclass " + class_name.stringify + "<")) %}
        {% if class_doc.empty? %}
          {% class_doc = comment_accum %}
        {% end %}
        {% comment_accum = "" %}
        {% in_target_node = true %}
        {% node_depth = 1 %}
      {% elsif !in_target_node %}
        {% if s_stripped.starts_with?("@[Icon(") %}
          {% class_icon_path = s_stripped.gsub(/^@\[Icon\(\"/, "").gsub(/\"\)\].*/, "") %}
        {% elsif s_stripped.starts_with?("@[Abstract]") %}
          {% is_abstract_class = true %}
        {% elsif s_stripped.starts_with?("@[Tool]") %}
          {% is_tool_class = true %}
        {% elsif s_stripped.starts_with?("@[StaticUnload]") %}
          {% is_static_unload = true %}
        {% elsif s_stripped.starts_with?("@[ScriptPath(") %}
          {% script_path_override = s_stripped.gsub(/^@\[ScriptPath\(\"/, "").gsub(/\"\)\].*/, "") %}
        {% elsif !s_stripped.starts_with?("@") && !s_stripped.empty? %}
          {% comment_accum = "" %}
          {% class_icon_path = "" %}
          {% script_path_override = "" %}
          {% is_abstract_class = false %}
          {% is_tool_class = false %}
          {% is_static_unload = false %}
        {% end %}
      {% elsif in_target_node %}
        {% if s_stripped.starts_with?("property ") %}
          {% p_var = s_stripped.gsub(/^property\s+/, "").gsub(/\s*[:=].*/, "") %}
          {% extracted_prop_docs[p_var] = comment_accum %}
          {% comment_accum = "" %}
        {% elsif s_stripped.starts_with?("signal ") %}
          {% s_var = s_stripped.gsub(/^signal\s+/, "").gsub(/\s*[(:].*/, "") %}
          {% extracted_sig_docs[s_var] = comment_accum %}
          {% comment_accum = "" %}
        {% elsif s_stripped.starts_with?("def ") || s_stripped.starts_with?("def self.") %}
          {% m_var = s_stripped.gsub(/^def\s+(self\.)?/, "").gsub(/\s*[(:].*/, "") %}
          {% extracted_method_docs[m_var] = comment_accum %}
          {% comment_accum = "" %}
          {% node_depth = node_depth + 1 %}
        {% elsif s_stripped.starts_with?("if ") || s_stripped.starts_with?("unless ") || s_stripped.starts_with?("while ") || s_stripped.starts_with?("until ") || s_stripped.starts_with?("case ") || s_stripped.starts_with?("begin") || s_stripped.ends_with?(" do") || s_stripped.includes?(" do |") %}
          {% node_depth = node_depth + 1 %}
          {% comment_accum = "" %}
        {% elsif s_stripped == "end" %}
          {% node_depth = node_depth - 1 %}
          {% if node_depth <= 0 %}
            {% in_target_node = false %}
            {% node_processed = true %}
          {% end %}
          {% comment_accum = "" %}
        {% elsif !s_stripped.starts_with?("@") && !s_stripped.empty? %}
          {% comment_accum = "" %}
        {% end %}
      {% else %}
        {% comment_accum = "" %}
      {% end %}
    {% end %}
  {% end %}

  {% if base_godot_name == "EditorPlugin" || parent_name.stringify.includes?("EditorPlugin") %}
    {% is_tool_class = true %}
  {% end %}

  {% for item_entry in stmts_items %}
    {% if item_entry[0] == :category_start %}
      {% props << {:category, item_entry[1], ""} %}
    {% elsif item_entry[0] == :group_start %}
      {% props << {:group, item_entry[1], item_entry[2]} %}
    {% elsif item_entry[0] == :group_end %}
      {% props << {:group, "", ""} %}
    {% elsif item_entry[0] == :subgroup_start %}
      {% props << {:subgroup, item_entry[1], item_entry[2]} %}
    {% elsif item_entry[0] == :subgroup_end %}
      {% props << {:subgroup, "", ""} %}
    {% elsif item_entry[0] == :stmt %}
      {% stmt = item_entry[1] %}
      {% if stmt.class_name.id == "Annotation" %}
        {% anno_name = stmt.name.names.last.stringify %}
        {% if anno_name == "Doc" %}
          {% class_doc = stmt.args[0].stringify %}
        {% elsif anno_name == "Tool" %}
          {% is_tool_class = true %}
        {% elsif anno_name == "Icon" %}
          {% class_icon_path = stmt.args[0].stringify %}
        {% elsif anno_name == "Abstract" %}
          {% is_abstract_class = true %}
        {% elsif anno_name == "StaticUnload" %}
          {% is_static_unload = true %}
        {% elsif anno_name == "ScriptPath" %}
          {% script_path_override = stmt.args[0].stringify %}
        {% elsif anno_name == "ExportCategory" %}
          {% cat_name = stmt.args[0].is_a?(StringLiteral) ? stmt.args[0] : stmt.args[0].id.stringify %}
          {% props << {:category, cat_name, ""} %}
        {% elsif anno_name == "Group" %}
          {% for g in stmt.args %}
            {% node_groups << (g.is_a?(StringLiteral) ? g : g.id.stringify) %}
          {% end %}
        {% elsif anno_name == "ExportGroup" %}
          {% grp_name = stmt.args[0].is_a?(StringLiteral) ? stmt.args[0] : stmt.args[0].id.stringify %}
          {% pfx = "" %}
          {% if stmt.named_args %}
            {% for k, v in stmt.named_args %}
              {% if k.stringify == "prefix" %}
                {% pfx = v.is_a?(StringLiteral) ? v : v.id.stringify %}
              {% end %}
            {% end %}
          {% end %}
          {% if pfx.empty? && stmt.args.size > 1 %}
            {% pfx = stmt.args[1].is_a?(StringLiteral) ? stmt.args[1] : stmt.args[1].id.stringify %}
          {% end %}
          {% props << {:group, grp_name, pfx} %}
          {% last_anno = stmt %}
        {% elsif anno_name == "ExportSubgroup" %}
          {% sub_name = stmt.args[0].is_a?(StringLiteral) ? stmt.args[0] : stmt.args[0].id.stringify %}
          {% pfx = "" %}
          {% if stmt.named_args %}
            {% for k, v in stmt.named_args %}
              {% if k.stringify == "prefix" %}
                {% pfx = v.is_a?(StringLiteral) ? v : v.id.stringify %}
              {% end %}
            {% end %}
          {% end %}
          {% if pfx.empty? && stmt.args.size > 1 %}
            {% pfx = stmt.args[1].is_a?(StringLiteral) ? stmt.args[1] : stmt.args[1].id.stringify %}
          {% end %}
          {% props << {:subgroup, sub_name, pfx} %}
          {% last_anno = stmt %}
        {% elsif anno_name == "WarningIgnore" || anno_name == "WarningIgnoreStart" || anno_name == "WarningIgnoreRestore" %}
          # suppressed warning, no-op
        {% else %}
          {% last_anno = stmt %}
        {% end %}
    {% elsif stmt.is_a?(Call) && stmt.name.stringify == "icon" %}
      {% class_icon_path = stmt.args[0].is_a?(StringLiteral) ? stmt.args[0] : stmt.args[0].id.stringify %}
    {% elsif stmt.is_a?(Call) && stmt.name.stringify == "abstract_class" %}
      {% is_abstract_class = true %}
    {% elsif stmt.is_a?(Call) && stmt.name.stringify == "static_unload" %}
      {% is_static_unload = true %}
    {% elsif stmt.is_a?(Call) && stmt.name.stringify == "export_category" %}
      {% cat_name = stmt.args[0].is_a?(StringLiteral) ? stmt.args[0] : stmt.args[0].id.stringify %}
      {% props << {:category, cat_name, ""} %}
    {% elsif stmt.is_a?(Call) && stmt.name.stringify == "export_group" %}
      {% grp_name = stmt.args[0].is_a?(StringLiteral) ? stmt.args[0] : stmt.args[0].id.stringify %}
      {% pfx = "" %}
      {% if stmt.named_args %}
        {% for na in stmt.named_args %}
          {% if na.name.stringify == "prefix" %}
            {% pfx = na.value.is_a?(StringLiteral) ? na.value : na.value.id.stringify %}
          {% end %}
        {% end %}
      {% end %}
      {% if pfx.empty? && stmt.args.size > 1 %}
        {% pfx = stmt.args[1].is_a?(StringLiteral) ? stmt.args[1] : stmt.args[1].id.stringify %}
      {% end %}
      {% props << {:group, grp_name, pfx} %}
    {% elsif stmt.is_a?(Call) && stmt.name.stringify == "export_subgroup" %}
      {% sub_name = stmt.args[0].is_a?(StringLiteral) ? stmt.args[0] : stmt.args[0].id.stringify %}
      {% pfx = "" %}
      {% if stmt.named_args %}
        {% for na in stmt.named_args %}
          {% if na.name.stringify == "prefix" %}
            {% pfx = na.value.is_a?(StringLiteral) ? na.value : na.value.id.stringify %}
          {% end %}
        {% end %}
      {% end %}
      {% if pfx.empty? && stmt.args.size > 1 %}
        {% pfx = stmt.args[1].is_a?(StringLiteral) ? stmt.args[1] : stmt.args[1].id.stringify %}
      {% end %}
      {% props << {:subgroup, sub_name, pfx} %}
    {% elsif stmt.is_a?(Call) && stmt.name.stringify == "group" %}
      {% for g in stmt.args %}
        {% node_groups << (g.is_a?(StringLiteral) ? g : g.id.stringify) %}
      {% end %}
    {% elsif stmt.is_a?(Call) && (stmt.name.stringify == "onready" || stmt.name.stringify == "node_ref" || stmt.name.stringify == "unique_node_ref" || stmt.name.stringify == "unique_node") %}
      {% is_unique_call = (stmt.name.stringify == "unique_node_ref" || stmt.name.stringify == "unique_node") %}
      {% if stmt.args.size == 1 %}
        {% o_decl = stmt.args[0] %}
        {% if o_decl.is_a?(TypeDeclaration) %}
          {% o_name = o_decl.var.stringify %}
          {% o_path = o_decl.value ? (o_decl.value.is_a?(StringLiteral) ? o_decl.value : o_decl.value.id.stringify) : (is_unique_call ? "%#{o_name.camelcase}" : o_name) %}
          {% if is_unique_call && !o_path.starts_with?('%') %}
            {% o_path = "%" + o_path %}
          {% end %}
          {% o_t = o_decl.type %}
          {% if o_t.is_a?(Union) %}
            {% actual_o_t = o_t.types.reject { |sub_t| sub_t.stringify == "Nil" || sub_t.stringify == "::Nil" }[0] %}
          {% else %}
            {% actual_o_t = o_t %}
          {% end %}
          {% onready_props << {o_decl.var, actual_o_t, o_path} %}
        {% end %}
      {% elsif stmt.args.size >= 2 %}
        {% o_var = stmt.args[0] %}
        {% o_type = stmt.args[1] %}
        {% if stmt.args.size >= 3 %}
          {% raw_p = stmt.args[2] %}
          {% o_path = raw_p.is_a?(StringLiteral) ? raw_p : raw_p.id.stringify %}
        {% else %}
          {% o_path = is_unique_call ? "%#{o_var.id.stringify.camelcase}" : o_var.id.stringify.camelcase %}
        {% end %}
        {% if is_unique_call && !o_path.starts_with?('%') %}
          {% o_path = "%" + o_path %}
        {% end %}
        {% onready_props << {o_var, o_type, o_path} %}
      {% end %}
    {% elsif stmt.is_a?(StringLiteral) && class_doc.empty? %}
      {% class_doc = stmt.value %}
    {% elsif stmt.is_a?(Def) && (stmt.receiver.is_a?(Nop) || !stmt.receiver) %}
      {% if stmt.name.stringify == "_ready" %}
        {% has_ready = true %}
      {% elsif stmt.name.stringify == "_process" %}
        {% has_process = true %}
      {% elsif stmt.name.stringify == "_physics_process" %}
        {% has_physics_process = true %}
      {% elsif stmt.name.stringify == "_enter_tree" %}
        {% has_enter_tree = true %}
      {% elsif stmt.name.stringify == "_exit_tree" %}
        {% has_exit_tree = true %}
      {% elsif stmt.name.stringify == "_build" %}
        {% has_build = true %}
      {% elsif stmt.name.stringify == "_input" %}
        {% has_input = true %}
      {% elsif stmt.name.stringify == "_unhandled_input" %}
        {% has_unhandled_input = true %}
      {% elsif stmt.name.stringify == "_unhandled_key_input" %}
        {% has_unhandled_key_input = true %}
      {% elsif stmt.name.stringify == "_shortcut_input" %}
        {% has_shortcut_input = true %}
      {% elsif stmt.name.stringify == "_gui_input" %}
        {% has_gui_input = true %}
      {% elsif stmt.name.stringify == "_godot_call_virtual_with_data" %}
        {% has_custom_virtual_with_data = true %}
      {% elsif !stmt.name.stringify.starts_with?("_") && stmt.args.size == 0 %}
        {% user_methods << stmt.name %}
      {% end %}
      {% if last_anno && last_anno.name.stringify == "RPC" %}
        {%
          r_mode = 2
          r_trans = 2
          r_local = false
          r_chan = 0
        %}
        {% if last_anno.named_args %}
          {% for k, v in last_anno.named_args %}
            {% if k.stringify == "mode" %}
              {% if v.stringify == "any_peer" || v.id == "any_peer" %}
                {% r_mode = 1 %}
              {% else %}
                {% r_mode = 2 %}
              {% end %}
            {% elsif k.stringify == "sync" %}
              {% if v.stringify == "call_local" || v.id == "call_local" %}
                {% r_local = true %}
              {% end %}
            {% elsif k.stringify == "call_local" %}
              {% r_local = v %}
            {% elsif k.stringify == "transfer_mode" %}
              {% if v.stringify == "unreliable" || v.id == "unreliable" %}
                {% r_trans = 0 %}
              {% elsif v.stringify == "unreliable_ordered" || v.id == "unreliable_ordered" %}
                {% r_trans = 1 %}
              {% else %}
                {% r_trans = 2 %}
              {% end %}
            {% elsif k.stringify == "channel" %}
              {% r_chan = v %}
            {% end %}
          {% end %}
        {% elsif last_anno.args.size > 0 %}
          {% if last_anno.args[0].stringify == "any_peer" || last_anno.args[0].id == "any_peer" %}
            {% r_mode = 1 %}
          {% end %}
          {% if last_anno.args.size > 1 %}
            {% if last_anno.args[1].stringify == "call_local" || last_anno.args[1].id == "call_local" %}
              {% r_local = true %}
            {% end %}
          {% end %}
          {% if last_anno.args.size > 2 %}
            {% if last_anno.args[2].stringify == "unreliable" || last_anno.args[2].id == "unreliable" %}
              {% r_trans = 0 %}
            {% elsif last_anno.args[2].stringify == "unreliable_ordered" || last_anno.args[2].id == "unreliable_ordered" %}
              {% r_trans = 1 %}
            {% else %}
              {% r_trans = 2 %}
            {% end %}
          {% end %}
          {% if last_anno.args.size > 3 %}
            {% r_chan = last_anno.args[3] %}
          {% end %}
        {% end %}
        {% rpc_methods << {stmt.name.stringify, r_mode, r_trans, r_local, r_chan} %}
      {% elsif last_anno && last_anno.name.stringify == "ExportToolButton" %}
        {% if stmt.args.size > 0 %}
          {% raise "ExportToolButton method '#{stmt.name}' cannot have arguments" %}
        {% end %}
        {%
          tb_label = ""
          tb_icon = ""
          if last_anno.args.size > 0
            tb_label = (last_anno.args[0].is_a?(StringLiteral) ? last_anno.args[0] : last_anno.args[0].id.stringify).gsub(/^\"|\"$/, "")
          end
          if last_anno.args.size > 1
            tb_icon = (last_anno.args[1].is_a?(StringLiteral) ? last_anno.args[1] : last_anno.args[1].id.stringify).gsub(/^\"|\"$/, "")
          end
        %}
        {% if last_anno.named_args %}
          {% for key, val in last_anno.named_args %}
            {% if key.stringify == "icon" %}
              {% tb_icon = (val.is_a?(StringLiteral) ? val : val.id.stringify).gsub(/^\"|\"$/, "") %}
            {% elsif key.stringify == "text" || key.stringify == "label" %}
              {% tb_label = (val.is_a?(StringLiteral) ? val : val.id.stringify).gsub(/^\"|\"$/, "") %}
            {% end %}
          {% end %}
        {% end %}
        {%
          if tb_label.empty?
            tb_label = stmt.name.stringify.split("_").map(&.capitalize).join(" ")
          end
          tb_hint_str = tb_icon.empty? ? tb_label : "#{tb_label.id},#{tb_icon.id}"
        %}
        {% tool_buttons << {stmt.name, tb_hint_str, :method} %}
        {% props << {:tool_button, stmt.name, tb_hint_str} %}
      {% end %}
      {%
        m_name_str = stmt.name.stringify
        is_lifecycle_cb = (m_name_str == "_ready" || m_name_str == "_process" || m_name_str == "_physics_process" || m_name_str == "_enter_tree" || m_name_str == "_exit_tree" || m_name_str == "_build")
        m_doc = extracted_method_docs[m_name_str] || (stmt.doc_comment ? stmt.doc_comment.stringify : "") || ""
      %}
      {% if !is_lifecycle_cb || (!m_doc.empty?) %}
        {% methods_doc << {stmt.name, stmt.args, stmt.return_type, m_doc.stringify} %}
      {% end %}
      {% last_anno = nil %}
    {% elsif stmt.is_a?(Call) && stmt.name.id == "property" %}
      {%
        p_arg = stmt.args[0]
        if p_arg.is_a?(Assign)
          p_var_name = p_arg.target
          p_val = p_arg.value
          p_type = nil
        else
          p_var_name = p_arg.var
          p_val = p_arg.value
          p_type = p_arg.type
        end
        p_name_str = p_var_name.stringify
        p_doc = extracted_prop_docs[p_name_str] || ""
        p_decl = p_arg
        enum_target = nil
        if p_type && p_type.is_a?(Path) && p_type.resolve? && (p_type.resolve < Enum)
          enum_target = p_type.resolve
        elsif last_anno && (last_anno.name.stringify == "ExportEnum" || last_anno.name.stringify == "ExportFlags") && last_anno.args.size > 0 && last_anno.args[0].is_a?(Path) && last_anno.args[0].resolve? && (last_anno.args[0].resolve < Enum)
          enum_target = last_anno.args[0].resolve
        end

        if enum_target
          is_flags = (last_anno && last_anno.name.stringify == "ExportFlags") || enum_target.annotation(Flags) || enum_target.annotation(::Flags)
          enum_target.constants.each do |c_item|
            if !is_flags || (c_item.stringify != "None" && c_item.stringify != "All")
              already_present = false
              class_constants.each do |existing|
                if existing[0] == enum_target.name.stringify && existing[1] == c_item.stringify
                  already_present = true
                end
              end
              if !already_present
                class_constants << {enum_target.name.stringify, c_item.stringify, enum_target, c_item, is_flags ? true : false}
              end
            end
          end
        end
      %}
      {% if last_anno && (last_anno.name.stringify == "OnReady" || last_anno.name.stringify == "NodeRef" || last_anno.name.stringify == "ChildNode" || last_anno.name.stringify == "UniqueNode" || last_anno.name.stringify == "UniqueNodeRef") %}
        {% is_unique = (last_anno.name.stringify == "UniqueNode" || last_anno.name.stringify == "UniqueNodeRef") %}
        {% onready_path = last_anno.args.size > 0 ? (last_anno.args[0].is_a?(StringLiteral) ? last_anno.args[0] : last_anno.args[0].id.stringify) : (is_unique ? "%#{p_name_str.camelcase}" : p_name_str) %}
        {% if is_unique && !onready_path.starts_with?('%') %}
          {% onready_path = "%" + onready_path %}
        {% end %}
        {% o_t = p_type %}
        {% if o_t.is_a?(Union) %}
          {% actual_o_t = o_t.types.reject { |sub_t| sub_t.stringify == "Nil" || sub_t.stringify == "::Nil" }[0] %}
        {% else %}
          {% actual_o_t = o_t %}
        {% end %}
        {% onready_props << {p_var_name, actual_o_t, onready_path} %}
      {% else %}
        {% if last_anno %}
          {% a_name = last_anno.name.is_a?(Path) ? last_anno.name.names.last.stringify : last_anno.name.stringify %}
          {% if a_name == "ExportToolButton" %}
            {%
              p_t_str = p_type ? p_type.stringify.gsub(/^(::)?/, "") : ""
              is_proc = false
              if p_val && (p_val.is_a?(ProcPointer) || p_val.is_a?(ProcLiteral))
                is_proc = true
              elsif p_t_str.starts_with?("Proc(")
                is_proc = true
              elsif p_val && p_val.is_a?(Call)
                raise "ExportToolButton property '#{p_var_name}' must be assigned a Proc (e.g. 'property #{p_var_name} = ->some_method' or 'property #{p_var_name} = ->{ ... }'), not a method call '#{p_val.name}'. Tool buttons take only a no-args proc: Proc(Void)."
              else
                raise "ExportToolButton property '#{p_var_name}' must be a no-args proc: Proc(Void) (e.g. 'property #{p_var_name} = ->some_method' or 'property #{p_var_name} = ->{ ... }'), got '#{p_type || p_val}'"
              end

              norm_t = p_t_str.gsub(/^(::)?/, "").gsub(/\s*\|\s*(::)?Nil/, "").gsub(/\?/, "").strip
              if !norm_t.empty? && norm_t != "Proc(Void)" && norm_t != "Proc(Nil)"
                raise "ExportToolButton property '#{p_var_name}' must take only a no-args proc: Proc(Void), got '#{p_type}'"
              end
              if p_val && p_val.is_a?(ProcPointer) && p_val.args.size > 0
                raise "ExportToolButton proc pointer '#{p_var_name}' takes #{p_val.args.size} argument(s). Tool buttons must take only a no-args proc."
              elsif p_val && p_val.is_a?(ProcLiteral) && p_val.stringify.starts_with?("->(")
                raise "ExportToolButton proc literal '#{p_var_name}' takes argument(s). Tool buttons must take only a no-args proc."
              end
              tb_kind = :proc_property
            %}
            {% tool_buttons << {p_var_name, "", tb_kind} %}
          {% end %}
          {% for key, val in last_anno.named_args %}
            {% if key.stringify == "doc" %}
              {% p_doc = val.stringify %}
            {% end %}
          {% end %}
        {% end %}
        {% props << {:prop, stmt.args[0], last_anno, p_doc} %}
      {% end %}
      {% last_anno = nil %}
    {% elsif stmt.is_a?(Call) && stmt.name.id == "signal" %}
      {%
        s_item = stmt.args[0]
        s_name_str = (s_item.is_a?(Call) ? s_item.name : s_item).stringify
        s_doc = extracted_sig_docs[s_name_str] || ""
      %}
      {% sigs << {stmt.args[0], s_doc} %}
      {% last_anno = nil %}
    {% else %}
      {% last_anno = nil %}
    {% end %}
    {% end %}
  {% end %}

  {% if onready_props.size > 0 || rpc_methods.size > 0 %}
    {% has_ready = true %}
  {% end %}

  {%
    proc_tb_names = [] of StringLiteral
    tool_buttons.each do |tb|
      if tb[2] == :proc_property
        proc_tb_names << tb[0].stringify
      end
    end
  %}

  @[GodotClass]
  class {{class_name}} {% unless is_reopen %} < {{parent_name}} {% end %}
    def self.godot_class_name : String
      "{{class_name}}"
    end

    def self.godot_parent_class_name : String
      {{base_godot_name}}
    end

    macro create(**kwargs, &block)
      ::create(\{{@type}}, \{{kwargs.double_splat}}) \{{block}}
    end

    macro build(**kwargs, &block)
      ::create(\{{@type}}, \{{kwargs.double_splat}}) \{{block}}
    end

    def self.new(&block : self ->) : self
      inst = ::Godot.create(self)
      with inst yield inst
      inst
    end

    def self._godot_has_virtual_method(method_name : String) : Bool
      norm = method_name.starts_with?('_') ? method_name : "_#{method_name}"
      case norm
      when "_enter_tree"
        return true
      {% for item_entry in stmts_items %}
        {% if item_entry[0] == :stmt %}
          {% stmt = item_entry[1] %}
          {% if stmt.is_a?(Def) && stmt.name.stringify.starts_with?("_") && stmt.name.stringify != "_enter_tree" %}
          when {{stmt.name.stringify}}
            return true
          {% end %}
        {% end %}
      {% end %}
      else
        {% if is_reopen %}
          previous_def
        {% else %}
          super
        {% end %}
      end
    end

    {% if proc_tb_names.size > 0 %}
      # Intercept property definitions inside the node to support proc-based ExportToolButtons
      # (e.g. `property my_button = ->some_method`, `property my_button : Proc(Void) = ->some_method`,
      # or `property my_button = ->{ ... }`)
      macro property(*names, &block)
        \{% for name in names %}
          \{%
            p_name = nil
            p_val = nil
            if name.is_a?(Assign)
              p_name = name.target.stringify
              p_val = name.value
            elsif name.is_a?(TypeDeclaration)
              p_name = name.var.stringify
              p_val = name.value
            end
          %}
          \{% if p_name && {{proc_tb_names}}.includes?(p_name) && p_val && p_val.is_a?(ProcPointer) %}
            \{% m_name = p_val.name %}
            @\{{p_name.id}} : Proc(Void)? = nil
            def \{{p_name.id}} : Proc(Void)
              if val = @\{{p_name.id}}
                val
              else
                fn = ->{ self.\{{m_name.id}}; nil }
                @\{{p_name.id}} = fn
                fn
              end
            end
            def \{{p_name.id}}=(val : Proc(Void))
              @\{{p_name.id}} = val
            end
          \{% elsif p_name && {{proc_tb_names}}.includes?(p_name) && p_val && p_val.is_a?(ProcLiteral) %}
            @\{{p_name.id}} : Proc(Void)? = nil
            def \{{p_name.id}} : Proc(Void)
              if val = @\{{p_name.id}}
                val
              else
                raw_proc = (\{{p_val}})
                fn = ->{ raw_proc.call; nil }
                @\{{p_name.id}} = fn
                fn
              end
            end
            def \{{p_name.id}}=(val : Proc(Void))
              @\{{p_name.id}} = val
            end
          \{% elsif block %}
            ::property \{{name}} \{{block}}
          \{% else %}
            ::property \{{name}}
          \{% end %}
        \{% end %}
      end
    {% end %}

    # Macro block containing fields, signals, and methods
    {{ yield }}

    {% if onready_props.size > 0 %}
      private def _godot_init_onready_properties : Void
        {% for item in onready_props %}
          {% v_name = item[0] %}
          {% v_type = item[1] %}
          {% v_path = item[2] %}
          if n = get_node_as?({{v_path}}, {{v_type}})
            self.{{v_name.id}} = n
          end
        {% end %}
      end
    {% end %}

    {% if rpc_methods.size > 0 %}
      private def _godot_setup_rpc_configs : Void
        {% for r in rpc_methods %}
          ::Godot::Bridge.node_rpc_config(@pointer, {{r[0]}}, {{r[1]}}, {{r[2]}}, {{r[3]}}, {{r[4]}})
        {% end %}
      end
    {% end %}

    def _godot_call_virtual(method_name : String, delta : Float64) : Void
      ::Godot::NodeContext.scope(self) do
        case method_name
        when "_enter_tree"
          {% unless base_godot_name.stringify.includes?("Script") || base_godot_name.stringify.includes?("Plugin") || class_name.stringify.includes?("Script") || class_name.stringify.includes?("Plugin") %}
          link_class_script if ::Godot.editor_hint?
          {% end %}
          if !::Godot.editor_hint? || {{is_tool_class}}
            _enter_tree if responds_to?(:_enter_tree)
          end
        when "_exit_tree"
          _exit_tree if responds_to?(:_exit_tree)
        {% if has_build %}
        when "_build"
          _build if responds_to?(:_build)
        {% end %}
        when "_ready"
          {% if node_groups.size > 0 %}
            {% for grp in node_groups %}
              add_to_group({{grp}})
            {% end %}
          {% end %}
          {% if onready_props.size > 0 %}
            _godot_init_onready_properties
          {% end %}
          {% if rpc_methods.size > 0 %}
            _godot_setup_rpc_configs
          {% end %}
          _ready if responds_to?(:_ready)
        when "_process"
          ::Godot::ThreadSafety.flush_main_thread_queue!
          _process(delta) if responds_to?(:_process)
        when "_physics_process"
          ::Godot::ThreadSafety.flush_main_thread_queue!
          _physics_process(delta) if responds_to?(:_physics_process)
        else
          {% if is_reopen %}
            previous_def
          {% else %}
            super
          {% end %}
        end
      end
    end

    {% if !has_custom_virtual_with_data && (has_input || has_unhandled_input || has_unhandled_key_input || has_shortcut_input || has_gui_input) %}
    def _godot_call_virtual_with_data(method_name : String, args : Void**, ret : Void*) : Void
      ::Godot::NodeContext.scope(self) do
        case method_name
        {% if has_input %}
        when "_input", "input"
          if !args.null? && !args[0].null?
            _input(::Godot::InputEvent.wrap(args[0]))
          end
        {% end %}
        {% if has_unhandled_input %}
        when "_unhandled_input", "unhandled_input"
          if !args.null? && !args[0].null?
            _unhandled_input(::Godot::InputEvent.wrap(args[0]))
          end
        {% end %}
        {% if has_unhandled_key_input %}
        when "_unhandled_key_input", "unhandled_key_input"
          if !args.null? && !args[0].null?
            _unhandled_key_input(::Godot::InputEvent.wrap(args[0]))
          end
        {% end %}
        {% if has_shortcut_input %}
        when "_shortcut_input", "shortcut_input"
          if !args.null? && !args[0].null?
            _shortcut_input(::Godot::InputEvent.wrap(args[0]))
          end
        {% end %}
        {% if has_gui_input %}
        when "_gui_input", "gui_input"
          if !args.null? && !args[0].null?
            _gui_input(::Godot::InputEvent.wrap(args[0]))
          end
        {% end %}
        else
          {% if is_reopen %}
            previous_def
          {% else %}
            super
          {% end %}
        end
      end
    end
    {% end %}

    {% if user_methods.size > 0 %}
    def call(method : String, *args) : Void*
      ::Godot::NodeContext.scope(self) do
        case method
        {% for m in user_methods %}
        when {{m.stringify}}
          {{m.id}}
          Pointer(Void).null
        {% end %}
        else
          {% if is_reopen %}
            previous_def
          {% else %}
            super
          {% end %}
        end
      end
    end
    {% end %}

    def _godot_set_property(prop_name : String, val_ptr : Void*) : Void
      case prop_name
      {% for item in props %}
        {% if item[0] == :prop %}
          {% arg = item[1] %}
          {% var_name = arg.is_a?(Assign) ? arg.target : arg.var %}
          {% var_type = arg.is_a?(Assign) ? "Callable" : (arg.type ? arg.type.stringify.gsub(/^(::)?Godot::/, "") : "Callable") %}
          when "{{var_name.id}}"
            {% if var_type == "Float32" %}
              self.{{var_name.id}} = val_ptr.as(Float64*).value.to_f32
            {% elsif var_type == "Float64" %}
              self.{{var_name.id}} = val_ptr.as(Float64*).value
            {% elsif var_type == "Int32" %}
              self.{{var_name.id}} = val_ptr.as(Int64*).value.to_i32
            {% elsif var_type == "Int64" %}
              self.{{var_name.id}} = val_ptr.as(Int64*).value
            {% elsif var_type == "Bool" %}
              self.{{var_name.id}} = val_ptr.as(UInt8*).value != 0_u8
            {% elsif var_type == "Vector2" %}
              self.{{var_name.id}} = val_ptr.as(::Godot::Vector2*).value
            {% elsif var_type == "Vector2i" %}
              self.{{var_name.id}} = val_ptr.as(::Godot::Vector2i*).value
            {% elsif var_type == "Vector3" %}
              self.{{var_name.id}} = val_ptr.as(::Godot::Vector3*).value
            {% elsif var_type == "Vector3i" %}
              self.{{var_name.id}} = val_ptr.as(::Godot::Vector3i*).value
            {% elsif var_type == "Color" %}
              self.{{var_name.id}} = val_ptr.as(::Godot::Color*).value
            {% elsif var_type == "Rect2" %}
              self.{{var_name.id}} = val_ptr.as(::Godot::Rect2*).value
            {% elsif var_type == "Transform3D" %}
              self.{{var_name.id}} = val_ptr.as(::Godot::Transform3D*).value
            {% elsif var_type == "String" %}
              c_str = val_ptr.as(Pointer(UInt8)*).value
              self.{{var_name.id}} = c_str.null? ? "" : String.new(c_str)
            {% elsif arg.is_a?(TypeDeclaration) && arg.type && arg.type.is_a?(Path) && arg.type.resolve? && (arg.type.resolve < Enum) %}
              self.{{var_name.id}} = {{arg.type.id}}.from_value?(val_ptr.as(Int64*).value) || self.{{var_name.id}}
            {% end %}
        {% end %}
      {% end %}
      else
        {% if is_reopen %}
          previous_def
        {% else %}
          super
        {% end %}
      end
    end

    def _godot_get_property(prop_name : String, ret_ptr : Void*) : Void
      case prop_name
      {% for item in props %}
        {% if item[0] == :prop %}
          {% arg = item[1] %}
          {% var_name = arg.is_a?(Assign) ? arg.target : arg.var %}
          {% var_type = arg.is_a?(Assign) ? "Callable" : (arg.type ? arg.type.stringify.gsub(/^(::)?Godot::/, "") : "Callable") %}
          when "{{var_name.id}}"
            {% if var_type == "Float32" || var_type == "Float64" %}
              ret_ptr.as(Float64*).value = self.{{var_name.id}}.to_f64
            {% elsif var_type == "Int32" || var_type == "Int64" %}
              ret_ptr.as(Int64*).value = self.{{var_name.id}}.to_i64
            {% elsif var_type == "Bool" %}
              ret_ptr.as(UInt8*).value = self.{{var_name.id}} ? 1_u8 : 0_u8
            {% elsif var_type == "Vector2" %}
              ret_ptr.as(::Godot::Vector2*).value = self.{{var_name.id}}
            {% elsif var_type == "Vector2i" %}
              ret_ptr.as(::Godot::Vector2i*).value = self.{{var_name.id}}
            {% elsif var_type == "Vector3" %}
              ret_ptr.as(::Godot::Vector3*).value = self.{{var_name.id}}
            {% elsif var_type == "Vector3i" %}
              ret_ptr.as(::Godot::Vector3i*).value = self.{{var_name.id}}
            {% elsif var_type == "Color" %}
              ret_ptr.as(::Godot::Color*).value = self.{{var_name.id}}
            {% elsif var_type == "Rect2" %}
              ret_ptr.as(::Godot::Rect2*).value = self.{{var_name.id}}
            {% elsif var_type == "Transform3D" %}
              ret_ptr.as(::Godot::Transform3D*).value = self.{{var_name.id}}
            {% elsif var_type == "String" %}
              ret_ptr.as(Pointer(UInt8)*).value = self.{{var_name.id}}.to_unsafe
            {% elsif arg.is_a?(TypeDeclaration) && arg.type && arg.type.is_a?(Path) && arg.type.resolve? && (arg.type.resolve < Enum) %}
              ret_ptr.as(Int64*).value = self.{{var_name.id}}.to_i64
            {% end %}
        {% end %}
      {% end %}
      else
        {% if is_reopen %}
          previous_def
        {% else %}
          super
        {% end %}
      end
    end

    def _godot_call_tool_button(button_name : String) : Void
      case button_name
      {% for tb in tool_buttons %}
      when "{{tb[0].id}}"
        {% if tb[2] == :proc_property %}
          if btn = self.{{tb[0].id}}
            btn.call
          end
        {% else %}
          self.{{tb[0].id}}
        {% end %}
      {% end %}
      else
        {% if is_reopen %}
          previous_def
        {% else %}
          super
        {% end %}
      end
    end

    macro finished
      def self._godot_module_properties : ::Array(::Godot::PropertyInfo)
        props_list = ::Array(::Godot::PropertyInfo).new
        \{% for anc in @type.ancestors %}
          \{% if anc.resolve.methods.map(&.name.stringify).includes?("_godot_module_properties") %}
            props_list.concat(\{{anc.resolve}}._godot_module_properties)
          \{% end %}
        \{% end %}
        props_list
      end

      def self._godot_module_signals : ::Array(::Godot::SignalInfo)
        sigs_list = ::Array(::Godot::SignalInfo).new
        \{% for anc in @type.ancestors %}
          \{% if anc.resolve.methods.map(&.name.stringify).includes?("_godot_module_signals") %}
            sigs_list.concat(\{{anc.resolve}}._godot_module_signals)
          \{% end %}
        \{% end %}
        sigs_list
      end

      def self._godot_module_constants : ::Array(::Godot::ConstantInfo)
        consts_list = ::Array(::Godot::ConstantInfo).new
        \{% for anc in @type.ancestors %}
          \{% if anc.resolve.methods.map(&.name.stringify).includes?("_godot_module_constants") %}
            consts_list.concat(\{{anc.resolve}}._godot_module_constants)
          \{% end %}
        \{% end %}
        consts_list
      end
    end
  end

  # Auto-register this node with full property and signal metadata
  properties_{{class_name}} = Array(::Godot::PropertyInfo).new
  constants_{{class_name}} = Array(::Godot::ConstantInfo).new
  {% for c in class_constants %}
    constants_{{class_name}} << ::Godot::ConstantInfo.new(
      {{c[0]}},
      {{c[1]}},
      {{c[2]}}::{{c[3].id}}.to_i64,
      {{c[4]}}
    )
  {% end %}
  {% for item in props %}
    {% if item[0] == :category %}
      properties_{{class_name}} << ::Godot::PropertyInfo.new(
        {{item[1]}},
        "",
        0,
        0_u32,
        "",
        128_u32
      )
    {% elsif item[0] == :group %}
      properties_{{class_name}} << ::Godot::PropertyInfo.new(
        {{item[1]}},
        "",
        0,
        0_u32,
        {{item[2]}},
        64_u32
      )
    {% elsif item[0] == :subgroup %}
      properties_{{class_name}} << ::Godot::PropertyInfo.new(
        {{item[1]}},
        "",
        0,
        0_u32,
        {{item[2]}},
        256_u32
      )
    {% elsif item[0] == :tool_button %}
      properties_{{class_name}} << ::Godot::PropertyInfo.new(
        "{{item[1].id}}",
        "Callable",
        25,
        39_u32,
        "{{item[2].id}}",
        4_u32
      )
    {% elsif item[0] == :prop %}
      {% arg = item[1] %}
      {% anno = item[2] %}
      {% var_name = arg.is_a?(Assign) ? arg.target : arg.var %}
      {% var_type = arg.is_a?(Assign) ? "Callable" : (arg.type ? arg.type.stringify.gsub(/^(::)?Godot::/, "") : "Callable") %}
      {%
        vtype = 0
        hint = 0
        hint_str = ""
        is_enum = false
        if arg.is_a?(TypeDeclaration) && arg.type && arg.type.is_a?(Path) && arg.type.resolve? && (arg.type.resolve < Enum)
          is_enum = true
          vtype = 2
          hint = 2
          enum_res = arg.type.resolve
          hint_str = enum_res.constants.map { |c| "#{c.id}:#{enum_res.constant(c).id}" }.join(",")
        elsif var_type == "Bool"
          vtype = 1
        elsif var_type == "Int32" || var_type == "Int64"
          vtype = 2
        elsif var_type == "Float32" || var_type == "Float64"
          vtype = 3
        elsif var_type == "String"
          vtype = 4
        elsif var_type == "Vector2"
          vtype = 5
        elsif var_type == "Vector2i"
          vtype = 6
        elsif var_type == "Rect2"
          vtype = 7
        elsif var_type == "Rect2i"
          vtype = 8
        elsif var_type == "Vector3"
          vtype = 9
        elsif var_type == "Vector3i"
          vtype = 10
        elsif var_type == "Transform2D"
          vtype = 11
        elsif var_type == "Vector4"
          vtype = 12
        elsif var_type == "Vector4i"
          vtype = 13
        elsif var_type == "Plane"
          vtype = 14
        elsif var_type == "Quaternion"
          vtype = 15
        elsif var_type == "AABB"
          vtype = 16
        elsif var_type == "Basis"
          vtype = 17
        elsif var_type == "Transform3D"
          vtype = 18
        elsif var_type == "Projection"
          vtype = 19
        elsif var_type == "Color"
          vtype = 20
        elsif var_type == "StringName"
          vtype = 21
        elsif var_type == "NodePath"
          vtype = 22
        elsif var_type == "RID"
          vtype = 23
        elsif var_type == "Callable"
          vtype = 25
        elsif var_type == "Signal"
          vtype = 26
        elsif var_type == "Dictionary"
          vtype = 27
        elsif var_type == "Array"
          vtype = 28
        else
          vtype = 24
        end

        prop_usage = anno ? 6 : 2
      %}
      {% if anno %}
        {% a_name = anno.name.stringify %}
        {% if a_name == "Export" %}
          {% if anno.named_args %}
            {% for key, val in anno.named_args %}
              {% k_str = key.stringify %}
              {% if k_str == "range" %}
                {% hint = 1 %}
                {% b_id = val.begin.id.gsub(/_[a-z0-9]+/, "") %}
                {% e_id = val.end.id.gsub(/_[a-z0-9]+/, "") %}
                {% hint_str = "#{b_id},#{e_id}" %}
              {% elsif k_str == "step" %}
                {% s_id = val.id.gsub(/_[a-z0-9]+/, "") %}
                {% hint_str = "#{hint_str.id},#{s_id}" %}
              {% elsif k_str == "enum" %}
                {% hint = 2 %}
                {% if val.is_a?(ArrayLiteral) %}
                  {% hint_str = val.map(&.id.stringify).join(",") %}
                {% elsif val.is_a?(Path) && val.resolve? && (val.resolve < Enum) %}
                  {% enum_res = val.resolve %}
                  {% hint_str = enum_res.constants.map { |c| "#{c.id}:#{enum_res.constant(c).id}" }.join(",") %}
                  {% if var_type != "String" %}
                    {% vtype = 2 %}
                  {% end %}
                {% else %}
                  {% hint_str = val.id.stringify %}
                {% end %}
              {% elsif k_str == "file" %}
                {% hint = 13 %}
                {% hint_str = val.id.stringify %}
              {% elsif k_str == "file_path" %}
                {% hint = 44 %}
                {% hint_str = val.id.stringify %}
              {% elsif k_str == "dir" %}
                {% hint = 14 %}
              {% elsif k_str == "global_file" %}
                {% hint = 15 %}
                {% hint_str = val.id.stringify %}
              {% elsif k_str == "global_dir" %}
                {% hint = 16 %}
              {% elsif k_str == "multiline" %}
                {% hint = 18 %}
              {% elsif k_str == "placeholder" %}
                {% hint = 20 %}
                {% hint_str = val.id.stringify %}
              {% elsif k_str == "flags" %}
                {% hint = 6 %}
                {% if val.is_a?(ArrayLiteral) %}
                  {% hint_str = val.map(&.id.stringify).join(",") %}
                {% elsif val.is_a?(Path) && val.resolve? && (val.resolve < Enum) %}
                  {% enum_res = val.resolve %}
                  {% valid_consts = enum_res.constants.reject { |c| c.stringify == "None" || c.stringify == "All" } %}
                  {% hint_str = valid_consts.map(&.id.stringify).join(",") %}
                  {% if var_type != "String" %}
                    {% vtype = 2 %}
                  {% end %}
                {% else %}
                  {% hint_str = val.id.stringify %}
                {% end %}
              {% elsif k_str == "flags_2d_render" %}
                {% hint = 7 %}
              {% elsif k_str == "flags_2d_physics" %}
                {% hint = 8 %}
              {% elsif k_str == "flags_2d_navigation" %}
                {% hint = 9 %}
              {% elsif k_str == "flags_3d_render" %}
                {% hint = 10 %}
              {% elsif k_str == "flags_3d_physics" %}
                {% hint = 11 %}
              {% elsif k_str == "flags_3d_navigation" %}
                {% hint = 12 %}
              {% elsif k_str == "flags_avoidance" %}
                {% hint = 37 %}
              {% elsif k_str == "exp_easing" %}
                {% hint = 4 %}
                {% hint_str = val.is_a?(BoolLiteral) ? "" : val.id.stringify %}
              {% elsif k_str == "color_no_alpha" %}
                {% hint = 21 %}
              {% elsif k_str == "node_path" %}
                {% hint = 26 %}
                {%
                  node_path_queue = [] of ASTNode
                  node_path_queue << val
                  extracted_types = [] of StringLiteral
                %}
                {% for step in [1, 2, 3, 4, 5, 6, 7, 8] %}
                  {%
                    if node_path_queue.size > 0
                      next_queue = [] of ASTNode
                      node_path_queue.each do |item|
                        if item.is_a?(Call) && item.name.stringify == "|"
                          next_queue << item.receiver
                          item.args.each { |ca| next_queue << ca }
                        elsif item.is_a?(ArrayLiteral)
                          item.each { |elem| next_queue << elem }
                        elsif item.is_a?(StringLiteral)
                          extracted_types << item.id.stringify
                        elsif item.is_a?(Path)
                          item_name_str = item.stringify.gsub(/^::/, "")
                          if extracted_aliases[item_name_str]
                            extracted_aliases[item_name_str].each do |sub_alias_type|
                              extracted_types << sub_alias_type.gsub(/^(::)?Godot::/, "")
                            end
                          elsif item.resolve? == nil
                            raise "ExportNodePath type '#{item}' does not exist or cannot be resolved"
                          elsif item.resolve.type_vars.size > 0
                            item.resolve.type_vars.each do |tv|
                              extracted_types << tv.stringify.gsub(/^(::)?Godot::/, "")
                            end
                          else
                            resolved_str = item.resolve.stringify
                            resolved_str.gsub(/[()]/, "").split("|").each do |part|
                              extracted_types << part.strip.gsub(/^(::)?Godot::/, "")
                            end
                          end
                        else
                          extracted_types << item.stringify.gsub(/^(::)?Godot::/, "")
                        end
                      end
                      node_path_queue = next_queue
                    end
                  %}
                {% end %}
                {% hint_str = extracted_types.uniq.join(",") %}
              {% elsif k_str == "storage" %}
                {% prop_usage = 2 %}
              {% elsif k_str == "tool_button" %}
                {% hint = 39 %}
                {% vtype = 25 %}
                {% prop_usage = 4 %}
                {% hint_str = val.id.stringify %}
              {% elsif k_str == "hint" %}
                {% hint = val.id.gsub(/_[a-z0-9]+/, "") %}
              {% elsif k_str == "hint_string" %}
                {% hint_str = val.id.stringify %}
              {% elsif k_str == "usage" %}
                {% prop_usage = val.id.gsub(/_[a-z0-9]+/, "") %}
              {% end %}
            {% end %}
          {% end %}
        {% elsif a_name == "ExportRange" %}
          {% hint = 1 %}
          {% step_val = "" %}
          {% if anno.named_args %}
            {% for k, v in anno.named_args %}
              {% if k.stringify == "step" %}
                {% step_val = v.id.gsub(/_[a-z0-9]+/, "") %}
              {% end %}
            {% end %}
          {% end %}
          {% if anno.args[0].is_a?(RangeLiteral) %}
            {% b_id = anno.args[0].begin.id.gsub(/_[a-z0-9]+/, "") %}
            {% e_id = anno.args[0].end.id.gsub(/_[a-z0-9]+/, "") %}
            {% hint_str = "#{b_id},#{e_id}" %}
            {% if !step_val.empty? %}
              {% hint_str = "#{hint_str.id},#{step_val.id}" %}
            {% elsif anno.args.size > 1 %}
              {% s_id = anno.args[1].id.gsub(/_[a-z0-9]+/, "") %}
              {% hint_str = "#{hint_str.id},#{s_id}" %}
            {% end %}
          {% else %}
            {% b_id = anno.args[0].id.gsub(/_[a-z0-9]+/, "") %}
            {% e_id = anno.args[1].id.gsub(/_[a-z0-9]+/, "") %}
            {% hint_str = "#{b_id},#{e_id}" %}
            {% if !step_val.empty? %}
              {% hint_str = "#{hint_str.id},#{step_val.id}" %}
            {% elsif anno.args.size > 2 %}
              {% s_id = anno.args[2].id.gsub(/_[a-z0-9]+/, "") %}
              {% hint_str = "#{hint_str.id},#{s_id}" %}
            {% end %}
          {% end %}
        {% elsif a_name == "ExportEnum" %}
          {% hint = 2 %}
          {% if anno.args.size > 0 && anno.args[0].is_a?(Path) && anno.args[0].resolve? && (anno.args[0].resolve < Enum) %}
            {% enum_res = anno.args[0].resolve %}
            {% hint_str = enum_res.constants.map { |c| "#{c.id}:#{enum_res.constant(c).id}" }.join(",") %}
            {% if var_type != "String" %}
              {% vtype = 2 %}
            {% end %}
          {% elsif anno.args.size > 0 %}
            {% hint_str = anno.args.map(&.id.stringify).join(",") %}
          {% end %}
        {% elsif a_name == "ExportFile" %}
          {% hint = 13 %}
          {% hint_str = anno.args.size > 0 ? anno.args[0].id.stringify : "" %}
        {% elsif a_name == "ExportFilePath" %}
          {% hint = 44 %}
          {% hint_str = anno.args.size > 0 ? anno.args[0].id.stringify : "" %}
        {% elsif a_name == "ExportDir" %}
          {% hint = 14 %}
        {% elsif a_name == "ExportGlobalFile" %}
          {% hint = 15 %}
          {% hint_str = anno.args.size > 0 ? anno.args[0].id.stringify : "" %}
        {% elsif a_name == "ExportGlobalDir" %}
          {% hint = 16 %}
        {% elsif a_name == "ExportMultiline" %}
          {% hint = 18 %}
        {% elsif a_name == "ExportPlaceholder" %}
          {% hint = 20 %}
          {% hint_str = anno.args[0].id.stringify %}
        {% elsif a_name == "ExportFlags" %}
          {% hint = 6 %}
          {% if anno.args.size > 0 && anno.args[0].is_a?(Path) && anno.args[0].resolve? && (anno.args[0].resolve < Enum) %}
            {% enum_res = anno.args[0].resolve %}
            {% valid_consts = enum_res.constants.reject { |c| c.stringify == "None" || c.stringify == "All" } %}
            {% hint_str = valid_consts.map(&.id.stringify).join(",") %}
            {% if var_type != "String" %}
              {% vtype = 2 %}
            {% end %}
          {% elsif anno.args.size > 0 %}
            {% hint_str = anno.args.map(&.id.stringify).join(",") %}
          {% end %}
        {% elsif a_name == "ExportFlags2DRender" %}
          {% hint = 7 %}
        {% elsif a_name == "ExportFlags2DPhysics" %}
          {% hint = 8 %}
        {% elsif a_name == "ExportFlags2DNavigation" %}
          {% hint = 9 %}
        {% elsif a_name == "ExportFlags3DRender" %}
          {% hint = 10 %}
        {% elsif a_name == "ExportFlags3DPhysics" %}
          {% hint = 11 %}
        {% elsif a_name == "ExportFlags3DNavigation" %}
          {% hint = 12 %}
        {% elsif a_name == "ExportFlagsAvoidance" %}
          {% hint = 37 %}
        {% elsif a_name == "ExportExpEasing" %}
          {% hint = 4 %}
          {% hint_str = anno.args.size > 0 ? anno.args[0].id.stringify : "" %}
        {% elsif a_name == "ExportColorNoAlpha" %}
          {% hint = 21 %}
        {% elsif a_name == "ExportNodePath" %}
          {% hint = 26 %}
          {%
            node_path_queue = [] of ASTNode
            anno.args.each { |a| node_path_queue << a }
            extracted_types = [] of StringLiteral
          %}
          {% for step in [1, 2, 3, 4, 5, 6, 7, 8] %}
            {%
              if node_path_queue.size > 0
                next_queue = [] of ASTNode
                node_path_queue.each do |item|
                  if item.is_a?(Call) && item.name.stringify == "|"
                    next_queue << item.receiver
                    item.args.each { |ca| next_queue << ca }
                  elsif item.is_a?(ArrayLiteral)
                    item.each { |elem| next_queue << elem }
                  elsif item.is_a?(StringLiteral)
                    extracted_types << item.id.stringify
                  elsif item.is_a?(Path)
                    item_name_str = item.stringify.gsub(/^::/, "")
                    if extracted_aliases[item_name_str]
                      extracted_aliases[item_name_str].each do |sub_alias_type|
                        extracted_types << sub_alias_type.gsub(/^(::)?Godot::/, "")
                      end
                    elsif item.resolve? == nil
                      raise "ExportNodePath type '#{item}' does not exist or cannot be resolved"
                    elsif item.resolve.type_vars.size > 0
                      item.resolve.type_vars.each do |tv|
                        extracted_types << tv.stringify.gsub(/^(::)?Godot::/, "")
                      end
                    else
                      resolved_str = item.resolve.stringify
                      resolved_str.gsub(/[()]/, "").split("|").each do |part|
                        extracted_types << part.strip.gsub(/^(::)?Godot::/, "")
                      end
                    end
                  else
                    extracted_types << item.stringify.gsub(/^(::)?Godot::/, "")
                  end
                end
                node_path_queue = next_queue
              end
            %}
          {% end %}
          {% hint_str = extracted_types.uniq.join(",") %}
        {% elsif a_name == "ExportStorage" %}
          {% prop_usage = 2 %}
        {% elsif a_name == "ExportToolButton" %}
          {% hint = 39 %}
          {% vtype = 25 %}
          {% prop_usage = 4 %}
          {%
            tb_label = ""
            tb_icon = ""
            if anno.args.size > 0
              tb_label = (anno.args[0].is_a?(StringLiteral) ? anno.args[0] : anno.args[0].id.stringify).gsub(/^\"|\"$/, "")
            end
            if anno.args.size > 1
              tb_icon = (anno.args[1].is_a?(StringLiteral) ? anno.args[1] : anno.args[1].id.stringify).gsub(/^\"|\"$/, "")
            end
          %}
          {% if anno.named_args %}
            {% for key, val in anno.named_args %}
              {% if key.stringify == "icon" %}
                {% tb_icon = (val.is_a?(StringLiteral) ? val : val.id.stringify).gsub(/^\"|\"$/, "") %}
              {% elsif key.stringify == "text" || key.stringify == "label" %}
                {% tb_label = (val.is_a?(StringLiteral) ? val : val.id.stringify).gsub(/^\"|\"$/, "") %}
              {% end %}
            {% end %}
          {% end %}
          {%
            if tb_label.empty?
              tb_label = var_name.stringify.split("_").map(&.capitalize).join(" ")
            end
            hint_str = tb_icon.empty? ? tb_label : "#{tb_label.id},#{tb_icon.id}"
          %}
        {% elsif a_name == "ExportCustom" %}
          {% if anno.args.size > 0 %}
            {% hint = anno.args[0].id.gsub(/_[a-z0-9]+/, "") %}
            {% hint_str = anno.args.size > 1 ? anno.args[1].id.stringify : "" %}
            {% if anno.args.size > 2 %}
              {% prop_usage = anno.args[2].id.gsub(/_[a-z0-9]+/, "") %}
            {% end %}
          {% elsif anno.named_args %}
            {% for k, v in anno.named_args %}
              {% if k.stringify == "hint" %}
                {% hint = v.id.gsub(/_[a-z0-9]+/, "") %}
              {% elsif k.stringify == "hint_string" %}
                {% hint_str = v.id.stringify %}
              {% elsif k.stringify == "usage" %}
                {% prop_usage = v.id.gsub(/_[a-z0-9]+/, "") %}
              {% end %}
            {% end %}
          {% end %}
        {% end %}
      {% end %}
      properties_{{class_name}} << ::Godot::PropertyInfo.new(
        "{{var_name.id}}",
        "{{hint == 39 ? "Callable".id : var_type.id}}",
        {{vtype}},
        {{hint || 0}}_u32,
        "{{hint_str.id}}",
        {{prop_usage || 6}}_u32
      )
    {% end %}
  {% end %}

  signals_{{class_name}} = Array(::Godot::SignalInfo).new
  {% for sig_entry in sigs %}
    {% sig = sig_entry[0] %}
    {% sig_doc = sig_entry[1] %}
    {% if sig.is_a?(Call) %}
      {% sig_name = sig.name %}
      {% sig_args = sig.args %}
    {% else %}
      {% sig_name = sig %}
      {% sig_args = [] of Nil %}
    {% end %}

    args_{{sig_name.id}} = Array(::Godot::SignalArgInfo).new
    {% for a in sig_args %}
      {% if a.is_a?(TypeDeclaration) %}
        {% atype = a.type.stringify %}
        {%
          avtype = 0
          if atype == "Float32" || atype == "Float64"
            avtype = 3
          elsif atype == "Int32" || atype == "Int64"
            avtype = 2
          elsif atype == "Bool"
            avtype = 1
          elsif atype == "String"
            avtype = 4
          end
        %}
        args_{{sig_name.id}} << ::Godot::SignalArgInfo.new("{{a.var.id}}", {{avtype}})
      {% else %}
        args_{{sig_name.id}} << ::Godot::SignalArgInfo.new("{{a.id}}", 0)
      {% end %}
    {% end %}
    signals_{{class_name}} << ::Godot::SignalInfo.new("{{sig_name.id}}", args_{{sig_name.id}})
  {% end %}

  properties_{{class_name}}.concat({{class_name}}._godot_module_properties)
  constants_{{class_name}}.concat({{class_name}}._godot_module_constants)
  signals_{{class_name}}.concat({{class_name}}._godot_module_signals)

  {% if script_path_override && !script_path_override.empty? %}
    script_path_{{class_name}} = {{script_path_override}}
  {% else %}
    script_path_{{class_name}} = ::Godot.to_godot_res_path({{src_file}})
  {% end %}

  ::Godot::ClassRegistry.register(
    ::Godot::ClassRegistry::Entry.new(
      "{{class_name}}",
      {{base_godot_name}},
      ->(godot_ptr : Void*) {
        _inst_{{class_name.id}} = {{class_name}}.new
        _inst_{{class_name.id}}.pointer = godot_ptr
        _inst_{{class_name.id}}.as(::Godot::Object)
      },
      {{is_tool_class}},
      {{has_ready}} || {{class_name}}._godot_has_virtual_method("_ready"),
      {{has_process}} || {{class_name}}._godot_has_virtual_method("_process"),
      {{has_physics_process}} || {{class_name}}._godot_has_virtual_method("_physics_process"),
      {{has_enter_tree}} || {{class_name}}._godot_has_virtual_method("_enter_tree"),
      {{has_exit_tree}} || {{class_name}}._godot_has_virtual_method("_exit_tree"),
      {{has_input}},
      {{has_unhandled_input}},
      {{has_unhandled_key_input}},
      {{has_shortcut_input}},
      {{has_gui_input}},
      properties_{{class_name}},
      signals_{{class_name}},
      {{class_icon_path}},
      {{is_abstract_class}},
      {% if rpc_methods.size > 0 %}
      [
        {% for r in rpc_methods %}
          {name: {{r[0]}}, rpc_mode: {{r[1]}}, transfer_mode: {{r[2]}}, call_local: {{r[3]}}, channel: {{r[4]}}},
        {% end %}
      ],
      {% else %}
        ([] of NamedTuple(name: String, rpc_mode: Int32, transfer_mode: Int32, call_local: Bool, channel: Int32)),
      {% end %}
      has_virtual_proc: ->(m : String) { {{class_name}}._godot_has_virtual_method(m) },
      constants: constants_{{class_name}},
      script_path: script_path_{{class_name}}
    )
  )

  # Auto-register Godot Editor documentation XML
  {% unless flag?(:release) || flag?(:no_doc) || flag?(:no_editor_docs) %}
  xml_{{class_name}} = String.build do |io|
    io << "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n"
    io << "<class name=\"{{class_name.id}}\" inherits=\"" << {{base_godot_name}} << "\">\n"
    io << "  <brief_description>\n"
    {% if class_doc != "" %}
      io << "    " << ::Godot::XML.escape({{class_doc}}) << "\n"
    {% end %}
    io << "  </brief_description>\n"
    io << "  <description>\n"
    {% if class_doc != "" %}
      io << "    " << ::Godot::XML.escape({{class_doc}}) << "\n"
    {% end %}
    io << "  </description>\n"
    io << "  <tutorials>\n  </tutorials>\n"
    io << "  <members>\n"
    {% for item in props %}
      {% if item[0] == :prop %}
        {% arg = item[1] %}
        {% p_doc = item[3] %}
        {% var_name = arg.is_a?(Assign) ? arg.target : arg.var %}
        {% var_type = arg.is_a?(Assign) ? "Callable" : (arg.type ? arg.type.stringify.gsub(/^(::)?Godot::/, "") : "Callable") %}
        {%
          gtype = "Variant"
          if var_type == "Float32" || var_type == "Float64"
            gtype = "float"
          elsif var_type == "Int32" || var_type == "Int64"
            gtype = "int"
          elsif var_type == "Bool"
            gtype = "bool"
          elsif var_type == "String"
            gtype = "String"
          elsif var_type == "Vector2"
            gtype = "Vector2"
          elsif var_type == "Vector3"
            gtype = "Vector3"
          elsif var_type == "Color"
            gtype = "Color"
          elsif var_type == "NodePath"
            gtype = "NodePath"
          elsif var_type == "Callable"
            gtype = "Callable"
          end
        %}
        io << "    <member name=\"{{var_name.id}}\" type=\"{{gtype.id}}\" setter=\"\" getter=\"\">"
        {% if p_doc && p_doc != "" %}
          io << ::Godot::XML.escape({{p_doc}})
        {% end %}
        io << "</member>\n"
      {% end %}
    {% end %}
    io << "  </members>\n"
    io << "  <signals>\n"
    {% for sig_entry in sigs %}
      {% sig = sig_entry[0] %}
      {% sig_doc = sig_entry[1] %}
      {% if sig.is_a?(Call) %}
        {% sig_name = sig.name %}
        {% sig_args = sig.args %}
      {% else %}
        {% sig_name = sig %}
        {% sig_args = [] of Nil %}
      {% end %}
      io << "    <signal name=\"{{sig_name.id}}\">\n"
      io << "      <description>"
      {% if sig_doc && sig_doc != "" %}
        io << ::Godot::XML.escape({{sig_doc}})
      {% end %}
      io << "</description>\n"
      {% for a, a_idx in sig_args %}
        {% if a.is_a?(TypeDeclaration) %}
          io << "      <param index=\"" << {{a_idx}} << "\" name=\"{{a.var.id}}\" type=\"{{a.type.id}}\" />\n"
        {% end %}
      {% end %}
      io << "    </signal>\n"
      {% end %}
    io << "  </signals>\n"
    {% if methods_doc.size > 0 %}
    io << "  <methods>\n"
    {% for m_entry in methods_doc %}
      {% m_name = m_entry[0] %}
      {% m_args = m_entry[1] %}
      {% m_ret = m_entry[2] %}
      {% m_doc = m_entry[3] %}
      {%
        ret_type_str = m_ret ? m_ret.stringify : "void"
        g_ret = "void"
        if ret_type_str == "Void" || ret_type_str == "Nil" || ret_type_str == "void"
          g_ret = "void"
        elsif ret_type_str == "Float32" || ret_type_str == "Float64"
          g_ret = "float"
        elsif ret_type_str.starts_with?("Int") || ret_type_str.starts_with?("UInt")
          g_ret = "int"
        elsif ret_type_str == "Bool"
          g_ret = "bool"
        elsif ret_type_str == "String"
          g_ret = "String"
        elsif ret_type_str == "Vector2"
          g_ret = "Vector2"
        elsif ret_type_str == "Vector3"
          g_ret = "Vector3"
        elsif ret_type_str == "Color"
          g_ret = "Color"
        elsif ret_type_str == "NodePath"
          g_ret = "NodePath"
        elsif !ret_type_str.empty?
          g_ret = ret_type_str
        end
      %}
      io << "    <method name=\"{{m_name.id}}\">\n"
      io << "      <return type=\"" << {{g_ret}} << "\" />\n"
      {% for a, a_idx in m_args %}
        {%
          a_type_str = a.restriction ? a.restriction.stringify : "Variant"
          a_gtype = "Variant"
          if a_type_str == "Float32" || a_type_str == "Float64"
            a_gtype = "float"
          elsif a_type_str.starts_with?("Int") || a_type_str.starts_with?("UInt")
            a_gtype = "int"
          elsif a_type_str == "Bool"
            a_gtype = "bool"
          elsif a_type_str == "String"
            a_gtype = "String"
          elsif a_type_str == "Vector2"
            a_gtype = "Vector2"
          elsif a_type_str == "Vector3"
            a_gtype = "Vector3"
          elsif a_type_str == "Color"
            a_gtype = "Color"
          elsif a_type_str == "NodePath"
            a_gtype = "NodePath"
          elsif !a_type_str.empty?
            a_gtype = a_type_str
          end
        %}
        {% if a.default_value %}
          io << "      <param index=\"" << {{a_idx}} << "\" name=\"{{a.name.id}}\" type=\"" << {{a_gtype}} << "\" default=\"" << ::Godot::XML.escape({{a.default_value.id.stringify}}) << "\" />\n"
        {% else %}
          io << "      <param index=\"" << {{a_idx}} << "\" name=\"{{a.name.id}}\" type=\"" << {{a_gtype}} << "\" />\n"
        {% end %}
      {% end %}
      io << "      <description>"
      {% if m_doc && m_doc != "" %}
        io << ::Godot::XML.escape({{m_doc}})
      {% end %}
      io << "</description>\n"
      io << "    </method>\n"
    {% end %}
    io << "  </methods>\n"
    {% end %}
    io << "</class>"
  end
    ::Godot::EditorDocRegistry.register(xml_{{class_name}})
  {% end %}
end

# Declares a custom Godot Resource class registered with ClassDB and EditorHelp.
# Supports @[Export] properties, custom signals, and serialization to `.tres`.
#
# ```
# resource ItemData < Resource do
#   @[Export]
#   property item_name : String = "Health Potion"
#
# Declares a custom Resource subclass registered with ClassDB.
# Defaults to inheriting `Resource` when no parent is specified.
# Can be called with or without a block (e.g. `resource MyItem`).
#
# ```
# resource CustomPotion do
#   @[Export]
#   property item_name : String = "Health Potion"
#
#   @[Export]
#   property value : Int32 = 50
# end
#
# resource ShortItem
# ```
macro resource(decl)
  resource {{decl}} do
  end
end

macro resource(decl, &block)
  {% if decl.is_a?(Call) && decl.name == "<" %}
    node {{decl}} do
      {{yield}}
    end
  {% else %}
    {% if decl.resolve? %}
      node {{decl}} do
        {{yield}}
      end
    {% else %}
      node {{decl}} < Resource do
        {{yield}}
      end
    {% end %}
  {% end %}
end

# Declares a custom RefCounted or generic Godot engine class registered with ClassDB.
# Defaults to inheriting `RefCounted` when no parent is specified.
# Can be called with or without a block (e.g. `gdclass MyState`).
#
# ```
# gdclass StateMachine < RefCounted do
#   @[Export]
#   property current_state : String = "idle"
# end
#
# gdclass SimpleState
# ```
macro gdclass(decl)
  gdclass {{decl}} do
  end
end

macro gdclass(decl, &block)
  {% if decl.is_a?(Call) && decl.name == "<" %}
    node {{decl}} do
      {{yield}}
    end
  {% else %}
    {% if decl.resolve? %}
      node {{decl}} do
        {{yield}}
      end
    {% else %}
      node {{decl}} < RefCounted do
        {{yield}}
      end
    {% end %}
  {% end %}
end

# Declares a reusable Godot module or mixin registered with ClassDB metadata.
# Can declare properties (with @[Export]), signals, lifecycle hooks, and interface methods.
# When included into a `node`, `gdclass`, or `resource` via `include`, its properties
# and signals are automatically registered with ClassDB and dispatched via the GDExtension bridge.
#
# ### Examples:
# ```crystal
# gmodule Damageable do
#   signal health_changed(current : Int32, max : Int32)
#   signal died
#
#   @[Export(range: 0..100)]
#   property health : Int32 = 100
#
#   @[Export]
#   property max_health : Int32 = 100
#
#   def take_damage(amount : Int32) : Void
#     self.health = Math.max(0, self.health - amount)
#     emit(health_changed, self.health, self.max_health)
#     emit(died) if self.health == 0
#   end
# end
#
# node Player < CharacterBody2D do
#   include Damageable
# end
# ```
macro gmodule(decl)
  gmodule {{decl}} do
  end
end

macro gmodule(decl, &block)
  {% if decl.is_a?(Call) && decl.name == "<" %}
    {% module_name = decl.receiver %}
    {% parent_module = decl.args[0] %}
  {% else %}
    {% module_name = decl %}
    {% parent_module = nil %}
  {% end %}

  {%
    props = [] of Nil
    sigs = [] of Nil
    tool_buttons = [] of Nil
    rpc_methods = [] of Nil
    class_constants = [] of Nil
    virtual_methods = [] of Nil
    user_methods = [] of Nil

    raw_stmts = if block.is_a?(Nop)
                  [] of Nil
                elsif block.body.is_a?(Expressions)
                  block.body.expressions
                elsif block.body.is_a?(Nop)
                  [] of Nil
                else
                  [block.body]
                end

    stmts_items = [] of Nil
    raw_stmts.each do |s|
      if s.is_a?(Call) && s.name.stringify == "export_category" && s.block && !s.block.is_a?(Nop)
        cat_name = s.args[0].is_a?(StringLiteral) ? s.args[0] : s.args[0].id.stringify
        stmts_items << {:category_start, cat_name}
        inner_cat = s.block.body.is_a?(Expressions) ? s.block.body.expressions : (s.block.body.is_a?(Nop) ? [] of Nil : [s.block.body])
        inner_cat.each do |s2|
          stmts_items << {:stmt, s2}
        end
      elsif s.is_a?(Call) && s.name.stringify == "export_group" && s.block && !s.block.is_a?(Nop)
        grp_name = s.args[0].is_a?(StringLiteral) ? s.args[0] : s.args[0].id.stringify
        pfx = s.args.size > 1 ? (s.args[1].is_a?(StringLiteral) ? s.args[1] : s.args[1].id.stringify) : ""
        stmts_items << {:group_start, grp_name, pfx}
        inner_grp = s.block.body.is_a?(Expressions) ? s.block.body.expressions : (s.block.body.is_a?(Nop) ? [] of Nil : [s.block.body])
        inner_grp.each do |s2|
          stmts_items << {:stmt, s2}
        end
        stmts_items << {:group_end}
      else
        stmts_items << {:stmt, s}
      end
    end

    last_anno = nil
    stmts_items.each do |item_entry|
      if item_entry[0] == :category_start
        props << {:category, item_entry[1], ""}
      elsif item_entry[0] == :group_start
        props << {:group, item_entry[1], item_entry[2]}
      elsif item_entry[0] == :group_end
        props << {:group, "", ""}
      elsif item_entry[0] == :stmt
        stmt = item_entry[1]
        if stmt.class_name.id == "Annotation"
          anno_name = stmt.name.names.last.stringify
          if anno_name == "ExportCategory"
            cat_name = stmt.args[0].is_a?(StringLiteral) ? stmt.args[0] : stmt.args[0].id.stringify
            props << {:category, cat_name, ""}
          elsif anno_name == "ExportGroup"
            grp_name = stmt.args[0].is_a?(StringLiteral) ? stmt.args[0] : stmt.args[0].id.stringify
            pfx = stmt.args.size > 1 ? (stmt.args[1].is_a?(StringLiteral) ? stmt.args[1] : stmt.args[1].id.stringify) : ""
            props << {:group, grp_name, pfx}
            last_anno = stmt
          elsif anno_name == "WarningIgnore" || anno_name == "WarningIgnoreStart" || anno_name == "WarningIgnoreRestore"
            # no-op
          else
            last_anno = stmt
          end
        elsif stmt.is_a?(Def) && (stmt.receiver.is_a?(Nop) || !stmt.receiver)
          m_name_str = stmt.name.stringify
          if m_name_str.starts_with?("_")
            virtual_methods << m_name_str
          else
            user_methods << stmt.name
          end
          if last_anno && last_anno.name.stringify == "ExportToolButton"
            tb_label = last_anno.args.size > 0 ? (last_anno.args[0].is_a?(StringLiteral) ? last_anno.args[0] : last_anno.args[0].id.stringify).gsub(/^\"|\"$/, "") : ""
            tb_icon = last_anno.args.size > 1 ? (last_anno.args[1].is_a?(StringLiteral) ? last_anno.args[1] : last_anno.args[1].id.stringify).gsub(/^\"|\"$/, "") : ""
            if tb_label.empty?
              tb_label = stmt.name.stringify.split("_").map(&.capitalize).join(" ")
            end
            tb_hint_str = tb_icon.empty? ? tb_label : "#{tb_label.id},#{tb_icon.id}"
            tool_buttons << {stmt.name, tb_hint_str, :method}
            props << {:tool_button, stmt.name, tb_hint_str}
          end
          last_anno = nil
        elsif stmt.is_a?(Call) && stmt.name.id == "property"
          p_arg = stmt.args[0]
          p_type = p_arg.is_a?(Assign) ? nil : p_arg.type
          enum_target = nil
          if p_type && p_type.is_a?(Path) && p_type.resolve? && (p_type.resolve < Enum)
            enum_target = p_type.resolve
          elsif last_anno && (last_anno.name.stringify == "ExportEnum" || last_anno.name.stringify == "ExportFlags") && last_anno.args.size > 0 && last_anno.args[0].is_a?(Path) && last_anno.args[0].resolve? && (last_anno.args[0].resolve < Enum)
            enum_target = last_anno.args[0].resolve
          end
          if enum_target
            is_flags = (last_anno && last_anno.name.stringify == "ExportFlags") || enum_target.annotation(Flags) || enum_target.annotation(::Flags)
            enum_target.constants.each do |c_item|
              if !is_flags || (c_item.stringify != "None" && c_item.stringify != "All")
                class_constants << {enum_target.name.stringify, c_item.stringify, enum_target.name, c_item, is_flags}
              end
            end
          end
          props << {:prop, stmt.args[0], last_anno, ""}
          last_anno = nil
        elsif stmt.is_a?(Call) && stmt.name.id == "signal"
          sigs << {stmt.args[0], ""}
          last_anno = nil
        else
          last_anno = nil
        end
      end
    end
  %}

  module {{module_name}}
    {% if parent_module %}
      include {{parent_module}}
    {% end %}

    def self._godot_module_properties : ::Array(::Godot::PropertyInfo)
      properties_{{module_name.id}} = ::Array(::Godot::PropertyInfo).new
      {% for item in props %}
        {% if item[0] == :category %}
          properties_{{module_name.id}} << ::Godot::PropertyInfo.new(
            {{item[1]}}, "", 0, 0_u32, "", 128_u32
          )
        {% elsif item[0] == :group %}
          properties_{{module_name.id}} << ::Godot::PropertyInfo.new(
            {{item[1]}}, "", 0, 0_u32, {{item[2]}}, 64_u32
          )
        {% elsif item[0] == :subgroup %}
          properties_{{module_name.id}} << ::Godot::PropertyInfo.new(
            {{item[1]}}, "", 0, 0_u32, {{item[2]}}, 256_u32
          )
        {% elsif item[0] == :tool_button %}
          properties_{{module_name.id}} << ::Godot::PropertyInfo.new(
            "{{item[1].id}}", "Callable", 25, 39_u32, "{{item[2].id}}", 4_u32
          )
        {% elsif item[0] == :prop %}
          {% arg = item[1] %}
          {% anno = item[2] %}
          {% var_name = arg.is_a?(Assign) ? arg.target : arg.var %}
          {% var_type = arg.is_a?(Assign) ? "Callable" : (arg.type ? arg.type.stringify.gsub(/^(::)?Godot::/, "") : "Callable") %}
          {%
            vtype = 0
            hint = 0
            hint_str = ""
            is_enum = false
            if arg.is_a?(TypeDeclaration) && arg.type && arg.type.is_a?(Path) && arg.type.resolve? && (arg.type.resolve < Enum)
              is_enum = true
              vtype = 2
              hint = 2
              enum_res = arg.type.resolve
              hint_str = enum_res.constants.map { |c| "#{c.id}:#{enum_res.constant(c).id}" }.join(",")
            elsif var_type == "Bool"
              vtype = 1
            elsif var_type == "Int32" || var_type == "Int64"
              vtype = 2
            elsif var_type == "Float32" || var_type == "Float64"
              vtype = 3
            elsif var_type == "String"
              vtype = 4
            elsif var_type == "Vector2"
              vtype = 5
            elsif var_type == "Vector2i"
              vtype = 6
            elsif var_type == "Rect2"
              vtype = 7
            elsif var_type == "Rect2i"
              vtype = 8
            elsif var_type == "Vector3"
              vtype = 9
            elsif var_type == "Vector3i"
              vtype = 10
            elsif var_type == "Transform2D"
              vtype = 11
            elsif var_type == "Vector4"
              vtype = 12
            elsif var_type == "Vector4i"
              vtype = 13
            elsif var_type == "Plane"
              vtype = 14
            elsif var_type == "Quaternion"
              vtype = 15
            elsif var_type == "AABB"
              vtype = 16
            elsif var_type == "Basis"
              vtype = 17
            elsif var_type == "Transform3D"
              vtype = 18
            elsif var_type == "Projection"
              vtype = 19
            elsif var_type == "Color"
              vtype = 20
            elsif var_type == "StringName"
              vtype = 21
            elsif var_type == "NodePath"
              vtype = 22
            elsif var_type == "RID"
              vtype = 23
            elsif var_type == "Callable"
              vtype = 25
            elsif var_type == "Signal"
              vtype = 26
            elsif var_type == "Dictionary"
              vtype = 27
            elsif var_type == "Array"
              vtype = 28
            else
              vtype = 24
            end

            prop_usage = anno ? 6 : 2
          %}
          {% if anno %}
            {% a_name = anno.name.stringify %}
            {% if a_name == "Export" %}
              {% if anno.named_args %}
                {% for key, val in anno.named_args %}
                  {% k_str = key.stringify %}
                  {% if k_str == "range" %}
                    {% hint = 1 %}
                    {% b_id = val.begin.id.gsub(/_[a-z0-9]+/, "") %}
                    {% e_id = val.end.id.gsub(/_[a-z0-9]+/, "") %}
                    {% hint_str = "#{b_id},#{e_id}" %}
                  {% elsif k_str == "step" %}
                    {% s_id = val.id.gsub(/_[a-z0-9]+/, "") %}
                    {% hint_str = "#{hint_str.id},#{s_id}" %}
                  {% elsif k_str == "enum" %}
                    {% hint = 2 %}
                    {% if val.is_a?(ArrayLiteral) %}
                      {% hint_str = val.map(&.id.stringify).join(",") %}
                    {% elsif val.is_a?(Path) && val.resolve? && (val.resolve < Enum) %}
                      {% enum_res = val.resolve %}
                      {% hint_str = enum_res.constants.map { |c| "#{c.id}:#{enum_res.constant(c).id}" }.join(",") %}
                      {% if var_type != "String" %}
                        {% vtype = 2 %}
                      {% end %}
                    {% end %}
                  {% end %}
                {% end %}
              {% end %}
            {% elsif a_name == "ExportRange" %}
              {% hint = 1 %}
              {% if anno.named_args %}
                {% for k, v in anno.named_args %}
                  {% if k.stringify == "range" %}
                    {% b_id = v.begin.id.gsub(/_[a-z0-9]+/, "") %}
                    {% e_id = v.end.id.gsub(/_[a-z0-9]+/, "") %}
                    {% hint_str = "#{b_id},#{e_id}" %}
                  {% elsif k.stringify == "step" %}
                    {% s_id = v.id.gsub(/_[a-z0-9]+/, "") %}
                    {% hint_str = "#{hint_str.id},#{s_id}" %}
                  {% end %}
                {% end %}
              {% elsif anno.args.size > 1 %}
                {% b_id = anno.args[0].id.gsub(/_[a-z0-9]+/, "") %}
                {% e_id = anno.args[1].id.gsub(/_[a-z0-9]+/, "") %}
                {% hint_str = "#{b_id},#{e_id}" %}
                {% if anno.args.size > 2 %}
                  {% s_id = anno.args[2].id.gsub(/_[a-z0-9]+/, "") %}
                  {% hint_str = "#{hint_str.id},#{s_id}" %}
                {% end %}
              {% end %}
            {% elsif a_name == "ExportEnum" %}
              {% hint = 2 %}
              {% if anno.args.size > 0 && anno.args[0].is_a?(Path) && anno.args[0].resolve? && (anno.args[0].resolve < Enum) %}
                {% enum_res = anno.args[0].resolve %}
                {% hint_str = enum_res.constants.map { |c| "#{c.id}:#{enum_res.constant(c).id}" }.join(",") %}
                {% if var_type != "String" %}
                  {% vtype = 2 %}
                {% end %}
              {% elsif anno.args.size > 0 %}
                {% hint_str = anno.args.map(&.id.stringify).join(",") %}
              {% end %}
            {% end %}
          {% end %}
          properties_{{module_name.id}} << ::Godot::PropertyInfo.new(
            "{{var_name.id}}",
            "{{hint == 39 ? "Callable".id : var_type.id}}",
            {{vtype}},
            {{hint || 0}}_u32,
            "{{hint_str.id}}",
            {{prop_usage || 6}}_u32
          )
        {% end %}
      {% end %}
      {% if parent_module %}
        properties_{{module_name.id}}.concat({{parent_module}}._godot_module_properties)
      {% end %}
      properties_{{module_name.id}}
    end

    def _godot_module_properties : ::Array(::Godot::PropertyInfo)
      {{module_name}}._godot_module_properties
    end

    def self._godot_module_signals : ::Array(::Godot::SignalInfo)
      signals_{{module_name.id}} = ::Array(::Godot::SignalInfo).new
      {% for sig_entry in sigs %}
        {% sig = sig_entry[0] %}
        {% if sig.is_a?(Call) %}
          {% sig_name = sig.name %}
          {% sig_args = sig.args %}
        {% else %}
          {% sig_name = sig %}
          {% sig_args = [] of Nil %}
        {% end %}
        args_{{sig_name.id}} = ::Array(::Godot::SignalArgInfo).new
        {% for a in sig_args %}
          {% if a.is_a?(TypeDeclaration) %}
            {% atype = a.type.stringify %}
            {%
              avtype = 0
              if atype == "Float32" || atype == "Float64"
                avtype = 3
              elsif atype == "Int32" || atype == "Int64"
                avtype = 2
              elsif atype == "Bool"
                avtype = 1
              elsif atype == "String"
                avtype = 4
              end
            %}
            args_{{sig_name.id}} << ::Godot::SignalArgInfo.new("{{a.var.id}}", {{avtype}})
          {% else %}
            args_{{sig_name.id}} << ::Godot::SignalArgInfo.new("{{a.id}}", 0)
          {% end %}
        {% end %}
        signals_{{module_name.id}} << ::Godot::SignalInfo.new("{{sig_name.id}}", args_{{sig_name.id}})
      {% end %}
      {% if parent_module %}
        signals_{{module_name.id}}.concat({{parent_module}}._godot_module_signals)
      {% end %}
      signals_{{module_name.id}}
    end

    def _godot_module_signals : ::Array(::Godot::SignalInfo)
      {{module_name}}._godot_module_signals
    end

    def self._godot_module_constants : ::Array(::Godot::ConstantInfo)
      constants_{{module_name.id}} = ::Array(::Godot::ConstantInfo).new
      {% for c in class_constants %}
        constants_{{module_name.id}} << ::Godot::ConstantInfo.new(
          {{c[0]}},
          {{c[1]}},
          {{c[2]}}::{{c[3].id}}.to_i64,
          {{c[4]}}
        )
      {% end %}
      {% if parent_module %}
        constants_{{module_name.id}}.concat({{parent_module}}._godot_module_constants)
      {% end %}
      constants_{{module_name.id}}
    end

    def _godot_module_constants : ::Array(::Godot::ConstantInfo)
      {{module_name}}._godot_module_constants
    end

    def self._godot_has_virtual_method(method_name : String) : Bool
      norm = method_name.starts_with?('_') ? method_name : "_#{method_name}"
      case norm
      {% for vm in virtual_methods %}
      when {{vm.stringify}}
        return true
      {% end %}
      else
        {% if parent_module %}
          {{parent_module}}._godot_has_virtual_method(method_name) rescue false
        {% else %}
          false
        {% end %}
      end
    end

    def _godot_set_property(prop_name : String, val_ptr : Void*) : Void
      case prop_name
      {% for item in props %}
        {% if item[0] == :prop %}
          {% arg = item[1] %}
          {% var_name = arg.is_a?(Assign) ? arg.target : arg.var %}
          {% var_type = arg.is_a?(Assign) ? "Callable" : (arg.type ? arg.type.stringify.gsub(/^(::)?Godot::/, "") : "Callable") %}
          when "{{var_name.id}}"
            {% if var_type == "Float32" %}
              self.{{var_name.id}} = val_ptr.as(Float64*).value.to_f32
            {% elsif var_type == "Float64" %}
              self.{{var_name.id}} = val_ptr.as(Float64*).value
            {% elsif var_type == "Int32" %}
              self.{{var_name.id}} = val_ptr.as(Int64*).value.to_i32
            {% elsif var_type == "Int64" %}
              self.{{var_name.id}} = val_ptr.as(Int64*).value
            {% elsif var_type == "Bool" %}
              self.{{var_name.id}} = val_ptr.as(UInt8*).value != 0_u8
            {% elsif var_type == "Vector2" %}
              self.{{var_name.id}} = val_ptr.as(::Godot::Vector2*).value
            {% elsif var_type == "Vector2i" %}
              self.{{var_name.id}} = val_ptr.as(::Godot::Vector2i*).value
            {% elsif var_type == "Vector3" %}
              self.{{var_name.id}} = val_ptr.as(::Godot::Vector3*).value
            {% elsif var_type == "Vector3i" %}
              self.{{var_name.id}} = val_ptr.as(::Godot::Vector3i*).value
            {% elsif var_type == "Color" %}
              self.{{var_name.id}} = val_ptr.as(::Godot::Color*).value
            {% elsif var_type == "Rect2" %}
              self.{{var_name.id}} = val_ptr.as(::Godot::Rect2*).value
            {% elsif var_type == "Transform3D" %}
              self.{{var_name.id}} = val_ptr.as(::Godot::Transform3D*).value
            {% elsif var_type == "String" %}
              c_str = val_ptr.as(Pointer(UInt8)*).value
              self.{{var_name.id}} = c_str.null? ? "" : String.new(c_str)
            {% elsif arg.is_a?(TypeDeclaration) && arg.type && arg.type.is_a?(Path) && arg.type.resolve? && (arg.type.resolve < Enum) %}
              self.{{var_name.id}} = {{arg.type.id}}.from_value?(val_ptr.as(Int64*).value) || self.{{var_name.id}}
            {% end %}
        {% end %}
      {% end %}
      else
        super
      end
    end

    def _godot_get_property(prop_name : String, ret_ptr : Void*) : Void
      case prop_name
      {% for item in props %}
        {% if item[0] == :prop %}
          {% arg = item[1] %}
          {% var_name = arg.is_a?(Assign) ? arg.target : arg.var %}
          {% var_type = arg.is_a?(Assign) ? "Callable" : (arg.type ? arg.type.stringify.gsub(/^(::)?Godot::/, "") : "Callable") %}
          when "{{var_name.id}}"
            {% if var_type == "Float32" || var_type == "Float64" %}
              ret_ptr.as(Float64*).value = self.{{var_name.id}}.to_f64
            {% elsif var_type == "Int32" || var_type == "Int64" %}
              ret_ptr.as(Int64*).value = self.{{var_name.id}}.to_i64
            {% elsif var_type == "Bool" %}
              ret_ptr.as(UInt8*).value = self.{{var_name.id}} ? 1_u8 : 0_u8
            {% elsif var_type == "Vector2" %}
              ret_ptr.as(::Godot::Vector2*).value = self.{{var_name.id}}
            {% elsif var_type == "Vector2i" %}
              ret_ptr.as(::Godot::Vector2i*).value = self.{{var_name.id}}
            {% elsif var_type == "Vector3" %}
              ret_ptr.as(::Godot::Vector3*).value = self.{{var_name.id}}
            {% elsif var_type == "Vector3i" %}
              ret_ptr.as(::Godot::Vector3i*).value = self.{{var_name.id}}
            {% elsif var_type == "Color" %}
              ret_ptr.as(::Godot::Color*).value = self.{{var_name.id}}
            {% elsif var_type == "Rect2" %}
              ret_ptr.as(::Godot::Rect2*).value = self.{{var_name.id}}
            {% elsif var_type == "Transform3D" %}
              ret_ptr.as(::Godot::Transform3D*).value = self.{{var_name.id}}
            {% elsif var_type == "String" %}
              ret_ptr.as(Pointer(UInt8)*).value = self.{{var_name.id}}.to_unsafe
            {% elsif arg.is_a?(TypeDeclaration) && arg.type && arg.type.is_a?(Path) && arg.type.resolve? && (arg.type.resolve < Enum) %}
              ret_ptr.as(Int64*).value = self.{{var_name.id}}.to_i64
            {% end %}
        {% end %}
      {% end %}
      else
        super
      end
    end

    def _godot_call_tool_button(button_name : String) : Void
      case button_name
      {% for tb in tool_buttons %}
      when "{{tb[0].id}}"
        {% if tb[2] == :proc_property %}
          if btn = self.{{tb[0].id}}
            btn.call
          end
        {% else %}
          self.{{tb[0].id}}
        {% end %}
      {% end %}
      else
        super
      end
    end

    {{ yield }}
  end
end

macro godot_module(decl, &block)
  gmodule {{decl}} do
    {{yield}}
  end
end

macro godot_module(decl)
  gmodule {{decl}} do
  end
end

macro finished
  {% for klass in ::Godot::Object.all_subclasses %}
    {% if klass.annotation(::GodotClass) %}
      {% if klass.class.methods.map(&.name.stringify).includes?("_godot_auto_register_class") %}
        {{klass}}._godot_auto_register_class
      {% end %}
    {% end %}
  {% end %}
end


