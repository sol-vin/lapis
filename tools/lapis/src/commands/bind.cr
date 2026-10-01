require "../core/logger"
require "./bind/engine"
require "./bind/project"
require "option_parser"

module Lapis
  module Commands
    module Bind
      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: GDExtension & Project Binding Generator ===\e[0m

Usage:
  lapis bind <engine|project> [options]
  lapis generate <engine|project> [options]

Subcommands:
  engine                 Generate typed Crystal bindings for Godot engine from extension_api.json
  project [PATH]         Inspect GDScript nodes in a Godot project and generate typed Crystal wrappers

Engine Options:
  -d, --dump             Dump extension_api.json from Godot executable before generating
  -a, --api=PATH         Explicit path to extension_api.json
  -o, --output=DIR       Output directory (default: src/libgodot/generated)
  --overrides=PATH       Explicit path to overrides.yml (keywords and type mappings)

Project Options:
  -p, --path=DIR         Project root containing project.godot (default: current directory)
  -o, --output=DIR       Output directory (default: <project>/src/generated/project_nodes)
  -j, --json=PATH        Output JSON metadata path

Global Options:
  -h, --help             Show this help screen

Examples:
  lapis bind engine                     # Generate LibGodot engine class bindings
  lapis bind engine --dump              # Dump extension_api.json from Godot then regenerate
  lapis bind project                    # Generate wrappers for custom GDScript nodes in CWD
  lapis bind project test               # Generate wrappers for custom GDScript nodes in test/
HELP
      end

      def self.run_engine(sub_args : Array(String)) : Int32
        api_path : Path? = nil
        output_dir : Path? = nil
        overrides_path : Path? = nil
        dump_api = false

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis bind engine [options]"
          opts.on("-d", "--dump", "Dump extension_api.json from Godot before generating") { dump_api = true }
          opts.on("-a PATH", "--api=PATH", "Path to extension_api.json") { |p| api_path = Path.new(p) }
          opts.on("-o DIR", "--output=DIR", "Output directory") { |d| output_dir = Path.new(d) }
          opts.on("--overrides=PATH", "Path to overrides.yml") { |o| overrides_path = Path.new(o) }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
        end
        parser.parse(sub_args)

        Engine.generate(
          api_path: api_path,
          output_dir: output_dir,
          overrides_path: overrides_path,
          dump_api: dump_api
        )
      end

      def self.run_project(sub_args : Array(String)) : Int32
        project_path : Path? = nil
        output_dir : Path? = nil
        json_path : Path? = nil

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis bind project [PATH] [options]"
          opts.on("-p DIR", "--path=DIR", "Target project directory") { |d| project_path = Path.new(d) }
          opts.on("-o DIR", "--output=DIR", "Output directory for wrappers") { |d| output_dir = Path.new(d) }
          opts.on("-j PATH", "--json=PATH", "Output JSON metadata path") { |j| json_path = Path.new(j) }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
        end

        remaining = [] of String
        parser.unknown_args do |rest|
          remaining = rest
        end
        parser.parse(sub_args)

        if project_path.nil? && !remaining.empty?
          project_path = Path.new(remaining[0])
        end

        Project.generate(
          project_path: project_path,
          output_dir: output_dir,
          json_path: json_path
        )
      end

      def self.run(args : Array(String)) : Int32
        if args.empty? || args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        subcommand = args[0]
        sub_args = args[1..]

        case subcommand
        when "engine", "libgodot", "api"
          run_engine(sub_args)
        when "project"
          run_project(sub_args)
        else
          Core::Logger.error("Unknown bind target: '#{subcommand}'. Expected 'engine' or 'project'.")
          puts
          print_help
          1
        end
      end
    end
  end
end
