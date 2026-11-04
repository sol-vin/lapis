require "../core/env"
require "../core/logger"
require "../core/process_runner"
require "../core/baked_file_system"
require "option_parser"

module Lapis
  module Commands
    module Spec
      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Crystal Specification Runner ===\e[0m

Usage: lapis spec [options] [files/directories]

Options:
  -e, --example PATTERN     Run only examples matching PATTERN
  --all                     Run both engine specs (spec) and CLI specs (tools/lapis/spec)
  --engine-only             Run only engine specifications (spec)
  --cli-only                Run only Lapis CLI specifications (tools/lapis/spec)
  -v, --verbose             Enable verbose diagnostic output
  -h, --help                Show this help screen

Examples:
  lapis spec
  lapis spec -e "Vector2"
  lapis spec spec/math_spec.cr
  lapis spec --all
  lapis spec --engine-only
  lapis spec --cli-only
HELP
      end

      def self.run(args : Array(String)) : Int32
        if args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        example_pattern : String? = nil
        run_all = false
        engine_only = false
        cli_only = false
        pass_files = [] of String

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis spec [options] [files]"
          opts.on("-e PATTERN", "--example=PATTERN", "Run only examples matching PATTERN") { |p| example_pattern = p }
          opts.on("--all", "Run both engine and CLI specifications") { run_all = true }
          opts.on("--engine-only", "Run only engine specifications (spec)") { engine_only = true }
          opts.on("--cli-only", "Run only CLI specifications (tools/lapis/spec)") { cli_only = true }
          opts.on("-v", "--verbose", "Enable verbose diagnostic output") { Core::Logger.verbose = true }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
          opts.unknown_args do |before, after|
            pass_files.concat(before)
            pass_files.concat(after)
          end
        end

        parser.parse(args)

        curr = Path.new(Dir.current).expand
        root = if !run_all && !engine_only && !cli_only &&
                  Dir.exists?(curr.join("spec")) &&
                  (File.exists?(curr.join("shard.yml")) || File.exists?(curr.join("project.godot")))
                 curr
               else
                 Core::Env::ROOT_DIR
               end

        if !Core::BakedFileSystem.engine_libs_present?(root) &&
           !Core::Env.is_libgodot_repo?(root) &&
           Core::BakedFileSystem.files_with_prefix("src").size > 0
          Core::BakedFileSystem.extract_engine_lib(root.join("lib/lapis"), overwrite: false)
        end

        crystal_args = ["spec"]
        if ex = example_pattern
          crystal_args << "-e"
          crystal_args << ex
        end

        if !pass_files.empty?
          crystal_args.concat(pass_files)
        elsif run_all
          crystal_args << "spec"
          crystal_args << "tools/lapis/spec"
        elsif engine_only
          crystal_args << "spec"
        elsif cli_only
          crystal_args << "tools/lapis/spec"
        else
          crystal_args << "spec"
        end

        base_crystal_path = Core::ProcessRunner.capture("crystal", ["env", "CRYSTAL_PATH"])[:output].strip
        path_parts = [] of String
        path_parts << root.join("lib/lapis/src").to_s if Dir.exists?(root.join("lib/lapis/src"))
        path_parts << root.join("src").to_s if Core::Env.is_libgodot_repo?(root) && Dir.exists?(root.join("src"))
        path_parts << root.join("lib").to_s if Dir.exists?(root.join("lib"))
        if (global = Core::Env.global_libgodot_path) && Dir.exists?(global.join("lib"))
          glib = global.join("lib").to_s
          path_parts << glib unless path_parts.includes?(glib)
        end
        path_parts << base_crystal_path unless base_crystal_path.empty?
        env = {"CRYSTAL_PATH" => path_parts.uniq.join(Core::Env.path_sep)}

        Core::Logger.info("Executing: crystal #{crystal_args.join(" ")}")
        res = Process.run("crystal", crystal_args, env: env, chdir: root.to_s, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
        res.success? ? 0 : (res.exit_code || 1)
      end
    end
  end
end
