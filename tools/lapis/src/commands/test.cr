require "../core/env"
require "../core/logger"
require "../core/process_runner"
require "../core/step_summary"
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
  -v, --verbose         Enable verbose diagnostic logging and pass to Godot
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
          test_dir.join(".godot/editor/script_editor_cache.cfg"),
        ].each do |marker|
          File.delete(marker) if File.exists?(marker)
        end
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
          opts.on("-v", "--verbose", "Enable verbose diagnostic logging") { Core::Logger.verbose = true }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
        end

        parser.parse(args)

        root = Core::Env::ROOT_DIR
        test_dir = root.join("test")
        test_bin_dir = test_dir.join("bin")
        godot_exe = Core::GodotFinder.resolve(godot_path)

        step_summary = Core::StepSummary.new("LibGodot Test Suite Status Report", godot_exe)
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
                res = Core::ProcessRunner.run_with_capture(
                  "crystal",
                  ["spec", "test/spec"],
                  chdir: root.to_s
                )
                step_dur = (Time.instant - step_start).total_seconds.round(2)
                step_summary.add_phase(
                  tag: "[TEST:SPECS:ENGINE]",
                  name: "Engine Specifications (test/spec)",
                  category: "Spec",
                  success: res[:status].success?,
                  duration: step_dur,
                  exit_code: safe_exit_code(res[:status]),
                  error_excerpt: res[:error_excerpt]
                )
              end
            end

            # Phase 1b: Lapis Toolchain & CLI Specifications
            unless skip_cli_specs
              lapis_spec_dir = root.join("tools/lapis/spec")
              if Dir.exists?(lapis_spec_dir)
                Core::Logger.step("Test:Specs:CLI", "Running Phase 1b: Lapis toolchain specifications in tools/lapis/spec...")
                step_start = Time.instant
                res = Core::ProcessRunner.run_with_capture(
                  "crystal",
                  ["spec", "tools/lapis/spec"],
                  chdir: root.to_s
                )
                step_dur = (Time.instant - step_start).total_seconds.round(2)
                step_summary.add_phase(
                  tag: "[TEST:SPECS:CLI]",
                  name: "Lapis CLI Specifications (tools/lapis/spec)",
                  category: "Spec",
                  success: res[:status].success?,
                  duration: step_dur,
                  exit_code: safe_exit_code(res[:status]),
                  error_excerpt: res[:error_excerpt]
                )
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
                spec_tag_name = Path.new(spec_file).basename.gsub(".cr", "").upcase
                Core::Logger.step("Test:Specs:Root", "Running #{spec_file}...")
                step_start = Time.instant
                res = Core::ProcessRunner.run_with_capture(
                  "crystal",
                  ["run", spec_file],
                  chdir: root.to_s
                )
                {% if flag?(:windows) %}
                  if !res[:status].success?
                    sleep 0.5.seconds
                    res = Core::ProcessRunner.run_with_capture(
                      "crystal",
                      ["run", spec_file],
                      chdir: root.to_s
                    )
                  end
                {% end %}
                step_dur = (Time.instant - step_start).total_seconds.round(2)
                step_summary.add_phase(
                  tag: "[TEST:SPECS:#{spec_tag_name}]",
                  name: "Architectural Spec (#{spec_file})",
                  category: "Spec",
                  success: res[:status].success?,
                  duration: step_dur,
                  exit_code: safe_exit_code(res[:status]),
                  error_excerpt: res[:error_excerpt]
                )
              end
            end

            # Phase 1d: Debugger & Crash Handler Specifications
            debugger_specs = [
              "spec/crash_handler_spec.cr",
              "spec/lldb_driver_spec.cr",
              "spec/debugger_breakpoints_spec.cr",
              "spec/lldb_integration_spec.cr",
            ]
            active_dbg_specs = debugger_specs.select { |f| File.exists?(root.join(f)) }
            if active_dbg_specs.any?
              Core::Logger.step("Test:Specs:Debugger", "Running Phase 1d: Debugger and crash handler specifications...")
              step_start = Time.instant
              res = Core::ProcessRunner.run_with_capture(
                "crystal",
                ["spec"] + active_dbg_specs,
                chdir: root.to_s
              )
              step_dur = (Time.instant - step_start).total_seconds.round(2)
              step_summary.add_phase(
                tag: "[TEST:SPECS:DEBUGGER]",
                name: "Debugger & Crash Handler Specifications",
                category: "Spec",
                success: res[:status].success?,
                duration: step_dur,
                exit_code: safe_exit_code(res[:status]),
                error_excerpt: res[:error_excerpt]
              )
            end
          end

          # -----------------------------------------------------------------------
          # Phase 2: In-Editor Tool Tests (Headless)
          # -----------------------------------------------------------------------
          unless skip_tool_tests
            if godot_exe
              Core::Logger.step("Test:Editor", "Running In-Editor Tool Tests (Headless Phase 2a/2b)...")
              env = {
                "CRYSTAL_TOOL_TEST"     => "1",
                "GODOT_RUN_TOOL_TESTS"  => "1",
                "GODOT_HEADLESS"        => "1",
                "LIBGL_ALWAYS_SOFTWARE" => "1",
              }
              clear_markers(test_dir, test_bin_dir)
              step_start = Time.instant
              res = Core::ProcessRunner.run_with_capture(
                godot_exe,
                ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--editor", "--path", "test", "--quit-after", "600"],
                env: env,
                chdir: root.to_s
              )
              step_dur = (Time.instant - step_start).total_seconds.round(2)

              failed_tool_marker = [test_dir.join(".tool_tests_failed"), test_bin_dir.join(".tool_tests_failed")].find { |f| File.exists?(f) }
              passed_tool_marker = [test_dir.join(".tool_tests_passed"), test_bin_dir.join(".tool_tests_passed")].find { |f| File.exists?(f) }

              editor_success = true
              tool_err : String? = nil
              if failed_tool_marker
                Core::Logger.error("In-editor @tool tests reported failures.")
                editor_success = false
                tool_err = File.read(failed_tool_marker) rescue "In-editor @tool test failure reported in marker."
              elsif !passed_tool_marker && !res[:status].success?
                editor_success = false
                tool_err = res[:error_excerpt] || "In-editor tests crashed before completing."
              else
                Core::Logger.success("In-editor @tool tests verified successfully!")
              end

              step_summary.add_phase(
                tag: "[TEST:TOOL_NODES]",
                name: "Headless In-Editor @tool Tests (Phase 2a/2b)",
                category: "Test",
                success: editor_success,
                duration: step_dur,
                exit_code: safe_exit_code(res[:status]),
                error_excerpt: tool_err
              )
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
              res = begin
                Core::ProcessRunner.run_with_capture(
                  standalone_exe.to_s,
                  ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--quit-after", "600", "--", "--autorun"],
                  chdir: test_bin_dir.to_s
                )
              rescue ex
                Core::Logger.error("Failed to execute regular standalone runner: #{ex.message}")
                {status: Process::Status[1], error_excerpt: ex.message}
              end
              step_dur = (Time.instant - step_start).total_seconds.round(2)

              failed_marker = [test_dir.join(".runtime_tests_failed"), test_bin_dir.join(".runtime_tests_failed")].find { |f| File.exists?(f) }
              passed_marker = [test_dir.join(".runtime_tests_passed"), test_bin_dir.join(".runtime_tests_passed")].find { |f| File.exists?(f) }

              standalone_success = true
              standalone_err : String? = nil
              if failed_marker
                Core::Logger.error("Regular standalone test runner reported failures.")
                standalone_success = false
                standalone_err = File.read(failed_marker) rescue "Runtime assertion failures reported."
              elsif !passed_marker && !res[:status].success?
                standalone_success = false
                standalone_err = res[:error_excerpt] || "Process exited abnormally."
              else
                Core::Logger.success("Regular standalone test runner verified successfully!")
              end

              step_summary.add_phase(
                tag: "[TEST:STANDALONE]",
                name: "Regular Standalone Test Runner (#{standalone_exe.basename})",
                category: "Test",
                success: standalone_success,
                duration: step_dur,
                exit_code: safe_exit_code(res[:status]),
                error_excerpt: standalone_err
              )
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
              res = begin
                Core::ProcessRunner.run_with_capture(
                  sandbox_exe.to_s,
                  ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--quit-after", "600", "--", "--autorun"],
                  chdir: sandbox_dir.to_s
                )
              rescue ex
                Core::Logger.error("Failed to execute portable runner: #{ex.message}")
                {status: Process::Status[1], error_excerpt: ex.message}
              end
              step_dur = (Time.instant - step_start).total_seconds.round(2)

              failed_marker = [test_dir.join(".runtime_tests_failed"), sandbox_dir.join(".runtime_tests_failed")].find { |f| File.exists?(f) }
              passed_marker = [test_dir.join(".runtime_tests_passed"), sandbox_dir.join(".runtime_tests_passed")].find { |f| File.exists?(f) }

              portable_success = true
              portable_err : String? = nil
              if failed_marker
                Core::Logger.error("Standalone portable test runner reported failures in isolated sandbox.")
                portable_success = false
                portable_err = File.read(failed_marker) rescue "Runtime assertion failures reported."
              elsif !passed_marker && !res[:status].success?
                portable_success = false
                portable_err = res[:error_excerpt] || "Portable runner exited abnormally in sandbox."
              else
                Core::Logger.success("Standalone portable test runner verified successfully in isolated sandbox!")
              end

              step_summary.add_phase(
                tag: "[TEST:PORTABLE]",
                name: "Standalone Portable Test Runner in Sandbox",
                category: "Test",
                success: portable_success,
                duration: step_dur,
                exit_code: safe_exit_code(res[:status]),
                error_excerpt: portable_err
              )

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
              res = begin
                Core::ProcessRunner.run_with_capture(
                  godot_exe,
                  ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--path", ".", "--quit-after", "600", "--", "--autorun"],
                  chdir: test_dir.to_s
                )
              rescue ex
                Core::Logger.error("Failed to execute runtime runner: #{ex.message}")
                {status: Process::Status[1], error_excerpt: ex.message}
              end
              step_dur = (Time.instant - step_start).total_seconds.round(2)

              failed_marker = [test_dir.join(".runtime_tests_failed"), test_bin_dir.join(".runtime_tests_failed")].find { |f| File.exists?(f) }
              passed_marker = [test_dir.join(".runtime_tests_passed"), test_bin_dir.join(".runtime_tests_passed")].find { |f| File.exists?(f) }

              runtime_success = true
              runtime_err : String? = nil
              if failed_marker
                Core::Logger.error("Runtime test runner reported failures.")
                runtime_success = false
                runtime_err = File.read(failed_marker) rescue "Runtime assertion failures reported."
              elsif !passed_marker && !res[:status].success?
                runtime_success = false
                runtime_err = res[:error_excerpt] || "Runtime project exited abnormally."
              else
                Core::Logger.success("Runtime test suite verified successfully!")
              end

              step_summary.add_phase(
                tag: "[TEST:RUNTIME]",
                name: "In-Project Runtime Test Runner (main_test_runner.tscn)",
                category: "Test",
                success: runtime_success,
                duration: step_dur,
                exit_code: safe_exit_code(res[:status]),
                error_excerpt: runtime_err
              )
            else
              Core::Logger.warn("Godot executable not found, skipping runtime tests.")
            end
          end
        ensure
          total_duration = (Time.instant - start_time).total_seconds.round(2)
          step_summary.total_duration = total_duration

          # Harvest runtime metrics if available
          summary_file = [test_dir.join(".runtime_test_results.txt"), test_bin_dir.join(".runtime_test_results.txt")].find { |f| File.exists?(f) }
          runtime_total = 0
          runtime_passed = 0
          runtime_failed = 0
          if summary_file
            content = File.read(summary_file)
            runtime_total = $1.to_i if content =~ /TOTAL=(\d+)/
            runtime_passed = $1.to_i if content =~ /PASSED=(\d+)/
            runtime_failed = $1.to_i if content =~ /FAILED=(\d+)/
          end

          failed_details = [] of String
          failed_file = [test_dir.join(".runtime_tests_failed"), test_bin_dir.join(".runtime_tests_failed")].find { |f| File.exists?(f) }
          if failed_file
            failed_details = File.read(failed_file).lines.map(&.strip).reject(&.empty?)
          end
          step_summary.set_runtime_metrics(runtime_total, runtime_passed, runtime_failed, failed_details)

          # Record built test artifacts
          [
            test_bin_dir.join("tests#{Core::Env.exe_ext}"),
            test_bin_dir.join("tests_portable#{Core::Env.exe_ext}"),
            test_bin_dir.join("tests.pck"),
            root.join("bin/test-suite-windows.zip"),
            root.join("bin/test-suite-linux.zip"),
            root.join("bin/test-suite-macos.zip"),
          ].each do |art|
            step_summary.add_artifact(art.basename, art) if File.exists?(art)
          end

          step_summary.publish([test_dir, test_bin_dir], append_to_github_summary: true)
        end

        puts
        if step_summary.overall_success?
          Core::Logger.success("All test suites passed successfully! (#{total_duration}s)")
          0
        else
          failed_tags = step_summary.failed_phases.map(&.tag)
          Core::Logger.error("The following test phases failed (#{total_duration}s): #{failed_tags.join(", ")}")
          1
        end
      end
    end
  end
end
