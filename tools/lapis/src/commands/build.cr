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

module Lapis
  module Commands
    module Build
      # Automatically dump and generate project GDScript bindings if project contains custom .gd files
      def self.check_and_generate_project_bindings(entry : Path, root : Path)
        proj_dir = entry.parent
        proj_dir = proj_dir.parent if proj_dir.basename == "src"

        # Check for .gd files excluding addons, .godot, tools
        gd_files = Dir.glob(proj_dir.to_s.gsub('\\', '/') + "/**/*.gd").reject do |f|
          f.includes?("/addons/") || f.includes?("\\addons\\") ||
            f.includes?("/.godot/") || f.includes?("\\.godot\\") ||
            f.includes?("/tools/") || f.includes?("\\tools\\") ||
            File.basename(f) == "dump_project_nodes.gd"
        end

        return if gd_files.empty?

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

        out_json = proj_dir.join("src", "generated", "project_nodes.json")
        out_manifest = proj_dir.join("src", "generated", "project_nodes", "all_project_nodes.cr")
        if File.exists?(out_json) && File.exists?(out_manifest)
          json_mtime = File.info(out_json).modification_time
          newest_gd = gd_files.map { |f| File.info(f).modification_time rescue ::Time.unix(0) }.max?
          if newest_gd && newest_gd <= json_mtime
            return
          end
        end

        Core::Logger.info("Detected custom GDScript files in #{proj_dir.basename}, generating project bindings...")
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
      ) : Int32
        root = Core::Env::ROOT_DIR
        FileUtils.mkdir_p(output_path.parent) unless Dir.exists?(output_path.parent)

        check_and_generate_project_bindings(entry_path, root)

        src_dir = if sp = source_path
                    Path.new(sp).expand
                  else
                    root.join("src")
                  end
        base_crystal_path = Core::ProcessRunner.capture("crystal", ["env", "CRYSTAL_PATH"])[:output].strip
        entry_parent = entry_path.parent
        proj_lib = (entry_parent.basename == "src" ? entry_parent.parent : entry_parent).join("lib")

        path_parts = [src_dir.to_s]
        path_parts << proj_lib.to_s if Dir.exists?(proj_lib)
        path_parts << root.join("lib").to_s if Dir.exists?(root.join("lib")) && root.join("lib") != proj_lib
        path_parts << root.join("addons").to_s if Dir.exists?(root.join("addons"))
        path_parts << base_crystal_path unless base_crystal_path.empty?
        full_crystal_path = path_parts.join(Core::Env.path_sep)

        cmd_args = ["build", entry_path.to_s, "-o", output_path.to_s]
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
        # 1. If explicitly specified, respect that choice.
        # 2. Otherwise, auto-enable for shared libraries (.so, .dll, .dylib or -shared / /DLL / -dynamiclib).
        # On Linux ELF targets, Crystal's symbol mangling generates characters like '@' (e.g. Type@Module#method)
        # which modern linkers (lld, mold) interpret as ELF symbol versioning in multi-module builds, causing link failure.
        # --single-module generates a single LLVM translation unit where non-exported methods receive internal linkage.
        is_shared_lib = [".so", ".dll", ".dylib"].includes?(output_path.extension) ||
                        (link_flags && (link_flags.includes?("-shared") || link_flags.includes?("/DLL") || link_flags.includes?("-dynamiclib")))
        should_single_module = single_module.nil? ? is_shared_lib : single_module

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

        env = {"CRYSTAL_PATH" => full_crystal_path}

        working_dir = if entry_path.to_s.starts_with?("src/") || entry_path.to_s.starts_with?("src\\")
                        root
                      elsif entry_path.parent.basename == "src"
                        entry_path.parent.parent
                      else
                        entry_path.parent
                      end

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

      def self.build_addons(args : Array(String)) : Int32
        release = false
        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis build addons [options]"
          opts.on("-r", "--release", "Compile in release mode with optimizations") { release = true }
          opts.on("-h", "--help", "Show help") do
            puts opts
            exit 0
          end
        end
        parser.parse(args)

        root = Core::Env::ROOT_DIR
        test_addons = Dir.exists?(root.join("addons")) ? root.join("addons") : root.join("test/addons")
        return 0 unless Dir.exists?(test_addons)

        ext = Core::Env.dll_ext
        link_flags = Core::Env.link_flags

        # Discover candidate addons to compile
        candidate_names = Dir.children(test_addons).select do |name|
          next false if name == "crystal_integration"
          addon_dir = test_addons.join(name)
          Dir.exists?(addon_dir) && (name.starts_with?("dummy_") || File.exists?(addon_dir.join("src/main.cr"))) && File.exists?(addon_dir.join("src/main.cr"))
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
          main_cr = addon_dir.join("src/main.cr")
          bin_dir = addon_dir.join("bin")
          FileUtils.mkdir_p(bin_dir) unless Dir.exists?(bin_dir)
          out_lib = bin_dir.join("#{name}.#{ext}")

          Core::Logger.step("DummyAddon", "Compiling #{name} -> #{out_lib.basename}...")
          code = compile_binary(
            entry_path: main_cr,
            output_path: out_lib,
            link_flags: link_flags,
            flags: "-Dlibgodot_addon",
            release: release
          )
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

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis build examples [options]"
          opts.on("-r", "--release", "Compile in release mode with optimizations") { release = true }
          opts.on("-x", "--exe", "Compile standalone executable target (game_exe)") { exe = true }
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
              release: release
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

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis build game [options]"
          opts.on("-p PATH", "--path=PATH", "Game project directory (default: current project)") { |v| proj_path = v }
          opts.on("-r", "--release", "Compile in release mode with optimizations (-O3)") { release = true }
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

        # If lib/lapis is missing and engine source is baked into BakedFileSystem, extract it directly!
        if !Dir.exists?(proj_dir.join("lib/lapis/src")) && !File.exists?(Path.new(src_dir).join("libgodot.cr")) && !File.exists?(Path.new(src_dir).join("lapis.cr"))
          if Core::BakedFileSystem.files_with_prefix("src").size > 0
            Core::Logger.step("Deps", "Extracting embedded Lapis engine library into lib/lapis...")
            Core::BakedFileSystem.extract_engine_lib(proj_dir.join("lib/lapis"))
            src_dir = proj_dir.join("lib/lapis/src").to_s
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
          without_benchmarks: without_benchmarks
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
      --without-benchmarks Exclude benchmark definitions from compiled binary
      --with-benchmarks Include benchmark definitions in compiled binary
  -m, --single-module   Generate a single LLVM module (auto-enabled for shared libraries)
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
  -m, --single-module   Generate a single LLVM module (auto-enabled for shared libraries)
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

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis build --entry <path> --output <path> [options]"
          opts.on("-e PATH", "--entry=PATH", "Entry source file (.cr)") { |v| entry = v }
          opts.on("-o PATH", "--output=PATH", "Output binary path") { |v| output = v }
          opts.on("-l FLAGS", "--link-flags=FLAGS", "Linker flags") { |v| link_flags = v }
          opts.on("-f FLAGS", "--flags=FLAGS", "Extra Crystal compiler flags") { |v| flags = v }
          opts.on("-r", "--release", "Compile in release mode with optimizations") { release = true }
          opts.on("--without-benchmarks", "Exclude benchmark definitions from compiled binary") { without_benchmarks = true }
          opts.on("--with-benchmarks", "Include benchmark definitions in compiled binary") { without_benchmarks = false }
          opts.on("-m", "--single-module", "Generate a single LLVM module (auto-enabled for shared libraries)") { single_module = true }
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
          without_benchmarks: without_benchmarks
        )
      end
    end
  end
end
