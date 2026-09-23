require "../core/env"
require "../core/logger"
require "../core/process_runner"
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
  --engine-only             Run only engine specifications (test/spec)
  --cli-only                Run only Lapis CLI specifications (tools/lapis/spec)
  -v, --verbose             Enable verbose diagnostic output
  -h, --help                Show this help screen

Examples:
  lapis spec
  lapis spec -e "Vector2"
  lapis spec test/spec/testing_spec.cr
  lapis spec --engine-only
HELP
      end

      def self.run(args : Array(String)) : Int32
        if args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        example_pattern : String? = nil
        engine_only = false
        cli_only = false
        pass_files = [] of String

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis spec [options] [files]"
          opts.on("-e PATTERN", "--example=PATTERN", "Run only examples matching PATTERN") { |p| example_pattern = p }
          opts.on("--engine-only", "Run only engine specifications (test/spec)") { engine_only = true }
          opts.on("--cli-only", "Run only CLI specifications (tools/lapis/spec)") { cli_only = true }
          opts.on("-v", "--verbose", "Enable verbose diagnostic output") { Core::Logger.verbose = true }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
          opts.unknown_args do |before, after|
            pass_files.concat(before)
            pass_files.concat(after)
          end
        end

        parser.parse(args)

        root = Core::Env::ROOT_DIR

        crystal_args = ["spec"]
        if ex = example_pattern
          crystal_args << "-e"
          crystal_args << ex
        end

        if !pass_files.empty?
          crystal_args.concat(pass_files)
        elsif engine_only
          crystal_args << "test/spec"
        elsif cli_only
          crystal_args << "tools/lapis/spec"
        else
          crystal_args << "test/spec"
        end

        Core::Logger.info("Executing: crystal #{crystal_args.join(" ")}")
        res = Process.run("crystal", crystal_args, chdir: root.to_s, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
        res.success? ? 0 : (res.exit_code || 1)
      end
    end
  end
end
