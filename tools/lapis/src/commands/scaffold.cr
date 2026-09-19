require "../core/env"
require "../core/logger"
require "../core/baked_file_system"
require "./deps"
require "./setup"
require "./install"
require "file_utils"
require "option_parser"

module Lapis
  module Commands
    module Scaffold
      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Project Scaffolding Tool ===\e[0m

Usage:
  lapis scaffold <game|project|addon|example> [name] [options]
  lapis new <game|project|addon|example> [name] [options]

Subcommands:
  game, project [name]   Scaffold a complete new game from template in DIR or CWD
  example <name>         Scaffold a self-contained showcase example project in examples/<name>
  addon <name>           Scaffold a redistributable GDExtension addon in addons/<name>

Options:
  -t, --target=DIR       Explicit target output directory
  -n, --name=NAME        Explicit project name
  -f, --force            Overwrite existing files in non-empty target directory
  -l, --local            Use local relative path for lapis dependency in shard.yml
  --skip-godot           Skip automatic Godot engine download
  -a, --author=NAME      Author name for shard.yml (addons only)
  -d, --desc=TEXT        Description for shard.yml (addons only)
  -h, --help             Show this help screen

Examples:
  lapis new game                     # Scaffold in current working directory
  lapis new project my_game          # Scaffold into ./my_game
  lapis new game --target path/game  # Scaffold into specified directory
  lapis scaffold addon my_inventory -a "Sol-Vin" -d "Inventory system for Godot"
  lapis new example 3d_fps
HELP
      end

      private def self.customize_project_files(
        dst_dir : Path,
        proj_title : String,
        proj_slug : String,
        root : Path,
        local_dep : Bool
      ) : Void
        godot_proj = dst_dir.join("project.godot")
        if File.exists?(godot_proj)
          content = File.read(godot_proj)
          content = content.gsub(/config\/name="[^"]*"/, "config/name=\"#{proj_title}\"")
          File.write(godot_proj, content)
        end

        shard_path = dst_dir.join("shard.yml")
        dest_expanded = dst_dir.expand.to_s.gsub('\\', '/')
        root_expanded = root.expand.to_s.gsub('\\', '/')

        if local_dep || (dest_expanded.starts_with?(root_expanded) && !dest_expanded.includes?(".."))
          rel_root = Path.new(root).relative_to(dst_dir).to_s.gsub('\\', '/')
          rel_root = "./#{rel_root}" unless rel_root.starts_with?(".")
          dep_str = "  lapis:\n    path: #{rel_root}"
        else
          dep_str = "  lapis:\n    github: sol-vin/lapis\n    branch: master"
        end

        shard_content = <<-YAML
name: #{proj_slug}
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
        File.write(shard_path, shard_content)

        readme_path = dst_dir.join("README.md")
        readme_content = <<-MD
# #{proj_title}

A Godot 4.8 + Crystal game built with [Lapis](https://github.com/sol-vin/lapis).

## Development

```bash
# Compile game library
lapis build game

# Open in Godot Editor
lapis editor
```
MD
        File.write(readme_path, readme_content)
      end

      # Recursively copy template directory with exclusions and customizations
      private def self.copy_template_dir(
        src_dir : Path,
        dst_dir : Path,
        proj_title : String,
        proj_slug : String,
        root : Path,
        local_dep : Bool
      ) : Void
        excludes = [
          ".godot", ".git", ".uid", "crash_dump",
          "test_ext.log", "template_ext.log",
          "bin", "lib", "dist"
        ]

        pattern = src_dir.to_s.gsub('\\', '/') + "/**/*"
        Dir.glob(pattern).each do |item|
          rel = Path.new(item).relative_to(src_dir).to_s.gsub('\\', '/')
          next if excludes.any? { |ex| rel == ex || rel.starts_with?("#{ex}/") || rel.ends_with?(".log") }

          target_item = dst_dir.join(rel)

          if Dir.exists?(item)
            FileUtils.mkdir_p(target_item)
          else
            FileUtils.mkdir_p(target_item.parent)
            FileUtils.cp(item, target_item.to_s)
          end
        end

        customize_project_files(dst_dir, proj_title, proj_slug, root, local_dep)
      end

      def self.scaffold_game(
        name : String?,
        target_dir : Path?,
        force : Bool = false,
        local_dep : Bool = false,
        skip_godot : Bool = false
      ) : Int32
        root = Core::Env::ROOT_DIR

        # 1. Resolve destination directory
        dest = if target_dir
          target_dir.expand
        elsif name && name != "." && name != "./"
          Path.new(Dir.current).join(name).expand
        else
          Path.new(Dir.current).expand
        end

        # 2. Resolve project title and slug
        raw_name = if name && name != "." && name != "./"
          name
        else
          dest.basename
        end
        raw_name = "MyGame" if raw_name.empty? || raw_name == "."

        proj_slug = raw_name.underscore
        proj_title = raw_name.split(/[-_]/).map(&.capitalize).join(" ")

        # 3. Locate template source
        template_dir = root.join("template")
        use_baked = Core::BakedFileSystem.files_with_prefix("template").size > 0

        unless use_baked || Dir.exists?(template_dir)
          if (exe = Process.executable_path)
            cand = Path.new(exe).parent.parent.join("template")
            template_dir = cand if Dir.exists?(cand)
          end
        end
        unless use_baked || Dir.exists?(template_dir)
          if (global_root = Core::Env.global_libgodot_path)
            cand = global_root.join("template")
            template_dir = cand if Dir.exists?(cand)
          end
        end

        unless use_baked || Dir.exists?(template_dir)
          Core::Logger.error("Starter template assets not found in BakedFileSystem or on disk.")
          return 1
        end

        # 4. Check target directory emptiness
        if Dir.exists?(dest)
          entries = Dir.children(dest).reject { |c| c.starts_with?(".") }
          if !entries.empty? && !force
            Core::Logger.error("Target directory '#{dest}' is not empty (#{entries.size} files/directories found). Use --force to proceed.")
            return 1
          end
        else
          FileUtils.mkdir_p(dest)
        end

        Core::Logger.step("Scaffold", "Creating new Lapis game '#{proj_title}' at #{dest}...")

        # 5. Copy and customize template files
        if use_baked
          Core::BakedFileSystem.extract_folder("template", dest)
          customize_project_files(dest, proj_title, proj_slug, root, local_dep)
        else
          copy_template_dir(template_dir, dest, proj_title, proj_slug, root, local_dep)
        end

        # Ensure godot-version.yml exists
        ver_dest = dest.join("godot-version.yml")
        unless File.exists?(ver_dest)
          if File.exists?(root.join("godot-version.yml"))
            FileUtils.cp(root.join("godot-version.yml"), ver_dest)
          elsif Core::BakedFileSystem.has_file?("godot-version.yml")
            Core::BakedFileSystem.extract_file("godot-version.yml", ver_dest)
          end
        end

        # 6. Bundle compiled Crystal plugin libraries into addons/crystal_integration/bin/ and dependencies into bin/
        game_bin = dest.join("bin")
        FileUtils.mkdir_p(game_bin)
        Commands::Deps.run(["-t", game_bin.to_s])

        addon_bin = dest.join("addons/crystal_integration/bin")
        FileUtils.mkdir_p(addon_bin)

        candidate_bin_dirs = [
          root.join("bin"),
          root.join("addons/crystal_integration/bin"),
        ]
        if (exe = Process.executable_path)
          exe_p = Path.new(exe)
          candidate_bin_dirs << exe_p.parent.join("addons/crystal_integration/bin")
          candidate_bin_dirs << exe_p.parent.parent.join("share/lapis/addons/crystal_integration/bin")
          candidate_bin_dirs << exe_p.parent.parent.join("addons/crystal_integration/bin")
        end
        candidate_bin_dirs << Commands::Install.config_dir.join("addons/crystal_integration/bin")

        needed_libs = if Core::Env.windows?
          ["crystal_bridge.dll", "plugin.dll", "gc.dll", "iconv-2.dll", "pcre2-8.dll", "libgodot.dll"]
        elsif Core::Env.macos?
          ["crystal_bridge.dylib", "plugin.dylib", "libgodot.dylib"]
        else
          ["crystal_bridge.so", "plugin.so", "libgodot.so"]
        end

        needed_libs.each do |lib_name|
          src = candidate_bin_dirs.compact_map { |d| d.join(lib_name) if File.exists?(d.join(lib_name)) }.first?
          if src
            Commands::Deps.safe_copy(src, addon_bin.join(lib_name))
            Commands::Deps.safe_copy(src, game_bin.join(lib_name)) if ["crystal_bridge.dll", "crystal_bridge.so", "crystal_bridge.dylib"].includes?(lib_name)
          end
        end

        # 7. Automatically download and install current Godot engine version into project root
        unless skip_godot
          godot_dest = dest.join("godot#{Core::Env.exe_ext}")
          if File.exists?(godot_dest)
            Core::Logger.info("Godot binary already exists at #{godot_dest}")
          else
            target_ver = Commands::Setup.resolve_version(dest, nil)
            platform_suffix = if Core::Env.windows?
              "win64.exe.zip"
            elsif Core::Env.macos?
              "macos.universal.zip"
            else
              "linux.x86_64.zip"
            end
            url = "https://github.com/godotengine/godot-builds/releases/download/#{target_ver}/Godot_v#{target_ver}_#{platform_suffix}"
            begin
              Core::Logger.step("Scaffold", "Downloading Godot engine (#{target_ver}) to #{godot_dest.basename}...")
              success = Commands::Setup.download_and_extract(url, godot_dest)
              if success && File.exists?(godot_dest)
                Core::Logger.success("Installed Godot engine binary at #{godot_dest}!")
              else
                Core::Logger.warn("Notice: Could not download Godot engine automatically. Please place your Godot binary at #{godot_dest}")
              end
            rescue ex
              Core::Logger.warn("Notice: Godot engine download skipped (offline or network error: #{ex.message}). Please place your Godot binary at #{godot_dest}")
            end
          end
        end

        Core::Logger.success("New Lapis game '#{proj_title}' created successfully at #{dest}!")
        puts
        puts "\e[32mNext steps:\e[0m"
        if dest != Path.new(Dir.current).expand
          puts "  cd #{dest}"
        end
        puts "  lapis build game          # Compile game library (bin/#{Core::Env.game_file})"
        puts "  lapis editor              # Launch in Godot Editor"
        puts
        0
      end

      def self.scaffold_example(name : String, target_dir : Path?) : Int32
        root = Core::Env::ROOT_DIR
        ex_dir = target_dir || root.join("examples", name)

        if Dir.exists?(ex_dir)
          Core::Logger.error("Target directory already exists: #{ex_dir}")
          return 1
        end

        Core::Logger.step("Scaffold", "Creating new Lapis example '#{name}' at #{ex_dir}...")
        FileUtils.mkdir_p(ex_dir.join("src"))
        FileUtils.mkdir_p(ex_dir.join("scenes"))
        FileUtils.mkdir_p(ex_dir.join("bin"))

        # project.godot
        File.write(ex_dir.join("project.godot"), <<-GODOT
config_version=5

[application]

config/name="#{name}"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.3", "Forward Plus")
GODOT
        )

        # shard.yml
        File.write(ex_dir.join("shard.yml"), <<-YAML
name: #{name}
version: 0.1.0

dependencies:
  lapis:
    path: ../..
YAML
        )

        # godot-version.yml
        version_file = root.join("godot-version.yml")
        if File.exists?(version_file)
          FileUtils.cp(version_file, ex_dir.join("godot-version.yml"))
        elsif Core::BakedFileSystem.has_file?("godot-version.yml")
          Core::BakedFileSystem.extract_file("godot-version.yml", ex_dir.join("godot-version.yml"))
        else
          File.write(ex_dir.join("godot-version.yml"), "version: \"4.8-dev6\"\n")
        end

        # src/main.cr
        File.write(ex_dir.join("src/main.cr"), <<-CR
require "lapis"

node #{name.camelcase} < Node2D do
  def _ready : Void
    Godot.print("#{name.camelcase} initialized successfully!")
  end
end
CR
        )

        # scenes/main.tscn
        File.write(ex_dir.join("scenes/main.tscn"), <<-TSCN
[gd_scene format=3]

[node name="Main" type="#{name.camelcase}"]
TSCN
        )

        Core::Logger.success("Example '#{name}' scaffolded successfully at #{ex_dir}!")
        0
      end

      def self.scaffold_addon(name : String, target_dir : Path?, author : String?, desc : String?) : Int32
        root = Core::Env::ROOT_DIR
        addon_dir = target_dir || root.join("addons", name)

        if Dir.exists?(addon_dir)
          Core::Logger.error("Target addon directory already exists: #{addon_dir}")
          return 1
        end

        Core::Logger.step("Scaffold", "Creating new GDExtension addon '#{name}' at #{addon_dir}...")
        FileUtils.mkdir_p(addon_dir.join("src"))
        FileUtils.mkdir_p(addon_dir.join("bin"))

        # .gdextension manifest
        File.write(addon_dir.join("#{name}.gdextension"), <<-GDM
[configuration]
entry_symbol = "crystal_godot_init"
compatibility_minimum = "4.1"
reloadable = true

[libraries]
windows.debug.x86_64 = "res://addons/#{name}/bin/#{name}.dll"
windows.release.x86_64 = "res://addons/#{name}/bin/#{name}.dll"
linux.debug.x86_64 = "res://addons/#{name}/bin/#{name}.so"
linux.release.x86_64 = "res://addons/#{name}/bin/#{name}.so"
macos.debug = "res://addons/#{name}/bin/#{name}.dylib"
macos.release = "res://addons/#{name}/bin/#{name}.dylib"
GDM
        )

        # shard.yml
        File.write(addon_dir.join("shard.yml"), <<-YAML
name: #{name}
version: 0.1.0
authors:
  - #{author || "Author"}
description: #{desc || "#{name} GDExtension Addon"}

dependencies:
  lapis:
    path: ../..
YAML
        )

        # godot-version.yml
        version_file = root.join("godot-version.yml")
        if File.exists?(version_file)
          FileUtils.cp(version_file, addon_dir.join("godot-version.yml"))
        elsif Core::BakedFileSystem.has_file?("godot-version.yml")
          Core::BakedFileSystem.extract_file("godot-version.yml", addon_dir.join("godot-version.yml"))
        else
          File.write(addon_dir.join("godot-version.yml"), "version: \"4.8-dev6\"\n")
        end

        # src/main.cr
        File.write(addon_dir.join("src/main.cr"), <<-CR
require "lapis"

@[Tool]
node #{name.camelcase}Node < Node do
  def _ready : Void
    Godot.print("#{name.camelcase}Node ready!")
  end
end
CR
        )

        Core::Logger.success("Addon '#{name}' scaffolded successfully at #{addon_dir}!")
        0
      end

      def self.run(args : Array(String)) : Int32
        if args.empty? || args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        kind = args[0]
        target_path : String? = nil
        explicit_name : String? = nil
        force : Bool = false
        local_dep : Bool = false
        skip_godot : Bool = false
        author : String? = nil
        desc : String? = nil

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis scaffold #{kind} [name] [options]"
          opts.on("-t DIR", "--target=DIR", "Explicit target directory") { |d| target_path = d }
          opts.on("-n NAME", "--name=NAME", "Explicit project name") { |n| explicit_name = n }
          opts.on("-f", "--force", "Overwrite existing files in non-empty target directory") { force = true }
          opts.on("-l", "--local", "Use local relative path for lapis dependency in shard.yml") { local_dep = true }
          opts.on("--skip-godot", "Skip automatic Godot engine download") { skip_godot = true }
          opts.on("-a NAME", "--author=NAME", "Addon author name") { |a| author = a }
          opts.on("-d TEXT", "--desc=TEXT", "Addon description") { |text| desc = text }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
        end

        remaining_args = [] of String
        parser.unknown_args do |rest|
          remaining_args = rest
        end

        parser.parse(args[1..])

        # Positional name from remaining args
        name = explicit_name || (remaining_args.empty? ? nil : remaining_args[0])
        target_dir = (tp = target_path) ? Path.new(tp).expand : nil

        case kind
        when "game", "project"
          scaffold_game(name, target_dir, force: force, local_dep: local_dep, skip_godot: skip_godot)
        when "example"
          if name.nil?
            Core::Logger.error("Name is required: lapis scaffold example <name>")
            puts
            print_help
            return 1
          end
          scaffold_example(name, target_dir)
        when "addon"
          if name.nil?
            Core::Logger.error("Name is required: lapis scaffold addon <name>")
            puts
            print_help
            return 1
          end
          scaffold_addon(name, target_dir, author, desc)
        else
          Core::Logger.error("Unknown scaffold type: '#{kind}'. Expected 'game', 'project', 'addon', or 'example'.")
          puts
          print_help
          1
        end
      end
    end
  end
end
