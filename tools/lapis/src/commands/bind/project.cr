require "../../core/env"
require "../../core/logger"
require "../../core/godot_finder"
require "../../core/process_runner"
require "json"
require "file_utils"

module Lapis
  module Commands
    module Bind
      module Project
        DUMP_SCRIPT_CONTENT = {{ read_file("#{__DIR__}/../../../../api_generator/dump_project_nodes.gd") }}

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

        private def self.sanitize_ident(name : String) : String
          clean = name.gsub(/[^a-zA-Z0-9_]/, "_").underscore
          clean = "arg_#{clean}" if clean.starts_with?(/[0-9]/)
          clean = "arg" if clean.empty?
          KEYWORDS[clean]? || clean
        end

        private def self.resolve_crystal_return_type(type_id : Int64, class_name : String?) : String
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

        private def self.resolve_crystal_param_type(type_id : Int64, class_name : String?) : String?
          if !class_name.nil? && !class_name.empty?
            clean_class = class_name.gsub(/[^a-zA-Z0-9_]/, "")
            if clean_class.starts_with?("Godot::")
              return clean_class
            else
              return "Godot::#{clean_class}"
            end
          end

          return nil if type_id == 0
          VARIANT_TYPE_MAP[type_id]?
        end

        private def self.add_with_parents(
          file : String,
          parent_map : Hash(String, String?),
          visited : Set(String),
          visiting : Set(String),
          ordered_files : Array(String),
        ) : Nil
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

        def self.generate(
          project_path : Path? = nil,
          output_dir : Path? = nil,
          json_path : Path? = nil,
        ) : Int32
          root = Core::Env::ROOT_DIR
          proj_dir = (project_path || Path.new(Dir.current)).expand

          # Determine scripts directory and ensure dump_project_nodes.gd exists
          scripts_dir = proj_dir.join("scripts")
          FileUtils.mkdir_p(scripts_dir)
          dump_script = scripts_dir.join("dump_project_nodes.gd")
          dump_script_created = false

          unless File.exists?(dump_script)
            File.write(dump_script, DUMP_SCRIPT_CONTENT)
            dump_script_created = true
          end

          godot_exe = Core::GodotFinder.resolve
          if godot_exe.nil?
            Core::Logger.error("Godot executable not found to dump project custom nodes!")
            return 1
          end

          out_json = (json_path || proj_dir.join("src/generated/project_nodes.json")).expand
          out_dir = (output_dir || proj_dir.join("src/generated/project_nodes")).expand
          FileUtils.mkdir_p(out_json.parent)
          FileUtils.mkdir_p(out_dir)

          # 1. Run headless Godot dump
          Core::Logger.step("Bind:Project", "Dumping custom nodes for #{proj_dir.basename}...")
          rel_json = out_json.relative_to(proj_dir).to_s.gsub('\\', '/')

          begin
            res = Core::ProcessRunner.run(
              godot_exe,
              ["--headless", "--path", proj_dir.to_s, "-s", "res://scripts/dump_project_nodes.gd", "--", "--output", rel_json],
              chdir: proj_dir.to_s,
              env: {"GODOT_HEADLESS" => "1"}
            )
          ensure
            if dump_script_created && File.exists?(dump_script)
              File.delete(dump_script)
              if Dir.empty?(scripts_dir)
                Dir.delete(scripts_dir) rescue nil
              end
            end
          end

          unless File.exists?(out_json)
            Core::Logger.error("Failed to generate #{out_json}")
            return 1
          end

          # 2. Clean existing generated files in out_dir
          if Dir.exists?(out_dir)
            Dir.each_child(out_dir) do |entry|
              path = out_dir.join(entry)
              if File.file?(path)
                File.delete(path)
              elsif Dir.exists?(path)
                FileUtils.rm_rf(path)
              end
            end
          end

          # 3. Parse JSON and generate wrapper classes
          Core::Logger.step("Bind:Project", "Generating typed Crystal wrappers -> #{out_dir}...")
          data = JSON.parse(File.read(out_json))

          generated_files = [] of String
          parent_map = Hash(String, String?).new
          custom_class_names = Set(String).new

          if gdscript_classes = data["gdscript_classes"]?.try(&.as_a)
            gdscript_classes.each do |c|
              if raw_name = c["name"]?.try(&.as_s)
                clean = raw_name.gsub(/[^a-zA-Z0-9_]/, "")
                custom_class_names << clean unless clean.empty?
              end
            end
          end

          if gdscript_classes = data["gdscript_classes"]?.try(&.as_a)
            gdscript_classes.each do |c|
              raw_name = c["name"]?.try(&.as_s) || ""
              clean_class_name = raw_name.gsub(/[^a-zA-Z0-9_]/, "")
              next if clean_class_name.empty?

              inherits_name = c["inherits"]?.try(&.as_s) || "Node"
              clean_inherits = inherits_name.gsub(/[^a-zA-Z0-9_]/, "")
              is_custom_parent = custom_class_names.includes?(clean_inherits)

              inherits_type = if inherits_name.starts_with?("Crystal")
                                "Godot::Node"
                              else
                                inherits_name.starts_with?("Godot::") ? inherits_name : "Godot::#{inherits_name}"
                              end
              script_path = c["path"]?.try(&.as_s) || ""

              file_basename = "#{clean_class_name.underscore}.cr"
              target_path = out_dir.join(file_basename)
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
                io.puts "    def initialize(pointer : Void* = Pointer(Void).null)"
                io.puts "      super(pointer)"
                io.puts "    end\n"
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
                    when 1
                      io.puts "    def #{clean_getter} : Bool\n      call_bool(\"get\", \"#{prop_name}\")\n    end"
                    when 2
                      io.puts "    def #{clean_getter} : Int64\n      call_i64(\"get\", \"#{prop_name}\")\n    end"
                    when 3
                      io.puts "    def #{clean_getter} : Float64\n      call_f64(\"get\", \"#{prop_name}\")\n    end"
                    when 4
                      io.puts "    def #{clean_getter} : String\n      call_str(\"get\", \"#{prop_name}\")\n    end"
                    when 24
                      base_t = c_type.rstrip('?')
                      io.puts "    def #{clean_getter} : #{c_type}\n      call_obj_as(#{base_t}, \"get\", \"#{prop_name}\")\n    end"
                    else
                      io.puts "    def #{clean_getter} : String\n      call_str(\"get\", \"#{prop_name}\")\n    end"
                    end

                    io.puts "    def #{clean_setter}(val) : Void\n      call(\"set\", \"#{prop_name}\", val)\n    end\n"
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
                    when 0
                      io.puts "      call(\"#{m_name}\"#{args_pass_str})\n      nil"
                    when 1
                      io.puts "      call_bool(\"#{m_name}\"#{args_pass_str})"
                    when 2
                      io.puts "      call_i64(\"#{m_name}\"#{args_pass_str})"
                    when 3
                      io.puts "      call_f64(\"#{m_name}\"#{args_pass_str})"
                    when 4
                      io.puts "      call_str(\"#{m_name}\"#{args_pass_str})"
                    when 24
                      base_t = ret_c_type.rstrip('?')
                      io.puts "      call_obj_as(#{base_t}, \"#{m_name}\"#{args_pass_str})"
                    else
                      io.puts "      call(\"#{m_name}\"#{args_pass_str})\n      nil"
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

          # 4. Manifest (all_project_nodes.cr)
          ordered_files = [] of String
          visited = Set(String).new
          visiting = Set(String).new

          generated_files.sort.each do |f|
            add_with_parents(f, parent_map, visited, visiting, ordered_files)
          end

          manifest_path = out_dir.join("all_project_nodes.cr")
          File.open(manifest_path, "w") do |io|
            io.puts "# Generated All Project Custom Nodes Manifest"
            ordered_files.each do |f|
              io.puts "require \"./#{f}\""
            end
          end

          # Automatically format generated wrappers using crystal tool format
          Process.run("crystal", ["tool", "format", out_dir.to_s]) rescue nil

          Core::Logger.success("Project bindings generated successfully (#{generated_files.size} nodes) in #{out_dir}!")
          0
        end
      end
    end
  end
end
