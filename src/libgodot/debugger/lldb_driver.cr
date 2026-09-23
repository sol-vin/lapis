# =============================================================================
# LibGodot - LLDB Native Debugger Driver
# =============================================================================
# Controls an external LLDB debugger process via piped stdio.
# Handles process attachment, breakpoint synchronization, call stack extraction,
# variable inspection, and asynchronous stop event parsing.

module Lapis
  include Godot

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

    struct StackFrame
      property index : Int32
      property function : String
      property file : String
      property line : Int32
      property address : String

      def initialize(@index : Int32, @function : String, @file : String, @line : Int32, @address : String = "")
      end

      def to_s : String
        f = @file.empty? ? "unknown" : @file
        l = @line > 0 ? ":#{@line}" : ""
        "#{@index}: #{@function} at #{f}#{l}"
      end
    end

    struct BreakpointInfo
      property id : Int32
      property file : String
      property line : Int32
      property hit_count : Int32
      property enabled : Bool
      property resolved : Bool

      def initialize(@id : Int32, @file : String, @line : Int32, @hit_count : Int32 = 0, @enabled : Bool = true, @resolved : Bool = false)
      end
    end

    struct VariableInfo
      property name : String
      property type_name : String
      property value : String

      def initialize(@name : String, @type_name : String, @value : String)
      end
    end

    struct StopInfo
      property reason : StopReason
      property thread_id : Int32
      property frame : StackFrame?
      property description : String

      def initialize(@reason : StopReason, @thread_id : Int32 = 1, @frame : StackFrame? = nil, @description : String = "")
      end
    end

    enum DriverState
      Detached
      Attaching
      Running
      Paused
      Terminated
    end

    class LldbDriver
      getter state : DriverState = DriverState::Detached
      getter attached_pid : Int64? = nil
      getter breakpoints : Hash(Int32, BreakpointInfo) = Hash(Int32, BreakpointInfo).new

      property on_stop : Proc(StopInfo, Nil)? = nil
      property on_continue : Proc(Nil)? = nil
      property on_output : Proc(String, Nil)? = nil
      property on_exit : Proc(Int32, Nil)? = nil

      @process : Process? = nil
      @reader_thread : ::Thread? = nil
      @out_channel : ::Channel(String)? = nil
      @mutex : ::Thread::Mutex = ::Thread::Mutex.new
      @command_response : String = ""
      @waiting_for_prompt : Bool = false
      @response_channel : ::Channel(String)? = nil

      def initialize(@lldb_path : String = "lldb")
      end

      # Discovers the lldb executable on the system
      def self.find_lldb(custom_path : String? = nil) : String?
        if custom_path && !custom_path.strip.empty?
          clean = custom_path.strip
          return clean if File.exists?(clean)
        end

        # Check PATH
        path_exts = {% if flag?(:windows) %} [".exe", ".cmd", ""] {% else %} [""] {% end %}
        env_path = ENV["PATH"]? || ""
        sep = {% if flag?(:windows) %} ';' {% else %} ':' {% end %}
        env_path.split(sep).each do |dir|
          next if dir.empty?
          path_exts.each do |ext|
            candidate = File.join(dir, "lldb#{ext}")
            return candidate if File.exists?(candidate)
          end
        end

        {% if flag?(:windows) %}
          # Common Windows locations
          user_profile = ENV["USERPROFILE"]? || ""
          local_app_data = ENV["LOCALAPPDATA"]? || ""
          candidates = [
            "C:\\ProgramData\\llvm\\bin\\lldb.exe",
            File.join(user_profile, "scoop", "apps", "llvm", "current", "bin", "lldb.exe"),
            "C:\\Program Files\\LLVM\\bin\\lldb.exe",
            "C:\\Program Files (x86)\\LLVM\\bin\\lldb.exe",
            "C:\\Program Files\\Microsoft Visual Studio\\2022\\Community\\VC\\Tools\\Llvm\\bin\\lldb.exe",
            "C:\\Program Files\\Microsoft Visual Studio\\2022\\Professional\\VC\\Tools\\Llvm\\bin\\lldb.exe",
            "C:\\Program Files\\Microsoft Visual Studio\\2022\\Enterprise\\VC\\Tools\\Llvm\\bin\\lldb.exe",
            "C:\\Program Files (x86)\\Microsoft Visual Studio\\2022\\BuildTools\\VC\\Tools\\Llvm\\bin\\lldb.exe",
          ]
          candidates.each do |cand|
            return cand if File.exists?(cand)
          end
        {% end %}

        nil
      end

      # Returns true if LLDB is available
      def self.available?(custom_path : String? = nil) : Bool
        !find_lldb(custom_path).nil?
      end

      # Starts the LLDB subprocess and attaches to a target PID
      def attach(pid : Int64) : Bool
        return false if @process && @state != DriverState::Detached && @state != DriverState::Terminated

        exe = self.class.find_lldb(@lldb_path) || @lldb_path
        begin
          proc = Process.new(
            exe,
            ["--no-use-colors"],
            input: Process::Redirect::Pipe,
            output: Process::Redirect::Pipe,
            error: Process::Redirect::Pipe
          )
          @process = proc
          @state = DriverState::Attaching
          @attached_pid = pid
          @out_channel = ::Channel(String).new(128)
          @response_channel = ::Channel(String).new(1)

          start_reader_threads(proc)

          # Send attach command
          send_command("process attach --pid #{pid}")
          @state = DriverState::Paused
          true
        rescue ex
          @state = DriverState::Detached
          @attached_pid = nil
          if cb = @on_output
            cb.call("[LLDB Error] Failed to spawn #{exe}: #{ex.message}\n")
          end
          false
        end
      end

      # Detaches LLDB cleanly
      def detach : Void
        return unless @process

        if @state == DriverState::Paused
          send_command("process detach")
        else
          send_command("process interrupt")
          send_command("process detach")
        end
        send_command("quit")

        @state = DriverState::Detached
        @attached_pid = nil
        close_process
      end

      # Sends a raw command line to LLDB
      def send_command(cmd : String) : Void
        proc = @process
        return unless proc && !proc.terminated?

        if stdin = proc.input
          begin
            stdin.puts(cmd)
            stdin.flush
          rescue
          end
        end
      end

      # Sets a breakpoint at the given file and line
      def set_breakpoint(file : String, line : Int32) : BreakpointInfo
        # Clean path for LLDB
        clean_file = file.gsub('\\', '/')
        cmd = "breakpoint set --file \"#{File.basename(clean_file)}\" --line #{line}"
        send_command(cmd)

        id = @breakpoints.size + 1
        bp = BreakpointInfo.new(id, clean_file, line, enabled: true, resolved: true)
        @mutex.synchronize do
          @breakpoints[id] = bp
        end
        bp
      end

      # Removes a breakpoint by ID
      def remove_breakpoint(id : Int32) : Bool
        send_command("breakpoint delete #{id}")
        @mutex.synchronize do
          @breakpoints.delete(id)
        end
        true
      end

      # Resumes execution
      def continue_exec : Void
        return unless @state == DriverState::Paused
        @state = DriverState::Running
        send_command("process continue")
        if cb = @on_continue
          cb.call
        end
      end

      # Interrupts/pauses execution
      def interrupt_exec : Void
        return unless @state == DriverState::Running
        send_command("process interrupt")
      end

      # Step over (next source line)
      def step_over : Void
        return unless @state == DriverState::Paused
        send_command("thread step-over")
      end

      # Step into function
      def step_into : Void
        return unless @state == DriverState::Paused
        send_command("thread step-in")
      end

      # Step out of function
      def step_out : Void
        return unless @state == DriverState::Paused
        send_command("thread step-out")
      end

      # Requests call stack backtrace
      def request_backtrace : Void
        send_command("thread backtrace")
      end

      # Requests local variables
      def request_variables : Void
        send_command("frame variable")
      end

      # Evaluates an expression
      def evaluate(expr : String) : Void
        send_command("expression #{expr}")
      end

      # Pumps background events non-blockingly on the Godot main thread
      def poll : Void
        if ch = @out_channel
          loop do
            select
            when line = ch.receive?
              if line
                handle_lldb_output_line(line)
              else
                break
              end
            else
              break
            end
          end
        end

        if (proc = @process) && proc.terminated? && @state != DriverState::Terminated && @state != DriverState::Detached
          exit_code = proc.wait.exit_code rescue -1
          @state = DriverState::Terminated
          if cb = @on_exit
            cb.call(exit_code)
          end
        end
      end

      # Parses lines coming from LLDB stdout
      private def handle_lldb_output_line(line : String) : Void
        if cb = @on_output
          cb.call(line + "\n")
        end

        # Check for stop events
        # e.g.: "* thread #1, stop reason = breakpoint 1.1"
        # e.g.: "Process 12345 stopped"
        if line.includes?("stop reason =") || line.includes?("Process") && line.includes?("stopped")
          @state = DriverState::Paused
          info = parse_stop_info(line)
          if cb = @on_stop
            cb.call(info)
          end
        elsif line.includes?("Process") && line.includes?("resuming")
          @state = DriverState::Running
          if cb = @on_continue
            cb.call
          end
        end
      end

      # Parses stop event string into StopInfo
      def parse_stop_info(line : String) : StopInfo
        reason = StopReason::Unknown
        if line.includes?("breakpoint")
          reason = StopReason::Breakpoint
        elsif line.includes?("signal") || line.includes?("SIG") || line.includes?("EXCEPTION")
          reason = StopReason::Signal
        elsif line.includes?("step")
          reason = StopReason::Step
        elsif line.includes?("interrupt")
          reason = StopReason::UserInterrupt
        end

        frame = parse_frame_line(line)
        StopInfo.new(reason: reason, thread_id: 1, frame: frame, description: line)
      end

      # Extracts StackFrame from LLDB frame line
      # e.g.: "    frame #0: 0x00007ff812345678 game.dll`Player#_physics_process(self=0x...) at player.cr:42:5"
      def parse_frame_line(line : String) : StackFrame?
        return nil unless line.includes?("frame #")

        idx = 0
        fn = "unknown"
        file = ""
        line_num = 0
        addr = ""

        # Extract frame index
        if match = line.match(/frame #(\d+): (0x[0-9a-fA-F]+)\s+([^\s]+)(.*)/)
          idx = match[1].to_i32 rescue 0
          addr = match[2]
          fn = match[3]
          rest = match[4]

          if at_match = rest.match(/at\s+([^:]+):(\d+)/)
            file = at_match[1].strip
            line_num = at_match[2].to_i32 rescue 0
          end
        end

        StackFrame.new(idx, fn, file, line_num, addr)
      end

      # Spawns OS background thread to read LLDB stdout/stderr into buffered channel
      private def start_reader_threads(proc : Process) : Void
        out_ch = @out_channel
        return unless out_ch

        stdout = proc.output
        stderr = proc.error

        ::Thread.new do
          begin
            if stdout
              while line = stdout.gets
                out_ch.send(line.chomp)
              end
            end
          rescue
          ensure
            out_ch.close rescue nil
          end
        end

        ::Thread.new do
          begin
            if stderr
              while err_line = stderr.gets
                out_ch.send("[stderr] " + err_line.chomp)
              end
            end
          rescue
          end
        end
      end

      private def close_process : Void
        if proc = @process
          begin
            proc.terminate unless proc.terminated?
          rescue
          end
          @process = nil
        end
      end
    end
  end
end

module Godot
  alias Debugger = ::Lapis::Debugger
end
