require "../core/env"
require "../core/logger"
require "../core/process_runner"
require "../core/godot_finder"
require "file_utils"
require "option_parser"

module Lapis
  module Commands
    module Test
      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Automated Test Suite Runner ===\e[0m

Usage: lapis test [options]

Options:
  --skip-specs          Skip Crystal spec unit tests (test/spec, spec/*)
  --skip-tool-tests     Skip headless in-editor @tool tests
  --skip-runtime-tests  Skip Godot runtime test project
  --skip-standalone     Skip standalone compiled test executable
  -g, --godot=PATH      Explicit Godot engine executable path
  -h, --help            Show this help screen

Examples:
  lapis test
  lapis test --skip-specs
  lapis test --skip-runtime-tests
HELP
      end

      def self.clear_markers(test_dir : Path, test_bin_dir : Path)
        [
          test_dir.join(".tool_tests_passed"),
          test_dir.join(".tool_tests_failed"),
          test_dir.join(".runtime_tests_passed"),
          test_dir.join(".runtime_tests_failed"),
          test_dir.join(".runtime_test_results.txt"),
          test_bin_dir.join(".tool_tests_passed"),
          test_bin_dir.join(".tool_tests_failed"),
          test_bin_dir.join(".runtime_tests_passed"),
          test_bin_dir.join(".runtime_tests_failed"),
          test_bin_dir.join(".runtime_test_results.txt"),
        ].each do |marker|
          File.delete(marker) if File.exists?(marker)
        end
      end

      def self.run(args : Array(String)) : Int32
        if args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        skip_specs = false
        skip_tool_tests = false
        skip_runtime_tests = false
        skip_standalone = false
        godot_path : String? = nil

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis test [options]"
          opts.on("--skip-specs", "Skip Crystal spec unit tests") { skip_specs = true }
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
        clear_markers(test_dir, test_bin_dir)

        # -----------------------------------------------------------------------
        # Phase 1: Crystal Unit Specs
        # -----------------------------------------------------------------------
        unless skip_specs
          spec_dir = test_dir.join("spec")
          if Dir.exists?(spec_dir)
            Core::Logger.step("Test:Specs", "Running Crystal specifications in test/spec...")
            status = Core::ProcessRunner.run(
              "crystal",
              ["spec", "test/spec"],
              chdir: root.to_s
            )
            failed_steps << "Crystal Specifications (test/spec)" unless status.success?
          end

          root_specs = [
            "spec/libgodot_spec.cr",
            "spec/boot_spec.cr",
            "spec/api_coverage_spec.cr",
            "spec/project_scaffolding_spec.cr",
            "spec/godot_version_verification_spec.cr",
            "spec/lapis_install_spec.cr",
            "spec/tool_verification_spec.cr",
            "spec/baked_file_system_spec.cr",
          ]
          root_specs.each do |spec_file|
            full_path = root.join(spec_file)
            if File.exists?(full_path)
              Core::Logger.step("Test:Specs", "Running #{spec_file}...")
              status = Core::ProcessRunner.run(
                "crystal",
                ["run", spec_file],
                chdir: root.to_s
              )
              failed_steps << "Crystal Spec (#{spec_file})" unless status.success?
            end
          end
        end

        # -----------------------------------------------------------------------
        # Phase 2: In-Editor Tool Script Tests
        # -----------------------------------------------------------------------
        unless skip_tool_tests
          if godot_exe
            Core::Logger.step("Test:ToolTests", "Running In-Editor Tool Script Tests (ToolTester2D & ToolTester3D)...")
            tool_env = {
              "GODOT_RUN_TOOL_TESTS" => "1",
              "LIBGL_ALWAYS_SOFTWARE" => "1"
            }
            status = Core::ProcessRunner.run(
              godot_exe,
              ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--editor", "--path", "test", "--quit-after", "300"],
              env: tool_env,
              chdir: root.to_s
            )

            failed_marker = [test_dir.join(".tool_tests_failed"), test_bin_dir.join(".tool_tests_failed")].find { |f| File.exists?(f) }
            passed_marker = [test_dir.join(".tool_tests_passed"), test_bin_dir.join(".tool_tests_passed")].find { |f| File.exists?(f) }

            if failed_marker
              fail_msg = File.read(failed_marker).strip
              Core::Logger.error("Tool tests failed: #{fail_msg}")
              failed_steps << "In-Editor Tool Tests"
            elsif !passed_marker && !status.success?
              failed_steps << "In-Editor Tool Tests"
            else
              Core::Logger.success("In-Editor Tool Script Tests verified successfully!")
            end
          else
            Core::Logger.warn("Godot engine not found, skipping tool tests.")
          end
        end

        # -----------------------------------------------------------------------
        # Phase 3: Standalone Compiled Test Runner
        # -----------------------------------------------------------------------
        unless skip_standalone
          standalone_exe = test_bin_dir.join("tests#{Core::Env.exe_ext}")
          standalone_exe = test_bin_dir.join("game#{Core::Env.exe_ext}") unless File.exists?(standalone_exe)

          if File.exists?(standalone_exe)
            Core::Logger.step("Test:Standalone", "Running Standalone Test Runner (#{standalone_exe.basename} --autorun)...")
            status = Core::ProcessRunner.run(
              standalone_exe.to_s,
              ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--quit-after", "600", "--", "--autorun"],
              chdir: test_bin_dir.to_s
            )

            failed_marker = [test_dir.join(".runtime_tests_failed"), test_bin_dir.join(".runtime_tests_failed")].find { |f| File.exists?(f) }
            passed_marker = [test_dir.join(".runtime_tests_passed"), test_bin_dir.join(".runtime_tests_passed")].find { |f| File.exists?(f) }

            if failed_marker
              Core::Logger.error("Standalone test runner reported failures.")
              failed_steps << "Standalone Test Runner"
            elsif !passed_marker && !status.success?
              failed_steps << "Standalone Test Runner"
            else
              Core::Logger.success("Standalone test runner verified successfully!")
            end
          end
        end

        # -----------------------------------------------------------------------
        # Phase 4: In-Project Runtime Test Runner
        # -----------------------------------------------------------------------
        unless skip_runtime_tests
          if godot_exe
            Core::Logger.step("Test:Runtime", "Running In-Project Runtime Test Runner (main_test_runner.tscn)...")
            status = Core::ProcessRunner.run(
              godot_exe,
              ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--path", ".", "--quit-after", "600", "--", "--autorun"],
              chdir: test_dir.to_s
            )

            failed_marker = [test_dir.join(".runtime_tests_failed"), test_bin_dir.join(".runtime_tests_failed")].find { |f| File.exists?(f) }
            passed_marker = [test_dir.join(".runtime_tests_passed"), test_bin_dir.join(".runtime_tests_passed")].find { |f| File.exists?(f) }

            if failed_marker
              Core::Logger.error("Runtime test runner reported failures.")
              failed_steps << "Runtime Tests"
            elsif !passed_marker && !status.success?
              failed_steps << "Runtime Tests"
            else
              Core::Logger.success("Runtime test suite verified successfully!")
            end
          else
            Core::Logger.warn("Godot executable not found, skipping runtime tests.")
          end
        end

        puts
        if failed_steps.empty?
          Core::Logger.success("All test suites passed successfully!")
          0
        else
          Core::Logger.error("The following test suites failed: #{failed_steps.join(", ")}")
          1
        end
      end
    end
  end
end
