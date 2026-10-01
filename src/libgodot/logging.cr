require "./logging/filter"
require "./logging/level"
require "./logging/record"
require "./logging/sink"
require "./logging/channel"
require "./logging/logger"
require "./logging/macros"

module Godot
  # ===========================================================================
  # Godot Engine Logging & Diagnostics System
  # ===========================================================================

  # Master diagnostic logger instance accessor
  def self.logger : DiagnosticLogger
    DiagnosticLogger.instance
  end

  # Access or register a user-defined log channel
  def self.channel(name : String) : LogChannel
    DiagnosticLogger.channel(name)
  end

  # Configure a user-defined log channel with status, level, and filters
  def self.configure_channel(name : String, status : String = "active", min_level : LogLevel? = nil, &block : LogChannel ->) : LogChannel
    DiagnosticLogger.configure_channel(name, status, min_level, &block)
  end

  # Register a globally named log filter
  def self.register_filter(name : String, &block : LogFilterProc) : Void
    DiagnosticLogger.register_filter(name, &block)
  end

  # Returns the circular in-memory buffer of recent log records
  def self.log_history : Array(LogRecord)
    DiagnosticLogger.instance.ring_buffer.snapshot
  end

  # Returns true if the engine was launched with verbose logging enabled (--verbose)
  def self.verbose? : Bool
    Bridge.verbose?
  end

  # Prints a formatted message to the Godot console and records it to log sinks
  def self.print(*args)
    msg = args.join(" ")
    log_info("Stdout", msg)
  end

  # Prints an error message to the Godot console and standard error
  def self.printerr(*args)
    msg = args.join(" ")
    log_error("Stderr", msg)
  end

  # Prints a rich structured error with function, file, and line details
  def self.print_error(msg : String, func : String = "", file : String = __FILE__, line : Int32 = __LINE__)
    log(:error, "Error", msg, file: file, line: line, func: func)
  end

  # Prints a rich structured warning with function, file, and line details
  def self.print_warning(msg : String, func : String = "", file : String = __FILE__, line : Int32 = __LINE__)
    log(:warn, "Warning", msg, file: file, line: line, func: func)
  end

  # Prints a verbose diagnostic message that only appears when verbose logging is active
  def self.print_verbose(*args)
    msg = args.join(" ")
    log_debug("Verbose", msg)
  end

  # Alias for `print_verbose`
  def self.debug(*args)
    print_verbose(*args)
  end
end
