require "../core/env"
require "../core/logger"
require "../core/baked_file_system"
require "./deps"
require "./setup"
require "./install"
require "../core/godot_finder"
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
  addon <name>           Scaffold a GDExtension addon (in current project if project.godot exists, or standalone project)

Options:
  -t, --target=DIR       Explicit target output directory
  -n, --name=NAME        Explicit project name
  -f, --force            Overwrite existing files in non-empty target directory
  -l, --local            Use local relative path for lapis dependency in shard.yml
  --skip-godot           Skip automatic Godot engine download
  -a, --author=NAME      Author name for shard.yml (addons only)
  -d, --desc=TEXT        Description for shard.yml (addons only)
  --no-git, --skip-git   Do not initialize git repository in new addon directory
  --git                  Force git repository initialization in new addon directory
  -h, --help             Show this help screen

Examples:
  lapis new game                     # Scaffold in current working directory
  lapis new project my_game          # Scaffold into ./my_game
  lapis new addon my_inventory       # Add addon to current Godot project (or standalone if none)
  lapis new addon my_inventory --no-git # Add addon and keep it tracked by parent project git
  lapis scaffold addon my_tool -a "Sol-Vin" -d "Editor tooling addon"
  lapis new example 3d_fps
HELP
      end

      private def self.customize_project_files(
        dst_dir : Path,
        proj_title : String,
        proj_slug : String,
        root : Path,
        local_dep : Bool,
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

        if local_dep || (Core::Env.is_libgodot_repo?(root) && dest_expanded.starts_with?("#{root_expanded}/examples"))
          rel_root = Path.new(root).relative_to(dst_dir).to_s.gsub('\\', '/')
          rel_root = "./#{rel_root}" unless rel_root.starts_with?(".")
          dep_str = "  lapis:\n    path: #{rel_root}"
          File.write(dst_dir.join("shard.override.yml"), "dependencies:\n  lapis:\n    path: #{rel_root}\n")
        else
          ver = Core::GodotFinder.expected_version(dst_dir.to_s)
          dep_str = "  lapis:\n    github: sol-vin/lapis\n    tag: #{ver}"
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
        local_dep : Bool,
      ) : Void
        excludes = [
          ".godot", ".git", ".uid", "crash_dump",
          "test_ext.log", "template_ext.log",
          "bin", "lib", "dist",
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
        skip_godot : Bool = false,
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
          if Core::BakedFileSystem.files_with_prefix("addons/crystal_integration").size > 0
            Core::BakedFileSystem.extract_folder("addons/crystal_integration", dest.join("addons/crystal_integration"))
          end
          customize_project_files(dest, proj_title, proj_slug, root, local_dep)
        else
          copy_template_dir(template_dir, dest, proj_title, proj_slug, root, local_dep)
          addon_src = root.join("addons/crystal_integration")
          addon_dest = dest.join("addons/crystal_integration")
          if !Dir.exists?(addon_dest) && Dir.exists?(addon_src)
            FileUtils.mkdir_p(addon_dest)
            ["crystal.gdextension", "plugin.cfg", "plugin.gd", "crystal_icon.svg"].each do |f|
              FileUtils.cp(addon_src.join(f), addon_dest.join(f)) if File.exists?(addon_src.join(f))
            end
          end
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

        addon_bin = dest.join("addons/crystal_integration/bin")
        FileUtils.mkdir_p(addon_bin)

        # First, ensure any libraries embedded in BakedFileSystem are copied to both addon_bin and game_bin
        ["crystal_bridge.dll", "crystal_bridge.so", "crystal_bridge.dylib", "gc.dll", "iconv-2.dll", "pcre2-8.dll"].each do |lib_name|
          src_in_addon = addon_bin.join(lib_name)
          if File.exists?(src_in_addon)
            Commands::Deps.safe_copy(src_in_addon, game_bin.join(lib_name))
          end
        end

        candidate_bin_dirs = Core::Env.candidate_runtime_dirs(root)

        needed_libs = if Core::Env.windows?
                        ["crystal_bridge.dll", "plugin.dll", "gc.dll", "iconv-2.dll", "pcre2-8.dll", "libgodot.dll"]
                      elsif Core::Env.macos?
                        ["crystal_bridge.dylib", "plugin.dylib", "libgodot.dylib"]
                      else
                        ["crystal_bridge.so", "plugin.so", "libgodot.so"]
                      end

        needed_libs.each do |lib_name|
          target_addon_file = addon_bin.join(lib_name)
          unless File.exists?(target_addon_file)
            src = candidate_bin_dirs.compact_map { |d| d.join(lib_name) if File.exists?(d.join(lib_name)) }.first?
            if src
              Commands::Deps.safe_copy(src, target_addon_file)
              Commands::Deps.safe_copy(src, game_bin.join(lib_name)) if ["crystal_bridge.dll", "crystal_bridge.so", "crystal_bridge.dylib", "gc.dll", "iconv-2.dll", "pcre2-8.dll"].includes?(lib_name)
            end
          end
        end

        # Safety: purge any foreign platform binaries in newly scaffolded project
        Core::Env.purge_foreign_binaries(addon_bin)
        Core::Env.purge_foreign_binaries(game_bin)

        # Verification: ensure GDExtension loader bridge exists
        bridge_file = Core::Env.bridge_file
        unless File.exists?(addon_bin.join(bridge_file))
          Core::Logger.error("Failed to bundle required GDExtension bridge (#{bridge_file}) into #{addon_bin}.")
          return 1
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

      def self.find_godot_project_root(start_dir : Path) : Path?
        p = start_dir.expand
        loop do
          return p if File.exists?(p.join("project.godot"))
          parent = p.parent
          break if parent == p
          p = parent
        end
        nil
      end

      def self.inside_git_repo?(dir : Path) : Bool
        return false unless Process.find_executable("git")
        res = Core::ProcessRunner.capture("git", ["rev-parse", "--is-inside-work-tree"], chdir: dir.to_s)
        res[:status] == 0 && res[:output].strip == "true"
      rescue
        false
      end

      def self.init_git_repo(dir : Path) : Bool
        return false unless Process.find_executable("git")
        res = Core::ProcessRunner.capture("git", ["init"], chdir: dir.to_s)
        res[:status] == 0
      rescue
        false
      end

      def self.enable_plugin_in_godot_project(godot_proj_path : Path, plugin_cfg_res_path : String) : Void
        return unless File.exists?(godot_proj_path)
        content = File.read(godot_proj_path)
        return if content.includes?(plugin_cfg_res_path)

        if content =~ /\[editor_plugins\]\s*enabled=PackedStringArray\(([^)]*)\)/
          inner = $1.strip
          new_inner = inner.empty? ? "\"#{plugin_cfg_res_path}\"" : "#{inner}, \"#{plugin_cfg_res_path}\""
          content = content.sub(/\[editor_plugins\]\s*enabled=PackedStringArray\([^)]*\)/, "[editor_plugins]\n\nenabled=PackedStringArray(#{new_inner})")
        elsif content.includes?("[editor_plugins]")
          content = content.sub("[editor_plugins]", "[editor_plugins]\n\nenabled=PackedStringArray(\"#{plugin_cfg_res_path}\")")
        else
          content = content.rstrip + "\n\n[editor_plugins]\n\nenabled=PackedStringArray(\"#{plugin_cfg_res_path}\")\n"
        end
        File.write(godot_proj_path, content)
      rescue ex
        Core::Logger.debug("Notice: Could not automatically enable plugin in project.godot: #{ex.message}")
      end

      private def self.customize_addon_project_files(
        dest : Path,
        title : String,
        slug : String,
        pascal : String,
        author : String?,
        desc : String?,
        root : Path,
        local_dep : Bool,
      ) : Void
        addon_dir = dest.join("addons", slug)

        # project.godot
        p_godot = dest.join("project.godot")
        if File.exists?(p_godot)
          c = File.read(p_godot)
          c = c.gsub("Crystal Addon Test Runner", "#{title} Test Runner")
          c = c.gsub("res://addons/crystal_addon/plugin.cfg", "res://addons/#{slug}/plugin.cfg")
          File.write(p_godot, c)
        end

        # Makefile
        makefile = dest.join("Makefile")
        if File.exists?(makefile)
          c = File.read(makefile)
          c = c.gsub("crystal_addon", slug)
          File.write(makefile, c)
        end

        # shard.yml
        shard = dest.join("shard.yml")
        if File.exists?(shard)
          c = File.read(shard)
          c = c.gsub(/name:\s*[^\r\n]+/, "name: #{slug}")
          c = c.gsub(/authors:\s*\n\s*-\s*[^\r\n]+/, "authors:\n  - #{author}") if author
          dest_expanded = dest.expand.to_s.gsub('\\', '/')
          root_expanded = root.expand.to_s.gsub('\\', '/')
          if local_dep || (Core::Env.is_libgodot_repo?(root) && dest_expanded.starts_with?("#{root_expanded}/examples"))
            rel_root = Path.new(root).relative_to(dest).to_s.gsub('\\', '/')
            rel_root = "./#{rel_root}" unless rel_root.starts_with?(".")
            c = c.gsub(/path:\s*[^\r\n]+/, "path: #{rel_root}")
            File.write(dest.join("shard.override.yml"), "dependencies:\n  lapis:\n    path: #{rel_root}\n")
          else
            ver = Core::GodotFinder.expected_version(dest.to_s)
            c = c.gsub(/path:\s*[^\r\n]+/, "github: sol-vin/lapis\n    tag: #{ver}")
            c = c.gsub(/branch:\s*[^\r\n]+/, "tag: #{ver}")
          end
          File.write(shard, c)
        end

        # README.md
        readme = dest.join("README.md")
        if File.exists?(readme)
          c = File.read(readme)
          c = c.gsub("Crystal Addon", title)
          c = c.gsub("crystal_addon", slug)
          c = c.gsub("CrystalAddon", pascal)
          File.write(readme, c)
        end

        # addons/<slug>/plugin.cfg
        plugin_cfg = addon_dir.join("plugin.cfg")
        if File.exists?(plugin_cfg)
          c = File.read(plugin_cfg)
          c = c.gsub(/name="[^"]*"/, "name=\"#{title}\"")
          c = c.gsub(/description="[^"]*"/, "description=\"#{desc || "#{title} GDExtension Addon"}\"")
          c = c.gsub(/author="[^"]*"/, "author=\"#{author || "Developer"}\"")
          File.write(plugin_cfg, c)
        end

        # addons/<slug>/plugin.gd
        plugin_gd = addon_dir.join("plugin.gd")
        if File.exists?(plugin_gd)
          c = File.read(plugin_gd)
          c = c.gsub("CrystalAddonPlugin", "#{pascal}Plugin")
          File.write(plugin_gd, c)
        end

        # addons/<slug>/<slug>.gdextension and root <slug>.gdextension
        [addon_dir.join("#{slug}.gdextension"), dest.join("#{slug}.gdextension")].each do |gdm|
          if File.exists?(gdm)
            c = File.read(gdm)
            c = c.gsub("crystal_addon", slug)
            c = c.gsub("crystal_godot_init", "crystal_library_init")
            File.write(gdm, c)
          end
        end

        # src/main.cr
        main_cr = dest.join("src/main.cr")
        if File.exists?(main_cr)
          c = File.read(main_cr)
          c = c.gsub("CrystalAddonBanner", "#{pascal}Banner")
          c = c.gsub("CrystalAddonPlugin", "#{pascal}Plugin")
          c = c.gsub("CrystalAddon", pascal)
          c = c.gsub("Crystal Addon", title)
          File.write(main_cr, c)
        end

        # spec/main_spec.cr
        main_spec = dest.join("spec/main_spec.cr")
        if File.exists?(main_spec)
          c = File.read(main_spec)
          c = c.gsub("CrystalAddonBanner", "#{pascal}Banner")
          c = c.gsub("CrystalAddonPlugin", "#{pascal}Plugin")
          c = c.gsub("CrystalAddon", pascal)
          File.write(main_spec, c)
        end

        # spec/editor/editor_spec.cr
        editor_spec = dest.join("spec/editor/editor_spec.cr")
        if File.exists?(editor_spec)
          c = File.read(editor_spec)
          c = c.gsub("CrystalAddonBanner", "#{pascal}Banner")
          c = c.gsub("CrystalAddonPlugin", "#{pascal}Plugin")
          c = c.gsub("CrystalAddon", pascal)
          File.write(editor_spec, c)
        end
      end

      def self.scaffold_addon(
        name : String,
        target_dir : Path?,
        author : String?,
        desc : String?,
        no_git : Bool = false,
        force_git : Bool = false,
        force : Bool = false,
        local_dep : Bool = false,
        pascal_name : String? = nil,
      ) : Int32
        root = Core::Env::ROOT_DIR
        curr = Path.new(Dir.current).expand

        # Check if we are inside an existing Godot project (project.godot in current working directory)
        project_root = File.exists?(curr.join("project.godot")) ? curr : nil

        if project_root
          # -------------------------------------------------------------------------
          # Mode A: In-Project Addon
          # Adds the addon to the current Godot project under addons/<name>/
          # -------------------------------------------------------------------------
          addon_dir = target_dir || project_root.join("addons", name.underscore)

          if Dir.exists?(addon_dir)
            entries = Dir.children(addon_dir).reject { |c| c.starts_with?(".") }
            if !entries.empty? && !force
              Core::Logger.error("Target addon directory '#{addon_dir}' already exists and is not empty. Use --force to proceed.")
              return 1
            end
          else
            FileUtils.mkdir_p(addon_dir)
          end

          Core::Logger.step("Scaffold", "Adding GDExtension addon '#{name}' to project at #{addon_dir}...")
          FileUtils.mkdir_p(addon_dir.join("src"))
          FileUtils.mkdir_p(addon_dir.join("bin"))
          FileUtils.mkdir_p(addon_dir.join("spec/editor"))
          File.write(addon_dir.join("bin/.gdignore"), "# Godot ignore file\n") unless File.exists?(addon_dir.join("bin/.gdignore"))

          slug = name.underscore
          title = name.split(/[-_]/).map(&.capitalize).join(" ")
          pascal = pascal_name || name.camelcase

          # 1. plugin.cfg
          File.write(addon_dir.join("plugin.cfg"), <<-CFG
[plugin]

name="#{title}"
description="#{desc || "#{title} GDExtension Addon"}"
author="#{author || "Developer"}"
version="0.1.0"
script="plugin.gd"
CFG
          )

          # 2. plugin.gd
          File.write(addon_dir.join("plugin.gd"), <<-GD
@tool
extends #{pascal}Plugin
GD
          )

          # 3. .gdextension manifest
          File.write(addon_dir.join("#{slug}.gdextension"), <<-GDM
[configuration]
entry_symbol = "crystal_library_init"
compatibility_minimum = "4.1"
reloadable = true

[libraries]
windows.debug.x86_64 = "res://addons/#{slug}/bin/crystal_bridge.dll"
windows.release.x86_64 = "res://addons/#{slug}/bin/crystal_bridge.dll"
linux.debug.x86_64 = "res://addons/#{slug}/bin/crystal_bridge.so"
linux.release.x86_64 = "res://addons/#{slug}/bin/crystal_bridge.so"
macos.debug = "res://addons/#{slug}/bin/crystal_bridge.dylib"
macos.release = "res://addons/#{slug}/bin/crystal_bridge.dylib"
macos.debug.arm64 = "res://addons/#{slug}/bin/crystal_bridge.dylib"
macos.release.arm64 = "res://addons/#{slug}/bin/crystal_bridge.dylib"
macos.debug.x86_64 = "res://addons/#{slug}/bin/crystal_bridge.dylib"
macos.release.x86_64 = "res://addons/#{slug}/bin/crystal_bridge.dylib"

[dependencies]
macos.debug = { "res://addons/#{slug}/bin/game.dylib": "" }
macos.release = { "res://addons/#{slug}/bin/game.dylib": "" }
macos.debug.arm64 = { "res://addons/#{slug}/bin/game.dylib": "" }
macos.release.arm64 = { "res://addons/#{slug}/bin/game.dylib": "" }
macos.debug.x86_64 = { "res://addons/#{slug}/bin/game.dylib": "" }
macos.release.x86_64 = { "res://addons/#{slug}/bin/game.dylib": "" }
GDM
          )

          # Stage initial runtime dependencies
          Deps.run(["-t", addon_dir.join("bin").to_s])

          # 4. shard.yml
          dep_str = if local_dep
                      rel_root = Path.new(root).relative_to(addon_dir).to_s.gsub('\\', '/')
                      rel_root = "./#{rel_root}" unless rel_root.starts_with?(".")
                      File.write(addon_dir.join("shard.override.yml"), "dependencies:\n  lapis:\n    path: #{rel_root}\n")
                      "  lapis:\n    path: #{rel_root}"
                    else
                      ver = Core::GodotFinder.expected_version(addon_dir.to_s)
                      "  lapis:\n    github: sol-vin/lapis\n    tag: #{ver}"
                    end

          File.write(addon_dir.join("shard.yml"), <<-YAML
name: #{slug}
version: 0.1.0
authors:
  - #{author || "Developer <developer@example.com>"}
description: #{desc || "#{title} GDExtension Addon"}

dependencies:
#{dep_str}
YAML
          )

          # 5. godot-version.yml
          version_file = project_root.join("godot-version.yml")
          if File.exists?(version_file)
            FileUtils.cp(version_file, addon_dir.join("godot-version.yml"))
          elsif File.exists?(root.join("godot-version.yml"))
            FileUtils.cp(root.join("godot-version.yml"), addon_dir.join("godot-version.yml"))
          elsif Core::BakedFileSystem.has_file?("godot-version.yml")
            Core::BakedFileSystem.extract_file("godot-version.yml", addon_dir.join("godot-version.yml"))
          else
            File.write(addon_dir.join("godot-version.yml"), "version: \"4.8-dev6\"\n")
          end

          # 6. src/main.cr
          File.write(addon_dir.join("src/main.cr"), <<-CR
require "lapis"

{% unless flag?(:release) %}
  require "../spec/editor/**"
{% end %}

# Custom GDExtension Editor Plugin for #{title}
@[Tool]
node #{pascal}Plugin < EditorPlugin do
  def _enter_tree : Void
    Godot.print("[#{pascal}Plugin] Plugin activated in Godot Editor!")
  end

  def _exit_tree : Void
    Godot.print("[#{pascal}Plugin] Plugin deactivated.")
  end
end

# Custom scene node exported by #{title}
@[Tool]
node #{pascal}Node < Node do
  def _ready : Void
    Godot.print("#{pascal}Node ready!")
  end
end
CR
          )

          # 7. spec/main_spec.cr
          FileUtils.mkdir_p(addon_dir.join("spec"))
          File.write(addon_dir.join("spec/main_spec.cr"), <<-CR
require "spec"
require "../src/main"

describe #{pascal}Node do
  it "registers with Godot ClassRegistry" do
    entry = Godot::ClassRegistry.find("#{pascal}Node")
    entry.should_not be_nil
    entry.not_nil!.parent_name.should eq("Node")
  end

  it "is marked as tool node for editor execution" do
    entry = Godot::ClassRegistry.find("#{pascal}Node")
    entry.should_not be_nil
    entry.not_nil!.is_tool.should be_true
  end
end
CR
          )

          # 8. spec/editor/editor_spec.cr
          File.write(addon_dir.join("spec/editor/editor_spec.cr"), <<-CR
require "spec"
require "lapis"

include Lapis::Test

test_suite "Nodes" do
  test "#{pascal}Node is registered" do
    entry = Godot::ClassRegistry.find("#{pascal}Node")
    assert_not_nil entry, "Expected #{pascal}Node to be registered"
    assert_eq entry.not_nil!.parent_name, "Node"
  end
end

test_case "Editor", "#{pascal}Node editor tool verification" do
  entry = Godot::ClassRegistry.find("#{pascal}Node")
  assert_not_nil entry
  assert_true entry.not_nil!.is_tool
end
CR
          )

          # 9. Git repository handling for In-Project Addon
          if no_git
            Core::Logger.info("Skipping git init (--no-git specified); addon will be tracked by main project.")
          elsif force_git
            init_git_repo(addon_dir)
            Core::Logger.success("Initialized standalone git repository at #{addon_dir}.")
          else
            if inside_git_repo?(project_root)
              Core::Logger.info("Addon will be tracked by main project git repository. (Use --git to initialize as standalone repo)")
            else
              init_git_repo(addon_dir)
              Core::Logger.success("Initialized git repository at #{addon_dir}.")
            end
          end

          # 10. Automatically register plugin in project.godot
          enable_plugin_in_godot_project(project_root.join("project.godot"), "res://addons/#{slug}/plugin.cfg")

          Core::Logger.success("GDExtension addon '#{name}' added successfully to #{addon_dir}!")
          puts
          puts "\e[32mNext steps:\e[0m"
          puts "  1. Compile addon library:"
          puts "     \e[1mlapis build\e[0m"
          puts "  2. Open project in Godot Editor (addon enabled in Project Settings -> Plugins):"
          puts "     \e[1mlapis editor\e[0m"
          puts
          0
        else
          # -------------------------------------------------------------------------
          # Mode B: Standalone Addon Project
          # Creates a complete exportable addon project from template-addon
          # -------------------------------------------------------------------------
          dest = if target_dir
                   target_dir.expand
                 elsif name && name != "." && name != "./"
                   curr.join(name).expand
                 else
                   curr
                 end

          slug = name.underscore
          title = name.split(/[-_]/).map(&.capitalize).join(" ")
          pascal = name.camelcase

          template_addon_dir = root.join("template-addon")
          use_baked = Core::BakedFileSystem.files_with_prefix("template-addon").size > 0

          unless use_baked || Dir.exists?(template_addon_dir)
            if (exe = Process.executable_path)
              cand = Path.new(exe).parent.parent.join("template-addon")
              template_addon_dir = cand if Dir.exists?(cand)
            end
          end
          unless use_baked || Dir.exists?(template_addon_dir)
            if (global_root = Core::Env.global_libgodot_path)
              cand = global_root.join("template-addon")
              template_addon_dir = cand if Dir.exists?(cand)
            end
          end

          if Dir.exists?(dest)
            entries = Dir.children(dest).reject { |c| c.starts_with?(".") }
            if !entries.empty? && !force
              Core::Logger.error("Target directory '#{dest}' is not empty (#{entries.size} files found). Use --force to proceed.")
              return 1
            end
          else
            FileUtils.mkdir_p(dest)
          end

          Core::Logger.step("Scaffold", "Creating standalone GDExtension addon project '#{title}' at #{dest}...")

          if use_baked
            Core::BakedFileSystem.extract_folder("template-addon", dest)
          elsif Dir.exists?(template_addon_dir)
            copy_template_dir(template_addon_dir, dest, title, slug, root, local_dep)
          else
            Core::Logger.error("Addon template assets not found in BakedFileSystem or on disk.")
            return 1
          end

          # Rename addons/crystal_addon -> addons/<slug>
          orig_addon = dest.join("addons/crystal_addon")
          new_addon = dest.join("addons", slug)
          if Dir.exists?(orig_addon) && orig_addon != new_addon
            FileUtils.mv(orig_addon.to_s, new_addon.to_s)
          end

          # Rename crystal_addon.gdextension -> <slug>.gdextension
          orig_gdm = new_addon.join("crystal_addon.gdextension")
          new_gdm = new_addon.join("#{slug}.gdextension")
          if File.exists?(orig_gdm) && orig_gdm != new_gdm
            FileUtils.mv(orig_gdm.to_s, new_gdm.to_s)
          end

          # Ensure bin directories and .gdignore exist
          addon_bin = new_addon.join("bin")
          FileUtils.mkdir_p(addon_bin) unless Dir.exists?(addon_bin)
          File.write(addon_bin.join(".gdignore"), "# Godot ignore file\n") unless File.exists?(addon_bin.join(".gdignore"))

          root_bin = dest.join("bin")
          FileUtils.mkdir_p(root_bin) unless Dir.exists?(root_bin)
          File.write(root_bin.join(".gdignore"), "# Godot ignore file\n") unless File.exists?(root_bin.join(".gdignore"))

          # Customize files in dest
          customize_addon_project_files(dest, title, slug, pascal, author, desc, root, local_dep)

          # Also provide root .gdextension for root discovery and backwards compatibility
          if File.exists?(new_gdm)
            FileUtils.cp(new_gdm.to_s, dest.join("#{slug}.gdextension").to_s)
          end

          # Stage runtime dependencies (bridge DLL, gc.dll, libgodot.dll) into addon bin and root bin
          Deps.run(["-t", addon_bin.to_s])
          Deps.run(["-t", root_bin.to_s])

          # Resolve shards dependencies if shards executable is available
          if shards_exe = Process.find_executable("shards")
            Core::Logger.step("Shards", "Resolving dependencies for '#{slug}'...")
            Core::ProcessRunner.run(shards_exe, ["install"], chdir: dest.to_s)
          end

          # Git repository handling for standalone project
          if no_git
            Core::Logger.info("Skipping git init (--no-git specified).")
          else
            init_git_repo(dest)
            Core::Logger.success("Initialized git repository at #{dest}.")
          end

          Core::Logger.success("Standalone addon project '#{title}' created successfully at #{dest}!")
          puts
          puts "\e[32mNext steps:\e[0m"
          if dest != curr
            puts "  cd #{dest}"
          end
          puts "  make                      # Build addon library and stage dependencies"
          puts "  lapis editor              # Launch standalone test runner in Godot Editor"
          puts "  make package RELEASE=1    # Package distributable dist/#{slug}.zip"
          puts
          0
        end
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
        no_git : Bool = false
        force_git : Bool = false
        pascal_name : String? = nil

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis scaffold #{kind} [name] [options]"
          opts.on("-t DIR", "--target=DIR", "Explicit target directory") { |d| target_path = d }
          opts.on("-n NAME", "--name=NAME", "Explicit project name") { |n| explicit_name = n }
          opts.on("-c NAME", "--class=NAME", "Explicit PascalCase class name (e.g. CrShader)") { |c| pascal_name = c }
          opts.on("-f", "--force", "Overwrite existing files in non-empty target directory") { force = true }
          opts.on("-l", "--local", "Use local relative path for lapis dependency in shard.yml") { local_dep = true }
          opts.on("--skip-godot", "Skip automatic Godot engine download") { skip_godot = true }
          opts.on("-a NAME", "--author=NAME", "Addon author name") { |a| author = a }
          opts.on("-d TEXT", "--desc=TEXT", "Addon description") { |text| desc = text }
          opts.on("--no-git", "--skip-git", "Do not initialize git repository in new addon directory") { no_git = true }
          opts.on("--git", "Force git repository initialization in new addon directory") { force_git = true }
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
          scaffold_addon(
            name,
            target_dir,
            author,
            desc,
            no_git: no_git,
            force_git: force_git,
            force: force,
            local_dep: local_dep,
            pascal_name: pascal_name
          )
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
