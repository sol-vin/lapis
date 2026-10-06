require "../core/env"
require "../core/logger"
require "../core/baked_file_system"
require "file_utils"
require "option_parser"

module Lapis
  module Commands
    module Sync
      def self.safe_copy(src : Path | String, dst : Path | String, dry_run : Bool = false) : Bool
        return false unless File.exists?(src)
        return false if Core::Env.is_foreign_binary?(src)
        return true if File.expand_path(src.to_s) == File.expand_path(dst.to_s)

        if dry_run
          Core::Logger.info("[Dry Run] Would sync #{src} -> #{dst}")
          return true
        end

        begin
          dst_path = dst.to_s
          src_info = File.info(src)
          if File.exists?(dst_path)
            dst_info = File.info(dst_path)
            if src_info.size == dst_info.size && src_info.modification_time == dst_info.modification_time
              return true
            end
          end

          dst_dir = File.dirname(dst_path)
          FileUtils.mkdir_p(dst_dir) unless Dir.exists?(dst_dir)
          FileUtils.cp(src.to_s, dst_path)
          File.touch(dst_path, src_info.modification_time) rescue nil
          Core::Logger.debug("Synced #{src} -> #{dst}")
          true
        rescue ex
          Core::Logger.debug("Skipped sync to #{dst} (file locked): #{ex.message}")
          false
        end
      end

      # Sync addons directory tree recursively, preserving structure
      def self.sync_addon_directory(src_addon : Path, dst_addon : Path, dry_run : Bool = false)
        return unless Dir.exists?(src_addon)
        FileUtils.mkdir_p(dst_addon) unless dry_run || Dir.exists?(dst_addon)

        pattern = src_addon.to_s.gsub('\\', '/') + "/**/*"
        Dir.glob(pattern).each do |file|
          next if Dir.exists?(file)
          # Skip bin directory inside addon (handled separately by bin sync)
          rel = Path.new(file).relative_to(src_addon)
          rel_str = rel.to_s.gsub('\\', '/')
          next if rel_str == "bin" || rel_str.starts_with?("bin/")

          dst_file = dst_addon.join(rel)
          safe_copy(file, dst_file, dry_run: dry_run)
        end
      end

      def self.topological_sort_extensions(
        entries : Array(String),
        addon_for_ext : Hash(String, String),
        ext_for_addon : Hash(String, String),
        deps_for_addon : Hash(String, Array(String))
      ) : Array(String)
        sorted = [] of String
        visited = Set(String).new
        visiting = Set(String).new

        entries.each do |entry|
          visit_ext_node(entry, addon_for_ext, ext_for_addon, deps_for_addon, visited, visiting, sorted)
        end
        sorted
      end

      private def self.visit_ext_node(
        ext_item : String,
        addon_for_ext : Hash(String, String),
        ext_for_addon : Hash(String, String),
        deps_for_addon : Hash(String, Array(String)),
        visited : Set(String),
        visiting : Set(String),
        sorted : Array(String)
      ) : Nil
        return if visited.includes?(ext_item)
        return if visiting.includes?(ext_item)
        visiting.add(ext_item)

        if a = addon_for_ext[ext_item]?
          deps_for_addon[a].each do |dep_name|
            if dep_ext = ext_for_addon[dep_name]?
              visit_ext_node(dep_ext, addon_for_ext, ext_for_addon, deps_for_addon, visited, visiting, sorted)
            end
          end
        end

        visiting.delete(ext_item)
        visited.add(ext_item)
        sorted << ext_item
      end

      # Ensure .godot/extension_list.cfg contains all active GDExtension manifests
      def self.ensure_extension_list(project_dir : Path)
        addons_dir = project_dir.join("addons")
        return unless Dir.exists?(addons_dir)

        godot_dir = project_dir.join(".godot")
        FileUtils.mkdir_p(godot_dir) unless Dir.exists?(godot_dir)

        ext_list = godot_dir.join("extension_list.cfg")
        existing_lines = File.exists?(ext_list) ? File.read(ext_list).lines.map(&.strip).reject(&.empty?) : [] of String
        # Clean up legacy, wrong, or non-existent entries
        existing_lines.reject! do |l|
          if l.ends_with?("crystal_integration.gdextension")
            true
          elsif l.starts_with?("res://")
            rel_file = l.sub("res://", "")
            !File.exists?(project_dir.join(rel_file))
          else
            false
          end
        end

        pattern = addons_dir.to_s.gsub('\\', '/') + "/**/*.gdextension"
        discovered_entries = [] of String
        Dir.glob(pattern).sort.each do |gdext_path|
          rel = Path.new(gdext_path).relative_to(project_dir).to_s.gsub('\\', '/')
          entry = "res://#{rel}"
          discovered_entries << entry unless discovered_entries.includes?(entry)
        end

        # Map each extension to its addon folder and inspect dependencies
        addon_for_ext = Hash(String, String).new
        ext_for_addon = Hash(String, String).new
        deps_for_addon = Hash(String, Array(String)).new { |h, k| h[k] = [] of String }

        discovered_entries.each do |ext_entry|
          # e.g. res://addons/dummy_dep_combat/dummy_dep_combat.gdextension
          clean_path = ext_entry.sub(/^res:\/\//, "")
          parts = clean_path.split('/')
          if parts.size >= 2 && parts[0] == "addons"
            aname = parts[1]
            addon_for_ext[ext_entry] = aname
            ext_for_addon[aname] = ext_entry

            cfg_file = project_dir.join("addons", aname, "plugin.cfg")
            if File.exists?(cfg_file)
              File.each_line(cfg_file) do |line|
                if line.strip =~ /dependencies\s*=\s*\[(.*)\]/
                  $1.scan(/["']([^"']+)["']/) do |m|
                    dep_name = m[1].strip
                    deps_for_addon[aname] << dep_name
                  end
                end
              end
            end
          end
        end

        # Topologically sort discovered extensions
        sorted_entries = topological_sort_extensions(discovered_entries, addon_for_ext, ext_for_addon, deps_for_addon)

        sorted_entries.each do |entry|
          unless existing_lines.includes?(entry)
            existing_lines << entry
          end
        end

        # If existing_lines has out-of-order dependencies, re-sort existing_lines based on sorted_entries
        existing_lines.sort_by! do |line|
          idx = sorted_entries.index(line)
          idx ? idx : 9999
        end

        # Always ensure primary crystal extension is at index 0 if crystal_integration addon exists
        primary_ext = "res://addons/crystal_integration/crystal.gdextension"
        if Dir.exists?(addons_dir.join("crystal_integration"))
          existing_lines.delete(primary_ext)
          existing_lines.unshift(primary_ext)
        end

        File.write(ext_list, existing_lines.join("\n") + "\n")
        Core::Logger.debug("Updated extension_list.cfg in #{project_dir}")
      end

      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Binary & Addon Synchronizer ===\e[0m

Usage: lapis sync [options]

Options:
  -t, --target-bin=DIR  Explicit target bin directory to synchronize to
  -n, --dry-run         Preview synchronization actions without modifying files
  --addons-only         Sync only GDExtension addons and manifests
  --bins-only           Sync only compiled binaries and runtime libraries
  -h, --help            Show this help screen

Examples:
  lapis sync
  lapis sync --dry-run
  lapis sync --addons-only
  lapis sync --bins-only
  lapis sync -t custom/game/bin
HELP
      end

      def self.run(args : Array(String)) : Int32
        if args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        target_bin : String? = nil
        addons_only = false
        bins_only = false
        dry_run = false

        OptionParser.parse(args) do |parser|
          parser.banner = "Usage: lapis sync [options]"
          parser.on("-t DIR", "--target-bin=DIR", "Explicit target bin directory") { |dir| target_bin = dir }
          parser.on("--target=DIR", "Explicit target bin directory") { |dir| target_bin = dir }
          parser.on("-n", "--dry-run", "Preview synchronization actions without modifying files") { dry_run = true }
          parser.on("--addons-only", "Sync only addons and manifests") { addons_only = true }
          parser.on("--bins-only", "Sync only compiled binaries and runtime DLLs") { bins_only = true }
          parser.on("-h", "--help", "Show help") { print_help; exit 0 }
        end

        root = Core::Env::ROOT_DIR
        bin_dir = root.join("bin")
        target_dirs = Core::Env.collect_target_bin_dirs(root, target_bin)

        # 1. Sync addons
        unless bins_only
          src_addon = root.join("addons/crystal_integration")
          if Dir.exists?(src_addon)
            addon_targets = [
              root.join("template/addons/crystal_integration"),
              root.join("template-addon/addons/crystal_integration"),
              root.join("performance/addons/crystal_integration"),
            ]

            examples_dir = root.join("examples")
            if Dir.exists?(examples_dir)
              Dir.each_child(examples_dir) do |child|
                ex = examples_dir.join(child)
                if Dir.exists?(ex)
                  addon_targets << ex.join("addons/crystal_integration")
                  ensure_extension_list(ex)
                end
              end
            end

            ensure_extension_list(root)
            ensure_extension_list(root.join("template"))
            ensure_extension_list(root.join("template-addon"))
            ensure_extension_list(root.join("performance"))

            curr = Path.new(Dir.current).expand
            if (File.exists?(curr.join("project.godot")) || Dir.exists?(curr.join("addons"))) && curr != root
              ensure_extension_list(curr)
            end

            addon_targets.each do |dst|
              sync_addon_directory(src_addon, dst, dry_run: dry_run)
            end
            Core::Logger.step("Sync", "Addons and manifests synchronized across #{addon_targets.size} targets")
          end
        end

        # 2. Sync binaries
        unless addons_only
          platform_files = Core::Env.platform_bin_files.dup

          # Purge foreign binaries from root bin directory
          Core::Env.purge_foreign_binaries(bin_dir) unless dry_run

          synced_count = 0
          target_dirs.each do |dir|
            next if dir == bin_dir
            FileUtils.mkdir_p(dir) unless dry_run || Dir.exists?(dir)

            dir_str = dir.to_s.gsub('\\', '/')
            is_addon_bin = dir_str.includes?("/addons/") || dir_str.ends_with?("/addons")
            files_to_sync = if is_addon_bin
                              platform_files.reject { |f| f.starts_with?("libgodot") }
                            else
                              platform_files
                            end

            files_to_sync.each do |bin_name|
              src = if File.exists?(bin_dir.join(bin_name))
                      bin_dir.join(bin_name)
                    elsif File.exists?(root.join("addons/crystal_integration/bin").join(bin_name)) && root.join("addons/crystal_integration/bin") != dir
                      root.join("addons/crystal_integration/bin").join(bin_name)
                    else
                      nil
                    end

              if src && safe_copy(src, dir.join(bin_name), dry_run: dry_run)
                synced_count += 1
              end
            end

            if is_addon_bin
              ["libgodot.dll", "libgodot.lib", "libgodot.so", "libgodot.dylib"].each do |lg|
                stray = dir.join(lg)
                File.delete(stray) if !dry_run && File.exists?(stray)
              end
            end

            # plugin file is strictly synced to crystal_integration/bin and root bin
            is_crystal_integration = dir_str.ends_with?("addons/crystal_integration/bin") || dir_str == root.join("bin").to_s.gsub('\\', '/')
            plugin_target = dir.join(Core::Env.plugin_file)

            if is_crystal_integration
              src_plugin = bin_dir.join(Core::Env.plugin_file)
              safe_copy(src_plugin, plugin_target, dry_run: dry_run)
            else
              # Purge any stray plugin binaries from non-crystal_integration addon directories
              ["plugin.dll", "plugin.so", "plugin.dylib"].each do |p_lib|
                stray = dir.join(p_lib)
                File.delete(stray) if !dry_run && File.exists?(stray)
              end
            end

            # Purge foreign stray files (.cr, .cr.uid, ~* temporary shadow copies)
            if Dir.exists?(dir)
              Dir.each_child(dir) do |item|
                full_path = dir.join(item)
                next if Dir.exists?(full_path)

                if item.ends_with?(".cr") || item.ends_with?(".cr.uid") || item.starts_with?("~")
                  begin
                    File.delete(full_path) unless dry_run
                    Core::Logger.debug("Purged temporary file: #{full_path}")
                  rescue
                  end
                end
              end
            end
          end

          # Sync game binary to corresponding addons/crystal_integration/bin for consumer projects
          game_file = Core::Env.game_file
          consumer_projs = ["test", "template", "performance"]
          examples_dir = root.join("examples")
          if Dir.exists?(examples_dir)
            Dir.each_child(examples_dir) do |child|
              ex_dir = examples_dir.join(child)
              consumer_projs << "examples/#{child}" if File.directory?(ex_dir)
            end
          end
          consumer_projs.each do |proj|
            proj_dir = root.join(proj)
            src_game = proj_dir.join("bin", game_file)
            if File.exists?(src_game)
              dst_game = proj_dir.join("addons/crystal_integration/bin", game_file)
              safe_copy(src_game, dst_game, dry_run: dry_run)
              dst_bin_game = proj_dir.join("bin/addons/crystal_integration/bin", game_file)
              safe_copy(src_game, dst_bin_game, dry_run: dry_run)
              if Core::Env.windows?
                src_pdb = proj_dir.join("bin", "game.pdb")
                if File.exists?(src_pdb)
                  safe_copy(src_pdb, proj_dir.join("addons/crystal_integration/bin", "game.pdb"), dry_run: dry_run)
                  safe_copy(src_pdb, proj_dir.join("bin/addons/crystal_integration/bin", "game.pdb"), dry_run: dry_run)
                end
              end
            end
          end

          Core::Logger.step("Sync", "Binaries synchronized across #{target_dirs.size} destinations")
        end

        consumer_dep_targets = ["test", "template", "template-addon", "performance", "benchmarks", "godot-src"]
        ex_dir_check = root.join("examples")
        if Dir.exists?(ex_dir_check)
          Dir.each_child(ex_dir_check) do |child|
            consumer_dep_targets << "examples/#{child}" if Dir.exists?(ex_dir_check.join(child))
          end
        end
        (["."] + consumer_dep_targets).each do |proj|
          proj_dir = root.join(proj)
          next unless Dir.exists?(proj_dir)
          root_gd = proj_dir.join(".gdignore")
          File.write(root_gd, "") if !dry_run && (proj == "benchmarks" || proj == "godot-src") && !File.exists?(root_gd)
          bin_gd = proj_dir.join("bin/.gdignore")
          File.write(bin_gd, "") if !dry_run && Dir.exists?(proj_dir.join("bin")) && !File.exists?(bin_gd)

          if File.exists?(proj_dir.join("shard.yml")) && !Dir.exists?(proj_dir.join("lib/lapis")) && proj != "."
            if Core::BakedFileSystem.files_with_prefix("src").size > 0
              Core::Logger.step("Sync", "Extracting embedded Lapis engine library into #{proj}/lib/lapis...")
              Core::BakedFileSystem.extract_engine_lib(proj_dir.join("lib/lapis")) unless dry_run
            elsif shards_exe = Core::ProcessRunner.find_executable("shards")
              Core::ProcessRunner.run(shards_exe, ["install"], chdir: proj_dir.to_s) unless dry_run
            end
          end

          lib_gd = proj_dir.join("lib/.gdignore")
          if Dir.exists?(proj_dir.join("lib")) && !File.exists?(lib_gd)
            File.write(lib_gd, "") unless dry_run
          end
        end

        # 4. Sync godot-version.yml across all consumer projects
        root_version_yml = root.join("godot-version.yml")
        if File.exists?(root_version_yml)
          ver = Core::GodotFinder.expected_version(root.to_s)
          # Synchronize tag in template shard specifications only if using remote github tag
          ["template", "template-addon"].each do |t_dir|
            ["shard.yml", "shard.release.yml"].each do |s_name|
              s_file = root.join(t_dir, s_name)
              if File.exists?(s_file)
                content = File.read(s_file)
                if content.includes?("github: sol-vin/lapis")
                  updated = content.gsub(/tag:\s*[^\r\n]+/, "tag: #{ver}")
                  File.write(s_file, updated) if !dry_run && updated != content
                end
              end
            end
          end

          consumer_projs = ["test", "template", "template-addon", "performance"]
          examples_dir = root.join("examples")
          if Dir.exists?(examples_dir)
            Dir.each_child(examples_dir) do |child|
              ex = examples_dir.join(child)
              consumer_projs << "examples/#{child}" if Dir.exists?(ex)
            end
          end

          consumer_projs.each do |proj|
            proj_dir = root.join(proj)
            next unless Dir.exists?(proj_dir)
            dst_yml = proj_dir.join("godot-version.yml")
            safe_copy(root_version_yml, dst_yml, dry_run: dry_run)
          end
        end

        # 5. Sync src/bridge/godot_version.h
        bridge_dir = root.join("src/bridge")
        if Dir.exists?(bridge_dir)
          target_ver = Core::GodotFinder.expected_version(root.to_s)
          hdr = bridge_dir.join("godot_version.h")
          hdr_content = <<-H
// Auto-generated target Godot version for C++ GDExtension loader bridge
#pragma once

#ifndef LIBGODOT_TARGET_VERSION
#define LIBGODOT_TARGET_VERSION "#{target_ver}"
#endif

H
          if !dry_run && (!File.exists?(hdr) || File.read(hdr).gsub("\r\n", "\n") != hdr_content.gsub("\r\n", "\n"))
            begin
              File.write(hdr, hdr_content)
              Core::Logger.debug("Updated #{hdr} to #{target_ver}")
            rescue ex
              Core::Logger.debug("Skipped writing #{hdr} (file locked): #{ex.message}")
            end
          end
        end

        # 6. Sync README.md badges and engine version requirement
        readme_file = root.join("README.md")
        if File.exists?(readme_file)
          readme_content = File.read(readme_file)
          updated_readme = readme_content

          # Godot version & badge
          godot_ver = Core::GodotFinder.expected_version(root.to_s)
          escaped_godot = godot_ver.gsub("-", "--")
          updated_readme = updated_readme.gsub(
            /\[!\[Godot\]\(https:\/\/img\.shields\.io\/badge\/Godot-[^-\s)]+(?:--[^-\s)]+)?-blue\.svg([^)]*)\)\]\([^)]+\)/,
            "[![Godot](https://img.shields.io/badge/Godot-#{escaped_godot}-blue.svg\\1)](https://godotengine.org)"
          )

          # Lapis version & badge
          lapis_ver = Lapis::VERSION
          lapis_badge = "[![Lapis](https://img.shields.io/badge/Lapis-#{lapis_ver}-blueviolet.svg?style=flat)](https://github.com/sol-vin/lapis/releases)"
          if updated_readme =~ /\[!\[Lapis\]\(https:\/\/img\.shields\.io\/badge\/Lapis-[^-\s)]+-blueviolet\.svg[^)]*\)\]\([^)]+\)/
            updated_readme = updated_readme.gsub(
              /\[!\[Lapis\]\(https:\/\/img\.shields\.io\/badge\/Lapis-[^-\s)]+-blueviolet\.svg([^)]*)\)\]\([^)]+\)/,
              "[![Lapis](https://img.shields.io/badge/Lapis-#{lapis_ver}-blueviolet.svg\\1)](https://github.com/sol-vin/lapis/releases)"
            )
          else
            if updated_readme.includes?("[![Godot]")
              updated_readme = updated_readme.sub("[![Godot]", "#{lapis_badge}\n[![Godot]")
            elsif updated_readme.includes?("[![Crystal]")
              updated_readme = updated_readme.sub("[![Crystal]", "#{lapis_badge}\n[![Crystal]")
            end
          end

          # Godot Engine requirements text in README
          updated_readme = updated_readme.gsub(
            /-\s*\*\*Godot Engine\*\*:\s*4\.[0-9]+[^+]*\+?[^\n]*/,
            "- **Godot Engine**: #{godot_ver}+ (Standard build, 64-bit)"
          )

          if !dry_run && updated_readme != readme_content
            begin
              File.write(readme_file, updated_readme)
              Core::Logger.info("Synchronized README.md version badges (Godot: #{godot_ver}, Lapis: #{lapis_ver})")
            rescue ex
              Core::Logger.debug("Skipped updating README.md (file locked): #{ex.message}")
            end
          end
        end

        0
      end
    end
  end
end
