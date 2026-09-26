require "../core/env"
require "../core/logger"
require "../core/process_runner"
require "./install_addon"
require "file_utils"
require "option_parser"

module Lapis
  module Commands
    module ShardManager
      # Formats a dependency entry block for shard.yml
      def self.format_dependency_entry(
        name : String,
        spec : InstallAddon::AddonSpec,
        branch : String? = nil,
        tag : String? = nil,
        version : String? = nil,
        path_override : String? = nil,
        project_dir : Path = Path.new(Dir.current),
      ) : String
        if path_val = path_override || (spec.type == :local_dir ? spec.path : nil)
          rel_p = if path_val.starts_with?(".")
                    path_val.gsub('\\', '/')
                  else
                    p = Path.new(path_val).expand
                    if Dir.exists?(project_dir)
                      p.relative_to(project_dir.expand).to_s.gsub('\\', '/')
                    else
                      path_val.gsub('\\', '/')
                    end
                  end
          rel_p = "./#{rel_p}" unless rel_p.starts_with?(".")
          <<-YAML
  #{name}:
    path: #{rel_p}
YAML
        elsif version
          owner = spec.owner || "sol-vin"
          repo = spec.repo || name
          clean_ver = version.starts_with?("~>") || version.starts_with?(">=") || version.starts_with?("=") ? version : "~> #{version.lchop("v")}"
          <<-YAML
  #{name}:
    github: #{owner}/#{repo}
    version: "#{clean_ver}"
YAML
        else
          owner = spec.owner || "sol-vin"
          repo = spec.repo || name
          ref_val = branch || tag || spec.tag || "master"
          <<-YAML
  #{name}:
    github: #{owner}/#{repo}
    branch: #{ref_val}
YAML
        end
      end

      # Adds or updates a dependency in shard.yml
      def self.add_dependency(
        project_dir : Path,
        name : String,
        spec : InstallAddon::AddonSpec,
        branch : String? = nil,
        tag : String? = nil,
        version : String? = nil,
        path_override : String? = nil,
      ) : Bool
        shard_path = project_dir.join("shard.yml")
        unless File.exists?(shard_path)
          FileUtils.mkdir_p(project_dir)
          proj_name = project_dir.basename.underscore
          default_content = <<-YAML
name: #{proj_name}
version: 0.1.0

dependencies:
YAML
          File.write(shard_path, default_content)
          Core::Logger.info("Initialized minimal shard.yml in #{project_dir}")
        end

        content = File.read(shard_path)
        dep_block = format_dependency_entry(name, spec, branch, tag, version, path_override, project_dir)

        # Check if dependencies: section exists
        unless content =~ /^dependencies:\s*$/m
          # Append dependencies section
          content = content.rstrip + "\n\ndependencies:\n"
        end

        # Check if dependency already exists
        regex = /^  #{Regex.escape(name)}:[^\r\n]*(?:\r?\n|\z)(?:[ \t]{3,}[^\r\n]*(?:\r?\n|\z))*/m
        block = dep_block.rstrip + "\n"
        new_content = if content =~ regex
                        content.gsub(regex, block)
                      else
                        content.gsub(/^dependencies:\s*$/m, "dependencies:\n#{block.rstrip}")
                      end

        File.write(shard_path, new_content)
        Core::Logger.success("Added dependency '#{name}' to #{shard_path}")
        true
      rescue ex
        Core::Logger.error("Failed to add dependency to shard.yml: #{ex.message}")
        false
      end

      # Removes a dependency from shard.yml
      def self.remove_dependency(project_dir : Path, name : String) : Bool
        shard_path = project_dir.join("shard.yml")
        return true unless File.exists?(shard_path)

        content = File.read(shard_path)
        regex = /^  #{Regex.escape(name)}:[^\r\n]*(?:\r?\n|\z)(?:[ \t]{3,}[^\r\n]*(?:\r?\n|\z))*/m
        return true unless content =~ regex

        new_content = content.gsub(regex, "")
        File.write(shard_path, new_content)
        Core::Logger.success("Removed dependency '#{name}' from #{shard_path}")
        true
      rescue ex
        Core::Logger.error("Failed to remove dependency from shard.yml: #{ex.message}")
        false
      end

      # Executes shards install in target directory
      def self.run_shards_install(project_dir : Path) : Bool
        if shards_bin = Process.find_executable("shards")
          Core::Logger.step("Shards", "Resolving Crystal dependencies in #{project_dir}...")
          res = Core::ProcessRunner.capture(shards_bin, ["install"], chdir: project_dir.to_s)
          if res[:status].success?
            Core::Logger.success("Dependencies resolved successfully with 'shards install'.")
            return true
          else
            Core::Logger.warn("Notice: 'shards install' exited with #{res[:status].exit_code}: #{res[:error]}")
            return false
          end
        else
          Core::Logger.info("Tip: 'shards' executable not found in PATH. Run 'shards install' manually once installed.")
          true
        end
      rescue ex
        Core::Logger.warn("Failed to run shards install: #{ex.message}")
        false
      end

      # Executes shards prune in target directory
      def self.run_shards_prune(project_dir : Path) : Bool
        if shards_bin = Process.find_executable("shards")
          Core::Logger.step("Shards", "Pruning unused dependencies in #{project_dir}...")
          res = Core::ProcessRunner.capture(shards_bin, ["prune"], chdir: project_dir.to_s)
          return res[:status].success?
        else
          # Fallback: remove lib/<name> directly
          lib_dir = project_dir.join("lib")
          return true unless Dir.exists?(lib_dir)
          true
        end
      rescue
        false
      end

      # CLI entry point for `lapis install shard`
      def self.install(args : Array(String)) : Int32
        if args.empty? || args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        project_dir_arg : String? = nil
        branch_arg : String? = nil
        tag_arg : String? = nil
        version_arg : String? = nil
        path_arg : String? = nil
        skip_shards = false

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis install shard <specifier> [options]"
          opts.on("-p DIR", "--project=DIR", "Target project directory (default: .)") { |d| project_dir_arg = d }
          opts.on("-b BRANCH", "--branch=BRANCH", "Git branch to track") { |b| branch_arg = b }
          opts.on("-t TAG", "--tag=TAG", "Git tag to track") { |t| tag_arg = t }
          opts.on("-v VER", "--version=VER", "Shard version requirement (e.g. ~> 0.1.0)") { |v| version_arg = v }
          opts.on("--path=DIR", "Local relative path for dependency") { |d| path_arg = d }
          opts.on("--skip-shards", "Skip running 'shards install'") { skip_shards = true }
          opts.on("-h", "--help", "Show help screen") { print_help; exit 0 }
        end

        remaining = [] of String
        parser.unknown_args { |r| remaining = r }
        parser.parse(args)

        if remaining.empty?
          Core::Logger.error("Missing shard specifier (e.g. 'github:sol-vin/crshader' or 'sol-vin/crshader').")
          return 1
        end

        spec_raw = remaining[0]
        spec = InstallAddon.parse_spec(spec_raw)
        name = spec.name

        target_project = if (p = project_dir_arg) && !p.empty?
                           Path.new(p).expand
                         else
                           Path.new(Dir.current).expand
                         end

        Core::Logger.step("Install:Shard", "Adding shard '#{name}' to #{target_project}...")

        ok = add_dependency(
          target_project,
          name,
          spec,
          branch: branch_arg,
          tag: tag_arg,
          version: version_arg,
          path_override: path_arg,
        )

        unless ok
          return 1
        end

        unless skip_shards
          run_shards_install(target_project)
        end

        puts "\n\e[32m✓ Shard '#{name}' installed into shard.yml!\e[0m"
        puts "  In your Crystal code, use: \e[1;36mrequire \"#{name}\"\e[0m"
        0
      end

      # CLI entry point for `lapis uninstall shard`
      def self.uninstall(args : Array(String)) : Int32
        if args.empty? || args.includes?("-h") || args.includes?("--help")
          puts "Usage: lapis uninstall shard <name> [options]"
          return 0
        end

        project_dir_arg : String? = nil
        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis uninstall shard <name> [options]"
          opts.on("-p DIR", "--project=DIR", "Target project directory (default: .)") { |d| project_dir_arg = d }
          opts.on("-h", "--help", "Show help screen") { puts opts; exit 0 }
        end

        remaining = [] of String
        parser.unknown_args { |r| remaining = r }
        parser.parse(args)

        if remaining.empty?
          Core::Logger.error("Missing shard name to uninstall.")
          return 1
        end

        name = remaining[0]
        # Clean name if given as github:owner/name or owner/name
        if name.includes?('/')
          name = name.split('/').last
        end

        target_project = if (p = project_dir_arg) && !p.empty?
                           Path.new(p).expand
                         else
                           Path.new(Dir.current).expand
                         end

        Core::Logger.step("Uninstall:Shard", "Removing shard '#{name}' from #{target_project}...")
        remove_dependency(target_project, name)
        run_shards_prune(target_project)

        # Also remove lib/<name> directly if still exists
        lib_addon = target_project.join("lib", name)
        if Dir.exists?(lib_addon)
          FileUtils.rm_rf(lib_addon)
        end

        puts "\n\e[32m✓ Shard '#{name}' uninstalled from shard.yml!\e[0m"
        0
      end

      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Shard Dependency Manager ===\e[0m

Usage:
  lapis install shard <specifier> [options]
  lapis uninstall shard <name> [options]

Specifiers:
  github:owner/repo[@branch|tag]  Install from GitHub repository
  owner/repo[@branch|tag]         Shorthand GitHub repository
  path/to/local/shard             Install local shard path dependency

Options:
  -p, --project=DIR               Target project directory (default: .)
  -b, --branch=BRANCH             Git branch to track (default: master)
  -t, --tag=TAG                   Git tag to track
  -v, --version=VER               Version constraint (e.g. ~> 0.1.0)
  --path=DIR                      Local path override for dependency
  --skip-shards                   Do not execute 'shards install'
  -h, --help                      Show this help screen

Examples:
  lapis install shard github:sol-vin/crshader
  lapis install shard sol-vin/crshader@v0.1.0
  lapis install shard ../../bin/crshader
  lapis uninstall shard crshader
HELP
      end
    end
  end
end
