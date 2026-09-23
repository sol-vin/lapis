require "../core/env"
require "../core/logger"
require "../core/process_runner"
require "../core/godot_finder"
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
        single_module : Bool? = nil
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
        full_crystal_path = "#{src_dir}#{Core::Env.path_sep}#{base_crystal_path}"

        cmd_args = ["build", entry_path.to_s, "-o", output_path.to_s]
        cmd_args << "--release" if release

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

        if (lf = link_flags) && !lf.empty?
          cmd_args << "--link-flags"
          cmd_args << lf
        end

        if (fl = flags) && !fl.empty?
          fl.split(' ').each do |f|
            next if f.empty?
            if f == "--no-single-module"
              cmd_args.delete("--single-module")
            else
              cmd_args << f
            end
          end
        end

        env = {"CRYSTAL_PATH" => full_crystal_path}

        working_dir = if entry_path.parent.basename == "src"
          entry_path.parent.parent
        else
          entry_path.parent
        end

        Core::Logger.step("Build", "Compiling #{output_path.basename}...")
        status = Core::ProcessRunner.run(
          "crystal",
          cmd_args,
          env: env,
          chdir: working_dir.to_s
        )

        if status.success?
          Core::Logger.success("#{output_path.basename} built successfully!")
          0
        else
          Core::Logger.error("Build failed with exit code #{status.exit_code}")
          status.exit_code
        end
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
        test_addons = root.join("test/addons")
        return 0 unless Dir.exists?(test_addons)

        ext = Core::Env.dll_ext
        link_flags = Core::Env.link_flags

        failed = 0
        Dir.each_child(test_addons) do |name|
          addon_dir = test_addons.join(name)
          next unless Dir.exists?(addon_dir) && (name.starts_with?("dummy_") || File.exists?(addon_dir.join("src/main.cr")))

          main_cr = addon_dir.join("src/main.cr")
          next unless File.exists?(main_cr)

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

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis build game [options]"
          opts.on("-p PATH", "--path=PATH", "Game project directory (default: current project)") { |v| proj_path = v }
          opts.on("-r", "--release", "Compile in release mode with optimizations (-O3)") { release = true }
          opts.on("-m", "--single-module", "Generate a single LLVM module") { single_module = true }
          opts.on("--no-single-module", "Disable single LLVM module generation") { single_module = false }
          opts.on("-s PATH", "--source-path=PATH", "Source path for CRYSTAL_PATH") { |v| source_path = v }
          opts.on("-l FLAGS", "--link-flags=FLAGS", "Linker flags") { |v| link_flags = v }
          opts.on("-f FLAGS", "--flags=FLAGS", "Extra Crystal compiler flags") { |v| flags = v }
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

        bin_dir = proj_dir.join("bin")
        FileUtils.mkdir_p(bin_dir) unless Dir.exists?(bin_dir)
        output_lib = bin_dir.join(Core::Env.game_file)

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
          single_module: single_module
        )

        return code if code != 0

        # Ensure runtime dependencies & bridge are synced into bin
        Deps.run(["-t", bin_dir.to_s])
        Sync.run(["-t", bin_dir.to_s, "--bins-only"])

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
  addons                Build all test/dummy addons in test/addons/
  examples              Build all showcase examples in examples/

Options for game library build ('lapis build' or 'lapis build game'):
  -p, --path=PATH       Game project directory (default: current project)
  -r, --release         Compile in release mode with optimizations (-O3)
  -m, --single-module   Generate a single LLVM module (auto-enabled for shared libraries)
      --no-single-module Disable single LLVM module generation
  -s, --source-path=DIR Source path prepended to CRYSTAL_PATH
  -l, --link-flags=FLAGS Linker flags passed to crystal build
  -f, --flags=FLAGS     Extra Crystal compiler flags (e.g. -Dlibgodot_addon)

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
          end
        end

        # Auto-detect `lapis build` inside a game project
        has_entry_arg = args.any? { |a| a == "-e" || a.starts_with?("-e=") || a.starts_with?("--entry") }
        has_output_arg = args.any? { |a| a == "-o" || a.starts_with?("-o=") || a.starts_with?("--output") }

        if !has_entry_arg && !has_output_arg
          curr = Path.new(Dir.current).expand
          root = Core::Env::ROOT_DIR
          if File.exists?(curr.join("project.godot")) && File.exists?(curr.join("src/main.cr"))
            return build_game(args)
          elsif File.exists?(root.join("project.godot")) && File.exists?(root.join("src/main.cr"))
            return build_game(args)
          elsif args.empty?
            print_help
            return 0
          end
        end

        entry : String? = nil
        output : String? = nil
        link_flags : String? = nil
        flags : String? = nil
        release = false
        single_module : Bool? = nil
        source_path : String? = nil

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis build --entry <path> --output <path> [options]"
          opts.on("-e PATH", "--entry=PATH", "Entry source file (.cr)") { |v| entry = v }
          opts.on("-o PATH", "--output=PATH", "Output binary path") { |v| output = v }
          opts.on("-l FLAGS", "--link-flags=FLAGS", "Linker flags") { |v| link_flags = v }
          opts.on("-f FLAGS", "--flags=FLAGS", "Extra Crystal compiler flags") { |v| flags = v }
          opts.on("-r", "--release", "Compile in release mode with optimizations") { release = true }
          opts.on("-m", "--single-module", "Generate a single LLVM module (auto-enabled for shared libraries)") { single_module = true }
          opts.on("--no-single-module", "Disable single LLVM module generation") { single_module = false }
          opts.on("-s PATH", "--source-path=PATH", "Source path for CRYSTAL_PATH") { |v| source_path = v }
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
          single_module: single_module
        )
      end
    end
  end
end
