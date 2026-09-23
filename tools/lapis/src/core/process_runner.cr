require "./logger"

module Lapis
  module Core
    module ProcessRunner
      # In-memory rolling line recorder that streams live bytes to a passthrough IO
      class TeeIO < IO
        getter captured_lines = Deque(String).new
        @current_line = IO::Memory.new
        @passthrough : IO?
        @max_lines : Int32

        def initialize(@passthrough : IO? = nil, @max_lines : Int32 = 80)
        end

        def read(slice : Bytes) : Int32
          raise IO::Error.new("Cannot read from TeeIO")
        end

        def write(slice : Bytes) : Nil
          @passthrough.try &.write(slice)
          @passthrough.try &.flush

          slice.each do |byte|
            if byte == '\n'.ord
              line = @current_line.to_s
              @current_line.clear
              @captured_lines.shift if @captured_lines.size >= @max_lines
              @captured_lines << line
            else
              @current_line.write_byte(byte) unless byte == '\r'.ord
            end
          end
        end

        def close : Nil
          if @current_line.size > 0
            line = @current_line.to_s
            @current_line.clear
            @captured_lines.shift if @captured_lines.size >= @max_lines
            @captured_lines << line
          end
          @passthrough.try &.flush
        end

        def excerpt : String
          @captured_lines.to_a.join("\n")
        end
      end

      # Run a command with streaming live output to STDOUT/STDERR while capturing trailing lines for error triage
      def self.run_with_capture(
        command : String,
        args : Array(String) = [] of String,
        env : Process::Env = nil,
        chdir : String? = nil,
        max_lines : Int32 = 80,
      ) : {status: Process::Status, error_excerpt: String?}
        actual_args = args.dup
        is_godot = Path.new(command).basename.downcase.starts_with?("godot")
        if is_godot && Logger.verbose? && !actual_args.includes?("--verbose") && !actual_args.includes?("-v")
          actual_args << "--verbose"
        end

        proc_env = Hash(String, String?).new
        env.try &.each { |k, v| proc_env[k] = v }
        if Logger.verbose?
          proc_env["LIBGODOT_VERBOSE"] = "1"
          proc_env["GODOT_VERBOSE"] = "1"
        end

        start_time = ::Time.instant
        Logger.debug("Executing (with live capture): #{command} #{actual_args.join(" ")} (chdir: #{chdir || Dir.current})")
        tee_out = TeeIO.new(STDOUT, max_lines)
        tee_err = TeeIO.new(STDERR, max_lines)

        status = Process.run(
          command: command,
          args: actual_args,
          env: proc_env,
          chdir: chdir,
          output: tee_out,
          error: tee_err
        )
        tee_out.close
        tee_err.close

        duration_ms = (::Time.instant - start_time).total_milliseconds
        exit_code = status.normal_exit? ? status.exit_code : -1
        Logger.trace("Process", "Completed #{Path.new(command).basename} -> exit #{exit_code} (#{duration_ms.round(1)}ms)")

        error_excerpt = nil
        unless status.success?
          err_text = tee_err.excerpt
          out_text = tee_out.excerpt
          error_excerpt = !err_text.strip.empty? ? err_text : out_text
        end

        {status: status, error_excerpt: error_excerpt}
      end

      # Run a command with streaming output to STDOUT/STDERR
      def self.run(
        command : String,
        args : Array(String) = [] of String,
        env : Process::Env = nil,
        chdir : String? = nil,
      ) : Process::Status
        actual_args = args.dup
        is_godot = Path.new(command).basename.downcase.starts_with?("godot")
        if is_godot && Logger.verbose? && !actual_args.includes?("--verbose") && !actual_args.includes?("-v")
          actual_args << "--verbose"
        end

        proc_env = Hash(String, String?).new
        env.try &.each { |k, v| proc_env[k] = v }
        if Logger.verbose?
          proc_env["LIBGODOT_VERBOSE"] = "1"
          proc_env["GODOT_VERBOSE"] = "1"
        end

        start_time = ::Time.instant
        Logger.debug("Executing: #{command} #{actual_args.join(" ")} (chdir: #{chdir || Dir.current})")
        status = Process.run(
          command: command,
          args: actual_args,
          env: proc_env,
          chdir: chdir,
          input: Process::Redirect::Inherit,
          output: Process::Redirect::Inherit,
          error: Process::Redirect::Inherit
        )
        duration_ms = (::Time.instant - start_time).total_milliseconds
        exit_code = status.normal_exit? ? status.exit_code : -1
        Logger.trace("Process", "Completed #{Path.new(command).basename} -> exit #{exit_code} (#{duration_ms.round(1)}ms)")
        status
      end

      # Run a command and capture STDOUT and STDERR as strings
      def self.capture(
        command : String,
        args : Array(String) = [] of String,
        env : Process::Env = nil,
        chdir : String? = nil,
      ) : {status: Process::Status, output: String, error: String}
        actual_args = args.dup
        is_godot = Path.new(command).basename.downcase.starts_with?("godot")
        if is_godot && Logger.verbose? && !actual_args.includes?("--verbose") && !actual_args.includes?("-v")
          actual_args << "--verbose"
        end

        proc_env = Hash(String, String?).new
        env.try &.each { |k, v| proc_env[k] = v }
        if Logger.verbose?
          proc_env["LIBGODOT_VERBOSE"] = "1"
          proc_env["GODOT_VERBOSE"] = "1"
        end

        start_time = ::Time.instant
        Logger.debug("Capturing: #{command} #{actual_args.join(" ")}")
        stdout = IO::Memory.new
        stderr = IO::Memory.new
        status = Process.run(
          command: command,
          args: actual_args,
          env: proc_env,
          chdir: chdir,
          output: stdout,
          error: stderr
        )
        duration_ms = (::Time.instant - start_time).total_milliseconds
        exit_code = status.normal_exit? ? status.exit_code : -1
        Logger.trace("Process", "Captured #{Path.new(command).basename} -> exit #{exit_code} (#{duration_ms.round(1)}ms)")
        {status: status, output: stdout.to_s, error: stderr.to_s}
      end

      # Find an executable in PATH or check if an absolute/relative path exists and is executable
      def self.find_executable(name : String) : String?
        # If it contains directory separators and exists
        if (name.includes?('/') || name.includes?('\\')) && File.exists?(name)
          return File.expand_path(name)
        end

        exts = Env.windows? ? [".exe", ".cmd", ".bat", ""] : [""]
        paths = (ENV["PATH"]? || "").split(Env.path_sep)

        paths.each do |p|
          next if p.empty?
          exts.each do |ext|
            candidate = Path.new(p).join("#{name}#{ext}")
            if File.exists?(candidate) && !Dir.exists?(candidate)
              return candidate.expand.to_s
            end
          end
        end

        nil
      end
    end
  end
end
