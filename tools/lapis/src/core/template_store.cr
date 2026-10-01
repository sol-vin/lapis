# tools/lapis/src/core/template_store.cr
require "json"
require "compress/zip"
require "file_utils"
require "./env"
require "./logger"

module Lapis
  module Core
    struct TemplateManifest
      include JSON::Serializable

      property schema_version : Int32 = 1
      property name : String
      property display_name : String
      property description : String
      property author : String
      property version : String
      property godot_version : String
      property tags : Array(String)
      property features : Hash(String, Bool)
      property addons : Array(String)
      property created_at : String
      property file_count : Int32
      property uncompressed_bytes : UInt64

      def initialize(
        @name : String,
        @display_name : String = "",
        @description : String = "",
        @author : String = "",
        @version : String = "1.0.0",
        @godot_version : String = "4.4.stable",
        @tags = [] of String,
        @features = Hash(String, Bool).new,
        @addons = [] of String,
        @created_at : String = Time.utc.to_s("%Y-%m-%dT%H:%M:%SZ"),
        @file_count : Int32 = 0,
        @uncompressed_bytes : UInt64 = 0_u64
      )
        @display_name = @name.split(/[-_]/).map(&.capitalize).join(" ") if @display_name.empty?
      end
    end

    class TemplateStore
      def self.excluded_path?(rel_path : String) : Bool
        parts = rel_path.split('/')
        return true if parts.any? { |p| p == ".godot" || p == ".git" || p == ".agents" || p == "bin" || p == "lib" }
        return true if rel_path.ends_with?(".uid")
        return true if rel_path.ends_with?("~")
        return true if rel_path.ends_with?(".log")
        return true if rel_path.ends_with?(".tmp") || rel_path.ends_with?(".TMP")
        return true if rel_path.ends_with?(".pdb")
        return true if rel_path.ends_with?("shard.override.yml")
        return true if rel_path.ends_with?("shard.lock")
        return true if rel_path.includes?("_loaded_")
        return true if rel_path.includes?("crash_dump")
        false
      end

      def self.store_dir : Path
        base = if Env.windows?
                 if appdata = ENV["APPDATA"]?
                   Path.new(appdata)
                 else
                   Path.home.join("AppData/Roaming")
                 end
               elsif Env.macos?
                 Path.home.join("Library/Application Support")
               else
                 if xdg = ENV["XDG_DATA_HOME"]?
                   Path.new(xdg)
                 else
                   Path.home.join(".local/share")
                 end
               end
        base.join("lapis/templates")
      end

      def self.ensure_store_dir : Path
        dir = store_dir
        FileUtils.mkdir_p(dir) unless Dir.exists?(dir)
        dir
      end

      # Packages a project directory into the global template store
      def self.save_template(
        source_dir : Path,
        name : String,
        display_name : String? = nil,
        description : String? = nil,
        author : String? = nil,
        tags : Array(String)? = nil
      ) : TemplateManifest
        clean_name = name.strip.downcase.gsub(/[^a-z0-9_-]/, "_")
        target_store = ensure_store_dir.join(clean_name)
        FileUtils.mkdir_p(target_store)

        zip_path = target_store.join("template.zip")
        manifest_path = target_store.join("template.json")

        # 1. Inspect existing project.godot or shard.yml for metadata fallbacks
        detected_author = author || "Developer"
        detected_desc = description || "Custom Lapis project template"
        detected_ver = "1.0.0"
        detected_godot = "4.4.stable"
        detected_addons = [] of String
        detected_features = Hash(String, Bool).new

        godot_proj = source_dir.join("project.godot")
        if File.exists?(godot_proj)
          content = File.read(godot_proj)
          if m = content.match(/config\/name="([^"]+)"/)
            display_name ||= m[1]
          end
          detected_features["physics_2d"] = content.includes?("2d") || content.includes?("canvas")
          detected_features["physics_3d"] = content.includes?("3d") || content.includes?("spatial")
        end

        shard_yml = source_dir.join("shard.yml")
        if File.exists?(shard_yml)
          content = File.read(shard_yml)
          if m = content.match(/version:\s*([0-9A-Za-z_.-]+)/)
            detected_ver = m[1].strip
          end
          if m = content.match(/authors:\s*\n\s*-\s*([^\r\n]+)/)
            detected_author = author || m[1].strip
          end
        end

        # Check addons
        addons_dir = source_dir.join("addons")
        if Dir.exists?(addons_dir)
          Dir.each_child(addons_dir) do |c|
            detected_addons << c if Dir.exists?(addons_dir.join(c)) && !c.starts_with?(".")
          end
        end

        # 2. Package directory into template.zip
        file_count = 0
        total_bytes = 0_u64

        File.open(zip_path.to_s, "w") do |file|
          Compress::Zip::Writer.open(file) do |zip|
            pattern = source_dir.to_s.gsub('\\', '/') + "/**/*"
            Dir.glob(pattern).each do |item|
              next if Dir.exists?(item)

              item_path = Path.new(item).expand
              next if item_path == zip_path.expand
              next if item_path.extension == ".zip"

              rel_path = Path.new(item).relative_to(source_dir).to_s.gsub('\\', '/')

              # Skip excludes
              next if excluded_path?(rel_path)

              sz = File.size(item).to_u64
              file_count += 1
              total_bytes += sz

              File.open(item) do |io|
                zip.add(rel_path, io)
              end
            end
          end
        end

        manifest = TemplateManifest.new(
          name: clean_name,
          display_name: display_name || clean_name.split(/[-_]/).map(&.capitalize).join(" "),
          description: detected_desc,
          author: detected_author,
          version: detected_ver,
          godot_version: detected_godot,
          tags: tags || ["custom", "game"],
          features: detected_features,
          addons: detected_addons,
          file_count: file_count,
          uncompressed_bytes: total_bytes
        )

        File.write(manifest_path, manifest.to_pretty_json)
        manifest
      end

      # Lists all templates stored in the global template store
      def self.list_templates : Array(TemplateManifest)
        store = ensure_store_dir
        results = [] of TemplateManifest

        Dir.each_child(store) do |child|
          next if child.starts_with?(".")
          manifest_path = store.join(child).join("template.json")
          if File.exists?(manifest_path)
            begin
              results << TemplateManifest.from_json(File.read(manifest_path))
            rescue
              # Corrupted or partial template
            end
          end
        end

        results.sort_by(&.name)
      end

      # Returns metadata for a specific template
      def self.get_template(name : String) : TemplateManifest?
        clean_name = name.strip.downcase.gsub(/[^a-z0-9_-]/, "_")
        manifest_path = ensure_store_dir.join(clean_name).join("template.json")
        if File.exists?(manifest_path)
          begin
            return TemplateManifest.from_json(File.read(manifest_path))
          rescue
            nil
          end
        end
        nil
      end

      # Extracts a template from the global store into dest_dir
      def self.extract_template(name : String, dest_dir : Path) : Bool
        clean_name = name.strip.downcase.gsub(/[^a-z0-9_-]/, "_")
        zip_path = ensure_store_dir.join(clean_name).join("template.zip")
        return false unless File.exists?(zip_path)

        FileUtils.mkdir_p(dest_dir) unless Dir.exists?(dest_dir)

        Compress::Zip::Reader.open(zip_path.to_s) do |zip|
          zip.each_entry do |entry|
            entry_filename = entry.filename
            next if entry_filename.empty? || entry_filename.ends_with?("/")

            target_file = dest_dir.join(entry_filename)
            FileUtils.mkdir_p(target_file.parent) unless Dir.exists?(target_file.parent)

            File.open(target_file.to_s, "w") do |target_io|
              IO.copy(entry.io, target_io)
            end
          end
        end
        true
      rescue ex
        Logger.error("Failed to extract template '#{name}': #{ex.message}")
        false
      end

      # Deletes a template from the store
      def self.delete_template(name : String) : Bool
        clean_name = name.strip.downcase.gsub(/[^a-z0-9_-]/, "_")
        target_dir = ensure_store_dir.join(clean_name)
        if Dir.exists?(target_dir)
          FileUtils.rm_rf(target_dir)
          return true
        end
        false
      end

      # Purges all or selected templates
      def self.clean_templates(keep_names : Array(String)? = nil) : Int32
        store = ensure_store_dir
        cleaned = 0
        Dir.each_child(store) do |child|
          next if child.starts_with?(".")
          if keep_names && keep_names.includes?(child)
            next
          end
          target = store.join(child)
          if Dir.exists?(target)
            FileUtils.rm_rf(target)
            cleaned += 1
          end
        end
        cleaned
      end

      # Returns list of relative file paths in template archive
      def self.template_files(name : String) : Array(String)
        clean_name = name.strip.downcase.gsub(/[^a-z0-9_-]/, "_")
        zip_path = ensure_store_dir.join(clean_name).join("template.zip")
        return [] of String unless File.exists?(zip_path)

        files = [] of String
        Compress::Zip::Reader.open(zip_path.to_s) do |zip|
          zip.each_entry do |entry|
            files << entry.filename unless entry.filename.ends_with?("/")
          end
        end
        files.sort
      rescue
        [] of String
      end

      # Exports a template as a single zip archive containing template.json and project files
      def self.export_template(name : String, out_path : Path) : Bool
        clean_name = name.strip.downcase.gsub(/[^a-z0-9_-]/, "_")
        tpl_dir = ensure_store_dir.join(clean_name)
        return false unless Dir.exists?(tpl_dir)

        zip_source = tpl_dir.join("template.zip")
        manifest_source = tpl_dir.join("template.json")
        return false unless File.exists?(zip_source)

        FileUtils.mkdir_p(out_path.parent) unless Dir.exists?(out_path.parent)
        File.delete(out_path) if File.exists?(out_path)

        File.open(out_path.to_s, "w") do |out_file|
          Compress::Zip::Writer.open(out_file) do |out_zip|
            if File.exists?(manifest_source)
              manifest_content = File.read(manifest_source)
              out_zip.add("template.json", manifest_content)
            end
            Compress::Zip::Reader.open(zip_source.to_s) do |in_zip|
              in_zip.each_entry do |entry|
                next if entry.filename == "template.json"
                out_zip.add(entry.filename, entry.io)
              end
            end
          end
        end
        true
      rescue
        false
      end

      # Imports a template zip archive into the store
      def self.import_template(archive_path : Path, custom_name : String? = nil) : TemplateManifest?
        return nil unless File.exists?(archive_path)

        dest_name = custom_name || archive_path.basename(".zip").strip.downcase.gsub(/[^a-z0-9_-]/, "_")
        target_dir = ensure_store_dir.join(dest_name)
        FileUtils.mkdir_p(target_dir)

        dest_zip = target_dir.join("template.zip")
        FileUtils.cp(archive_path, dest_zip)

        # Check if archive already contains template.json inside
        manifest = nil
        begin
          Compress::Zip::Reader.open(archive_path.to_s) do |zip|
            zip.each_entry do |entry|
              if entry.filename == "template.json"
                manifest = TemplateManifest.from_json(entry.io.gets_to_end)
                break
              end
            end
          end
        rescue
        end

        manifest ||= TemplateManifest.new(
          name: dest_name,
          display_name: dest_name.split(/[-_]/).map(&.capitalize).join(" "),
          description: "Imported Lapis template",
          author: "Unknown"
        )

        count = 0
        uncompressed = 0_u64
        buf = uninitialized UInt8[4096]
        begin
          Compress::Zip::Reader.open(dest_zip.to_s) do |zip|
            zip.each_entry do |entry|
              next if entry.filename == "template.json" || entry.filename.ends_with?("/")
              count += 1
              while (n = entry.io.read(buf.to_slice)) > 0
                uncompressed += n.to_u64
              end
            end
          end
        rescue
        end

        manifest.file_count = count
        manifest.uncompressed_bytes = uncompressed

        File.write(target_dir.join("template.json"), manifest.to_pretty_json)
        manifest
      end
    end
  end
end
