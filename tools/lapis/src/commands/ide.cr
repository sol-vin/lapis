require "../core/env"
require "../core/logger"
require "../core/process_runner"
require "file_utils"
require "option_parser"

module Lapis
  module Commands
    module Ide
      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: IDE & Editor Configuration Tool ===\e[0m

Usage: lapis ide <subcommand> [editor] [options]

Configures editor and IDE workspaces (VS Code, Cursor, Zed, Neovim) with
Crystalline LSP support, build tasks, and LLDB debugger launch configurations.

Subcommands:
  setup [editor]        Generate workspace settings and tasks for specified editor
                        Supported editors: vscode (default), zed, neovim

Options:
  -p, --path=PATH       Project directory (default: current working directory)
  -f, --force           Overwrite existing workspace configuration files
  -h, --help            Show this help screen

Examples:
  lapis ide setup
  lapis ide setup vscode
  lapis ide setup zed
  lapis ide setup neovim
HELP
      end

      def self.run(args : Array(String)) : Int32
        if args.empty? || args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        subcmd = args.first
        editor = "vscode"
        proj_path : String? = nil
        force = false

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis ide <subcommand> [editor] [options]"
          opts.on("-p PATH", "--path=PATH", "Target project directory") { |p| proj_path = p }
          opts.on("-f", "--force", "Overwrite existing configuration") { force = true }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
          opts.unknown_args do |before, after|
            rem = before + after
            if rem.size > 1 && subcmd == "setup"
              editor = rem[1]
            end
          end
        end

        parser.parse(args)

        target_dir = if (pp = proj_path) && !pp.empty?
                       Path.new(pp).expand
                     else
                       Path.new(Dir.current).expand
                     end

        case subcmd.downcase
        when "setup"
          setup_editor(target_dir, editor.downcase, force)
        else
          Core::Logger.error("Unknown ide subcommand: '#{subcmd}'. Run 'lapis ide --help' for usage.")
          1
        end
      end

      def self.setup_editor(target_dir : Path, editor : String, force : Bool) : Int32
        case editor
        when "vscode", "cursor", "windsurf"
          setup_vscode(target_dir, force)
        when "zed"
          setup_zed(target_dir, force)
        when "neovim", "nvim"
          setup_neovim(target_dir, force)
        else
          Core::Logger.error("Unsupported editor '#{editor}'. Supported: vscode, zed, neovim.")
          1
        end
      end

      def self.setup_vscode(target_dir : Path, force : Bool) : Int32
        vscode_dir = target_dir.join(".vscode")
        FileUtils.mkdir_p(vscode_dir) unless Dir.exists?(vscode_dir)

        # 1. settings.json
        settings_file = vscode_dir.join("settings.json")
        if !File.exists?(settings_file) || force
          root = Core::Env::ROOT_DIR
          crystalline_path = root.join("bin/crystalline" + (Core::Env.windows? ? ".exe" : "")).to_s.gsub('\\', '/')
          settings_json = <<-JSON
{
  "crystal-lang.server": "#{crystalline_path}",
  "crystal-lang.compiler": "crystal",
  "files.associations": {
    "*.cr": "crystal",
    "*.gdextension": "ini",
    "*.tscn": "ini",
    "*.godot": "ini"
  },
  "editor.formatOnSave": true,
  "godotTools.editorPath.godot4": "./godot#{Core::Env.exe_ext}",
  "godotTools.lsp.serverPort": 6005
}
JSON
          File.write(settings_file, settings_json)
          Core::Logger.success("Generated #{settings_file}")
        else
          Core::Logger.info("#{settings_file} already exists (use --force to overwrite)")
        end

        # 2. tasks.json
        tasks_file = vscode_dir.join("tasks.json")
        if !File.exists?(tasks_file) || force
          lapis_cmd = Core::Env::ROOT_DIR.join("bin/lapis" + Core::Env.exe_ext).to_s.gsub('\\', '/')
          tasks_json = <<-JSON
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Lapis: Build Game (F5)",
      "type": "shell",
      "command": "#{lapis_cmd} build game",
      "group": {
        "kind": "build",
        "isDefault": true
      },
      "problemMatcher": []
    },
    {
      "label": "Lapis: Run Game",
      "type": "shell",
      "command": "#{lapis_cmd} run",
      "problemMatcher": []
    },
    {
      "label": "Lapis: Run Tests",
      "type": "shell",
      "command": "#{lapis_cmd} test",
      "problemMatcher": []
    },
    {
      "label": "Lapis: Doctor Diagnostics",
      "type": "shell",
      "command": "#{lapis_cmd} doctor",
      "problemMatcher": []
    }
  ]
}
JSON
          File.write(tasks_file, tasks_json)
          Core::Logger.success("Generated #{tasks_file}")
        else
          Core::Logger.info("#{tasks_file} already exists (use --force to overwrite)")
        end

        # 3. launch.json
        launch_file = vscode_dir.join("launch.json")
        if !File.exists?(launch_file) || force
          launch_json = <<-JSON
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug Godot Game (LLDB)",
      "type": "lldb",
      "request": "launch",
      "program": "${workspaceFolder}/godot#{Core::Env.exe_ext}",
      "args": ["--path", "${workspaceFolder}"],
      "cwd": "${workspaceFolder}",
      "preLaunchTask": "Lapis: Build Game (F5)"
    },
    {
      "name": "Debug Godot Editor (LLDB)",
      "type": "lldb",
      "request": "launch",
      "program": "${workspaceFolder}/godot#{Core::Env.exe_ext}",
      "args": ["--editor", "--path", "${workspaceFolder}"],
      "cwd": "${workspaceFolder}"
    }
  ]
}
JSON
          File.write(launch_file, launch_json)
          Core::Logger.success("Generated #{launch_file}")
        else
          Core::Logger.info("#{launch_file} already exists (use --force to overwrite)")
        end

        Core::Logger.success("VS Code workspace configured for Lapis and Crystal!")
        0
      end

      def self.setup_zed(target_dir : Path, force : Bool) : Int32
        zed_dir = target_dir.join(".zed")
        FileUtils.mkdir_p(zed_dir) unless Dir.exists?(zed_dir)
        settings_file = zed_dir.join("settings.json")
        if !File.exists?(settings_file) || force
          root = Core::Env::ROOT_DIR
          crystalline_path = root.join("bin/crystalline" + (Core::Env.windows? ? ".exe" : "")).to_s.gsub('\\', '/')
          zed_json = <<-JSON
{
  "languages": {
    "Crystal": {
      "language_servers": ["crystalline"]
    }
  },
  "lsp": {
    "crystalline": {
      "binary": {
        "path": "#{crystalline_path}"
      }
    }
  }
}
JSON
          File.write(settings_file, zed_json)
          Core::Logger.success("Generated #{settings_file}")
        else
          Core::Logger.info("#{settings_file} already exists (use --force to overwrite)")
        end
        Core::Logger.success("Zed workspace configured for Lapis and Crystal!")
        0
      end

      def self.setup_neovim(target_dir : Path, force : Bool) : Int32
        nvim_file = target_dir.join(".lapis_nvim.lua")
        if !File.exists?(nvim_file) || force
          root = Core::Env::ROOT_DIR
          crystalline_path = root.join("bin/crystalline" + (Core::Env.windows? ? ".exe" : "")).to_s.gsub('\\', '/')
          lua_config = <<-LUA
-- Lapis Neovim Crystalline LSP Configuration
-- Source this in your init.lua or lua/plugins/lsp.lua
local lspconfig = require('lspconfig')
lspconfig.crystalline.setup({
  cmd = { "#{crystalline_path}", "--stdio" },
  filetypes = { "crystal" },
  root_dir = lspconfig.util.root_pattern("shard.yml", ".git")
})
LUA
          File.write(nvim_file, lua_config)
          Core::Logger.success("Generated #{nvim_file}")
        else
          Core::Logger.info("#{nvim_file} already exists (use --force to overwrite)")
        end
        Core::Logger.success("Neovim configuration generated for Lapis and Crystal!")
        0
      end
    end
  end
end
