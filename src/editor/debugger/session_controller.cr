# =============================================================================
# LibGodot - Debugger Session Controller
# =============================================================================
# Bridges a Godot EditorDebuggerSession with an external radare2 driver and UI tab.
# Coordinates breakpoint synchronization, script editor line highlighting,
# live pdc decompilation, and multiplayer lockstep break/resume across peer sessions.

require "../../lapis"
require "../../libgodot/debugger/radare_driver"
require "./debugger_session_tab"

module Godot
  class DebuggerSessionController
    getter session_id : Int32
    getter session : EditorDebuggerSession
    getter driver : Debugger::RadareDriver
    getter tab : CrystalRadareSessionTab? = nil
    getter target_pid : Int64? = nil
    getter role : String = "Peer"
    property lockstep_enabled : Bool = true
    getter active_context : Debugger::ExecutionContext? = nil
    getter rpc_trace_log : Array(String) = [] of String

    # Callback invoked when this session stops or resumes: (origin_session_id, is_paused)
    property on_lockstep_signal : Proc(Int32, Bool, Nil)? = nil

    def initialize(@session_id : Int32, @session : EditorDebuggerSession, r2_path : String = "r2")
      @driver = Debugger::RadareDriver.new(r2_path)
      setup_driver_callbacks
    end

    # Registers an addon for context-aware classification and debugging
    def debug_addon(addon_name : String, binary_name : String? = nil) : Void
      bin_name = binary_name || "#{addon_name}.dll"
      @driver.classifier.register_addon(addon_name, bin_name)
      @tab.try(&.append_console("[Addon Debug] Registered #{addon_name} (#{bin_name}) for context-aware inspection.\n"))
    end

    # Logs a multiplayer RPC event for tracing network activity across sessions
    def log_rpc(sender_id : Int32, method_name : String, args_summary : String = "") : Void
      entry = "[RPC from #{sender_id} -> #{@role} (Session #{@session_id})] #{method_name}(#{args_summary})"
      @rpc_trace_log << entry
      @tab.try(&.append_console("#{entry}\n"))
    end

    # Creates and embeds the session tab into Godot's Debugger bottom dock
    def create_and_add_tab : CrystalRadareSessionTab?
      tab = Godot.create(Godot::CrystalRadareSessionTab)
      return nil unless tab

      tab.setup(@session_id, @role, @driver)

      tab.set_on_command do |cmd|
        @driver.send_command(cmd)
      end

      tab.set_on_frame_select do |frame|
        jump_to_source_frame(frame)
        update_frame_decompilation(frame)
      end

      tab.set_on_lockstep_toggle do |enabled|
        @lockstep_enabled = enabled
      end

      tab.set_on_attach_request do
        if @driver.state == Debugger::DriverState::Detached || @driver.state == Debugger::DriverState::Terminated
          if pid = @target_pid
            attach(pid)
          end
        else
          detach
        end
      end

      @session.add_session_tab(tab)
      @tab = tab
      tab
    rescue ex
      Godot.print("[CrystalDebuggerPlugin] create_and_add_tab exception: #{ex.message}")
      nil
    end

    # Attaches radare2 to the target process ID
    def attach(pid : Int64) : Bool
      @target_pid = pid
      success = @driver.attach(pid)
      if success
        @tab.try(&.update_status("Attached (PID: #{pid})", true, is_paused: true))
        @tab.try(&.append_console("[radare2] Attached successfully to PID #{pid}.\n"))
      else
        @tab.try(&.update_status("Failed to attach", false))
      end
      success
    end

    # Detaches radare2 from the process
    def detach : Void
      @driver.detach
      @tab.try(&.update_status("Detached", false))
      @tab.try(&.append_console("[radare2] Detached from process.\n"))
    end

    # Updates the detected multiplayer role (e.g. Server, Client 1)
    def update_role(role : String, pid : Int64) : Void
      @role = role
      @target_pid = pid
      @tab.try(&.update_role(role, pid))
    end

    # Synchronizes a breakpoint with this session's radare2 instance
    def set_breakpoint(file : String, line : Int32) : Void
      @driver.set_breakpoint(file, line)
      @tab.try(&.append_console("[radare2] Breakpoint added: #{File.basename(file)}:#{line}\n"))
    end

    # Removes a breakpoint from this session's radare2 instance
    def remove_breakpoint(file : String, line : Int32) : Void
      clean_file = file.gsub('\\', '/')
      found_id = -1
      @driver.breakpoints.each do |id, bp|
        if bp.file == clean_file && bp.line == line
          found_id = id
          break
        end
      end

      if found_id > 0
        @driver.remove_breakpoint(found_id)
        @tab.try(&.append_console("[radare2] Breakpoint removed: #{File.basename(file)}:#{line}\n"))
      end
    end

    # Non-blocking per-frame polling hook
    def poll : Void
      @driver.poll
    end

    # Cooperatively pauses this session due to a peer lockstep break event
    def lockstep_pause : Void
      return unless @driver.state == Debugger::DriverState::Running
      @driver.lockstep_paused_externally = true
      @driver.interrupt_exec
      if @driver.attached_pid.nil?
        @driver.state = Debugger::DriverState::Paused
      end
      @tab.try(&.append_console("[Multiplayer Lockstep] Paused peer instance because another instance hit a breakpoint.\n"))
      @tab.try(&.update_status("Paused (Peer Break)", true, is_paused: true))
    end

    # Cooperatively resumes this session when peer resumes
    def lockstep_resume : Void
      return unless @driver.state == Debugger::DriverState::Paused
      @driver.continue_exec
      if @driver.attached_pid.nil?
        @driver.state = Debugger::DriverState::Running
      end
      @tab.try(&.append_console("[Multiplayer Lockstep] Resumed peer instance in lockstep.\n"))
      @tab.try(&.update_status("Running", true, is_paused: false))
    end

    # Highlights the source file and line in Godot's Script Editor
    private def jump_to_source_frame(frame : Debugger::StackFrame) : Void
      return if frame.file.empty? || frame.line <= 0

      res_path = frame.file
      if !res_path.starts_with?("res://") && !Godot::ProjectSettings.singleton_ptr.null?
        ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
        localized = ps.call_str("localize_path", frame.file)
        res_path = localized unless localized.empty?
      end

      if !Godot::EditorInterface.singleton_ptr.null?
        ed_iface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
        res = Godot.load(res_path, "Script")
        if res && !res.pointer.null?
          target_line = (frame.line > 0 ? frame.line - 1 : 0).to_i64
          ed_iface.edit_script(Godot::Script.new(res.pointer), target_line, 0_i64, true)
        end
      end
    rescue
    end

    # Updates the decompiler and disassembly tabs for the selected stack frame
    private def update_frame_decompilation(frame : Debugger::StackFrame) : Void
      return unless decompiler = @driver.decompiler

      addr = if frame.address.starts_with?("0x") || frame.address.starts_with?("0X")
               frame.address[2..].to_u64?(16) || 0_u64
             else
               frame.address.to_u64? || 0_u64
             end

      if addr > 0
        decomp = decompiler.decompile_at(addr)
        disasm = decompiler.disassemble_function(addr)
        @tab.try(&.update_decompiled_code(decomp))
        @tab.try(&.update_disassembly(disasm))
      end
    rescue
    end

    private def setup_driver_callbacks : Void
      @driver.on_stop = ->(info : Debugger::StopInfo) {
        @driver.state = Debugger::DriverState::Paused
        status_label = @driver.lockstep_paused_externally ? "Paused (Peer Break)" : "Paused (#{info.reason})"
        @tab.try(&.update_status(status_label, true, is_paused: true))
        @tab.try(&.append_console("[radare2] #{info.description}\n"))

        if rep = info.crash_report
          @tab.try(&.append_console(rep.summary + "\n"))
        end

        @active_context = info.frame.try(&.context)
        if ctx = @active_context
          @tab.try(&.append_console("#{ctx.badge}\n"))
        end

        if frame = info.frame
          jump_to_source_frame(frame)
          update_frame_decompilation(frame)
          @tab.try(&.update_stack_frames([frame]))
        end

        # Update CPU registers on UI
        if client = @driver.client
          regs = client.debug.registers
          @tab.try(&.update_registers(regs.values))
        end

        # Request full backtrace
        @driver.request_backtrace

        # Notify multiplayer peers only if this was an origin break (not an echo of an external lockstep pause)
        if @lockstep_enabled && !@driver.lockstep_paused_externally
          if cb = @on_lockstep_signal
            cb.call(@session_id, true)
          end
        end
      }

      @driver.on_backtrace = ->(frames : Array(Debugger::StackFrame)) {
        @tab.try(&.update_stack_frames(frames))
      }

      @driver.on_continue = -> {
        @driver.state = Debugger::DriverState::Running
        @tab.try(&.update_status("Running", true, is_paused: false))
        if @lockstep_enabled && !@driver.lockstep_paused_externally
          if cb = @on_lockstep_signal
            cb.call(@session_id, false)
          end
        end
      }

      @driver.on_output = ->(out_text : String) {
        @tab.try(&.append_console(out_text))
      }

      @driver.on_exit = ->(exit_code : Int32) {
        @tab.try(&.update_status("Terminated (Exit: #{exit_code})", false))
        @tab.try(&.append_console("[radare2] Process terminated with exit code #{exit_code}.\n"))
      }
    end

    # Handles remote four-boundary crash notifications from running game
    def handle_remote_fault(message : String) : Void
      parts = message.split(':')
      pc_str = parts[2]? || "0"
      pc = pc_str.starts_with?("0x") ? (pc_str[2..].to_u64?(16) || 0_u64) : (pc_str.to_u64? || 0_u64)
      diag = if client = @driver.client
               mod = client.debug.module_at(pc)
               origin = mod ? Lapis::Debugger::PluginForensics.classify_module(mod.name) : Lapis::Debugger::ModuleOrigin::Unknown
               "Crash fault at 0x#{pc.to_s(16)} in #{mod ? mod.name : "unknown"} [#{origin}]"
             else
               "Crash fault at 0x#{pc.to_s(16)}"
             end
      @tab.try(&.append_console("\n[LAPIS CRASH FORENSICS] #{diag}\n"))
    end

    # Handles remote dead pointer notification
    def handle_remote_dead_pointer(message : String) : Void
      parts = message.split(':')
      id = parts[2]?.try(&.to_u64?) || 0_u64
      cls = parts[3]? || "Node"
      @tab.try(&.append_console("\n[DEAD POINTER HAZARD] Object ##{id} (#{cls}) was freed but accessed by Crystal without #check_alive!\n"))
    end

    # Handles remote stale vtable notification after hot-reload
    def handle_remote_stale_vtable(message : String) : Void
      parts = message.split(':')
      vtable = parts[2]? || "unknown"
      @tab.try(&.append_console("\n[STALE VTABLE RACE] Access to stale vtable #{vtable} in unloaded shadow DLL after reload!\n"))
    end

    # Cleans up active tab and detaches debugger on session end or plugin unload
    def cleanup : Void
      detach rescue nil
      if t = @tab
        if !t.pointer.null? && t.alive?
          @session.remove_session_tab(t) rescue nil
        end
        @tab = nil
      end
      if !@session.pointer.null?
        @session.unreference rescue nil
      end
    end
  end
end
