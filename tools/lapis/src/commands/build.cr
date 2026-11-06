require "../core/env"
require "../core/logger"
require "../core/text"
require "../core/process_runner"
require "../core/godot_finder"
require "../core/baked_file_system"
require "./bind/project"
require "./sync"
require "file_utils"
require "option_parser"
require "digest/sha256"
require "json"

module Lapis
  module Commands
    module Build
      SKIP_GD_SCAN_DIRS = Bind::Project::SKIP_SCAN_DIRS
      SKIP_CR_SCAN_DIRS = Set{".godot", ".git", "bin", "docs", "dist", "scratch"}

      @@cached_base_crystal_path : String? = nil

      def self.base_crystal_path : String
        if cached = @@cached_base_crystal_path
          return cached
        end
        val = Core::ProcessRunner.capture("crystal", ["env", "CRYSTAL_PATH"])[:output].strip
        @@cached_base_crystal_path = val
        val
      end

      # Recursively scans a directory for .cr files and updates the SHA-256 digest with relative paths, sizes, and mtimes.
      private def self.hash_cr_tree(ctx : Digest::SHA256, base_dir : Path, current_dir : Path = base_dir) : Nil
        return unless Dir.exists?(current_dir)
        entries = Dir.children(current_dir.to_s).sort!
        entries.each do |entry|
          next if SKIP_CR_SCAN_DIRS.includes?(entry)
          child = current_dir.join(entry)
          info = File.info?(child.to_s, follow_symlinks: false)
          next unless info
          next if info.symlink?
          if info.directory?
            hash_cr_tree(ctx, base_dir, child)
          elsif entry.ends_with?(".cr") || entry == "shard.yml" || entry == "shard.lock"
            rel = child.relative_to(base_dir).to_s.gsub('\\', '/') rescue entry
            ctx.update("#{rel}:#{info.size}:#{info.modification_time.to_unix_ms}\n")
          end
        end
      rescue
      end

      # Computes a fast fingerprint of all Crystal sources, shard manifests, and compiler flags affecting a binary build.
      def self.compute_source_digest(
        working_dir : Path,
        entry_path : Path,
        src_dir : Path,
        cmd_args : Array(String),
        full_crystal_path : String,
      ) : String
        Digest::SHA256.hexdigest do |ctx|
          ctx.update("v1|args=#{cmd_args.join(" ")}|cpath=#{full_crystal_path}\n")
          if File.exists?(entry_path)
            if info = File.info?(entry_path.to_s)
              ctx.update("entry:#{info.size}:#{info.modification_time.to_unix_ms}\n")
            end
          end
          ["shard.yml", "shard.lock"].each do |manifest|
            m_path = working_dir.join(manifest)
            if info = File.info?(m_path.to_s)
              ctx.update("#{manifest}:#{info.size}:#{info.modification_time.to_unix_ms}\n")
            end
          end
          hash_cr_tree(ctx, working_dir, working_dir.join("src"))
          hash_cr_tree(ctx, working_dir, working_dir.join("spec"))
          hash_cr_tree(ctx, working_dir, working_dir.join("addons"))
          hash_cr_tree(ctx, working_dir, working_dir.join("lib"))
          if src_dir != working_dir.join("src") && !src_dir.to_s.starts_with?(working_dir.to_s)
            hash_cr_tree(ctx, src_dir, src_dir)
          end
        end
      end

      def self.build_manifest_path(output_path : Path) : Path
        output_path.parent.join(".lapis_build_#{output_path.basename}.json")
      end

      def self.binary_up_to_date?(
        working_dir : Path,
        entry_path : Path,
        output_path : Path,
        cmd_args : Array(String),
        full_crystal_path : String,
      ) : Bool
        digest = compute_source_digest(working_dir, entry_path, working_dir.join("src"), cmd_args, full_crystal_path)
        binary_up_to_date?(output_path, digest)
      end

      def self.binary_up_to_date?(output_path : Path, expected_digest : String) : Bool
        return false unless File.exists?(output_path)
        out_info = File.info?(output_path.to_s)
        return false unless out_info && out_info.size > 0

        manifest_file = build_manifest_path(output_path)
        return false unless File.exists?(manifest_file)

        begin
          data = ::JSON.parse(File.read(manifest_file))
          saved_digest = data["digest"]?.try(&.as_s)
          return false unless saved_digest == expected_digest
          true
        rescue
          false
        end
      end

      def self.save_build_manifest(
        working_dir : Path,
        entry_path : Path,
        output_path : Path,
        cmd_args : Array(String),
        full_crystal_path : String,
      ) : Nil
        digest = compute_source_digest(working_dir, entry_path, working_dir.join("src"), cmd_args, full_crystal_path)
        save_build_manifest(output_path, digest)
      end

      def self.save_build_manifest(output_path : Path, digest : String) : Nil
        return unless File.exists?(output_path)
        manifest_file = build_manifest_path(output_path)
        payload = {
          "version" => 1,
          "output"  => output_path.basename,
          "digest"  => digest,
          "mtime"   => (File.info?(output_path.to_s).try(&.modification_time.to_unix_ms) || 0_i64),
        }.to_json
        File.write(manifest_file, payload)
      rescue
      end

      # Automatically dump and generate project GDScript bindings if project contains custom .gd files
      # whose ClassDB/script interface signatures have changed.
      def self.check_and_generate_project_bindings(entry : Path, root : Path)
        proj_dir = entry.parent
        proj_dir = proj_dir.parent if proj_dir.basename == "src"
        return if proj_dir.to_s.gsub('\\', '/').includes?("/addons/")
        return unless File.exists?(proj_dir.join("project.godot"))

        gd_files = Bind::Project.find_custom_gd_files(proj_dir)
        return if gd_files.empty?

        # Fast signature check: if GDScript interface signatures (class_name, extends, @export, signal, func headers)
        # have not changed since the last bind, skip booting headless Godot!
        return if Bind::Project.up_to_date?(proj_dir)

        # Ensure that if bin/game.dll already exists, addons/crystal_integration/bin/game.dll is synced before Godot boots.
        # If bin/game.dll does not exist yet, remove any stale orphan in addons/crystal_integration/bin.
        bin_game = proj_dir.join("bin", Core::Env.game_file)
        addon_game = proj_dir.join("addons/crystal_integration/bin", Core::Env.game_file)
        if File.exists?(bin_game)
          if Dir.exists?(addon_game.parent)
            Sync.safe_copy(bin_game, addon_game)
            if Core::Env.windows?
              src_pdb = proj_dir.join("bin", "game.pdb")
              dst_pdb = proj_dir.join("addons/crystal_integration/bin", "game.pdb")
              Sync.safe_copy(src_pdb, dst_pdb) if File.exists?(src_pdb)
            end
          end
        elsif File.exists?(addon_game)
          File.delete(addon_game) rescue nil
        end

        Core::Logger.info("Detected modified GDScript interface signatures in #{proj_dir.basename}, generating project bindings...")
        Bind::Project.generate(project_path: proj_dir)
      end

      # Core compilation function for a single Crystal binary
      def self.compile_binary(
        entry_path : Path,
        output_path : Path,
        link_flags : String? = nil,
        flags : String? = nil,
        release : Bool = false,
        source_path : String? = nil,
        single_module : Bool? = nil,
        without_benchmarks : Bool = false,
        force : Bool = false,
      ) : Int32
        root = Core::Env::ROOT_DIR
        FileUtils.mkdir_p(output_path.parent) unless Dir.exists?(output_path.parent)

        check_and_generate_project_bindings(entry_path, root)

        entry_parent = entry_path.parent
        proj_dir = (entry_parent.basename == "src" ? entry_parent.parent : entry_parent)
        host_proj_dir : Path? = (proj_dir.parent.basename == "addons" ? proj_dir.parent.parent : nil)
        proj_lib = proj_dir.join("lib")
        host_lib = host_proj_dir.try(&.join("lib"))

        # Self-heal standalone projects missing embedded lib/lapis, lib/cradare2, or lib/opal
        target_proj_for_libs = host_proj_dir || proj_dir
        target_lib_for_libs = host_lib || proj_lib
        if !Core::BakedFileSystem.engine_libs_present?(target_proj_for_libs) &&
           !Core::Env.is_libgodot_repo?(root) &&
           !Core::Env.is_libgodot_repo?(target_proj_for_libs) &&
           (File.exists?(target_proj_for_libs.join("shard.yml")) || File.exists?(target_proj_for_libs.join("project.godot"))) &&
           Core::BakedFileSystem.files_with_prefix("src").size > 0
          Core::BakedFileSystem.extract_engine_lib(target_lib_for_libs.join("lapis"), overwrite: false)
        end

        src_dir = if sp = source_path
                    Path.new(sp).expand
                  elsif Dir.exists?(proj_lib.join("lapis/src"))
                    proj_lib.join("lapis/src")
                  elsif Dir.exists?(proj_lib.join("libgodot/src"))
                    proj_lib.join("libgodot/src")
                  elsif (hl = host_lib) && Dir.exists?(hl.join("lapis/src"))
                    hl.join("lapis/src")
                  elsif (hl = host_lib) && Dir.exists?(hl.join("libgodot/src"))
                    hl.join("libgodot/src")
                  elsif Dir.exists?(root.join("src")) && (File.exists?(root.join("src/libgodot.cr")) || File.exists?(root.join("src/lapis.cr")))
                    root.join("src")
                  elsif (global = Core::Env.global_libgodot_path) && Dir.exists?(global.join("src"))
                    global.join("src")
                  else
                    root.join("src")
                  end

        path_parts = [src_dir.to_s]
        path_parts << proj_dir.join("src").to_s if Dir.exists?(proj_dir.join("src")) && proj_dir.join("src") != src_dir
        path_parts << proj_dir.join("addons").to_s if Dir.exists?(proj_dir.join("addons"))
        if hp = host_proj_dir
          path_parts << hp.join("addons").to_s if Dir.exists?(hp.join("addons"))
        end
        path_parts << proj_lib.to_s if Dir.exists?(proj_lib)
        if (hl = host_lib) && Dir.exists?(hl) && hl != proj_lib
          path_parts << hl.to_s
        end
        path_parts << root.join("lib").to_s if Dir.exists?(root.join("lib")) && root.join("lib") != proj_lib
        if (global = Core::Env.global_libgodot_path) && Dir.exists?(global.join("lib"))
          glib = global.join("lib")
          path_parts << glib.to_s if glib != proj_lib && glib != root.join("lib")
        end
        path_parts << root.join("addons").to_s if Dir.exists?(root.join("addons"))
        std_cpath = base_crystal_path
        path_parts << std_cpath unless std_cpath.empty?
        full_crystal_path = path_parts.uniq.join(Core::Env.path_sep)

        working_dir = if entry_path.to_s.starts_with?("src/") || entry_path.to_s.starts_with?("src\\")
                        root
                      elsif entry_path.parent.basename == "src"
                        entry_path.parent.parent
                      else
                        entry_path.parent
                      end

        # Normalize entry and output paths relative to working_dir when inside working_dir
        # so CLI builds (`make` / `lapis build`) and Editor builds (`F5`) share the exact same Crystal cache directory.
        norm_entry_arg = begin
          rel_e = entry_path.expand.relative_to(working_dir.expand).to_s.gsub('\\', '/')
          rel_e.starts_with?("../") ? entry_path.to_s : rel_e
        rescue
          entry_path.to_s
        end

        norm_output_arg = begin
          rel_o = output_path.expand.relative_to(working_dir.expand).to_s.gsub('\\', '/')
          rel_o.starts_with?("../") ? output_path.to_s : rel_o
        rescue
          output_path.to_s
        end

        cmd_args = ["build", norm_entry_arg, "-o", norm_output_arg]
        if release
          cmd_args << "--release"
        else
          cmd_args << "--debug"
        end

        cmd_args << "-Dno_benchmarks" if without_benchmarks

        no_log = ENV["NO_LOG"]? == "1"
        log_flag : String? = nil
        if env_log = (ENV["LOG"]? || ENV["LOG_LEVEL"]?)
          log_flag = env_log unless env_log.empty?
        end

        if (fl = flags) && !fl.empty?
          fl.split(' ').each do |f|
            cleaned = f.strip.sub(/^['"]+/, "").sub(/['"]+$/, "")
            no_log = true if cleaned == "--no-log" || cleaned == "-Dno_log"
            if cleaned.starts_with?("--log=") || cleaned.starts_with?("-Dlog=") || cleaned.starts_with?("--log-level=")
              log_flag = cleaned.split('=', 2)[1]
            end
          end
        end

        if no_log
          cmd_args << "-Dno_log" unless cmd_args.includes?("-Dno_log")
        elsif lf = log_flag
          cmd_args << "-Dlog=#{lf}" unless cmd_args.includes?("-Dlog=#{lf}")
        end

        cmd_args << "-Dno_doc" if (ENV["STRIP_DOCS"]? == "1" || ENV["NO_DOC"]? == "1") && !cmd_args.includes?("-Dno_doc")
        cmd_args << "-Dno_thread_safety" if (ENV["NO_THREAD_SAFETY"]? == "1" || ENV["FAST_DISPATCH"]? == "1") && !cmd_args.includes?("-Dno_thread_safety")
        cmd_args << "-Dno_testing" if ENV["NO_TESTING"]? == "1" && !cmd_args.includes?("-Dno_testing")
        cmd_args << "-Dtesting" if ENV["TESTING"]? == "1" && !cmd_args.includes?("-Dtesting")
        cmd_args << "-Dleak_tracker" if (ENV["LEAK_TRACKER"]? == "1" || ENV["TRACE_ALLOCATIONS"]? == "1") && !cmd_args.includes?("-Dleak_tracker")
        cmd_args << "-Dtrace_signals" if (ENV["TRACE_SIGNALS"]? == "1" || ENV["SIGNAL_SPY"]? == "1") && !cmd_args.includes?("-Dtrace_signals")
        cmd_args << "-Dprofile_dispatches" if ENV["PROFILE_DISPATCHES"]? == "1" && !cmd_args.includes?("-Dprofile_dispatches")
        cmd_args << "-Dtrace_dead_pointers" if ENV["TRACE_DEAD_POINTERS"]? == "1" && !cmd_args.includes?("-Dtrace_dead_pointers")
        cmd_args << "-Dno_crash_handler" if ENV["NO_CRASH_HANDLER"]? == "1" && !cmd_args.includes?("-Dno_crash_handler")

        # Determine whether to use --single-module:
        # 1. If explicitly specified via CLI or SINGLE_MODULE env var, respect that choice.
        # 2. Otherwise, only auto-enable for shared libraries on Linux ELF targets where Crystal's '@' symbol
        #    mangling triggers ELF symbol versioning errors in lld/mold.
        #    On Windows (MSVC link.exe) and macOS (ld64), multi-module builds link cleanly, enabling multi-core
        #    LLVM compilation and incremental .o/.obj caching across builds.
        is_shared_lib = [".so", ".dll", ".dylib"].includes?(output_path.extension) ||
                        (link_flags && (link_flags.includes?("-shared") || link_flags.includes?("/DLL") || link_flags.includes?("-dynamiclib")))
        env_single = ENV["SINGLE_MODULE"]?
        should_single_module = if !single_module.nil?
                                 single_module
                               elsif env_single == "1"
                                 true
                               elsif env_single == "0"
                                 false
                               else
                                 Core::Env.linux? && is_shared_lib
                               end

        if should_single_module && !release
          cmd_args << "--single-module"
        end

        effective_link_flags = if (lf = link_flags) && !lf.empty?
                                 lf
                               elsif is_shared_lib
                                 Core::Env.link_flags
                               else
                                 nil
                               end

        if (lf = effective_link_flags) && !lf.empty?
          cleaned_lf = lf.strip.sub(/^['"]+/, "").sub(/['"]+$/, "")
          unless cleaned_lf.empty?
            cmd_args << "--link-flags"
            cmd_args << cleaned_lf
          end
        end

        has_addon_flag = false
        if (fl = flags) && !fl.empty?
          fl.split(' ').each do |f|
            next if f.empty?
            cleaned = f.strip.sub(/^['"]+/, "").sub(/['"]+$/, "")
            next if cleaned.empty?
            if cleaned == "--no-single-module"
              cmd_args.delete("--single-module")
            else
              has_addon_flag = true if cleaned == "-Dlibgodot_addon"
              cmd_args << cleaned
            end
          end
        end

        # Auto-detect if compiling a third-party / redistributable addon binary:
        # If output_path or entry_path resides within an addon folder (and NOT crystal_integration),
        # automatically inject -Dlibgodot_addon to prevent compiling editor integration / language bindings into the addon DLL.
        norm_out = output_path.to_s.gsub('\\', '/')
        norm_entry = entry_path.to_s.gsub('\\', '/')
        is_addon_target = (norm_out.includes?("/addons/") || norm_out.starts_with?("addons/") ||
                           norm_entry.includes?("/addons/") || norm_entry.starts_with?("addons/")) &&
                          !norm_out.includes?("crystal_integration") && !norm_entry.includes?("crystal_integration")

        if is_addon_target && !has_addon_flag && !cmd_args.includes?("-Dlibgodot_addon")
          cmd_args << "-Dlibgodot_addon"
        end

        effective_force = force || ENV["FORCE"]? == "1" || ENV["LAPIS_FORCE_BUILD"]? == "1"
        source_digest = compute_source_digest(working_dir.expand, entry_path.expand, src_dir.expand, cmd_args, full_crystal_path)

        if !effective_force && binary_up_to_date?(output_path.expand, source_digest)
          if output_path.basename == Core::Env.game_file
            addon_bin = working_dir.join("addons/crystal_integration/bin")
            if Dir.exists?(addon_bin)
              Commands::Sync.safe_copy(output_path, addon_bin.join(output_path.basename))
              if Core::Env.windows?
                src_pdb = Path.new(output_path.to_s.sub(/\.dll$/, ".pdb"))
                dst_pdb = addon_bin.join(output_path.basename.to_s.sub(/\.dll$/, ".pdb"))
                Commands::Sync.safe_copy(src_pdb, dst_pdb) if File.exists?(src_pdb)
              end
            end
          end
          Core::Logger.success("#{output_path.basename} is up to date (0.0s — no source changes).")
          return 0
        end

        env = {"CRYSTAL_PATH" => full_crystal_path}

        Core::Logger.step("Build", "Compiling #{output_path.basename}...")
        t0 = Time.instant
        build_log = root.join("log/build.log")
        status = Core::ProcessRunner.run(
          "crystal",
          cmd_args,
          env: env,
          chdir: working_dir.to_s,
          tee_file: build_log
        )
        elapsed = (Time.instant - t0).total_seconds

        if status.success?
          save_build_manifest(output_path.expand, source_digest)
          Core::Logger.success("#{output_path.basename} built successfully in #{elapsed.round(2)}s!")
          # If output is a game library, also sync to addons/crystal_integration/bin if present
          if output_path.basename == Core::Env.game_file
            addon_bin = working_dir.join("addons/crystal_integration/bin")
            if Dir.exists?(addon_bin)
              Commands::Sync.safe_copy(output_path, addon_bin.join(output_path.basename))
              if Core::Env.windows?
                src_pdb = Path.new(output_path.to_s.sub(/\.dll$/, ".pdb"))
                dst_pdb = addon_bin.join(output_path.basename.to_s.sub(/\.dll$/, ".pdb"))
                Commands::Sync.safe_copy(src_pdb, dst_pdb) if File.exists?(src_pdb)
              end
            end
          end
          0
        else
          code = status.normal_exit? ? status.exit_code : -1
          Core::Logger.error("Build failed with exit code #{code} after #{elapsed.round(2)}s")
          code
        end
      end

      def self.topological_sort_addons(names : Array(String), deps_graph : Hash(String, Array(String))) : Array(String)
        sorted = [] of String
        visited = Set(String).new
        visiting = Set(String).new

        names.sort.each do |name|
          visit_addon_node(name, names, deps_graph, visited, visiting, sorted)
        end
        sorted
      end

      private def self.visit_addon_node(
        node : String,
        all_nodes : Array(String),
        deps_graph : Hash(String, Array(String)),
        visited : Set(String),
        visiting : Set(String),
        sorted : Array(String)
      ) : Nil
        return if visited.includes?(node)
        return if visiting.includes?(node)
        visiting.add(node)

        if deps = deps_graph[node]?
          deps.each do |dep|
            visit_addon_node(dep, all_nodes, deps_graph, visited, visiting, sorted) if all_nodes.includes?(dep)
          end
        end

        visiting.delete(node)
        visited.add(node)
        sorted << node
      end

      # Ensures addons/<name>/src/<name>.cr exists if addons/<name>/src/main.cr exists,
      # allowing game code to `require "<name>"` directly from CRYSTAL_PATH.
      # Also sanitizes unguarded `require "../spec/editor/**"` in `src/main.cr` when
      # `addons/<name>/spec/editor` does not exist so source-installed addons compile cleanly.
      def self.ensure_addon_library_entrypoint(addon_dir : Path, addon_name : String = addon_dir.basename) : Void
        src_dir = addon_dir.join("src")
        main_cr = src_dir.join("main.cr")
        lib_cr = src_dir.join("#{addon_name}.cr")
        if File.exists?(main_cr)
          if !Dir.exists?(addon_dir.join("spec/editor"))
            content = File.read(main_cr)
            if content =~ /^\s*require\s+"\.\.\/spec\/editor\/\*\*"/m
              sanitized = content.gsub(/^(\s*)require\s+"\.\.\/spec\/editor\/\*\*"/m, "\\1# require \"../spec/editor/**\" # omitted when installed as addon without spec/editor")
              File.write(main_cr, sanitized) if sanitized != content
            end
          end
          if !File.exists?(lib_cr)
            File.write(lib_cr, "require \"./main\"\n")
          end
        end
      rescue
      end

      # Compiles a single source-included addon in `addons/<name>` (`src/main.cr` -> `bin/<name>.dll`)
      def self.compile_addon_dir(
        addon_dir : Path,
        proj_dir : Path? = nil,
        release : Bool = false,
        force : Bool = false,
      ) : Int32
        name = addon_dir.basename
        main_cr = addon_dir.join("src/main.cr")
        return 0 unless File.exists?(main_cr)

        ensure_addon_library_entrypoint(addon_dir, name)

        ext = Core::Env.dll_ext
        link_flags = Core::Env.link_flags
        bin_dir = addon_dir.join("bin")
        FileUtils.mkdir_p(bin_dir) unless Dir.exists?(bin_dir)
        out_lib = bin_dir.join("#{name}.#{ext}")

        Core::Logger.step("DummyAddon", "Compiling #{name} -> #{out_lib.basename}...")
        code = compile_binary(
          entry_path: main_cr,
          output_path: out_lib,
          link_flags: link_flags,
          flags: "-Dlibgodot_addon",
          release: release,
          force: force
        )
        return code if code != 0

        # If bin/game.<ext> also exists (e.g. from precompiled release or macOS .gdextension), sync it so both match
        game_lib = bin_dir.join(Core::Env.game_file)
        if File.exists?(game_lib) && game_lib != out_lib
          Commands::Sync.safe_copy(out_lib, game_lib)
          if Core::Env.windows?
            src_pdb = Path.new(out_lib.to_s.sub(/\.dll$/, ".pdb"))
            dst_pdb = bin_dir.join("game.pdb")
            Commands::Sync.safe_copy(src_pdb, dst_pdb) if File.exists?(src_pdb)
          end
        end
        0
      end

      def self.build_addons(args : Array(String)) : Int32
        release = false
        force = false
        proj_path : String? = nil
        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis build addons [options]"
          opts.on("-p PATH", "--path=PATH", "Game project directory (default: current project)") { |v| proj_path = v }
          opts.on("-r", "--release", "Compile in release mode with optimizations") { release = true }
          opts.on("-F", "--force", "Force rebuild even if sources are unchanged") { force = true }
          opts.on("-h", "--help", "Show help") do
            puts opts
            exit 0
          end
        end
        parser.parse(args)

        root = Core::Env::ROOT_DIR
        curr = Path.new(Dir.current).expand
        proj_dir = if (pp = proj_path) && !pp.empty?
                     Path.new(pp).expand
                   elsif (nearest = Core::Env.find_project_dir(curr)) && Dir.exists?(nearest.join("addons"))
                     nearest
                   elsif Dir.exists?(curr.join("addons"))
                     curr
                   else
                     root
                   end

        test_addons = Dir.exists?(proj_dir.join("addons")) ? proj_dir.join("addons") : proj_dir.join("test/addons")
        return 0 unless Dir.exists?(test_addons)

        # Discover candidate addons to compile
        candidate_names = Dir.children(test_addons).select do |name|
          next false if name == "crystal_integration"
          addon_dir = test_addons.join(name)
          Dir.exists?(addon_dir) && File.exists?(addon_dir.join("src/main.cr"))
        end

        # Read dependency graph from plugin.cfg / shard.yml
        deps_graph = Hash(String, Array(String)).new { |h, k| h[k] = [] of String }
        candidate_names.each do |name|
          cfg = test_addons.join(name, "plugin.cfg")
          if File.exists?(cfg)
            File.each_line(cfg) do |line|
              if line.strip =~ /dependencies\s*=\s*\[(.*)\]/
                $1.scan(/["']([^"']+)["']/) do |m|
                  dep_name = m[1].strip
                  deps_graph[name] << dep_name if candidate_names.includes?(dep_name)
                end
              end
            end
          end
        end

        # Topologically sort so base dependencies compile before dependent plugins
        sorted_names = topological_sort_addons(candidate_names, deps_graph)

        failed = 0
        sorted_names.each do |name|
          addon_dir = test_addons.join(name)
          code = compile_addon_dir(addon_dir, proj_dir, release: release, force: force)
          failed += 1 if code != 0
        end

        if failed == 0
          Core::Logger.success("All test addons built successfully!")
          0
        else
          Core::Logger.error("#{failed} addon(s) failed to build.")
          1
        end
      end

      def self.build_examples(args : Array(String)) : Int32
        release = false
        exe = false
        force = false

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis build examples [options]"
          opts.on("-r", "--release", "Compile in release mode with optimizations") { release = true }
          opts.on("-x", "--exe", "Compile standalone executable target (game_exe)") { exe = true }
          opts.on("-F", "--force", "Force rebuild even if sources are unchanged") { force = true }
          opts.on("-h", "--help", "Show help") do
            puts opts
            exit 0
          end
        end
        parser.parse(args)

        root = Core::Env::ROOT_DIR
        examples_dir = root.join("examples")
        return 0 unless Dir.exists?(examples_dir)

        failed = 0
        Dir.each_child(examples_dir) do |name|
          ex_dir = examples_dir.join(name)
          next unless Dir.exists?(ex_dir)

          makefile = ex_dir.join("Makefile")
          if File.exists?(makefile)
            target = exe ? "game_exe" : "all"
            make_args = [target]
            make_args << "RELEASE=1" if release
            make_args << "FORCE=1" if force

            Core::Logger.step("Examples", "Building #{target} for #{name}...")
            status = Core::ProcessRunner.run("make", make_args, chdir: ex_dir.to_s)
            failed += 1 unless status.success?
          elsif File.exists?(ex_dir.join("src/main.cr"))
            bin_dir = ex_dir.join("bin")
            FileUtils.mkdir_p(bin_dir) unless Dir.exists?(bin_dir)
            out_file = if exe
                         bin_dir.join("game#{Core::Env.exe_ext}")
                       else
                         bin_dir.join("game.#{Core::Env.dll_ext}")
                       end
            link_flags = exe ? nil : Core::Env.link_flags

            Core::Logger.step("Examples", "Building #{name} -> #{out_file.basename}...")
            code = compile_binary(
              entry_path: ex_dir.join("src/main.cr"),
              output_path: out_file,
              link_flags: link_flags,
              release: release,
              force: force
            )
            failed += 1 if code != 0
          end
        end

        if failed == 0
          Core::Logger.success("All examples built successfully!")
          0
        else
          Core::Logger.error("#{failed} example(s) failed to build.")
          1
        end
      end

      # Compiles the game library (bin/game.dll, bin/game.so, etc.) for the current or specified project
      def self.build_game(args : Array(String)) : Int32
        release = false
        single_module : Bool? = nil
        proj_path : String? = nil
        source_path : String? = nil
        link_flags : String? = nil
        flags : String? = nil
        without_benchmarks = false
        force = false

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis build game [options]"
          opts.on("-p PATH", "--path=PATH", "Game project directory (default: current project)") { |v| proj_path = v }
          opts.on("-r", "--release", "Compile in release mode with optimizations (-O3)") { release = true }
          opts.on("-F", "--force", "Force rebuild even if sources are unchanged") { force = true }
          opts.on("--without-benchmarks", "Exclude benchmark definitions from compiled binary") { without_benchmarks = true }
          opts.on("--with-benchmarks", "Include benchmark definitions in compiled binary") { without_benchmarks = false }
          opts.on("-m", "--single-module", "Generate a single LLVM module") { single_module = true }
          opts.on("--no-single-module", "Disable single LLVM module generation") { single_module = false }
          opts.on("-s PATH", "--source-path=PATH", "Source path for CRYSTAL_PATH") { |v| source_path = v }
          opts.on("-l FLAGS", "--link-flags=FLAGS", "Linker flags") { |v| link_flags = v }
          opts.on("--no-log", "Strip all logging statements from compiled binary at compile-time (-Dno_log)") { flags = "#{flags} -Dno_log" }
          opts.on("--log=LEVEL", "--log-level=LEVEL", "Set compile-time log severity threshold (-Dlog=LEVEL, e.g. 4, error, warn)") { |v| flags = "#{flags} -Dlog=#{v}" }
          opts.on("--strip-docs", "--no-doc", "Strip editor XML documentation from binary (-Dno_doc)") { flags = "#{flags} -Dno_doc" }
          opts.on("--no-thread-safety", "--fast-dispatch", "Bypass main thread checks for maximum performance (-Dno_thread_safety)") { flags = "#{flags} -Dno_thread_safety" }
          opts.on("--no-testing", "Strip test runner apparatus (-Dno_testing)") { flags = "#{flags} -Dno_testing" }
          opts.on("--testing", "Force include test runner apparatus in release (-Dtesting)") { flags = "#{flags} -Dtesting" }
          opts.on("--leak-tracker", "--trace-allocations", "Track ObjectDB instances and report leaks on exit (-Dleak_tracker)") { flags = "#{flags} -Dleak_tracker" }
          opts.on("--trace-signals", "--signal-spy", "Trace signal emissions and listener counts (-Dtrace_signals)") { flags = "#{flags} -Dtrace_signals" }
          opts.on("--profile-dispatches", "Profile execution time of Crystal method dispatches (-Dprofile_dispatches)") { flags = "#{flags} -Dprofile_dispatches" }
          opts.on("--trace-dead-pointers", "Track tombstone history for freed objects (-Dtrace_dead_pointers)") { flags = "#{flags} -Dtrace_dead_pointers" }
          opts.on("--no-crash-handler", "Disable custom Vectored Exception Handler (-Dno_crash_handler)") { flags = "#{flags} -Dno_crash_handler" }
          opts.on("-h", "--help", "Show help") do
            puts opts
            exit 0
          end
        end
        parser.parse(args)

        root = Core::Env::ROOT_DIR
        curr = Path.new(Dir.current).expand

        proj_dir = if (pp = proj_path) && !pp.empty?
                     Path.new(pp).expand
                   elsif (nearest = Core::Env.find_project_dir(curr)) && File.exists?(nearest.join("src/main.cr"))
                     nearest
                   elsif File.exists?(curr.join("project.godot")) || File.exists?(curr.join("src/main.cr"))
                     curr
                   elsif File.exists?(root.join("project.godot")) || File.exists?(root.join("src/main.cr"))
                     root
                   elsif File.exists?(root.join("template/project.godot"))
                     root.join("template")
                   else
                     curr
                   end

        main_cr = proj_dir.join("src/main.cr")
        unless File.exists?(main_cr)
          Core::Logger.error("Game entry point not found: #{main_cr}")
          return 1
        end

        # Check if this is an addon project (targets: addon: in shard.yml)
        is_addon_project = false
        addon_subfolder : Path? = nil
        if File.exists?(proj_dir.join("shard.yml"))
          shard_txt = File.read(proj_dir.join("shard.yml")) rescue ""
          if shard_txt =~ /targets:\s*\n\s*addon:/
            is_addon_project = true
            if Dir.exists?(proj_dir.join("addons"))
              Dir.children(proj_dir.join("addons")).each do |child|
                next if child == "crystal_integration"
                if File.exists?(proj_dir.join("addons", child, "plugin.cfg"))
                  addon_subfolder = proj_dir.join("addons", child)
                  break
                end
              end
            end
          end
        end

        bin_dir = if asf = addon_subfolder
                    asf.join("bin")
                  else
                    proj_dir.join("bin")
                  end
        FileUtils.mkdir_p(bin_dir) unless Dir.exists?(bin_dir)
        output_lib = bin_dir.join(Core::Env.game_file)

        if is_addon_project && (flags.nil? || !flags.not_nil!.includes?("-Dlibgodot_addon"))
          flags = flags ? "#{flags} -Dlibgodot_addon" : "-Dlibgodot_addon"
        end
        Sync.ensure_extension_list(proj_dir)

        # Resolve libgodot Crystal source path
        src_dir = if sp = source_path
                    Path.new(sp).expand.to_s
                  elsif Dir.exists?(proj_dir.join("lib/lapis/src"))
                    proj_dir.join("lib/lapis/src").to_s
                  elsif Dir.exists?(proj_dir.join("lib/libgodot/src"))
                    proj_dir.join("lib/libgodot/src").to_s
                  elsif Dir.exists?(root.join("src")) && (File.exists?(root.join("src/libgodot.cr")) || File.exists?(root.join("src/lapis.cr")))
                    root.join("src").to_s
                  elsif (global = Core::Env.global_libgodot_path) && Dir.exists?(global.join("src"))
                    global.join("src").to_s
                  else
                    proj_dir.join("src").to_s
                  end

        # If lib/lapis, lib/cradare2, or lib/opal is missing and engine source is baked into BakedFileSystem, extract it directly!
        if !Core::BakedFileSystem.engine_libs_present?(proj_dir) && !Core::Env.is_libgodot_repo?(root) && !Core::Env.is_libgodot_repo?(proj_dir)
          if Core::BakedFileSystem.files_with_prefix("src").size > 0
            Core::Logger.step("Deps", "Extracting embedded Lapis engine library into lib/lapis...")
            Core::BakedFileSystem.extract_engine_lib(proj_dir.join("lib/lapis"), overwrite: false)
            src_dir = proj_dir.join("lib/lapis/src").to_s if Dir.exists?(proj_dir.join("lib/lapis/src"))
          end
        end

        # If project has shard.yml and lib/ does not exist, and no src_dir found with libgodot.cr/lapis.cr, try shards install
        if File.exists?(proj_dir.join("shard.yml")) && !Dir.exists?(proj_dir.join("lib")) && !File.exists?(Path.new(src_dir).join("libgodot.cr")) && !File.exists?(Path.new(src_dir).join("lapis.cr"))
          if shards_exe = Core::ProcessRunner.find_executable("shards")
            Core::Logger.step("Shards", "Installing project dependencies via shards install...")
            Core::ProcessRunner.run(shards_exe, ["install"], chdir: proj_dir.to_s)
            if Dir.exists?(proj_dir.join("lib/lapis/src"))
              src_dir = proj_dir.join("lib/lapis/src").to_s
            elsif Dir.exists?(proj_dir.join("lib/libgodot/src"))
              src_dir = proj_dir.join("lib/libgodot/src").to_s
            end
          end
        end

        effective_link_flags = link_flags || Core::Env.link_flags
        code = compile_binary(
          entry_path: main_cr,
          output_path: output_lib,
          link_flags: effective_link_flags,
          flags: flags,
          release: release,
          source_path: src_dir,
          single_module: single_module,
          without_benchmarks: without_benchmarks,
          force: force
        )

        return code if code != 0

        # Ensure runtime dependencies & bridge are synced into bin
        Deps.run(["-t", bin_dir.to_s])
        Sync.run(["-t", bin_dir.to_s, "--bins-only"])

        # Sync game binary & PDB to addons/crystal_integration/bin if present
        ci_bin = proj_dir.join("addons/crystal_integration/bin")
        if Dir.exists?(ci_bin)
          Commands::Deps.safe_copy(output_lib, ci_bin.join(output_lib.basename))
          if Core::Env.windows?
            src_pdb = Path.new(output_lib.to_s.sub(/\.dll$/, ".pdb"))
            dst_pdb = ci_bin.join(output_lib.basename.to_s.sub(/\.dll$/, ".pdb"))
            Commands::Deps.safe_copy(src_pdb, dst_pdb) if File.exists?(src_pdb)
          end
          # Stage bridge and runtime dependencies in crystal_integration bin
          Deps.run(["-t", ci_bin.to_s, "--addon"])
        end

        # If building a standalone addon project, also sync the compiled library and dependencies to root bin/
        if is_addon_project && Dir.exists?(proj_dir.join("bin")) && proj_dir.join("bin") != bin_dir
          root_bin = proj_dir.join("bin")
          Commands::Deps.safe_copy(output_lib, root_bin.join(output_lib.basename))
          if Core::Env.windows?
            src_pdb = Path.new(output_lib.to_s.sub(/\.dll$/, ".pdb"))
            dst_pdb = root_bin.join(output_lib.basename.to_s.sub(/\.dll$/, ".pdb"))
            Commands::Deps.safe_copy(src_pdb, dst_pdb) if File.exists?(src_pdb)
          end
          Deps.run(["-t", root_bin.to_s])
          Sync.run(["-t", root_bin.to_s, "--bins-only"])
        end

        Core::Logger.success("Game library compiled and synced: #{output_lib.basename}")
        0
      end

      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Crystal Game & Plugin Compiler ===\e[0m

Usage:
  lapis build [game] [options]
  lapis build addons [options]
  lapis build examples [options]

Subcommands:
  game                  Build game library for current or specified project (default)
  addons                Build all test/dummy addons in addons/
  examples              Build all showcase examples in examples/

Options for game library build ('lapis build' or 'lapis build game'):
  -p, --path=PATH       Game project directory (default: current project)
  -r, --release         Compile in release mode with optimizations (-O3)
  -F, --force           Force rebuild even if Crystal sources are unchanged
      --without-benchmarks Exclude benchmark definitions from compiled binary
      --with-benchmarks Include benchmark definitions in compiled binary
  -m, --single-module   Generate a single LLVM module (auto-enabled on Linux shared libraries)
      --no-single-module Disable single LLVM module generation
  -s, --source-path=DIR Source path prepended to CRYSTAL_PATH
  -l, --link-flags=FLAGS Linker flags passed to crystal build
  -f, --flags=FLAGS     Extra Crystal compiler flags (e.g. -Dlibgodot_addon)
      --strip-docs      Strip editor XML documentation from binary (-Dno_doc)
      --no-thread-safety Bypass main thread checks for maximum performance (-Dno_thread_safety)
      --leak-tracker    Track ObjectDB instances and report leaks on exit (-Dleak_tracker)
      --trace-signals   Trace signal emissions and listener counts (-Dtrace_signals)
      --profile-dispatches Profile execution time of Crystal method dispatches (-Dprofile_dispatches)
      --trace-dead-pointers Track tombstone history for freed objects (-Dtrace_dead_pointers)
      --no-crash-handler Disable custom Vectored Exception Handler (-Dno_crash_handler)

Options for single binary build:
  -e, --entry=PATH      Entry source file (.cr) [Required for direct build]
  -o, --output=PATH     Output binary path (.dll, .so, .dylib, or .exe) [Required for direct build]
  -r, --release         Compile in release mode with optimizations (-O3)
  -F, --force           Force rebuild even if Crystal sources are unchanged
  -m, --single-module   Generate a single LLVM module (auto-enabled on Linux shared libraries)
      --no-single-module Disable single LLVM module generation
  -l, --link-flags=FLAGS Linker flags passed to crystal build
  -f, --flags=FLAGS     Extra Crystal compiler flags (e.g. -Dlibgodot_addon)
  -s, --source-path=DIR Source path prepended to CRYSTAL_PATH
  -x, --exe             Target executable instead of library (for examples)
  -h, --help            Show this help screen

Examples:
  lapis build game
  lapis build game -r
  lapis build -e src/editor/plugin.cr -o bin/plugin.dll --flags "-Dlibgodot_addon"
  lapis build -e template/src/main.cr -o template/bin/game.dll --release
  lapis build addons --release
  lapis build examples
HELP
      end

      def self.run(args : Array(String)) : Int32
        if args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        if !args.empty?
          if args[0] == "addons"
            return build_addons(args[1..])
          elsif args[0] == "examples"
            return build_examples(args[1..])
          elsif args[0] == "game"
            return build_game(args[1..])
          elsif !args[0].starts_with?("-") && !args[0].ends_with?(".cr")
            targets = ["game", "addons", "examples"]
            if suggestion = Core::Text.suggest(args[0], targets)
              Core::Logger.error("Unknown build target: '#{args[0]}'")
              puts "  \e[33mDid you mean 'lapis build #{suggestion}'?\e[0m\n\n"
              return 1
            end
          end
        end

        # Auto-detect `lapis build` inside a game project
        has_entry_arg = args.any? { |a| a == "-e" || a.starts_with?("-e=") || a.starts_with?("--entry") }
        has_output_arg = args.any? { |a| a == "-o" || a.starts_with?("-o=") || a.starts_with?("--output") }

        if !has_entry_arg && !has_output_arg
          curr = Path.new(Dir.current).expand
          root = Core::Env::ROOT_DIR
          nearest = Core::Env.find_project_dir(curr)
          if nearest && File.exists?(nearest.join("project.godot")) && File.exists?(nearest.join("src/main.cr"))
            return build_game(args)
          elsif File.exists?(curr.join("project.godot")) && File.exists?(curr.join("src/main.cr"))
            return build_game(args)
          elsif (curr == root) && File.exists?(root.join("project.godot")) && File.exists?(root.join("src/main.cr"))
            return build_game(args)
          else
            unless Core::Env.is_crystal_dir?(curr)
              Core::Logger.warn("Warning: Current directory '#{curr}' is not a Crystal/Lapis project (missing shard.yml or src/).")
            end
            if args.empty?
              print_help
              return 0
            end
          end
        end

        entry : String? = nil
        output : String? = nil
        link_flags : String? = nil
        flags : String? = nil
        release = false
        single_module : Bool? = nil
        source_path : String? = nil
        without_benchmarks = false
        force = false

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis build --entry <path> --output <path> [options]"
          opts.on("-e PATH", "--entry=PATH", "Entry source file (.cr)") { |v| entry = v }
          opts.on("-o PATH", "--output=PATH", "Output binary path") { |v| output = v }
          opts.on("-l FLAGS", "--link-flags=FLAGS", "Linker flags") { |v| link_flags = v }
          opts.on("-f FLAGS", "--flags=FLAGS", "Extra Crystal compiler flags") { |v| flags = v }
          opts.on("-r", "--release", "Compile in release mode with optimizations") { release = true }
          opts.on("-F", "--force", "Force rebuild even if Crystal sources are unchanged") { force = true }
          opts.on("--without-benchmarks", "Exclude benchmark definitions from compiled binary") { without_benchmarks = true }
          opts.on("--with-benchmarks", "Include benchmark definitions in compiled binary") { without_benchmarks = false }
          opts.on("-m", "--single-module", "Generate a single LLVM module (auto-enabled on Linux shared libraries)") { single_module = true }
          opts.on("--no-single-module", "Disable single LLVM module generation") { single_module = false }
          opts.on("-s PATH", "--source-path=PATH", "Source path for CRYSTAL_PATH") { |v| source_path = v }
          opts.on("--no-log", "Strip all logging statements from compiled binary at compile-time (-Dno_log)") { flags = "#{flags} -Dno_log" }
          opts.on("--log=LEVEL", "--log-level=LEVEL", "Set compile-time log severity threshold (-Dlog=LEVEL, e.g. 4, error, warn)") { |v| flags = "#{flags} -Dlog=#{v}" }
          opts.on("--strip-docs", "--no-doc", "Strip editor XML documentation from binary (-Dno_doc)") { flags = "#{flags} -Dno_doc" }
          opts.on("--no-thread-safety", "--fast-dispatch", "Bypass main thread checks for maximum performance (-Dno_thread_safety)") { flags = "#{flags} -Dno_thread_safety" }
          opts.on("--no-testing", "Strip test runner apparatus (-Dno_testing)") { flags = "#{flags} -Dno_testing" }
          opts.on("--testing", "Force include test runner apparatus in release (-Dtesting)") { flags = "#{flags} -Dtesting" }
          opts.on("--leak-tracker", "--trace-allocations", "Track ObjectDB instances and report leaks on exit (-Dleak_tracker)") { flags = "#{flags} -Dleak_tracker" }
          opts.on("--trace-signals", "--signal-spy", "Trace signal emissions and listener counts (-Dtrace_signals)") { flags = "#{flags} -Dtrace_signals" }
          opts.on("--profile-dispatches", "Profile execution time of Crystal method dispatches (-Dprofile_dispatches)") { flags = "#{flags} -Dprofile_dispatches" }
          opts.on("--trace-dead-pointers", "Track tombstone history for freed objects (-Dtrace_dead_pointers)") { flags = "#{flags} -Dtrace_dead_pointers" }
          opts.on("--no-crash-handler", "Disable custom Vectored Exception Handler (-Dno_crash_handler)") { flags = "#{flags} -Dno_crash_handler" }
          opts.on("-v", "--verbose", "Enable verbose diagnostic output") { Core::Logger.verbose = true }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
        end

        parser.parse(args)

        unless entry && output
          Core::Logger.error("Both --entry and --output are required.")
          puts
          print_help
          return 1
        end

        compile_binary(
          entry_path: Path.new(entry.not_nil!).expand,
          output_path: Path.new(output.not_nil!).expand,
          link_flags: link_flags,
          flags: flags,
          release: release,
          source_path: source_path,
          single_module: single_module,
          without_benchmarks: without_benchmarks,
          force: force
        )
      end
    end
  end
end
