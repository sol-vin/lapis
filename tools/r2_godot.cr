# =============================================================================
# LibGodot - Standalone Radare2 Godot/Lapis Plugin Server & CLI
# =============================================================================
# Can be run as a standalone CLI tool or directly inside radare2 via `#!pipe`:
#   [0x140001000]> #!pipe crystal run tools/r2_godot.cr -- godot object rcx
#   [0x140001000]> #!pipe crystal run tools/r2_godot.cr -- godot variant rdx
#   [0x140001000]> #!pipe crystal run tools/r2_godot.cr -- lapis supervisor

require "cradare2"
require "../src/libgodot/debugger/r2_godot_plugin"

module Lapis
  module Debugger
    def self.run_cli(args : Array(String)) : Nil
      # Check if running in an active radare2 session via environment or pipe
      in_session = ENV.has_key?("R2PIPE_IN") || ENV.has_key?("R2PIPE_PATH")

      opts = Cradare2::Options.build do |o|
        o.auto_analyze = false
      end

      # Connect to current session or target binary
      client = if in_session
                 opts.target = nil
                 Cradare2.open(opts)
               else
                 # Fallback: create client against game.dll or first arg
                 target = args.find { |a| a.ends_with?(".dll") || a.ends_with?(".exe") } || "bin/game.dll"
                 opts.target = target
                 Cradare2.open(opts)
               end

      plugin = R2GodotPlugin.new(client)
      router = Cradare2::Plugin::Router.new(client)
      router.mount("godot", plugin.godot_dispatcher)
      router.mount("lapis", plugin.lapis_dispatcher)

      # Strip target flags from arguments
      cmd_args = args.reject { |a| a.ends_with?(".dll") || a.ends_with?(".exe") }

      if cmd_args.empty?
        # Run interactive pipe server loop if on pipe
        if in_session
          Cradare2::Plugin::Server.run(router)
        else
          puts router.dispatch("godot detect")
          puts
          puts router.dispatch("lapis info")
        end
      else
        cmd_line = cmd_args.join(" ")
        output = router.dispatch(cmd_line)
        puts output
      end
    rescue ex
      STDERR.puts "Error in r2_godot: #{ex.message}"
    end
  end
end

Lapis::Debugger.run_cli(ARGV)
