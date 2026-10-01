# =============================================================================
# LibGodot - radare2 Native Debugger Driver
# =============================================================================
# High-performance native debugger driver wrapping cradare2 and radare2.
# Manages process attachment, source-line DWARF/PDB breakpoints, execution controls,
# worker thread event loops, multiplayer lockstep coordination, and crash forensics.

require "cradare2"
require "signal"
require "./decompiler"
require "./plugin_forensics"
require "./context_classifier"

module Godot
end

module Lapis
  include Godot

  {% if flag?(:windows) %}
    lib LibKernel32
      fun DebugBreakProcess(process : Void*) : Int32
      fun OpenProcess(desired_access : UInt32, inherit_handle : Int32, process_id : UInt32) : Void*
      fun CloseHandle(object : Void*) : Int32
    end
  {% end %}

  module Debugger
    enum StopReason
      Breakpoint
      Signal
      Step
      Exception
      UserInterrupt
      Exited
      Unknown
    end

    class StackFrame
      property index : Int32
      property function : String
      property file : String
      property line : Int32
      property address : String
      property module_name : String
      property context : ExecutionContext?

      def initialize(
        @index : Int32,
        @function : String,
        @file : String,
        @line : Int32,
        @address : String = "",
        @module_name : String = "",
        @context : ExecutionContext? = nil
      )
      end

      def to_s : String
        f = @file.empty? ? "unknown" : @file
        l = @line > 0 ? ":#{@line}" : ""
        ctx_badge = @context ? " #{@context.not_nil!.badge}" : ""
        "#{@index}: #{@function} at #{f}#{l}#{ctx_badge}"
      end
    end

    class BreakpointInfo
      property id : Int32
      property file : String
      property line : Int32
      property hit_count : Int32
      property enabled : Bool
      property resolved : Bool
      property address : UInt64

      def initialize(
        @id : Int32,
        @file : String,
        @line : Int32,
        @hit_count : Int32 = 0,
        @enabled : Bool = true,
        @resolved : Bool = false,
        @address : UInt64 = 0_u64,
      )
      end
    end

    class VariableInfo
      property name : String
      property type_name : String
      property value : String

      def initialize(@name : String, @type_name : String, @value : String)
      end
    end

    class StopInfo
      property reason : StopReason
      property thread_id : Int32
      property frame : StackFrame?
      property description : String
      property crash_report : CrashReport?

      def initialize(
        @reason : StopReason,
        @thread_id : Int32 = 1,
        @frame : StackFrame? = nil,
        @description : String = "",
        @crash_report : CrashReport? = nil,
      )
      end
    end

    enum DriverState
      Detached
      Attaching
      Running
      Paused
      Terminated
    end

    class RadareDriver
      property state : DriverState = DriverState::Detached
      getter attached_pid : Int64? = nil
      getter breakpoints : Hash(Int32, BreakpointInfo) = Hash(Int32, BreakpointInfo).new
      getter client : Cradare2::Client? = nil
      getter decompiler : Decompiler? = nil

      property on_stop : Proc(StopInfo, Nil)? = nil
      property on_continue : Proc(Nil)? = nil
      property on_output : Proc(String, Nil)? = nil
      property on_exit : Proc(Int32, Nil)? = nil
      property on_backtrace : Proc(Array(StackFrame), Nil)? = nil

      # Indicates whether the current pause was triggered by a cooperative peer lockstep break
      property lockstep_paused_externally : Bool = false

      getter classifier : ContextClassifier = ContextClassifier.new

      @worker_thread : ::Thread? = nil
      @event_channel : ::Channel(StopInfo) = ::Channel(StopInfo).new(64)
      @mutex : ::Thread::Mutex = ::Thread::Mutex.new
      @r2_path : String = "r2"
      @pending_stop_reason : StopReason? = nil
      @collecting_backtrace : Bool = false
      @backtrace_frames : Array(StackFrame) = [] of StackFrame

      def initialize(r2_path : String = "r2")
        @r2_path = r2_path
      end

      # Discovers radare2 executable path on system
      def self.find_radare2(custom_path : String? = nil) : String?
        Cradare2::Util::Locator.find_r2(custom_path) rescue nil
      end

      # Returns true if radare2 is installed and functional
      def self.available?(custom_path : String? = nil) : Bool
        !find_radare2(custom_path).nil?
      end

      # Spawns radare2 session and attaches to target process ID
      def attach(pid : Int64) : Bool
        return false if @state != DriverState::Detached && @state != DriverState::Terminated

        @state = DriverState::Attaching
        @attached_pid = pid

        begin
          # Open radare2 with process attachment
          # Transport attaches to target process PID in debug mode
          transport = Cradare2::Transport::ProcessTransport.new(
            target: "",
            flags: ["-p", pid.to_s],
            debug: true,
            write: true,
            r2_path: @r2_path
          )

          c = Cradare2::Client.new(transport)
          @client = c
          @decompiler = Decompiler.new(c)

          # Auto-load Windows PDB symbols if present
          {% if flag?(:windows) %}
            c.cmd(".idpi*") rescue nil
          {% end %}

          # Synchronize queued breakpoints
          sync_all_breakpoints

          @state = DriverState::Paused
          if cb = @on_output
            cb.call("[radare2] Attached successfully to PID #{pid}.\n")
          end

          # Initial attach notification: process begins paused by debugger
          frame = current_stack_frame
          stop_info = StopInfo.new(
            reason: StopReason::Breakpoint,
            thread_id: 1,
            frame: frame,
            description: "Process attached (PID #{pid})"
          )
          @event_channel.send(stop_info) rescue nil

          true
        rescue ex
          @state = DriverState::Detached
          @attached_pid = nil
          @client = nil
          @decompiler = nil
          if cb = @on_output
            cb.call("[radare2 Error] Failed to attach to PID #{pid}: #{ex.message}\n")
          end
          false
        end
      end

      # Detaches radare2 cleanly
      def detach : Void
        return if @state == DriverState::Detached

        if @state == DriverState::Running
          interrupt_exec
        end

        if c = @client
          c.debug.detach rescue nil
          c.close rescue nil
        end

        @client = nil
        @decompiler = nil
        @state = DriverState::Detached
        @attached_pid = nil
        @lockstep_paused_externally = false

        if cb = @on_output
          cb.call("[radare2] Detached from process.\n")
        end
      end

      # Synchronizes all cached breakpoints to the active radare2 process
      def sync_all_breakpoints : Void
        c = @client
        return unless c && !c.closed?

        @mutex.synchronize do
          @breakpoints.each_value do |bp|
            if bp.enabled && bp.line > 0
              base_name = File.basename(bp.file)
              c.cmd("dbl #{base_name}:#{bp.line}") rescue nil
              bp.resolved = true
            end
          end
        end
      end

      # Sets a breakpoint at the given file and line
      def set_breakpoint(file : String, line : Int32) : BreakpointInfo
        clean_file = file.gsub('\\', '/')

        existing = @mutex.synchronize do
          @breakpoints.values.find { |b| b.file == clean_file && b.line == line }
        end
        return existing if existing

        if line > 0 && (c = @client) && !c.closed? && @state != DriverState::Attaching
          base_name = File.basename(clean_file)
          c.cmd("dbl #{base_name}:#{line}") rescue nil
        end

        id = @breakpoints.size + 1
        bp = BreakpointInfo.new(id, clean_file, line, enabled: true, resolved: true)
        @mutex.synchronize do
          @breakpoints[id] = bp
        end
        bp
      end

      # Removes a breakpoint by ID
      def remove_breakpoint(id : Int32) : Bool
        target_bp = @mutex.synchronize { @breakpoints.delete(id) }
        return false unless target_bp

        if (c = @client) && !c.closed?
          base_name = File.basename(target_bp.file)
          c.cmd("db- #{base_name}:#{target_bp.line}") rescue nil
        end
        true
      end

      # Removes a breakpoint by file and line
      def remove_breakpoint(file : String, line : Int32) : Bool
        clean_file = file.gsub('\\', '/')
        target_id : Int32? = nil
        @mutex.synchronize do
          @breakpoints.each do |id, bp|
            if bp.file == clean_file && bp.line == line
              target_id = id
              break
            end
          end
        end

        if tid = target_id
          remove_breakpoint(tid)
        else
          false
        end
      end

      # Resumes execution in the target process asynchronously via worker thread
      def continue_exec : Void
        return unless @state == DriverState::Paused

        @state = DriverState::Running
        @lockstep_paused_externally = false

        if cb = @on_continue
          cb.call
        end

        c = @client
        return unless c && !c.closed?

        # Launch blocking 'dc' in background worker thread
        @worker_thread = ::Thread.new do
          begin
            # Continues execution until breakpoint, signal, or process exit
            c.debug.continue rescue c.cmd("dc")

            # Execution stopped - parse registers and state
            info = parse_current_stop_state
            @event_channel.send(info) rescue nil
          rescue ex
            # Process terminated or session closed
            if @state != DriverState::Detached
              @state = DriverState::Terminated
            end
          end
        end
      end

      # Interrupts/pauses the target process
      def interrupt_exec : Void
        return unless @state == DriverState::Running
        pid = @attached_pid
        return unless pid

        {% if flag?(:windows) %}
          handle = LibKernel32.OpenProcess(0x1F0FFF_u32, 0, pid.to_u32)
          if handle && !handle.null?
            LibKernel32.DebugBreakProcess(handle)
            LibKernel32.CloseHandle(handle)
          end
        {% else %}
          Process.signal(::Signal::INT, pid.to_i) rescue nil
        {% end %}
      end

      # Single instruction step
      def step_instruction : Void
        return unless @state == DriverState::Paused
        c = @client
        if c && !c.closed?
          c.debug.step rescue c.cmd("ds")
          info = parse_current_stop_state(StopReason::Step)
          @event_channel.send(info) rescue nil
        end
      end

      # Step over source call
      def step_over : Void
        return unless @state == DriverState::Paused
        c = @client
        if c && !c.closed?
          c.debug.step_over rescue c.cmd("dso")
          info = parse_current_stop_state(StopReason::Step)
          @event_channel.send(info) rescue nil
        end
      end

      # Step into source call
      def step_into : Void
        return unless @state == DriverState::Paused
        c = @client
        if c && !c.closed?
          c.debug.step rescue c.cmd("ds")
          info = parse_current_stop_state(StopReason::Step)
          @event_channel.send(info) rescue nil
        end
      end

      # Step out of current function
      def step_out : Void
        return unless @state == DriverState::Paused
        c = @client
        if c && !c.closed?
          c.cmd("dsu") rescue (c.debug.step_over rescue c.cmd("dso"))
          info = parse_current_stop_state(StopReason::Step)
          @event_channel.send(info) rescue nil
        end
      end

      # Evaluates an expression in radare2
      def evaluate(expr : String) : String
        c = @client
        return "" unless c && !c.closed?
        c.cmd("?v #{expr}").strip rescue ""
      end

      # Requests local variables for active frame
      def request_variables(frame_index : Int32 = 0) : Array(VariableInfo)
        c = @client
        return [] of VariableInfo unless c && !c.closed?

        vars = [] of VariableInfo
        output = c.cmd("afvd") rescue ""
        output.each_line do |line|
          line = line.strip
          next if line.empty?
          if m = line.match(/^([a-zA-Z0-9_]+)\s*:\s*([^\s=]+)\s*=\s*(.*)$/)
            vars << VariableInfo.new(m[1], m[2], m[3])
          elsif m = line.match(/^([a-zA-Z0-9_]+)\s*=\s*(.*)$/)
            vars << VariableInfo.new(m[1], "unknown", m[2])
          end
        end
        vars
      end

      # Requests call stack frames and dispatches on_backtrace
      def request_backtrace : Void
        c = @client
        if c && !c.closed?
          frames = current_backtrace
          if cb = @on_backtrace
            cb.call(frames)
          end
        else
          @collecting_backtrace = true
          @backtrace_frames.clear
        end
      end

      # Sends an interactive raw command string to radare2
      def send_command(command : String) : String
        c = @client
        return "" unless c && !c.closed?
        res = c.cmd(command)
        if cb = @on_output
          cb.call(res + "\n")
        end
        res
      rescue ex
        "[Error] #{ex.message}"
      end

      # Pumps background events non-blockingly on the Godot main thread
      def poll : Void
        Fiber.yield

        loop do
          select
          when stop = @event_channel.receive?
            if stop
              @state = DriverState::Paused
              if cb = @on_stop
                cb.call(stop)
              end
            else
              break
            end
          else
            break
          end
        end

        if c = @client
          if c.closed? && @state != DriverState::Terminated && @state != DriverState::Detached
            @state = DriverState::Terminated
            if cb = @on_exit
              cb.call(0)
            end
          end
        end
      end

      # Parses stop event string for mock testing
      def parse_stop_info(line : String) : StopInfo
        reason = parse_stop_reason(line)
        frame = parse_frame_line(line)
        StopInfo.new(reason: reason, thread_id: 1, frame: frame, description: line)
      end

      # Processes streaming raw text line for headless testing or mock events
      def process_line(line : String) : Void
        return if line.blank?

        # Filter Windows SEH probe and debugger artifacts
        if line.includes?("DbgBreakPoint") || line.includes?("DbgUiRemoteBreakin")
          return
        end
        if line.includes?("0xc00000fd") || line.includes?("0xC00000FD")
          return
        end
        if line.includes?("Exception 0x80000003")
          return
        end

        if line.includes?("stopped")
          @state = DriverState::Paused
        elsif line.includes?("resuming")
          @state = DriverState::Running
          if cb = @on_continue
            cb.call
          end
          return
        end

        # If collecting backtrace
        if @collecting_backtrace
          if line.includes?("frame #")
            if f = parse_frame_line(line)
              @backtrace_frames << f
            end
            return
          elsif line.includes?("[0x") || line.includes?(">") || line.strip == ""
            @collecting_backtrace = false
            if cb = @on_backtrace
              cb.call(@backtrace_frames.dup)
            end
            return
          end
        end

        # If a frame line arrives and we have a pending stop reason
        if line.includes?("frame #")
          frame = parse_frame_line(line)
          reason = @pending_stop_reason || StopReason::Breakpoint
          @pending_stop_reason = nil
          @state = DriverState::Paused
          info = StopInfo.new(reason: reason, thread_id: 1, frame: frame, description: line)
          if cb = @on_stop
            cb.call(info)
          end
          return
        end

        reason = parse_stop_reason(line)
        if reason != StopReason::Unknown
          # Check if inline frame info exists on same line
          if line.includes?("frame #")
            frame = parse_frame_line(line)
            @state = DriverState::Paused
            info = StopInfo.new(reason: reason, thread_id: 1, frame: frame, description: line)
            if cb = @on_stop
              cb.call(info)
            end
          else
            # Wait for subsequent frame line
            @pending_stop_reason = reason
          end
        end
      end

      def parse_stop_reason(line : String) : StopReason
        lowered = line.downcase
        if lowered.includes?("breakpoint")
          StopReason::Breakpoint
        elsif lowered.includes?("signal") || lowered.includes?("sig") || lowered.includes?("exception")
          StopReason::Signal
        elsif lowered.includes?("step")
          StopReason::Step
        elsif lowered.includes?("interrupt")
          StopReason::UserInterrupt
        else
          StopReason::Unknown
        end
      end

      def parse_frame_line(line : String) : StackFrame?
        return nil unless line.includes?("frame #")

        idx = 0
        fn = "unknown"
        file = ""
        line_num = 0
        addr = ""

        if match = line.match(/frame #(\d+):\s*(0x[0-9a-fA-F]+)?\s*([^\s]+)(.*)/)
          idx = match[1].to_i32 rescue 0
          addr = match[2]? || ""
          fn = match[3]
          rest = match[4]? || ""

          if at_match = rest.match(/at\s+(.+?):(\d+)(?::\d+)?(?:\s*$|\s+\[)/)
            file = at_match[1].strip.gsub('\\', '/')
            line_num = at_match[2].to_i32 rescue 0
          elsif at_match = rest.match(/at\s+([^:\r\n]+):(\d+)/)
            file = at_match[1].strip.gsub('\\', '/')
            line_num = at_match[2].to_i32 rescue 0
          end
        end

        ctx = @classifier.classify(file, fn, "")
        StackFrame.new(idx, fn, file, line_num, addr, module_name: "", context: ctx)
      end

      # Queries radare2 state to construct current StopInfo
      private def parse_current_stop_state(explicit_reason : StopReason? = nil) : StopInfo
        c = @client
        unless c
          return StopInfo.new(reason: StopReason::Unknown)
        end

        regs = c.debug.registers
        pc = regs.pc
        frame = current_stack_frame

        reason = explicit_reason || StopReason::Breakpoint
        report : CrashReport? = nil

        # If faulting PC indicates crash / exception
        if pc < 0x1000 || c.cmd("d?").includes?("exception") || c.cmd("d?").includes?("signal")
          reason = StopReason::Exception
          report = PluginForensics.diagnose_crash(c) rescue nil
        end

        desc = "Stopped at 0x#{pc.to_s(16)}"
        if f = frame
          desc += " in #{f.function} (#{File.basename(f.file)}:#{f.line})"
        end

        StopInfo.new(
          reason: reason,
          thread_id: 1,
          frame: frame,
          description: desc,
          crash_report: report
        )
      end

      private def current_stack_frame : StackFrame?
        c = @client
        return nil unless c

        regs = c.debug.registers
        pc = regs.pc
        return nil if pc == 0

        # Query code line info for PC
        line_info = c.cmd("CL. @ 0x#{pc.to_s(16)}").strip rescue ""
        file_path = ""
        line_num = 0

        if m = line_info.match(/([^\s:]+):(\d+)/)
          file_path = m[1].gsub('\\', '/')
          line_num = m[2].to_i32 rescue 0
        end

        fn_name = c.cmd("fd @ 0x#{pc.to_s(16)}").strip rescue "0x#{pc.to_s(16)}"
        demangled = Cradare2::Util::Demangler.demangle(fn_name, c.transport)

        mod = c.debug.module_at(pc) rescue nil
        mod_name = mod ? mod.name : ""
        ctx = @classifier.classify(file_path, demangled, mod_name, pc)

        StackFrame.new(0, demangled, file_path, line_num, "0x#{pc.to_s(16)}", module_name: mod_name, context: ctx)
      end

      private def current_backtrace : Array(StackFrame)
        c = @client
        return [] of StackFrame unless c

        frames = [] of StackFrame
        r2_bt = c.crystal.demangled_backtrace rescue [] of Cradare2::Model::StackFrame

        r2_bt.each_with_index do |f, idx|
          line_info = c.cmd("CL. @ 0x#{f.address.to_s(16)}").strip rescue ""
          file_path = ""
          line_num = 0

          if m = line_info.match(/([^\s:]+):(\d+)/)
            file_path = m[1].gsub('\\', '/')
            line_num = m[2].to_i32 rescue 0
          end

          mod = c.debug.module_at(f.address) rescue nil
          mod_name = mod ? mod.name : ""
          fn = f.function_name || "unknown"
          ctx = @classifier.classify(file_path, fn, mod_name, f.address)

          frames << StackFrame.new(
            index: idx,
            function: fn,
            file: file_path,
            line: line_num,
            address: "0x#{f.address.to_s(16)}",
            module_name: mod_name,
            context: ctx
          )
        end

        frames
      end
    end
  end
end

module Godot
  {% unless Godot.has_constant?(:Debugger) %}
    alias Debugger = ::Lapis::Debugger
  {% end %}
end
