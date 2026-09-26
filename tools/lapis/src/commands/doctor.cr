require "../core/env"
require "../core/logger"
require "../core/process_runner"
require "../core/godot_finder"
require "../core/tool_checker"
require "option_parser"

module Lapis
  module Commands
    module Doctor
      record CheckItem, name : String, status : Symbol, detail : String, tip : String? = nil

      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Environment & Toolchain Diagnostics ===\e[0m

Usage: lapis doctor [options]

Options:
  -v, --verbose         Display extended diagnostic information
  -h, --help            Show this help screen

Examples:
  lapis doctor
  lapis doctor --verbose
HELP
      end

      # Runs comprehensive toolchain diagnostics and prints an actionable report.
      def self.run(args : Array(String)) : Int32
        verbose = args.includes?("-v") || args.includes?("--verbose")
        if args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        Core::Logger.step("Doctor", "Diagnosing Lapis development environment...\n")

        items = [] of CheckItem
        has_critical_failure = false

        # 1. Crystal Compiler
        crystal_exe = Process.find_executable("crystal")
        if crystal_exe
          c_ver_out = Core::ProcessRunner.capture("crystal", ["--version"])[:output]
          first_line = c_ver_out.lines.first?.try(&.strip) || "Unknown version"
          items << CheckItem.new("Crystal Compiler", :pass, first_line)
        else
          has_critical_failure = true
          items << CheckItem.new(
            "Crystal Compiler",
            :fail,
            "Crystal compiler not found in PATH",
            "Install Crystal 1.20+ from https://crystal-lang.org/install/ or run 'lapis update crystal'."
          )
        end

        # 2. Godot Engine Binary
        root = Core::Env::ROOT_DIR
        curr = Path.new(Dir.current).expand
        target_dir = File.exists?(curr.join("project.godot")) ? curr : root
        expected_ver = Core::GodotFinder.expected_version(target_dir.to_s)
        godot_exe = Core::GodotFinder.resolve(nil, target_dir.to_s, filter_version: false)

        if godot_exe && File.exists?(godot_exe)
          res = Core::ProcessRunner.capture(godot_exe, ["--version"])
          g_ver = res[:output].strip
          if Core::GodotFinder.verify_version(godot_exe, expected_ver, strict: false)
            items << CheckItem.new("Godot Engine", :pass, "#{godot_exe} (v#{g_ver})")
          else
            items << CheckItem.new(
              "Godot Engine",
              :warn,
              "Detected v#{g_ver} at #{godot_exe}, expected target #{expected_ver}",
              "Run 'lapis setup' to download and configure the targeted Godot engine binary."
            )
          end
        else
          items << CheckItem.new(
            "Godot Engine",
            :fail,
            "Godot binary not found in PATH or project directory",
            "Run 'lapis setup' to automatically download and configure Godot."
          )
        end

        # 3. C++ Compiler (GCC / Clang)
        cxx_candidates = Core::Env.windows? ? ["g++", "clang++", "cl"] : ["g++", "clang++"]
        found_cxx : String? = nil
        cxx_version : String? = nil
        cxx_candidates.each do |cand|
          if path = Process.find_executable(cand)
            found_cxx = cand
            ver_res = Core::ProcessRunner.capture(cand, ["--version"])
            cxx_version = ver_res[:output].lines.first?.try(&.strip) || cand
            break
          end
        end

        if found_cxx
          items << CheckItem.new("C++ Bridge Compiler", :pass, "#{found_cxx} (#{cxx_version})")
        else
          has_critical_failure = true
          tip_msg = Core::Env.windows? ? "Install MinGW-w64 (via MSYS2 or winlibs.com) or Clang (via 'scoop install llvm')." : "Install build tools: 'sudo apt install build-essential' (Ubuntu) or 'xcode-select --install' (macOS)."
          items << CheckItem.new("C++ Bridge Compiler", :fail, "No C++ compiler (g++/clang++) found in PATH", tip_msg)
        end

        # 4. LLDB Native Debugger
        lldb_exe = Process.find_executable("lldb") || Process.find_executable("lldb.exe")
        if lldb_exe
          res = Core::ProcessRunner.capture("lldb", ["--version"])
          lldb_ver = res[:output].lines.first?.try(&.strip) || "Found at #{lldb_exe}"
          items << CheckItem.new("Native Debugger (LLDB)", :pass, lldb_ver)
        else
          tip_msg = Core::Env.windows? ? "Install via 'scoop install llvm' or 'winget install LLVM.LLVM' to enable in-editor breakpoint sync." : "Install via 'sudo apt install lldb' (Debian/Ubuntu) or 'brew install llvm' (macOS)."
          items << CheckItem.new(
            "Native Debugger (LLDB)",
            :warn,
            "LLDB debugger not found (native in-editor breakpoint sync disabled)",
            tip_msg
          )
        end

        # 5. Build Utilities (make, git, shards)
        make_exe = Process.find_executable("make") || Process.find_executable("mingw32-make")
        if make_exe
          items << CheckItem.new("GNU Make", :pass, "Found at #{make_exe}")
        else
          items << CheckItem.new("GNU Make", :warn, "make utility not found in PATH", "Install make or run tasks directly via 'lapis <command>'.")
        end

        git_exe = Process.find_executable("git")
        if git_exe
          items << CheckItem.new("Git Version Control", :pass, "Found at #{git_exe}")
        else
          items << CheckItem.new("Git Version Control", :warn, "git not found in PATH", "Install Git for dependency management and versioning.")
        end

        shards_exe = Process.find_executable("shards")
        if shards_exe
          items << CheckItem.new("Crystal Shards Manager", :pass, "Found at #{shards_exe}")
        else
          items << CheckItem.new("Crystal Shards Manager", :warn, "shards not found in PATH", "Shards package manager enables external Crystal dependencies.")
        end

        # 6. Language Server (Crystalline LSP)
        c_status = Core::ToolChecker.check_crystalline
        if c_status.installed
          items << CheckItem.new("Crystalline LSP", :pass, "#{c_status.path} (#{c_status.version})")
        else
          items << CheckItem.new(
            "Crystalline LSP",
            :warn,
            "Crystalline LSP not found (in-editor Crystal autocomplete & diagnostics disabled)",
            "Run 'lapis update crystalline' or 'lapis setup --lsp' to configure Crystalline."
          )
        end

        # 7. Packaging Tools (Inno Setup / dpkg-deb)
        if Core::Env.windows?
          iscc = Commands::Package.find_iscc
          if iscc
            items << CheckItem.new("Inno Setup Compiler", :pass, "Found at #{iscc}")
          else
            items << CheckItem.new(
              "Inno Setup Compiler",
              :info,
              "ISCC not detected (Windows installer packaging unavailable)",
              "Install Inno Setup via 'winget install JRSoftware.InnoSetup' or 'choco install innosetup'."
            )
          end
        elsif Core::Env.linux?
          if dpkg = Process.find_executable("dpkg-deb")
            items << CheckItem.new("Debian Packager (dpkg-deb)", :pass, "Found at #{dpkg}")
          else
            items << CheckItem.new(
              "Debian Packager (dpkg-deb)",
              :info,
              "dpkg-deb not detected (.deb packaging unavailable)",
              "Install via 'sudo apt install dpkg' to package Debian (.deb) distributions."
            )
          end
        end

        # 7. Core Runtime Libraries Check
        bin_dir = root.join("bin")
        required_libs = Core::Env.platform_bin_files
        missing_libs = [] of String
        required_libs.each do |lib_name|
          found = false
          # Check root bin and addons/crystal_integration/bin
          if File.exists?(bin_dir.join(lib_name)) || File.exists?(root.join("addons/crystal_integration/bin", lib_name))
            found = true
          end
          missing_libs << lib_name unless found
        end

        if missing_libs.empty?
          items << CheckItem.new("Runtime Libraries", :pass, "All #{required_libs.size} platform libraries verified in bin/")
        else
          items << CheckItem.new(
            "Runtime Libraries",
            :warn,
            "Missing runtime libraries: #{missing_libs.join(", ")}",
            "Run 'lapis deps' to verify and copy required runtime libraries."
          )
        end

        # 8. Project Health Diagnostics (if inside a Godot project)
        in_project = File.exists?(curr.join("project.godot")) || File.exists?(curr.join("src/main.cr"))
        if in_project
          proj_name = File.exists?(curr.join("project.godot")) ? "Godot project (#{curr.basename})" : "Crystal game project"
          issues = [] of String

          issues << "Missing shard.yml" unless File.exists?(curr.join("shard.yml"))
          issues << "Missing src/main.cr entry point" unless File.exists?(curr.join("src/main.cr"))

          ext_manifest = curr.join("addons/crystal_integration/crystal.gdextension")
          issues << "Missing crystal.gdextension manifest" unless File.exists?(ext_manifest)

          ext_list = curr.join(".godot/extension_list.cfg")
          if File.exists?(ext_list)
            lines = File.read(ext_list)
            issues << "extension_list.cfg missing crystal.gdextension entry" unless lines.includes?("crystal.gdextension")
          else
            issues << "Missing .godot/extension_list.cfg"
          end

          issues << "Missing bin/.gdignore (Godot will scan output binaries)" unless File.exists?(curr.join("bin/.gdignore"))

          if issues.empty?
            items << CheckItem.new("Project Configuration", :pass, "#{proj_name} is fully configured for Crystal!")
          else
            items << CheckItem.new(
              "Project Configuration",
              :warn,
              "#{issues.size} configuration warning(s) in #{curr.basename}",
              "Run 'lapis init' or 'lapis sync' to resolve project configuration gaps."
            )
          end
        end

        # Print Formatted Report
        puts "\e[1mDiagnostic Results:\e[0m"
        items.each do |item|
          symbol = case item.status
                   when :pass
                     "\e[32m[✓]\e[0m"
                   when :warn
                     "\e[33m[!]\e[0m"
                   when :info
                     "\e[36m[i]\e[0m"
                   when :fail
                     "\e[31m[✗]\e[0m"
                   else
                     "[-]"
                   end

          puts "  #{symbol} \e[1m#{item.name}\e[0m: #{item.detail}"
          if item.tip && (item.status == :fail || item.status == :warn || verbose)
            puts "      \e[33mTip:\e[0m #{item.tip}"
          end
        end
        puts

        if has_critical_failure
          Core::Logger.error("Doctor detected critical configuration issues. Please review tips above.")
          1
        else
          pass_count = items.count { |i| i.status == :pass }
          Core::Logger.success("Doctor diagnosis complete: #{pass_count}/#{items.size} checks passed cleanly!")
          0
        end
      end
    end
  end
end
