module Godot
  # ===========================================================================
  # Godot Engine Logging & Diagnostics System
  # ===========================================================================

  # Prints a formatted message to the Godot console and standard output
  def self.print(*args)
    msg = args.join(" ")
    if Bridge.api && !Bridge.api.null?
      Bridge.print(msg)
    else
      puts msg
    end
  end

  # Prints an error message to the Godot console and standard error
  def self.printerr(*args)
    msg = args.join(" ")
    if Bridge.api && !Bridge.api.null?
      Bridge.printerr(msg)
    else
      STDERR.puts msg
    end
  end

  # Prints a rich structured error with function, file, and line details
  def self.print_error(msg : String, func : String = "", file : String = __FILE__, line : Int32 = __LINE__)
    if Bridge.api && !Bridge.api.null?
      Bridge.error(msg, "", func, file, line)
    else
      STDERR.puts "[ERROR] #{msg} (#{file}:#{line} in #{func})"
    end
  end

  # Prints a rich structured warning with function, file, and line details
  def self.print_warning(msg : String, func : String = "", file : String = __FILE__, line : Int32 = __LINE__)
    if Bridge.api && !Bridge.api.null?
      Bridge.warning(msg, "", func, file, line)
    else
      STDERR.puts "[WARNING] #{msg}"
    end
  end

  # Returns true if the engine was launched with verbose logging enabled (--verbose)
  def self.verbose? : Bool
    Bridge.verbose?
  end

  # Prints a verbose diagnostic message that only appears when verbose logging is active
  def self.print_verbose(*args)
    msg = args.join(" ")
    Bridge.print_verbose(msg)
  end

  # Alias for `print_verbose`
  def self.debug(*args)
    print_verbose(*args)
  end
end
