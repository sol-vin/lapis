# =============================================================================
# LibGodot - Debugger Session Controller
# =============================================================================
# Bridges a Godot EditorDebuggerSession with an external LLDB driver and UI tab.
# Coordinates breakpoint synchronization, script editor line highlighting,
# and multiplayer lockstep break/resume across peer sessions.

require "../../lapis"
require "../../libgodot/debugger/lldb_driver"
require "./debugger_session_tab"

module Godot
  class DebuggerSessionController
    getter session_id : Int32
    getter session : EditorDebuggerSession
    getter driver : Debugger::LldbDriver
    getter tab : CrystalLldbSessionTab? = nil
    getter target_pid : Int64? = nil
    getter role : String = "Peer"
    property lockstep_enabled : Bool = true

    # Callback invoked when this session stops or resumes: (origin_session_id, is_paused)
    property on_lockstep_signal : Proc(Int32, Bool, Nil)? = nil

    def initialize(@session_id : Int32, @session : EditorDebuggerSession, lldb_path : String = "lldb")
      @driver = Debugger::LldbDriver.new(lldb_path)
      setup_driver_callbacks
    end

    # Creates and embeds the session tab into Godot's Debugger bottom dock
    def create_and_add_tab : CrystalLldbSessionTab?
      tab = Godot.create(Godot::CrystalLldbSessionTab)
      return nil unless tab

      tab.setup(@session_id, @role, @driver)

      tab.set_on_command do |cmd|
        @driver.send_command(cmd)
      end

      tab.set_on_frame_select do |frame|
        jump_to_source_frame(frame)
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

    # Attaches LLDB to the target process ID
    def attach(pid : Int64) : Bool
      @target_pid = pid
      success = @driver.attach(pid)
      if success
        @tab.try(&.update_status("Attached (PID: #{pid})", true, is_paused: true))
        @tab.try(&.append_console("[LLDB] Attached successfully to PID #{pid}.\n"))
      else
        @tab.try(&.update_status("Failed to attach", false))
      end
      success
    end

    # Detaches LLDB from the process
    def detach : Void
      @driver.detach
      @tab.try(&.update_status("Detached", false))
      @tab.try(&.append_console("[LLDB] Detached from process.\n"))
    end

    # Updates the detected multiplayer role (e.g. Server, Client 1)
    def update_role(role : String, pid : Int64) : Void
      @role = role
      @target_pid = pid
      @tab.try(&.update_role(role, pid))
    end

    # Synchronizes a breakpoint with this session's LLDB instance
    def set_breakpoint(file : String, line : Int32) : Void
      @driver.set_breakpoint(file, line)
      @tab.try(&.append_console("[LLDB] Breakpoint added: #{File.basename(file)}:#{line}\n"))
    end

    # Removes a breakpoint from this session's LLDB instance
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
        @tab.try(&.append_console("[LLDB] Breakpoint removed: #{File.basename(file)}:#{line}\n"))
      end
    end

    # Non-blocking per-frame polling hook
    def poll : Void
      @driver.poll
    end

    # Cooperatively pauses this session due to a peer lockstep break event
    def lockstep_pause : Void
      return unless @driver.state == Debugger::DriverState::Running
      @driver.interrupt_exec
      @tab.try(&.append_console("[Multiplayer Lockstep] Paused peer instance because another instance hit a breakpoint.\n"))
      @tab.try(&.update_status("Paused (Peer Break)", true, is_paused: true))
    end

    # Cooperatively resumes this session when peer resumes
    def lockstep_resume : Void
      return unless @driver.state == Debugger::DriverState::Paused
      @driver.continue_exec
      @tab.try(&.append_console("[Multiplayer Lockstep] Resumed peer instance.\n"))
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
        se = ed_iface.get_script_editor
        if !se.pointer.null?
          res = Godot.load(res_path, "Script")
          if res && !res.pointer.null?
            se.call("goto_line", frame.line - 1)
          end
        end
      end
    rescue
    end

    private def setup_driver_callbacks : Void
      @driver.on_stop = ->(info : Debugger::StopInfo) {
        @tab.try(&.update_status("Paused (#{info.reason})", true, is_paused: true))
        @tab.try(&.append_console("[LLDB] Stopped: #{info.description}\n"))

        if frame = info.frame
          jump_to_source_frame(frame)
          @tab.try(&.update_stack_frames([frame]))
        end

        # Request full backtrace
        @driver.request_backtrace

        # Notify multiplayer peers if lockstep is enabled
        if @lockstep_enabled
          if cb = @on_lockstep_signal
            cb.call(@session_id, true)
          end
        end
      }

      @driver.on_continue = -> {
        @tab.try(&.update_status("Running", true, is_paused: false))
        if @lockstep_enabled
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
        @tab.try(&.append_console("[LLDB] Process terminated with exit code #{exit_code}.\n"))
      }
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
