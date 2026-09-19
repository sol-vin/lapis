require "file_utils"
require "path"

module Lapis
  module Core
    module BakedFileSystem
      record BakedFile,
        path : String,
        content : String,
        size : Int32

      macro bake_manifest(manifest_path, repo_root)
        {% begin %}
          {%
            manifest = read_file(manifest_path)
            lines = manifest.split("\n")
          %}
          BAKED_FILES = {
            {% for line in lines %}
              {%
                trimmed = line.strip
              %}
              {% if trimmed.starts_with?("- ") %}
                {%
                  fpath = trimmed.gsub(/^- /, "").strip
                  full_path = "#{repo_root.id}/#{fpath.id}"
                  file_content = read_file(full_path)
                  file_size = file_content.size
                %}
                {{ fpath }} => BakedFile.new({{ fpath }}, {{ file_content }}, {{ file_size }}),
              {% end %}
            {% end %}
          }
        {% end %}
      end

      # Bake the platform-specific files manifest at compile time
      {% if flag?(:windows) %}
        bake_manifest("#{__DIR__}/../../baked_windows.yml", "#{__DIR__}/../../../../")
      {% elsif flag?(:darwin) %}
        bake_manifest("#{__DIR__}/../../baked_macos.yml", "#{__DIR__}/../../../../")
      {% else %}
        bake_manifest("#{__DIR__}/../../baked_linux.yml", "#{__DIR__}/../../../../")
      {% end %}

      # Retrieves a baked file by its virtual relative path. Raises KeyError if not found.
      def self.get(path : String) : BakedFile
        normalized = normalize_path(path)
        BAKED_FILES[normalized]? || raise KeyError.new("Baked file '#{path}' (normalized: '#{normalized}') not found in BakedFileSystem!")
      end

      # Retrieves a baked file by its virtual relative path, returning nil if not found.
      def self.get?(path : String) : BakedFile?
        normalized = normalize_path(path)
        BAKED_FILES[normalized]?
      end

      # Checks if a virtual path exists in the baked file system.
      def self.has_file?(path : String) : Bool
        normalized = normalize_path(path)
        BAKED_FILES.has_key?(normalized)
      end

      # Returns an array of all virtual file paths embedded in the binary.
      def self.files : Array(String)
        BAKED_FILES.keys
      end

      # Returns an array of all virtual paths starting with the given prefix.
      def self.files_with_prefix(prefix : String) : Array(String)
        norm_prefix = normalize_path(prefix)
        norm_prefix = "#{norm_prefix}/" unless norm_prefix.empty? || norm_prefix.ends_with?('/')
        files.select { |f| f.starts_with?(norm_prefix) }
      end

      # Extracts a single baked file to disk.
      def self.extract_file(virtual_path : String, target_path : Path | String) : Bool
        if file = get?(virtual_path)
          dest = Path.new(target_path)
          FileUtils.mkdir_p(dest.parent)
          File.write(dest, file.content)
          true
        else
          false
        end
      end

      # Extracts all files matching a virtual prefix into destination_dir.
      # The prefix is stripped from the output relative path.
      # Returns the number of files extracted.
      def self.extract_folder(prefix : String, destination_dir : Path | String) : Int32
        dest_root = Path.new(destination_dir)
        norm_prefix = normalize_path(prefix)
        norm_prefix = "#{norm_prefix}/" unless norm_prefix.empty? || norm_prefix.ends_with?('/')

        matched = files.select { |f| f.starts_with?(norm_prefix) }
        matched.each do |vpath|
          file = get(vpath)
          rel_subpath = vpath[norm_prefix.size..-1]
          target_path = dest_root.join(rel_subpath)
          FileUtils.mkdir_p(target_path.parent)
          File.write(target_path, file.content)
        end

        matched.size
      end

      # Normalizes directory separators to forward slashes
      private def self.normalize_path(path : String) : String
        path.gsub('\\', '/').strip('/')
      end
    end
  end
end
