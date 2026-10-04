# =============================================================================
# LibGodot - Action Driver JSON-RPC IPC Server
# =============================================================================
# Embedded localhost TCP listener allowing external CLI (`lapis driver`) and
# TUI dashboards to control the running Godot Editor instance in real time.
# =============================================================================

require "socket"
require "json"
require "./action_driver"
require "./action_driver_vision"

module Lapis
  module Editor
    class DriverServer
      DEFAULT_PORT = 9095
      @@instance : DriverServer? = nil

      getter? running : Bool = false
      getter port : Int32
      @server : ::TCPServer? = nil
      @driver : ActionDriver

      def initialize(@port : Int32 = DEFAULT_PORT)
        @driver = ActionDriver.new
      end

      def self.instance : DriverServer
        @@instance ||= new(ENV["GODOT_DRIVER_PORT"]?.try(&.to_i?) || DEFAULT_PORT)
      end

      def self.start_if_enabled : Void
        # Auto-starts in editor mode unless explicitly disabled
        if Godot.editor_hint? && ENV["GODOT_DRIVER_DISABLE"]? != "1"
          instance.start rescue nil
        end
      end

      def start : Void
        return if @running
        begin
          server = ::TCPServer.new("127.0.0.1", @port)
          @server = server
          @running = true
          Godot.print("[DriverServer] Action Driver IPC listening on 127.0.0.1:#{@port}")

          spawn do
            while @running
              begin
                if client = server.accept?
                  spawn handle_client(client)
                else
                  break
                end
              rescue
                break unless @running
              end
            end
          end
        rescue ex
          Godot.print("[DriverServer] Notice: could not bind IPC socket on port #{@port}: #{ex.message}")
        end
      end

      def stop : Void
        @running = false
        @server.try(&.close) rescue nil
        @server = nil
      end

      private def handle_client(client : ::TCPSocket) : Void
        while line = client.gets
          break if line.empty?
          response = dispatch_command(line.strip)
          client.puts(response)
          client.flush
        end
      ensure
        client.close rescue nil
      end

      private def dispatch_command(raw_json : String) : String
        data = ::JSON.parse(raw_json) rescue nil
        return {"status" => "error", "message" => "Malformed JSON"}.to_json unless data

        action = data["action"]?.try(&.as_s?) || ""

        case action
        when "ping"
          {"status" => "ok", "pong" => true, "pid" => Process.pid}.to_json
        when "status"
          {
            "status"  => "ok",
            "editor"  => Godot.editor_hint?,
            "pid"     => Process.pid,
            "version" => Godot::VERSION,
          }.to_json
        when "click"
          selector = data["selector"]?.try(&.as_s?) || ""
          if ctrl = @driver.find_control(selector) || @driver.find_button(selector)
            @driver.click(ctrl)
            {"status" => "ok", "message" => "Clicked '#{ctrl.name}'"}.to_json
          else
            {"status" => "error", "message" => "Control not found: '#{selector}'"}.to_json
          end
        when "type"
          selector = data["selector"]?.try(&.as_s?) || ""
          text = data["text"]?.try(&.as_s?) || ""
          if ctrl = @driver.find_control(selector) || @driver.find_line_edit(selector)
            @driver.type_text(ctrl, text)
            {"status" => "ok", "message" => "Typed text into '#{ctrl.name}'"}.to_json
          else
            {"status" => "error", "message" => "Control not found: '#{selector}'"}.to_json
          end
        when "select_tab"
          selector = data["selector"]?.try(&.as_s?) || ""
          tab = data["tab"]?.try(&.as_s?) || ""
          if ctrl = @driver.find_control(selector)
            @driver.select_tab(ctrl, tab)
            {"status" => "ok", "message" => "Selected tab '#{tab}' on '#{ctrl.name}'"}.to_json
          else
            {"status" => "error", "message" => "Tab control not found: '#{selector}'"}.to_json
          end
        when "open_scene"
          path = data["path"]?.try(&.as_s?) || ""
          @driver.open_scene(path)
          {"status" => "ok", "message" => "Opened scene '#{path}'"}.to_json
        when "save_scene"
          @driver.save_scene
          {"status" => "ok", "message" => "Saved current scene"}.to_json
        when "open_script"
          path = data["path"]?.try(&.as_s?) || ""
          line = data["line"]?.try(&.as_i?) || 1
          col = data["col"]?.try(&.as_i?) || 0
          if @driver.open_script(path, line, col)
            {"status" => "ok", "message" => "Opened script '#{path}' at #{line}:#{col}"}.to_json
          else
            {"status" => "error", "message" => "Failed to open script '#{path}'"}.to_json
          end
        when "current_script"
          curr = @driver.get_current_script_path
          {"status" => "ok", "path" => curr}.to_json
        when "open_scripts"
          scripts = @driver.get_open_script_paths
          {"status" => "ok", "scripts" => scripts}.to_json
        when "switch_main_screen"
          screen = data["screen"]?.try(&.as_s?) || ""
          @driver.switch_to_main_screen(screen)
          {"status" => "ok", "message" => "Switched to main screen '#{screen}'"}.to_json
        when "find"
          selector = data["selector"]?.try(&.as_s?) || ""
          if ctrl = @driver.find_control(selector) || @driver.find_button(selector)
            {
              "status"  => "ok",
              "found"   => true,
              "name"    => ctrl.name,
              "class"   => ctrl.get_class,
              "visible" => (ctrl.is_visible rescue true),
            }.to_json
          else
            {"status" => "ok", "found" => false, "selector" => selector}.to_json
          end
        when "trigger_build"
          @driver.trigger_crystal_build
          {"status" => "ok", "message" => "Triggered Crystal build"}.to_json
        when "dump_dom"
          depth = data["depth"]?.try(&.as_i?) || 6
          dom = @driver.dump_dom(max_depth: depth)
          {"status" => "ok", "dom" => dom}.to_json
        when "screenshot"
          path = data["path"]?.try(&.as_s?) || "reports/screenshots/editor.png"
          saved = @driver.take_screenshot(path)
          if saved
            {"status" => "ok", "path" => saved}.to_json
          else
            {"status" => "error", "message" => "Failed to capture screenshot"}.to_json
          end
        when "crop"
          selector = data["selector"]?.try(&.as_s?) || ""
          path = data["path"]?.try(&.as_s?) || "reports/elements/#{selector.gsub(/[^a-z0-9_]/i, "_")}.png"
          if ctrl = @driver.find_control(selector) || @driver.find_button(selector)
            saved = @driver.crop_element(ctrl, path)
            if saved
              {"status" => "ok", "path" => saved, "rect" => ctrl.name}.to_json
            else
              {"status" => "error", "message" => "Failed to crop element '#{selector}'"}.to_json
            end
          else
            {"status" => "error", "message" => "Control not found: '#{selector}'"}.to_json
          end
        when "vision"
          out_dir = data["output_dir"]?.try(&.as_s?) || "reports/ai_vision"
          manifest = @driver.capture_ai_manifest(out_dir)
          {
            "status"          => "ok",
            "manifest_path"   => manifest[:manifest_path],
            "screenshot_path" => manifest[:screenshot_path],
            "element_count"   => manifest[:count],
          }.to_json
        else
          {"status" => "error", "message" => "Unknown action '#{action}'"}.to_json
        end
      rescue ex
        {"status" => "error", "message" => "Exception during command dispatch: #{ex.message}"}.to_json
      end
    end
  end
end
