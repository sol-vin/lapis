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
require "opal"

module Lapis
  module Commands
    module InstallAddon
      struct AddonSpec
        property raw : String
        property type : Symbol # :github, :gitlab, :git, :local_file, :local_dir, :url, :invalid_path
        property owner : String?
        property repo : String?
        property tag : String?
        property path : String?
        property error_message : String?

        def initialize(@raw, @type, @owner = nil, @repo = nil, @tag = nil, @path = nil, @error_message = nil)
        end

        def name : String
          if r = @repo
            r
          elsif p = @path
            Path.new(p).basename.rchop(".zip").rchop(".tar.gz").rchop("-windows").rchop("-linux").rchop("-macos")
          else
            "addon"
          end
        end
      end

      struct AddonInfo
        property name : String
        property display_name : String
        property version : String
        property author : String
        property description : String
        property type : Symbol # :source, :compiled, :gdscript
        property dependencies : Array(String)
        property is_recompilable : Bool
        property binary_status : String
        property path : Path

        def initialize(
          @name : String,
          @display_name : String,
          @version : String,
          @author : String,
          @description : String,
          @type : Symbol,
          @dependencies : Array(String),
          @is_recompilable : Bool,
          @binary_status : String,
          @path : Path
        )
        end
      end

      # Inspects an addon directory and extracts metadata, dependencies, and compilation status
      def self.inspect_addon(addon_path : Path | String) : AddonInfo
        dir = Path.new(addon_path).expand
        name = dir.basename
        display_name = name
        version = "0.1.0"
        author = "Unknown"
        description = "No description provided."
        dependencies = [] of String

        cfg_file = dir.join("plugin.cfg")
        if File.exists?(cfg_file)
          begin
            content = File.read(cfg_file)
            content.each_line do |line|
              trimmed = line.strip
              if trimmed.starts_with?("name=") || trimmed.starts_with?("name =")
                if m = trimmed.match(/name\s*=\s*["']([^"']+)["']/)
                  display_name = m[1]
                end
              elsif trimmed.starts_with?("version=") || trimmed.starts_with?("version =")
                if m = trimmed.match(/version\s*=\s*["']([^"']+)["']/)
                  version = m[1]
                end
              elsif trimmed.starts_with?("author=") || trimmed.starts_with?("author =")
                if m = trimmed.match(/author\s*=\s*["']([^"']+)["']/)
                  author = m[1]
                end
              elsif trimmed.starts_with?("description=") || trimmed.starts_with?("description =")
                if m = trimmed.match(/description\s*=\s*["']([^"']+)["']/)
                  description = m[1]
                end
              elsif trimmed.starts_with?("dependencies=") || trimmed.starts_with?("dependencies =")
                if trimmed =~ /dependencies\s*=\s*\[(.*)\]/
                  raw_deps = $1
                  raw_deps.scan(/["']([^"']+)["']/) do |match|
                    dependencies << match[1].strip unless match[1].strip.empty?
                  end
                elsif trimmed =~ /dependencies\s*=\s*["']([^"']+)["']/
                  $1.split(',').each do |d|
                    cleaned = d.strip
                    dependencies << cleaned unless cleaned.empty?
                  end
                end
              end
            end
          rescue
          end
        end

        json_file = dir.join("addon.json")
        if File.exists?(json_file)
          begin
            json_val = ::JSON.parse(File.read(json_file))
            if j_name = json_val["name"]?.try(&.as_s)
              display_name = j_name if display_name == name
            end
            if j_ver = json_val["version"]?.try(&.as_s)
              version = j_ver
            end
            if j_desc = json_val["description"]?.try(&.as_s)
              description = j_desc if description == "No description provided."
            end
            if j_deps = json_val["dependencies"]?.try(&.as_a)
              j_deps.each do |d|
                d_str = d.as_s rescue nil
                dependencies << d_str if d_str && !dependencies.includes?(d_str)
              end
            end
          rescue
          end
        end

        shard_file = dir.join("shard.yml")
        if File.exists?(shard_file)
          begin
            shard_content = File.read(shard_file)
            in_deps = false
            shard_content.each_line do |line|
              if line.starts_with?("dependencies:")
                in_deps = true
                next
              elsif in_deps && line =~ /^[a-zA-Z]/
                in_deps = false
              end
              if in_deps && line =~ /^\s+([a-zA-Z0-9_\-]+):/
                dep_key = $1
                dependencies << dep_key unless ["libgodot", "lapis"].includes?(dep_key) || dependencies.includes?(dep_key)
              end
            end
          rescue
          end
        end

        has_src = Dir.exists?(dir.join("src")) && !Dir.glob(dir.join("src/**/*.cr").to_s.gsub('\\', '/')).empty?
        has_shard = File.exists?(shard_file)
        has_makefile = File.exists?(dir.join("Makefile"))
        is_source = has_src || has_shard || has_makefile

        bin_dir = dir.join("bin")
        bin_files = if Dir.exists?(bin_dir)
                      Dir.children(bin_dir).select { |f| f.ends_with?(".dll") || f.ends_with?(".so") || f.ends_with?(".dylib") }
                        .reject { |f| f.starts_with?("crystal_bridge") || ["gc.dll", "iconv-2.dll", "pcre2-8.dll", "libgodot.dll"].includes?(f) }
                    else
                      [] of String
                    end
        has_gdext = !Dir.glob(dir.join("**/*.gdextension").to_s.gsub('\\', '/')).empty?

        type = if is_source
                 :source
               elsif has_gdext || !bin_files.empty?
                 :compiled
               else
                 :gdscript
               end

        is_recompilable = is_source

        binary_status = case type
                        when :source
                          if bin_files.empty?
                            "Missing binary"
                          else
                            main_cr = dir.join("src", "main.cr")
                            src_target = File.exists?(main_cr) ? main_cr : (Dir.glob(dir.join("src/**/*.cr").to_s.gsub('\\', '/')).first? ? Path.new(Dir.glob(dir.join("src/**/*.cr").to_s.gsub('\\', '/')).first) : nil)
                            if src_target && File.exists?(src_target)
                              src_time = File.info(src_target).modification_time
                              bin_time = File.info(dir.join("bin", bin_files[0])).modification_time
                              if src_time > bin_time
                                "Needs recompile"
                              else
                                "Up-to-date"
                              end
                            else
                              "Up-to-date"
                            end
                          end
                        when :compiled
                          bin_files.empty? ? "Missing binary" : "Ready (Precompiled)"
                        else
                          "Ready (GDScript)"
                        end

        AddonInfo.new(
          name: name,
          display_name: display_name,
          version: version,
          author: author,
          description: description,
          type: type,
          dependencies: dependencies.uniq,
          is_recompilable: is_recompilable,
          binary_status: binary_status,
          path: dir
        )
      end

      # Checks if a given filepath or directory represents a valid Crystal Godot addon
      def self.is_crystal_addon?(path_str : String) : Bool
        p = Path.new(path_str).expand
        if File.file?(p)
          if p.extension == ".zip"
            begin
              File.open(p.to_s) do |f|
                Compress::Zip::Reader.open(f) do |zip|
                  found = false
                  zip.each_entry do |entry|
                    fn = entry.filename.gsub('\\', '/')
                    if fn.ends_with?(".gdextension") || fn.ends_with?("plugin.cfg") || fn.ends_with?("shard.yml") || fn.includes?("crystal_bridge")
                      found = true
                      break
                    end
                  end
                  return found
                end
              end
            rescue
              return false
            end
          end
          return false
        elsif Dir.exists?(p)
          # Check for .gdextension
          return true if Dir.glob(p.join("**/*.gdextension").to_s.gsub('\\', '/')).size > 0
          # Check for plugin.cfg
          return true if Dir.glob(p.join("**/plugin.cfg").to_s.gsub('\\', '/')).size > 0
          # Check for shard.yml or crystal sources
          return true if File.exists?(p.join("shard.yml")) || Dir.glob(p.join("**/*.cr").to_s.gsub('\\', '/')).size > 0
          # Check for crystal_bridge
          return true if Dir.glob(p.join("**/crystal_bridge.*").to_s.gsub('\\', '/')).size > 0
          false
        else
          false
        end
      end

      # Parse specifier string:
      # - github:owner/repo[@tag]
      # - gitlab:owner/repo[@tag]
      # - git:url[@branch|tag]
      # - https://github.com/owner/repo[.git][@tag]
      # - https://gitlab.com/owner/repo[.git][@tag]
      # - local/path/to/addon.zip (fallback)
      # - local/path/to/addon_dir (fallback)
      def self.parse_spec(raw : String) : AddonSpec
        spec = raw.strip

        # Extract @tag or @branch if present at end (unless it's part of an existing local path)
        tag : String? = nil
        if spec.includes?("@") && !spec.starts_with?("@") && !File.exists?(spec) && !Dir.exists?(spec)
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

        # Check gitlab: or gl: prefix
        if spec.starts_with?("gitlab:") || spec.starts_with?("gl:")
          repo_part = spec.split(':', 2)[1]
          parts = repo_part.split('/')
          if parts.size >= 2
            owner = parts[0...-1].join('/')
            repo = parts.last
            return AddonSpec.new(raw, :gitlab, owner, repo, tag)
          end
        end

        # Check git: prefix (always assumed to be source code)
        if spec.starts_with?("git:")
          git_url = spec.split(':', 2)[1]
          repo_name = Path.new(git_url.split('/').last).basename.rchop(".git")
          return AddonSpec.new(raw, :git, repo: repo_name, tag: tag, path: git_url)
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
          elsif uri.host == "gitlab.com" || uri.host == "www.gitlab.com"
            path_parts = uri.path.strip('/').split('/')
            if path_parts.size >= 2
              owner = path_parts[0...-1].join('/')
              repo = path_parts.last.rchop(".git")
              return AddonSpec.new(raw, :gitlab, owner, repo, tag)
            end
          elsif spec.ends_with?(".git")
            repo_name = Path.new(spec.split('/').last).basename.rchop(".git")
            return AddonSpec.new(raw, :git, repo: repo_name, tag: tag, path: spec)
          end
          return AddonSpec.new(raw, :url, path: spec, tag: tag)
        end

        # Silent fallback to local filepath (checks for zip or folder and verifies it is a Crystal addon)
        if is_crystal_addon?(spec)
          if File.file?(spec) || spec.ends_with?(".zip") || spec.ends_with?(".tar.gz")
            return AddonSpec.new(raw, :local_file, path: spec)
          else
            return AddonSpec.new(raw, :local_dir, path: spec)
          end
        end

        if File.exists?(spec) || Dir.exists?(spec)
          return AddonSpec.new(
            raw,
            :invalid_path,
            path: spec,
            error_message: "Path '#{spec}' is not a valid Crystal Godot addon (missing .gdextension, plugin.cfg, or shard.yml)."
          )
        end

        AddonSpec.new(
          raw,
          :invalid_path,
          path: spec,
          error_message: "No Crystal addon found at path '#{spec}'. To install from remote repositories, use an explicit provider ID: 'github:owner/repo', 'gitlab:owner/repo', or 'git:url'."
        )
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

      # Checks if GitHub repository has source code (src/, *.cr, shard.yml, or addons/)
      def self.repo_has_source_code?(owner : String, repo : String) : Bool
        resp = github_api_get("/repos/#{owner}/#{repo}/contents")
        if resp && resp.status_code == 200
          begin
            entries = ::JSON.parse(resp.body).as_a
            return entries.any? do |e|
              name = e["name"]?.try(&.as_s) || ""
              type = e["type"]?.try(&.as_s) || ""
              (name == "src" && type == "dir") ||
              (name == "addons" && type == "dir") ||
              (name == "shard.yml") ||
              name.ends_with?(".cr")
            end
          rescue
          end
        end
        false
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
        # If /releases/latest returned 404 or empty (e.g. pre-releases only), fall back to checking all releases
        if (resp.nil? || resp.status_code != 200) && (tag.nil? || tag.empty? || tag.downcase == "latest")
          resp = github_api_get("/repos/#{owner}/#{repo}/releases")
          if resp && resp.status_code == 200
            begin
              releases = ::JSON.parse(resp.body).as_a
              if first_rel = releases.first?
                assets = first_rel["assets"]?.try(&.as_a) || [] of ::JSON::Any
                plat = platform.downcase
                matched = assets.find do |a|
                  name = a["name"]?.try(&.as_s.downcase) || ""
                  name.includes?(plat) && (name.ends_with?(".zip") || name.ends_with?(".tar.gz"))
                end
                matched ||= assets.find do |a|
                  name = a["name"]?.try(&.as_s.downcase) || ""
                  name.ends_with?(".zip") && !name.includes?("linux") && !name.includes?("macos") && !name.includes?("windows")
                end
                if matched && (url = matched["browser_download_url"]?.try(&.as_s)) && (name = matched["name"]?.try(&.as_s))
                  return {url, name}
                end
              end
            rescue
            end
          end
        end

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
          name.ends_with?(".zip") && !name.includes?("linux") && !name.includes?("macos") && !name.includes?("windows")
        end

        matched ||= assets.first?

        if matched && (url = matched["browser_download_url"]?.try(&.as_s)) && (name = matched["name"]?.try(&.as_s))
          {url, name}
        else
          fallback_filename = "#{repo}-#{platform.downcase}.zip"
          fallback_url = if tag && !tag.empty? && tag.downcase != "latest"
                           clean_tag = tag.starts_with?("v") ? tag : "v#{tag}"
                           "https://github.com/#{owner}/#{repo}/releases/download/#{clean_tag}/#{fallback_filename}"
                         else
                           "https://github.com/#{owner}/#{repo}/releases/latest/download/#{fallback_filename}"
                         end
          {fallback_url, fallback_filename}
        end
      rescue ex
        Core::Logger.debug("Notice: Error parsing GitHub release: #{ex.message}")
        fallback_filename = "#{repo}-#{platform.downcase}.zip"
        fallback_url = if tag && !tag.empty? && tag.downcase != "latest"
                         clean_tag = tag.starts_with?("v") ? tag : "v#{tag}"
                         "https://github.com/#{owner}/#{repo}/releases/download/#{clean_tag}/#{fallback_filename}"
                       else
                         "https://github.com/#{owner}/#{repo}/releases/latest/download/#{fallback_filename}"
                       end
        {fallback_url, fallback_filename}
      end

      def self.gitlab_api_get(path : String) : HTTP::Client::Response?
        uri = URI.parse("https://gitlab.com")
        client = HTTP::Client.new(uri)
        client.connect_timeout = 10.seconds
        client.read_timeout = 15.seconds
        headers = HTTP::Headers{
          "User-Agent" => "Lapis-CLI/#{Lapis::VERSION}",
          "Accept"     => "application/json",
        }
        if (t = ENV["GITLAB_TOKEN"]?) && !t.empty?
          headers["PRIVATE-TOKEN"] = t
        end
        client.get(path, headers: headers)
      rescue
        nil
      end

      # Checks if GitLab repository has source code (src/, addons/, shard.yml, *.cr)
      def self.gitlab_repo_has_source_code?(owner : String, repo : String) : Bool
        proj_encoded = URI.encode_path("#{owner}/#{repo}")
        resp = gitlab_api_get("/api/v4/projects/#{proj_encoded}/repository/tree")
        if resp && resp.status_code == 200
          begin
            entries = ::JSON.parse(resp.body).as_a
            return entries.any? do |e|
              name = e["name"]?.try(&.as_s) || ""
              type = e["type"]?.try(&.as_s) || ""
              (name == "src" && type == "tree") ||
              (name == "addons" && type == "tree") ||
              (name == "shard.yml") ||
              name.ends_with?(".cr")
            end
          rescue
          end
        end
        false
      end

      # Queries GitLab Releases for matching release asset
      def self.find_gitlab_release_asset_url(
        owner : String,
        repo : String,
        tag : String? = nil,
        platform : String = Core::Env.current_platform,
      ) : Tuple(String, String)?
        proj_encoded = URI.encode_path("#{owner}/#{repo}")
        resp = gitlab_api_get("/api/v4/projects/#{proj_encoded}/releases")
        return nil unless resp && resp.status_code == 200
        releases = ::JSON.parse(resp.body).as_a
        return nil if releases.empty?

        target_release = if tag && !tag.empty? && tag.downcase != "latest"
                           clean_tag = tag.starts_with?("v") ? tag : "v#{tag}"
                           releases.find { |r| r["tag_name"]?.try(&.as_s) == clean_tag || r["tag_name"]?.try(&.as_s) == tag }
                         else
                           releases.first?
                         end
        return nil unless target_release

        assets = target_release["assets"]?.try(&.["links"]?).try(&.as_a) || [] of ::JSON::Any
        plat = platform.downcase
        matched = assets.find do |a|
          name = a["name"]?.try(&.as_s.downcase) || ""
          name.includes?(plat) && (name.ends_with?(".zip") || name.ends_with?(".tar.gz"))
        end
        matched ||= assets.find do |a|
          name = a["name"]?.try(&.as_s.downcase) || ""
          name.ends_with?(".zip") && !name.includes?("linux") && !name.includes?("macos") && !name.includes?("windows")
        end

        if matched && (url = matched["url"]?.try(&.as_s)) && (name = matched["name"]?.try(&.as_s))
          {url, name}
        else
          nil
        end
      rescue
        nil
      end

      # Copies or extracts an addon from a local cloned or unpacked directory
      def self.extract_addon_from_folder(source_dir : Path, project_root : Path, addon_name : String) : Void
        target_addon = project_root.join("addons", addon_name)
        FileUtils.mkdir_p(target_addon)

        # Check if source_dir contains addons/<addon_name>
        candidate = source_dir.join("addons", addon_name)
        if Dir.exists?(candidate)
          FileUtils.cp_r(candidate.to_s, target_addon.to_s)
          return
        end

        # Check if source_dir contains addons/<any>
        src_addons = source_dir.join("addons")
        if Dir.exists?(src_addons)
          if first_sub = Dir.children(src_addons).find { |c| Dir.exists?(src_addons.join(c)) }
            FileUtils.cp_r(src_addons.join(first_sub).to_s, target_addon.to_s)
            return
          end
        end

        # Otherwise copy root files (excluding .git)
        Dir.each_child(source_dir) do |child|
          next if child == ".git"
          src_item = source_dir.join(child)
          if File.file?(src_item)
            FileUtils.cp(src_item, target_addon.join(child))
          elsif Dir.exists?(src_item)
            FileUtils.cp_r(src_item.to_s, target_addon.join(child).to_s)
          end
        end
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

        # Always maintain crystal_integration as the first extension entry
        primary_ext = "res://addons/crystal_integration/crystal.gdextension"
        if Dir.exists?(project_dir.join("addons", "crystal_integration"))
          if existing_lines.includes?(primary_ext)
            if existing_lines.first? != primary_ext
              existing_lines.delete(primary_ext)
              existing_lines.unshift(primary_ext)
              updated = true
            end
          else
            existing_lines.unshift(primary_ext)
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
                         # Do not leak third-party/unbuilt crystal_integration from addon repos unless crystal_integration is specifically targeted
                         if clean_name.starts_with?("addons/crystal_integration/") || clean_name == "addons/crystal_integration"
                           next unless addon_name == "crystal_integration"
                         end
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
        visited : Set(String) = Set(String).new,
      ) : Int32
        addon_name = spec.name
        if visited.includes?(addon_name)
          Core::Logger.info("Addon '#{addon_name}' already processed in current dependency graph.")
          return 0
        end
        visited << addon_name

        target_addon_dir = project_dir.join("addons", addon_name)

        if Dir.exists?(target_addon_dir) && !force
          Core::Logger.info("Addon directory '#{target_addon_dir}' already exists. Use --force to overwrite.")
        end

        temp_zip = project_dir.join("scratch", "addon_temp_#{::Time.utc.to_unix_ms}.zip")
        FileUtils.mkdir_p(temp_zip.parent)

        begin
          case spec.type
          when :invalid_path
            Core::Logger.error(spec.error_message || "Invalid addon path: #{spec.raw}")
            return 1

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

          when :git
            git_url = spec.path || spec.raw.sub(/^git:/, "")
            Core::Logger.step("Install:Addon", "Cloning git repository from #{git_url} (source mode)...")
            git_bin = Process.find_executable("git")
            unless git_bin
              Core::Logger.error("Git executable not found in PATH to clone #{git_url}")
              return 1
            end
            clone_stage = project_dir.join("scratch", "addon_git_#{::Time.utc.to_unix_ms}")
            FileUtils.rm_rf(clone_stage) if Dir.exists?(clone_stage)
            clone_args = ["clone", "--depth", "1"]
            if t = spec.tag
              clone_args += ["--branch", t]
            end
            clone_args += [git_url, clone_stage.to_s]
            res = Core::ProcessRunner.run(git_bin, clone_args)
            unless res.success?
              Core::Logger.error("Failed to clone git repository from #{git_url}")
              FileUtils.rm_rf(clone_stage) if Dir.exists?(clone_stage)
              return 1
            end
            extract_addon_from_folder(clone_stage, project_dir, addon_name)
            FileUtils.rm_rf(clone_stage) if Dir.exists?(clone_stage)

          when :gitlab
            owner = spec.owner.not_nil!
            repo = spec.repo.not_nil!
            tag = spec.tag

            Core::Logger.step("Install:Addon", "Resolving GitLab addon '#{owner}/#{repo}'#{tag ? " (tag: #{tag})" : ""}...")

            download_url : String? = nil
            download_filename : String? = nil

            # Step 1: Check GitLab Releases first (unless --source explicitly requested)
            if !prefer_source
              if release_asset = find_gitlab_release_asset_url(owner, repo, tag)
                download_url, download_filename = release_asset
                Core::Logger.step("Install:Addon", "Found GitLab release asset '#{download_filename}' from #{download_url}")
              end
            end

            # Step 2: Fall back to repository source if release not available or --source requested
            if download_url.nil?
              if prefer_release
                Core::Logger.error("No suitable release asset found for #{owner}/#{repo} on platform #{Core::Env.current_platform}")
                return 1
              end
              has_source = gitlab_repo_has_source_code?(owner, repo)
              if has_source
                Core::Logger.info("Found source code in #{owner}/#{repo} GitLab repository tree.")
              end
              ref_name = tag || "main"
              download_url = "https://gitlab.com/#{owner}/#{repo}/-/archive/#{ref_name}/#{repo}-#{ref_name}.zip"
              download_filename = "#{repo}-#{ref_name}.zip"
            end

            url = download_url.not_nil!
            Core::Logger.step("Install:Addon", "Downloading #{download_filename} from #{url}...")
            if !Get.download_file(url, temp_zip)
              Core::Logger.error("Failed to download addon archive from #{url}")
              return 1
            end
            extract_addon_zip(temp_zip, project_dir, addon_name)

          when :github
            owner = spec.owner.not_nil!
            repo = spec.repo.not_nil!
            tag = spec.tag

            Core::Logger.step("Install:Addon", "Resolving GitHub addon '#{owner}/#{repo}'#{tag ? " (tag: #{tag})" : ""}...")

            download_url = nil
            download_filename = nil

            # Step 1: Check GitHub Releases first (unless --source explicitly requested)
            if !prefer_source
              if release_asset = find_release_asset_url(owner, repo, tag)
                download_url, download_filename = release_asset
                Core::Logger.step("Install:Addon", "Found release asset '#{download_filename}' from #{download_url}")
              end
            end

            # Step 2: Fall back to repository source if release not available or --source requested
            if download_url.nil?
              if prefer_release
                Core::Logger.error("No suitable release asset found for #{owner}/#{repo} on platform #{Core::Env.current_platform}")
                return 1
              end
              has_source = repo_has_source_code?(owner, repo)
              if has_source
                Core::Logger.info("Found source code in #{owner}/#{repo} GitHub repository tree.")
              end
              branch = tag || "main"
              download_url = "https://github.com/#{owner}/#{repo}/archive/refs/heads/#{branch}.zip"
              download_filename = "#{repo}-#{branch}.zip"
            end

            url = download_url.not_nil!
            Core::Logger.step("Install:Addon", "Downloading #{download_filename} from #{url}...")
            if !Get.download_file(url, temp_zip)
              # If main/master branch failed, try the other
              alt_url = if url.includes?("/heads/main.zip")
                          "https://github.com/#{owner}/#{repo}/archive/refs/heads/master.zip"
                        elsif url.includes?("/heads/master.zip")
                          "https://github.com/#{owner}/#{repo}/archive/refs/heads/main.zip"
                        else
                          nil
                        end
              if alt_url && tag.nil?
                Core::Logger.info("Retrying with alternative branch -> #{alt_url}...")
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

          # Post-Install Step 2b: Recursive Addon Dependency Resolution
          addon_info = inspect_addon(target_addon_dir)
          if !addon_info.dependencies.empty?
            Core::Logger.step("Addon:Dependencies", "Resolving #{addon_info.dependencies.size} dependencies for '#{addon_name}': #{addon_info.dependencies.join(", ")}...")
            addon_info.dependencies.each do |dep_spec_str|
              dep_spec = parse_spec(dep_spec_str)
              dep_target = project_dir.join("addons", dep_spec.name)
              if Dir.exists?(dep_target)
                Core::Logger.info("Dependency '#{dep_spec.name}' already installed at #{dep_target}")
              else
                Core::Logger.step("Install:Dependency", "Installing required dependency '#{dep_spec_str}' for '#{addon_name}'...")
                install_addon(
                  dep_spec,
                  project_dir,
                  prefer_release: prefer_release,
                  prefer_source: prefer_source,
                  auto_enable: auto_enable,
                  force: false,
                  also_shard: also_shard,
                  auto_bind: auto_bind,
                  visited: visited
                )
              end
            end
          end

          # Post-Install Step 3: Track addon in shard.yml under addons: key
          ShardManager.add_addon(
            project_dir,
            addon_name,
            spec,
            branch: (spec.type == :git ? spec.tag : nil),
            tag: spec.tag,
            version: spec.tag,
            path_override: path_override
          )

          # Post-Install Step 3b: If also_shard requested, also track in dependencies:
          if also_shard
            Core::Logger.step("Addon:Shard", "Adding '#{addon_name}' to shard.yml dependencies...")
            ShardManager.add_dependency(
              project_dir,
              addon_name,
              spec,
              path_override: path_override
            )
            ShardManager.run_shards_install(project_dir)
          end

          # Post-Install Step 3c: Run AddonNegotiator to ensure version deduplication
          negotiated_ok, _, neg_errors = ShardManager::AddonNegotiator.negotiate_project_addons(project_dir)
          unless negotiated_ok
            neg_errors.each { |err| Core::Logger.warn("Addon Dependency Warning: #{err}") }
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

        # Always untrack from addons: section in shard.yml
        ShardManager.remove_addon(project_dir, addon_name)

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
  github:owner/repo[@tag]    Install addon from GitHub repository (source or release)
  gitlab:owner/repo[@tag]    Install addon from GitLab repository (source or release)
  git:url[@branch|tag]       Install addon from Git repository (always source)
  path/to/archive.zip        Install from local Crystal addon zip archive
  path/to/directory          Install from local Crystal addon directory

Options:
  -p, --project=DIR          Target Godot project directory (default: .)
  -t, --tag=TAG              Specific release tag or branch
  --release                  Prefer pre-compiled release binaries over source
  --source                   Prefer repository source over pre-compiled release
  --shard                    Also add addon as Crystal dependency in shard.yml
  --bind                     Generate typed Crystal bindings for addon nodes
  --path=DIR                 Local relative path override for shard dependency
  --no-enable                Do not auto-enable plugin in project.godot
  -u, --uninstall            Uninstall specified addon
  -f, --force                Overwrite existing addon files
  -h, --help                 Show this help screen

Examples:
  lapis install addon github:sol-vin/crshader
  lapis install addon gitlab:my-group/my-addon@v1.0.0
  lapis install addon git:https://example.com/dialogue.git
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

        if spec_arg == "list" || spec_arg == "ls"
          addons_dir = target_project.join("addons")
          unless Dir.exists?(addons_dir)
            Core::Logger.info("No addons directory found in #{target_project}")
            return 0
          end
          installed = Dir.children(addons_dir).select { |c| Dir.exists?(addons_dir.join(c)) }
          if installed.empty?
            Core::Logger.info("No addons installed in #{target_project.join("addons")}")
            return 0
          end

          puts
          puts Opal.style.bold.fg(:cyan).render("  📦 Installed Godot Addons (#{target_project.basename}):")
          puts

          tbl = Opal::UI::Table.new(
            headers: ["Addon Name", "Version", "Type", "Status", "Dependencies", "Description"],
            header_fg: :cyan
          )

          installed.each do |addon|
            a_dir = addons_dir.join(addon)
            info = inspect_addon(a_dir)
            type_str = case info.type
                       when :source   then "Source"
                       when :compiled then "GDExtension"
                       else                "GDScript"
                       end
            deps_str = info.dependencies.empty? ? "-" : info.dependencies.join(", ")
            desc_short = info.description.lines.first?.try(&.strip) || "No description"
            desc_short = desc_short[0...35] + "..." if desc_short.size > 38

            tbl.row([
              info.display_name,
              info.version,
              type_str,
              info.binary_status,
              deps_str,
              desc_short
            ])
          end

          puts tbl.to_print_s(width: 120)
          puts
          return 0
        end

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
