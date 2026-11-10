require "../../core/env"
require "../../core/logger"
require "../../core/godot_finder"
require "../../core/process_runner"
require "json"
require "file_utils"
require "digest/sha256"

module Lapis
  module Commands
    module Bind
      module Project
        DUMP_SCRIPT_CONTENT = {{ read_file("#{__DIR__}/../../../../api_generator/dump_project_nodes.gd") }}

        SKIP_SCAN_DIRS = Set{"lib", ".godot", ".git", "tools", "bin", "docs", "dist", "benchmarks", "scratch", "examples", "template", "template-addon", "performance", "test"}

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

        CRYSTAL_RESERVED_WORDS = Set{
          "alias", "def", "end", "class", "module", "struct", "enum", "lib", "fun",
          "macro", "in", "out", "begin", "rescue", "ensure", "next", "break", "return",
          "yield", "self", "super", "nil", "true", "false", "abstract", "private",
          "protected", "asm", "forall", "typeof", "sizeof", "instance_sizeof",
          "offsetof", "pointerof", "uninitialized", "with", "verbatim", "when",
          "select", "then", "type", "include", "extend", "require", "case", "if",
          "else", "elsif", "unless", "until", "while", "do", "for", "of", "as",
          "is_a?", "nil?", "responds_to?",
        }

        def self.sanitize_ident(name : String) : String
          clean = name.gsub(/[^a-zA-Z0-9_]/, "_").underscore
          clean = "arg_#{clean}" if clean.starts_with?(/[0-9]/)
          clean = "arg" if clean.empty?
          if mapped = KEYWORDS[clean]?
            mapped
          elsif CRYSTAL_RESERVED_WORDS.includes?(clean)
            "#{clean}_arg"
          else
            clean
          end
        end

        # Recursively finds custom .gd files in a project, skipping build/library/hidden folders.
        def self.find_custom_gd_files(
          dir : Path,
          include_addons : Bool = false,
          out_files : Array(String) = [] of String,
        ) : Array(String)
          return out_files unless Dir.exists?(dir)
          Dir.each_child(dir.to_s) do |entry|
            next if SKIP_SCAN_DIRS.includes?(entry)
            next if !include_addons && entry == "addons"
            child = dir.join(entry)
            info = File.info?(child.to_s, follow_symlinks: false)
            next unless info
            next if info.symlink?
            if info.directory?
              find_custom_gd_files(child, include_addons, out_files)
            elsif entry.ends_with?(".gd") && entry != "dump_project_nodes.gd"
              out_files << child.to_s
            end
          end
          out_files
        rescue
          out_files
        end

        # Extracts only ClassDB/GDScript interface declarations (class_name, extends, @export,
        # top-level var/const/enum/signal, and func headers) so editing function bodies
        # inside a .gd script does not trigger unnecessary headless Godot rebinding.
        def self.extract_gd_interface_signature(file_path : Path) : String
          extract_gd_interface_signature(file_path.to_s)
        end

        def self.extract_gd_interface_signature(file_path : String) : String
          return "" unless File.exists?(file_path)
          String.build do |io|
            pending_export = false
            File.each_line(file_path) do |raw_line|
              # Ignore pure comment lines and blank lines
              stripped = raw_line.strip
              next if stripped.empty? || stripped.starts_with?("#")

              # Check if line is top-level (no leading indentation) or a class/func/signal/export declaration
              is_top_level = !(raw_line.starts_with?(" ") || raw_line.starts_with?("\t"))

              if stripped.starts_with?("class_name ") ||
                 stripped.starts_with?("extends ") ||
                 stripped.starts_with?("signal ") ||
                 stripped.starts_with?("func ") ||
                 stripped.starts_with?("static func ") ||
                 stripped.starts_with?("@export") ||
                 (is_top_level && (stripped.starts_with?("var ") || stripped.starts_with?("const ") || stripped.starts_with?("enum "))) ||
                 (pending_export && stripped.starts_with?("var "))
                # Strip trailing inline comment outside strings for deterministic signature comparison
                clean_sig = stripped.sub(/\s+#.*$/, "")
                io << clean_sig << "\n"
                pending_export = stripped.starts_with?("@export") && !stripped.includes?("var ")
              else
                pending_export = false
              end
            end
          end
        rescue
          ""
        end

        # Computes a deterministic SHA-256 digest of all project GDScript interface signatures
        # and non-Crystal GDExtension addon manifests.
        def self.compute_interface_digest(proj_dir : Path, include_addons : Bool = false) : String
          gd_files = find_custom_gd_files(proj_dir, include_addons).sort!
          Digest::SHA256.hexdigest do |ctx|
            ctx.update("v1|include_addons=#{include_addons}\n")
            gd_files.each do |gd_file|
              rel = Path.new(gd_file).relative_to(proj_dir).to_s.gsub('\\', '/') rescue gd_file
              ctx.update("gd:#{rel}\n")
              ctx.update(extract_gd_interface_signature(gd_file))
              ctx.update("\n")
            end

            # Also track non-Crystal .gdextension manifests in addons/ if present
            addons_dir = proj_dir.join("addons")
            if Dir.exists?(addons_dir)
              Dir.glob(addons_dir.to_s.gsub('\\', '/') + "/**/*.gdextension").sort!.each do |ext_file|
                next if ext_file.includes?("crystal_integration")
                addon_dir = Path.new(ext_file).parent
                # If addon has Crystal sources or a shard.yml, its classes are already filtered via local_crystal_classes
                next if File.exists?(addon_dir.join("shard.yml")) || Dir.exists?(addon_dir.join("src"))
                rel_ext = Path.new(ext_file).relative_to(proj_dir).to_s.gsub('\\', '/') rescue ext_file
                mtime = File.info?(ext_file).try(&.modification_time.to_unix_ms) || 0_i64
                ctx.update("ext:#{rel_ext}:#{mtime}\n")
              end
            end
          end
        end

        # Checks whether generated project bindings are already up to date with current ClassDB/GDScript signatures.
        def self.up_to_date?(
          proj_dir : Path,
          out_dir : Path? = nil,
          out_json : Path? = nil,
          include_addons : Bool = false,
        ) : Bool
          resolved_json = (out_json || proj_dir.join("src/generated/project_nodes.json")).expand
          resolved_dir = (out_dir || proj_dir.join("src/generated/project_nodes")).expand
          manifest_cr = resolved_dir.join("all_project_nodes.cr")
          bind_state = resolved_dir.join(".bind_manifest.json")

          return false unless File.exists?(manifest_cr)

          current_digest = compute_interface_digest(proj_dir, include_addons)

          if File.exists?(bind_state)
            begin
              state = ::JSON.parse(File.read(bind_state))
              saved_digest = state["digest"]?.try(&.as_s)
              return saved_digest == current_digest if saved_digest
            rescue
            end
          end

          # Migration / pre-existing bindings check: if all_project_nodes.cr already exists on disk
          # and is at least as new as every custom .gd file in the project, seed .bind_manifest.json and treat as up to date.
          if File.exists?(resolved_json)
            begin
              manifest_mtime = File.info(manifest_cr).modification_time
              gd_files = find_custom_gd_files(proj_dir, include_addons)
              if gd_files.none? { |f| (File.info?(f).try(&.modification_time) || ::Time.utc) > manifest_mtime }
                save_bind_manifest(resolved_dir, current_digest, 0)
                return true
              end
            rescue
            end
          end

          false
        end

        private def self.write_if_changed(path : Path, content : String) : Bool
          if File.exists?(path)
            existing = File.read(path) rescue nil
            return false if existing == content
          end
          FileUtils.mkdir_p(path.parent) unless Dir.exists?(path.parent)
          File.write(path, content)
          true
        end

        private def self.save_bind_manifest(out_dir : Path, digest : String, node_count : Int32) : Nil
          FileUtils.mkdir_p(out_dir) unless Dir.exists?(out_dir)
          manifest_file = out_dir.join(".bind_manifest.json")
          payload = {
            "version"    => 1,
            "digest"     => digest,
            "node_count" => node_count,
          }.to_json
          write_if_changed(manifest_file, payload)
        rescue
        end

        private def self.resolve_crystal_return_type(type_id : Int64, class_name : String?) : String
          if type_id == 24 && !class_name.nil? && !class_name.empty? && !class_name.includes?(".")
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
          if type_id == 24 && !class_name.nil? && !class_name.empty? && !class_name.includes?(".")
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
          include_addons : Bool = false,
          force : Bool = false,
        ) : Int32
          proj_dir = (project_path || Path.new(Dir.current)).expand
          out_json = (json_path || proj_dir.join("src/generated/project_nodes.json")).expand
          out_dir = (output_dir || proj_dir.join("src/generated/project_nodes")).expand

          current_digest = compute_interface_digest(proj_dir, include_addons)

          # Fast path 1: If bindings and manifest exist and ClassDB/GDScript signatures haven't changed, skip!
          if !force && up_to_date?(proj_dir, out_dir, out_json, include_addons)
            Core::Logger.debug("Project node bindings up to date for #{proj_dir.basename} (ClassDB/GDScript signatures unchanged).")
            return 0
          end

          FileUtils.mkdir_p(out_json.parent)
          FileUtils.mkdir_p(out_dir)

          # Fast path 2: If project has zero custom .gd files and no external non-Crystal GDExtension plugins,
          # we do not need to boot headless Godot to know that zero GDScript wrappers are needed.
          gd_files = find_custom_gd_files(proj_dir, include_addons)
          if !force && gd_files.empty?
            write_if_changed(out_json, "{\n  \"gdscript_classes\": [],\n  \"plugin_classes\": []\n}\n") unless File.exists?(out_json)
            manifest_path = out_dir.join("all_project_nodes.cr")
            write_if_changed(manifest_path, "# Generated All Project Custom Nodes Manifest\n")
            save_bind_manifest(out_dir, current_digest, 0)
            Core::Logger.debug("No custom GDScript files in #{proj_dir.basename}; skipped headless Godot node dump.")
            return 0
          end

          # Determine scripts directory and ensure dump_project_nodes.gd exists
          scripts_dir = proj_dir.join("scripts")
          FileUtils.mkdir_p(scripts_dir)
          dump_script = scripts_dir.join("dump_project_nodes.gd")
          is_engine_repo = File.exists?(proj_dir.join("tools/api_generator/dump_project_nodes.gd"))
          dump_script_created = false

          if !is_engine_repo || !File.exists?(dump_script)
            File.write(dump_script, DUMP_SCRIPT_CONTENT)
            dump_script_created = !is_engine_repo
          end

          godot_exe = Core::GodotFinder.resolve(project_dir: proj_dir.to_s)
          if godot_exe.nil?
            Core::Logger.error("Godot executable not found to dump project custom nodes!")
            return 1
          end

          # 1. Run headless Godot dump
          Core::Logger.step("Bind:Project", "Dumping custom nodes for #{proj_dir.basename}...")
          rel_json = out_json.relative_to(proj_dir).to_s.gsub('\\', '/')

          begin
            dump_args = ["--headless", "--path", proj_dir.to_s, "-s", "res://scripts/dump_project_nodes.gd", "--", "--output", rel_json]
            dump_args << "--include-addons" if include_addons
            Core::ProcessRunner.run(
              godot_exe,
              dump_args,
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

          generate_wrappers_from_json(proj_dir, out_json, out_dir, include_addons, current_digest)
        end

        def self.generate_wrappers_from_json(
          proj_dir : Path,
          out_json : Path,
          out_dir : Path,
          include_addons : Bool = false,
          current_digest : String = "",
        ) : Int32
          # 2. Parse JSON and generate wrapper classes in memory (write-if-changed to preserve mtimes)
          Core::Logger.step("Bind:Project", "Generating typed Crystal wrappers -> #{out_dir}...")
          data = ::JSON.parse(File.read(out_json))

          generated_files = [] of String
          new_file_contents = Hash(String, String).new
          parent_map = Hash(String, String?).new
          custom_class_names = Set(String).new

          # Scan project's own Crystal source files (and installed Crystal shards/addons) to exclude classes already defined in Crystal
          local_crystal_classes = Set(String).new
          Dir.glob(proj_dir.to_s.gsub('\\', '/') + "/**/*.cr").each do |cr_file|
            next if cr_file.includes?("/generated/") || cr_file.includes?("\\generated\\") ||
                    cr_file.includes?("/lib/lapis/") || cr_file.includes?("\\lib\\lapis\\") ||
                    cr_file.includes?("/.godot/") || cr_file.includes?("\\.godot\\") ||
                    cr_file.includes?("/scratch/") || cr_file.includes?("\\scratch\\") ||
                    cr_file.includes?("/bin/") || cr_file.includes?("\\bin\\") ||
                    cr_file.includes?("/godot-src/") || cr_file.includes?("\\godot-src\\")
            begin
              File.each_line(cr_file) do |line|
                if line =~ /^\s*(?:node|node2d|node3d|resource|gdclass|class|struct)\s+([A-Za-z0-9_]+)/
                  local_crystal_classes << $1
                end
              end
            rescue
            end
          end

          # Combine both gdscript_classes and plugin_classes from GDExtensions
          all_classes = [] of ::JSON::Any
          if g_classes = data["gdscript_classes"]?.try(&.as_a)
            all_classes.concat(g_classes)
          end
          if p_classes = data["plugin_classes"]?.try(&.as_a)
            all_classes.concat(p_classes)
          end

          # Filter out locally defined classes, dummy test addons, and test runners (and addons/ unless include_addons)
          filtered_classes = all_classes.reject do |c|
            raw_name = c["name"]?.try(&.as_s) || ""
            clean = raw_name.gsub(/[^a-zA-Z0-9_]/, "")
            script_path = c["path"]?.try(&.as_s) || ""
            inherits_str = c["inherits"]?.try(&.as_s) || ""
            has_class_name = c["has_class_name"]?.try(&.as_bool) != false
            is_cli_script = (inherits_str == "SceneTree" || inherits_str == "MainLoop") && !has_class_name
            is_addon_script = script_path.starts_with?("res://addons/") || script_path.includes?("/addons/") || script_path.starts_with?("addons/")
            clean.empty? ||
              is_cli_script ||
              (!include_addons && is_addon_script) ||
              local_crystal_classes.includes?(clean) ||
              clean.starts_with?("Dummy") ||
              clean.starts_with?("TestRunner") ||
              clean.starts_with?("ToolTester") ||
              clean == "RunTesterPanel"
          end

          filtered_classes.each do |c|
            if raw_name = c["name"]?.try(&.as_s)
              clean = raw_name.gsub(/[^a-zA-Z0-9_]/, "")
              custom_class_names << clean unless clean.empty?
            end
          end

          filtered_classes.each do |c|
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
            generated_files << file_basename
            parent_map[file_basename] = is_custom_parent ? "#{clean_inherits.underscore}.cr" : nil

            wrapper_content = String.build do |io|
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

              method_names = Set(String).new
              if methods = c["methods"]?.try(&.as_a)
                methods.each do |m|
                  m_name = m["name"]?.try(&.as_s) || ""
                  next if m_name.empty? || m_name.starts_with?("@") || m_name == "get" || m_name == "set"
                  method_names << sanitize_ident(m_name)
                end
              end

              # Properties
              emitted_props = Set(String).new
              if props = c["properties"]?.try(&.as_a)
                props.each do |p|
                  prop_name = p["name"]?.try(&.as_s) || ""
                  next if prop_name.empty? || prop_name.starts_with?("@")
                  prop_type_id = p["type"]?.try(&.as_i64) || 0_i64
                  prop_usage = p["usage"]?.try(&.as_i64) || 0_i64
                  next if prop_type_id == 0_i64 || (prop_usage & (64_i64 | 128_i64 | 256_i64)) != 0_i64
                  prop_class = p["class_name"]?.try(&.as_s)
                  c_type = resolve_crystal_return_type(prop_type_id, prop_class)
                  clean_getter = sanitize_ident(prop_name)
                  next if method_names.includes?(clean_getter) || emitted_props.includes?(clean_getter)
                  emitted_props << clean_getter
                  clean_setter = "#{clean_getter}="

                  io.puts "    # Property `#{prop_name}` (#{c_type})"
                  case prop_type_id
                  when 1
                    io.puts "    def #{clean_getter} : Bool\n      call_bool(\"get\", \"#{prop_name}\")\n    end"
                  when 2
                    if c_type != "Int64" && c_type.ends_with?("?")
                      base_t = c_type.rstrip('?')
                      io.puts "    def #{clean_getter} : #{c_type}\n      #{base_t}.from_value?(call_i64(\"get\", \"#{prop_name}\"))\n    end"
                    else
                      io.puts "    def #{clean_getter} : Int64\n      call_i64(\"get\", \"#{prop_name}\")\n    end"
                    end
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
              emitted_methods = Set(String).new
              if methods = c["methods"]?.try(&.as_a)
                methods.each do |m|
                  m_name = m["name"]?.try(&.as_s) || ""
                  next if m_name.empty? || m_name.starts_with?("@") || m_name == "get" || m_name == "set"
                  clean_m_name = sanitize_ident(m_name)
                  next if emitted_methods.includes?(clean_m_name)
                  emitted_methods << clean_m_name
                  ret_type_id = m["return_type"]?.try(&.as_i64) || 0_i64
                  ret_class = m["return_class_name"]?.try(&.as_s)
                  ret_c_type = resolve_crystal_return_type(ret_type_id, ret_class)

                  args_entries = m["args"]?.try(&.as_a) || [] of ::JSON::Any
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
                    if ret_c_type != "Int64" && ret_c_type.ends_with?("?")
                      base_t = ret_c_type.rstrip('?')
                      io.puts "      #{base_t}.from_value?(call_i64(\"#{m_name}\"#{args_pass_str}))"
                    else
                      io.puts "      call_i64(\"#{m_name}\"#{args_pass_str})"
                    end
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
              reserved_types = Set{"Array", "Hash", "String", "Int32", "Float64", "Object", "Class", "Module", "Enum", "Struct", "Nil", "Bool", "Pointer", "Tuple", "NamedTuple"}
              unless reserved_types.includes?(clean_class_name)
                io.puts "alias #{clean_class_name} = Godot::#{clean_class_name}"
              end
            end

            new_file_contents[file_basename] = wrapper_content
          end

          # 3. Manifest (all_project_nodes.cr)
          ordered_files = [] of String
          visited = Set(String).new
          visiting = Set(String).new

          generated_files.sort.each do |f|
            add_with_parents(f, parent_map, visited, visiting, ordered_files)
          end

          manifest_content = String.build do |io|
            io.puts "# Generated All Project Custom Nodes Manifest"
            ordered_files.each do |f|
              io.puts "require \"./#{f}\""
            end
          end
          new_file_contents["all_project_nodes.cr"] = manifest_content

          # 4. Remove stale .cr files that are no longer part of generated_files
          if Dir.exists?(out_dir)
            Dir.each_child(out_dir) do |entry|
              next if entry == ".bind_manifest.json"
              path = out_dir.join(entry)
              if File.file?(path) && entry.ends_with?(".cr") && !new_file_contents.has_key?(entry)
                File.delete(path) rescue nil
              elsif Dir.exists?(path)
                FileUtils.rm_rf(path) rescue nil
              end
            end
          end

          # 5. Write only modified .cr files and format only if changes occurred
          changed_paths = [] of String
          new_file_contents.each do |fname, content|
            target_path = out_dir.join(fname)
            if write_if_changed(target_path, content)
              changed_paths << target_path.to_s
            end
          end

          if !changed_paths.empty? && !generated_files.empty?
            Process.run("crystal", ["tool", "format", out_dir.to_s]) rescue nil
          end

          save_bind_manifest(out_dir, current_digest, generated_files.size)

          Core::Logger.success("Project bindings generated successfully (#{generated_files.size} nodes) in #{out_dir}!")
          0
        end
      end
    end
  end
end
