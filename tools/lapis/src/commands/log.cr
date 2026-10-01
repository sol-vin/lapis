require "../core/env"
require "../core/logger"
require "../core/text"
require "file_utils"
require "compress/zip"
require "opal"

module Lapis
  module Commands
    module Log
      def self.print_help : Void
        puts <<-HELP
=== Lapis: Project & Toolchain Log Manager ===

Usage:
  lapis log [command] [target] [options]

Commands:
  lapis log                      Show status of logs, channels, and active filters
  lapis log channels             List registered log channels and their status
  lapis log filters              List available filter rules (public, safe, no_spoilers, etc.)
  lapis log tail [target]        Stream log output (supports -f / --follow)
  lapis log view [target]        View log contents
  lapis log clean                Clear or truncate old log files (--force to skip prompt)
  lapis log search <pattern>     Regex search across all logs
  lapis log export [--zip]       Bundle logs into a timestamped zip archive
  lapis log crash                Display details and callstack of most recent crash

Targets:
  editor        Editor session logs (log/editor.log)
  game          Game runtime logs (log/game.log)
  build         Compiler and build logs (log/build.log)
  test          Test runner logs (log/test.log)
  bridge        C++ GDExtension bridge traces (log/bridge.log)
  crash         Crash dumps and backtrace snapshots (log/crash.log)
  public        Public sanitized logs (log/public.log)
  all           All active logs in project (default)

Options:
  --crystal                      Select Crystal verbose trace log (e.g. editor-crystal.log)
  --both                         Multiplex both engine log and Crystal trace log
  --public                       Apply public filter (only show public logs and errors, hiding secret game info)
  -s, --status=STATUS            Filter by user-defined status (e.g. public, verified, active)
  -F, --filter=NAME              Filter by named or custom filter (e.g. public, safe, no_spoilers)
  -f, --follow                   Follow new log entries in real-time (tail -f)
  -n, --lines=N                  Number of lines to output (default: 50)
  -l, --level=LEVEL              Filter by minimum level (error, warn, info, debug, trace)
  -c, --channel=CHANNEL          Filter by specific channel (e.g. Bridge, Inspector, Public)
  -h, --help                     Show this help screen
HELP
      end

      def self.run(args : Array(String)) : Int32
        if args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        root = Core::Env::ROOT_DIR
        log_dir = resolve_log_dir(root)

        if args.empty?
          return show_status(log_dir)
        end

        subcommand = args[0].downcase

        case subcommand
        when "status", "list", "ls"
          show_status(log_dir)
        when "channels", "ch"
          show_channels
        when "filters", "filt"
          show_filters
        when "tail"
          run_tail(log_dir, args[1..])
        when "view", "cat", "show"
          run_view(log_dir, args[1..])
        when "clean", "clear", "purge"
          run_clean(log_dir, args[1..])
        when "search", "grep", "find"
          run_search(log_dir, args[1..])
        when "export", "zip", "bundle"
          run_export(log_dir, args[1..])
        when "crash", "dump", "backtrace"
          run_crash(log_dir, args[1..])
        else
          # If first arg is a known target, treat as 'view' or 'tail'
          if known_target?(subcommand)
            run_view(log_dir, args)
          else
            Core::Logger.error("Unknown log command: '#{subcommand}'")
            print_help
            1
          end
        end
      end

      private def self.resolve_log_dir(root : Path) : Path
        # Check current working directory first
        cwd_log = Path.new("log")
        return cwd_log if Dir.exists?(cwd_log)

        # Fall back to root log directory
        root_log = root.join("log")
        FileUtils.mkdir_p(root_log) unless Dir.exists?(root_log)
        root_log
      end

      private def self.known_target?(target : String) : Bool
        {"editor", "game", "build", "test", "bridge", "crash", "public", "all"}.includes?(target)
      end

      private def self.glob_logs(log_dir : Path) : Array(String)
        posix_dir = log_dir.expand.to_s.gsub('\\', '/')
        Dir.glob("#{posix_dir}/*.log")
      end

      # =========================================================================
      # 1. Log Status & File Summaries
      # =========================================================================
      private def self.show_status(log_dir : Path) : Int32
        puts "\e[1;36m=== Lapis Diagnostic Logs: #{log_dir} ===\e[0m\n"
        log_files = glob_logs(log_dir).sort
        if File.exists?("crash_dump.log") && !log_files.includes?(File.expand_path("crash_dump.log"))
          log_files << "crash_dump.log"
        end

        if log_files.empty?
          puts "  \e[90m(no log files found in #{log_dir})\e[0m\n"
          return 0
        end

        printf("  %-24s %-12s %-10s %s\n", "Log File", "Size", "Lines", "Last Modified")
        printf("  %-24s %-12s %-10s %s\n", "--------", "----", "-----", "-------------")

        total_bytes = 0_i64
        total_lines = 0

        log_files.each do |filepath|
          filename = Path.new(filepath).basename
          size = File.size(filepath) rescue 0_i64
          total_bytes += size
          line_count = count_lines(filepath)
          total_lines += line_count
          mtime = File.info(filepath).modification_time.to_s("%Y-%m-%d %H:%M:%S") rescue "N/A"

          size_str = format_bytes(size)
          printf("  %-24s %-12s %-10d %s\n", filename, size_str, line_count, mtime)
        end

        puts
        printf("  \e[1mTotal:\e[0m %d files, %s, %d lines\n\n", log_files.size, format_bytes(total_bytes), total_lines)

        puts "\e[1;36m=== Standard Diagnostic Channels & Filters ===\e[0m"
        printf("  %-16s %-16s %s\n", "Channel", "Status", "Filter Policy")
        printf("  %-16s %-16s %s\n", "-------", "------", "-------------")
        printf("  %-16s %-16s %s\n", "public", "[public_safe]", "errors_only + custom:public (strictly blocks secret game info)")
        printf("  %-16s %-16s %s\n", "editor", "[active]", "unfiltered (mirrors Godot console and Crystal trace)")
        printf("  %-16s %-16s %s\n", "game", "[active]", "unfiltered runtime logs")
        printf("  %-16s %-16s %s\n", "bridge", "[active]", "GDExtension loader and C-API bridge traces")
        printf("  %-16s %-16s %s\n\n", "crash", "[standby]", "Windows VEH 0xC0000005 crash handler & ring buffer")
        0
      end

      # =========================================================================
      # 1b. Channels & Filters Introspection
      # =========================================================================
      private def self.show_channels : Int32
        puts "\e[1;36m=== Lapis Log Channels ===\e[0m\n"
        printf("  %-18s %-18s %-12s %s\n", "Channel Name", "Default Status", "Min Level", "Description")
        printf("  %-18s %-18s %-12s %s\n", "------------", "--------------", "---------", "-----------")
        printf("  %-18s %-18s %-12s %s\n", "public", "public_release", "Error", "Sanitized channel for public distribution / bug reports")
        printf("  %-18s %-18s %-12s %s\n", "editor", "active", "Trace", "Godot editor session and in-editor @tool logs")
        printf("  %-18s %-18s %-12s %s\n", "game", "active", "Trace", "Standalone runtime gameplay logs")
        printf("  %-18s %-18s %-12s %s\n", "bridge", "active", "Trace", "C++ GDExtension bridge calls and symbol resolutions")
        printf("  %-18s %-18s %-12s %s\n", "test", "active", "Trace", "Automated spec runner and test suite executions")
        printf("  %-18s %-18s %-12s %s\n\n", "crash", "standby", "Error", "VEH pre-crash ring buffer dump on fatal exception")
        puts "  \e[90mUsers can define custom channels via `Godot.configure_channel(\"name\", status: \"...\", min_level: ...)`\e[0m\n"
        0
      end

      private def self.show_filters : Int32
        puts "\e[1;36m=== Lapis Log Filter Rules ===\e[0m\n"
        printf("  %-18s %-20s %s\n", "Filter Name", "Target", "Rule Definition")
        printf("  %-18s %-20s %s\n", "-----------", "------", "---------------")
        printf("  %-18s %-20s %s\n", "public", "Public channels & sinks", "Allows Error logs OR public tagged/status; drops <secret>, <confidential>")
        printf("  %-18s %-20s %s\n", "safe", "Security sanitization", "Drops passwords, secrets, api_key, private_key tokens")
        printf("  %-18s %-20s %s\n", "errors_only", "Error triage", "Only permits records with level <= Error")
        printf("  %-18s %-20s %s\n", "warn_and_error", "Warning triage", "Only permits records with level <= Warn")
        printf("  %-18s %-20s %s\n\n", "no_spoilers", "Streamer safe / Story", "Drops records with status 'spoiler', tag 'spoiler', or 'spoiler:' prefix")
        puts "  \e[90mUsers can register custom filters via `Godot.register_filter(\"name\") { |rec| ... }`\e[0m\n"
        0
      end

      # =========================================================================
      # 2. Log Tail & Real-Time Follow
      # =========================================================================
      private def self.run_tail(log_dir : Path, args : Array(String)) : Int32
        target = "editor"
        follow = false
        lines_count = 50
        crystal_mode = false
        both_mode = false
        level_filter : String? = nil
        channel_filter : String? = nil
        status_filter : String? = nil
        custom_filter : String? = nil

        i = 0
        while i < args.size
          arg = args[i]
          case arg
          when "-f", "--follow"
            follow = true
          when "--crystal"
            crystal_mode = true
          when "--both"
            both_mode = true
          when "--public"
            custom_filter = "public"
          when "-s", "--status"
            if i + 1 < args.size
              status_filter = args[i + 1]
              i += 1
            end
          when .starts_with?("--status=")
            status_filter = arg[9..]
          when "-F", "--filter"
            if i + 1 < args.size
              custom_filter = args[i + 1]
              i += 1
            end
          when .starts_with?("--filter=")
            custom_filter = arg[9..]
          when "-n", "--lines"
            if i + 1 < args.size
              lines_count = args[i + 1].to_i? || 50
              i += 1
            end
          when .starts_with?("-n=")
            lines_count = arg[3..].to_i? || 50
          when .starts_with?("--lines=")
            lines_count = arg[8..].to_i? || 50
          when "-l", "--level"
            if i + 1 < args.size
              level_filter = args[i + 1].upcase
              i += 1
            end
          when .starts_with?("--level=")
            level_filter = arg[8..].upcase
          when "-c", "--channel"
            if i + 1 < args.size
              channel_filter = args[i + 1].downcase
              i += 1
            end
          when .starts_with?("--channel=")
            channel_filter = arg[10..].downcase
          else
            target = arg unless arg.starts_with?("-")
          end
          i += 1
        end

        files_to_tail = resolve_target_files(log_dir, target, crystal_mode, both_mode)
        if files_to_tail.empty?
          Core::Logger.error("No log files matching target '#{target}' in #{log_dir}")
          return 1
        end

        filter_note = custom_filter ? " [filter: #{custom_filter}]" : ""
        puts "\e[1;36m=== Tailing [#{target}] (#{files_to_tail.map { |f| Path.new(f).basename }.join(", ")})#{filter_note} ===\e[0m"
        puts "\e[90m(Press Ctrl+C to stop streaming)\e[0m\n" if follow

        # Print initial lines
        files_to_tail.each do |f|
          if File.exists?(f)
            lines = read_last_lines(f, lines_count)
            lines.each do |line|
              if matches_filters?(line, level_filter, channel_filter, custom_filter, status_filter)
                print_formatted_line(line, files_to_tail.size > 1 ? Path.new(f).basename : nil)
              end
            end
          end
        end

        return 0 unless follow

        # Follow mode (tail -f)
        file_positions = Hash(String, Int64).new
        files_to_tail.each do |f|
          file_positions[f] = File.size(f) rescue 0_i64
        end

        loop do
          files_to_tail.each do |f|
            next unless File.exists?(f)
            curr_size = File.size(f) rescue 0_i64
            last_pos = file_positions[f]? || 0_i64

            if curr_size < last_pos
              # File truncated / rotated
              file_positions[f] = 0_i64
              last_pos = 0_i64
            end

            if curr_size > last_pos
              File.open(f, "r") do |handle|
                handle.seek(last_pos)
                while line = handle.gets
                  if matches_filters?(line, level_filter, channel_filter, custom_filter, status_filter)
                    print_formatted_line(line, files_to_tail.size > 1 ? Path.new(f).basename : nil)
                  end
                end
                file_positions[f] = handle.pos
              end
            end
          end
          sleep 0.25.seconds
        end
        0
      rescue ex
        puts "\n\e[90m[Tail stopped]\e[0m"
        0
      end

      # =========================================================================
      # 3. Log View / Inspection
      # =========================================================================
      private def self.run_view(log_dir : Path, args : Array(String)) : Int32
        target = "editor"
        crystal_mode = false
        custom_filter : String? = nil
        status_filter : String? = nil

        i = 0
        while i < args.size
          a = args[i]
          if a == "--crystal"
            crystal_mode = true
          elsif a == "--public"
            custom_filter = "public"
          elsif a == "-s" || a == "--status"
            if i + 1 < args.size
              status_filter = args[i + 1]
              i += 1
            end
          elsif a.starts_with?("--status=")
            status_filter = a[9..]
          elsif a == "-F" || a == "--filter"
            if i + 1 < args.size
              custom_filter = args[i + 1]
              i += 1
            end
          elsif a.starts_with?("--filter=")
            custom_filter = a[9..]
          elsif !a.starts_with?("-")
            target = a
          end
          i += 1
        end

        files = resolve_target_files(log_dir, target, crystal_mode, false)

        if files.empty?
          Core::Logger.error("No log file found for target '#{target}' in #{log_dir}")
          return 1
        end

        target_file = files.first
        unless File.exists?(target_file)
          Core::Logger.warn("Log file does not exist yet: #{target_file}")
          return 0
        end

        filter_note = custom_filter ? " [filter: #{custom_filter}]" : ""
        status_note = status_filter ? " [status: #{status_filter}]" : ""
        puts "\e[1;36m=== Viewing: #{target_file} (#{format_bytes(File.size(target_file))})#{filter_note}#{status_note} ===\e[0m\n"

        filtered_lines = [] of String
        File.each_line(target_file) do |line|
          if matches_filters?(line, nil, nil, custom_filter, status_filter)
            filtered_lines << line
          end
        end

        if STDOUT.tty? && !ENV.has_key?("CI") && filtered_lines.size > 20
          selected = Opal.filter(
            items: filtered_lines,
            title: "Log Inspector: #{Path.new(target_file).basename}",
            preview: ->(l : String) {
              idx = filtered_lines.index(l) || 0
              s = Math.max(0, idx - 4)
              e = Math.min(filtered_lines.size - 1, idx + 8)
              filtered_lines[s..e].join("\n")
            }
          )
          if sel = selected
            puts "\nSelected entry:"
            print_formatted_line(sel)
          end
        else
          filtered_lines.each do |line|
            print_formatted_line(line)
          end
        end
        0
      end

      # =========================================================================
      # 4. Clean Logs
      # =========================================================================
      private def self.run_clean(log_dir : Path, args : Array(String)) : Int32
        force = args.includes?("-f") || args.includes?("--force") || args.includes?("-y")

        log_files = glob_logs(log_dir)
        if File.exists?("crash_dump.log")
          log_files << "crash_dump.log"
        end

        if log_files.empty?
          puts "Log directory #{log_dir} is already clean."
          return 0
        end

        unless force
          confirmed = if STDOUT.tty? && !ENV.has_key?("CI")
                        Opal.confirm("Purge #{log_files.size} log file(s) in #{log_dir}?", default: false)
                      else
                        print "Purge #{log_files.size} log file(s) in #{log_dir}? [y/N]: "
                        resp = gets
                        resp && resp.strip.downcase == "y"
                      end

          unless confirmed
            puts "Aborted."
            return 0
          end
        end

        purged = 0
        log_files.each do |f|
          begin
            File.delete(f)
            purged += 1
          rescue
          end
        end

        Core::Logger.success("Cleaned #{purged} log file(s) from #{log_dir}")
        0
      end

      # =========================================================================
      # 5. Search Across Logs
      # =========================================================================
      private def self.run_search(log_dir : Path, args : Array(String)) : Int32
        query = args.first?
        if !query || query.empty?
          Core::Logger.error("Please provide a search pattern: lapis log search <pattern>")
          return 1
        end

        regex = Regex.new(query, Regex::Options::IGNORE_CASE) rescue Regex.new(Regex.escape(query))
        log_files = glob_logs(log_dir)
        if File.exists?("crash_dump.log")
          log_files << "crash_dump.log"
        end

        total_matches = 0
        puts "\e[1;36m=== Searching logs for '#{query}' in #{log_dir} ===\e[0m\n"

        log_files.each do |filepath|
          filename = Path.new(filepath).basename
          file_matched = false

          line_num = 0
          File.each_line(filepath) do |line|
            line_num += 1
            if line =~ regex
              total_matches += 1
              unless file_matched
                puts "\e[1;34m--- #{filename} ---\e[0m"
                file_matched = true
              end
              colored_line = line.gsub(regex) { |m| "\e[1;31;43m#{m}\e[0m" }
              printf("  \e[90m%4d:\e[0m %s\n", line_num, colored_line)
            end
          end
          puts if file_matched
        end

        if total_matches == 0
          puts "  \e[90m(no matches found)\e[0m\n"
        else
          printf("Found \e[1;32m%d match(es)\e[0m across log files.\n", total_matches)
        end
        0
      end

      # =========================================================================
      # 6. Export Logs to Zip Archive (With Custom / Public Filter Sanitization)
      # =========================================================================
      private def self.run_export(log_dir : Path, args : Array(String)) : Int32
        timestamp = Time.local.to_s("%Y%m%d_%H%M%S")
        custom_filter : String? = nil

        args.each do |a|
          if a == "--public"
            custom_filter = "public"
          elsif a.starts_with?("--filter=")
            custom_filter = a[9..]
          end
        end

        suffix = custom_filter ? "_#{custom_filter}" : ""
        out_zip = log_dir.join("lapis_logs_#{timestamp}#{suffix}.zip")

        log_files = glob_logs(log_dir)
        if File.exists?("crash_dump.log")
          log_files << "crash_dump.log"
        end

        if log_files.empty?
          Core::Logger.warn("No logs to export in #{log_dir}")
          return 0
        end

        File.open(out_zip, "w") do |file|
          Compress::Zip::Writer.open(file) do |zip|
            log_files.each do |log_file|
              entry_name = Path.new(log_file).basename

              content = if custom_filter
                          # Sanitize lines based on filter (e.g. omitting secret game data)
                          filtered_lines = [] of String
                          File.each_line(log_file) do |line|
                            filtered_lines << line if matches_filters?(line, nil, nil, custom_filter)
                          end
                          filtered_lines.join("\n")
                        else
                          File.read(log_file)
                        end

              zip.add(entry_name, content)
            end

            # Add system diagnostic summary
            summary = <<-TXT
Lapis Diagnostic Export
Timestamp: #{Time.local}
Filter: #{custom_filter || "none (all logs included)"}
Platform: #{Core::Env.current_platform}
Root: #{Core::Env::ROOT_DIR}
Exported Files:
#{log_files.map { |f| "  - #{Path.new(f).basename} (#{File.size(f)} bytes)" }.join("\n")}
TXT
            zip.add("system_info.txt", summary)
          end
        end

        filter_note = custom_filter ? " [sanitized with '#{custom_filter}' filter]" : ""
        Core::Logger.success("Exported #{log_files.size} log(s) to #{out_zip} (#{format_bytes(File.size(out_zip))})#{filter_note}")
        0
      end

      # =========================================================================
      # 7. Crash Log Inspection
      # =========================================================================
      private def self.run_crash(log_dir : Path, args : Array(String)) : Int32
        candidates = [
          log_dir.join("crash.log").to_s,
          "crash_dump.log",
          log_dir.join("editor.log").to_s
        ]

        crash_file = candidates.find { |p| File.exists?(p) && File.size(p) > 0 }
        unless crash_file
          puts "\e[1;32m✓ No recent crash reports or access violations found.\e[0m"
          return 0
        end

        puts "\e[1;31m=== Recent Crash Diagnostic Report: #{crash_file} ===\e[0m\n"
        in_backtrace = false
        in_ring_buffer = false

        File.each_line(crash_file) do |line|
          if line.includes?("CRASH INTERCEPTED") || line.includes?("Exception Code")
            puts "\e[1;31m#{line}\e[0m"
          elsif line.includes?("CPU Registers:")
            puts "\e[1;33m#{line}\e[0m"
          elsif line.includes?("Callstack:")
            in_backtrace = true
            puts "\e[1;36m#{line}\e[0m"
          elsif line.includes?("Pre-Crash Ring Buffer")
            in_backtrace = false
            in_ring_buffer = true
            puts "\e[1;35m#{line}\e[0m"
          elsif in_backtrace
            puts "  \e[90m#{line.strip}\e[0m"
          elsif in_ring_buffer
            print_formatted_line(line)
          else
            puts line
          end
        end
        0
      end

      # =========================================================================
      # Helpers
      # =========================================================================
      private def self.resolve_target_files(log_dir : Path, target : String, crystal_mode : Bool, both_mode : Bool) : Array(String)
        res = [] of String
        case target.downcase
        when "editor"
          if both_mode
            res << log_dir.join("editor.log").to_s
            res << log_dir.join("editor-crystal.log").to_s
          elsif crystal_mode
            res << log_dir.join("editor-crystal.log").to_s
          else
            res << log_dir.join("editor.log").to_s
          end
        when "game"
          if both_mode
            res << log_dir.join("game.log").to_s
            res << log_dir.join("game-crystal.log").to_s
          elsif crystal_mode
            res << log_dir.join("game-crystal.log").to_s
          else
            res << log_dir.join("game.log").to_s
          end
        when "build"
          res << log_dir.join("build.log").to_s
        when "test"
          if both_mode
            res << log_dir.join("test.log").to_s
            res << log_dir.join("test-crystal.log").to_s
          elsif crystal_mode
            res << log_dir.join("test-crystal.log").to_s
          else
            res << log_dir.join("test.log").to_s
          end
        when "bridge"
          res << log_dir.join("bridge.log").to_s
        when "crash"
          res << log_dir.join("crash.log").to_s
          res << "crash_dump.log" if File.exists?("crash_dump.log")
        when "public"
          res << log_dir.join("public.log").to_s
        when "all"
          glob_logs(log_dir).each { |f| res << f }
        else
          # Check if target is a literal filename
          exact = log_dir.join(target.ends_with?(".log") ? target : "#{target}.log").to_s
          res << exact if File.exists?(exact)
        end
        res.uniq
      end

      private def self.count_lines(file : String) : Int32
        count = 0
        File.each_line(file) { count += 1 }
        count
      rescue
        0
      end

      private def self.read_last_lines(file : String, n : Int32) : Array(String)
        lines = [] of String
        File.each_line(file) do |line|
          lines << line
          lines.shift if lines.size > n
        end
        lines
      rescue
        [] of String
      end

      private def self.format_bytes(bytes : Int64) : String
        return "#{bytes} B" if bytes < 1024
        kb = bytes / 1024.0
        return sprintf("%.1f KB", kb) if kb < 1024
        mb = kb / 1024.0
        sprintf("%.1f MB", mb)
      end

      private def self.matches_filters?(
        line : String,
        level : String?,
        channel : String?,
        custom_filter : String? = nil,
        status_filter : String? = nil
      ) : Bool
        if l = level
          return false unless line.includes?("[#{l}]")
        end
        if c = channel
          return false unless line.downcase.includes?("[#{c}]")
        end
        if s = status_filter
          return false unless line.downcase.includes?("{#{s.downcase}}")
        end
        if filt = custom_filter
          case filt.downcase
          when "public"
            # Public filter: Allows error logs OR explicitly public records, while strictly rejecting secret/confidential lines
            has_error = line.includes?("[ERROR]")
            is_pub = line.includes?("[Public]") || line.includes?("<public>") || line.includes?("{public}")
            is_sec = line.includes?("<secret>") || line.includes?("<confidential>") || line.includes?("{secret}") || line.includes?("{confidential}") || line.includes?("[Internal]")
            return false unless (has_error || is_pub) && !is_sec
          when "safe", "security"
            # Sanitization filter: Rejects lines containing secret/confidential tags or sensitive credentials
            is_sec = line.includes?("<secret>") || line.includes?("<confidential>") || line.includes?("{secret}") || line.includes?("{confidential}") ||
                     line.downcase.includes?("password=") || line.downcase.includes?("secret=") ||
                     line.downcase.includes?("api_key=") || line.downcase.includes?("token=") ||
                     line.downcase.includes?("private_key")
            return false if is_sec
          when "no_spoilers"
            is_spoiler = line.includes?("{spoiler}") || line.includes?("<spoiler>") || line.downcase.includes?("spoiler:")
            return false if is_spoiler
          when "errors_only"
            return false unless line.includes?("[ERROR]")
          when "warn_and_error"
            return false unless line.includes?("[ERROR]") || line.includes?("[WARN]")
          else
            # Custom tag or substring check
            return false unless line.downcase.includes?(filt.downcase)
          end
        end
        true
      end

      private def self.print_formatted_line(line : String, prefix : String? = nil) : Void
        tag = prefix ? "\e[36m[#{prefix}]\e[0m " : ""
        # Colorize levels if present
        colored = line
          .gsub("[ERROR]", "\e[1;31m[ERROR]\e[0m")
          .gsub("[WARN]", "\e[1;33m[WARN]\e[0m")
          .gsub("[INFO]", "\e[1;36m[INFO]\e[0m")
          .gsub("[DEBUG]", "\e[1;32m[DEBUG]\e[0m")
          .gsub("[TRACE]", "\e[90m[TRACE]\e[0m")
          .gsub("[INTERNAL]", "\e[35m[INTERNAL]\e[0m")
        puts "#{tag}#{colored}"
      end
    end
  end
end
