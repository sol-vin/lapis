require "../core/env"
require "../core/logger"
require "../core/process_runner"
require "./get"
require "./deps"
require "./bind/project"
require "./shard_manager"
require "file_utils"
require "option_parser"
require "json"
require "http/client"
require "uri"
require "compress/zip"

module Lapis
  module Commands
    module InstallAddon
      struct AddonSpec
        property raw : String
        property type : Symbol # :github, :local_file, :local_dir, :url
        property owner : String?
        property repo : String?
        property tag : String?
        property path : String?

        def initialize(@raw, @type, @owner = nil, @repo = nil, @tag = nil, @path = nil)
        end

        def name : String
          if r = @repo
            r
          elsif p = @path
            Path.new(p).basename.rchop(".zip").rchop("-windows").rchop("-linux").rchop("-macos")
          else
            "addon"
          end
        end
      end

      # Parse specifier string:
      # - github:owner/repo[@tag]
      # - gh:owner/repo[@tag]
      # - owner/repo[@tag]
      # - https://github.com/owner/repo[.git][@tag]
      # - local/path/to/addon.zip
      # - local/path/to/addon_dir
      def self.parse_spec(raw : String) : AddonSpec
        spec = raw.strip

        # Extract @tag or @branch if present at end
        tag : String? = nil
        if spec.includes?("@") && !spec.starts_with?("@")
          parts = spec.split('@', 2)
          spec = parts[0]
          tag = parts[1] unless parts[1].empty?
        end

        # Check github: or gh: prefix
        if spec.starts_with?("github:") || spec.starts_with?("gh:")
          repo_part = spec.split(':', 2)[1]
          owner_repo = repo_part.split('/')
          if owner_repo.size == 2
            return AddonSpec.new(raw, :github, owner_repo[0], owner_repo[1], tag)
          end
        end

        # Check full URL
        if spec.starts_with?("http://") || spec.starts_with?("https://")
          uri = URI.parse(spec)
          if uri.host == "github.com" || uri.host == "www.github.com"
            path_parts = uri.path.strip('/').split('/')
            if path_parts.size >= 2
              owner = path_parts[0]
              repo = path_parts[1].rchop(".git")
              return AddonSpec.new(raw, :github, owner, repo, tag)
            end
          end
          return AddonSpec.new(raw, :url, path: spec, tag: tag)
        end

        # Check local file or archive extension (.zip, .tar.gz)
        if File.file?(spec) || spec.ends_with?(".zip") || spec.ends_with?(".tar.gz")
          return AddonSpec.new(raw, :local_file, path: spec)
        elsif Dir.exists?(spec) || spec.starts_with?("./") || spec.starts_with?("../") || spec.starts_with?("/") || spec.starts_with?("addons/") || spec.starts_with?("addons\\") || spec.ends_with?('/') || spec.includes?('\\')
          return AddonSpec.new(raw, :local_dir, path: spec)
        end

        # Check owner/repo pattern (e.g. sol-vin/crshader)
        if spec =~ /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/
          parts = spec.split('/')
          return AddonSpec.new(raw, :github, parts[0], parts[1], tag)
        end

        AddonSpec.new(raw, :local_dir, path: spec)
      end

      def self.github_token : String?
        if (t = ENV["GITHUB_TOKEN"]?) && !t.empty?
          return t
        end
        if Process.find_executable("gh")
          res = Core::ProcessRunner.capture("gh", ["auth", "token"]) rescue nil
          if res && res[:status].success? && !res[:output].strip.empty?
            return res[:output].strip
          end
        end
        nil
      end

      def self.github_api_get(path : String) : HTTP::Client::Response?
        uri = URI.parse("https://api.github.com")
        client = HTTP::Client.new(uri)
        client.connect_timeout = 10.seconds
        client.read_timeout = 15.seconds
        headers = HTTP::Headers{
          "User-Agent" => "Lapis-CLI/#{Lapis::VERSION}",
          "Accept"     => "application/vnd.github.v3+json",
        }
        if token = github_token
          headers["Authorization"] = "Bearer #{token}"
        end
        client.get(path, headers: headers)
      rescue
        nil
      end

      # Checks if GitHub repository has an addons directory in its tree
      def self.repo_has_addons_dir?(owner : String, repo : String) : Bool
        # 1. Try checking /repos/:owner/:repo/contents/addons
        resp = github_api_get("/repos/#{owner}/#{repo}/contents/addons")
        if resp && resp.status_code == 200
          return true
        elsif resp && resp.status_code == 404
          return false
        end

        # 2. Try checking root contents for "addons" dir
        resp_root = github_api_get("/repos/#{owner}/#{repo}/contents")
        if resp_root && resp_root.status_code == 200
          begin
            entries = ::JSON.parse(resp_root.body).as_a
            return entries.any? { |e| e["name"]?.try(&.as_s) == "addons" && e["type"]?.try(&.as_s) == "dir" }
          rescue
          end
        end

        false
      end

      # Queries GitHub Releases to find appropriate asset URL
      def self.find_release_asset_url(
        owner : String,
        repo : String,
        tag : String? = nil,
        platform : String = Core::Env.current_platform,
      ) : Tuple(String, String)?
        path = if tag && !tag.empty? && tag.downcase != "latest"
                 clean_tag = tag.starts_with?("v") ? tag : "v#{tag}"
                 "/repos/#{owner}/#{repo}/releases/tags/#{clean_tag}"
               else
                 "/repos/#{owner}/#{repo}/releases/latest"
               end

        resp = github_api_get(path)
        return nil unless resp && resp.status_code == 200

        body = ::JSON.parse(resp.body)
        assets = body["assets"]?.try(&.as_a) || [] of ::JSON::Any
        return nil if assets.empty?

        plat = platform.downcase
        matched = assets.find do |a|
          name = a["name"]?.try(&.as_s.downcase) || ""
          name.includes?(plat) && (name.ends_with?(".zip") || name.ends_with?(".tar.gz"))
        end

        matched ||= assets.find do |a|
          name = a["name"]?.try(&.as_s.downcase) || ""
          name.ends_with?(".zip")
        end

        matched ||= assets.first?

        if matched && (url = matched["browser_download_url"]?.try(&.as_s)) && (name = matched["name"]?.try(&.as_s))
          {url, name}
        else
          nil
        end
      rescue ex
        Core::Logger.debug("Notice: Error parsing GitHub release: #{ex.message}")
        nil
      end

      # Registers and enables plugin in project.godot under [editor_plugins]
      def self.enable_in_project_godot(project_path : Path, plugin_cfg_rel_path : String) : Bool
        project_godot = project_path.join("project.godot")
        return false unless File.exists?(project_godot)

        content = File.read(project_godot)
        target_entry = "res://#{plugin_cfg_rel_path.gsub('\\', '/')}"

        if content.includes?(target_entry)
          Core::Logger.info("Plugin '#{target_entry}' is already enabled in project.godot")
          return true
        end

        if content =~ /\[editor_plugins\]\s*[\r\n]+enabled=PackedStringArray\((.*?)\)/m
          existing_args = $1.strip
          new_args = if existing_args.empty?
                       "\"#{target_entry}\""
                     else
                       "#{existing_args}, \"#{target_entry}\""
                     end
          new_content = content.gsub(/\[editor_plugins\]\s*[\r\n]+enabled=PackedStringArray\((.*?)\)/m, "[editor_plugins]\n\nenabled=PackedStringArray(#{new_args})")
          File.write(project_godot, new_content)
          Core::Logger.success("Enabled plugin '#{target_entry}' in project.godot")
          return true
        elsif content.includes?("[editor_plugins]")
          new_content = content.gsub("[editor_plugins]", "[editor_plugins]\n\nenabled=PackedStringArray(\"#{target_entry}\")")
          File.write(project_godot, new_content)
          Core::Logger.success("Enabled plugin '#{target_entry}' in project.godot")
          return true
        else
          new_content = content.rstrip + "\n\n[editor_plugins]\n\nenabled=PackedStringArray(\"#{target_entry}\")\n"
          File.write(project_godot, new_content)
          Core::Logger.success("Registered and enabled plugin '#{target_entry}' in project.godot")
          return true
        end
      rescue ex
        Core::Logger.warn("Failed to auto-enable plugin in project.godot: #{ex.message}")
        false
      end

      # Unregisters plugin from project.godot under [editor_plugins]
      def self.disable_in_project_godot(project_path : Path, plugin_cfg_rel_path : String) : Bool
        project_godot = project_path.join("project.godot")
        return false unless File.exists?(project_godot)

        content = File.read(project_godot)
        target_entry = "res://#{plugin_cfg_rel_path.gsub('\\', '/')}"

        return true unless content.includes?(target_entry)

        if content =~ /\[editor_plugins\]\s*[\r\n]+enabled=PackedStringArray\((.*?)\)/m
          existing_args = $1.strip
          items = existing_args.scan(/"([^"]+)"/).map(&.[1])
          items.reject! { |i| i == target_entry }
          new_args = items.map { |i| "\"#{i}\"" }.join(", ")
          new_content = content.gsub(/\[editor_plugins\]\s*[\r\n]+enabled=PackedStringArray\((.*?)\)/m, "[editor_plugins]\n\nenabled=PackedStringArray(#{new_args})")
          File.write(project_godot, new_content)
          Core::Logger.success("Disabled plugin '#{target_entry}' in project.godot")
          return true
        end
        true
      rescue ex
        Core::Logger.warn("Failed to disable plugin in project.godot: #{ex.message}")
        false
      end

      # Registers .gdextension files into .godot/extension_list.cfg so headless tools and editor detect them immediately
      def self.register_in_extension_list(project_dir : Path, target_addon_dir : Path) : Void
        gdext_files = Dir.glob(target_addon_dir.join("**/*.gdextension").to_s.gsub('\\', '/'))
        return if gdext_files.empty?

        godot_dir = project_dir.join(".godot")
        FileUtils.mkdir_p(godot_dir)
        cfg_file = godot_dir.join("extension_list.cfg")
        existing_lines = File.exists?(cfg_file) ? File.read_lines(cfg_file) : [] of String

        updated = false
        gdext_files.each do |ext_path|
          rel_path = "res://" + Path.new(ext_path).relative_to(project_dir).to_s.gsub('\\', '/')
          unless existing_lines.includes?(rel_path)
            existing_lines << rel_path
            updated = true
          end
        end

        if updated
          File.write(cfg_file, existing_lines.join("\n") + "\n")
        end
      rescue
      end

      # Unregisters .gdextension files from .godot/extension_list.cfg
      def self.unregister_from_extension_list(project_dir : Path, addon_name : String) : Void
        cfg_file = project_dir.join(".godot", "extension_list.cfg")
        return unless File.exists?(cfg_file)

        prefix = "res://addons/#{addon_name}/"
        lines = File.read_lines(cfg_file)
        filtered = lines.reject { |l| l.starts_with?(prefix) }
        if filtered.size != lines.size
          File.write(cfg_file, filtered.join("\n") + "\n")
        end
      rescue
      end

      # Stages GDExtension runtime dependencies if addon contains .gdextension
      def self.stage_addon_dependencies(addon_dir : Path) : Void
        gdext_files = Dir.glob(addon_dir.join("**/*.gdextension").to_s.gsub('\\', '/'))
        return if gdext_files.empty?

        bin_dir = addon_dir.join("bin")
        FileUtils.mkdir_p(bin_dir) unless Dir.exists?(bin_dir)

        bridge_name = Core::Env.bridge_file
        needed_files = [bridge_name]
        if Core::Env.windows?
          needed_files += ["gc.dll", "iconv-2.dll", "pcre2-8.dll"]
        end

        # GDExtension addons must NEVER contain or link libgodot shared library.
        # Defensively purge any erroneously copied libgodot binaries from addon bin directory.
        libgodot_name = Core::Env.windows? ? "libgodot.dll" : (Core::Env.macos? ? "libgodot.dylib" : "libgodot.so")
        libgodot_lib = "libgodot.lib"
        FileUtils.rm_f(bin_dir.join(libgodot_name)) if File.exists?(bin_dir.join(libgodot_name))
        FileUtils.rm_f(bin_dir.join(libgodot_lib)) if File.exists?(bin_dir.join(libgodot_lib))

        if needed_files.any? { |f| !File.exists?(bin_dir.join(f)) }
          Core::Logger.step("Deps", "Staging GDExtension runtime dependencies into #{bin_dir}...")
          Commands::Deps.run(["-t", bin_dir.to_s, "--addon"])
        end
      end

      # Smart extraction of addon archives
      def self.extract_addon_zip(zip_path : Path, project_root : Path, addon_name : String) : Bool
        FileUtils.mkdir_p(project_root) unless Dir.exists?(project_root)

        has_addons_folder = false
        root_dir_prefix : String? = nil

        # Pre-scan zip entries to determine structure
        File.open(zip_path.to_s) do |f|
          Compress::Zip::Reader.open(f) do |zip|
            zip.each_entry do |entry|
              clean_name = entry.filename.gsub('\\', '/')
              if clean_name.starts_with?("addons/") || clean_name.includes?("/addons/")
                has_addons_folder = true
                if clean_name.includes?("/addons/") && !clean_name.starts_with?("addons/")
                  parts = clean_name.split("/addons/", 2)
                  root_dir_prefix = "#{parts[0]}/"
                end
                break
              end
            end
          end
        end

        file_count = 0
        File.open(zip_path.to_s) do |f|
          Compress::Zip::Reader.open(f) do |zip|
            zip.each_entry do |entry|
              raw_name = entry.filename.gsub('\\', '/')
              clean_name = raw_name

              # Strip top-level repository prefix (e.g. crshader-master/addons/...)
              if (prefix = root_dir_prefix) && clean_name.starts_with?(prefix)
                clean_name = clean_name[prefix.size..]
              end

              dest = if has_addons_folder
                       # Archive contains addons/...
                       if clean_name.starts_with?("addons/")
                         project_root.join(clean_name)
                       else
                         # Skip unrelated top-level repo files (like README, src/) when installing from repo source
                         next
                       end
                     else
                       # Flat archive without addons/ prefix: extract into addons/<addon_name>/
                       project_root.join("addons", addon_name, clean_name)
                     end

              if entry.dir? || clean_name.ends_with?('/')
                FileUtils.mkdir_p(dest)
              else
                FileUtils.mkdir_p(dest.parent)
                File.open(dest, "wb") do |out_io|
                  IO.copy(entry.io, out_io)
                end
                file_count += 1
              end
            end
          end
        end

        Core::Logger.success("Extracted #{file_count} files for addon '#{addon_name}'.")
        true
      rescue ex
        Core::Logger.error("Failed to extract addon archive #{zip_path}: #{ex.message}")
        false
      end

      # Installs an addon into the target Godot project
      def self.install_addon(
        spec : AddonSpec,
        project_dir : Path,
        prefer_release : Bool = false,
        prefer_source : Bool = false,
        auto_enable : Bool = true,
        force : Bool = false,
        also_shard : Bool = false,
        auto_bind : Bool = false,
        path_override : String? = nil,
      ) : Int32
        addon_name = spec.name
        target_addon_dir = project_dir.join("addons", addon_name)

        if Dir.exists?(target_addon_dir) && !force
          Core::Logger.info("Addon directory '#{target_addon_dir}' already exists. Use --force to overwrite.")
        end

        temp_zip = project_dir.join("scratch", "addon_temp_#{::Time.utc.to_unix_ms}.zip")
        FileUtils.mkdir_p(temp_zip.parent)

        begin
          case spec.type
          when :local_file
            local_path = Path.new(spec.path.not_nil!).expand
            unless File.exists?(local_path)
              Core::Logger.error("Local archive file not found: #{local_path}")
              return 1
            end
            Core::Logger.step("Install:Addon", "Installing from local archive #{local_path.basename}...")
            extract_addon_zip(local_path, project_dir, addon_name)

          when :local_dir
            local_path = Path.new(spec.path.not_nil!).expand
            unless Dir.exists?(local_path)
              Core::Logger.error("Local addon directory not found: #{local_path}")
              return 1
            end
            Core::Logger.step("Install:Addon", "Installing from local directory #{local_path}...")
            FileUtils.mkdir_p(target_addon_dir)
            FileUtils.cp_r(local_path.to_s, target_addon_dir.to_s)

          when :github
            owner = spec.owner.not_nil!
            repo = spec.repo.not_nil!
            tag = spec.tag

            Core::Logger.step("Install:Addon", "Resolving addon '#{owner}/#{repo}'#{tag ? " (tag: #{tag})" : ""}...")

            use_release = prefer_release
            unless use_release || prefer_source
              has_addons = repo_has_addons_dir?(owner, repo)
              if !has_addons
                Core::Logger.info("No 'addons/' directory found in #{owner}/#{repo} repository tree. Checking GitHub Releases...")
                use_release = true
              else
                Core::Logger.info("Found 'addons/' directory in #{owner}/#{repo} repository tree.")
              end
            end

            download_url : String? = nil
            download_filename : String? = nil

            if use_release
              if release_asset = find_release_asset_url(owner, repo, tag)
                download_url, download_filename = release_asset
                Core::Logger.step("Install:Addon", "Found release asset '#{download_filename}' from #{download_url}")
              else
                Core::Logger.warn("No suitable release asset found for #{owner}/#{repo}. Falling back to repository source...")
                use_release = false
              end
            end

            unless use_release
              branch = tag || "master"
              download_url = "https://github.com/#{owner}/#{repo}/archive/refs/heads/#{branch}.zip"
              download_filename = "#{repo}-#{branch}.zip"
            end

            url = download_url.not_nil!
            Core::Logger.step("Install:Addon", "Downloading #{download_filename} from #{url}...")
            if !Get.download_file(url, temp_zip)
              # If master branch failed, try main
              if !use_release && (tag.nil? || tag == "master")
                alt_url = "https://github.com/#{owner}/#{repo}/archive/refs/heads/main.zip"
                Core::Logger.info("Retrying with default branch 'main' -> #{alt_url}...")
                if !Get.download_file(alt_url, temp_zip)
                  Core::Logger.error("Failed to download addon archive from #{url} or #{alt_url}")
                  return 1
                end
              else
                Core::Logger.error("Failed to download addon archive from #{url}")
                return 1
              end
            end

            Core::Logger.step("Install:Addon", "Extracting addon into #{project_dir}...")
            extract_addon_zip(temp_zip, project_dir, addon_name)

          when :url
            url = spec.path.not_nil!
            Core::Logger.step("Install:Addon", "Downloading addon archive from #{url}...")
            if !Get.download_file(url, temp_zip)
              Core::Logger.error("Failed to download addon archive from #{url}")
              return 1
            end
            extract_addon_zip(temp_zip, project_dir, addon_name)
          end

          # Post-Install Step 1: Stage GDExtension runtime dependencies if needed
          if Dir.exists?(target_addon_dir)
            stage_addon_dependencies(target_addon_dir)
          end

          # Post-Install Step 2: Auto-enable in project.godot
          if auto_enable
            plugin_cfg_path = target_addon_dir.join("plugin.cfg")
            if File.exists?(plugin_cfg_path)
              rel_cfg = Path.new("addons", addon_name, "plugin.cfg").to_s.gsub('\\', '/')
              enable_in_project_godot(project_dir, rel_cfg)
            else
              # Search for any plugin.cfg inside target_addon_dir or project_dir/addons
              cfgs = Dir.glob(target_addon_dir.join("**/*.plugin.cfg").to_s.gsub('\\', '/')) + Dir.glob(target_addon_dir.join("**/plugin.cfg").to_s.gsub('\\', '/'))
              if cfgs.empty?
                cfgs = Dir.glob(project_dir.join("addons/**/plugin.cfg").to_s.gsub('\\', '/'))
              end
              if first_cfg = cfgs.first?
                rel_cfg = Path.new(first_cfg).relative_to(project_dir).to_s.gsub('\\', '/')
                enable_in_project_godot(project_dir, rel_cfg)
                actual_addon_dir = Path.new(first_cfg).parent
                if Dir.exists?(actual_addon_dir)
                  stage_addon_dependencies(actual_addon_dir)
                  target_addon_dir = actual_addon_dir
                  addon_name = actual_addon_dir.basename
                end
              end
            end
          end

          # Ensure GDExtension is registered in .godot/extension_list.cfg for immediate ClassDB discovery
          register_in_extension_list(project_dir, target_addon_dir)

          # Post-Install Step 3: Add to shard.yml if also_shard requested
          if also_shard
            Core::Logger.step("Addon:Shard", "Adding '#{addon_name}' to shard.yml...")
            ShardManager.add_dependency(
              project_dir,
              addon_name,
              spec,
              path_override: path_override
            )
            ShardManager.run_shards_install(project_dir)
          end

          # Post-Install Step 4: Run auto-binding if requested
          if auto_bind
            Core::Logger.step("Addon:Bind", "Generating typed Crystal bindings for addon nodes...")
            Bind::Project.generate(project_path: project_dir)
          end

          Core::Logger.success("Addon '#{addon_name}' installed successfully into #{target_addon_dir}!")
          puts "\n  Addon: \e[32m#{addon_name}\e[0m"
          puts "  Path:  \e[36m#{target_addon_dir}\e[0m"
          if File.exists?(project_dir.join("project.godot"))
            puts "\nReady to use! Open in editor with: \e[1;36mlapis editor\e[0m"
          end
          0
        ensure
          File.delete(temp_zip) if File.exists?(temp_zip)
        end
      end

      # Uninstalls an addon from the target Godot project
      def self.uninstall_addon(addon_name : String, project_dir : Path, also_shard : Bool = false) : Int32
        target_addon_dir = project_dir.join("addons", addon_name)

        # Unregister from project.godot
        rel_cfg = Path.new("addons", addon_name, "plugin.cfg").to_s.gsub('\\', '/')
        disable_in_project_godot(project_dir, rel_cfg)
        unregister_from_extension_list(project_dir, addon_name)

        if also_shard
          ShardManager.remove_dependency(project_dir, addon_name)
          ShardManager.run_shards_prune(project_dir)
        end

        if Dir.exists?(target_addon_dir)
          FileUtils.rm_rf(target_addon_dir)
          Core::Logger.success("Removed addon directory #{target_addon_dir}")
        else
          Core::Logger.info("Addon directory '#{target_addon_dir}' does not exist.")
        end

        Core::Logger.success("Addon '#{addon_name}' uninstalled successfully.")
        0
      end

      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Addon Package Manager ===\e[0m

Usage:
  lapis install addon <specifier> [options]
  lapis uninstall addon <name> [options]

Specifiers:
  github:owner/repo[@tag]    Install addon from GitHub repository or release
  owner/repo[@tag]           Shorthand GitHub repository or release
  https://github.com/...     Full GitHub repository URL
  path/to/archive.zip        Install from local zip archive
  path/to/directory          Install from local addon directory

Options:
  -p, --project=DIR          Target Godot project directory (default: .)
  -t, --tag=TAG              Specific release tag or branch
  --release                  Force installation from GitHub Releases
  --source                   Force installation from repository source
  --shard                    Also add addon as Crystal dependency in shard.yml
  --bind                     Generate typed Crystal bindings for addon nodes
  --path=DIR                 Local relative path override for shard dependency
  --no-enable                Do not auto-enable plugin in project.godot
  -u, --uninstall            Uninstall specified addon
  -f, --force                Overwrite existing addon files
  -h, --help                 Show this help screen

Examples:
  lapis install addon github:sol-vin/crshader
  lapis install addon sol-vin/crshader@v0.1.0
  lapis install addon ./dist/crshader-windows.zip
  lapis uninstall addon crshader
HELP
      end

      def self.run(args : Array(String)) : Int32
        if args.empty? || args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        project_dir_arg : String? = nil
        tag_arg : String? = nil
        prefer_release = false
        prefer_source = false
        auto_enable = true
        force = false
        uninstall = false
        also_shard = false
        auto_bind = false
        path_override : String? = nil

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis install addon <specifier> [options]"
          opts.on("-p DIR", "--project=DIR", "Target Godot project directory") { |d| project_dir_arg = d }
          opts.on("-t TAG", "--tag=TAG", "Specific release tag or branch") { |t| tag_arg = t }
          opts.on("--release", "Force installation from GitHub Releases") { prefer_release = true }
          opts.on("--source", "Force installation from repository source") { prefer_source = true }
          opts.on("--shard", "Also add addon as Crystal dependency in shard.yml") { also_shard = true }
          opts.on("--bind", "Generate typed Crystal bindings for addon nodes") { auto_bind = true }
          opts.on("--path=DIR", "Local path override for shard dependency") { |d| path_override = d }
          opts.on("--no-enable", "Do not auto-enable plugin in project.godot") { auto_enable = false }
          opts.on("-u", "--uninstall", "Uninstall specified addon") { uninstall = true }
          opts.on("-f", "--force", "Overwrite existing addon files") { force = true }
          opts.on("-h", "--help", "Show help screen") do
            print_help
            exit 0
          end
        end

        remaining = [] of String
        parser.unknown_args { |r| remaining = r }
        parser.parse(args)

        if remaining.empty?
          Core::Logger.error("Missing addon specifier or name.")
          puts
          print_help
          return 1
        end

        target_project = if (p = project_dir_arg) && !p.empty?
                           Path.new(p).expand
                         else
                           Path.new(Dir.current).expand
                         end

        spec_arg = remaining[0]

        if uninstall || remaining.includes?("uninstall")
          addon_name = spec_arg.starts_with?("github:") ? spec_arg.split('/')[1] : spec_arg
          return uninstall_addon(addon_name, target_project, also_shard: also_shard)
        end

        spec = parse_spec(spec_arg)
        # Override tag if explicit option given
        if t = tag_arg
          spec.tag = t
        end

        install_addon(
          spec,
          target_project,
          prefer_release: prefer_release,
          prefer_source: prefer_source,
          auto_enable: auto_enable,
          force: force,
          also_shard: also_shard,
          auto_bind: auto_bind,
          path_override: path_override,
        )
      end
    end
  end
end
