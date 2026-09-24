require "../core/env"
require "../core/logger"
require "file_utils"
require "option_parser"

module Lapis
  module Commands
    module Sync
      def self.safe_copy(src : Path | String, dst : Path | String) : Bool
        return false unless File.exists?(src)
        return false if Core::Env.is_foreign_binary?(src)
        return true if File.expand_path(src.to_s) == File.expand_path(dst.to_s)

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
      def self.sync_addon_directory(src_addon : Path, dst_addon : Path)
        return unless Dir.exists?(src_addon)
        FileUtils.mkdir_p(dst_addon) unless Dir.exists?(dst_addon)

        pattern = src_addon.to_s.gsub('\\', '/') + "/**/*"
        Dir.glob(pattern).each do |file|
          next if Dir.exists?(file)
          # Skip bin directory inside addon (handled separately by bin sync)
          rel = Path.new(file).relative_to(src_addon)
          rel_str = rel.to_s.gsub('\\', '/')
          next if rel_str == "bin" || rel_str.starts_with?("bin/")

          dst_file = dst_addon.join(rel)
          safe_copy(file, dst_file)
        end
      end

      # Ensure .godot/extension_list.cfg contains all active GDExtension manifests
      def self.ensure_extension_list(project_dir : Path)
        addons_dir = project_dir.join("addons")
        return unless Dir.exists?(addons_dir)

        godot_dir = project_dir.join(".godot")
        FileUtils.mkdir_p(godot_dir) unless Dir.exists?(godot_dir)

        ext_list = godot_dir.join("extension_list.cfg")
        existing_lines = File.exists?(ext_list) ? File.read(ext_list).lines.map(&.strip).reject(&.empty?) : [] of String
        # Clean up legacy or wrong entries
        existing_lines.reject! { |l| l.ends_with?("crystal_integration.gdextension") }

        pattern = addons_dir.to_s.gsub('\\', '/') + "/**/*.gdextension"
        Dir.glob(pattern).sort.each do |gdext_path|
          rel = Path.new(gdext_path).relative_to(project_dir).to_s.gsub('\\', '/')
          entry = "res://#{rel}"
          unless existing_lines.includes?(entry)
            existing_lines << entry
          end
        end

        # Always ensure primary crystal extension if crystal_integration addon exists
        primary_ext = "res://addons/crystal_integration/crystal.gdextension"
        if Dir.exists?(addons_dir.join("crystal_integration")) && !existing_lines.includes?(primary_ext)
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
  --addons-only         Sync only GDExtension addons and manifests
  --bins-only           Sync only compiled binaries and runtime libraries
  -h, --help            Show this help screen

Examples:
  lapis sync
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

        OptionParser.parse(args) do |parser|
          parser.banner = "Usage: lapis sync [options]"
          parser.on("-t DIR", "--target-bin=DIR", "Explicit target bin directory") { |dir| target_bin = dir }
          parser.on("--target=DIR", "Explicit target bin directory") { |dir| target_bin = dir }
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
            ensure_extension_list(root.join("performance"))

            addon_targets.each do |dst|
              sync_addon_directory(src_addon, dst)
            end
            Core::Logger.step("Sync", "Addons and manifests synchronized across #{addon_targets.size} targets")
          end
        end

        # 2. Sync binaries
        unless addons_only
          platform_files = Core::Env.platform_bin_files.dup

          # Purge foreign binaries from root bin directory
          Core::Env.purge_foreign_binaries(bin_dir)

          synced_count = 0
          target_dirs.each do |dir|
            next if dir == bin_dir
            FileUtils.mkdir_p(dir) unless Dir.exists?(dir)

            # Purge foreign platform binaries (.so on Windows, .dll on Linux)
            Core::Env.purge_foreign_binaries(dir)

            platform_files.each do |bin_name|
              src = if File.exists?(bin_dir.join(bin_name))
                      bin_dir.join(bin_name)
                    elsif File.exists?(root.join("addons/crystal_integration/bin").join(bin_name)) && root.join("addons/crystal_integration/bin") != dir
                      root.join("addons/crystal_integration/bin").join(bin_name)
                    else
                      nil
                    end

              if src && safe_copy(src, dir.join(bin_name))
                synced_count += 1
              end
            end

            # plugin file is strictly synced to crystal_integration/bin and root bin
            dir_str = dir.to_s.gsub('\\', '/')
            is_crystal_integration = dir_str.ends_with?("addons/crystal_integration/bin") || dir_str == root.join("bin").to_s.gsub('\\', '/')
            plugin_target = dir.join(Core::Env.plugin_file)

            if is_crystal_integration
              src_plugin = bin_dir.join(Core::Env.plugin_file)
              safe_copy(src_plugin, plugin_target)
            else
              # Purge any stray plugin binaries from non-crystal_integration addon directories
              ["plugin.dll", "plugin.so", "plugin.dylib"].each do |p_lib|
                stray = dir.join(p_lib)
                File.delete(stray) if File.exists?(stray)
              end
            end

            # Purge foreign stray files (.cr, .cr.uid, ~* temporary shadow copies)
            if Dir.exists?(dir)
              Dir.each_child(dir) do |item|
                full_path = dir.join(item)
                next if Dir.exists?(full_path)

                if item.ends_with?(".cr") || item.ends_with?(".cr.uid") || item.starts_with?("~")
                  begin
                    File.delete(full_path)
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
          Dir.glob(root.join("examples/*").to_s).each do |ex_dir|
            consumer_projs << "examples/#{File.basename(ex_dir)}" if File.directory?(ex_dir)
          end
          consumer_projs.each do |proj|
            proj_dir = root.join(proj)
            src_game = proj_dir.join("bin", game_file)
            if File.exists?(src_game)
              dst_game = proj_dir.join("addons/crystal_integration/bin", game_file)
              safe_copy(src_game, dst_game)
              dst_bin_game = proj_dir.join("bin/addons/crystal_integration/bin", game_file)
              safe_copy(src_game, dst_bin_game)
              if Core::Env.windows?
                src_pdb = proj_dir.join("bin", "game.pdb")
                if File.exists?(src_pdb)
                  safe_copy(src_pdb, proj_dir.join("addons/crystal_integration/bin", "game.pdb"))
                  safe_copy(src_pdb, proj_dir.join("bin/addons/crystal_integration/bin", "game.pdb"))
                end
              end
            end
          end

          Core::Logger.step("Sync", "Binaries synchronized across #{target_dirs.size} destinations")
        end

        # 3. Ensure dependencies and .gdignore across all targets
        (["."] + ["test", "template", "template-addon", "performance", "benchmarks", "godot-src", "examples/basic_demo"]).each do |proj|
          proj_dir = root.join(proj)
          next unless Dir.exists?(proj_dir)
          root_gd = proj_dir.join(".gdignore")
          File.write(root_gd, "") if (proj == "benchmarks" || proj == "godot-src") && !File.exists?(root_gd)
          bin_gd = proj_dir.join("bin/.gdignore")
          File.write(bin_gd, "") if Dir.exists?(proj_dir.join("bin")) && !File.exists?(bin_gd)

          if File.exists?(proj_dir.join("shard.yml")) && !Dir.exists?(proj_dir.join("lib/lapis")) && proj != "."
            if shards_exe = Core::ProcessRunner.find_executable("shards")
              Core::ProcessRunner.run(shards_exe, ["install"], chdir: proj_dir.to_s)
            end
          end

          lib_gd = proj_dir.join("lib/.gdignore")
          if Dir.exists?(proj_dir.join("lib")) && !File.exists?(lib_gd)
            File.write(lib_gd, "")
          end
        end

        # 4. Sync godot-version.yml across all consumer projects
        root_version_yml = root.join("godot-version.yml")
        if File.exists?(root_version_yml)
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
            safe_copy(root_version_yml, dst_yml)
          end
        end

        0
      end
    end
  end
end
