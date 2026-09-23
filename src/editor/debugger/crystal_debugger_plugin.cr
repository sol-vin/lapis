# =============================================================================
# LibGodot - Crystal Editor Debugger Plugin
# =============================================================================
# Native EditorDebuggerPlugin registered into Godot's ClassDB.
# Captures breakpoints set in Godot's Script Editor gutter, attaches LLDB
# sessions to running child instances, manages multi-session tabs for multiplayer,
# and enforces lockstep pause/continue across peer instances.

require "../../lapis"
require "./session_controller"

module Godot
  @[Tool]
  node CrystalDebuggerPlugin < EditorDebuggerPlugin do
    property auto_attach : Bool = true
    property lldb_path : String = "lldb"
  end

  class CrystalDebuggerPlugin
    @@instance : CrystalDebuggerPlugin? = nil

    getter sessions : Hash(Int32, DebuggerSessionController) = Hash(Int32, DebuggerSessionController).new
    getter active_breakpoints : Hash(String, Set(Int32)) = Hash(String, Set(Int32)).new

    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
      @@instance = self
      cleanup_proc = -> {
        if inst = @@instance
          inst.cleanup rescue nil
        end
      }
      CrystalIntegrationPlugin.on_cleanup = cleanup_proc
      Bridge.set_debugger_cleanup(cleanup_proc)
    end

    def self.instance : CrystalDebuggerPlugin?
      @@instance
    end

    # Virtual method check for GDExtension dispatch
    def self._godot_has_virtual_method(method_name : String) : Bool
      case method_name
      when "_capture", "_has_capture", "_setup_session",
           "_breakpoints_cleared_in_tree", "_breakpoint_set_in_tree", "_goto_script_line"
        true
      else
        false
      end
    end

    # Dispatches virtual method calls from Godot engine
    def _godot_call_virtual_with_data(method_name : String, args : Void**, ret : Void*) : Void
      case method_name
      when "_has_capture"
        return if ret.null? || args.null? || args[0].null?
        cap = Bridge.arg_to_string(args[0])
        ret.as(UInt8*).value = (cap == "crystal_debugger") ? 1_u8 : 0_u8
      when "_capture"
        return if ret.null? || args.null?
        msg = Bridge.arg_to_string(args[0])
        sess_id = args[2].as(Int32*).value
        handled = handle_capture(msg, sess_id)
        ret.as(UInt8*).value = handled ? 1_u8 : 0_u8
      when "_setup_session"
        return if args.null? || args[0].null?
        sess_id = args[0].as(Int32*).value
        setup_session_controller(sess_id)
      when "_breakpoint_set_in_tree"
        return if args.null?
        script_ptr = args[0]
        line = args[1].as(Int32*).value
        enabled = args[2].as(UInt8*).value != 0_u8
        if !script_ptr.null?
          script = Godot::Script.new(script_ptr.as(Void**).value)
          path = script.call_str("get_path")
          handle_breakpoint_toggle(path, line, enabled)
        end
      when "_breakpoints_cleared_in_tree"
        handle_breakpoints_cleared
      when "_goto_script_line"
        return if args.null?
        script_ptr = args[0]
        line = args[1].as(Int32*).value
        if !script_ptr.null?
          script = Godot::Script.new(script_ptr.as(Void**).value)
          path = script.call_str("get_path")
          Godot.print("[CrystalDebuggerPlugin] Navigated to script: #{path}:#{line}")
        end
      end
    end

    # Called whenever Godot creates a new debug session (e.g. Session 0 for Server, Session 1 for Client)
    def setup_session_controller(session_id : Int32) : Void
      session = get_session(session_id.to_i64)
      return if session.pointer.null?

      controller = DebuggerSessionController.new(session_id, session, @lldb_path)
      # controller.create_and_add_tab

      # Setup lockstep multiplayer callback:
      # If any instance hits a breakpoint, pause all other multiplayer instances
      controller.on_lockstep_signal = ->(origin_id : Int32, is_paused : Bool) {
        @sessions.each do |sid, peer_ctrl|
          next if sid == origin_id
          if is_paused
            peer_ctrl.lockstep_pause
          else
            peer_ctrl.lockstep_resume
          end
        end
      }

      # Push existing project breakpoints to this new session
      @active_breakpoints.each do |file, lines|
        lines.each do |line|
          controller.set_breakpoint(file, line)
        end
      end

      # Hook session stopped signal to clean up
      session.connect("stopped") do |_args|
        if ctrl = @sessions[session_id]?
          ctrl.detach
        end
      end

      @sessions[session_id] = controller
      Godot.print("[CrystalDebuggerPlugin] Initialized LLDB Debugger Session #{session_id}")
    end

    # Handles incoming TCP messages from running game instances
    def handle_capture(message : String, session_id : Int32) : Bool
      if message.starts_with?("crystal_debugger:ready:")
        parts = message.split(':')
        pid = parts[2]?.try(&.to_i64?) || 0_i64
        role = parts[3]? || "Instance"

        if ctrl = @sessions[session_id]?
          ctrl.update_role(role, pid)
          if @auto_attach && pid > 0
            ctrl.attach(pid)
          end
        end
        return true
      elsif message.starts_with?("crystal_debugger:role:")
        parts = message.split(':')
        pid = parts[2]?.try(&.to_i64?) || 0_i64
        role = parts[3]? || "Instance"

        if ctrl = @sessions[session_id]?
          ctrl.update_role(role, pid)
        end
        return true
      end
      false
    end

    # Handles gutter breakpoint click events from Godot's Script Editor
    def handle_breakpoint_toggle(res_path : String, line : Int32, enabled : Bool) : Void
      global_file = res_path
      if res_path.starts_with?("res://") && !Godot::ProjectSettings.singleton_ptr.null?
        ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
        global_file = ps.call_str("globalize_path", res_path).gsub('\\', '/')
      end

      clean_path = global_file.gsub('\\', '/')
      lines = @active_breakpoints[clean_path] ||= Set(Int32).new

      if enabled
        lines.add(line)
        @sessions.each_value do |ctrl|
          ctrl.set_breakpoint(clean_path, line)
        end
        Godot.print("[CrystalDebuggerPlugin] Breakpoint set: #{File.basename(clean_path)}:#{line}")
      else
        lines.delete(line)
        @sessions.each_value do |ctrl|
          ctrl.remove_breakpoint(clean_path, line)
        end
        Godot.print("[CrystalDebuggerPlugin] Breakpoint cleared: #{File.basename(clean_path)}:#{line}")
      end
    end

    # Clears all breakpoints across all active sessions
    def handle_breakpoints_cleared : Void
      @active_breakpoints.each do |file, lines|
        lines.each do |line|
          @sessions.each_value do |ctrl|
            ctrl.remove_breakpoint(file, line)
          end
        end
      end
      @active_breakpoints.clear
      Godot.print("[CrystalDebuggerPlugin] All native breakpoints cleared.")
    end

    # Polling hook called from plugin _process
    def poll : Void
      @sessions.each_value(&.poll)
    end

    # Cleans up all active debugger sessions and resets singleton
    def cleanup : Void
      @sessions.each_value do |ctrl|
        ctrl.cleanup rescue nil
      end
      @sessions.clear
      @active_breakpoints.clear
      @@instance = nil
    end
  end
end
