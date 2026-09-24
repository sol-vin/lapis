require "json"
require "yaml"

puts "=== LibGodot Crystal Binding Generator ==="
puts "Loading extension_api.json..."

api_file = if File.exists?("extension_api.json")
             "extension_api.json"
           elsif File.exists?("rsrc/extension_api.json")
             "rsrc/extension_api.json"
           elsif File.exists?(File.join(__DIR__, "..", "..", "rsrc", "extension_api.json"))
             File.join(__DIR__, "..", "..", "rsrc", "extension_api.json")
           elsif File.exists?(File.join(__DIR__, "..", "..", "extension_api.json"))
             File.join(__DIR__, "..", "..", "extension_api.json")
           else
             puts "Error: extension_api.json not found! Run godot.exe --headless --dump-extension-api first."
             exit 1
           end

api_json = File.read(api_file)
api_data = JSON.parse(api_json)

# Load overrides
overrides_file = if File.exists?("tools/api_generator/overrides.yml")
                   "tools/api_generator/overrides.yml"
                 elsif File.exists?(File.join(__DIR__, "overrides.yml"))
                   File.join(__DIR__, "overrides.yml")
                 elsif File.exists?("scripts/overrides.yml")
                   "scripts/overrides.yml"
                 else
                   nil
                 end

overrides = if overrides_file && File.exists?(overrides_file)
              YAML.parse(File.read(overrides_file))
            else
              YAML.parse("{}")
            end

keywords = Hash(String, String).new
if kw = overrides["keywords"]?
  kw.as_h.each do |k, v|
    keywords[k.to_s] = v.to_s
  end
end

type_map = Hash(String, String).new
if tm = overrides["type_map"]?
  tm.as_h.each do |k, v|
    type_map[k.to_s] = v.to_s
  end
end

predicate_aliases = Hash(String, Array(String)).new
if pa = overrides["predicate_aliases"]?
  pa.as_h.each do |k, v|
    predicate_aliases[k.to_s] = v.as_a.map(&.to_s)
  end
end

def sanitize_name(name : String, keywords : Hash(String, String)) : String
  clean = name.gsub(/[^a-zA-Z0-9_]/, "_")
  clean = clean.underscore
  if clean.starts_with?(/[0-9]/)
    clean = "arg_#{clean}"
  elsif clean.empty?
    clean = "arg"
  end
  if mapped = keywords[clean]?
    mapped
  else
    clean
  end
end

def crystal_type_name(godot_type : String, type_map : Hash(String, String)) : String
  if godot_type.starts_with?("enum::") || godot_type.starts_with?("bitfield::")
    return "Int64"
  elsif mapped = type_map[godot_type]?
    mapped
  elsif godot_type.starts_with?("typedarray::")
    return "Pointer(Void)"
  elsif godot_type.ends_with?("*") || godot_type.starts_with?("const ") || godot_type.includes?("*")
    return "Pointer(Void)"
  else
    godot_type.gsub(/[^a-zA-Z0-9_]/, "")
  end
end

def resolve_type_info(godot_type : String, current_class : String, type_map : Hash(String, String)) : NamedTuple(crystal_type: String, is_enum: Bool, enum_type: String?)
  if godot_type.starts_with?("enum::") || godot_type.starts_with?("bitfield::")
    raw = godot_type.sub(/^(?:enum|bitfield)::/, "")
    if raw.includes?(".")
      target_class, target_enum = raw.split(".", 2)
      target_enum = target_enum.gsub(/[^a-zA-Z0-9_]/, "")
      enum_type_name = if target_class == current_class
                         target_enum
                       else
                         "Godot::#{target_class}::#{target_enum}"
                       end
      return {crystal_type: "#{enum_type_name} | Int", is_enum: true, enum_type: enum_type_name}
    else
      enum_name = raw.gsub(/[^a-zA-Z0-9_]/, "")
      enum_type_name = "Godot::#{enum_name}"
      return {crystal_type: "#{enum_type_name} | Int", is_enum: true, enum_type: enum_type_name}
    end
  elsif godot_type == "NodePath"
    return {crystal_type: "NodePath | String", is_enum: false, enum_type: nil}
  elsif mapped = type_map[godot_type]?
    return {crystal_type: mapped, is_enum: false, enum_type: nil}
  elsif godot_type.starts_with?("typedarray::")
    return {crystal_type: "Pointer(Void)", is_enum: false, enum_type: nil}
  elsif godot_type.ends_with?("*") || godot_type.starts_with?("const ") || godot_type.includes?("*")
    return {crystal_type: "Pointer(Void)", is_enum: false, enum_type: nil}
  else
    clean = godot_type.gsub(/[^a-zA-Z0-9_]/, "")
    return {crystal_type: clean, is_enum: false, enum_type: nil}
  end
end

def resolve_return_type(godot_type : String, current_class : String, type_map : Hash(String, String)) : NamedTuple(crystal_type: String, is_enum: Bool)
  if godot_type.starts_with?("enum::") || godot_type.starts_with?("bitfield::")
    raw = godot_type.sub(/^(?:enum|bitfield)::/, "")
    if raw.includes?(".")
      target_class, target_enum = raw.split(".", 2)
      target_enum = target_enum.gsub(/[^a-zA-Z0-9_]/, "")
      enum_type_name = if target_class == current_class
                         target_enum
                       else
                         "Godot::#{target_class}::#{target_enum}"
                       end
      return {crystal_type: enum_type_name, is_enum: true}
    else
      enum_name = raw.gsub(/[^a-zA-Z0-9_]/, "")
      return {crystal_type: "Godot::#{enum_name}", is_enum: true}
    end
  elsif godot_type == "NodePath"
    return {crystal_type: "NodePath", is_enum: false}
  else
    mapped = crystal_type_name(godot_type, type_map)
    return {crystal_type: mapped, is_enum: false}
  end
end

def to_snake_case(s : String) : String
  case s
  when "OS" then "os"
  when "IP" then "ip"
  else
    s.underscore.gsub(/_2_d\b/, "_2d").gsub(/_3_d\b/, "_3d")
  end
end

def resolve_default_value(raw_val : String, crystal_type : String, is_enum : Bool) : String?
  raw = raw_val.strip
  if is_enum
    return raw.matches?(/\A-?\d+\z/) ? raw : nil
  end

  case crystal_type
  when "Bool"
    case raw
    when "true", "1"  then "true"
    when "false", "0" then "false"
    else                   nil
    end
  when "Float64", "Float32"
    if raw.matches?(/\A-?\d+(\.\d+)?(e-?\d+)?\z/i)
      raw.includes?(".") || raw.includes?("e") ? "#{raw}_f64" : "#{raw}.0_f64"
    else
      nil
    end
  when "Int64", "Int32", "UInt64", "UInt32", "Int16", "UInt16", "Int8", "UInt8"
    if raw.matches?(/\A-?\d+\z/)
      "#{raw}_i64"
    else
      nil
    end
  when "String", "StringName"
    if raw.starts_with?("&\"") && raw.ends_with?("\"")
      "\"#{raw[2...-1]}\""
    elsif raw.starts_with?("\"") && raw.ends_with?("\"")
      raw
    else
      nil
    end
  when "NodePath | String"
    if raw == "NodePath(\"\")" || raw == "\"\""
      "\"\""
    elsif raw.starts_with?("&\"") && raw.ends_with?("\"")
      "\"#{raw[2...-1]}\""
    elsif raw.starts_with?("\"") && raw.ends_with?("\"")
      raw
    else
      nil
    end
  when "Vector2"
    if m = raw.match(/\AVector2\(([^,]+),\s*([^)]+)\)\z/)
      "Vector2.new(#{m[1]}.to_f32, #{m[2]}.to_f32)"
    else
      nil
    end
  when "Vector2i"
    if m = raw.match(/\AVector2i\(([^,]+),\s*([^)]+)\)\z/)
      "Vector2i.new(#{m[1]}.to_i32, #{m[2]}.to_i32)"
    else
      nil
    end
  when "Vector3"
    if m = raw.match(/\AVector3\(([^,]+),\s*([^,]+),\s*([^)]+)\)\z/)
      "Vector3.new(#{m[1]}.to_f32, #{m[2]}.to_f32, #{m[3]}.to_f32)"
    else
      nil
    end
  when "Vector3i"
    if m = raw.match(/\AVector3i\(([^,]+),\s*([^,]+),\s*([^)]+)\)\z/)
      "Vector3i.new(#{m[1]}.to_i32, #{m[2]}.to_i32, #{m[3]}.to_i32)"
    else
      nil
    end
  when "Color"
    if m = raw.match(/\AColor\(([^,]+),\s*([^,]+),\s*([^,]+),\s*([^)]+)\)\z/)
      "Color.new(#{m[1]}.to_f32, #{m[2]}.to_f32, #{m[3]}.to_f32, #{m[4]}.to_f32)"
    else
      nil
    end
  when "Rect2"
    if m = raw.match(/\ARect2\(([^,]+),\s*([^,]+),\s*([^,]+),\s*([^)]+)\)\z/)
      "Rect2.new(#{m[1]}.to_f32, #{m[2]}.to_f32, #{m[3]}.to_f32, #{m[4]}.to_f32)"
    else
      nil
    end
  else
    if raw == "null"
      "nil"
    else
      nil
    end
  end
end

def format_doc_comment(raw_text : String?, indent : String = "  ") : String
  return "" if raw_text.nil? || raw_text.to_s.strip.empty?

  # Clean Godot BBCode tags into standard Markdown
  text = raw_text.to_s
    .gsub(/\[codeblock\]/m, "```gdscript\n")
    .gsub(/\[\/codeblock\]/m, "\n```")
    .gsub(/\[codeblocks\]/m, "")
    .gsub(/\[\/codeblocks\]/m, "")
    .gsub(/\[gdscript\]/m, "```gdscript\n")
    .gsub(/\[\/gdscript\]/m, "\n```")
    .gsub(/\[csharp\]/m, "```csharp\n")
    .gsub(/\[\/csharp\]/m, "\n```")
    .gsub(/\[code\](.*?)\[\/code\]/m) { "`#{$1}`" }
    .gsub(/\[b\](.*?)\[\/b\]/m) { "**#{$1}**" }
    .gsub(/\[i\](.*?)\[\/i\]/m) { "*#{$1}*" }
    .gsub(/\[kbd\](.*?)\[\/kbd\]/m) { "`#{$1}`" }
    .gsub(/\[url=(.*?)\](.*?)\[\/url\]/m) { "[$2]($1)" }
    .gsub(/\[url\](.*?)\[\/url\]/m) { "[$1]($1)" }
    .gsub(/\[annotation\s+([^\]]+)\]/) { "`#{$1}`" }
    .gsub(/\[param\s+(\w+)\]/) { "`#{$1}`" }
    .gsub(/\[member\s+([\w\.]+)\]/) { "`#{$1}`" }
    .gsub(/\[method\s+([\w\.]+)\]/) { "`##{$1}`" }
    .gsub(/\[constant\s+([\w\.]+)\]/) { "`#{$1}`" }
    .gsub(/\[enum\s+([\w\.]+)\]/) { "`#{$1}`" }
    .gsub(/\[signal\s+([\w\.]+)\]/) { "`#{$1}`" }
    .gsub(/\[(\w+)\]/) { "`#{$1}`" }

  lines = text.strip.lines
  doc_lines = lines.map do |line|
    cleaned = line.rstrip
    cleaned.empty? ? "#{indent}#" : "#{indent}# #{cleaned}"
  end

  doc_lines.join("\n") + "\n"
end

# Ensure directories
Dir.mkdir_p("src/libgodot/generated")
Dir.mkdir_p("src/libgodot/generated/classes")

# =============================================================================
# 1. Global Enums
# =============================================================================
puts "Generating global enums..."
File.open("src/libgodot/generated/global_enums.cr", "w") do |f|
  f.puts "# Generated Global Enums for Godot 4.8+"
  f.puts "module Godot"

  if global_enums = api_data["global_enums"]?
    global_enums.as_a.each do |e|
      raw_enum_name = e["name"].as_s
      enum_name = raw_enum_name.starts_with?("Variant.") ? raw_enum_name.gsub("Variant.", "") : raw_enum_name
      next if enum_name.empty?

      f.puts "  # Godot `#{enum_name}` global enum."
      f.puts "  enum #{enum_name} : Int64"
      enum_prefix = "#{enum_name.underscore.upcase}_"
      alt_prefix = "#{enum_name.upcase}_"
      if values = e["values"]?
        values.as_a.each do |v|
          val_name = v["name"].as_s
          clean_val = if val_name.starts_with?(enum_prefix)
                        val_name[enum_prefix.size..]
                      elsif val_name.starts_with?(alt_prefix)
                        val_name[alt_prefix.size..]
                      else
                        val_name
                      end
          parts = clean_val.split('_')
          camel_val = parts.map(&.capitalize).join
          camel_val = "Val#{camel_val}" if camel_val.starts_with?(/[0-9]/)
          camel_val = "None" if camel_val.empty?
          val_num = v["value"].as_i64
          f.puts "    #{camel_val} = #{val_num}_i64"
        end
      end
      f.puts "  end\n"
    end
  end

  f.puts "end"
end

# =============================================================================
# 2. Singletons
# =============================================================================
puts "Generating singletons..."
File.open("src/libgodot/generated/singletons.cr", "w") do |f|
  f.puts "# Generated Singletons for Godot 4.8+"
  f.puts "module Godot"

  if singletons = api_data["singletons"]?
    singletons.as_a.each do |s|
      s_name = s["name"].as_s
      s_type = s["type"]?.try(&.as_s) || s_name
      parent_type = s_name == "GDScriptLanguageProtocol" ? "Godot::JSONRPC" : "Godot::Object"
      f.puts "  # Godot `#{s_name}` singleton (#{s_type})."
      f.puts "  godot_singleton(#{s_name}, \"#{s_name}\", #{parent_type})"
      snake_name = to_snake_case(s_name)
      f.puts "  godot_singleton_accessor(#{snake_name}, #{s_name})"
      if snake_name.includes?("_2d")
        f.puts "  godot_singleton_accessor(#{snake_name.gsub(/_2d/, "2d")}, #{s_name})"
      elsif snake_name.includes?("_3d")
        f.puts "  godot_singleton_accessor(#{snake_name.gsub(/_3d/, "3d")}, #{s_name})"
      end
      f.puts ""
    end
  end

  f.puts "end"
end

# =============================================================================
# 3. Classes (Topologically Sorted)
# =============================================================================
puts "Sorting classes topologically..."
classes = api_data["classes"].as_a.reject do |c|
  api_type = c["api_type"]?.try(&.as_s)
  api_type == "extension" || api_type == "editor_extension"
end

# Build dependency graph
class_map = Hash(String, JSON::Any).new
inherits_map = Hash(String, String?).new
classes.each do |c|
  name = c["name"].as_s
  class_map[name] = c
  inherits_map[name] = c["inherits"]?.try(&.as_s)
end

# Topological sort
visited = Set(String).new
sorted_classes = Array(JSON::Any).new

def visit(name : String, class_map, inherits_map, visited, sorted_classes)
  return if visited.includes?(name)
  visited.add(name)
  if parent = inherits_map[name]?
    if class_map.has_key?(parent)
      visit(parent, class_map, inherits_map, visited, sorted_classes)
    end
  end
  if c = class_map[name]?
    sorted_classes << c
  end
end

class_map.keys.each do |name|
  visit(name, class_map, inherits_map, visited, sorted_classes)
end

puts "Generating #{sorted_classes.size} classes..."

class_names = Set(String).new
class_map.keys.each { |k| class_names.add(k) }

all_method_names = Set(String).new
classes.each do |c|
  c["methods"]?.try(&.as_a.each { |m| all_method_names.add(m["name"].as_s) })
end

manual_methods = Hash(String, Set(String)).new
ext_files = Dir.glob("src/libgodot/extensions/*.cr")
if ext_files.empty?
  ext_files = Dir.glob(File.join(__DIR__, "..", "..", "src", "libgodot", "extensions", "*.cr"))
end
manual_files = ["src/libgodot/object.cr", "src/libgodot.cr"] + ext_files
manual_files.each do |manual_file|
  path = if File.exists?(manual_file)
           manual_file
         elsif File.exists?(File.join(__DIR__, "..", "..", manual_file))
           File.join(__DIR__, "..", "..", manual_file)
         else
           nil
         end
  next unless path && File.exists?(path)

  curr_class : String? = nil
  File.each_line(path) do |line|
    if line =~ /^\s*class\s+([A-Za-z0-9_]+)/
      curr_class = $1
      manual_methods[curr_class] ||= Set(String).new
    elsif curr_class
      if line =~ /^\s*(?:def|property|getter|setter)\??\s+(?:self\.)?([A-Za-z0-9_]+[=?]?)/
        m_ident = $1
        manual_methods[curr_class].add(m_ident)
        manual_methods[curr_class].add("#{m_ident}=") unless m_ident.ends_with?("=")
      end
    end
  end
end

def generate_class_code(io : IO, c : JSON::Any, keywords : Hash(String, String), type_map : Hash(String, String), class_names : Set(String), all_method_names : Set(String), manual_methods : Hash(String, Set(String)), predicate_aliases : Hash(String, Array(String)))
  name = c["name"].as_s
  parent = c["inherits"]?.try(&.as_s) || "Godot::Object"
  parent_type = parent == "Godot::Object" ? parent : (parent.starts_with?("Godot::") ? parent : "Godot::#{parent}")
  class_manuals = manual_methods[name]?
  defined_class_methods = Set(String).new

  # Class documentation
  class_doc_parts = [] of String
  if brief = c["brief_description"]?.try(&.as_s.strip)
    class_doc_parts << brief unless brief.empty?
  end
  if desc = c["description"]?.try(&.as_s.strip)
    if !desc.empty? && !class_doc_parts.includes?(desc)
      class_doc_parts << desc
    end
  end
  full_class_doc = class_doc_parts.join("\n\n")
  if !full_class_doc.empty?
    io.print format_doc_comment(full_class_doc, indent: "  ")
  end

  if name == "Object"
    io.puts "  class Object"
    io.puts "    def initialize(@pointer : Void* = Pointer(Void).null)"
    io.puts "      if !@pointer.null?"
    io.puts "        @instance_id = Bridge.object_get_instance_id(@pointer)"
    io.puts "      end"
    io.puts "    end\n"
  else
    io.puts "  class #{name} < #{parent_type}"
    io.puts "    def initialize(pointer : Void* = Pointer(Void).null)"
    io.puts "      super(pointer)"
    io.puts "    end\n"
  end

  # Inner enums
  if enums = c["enums"]?
    enums.as_a.each do |e|
      e_name = e["name"].as_s
      next if e_name.empty?
      if e_doc = e["description"]?.try(&.as_s.strip)
        io.print format_doc_comment(e_doc, indent: "    ")
      end
      io.puts "    enum #{e_name} : Int64"
      if values = e["values"]?
        values.as_a.each do |v|
          val_name = v["name"].as_s
          parts = val_name.split('_')
          camel_val = parts.map(&.capitalize).join
          camel_val = "Val#{camel_val}" if camel_val.starts_with?(/[0-9]/)
          val_num = v["value"].as_i64
          io.puts "      #{camel_val} = #{val_num}_i64"
        end
      end
      io.puts "    end\n"
    end
  end

  # Methods
  if methods = c["methods"]?
    methods.as_a.each do |m|
      m_name = m["name"].as_s
      next if m["is_virtual"]?.try(&.as_bool)
      next if m["is_vararg"]?.try(&.as_bool)
      hash_val = m["hash"]?.try(&.as_i64) || 0_i64
      sanitized_m_name = sanitize_name(m_name, keywords)

      is_static = m["is_static"]?.try(&.as_bool) || false
      target_ptr = is_static ? "Pointer(Void).null" : "@pointer"
      method_prefix = is_static ? "def self." : "def "

      defined_class_methods.add("#{method_prefix}#{sanitized_m_name}")
      if is_static
        defined_class_methods.add("def #{sanitized_m_name}")
      end

      # Build argument list with default values
      args = m["arguments"]?.try(&.as_a) || [] of JSON::Any
      arg_defs = [] of String
      arg_names = [] of String
      arg_is_enum = [] of Bool

      # Resolve defaults for all arguments
      defaults = args.map do |a|
        if dv = a["default_value"]?
          t_info = resolve_type_info(a["type"].as_s, name, type_map)
          resolve_default_value(dv.as_s, t_info[:crystal_type], t_info[:is_enum])
        else
          nil
        end
      end

      # Find first index from right that does NOT have a valid default value
      first_non_default_idx = -1
      (args.size - 1).downto(0) do |i|
        if defaults[i].nil?
          first_non_default_idx = i
          break
        end
      end

      args.each_with_index do |a, idx|
        raw_a_name = a["name"].as_s
        a_name = sanitize_name(raw_a_name, keywords)
        t_info = resolve_type_info(a["type"].as_s, name, type_map)
        crystal_type = t_info[:crystal_type]
        def_val = (idx > first_non_default_idx) ? defaults[idx] : nil
        if def_val == "nil" && !crystal_type.ends_with?("?")
          crystal_type = "#{crystal_type}?"
        end
        if def_val
          arg_defs << "#{a_name} : #{crystal_type} = #{def_val}"
        else
          arg_defs << "#{a_name} : #{crystal_type}"
        end
        arg_names << a_name
        arg_is_enum << t_info[:is_enum]
      end

      # Return type
      ret_data = m["return_value"]?
      ret_type_godot = ret_data ? ret_data["type"].as_s : "void"
      ret_meta = ret_data && ret_data["meta"]? ? ret_data["meta"].as_s : nil
      ret_info = resolve_return_type(ret_type_godot, name, type_map)
      ret_type_crystal = ret_info[:crystal_type]
      is_ret_enum = ret_info[:is_enum]

      # Lazy method bind variable
      clean_var_name = m_name.gsub(/[^a-zA-Z0-9_]/, "_")
      io.puts "    @@mb_#{clean_var_name} : Void* = Pointer(Void).null"
      if m_doc = m["description"]?.try(&.as_s.strip)
        io.print format_doc_comment(m_doc, indent: "    ")
      end
      io.puts "    #{method_prefix}#{sanitized_m_name}(#{arg_defs.join(", ")}) : #{ret_type_crystal}"
      io.puts "      godot_bind(@@mb_#{clean_var_name}, \"#{name}\", \"#{m_name}\", #{hash_val}_i64)"

      # Prepare arguments using macros
      cleanups = [] of String
      args_expr = if args.empty?
                    "Pointer(Pointer(Void)).null"
                  else
                    args.each_with_index do |a, idx|
                      a_name = arg_names[idx]
                      godot_type = a["type"].as_s
                      if arg_is_enum[idx]
                        io.puts "      val_#{idx} = #{a_name}.is_a?(Int) ? #{a_name}.to_i64 : #{a_name}.value.to_i64"
                        io.puts "      arg_#{idx} = pointerof(val_#{idx}).as(Void*)"
                      elsif class_names.includes?(godot_type) || godot_type.starts_with?("Godot::") || ["Node", "Resource", "SceneTree", "Object", "Mesh"].includes?(godot_type)
                        io.puts "      arg_ptr_#{idx} = #{a_name} ? #{a_name}.pointer : Pointer(Void).null"
                        io.puts "      arg_#{idx} = pointerof(arg_ptr_#{idx}).as(Void*)"
                      elsif godot_type == "String"
                        io.puts "      str_#{idx} = Bridge.make_string(#{a_name})"
                        io.puts "      arg_#{idx} = str_#{idx}"
                        cleanups << "Bridge.free_string(str_#{idx})"
                      elsif godot_type == "StringName"
                        io.puts "      sn_#{idx} = Bridge.make_string_name(#{a_name})"
                        io.puts "      arg_#{idx} = sn_#{idx}"
                        cleanups << "Bridge.free_string_name(sn_#{idx})"
                      elsif godot_type == "NodePath"
                        io.puts "      np_#{idx} = Bridge.make_nodepath(#{a_name}.to_s)"
                        io.puts "      arg_#{idx} = np_#{idx}"
                        cleanups << "Bridge.free_nodepath(np_#{idx})"
                      else
                        if godot_type == "float"
                          io.puts "      val_#{idx} = #{a_name}.to_f64"
                        elsif godot_type == "int" || godot_type.starts_with?("enum::") || godot_type.starts_with?("bitfield::")
                          io.puts "      val_#{idx} = #{a_name}.to_i64"
                        else
                          io.puts "      val_#{idx} = #{a_name}"
                        end
                        io.puts "      arg_#{idx} = pointerof(val_#{idx}).as(Void*)"
                      end
                    end
                    arg_array = (0...args.size).map { |i| "arg_#{i}" }
                    io.puts "      args = StaticArray[#{arg_array.join(", ")}]"
                    "args.to_unsafe.as(Void**)"
                  end

      # Marshalling return value using ptrcall macros
      if is_ret_enum
        io.puts "      godot_ptrcall_enum(@@mb_#{clean_var_name}, #{target_ptr}, #{args_expr}, #{ret_type_crystal})"
      elsif ret_type_crystal == "Void"
        io.puts "      godot_ptrcall_void(@@mb_#{clean_var_name}, #{target_ptr}, #{args_expr})"
      elsif ret_type_crystal == "Bool"
        io.puts "      godot_ptrcall_bool(@@mb_#{clean_var_name}, #{target_ptr}, #{args_expr})"
      elsif ret_type_crystal == "Int64" || ret_type_crystal == "Int32"
        io.puts "      godot_ptrcall_int(@@mb_#{clean_var_name}, #{target_ptr}, #{args_expr})"
      elsif ret_type_crystal == "Float64" || ret_type_crystal == "Float32"
        io.puts "      godot_ptrcall_float(@@mb_#{clean_var_name}, #{target_ptr}, #{args_expr})"
      elsif ["Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i", "Color", "Rect2", "Rect2i", "Transform2D", "Transform3D", "Basis", "Quaternion", "Plane", "AABB"].includes?(ret_type_crystal)
        io.puts "      godot_ptrcall_val(@@mb_#{clean_var_name}, #{target_ptr}, #{args_expr}, #{ret_type_crystal})"
      elsif ret_type_crystal == "Void*" || ret_type_crystal == "Pointer(Void)"
        if ret_type_godot == "Variant"
          io.puts "      ret_var = StaticArray(UInt8, 24).new(0_u8)"
          io.puts "      godot_ptrcall(@@mb_#{clean_var_name}, #{target_ptr}, #{args_expr}, ret_var.to_unsafe.as(Void*))"
          io.puts "      ret_ptr = Pointer(Void).null"
          io.puts "      Bridge.type_from_variant(24, pointerof(ret_ptr).as(Void*), ret_var.to_unsafe.as(Void*))"
          io.puts "      ret_ptr"
        elsif ret_type_godot.starts_with?("Packed") || ["Callable", "Signal"].includes?(ret_type_godot)
          io.puts "      ret_buf = StaticArray(Pointer(Void), 2).new(Pointer(Void).null)"
          io.puts "      godot_ptrcall(@@mb_#{clean_var_name}, #{target_ptr}, #{args_expr}, ret_buf.to_unsafe.as(Void*))"
          io.puts "      ret_buf[0].null? ? ret_buf[1] : ret_buf[0]"
        else
          io.puts "      ret_ptr = Pointer(Void).null"
          io.puts "      godot_ptrcall(@@mb_#{clean_var_name}, #{target_ptr}, #{args_expr}, pointerof(ret_ptr).as(Void*))"
          io.puts "      ret_ptr"
        end
      elsif ret_type_crystal == "String"
        args_str = arg_names.empty? ? "" : ", #{arg_names.join(", ")}"
        if is_static
          io.puts "      godot_static_call_str(\"#{m_name}\"#{args_str})"
        else
          io.puts "      godot_call_str(\"#{m_name}\"#{args_str})"
        end
      elsif ret_type_crystal == "NodePath"
        args_str = arg_names.empty? ? "" : ", #{arg_names.join(", ")}"
        if is_static
          io.puts "      NodePath.new(godot_static_call_str(\"#{m_name}\"#{args_str}))"
        else
          io.puts "      NodePath.new(godot_call_str(\"#{m_name}\"#{args_str}))"
        end
      else
        io.puts "      godot_ptrcall_obj(@@mb_#{clean_var_name}, #{target_ptr}, #{args_expr}, #{ret_type_crystal})"
      end

      if !cleanups.empty?
        io.puts "    ensure"
        cleanups.each do |c|
          io.puts "      #{c}"
        end
      end

      io.puts "    end\n"

      if is_static
        io.puts "    # Instance convenience delegator for static method `#{sanitized_m_name}`"
        io.puts "    def #{sanitized_m_name}(#{arg_defs.join(", ")}) : #{ret_type_crystal}"
        io.puts "      self.class.#{sanitized_m_name}(#{arg_names.join(", ")})"
        io.puts "    end\n"
      end

      if sanitized_m_name != m_name && m_name == "begin" && !args.empty?
        io.puts "    def begin(#{arg_defs.join(", ")}) : #{ret_type_crystal}"
        io.puts "      begin_val(#{arg_names.join(", ")})"
        io.puts "    end\n"
      end

      # Automatic predicate syntactic sugar (? alias) for all methods returning Bool
      if ret_type_crystal == "Bool"
        pred_candidates = [] of String
        pred_candidates << "#{sanitized_m_name}?" unless sanitized_m_name.ends_with?('?')

        if sanitized_m_name.starts_with?("is_")
          stripped = sanitized_m_name.sub(/^is_/, "")
          pred_candidates << "#{stripped}?" if !stripped.empty? && !stripped.starts_with?(/[0-9]/)
        elsif sanitized_m_name.starts_with?("are_")
          stripped = sanitized_m_name.sub(/^are_/, "")
          pred_candidates << "#{stripped}?" if !stripped.empty? && !stripped.starts_with?(/[0-9]/)
        end

        if extra_aliases = predicate_aliases[m_name]?
          extra_aliases.each do |alias_name|
            pred_candidates << (alias_name.ends_with?('?') ? alias_name : "#{alias_name}?")
          end
        end

        pred_candidates.each do |pred_name|
          pred_sig = "#{method_prefix}#{pred_name}"
          next if defined_class_methods.includes?(pred_sig)
          next if class_manuals && class_manuals.includes?(pred_name)

          defined_class_methods.add(pred_sig)
          io.puts "    # Predicate alias for `#{sanitized_m_name}`"
          io.puts "    #{pred_sig}(#{arg_defs.join(", ")}) : Bool"
          if is_static
            io.puts "      self.class.#{sanitized_m_name}(#{arg_names.join(", ")})"
          else
            io.puts "      #{sanitized_m_name}(#{arg_names.join(", ")})"
          end
          io.puts "    end\n"

          if is_static
            inst_pred_sig = "def #{pred_name}"
            if !defined_class_methods.includes?(inst_pred_sig) && !(class_manuals && class_manuals.includes?(pred_name))
              defined_class_methods.add(inst_pred_sig)
              io.puts "    # Instance convenience delegator for static predicate `#{sanitized_m_name}`"
              io.puts "    #{inst_pred_sig}(#{arg_defs.join(", ")}) : Bool"
              io.puts "      self.class.#{pred_name}(#{arg_names.join(", ")})"
              io.puts "    end\n"
            end
          end
        end
      end
    end
  end

  # Properties (Getter/Setter synthesis)
  if props = c["properties"]?.try(&.as_a)
    existing_methods = Set(String).new
    c["methods"]?.try(&.as_a.each { |m| existing_methods.add(sanitize_name(m["name"].as_s, keywords)) })

    props.each do |p|
      raw_p_name = p["name"].as_s
      next if raw_p_name.empty? || raw_p_name.includes?("/")
      clean_p_name = sanitize_name(raw_p_name, keywords)

      # Avoid colliding if a method with the exact same name already exists directly on this class
      next if existing_methods.includes?(clean_p_name) || defined_class_methods.includes?("def #{clean_p_name}")

      raw_setter = p["setter"]?.try(&.as_s) || ""
      raw_getter = p["getter"]?.try(&.as_s) || ""
      index = p["index"]?
      has_index = index && !index.raw.nil? && !index.to_s.empty?
      index_val = has_index ? "#{index}_i64" : ""

      # Resolve getter
      resolved_getter = if all_method_names.includes?(raw_getter)
                          raw_getter
                        elsif raw_getter.starts_with?("_") && all_method_names.includes?(raw_getter.lstrip('_'))
                          raw_getter.lstrip('_')
                        else
                          nil
                        end

      # Resolve setter
      resolved_setter = if all_method_names.includes?(raw_setter)
                          raw_setter
                        elsif raw_setter.starts_with?("_") && all_method_names.includes?(raw_setter.lstrip('_'))
                          raw_setter.lstrip('_')
                        else
                          nil
                        end

      clean_getter = resolved_getter ? sanitize_name(resolved_getter, keywords) : nil
      clean_setter = resolved_setter ? sanitize_name(resolved_setter, keywords) : nil
      p_type = p["type"].as_s

      # Generate Getter
      if clean_getter
        has_manual_getter = class_manuals && (class_manuals.includes?(clean_p_name) || class_manuals.includes?("#{clean_p_name}?"))
        if !has_manual_getter
          io.puts "    # Property `#{raw_p_name}` getter"
          if has_index
            io.puts "    def #{clean_p_name}"
            io.puts "      #{clean_getter}(#{index_val})"
            io.puts "    end\n"
          else
            io.puts "    def #{clean_p_name}"
            io.puts "      #{clean_getter}"
            io.puts "    end\n"
          end
          defined_class_methods.add("def #{clean_p_name}")

          # Boolean predicate alias
          if p_type == "bool" || raw_getter.starts_with?("is_") || raw_getter.starts_with?("has_")
            pred_name = "#{clean_p_name}?"
            pred_sig = "def #{pred_name}"
            if !defined_class_methods.includes?(pred_sig) && !(class_manuals && class_manuals.includes?(pred_name))
              defined_class_methods.add(pred_sig)
              io.puts "    def #{pred_name}"
              io.puts "      #{clean_p_name}"
              io.puts "    end\n"
            end
          end
        end
      end

      # Generate Setter
      if clean_setter
        has_manual_setter = class_manuals && class_manuals.includes?("#{clean_p_name}=")
        if !has_manual_setter
          io.puts "    # Property `#{raw_p_name}` setter"
          if p_type == "float"
            if has_index
              io.puts "    def #{clean_p_name}=(val : Number)"
              io.puts "      #{clean_setter}(#{index_val}, val.to_f64)"
              io.puts "    end\n"
            else
              io.puts "    def #{clean_p_name}=(val : Number)"
              io.puts "      #{clean_setter}(val.to_f64)"
              io.puts "    end\n"
            end
          elsif p_type == "int"
            if has_index
              io.puts "    def #{clean_p_name}=(val : Int)"
              io.puts "      #{clean_setter}(#{index_val}, val.to_i64)"
              io.puts "    end\n"
            else
              io.puts "    def #{clean_p_name}=(val : Int)"
              io.puts "      #{clean_setter}(val.to_i64)"
              io.puts "    end\n"
            end
          else
            if has_index
              io.puts "    def #{clean_p_name}=(val)"
              io.puts "      #{clean_setter}(#{index_val}, val)"
              io.puts "    end\n"
            else
              io.puts "    def #{clean_p_name}=(val)"
              io.puts "      #{clean_setter}(val)"
              io.puts "    end\n"
            end
          end
        end
      end
    end
  end

  # Signals
  if signals = c["signals"]?
    signals.as_a.each do |sig|
      sig_name = sig["name"].as_s
      next if all_method_names.includes?(sig_name)
      clean_sig_name = sanitize_name(sig_name, keywords)
      sig_args = sig["arguments"]?.try(&.as_a) || [] of JSON::Any
      sig_arg_types = sig_args.map do |a|
        t_info = resolve_return_type(a["type"].as_s, name, type_map)
        t_info[:crystal_type]
      end
      if sig_arg_types.empty?
        io.puts "    godot_signal #{clean_sig_name}"
      else
        io.puts "    godot_signal #{clean_sig_name}, #{sig_arg_types.join(", ")}"
      end
    end
  end

  io.puts "  end\n"
end

# Assert that 100% of classes from extension_api.json were sorted
if sorted_classes.size != classes.size
  puts "Error: Sorted classes count (#{sorted_classes.size}) does not match extension_api.json classes count (#{classes.size})!"
  exit 1
end

# Generate modular files in topological dependency order
num_parts = 6
chunk_size = (sorted_classes.size.to_f / num_parts).ceil.to_i
total_chunked = 0

num_parts.times do |part_idx|
  start_idx = part_idx * chunk_size
  end_idx = Math.min((part_idx + 1) * chunk_size, sorted_classes.size)
  part_classes = sorted_classes[start_idx...end_idx]
  total_chunked += part_classes.size
  part_num = part_idx + 1

  puts "Writing src/libgodot/generated/classes/classes_part#{part_num}.cr (#{part_classes.size} classes)..."
  File.open("src/libgodot/generated/classes/classes_part#{part_num}.cr", "w") do |f|
    f.puts "# Generated classes part #{part_num} (in topological order)"
    f.puts "module Godot"
    part_classes.each do |c|
      generate_class_code(f, c, keywords, type_map, class_names, all_method_names, manual_methods, predicate_aliases)
    end
    f.puts "end"
  end
end

if total_chunked != sorted_classes.size
  puts "Error: Total chunked classes (#{total_chunked}) does not match sorted classes (#{sorted_classes.size})!"
  exit 1
end

# Generate master all_classes.cr
File.open("src/libgodot/generated/classes/all_classes.cr", "w") do |f|
  f.puts "# Master index requiring all classes in topological dependency order"
  num_parts.times do |part_idx|
    f.puts "require \"./classes_part#{part_idx + 1}\""
  end
end

puts "=== Binding Generation Complete: #{total_chunked}/#{classes.size} classes verified! ==="
