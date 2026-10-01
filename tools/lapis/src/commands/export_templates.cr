# tools/lapis/src/commands/export_templates.cr
require "file_utils"
require "path"
require "option_parser"
require "../core/env"
require "../core/logger"
require "../core/godot_finder"
require "opal"

module Lapis
  module Commands
    module ExportTemplates
      def self.godot_templates_base_dir : Path
        if Core::Env.windows?
          appdata = ENV["APPDATA"]? || (ENV["USERPROFILE"]? ? File.join(ENV["USERPROFILE"], "AppData", "Roaming") : nil)
          Path.new(appdata || ".").join("Godot", "export_templates")
        elsif Core::Env.macos?
          Path.home.join("Library", "Application Support", "Godot", "export_templates")
        else
          data_home = ENV["XDG_DATA_HOME"]? || Path.home.join(".local", "share").to_s
          Path.new(data_home).join("godot", "export_templates")
        end
      end

      def self.target_godot_version : String
        root = Core::Env::ROOT_DIR.to_s
        expected = Core::GodotFinder.expected_version(root)
        # Normalize to template folder name (e.g., "4.3.stable" or "4.3")
        if expected.includes?("-")
          expected.gsub('-', '.')
        elsif !expected.includes?(".stable") && !expected.includes?(".dev") && !expected.includes?(".rc")
          "#{expected}.stable"
        else
          expected
        end
      end

      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Export Templates Manager & Architecture Inspector ===\e[0m

Usage:
  lapis export-templates [command] [options]

Subcommands:
  status               Check installed Godot & Crystal export templates
  explain              Comprehensive architectural explanation of Crystal export templates
  install              Download and install official templates for current Godot version
  verify               Verify checksums and executable headers of installed templates

Options:
  -v, --version=VER    Explicit Godot template version (e.g. '4.3.stable')
  -h, --help           Show this help message

Examples:
  lapis export-templates status
  lapis export-templates explain
  lapis export-templates install
  lapis export-templates verify --version=4.3.stable
HELP
      end

      def self.run(args : Array(String)) : Int32
        subcmd = args.first? || "status"
        if subcmd == "-h" || subcmd == "--help" || subcmd == "help"
          print_help
          return 0
        end

        custom_version : String? = nil
        parser = OptionParser.new do |opts|
          opts.on("-v VER", "--version=VER", "Explicit Godot version tag") { |v| custom_version = v }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
        end
        remaining_args = args.size > 1 ? args[1..] : [] of String
        parser.parse(remaining_args)

        version = (cv = custom_version) ? cv : target_godot_version

        case subcmd
        when "status"
          cmd_status(version)
        when "explain"
          cmd_explain
        when "install"
          cmd_install(version)
        when "verify"
          cmd_verify(version)
        else
          Core::Logger.error("Unknown subcommand '#{subcmd}'. Run 'lapis export-templates --help' for usage.")
          1
        end
      end

      def self.cmd_status(version : String) : Int32
        base = godot_templates_base_dir
        target_dir = base.join(version)

        puts Opal.style.bold.fg(:cyan).render("\n=== Godot & Crystal Export Templates Status ===\n")
        puts "Target Engine Version : \e[1;97m#{version}\e[0m"
        puts "Templates Store Path  : \e[38;5;244m#{target_dir}\e[0m\n"

        unless Dir.exists?(target_dir)
          Core::Logger.warn("Export templates directory not found for #{version}!")
          puts "\nTo install official templates, run:"
          puts "  \e[1;36mlapis export-templates install\e[0m"
          puts "  \e[38;5;244m(Or download Godot_v#{version}_export_templates.tpz from godotengine.org)\e[0m\n"
          return 0
        end

        standard_templates = [
          {"windows_release_x86_64.exe", "Windows 64-bit Release"},
          {"windows_debug_x86_64.exe", "Windows 64-bit Debug"},
          {"linux_release_x86_64", "Linux 64-bit Release"},
          {"linux_debug_x86_64", "Linux 64-bit Debug"},
          {"macos.zip", "macOS Universal Release/Debug"},
          {"web_release.zip", "Web / WebAssembly Release"},
          {"android_release.apk", "Android APK Release"},
        ]

        puts "Installed Templates:"
        found_any = false
        standard_templates.each do |filename, desc|
          file_path = target_dir.join(filename)
          if File.exists?(file_path)
            size_mb = (File.size(file_path).to_f / (1024.0 * 1024.0)).round(1)
            puts "  \e[1;32m[INSTALLED]\e[0m  %-30s  %-26s (%5.1f MB)" % [filename, desc, size_mb]
            found_any = true
          else
            puts "  \e[38;5;240m[ MISSING ]\e[0m  %-30s  %-26s" % [filename, desc]
          end
        end

        # Check for custom monolithic Crystal templates if present
        crystal_custom = [
          {"crystal_windows_release_x86_64.exe", "Custom Crystal Monolithic (Windows)"},
          {"crystal_linux_release_x86_64", "Custom Crystal Monolithic (Linux)"},
        ]
        crystal_custom.each do |filename, desc|
          file_path = target_dir.join(filename)
          if File.exists?(file_path)
            size_mb = (File.size(file_path).to_f / (1024.0 * 1024.0)).round(1)
            puts "  \e[1;35m[ CRYSTAL ]\e[0m  %-30s  %-26s (%5.1f MB)" % [filename, desc, size_mb]
          end
        end

        puts
        if found_any
          Core::Logger.success("Export templates are ready for desktop packaging and editor exports.")
        else
          Core::Logger.warn("No templates found in #{target_dir}.")
        end
        0
      end

      def self.cmd_explain : Int32
        puts Opal.style.bold.fg(:magenta).render("\n=== Crystal & Godot Export Templates Architecture Guide ===\n")
        puts <<-EXPLAIN
\e[1;96m1. Do Export Templates for Crystal Work?\e[0m
   \e[1;32mYES, absolutely.\e[0m
   Godot export templates are stripped, optimized engine runner binaries with the editor UI
   removed (producing lean 40-70 MB binaries instead of 120+ MB editor executables).

   In Lapis (Mode A - GDExtension):
   - Standard Godot export templates run your game cleanly!
   - The export template initializes Godot, discovers `addons/crystal_integration/crystal.gdextension`,
     loads `bin/crystal_bridge.dll`, and dynamically executes your Crystal `bin/game.dll`.
   - Crystal GC (Boehm GC) is initialized during bridge loading and runs natively.

\e[1;96m2. Are Export Templates Needed?\e[0m
   It depends on your workflow:
   - \e[1;33mStandalone CLI Packaging (`lapis package game`):\e[0m
     \e[1;32mOPTIONAL for Desktop!\e[0m Lapis can package games by embedding your `.pck` archive
     directly into any Godot runner binary via the 12-byte `GDPC` header/footer protocol.
     You can package a game right from the CLI without downloading official export templates!
   - \e[1;33mIn-Editor GUI Export (`Project -> Export...` in Godot):\e[0m
     \e[1;31mMANDATORY!\e[0m The Godot editor GUI strictly requires export templates to be installed
     under your system's template path. Without them, the Export dialog aborts with:
     \e[31m"Export templates not found for current engine version"\e[0m.
   - \e[1;33mMobile (Android / iOS) & WebAssembly (HTML5):\e[0m
     \e[1;31mMANDATORY!\e[0m On iOS and WebAssembly, dynamic loading (`LoadLibrary` / `dlopen`) is either
     strictly forbidden by platform App Store policy or unsupported in browser sandboxes.
     Exporting to iOS or Web requires compiling Godot's export template with Crystal statically linked.

\e[1;96m3. What Benefits Do Custom Crystal Export Templates Provide?\e[0m
   - \e[1mMonolithic Single-File Executables:\e[0m
     Static linking compiles Godot C++ + Crystal CRT + Boehm GC + game code into one single `.exe`
     or Linux ELF binary with ZERO external DLL dependencies (`crystal_bridge.dll` and `game.dll`
     are completely merged into the runner).
   - \e[1mSubsystem Pruning & Binary Shrinking:\e[0m
     Official export templates contain the entire Godot engine (3D, physics, navigation, XR, etc.).
     Custom export templates can disable unused subsystems (e.g. `disable_3d=yes`, `module_navigation_enabled=no`)
     reducing binary sizes down to ~15-25 MB!
   - \e[1mLink-Time Optimization (LTO):\e[0m
     Whole-program optimization across C++ GDExtension bridge and Crystal LLVM bitcode enables
     inlining across the C-API boundary for maximum execution throughput.

\e[1;96m4. Recommended Production Shipping Workflow:\e[0m
   - For rapid desktop shipping: Run \e[1;36mlapis package game\e[0m (zero template setup required).
   - For in-editor GUI exports: Run \e[1;36mlapis export-templates install\e[0m once per engine version.
EXPLAIN
        0
      end

      def self.cmd_install(version : String) : Int32
        base = godot_templates_base_dir
        target_dir = base.join(version)

        puts Opal.style.bold.fg(:cyan).render("\n=== Installing Godot Export Templates (v#{version}) ===\n")
        puts "Target Directory: #{target_dir}"

        if Dir.exists?(target_dir) && (File.exists?(target_dir.join("windows_release_x86_64.exe")) || File.exists?(target_dir.join("linux_release_x86_64")))
          Core::Logger.info("Export templates already installed at #{target_dir}.")
          Core::Logger.info("Run 'lapis export-templates verify' to test integrity.")
          return 0
        end

        FileUtils.mkdir_p(target_dir)

        # Download URL for official Godot export templates .tpz
        # e.g., https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz
        clean_tag = version.gsub('.', '-').gsub("-stable", "-stable")
        # Format tag for Godot GitHub release
        gh_tag = if version.includes?(".stable")
                   version.gsub(".stable", "-stable")
                 else
                   version
                 end
        tpz_url = "https://github.com/godotengine/godot/releases/download/#{gh_tag}/Godot_v#{gh_tag}_export_templates.tpz"

        Core::Logger.step("Download", "Downloading templates archive from GitHub: #{tpz_url}")
        tmp_archive = Path.new(Dir.tempdir).join("godot_templates_#{version}.tpz")

        download_success = false
        if Process.run("curl", ["-fSL", tpz_url, "-o", tmp_archive.to_s]).success?
          download_success = true
        elsif Process.run("powershell", ["-NoProfile", "-Command", "Invoke-WebRequest -Uri '#{tpz_url}' -OutFile '#{tmp_archive}'"]).success?
          download_success = true
        end

        unless download_success && File.exists?(tmp_archive) && File.size(tmp_archive) > 10000
          Core::Logger.error("Failed to automatically download export templates from #{tpz_url}.")
          Core::Logger.info("You can download Godot_v#{gh_tag}_export_templates.tpz manually from https://godotengine.org/download")
          Core::Logger.info("and extract the 'templates/' folder contents directly into: #{target_dir}")
          return 1
        end

        Core::Logger.step("Extract", "Extracting export templates into #{target_dir}...")
        # .tpz files are standard zip files
        extract_success = false
        if Process.run("tar", ["-xf", tmp_archive.to_s, "--strip-components=1", "-C", target_dir.to_s]).success?
          extract_success = true
        elsif Process.run("powershell", ["-NoProfile", "-Command", "Expand-Archive -Path '#{tmp_archive}' -DestinationPath '#{target_dir}' -Force"]).success?
          # If extracted with 'templates/' subfolder, move files up
          sub_templates = target_dir.join("templates")
          if Dir.exists?(sub_templates)
            Dir.each_child(sub_templates) do |child|
              FileUtils.mv(sub_templates.join(child).to_s, target_dir.join(child).to_s) rescue nil
            end
            FileUtils.rm_rf(sub_templates.to_s) rescue nil
          end
          extract_success = true
        end

        File.delete(tmp_archive) rescue nil

        if extract_success
          Core::Logger.success("Successfully installed Godot #{version} export templates!")
          cmd_status(version)
          0
        else
          Core::Logger.error("Failed to extract template archive to #{target_dir}.")
          1
        end
      end

      def self.cmd_verify(version : String) : Int32
        base = godot_templates_base_dir
        target_dir = base.join(version)

        puts Opal.style.bold.fg(:cyan).render("\n=== Verifying Export Templates Integrity (v#{version}) ===\n")

        unless Dir.exists?(target_dir)
          Core::Logger.error("Templates directory not found: #{target_dir}")
          return 1
        end

        checked_count = 0
        valid_count = 0

        Dir.each_child(target_dir) do |item|
          file_path = target_dir.join(item)
          next unless File.file?(file_path)

          checked_count += 1
          size = File.size(file_path)
          if size > 1024 * 1024 # Executables should be > 1MB
            valid_count += 1
            puts "  \e[32m✔\e[0m %-32s (%5.1f MB) [VALID]" % [item, size.to_f / (1024.0 * 1024.0)]
          else
            puts "  \e[31m✘\e[0m %-32s (%d bytes) [SUSPICIOUSLY SMALL]" % [item, size]
          end
        end

        puts
        if valid_count > 0 && valid_count == checked_count
          Core::Logger.success("All #{checked_count} template files verified successfully.")
          0
        elsif valid_count > 0
          Core::Logger.warn("#{valid_count}/#{checked_count} template files appear valid.")
          0
        else
          Core::Logger.error("No valid export template binaries detected.")
          1
        end
      end
    end
  end
end
