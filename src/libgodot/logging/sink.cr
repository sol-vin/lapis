require "./record"
require "./level"

module Godot
  alias LogFilterProc = Proc(LogRecord, Bool)

  # Base interface for log output destinations with custom filter support
  abstract class LogSink
    property? enabled : Bool = true
    property status : String = "active"
    property min_level : LogLevel = LogLevel::Trace
    getter filters : Array(LogFilterProc) = [] of LogFilterProc

    def status?(expected : String) : Bool
      @status.downcase == expected.downcase
    end

    # Adds a user-defined filter block. If the block returns false, the record is rejected by this sink.
    def add_filter(&block : LogFilterProc) : Void
      @filters << block
    end

    def add_filter(filter : LogFilterProc) : Void
      @filters << filter
    end

    # Attach a globally registered named filter (e.g. "public", "safe", "no_spoilers")
    def add_filter(named_filter : String) : Void
      @filters << Proc(LogRecord, Bool).new { |rec|
        if filter_proc = DiagnosticLogger.named_filter(named_filter)
          filter_proc.call(rec)
        else
          true
        end
      }
    end

    def clear_filters : Void
      @filters.clear
    end

    def passes_filters?(record : LogRecord) : Bool
      return false unless @enabled
      return false if @status.downcase == "disabled" || @status.downcase == "muted"
      return false if record.level > @min_level
      @filters.all? { |f| f.call(record) }
    end

    abstract def write(record : LogRecord) : Void
    abstract def flush : Void
    abstract def close : Void
  end

  # Writes log records to disk with timestamps and automatic directory creation.
  # Uses low-level LibSystemIO (fopen/fwrite/fclose) to ensure thread-safety
  # across unmanaged OS threads (Thread.new) and alien C++ engine threads,
  # completely bypassing Crystal's fiber event loop on POSIX and IOCP on Windows.
  class FileLogSink < LogSink
    getter path : Path
    @fp : Void* = Pointer(Void).null
    @mutex : ::Thread::Mutex = ::Thread::Mutex.new
    @bytes_written : Int64 = 0_i64
    @max_bytes : Int64 = 20_971_520_i64 # 20MB default rotation cap

    def initialize(file_path : String | Path, @max_bytes : Int64 = 20_971_520_i64)
      @path = Path.new(file_path).expand
      ensure_open
    end

    private def ensure_open : Void
      return unless @fp.null?
      dir = @path.parent.to_s
      SystemIO.ensure_dir(dir) unless dir.empty?
      sz = SystemIO.file_size(@path.to_s)
      @bytes_written = sz >= 0_i64 ? sz : 0_i64
      @fp = LibSystemIO.fopen(@path.to_s.to_unsafe, "ab".to_unsafe)
    end

    def write(record : LogRecord) : Void
      return unless passes_filters?(record)

      @mutex.synchronize do
        ensure_open
        unless @fp.null?
          line = record.to_formatted_string(include_location: true)
          LibSystemIO.fwrite(line.to_unsafe.as(Void*), 1_u64, line.bytesize.to_u64, @fp)
          newline = "\n"
          LibSystemIO.fwrite(newline.to_unsafe.as(Void*), 1_u64, 1_u64, @fp)
          @bytes_written += line.bytesize + 1
          if record.level <= LogLevel::Warn
            LibSystemIO.fflush(@fp)
          end

          # Simple log rotation check (rotate to .1 if capped)
          if @bytes_written >= @max_bytes
            rotate_internal
          end
        end
      end
    end

    private def rotate_internal : Void
      return if @fp.null?
      LibSystemIO.fclose(@fp)
      @fp = Pointer(Void).null
      rotated_path = "#{@path}.1"
      SystemIO.delete_file(rotated_path)
      LibSystemIO.rename(@path.to_s.to_unsafe, rotated_path.to_unsafe)
      ensure_open
    end

    def flush : Void
      @mutex.synchronize do
        LibSystemIO.fflush(@fp) unless @fp.null?
      end
    end

    def close : Void
      @mutex.synchronize do
        unless @fp.null?
          LibSystemIO.fclose(@fp)
          @fp = Pointer(Void).null
        end
      end
    end
  end

  # Routes logs to Godot engine console and standard error/out
  # Invariant: Sub-Godot verbosity (Debug, Trace, Internal) is never printed to STDOUT
  class GodotConsoleSink < LogSink
    @mutex : ::Thread::Mutex = ::Thread::Mutex.new

    def initialize
      # Console only captures up to Info by default; Debug/Trace/Internal stay in file
      @min_level = LogLevel::Info
    end

    private def safe_puts_stdout(str : String) : Void
      if Fiber.current.execution_context?
        puts str
      else
        msg = str + "\n"
        {% if flag?(:windows) %}
          LibC._write(1, msg.to_unsafe, msg.bytesize.to_u32)
        {% else %}
          LibC.write(1, msg.to_unsafe.as(Void*), msg.bytesize.to_u64)
        {% end %}
      end
    rescue
      # Ignore I/O errors on unmanaged threads
    end

    private def safe_puts_stderr(str : String) : Void
      if Fiber.current.execution_context?
        STDERR.puts str
      else
        msg = str + "\n"
        {% if flag?(:windows) %}
          LibC._write(2, msg.to_unsafe, msg.bytesize.to_u32)
        {% else %}
          LibC.write(2, msg.to_unsafe.as(Void*), msg.bytesize.to_u64)
        {% end %}
      end
    rescue
      # Ignore I/O errors on unmanaged threads
    end

    def write(record : LogRecord) : Void
      return unless passes_filters?(record)

      case record.level
      when .error?
        if Bridge.api && !Bridge.api.null?
          Bridge.error(record.message, "", record.function, record.file, record.line)
        else
          safe_puts_stderr(record.to_ansi(include_location: true))
        end
      when .warn?
        if Bridge.api && !Bridge.api.null?
          Bridge.warning(record.message, "", record.function, record.file, record.line)
        else
          safe_puts_stderr(record.to_ansi(include_location: true))
        end
      when .info?
        tag = (record.channel.empty? || record.channel == "General" || record.channel == "Stdout") ? "" : "[#{record.channel}] "
        msg = "#{tag}#{record.message}"
        if Bridge.api && !Bridge.api.null?
          Bridge.print(msg)
        else
          safe_puts_stdout(record.to_ansi(include_location: false))
        end
      when .debug?, .trace?, .internal?
        # Only print to console if verbose mode is explicitly active on host
        if Godot.verbose?
          tag = "[#{record.channel}:#{record.level.name_tag}] "
          msg = "#{tag}#{record.message}"
          if Bridge.api && !Bridge.api.null?
            Bridge.print_verbose(msg)
          else
            safe_puts_stdout(record.to_ansi(include_location: true))
          end
        end
      when .off?
        # no-op
      else
        # Custom user-defined categories default to standard console output
        tag = (record.channel.empty? || record.channel == "General" || record.channel == "Stdout") ? "" : "[#{record.channel}:#{record.level.name_tag}] "
        msg = "#{tag}#{record.message}"
        if Bridge.api && !Bridge.api.null?
          Bridge.print(msg)
        else
          safe_puts_stdout(record.to_ansi(include_location: false))
        end
      end
    end

    def flush : Void
      # Engine console flushes on call
    end

    def close : Void
    end
  end

  # Keeps a circular in-memory buffer of recent logs for crash dumps and editor GUI inspection
  class MemoryRingBufferSink < LogSink
    getter capacity : Int32
    @buffer : Array(LogRecord)
    @mutex : ::Thread::Mutex = ::Thread::Mutex.new

    def initialize(@capacity : Int32 = 500)
      @buffer = Array(LogRecord).new(@capacity)
      @min_level = LogLevel::Internal # Capture everything in memory
    end

    def write(record : LogRecord) : Void
      return unless passes_filters?(record)
      @mutex.synchronize do
        if @buffer.size >= @capacity
          @buffer.shift
        end
        @buffer << record
      end
    end

    def snapshot : Array(LogRecord)
      @mutex.synchronize do
        @buffer.dup
      end
    end

    def clear : Void
      @mutex.synchronize do
        @buffer.clear
      end
    end

    def flush : Void
    end

    def close : Void
      clear
    end
  end
end
