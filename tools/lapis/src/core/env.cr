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
