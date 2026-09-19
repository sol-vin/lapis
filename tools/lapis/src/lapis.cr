require "./version"
require "./core/env"
require "./core/logger"
require "./commands/dirs"
require "./commands/deps"
require "./commands/sync"
require "./commands/build"
require "./commands/test"
require "./commands/editor"
require "./commands/scaffold"
require "./commands/package"
require "./commands/bind"
require "./commands/clean"
require "./commands/docs"
require "./commands/setup"
require "./commands/install"

module Lapis

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
  test                  Run unit specs, in-editor tool tests, and runtime test projects
  editor                Launch Godot Editor with log monitoring, auto-quit, and LLDB attachment
  run                   Run Godot project standalone with log monitoring and LLDB attachment
  setup                 Download and configure targeted Godot engine binary

\e[36mScaffolding & Distribution Commands:\e[0m
  scaffold, new         Scaffold a new game, addon, or example ('lapis new game [name]')
  package               Create native .zip distribution archives or playable standalone game
  docs                  Generate and patch HTML API documentation

\e[36mInstallation & System Commands:\e[0m
  install               Install Lapis CLI globally into system/user PATH
  uninstall             Uninstall Lapis CLI globally from computer

\e[36mGlobal Options:\e[0m
  -v, --version         Show Lapis toolchain version
  -h, --help            Show this help text
  -q, --quiet           Suppress non-essential log output
  --verbose             Enable verbose debug logging

\e[36mExamples:\e[0m
  lapis dirs
  lapis deps
  lapis sync
  lapis new game my_game
  lapis bind engine                     # Generate LibGodot engine class bindings
  lapis bind project                    # Generate wrappers for custom GDScript nodes
  lapis build -e src/editor/plugin.cr -o bin/plugin.dll --flags "-Dlibgodot_addon"
  lapis test
  lapis editor -p test --quit-after 5
  lapis package game -p template -r
  lapis clean

For detailed help on any subcommand, run:
  lapis help <subcommand>   or   lapis <subcommand> --help

HELP
  end

  def self.dispatch_help(subcommand : String)
    case subcommand
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
    when "editor", "run"
      Commands::Editor.run(["--help"])
    when "setup"
      Commands::Setup.run(["--help"])
    when "scaffold", "new"
      Commands::Scaffold.print_help
    when "package"
      Commands::Package.run(["--help"])
    when "docs"
      Commands::Docs.run(["--help"])
    when "install", "uninstall"
      Commands::Install.print_help
    else
      Core::Logger.error("Unknown command for help: '#{subcommand}'")
      puts
      print_help
    end
  end

  def self.main(args : Array(String)) : Int32
    if args.empty?
      print_help
      return 0
    end

    if args.size == 1 && (args[0] == "-h" || args[0] == "--help")
      print_help
      return 0
    end

    if args.size == 1 && (args[0] == "-v" || args[0] == "--version")
      puts "Lapis v#{VERSION}"
      return 0
    end

    # Handle global quiet/verbose flags
    filtered_args = [] of String
    args.each do |arg|
      case arg
      when "-q", "--quiet"
        Core::Logger.quiet = true
      when "--verbose"
        Core::Logger.verbose = true
      else
        filtered_args << arg
      end
    end

    if filtered_args.empty?
      print_help
      return 0
    end

    subcommand = filtered_args[0]
    sub_args = filtered_args[1..]

    case subcommand
    when "help"
      if sub_args.empty?
        print_help
      else
        dispatch_help(sub_args[0])
      end
      0
    when "dirs"
      Commands::Dirs.run(sub_args)
    when "deps"
      Commands::Deps.run(sub_args)
    when "sync"
      Commands::Sync.run(sub_args)
    when "build"
      Commands::Build.run(sub_args)
    when "bind", "generate", "bindings"
      Commands::Bind.run(sub_args)
    when "clean"
      Commands::Clean.run(sub_args)
    when "test"
      Commands::Test.run(sub_args)
    when "editor"
      Commands::Editor.run(sub_args)
    when "run"
      Commands::Editor.run(["--run"] + sub_args)
    when "setup"
      Commands::Setup.run(sub_args)
    when "scaffold", "new"
      Commands::Scaffold.run(sub_args)
    when "package"
      Commands::Package.run(sub_args)
    when "docs"
      Commands::Docs.run(sub_args)
    when "install"
      Commands::Install.run(sub_args)
    when "uninstall"
      Commands::Install.run(["--uninstall"] + sub_args)
    else
      Core::Logger.error("Unknown command: '#{subcommand}'")
      puts
      print_help
      1
    end
  end
end

exit Lapis.main(ARGV)
