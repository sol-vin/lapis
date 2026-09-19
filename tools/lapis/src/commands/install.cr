require "../core/env"
require "../core/logger"
require "../core/process_runner"
require "file_utils"
require "option_parser"
require "json"

module Lapis
  module Commands
    module Install
      {% unless flag?(:windows) %}
        lib LibC
          fun geteuid : UInt32
        end
      {% end %}

      def self.config_dir : Path
        if Core::Env.windows?
          appdata = ENV["APPDATA"]? || ENV["LOCALAPPDATA"]? || (ENV["USERPROFILE"]? ? File.join(ENV["USERPROFILE"], "AppData", "Roaming") : nil)
          if appdata
            Path.new(appdata).join("lapis")
          else
            Path.home.join(".config", "lapis")
          end
        else
          xdg = ENV["XDG_CONFIG_HOME"]?
          if xdg && !xdg.empty?
            Path.new(xdg).join("lapis")
          else
            Path.home.join(".config", "lapis")
          end
        end
      end

      def self.config_file : Path
        config_dir.join("config.json")
      end

      def self.save_config(libgodot_path : Path, bin_path : Path) : Void
        dir = config_dir
        FileUtils.mkdir_p(dir) unless Dir.exists?(dir)
        cfg = {
          "version"        => Lapis::VERSION,
          "libgodot_path"  => libgodot_path.expand.to_s.gsub('\\', '/'),
          "bin_path"       => bin_path.expand.to_s.gsub('\\', '/'),
          "installed_at"   => Time.utc.to_s("%Y-%m-%dT%H:%M:%SZ"),
        }
        File.write(config_file, cfg.to_pretty_json)
        Core::Logger.debug("Saved Lapis global config to #{config_file}")
      rescue ex
        Core::Logger.debug("Notice: Failed to save Lapis global config: #{ex.message}")
      end

      def self.read_config : Hash(String, String)?
        cfg_file = config_file
        return nil unless File.exists?(cfg_file)
        Hash(String, String).from_json(File.read(cfg_file))
      rescue
        nil
      end

      def self.clean_config : Void
        cfg = config_file
        File.delete(cfg) if File.exists?(cfg)
        dir = config_dir
        Dir.delete(dir) if Dir.exists?(dir) && Dir.children(dir).empty?
      rescue
      end

      def self.resolve_install_dir(explicit_dir : String?, prefix : String?) : Path
        if explicit_dir && !explicit_dir.empty?
          return Path.new(explicit_dir).expand
        end

        if prefix && !prefix.empty?
          return Path.new(prefix).expand.join("bin")
        end

        {% if flag?(:windows) %}
          # Candidate 1: WindowsApps (standard per-user bin directory in default PATH on Win 10/11)
          if (local_app_data = ENV["LOCALAPPDATA"]?) && !local_app_data.empty?
            win_apps = Path.new(local_app_data).join("Microsoft", "WindowsApps")
            return win_apps.expand if Dir.exists?(win_apps)
          end

          # Candidate 2: Scoop shims (if in PATH)
          if (user_profile = ENV["USERPROFILE"]?) && !user_profile.empty?
            scoop_shims = Path.new(user_profile).join("scoop", "shims")
            return scoop_shims.expand if Dir.exists?(scoop_shims) && in_path?(scoop_shims)

            user_local_bin = Path.new(user_profile).join(".local", "bin")
            return user_local_bin.expand if Dir.exists?(user_local_bin) && in_path?(user_local_bin)

            user_bin = Path.new(user_profile).join("bin")
            return user_bin.expand if Dir.exists?(user_bin) && in_path?(user_bin)
          end

          # Fallback
          if (local_app_data = ENV["LOCALAPPDATA"]?) && !local_app_data.empty?
            Path.new(local_app_data).join("Microsoft", "WindowsApps").expand
          elsif (user_profile = ENV["USERPROFILE"]?) && !user_profile.empty?
            Path.new(user_profile).join("bin").expand
          else
            Path.new("C:/Windows").expand
          end
        {% else %}
          # Unix / Linux / macOS
          is_root = begin
            LibC.geteuid == 0
          rescue
            false
          end
          if is_root
            Path.new("/usr/local/bin")
          else
            user_local_bin = Path.home.join(".local", "bin")
            if in_path?(user_local_bin)
              user_local_bin
            elsif (File.info?("/usr/local/bin").try(&.permissions.other_write?) rescue false)
              Path.new("/usr/local/bin")
            else
              user_local_bin
            end
          end
        {% end %}
      end

      def self.in_path?(dir : Path) : Bool
        expanded_target = dir.expand.to_s.gsub('\\', '/').rstrip('/').downcase
        env_path = ENV["PATH"]? || ""
        paths = env_path.split(Core::Env.path_sep).map do |p|
          next "" if p.strip.empty?
          Path.new(p.strip).expand.to_s.gsub('\\', '/').rstrip('/').downcase
        end
        paths.includes?(expanded_target)
      end

      def self.find_source_binary(root : Path) : Path?
        exe_name = "lapis#{Core::Env.exe_ext}"

        # 1. Check root/bin/lapis[.exe]
        root_bin_exe = root.join("bin", exe_name)
        return root_bin_exe if File.exists?(root_bin_exe)

        # 2. Check running executable path if it's named lapis
        if (self_exe = Process.executable_path)
          self_path = Path.new(self_exe)
          if self_path.basename == exe_name && File.exists?(self_path)
            return self_path
          end
        end

        # 3. Check current directory
        cwd_exe = Path.new(Dir.current).join(exe_name)
        return cwd_exe if File.exists?(cwd_exe)

        nil
      end

      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Toolchain Installation Manager ===\e[0m

Usage:
  lapis install [options]
  lapis uninstall [options]

Options:
  -d, --dir=DIR          Explicit destination directory for executable
  -p, --prefix=PREFIX    Install prefix (executable copied to PREFIX/bin)
  -u, --uninstall        Uninstall Lapis executable and remove global configuration
  -f, --force            Overwrite existing destination binary
  -h, --help             Show this help screen

Defaults:
  Windows: %LOCALAPPDATA%\\Microsoft\\WindowsApps (user-writable, in PATH by default)
  Linux / macOS: /usr/local/bin (root) or ~/.local/bin (non-root)

Examples:
  lapis install                           # Install to default directory
  lapis install -d ~/scoop/shims          # Install into custom directory
  lapis install -p /usr/local             # Install into /usr/local/bin
  lapis install --uninstall               # Remove installed executable
HELP
      end

      def self.run(args : Array(String)) : Int32
        explicit_dir : String? = nil
        prefix : String? = nil
        uninstall : Bool = false
        force : Bool = false

        if args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis install [options]"
          opts.on("-d DIR", "--dir=DIR", "Explicit installation directory") { |d| explicit_dir = d }
          opts.on("-p PREFIX", "--prefix=PREFIX", "Installation prefix") { |p| prefix = p }
          opts.on("-u", "--uninstall", "Uninstall Lapis toolchain") { uninstall = true }
          opts.on("-f", "--force", "Force overwrite existing binary") { force = true }
          opts.on("-h", "--help", "Show help screen") do
            print_help
            exit 0
          end
        end

        # Pre-check if first argument is uninstall
        if args.includes?("uninstall")
          uninstall = true
          args = args.reject { |a| a == "uninstall" }
        end

        parser.parse(args)

        root = Core::Env::ROOT_DIR
        install_dir = resolve_install_dir(explicit_dir, prefix)
        exe_name = "lapis#{Core::Env.exe_ext}"
        dest_bin = install_dir.join(exe_name)

        if uninstall
          # If not present in resolved dir, check saved config
          if !File.exists?(dest_bin)
            if (cfg = read_config) && (saved_bin = cfg["bin_path"]?)
              if File.exists?(saved_bin)
                dest_bin = Path.new(saved_bin)
              end
            end
          end

          if File.exists?(dest_bin)
            begin
              File.delete(dest_bin)
              clean_config
              Core::Logger.success("Lapis CLI uninstalled successfully from #{dest_bin}.")
              return 0
            rescue ex
              Core::Logger.error("Failed to delete #{dest_bin}: #{ex.message}")
              return 1
            end
          else
            Core::Logger.info("Lapis executable not found at #{dest_bin}. Nothing to uninstall.")
            clean_config
            return 0
          end
        end

        # Installation Mode
        Core::Logger.step("Install", "Installing Lapis CLI (v#{Lapis::VERSION}) to #{dest_bin}...")

        src_bin = find_source_binary(root)
        unless src_bin && File.exists?(src_bin)
          Core::Logger.step("Build", "Compiling Lapis toolchain prior to installation...")
          target_out = root.join("bin", exe_name)
          FileUtils.mkdir_p(target_out.parent) unless Dir.exists?(target_out.parent)
          build_args = ["build", root.join("tools/lapis/src/lapis.cr").to_s, "-o", target_out.to_s, "--release"]
          res = Core::ProcessRunner.run("crystal", build_args)
          if !res.success? || !File.exists?(target_out)
            Core::Logger.error("Failed to compile #{target_out} for installation.")
            return 1
          end
          src_bin = target_out
        end

        FileUtils.mkdir_p(install_dir) unless Dir.exists?(install_dir)

        # Copy executable to destination
        begin
          if File.exists?(dest_bin)
            File.delete(dest_bin) rescue nil
          end
          FileUtils.cp(src_bin.to_s, dest_bin.to_s)
          File.chmod(dest_bin.to_s, 0o755) unless Core::Env.windows?
        rescue ex
          Core::Logger.error("Failed to copy #{src_bin} -> #{dest_bin}: #{ex.message}")
          if Core::Env.windows? && ex.message.to_s.includes?("Access is denied")
            Core::Logger.info("Tip: If 'lapis.exe' is currently running, close other terminal instances or specify --dir.")
          end
          return 1
        end

        # Save configuration
        save_config(root, dest_bin)

        Core::Logger.success("Lapis CLI (v#{Lapis::VERSION}) installed successfully!")
        puts "  Destination: \e[32m#{dest_bin}\e[0m"

        if in_path?(install_dir)
          puts "  PATH Status: \e[32mVerified in PATH\e[0m"
          puts "\nYou can now run \e[1;36mlapis\e[0m from any directory or terminal."
        else
          puts "  PATH Status: \e[33mNot in PATH\e[0m"
          puts "\n\e[33mNotice: '#{install_dir}' is not currently in your system PATH.\e[0m"
          if Core::Env.windows?
            puts "To add it to your PATH in PowerShell, run:"
            puts "  [Environment]::SetEnvironmentVariable(\"Path\", $env:Path + \";#{install_dir}\", [EnvironmentVariableTarget]::User)"
          else
            puts "To add it to your PATH, add this line to your ~/.bashrc or ~/.zshrc:"
            puts "  export PATH=\"#{install_dir}:$PATH\""
          end
        end

        0
      end
    end
  end
end
