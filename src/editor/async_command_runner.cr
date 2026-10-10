# =============================================================================
# LibGodot - Asynchronous Non-Blocking Command Runner
# =============================================================================
# Executes child CLI processes on a background OS thread with line-by-line
# output streaming and thread-safe dispatch onto Godot's engine main thread.
# Prevents editor UI freezing during builds, spec runs, and benchmarks.
# =============================================================================
module Lapis
  class AsyncCommandRunner
    enum EventType
      Line
      Finished
      Error
    end

    struct Event
      getter type : EventType
      getter text : String
      getter exit_code : Int32
      getter elapsed_sec : Float64

      def initialize(@type : EventType, @text : String = "", @exit_code : Int32 = 0, @elapsed_sec : Float64 = 0.0)
      end
    end

    @@instance : AsyncCommandRunner? = nil

    def self.instance : AsyncCommandRunner
      @@instance ||= new
    end

    getter? running : Bool = false
    getter active_command_name : String = ""

    @mutex = ::Thread::Mutex.new
    @queue = [] of Event
    @active_process : Process? = nil
    @on_line_cb : Proc(String, Nil)? = nil
    @on_finish_cb : Proc(Int32, Float64, String, Nil)? = nil
    @accumulated_output = IO::Memory.new
    @start_time : ::Time::Instant = ::Time.instant

    def elapsed_seconds : Float64
      return 0.0 unless @running
      (::Time.instant - @start_time).total_seconds
    end

    # Executes a command asynchronously on a background thread.
    # Returns true if started, false if another command is already active.
    def run(
      name : String,
      command : String,
      args : Array(String),
      env : Process::Env = nil,
      chdir : String? = nil,
      on_line : Proc(String, Nil)? = nil,
      &on_finish : Int32, Float64, String -> Nil
    ) : Bool
      @mutex.synchronize do
        return false if @running
        @running = true
        @active_command_name = name
        @on_line_cb = on_line
        @on_finish_cb = on_finish
        @accumulated_output.clear
        @start_time = ::Time.instant
      end

      # Background OS worker thread
      ::Thread.new do
        read_pipe, write_pipe = IO.pipe
        begin
          proc = Process.new(command, args, env: env, chdir: chdir, output: write_pipe, error: write_pipe)
          @mutex.synchronize { @active_process = proc }
          write_pipe.close

          read_pipe.each_line do |line|
            @mutex.synchronize do
              @accumulated_output.puts line
              @queue << Event.new(EventType::Line, line)
            end
          end

          status = proc.wait
          elapsed = (::Time.instant - @start_time).total_seconds
          code = status.normal_exit? ? status.exit_code : -1

          @mutex.synchronize do
            @queue << Event.new(EventType::Finished, "", code, elapsed)
            @active_process = nil
          end
        rescue ex
          elapsed = (::Time.instant - @start_time).total_seconds
          @mutex.synchronize do
            @queue << Event.new(EventType::Error, ex.message || "Subprocess failed", -1, elapsed)
            @active_process = nil
          end
        ensure
          read_pipe.close rescue nil
        end
      end

      true
    end

    # Sets or replaces the live line callback
    def set_on_line(&block : String -> Nil) : Void
      @mutex.synchronize do
        @on_line_cb = block
      end
    end

    # Cancels the actively running child process if any
    def cancel : Void
      @mutex.synchronize do
        if proc = @active_process
          proc.terminate rescue nil
        end
      end
    end

    # Drains all queued output events and dispatches callbacks on the calling thread (Godot main thread).
    def poll : Void
      events_to_process = [] of Event
      @mutex.synchronize do
        return if @queue.empty?
        events_to_process = @queue.dup
        @queue.clear
      end

      events_to_process.each do |evt|
        case evt.type
        when EventType::Line
          cb = @mutex.synchronize { @on_line_cb }
          cb.try &.call(evt.text)
        when EventType::Finished
          finish_cb = @mutex.synchronize { @on_finish_cb }
          output_text = @mutex.synchronize { @accumulated_output.to_s }
          @mutex.synchronize do
            @running = false
            @on_finish_cb = nil
          end
          finish_cb.try &.call(evt.exit_code, evt.elapsed_sec, output_text)
        when EventType::Error
          finish_cb = @mutex.synchronize { @on_finish_cb }
          output_text = @mutex.synchronize { @accumulated_output.to_s }
          @mutex.synchronize do
            @running = false
            @on_finish_cb = nil
          end
          finish_cb.try &.call(evt.exit_code, evt.elapsed_sec, "Error: #{evt.text}\n#{output_text}")
        end
      end
    end
  end
end
