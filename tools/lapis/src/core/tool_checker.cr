require "./env"
require "./process_runner"
require "./logger"

module Lapis
  module Core
    module ToolChecker
      {% begin %}
        {%
          shard_content = read_file("#{__DIR__}/../../../../shard.yml")
          crystal_line = ""
          lines = shard_content.split("\n")
        %}
        {% for line in lines %}
          {% if line.strip.starts_with?("crystal:") %}
            {% crystal_line = line.strip %}
          {% end %}
        {% end %}
        {%
          min_ver = "1.20.0"
          target_ver = "1.21.0"
          if crystal_line.size > 0
            val = crystal_line.split(":")[1].gsub(/["'\r\n]/, "").strip
            if val.includes?(">=")
              parts = val.split(",")
            else
              parts = [val]
            end
          else
            parts = [] of String
          end
        %}
        {% for p in parts %}
          {%
            trimmed = p.strip
            if trimmed.starts_with?(">=")
              min_ver = trimmed.gsub(/>=/, "").strip
            elsif trimmed.starts_with?("<=")
              target_ver = trimmed.gsub(/<=/, "").strip
            elsif trimmed.size > 0 && !trimmed.includes?(">") && !trimmed.includes?("<")
              min_ver = trimmed
              target_ver = trimmed
            end
          %}
        {% end %}
        MIN_CRYSTAL_VERSION = {{ min_ver }}
        TARGET_CRYSTAL_VERSION = {{ target_ver }}
      {% end %}

      record ToolStatus,
        name : String,
        installed : Bool,
        version : String?,
        supported : Bool,
        path : String?,
        message : String,
        required : Bool = true

      # Parses semver into numeric components [major, minor, patch]
      def self.parse_semver(ver_str : String) : Tuple(Int32, Int32, Int32)
        # Extract digits like 1.21.0 from "Crystal 1.21.0 [57cf7da]..."
        if m = ver_str.match(/(\d+)\.(\d+)(?:\.(\d+))?/)
          major = m[1].to_i
          minor = m[2].to_i
          patch = m[3]?.try(&.to_i) || 0
          {major, minor, patch}
        else
          {0, 0, 0}
        end
      end

      # Compares two semver tuples. Returns > 0 if a > b, 0 if a == b, < 0 if a < b
      def self.compare_semver(a : String, b : String) : Int32
        ma, na, pa = parse_semver(a)
        mb, nb, pb = parse_semver(b)
        if ma != mb
          ma <=> mb
        elsif na != nb
          na <=> nb
        else
          pa <=> pb
        end
      end

      def self.crystal_version_supported?(detected : String, min_ver : String = MIN_CRYSTAL_VERSION) : Bool
        compare_semver(detected, min_ver) >= 0
      end

      def self.find_crystal : String?
        ProcessRunner.find_executable("crystal")
      end

      def self.get_crystal_version(crystal_bin : String) : String?
        res = ProcessRunner.capture(crystal_bin, ["--version"])
        if res[:status].success?
          output = res[:output].strip
          if m = output.match(/Crystal\s+([0-9]+\.[0-9]+\.[0-9]+)/i)
            m[1]
          else
            output.lines.first?
          end
        else
          nil
        end
      rescue
        nil
      end

      def self.find_make : String?
        candidates = ["make", "mingw32-make"]
        candidates.each do |cand|
          if path = ProcessRunner.find_executable(cand)
            return path
          end
        end
        nil
      end

      def self.get_make_version(make_bin : String) : String?
        res = ProcessRunner.capture(make_bin, ["--version"])
        if res[:status].success?
          res[:output].lines.first?.try(&.strip)
        else
          nil
        end
      rescue
        nil
      end

      def self.check_crystal : ToolStatus
        crystal_path = find_crystal
        unless crystal_path
          return ToolStatus.new(
            name: "crystal",
            installed: false,
            version: nil,
            supported: false,
            path: nil,
            message: "Crystal compiler ('crystal') was not found in PATH. Please install Crystal #{MIN_CRYSTAL_VERSION}+ (e.g. via Scoop on Windows, Homebrew on macOS, or your system package manager)."
          )
        end

        detected_ver = get_crystal_version(crystal_path)
        unless detected_ver
          return ToolStatus.new(
            name: "crystal",
            installed: true,
            version: "unknown",
            supported: false,
            path: crystal_path,
            message: "Crystal binary found at #{crystal_path}, but failed to query 'crystal --version'."
          )
        end

        if crystal_version_supported?(detected_ver, MIN_CRYSTAL_VERSION)
          ToolStatus.new(
            name: "crystal",
            installed: true,
            version: detected_ver,
            supported: true,
            path: crystal_path,
            message: "Crystal #{detected_ver} verified at #{crystal_path} (minimum: #{MIN_CRYSTAL_VERSION}, target: #{TARGET_CRYSTAL_VERSION})."
          )
        else
          ToolStatus.new(
            name: "crystal",
            installed: true,
            version: detected_ver,
            supported: false,
            path: crystal_path,
            message: "Crystal version #{detected_ver} at #{crystal_path} is below the minimum required version #{MIN_CRYSTAL_VERSION}. Please upgrade Crystal."
          )
        end
      end

      def self.check_make : ToolStatus
        make_path = find_make
        unless make_path
          return ToolStatus.new(
            name: "make",
            installed: false,
            version: nil,
            supported: false,
            path: nil,
            message: "GNU Make ('make') was not found in PATH. Please install Make (e.g. via Scoop 'scoop install make' on Windows, or build-essential on Linux) to compile projects and run build automation."
          )
        end

        ver = get_make_version(make_path) || "present"
        ToolStatus.new(
          name: "make",
          installed: true,
          version: ver,
          supported: true,
          path: make_path,
          message: "GNU Make verified at #{make_path} (#{ver})."
        )
      end

      def self.find_lldb : String?
        if path = ProcessRunner.find_executable("lldb")
          return path
        end

        {% if flag?(:windows) %}
          user_profile = ENV["USERPROFILE"]? || ""
          candidates = [
            "C:\\Program Files\\LLVM\\bin\\lldb.exe",
            "C:\\Program Files (x86)\\LLVM\\bin\\lldb.exe",
            "C:\\ProgramData\\llvm\\bin\\lldb.exe",
            File.join(user_profile, "scoop", "apps", "llvm", "current", "bin", "lldb.exe"),
            "C:\\Program Files\\Microsoft Visual Studio\\2022\\Community\\VC\\Tools\\Llvm\\bin\\lldb.exe",
            "C:\\Program Files\\Microsoft Visual Studio\\2022\\Professional\\VC\\Tools\\Llvm\\bin\\lldb.exe",
            "C:\\Program Files\\Microsoft Visual Studio\\2022\\Enterprise\\VC\\Tools\\Llvm\\bin\\lldb.exe",
            "C:\\Program Files (x86)\\Microsoft Visual Studio\\2022\\BuildTools\\VC\\Tools\\Llvm\\bin\\lldb.exe",
          ]
          candidates.each do |cand|
            return cand if File.exists?(cand)
          end
        {% end %}
        nil
      end

      def self.get_lldb_version(lldb_bin : String) : String?
        res = ProcessRunner.capture(lldb_bin, ["--version"])
        if res[:status].success?
          res[:output].lines.first?.try(&.strip)
        else
          nil
        end
      rescue
        nil
      end

      def self.check_lldb : ToolStatus
        lldb_path = find_lldb
        unless lldb_path
          return ToolStatus.new(
            name: "lldb",
            installed: false,
            version: nil,
            supported: false,
            path: nil,
            message: "LLDB debugger ('lldb') was not found. Install LLVM (e.g. 'winget install LLVM.LLVM' or 'scoop install llvm' on Windows, 'apt install lldb' on Linux) for native Crystal debugging.",
            required: false
          )
        end

        ver = get_lldb_version(lldb_path) || "present"
        ToolStatus.new(
          name: "lldb",
          installed: true,
          version: ver,
          supported: true,
          path: lldb_path,
          message: "LLDB debugger verified at #{lldb_path} (#{ver}).",
          required: false
        )
      end

      def self.find_git : String?
        ProcessRunner.find_executable("git")
      end

      def self.get_git_version(git_bin : String) : String?
        res = ProcessRunner.capture(git_bin, ["--version"])
        if res[:status].success?
          res[:output].lines.first?.try(&.strip)
        else
          nil
        end
      rescue
        nil
      end

      def self.check_git : ToolStatus
        git_path = find_git
        unless git_path
          return ToolStatus.new(
            name: "git",
            installed: false,
            version: nil,
            supported: false,
            path: nil,
            message: "Git ('git') was not found in PATH. Please install Git (e.g. 'winget install Git.Git' on Windows, or your system package manager) for dependency management."
          )
        end

        ver = get_git_version(git_path) || "present"
        ToolStatus.new(
          name: "git",
          installed: true,
          version: ver,
          supported: true,
          path: git_path,
          message: "Git verified at #{git_path} (#{ver})."
        )
      end

      def self.find_crystalline : String?
        if path = ProcessRunner.find_executable("crystalline")
          return path
        end

        root = Env::ROOT_DIR
        local_bin = root.join("bin", "crystalline#{Env.exe_ext}")
        return local_bin.to_s if File.exists?(local_bin)

        {% if flag?(:windows) %}
          user_profile = ENV["USERPROFILE"]? || ""
          local_app_data = ENV["LOCALAPPDATA"]? || ""
          candidates = [
            File.join(local_app_data, "Programs", "Lapis", "bin", "crystalline.exe"),
            File.join(user_profile, "scoop", "shims", "crystalline.exe"),
            File.join(user_profile, "scoop", "apps", "crystalline", "current", "crystalline.exe"),
            "C:\\Program Files\\crystalline\\bin\\crystalline.exe",
            "C:\\crystalline\\bin\\crystalline.exe",
          ]
          candidates.each do |cand|
            return cand if File.exists?(cand)
          end
        {% else %}
          user_bin = File.join(Path.home, ".local", "bin", "crystalline")
          return user_bin if File.exists?(user_bin)
          if File.exists?("/usr/local/bin/crystalline")
            return "/usr/local/bin/crystalline"
          end
        {% end %}
        nil
      end

      def self.get_crystalline_version(crystalline_bin : String) : String?
        res = ProcessRunner.capture(crystalline_bin, ["--version"])
        if res[:status].success?
          res[:output].lines.first?.try(&.strip)
        else
          nil
        end
      rescue
        nil
      end

      def self.check_crystalline : ToolStatus
        c_path = find_crystalline
        unless c_path
          return ToolStatus.new(
            name: "crystalline",
            installed: false,
            version: nil,
            supported: false,
            path: nil,
            message: "Crystalline LSP ('crystalline') was not found. Install Crystalline from GitHub releases (or via 'lapis setup --lsp') for Godot in-editor Crystal autocompletion & diagnostics.",
            required: false
          )
        end

        ver = get_crystalline_version(c_path) || "present"
        ToolStatus.new(
          name: "crystalline",
          installed: true,
          version: ver,
          supported: true,
          path: c_path,
          message: "Crystalline LSP verified at #{c_path} (#{ver}).",
          required: false
        )
      end

      def self.check_all : Array(ToolStatus)
        [check_crystal, check_lldb, check_make, check_git, check_crystalline]
      end

      # Validates tools and logs any errors or warnings. Returns true if all required tools pass (or all tools if strict: true).
      def self.verify_all(strict : Bool = false) : Bool
        statuses = check_all
        all_passed = true

        statuses.each do |status|
          is_required = strict || status.required
          if status.installed && status.supported
            Logger.debug("Tool check passed: #{status.name} -> #{status.message}")
          else
            if is_required
              all_passed = false
              Logger.error("Required tool check failed: #{status.message}")
            else
              Logger.warn("Tool check notice: #{status.message}")
            end
          end
        end

        all_passed
      end
    end
  end
end
