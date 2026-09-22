require "../core/env"
require "../core/logger"
require "../core/process_runner"
require "../core/godot_finder"
require "file_utils"
require "option_parser"
require "./package"

module Lapis
  module Commands
    module Test
      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Automated Test Suite Runner ===\e[0m

Usage: lapis test [options]

Options:
  --skip-specs          Skip all Crystal spec unit tests (test/spec, tools/lapis/spec, spec/*)
  --skip-engine-specs   Skip engine & bindings specifications (test/spec)
  --skip-cli-specs      Skip Lapis toolchain & CLI specifications (tools/lapis/spec)
  --skip-tool-tests     Skip headless in-editor @tool tests
  --skip-runtime-tests  Skip Godot runtime test project
  --skip-standalone     Skip standalone compiled test executable
  -g, --godot=PATH      Explicit Godot engine executable path
  -h, --help            Show this help screen

Examples:
  lapis test
  lapis test --skip-specs
  lapis test --skip-cli-specs
  lapis test --skip-runtime-tests
HELP
      end

      def self.clear_markers(test_dir : Path, test_bin_dir : Path)
        [
          test_dir.join(".tool_tests_passed"),
          test_dir.join(".tool_tests_failed"),
          test_dir.join(".editor_game_passed"),
          test_dir.join(".editor_game_failed"),
          test_dir.join(".runtime_tests_passed"),
          test_dir.join(".runtime_tests_failed"),
          test_dir.join(".runtime_test_results.txt"),
          test_bin_dir.join(".tool_tests_passed"),
          test_bin_dir.join(".tool_tests_failed"),
          test_bin_dir.join(".editor_game_passed"),
          test_bin_dir.join(".editor_game_failed"),
          test_bin_dir.join(".runtime_tests_passed"),
          test_bin_dir.join(".runtime_tests_failed"),
          test_bin_dir.join(".runtime_test_results.txt"),
        ].each do |marker|
          File.delete(marker) if File.exists?(marker)
        end
      end

      record StepResult,
        name : String,
        success : Bool,
        duration : Float64,
        exit_code : Int32

      def self.generate_status_report(
        test_dir : Path,
        test_bin_dir : Path,
        godot_exe : String?,
        recorded_results : Array(StepResult),
        failed_steps : Array(String),
        total_duration : Float64
      ) : Void
        platform_arch = Core::Env.windows? ? "x86_64" : (Core::Env.macos? ? "arm64" : "x86_64")
        platform_name = if Core::Env.windows?
          "Windows (#{platform_arch})"
        elsif Core::Env.macos?
          "macOS (#{platform_arch})"
        else
          "Linux (#{platform_arch})"
        end

        crystal_ver = "Crystal #{Crystal::VERSION}"
        godot_ver = "Unknown"
        if g = godot_exe
          res = Core::ProcessRunner.capture(g.to_s, ["--version"])
          godot_ver = res[:output].lines.first?.try(&.strip) || "Unknown" if res[:status].success?
        end

        runtime_total = 0
        runtime_passed = 0
        runtime_failed = 0
        summary_file = [test_dir.join(".runtime_test_results.txt"), test_bin_dir.join(".runtime_test_results.txt")].find { |f| File.exists?(f) }
        if summary_file
          content = File.read(summary_file)
          runtime_total = $1.to_i if content =~ /TOTAL=(\d+)/
          runtime_passed = $1.to_i if content =~ /PASSED=(\d+)/
          runtime_failed = $1.to_i if content =~ /FAILED=(\d+)/
        end

        status_badge = failed_steps.empty? ? "**SUCCESS (All Passed)**" : "**FAILED (#{failed_steps.size} failed)**"

        md_report = String.build do |md|
          md.puts "## LibGodot Test Suite Status Report (#{platform_name})"
          md.puts
          md.puts "| Metric | Value |"
          md.puts "| :--- | :--- |"
          md.puts "| **Overall Status** | #{status_badge} |"
          md.puts "| **Platform** | #{platform_name} |"
          md.puts "| **Crystal Version** | #{crystal_ver} |"
          md.puts "| **Godot Version** | #{godot_ver} |"
          md.puts "| **Total Duration** | #{total_duration}s |"
          if runtime_total > 0
            md.puts "| **Runtime Assertions** | #{runtime_passed} / #{runtime_total} passed |"
          end
          md.puts
          md.puts "### Executed Test Steps"
          md.puts
          md.puts "| Status | Phase / Test Step | Duration | Exit Code |"
          md.puts "| :---: | :--- | :---: | :---: |"
          recorded_results.each do |r|
            status_icon = r.success ? "PASSED" : "FAILED"
            md.puts "| #{status_icon} | #{r.name} | #{r.duration}s | #{r.exit_code} |"
          end
          if !failed_steps.empty?
            md.puts
            md.puts "### Failures Detected (#{failed_steps.size})"
            failed_steps.each do |f|
              md.puts "- FAIL: #{f}"
            end
          end
        end

        json_steps = recorded_results.map do |r|
          %{{"name": #{r.name.to_json}, "success": #{r.success}, "duration": #{r.duration}, "exit_code": #{r.exit_code}}}
        end.join(", ")

        json_failed = failed_steps.map(&.to_json).join(", ")

        json_report = %{{
  "platform": #{platform_name.to_json},
  "crystal_version": #{crystal_ver.to_json},
  "godot_version": #{godot_ver.to_json},
  "duration_seconds": #{total_duration},
  "overall_success": #{failed_steps.empty?},
  "failed_steps_count": #{failed_steps.size},
  "failed_steps": [#{json_failed}],
  "runtime_summary": {
    "total": #{runtime_total},
    "passed": #{runtime_passed},
    "failed": #{runtime_failed}
  },
  "steps": [#{json_steps}],
  "timestamp": #{Time.utc.to_rfc3339.to_json}
}}

        FileUtils.mkdir_p(test_dir) unless Dir.exists?(test_dir)
        FileUtils.mkdir_p(test_bin_dir) unless Dir.exists?(test_bin_dir)

        File.write(test_dir.join("test_report.md"), md_report)
        File.write(test_bin_dir.join("test_report.md"), md_report)
        File.write(test_dir.join("test_report.json"), json_report)
        File.write(test_bin_dir.join("test_report.json"), json_report)

        if gsummary = ENV["GITHUB_STEP_SUMMARY"]?
          begin
            File.open(gsummary, "a") do |io|
              io.puts "\n"
              io.puts md_report
              io.puts "\n"
            end
            Core::Logger.info("Published test report to GitHub Step Summary.")
          rescue ex
            Core::Logger.warn("Could not write to GITHUB_STEP_SUMMARY: #{ex.message}")
          end
        end
      rescue ex
        Core::Logger.warn("Error generating test status report: #{ex.message}")
      end

      private def self.safe_exit_code(status : Process::Status) : Int32
        status.normal_exit? ? status.exit_code : -1
      end

      def self.run(args : Array(String)) : Int32
        if args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        start_time = Time.instant
        skip_specs = false
        skip_engine_specs = false
        skip_cli_specs = false
        skip_tool_tests = false
        skip_runtime_tests = false
        skip_standalone = false
        godot_path : String? = nil

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis test [options]"
          opts.on("--skip-specs", "Skip all Crystal spec unit tests") { skip_specs = true }
          opts.on("--skip-engine-specs", "Skip engine & bindings specifications") { skip_engine_specs = true }
          opts.on("--skip-cli-specs", "Skip Lapis toolchain & CLI specifications") { skip_cli_specs = true }
          opts.on("--skip-tool-tests", "Skip in-editor @tool tests") { skip_tool_tests = true }
          opts.on("--skip-runtime-tests", "Skip Godot runtime test project") { skip_runtime_tests = true }
          opts.on("--skip-standalone", "Skip standalone test executable") { skip_standalone = true }
          opts.on("-g PATH", "--godot=PATH", "Explicit Godot executable path") { |p| godot_path = p }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
        end

        parser.parse(args)

        root = Core::Env::ROOT_DIR
        test_dir = root.join("test")
        test_bin_dir = test_dir.join("bin")
        godot_exe = Core::GodotFinder.resolve(godot_path)

        failed_steps = [] of String
        recorded_results = [] of StepResult
        clear_markers(test_dir, test_bin_dir)

        begin
          # -----------------------------------------------------------------------
          # Phase 1: Crystal Unit Specs
          # -----------------------------------------------------------------------
          unless skip_specs
            # Phase 1a: Engine & Core Bindings Specifications
            unless skip_engine_specs
              spec_dir = test_dir.join("spec")
              if Dir.exists?(spec_dir)
                Core::Logger.step("Test:Specs:Engine", "Running Phase 1a: Engine specifications in test/spec...")
                step_start = Time.instant
                status = Core::ProcessRunner.run(
                  "crystal",
                  ["spec", "test/spec"],
                  chdir: root.to_s
                )
                step_dur = (Time.instant - step_start).total_seconds.round(2)
                recorded_results << StepResult.new("Phase 1a: Engine Specifications (test/spec)", status.success?, step_dur, safe_exit_code(status))
                failed_steps << "Phase 1a: Engine Specifications (test/spec)" unless status.success?
              end
            end

            # Phase 1b: Lapis Toolchain & CLI Specifications
            unless skip_cli_specs
              lapis_spec_dir = root.join("tools/lapis/spec")
              if Dir.exists?(lapis_spec_dir)
                Core::Logger.step("Test:Specs:CLI", "Running Phase 1b: Lapis toolchain specifications in tools/lapis/spec...")
                step_start = Time.instant
                status = Core::ProcessRunner.run(
                  "crystal",
                  ["spec", "tools/lapis/spec"],
                  chdir: root.to_s
                )
                step_dur = (Time.instant - step_start).total_seconds.round(2)
                recorded_results << StepResult.new("Phase 1b: Lapis CLI Specifications (tools/lapis/spec)", status.success?, step_dur, safe_exit_code(status))
                failed_steps << "Phase 1b: Lapis CLI Specifications (tools/lapis/spec)" unless status.success?
              end
            end

            # Phase 1c: Headless Architectural & Integration Specs
            root_specs = [
              "spec/libgodot_spec.cr",
              "spec/boot_spec.cr",
              "spec/binary_release_spec.cr",
              "spec/api_coverage_spec.cr",
              "spec/project_scaffolding_spec.cr",
              "spec/godot_version_verification_spec.cr",
              "spec/lapis_install_spec.cr",
              "spec/tool_verification_spec.cr",
              "spec/baked_file_system_spec.cr",
              "spec/standalone_portable_spec.cr",
            ]
            root_specs.each do |spec_file|
              full_path = root.join(spec_file)
              if File.exists?(full_path)
                Core::Logger.step("Test:Specs:Root", "Running #{spec_file}...")
                step_start = Time.instant
                status = Core::ProcessRunner.run(
                  "crystal",
                  ["run", spec_file],
                  chdir: root.to_s
                )
                {% if flag?(:windows) %}
                if !status.success?
                  sleep 0.5.seconds
                  status = Core::ProcessRunner.run(
                    "crystal",
                    ["run", spec_file],
                    chdir: root.to_s
                  )
                end
                {% end %}
                step_dur = (Time.instant - step_start).total_seconds.round(2)
                recorded_results << StepResult.new("Crystal Spec (#{spec_file})", status.success?, step_dur, safe_exit_code(status))
                failed_steps << "Crystal Spec (#{spec_file})" unless status.success?
              end
            end
          end

          # -----------------------------------------------------------------------
          # Phase 2: In-Editor Tool Tests (Headless)
          # -----------------------------------------------------------------------
          unless skip_tool_tests
            if godot_exe
              Core::Logger.step("Test:Editor", "Running In-Editor Tool Tests (Headless Phase 2a/2b)...")
              env = {
                "CRYSTAL_TOOL_TEST"      => "1",
                "GODOT_RUN_TOOL_TESTS"   => "1",
                "GODOT_HEADLESS"         => "1",
                "LIBGL_ALWAYS_SOFTWARE"  => "1"
              }
              clear_markers(test_dir, test_bin_dir)
              step_start = Time.instant
              status = Core::ProcessRunner.run(
                godot_exe,
                ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--editor", "--path", "test", "--quit-after", "600"],
                env: env,
                chdir: root.to_s
              )
              step_dur = (Time.instant - step_start).total_seconds.round(2)

              failed_tool_marker = [test_dir.join(".tool_tests_failed"), test_bin_dir.join(".tool_tests_failed")].find { |f| File.exists?(f) }
              passed_tool_marker = [test_dir.join(".tool_tests_passed"), test_bin_dir.join(".tool_tests_passed")].find { |f| File.exists?(f) }

              editor_success = true
              if failed_tool_marker
                Core::Logger.error("In-editor @tool tests reported failures.")
                failed_steps << "In-Editor Tests (Phase 2a/2b)"
                editor_success = false
              elsif !passed_tool_marker && !status.success?
                failed_steps << "In-Editor Tests (Phase 2a/2b)"
                editor_success = false
              else
                Core::Logger.success("In-editor @tool tests verified successfully!")
              end
              recorded_results << StepResult.new("In-Editor Tests (Phase 2a/2b)", editor_success, step_dur, safe_exit_code(status))
            else
              Core::Logger.warn("Godot executable not found, skipping in-editor tests.")
            end
          end

          # -----------------------------------------------------------------------
          # Phase 3a: Standalone Test Runner (Regular with separate .pck & DLL/SO)
          # -----------------------------------------------------------------------
          unless skip_standalone
            standalone_exe = test_bin_dir.join("tests#{Core::Env.exe_ext}")
            standalone_exe = test_bin_dir.join("game#{Core::Env.exe_ext}") unless File.exists?(standalone_exe)

            if File.exists?(standalone_exe)
              File.chmod(standalone_exe.to_s, 0o755) unless Core::Env.windows?
              Core::Logger.step("Test:Standalone", "Running Standalone Test Runner (Regular with separate .pck & DLL/SO: #{standalone_exe.basename})...")
              clear_markers(test_dir, test_bin_dir)
              step_start = Time.instant
              status = begin
                Core::ProcessRunner.run(
                  standalone_exe.to_s,
                  ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--quit-after", "600", "--", "--autorun"],
                  chdir: test_bin_dir.to_s
                )
              rescue ex
                Core::Logger.error("Failed to execute regular standalone runner: #{ex.message}")
                Process::Status[1]
              end
              step_dur = (Time.instant - step_start).total_seconds.round(2)

              failed_marker = [test_dir.join(".runtime_tests_failed"), test_bin_dir.join(".runtime_tests_failed")].find { |f| File.exists?(f) }
              passed_marker = [test_dir.join(".runtime_tests_passed"), test_bin_dir.join(".runtime_tests_passed")].find { |f| File.exists?(f) }

              standalone_success = true
              if failed_marker
                Core::Logger.error("Regular standalone test runner reported failures.")
                failed_steps << "Regular Standalone Test Runner"
                standalone_success = false
              elsif !passed_marker && !status.success?
                failed_steps << "Regular Standalone Test Runner"
                standalone_success = false
              else
                Core::Logger.success("Regular standalone test runner verified successfully!")
              end
              recorded_results << StepResult.new("Regular Standalone Test Runner", standalone_success, step_dur, safe_exit_code(status))
            end

            # -----------------------------------------------------------------------
            # Phase 3b: Standalone Portable Test Runner (Embedded PCK in isolated sandbox)
            # -----------------------------------------------------------------------
            portable_exe = test_bin_dir.join("tests_portable#{Core::Env.exe_ext}")
            pck_file = test_bin_dir.join("tests.pck")
            if !File.exists?(portable_exe) && File.exists?(standalone_exe) && File.exists?(pck_file)
              Package.embed_pck_in_executable(standalone_exe, pck_file, portable_exe)
            end

            if File.exists?(portable_exe)
              Core::Logger.step("Test:Portable", "Running Standalone Portable Test Runner (Isolated Embedded PCK without external .pck: #{portable_exe.basename})...")

              # Setup isolated sandbox containing ONLY portable binary and dynamic libraries (NO .pck files!)
              sandbox_dir = root.join("scratch/test_portable_sandbox")
              FileUtils.rm_rf(sandbox_dir) if Dir.exists?(sandbox_dir)
              FileUtils.mkdir_p(sandbox_dir)

              sandbox_exe = sandbox_dir.join("tests_portable#{Core::Env.exe_ext}")
              FileUtils.cp(portable_exe.to_s, sandbox_exe.to_s)
              File.chmod(sandbox_exe.to_s, 0o755) unless Core::Env.windows?

              # Copy required dynamic libraries, addons, and manifests (exclude any .pck or .zip)
              Dir.each_child(test_bin_dir) do |item|
                next if item.ends_with?(".pck") || item.ends_with?(".zip")
                next if item.starts_with?(".") && item != ".godot"
                src_item = test_bin_dir.join(item)
                if File.file?(src_item) && [".dll", ".so", ".dylib"].includes?(src_item.extension)
                  FileUtils.cp(src_item.to_s, sandbox_dir.join(item).to_s)
                elsif Dir.exists?(src_item) && (item == "addons" || item == ".godot")
                  FileUtils.cp_r(src_item.to_s, sandbox_dir.join(item).to_s)
                end
              end

              clear_markers(test_dir, sandbox_dir)

              step_start = Time.instant
              status = begin
                Core::ProcessRunner.run(
                  sandbox_exe.to_s,
                  ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--quit-after", "600", "--", "--autorun"],
                  chdir: sandbox_dir.to_s
                )
              rescue ex
                Core::Logger.error("Failed to execute portable runner: #{ex.message}")
                Process::Status[1]
              end
              step_dur = (Time.instant - step_start).total_seconds.round(2)

              failed_marker = [test_dir.join(".runtime_tests_failed"), sandbox_dir.join(".runtime_tests_failed")].find { |f| File.exists?(f) }
              passed_marker = [test_dir.join(".runtime_tests_passed"), sandbox_dir.join(".runtime_tests_passed")].find { |f| File.exists?(f) }

              portable_success = true
              if failed_marker || !passed_marker || !status.success?
                Core::Logger.error("Standalone portable test runner reported failures in isolated sandbox.")
                failed_steps << "Standalone Portable Test Runner"
                portable_success = false
              else
                Core::Logger.success("Standalone portable test runner verified successfully in isolated sandbox!")
              end
              recorded_results << StepResult.new("Standalone Portable Test Runner", portable_success, step_dur, safe_exit_code(status))

              FileUtils.rm_rf(sandbox_dir) if Dir.exists?(sandbox_dir)
            end
          end

          # -----------------------------------------------------------------------
          # Phase 4: Runtime Test Project (via Godot CLI)
          # -----------------------------------------------------------------------
          unless skip_runtime_tests
            if godot_exe
              Core::Logger.step("Test:Runtime", "Running In-Project Runtime Test Runner (main_test_runner.tscn)...")
              step_start = Time.instant
              status = begin
                Core::ProcessRunner.run(
                  godot_exe,
                  ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--path", ".", "--quit-after", "600", "--", "--autorun"],
                  chdir: test_dir.to_s
                )
              rescue ex
                Core::Logger.error("Failed to execute runtime runner: #{ex.message}")
                Process::Status[1]
              end
              step_dur = (Time.instant - step_start).total_seconds.round(2)

              failed_marker = [test_dir.join(".runtime_tests_failed"), test_bin_dir.join(".runtime_tests_failed")].find { |f| File.exists?(f) }
              passed_marker = [test_dir.join(".runtime_tests_passed"), test_bin_dir.join(".runtime_tests_passed")].find { |f| File.exists?(f) }

              runtime_success = true
              if failed_marker
                Core::Logger.error("Runtime test runner reported failures.")
                failed_steps << "Runtime Tests"
                runtime_success = false
              elsif !passed_marker && !status.success?
                failed_steps << "Runtime Tests"
                runtime_success = false
              else
                Core::Logger.success("Runtime test suite verified successfully!")
              end
              recorded_results << StepResult.new("Runtime Tests (main_test_runner.tscn)", runtime_success, step_dur, safe_exit_code(status))
            else
              Core::Logger.warn("Godot executable not found, skipping runtime tests.")
            end
          end
        ensure
          total_duration = (Time.instant - start_time).total_seconds.round(2)
          generate_status_report(test_dir, test_bin_dir, godot_exe, recorded_results, failed_steps, total_duration)
        end

        puts
        if failed_steps.empty?
          Core::Logger.success("All test suites passed successfully! (#{total_duration}s)")
          0
        else
          Core::Logger.error("The following test suites failed (#{total_duration}s): #{failed_steps.join(", ")}")
          1
        end
      end
    end
  end
end
