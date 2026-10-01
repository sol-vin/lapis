require "./level"
require "./record"
require "./sink"
require "./channel"

module Godot
  # ===========================================================================
  # Central Thread-Safe Diagnostic Logging Dispatcher with User-Defined Filters
  # ===========================================================================
  #
  # Manages log channels, custom status filtering, multi-sink routing,
  # and public/safe sanitization.
  # ===========================================================================
  class DiagnosticLogger
    @@instance : DiagnosticLogger? = nil
    @@mutex : ::Thread::Mutex = ::Thread::Mutex.new
    @@named_filters : Hash(String, LogFilterProc) = Hash(String, LogFilterProc).new
    @@channels : Hash(String, LogChannel) = Hash(String, LogChannel).new

    getter sinks : Array(LogSink)
    getter ring_buffer : MemoryRingBufferSink
    getter console_sink : GodotConsoleSink
    getter file_sink : FileLogSink?
    property min_level : LogLevel

    # -------------------------------------------------------------------------
    # User-Defined Filter Registry
    # -------------------------------------------------------------------------

    # Register a named filter globally (e.g. "public", "safe", "security", "telemetry")
    def self.register_filter(name : String, &block : LogFilterProc) : Void
      @@mutex.synchronize do
        @@named_filters[name.downcase] = block
      end
    end

    def self.register_filter(name : String, filter : LogFilterProc) : Void
      @@mutex.synchronize do
        @@named_filters[name.downcase] = filter
      end
    end

    def self.named_filter(name : String) : LogFilterProc?
      @@mutex.synchronize do
        @@named_filters[name.downcase]?
      end
    end

    def self.filter_names : Array(String)
      @@mutex.synchronize do
        @@named_filters.keys.dup
      end
    end

    # Built-in default filters
    register_filter("public") do |record|
      # Public filter: allows errors, or explicitly public logs, while strictly blocking confidential/secret game data
      record.level.error? || (record.public? && !record.confidential?)
    end

    register_filter("safe") do |record|
      # Security/sanitization filter: rejects any log containing secrets, credentials, or confidential tags
      if record.confidential?
        false
      else
        msg_low = record.message.downcase
        !(msg_low.includes?("password=") || msg_low.includes?("secret=") ||
          msg_low.includes?("api_key=") || msg_low.includes?("token=") ||
          msg_low.includes?("private_key"))
      end
    end

    register_filter("errors_only") do |record|
      record.level.error?
    end

    register_filter("warn_and_error") do |record|
      record.level <= LogLevel::Warn
    end

    register_filter("no_spoilers") do |record|
      !record.has_tag?("spoiler") && !record.status?("spoiler") && !record.message.downcase.includes?("spoiler:")
    end

    # -------------------------------------------------------------------------
    # User-Defined Log Channels & Status Management
    # -------------------------------------------------------------------------

    # Access or create a named log channel
    def self.channel(name : String) : LogChannel
      key = name.downcase
      @@mutex.synchronize do
        @@channels[key] ||= LogChannel.new(name: name)
      end
    end

    # Configures a channel with custom status, minimum level, and user-defined filter procs
    def self.configure_channel(name : String, status : String = "active", min_level : LogLevel? = nil, &block : LogChannel ->) : LogChannel
      chan = channel(name)
      chan.status = status
      chan.min_level = min_level if min_level
      block.call(chan)
      chan
    end

    def self.channel_names : Array(String)
      @@mutex.synchronize do
        @@channels.keys.dup
      end
    end

    # -------------------------------------------------------------------------
    # Singleton & Dispatcher Access
    # -------------------------------------------------------------------------

    def self.instance : DiagnosticLogger
      if inst = @@instance
        inst
      else
        @@mutex.synchronize do
          @@instance ||= DiagnosticLogger.new
        end
      end
    end

    def self.dispatch(
      level : LogLevel,
      channel : String,
      message : String,
      file : String = "",
      line : Int32 = 0,
      function : String = "",
      tags : Array(String) = [] of String,
      status : String = ""
    ) : Void
      instance.dispatch(level, channel, message, file, line, function, tags, status)
    end

    def initialize
      # Determine default minimum log level based on environment or build flags
      env_level_str = ENV["LAPIS_LOG_LEVEL"]?
      @min_level = if env_level_str
                     LogLevel.parse?(env_level_str) || LogLevel::Trace
                   else
                     {% if flag?(:release) %}
                       LogLevel::Info
                     {% else %}
                       LogLevel::Trace
                     {% end %}
                   end

      @sinks = Array(LogSink).new
      @mutex = ::Thread::Mutex.new

      # 1. In-memory circular buffer for editor UI inspection and crash reports
      @ring_buffer = MemoryRingBufferSink.new(capacity: 2500)
      @sinks << @ring_buffer

      # 2. Godot console sink (filters Debug/Trace/Internal from STDOUT)
      @console_sink = GodotConsoleSink.new
      @sinks << @console_sink

      # 3. File log sink (if configured via environment variable or standard location)
      @file_sink = nil
      setup_file_sink
    end

    private def setup_file_sink : Void
      log_file_env = ENV["LAPIS_LOG_FILE"]?
      target_path = if log_file_env && !log_file_env.empty?
                      log_file_env
                    else
                      context = ENV["LAPIS_LOG_CONTEXT"]? || "crystal"
                      "log/#{context}.log"
                    end

      begin
        sink = FileLogSink.new(target_path)
        @file_sink = sink
        @sinks << sink
      rescue ex
        # Continue safely if file sink cannot be opened
      end
    end

    # Creates and registers a public log sink that only captures errors and public-tagged records,
    # preventing leakage of secret game information.
    def create_public_sink(path : String | Path = "log/public.log", min_level : LogLevel = LogLevel::Trace) : FileLogSink
      sink = FileLogSink.new(path)
      sink.status = "public_channel"
      sink.min_level = min_level
      if pub_filter = DiagnosticLogger.named_filter("public")
        sink.add_filter(pub_filter)
      else
        sink.add_filter { |r| r.level.error? || (r.public? && !r.confidential?) }
      end
      add_sink(sink)
      sink
    end

    # Creates a dedicated file sink for a specific channel
    def create_channel_sink(
      channel_name : String,
      path : String | Path = "log/#{channel_name}.log",
      min_level : LogLevel = LogLevel::Trace,
      &block : FileLogSink ->
    ) : FileLogSink
      sink = FileLogSink.new(path)
      sink.min_level = min_level
      block.call(sink)
      chan = DiagnosticLogger.channel(channel_name)
      chan.add_sink(sink)
      sink
    end

    # Dispatches a structured log message across registered channels and sinks
    def dispatch(
      level : LogLevel,
      channel : String,
      message : String,
      file : String = "",
      line : Int32 = 0,
      function : String = "",
      tags : Array(String) = [] of String,
      status : String = ""
    ) : Void
      return if level.off? || level > @min_level

      # Check channel status & channel-level filters if channel is registered
      chan = @@mutex.synchronize { @@channels[channel.downcase]? }
      record_status = if !status.empty?
                        status
                      elsif chan
                        chan.status
                      else
                        ""
                      end

      record = LogRecord.new(
        level: level,
        channel: channel,
        message: message,
        file: file,
        line: line,
        function: function,
        tags: tags,
        status: record_status
      )

      # If channel exists, verify channel filters pass
      if chan
        return unless chan.passes_filters?(record)
        chan.dispatch_sinks(record)
      end

      # Dispatch across central logger sinks
      @mutex.synchronize do
        @sinks.each do |sink|
          sink.write(record) if sink.enabled?
        end
      end
    end

    def add_sink(sink : LogSink) : Void
      @mutex.synchronize do
        @sinks << sink unless @sinks.includes?(sink)
      end
    end

    def remove_sink(sink : LogSink) : Void
      @mutex.synchronize do
        @sinks.delete(sink)
      end
    end

    def set_file_destination(path : String | Path) : Void
      @mutex.synchronize do
        if existing = @file_sink
          @sinks.delete(existing)
          existing.close rescue nil
        end
        new_sink = FileLogSink.new(path)
        @file_sink = new_sink
        @sinks << new_sink
      end
    end

    def flush : Void
      @mutex.synchronize do
        @sinks.each(&.flush)
        @@channels.values.each do |chan|
          chan.sinks.each(&.flush)
        end
      end
    end

    def close : Void
      @mutex.synchronize do
        @sinks.each(&.close)
        @@channels.values.each do |chan|
          chan.sinks.each(&.close)
        end
      end
    end
  end
end
