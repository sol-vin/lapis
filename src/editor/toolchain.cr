# =============================================================================
# LibGodot - Lapis CLI Toolchain Resolver & Command Interface
# =============================================================================
# Discovers and resolves the lapis CLI executable, queries toolchain versions,
# and prepares command arguments for builds, tests, benchmarks, and doctor diagnostics.
# =============================================================================

require "../lapis"

module Lapis
  module Toolchain
    # Resolves the path to the 'lapis' CLI executable
    def self.resolve_lapis_bin : String?
      # 1. Environment variable override
      if env_path = ::ENV["LAPIS_BIN"]?
        return File.expand_path(env_path) if File.exists?(env_path)
      end

      # 2. Local workspace and addon directories
      candidates = [
        "bin/lapis.exe", "bin/lapis",
        "../bin/lapis.exe", "../bin/lapis",
        "../../bin/lapis.exe", "../../bin/lapis",
        "addons/crystal_integration/bin/lapis.exe", "addons/crystal_integration/bin/lapis",
        "../addons/crystal_integration/bin/lapis.exe", "../addons/crystal_integration/bin/lapis",
      ]
      if found = candidates.find { |p| File.exists?(p) }
        return File.expand_path(found)
      end

      # 3. System PATH
      if sys_lapis = Process.find_executable("lapis")
        return sys_lapis
      end

      nil
    end

    # Checks if the lapis CLI toolchain is available on disk or PATH
    def self.has_lapis? : Bool
      !resolve_lapis_bin.nil?
    end

    # Returns the detected lapis toolchain version string
    def self.version : String
      if bin = resolve_lapis_bin
        out_io = IO::Memory.new
        res = Process.run(bin, ["--version"], output: out_io, error: out_io) rescue nil
        if res && res.success?
          v = out_io.to_s.strip
          return v unless v.empty?
        end
      end
      "v#{::Godot::VERSION}"
    end

    # Formats command arguments for compiling the game library
    def self.build_game_args(entry_file : String, out_dll : String, link_flags : String, is_release : Bool) : Array(String)
      args = ["build", "--entry", entry_file, "--output", out_dll, "--link-flags", link_flags]
      args << "--release" if is_release
      args
    end

    # Formats command arguments for rebuilding all addons
    def self.build_addons_args(is_release : Bool = false) : Array(String)
      args = ["build", "addons"]
      args << "--release" if is_release
      args
    end

    # Formats command arguments for running benchmarks
    def self.benchmarks_args(
      iterations : Int32 = 3,
      group_name : String? = nil,
      benchmark_name : String? = nil,
      category : String? = nil,
      all_languages : Bool = false
    ) : Array(String)
      args = ["benchmarks", "run", "html", "-i", iterations.to_s, "--no-tui"]
      args += ["-g", group_name] if group_name
      args += ["-f", benchmark_name] if benchmark_name
      args += ["-c", category] if category
      args << "--all-languages" if all_languages
      args
    end

    # Formats command arguments for running doctor diagnostics
    def self.doctor_args(autofix : Bool = false) : Array(String)
      autofix ? ["doctor", "autofix"] : ["doctor", "--verbose"]
    end

    # Formats command arguments for packaging a standalone game
    def self.package_args(project_dir : String = ".", release : Bool = true) : Array(String)
      args = ["package", "game", "-p", project_dir, "-f"]
      args << "-r" if release
      args
    end
  end
end
