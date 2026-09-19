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
            "spec/standalone_portable_spec.cr",
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
        # Phase 2: In-Editor Tests (Phase 2a: Tool Scripts & Phase 2b: Game Runner in Play Mode)
        # -----------------------------------------------------------------------
        unless skip_tool_tests
          if godot_exe
            Core::Logger.step("Test:EditorTests", "Running In-Editor Tests (Phase 2a: @tool scripts & Phase 2b: 'Press Play' editor game runner)...")
            tool_env = {
              "GODOT_RUN_TOOL_TESTS"   => "1",
              "GODOT_RUN_EDITOR_TESTS" => "1",
              "GODOT_TEST_AUTORUN"     => "1",
              "LIBGL_ALWAYS_SOFTWARE"  => "1"
            }
            clear_markers(test_dir, test_bin_dir)
            status = Core::ProcessRunner.run(
              godot_exe,
              ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--editor", "--path", "test", "--quit-after", "600"],
              env: tool_env,
              chdir: root.to_s
            )

            failed_tool_marker = [test_dir.join(".tool_tests_failed"), test_bin_dir.join(".tool_tests_failed")].find { |f| File.exists?(f) }
            passed_tool_marker = [test_dir.join(".tool_tests_passed"), test_bin_dir.join(".tool_tests_passed")].find { |f| File.exists?(f) }
            failed_editor_marker = [test_dir.join(".editor_game_failed"), test_bin_dir.join(".editor_game_failed")].find { |f| File.exists?(f) }
            passed_editor_marker = [test_dir.join(".editor_game_passed"), test_bin_dir.join(".editor_game_passed")].find { |f| File.exists?(f) }

            if failed_tool_marker || failed_editor_marker
              fail_msg = [(failed_tool_marker ? File.read(failed_tool_marker).strip : nil), (failed_editor_marker ? File.read(failed_editor_marker).strip : nil)].compact.join(" | ")
              Core::Logger.error("In-editor tests failed: #{fail_msg}")
              failed_steps << "In-Editor Tests (Phase 2a/2b)"
            elsif (!passed_tool_marker || !passed_editor_marker) && !status.success?
              failed_steps << "In-Editor Tests (Phase 2a/2b)"
            else
              Core::Logger.success("In-Editor Tests: Phase 2a (@tool scripts) & Phase 2b ('Press Play' editor game runner) verified successfully!")
            end
          else
            Core::Logger.warn("Godot engine not found, skipping in-editor tests.")
          end
        end

        # -----------------------------------------------------------------------
        # Phase 3a: Standalone Test Runner (Regular with separate .pck & DLL/SO)
        # -----------------------------------------------------------------------
        unless skip_standalone
          standalone_exe = test_bin_dir.join("tests#{Core::Env.exe_ext}")
          standalone_exe = test_bin_dir.join("game#{Core::Env.exe_ext}") unless File.exists?(standalone_exe)

          if File.exists?(standalone_exe)
            Core::Logger.step("Test:Standalone", "Running Standalone Test Runner (Regular with separate .pck & DLL/SO: #{standalone_exe.basename})...")
            clear_markers(test_dir, test_bin_dir)
            status = Core::ProcessRunner.run(
              standalone_exe.to_s,
              ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--quit-after", "600", "--", "--autorun"],
              chdir: test_bin_dir.to_s
            )

            failed_marker = [test_dir.join(".runtime_tests_failed"), test_bin_dir.join(".runtime_tests_failed")].find { |f| File.exists?(f) }
            passed_marker = [test_dir.join(".runtime_tests_passed"), test_bin_dir.join(".runtime_tests_passed")].find { |f| File.exists?(f) }

            if failed_marker
              Core::Logger.error("Regular standalone test runner reported failures.")
              failed_steps << "Regular Standalone Test Runner"
            elsif !passed_marker && !status.success?
              failed_steps << "Regular Standalone Test Runner"
            else
              Core::Logger.success("Regular standalone test runner verified successfully!")
            end
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

            status = Core::ProcessRunner.run(
              sandbox_exe.to_s,
              ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--quit-after", "600", "--", "--autorun"],
              chdir: sandbox_dir.to_s
            )

            failed_marker = [test_dir.join(".runtime_tests_failed"), sandbox_dir.join(".runtime_tests_failed")].find { |f| File.exists?(f) }
            passed_marker = [test_dir.join(".runtime_tests_passed"), sandbox_dir.join(".runtime_tests_passed")].find { |f| File.exists?(f) }

            if failed_marker || !passed_marker || !status.success?
              Core::Logger.error("Standalone portable test runner reported failures in isolated sandbox.")
              failed_steps << "Standalone Portable Test Runner"
            else
              Core::Logger.success("Standalone portable test runner verified successfully in isolated sandbox!")
            end

            FileUtils.rm_rf(sandbox_dir) if Dir.exists?(sandbox_dir)
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
