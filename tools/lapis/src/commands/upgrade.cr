require "../core/env"
require "../core/logger"
require "../core/process_runner"
require "../core/baked_file_system"
require "../core/godot_finder"
require "./sync"
require "./deps"
require "file_utils"
require "option_parser"

module Lapis
  module Commands
    module Upgrade
      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Project Upgrade Manager ===\e[0m

Usage:
  lapis upgrade [options]

Upgrades an existing Godot + Crystal project to the latest Lapis version.
Refreshes embedded engine bindings in lib/lapis, updates GDExtension manifests,
synchronizes runtime DLLs, migrates shard.yml dependencies, and verifies configs.

Options:
  -p, --path=PATH       Target Godot project directory (default: current directory)
  -f, --force           Force overwrite of existing files even if up to date
  --dry-run             Display upgrade actions without modifying files
  -v, --verbose         Enable verbose logging
  -h, --help            Show this help screen

Examples:
  lapis upgrade
  lapis upgrade -p path/to/my_game
  lapis upgrade --force
HELP
      end

      def self.run(args : Array(String)) : Int32
        if args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        proj_path : String? = nil
        force = false
        dry_run = false

        OptionParser.parse(args) do |parser|
          parser.banner = "Usage: lapis upgrade [options]"
          parser.on("-p PATH", "--path=PATH", "Target Godot project directory") { |p| proj_path = p }
          parser.on("-f", "--force", "Force overwrite of existing files") { force = true }
          parser.on("--dry-run", "Preview upgrade steps without applying them") { dry_run = true }
          parser.on("-v", "--verbose", "Enable verbose logging") { Core::Logger.verbose = true }
          parser.on("-h", "--help", "Show help") { print_help; exit 0 }
          parser.unknown_args do |unparsed|
            if !unparsed.empty? && proj_path.nil? && !unparsed.first.starts_with?("-")
              proj_path = unparsed.first
            end
          end
        end

        target_path_str = (pp = proj_path) ? pp : "."
        target_dir = Path.new(target_path_str).expand
        godot_proj = target_dir.join("project.godot")
        shard_path = target_dir.join("shard.yml")

        unless File.exists?(godot_proj) || File.exists?(shard_path)
          Core::Logger.error("No Godot project found at '#{target_dir}'.")
          Core::Logger.info("Please run 'lapis upgrade' from a project root or pass -p <path>.")
          return 1
        end

        Core::Logger.step("Upgrade", "Upgrading project at #{target_dir.basename} to Lapis v#{Lapis::VERSION}...")

        if dry_run
          Core::Logger.info("[Dry Run] Would upgrade engine bindings in #{target_dir.join("lib/lapis")}")
          Core::Logger.info("[Dry Run] Would update shard.yml dependencies to 'path: lib/lapis'")
          Core::Logger.info("[Dry Run] Would refresh addons/crystal_integration manifests")
          Core::Logger.info("[Dry Run] Would sync runtime binaries to #{target_dir.join("bin")}")
          return 0
        end

        # 1. Update/Extract embedded engine library source into lib/lapis
        if Core::BakedFileSystem.files_with_prefix("src").size > 0
          Core::Logger.step("Upgrade", "Extracting Lapis engine library (v#{Lapis::VERSION}) into lib/lapis...")
          Core::BakedFileSystem.extract_engine_lib(target_dir.join("lib/lapis"))
        end

        # 2. Migrate shard.yml dependencies from remote git to local path
        if File.exists?(shard_path)
          shard_content = File.read(shard_path)
          modified = false

          # Convert github: sol-vin/lapis to path: lib/lapis
          if shard_content.includes?("github: sol-vin/lapis") || shard_content.includes?("sol-vin/lapis")
            shard_content = shard_content.gsub(/github:\s*sol-vin\/lapis[^\r\n]*/, "path: lib/lapis")
            shard_content = shard_content.gsub(/tag:\s*[^\r\n]+(?:\r?\n)?/, "")
            shard_content = shard_content.gsub(/branch:\s*[^\r\n]+(?:\r?\n)?/, "")
            modified = true
          end

          if modified
            File.write(shard_path, shard_content)
            Core::Logger.success("Migrated shard.yml dependency to local embedded 'path: lib/lapis'")
          end

          # Also check shard.release.yml if present
          rel_shard = target_dir.join("shard.release.yml")
          if File.exists?(rel_shard)
            rel_content = File.read(rel_shard)
            if rel_content.includes?("github: sol-vin/lapis") || rel_content.includes?("sol-vin/lapis")
              rel_content = rel_content.gsub(/github:\s*sol-vin\/lapis[^\r\n]*/, "path: lib/lapis")
              rel_content = rel_content.gsub(/tag:\s*[^\r\n]+(?:\r?\n)?/, "")
              rel_content = rel_content.gsub(/branch:\s*[^\r\n]+(?:\r?\n)?/, "")
              File.write(rel_shard, rel_content)
            end
          end
        end

        # 3. Refresh crystal_integration GDExtension addon files
        addon_dir = target_dir.join("addons/crystal_integration")
        FileUtils.mkdir_p(addon_dir) unless Dir.exists?(addon_dir)
        if Core::BakedFileSystem.files_with_prefix("addons/crystal_integration").size > 0
          Core::Logger.step("Upgrade", "Refreshing crystal_integration GDExtension addon files...")
          Core::BakedFileSystem.extract_folder("addons/crystal_integration", addon_dir)
        end

        # 4. Refresh godot-version.yml and ensure extension_list.cfg
        ver_dest = target_dir.join("godot-version.yml")
        if Core::BakedFileSystem.has_file?("godot-version.yml")
          Core::BakedFileSystem.extract_file("godot-version.yml", ver_dest)
        end
        Sync.ensure_extension_list(target_dir)

        # 5. Synchronize runtime binaries (DLLs, bridge)
        bin_dir = target_dir.join("bin")
        FileUtils.mkdir_p(bin_dir) unless Dir.exists?(bin_dir)
        File.write(bin_dir.join(".gdignore"), "") unless File.exists?(bin_dir.join(".gdignore"))

        Deps.run(["-t", bin_dir.to_s])
        Sync.run(["-t", bin_dir.to_s, "--bins-only"])

        # Also sync to addons/crystal_integration/bin if it exists
        addon_bin = addon_dir.join("bin")
        if Dir.exists?(addon_bin)
          Deps.run(["-t", addon_bin.to_s, "--addon"])
        end

        # 6. Verify pre-commit hook if .githooks directory exists
        hooks_dir = target_dir.join(".githooks")
        if Dir.exists?(hooks_dir) && Core::BakedFileSystem.has_file?("template/.githooks/pre-commit")
          Core::BakedFileSystem.extract_file("template/.githooks/pre-commit", hooks_dir.join("pre-commit"))
        end

        puts
        puts "\e[32m========================================================================\e[0m"
        puts "\e[32m  Project '#{target_dir.basename}' successfully upgraded to Lapis v#{Lapis::VERSION}!\e[0m"
        puts "\e[32m========================================================================\e[0m"
        puts <<-NEXT

\e[36mSummary of upgrades:\e[0m
  ✓ Lapis Crystal engine bindings refreshed in \e[1mlib/lapis/\e[0m
  ✓ Shard dependency configured to embedded \e[1mpath: lib/lapis\e[0m
  ✓ GDExtension manifests refreshed in \e[1maddons/crystal_integration/\e[0m
  ✓ Native runtime libraries and bridge synced to \e[1mbin/\e[0m
  ✓ Engine version and extension configurations verified

\e[36mNext steps:\e[0m
  1. Recompile your game library:
     \e[1mlapis build\e[0m
  2. Launch the project in Godot Editor:
     \e[1mlapis editor\e[0m
NEXT
        0
      end
    end
  end
end
