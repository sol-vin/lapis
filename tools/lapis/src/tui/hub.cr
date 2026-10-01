# =============================================================================
# Lapis - Central Interactive TUI Hub & Command Launcher
# =============================================================================
# Full-screen terminal dashboard providing an all-in-one command center,
# telemetry metrics, quick tool dispatch, and global floating command palette.
# =============================================================================

require "opal"
require "../core/env"
require "../core/logger"
require "../core/godot_finder"
require "../core/process_runner"
require "./new_wizard"
require "./editor_launcher"
require "./package_form"
require "./debugger_view"
require "./log_viewer"
require "./bench_viewer"
require "./run_monitor"
require "../commands/test"
require "../commands/doctor"
require "../commands/sync"
require "../commands/clean"
require "../commands/docs"

module Lapis
  module TUI
    class Hub
      getter? running : Bool = true
      property selected_index : Int32 = 0
      property? palette_open : Bool = false
      getter palette : Opal::UI::CommandPalette
      getter status_message : String? = nil
      getter status_time : Time? = nil

      MENU_ITEMS = [
        {"[+]", "New Project / Addon Wizard", "Scaffold games, addons, and examples with folder picker", "N"},
        {"[#]", "Launch Godot Editor", "Persistent launcher with process monitoring & log watching", "E"},
        {"[B]", "Packaging & Export Center", "Configure multi-target builds with live build logs", "P"},
        {"[D]", "Radare2 Native Debugger", "Registers, disassembly, source mapping & hex memory inspection", "D"},
        {"[L]", "Diagnostic Log Viewer", "Real-time log tailing, channel filters & regex search", "L"},
        {"[#]", "Benchmark Visualizer", "Opal Cartesian charts, latency percentiles & memory deltas", "B"},
        {"[~]", "Run Game (Performance Monitor)", "Live FPS/memory charts with graceful Ctrl+K termination", "R"},
        {"[?]", "Test Suites Dashboard", "Multi-phase test runner with split-screen logs", "T"},
        {"[+]", "Toolchain Doctor", "Comprehensive environment & dependency health diagnostics", "O"},
        {"[~]", "Synchronize Multi-Targets", "Sync bridge DLLs and manifests across all targets", "S"},
        {"[x]", "Clean Build Artifacts", "Clean build artifacts and release locked shadow DLLs", "C"},
        {"[=]", "Generate Documentation", "Build static offline HTML documentation site", "M"},
        {"[X]", "Exit", "Exit Lapis CLI Hub", "Q"},
      ]

      def initialize
        @palette = Opal::UI::CommandPalette.new
        setup_palette_commands
      end

      def self.run : Int32
        new.run
      end

      def run : Int32
        return 0 unless STDOUT.tty?

        driver = Opal::Terminal.default_driver
        driver.raw_mode do
          driver.enter_alternate_screen
          driver.hide_cursor
          begin
            while @running
              render(driver)
              handle_input(driver)
            end
          ensure
            driver.show_cursor
            driver.exit_alternate_screen
          end
        end

        0
      end

      private def setup_palette_commands
        @palette.add("hub:new", "New Project / Addon", "Scaffold", "N") { launch_new_wizard }
        @palette.add("hub:editor", "Launch Godot Editor", "Engine", "E") { launch_editor }
        @palette.add("hub:package", "Package & Export", "Build", "P") { launch_package_form }
        @palette.add("hub:debug", "Radare2 Native Debugger", "Debug", "D") { launch_debugger }
        @palette.add("hub:log", "Diagnostic Log Viewer", "Logs", "L") { launch_log_viewer }
        @palette.add("hub:bench", "Benchmark Visualizer", "Bench", "B") { launch_bench_viewer }
        @palette.add("hub:run", "Run Game (Performance Monitor)", "Engine", "R") { launch_run_monitor }
        @palette.add("hub:test", "Run Test Suites", "Test", "T") { launch_test_runner }
        @palette.add("hub:doctor", "Toolchain Doctor", "System", "O") { run_command("doctor") }
        @palette.add("hub:sync", "Synchronize Targets", "Build", "S") { run_command("sync") }
        @palette.add("hub:clean", "Clean Build Artifacts", "Build", "C") { run_command("clean") }
        @palette.add("hub:docs", "Generate API Documentation", "Docs", "M") { run_command("docs") }
        @palette.add("hub:exit", "Quit Lapis Hub", "General", "Q") { @running = false }
      end

      def render_to_buffer(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        # 1. Header Banner & Telemetry
        render_header(buffer, width)

        # 2. Main Menu
        render_menu(buffer, width, height)

        # 3. Status Bar & Keybinding Hints
        render_footer(buffer, width, height)

        # 4. Floating Command Palette (if open)
        if @palette_open
          @palette.render(buffer, (width - 70) // 2, 4, 70, Math.min(16, height - 6))
        end
      end

      private def render(driver : Opal::Terminal::Driver)
        w, h = driver.size
        width = Math.max(80, w)
        height = Math.max(24, h)
        buffer = Opal::UI::Buffer.new(width, height)
        render_to_buffer(buffer, width, height)

        driver.write(Opal::Terminal::Screen.move_to(1, 1))
        driver.write(buffer.render_to_string(with_ansi: true))
        driver.flush
      end

      private def render_header(buffer : Opal::UI::Buffer, width : Int32)
        root = Core::Env::ROOT_DIR
        curr = Path.new(Dir.current).expand
        in_project = File.exists?(curr.join("project.godot"))
        proj_name = in_project ? curr.basename : "Workspace Root (#{root.basename})"
        godot_exe = Core::GodotFinder.resolve(nil)
        godot_ver = godot_exe ? (Core::GodotFinder.get_version(godot_exe) || "4.8-dev") : "Not Found"
        platform_name = Core::Env.current_platform
        git_branch = Core::ProcessRunner.capture("git", ["branch", "--show-current"])[:output].strip rescue "main"
        git_branch = "main" if git_branch.empty?

        bridge_compiled = File.exists?(root.join("bin/crystal_bridge.dll"))

        buffer.put_string(2, 1, ":: LAPIS CLI TERMINAL HUB ::", fg: Opal::Color.bright_magenta, bold: true)
        buffer.put_string(32, 1, "v#{VERSION} │ Pure Crystal Engine Toolchain", fg: Opal::Color.bright_black)

        info_line = "Project: #{proj_name} (#{git_branch}) │ Platform: #{platform_name} │ Godot: #{godot_ver} │ Crystal: v#{Crystal::VERSION}"
        buffer.put_string(2, 2, info_line, fg: Opal::Color.cyan)

        bridge_str = bridge_compiled ? "[OK] Bridge Ready" : "[!] Bridge Missing"
        bridge_fg = bridge_compiled ? Opal::Color.green : Opal::Color.yellow
        buffer.put_string(2, 3, bridge_str, fg: bridge_fg, bold: true)

        buffer.put_string(2, 4, "─" * (width - 4), fg: Opal::Color.bright_black)
      end

      private def render_menu(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        start_y = 6
        max_items = height - 10

        MENU_ITEMS.each_with_index do |item, idx|
          break if idx >= max_items
          y = start_y + idx
          selected = (idx == @selected_index)

          icon, title, desc, key = item
          prefix = selected ? " ► " : "   "
          fg = selected ? Opal::Color.bright_white : Opal::Color.white
          bg = selected ? Opal::Color.hex("#2A2B3D") : Opal::Color.none

          # Highlight shortcut key in brackets
          key_badge = "[ #{key} ]"

          buffer.put_string(2, y, "#{prefix}#{icon} #{key_badge} #{title}", fg: fg, bg: bg, bold: selected)

          desc_x = 48
          if width > 90
            buffer.put_string(desc_x, y, desc, fg: Opal::Color.bright_black, bg: bg)
          end
        end
      end

      private def render_footer(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        y = height - 3
        buffer.put_string(2, y, "─" * (width - 4), fg: Opal::Color.bright_black)

        if msg = @status_message
          buffer.put_string(2, y + 1, "ℹ #{msg}", fg: Opal::Color.yellow, bold: true)
        else
          hints = "↑/↓: Navigate │ Enter: Select │ Shift+~ / ~: Command Palette │ Q: Quit"
          buffer.put_string(2, y + 1, hints, fg: Opal::Color.cyan)
        end
      end

      private def handle_input(driver : Opal::Terminal::Driver)
        ev = driver.read_event
        return unless ev.is_a?(Opal::Terminal::KeyEvent)

        # Global command palette toggle: Shift+~ or ~ or ` or Ctrl+P
        if ev.char == '~' || ev.char == '`' || ev.matches?("ctrl+p")
          @palette_open = !@palette_open
          return
        end

        if @palette_open
          handle_palette_input(ev)
          return
        end

        case ev.name
        when "up"
          @selected_index = Math.max(0, @selected_index - 1)
        when "down"
          @selected_index = Math.min(MENU_ITEMS.size - 1, @selected_index + 1)
        when "enter"
          execute_selected_item
        else
          if ch = ev.char
            case ch
            when 'q', 'Q'
              @running = false
            when 'n', 'N'
              launch_new_wizard
            when 'e', 'E'
              launch_editor
            when 'p', 'P'
              launch_package_form
            when 'd', 'D'
              launch_debugger
            when 'l', 'L'
              launch_log_viewer
            when 'b', 'B'
              launch_bench_viewer
            when 'r', 'R'
              launch_run_monitor
            when 't', 'T'
              launch_test_runner
            when 'o', 'O'
              run_command("doctor")
            when 's', 'S'
              run_command("sync")
            when 'c', 'C'
              run_command("clean")
            when 'm', 'M'
              run_command("docs")
            when '?'
              @palette_open = true
            end
          end
        end
      end

      private def handle_palette_input(ev : Opal::Terminal::KeyEvent)
        case ev.name
        when "escape", "esc"
          @palette_open = false
        when "up"
          @palette.cursor_up
        when "down"
          @palette.cursor_down
        when "enter"
          if action = @palette.selected_action
            @palette_open = false
            action.callback.try &.call
          end
        when "backspace"
          @palette.query = @palette.query[0...-1] if @palette.query.size > 0
          @palette.cursor = 0
        else
          if ch = ev.char
            @palette.query += ch
            @palette.cursor = 0
          end
        end
      end

      private def execute_selected_item
        case @selected_index
        when 0  then launch_new_wizard
        when 1  then launch_editor
        when 2  then launch_package_form
        when 3  then launch_debugger
        when 4  then launch_log_viewer
        when 5  then launch_bench_viewer
        when 6  then launch_run_monitor
        when 7  then launch_test_runner
        when 8  then run_command("doctor")
        when 9  then run_command("sync")
        when 10 then run_command("clean")
        when 11 then run_command("docs")
        when 12 then @running = false
        end
      end

      def launch_new_wizard : Nil
        NewWizard.run
      end

      def launch_editor : Nil
        EditorLauncher.run
      end

      def launch_package_form : Nil
        PackageForm.run
      end

      def launch_debugger : Nil
        DebuggerView.run
      end

      def launch_log_viewer : Nil
        LogViewer.run
      end

      def launch_bench_viewer : Nil
        BenchViewer.run
      end

      def launch_run_monitor : Nil
        RunMonitor.run
      end

      def launch_test_runner : Nil
        driver = Opal::Terminal.default_driver
        driver.exit_alternate_screen
        driver.show_cursor
        Commands::Test.run(["--tui"])
        driver.enter_alternate_screen
        driver.hide_cursor
      end

      private def run_command(subcmd : String) : Nil
        driver = Opal::Terminal.default_driver
        driver.exit_alternate_screen
        driver.show_cursor
        puts Opal.style.bold.fg(:cyan).render("\n=== Running lapis #{subcmd} ===\n")
        case subcmd
        when "doctor" then Commands::Doctor.run([] of String)
        when "sync"   then Commands::Sync.run([] of String)
        when "clean"  then Commands::Clean.run([] of String)
        when "docs"   then Commands::Docs.run([] of String)
        end
        puts "\n\e[33mPress Enter to return to Lapis CLI Hub...\e[0m"
        STDIN.gets
        driver.enter_alternate_screen
        driver.hide_cursor
      end
    end
  end
end
