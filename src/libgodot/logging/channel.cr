require "./level"
require "./record"
require "./sink"

module Godot
  # ===========================================================================
  # User-Defined Log Channel with Status & Custom Filtering
  # ===========================================================================
  #
  # A LogChannel represents a dedicated diagnostic category (e.g. "Public",
  # "Network", "Gameplay", "Combat").
  #
  # Channels allow users to:
  # 1. Define custom status (e.g. "active", "public_safe", "muted", "quarantined").
  # 2. Attach channel-level filters (e.g. error-only filter + custom public filter).
  # 3. Restrict minimum log level per channel.
  # 4. Attach dedicated channel sinks (e.g. log/public.log).
  # ===========================================================================
  class LogChannel
    getter name : String
    property status : String
    property min_level : LogLevel
    getter filters : Array(LogFilterProc)
    getter sinks : Array(LogSink)
    property? enabled : Bool = true

    def initialize(@name : String, @status : String = "active", @min_level : LogLevel = LogLevel::Trace)
      @filters = Array(LogFilterProc).new
      @sinks = Array(LogSink).new
    end

    def status?(expected : String) : Bool
      @status.downcase == expected.downcase
    end

    def mute! : Void
      @status = "muted"
      @enabled = false
    end

    def unmute! : Void
      @status = "active"
      @enabled = true
    end

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

    def add_sink(sink : LogSink) : Void
      @sinks << sink unless @sinks.includes?(sink)
    end

    def remove_sink(sink : LogSink) : Void
      @sinks.delete(sink)
    end

    # Evaluates whether a log record passes this channel's level, status, and custom filters
    def passes_filters?(record : LogRecord) : Bool
      return false unless @enabled
      return false if @status.downcase == "disabled" || @status.downcase == "muted"
      return false if record.level > @min_level
      @filters.all? { |f| f.call(record) }
    end

    # Dispatches directly to this channel's dedicated sinks (if any)
    def dispatch_sinks(record : LogRecord) : Void
      @sinks.each do |sink|
        sink.write(record) if sink.enabled?
      end
    end

    # Ergonomic channel-level logging methods
    def log(
      level : LogLevel,
      message : String,
      file : String = "",
      line : Int32 = 0,
      func : String = "",
      tags : Array(String) = [] of String,
      status : String = ""
    ) : Void
      DiagnosticLogger.dispatch(
        level: level,
        channel: @name,
        message: message,
        file: file,
        line: line,
        function: func,
        tags: tags,
        status: status.empty? ? @status : status
      )
    end

    def error(message : String, tags : Array(String) = [] of String, status : String = "") : Void
      log(LogLevel::Error, message, tags: tags, status: status)
    end

    def warn(message : String, tags : Array(String) = [] of String, status : String = "") : Void
      log(LogLevel::Warn, message, tags: tags, status: status)
    end

    def info(message : String, tags : Array(String) = [] of String, status : String = "") : Void
      log(LogLevel::Info, message, tags: tags, status: status)
    end

    def debug(message : String, tags : Array(String) = [] of String, status : String = "") : Void
      log(LogLevel::Debug, message, tags: tags, status: status)
    end

    def trace(message : String, tags : Array(String) = [] of String, status : String = "") : Void
      log(LogLevel::Trace, message, tags: tags, status: status)
    end
  end
end
