module Godot
  # **Log Filter Registry & Delayed Enum Generator**: Metaprogramming engine for extensible log filters.
  #
  # This module allows the core engine, editor plugins, addons, and game code to register
  # custom log filters and categories anywhere across the codebase using `log_filter` or `define_log_filters`.
  #
  # At the end of compilation, a `macro finished` hook gathers all registered filters across
  # all files and synthesizes the unified `Godot::LogLevel` enum.
  #
  # ### Features Synthesized:
  # <table>
  #   <thead>
  #     <tr>
  #       <th>Feature</th>
  #       <th>Description</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr>
  #       <td><code>LogLevel</code> Enum</td>
  #       <td>Unified typed enum inheriting from <code>UInt8</code> containing core and user categories.</td>
  #     </tr>
  #     <tr>
  #       <td><code>#tag</code></td>
  #       <td>Bracketed tag string (e.g. <code>"[ERROR]"</code>, <code>"{spoiler}"</code>).</td>
  #     </tr>
  #     <tr>
  #       <td><code>#name_tag</code></td>
  #       <td>Clean uppercase identifier (e.g. <code>"ERROR"</code>, <code>"SPOILER"</code>).</td>
  #     </tr>
  #     <tr>
  #       <td><code>#color_bbcode</code></td>
  #       <td>Hex color sequence for rich editor panel rendering (e.g. <code>"#ff5555"</code>).</td>
  #     </tr>
  #     <tr>
  #       <td><code>#ansi_color</code></td>
  #       <td>Terminal ANSI escape code for colored console output.</td>
  #     </tr>
  #     <tr>
  #       <td><code>#severity</code></td>
  #       <td>Numeric severity level (1: Error, 2: Warn, 3: Info, etc.) for compile-time and runtime filtering.</td>
  #     </tr>
  #     <tr>
  #       <td><code>.from_line(line, default = nil)</code></td>
  #       <td>Fast text scanner that extracts the matching enum category from raw strings.</td>
  #     </tr>
  #     <tr>
  #       <td><code>.all_tags</code> / <code>.all_name_tags</code></td>
  #       <td>Array introspection of all registered tags.</td>
  #     </tr>
  #     <tr>
  #       <td><code>.parse?(str)</code></td>
  #       <td>Case-insensitive parser for CLI and config input.</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # ### Example: Registering Custom Filters Anywhere in Your Project
  # ```crystal
  # # Single-statement registration
  # log_filter :spoiler, tag: "{spoiler}", color: "#bd93f9"
  # log_filter :public, tag: "{public}", color: "#50fa7b"
  #
  # # Block DSL registration
  # define_log_filters do
  #   filter :combat, tag: "[COMBAT]", color: "#ff9900"
  #   filter :quest,  tag: "[QUEST]",  color: "#99ccff"
  # end
  # ```

  annotation LogFilterMeta; end
  abstract struct LogFilterRegistry; end

  # Registers a single log filter definition anywhere in the codebase
  macro log_filter(name, tag = nil, name_tag = nil, color = nil, ansi = nil, level = nil)
    @[::Godot::LogFilterMeta(
      name: {{name.id.stringify}},
      tag: {{tag || "[#{name.id.upcase}]"}},
      name_tag: {{name_tag || name.id.upcase.stringify}},
      color: {{color || "#ffffff"}},
      ansi: {{ansi || "\e[0m"}},
      level: {{level}}
    )]
    struct LogFilter_{{name.id.camelcase}} < ::Godot::LogFilterRegistry; end
  end

  # Alias for `log_filter`
  macro define_log_filter(name, tag = nil, name_tag = nil, color = nil, ansi = nil, level = nil)
    ::Godot.log_filter({{name}}, tag: {{tag}}, name_tag: {{name_tag}}, color: {{color}}, ansi: {{ansi}}, level: {{level}})
  end

  # Block DSL for registering multiple log filters cleanly
  macro define_log_filters(&block)
    macro filter(fname, **opts)
      ::Godot.log_filter(\{{fname}}, \{{opts.double_splat}})
    end
    {{yield}}
  end

  # --- Core Engine Pre-Registered Filters ---
  log_filter :off, level: 0, tag: "[OFF]", color: "#ffffff", ansi: "\e[0m"
  log_filter :error, level: 1, tag: "[ERROR]", color: "#ff5555", ansi: "\e[1;31m"
  log_filter :warn, level: 2, tag: "[WARN]", color: "#ffb86c", ansi: "\e[1;33m"
  log_filter :info, level: 3, tag: "[INFO]", color: "#8be9fd", ansi: "\e[1;36m"
  log_filter :debug, level: 4, tag: "[DEBUG]", color: "#50fa7b", ansi: "\e[1;32m"
  log_filter :trace, level: 5, tag: "[TRACE]", color: "#6272a4", ansi: "\e[90m"
  log_filter :internal, level: 6, tag: "[INTERNAL]", color: "#bd93f9", ansi: "\e[35m"
end

# Re-export at top-level for maximum ergonomics
macro log_filter(name, **opts)
  ::Godot.log_filter({{name}}, {{opts.double_splat}})
end

macro define_log_filter(name, **opts)
  ::Godot.log_filter({{name}}, {{opts.double_splat}})
end

macro define_log_filters(&block)
  ::Godot.define_log_filters do
    {{yield}}
  end
end

macro finished
  module Godot
    # **LogLevel**: Unified typed enum containing core severity levels and user-defined log categories.
    enum LogLevel : UInt8
      {%
        seen = {} of String => Bool
        unique_filters = [] of ASTNode
      %}
      {% for k in ::Godot::LogFilterRegistry.all_subclasses %}
        {%
          ann = k.annotation(::Godot::LogFilterMeta)
          if ann
            key = ann[:name].downcase
            unless seen[key]
              seen[key] = true
              unique_filters << k
            end
          end
        %}
      {% end %}

      {% for k, idx in unique_filters %}
        {% ann = k.annotation(::Godot::LogFilterMeta) %}
        {{ann[:name].camelcase.id}} = {{ann[:level] || (idx + 10)}}
      {% end %}

      # Returns the bracketed log tag (e.g. "[ERROR]", "{spoiler}")
      def tag : String
        case self
        {% for k in unique_filters %}
          {% ann = k.annotation(::Godot::LogFilterMeta) %}
          in {{ann[:name].camelcase.id}}
            {{ann[:tag]}}
        {% end %}
        end
      end

      # Returns the clean uppercase identifier tag (e.g. "ERROR", "SPOILER")
      def name_tag : String
        case self
        {% for k in unique_filters %}
          {% ann = k.annotation(::Godot::LogFilterMeta) %}
          in {{ann[:name].camelcase.id}}
            {{ann[:name_tag]}}
        {% end %}
        end
      end

      # Returns the BBCode color string for rich UI display (e.g. "#ff5555")
      def color_bbcode : String
        case self
        {% for k in unique_filters %}
          {% ann = k.annotation(::Godot::LogFilterMeta) %}
          in {{ann[:name].camelcase.id}}
            {{ann[:color]}}
        {% end %}
        end
      end

      # Returns the ANSI color escape sequence for terminal output
      def ansi_color : String
        case self
        {% for k in unique_filters %}
          {% ann = k.annotation(::Godot::LogFilterMeta) %}
          in {{ann[:name].camelcase.id}}
            {{ann[:ansi]}}
        {% end %}
        end
      end

      # Returns the numeric severity level (1: Error, 2: Warn, 3: Info, 4: Debug, 5: Trace, etc.)
      def severity : Int32
        case self
        {% for k in unique_filters %}
          {% ann = k.annotation(::Godot::LogFilterMeta) %}
          in {{ann[:name].camelcase.id}}
            {{ann[:level] || 3}}
        {% end %}
        end
      end

      def <=>(other : LogLevel) : Int32
        severity <=> other.severity
      end

      def <(other : LogLevel) : Bool
        severity < other.severity
      end

      def <=(other : LogLevel) : Bool
        severity <= other.severity
      end

      def >(other : LogLevel) : Bool
        severity > other.severity
      end

      def >=(other : LogLevel) : Bool
        severity >= other.severity
      end

      # Scans a raw log line string and extracts the matching enum category if present.
      # User-defined custom tags are evaluated first so specific categories (like {spoiler})
      # take precedence over generic severity tags (like [INFO]).
      def self.from_line(line : String, default : LogLevel? = nil) : LogLevel?
        {% for k in unique_filters %}
          {% ann = k.annotation(::Godot::LogFilterMeta) %}
          {% unless ["off", "error", "warn", "info", "debug", "trace", "internal"].includes?(ann[:name].downcase) %}
            return LogLevel::{{ann[:name].camelcase.id}} if line.includes?({{ann[:tag]}}) || line.includes?({{ann[:name_tag]}})
          {% end %}
        {% end %}
        {% for k in unique_filters %}
          {% ann = k.annotation(::Godot::LogFilterMeta) %}
          {% if ["off", "error", "warn", "info", "debug", "trace", "internal"].includes?(ann[:name].downcase) %}
            return LogLevel::{{ann[:name].camelcase.id}} if line.includes?({{ann[:tag]}}) || line.includes?({{ann[:name_tag]}})
          {% end %}
        {% end %}
        default
      end

      # Returns all registered bracketed tag strings
      def self.all_tags : Array(String)
        [
          {% for k in unique_filters %}
            {% ann = k.annotation(::Godot::LogFilterMeta) %}
            {{ann[:tag]}},
          {% end %}
        ]
      end

      # Returns all registered clean uppercase name tags
      def self.all_name_tags : Array(String)
        [
          {% for k in unique_filters %}
            {% ann = k.annotation(::Godot::LogFilterMeta) %}
            {{ann[:name_tag]}},
          {% end %}
        ]
      end

      # Case-insensitive parser supporting names, tags, numbers, and aliases
      def self.parse?(str : String) : LogLevel?
        norm = str.strip.downcase
        return nil if norm.empty?

        case norm
        when "none", "0"     then LogLevel::Off
        when "err", "1"      then LogLevel::Error
        when "warning", "2"  then LogLevel::Warn
        when "3"             then LogLevel::Info
        when "4"             then LogLevel::Debug
        when "5"             then LogLevel::Trace
        when "gc", "6"       then LogLevel::Internal
        {% for k in unique_filters %}
          {% ann = k.annotation(::Godot::LogFilterMeta) %}
          when {{ann[:name].downcase}}
            LogLevel::{{ann[:name].camelcase.id}}
          {% if ann[:name_tag].downcase != ann[:name].downcase %}
            when {{ann[:name_tag].downcase}}
              LogLevel::{{ann[:name].camelcase.id}}
          {% end %}
        {% end %}
        else
          nil
        end
      end
    end
  end
end
