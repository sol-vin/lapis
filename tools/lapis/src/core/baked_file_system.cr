require "bakelite"
require "file_utils"
require "path"

module Lapis
  module Core
    module BakedFileSystem
      include ::Bakelite::FS

      # Transparent alias to Bakelite::Item for backward compatibility
      alias BakedFile = ::Bakelite::Item

      # Bake the platform-specific files manifest at compile time via Bakelite
      {% if flag?(:windows) %}
        bake_manifest "#{__DIR__}/../../baked_windows.yml", base_dir: "#{__DIR__}/../../../../"
      {% elsif flag?(:darwin) %}
        bake_manifest "#{__DIR__}/../../baked_macos.yml", base_dir: "#{__DIR__}/../../../../"
      {% else %}
        bake_manifest "#{__DIR__}/../../baked_linux.yml", base_dir: "#{__DIR__}/../../../../"
      {% end %}

      # Returns an array of all virtual paths starting with the given prefix.
      def self.files_with_prefix(prefix : String) : Array(String)
        norm_prefix = ::Bakelite::Volume.normalize_path(prefix)
        norm_prefix = "#{norm_prefix}/" unless norm_prefix.empty? || norm_prefix.ends_with?('/')
        files.select { |f| f.starts_with?(norm_prefix) }
      end

      # Extracts a single baked file to disk.
      def self.extract_file(virtual_path : String, target_path : Path | String, overwrite : Bool = true) : Bool
        if item = get?(virtual_path)
          item.extract(target_path, overwrite)
        else
          false
        end
      end

      # Returns true if the target project directory already has an up-to-date lib/lapis (including src/editor), lib/cradare2, and lib/opal extracted.
      def self.engine_libs_present?(project_dir : Path) : Bool
        lapis_dir = project_dir.join("lib/lapis")
        return false unless Dir.exists?(lapis_dir.join("src")) &&
                            File.exists?(lapis_dir.join("src/editor/benchmark_graph_control.cr")) &&
                            File.exists?(lapis_dir.join("src/editor/plugin.cr")) &&
                            Dir.exists?(project_dir.join("lib/cradare2/src")) &&
                            Dir.exists?(project_dir.join("lib/opal/src"))

        if (baked_shard = get?("shard.yml")) && File.exists?(lapis_dir.join("shard.yml"))
          baked_ver = baked_shard.content[/^version:\s*["']?([^\s"']+)["']?/m, 1]?
          disk_ver = (File.read(lapis_dir.join("shard.yml")) rescue "")[/^version:\s*["']?([^\s"']+)["']?/m, 1]?
          return false if baked_ver && disk_ver && baked_ver != disk_ver
        end

        true
      end

      # Extracts the lean embedded Lapis engine library into target directory (lib/lapis)
      # along with required runtime shard dependencies (lib/cradare2, lib/opal).
      # Uses the isolated :engine, :cradare2, and :opal volumes exclusively, guaranteeing zero non-code bloat.
      def self.extract_engine_lib(target_lapis_dir : Path | String, overwrite : Bool = true) : Bool
        dest_lapis = Path.new(target_lapis_dir)
        engine_vol = fs.volume?(:engine)
        return false unless engine_vol && !engine_vol.empty?

        # Extract only genuine engine source files directly from :engine volume
        extract_volume(:engine, dest_lapis, overwrite: overwrite)

        # Extract embedded cradare2 dependency into sibling lib/cradare2 directory
        dest_cradare2 = dest_lapis.parent.join("cradare2")
        if (cradare2_vol = fs.volume?(:cradare2)) && !cradare2_vol.empty?
          extract_volume(:cradare2, dest_cradare2, overwrite: overwrite)
          File.write(dest_cradare2.join(".gdignore"), "") unless File.exists?(dest_cradare2.join(".gdignore"))
        end

        # Extract embedded opal dependency into sibling lib/opal directory
        dest_opal = dest_lapis.parent.join("opal")
        if (opal_vol = fs.volume?(:opal)) && !opal_vol.empty?
          extract_volume(:opal, dest_opal, overwrite: overwrite)
          File.write(dest_opal.join(".gdignore"), "") unless File.exists?(dest_opal.join(".gdignore"))
        end

        # Ensure .gdignore is present at both lib/ and lib/lapis/
        FileUtils.mkdir_p(dest_lapis.parent) unless Dir.exists?(dest_lapis.parent)
        File.write(dest_lapis.parent.join(".gdignore"), "") unless File.exists?(dest_lapis.parent.join(".gdignore"))
        File.write(dest_lapis.join(".gdignore"), "") unless File.exists?(dest_lapis.join(".gdignore"))
        true
      end
    end
  end
end
