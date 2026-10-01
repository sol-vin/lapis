require "./level"

module Godot
  # Represents a single structured diagnostic log record with optional security / metadata tags
  struct LogRecord
    getter timestamp : ::Time
    getter level : LogLevel
    getter channel : String
    getter message : String
    getter file : String
    getter line : Int32
    getter function : String
    getter tags : Array(String)
    getter status : String

    def initialize(
      @level : LogLevel,
      @channel : String,
      @message : String,
      @file : String = "",
      @line : Int32 = 0,
      @function : String = "",
      @tags : Array(String) = [] of String,
      @status : String = "",
      @timestamp : ::Time = ::Time.local
    )
    end

    def has_tag?(tag : String) : Bool
      @tags.any? { |t| t.downcase == tag.downcase }
    end

    def has_status? : Bool
      !@status.empty?
    end

    def status?(expected : String) : Bool
      @status.downcase == expected.downcase
    end

    # Returns true if this record is safe for public distribution (marked public or public channel)
    def public? : Bool
      status?("public") || has_tag?("public") || @channel.downcase == "public"
    end

    # Returns true if this record is marked internal or contains secret/confidential tags or statuses
    def confidential? : Bool
      status?("secret") || status?("confidential") || status?("internal") || status?("spoiler") ||
        has_tag?("secret") || has_tag?("confidential") || has_tag?("internal") || has_tag?("spoiler") ||
        @channel.downcase == "internal"
    end

    # Format: [2026-09-28 18:56:12.345] [LEVEL] [Channel] {status} <tag1,tag2> Message (file:line)
    def to_formatted_string(include_location : Bool = false) : String
      time_str = @timestamp.to_s("%Y-%m-%d %H:%M:%S.%3N")
      loc_str = (include_location && !@file.empty? && @line > 0) ? " (#{@file}:#{@line})" : ""
      status_str = @status.empty? ? "" : " {#{@status}}"
      tag_str = @tags.empty? ? "" : " <#{@tags.join(",")}>"
      "[#{time_str}] [#{@level.name_tag}] [#{@channel}]#{status_str}#{tag_str} #{@message}#{loc_str}"
    end

    def to_bbcode(include_location : Bool = true) : String
      time_str = @timestamp.to_s("%H:%M:%S.%3N")
      loc_str = (include_location && !@file.empty? && @line > 0) ? " [color=#778899](#{@file}:#{@line})[/color]" : ""
      status_str = @status.empty? ? "" : " [color=#50fa7b]{#{@status}}[/color]"
      tag_str = @tags.empty? ? "" : " [color=#ffb86c]<#{@tags.join(",")}>[/color]"
      "[color=#778899][#{time_str}][/color] [color=#{@level.color_bbcode}][#{@level.name_tag}][/color] [color=#8be9fd][#{@channel}][/color]#{status_str}#{tag_str} [color=#f8f8f2]#{@message}[/color]#{loc_str}"
    end

    def to_ansi(include_location : Bool = false) : String
      time_str = @timestamp.to_s("%H:%M:%S.%3N")
      loc_str = (include_location && !@file.empty? && @line > 0) ? " \e[90m(#{@file}:#{@line})\e[0m" : ""
      status_str = @status.empty? ? "" : " \e[32m{#{@status}}\e[0m"
      tag_str = @tags.empty? ? "" : " \e[33m<#{@tags.join(",")}>\e[0m"
      "\e[90m[#{time_str}]\e[0m #{@level.ansi_color}[#{@level.name_tag}]\e[0m \e[36m[#{@channel}]\e[0m#{status_str}#{tag_str} #{@message}#{loc_str}"
    end
  end
end
