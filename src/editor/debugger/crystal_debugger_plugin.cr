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
    property auto_attach : Bool = false
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
      CrystalIntegrationPlugin.on_poll = -> {
        if inst = @@instance
          inst.poll
        end
      }
      Bridge.set_debugger_cleanup(cleanup_proc)
    end

    def self.instance : CrystalDebuggerPlugin?
      @@instance
    end

    # Virtual method check for GDExtension dispatch
    def self._godot_has_virtual_method(method_name : String) : Bool
      norm = method_name.starts_with?('_') ? method_name : "_#{method_name}"
      case norm
      when "_capture", "_has_capture", "_setup_session",
           "_breakpoints_cleared_in_tree", "_breakpoint_set_in_tree", "_goto_script_line"
        true
      else
        false
      end
    end

    # Dispatches virtual method calls from Godot engine
    def _godot_call_virtual_with_data(method_name : String, args : Void**, ret : Void*) : Void
      norm = method_name.starts_with?('_') ? method_name : "_#{method_name}"
      case norm
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
        sync_editor_breakpoints rescue nil
        setup_session_controller(sess_id)
      when "_breakpoint_set_in_tree"
        return if args.null?
        script_ptr = Bridge.ref_get_object(args[0])
        if script_ptr.null? && !args[0].null?
          script_ptr = args[0].as(Void**).value rescue Pointer(Void).null
        end
        line = args[1].as(Int32*).value
        enabled = args[2].as(UInt8*).value != 0_u8
        if !script_ptr.null?
          script = Godot::Script.new(script_ptr)
          path = script.call_str("get_path") rescue ""
          handle_breakpoint_toggle(path, line, enabled) unless path.empty?
        end
        sync_editor_breakpoints rescue nil
      when "_breakpoints_cleared_in_tree"
        handle_breakpoints_cleared
      when "_goto_script_line"
        return if args.null?
        script_ptr = Bridge.ref_get_object(args[0])
        if script_ptr.null? && !args[0].null?
          script_ptr = args[0].as(Void**).value rescue Pointer(Void).null
        end
        line = args[1].as(Int32*).value
        if !script_ptr.null?
          script = Godot::Script.new(script_ptr)
          path = script.call_str("get_path") rescue ""
          Godot.print("[CrystalDebuggerPlugin] Navigated to script: #{path}:#{line}")
        end
      end
    end

    # Called whenever Godot creates a new debug session (e.g. Session 0 for Server, Session 1 for Client)
    def setup_session_controller(session_id : Int32) : Void
      sync_editor_breakpoints rescue nil

      session = get_session(session_id.to_i64)
      return if session.pointer.null?

      controller = DebuggerSessionController.new(session_id, session, @lldb_path)
      controller.create_and_add_tab

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
    # Godot's EditorDebuggerNode passes 1-based line numbers (p_row + 1)
    def handle_breakpoint_toggle(res_path : String, line : Int32, enabled : Bool) : Void
      global_file = res_path
      if res_path.starts_with?("res://") && !Godot::ProjectSettings.singleton_ptr.null?
        ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
        global_file = ps.call_str("globalize_path", res_path).gsub('\\', '/')
      end

      clean_path = global_file.gsub('\\', '/')
      lines = @active_breakpoints[clean_path] ||= Set(Int32).new
      lldb_line = line > 0 ? line : 1

      if enabled
        lines.add(lldb_line)
        @sessions.each_value do |ctrl|
          ctrl.set_breakpoint(clean_path, lldb_line)
        end
        Godot.print("[CrystalDebuggerPlugin] Breakpoint set: #{File.basename(clean_path)}:#{lldb_line}")
      else
        lines.delete(lldb_line)
        @sessions.each_value do |ctrl|
          ctrl.remove_breakpoint(clean_path, lldb_line)
        end
        Godot.print("[CrystalDebuggerPlugin] Breakpoint cleared: #{File.basename(clean_path)}:#{lldb_line}")
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

    @poll_counter : Int32 = 0

    # Polling hook called from plugin _process
    def poll : Void
      @sessions.each_value(&.poll)

      @poll_counter += 1
      if @poll_counter >= 30
        @poll_counter = 0
        sync_editor_breakpoints rescue nil
      end
    end

    # Harmonizes breakpoints between Godot's ScriptEditor/CodeEdit and LLDB active breakpoints
    def sync_editor_breakpoints : Void
      return if Godot::EditorInterface.singleton_ptr.null?
      ed_interface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
      script_ed = ed_interface.get_script_editor rescue nil
      return if script_ed.nil? || script_ed.pointer.null?

      found_bps = Hash(String, Set(Int32)).new

      # 1. Query ScriptEditor get_breakpoints
      raw_bps = script_ed.call_str("get_breakpoints") rescue ""
      if !raw_bps.empty? && raw_bps != "[]"
        clean_raw = raw_bps.strip.lchop('[').rchop(']')
        clean_raw.split(',').each do |item|
          token = item.strip.strip('"').strip('\'')
          next if token.empty?
          if r_idx = token.rindex(':')
            res_path = token[0...r_idx].strip
            if l = token[(r_idx + 1)..-1].to_i?
              clean_path = globalize_res_path(res_path)
              # In Godot ScriptEditor::get_breakpoints(), lines are 0-based row indices from CodeEdit
              # Convert to 1-based line number for LLDB
              (found_bps[clean_path] ||= Set(Int32).new).add(l + 1)
            end
          end
        end
      end

      # 2. Directly inspect open script editor tabs (CodeEdit controls)
      begin
        current_ed = script_ed.call_obj("get_current_editor") rescue nil
        if current_ed && !current_ed.pointer.null?
          script_res = current_ed.call_obj("get_edited_resource") rescue nil
          if script_res && !script_res.pointer.null?
            res_path = script_res.call_str("get_path") rescue ""
            if !res_path.empty?
              base_ed = current_ed.call_obj("get_base_editor") rescue nil
              if base_ed && !base_ed.pointer.null?
                lines_str = base_ed.call_str("get_breakpointed_lines") rescue ""
                clean_path = globalize_res_path(res_path)
                lines_str.scan(/\d+/).each do |match|
                  if line_0 = match[0].to_i?
                    # CodeEdit is 0-based; convert to 1-based for LLDB
                    (found_bps[clean_path] ||= Set(Int32).new).add(line_0 + 1)
                  end
                end
              end
            end
          end
        end
      rescue
      end

      # 3. Read cached breakpoints from .godot/editor/script_editor_cache.cfg if present
      begin
        cache_file = ".godot/editor/script_editor_cache.cfg"
        if File.exists?(cache_file)
          curr_sec = ""
          File.each_line(cache_file) do |cline|
            sline = cline.strip
            if sline.starts_with?('[') && sline.ends_with?(']')
              curr_sec = sline[1...-1]
            elsif curr_sec.starts_with?("res://") && sline.includes?("\"breakpoints\":")
              clean_path = globalize_res_path(curr_sec)
              sline.scan(/\d+/).each do |match|
                if l0 = match[0].to_i?
                  (found_bps[clean_path] ||= Set(Int32).new).add(l0 + 1)
                end
              end
            end
          end
        end
      rescue
      end

      # Add newly discovered breakpoints
      found_bps.each do |path, lines|
        existing = @active_breakpoints[path] ||= Set(Int32).new
        lines.each do |line|
          unless existing.includes?(line)
            existing.add(line)
            @sessions.each_value do |ctrl|
              ctrl.set_breakpoint(path, line)
            end
            Godot.print("[CrystalDebuggerPlugin] Synced editor breakpoint: #{File.basename(path)}:#{line}")
          end
        end
      end

      # Remove cleared breakpoints
      @active_breakpoints.each do |path, existing|
        found = found_bps[path]? || Set(Int32).new
        to_remove = existing - found
        to_remove.each do |line|
          existing.delete(line)
          @sessions.each_value do |ctrl|
            ctrl.remove_breakpoint(path, line)
          end
          Godot.print("[CrystalDebuggerPlugin] Cleared editor breakpoint: #{File.basename(path)}:#{line}")
        end
      end
    end

    private def globalize_res_path(res_path : String) : String
      clean = res_path.gsub('\\', '/')
      if clean.starts_with?("res://") && !Godot::ProjectSettings.singleton_ptr.null?
        ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
        glob = ps.call_str("globalize_path", clean)
        return glob.gsub('\\', '/') unless glob.empty?
      end
      clean
    end

    # Cleans up all active debugger sessions and resets singleton
    def cleanup : Void
      CrystalIntegrationPlugin.on_poll = nil
      @sessions.each_value do |ctrl|
        ctrl.cleanup rescue nil
      end
      @sessions.clear
      @active_breakpoints.clear
      @@instance = nil
    end
  end
end
