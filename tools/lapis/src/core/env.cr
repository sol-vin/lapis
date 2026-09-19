require "file_utils"
require "path"
require "json"

module Lapis
  module Core
    module Env
      # Find project root by searching upwards for the main workspace root (containing src/libgodot.cr or tools/lapis),
      # or fallback to first directory with shard.yml or Makefile.
      def self.find_root : Path
        current = Path.new(Dir.current).expand
        # 1. Search upwards for true repository / workspace root
        cursor = current
        loop do
          if File.exists?(cursor.join("src/libgodot.cr")) || Dir.exists?(cursor.join("tools/lapis"))
            return cursor
          end
          parent = cursor.parent
          break if parent == cursor
          cursor = parent
        end

        # 2. If outside the main repo (e.g. standalone user project), search for shard.yml / Makefile
        cursor = current
        loop do
          if File.exists?(cursor.join("shard.yml")) && File.exists?(cursor.join("Makefile"))
            return cursor
          end
          parent = cursor.parent
          break if parent == cursor
          cursor = parent
        end

        # Fallback to current working directory
        current
      end

      def self.global_libgodot_path : Path?
        # 1. Check environment variables
        if (env_p = ENV["LIBGODOT_PATH"]? || ENV["LAPIS_PATH"]?) && !env_p.empty?
          p = Path.new(env_p).expand
          return p if Dir.exists?(p)
        end

        # 2. Check global configuration file
        cfg_path = if windows?
          appdata = ENV["APPDATA"]? || ENV["LOCALAPPDATA"]? || (ENV["USERPROFILE"]? ? File.join(ENV["USERPROFILE"], "AppData", "Roaming") : nil)
          appdata ? Path.new(appdata).join("lapis", "config.json") : Path.home.join(".config", "lapis", "config.json")
        else
          xdg = ENV["XDG_CONFIG_HOME"]?
          (xdg && !xdg.empty?) ? Path.new(xdg).join("lapis", "config.json") : Path.home.join(".config", "lapis", "config.json")
        end

        if File.exists?(cfg_path)
          begin
            cfg = Hash(String, String).from_json(File.read(cfg_path))
            if (lp = cfg["libgodot_path"]?) && !lp.empty?
              p = Path.new(lp).expand
              return p if Dir.exists?(p)
            end
          rescue
          end
        end

        nil
      end

      ROOT_DIR = find_root

      def self.windows? : Bool
        {% if flag?(:windows) %}
          true
        {% else %}
          false
        {% end %}
      end

      def self.macos? : Bool
        {% if flag?(:darwin) %}
          true
        {% else %}
          false
        {% end %}
      end

      def self.linux? : Bool
        {% if flag?(:linux) %}
          true
        {% else %}
          false
        {% end %}
      end

      def self.dll_ext : String
        if windows?
          "dll"
        elsif macos?
          "dylib"
        else
          "so"
        end
      end

      def self.exe_ext : String
        windows? ? ".exe" : ""
      end

      def self.link_flags : String
        if windows?
          "/DLL /ENTRY:_DllMainCRTStartup /EXPORT:crystal_godot_init"
        elsif macos?
          "-dynamiclib"
        else
          "-shared"
        end
      end

      def self.path_sep : String
        windows? ? ";" : ":"
      end

      # Platform-relevant runtime dependencies
      def self.platform_bin_files : Array(String)
        if windows?
          ["crystal_bridge.dll", "gc.dll", "iconv-2.dll", "pcre2-8.dll", "libgodot.dll", "libgodot.lib"]
        elsif macos?
          ["crystal_bridge.dylib", "libgodot.dylib"]
        else
          ["crystal_bridge.so", "libgodot.so"]
        end
      end

      def self.bridge_file : String
        "crystal_bridge.#{dll_ext}"
      end

      def self.plugin_file : String
        "plugin.#{dll_ext}"
      end

      def self.game_file : String
        "game.#{dll_ext}"
      end

      def self.current_platform : String
        if windows?
          "windows"
        elsif macos?
          "macos"
        else
          "linux"
        end
      end

      # Returns true if the file is a compiled binary/library belonging natively to the current platform.
      def self.is_native_binary?(filename : Path | String) : Bool
        fn = filename.is_a?(Path) ? filename.basename : Path.new(filename).basename
        ext = Path.new(fn).extension.downcase

        if windows?
          [".dll", ".exe", ".lib", ".pdb"].includes?(ext)
        elsif macos?
          [".dylib", ".dmg", ".pkg"].includes?(ext) || (ext.empty? && !fn.starts_with?(".") && !fn.includes?("."))
        else
          # Linux
          ext == ".so" || fn.includes?(".so.") || [".deb", ".tar.gz", ".tgz"].any? { |s| fn.ends_with?(s) } || (ext.empty? && !fn.starts_with?(".") && !fn.includes?("."))
        end
      end

      # Returns true if the file is a compiled binary/library belonging to a different (foreign) platform.
      def self.is_foreign_binary?(filename : Path | String) : Bool
        fn = filename.is_a?(Path) ? filename.basename : Path.new(filename).basename
        ext = Path.new(fn).extension.downcase

        if windows?
          ext == ".so" || fn.includes?(".so.") || ext == ".dylib" || ext == ".deb" || fn.ends_with?(".tar.gz") ||
            (ext.empty? && ["game", "tests", "perf", "lapis"].includes?(fn))
        elsif linux?
          [".dll", ".exe", ".dylib", ".lib", ".pdb", ".iss"].includes?(ext)
        else
          # macOS
          [".dll", ".exe", ".so", ".lib", ".pdb", ".deb", ".iss"].includes?(ext) || fn.includes?(".so.")
        end
      end

      # Scans a directory and deletes any files belonging to a foreign platform.
      # Returns the number of purged foreign files.
      def self.purge_foreign_binaries(dir : Path | String) : Int32
        target = Path.new(dir)
        return 0 unless Dir.exists?(target)

        purged_count = 0
        Dir.each_child(target) do |child|
          full_path = target.join(child)
          if File.file?(full_path)
            if is_foreign_binary?(full_path)
              begin
                File.delete(full_path)
                purged_count += 1
                Logger.debug("Purged foreign platform file: #{full_path}")
              rescue ex
                Logger.debug("Failed to purge #{full_path}: #{ex.message}")
              end
            end
          elsif Dir.exists?(full_path) && (child == "bin" || child == "addons" || child == "android")
            purged_count += purge_foreign_binaries(full_path)
          end
        end

        purged_count
      end

      # Collect all destination bin directories across the repository
      def self.collect_target_bin_dirs(root : Path = ROOT_DIR, target_bin : String? = nil) : Array(Path)
        dirs = [
          root.join("bin"),
          root.join("addons/crystal_integration/bin"),
          root.join("test/bin"),
          root.join("test/addons/crystal_integration/bin"),
          root.join("template/bin"),
          root.join("template/addons/crystal_integration/bin"),
          root.join("template-addon/addons/crystal_addon/bin"),
          root.join("template-addon/addons/crystal_integration/bin"),
          root.join("performance/bin"),
          root.join("performance/addons/crystal_integration/bin"),
        ]

        if target_bin && !target_bin.empty?
          dirs << Path.new(target_bin).expand
        end

        # Discover all addons in test/addons
        test_addons = root.join("test/addons")
        if Dir.exists?(test_addons)
          Dir.each_child(test_addons) do |child|
            p = test_addons.join(child)
            if Dir.exists?(p)
              dirs << p.join("bin")
            end
          end
        end

        # Discover all examples/*/bin and examples/*/addons/*/bin
        examples_dir = root.join("examples")
        if Dir.exists?(examples_dir)
          Dir.each_child(examples_dir) do |child|
            ex = examples_dir.join(child)
            if Dir.exists?(ex)
              dirs << ex.join("bin")
              dirs << ex.join("addons/crystal_integration/bin")

              # Other nested addons in example
              ex_addons = ex.join("addons")
              if Dir.exists?(ex_addons)
                Dir.each_child(ex_addons) do |addon_child|
                  addon_p = ex_addons.join(addon_child)
                  dirs << addon_p.join("bin") if Dir.exists?(addon_p)
                end
              end
            end
          end
        end

        dirs.uniq
      end
    end
  end
end
