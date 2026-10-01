module Godot
  # ===========================================================================
  # Compile-Time Zero-Cost Logging Macros with Extensible Tags & Status
  # ===========================================================================
  #
  # When compiled with `-Dno_log`, `-Dlog_disabled`, `-Dlog=0`, or `-Dlog=off`,
  # all logging invocations are completely stripped from the AST at compile time,
  # resulting in 0 CPU instructions, 0 function calls, and 0 memory allocations.
  #
  # Custom compiler flags supported:
  # - `-Dlog=0` / `-Dlog=off`: Disables all logs.
  # - `-Dlog=1` / `-Dlog=error`: Only error logs.
  # - `-Dlog=2` / `-Dlog=warn`: Error and warning logs.
  # - `-Dlog=3` / `-Dlog=info`: Error, warn, and info logs.
  # - `-Dlog=4` / `-Dlog=debug`: Error, warn, info, and debug logs.
  # - `-Dlog=5` / `-Dlog=trace`: All logs including verbose trace.
  #
  # In `--release` builds, debug and trace logs are elided unless `-Dlog_trace`
  # or `-Dlog=4|5` is specified.
  # ===========================================================================

  # Master log macro with AST elision, automatic tagging, and status handling
  macro log(level, *args, **kwargs)
    {%
      # Extract channel and message from positional arguments
      if args.size == 1
        chan = "General"
        msg = args[0]
      elsif args.size >= 2
        chan = args[0]
        msg = args[1]
      else
        chan = "General"
        msg = ""
      end

      # Extract level name from Path or Symbol
      lvl_id = if level.is_a?(Path)
                 level.names.last.id.downcase.stringify
               elsif level.is_a?(SymbolLiteral)
                 level.id.downcase.stringify
               else
                 level.id.downcase.stringify
               end

      # Determine compile-time minimum log level threshold
      min_lvl = 5
      if flag?(:no_log) || flag?(:log_disabled) || flag?(:"log=0") || flag?(:"log=off") || flag?(:"log=none")
        min_lvl = 0
      elsif flag?(:"log=1") || flag?(:"log=error") || flag?(:"log=err")
        min_lvl = 1
      elsif flag?(:"log=2") || flag?(:"log=warn") || flag?(:"log=warning")
        min_lvl = 2
      elsif flag?(:"log=3") || flag?(:"log=info")
        min_lvl = 3
      elsif flag?(:"log=4") || flag?(:"log=debug")
        min_lvl = 4
      elsif flag?(:"log=5") || flag?(:"log=trace")
        min_lvl = 5
      elsif flag?(:"log=6") || flag?(:"log=internal") || flag?(:"log=gc")
        min_lvl = 6
      elsif flag?(:release) && !flag?(:log_trace) && !flag?(:log_debug)
        min_lvl = 3
      end

      # Determine numeric severity for this log statement
      lvl_num = 3 # default severity for custom user categories
      if lvl_id == "off"
        lvl_num = 0
      elsif lvl_id == "error" || lvl_id == "err"
        lvl_num = 1
      elsif lvl_id == "warn" || lvl_id == "warning"
        lvl_num = 2
      elsif lvl_id == "info"
        lvl_num = 3
      elsif lvl_id == "debug"
        lvl_num = 4
      elsif lvl_id == "trace"
        lvl_num = 5
      elsif lvl_id == "internal" || lvl_id == "gc"
        lvl_num = 6
      end
    %}
    {% if lvl_num > 0 && lvl_num <= min_lvl %}
      # Resolve LogLevel enum member
      %resolved_lvl = {% if level.is_a?(Path) %}
                        {{level}}
                      {% else %}
                        ::Godot::LogLevel::{{lvl_id.camelcase.id}}
                      {% end %}

      # Automatically synthesize metadata tags from filter name_tag
      {% if kwargs[:tags] %}
        %effective_tags = [%resolved_lvl.name_tag] + ({{kwargs[:tags]}}).map(&.to_s)
      {% else %}
        %effective_tags = [%resolved_lvl.name_tag]
      {% end %}

      # Automatically synthesize status from filter name_tag
      {% if kwargs[:status] %}
        %effective_status = ({{kwargs[:status]}}).to_s
      {% else %}
        %effective_status = %resolved_lvl.name_tag.downcase
      {% end %}

      ::Godot::DiagnosticLogger.dispatch(
        level: %resolved_lvl,
        channel: {{chan}}.to_s,
        message: {{msg}}.to_s,
        file: {{kwargs[:file] || "__FILE__".id}},
        line: {{kwargs[:line] || "__LINE__".id}},
        function: {{kwargs[:func] || "\"\"".id}}.to_s,
        tags: %effective_tags,
        status: %effective_status
      )
    {% else %}
      # ELIDED FROM AST AT COMPILE TIME (0 instructions, 0 allocations)
    {% end %}
  end

  # --- Ergonomic Level Helpers (Supports both 1-arg and 2-arg forms) ---

  macro log_error(category, message = nil, **kwargs)
    {% if message.nil? %}
      ::Godot.log(::Godot::LogLevel::Error, "General", {{category}}, {{kwargs.double_splat}})
    {% else %}
      ::Godot.log(::Godot::LogLevel::Error, {{category}}, {{message}}, {{kwargs.double_splat}})
    {% end %}
  end

  macro log_warn(category, message = nil, **kwargs)
    {% if message.nil? %}
      ::Godot.log(::Godot::LogLevel::Warn, "General", {{category}}, {{kwargs.double_splat}})
    {% else %}
      ::Godot.log(::Godot::LogLevel::Warn, {{category}}, {{message}}, {{kwargs.double_splat}})
    {% end %}
  end

  macro log_info(category, message = nil, **kwargs)
    {% if message.nil? %}
      ::Godot.log(::Godot::LogLevel::Info, "General", {{category}}, {{kwargs.double_splat}})
    {% else %}
      ::Godot.log(::Godot::LogLevel::Info, {{category}}, {{message}}, {{kwargs.double_splat}})
    {% end %}
  end

  macro log_debug(category, message = nil, **kwargs)
    {% if message.nil? %}
      ::Godot.log(::Godot::LogLevel::Debug, "General", {{category}}, {{kwargs.double_splat}})
    {% else %}
      ::Godot.log(::Godot::LogLevel::Debug, {{category}}, {{message}}, {{kwargs.double_splat}})
    {% end %}
  end

  macro log_trace(category, message = nil, **kwargs)
    {% if message.nil? %}
      ::Godot.log(::Godot::LogLevel::Trace, "General", {{category}}, {{kwargs.double_splat}})
    {% else %}
      ::Godot.log(::Godot::LogLevel::Trace, {{category}}, {{message}}, {{kwargs.double_splat}})
    {% end %}
  end

  macro log_internal(category, message = nil, **kwargs)
    {% if message.nil? %}
      ::Godot.log(::Godot::LogLevel::Internal, "General", {{category}}, {{kwargs.double_splat}})
    {% else %}
      ::Godot.log(::Godot::LogLevel::Internal, {{category}}, {{message}}, {{kwargs.double_splat}})
    {% end %}
  end

  # --- Channel-Specific & Status Helpers ---

  # Logs directly to a specific channel
  macro log_channel(channel, level, message, **kwargs)
    ::Godot.log({{level}}, {{channel}}, {{message}}, {{kwargs.double_splat}})
  end

  # --- Public Channel & Secret Prevention Helpers ---

  # Logs a message explicitly tagged as "public" with "public" status for public channels and distribution
  macro log_public(level, category, message, **kwargs)
    ::Godot.log({{level}}, {{category}}, {{message}}, status: "public", {{kwargs.double_splat}})
  end

  macro log_public_info(category, message = nil, **kwargs)
    {% if message.nil? %}
      ::Godot.log_public(::Godot::LogLevel::Info, "Public", {{category}}, {{kwargs.double_splat}})
    {% else %}
      ::Godot.log_public(::Godot::LogLevel::Info, {{category}}, {{message}}, {{kwargs.double_splat}})
    {% end %}
  end

  macro log_public_warn(category, message = nil, **kwargs)
    {% if message.nil? %}
      ::Godot.log_public(::Godot::LogLevel::Warn, "Public", {{category}}, {{kwargs.double_splat}})
    {% else %}
      ::Godot.log_public(::Godot::LogLevel::Warn, {{category}}, {{message}}, {{kwargs.double_splat}})
    {% end %}
  end

  macro log_public_error(category, message = nil, **kwargs)
    {% if message.nil? %}
      ::Godot.log_public(::Godot::LogLevel::Error, "Public", {{category}}, {{kwargs.double_splat}})
    {% else %}
      ::Godot.log_public(::Godot::LogLevel::Error, {{category}}, {{message}}, {{kwargs.double_splat}})
    {% end %}
  end

  # Logs an internal/confidential message tagged as secret. Public log channels & sinks reject these!
  macro log_secret(level, category, message, **kwargs)
    ::Godot.log({{level}}, {{category}}, {{message}}, tags: ["secret", "confidential"], status: "secret", {{kwargs.double_splat}})
  end
end
