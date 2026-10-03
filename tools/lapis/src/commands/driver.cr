# =============================================================================
# Lapis - In-Editor Action Driver CLI Controller & REPL
# =============================================================================

require "../core/env"
require "../core/logger"
require "socket"
require "json"
require "option_parser"

module Lapis
  module Commands
    module Driver
      DEFAULT_PORT = 9095

      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: In-Editor Action Driver Controller ===\e[0m

Usage: lapis driver [command] [args] [options]

Commands:
  click <selector>            Click an in-editor Button or Control
  type <selector> <text>      Type text into a LineEdit / TextEdit
  select-tab <tab_name>       Switch an active TabBar / TabContainer
  open-scene <path>           Open a scene in Godot Editor
  save-scene                  Save current edited scene
  build                       Trigger Crystal build button in editor
  screenshot [path]           Capture full editor viewport screenshot
  crop <selector> [path]      Capture isolated screenshot of a single UI element
  vision [output_dir]         Generate Set-of-Marks AI Vision manifest & cropped widgets
  dom [depth]                 Dump live Godot Editor DOM tree hierarchy
  status                      Check connection status to running Godot Editor
  repl                        Launch interactive Action Driver REPL

Options:
  --port, -p <num>            Godot Action Driver IPC port (default: 9095)
  --host <addr>               IPC host (default: 127.0.0.1)
  -h, --help                  Show this help screen

Examples:
  lapis driver click "Build"
  lapis driver crop "Build" --output reports/elements/build.png
  lapis driver vision --output reports/ai_vision
  lapis driver repl
HELP
      end

      # Sends a JSON request over TCP socket to running Godot Editor
      def self.send_ipc(payload : Hash(String, JSON::Any), host : String = "127.0.0.1", port : Int32 = DEFAULT_PORT) : JSON::Any?
        begin
          client = TCPSocket.new(host, port, connect_timeout: 3.seconds)
          client.puts(payload.to_json)
          client.flush
          response = client.gets
          client.close
          response ? JSON.parse(response) : nil
        rescue ex
          puts "\e[31m[ActionDriver] Connection Error:\e[0m Could not connect to Godot Editor at #{host}:#{port} (#{ex.message})"
          puts "\e[33mHint:\e[0m Ensure Godot Editor is running with Lapis GDExtension loaded."
          nil
        end
      end

      def self.run(args : Array(String)) : Int32
        if args.empty? || args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        port = ENV["GODOT_DRIVER_PORT"]?.try(&.to_i?) || DEFAULT_PORT
        host = "127.0.0.1"

        cmd = args[0]
        sub_args = args[1..-1]

        case cmd
        when "status"
          req = {"action" => JSON::Any.new("status")}
          if res = send_ipc(req, host, port)
            puts "\e[32m[Connected]\e[0m Godot Editor running (PID: #{res["pid"]? || "unknown"})"
            0
          else
            1
          end
        when "click"
          selector = sub_args[0]? || "Build"
          req = {
            "action" => JSON::Any.new("click"),
            "selector" => JSON::Any.new(selector),
          }
          if res = send_ipc(req, host, port)
            puts "\e[32m[Success]\e[0m #{res["message"]? || "Clicked #{selector}"}"
            0
          else
            1
          end
        when "type"
          selector = sub_args[0]? || ""
          text = sub_args[1]? || ""
          req = {
            "action" => JSON::Any.new("type"),
            "selector" => JSON::Any.new(selector),
            "text" => JSON::Any.new(text),
          }
          if res = send_ipc(req, host, port)
            puts "\e[32m[Success]\e[0m #{res["message"]? || "Typed into #{selector}"}"
            0
          else
            1
          end
        when "select-tab"
          tab = sub_args[0]? || "Crystal"
          req = {
            "action" => JSON::Any.new("select_tab"),
            "selector" => JSON::Any.new("TabBar"),
            "tab" => JSON::Any.new(tab),
          }
          if res = send_ipc(req, host, port)
            puts "\e[32m[Success]\e[0m #{res["message"]? || "Selected tab #{tab}"}"
            0
          else
            1
          end
        when "open-scene"
          path = sub_args[0]? || "res://scenes/main.tscn"
          req = {
            "action" => JSON::Any.new("open_scene"),
            "path" => JSON::Any.new(path),
          }
          if res = send_ipc(req, host, port)
            puts "\e[32m[Success]\e[0m #{res["message"]? || "Opened scene"}"
            0
          else
            1
          end
        when "save-scene"
          req = {"action" => JSON::Any.new("save_scene")}
          if res = send_ipc(req, host, port)
            puts "\e[32m[Success]\e[0m #{res["message"]? || "Saved scene"}"
            0
          else
            1
          end
        when "build"
          req = {"action" => JSON::Any.new("trigger_build")}
          if res = send_ipc(req, host, port)
            puts "\e[32m[Success]\e[0m #{res["message"]? || "Triggered build"}"
            0
          else
            1
          end
        when "screenshot"
          path = sub_args[0]? || "reports/screenshots/editor.png"
          req = {
            "action" => JSON::Any.new("screenshot"),
            "path" => JSON::Any.new(path),
          }
          if res = send_ipc(req, host, port)
            puts "\e[32m[Success]\e[0m Screenshot captured: #{res["path"]? || path}"
            0
          else
            1
          end
        when "crop"
          selector = sub_args[0]? || "Build"
          path = sub_args[1]? || "reports/elements/#{selector}.png"
          req = {
            "action" => JSON::Any.new("crop"),
            "selector" => JSON::Any.new(selector),
            "path" => JSON::Any.new(path),
          }
          if res = send_ipc(req, host, port)
            puts "\e[32m[Success]\e[0m Cropped element '#{selector}' saved to #{res["path"]? || path}"
            0
          else
            1
          end
        when "vision"
          out_dir = sub_args[0]? || "reports/ai_vision"
          req = {
            "action" => JSON::Any.new("vision"),
            "output_dir" => JSON::Any.new(out_dir),
          }
          if res = send_ipc(req, host, port)
            puts "\e[32m[Success]\e[0m AI Vision Manifest generated: #{res["manifest_path"]?} (#{res["element_count"]?} elements)"
            0
          else
            1
          end
        when "dom"
          depth = sub_args[0]?.try(&.to_i?) || 6
          req = {
            "action" => JSON::Any.new("dump_dom"),
            "depth" => JSON::Any.new(depth.to_i64),
          }
          if res = send_ipc(req, host, port)
            puts res["dom"]?.try(&.as_s?) || "Empty DOM"
            0
          else
            1
          end
        when "repl"
          run_repl(host, port)
          0
        else
          puts "\e[31mUnknown command:\e[0m #{cmd}"
          print_help
          1
        end
      end

      # Interactive terminal REPL
      def self.run_repl(host : String, port : Int32) : Void
        puts "\e[35m=== Lapis Action Driver Interactive REPL ===\e[0m"
        puts "Connecting to Godot Editor on #{host}:#{port}..."

        ping_req = {"action" => JSON::Any.new("ping")}
        res = send_ipc(ping_req, host, port)
        unless res
          puts "\e[31mFailed to connect to Godot Editor.\e[0m"
          return
        end

        puts "\e[32mConnected successfully!\e[0m Type 'help' for commands, 'exit' to quit.\n"

        loop do
          print "\e[36mlapis-driver>\e[0m "
          line = gets
          break if line.nil? || line.strip == "exit" || line.strip == "quit"
          tokens = line.strip.split(/\s+/)
          next if tokens.empty?

          action = tokens[0]
          case action
          when "help"
            puts "Commands: click <target>, type <target> <text>, select-tab <tab>, screenshot, crop <target>, vision, dom, exit"
          when "click"
            target = tokens[1]? || "Build"
            run(["click", target])
          when "type"
            target = tokens[1]? || ""
            text = tokens[2..-1].join(" ")
            run(["type", target, text])
          when "select-tab"
            tab = tokens[1]? || "Crystal"
            run(["select-tab", tab])
          when "screenshot"
            run(["screenshot"])
          when "crop"
            target = tokens[1]? || "Build"
            run(["crop", target])
          when "vision"
            run(["vision"])
          when "dom"
            run(["dom"])
          else
            puts "Unknown command '#{action}'. Type 'help' for available commands."
          end
        end
      end
    end
  end
end
