require "../core/env"
require "../core/logger"
require "../core/process_runner"
require "file_utils"
require "option_parser"
require "compress/zip"
require "compress/gzip"
require "http/client"

module Lapis
  module Commands
    module Get
      REPO = "sol-vin/lapis"

      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Release & Source Code Downloader ===\e[0m

Usage:
  lapis get source [options]
  lapis get release [platform] [kind] [options]

Subcommands:
  source                 Download or clone Lapis source code from GitHub
  release [plat] [kind]  Download official compiled release archives

Platforms (default: host operating system):
  windows, win, win64    Microsoft Windows x86_64
  linux, linux64         Linux x86_64
  mac, macos, darwin     macOS Universal / ARM64

Release Kinds:
  cli, lapis             Standalone Lapis CLI executable archive (default)
  examples               Showcase example projects archive
  benchmark, benchmarks  Crystal vs GDScript benchmark suite
  performance, perf      Engine stress test & performance suite
  tests, test            Standalone test runner and test suites
  addon                  Redistributable crystal_integration addon
  template               Game starter template archive
  template-addon         Addon starter template archive
  all                    Download all release archives for platform

Options:
  -o, --output=PATH      Output destination directory or filename (default: .)
  -x, --extract          Automatically extract downloaded archive
  -t, --tag=TAG          Specific release tag (default: latest)
  -f, --force            Overwrite existing files
  --list                 List available release assets without downloading
  -b, --branch=BRANCH    Git branch to clone (source only, default: master)
  --shallow              Perform shallow git clone with depth 1 (source only)
  --zip                  Download source zip archive instead of git clone (source only)
  -h, --help             Show this help screen

Examples:
  lapis get source
  lapis get release windows
  lapis get release windows examples
  lapis get release windows benchmark
  lapis get release linux performance
  lapis get release mac tests
  lapis get release examples -x
  lapis get release all
HELP
      end

      # Normalize platform name into standard identifier: "windows", "linux", "macos"
      def self.normalize_platform(raw : String?) : String
        case raw.to_s.downcase.strip
        when "windows", "win", "win64", "win32"
          "windows"
        when "linux", "linux64", "ubuntu", "debian"
          "linux"
        when "mac", "macos", "darwin", "osx", "apple"
          "macos"
        else
          Core::Env.windows? ? "windows" : (Core::Env.macos? ? "macos" : "linux")
        end
      end

      def self.is_platform_name?(arg : String) : Bool
        ["windows", "win", "win64", "linux", "linux64", "mac", "macos", "darwin"].includes?(arg.downcase)
      end

      # Resolves asset filenames for a given platform and kind
      def self.resolve_asset_names(plat : String, kind : String) : Array(String)
        case kind.downcase
        when "cli", "lapis", "bin"
          case plat
          when "windows"
            ["lapis-windows-x86_64.zip"]
          when "macos"
            ["lapis-macos.zip"]
          else
            ["lapis-linux-x86_64.tar.gz"]
          end
        when "installer", "setup"
          case plat
          when "windows"
            ["lapis-setup-windows-x86_64.exe"]
          when "linux"
            ["lapis_#{Lapis::VERSION}_amd64.deb"]
          else
            ["lapis-macos.zip"]
          end
        when "deb"
          ["lapis_#{Lapis::VERSION}_amd64.deb"]
        when "examples", "example"
          ["examples-#{plat}.zip", "examples-#{plat}-x86_64.zip"]
        when "benchmark", "benchmarks"
          ["benchmarks-#{plat}.zip"]
        when "perf", "performance"
          ["perf-#{plat}.zip"]
        when "tests", "test"
          ["test-suite-#{plat}.zip"]
        when "addon", "crystal-addon", "crystal_addon"
          ["godot-crystal-addon-#{plat}.zip", "godot-crystal-addon.zip"]
        when "template"
          ["template-project.zip"]
        when "template-addon", "template_addon"
          ["template-addon-project.zip"]
        when "all"
          [
            plat == "windows" ? "lapis-windows-x86_64.zip" : (plat == "macos" ? "lapis-macos.zip" : "lapis-linux-x86_64.tar.gz"),
            "examples-#{plat}.zip",
            "benchmarks-#{plat}.zip",
            "perf-#{plat}.zip",
            "test-suite-#{plat}.zip",
            "godot-crystal-addon-#{plat}.zip",
            "template-project.zip",
            "template-addon-project.zip",
          ]
        else
          ["#{kind}-#{plat}.zip", "#{kind}.zip"]
        end
      end

      # Download URL builder
      def self.asset_url(repo : String, tag : String?, filename : String) : String
        if tag && !tag.empty? && tag.downcase != "latest"
          clean_tag = tag.starts_with?("v") ? tag : "v#{tag}"
          "https://github.com/#{repo}/releases/download/#{clean_tag}/#{filename}"
        else
          "https://github.com/#{repo}/releases/latest/download/#{filename}"
        end
      end

      # Downloads a remote URL to dest_file, handling HTTP redirects and progress
      def self.download_file(url : String, dest_file : Path, max_retries : Int32 = 3) : Bool
        attempts = 0
        while attempts < max_retries
          attempts += 1
          begin
            Core::Logger.trace("Get:Download", "GET #{url} (attempt #{attempts})")
            uri = URI.parse(url)
            client = HTTP::Client.new(uri)
            client.connect_timeout = 15.seconds
            client.read_timeout = 60.seconds

            path_and_query = uri.request_target

            success = client.get(path_and_query) do |response|
              if response.status_code == 301 || response.status_code == 302 || response.status_code == 307 || response.status_code == 308
                redirect_url = response.headers["Location"]?
                if redirect_url
                  Core::Logger.debug("Following redirect -> #{redirect_url}")
                  return download_file(redirect_url, dest_file, max_retries - attempts + 1)
                end
              end

              unless response.status_code == 200
                Core::Logger.warn("HTTP #{response.status_code} downloading #{url} (attempt #{attempts}/#{max_retries})")
                next false
              end

              FileUtils.mkdir_p(dest_file.parent) unless Dir.exists?(dest_file.parent)
              File.open(dest_file, "wb") do |f|
                IO.copy(response.body_io, f)
              end
              true
            end

            return true if success
          rescue ex
            Core::Logger.warn("Network error downloading #{url}: #{ex.message} (attempt #{attempts}/#{max_retries})")
          end

          if attempts < max_retries
            sleep 1.seconds
          end
        end

        Core::Logger.error("Failed to download #{url} after #{max_retries} attempts.")
        false
      end

      # Extracts a zip archive to target directory
      def self.extract_zip(zip_path : Path, target_dir : Path) : Bool
        FileUtils.mkdir_p(target_dir) unless Dir.exists?(target_dir)
        count = 0
        File.open(zip_path.to_s) do |f|
          Compress::Zip::Reader.open(f) do |zip|
            zip.each_entry do |entry|
              name = entry.filename
              clean_name = name.gsub('\\', '/')
              dest = target_dir.join(clean_name)
              if entry.dir? || clean_name.ends_with?('/')
                FileUtils.mkdir_p(dest)
              else
                FileUtils.mkdir_p(dest.parent)
                File.open(dest, "wb") do |out_io|
                  IO.copy(entry.io, out_io)
                end
                count += 1
              end
            end
          end
        end
        Core::Logger.success("Extracted #{count} files from #{zip_path.basename} into #{target_dir}.")
        true
      rescue ex
        Core::Logger.error("Failed to extract zip archive #{zip_path}: #{ex.message}")
        false
      end

      # Extracts a tar.gz archive to target directory
      def self.extract_tar_gz(tar_path : Path, target_dir : Path) : Bool
        FileUtils.mkdir_p(target_dir) unless Dir.exists?(target_dir)
        if Process.find_executable("tar")
          res = Core::ProcessRunner.capture("tar", ["-xzf", tar_path.to_s, "-C", target_dir.to_s])
          if res[:status] == 0
            Core::Logger.success("Extracted #{tar_path.basename} into #{target_dir}.")
            return true
          end
        end
        Core::Logger.warn("Notice: Tar command not available or extraction failed for #{tar_path}.")
        false
      rescue ex
        Core::Logger.error("Failed to extract tar archive #{tar_path}: #{ex.message}")
        false
      end

      def self.get_source(args : Array(String)) : Int32
        dir_arg : String? = nil
        branch = "master"
        tag : String? = nil
        shallow = true
        use_zip = false
        force = false

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis get source [options]"
          opts.on("-d DIR", "--dir=DIR", "Destination directory (default: ./lapis)") { |d| dir_arg = d }
          opts.on("-b BRANCH", "--branch=BRANCH", "Git branch to clone (default: master)") { |b| branch = b }
          opts.on("-t TAG", "--tag=TAG", "Git tag to checkout") { |t| tag = t }
          opts.on("--shallow", "Perform shallow clone (depth 1, default)") { shallow = true }
          opts.on("--no-shallow", "Perform full clone") { shallow = false }
          opts.on("--zip", "Download zip archive instead of git clone") { use_zip = true }
          opts.on("-f", "--force", "Overwrite existing directory") { force = true }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
        end

        remaining = [] of String
        parser.unknown_args { |r| remaining = r }
        parser.parse(args)

        dest_dir = if (d = dir_arg) && !d.empty?
                     Path.new(d).expand
                   elsif !remaining.empty?
                     Path.new(remaining.first).expand
                   else
                     Path.new(Dir.current).join("lapis").expand
                   end

        if Dir.exists?(dest_dir)
          entries = Dir.children(dest_dir).reject { |c| c.starts_with?(".") }
          if !entries.empty? && !force
            Core::Logger.error("Target directory '#{dest_dir}' is not empty. Use --force to proceed.")
            return 1
          end
        end

        has_git = !use_zip && !Process.find_executable("git").nil?

        if has_git
          clone_args = ["clone"]
          clone_args += ["--depth", "1"] if shallow && tag.nil?
          if t = tag
            clone_args += ["-b", t]
          elsif branch != "master"
            clone_args += ["-b", branch]
          end
          clone_args += ["https://github.com/#{REPO}.git", dest_dir.to_s]

          Core::Logger.step("Get:Source", "Cloning Lapis repository from GitHub into #{dest_dir}...")
          status = Process.run("git", clone_args)
          if status.success?
            Core::Logger.success("Lapis source code cloned successfully to #{dest_dir}!")
            return 0
          else
            Core::Logger.warn("Git clone failed, falling back to zip download...")
          end
        end

        # Fallback / Zip mode
        zip_url = if t = tag
                    clean_t = t.starts_with?("v") ? t : "v#{t}"
                    "https://github.com/#{REPO}/archive/refs/tags/#{clean_t}.zip"
                  else
                    "https://github.com/#{REPO}/archive/refs/heads/#{branch}.zip"
                  end

        temp_zip = dest_dir.parent.join("lapis_source_temp_#{Time.utc.to_unix_ms}.zip")
        begin
          Core::Logger.step("Get:Source", "Downloading Lapis source archive from #{zip_url}...")
          success = download_file(zip_url, temp_zip)
          unless success && File.exists?(temp_zip)
            Core::Logger.error("Failed to download Lapis source archive from #{zip_url}.")
            return 1
          end

          Core::Logger.step("Get:Source", "Extracting source archive into #{dest_dir}...")
          FileUtils.mkdir_p(dest_dir)
          File.open(temp_zip.to_s) do |f|
            Compress::Zip::Reader.open(f) do |zip|
              zip.each_entry do |entry|
                name = entry.filename
                # Strip root prefix (e.g. lapis-master/ or lapis-1.0.0/)
                parts = name.split('/', 2)
                sub_path = parts.size > 1 ? parts[1] : ""
                next if sub_path.empty?

                dest = dest_dir.join(sub_path)
                if entry.dir? || sub_path.ends_with?('/')
                  FileUtils.mkdir_p(dest)
                else
                  FileUtils.mkdir_p(dest.parent)
                  File.open(dest, "wb") do |out_io|
                    IO.copy(entry.io, out_io)
                  end
                end
              end
            end
          end

          Core::Logger.success("Lapis source archive extracted successfully to #{dest_dir}!")
          0
        ensure
          File.delete(temp_zip) if File.exists?(temp_zip)
        end
      end

      def self.get_release(args : Array(String)) : Int32
        out_arg : String? = nil
        extract = false
        tag : String? = nil
        force = false
        list_only = false

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis get release [platform] [kind] [options]"
          opts.on("-o PATH", "--output=PATH", "Destination file or directory") { |o| out_arg = o }
          opts.on("-x", "--extract", "Extract archive after download") { extract = true }
          opts.on("-t TAG", "--tag=TAG", "Release tag (default: latest)") { |t| tag = t }
          opts.on("-f", "--force", "Overwrite existing files") { force = true }
          opts.on("--list", "List release assets without downloading") { list_only = true }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
        end

        remaining = [] of String
        parser.unknown_args { |r| remaining = r }
        parser.parse(args)

        # Parse positional platform and kind
        platform : String? = nil
        kind : String? = nil

        if !remaining.empty?
          first = remaining[0]
          if is_platform_name?(first)
            platform = normalize_platform(first)
            kind = remaining.size > 1 ? remaining[1] : "cli"
          else
            # First argument is a kind (e.g. "examples", "benchmarks", "tests")
            platform = normalize_platform(nil)
            kind = first
          end
        else
          platform = normalize_platform(nil)
          kind = "cli"
        end

        plat = platform.not_nil!
        target_kind = (kind || "cli").downcase

        asset_files = resolve_asset_names(plat, target_kind)

        if list_only
          puts "\e[36mRelease assets for platform '#{plat}', kind '#{target_kind}':\e[0m"
          asset_files.each do |file|
            url = asset_url(REPO, tag, file)
            puts "  - #{file} -> #{url}"
          end
          return 0
        end

        curr = Path.new(Dir.current).expand
        dest_dir = if (oa = out_arg) && !oa.empty?
                     p = Path.new(oa).expand
                     File.directory?(p) || !p.extension.empty? ? p : p
                   else
                     curr
                   end

        Core::Logger.step("Get:Release", "Retrieving #{target_kind} release for #{plat}...")

        downloaded_any = false

        asset_files.each do |asset_filename|
          target_file = if dest_dir.to_s.ends_with?(".zip") || dest_dir.to_s.ends_with?(".tar.gz") || dest_dir.to_s.ends_with?(".exe") || dest_dir.to_s.ends_with?(".deb")
                          dest_dir
                        else
                          dest_dir.join(asset_filename)
                        end

          if File.exists?(target_file) && !force
            Core::Logger.info("Asset #{target_file.basename} already exists at #{target_file}. Use --force to re-download.")
            downloaded_any = true
            if extract && (target_file.extension == ".zip" || target_file.to_s.ends_with?(".tar.gz"))
              extract_archive(target_file, target_file.parent)
            end
            next
          end

          url = asset_url(REPO, tag, asset_filename)
          Core::Logger.step("Get:Release", "Downloading #{asset_filename} from #{url}...")

          if download_file(url, target_file)
            Core::Logger.success("Downloaded #{asset_filename} (#{File.size(target_file)} bytes) to #{target_file}!")
            downloaded_any = true

            if extract
              extract_archive(target_file, target_file.parent)
            end
          else
            Core::Logger.warn("Could not download #{asset_filename} from #{url}.")
          end
        end

        if downloaded_any
          0
        else
          Core::Logger.error("Failed to download requested release assets for '#{plat}' '#{target_kind}'.")
          1
        end
      end

      def self.extract_archive(file : Path, target_dir : Path) : Bool
        if file.extension == ".zip"
          extract_zip(file, target_dir)
        elsif file.to_s.ends_with?(".tar.gz")
          extract_tar_gz(file, target_dir)
        else
          false
        end
      end

      def self.run(args : Array(String)) : Int32
        if args.empty? || args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        subcmd = args[0]
        sub_args = args[1..]

        case subcmd.downcase
        when "source", "src"
          get_source(sub_args)
        when "release", "releases", "rel"
          get_release(sub_args)
        else
          # Allow 'lapis get windows' or 'lapis get examples' directly
          if is_platform_name?(subcmd) || ["examples", "benchmark", "benchmarks", "performance", "perf", "tests", "test", "addon", "template", "all"].includes?(subcmd.downcase)
            get_release(args)
          else
            Core::Logger.error("Unknown get subcommand: '#{subcmd}'. Expected 'source' or 'release'.")
            puts
            print_help
            1
          end
        end
      end
    end
  end
end
