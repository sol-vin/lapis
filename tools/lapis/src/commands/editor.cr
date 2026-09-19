require "../core/env"
require "../core/logger"
require "../core/process_runner"
require "../core/godot_finder"
require "../core/tool_checker"
require "option_parser"
require "file_utils"

module Lapis
  module Commands
    module Editor
      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Godot Editor & Runtime Launcher ===\e[0m

Usage: lapis editor [options]
       lapis run [options]

Options:
  -p, --path=PATH            Godot project path (default: test)
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
  lapis editor -p template
  lapis editor -p test --quit-after 10
  lapis editor -p test --lldb
  lapis run -p test
HELP
      end

      def self.run(args : Array(String)) : Int32
        if args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        proj_path = "test"
        run_standalone = false
        quit_after : Int32? = nil
        log_file : String? = nil
        lldb = false
        batch = false
        godot_path : String? = nil
        skip_version_check = false

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis editor [options]"
          opts.on("-p PATH", "--path=PATH", "Godot project path (default: test)") { |p| proj_path = p }
          opts.on("-r", "--run", "Run standalone project directly") { run_standalone = true }
          opts.on("-q SEC", "--quit-after=SEC", "Auto-quit after N seconds") { |s| quit_after = s.to_i? }
          opts.on("-l FILE", "--log-file=FILE", "Save editor log output to file") { |f| log_file = f }
          opts.on("--lldb", "Launch under LLDB debugger") { lldb = true }
          opts.on("--batch", "Non-interactive batch mode") { batch = true }
          opts.on("-g PATH", "--godot=PATH", "Explicit Godot binary path") { |g| godot_path = g }
          opts.on("--skip-version-check", "Bypass Godot engine version check") { skip_version_check = true }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
        end

        parser.parse(args)

        root = Core::Env::ROOT_DIR
        target_dir = root.join(proj_path)
        unless Dir.exists?(target_dir)
          Core::Logger.error("Target project directory does not exist: #{target_dir}")
          return 1
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

        godot_args = run_standalone ? ["--path", target_dir.to_s] : ["--editor", "--path", target_dir.to_s]
        if qa = quit_after
          godot_args << "--quit-after"
          godot_args << qa.to_s
        end

        action_name = run_standalone ? "Running Godot standalone" : "Launching Godot Editor"
        Core::Logger.step("Editor", "#{action_name} for #{proj_path} (#{File.basename(godot_exe)})...")

        status = if lldb
          lldb_cmd = Core::ProcessRunner.find_executable("lldb") || "lldb"
          lldb_args = ["--", godot_exe] + godot_args
          Core::ProcessRunner.run(lldb_cmd, lldb_args, chdir: target_dir.to_s)
        else
          Core::ProcessRunner.run(godot_exe, godot_args, chdir: target_dir.to_s)
        end

        status.exit_code
      end
    end
  end
end
