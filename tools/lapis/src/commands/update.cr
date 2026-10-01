require "../core/env"
require "../core/logger"
require "../core/process_runner"
require "../core/tool_checker"
require "./install"
require "./get"
require "file_utils"
require "option_parser"
require "compress/zip"
require "compress/gzip"
require "http/client"

module Lapis
  module Commands
    module Update
      REPO = "sol-vin/lapis"

      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Toolchain & Dependency Update Manager ===\e[0m

Usage:
  lapis update [subcommand] [options]

Subcommands:
  (no subcmd)           Check and update Lapis executable, Crystalline LSP, and Crystal compiler
  self, cli             Update the Lapis CLI executable itself
  crystalline, lsp      Update Crystalline Language Server Protocol daemon
  crystal               Check and update Crystal programming language compiler

Options:
  --check               Check for available updates without applying them
  -f, --force           Force reinstallation even if already up to date
  -y, --yes             Automatically accept package manager prompts
  -v, --version=TAG     Target specific release version
  --build               Rebuild Lapis executable from local source if inside repository
  -h, --help            Show this help screen

Examples:
  lapis update
  lapis update self
  lapis update crystalline
  lapis update crystal
  lapis update --check
HELP
      end

      # Self-updates the Lapis executable
      def self.update_self(
        check_only : Bool = false,
        force : Bool = false,
        target_version : String? = nil,
        build_local : Bool = false,
      ) : Int32
        root = Core::Env::ROOT_DIR
        exe_name = "lapis#{Core::Env.exe_ext}"
        current_exe = Commands::Install.find_source_binary(root) ||
                      (Process.executable_path ? Path.new(Process.executable_path.not_nil!).expand : nil)

        unless current_exe && File.exists?(current_exe)
          Core::Logger.error("Could not locate currently running Lapis executable.")
          return 1
        end

        Core::Logger.step("Update:Self", "Checking for Lapis updates (current: v#{Lapis::VERSION} at #{current_exe})...")

        # Cleanup any lingering .old executables from previous updates on Windows
        if Core::Env.windows?
          old_file = Path.new(current_exe.to_s + ".old")
          File.delete(old_file) if File.exists?(old_file) rescue nil
        end

        # Local repository rebuild option
        if build_local && Core::Env.is_libgodot_repo?(root)
          Core::Logger.step("Update:Self", "Rebuilding Lapis CLI from local repository source...")
          src_entry = root.join("tools/lapis/src/lapis.cr")
          res = Core::ProcessRunner.capture("crystal", ["build", src_entry.to_s, "-o", current_exe.to_s, "--release"])
          if res[:status] == 0
            Core::Logger.success("Lapis CLI successfully rebuilt and updated at #{current_exe}!")
            return 0
          else
            Core::Logger.error("Failed to rebuild Lapis CLI:\n#{res[:output]}")
            return 1
          end
        end

        plat = Core::Env.windows? ? "windows" : (Core::Env.macos? ? "macos" : "linux")
        archive_name = if Core::Env.windows?
                         "lapis-windows-x86_64.zip"
                       elsif Core::Env.macos?
                         "lapis-macos.zip"
                       else
                         "lapis-linux-x86_64.tar.gz"
                       end

        url = Get.asset_url(REPO, target_version, archive_name)

        if check_only
          Core::Logger.info("Latest release URL: #{url}")
          Core::Logger.info("Current version: v#{Lapis::VERSION}")
          return 0
        end

        temp_archive = current_exe.parent.join("lapis_dl_#{Time.utc.to_unix_ms}.archive")
        temp_extracted_dir = current_exe.parent.join("lapis_extracted_#{Time.utc.to_unix_ms}")

        begin
          Core::Logger.step("Update:Self", "Downloading latest Lapis release from #{url}...")
          unless Get.download_file(url, temp_archive)
            Core::Logger.error("Failed to download Lapis release archive from #{url}.")
            return 1
          end

          FileUtils.mkdir_p(temp_extracted_dir)
          Get.extract_archive(temp_archive, temp_extracted_dir)

          # Find extracted lapis binary
          new_bin = Dir.glob(temp_extracted_dir.to_s.gsub('\\', '/') + "/**/#{exe_name}").first?
          unless new_bin && File.exists?(new_bin)
            Core::Logger.error("Could not find #{exe_name} in extracted archive.")
            return 1
          end

          # Replace binary safely
          if Core::Env.windows?
            old_bin = Path.new(current_exe.to_s + ".old")
            File.delete(old_bin) if File.exists?(old_bin) rescue nil
            File.rename(current_exe.to_s, old_bin.to_s)
            FileUtils.cp(new_bin, current_exe.to_s)
          else
            FileUtils.cp(new_bin, current_exe.to_s)
            File.chmod(current_exe, 0o755)
          end

          Core::Logger.success("Lapis CLI successfully updated at #{current_exe}!")
          0
        rescue ex
          Core::Logger.error("Self-update failed: #{ex.message}")
          1
        ensure
          File.delete(temp_archive) if File.exists?(temp_archive) rescue nil
          FileUtils.rm_rf(temp_extracted_dir) if Dir.exists?(temp_extracted_dir) rescue nil
        end
      end

      def self.has_tool?(name : String) : Bool
        # Check standard executable lookup first
        begin
          if Process.find_executable(name)
            return true
          end
        rescue
          # WindowsApps execution alias reparse point or permission error
        end

        # On Windows, also check Scoop shims directly
        if Core::Env.windows?
          {% if flag?(:windows) %}
            if (user_profile = ENV["USERPROFILE"]?) && !user_profile.empty?
              [".cmd", ".exe", ".ps1", ".bat"].each do |ext|
                c = Path.new(user_profile).join("scoop", "shims", "#{name}#{ext}")
                return true if (File.exists?(c) rescue false)
              end
            end
          {% end %}
        end

        false
      end

      # Updates Crystalline Language Server (LSP)
      def self.update_crystalline(
        check_only : Bool = false,
        force : Bool = false,
        target_version : String? = nil,
      ) : Int32
        root = Core::Env::ROOT_DIR
        dest_exe = root.join("bin", "crystalline#{Core::Env.exe_ext}")
        c_status = Core::ToolChecker.check_crystalline

        Core::Logger.step("Update:Crystalline", "Checking Crystalline LSP status...")

        if c_status.installed
          Core::Logger.info("Found Crystalline at #{c_status.path} (#{c_status.version})")
        else
          Core::Logger.info("Crystalline LSP is currently not installed.")
        end

        tag = target_version || "v0.20.0"

        if check_only
          Core::Logger.info("Target Crystalline version: #{tag}")
          return 0
        end

        if Core::Env.windows?
          # On Windows, check Scoop or Winget
          if has_tool?("scoop")
            Core::Logger.step("Update:Crystalline", "Updating Crystalline via Scoop...")
            res = Core::ProcessRunner.capture("scoop", ["update", "crystalline"])
            if res[:status] == 0
              Core::Logger.success("Crystalline updated via Scoop.")
              return 0
            end
          end

          Core::Logger.info("On Windows, pre-built Crystalline binaries can be placed at #{dest_exe}.")
          Core::Logger.info("Download the Windows release from: https://github.com/elbywan/crystalline/releases")
          return 0
        end

        # Unix / macOS direct download
        url = if Core::Env.macos?
                "https://github.com/elbywan/crystalline/releases/download/#{tag}/crystalline_arm64-apple-darwin.gz"
              else
                "https://github.com/elbywan/crystalline/releases/download/#{tag}/crystalline_x86_64-unknown-linux-musl.gz"
              end

        temp_archive = dest_exe.parent.join("crystalline_dl_#{Time.utc.to_unix_ms}.gz")
        begin
          Core::Logger.step("Update:Crystalline", "Downloading Crystalline (#{tag}) from #{url}...")
          FileUtils.mkdir_p(dest_exe.parent)
          unless Get.download_file(url, temp_archive)
            Core::Logger.error("Failed to download Crystalline from #{url}.")
            return 1
          end

          File.open(dest_exe, "wb") do |f|
            Compress::Gzip::Reader.open(temp_archive.to_s) do |gz|
              IO.copy(gz, f)
            end
          end
          File.chmod(dest_exe, 0o755)

          Core::Logger.success("Crystalline LSP successfully updated at #{dest_exe}!")
          0
        rescue ex
          Core::Logger.error("Failed to update Crystalline: #{ex.message}")
          1
        ensure
          File.delete(temp_archive) if File.exists?(temp_archive) rescue nil
        end
      end

      # Checks and updates Crystal compiler
      def self.update_crystal(
        check_only : Bool = false,
        auto_yes : Bool = false,
      ) : Int32
        crystal_exe = Process.find_executable("crystal") rescue nil
        unless crystal_exe
          Core::Logger.error("Crystal compiler not found in PATH.")
          Core::Logger.info("Install Crystal from https://crystal-lang.org/install/")
          return 1
        end

        c_ver_out = Core::ProcessRunner.capture("crystal", ["--version"])[:output]
        current_ver = c_ver_out.lines.first?.try(&.strip) || "Unknown version"
        Core::Logger.step("Update:Crystal", "Current compiler: #{current_ver} (#{crystal_exe})")

        # Detect package manager
        cmd : String? = nil
        args = [] of String

        if Core::Env.windows?
          if crystal_exe.includes?("scoop") || has_tool?("scoop")
            cmd = "scoop"
            args = ["update", "crystal"]
          elsif has_tool?("winget")
            cmd = "winget"
            args = ["upgrade", "CrystalLang.Crystal"]
            args << "--accept-package-agreements" << "--accept-source-agreements" if auto_yes
          elsif has_tool?("choco")
            cmd = "choco"
            args = ["upgrade", "crystal"]
            args << "-y" if auto_yes
          end
        elsif Core::Env.macos?
          if has_tool?("brew")
            cmd = "brew"
            args = ["upgrade", "crystal"]
          end
        else # Linux
          if has_tool?("apt")
            cmd = "sudo"
            args = ["apt", "install", "--only-upgrade", "crystal"]
            args << "-y" if auto_yes
          elsif has_tool?("dnf")
            cmd = "sudo"
            args = ["dnf", "upgrade", "crystal"]
            args << "-y" if auto_yes
          elsif has_tool?("pacman")
            cmd = "sudo"
            args = ["pacman", "-Syu", "crystal"]
            args << "--noconfirm" if auto_yes
          end
        end

        if cmd.nil?
          Core::Logger.info("No supported package manager detected (Scoop, Winget, Chocolatey, Homebrew, APT, DNF, Pacman).")
          Core::Logger.info("To update Crystal manually, visit: https://crystal-lang.org/install/")
          return 0
        end

        full_cmd = "#{cmd} #{args.join(" ")}"

        if check_only
          Core::Logger.info("Detected update command: #{full_cmd}")
          return 0
        end

        Core::Logger.step("Update:Crystal", "Running update: #{full_cmd}...")
        status = Process.run(cmd, args)
        if status.success?
          new_ver = Core::ProcessRunner.capture("crystal", ["--version"])[:output].lines.first?.try(&.strip) || "Unknown"
          Core::Logger.success("Crystal compiler update completed! (#{new_ver})")
          0
        else
          Core::Logger.warn("Crystal compiler update command returned exit code #{status.exit_code}.")
          status.exit_code
        end
      end

      # Runs full update or dispatches subcommand
      def self.run(args : Array(String)) : Int32
        check_only = false
        force = false
        auto_yes = false
        target_version : String? = nil
        build_local = false

        if args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        filtered_args = [] of String
        args.each do |arg|
          case arg
          when "--check"
            check_only = true
          when "-f", "--force"
            force = true
          when "-y", "--yes"
            auto_yes = true
          when "--build"
            build_local = true
          else
            if arg.starts_with?("-v=") || arg.starts_with?("--version=")
              target_version = arg.split("=", 2)[1]
            else
              filtered_args << arg
            end
          end
        end

        subcmd = filtered_args.first?

        case subcmd.try(&.downcase)
        when "self", "cli", "lapis"
          update_self(check_only, force, target_version, build_local)
        when "crystalline", "lsp"
          update_crystalline(check_only, force, target_version)
        when "crystal"
          update_crystal(check_only, auto_yes)
        when nil
          # Full toolchain update
          Core::Logger.step("Update", "Performing full Lapis toolchain check & update...\n")
          code_self = update_self(check_only, force, target_version, build_local)
          puts
          code_lsp = update_crystalline(check_only, force, target_version)
          puts
          code_crystal = update_crystal(check_only, auto_yes)
          puts

          if code_self == 0 && code_lsp == 0 && code_crystal == 0
            Core::Logger.success("All components checked successfully!")
            0
          else
            Core::Logger.warn("One or more update steps reported warnings or non-zero status.")
            0
          end
        else
          Core::Logger.error("Unknown update target: '#{subcmd}'. Expected 'self', 'crystalline', or 'crystal'.")
          puts
          print_help
          1
        end
      end
    end
  end
end
