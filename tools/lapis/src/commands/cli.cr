# =============================================================================
# Lapis - Interactive TUI Command Hub CLI Command
# =============================================================================

require "../core/env"
require "../core/logger"
require "../tui/hub"
require "../tui/new_wizard"
require "../tui/editor_launcher"
require "../tui/package_form"
require "../tui/debugger_view"
require "../tui/log_viewer"
require "../tui/bench_viewer"
require "../tui/run_monitor"
require "../tui/driver_view"
require "option_parser"

module Lapis
  module Commands
    module Cli
      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Interactive TUI Terminal Command Center ===\e[0m

Usage: lapis cli [options]

Options:
  --new, -n             Launch interactive New Project / Addon Scaffolding Wizard
  --editor, -e          Launch persistent Godot Editor Launcher & Log Watcher
  --driver, -a          Launch Action Driver Controller & DOM Inspector
  --package, -p         Launch multi-target Packaging & Export Form
  --debug, -d           Launch Radare2 Native Debugger & Crash Forensics View
  --log, -l             Launch Diagnostic Log Viewer with real-time tailing
  --bench, -b           Launch Benchmark Suite Visualizer with Opal Cartesian Charts
  --run, -r, --monitor  Launch Game Runtime Performance Monitor with live FPS/RAM graphs
  -h, --help            Show this help screen

Examples:
  lapis cli             Launch central TUI Hub with global command palette
  lapis cli --new       Launch project creation wizard with folder picker
  lapis cli --editor    Launch persistent editor launcher with log tailing
HELP
      end

      def self.run(args : Array(String)) : Int32
        if args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        launch_mode = :hub

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis cli [options]"
          opts.on("-n", "--new", "Launch New Project / Addon Wizard") { launch_mode = :new }
          opts.on("-e", "--editor", "Launch Persistent Editor Launcher") { launch_mode = :editor }
          opts.on("-a", "--driver", "Launch Action Driver Controller") { launch_mode = :driver }
          opts.on("-p", "--package", "Launch Packaging Form") { launch_mode = :package }
          opts.on("-d", "--debug", "Launch Radare2 Debugger View") { launch_mode = :debug }
          opts.on("-l", "--log", "Launch Diagnostic Log Viewer") { launch_mode = :log }
          opts.on("-b", "--bench", "Launch Benchmark Visualizer") { launch_mode = :bench }
          opts.on("-r", "--run", "Launch Runtime Performance Monitor") { launch_mode = :run }
          opts.on("--monitor", "Launch Runtime Performance Monitor") { launch_mode = :run }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
        end

        parser.parse(args)

        case launch_mode
        when :new
          TUI::NewWizard.run
          0
        when :editor
          TUI::EditorLauncher.run
          0
        when :driver
          TUI::DriverView.run
          0
        when :package
          TUI::PackageForm.run
          0
        when :debug
          TUI::DebuggerView.run
          0
        when :log
          TUI::LogViewer.run
          0
        when :bench
          TUI::BenchViewer.run
          0
        when :run
          TUI::RunMonitor.run
          0
        else
          TUI::Hub.run
        end
      end
    end
  end
end
