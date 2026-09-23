require "./env"
require "./process_runner"
require "./logger"

module Lapis
  module Core
    module GodotFinder
      EMBEDDED_GODOT_VERSION = {{
                                 read_file("#{__DIR__}/../../../../godot-version.yml").split("\n").find(&.includes?("version:")).split(":")[1].gsub(/["'\r\n]/, "").strip
                               }}

      # Determines the expected Godot version by checking project-local godot-version.yml,
      # repository root godot-version.yml, or falling back to compile-time EMBEDDED_GODOT_VERSION.
      def self.expected_version(project_dir : String? = nil) : String
        if project_dir
          p_yml = File.join(project_dir, "godot-version.yml")
          if File.exists?(p_yml)
            if v = read_version_file(p_yml)
              return v
            end
          end
        end

        root_yml = Env::ROOT_DIR.join("godot-version.yml").to_s
        if File.exists?(root_yml)
          if v = read_version_file(root_yml)
            return v
          end
        end

        EMBEDDED_GODOT_VERSION
      end

      # Reads the version string from a godot-version.yml file
      def self.read_version_file(path : String) : String?
        File.read_lines(path).each do |line|
          if line.includes?("version:")
            parts = line.split(":", 2)
            if parts.size == 2
              return parts[1].gsub(/["'\r\n]/, "").strip
            end
          end
        end
        nil
      rescue
        nil
      end

      # Queries the Godot binary using --version and returns the output string
      def self.get_version(binary_path : String) : String?
        return nil unless File.exists?(binary_path)
        res = ProcessRunner.capture(binary_path, ["--version"])
        if res[:status].success?
          ver = res[:output].strip
          ver = res[:error].strip if ver.empty?
          ver.empty? ? nil : ver
        else
          nil
        end
      rescue
        nil
      end

      # Tokenizes version strings (e.g. "4.8-dev6" -> ["4", "8", "dev6"])
      # and verifies that all expected components exist in the detected string.
      def self.version_matches?(detected : String, expected : String) : Bool
        exp_tokens = expected.split(/[\.-]/).map(&.strip.downcase).reject(&.empty?)
        det_tokens = detected.split(/[\.-]/).map(&.strip.downcase).reject(&.empty?)
        return false if exp_tokens.empty?

        exp_tokens.all? { |tok| det_tokens.includes?(tok) }
      end

      # Validates a Godot binary against the expected version.
      # Returns true if matched, false otherwise.
      def self.verify_version(binary_path : String, expected : String, strict : Bool = false) : Bool
        detected = get_version(binary_path)
        unless detected
          if strict
            Logger.error("Could not query Godot version from: #{binary_path}")
            return false
          else
            Logger.warn("Could not query Godot version from: #{binary_path}")
            return true
          end
        end

        if version_matches?(detected, expected)
          Logger.debug("Godot binary #{binary_path} matches target version #{expected} (detected: #{detected})")
          true
        else
          msg = "Godot engine version mismatch! Expected: #{expected}, but found: #{detected} at #{binary_path}"
          if strict
            Logger.error(msg)
            false
          else
            Logger.warn(msg)
            false
          end
        end
      end

      # Discovers the Godot executable. If custom_path is provided, it takes precedence.
      # When filter_version is true, candidates are checked against the expected version,
      # returning the candidate that matches.
      def self.resolve(custom_path : String? = nil, project_dir : String? = nil, filter_version : Bool = true) : String?
        target_version = expected_version(project_dir)

        if custom_path && !custom_path.empty?
          return File.expand_path(custom_path) if File.exists?(custom_path)
          return nil
        end

        exe_ext = Env.exe_ext

        p_candidates = [] of String
        if project_dir && !project_dir.empty?
          p_path = Path.new(project_dir)
          p_candidates << p_path.join("godot#{exe_ext}").to_s
          p_candidates << p_path.join("godot.exe").to_s
          p_candidates << p_path.join("godot").to_s
          p_candidates << p_path.join("..", "godot#{exe_ext}").to_s
          p_candidates << p_path.join("..", "godot.exe").to_s
          p_candidates << p_path.join("..", "godot").to_s
        end

        candidates = [] of String?
        candidates << ENV["GODOT"]?
        candidates << ENV["GODOT4"]?
        candidates << ENV["GODOT_BIN"]?
        candidates << ENV["GODOT4_BIN"]?
        p_candidates.each { |p| candidates << p }
        candidates << Env::ROOT_DIR.join("godot#{exe_ext}").to_s
        candidates << Env::ROOT_DIR.join("godot.exe").to_s
        candidates << Env::ROOT_DIR.join("godot").to_s
        candidates << Env::ROOT_DIR.join("..", "godot#{exe_ext}").to_s
        candidates << Env::ROOT_DIR.join("..", "godot.exe").to_s
        candidates << Env::ROOT_DIR.join("..", "godot").to_s
        candidates << ProcessRunner.find_executable("godot")
        candidates << ProcessRunner.find_executable("godot4")
        candidates << ProcessRunner.find_executable("godot.exe")

        valid_candidates = [] of String
        candidates.compact.each do |c|
          next if c.empty?
          if File.exists?(c) && !Dir.exists?(c)
            exp = File.expand_path(c)
            valid_candidates << exp unless valid_candidates.includes?(exp)
          end
        end

        return nil if valid_candidates.empty?

        if filter_version
          # Prefer candidate that matches target_version
          valid_candidates.each do |cand|
            if det = get_version(cand)
              if version_matches?(det, target_version)
                return cand
              end
            end
          end
        end

        # Fallback to the first existing candidate
        valid_candidates.first
      end
    end
  end
end
