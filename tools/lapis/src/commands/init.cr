require "../core/env"
require "../core/logger"
require "../core/baked_file_system"
require "./deps"
require "./sync"
require "file_utils"
require "option_parser"

module Lapis
  module Commands
    module Init
      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Project Initialization Tool ===\e[0m

Usage: lapis init [options] [path]

Initializes Crystal and Lapis integration into an existing Godot project,
or creates a minimal Crystal Godot setup in the current directory.

Options:
  -p, --path=PATH       Target project directory (default: current working directory)
  -n, --name=NAME       Custom project name for shard.yml
  -f, --force           Overwrite existing configuration files
  -l, --local           Use local relative path for lapis dependency in shard.yml
  -h, --help            Show this help screen

Examples:
  lapis init
  lapis init -p my_existing_game
  lapis init --force
HELP
      end

      def self.run(args : Array(String)) : Int32
        if args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        proj_path : String? = nil
        proj_name : String? = nil
        force = false
        local_dep = false

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis init [options] [path]"
          opts.on("-p PATH", "--path=PATH", "Target directory") { |p| proj_path = p }
          opts.on("-n NAME", "--name=NAME", "Project name") { |n| proj_name = n }
          opts.on("-f", "--force", "Overwrite existing files") { force = true }
          opts.on("-l", "--local", "Use local relative path for lapis shard dependency") { local_dep = true }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
          opts.unknown_args do |before, after|
            remaining = before + after
            proj_path ||= remaining.first if !remaining.empty?
          end
        end

        parser.parse(args)

        curr = Path.new(Dir.current).expand
        target_dir = if (pp = proj_path) && !pp.empty?
          Path.new(pp).expand
        else
          curr
        end

        FileUtils.mkdir_p(target_dir) unless Dir.exists?(target_dir)
        root = Core::Env::ROOT_DIR
        raw_name = (proj_name || target_dir.basename.to_s).to_s
        slug = raw_name.downcase.gsub(/[^a-z0-9_]/, "_")

        Core::Logger.step("Init", "Initializing Lapis Crystal integration in #{target_dir}...")

        # 1. Ensure minimal project.godot if missing
        godot_proj = target_dir.join("project.godot")
        unless File.exists?(godot_proj)
          Core::Logger.info("Creating default project.godot...")
          cfg_content = <<-GODOT
; Engine configuration file.
config_version=5

[application]

config/name="#{proj_name || target_dir.basename}"
config/features=PackedStringArray("4.8")
GODOT
          File.write(godot_proj, cfg_content)
        end

        # 2. Setup shard.yml
        shard_yml = target_dir.join("shard.yml")
        if !File.exists?(shard_yml) || force
          dep_str = if local_dep || Core::Env.is_libgodot_repo?(root)
            rel_root = Path.new(root).relative_to(target_dir).to_s.gsub('\\', '/')
            rel_root = "./#{rel_root}" unless rel_root.starts_with?(".")
            "  lapis:\n    path: #{rel_root}"
          else
            "  lapis:\n    github: sol-vin/lapis\n    branch: master"
          end

          shard_content = <<-YAML
name: #{slug}
version: 0.1.0
authors:
  - Developer <developer@example.com>
license: MIT

dependencies:
#{dep_str}

targets:
  game:
    main: src/main.cr
YAML
          File.write(shard_yml, shard_content)
          Core::Logger.debug("Created shard.yml")
        end

        # 3. Setup starter src/main.cr
        src_dir = target_dir.join("src")
        FileUtils.mkdir_p(src_dir) unless Dir.exists?(src_dir)
        main_cr = src_dir.join("main.cr")
        if !File.exists?(main_cr) || force
          main_content = <<-CR
require "libgodot"

# Sample Crystal node registered into Godot ClassDB
node GameController < Node3D do
  @[Export]
  property speed : Float32 = 5.0_f32

  signal game_started

  def _ready : Void
    Godot.print("Crystal GameController initialized at #{name}")
    emit_game_started
  end

  def _process(delta : Float64) : Void
    # Frame logic here
  end
end
CR
          File.write(main_cr, main_content)
          Core::Logger.debug("Created src/main.cr")
        end

        # 4. Copy crystal_integration addon
        addons_dir = target_dir.join("addons/crystal_integration")
        FileUtils.mkdir_p(addons_dir) unless Dir.exists?(addons_dir)
        src_addon = root.join("addons/crystal_integration")
        if Dir.exists?(src_addon)
          Sync.sync_addon_directory(src_addon, addons_dir)
        else
          # Fallback to baked filesystem assets
          Core::BakedFileSystem.extract_folder("addons/crystal_integration", addons_dir)
        end

        # 5. Ensure .godot/extension_list.cfg
        Sync.ensure_extension_list(target_dir)

        # 6. Ensure .gdignore in bin/ and lib/
        bin_dir = target_dir.join("bin")
        FileUtils.mkdir_p(bin_dir) unless Dir.exists?(bin_dir)
        File.write(bin_dir.join(".gdignore"), "") unless File.exists?(bin_dir.join(".gdignore"))

        lib_dir = target_dir.join("lib")
        FileUtils.mkdir_p(lib_dir) unless Dir.exists?(lib_dir)
        File.write(lib_dir.join(".gdignore"), "") unless File.exists?(lib_dir.join(".gdignore"))

        # 7. Sync runtime dependencies
        Deps.run(["-t", bin_dir.to_s])
        Sync.run(["-t", bin_dir.to_s, "--bins-only"])

        puts
        Core::Logger.success("Lapis integration initialized successfully in #{target_dir.basename}!")
        puts <<-NEXT

\e[36mNext steps:\e[0m
  1. Compile your Crystal game library:
     \e[1mlapis build\e[0m

  2. Open your project in the Godot Editor:
     \e[1mlapis editor\e[0m

  3. Add new Crystal nodes in \e[1msrc/\e[0m and press \e[1mF5\e[0m in Godot to live-reload!
NEXT
        0
      end
    end
  end
end
