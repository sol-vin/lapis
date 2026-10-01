require "json"
require "file_utils"

# =============================================================================
# LibGodot Project Binding Generator
# =============================================================================
# Reads project_nodes.json produced by dump_project_nodes.gd and generates
# strongly typed Crystal wrapper classes for custom GDScript nodes and
# compiled GDExtension plugin nodes.
#
# Usage:
#   crystal run tools/api_generator/generate_project_bindings.cr -- <json_file> <out_dir>
# =============================================================================

json_path = ARGV[0]? || "project_nodes.json"
out_dir = ARGV[1]? || "src/generated/project_nodes"

unless File.exists?(json_path)
  STDERR.puts "Error: Project nodes JSON not found at #{json_path}"
  exit 1
end

# Clean out any previous generated files to prevent stale bindings
if Dir.exists?(out_dir)
  Dir.each_child(out_dir) do |entry|
    path = File.join(out_dir, entry)
    begin
      if File.file?(path)
        File.delete(path)
      elsif File.directory?(path)
        FileUtils.rm_rf(path)
      end
    rescue ex
      STDERR.puts "[ProjectGenerator] Warning: Could not remove #{path}: #{ex.message}"
    end
  end
else
  FileUtils.mkdir_p(out_dir)
end

data = JSON.parse(File.read(json_path))

# Mapping from Godot Variant Type ID to Crystal Type Name
VARIANT_TYPE_MAP = {
   0 => "Void",
   1 => "Bool",
   2 => "Int64",
   3 => "Float64",
   4 => "String",
   5 => "Godot::Vector2",
   6 => "Godot::Vector2i",
   7 => "Godot::Rect2",
   8 => "Godot::Rect2i",
   9 => "Godot::Vector3",
  10 => "Godot::Vector3i",
  11 => "Godot::Transform2D",
  12 => "Godot::Vector4",
  13 => "Godot::Vector4i",
  14 => "Godot::Plane",
  15 => "Godot::Quaternion",
  16 => "Godot::AABB",
  17 => "Godot::Basis",
  18 => "Godot::Transform3D",
  19 => "Godot::Projection",
  20 => "Godot::Color",
  21 => "String",
  22 => "Godot::NodePath",
  23 => "Godot::RID",
  24 => "Godot::Object",
  25 => "Godot::Callable",
  26 => "Godot::Signal",
  27 => "Godot::Dictionary",
  28 => "Godot::Array",
  29 => "Godot::PackedByteArray",
  30 => "Godot::PackedInt32Array",
  31 => "Godot::PackedInt64Array",
  32 => "Godot::PackedFloat32Array",
  33 => "Godot::PackedFloat64Array",
  34 => "Godot::PackedStringArray",
  35 => "Godot::PackedVector2Array",
  36 => "Godot::PackedVector3Array",
  37 => "Godot::PackedColorArray",
  38 => "Godot::PackedVector4Array",
}

KEYWORDS = {
  "type"    => "type_id",
  "end"     => "end_val",
  "begin"   => "begin_val",
  "class"   => "class_type",
  "default" => "default_val",
  "in"      => "in_val",
  "out"     => "out_val",
  "select"  => "select_val",
  "loop"    => "loop_val",
  "next"    => "next_val",
  "break"   => "break_val",
  "self"    => "self_node",
  "nil"     => "nil_val",
  "true"    => "true_val",
  "false"   => "false_val",
}

def sanitize_ident(name : String) : String
  clean = name.gsub(/[^a-zA-Z0-9_]/, "_").underscore
  clean = "arg_#{clean}" if clean.starts_with?(/[0-9]/)
  clean = "arg" if clean.empty?
  KEYWORDS[clean]? || clean
end

def resolve_crystal_return_type(type_id : Int64, class_name : String?) : String
  if !class_name.nil? && !class_name.empty?
    clean_class = class_name.gsub(/[^a-zA-Z0-9_]/, "")
    if clean_class == "Node" || clean_class == "Object" || clean_class == "Resource"
      return "Godot::#{clean_class}?"
    elsif clean_class.starts_with?("Godot::")
      return "#{clean_class}?"
    else
      return "Godot::#{clean_class}?"
    end
  end

  case type_id
  when  0 then "Void"
  when  1 then "Bool"
  when  2 then "Int64"
  when  3 then "Float64"
  when  4 then "String"
  when 24 then "Godot::Object?"
  else
    "Void"
  end
end

def resolve_crystal_param_type(type_id : Int64, class_name : String?) : String?
  if !class_name.nil? && !class_name.empty?
    clean_class = class_name.gsub(/[^a-zA-Z0-9_]/, "")
    if clean_class.starts_with?("Godot::")
      return clean_class
    else
      return "Godot::#{clean_class}"
    end
  end

  if type_id == 0
    return nil
  end

  VARIANT_TYPE_MAP[type_id]?
end

Dir.mkdir_p(out_dir)
generated_files = [] of String
parent_map = Hash(String, String?).new

# Collect all custom class names to detect inheritance between custom nodes
custom_class_names = Set(String).new
if gdscript_classes = data["gdscript_classes"]?.try(&.as_a)
  gdscript_classes.each do |c|
    if raw_name = c["name"]?.try(&.as_s)
      clean = raw_name.gsub(/[^a-zA-Z0-9_]/, "")
      custom_class_names << clean unless clean.empty?
    end
  end
end

# =============================================================================
# 1. Generate GDScript Node Bindings
# =============================================================================
if gdscript_classes = data["gdscript_classes"]?.try(&.as_a)
  gdscript_classes.each do |c|
    raw_name = c["name"]?.try(&.as_s) || ""
    clean_class_name = raw_name.gsub(/[^a-zA-Z0-9_]/, "")
    next if clean_class_name.empty?

    inherits_name = c["inherits"]?.try(&.as_s) || "Node"
    clean_inherits = inherits_name.gsub(/[^a-zA-Z0-9_]/, "")
    is_custom_parent = custom_class_names.includes?(clean_inherits)

    if inherits_name.starts_with?("Crystal")
      inherits_type = "Godot::Node"
    else
      inherits_type = inherits_name.starts_with?("Godot::") ? inherits_name : "Godot::#{inherits_name}"
    end
    script_path = c["path"]?.try(&.as_s) || ""

    file_basename = "#{clean_class_name.underscore}.cr"
    target_path = File.join(out_dir, file_basename)
    generated_files << file_basename
    parent_map[file_basename] = is_custom_parent ? "#{clean_inherits.underscore}.cr" : nil

    File.open(target_path, "w") do |io|
      io.puts "# Generated strongly typed wrapper for GDScript node `#{clean_class_name}`"
      io.puts "# Script Path: #{script_path}"
      if is_custom_parent
        io.puts "require \"./#{clean_inherits.underscore}.cr\""
      end
      io.puts "module Godot"
      io.puts "  class #{clean_class_name} < #{inherits_type}"
      io.puts "    # Wrap a native pointer to an existing #{clean_class_name} instance"
      io.puts "    def initialize(pointer : Void* = Pointer(Void).null)"
      io.puts "      super(pointer)"
      io.puts "    end\n"
      io.puts "    # Helper to wrap any Godot node into a typed #{clean_class_name}"
      io.puts "    def self.from(node : Godot::Object) : self"
      io.puts "      new(node.pointer)"
      io.puts "    end\n"

      # Properties
      if props = c["properties"]?.try(&.as_a)
        props.each do |p|
          prop_name = p["name"]?.try(&.as_s) || ""
          next if prop_name.empty? || prop_name.starts_with?("@")
          prop_type_id = p["type"]?.try(&.as_i64) || 0_i64
          prop_class = p["class_name"]?.try(&.as_s)
          c_type = resolve_crystal_return_type(prop_type_id, prop_class)
          clean_getter = sanitize_ident(prop_name)
          clean_setter = "#{clean_getter}="

          io.puts "    # Property `#{prop_name}` (#{c_type})"
          case prop_type_id
          when 1 # Bool
            io.puts "    def #{clean_getter} : Bool"
            io.puts "      call_bool(\"get\", \"#{prop_name}\")"
            io.puts "    end"
          when 2 # Int64
            io.puts "    def #{clean_getter} : Int64"
            io.puts "      call_i64(\"get\", \"#{prop_name}\")"
            io.puts "    end"
          when 3 # Float64
            io.puts "    def #{clean_getter} : Float64"
            io.puts "      call_f64(\"get\", \"#{prop_name}\")"
            io.puts "    end"
          when 4 # String
            io.puts "    def #{clean_getter} : String"
            io.puts "      call_str(\"get\", \"#{prop_name}\")"
            io.puts "    end"
          when 24 # Object
            io.puts "    def #{clean_getter} : #{c_type}"
            base_t = c_type.rstrip('?')
            io.puts "      call_obj_as(#{base_t}, \"get\", \"#{prop_name}\")"
            io.puts "    end"
          else
            io.puts "    def #{clean_getter} : String"
            io.puts "      call_str(\"get\", \"#{prop_name}\")"
            io.puts "    end"
          end

          io.puts "    def #{clean_setter}(val) : Void"
          io.puts "      call(\"set\", \"#{prop_name}\", val)"
          io.puts "    end\n"
        end
      end

      # Methods
      if methods = c["methods"]?.try(&.as_a)
        methods.each do |m|
          m_name = m["name"]?.try(&.as_s) || ""
          next if m_name.empty? || m_name.starts_with?("@") || m_name == "get" || m_name == "set"
          clean_m_name = sanitize_ident(m_name)
          ret_type_id = m["return_type"]?.try(&.as_i64) || 0_i64
          ret_class = m["return_class_name"]?.try(&.as_s)
          ret_c_type = resolve_crystal_return_type(ret_type_id, ret_class)

          # Build args signature & call args
          args_entries = m["args"]?.try(&.as_a) || [] of JSON::Any
          sig_parts = [] of String
          call_arg_names = [] of String

          args_entries.each_with_index do |a, idx|
            a_name = sanitize_ident(a["name"]?.try(&.as_s) || "arg_#{idx}")
            a_type_id = a["type"]?.try(&.as_i64) || 0_i64
            a_class = a["class_name"]?.try(&.as_s)
            a_c_type = resolve_crystal_param_type(a_type_id, a_class)
            if a_c_type
              sig_parts << "#{a_name} : #{a_c_type}"
            else
              sig_parts << a_name
            end
            call_arg_names << a_name
          end

          sig_str = sig_parts.join(", ")
          args_pass_str = call_arg_names.empty? ? "" : ", #{call_arg_names.join(", ")}"

          io.puts "    # Method `#{m_name}` -> #{ret_c_type}"
          io.puts "    def #{clean_m_name}(#{sig_str}) : #{ret_c_type}"
          case ret_type_id
          when 0 # Void / Nil
            io.puts "      call(\"#{m_name}\"#{args_pass_str})"
            io.puts "      nil"
          when 1 # Bool
            io.puts "      call_bool(\"#{m_name}\"#{args_pass_str})"
          when 2 # Int64
            io.puts "      call_i64(\"#{m_name}\"#{args_pass_str})"
          when 3 # Float64
            io.puts "      call_f64(\"#{m_name}\"#{args_pass_str})"
          when 4 # String
            io.puts "      call_str(\"#{m_name}\"#{args_pass_str})"
          when 24 # Object
            base_t = ret_c_type.rstrip('?')
            io.puts "      call_obj_as(#{base_t}, \"#{m_name}\"#{args_pass_str})"
          else
            io.puts "      call(\"#{m_name}\"#{args_pass_str})"
            io.puts "      nil"
          end
          io.puts "    end\n"
        end
      end

      # Signals
      if sigs = c["signals"]?.try(&.as_a)
        sigs.each do |s|
          sig_name = s["name"]?.try(&.as_s) || ""
          next if sig_name.empty?
          clean_sig_name = sanitize_ident(sig_name)
          io.puts "    # Bound Signal `#{sig_name}`"
          io.puts "    def #{clean_sig_name} : Godot::BoundSignal"
          io.puts "      signal(\"#{sig_name}\")"
          io.puts "    end\n"
        end
      end

      io.puts "  end"
      io.puts "end"
      io.puts ""
      io.puts "alias #{clean_class_name} = Godot::#{clean_class_name}"
    end
  end
end

# =============================================================================
# 2. Generate Manifest: all_project_nodes.cr (Topologically Ordered)
# =============================================================================
def add_with_parents(file : String, parent_map : Hash(String, String?), visited : Set(String), visiting : Set(String), ordered_files : Array(String)) : Nil
  return if visited.includes?(file)
  if visiting.includes?(file)
    visited << file
    ordered_files << file
    return
  end
  visiting << file
  if parent_file = parent_map[file]?
    add_with_parents(parent_file, parent_map, visited, visiting, ordered_files)
  end
  visiting.delete(file)
  visited << file
  ordered_files << file
end

ordered_files = [] of String
visited = Set(String).new
visiting = Set(String).new

generated_files.sort.each do |f|
  add_with_parents(f, parent_map, visited, visiting, ordered_files)
end

manifest_path = File.join(out_dir, "all_project_nodes.cr")
File.open(manifest_path, "w") do |io|
  io.puts "# Generated All Project Custom Nodes Manifest"
  ordered_files.each do |f|
    io.puts "require \"./#{f}\""
  end
end

puts "[ProjectGenerator] Generated #{generated_files.size} project node binding(s) in #{out_dir}"
