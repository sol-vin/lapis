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
require "./commands/doctor"
require "./commands/init"
require "./commands/ide"

module Lapis
  ALL_COMMANDS = [
    "dirs", "deps", "sync", "build", "bind", "generate", "clean",
    "test", "editor", "run", "setup", "doctor", "init", "ide",
    "scaffold", "new", "package", "docs", "version", "install", "uninstall", "completion"
  ]

  def self.levenshtein_distance(str1 : String, str2 : String) : Int32
    s1, s2 = str1.chars, str2.chars
    m, n = s1.size, s2.size
    d = Array.new(m + 1) { Array.new(n + 1, 0) }

    (0..m).each { |i| d[i][0] = i }
    (0..n).each { |j| d[0][j] = j }

    (1..m).each do |i|
      (1..n).each do |j|
        cost = (s1[i - 1] == s2[j - 1]) ? 0 : 1
        d[i][j] = Math.min(
          d[i - 1][j] + 1,      # deletion
          Math.min(
            d[i][j - 1] + 1,    # insertion
            d[i - 1][j - 1] + cost # substitution
          )
        )
      end
    end
    d[m][n]
  end

  def self.suggest_command(typo : String) : String?
    best = ALL_COMMANDS.min_by? { |c| levenshtein_distance(typo.downcase, c) }
    if best && levenshtein_distance(typo.downcase, best) <= 3
      best
    else
      nil
    end
  end

  def self.generate_completion(shell : String) : Int32
    case shell.downcase
    when "powershell", "pwsh"
      puts <<-PS1
# PowerShell completion script for Lapis CLI
Register-ArgumentCompleter -Native -CommandName lapis -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    $commands = @(
        'dirs', 'deps', 'sync', 'build', 'bind', 'generate', 'clean',
        'test', 'editor', 'run', 'setup', 'doctor', 'init',
        'scaffold', 'new', 'package', 'docs', 'version', 'install', 'uninstall', 'completion'
    )
    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
PS1
    when "bash"
      puts <<-BASH
# Bash completion script for Lapis CLI
_lapis_completions() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local commands="dirs deps sync build bind generate clean test editor run setup doctor init scaffold new package docs version install uninstall completion"
    COMPREPLY=( $(compgen -W "${commands}" -- "${cur}") )
}
complete -F _lapis_completions lapis
BASH
    when "zsh"
      puts <<-ZSH
# Zsh completion script for Lapis CLI
#compdef lapis
_lapis() {
    local -a commands
    commands=(
        'dirs:Ensure project and binary output directories exist'
        'deps:Verify and copy Crystal runtime dependencies & libgodot DLLs'
        'sync:Synchronize binaries, addons, and manifests across all targets'
        'build:Compile Crystal game libraries, plugins, or executables'
        'bind:Generate typed bindings for Godot engine or custom nodes'
        'clean:Remove build binaries and caches (preserves runtime libraries)'
        'test:Run test suites and headless verification'
        'editor:Launch Godot Editor with log monitoring and LLDB'
        'run:Run Godot project standalone'
        'setup:Download and configure targeted Godot engine binary'
        'doctor:Diagnose toolchain environment and project health'
        'init:Initialize Crystal integration in an existing Godot project'
        'scaffold:Scaffold a new game, addon, or example'
        'package:Create distribution archives or playable standalone game'
        'docs:Generate HTML API documentation'
        'version:Display Lapis toolchain version'
        'install:Install Lapis CLI globally'
        'uninstall:Uninstall Lapis CLI globally'
        'completion:Generate shell autocompletion script'
    )
    _describe 'command' commands
}
ZSH
    else
      Core::Logger.error("Unsupported shell for completion: '#{shell}'. Supported: powershell, bash, zsh.")
      return 1
    end
    0
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
  editor                Launch Godot Editor with log monitoring, auto-quit, and LLDB attachment
  run                   Run Godot project standalone with log monitoring and LLDB attachment
  test                  Run unit specs, in-editor tool tests, and runtime test projects
  setup                 Download and configure targeted Godot engine binary

\e[36mScaffolding & Distribution Commands:\e[0m
  init                  Initialize Crystal & Lapis integration in an existing Godot project
  ide                   Configure VS Code, Cursor, Zed, or Neovim with Crystalline LSP & LLDB
  scaffold, new         Scaffold a new game, addon, or example ('lapis new game [name]')
  package               Create native .zip distribution archives or playable standalone game
  docs                  Generate and patch HTML API documentation

\e[36mInstallation & System Commands:\e[0m
  doctor                Run full toolchain & project diagnostic checkup
  install               Install Lapis CLI globally into system/user PATH
  uninstall             Uninstall Lapis CLI globally from computer
  completion            Generate shell autocompletion script (powershell, bash, zsh)
  version               Display Lapis toolchain version

\e[36mGlobal Options:\e[0m
  -v, --version         Show Lapis toolchain version
  -h, --help            Show this help text
  -q, --quiet           Suppress non-essential log output
  --verbose             Enable verbose debug logging

\e[36mExamples:\e[0m
  lapis doctor                          # Verify toolchain health
  lapis init                            # Add Crystal to an existing Godot project
  lapis new game my_game                # Create brand new game
  lapis build game                      # Compile game library
  lapis editor                          # Open project in Godot Editor
  lapis clean --dry-run                 # Preview files and disk space to be reclaimed
  lapis clean                           # Prune intermediate artifacts & redundant files
  lapis package game -r                 # Package playable release game

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
    when "doctor"
      Commands::Doctor.run(["--help"])
    when "init"
      Commands::Init.run(["--help"])
    when "ide"
      Commands::Ide.print_help
    when "scaffold", "new"
      Commands::Scaffold.print_help
    when "package"
      Commands::Package.run(["--help"])
    when "docs"
      Commands::Docs.run(["--help"])
    when "version"
      puts "Usage: lapis version\n\nShow Lapis toolchain version."
    when "install", "uninstall"
      Commands::Install.print_help
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

  def self.main(args : Array(String)) : Int32
    if args.empty?
      print_help
      return 0
    end

    if args.size == 1 && (args[0] == "-h" || args[0] == "--help")
      print_help
      return 0
    end

    if args.size == 1 && (args[0] == "-v" || args[0] == "--version" || args[0] == "version")
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
      when "-v"
        # If alone, it was handled above. If combined with a command, it means verbose.
        Core::Logger.verbose = true
      else
        filtered_args << arg
      end
    end

    if Core::Logger.verbose?
      Core::Logger.trace("Lapis", "CLI Invoked: lapis #{args.join(" ")} (platform: #{Core::Env.current_platform}, root: #{Core::Env::ROOT_DIR})")
    end

    if filtered_args.empty?
      print_help
      return 0
    end

    subcommand = filtered_args[0]
    sub_args = filtered_args[1..]

    case subcommand
    when "version"
      puts "Lapis v#{VERSION}"
      0
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
    when "doctor", "check"
      Commands::Doctor.run(sub_args)
    when "init"
      Commands::Init.run(sub_args)
    when "ide"
      Commands::Ide.run(sub_args)
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
    when "completion"
      shell = sub_args.first? || (Core::Env.windows? ? "powershell" : "bash")
      generate_completion(shell)
    else
      Core::Logger.error("Unknown command: '#{subcommand}'")
      if suggestion = suggest_command(subcommand)
        puts "  \e[33mDid you mean '#{suggestion}'?\e[0m\n"
      end
      puts
      print_help
      1
    end
  end
end

exit Lapis.main(ARGV)
