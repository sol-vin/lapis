require "./version"
require "./core/env"
require "./core/logger"
require "./core/text"
require "opal"

require "./commands/dirs"
require "./commands/deps"
require "./commands/sync"
require "./commands/build"
require "./commands/test"
require "./commands/spec"
require "./commands/editor"
require "./commands/scaffold"
require "./commands/package"
require "./commands/bind"
require "./commands/clean"
require "./commands/docs"
require "./commands/setup"
require "./commands/install"
require "./commands/install_addon"
require "./commands/shard_manager"
require "./commands/doctor"
require "./commands/init"
require "./commands/ide"
require "./commands/get"
require "./commands/update"
require "./commands/upgrade"
require "./commands/benchmarks"
require "./commands/log"
require "./commands/decompile"
require "./commands/analyze"
require "./commands/template"
require "./commands/export_templates"
require "./commands/cli"
require "./tui/hub"

module Lapis
  # Canonical registry of all subcommands with concise descriptions.
  COMMAND_DESCRIPTIONS = {
    "cli"         => "Launch interactive TUI terminal command hub and dashboard",
    "dirs"        => "Ensure project and binary output directories exist",
    "deps"        => "Verify and copy Crystal runtime dependencies & libgodot DLLs",
    "sync"        => "Synchronize binaries, addons, and manifests across all targets",
    "build"       => "Compile Crystal game libraries, plugins, or standalone executables",
    "log"         => "Manage, view, tail, search, export, and inspect diagnostic logs",
    "bind"        => "Generate typed bindings for Godot engine or custom nodes",
    "generate"    => "Alias for bind",
    "clean"       => "Remove compiled game/bridge binaries or shadow DLLs",
    "test"        => "Run test suites and headless verification",
    "spec"        => "Run Crystal unit specs",
    "editor"      => "Launch Godot Editor with log monitoring and debugger",
    "run"         => "Run Godot project standalone",
    "decompile"   => "Decompile functions or disassemble binaries using native radare2",
    "analyze"     => "Perform deep static and dynamic radare2 binary and security analysis",
    "setup"       => "Download and configure targeted Godot engine binary",
    "doctor"      => "Diagnose toolchain environment and project health",
    "init"        => "Initialize Crystal integration in an existing Godot project",
    "upgrade"     => "Upgrade an existing Godot project to latest Lapis engine",
    "addon"       => "Install, uninstall, or manage Godot GDExtension addons",
    "shard"       => "Manage Crystal shard dependencies in Godot project",
    "ide"         => "Configure VS Code, Cursor, Zed, or Neovim with Crystalline LSP",
    "scaffold"    => "Scaffold a new game, addon, or example",
    "new"         => "Alias for scaffold",
    "package"     => "Create distribution archives or playable standalone game",
    "docs"        => "Generate HTML API documentation",
    "install"     => "Install Lapis CLI globally into system/user PATH",
    "uninstall"   => "Uninstall Lapis CLI globally from computer",
    "get"         => "Download Lapis source code or compiled release packages",
    "update"      => "Update Lapis executable, Crystalline LSP, and Crystal compiler",
    "benchmarks"  => "Run benchmarks, export HTML reports, and track progression",
    "bench"       => "Alias for benchmarks",
    "color"       => "Launch interactive 2D/3D TrueColor palette studio (Opal)",
    "explore"     => "Launch interactive terminal file dialog & project explorer (Opal)",
    "template"         => "Manage global project templates (save, list, remove, clean, export, import)",
    "templates"        => "Alias for template",
    "export-templates" => "Inspect, explain, install, and verify Godot & Crystal export templates",
    "shaders"          => "Launch real-time terminal text shader FX playground (Opal)",
    "completion"       => "Generate shell autocompletion script",
    "version"          => "Display Lapis toolchain version",
  }

  ALL_COMMANDS = COMMAND_DESCRIPTIONS.keys

  def self.levenshtein_distance(str1 : String, str2 : String) : Int32
    Opal::Input::Fuzzy.levenshtein(str1, str2)
  end

  def self.suggest_command(typo : String) : String?
    Opal::Input::Fuzzy.suggest(typo, ALL_COMMANDS)
  end

  # Dynamically generates shell autocompletion scripts using Opal's Completion engine
  def self.generate_completion(shell : String) : Int32
    app = build_cli_app
    case shell.downcase
    when "powershell", "pwsh"
      puts Opal::CLI::Completion.powershell("lapis", app)
    when "bash"
      puts Opal::CLI::Completion.bash("lapis", app)
    when "zsh"
      puts Opal::CLI::Completion.zsh("lapis", app)
    when "fish"
      puts Opal::CLI::Completion.fish("lapis", app)
    else
      Core::Logger.error("Unsupported shell for completion: '#{shell}'. Supported: powershell, bash, zsh, fish.")
      return 1
    end
    0
  end

  # Builds the complete declarative CLI application via Opal.cli
  def self.build_cli_app : Opal::CLI::App
    app = Opal.cli("lapis", VERSION) do |cli|
      cli.description "Lapis: Unified Crystal Engine Toolchain for Godot (v#{VERSION})"

      # Global options
      cli.flag :quiet, "--quiet", "-q", description: "Suppress non-essential log output", global: true
      cli.flag :verbose, "--verbose", description: "Enable verbose debug logging", global: true
      cli.flag :interactive, "--interactive", "-i", description: "Launch interactive terminal dashboard", global: true

      # === Build & Synchronization Commands ===
      cli.command :dirs do |cmd|
        cmd.category "Build & Synchronization Commands"
        cmd.description COMMAND_DESCRIPTIONS["dirs"]
        cmd.run { |ctx| Commands::Dirs.run(ctx.raw_args) }
      end

      cli.command :deps do |cmd|
        cmd.category "Build & Synchronization Commands"
        cmd.description COMMAND_DESCRIPTIONS["deps"]
        cmd.option :target, "--target-bin=DIR", "-t", description: "Target directory to synchronize"
        cmd.run { |ctx| Commands::Deps.run(ctx.raw_args) }
      end

      cli.command :sync do |cmd|
        cmd.category "Build & Synchronization Commands"
        cmd.description COMMAND_DESCRIPTIONS["sync"]
        cmd.run { |ctx| Commands::Sync.run(ctx.raw_args) }
      end

      cli.command :build do |cmd|
        cmd.category "Build & Synchronization Commands"
        cmd.description COMMAND_DESCRIPTIONS["build"]
        cmd.option :entry, "--entry=PATH", "-e", description: "Entry source file (.cr)"
        cmd.option :output, "--output=PATH", "-o", description: "Output binary path"
        cmd.flag :release, "--release", "-r", description: "Compile in release mode (-O3)"
        cmd.example "lapis build game -r"
        cmd.example "lapis build -e src/editor/plugin.cr -o bin/plugin.dll"
        cmd.run { |ctx| Commands::Build.run(ctx.raw_args) }
      end

      cli.command :bind do |cmd|
        cmd.category "Build & Synchronization Commands"
        cmd.description COMMAND_DESCRIPTIONS["bind"]
        cmd.alias_name "generate", "bindings"
        cmd.run { |ctx| Commands::Bind.run(ctx.raw_args) }
      end

      cli.command :clean do |cmd|
        cmd.category "Build & Synchronization Commands"
        cmd.description COMMAND_DESCRIPTIONS["clean"]
        cmd.flag :shadows, "--shadows", "-s", description: "Only purge stale Windows shadow DLLs"
        cmd.flag :dry_run, "--dry-run", "-d", description: "Preview files to be reclaimed without deleting"
        cmd.flag :all, "--all", description: "Purge all build artifacts and caches"
        cmd.run { |ctx| Commands::Clean.run(ctx.raw_args) }
      end

      # === Testing & Development Commands ===
      cli.command :cli do |cmd|
        cmd.category "Testing & Development Commands"
        cmd.description COMMAND_DESCRIPTIONS["cli"]
        cmd.alias_name "hub", "ui"
        cmd.run { |ctx| Commands::Cli.run(ctx.raw_args) }
      end

      cli.command :doctor do |cmd|
        cmd.category "Testing & Development Commands"
        cmd.description COMMAND_DESCRIPTIONS["doctor"]
        cmd.alias_name "check"
        cmd.run { |ctx| Commands::Doctor.run(ctx.raw_args) }
      end

      cli.command :editor do |cmd|
        cmd.category "Testing & Development Commands"
        cmd.description COMMAND_DESCRIPTIONS["editor"]
        cmd.run { |ctx| Commands::Editor.run(ctx.raw_args) }
      end

      cli.command :run do |cmd|
        cmd.category "Testing & Development Commands"
        cmd.description COMMAND_DESCRIPTIONS["run"]
        cmd.run { |ctx| Commands::Editor.run(["--run"] + ctx.raw_args) }
      end

      cli.command :test do |cmd|
        cmd.category "Testing & Development Commands"
        cmd.description COMMAND_DESCRIPTIONS["test"]
        cmd.flag :tui, "--tui", description: "Force launch interactive Terminal User Interface (TUI) dashboard"
        cmd.flag :no_tui, "--no-tui", description: "Disable TUI and use standard streaming logs"
        cmd.run { |ctx| Commands::Test.run(ctx.raw_args) }
      end

      cli.command :spec do |cmd|
        cmd.category "Testing & Development Commands"
        cmd.description COMMAND_DESCRIPTIONS["spec"]
        cmd.run { |ctx| Commands::Spec.run(ctx.raw_args) }
      end

      cli.command :benchmarks do |cmd|
        cmd.category "Testing & Development Commands"
        cmd.description COMMAND_DESCRIPTIONS["benchmarks"]
        cmd.alias_name "benchmark", "bench"
        cmd.run { |ctx| Commands::Benchmarks.run(ctx.raw_args) }
      end

      cli.command :setup do |cmd|
        cmd.category "Testing & Development Commands"
        cmd.description COMMAND_DESCRIPTIONS["setup"]
        cmd.run { |ctx| Commands::Setup.run(ctx.raw_args) }
      end

      cli.command :color do |cmd|
        cmd.category "Testing & Development Commands"
        cmd.description COMMAND_DESCRIPTIONS["color"]
        cmd.flag :spatial, "--3d", description: "Launch in 3D spatial color picker mode"
        cmd.option :shape, "--shape=SHAPE", description: "3D shape: cube, sphere, circle, square"
        cmd.run do |ctx|
          if ctx.flag?(:spatial)
            shape_str = ctx[:shape]?.try(&.to_s.downcase)
            shape = case shape_str
                    when "sphere" then Opal::UI::ColorPickerShape::Sphere3D
                    when "circle" then Opal::UI::ColorPickerShape::Circle2D
                    when "square" then Opal::UI::ColorPickerShape::Square2D
                    else               Opal::UI::ColorPickerShape::Cube3D
                    end
            if chosen = Opal.pick_color_3d(initial_shape: shape)
              puts "Selected Color: \e[1;97m#{chosen.to_hex}\e[0m (RGB: #{chosen.to_rgb})"
            end
          else
            if chosen = Opal.pick_color(Opal::Color.hex("#89B4FA"))
              puts "Selected Color: \e[1;97m#{chosen.to_hex}\e[0m (RGB: #{chosen.to_rgb})"
            end
          end
          0
        end
      end

      cli.command :explore do |cmd|
        cmd.category "Testing & Development Commands"
        cmd.description COMMAND_DESCRIPTIONS["explore"]
        cmd.alias_name "files", "browse"
        cmd.run do |ctx|
          target_path = ctx.raw_args.first? || "."
          if chosen = Opal.file_dialog(initial_path: target_path)
            puts "Selected: \e[1;96m#{chosen}\e[0m"
          end
          0
        end
      end

      cli.command :shaders do |cmd|
        cmd.category "Testing & Development Commands"
        cmd.description COMMAND_DESCRIPTIONS["shaders"]
        cmd.alias_name "fx"
        cmd.run do |_ctx|
          puts Opal.style.bold.fg(:cyan).render("✨ Opal Text Shader Playground")
          puts "Launching TUI test runner with active CRT scanlines shader..."
          Commands::Test.run(["--tui"])
        end
      end

      # === Scaffolding & Distribution Commands ===
      cli.command :init do |cmd|
        cmd.category "Scaffolding & Distribution Commands"
        cmd.description COMMAND_DESCRIPTIONS["init"]
        cmd.run { |ctx| Commands::Init.run(ctx.raw_args) }
      end

      cli.command :upgrade do |cmd|
        cmd.category "Scaffolding & Distribution Commands"
        cmd.description COMMAND_DESCRIPTIONS["upgrade"]
        cmd.run { |ctx| Commands::Upgrade.run(ctx.raw_args) }
      end

      cli.command :addon do |cmd|
        cmd.category "Scaffolding & Distribution Commands"
        cmd.description COMMAND_DESCRIPTIONS["addon"]
        cmd.run { |ctx| Commands::InstallAddon.run(ctx.raw_args) }
      end

      cli.command :shard do |cmd|
        cmd.category "Scaffolding & Distribution Commands"
        cmd.description COMMAND_DESCRIPTIONS["shard"]
        cmd.run do |ctx|
          sub_args = ctx.raw_args
          is_uninstall = sub_args.includes?("uninstall") || sub_args.includes?("remove") || sub_args.includes?("-u")
          shard_args = sub_args.reject { |a| a == "install" || a == "add" || a == "uninstall" || a == "remove" || a == "-u" }
          if is_uninstall
            Commands::ShardManager.uninstall(shard_args)
          else
            Commands::ShardManager.install(shard_args)
          end
        end
      end

      cli.command :ide do |cmd|
        cmd.category "Scaffolding & Distribution Commands"
        cmd.description COMMAND_DESCRIPTIONS["ide"]
        cmd.run { |ctx| Commands::Ide.run(ctx.raw_args) }
      end

      cli.command :scaffold do |cmd|
        cmd.category "Scaffolding & Distribution Commands"
        cmd.description COMMAND_DESCRIPTIONS["scaffold"]
        cmd.alias_name "new"
        cmd.run { |ctx| Commands::Scaffold.run(ctx.raw_args) }
      end

      cli.command :package do |cmd|
        cmd.category "Scaffolding & Distribution Commands"
        cmd.description COMMAND_DESCRIPTIONS["package"]
        cmd.run { |ctx| Commands::Package.run(ctx.raw_args) }
      end

      cli.command :docs do |cmd|
        cmd.category "Scaffolding & Distribution Commands"
        cmd.description COMMAND_DESCRIPTIONS["docs"]
        cmd.run { |ctx| Commands::Docs.run(ctx.raw_args) }
      end

      cli.command :template do |cmd|
        cmd.category "Scaffolding & Distribution Commands"
        cmd.description COMMAND_DESCRIPTIONS["template"]
        cmd.alias_name "templates"
        cmd.run { |ctx| Commands::Template.run(ctx.raw_args) }
      end

      cli.command :"export-templates" do |cmd|
        cmd.category "Scaffolding & Distribution Commands"
        cmd.description COMMAND_DESCRIPTIONS["export-templates"]
        cmd.alias_name "export_templates"
        cmd.run { |ctx| Commands::ExportTemplates.run(ctx.raw_args) }
      end

      # === Inspection & Reverse Engineering ===
      cli.command :log do |cmd|
        cmd.category "Inspection & Reverse Engineering"
        cmd.description COMMAND_DESCRIPTIONS["log"]
        cmd.alias_name "logs"
        cmd.run { |ctx| Commands::Log.run(ctx.raw_args) }
      end

      cli.command :decompile do |cmd|
        cmd.category "Inspection & Reverse Engineering"
        cmd.description COMMAND_DESCRIPTIONS["decompile"]
        cmd.run { |ctx| Commands::Decompile.run(ctx.raw_args) }
      end

      cli.command :analyze do |cmd|
        cmd.category "Inspection & Reverse Engineering"
        cmd.description COMMAND_DESCRIPTIONS["analyze"]
        cmd.alias_name "audit"
        cmd.run { |ctx| Commands::Analyze.run(ctx.raw_args) }
      end

      # === Installation & System Commands ===
      cli.command :install do |cmd|
        cmd.category "Installation & System Commands"
        cmd.description COMMAND_DESCRIPTIONS["install"]
        cmd.run { |ctx| Commands::Install.run(ctx.raw_args) }
      end

      cli.command :uninstall do |cmd|
        cmd.category "Installation & System Commands"
        cmd.description COMMAND_DESCRIPTIONS["uninstall"]
        cmd.run { |ctx| Commands::Install.run(["--uninstall"] + ctx.raw_args) }
      end

      cli.command :get do |cmd|
        cmd.category "Installation & System Commands"
        cmd.description COMMAND_DESCRIPTIONS["get"]
        cmd.run { |ctx| Commands::Get.run(ctx.raw_args) }
      end

      cli.command :update do |cmd|
        cmd.category "Installation & System Commands"
        cmd.description COMMAND_DESCRIPTIONS["update"]
        cmd.run { |ctx| Commands::Update.run(ctx.raw_args) }
      end

      cli.command :completion do |cmd|
        cmd.category "Installation & System Commands"
        cmd.description COMMAND_DESCRIPTIONS["completion"]
        cmd.run do |ctx|
          shell = ctx.raw_args.first? || (Core::Env.windows? ? "powershell" : "bash")
          Lapis.generate_completion(shell)
        end
      end

      cli.command :version do |cmd|
        cmd.category "Installation & System Commands"
        cmd.description COMMAND_DESCRIPTIONS["version"]
        cmd.run do
          puts "Lapis v#{VERSION}"
          0
        end
      end
    end

    app.on_help { |_ctx| print_help; nil }
    app.subcommands.each_value do |cmd|
      cmd.allow_unknown_options
      cmd_name = cmd.name
      cmd.on_help do |ctx|
        raw = ctx ? ctx.raw_args : [] of String
        dispatch_help(cmd_name, raw)
        nil
      end
    end

    app
  end

  def self.print_help
    puts <<-HELP
\e[35m========================================================================\e[0m
\e[35m   Lapis: Unified Crystal Engine Toolchain for Godot (v#{VERSION})\e[0m
\e[35m========================================================================\e[0m

Usage:
  lapis <subcommand> [options]
  lapis help <subcommand>

\e[36mBuild & Synchronization Commands:\e[0m
  dirs                  Ensure all project and binary output directories exist
  deps                  Verify and copy Crystal runtime dependencies & libgodot DLLs
  sync                  Synchronize binaries, addons, and manifests across all targets
  build                 Compile Crystal game libraries, plugins, or standalone executables
  bind, generate        Generate typed bindings for Godot engine or project custom nodes
  clean                 Remove compiled game and bridge binaries (safely preserves runtime DLLs)

\e[36mTesting & Development Commands:\e[0m
  doctor                Diagnose developer environment, compilers, and project health
  editor                Launch Godot Editor with log monitoring, auto-quit, and radare2 attachment
  run                   Run Godot project standalone with log monitoring and radare2 attachment
  test                  Run unit specs, in-editor tool tests, and runtime test projects
  spec                  Run Crystal unit specs
  color                 Launch interactive 2D/3D TrueColor palette studio (Opal)
  explore, files        Launch interactive terminal file dialog & project explorer (Opal)
  shaders, fx           Launch real-time terminal text shader FX playground (Opal)
  benchmarks, bench     Run benchmarks, export HTML reports, and track version progression
  setup                 Download and configure targeted Godot engine binary

\e[36mScaffolding & Distribution Commands:\e[0m
  init                  Initialize Crystal & Lapis integration in an existing Godot project
  upgrade               Upgrade an existing Godot project to latest Lapis engine & bindings
  addon                 Install, uninstall, or manage Godot GDExtension addons
  shard                 Manage Crystal shard dependencies in Godot project
  ide                   Configure VS Code, Cursor, Zed, or Neovim with Crystalline LSP & radare2
  scaffold, new         Scaffold a new game, addon, or example ('lapis new game [name]')
  template              Manage global modular project templates ('lapis template save')
  export-templates      Inspect and install Godot export templates for Crystal
  package               Create native .zip distribution archives or playable standalone game
  docs                  Generate, search, and browse HTML/TUI documentation

Inspection & Reverse Engineering:
  log                   Manage, view, tail, search, export, and inspect diagnostic logs
  decompile             Decompile functions or disassemble binaries using native radare2
  analyze, audit        Perform deep static and dynamic radare2 binary and security analysis

Installation & System Commands:
  install               Install Lapis CLI globally into system/user PATH
  uninstall             Uninstall Lapis CLI globally from computer
  get                   Download Lapis source code or compiled release packages from GitHub
  update                Update Lapis executable, Crystalline LSP daemon, and Crystal compiler
  completion            Generate shell autocompletion script (powershell, bash, zsh)
  version               Display Lapis toolchain version

Global Options:
  -v, --version         Show Lapis toolchain version
  -h, --help            Show this help text
  -q, --quiet           Suppress non-essential log output
  --verbose             Enable verbose debug logging
  -i, --interactive     Launch interactive terminal dashboard

Examples:
  lapis doctor                          # Verify toolchain health
  lapis init                            # Add Crystal to an existing Godot project
  lapis new game my_game                # Create brand new game
  lapis template save my_template       # Save project as global reusable template
  lapis export-templates explain        # Explain Crystal export template mechanics
  lapis docs lookup gd "CharacterBody3D.move_and_slide"
  lapis addon install github:user/repo  # Install a Godot GDExtension addon
  lapis build game                      # Compile game library
  lapis editor                          # Open project in Godot Editor
  lapis clean --shadows                 # Prune stale Windows shadow DLLs (*_loaded_*)
  lapis clean --dry-run                 # Preview files and disk space to be reclaimed
  lapis package game -r                 # Package playable release game

For detailed help on any subcommand, run:
  lapis help <subcommand>   or   lapis <subcommand> --help

HELP
  end

  def self.dispatch_help(subcommand : String, args : Array(String) = [] of String)
    case subcommand
    when "cli", "hub", "ui"
      Commands::Cli.print_help
    when "dirs"
      puts "Usage: lapis dirs\n\nEnsures all output directories exist across root, test, template, and performance."
    when "deps"
      Commands::Deps.run(["--help"])
    when "sync"
      Commands::Sync.run(["--help"])
    when "build"
      Commands::Build.run(["--help"])
    when "bind", "generate", "bindings"
      Commands::Bind.run(["--help"])
    when "clean"
      Commands::Clean.run(["--help"])
    when "test"
      Commands::Test.run(["--help"])
    when "spec"
      Commands::Spec.run(["--help"])
    when "color"
      puts "Usage: lapis color [options]\n\nLaunch interactive 2D/3D TrueColor palette studio (Opal).\n\nOptions:\n  --3d                 Launch in 3D spatial color picker mode\n  --shape=SHAPE        3D shape: cube, sphere, circle, square"
    when "explore", "files", "browse"
      puts "Usage: lapis explore [DIR]\n\nLaunch interactive terminal file dialog & project explorer (Opal)."
    when "shaders", "fx"
      puts "Usage: lapis shaders\n\nLaunch real-time terminal text shader FX playground (Opal)."
    when "editor", "run"
      Commands::Editor.run(["--help"])
    when "decompile"
      Commands::Decompile.run(["--help"])
    when "analyze", "audit"
      Commands::Analyze.run(["--help"])
    when "setup"
      Commands::Setup.run(["--help"])
    when "doctor"
      Commands::Doctor.run(["--help"])
    when "init"
      Commands::Init.run(["--help"])
    when "upgrade"
      Commands::Upgrade.print_help
    when "addon"
      Commands::InstallAddon.print_help
    when "shard"
      Commands::ShardManager.print_help
    when "ide"
      Commands::Ide.print_help
    when "scaffold", "new"
      Commands::Scaffold.print_help
    when "template", "templates"
      Commands::Template.print_help
    when "export-templates", "export_templates"
      Commands::ExportTemplates.run(["--help"])
    when "package"
      Commands::Package.run(["--help"])
    when "docs"
      Commands::Docs.run(["--help"])
    when "version"
      puts "Usage: lapis version\n\nShow Lapis toolchain version."
    when "install"
      if args.includes?("addon")
        Commands::InstallAddon.print_help
      elsif args.includes?("shard") || args.includes?("shards")
        Commands::ShardManager.print_help
      else
        Commands::Install.print_help
      end
    when "uninstall"
      if args.includes?("shard") || args.includes?("shards")
        Commands::ShardManager.uninstall(["--help"])
      elsif args.includes?("addon")
        Commands::InstallAddon.print_help
      else
        Commands::Install.print_help
      end
    when "get"
      Commands::Get.print_help
    when "update"
      Commands::Update.print_help
    when "benchmarks", "benchmark", "bench"
      Commands::Benchmarks.print_help
    when "log", "logs"
      Commands::Log.print_help
    when "completion"
      puts "Usage: lapis completion <powershell|bash|zsh>\n\nGenerates native shell autocompletion script."
    else
      Core::Logger.error("Unknown command for help: '#{subcommand}'")
      if suggestion = suggest_command(subcommand)
        puts "  \e[33mDid you mean '#{suggestion}'?\e[0m\n"
      end
      puts
      print_help
    end
  end

  # Launches the central interactive TUI command hub and dashboard
  def self.launch_interactive_dashboard : Int32
    TUI::Hub.run
  end

  # Spotlight command palette offering instant fuzzy selection of all Lapis commands
  private def self.launch_command_palette : Int32
    palette_options = [
      "[#] build       - Compile Crystal game library and GDExtension loader bridge",
      "[T] test        - Run Crystal specs, in-editor tool tests, and Godot runtime suites",
      "[C] color       - Interactive 2D/3D TrueColor palette picker & studio",
      "[F] explore     - Interactive terminal file dialog & project explorer",
      "[~] shaders     - Real-time terminal text shaders & post-processing playground",
      "[?] doctor      - Diagnose developer environment, toolchain prerequisites, and compilers",
      "[E] editor      - Open project in Godot Editor with automatic shadow DLL reloading",
      "[+] scaffold    - Interactive scaffolding wizard for new games and redistributable addons",
      "[L] log         - Inspect, tail, search, and filter game and editor log traces",
      "[B] benchmarks  - Run and profile Crystal vs GDScript performance benchmark suite",
      "[x] clean       - Purge build artifacts, cache, and locked Windows shadow DLLs",
      "[A] addon       - Install, audit, scaffold, and package redistributable Godot addons",
      "[=] sync        - Synchronize runtime DLLs and manifests across consumer projects",
      "[D] decompile   - Interactive radare2 pseudo-C disassembler and binary inspector",
      "[P] package     - Package playable standalone game or redistributable release archive",
      "[*] docs        - Build offline HTML API documentation and Godot EditorHelp XML",
      "[S] setup       - Download and configure targeted Godot engine executable",
      "[U] update      - Update shards dependencies and Crystal toolchain",
      "[X] exit        - Return to terminal",
    ]

    selected = Opal.select("Search Command to Execute:", palette_options, default_index: 0)
    cmd_name = selected.split[1]?.try(&.downcase) || ""

    case cmd_name
    when "build"       then Commands::Build.run([] of String)
    when "test"        then Commands::Test.run(["--tui"])
    when "color"
      Opal.pick_color(Opal::Color.hex("#89B4FA"))
      0
    when "explore"
      Opal.file_dialog(initial_path: ".")
      0
    when "shaders"
      Commands::Test.run(["--tui"])
    when "doctor"      then Commands::Doctor.run([] of String)
    when "editor"      then Commands::Editor.run([] of String)
    when "scaffold"    then Commands::Scaffold.run([] of String)
    when "log"         then Commands::Log.run([] of String)
    when "benchmarks"  then Commands::Benchmarks.run([] of String)
    when "clean"       then Commands::Clean.run([] of String)
    when "addon"       then Commands::InstallAddon.run(["list"])
    when "sync"        then Commands::Sync.run([] of String)
    when "decompile"   then Commands::Decompile.run([] of String)
    when "package"     then Commands::Package.run([] of String)
    when "docs"        then Commands::Docs.run([] of String)
    when "setup"       then Commands::Setup.run([] of String)
    when "update"      then Commands::Update.run([] of String)
    else
      0
    end
  end

  def self.main(args : Array(String)) : Int32
    # Pre-parse global quiet/verbose flags so Core::Logger matches CLI state
    args.each do |arg|
      case arg
      when "-q", "--quiet"
        Core::Logger.quiet = true
      when "--verbose"
        Core::Logger.verbose = true
      end
    end

    if Core::Logger.verbose?
      Core::Logger.trace("Lapis", "CLI Invoked: lapis #{args.join(" ")} (platform: #{Core::Env.current_platform}, root: #{Core::Env::ROOT_DIR})")
    end

    # Interactive Dashboard: if invoked without arguments on an interactive terminal
    if args.empty?
      if STDOUT.tty? && !ENV.has_key?("CI")
        return launch_interactive_dashboard
      else
        print_help
        return 0
      end
    end

    if args.size == 1 && (args[0] == "-h" || args[0] == "--help")
      print_help
      return 0
    end

    if args.size == 1 && (args[0] == "-v" || args[0] == "--version" || args[0] == "version")
      puts "Lapis v#{VERSION}"
      return 0
    end

    if args.size == 1 && (args[0] == "-i" || args[0] == "--interactive")
      return launch_interactive_dashboard
    end

    # Handle top-level help command
    if args[0] == "help"
      if args.size > 1
        dispatch_help(args[1], args[2..])
      else
        print_help
      end
      return 0
    end

    # Delegate to Opal CLI App
    app = build_cli_app
    app.run(args)
  end
end

exit Lapis.main(ARGV)
