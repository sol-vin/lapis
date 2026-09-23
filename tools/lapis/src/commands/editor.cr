require "../core/env"
require "../core/logger"
require "../core/process_runner"
require "../core/godot_finder"
require "../core/tool_checker"
require "../core/baked_file_system"
require "./build"
require "option_parser"
require "file_utils"

module Lapis
  module Commands
    module Editor
      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Godot Editor & Runtime Launcher ===\e[0m

Usage: lapis editor [options] [path]
       lapis run [options] [path]

Options:
  -p, --path=PATH            Godot project path (default: current project or test)
  -r, --run                  Run standalone project directly instead of opening editor
  -q, --quit-after=SEC       Auto-quit after N seconds
  -l, --log-file=FILE        Save editor log output to file
  --lldb                     Launch under LLDB debugger
  --batch                    Non-interactive batch mode
  -g, --godot=PATH           Explicit Godot binary path
  --skip-version-check       Bypass Godot engine version verification
  -h, --help                 Show this help screen

Examples:
  lapis editor
  lapis editor my_game
  lapis editor -p template
  lapis editor -p test --quit-after 10
  lapis editor -p test --lldb
  lapis run
  lapis run -p test
HELP
      end

      # Resolves the target Godot project directory:
      # 1. Explicit path if provided (absolute, relative to CWD, or relative to root).
      # 2. Current working directory if it contains project.godot.
      # 3. Workspace root if it contains project.godot (standalone project).
      # 4. Standard monorepo test project (test/) or template (template/).
      # 5. Fallback to current working directory.
      def self.resolve_target_dir(proj_path : String?, root : Path) : Path
        curr = Path.new(Dir.current).expand

        if proj_path && !proj_path.empty?
          p = Path.new(proj_path)
          if p.absolute? && Dir.exists?(p)
            return p
          end
          if Dir.exists?(curr.join(p))
            return curr.join(p).expand
          end
          if Dir.exists?(root.join(p))
            return root.join(p).expand
          end
          return p.expand
        end

        # Auto-detect target project when no path is explicitly provided:
        # 1. Current working directory if it contains project.godot
        if File.exists?(curr.join("project.godot"))
          return curr
        end

        # 2. Workspace root if it contains project.godot (standalone project)
        if File.exists?(root.join("project.godot"))
          return root
        end

        # 3. LibGodot monorepo: default to test project suite
        if File.exists?(root.join("test/project.godot"))
          return root.join("test")
        end

        # 4. LibGodot monorepo: fallback to template project
        if File.exists?(root.join("template/project.godot"))
          return root.join("template")
        end

        curr
      end

      def self.run(args : Array(String)) : Int32
        if args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        proj_path : String? = nil
        run_standalone = false
        quit_after : Int32? = nil
        log_file : String? = nil
        lldb = false
        batch = false
        godot_path : String? = nil
        skip_version_check = false

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis editor [options] [path]"
          opts.on("-p PATH", "--path=PATH", "Godot project path (default: current project or test)") { |p| proj_path = p }
          opts.on("-r", "--run", "Run standalone project directly") { run_standalone = true }
          opts.on("-q SEC", "--quit-after=SEC", "Auto-quit after N seconds") { |s| quit_after = s.to_i? }
          opts.on("-l FILE", "--log-file=FILE", "Save editor log output to file") { |f| log_file = f }
          opts.on("--lldb", "Launch under LLDB debugger") { lldb = true }
          opts.on("--batch", "Non-interactive batch mode") { batch = true }
          opts.on("-g PATH", "--godot=PATH", "Explicit Godot binary path") { |g| godot_path = g }
          opts.on("--skip-version-check", "Bypass Godot engine version check") { skip_version_check = true }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
          opts.unknown_args do |before, after|
            remaining = before + after
            proj_path ||= remaining.first if !remaining.empty?
          end
        end

        parser.parse(args)

        root = Core::Env::ROOT_DIR
        target_dir = resolve_target_dir(proj_path, root)
        unless Dir.exists?(target_dir)
          Core::Logger.error("Target project directory does not exist: #{target_dir}")
          return 1
        end

        unless File.exists?(target_dir.join("project.godot"))
          Core::Logger.warn("Notice: No project.godot found in #{target_dir}. Godot may open the Project Manager.")
        end

        expected_ver = Core::GodotFinder.expected_version(target_dir.to_s)
        godot_exe = Core::GodotFinder.resolve(godot_path, target_dir.to_s, filter_version: !skip_version_check)

        unless godot_exe
          Core::Logger.error("Godot executable not found.")
          return 1
        end

        unless skip_version_check
          Core::ToolChecker.verify_all(strict: false)
          unless Core::GodotFinder.verify_version(godot_exe, expected_ver, strict: true)
            Core::Logger.error("To bypass this verification check, pass --skip-version-check.")
            return 1
          end
        end

        # Pre-flight check: ensure GDExtension bridge & runtime binaries are present in target project
        addon_bin = target_dir.join("addons/crystal_integration/bin")
        bridge_file = Core::Env.bridge_file
        if !File.exists?(addon_bin.join(bridge_file))
          FileUtils.mkdir_p(addon_bin)
          if Core::BakedFileSystem.has_file?("addons/crystal_integration/bin/#{bridge_file}")
            Core::Logger.step("Sync", "Restoring missing GDExtension bridge from BakedFileSystem...")
            Core::BakedFileSystem.extract_folder("addons/crystal_integration/bin", addon_bin)
          end
        end

        # Ensure dependencies are copied to target_dir/bin
        proj_bin = target_dir.join("bin")
        FileUtils.mkdir_p(proj_bin)
        ["crystal_bridge.dll", "crystal_bridge.so", "crystal_bridge.dylib", "gc.dll", "iconv-2.dll", "pcre2-8.dll"].each do |lib_name|
          src_in_addon = addon_bin.join(lib_name)
          if File.exists?(src_in_addon) && !File.exists?(proj_bin.join(lib_name))
            Commands::Deps.safe_copy(src_in_addon, proj_bin.join(lib_name))
          end
        end

        # Ensure game.dll/so exists if project has src/main.cr
        game_file = Core::Env.game_file
        if File.exists?(target_dir.join("src/main.cr")) && !File.exists?(proj_bin.join(game_file))
          if Core::BakedFileSystem.has_file?("template/bin/#{game_file}")
            Core::Logger.step("Sync", "Restoring starter game library from BakedFileSystem...")
            Core::BakedFileSystem.extract_file("template/bin/#{game_file}", proj_bin.join(game_file))
            Commands::Deps.safe_copy(proj_bin.join(game_file), addon_bin.join(game_file))
          else
            Core::Logger.step("Build", "Building game library prior to launching editor...")
            Commands::Build.run(["game", "-p", target_dir.to_s])
          end
        end

        godot_args = run_standalone ? ["--path", target_dir.to_s] : ["--editor", "--path", target_dir.to_s]
        if qa = quit_after
          godot_args << "--quit-after"
          godot_args << qa.to_s
        end

        proj_display_name = if (pp = proj_path) && !pp.empty? && pp != "."
                              pp
                            else
                              target_dir.basename
                            end

        action_name = run_standalone ? "Running Godot standalone" : "Launching Godot Editor"
        Core::Logger.step("Editor", "#{action_name} for #{proj_display_name} (#{File.basename(godot_exe)})...")

        status = if lldb
                   lldb_cmd = Core::ProcessRunner.find_executable("lldb") || "lldb"
                   lldb_args = ["--", godot_exe] + godot_args
                   Core::ProcessRunner.run(lldb_cmd, lldb_args, chdir: target_dir.to_s)
                 else
                   Core::ProcessRunner.run(godot_exe, godot_args, chdir: target_dir.to_s)
                 end

        status.normal_exit? ? status.exit_code : 0
      end
    end
  end
end
