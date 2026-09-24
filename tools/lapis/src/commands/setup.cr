require "../core/env"
require "../core/logger"
require "../core/process_runner"
require "./bind/engine"
require "file_utils"
require "option_parser"
require "compress/zip"
require "compress/gzip"
require "http/client"

module Lapis
  module Commands
    module Setup
      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Godot Engine Development Setup ===\e[0m

Usage: lapis setup [templates] [version] [options]

Options:
  -v, --version=TAG     Target Godot version (e.g. 4.8-dev6, default from godot-version.yml)
  -t, --templates       Download and install Godot export templates
  -o, --output=PATH     Package export templates into specified zip
  -f, --force           Force download even if godot executable exists
  --skip-dump           Skip dumping extension_api.json after setup
  --lsp                 Configure Crystalline Language Server (LSP) library via shards
  -h, --help            Show this help screen

Examples:
  lapis setup
  lapis setup 4.8-dev6
  lapis setup templates
  lapis setup templates -o bin/export-templates.zip
  lapis setup --force
HELP
      end

      def self.resolve_version(root : Path, cli_version : String?) : String
        return cli_version if cli_version && !cli_version.empty?

        version_file = root.join("godot-version.yml")
        if File.exists?(version_file)
          content = File.read(version_file)
          if content =~ /version:\s*["']?([^"'\r\n]+)["']?/
            return $1.strip
          end
        end

        "4.8-dev5"
      end

      def self.download_and_extract(url : String, dest_exe : Path) : Bool
        Core::Logger.step("Setup", "Downloading Godot from #{url}...")
        zip_temp = dest_exe.parent.join("godot_temp.zip")

        begin
          HTTP::Client.get(url) do |response|
            if response.status_code == 301 || response.status_code == 302
              redirect_url = response.headers["Location"]?
              if redirect_url
                Core::Logger.debug("Following redirect -> #{redirect_url}")
                return download_and_extract(redirect_url, dest_exe)
              end
            end

            unless response.status_code == 200
              Core::Logger.error("HTTP error downloading Godot: #{response.status_code} #{response.status_message}")
              return false
            end

            File.open(zip_temp, "w") do |f|
              IO.copy(response.body_io, f)
            end
          end

          Core::Logger.step("Setup", "Extracting Godot engine executable...")
          File.open(zip_temp) do |f|
            Compress::Zip::Reader.open(f) do |zip|
              zip.each_entry do |entry|
                name = entry.filename
                if name.ends_with?(".exe") || (!Core::Env.windows? && !name.includes?("."))
                  next if name.includes?("console")
                  File.open(dest_exe, "w") do |out_io|
                    IO.copy(entry.io, out_io)
                  end
                  File.chmod(dest_exe, 0o755) unless Core::Env.windows?
                  break
                end
              end
            end
          end
          true
        ensure
          File.delete(zip_temp) if File.exists?(zip_temp)
        end
      end

      def self.download_to_file(url : String, dest_file : Path) : Bool
        HTTP::Client.get(url) do |response|
          if response.status_code == 301 || response.status_code == 302
            redirect_url = response.headers["Location"]?
            if redirect_url
              return download_to_file(redirect_url, dest_file)
            end
          end

          unless response.status_code == 200
            Core::Logger.error("HTTP error downloading #{url}: #{response.status_code} #{response.status_message}")
            return false
          end

          FileUtils.mkdir_p(dest_file.parent)
          File.open(dest_file, "w") do |f|
            IO.copy(response.body_io, f)
          end
          return true
        end
        false
      end

      def self.install_templates(root : Path, target_version : String, zip_output : Path? = nil) : Int32
        template_base = if Core::Env.windows?
                          if appdata = ENV["APPDATA"]?
                            Path.new(appdata).join("Godot/export_templates")
                          else
                            Path.home.join("AppData/Roaming/Godot/export_templates")
                          end
                        elsif Core::Env.macos?
                          Path.home.join("Library/Application Support/Godot/export_templates")
                        else
                          Path.home.join(".local/share/godot/export_templates")
                        end

        ver_folder = target_version.gsub('-', '.')
        target_dir = template_base.join(ver_folder)
        FileUtils.mkdir_p(target_dir)

        url = "https://github.com/godotengine/godot-builds/releases/download/#{target_version}/Godot_v#{target_version}_export_templates.tpz"
        Core::Logger.step("Setup", "Downloading Godot export templates from #{url}...")

        temp_tpz = target_dir.parent.join("templates_temp_#{Time.utc.to_unix_ms}.zip")
        begin
          success = download_to_file(url, temp_tpz)
          unless success && File.exists?(temp_tpz)
            Core::Logger.error("Failed to download export templates from #{url}")
            return 1
          end

          Core::Logger.step("Setup", "Extracting export templates to #{target_dir}...")
          File.open(temp_tpz) do |f|
            Compress::Zip::Reader.open(f) do |zip|
              zip.each_entry do |entry|
                name = entry.filename
                clean_name = name.sub(/^templates[\/\\]/, "")
                next if clean_name.empty? || clean_name.ends_with?("/") || clean_name.ends_with?("\\")

                dest = target_dir.join(clean_name)
                FileUtils.mkdir_p(dest.parent)
                File.open(dest, "w") do |out_io|
                  IO.copy(entry.io, out_io)
                end
              end
            end
          end
        ensure
          File.delete(temp_tpz) if File.exists?(temp_tpz)
        end

        if zo = zip_output
          FileUtils.mkdir_p(zo.parent)
          Core::Logger.step("Setup", "Packaging export templates zip -> #{zo}...")
          File.open(zo, "w") do |file|
            Compress::Zip::Writer.open(file) do |zip|
              Dir.glob(target_dir.to_s.gsub('\\', '/') + "/**/*").each do |t_file|
                next if Dir.exists?(t_file)
                rel = Path.new(t_file).relative_to(target_dir).to_s.gsub('\\', '/')
                zip.add(rel, File.open(t_file))
              end
            end
          end
        end

        Core::Logger.success("Installed Godot export templates for #{ver_folder} into #{target_dir}!")
        0
      end

      def self.setup_crystalline(root : Path, force : Bool = false) : Int32
        Core::Logger.step("Setup", "Configuring Crystalline Language Server library via shards...")
        status = Core::ProcessRunner.run("shards", ["install"], chdir: root.to_s)
        if status.success?
          Core::Env.patch_crystalline_library(root)
          Core::Logger.success("Crystalline library successfully configured via shards!")
          0
        else
          Core::Logger.error("Failed to install Crystalline dependency via shards.")
          status.exit_code
        end
      end

      def self.run(args : Array(String)) : Int32
        if args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        cli_ver : String? = nil
        force = false
        skip_dump = false
        templates_mode = false
        lsp_mode = false
        zip_output : Path? = nil

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis setup [templates] [version] [options]"
          opts.on("-v VER", "--version=VER", "Target Godot version") { |v| cli_ver = v }
          opts.on("-t", "--templates", "Download and install export templates") { templates_mode = true }
          opts.on("-o PATH", "--output=PATH", "Package export templates zip") { |p| zip_output = Path.new(p) }
          opts.on("-f", "--force", "Force re-download") { force = true }
          opts.on("--skip-dump", "Skip dumping extension_api.json") { skip_dump = true }
          opts.on("--lsp", "Configure Crystalline LSP library via shards") { lsp_mode = true }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
        end

        remaining = [] of String
        parser.unknown_args { |r| remaining = r }
        parser.parse(args)

        if remaining.includes?("templates")
          templates_mode = true
          remaining.delete("templates")
        end

        root = Core::Env::ROOT_DIR
        target_version = resolve_version(root, cli_ver || (remaining.empty? ? nil : remaining[0]))

        if lsp_mode
          return setup_crystalline(root, force)
        end

        if templates_mode
          return install_templates(root, target_version, zip_output)
        end

        dest_exe = root.join("godot#{Core::Env.exe_ext}")

        Core::Logger.step("Setup", "Godot Engine Setup: version #{target_version} at #{dest_exe}...")

        if File.exists?(dest_exe) && !force
          Core::Logger.info("Godot binary already exists at #{dest_exe}. Use --force to re-download.")
        else
          platform_suffix = if Core::Env.windows?
                              "win64.exe.zip"
                            elsif Core::Env.macos?
                              "macos.universal.zip"
                            else
                              "linux.x86_64.zip"
                            end

          url = "https://github.com/godotengine/godot-builds/releases/download/#{target_version}/Godot_v#{target_version}_#{platform_suffix}"
          success = download_and_extract(url, dest_exe)
          unless success
            Core::Logger.error("Failed to download Godot binary for version #{target_version}")
            return 1
          end
        end

        unless skip_dump
          Core::Logger.step("Setup", "Dumping extension API & generating engine bindings...")
          res = Bind::Engine.generate(dump_api: true)
          return res if res != 0
        end

        Core::Logger.success("Godot engine setup and API bindings completed successfully!")
        0
      end
    end
  end
end
