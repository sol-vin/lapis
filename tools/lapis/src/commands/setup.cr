require "../core/env"
require "../core/logger"
require "../core/process_runner"
require "../core/archive_security"
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
  -v, --version=TAG     Target Godot version (e.g. 4.8-beta4, default from godot-version.yml)
  -t, --templates       Download and install Godot export templates
  -o, --output=PATH     Package export templates into specified zip
  -f, --force           Force download even if godot executable exists
  --skip-dump           Skip dumping extension_api.json after setup
  --skip-build          Skip compiling Crystal source addons and project game binary
  --lsp                 Configure Crystalline Language Server (LSP) library via shards
  --innosetup           Install Inno Setup Compiler [Windows only]
  -h, --help            Show this help screen

Examples:
  lapis setup
  lapis setup 4.8-beta4
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

        Core::GodotFinder::EMBEDDED_GODOT_VERSION
      end

      # When upgrading the Lapis repository to a new Godot version (e.g. 4.8-beta1 -> 4.8-beta4),
      # synchronizes godot-version.yml, template manifests, C++ bridge header, badges.yml, README.md,
      # and automatically bumps the Lapis minor version (0.X.0) in shard.yml and tools/lapis/shard.yml.
      def self.sync_repo_version_on_godot_upgrade(root : Path, target_version : String) : Void
        return unless Core::Env.is_libgodot_repo?(root)
        version_file = root.join("godot-version.yml")
        return unless File.exists?(version_file)

        old_godot_ver = ""
        if File.read(version_file) =~ /version:\s*["']?([^"'\r\n]+)["']?/
          old_godot_ver = $1.strip
        end

        master_godot_ver = old_godot_ver
        master_res = Core::ProcessRunner.capture("git", ["-C", root.to_s, "show", "master:godot-version.yml"])
        if master_res[:status].success? && (master_res[:output] =~ /version:\s*["']?([^"'\r\n]+)["']?/)
          master_godot_ver = $1.strip
        end

        if target_version != old_godot_ver
          version_files = [
            root.join("godot-version.yml"),
            root.join("test/godot-version.yml"),
            root.join("template/godot-version.yml"),
            root.join("template-addon/godot-version.yml"),
          ]
          Dir.glob(root.join("examples/*/godot-version.yml").to_s.gsub('\\', '/')).each do |ef|
            version_files << Path.new(ef)
          end
          version_files.each do |vf|
            File.write(vf, "version: \"#{target_version}\"\n") if File.exists?(vf)
          end

          bridge_hdr = root.join("src/bridge/godot_version.h")
          if File.exists?(bridge_hdr)
            File.write(bridge_hdr, <<-CPP
// Auto-generated target Godot version for C++ GDExtension loader bridge
#pragma once

#ifndef LIBGODOT_TARGET_VERSION
#define LIBGODOT_TARGET_VERSION "#{target_version}"
#endif
CPP
            )
          end

          badges_yml = root.join("badges.yml")
          if File.exists?(badges_yml)
            bc = File.read(badges_yml).gsub(/(label:\s*"Godot"\r?\n\s*message:\s*")[^"]+(")/, "\\1#{target_version}\\2")
            File.write(badges_yml, bc)
          end

          readme_md = root.join("README.md")
          if File.exists?(readme_md)
            escaped_badge = target_version.gsub("-", "--")
            rc = File.read(readme_md).gsub(%r{(badge/Godot-)[A-Za-z0-9.\-_]+(-blue\.svg)}, "\\1#{escaped_badge}\\2")
            File.write(readme_md, rc)
          end
        end

        # Ensure Lapis minor version is bumped (0.X.0) when target_version differs from master or old_godot_ver
        if target_version != master_godot_ver || target_version != old_godot_ver
          shard_yml = root.join("shard.yml")
          return unless File.exists?(shard_yml)
          shard_text = File.read(shard_yml)
          return unless shard_text =~ /^version:\s*["']?(\d+)\.(\d+)\.(\d+)["']?/m
          curr_maj = $1.to_i
          curr_min = $2.to_i

          base_maj = curr_maj
          base_min = curr_min
          m_shard = Core::ProcessRunner.capture("git", ["-C", root.to_s, "show", "master:shard.yml"])
          if m_shard[:status].success? && (m_shard[:output] =~ /^version:\s*["']?(\d+)\.(\d+)\.(\d+)["']?/m)
            base_maj = $1.to_i
            base_min = $2.to_i
          end

          if curr_maj == base_maj && curr_min == base_min
            new_min = base_min + 1
            new_lapis_ver = "#{base_maj}.#{new_min}.0"
            [root.join("shard.yml"), root.join("tools/lapis/shard.yml")].each do |sf|
              next unless File.exists?(sf)
              updated = File.read(sf).sub(/^(version:\s*["']?)\d+\.\d+\.\d+(["']?)/m, "\\1#{new_lapis_ver}\\2")
              File.write(sf, updated)
            end
            readme_md = root.join("README.md")
            if File.exists?(readme_md)
              rc = File.read(readme_md).gsub(%r{(badge/Lapis-)\d+\.\d+\.\d+(-blueviolet\.svg)}, "\\1#{new_lapis_ver}\\2")
              File.write(readme_md, rc)
            end
            Core::Logger.step("Setup", "Bumped Lapis milestone version to #{new_lapis_ver} for Godot #{target_version}")
          end
        end
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
                next if name.ends_with?("/") || name.ends_with?("\\")
                if name.ends_with?(".exe") || name.ends_with?("/Contents/MacOS/Godot") || (!Core::Env.windows? && !name.includes?("."))
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

      def self.platform_suffixes : Array(String)
        if Core::Env.windows?
          ["win64.exe.zip"]
        elsif Core::Env.macos?
          {% if flag?(:aarch64) %}
            ["macos.arm64.zip", "macos.universal.zip", "macos.x86_64.zip"]
          {% else %}
            ["macos.x86_64.zip", "macos.universal.zip", "macos.arm64.zip"]
          {% end %}
        else
          ["linux.x86_64.zip"]
        end
      end

      def self.download_godot_for_version(target_version : String, dest_exe : Path) : Bool
        platform_suffixes.each do |suffix|
          url = "https://github.com/godotengine/godot-builds/releases/download/#{target_version}/Godot_v#{target_version}_#{suffix}"
          return true if download_and_extract(url, dest_exe)
        end
        false
      end

      # Resolves an existing Godot binary matching the project's expected version, or automatically
      # downloads and extracts it into `<project_dir>/godot(.exe)` on fresh host machines (e.g. after unzipping a source archive).
      def self.ensure_godot_binary(
        project_dir : Path,
        custom_path : String? = nil,
        filter_version : Bool = true,
      ) : String?
        found = Core::GodotFinder.resolve(custom_path, project_dir.to_s, filter_version: filter_version)
        return found if found

        # Never auto-download when caller passed an explicit custom binary path or disabled auto-provisioning
        return nil if (custom_path && !custom_path.empty?) || ENV["LAPIS_NO_AUTO_GODOT"]? == "1"

        expected_ver = Core::GodotFinder.expected_version(project_dir.to_s)
        dest_exe = project_dir.expand.join("godot#{Core::Env.exe_ext}")
        Core::Logger.step("Setup", "Godot #{expected_ver} not found on host; downloading into #{dest_exe}...")
        if download_godot_for_version(expected_ver, dest_exe) && File.exists?(dest_exe)
          return dest_exe.to_s
        end
        nil
      end

      def self.download_to_file(url : String, dest_file : Path, max_retries : Int32 = 3) : Bool
        attempts = 0
        while attempts < max_retries
          attempts += 1
          begin
            success = HTTP::Client.get(url) do |response|
              if response.status_code == 301 || response.status_code == 302
                redirect_url = response.headers["Location"]?
                if redirect_url
                  return download_to_file(redirect_url, dest_file, max_retries - attempts + 1)
                end
              end

              unless response.status_code == 200
                Core::Logger.warn("HTTP error downloading #{url}: #{response.status_code} #{response.status_message} (attempt #{attempts}/#{max_retries})")
                next false
              end

              FileUtils.mkdir_p(dest_file.parent)
              File.open(dest_file, "w") do |f|
                IO.copy(response.body_io, f)
              end
              true
            end

            return true if success
          rescue ex
            Core::Logger.warn("Network error downloading #{url}: #{ex.message} (attempt #{attempts}/#{max_retries})")
          end

          if attempts < max_retries
            backoff_sec = (1 << attempts)
            sleep backoff_sec.seconds
          end
        end

        Core::Logger.error("Failed to download #{url} after #{max_retries} attempts")
        false
      end

      def self.install_templates(root : Path, target_version : String, zip_output : Path? = nil, force : Bool = false) : Int32
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

        has_templates = Dir.exists?(target_dir) && (Dir.children(target_dir).size >= 3)
        if has_templates && !force
          Core::Logger.info("Export templates already installed at #{target_dir}. Use --force to re-download.")
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
          return 0
        end

        urls = [
          "https://github.com/sol-vin/lapis/releases/download/#{target_version}/godot-crystal-export-templates-#{target_version}.zip",
          "https://github.com/godotengine/godot-builds/releases/download/#{target_version}/Godot_v#{target_version}_export_templates.tpz",
          "https://github.com/sol-vin/lapis/releases/download/latest/godot-crystal-export-templates-#{target_version}.zip",
          "https://github.com/godotengine/godot/releases/download/#{target_version}/Godot_v#{target_version}_export_templates.tpz",
        ]

        temp_tpz = target_dir.parent.join("templates_temp_#{Time.utc.to_unix_ms}.zip")
        downloaded = false

        begin
          urls.each do |candidate_url|
            Core::Logger.step("Setup", "Attempting download from #{candidate_url}...")
            if download_to_file(candidate_url, temp_tpz) && File.exists?(temp_tpz) && File.size(temp_tpz) > 100_000
              downloaded = true
              break
            end
            File.delete(temp_tpz) if File.exists?(temp_tpz)
          end

          unless downloaded && File.exists?(temp_tpz)
            Core::Logger.warn("Failed to download export templates from mirrors. Attempting fallback synthesis...")
            if synthesize_fallback_templates(target_dir, target_version)
              return 0
            end

            Core::Logger.error("Failed to download export templates from any available mirrors.")
            return 1
          end

          Core::Logger.step("Setup", "Extracting export templates to #{target_dir}...")
          File.open(temp_tpz, "rb") do |f|
            Compress::Zip::Reader.open(f) do |zip|
              zip.each_entry do |entry|
                val = Core::ArchiveSecurity.validate_entry_path(entry.filename, entry.dir?)
                unless val.valid?
                  Core::Logger.error("Security Error: Refusing to extract export templates — unsafe entry '#{entry.filename.scrub}': #{val.reason}")
                  return 1
                end
              end
            end
          end

          target_dir_abs = target_dir.expand(home: false).normalize
          if Core::ArchiveSecurity.unsafe_existing_node?(target_dir_abs)
            Core::Logger.error("Security Error: Export templates directory '#{target_dir_abs}' is a symlink or unsafe reparse point.")
            return 1
          end
          FileUtils.mkdir_p(target_dir_abs) unless Dir.exists?(target_dir_abs)

          File.open(temp_tpz, "rb") do |f|
            Compress::Zip::Reader.open(f) do |zip|
              zip.each_entry do |entry|
                val = Core::ArchiveSecurity.validate_entry_path(entry.filename, entry.dir?)
                return 1 unless val.valid?
                next if val.skip? || val.is_dir?

                clean_name = val.clean_path == "templates" ? "" : val.clean_path.sub(/^templates\//, "")
                next if clean_name.empty?

                dest = Core::ArchiveSecurity.resolve_safe_destination(target_dir_abs, clean_name)
                unless dest
                  Core::Logger.error("Security Error: Export template entry '#{entry.filename.scrub}' escapes '#{target_dir_abs}'.")
                  return 1
                end

                FileUtils.mkdir_p(dest.parent)
                File.open(dest, "wb") do |out_io|
                  IO.copy(entry.io, out_io)
                end
              end
            end
          end

          # Ensure version.txt reflects target version
          File.write(target_dir.join("version.txt"), target_version.gsub('-', '.'))
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

      def self.synthesize_fallback_templates(target_dir : Path, target_version : String) : Bool
        FileUtils.mkdir_p(target_dir)
        File.write(target_dir.join("version.txt"), target_version.gsub('-', '.'))

        # Check if any other export templates exist in parent directory
        parent = target_dir.parent
        if Dir.exists?(parent)
          other_ver = Dir.children(parent).find do |c|
            c != target_dir.basename.to_s && Dir.exists?(parent.join(c)) && Dir.children(parent.join(c)).size > 2
          end
          if other_ver
            src_dir = parent.join(other_ver)
            Dir.glob(src_dir.to_s.gsub('\\', '/') + "/*").each do |file|
              next if File.basename(file) == "version.txt"
              FileUtils.cp(file, target_dir.join(File.basename(file)).to_s)
            end
            Core::Logger.success("Synthesized fallback export templates in #{target_dir} from #{src_dir}")
            return true
          end
        end

        # Check for godot executable in root or PATH
        godot_exe = [
          Core::Env::ROOT_DIR.join("godot.exe"),
          Core::Env::ROOT_DIR.join("godot"),
          Path.new("godot.exe"),
          Path.new("godot"),
        ].find { |p| File.exists?(p) }

        if godot_exe
          dest_files = Core::Env.windows? ? ["windows_release_x86_64.exe", "windows_debug_x86_64.exe"] : ["linux_release.x86_64", "linux_debug.x86_64"]
          dest_files.each do |f|
            FileUtils.cp(godot_exe.to_s, target_dir.join(f).to_s)
          end
          Core::Logger.success("Synthesized fallback export templates in #{target_dir} from #{godot_exe}")
          return true
        end

        false
      end

      def self.setup_crystalline(root : Path, force : Bool = false) : Int32
        dest_exe = root.join("bin", "crystalline#{Core::Env.exe_ext}")
        FileUtils.mkdir_p(dest_exe.parent)

        if File.exists?(dest_exe) && !force
          Core::Logger.info("Crystalline LSP already configured at #{dest_exe}. Use --force to re-download.")
          return 0
        end

        Core::Logger.step("Setup", "Configuring Crystalline Language Server at #{dest_exe}...")

        # If scratch or local compiled crystalline exists, stage it
        scratch_exe = root.join("scratch/crystalline/bin/crystalline#{Core::Env.exe_ext}")
        if File.exists?(scratch_exe)
          FileUtils.cp(scratch_exe.to_s, dest_exe.to_s)
          Core::Logger.success("Installed Crystalline LSP to #{dest_exe}!")
          return 0
        end

        # System PATH fallback
        if (sys_path = Process.find_executable("crystalline")) && File.exists?(sys_path)
          FileUtils.cp(sys_path, dest_exe.to_s)
          Core::Logger.success("Copied system Crystalline (#{sys_path}) to #{dest_exe}!")
          return 0
        end

        if Core::Env.windows?
          Core::Logger.info("Pre-built Crystalline binaries are currently only published for Linux and macOS. On Windows, place crystalline.exe at #{dest_exe}.")
          return 0
        end

        # Download from GitHub release
        tag = "v0.20.0"
        url = if Core::Env.macos?
                "https://github.com/elbywan/crystalline/releases/download/#{tag}/crystalline_arm64-apple-darwin.gz"
              else
                "https://github.com/elbywan/crystalline/releases/download/#{tag}/crystalline_x86_64-unknown-linux-musl.gz"
              end

        temp_archive = dest_exe.parent.join("crystalline_dl_temp.archive")
        if download_to_file(url, temp_archive)
          begin
            File.open(dest_exe, "wb") do |f|
              Compress::Gzip::Reader.open(temp_archive.to_s) do |gz|
                IO.copy(gz, f)
              end
            end
            File.chmod(dest_exe, 0o755)
            Core::Logger.success("Downloaded and configured Crystalline LSP at #{dest_exe}!")
            0
          rescue ex
            Core::Logger.error("Failed to extract Crystalline archive: #{ex.message}")
            1
          ensure
            File.delete(temp_archive) if File.exists?(temp_archive)
          end
        else
          Core::Logger.warn("Could not download Crystalline from #{url}. Please download Crystalline from https://github.com/elbywan/crystalline/releases and place it at #{dest_exe}.")
          1
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
        skip_build = false
        templates_mode = false
        lsp_mode = false
        innosetup_mode = false
        zip_output : Path? = nil

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis setup [templates] [version] [options]"
          opts.on("-v VER", "--version=VER", "Target Godot version") { |v| cli_ver = v }
          opts.on("-t", "--templates", "Download and install export templates") { templates_mode = true }
          opts.on("-o PATH", "--output=PATH", "Package export templates zip") { |p| zip_output = Path.new(p) }
          opts.on("-f", "--force", "Force re-download") { force = true }
          opts.on("-y", "--yes", "Automatically accept setup prompts") { }
          opts.on("--skip-dump", "Skip dumping extension_api.json") { skip_dump = true }
          opts.on("--skip-build", "Skip compiling Crystal source addons and project game binary") { skip_build = true }
          opts.on("--lsp", "Configure Crystalline LSP library via shards") { lsp_mode = true }
          opts.on("--innosetup", "Install Inno Setup Compiler [Windows only]") { innosetup_mode = true }
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

        if innosetup_mode
          unless Core::Env.windows?
            Core::Logger.error("Inno Setup Compiler is only available on Windows. Current platform: #{Core::Env.current_platform}")
            return 1
          end
          ps_script = root.join("scripts/windows/install_deps.ps1")
          if File.exists?(ps_script)
            Core::Logger.step("Setup", "Invoking Windows dependency installer for Inno Setup...")
            status = Core::ProcessRunner.run("powershell.exe", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ps_script.to_s, "-Tools", "innosetup"])
            return status.exit_code
          else
            Core::Logger.error("Windows dependency installer script not found at #{ps_script}")
            return 1
          end
        end

        if templates_mode
          return install_templates(root, target_version, zip_output, force)
        end

        dest_exe = root.join("godot#{Core::Env.exe_ext}")
        is_monorepo = Core::Env.is_libgodot_repo?(root)

        if !is_monorepo
          Commands::Sync.purge_stray_monorepo_dirs(root)
          stray_api = root.join("extension_api.json")
          File.delete(stray_api) if File.exists?(stray_api) && !File.exists?(root.join("src/libgodot.cr"))
        end

        if cli_ver || !remaining.empty?
          sync_repo_version_on_godot_upgrade(root, target_version)
        end

        Core::Logger.step("Setup", "Godot Engine Setup: version #{target_version} at #{dest_exe}...")

        if File.exists?(dest_exe) && !force
          Core::Logger.info("Godot binary already exists at #{dest_exe}. Use --force to re-download.")
        else
          success = download_godot_for_version(target_version, dest_exe)
          unless success
            Core::Logger.error("Failed to download Godot binary for version #{target_version}")
            return 1
          end
        end

        if is_monorepo
          unless skip_dump
            Core::Logger.step("Setup", "Dumping extension API & generating engine bindings...")
            res = Bind::Engine.generate(dump_api: true)
            return res if res != 0
          end
        elsif Core::Env.is_standalone_project?(root)
          # Provision embedded Lapis library, shard dependencies, GDExtension bridge/plugin, and game binary
          if File.exists?(root.join("shard.yml"))
            Commands::ShardManager.ensure_dependencies(root)
          elsif Core::BakedFileSystem.files_with_prefix("src").size > 0
            Core::BakedFileSystem.extract_engine_lib(root.join("lib/lapis"), overwrite: true)
          end

          if !skip_dump && target_version != Core::GodotFinder::EMBEDDED_GODOT_VERSION && Dir.exists?(root.join("lib/lapis/src"))
            Core::Logger.step("Setup", "Target Godot (#{target_version}) differs from embedded (#{Core::GodotFinder::EMBEDDED_GODOT_VERSION}); regenerating engine bindings in lib/lapis...")
            temp_api = root.join("lib/lapis/extension_api.json")
            res = Bind::Engine.generate(
              api_path: temp_api,
              output_dir: root.join("lib/lapis/src/libgodot/generated"),
              dump_api: true
            )
            File.delete(temp_api) if File.exists?(temp_api)
            File.delete(root.join("extension_api.json")) if File.exists?(root.join("extension_api.json"))
            return res if res != 0
          end

          Commands::Sync.ensure_extension_list(root)
          Commands::Deps.ensure_bridge_and_plugin(root, need_plugin: !skip_dump)
          Commands::Deps.run(["-t", root.join("bin").to_s])
          if Dir.exists?(root.join("addons/crystal_integration"))
            Commands::Deps.run(["-t", root.join("addons/crystal_integration/bin").to_s, "--addon"])
          end

          if !skip_build && Dir.exists?(root.join("addons"))
            Core::Logger.step("Setup", "Building Crystal source addons...")
            addon_res = Commands::Build.build_addons(["-p", root.to_s])
            return addon_res if addon_res != 0
          end

          Commands::Sync.ensure_extension_list(root)

          if !skip_dump && !skip_build && File.exists?(root.join("src/main.cr"))
            Core::Logger.step("Setup", "Building project game library...")
            build_res = Commands::Build.run(["game", "-p", root.to_s])
            return build_res if build_res != 0
          end
        end

        Core::Logger.success("Godot engine setup and API bindings completed successfully!")
        0
      end
    end
  end
end

require "./deps"
require "./sync"
require "./shard_manager"
require "./build"
