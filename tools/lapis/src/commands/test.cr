require "../core/env"
require "../core/logger"
require "../core/process_runner"
require "../core/step_summary"
require "../core/godot_finder"
require "../tui/tui"
require "file_utils"
require "option_parser"
require "./package"

module Lapis
  module Commands
    module Test
      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Automated Test Suite Runner ===\e[0m

Usage: lapis test [options] [path]

Options:
  -p, --path=PATH       Target Godot project path (default: current directory or workspace root)
  --project=PATH        Target Godot project path (alias for --path)
  --tui                 Force launch interactive Terminal User Interface (TUI) dashboard
  --no-tui              Disable TUI and use standard streaming logs
  --skip-specs          Skip all Crystal spec unit tests
  --skip-engine-specs   Skip engine & bindings specifications (root engine only)
  --skip-cli-specs      Skip Lapis toolchain & CLI specifications (root engine only)
  --skip-tool-tests     Skip in-editor @tool tests (root engine only)
  --skip-runtime-tests  Skip Godot runtime test project
  --skip-standalone     Skip standalone compiled test executable
  -f, --filter=PATTERN  Run only runtime tests matching PATTERN
  -c, --category=NAME   Run only runtime tests in category NAME
  --junit=PATH          Export runtime test results to JUnit XML report
  -g, --godot=PATH      Explicit Godot engine executable path
  -v, --verbose         Enable verbose diagnostic logging and pass to Godot
  -h, --help            Show this help screen

Examples:
  lapis test
  lapis test template
  lapis test -p template
  lapis test --skip-specs
  lapis test -f "Signal"
  lapis test -c "2D"
  lapis test --junit reports/junit.xml
HELP
      end

      def self.resolve_target_dir(proj_path : String?, root : Path) : Path
        curr = Path.new(Dir.current).expand

        if proj_path && !proj_path.empty?
          p = Path.new(proj_path)
          return p if p.absolute? && Dir.exists?(p)
          return curr.join(p).expand if Dir.exists?(curr.join(p))
          return root.join(p).expand if Dir.exists?(root.join(p))
          return p.expand
        end

        # Auto-detect target project when no path is explicitly provided:
        # If current directory is not root and contains project.godot or shard.yml, use current directory!
        if curr != root && (File.exists?(curr.join("project.godot")) || File.exists?(curr.join("shard.yml")))
          return curr
        end

        root
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

        proj_path : String? = nil
        start_time = Time.instant
        skip_specs = false
        skip_engine_specs = false
        skip_cli_specs = false
        skip_tool_tests = false
        skip_runtime_tests = false
        skip_standalone = false
        filter_pattern : String? = nil
        force_tui : Bool? = nil
        category_filter : String? = nil
        junit_path : String? = nil
        godot_path : String? = nil

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis test [options] [path]"
          opts.on("-p PATH", "--path=PATH", "Target Godot project path") { |p| proj_path = p }
          opts.on("--project=PATH", "Target Godot project path") { |p| proj_path = p }
          opts.on("--tui", "Force launch interactive Terminal User Interface (TUI) dashboard") { force_tui = true }
          opts.on("--no-tui", "Disable TUI and use standard streaming logs") { force_tui = false }
          opts.on("--skip-specs", "Skip all Crystal spec unit tests") { skip_specs = true }
          opts.on("--skip-engine-specs", "Skip engine & bindings specifications") { skip_engine_specs = true }
          opts.on("--skip-cli-specs", "Skip Lapis toolchain & CLI specifications") { skip_cli_specs = true }
          opts.on("--skip-tool-tests", "Skip in-editor @tool tests") { skip_tool_tests = true }
          opts.on("--skip-runtime-tests", "Skip Godot runtime test project") { skip_runtime_tests = true }
          opts.on("--skip-standalone", "Skip standalone test executable") { skip_standalone = true }
          opts.on("-f PATTERN", "--filter=PATTERN", "Run only tests matching PATTERN") { |p| filter_pattern = p }
          opts.on("-c NAME", "--category=NAME", "Run only tests in category NAME") { |c| category_filter = c }
          opts.on("--junit=PATH", "Export test results to JUnit XML report") { |j| junit_path = j }
          opts.on("-g PATH", "--godot=PATH", "Explicit Godot engine executable path") { |p| godot_path = p }
          opts.on("-v", "--verbose", "Enable verbose diagnostic logging") { Core::Logger.verbose = true }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
          opts.unknown_args do |before, after|
            remaining = before + after
            proj_path ||= remaining.first if !remaining.empty?
          end
        end

        parser.parse(args)

        root = Core::Env::ROOT_DIR
        target_dir = resolve_target_dir(proj_path, root)
        is_root_engine = (target_dir == root) && Core::Env.is_libgodot_repo?(root)
        test_dir = target_dir
        test_bin_dir = target_dir.join("bin")
        FileUtils.mkdir_p(test_bin_dir) unless Dir.exists?(test_bin_dir)
        godot_exe = Core::GodotFinder.resolve(godot_path, target_dir.to_s)

        junit_path ||= test_bin_dir.join("junit.xml").to_s

        extra_runtime_args = [] of String
        extra_runtime_args << "--filter=#{filter_pattern}" if filter_pattern
        extra_runtime_args << "--category=#{category_filter}" if category_filter
        extra_runtime_args << "--junit=#{junit_path}" if junit_path

        proj_title = is_root_engine ? "Lapis Test Suite" : "Lapis Test Suite — #{target_dir.basename}"
        step_summary = Core::StepSummary.new("#{proj_title} Status Report", godot_exe)
        clear_markers(test_dir, test_bin_dir)

        # Detect TUI availability (TTY output, not CI, or explicitly requested)
        use_tui = if force_tui.nil?
                    STDOUT.tty? && !ENV.has_key?("CI")
                  else
                    force_tui.not_nil!
                  end

        tui : TUI::Controller? = nil
        if use_tui
          platform_str = Core::Env.windows? ? "Windows x86_64" : (Core::Env.macos? ? "macOS arm64" : "Linux x86_64")
          godot_ver = godot_exe ? (Core::GodotFinder.get_version(godot_exe) || "4.8-dev6") : "Not Found"
          tui = TUI::Controller.new(proj_title, platform_str, godot_ver)
        end

        phase_map = {} of String => Int32
        add_phase_item = ->(tag : String, name : String, category : String) {
          if t = tui
            idx = t.state.phases.size
            t.register_phase(tag, tag, name, category)
            phase_map[tag] = idx
          end
        }

        has_project_specs = Dir.exists?(target_dir.join("spec")) && !skip_specs
        runtime_scene = [
          target_dir.join("scenes/main_test_runner.tscn"),
          target_dir.join("scenes/test_runner.tscn"),
        ].find { |s| File.exists?(s) }
        has_runtime_test_scene = !runtime_scene.nil? && !skip_runtime_tests

        standalone_exe = test_bin_dir.join("tests#{Core::Env.exe_ext}")
        pck_file = test_bin_dir.join("tests.pck")
        if is_root_engine && (!File.exists?(standalone_exe) || !File.exists?(pck_file))
          standalone_exe = test_bin_dir.join("game#{Core::Env.exe_ext}")
          pck_file = test_bin_dir.join("game.pck")
        end
        has_standalone = File.exists?(standalone_exe) && File.exists?(pck_file)
        portable_exe = test_bin_dir.join("tests_portable#{Core::Env.exe_ext}")

        if is_root_engine
          # Pre-register test phases into TUI checklist for root engine
          unless skip_specs
            add_phase_item.call("[TEST:SPECS:ENGINE]", "Engine Specifications (spec)", "Spec") unless skip_engine_specs
            add_phase_item.call("[TEST:SPECS:CLI]", "Toolchain Specifications (tools/lapis/spec)", "Spec") unless skip_cli_specs
            add_phase_item.call("[TEST:SPECS:ROOT]", "Headless Architectural Specifications", "Spec")
            add_phase_item.call("[TEST:SPECS:DEBUGGER]", "Debugger & Crash Handler Specifications", "Spec")
          end
          add_phase_item.call("[TEST:TOOL_NODES]", "Headless In-Editor @tool Tests", "Test") unless skip_tool_tests

          unless skip_standalone
            if has_standalone
              add_phase_item.call("[TEST:STANDALONE]", "Regular Standalone Test Runner", "Test")
            end
            if File.exists?(portable_exe) || has_standalone
              add_phase_item.call("[TEST:PORTABLE]", "Standalone Portable Test Runner", "Test")
            end
          end
          add_phase_item.call("[TEST:RUNTIME]", "In-Project Runtime Test Runner (main_test_runner.tscn)", "Test") unless skip_runtime_tests
        else
          # Consumer Project (template, template-addon, examples, or standalone game)
          if has_project_specs
            add_phase_item.call("[TEST:SPECS]", "Project Specifications (#{target_dir.basename})", "Spec")
          end
          if has_standalone && !skip_standalone
            add_phase_item.call("[TEST:STANDALONE]", "Standalone Test Runner (#{standalone_exe.basename})", "Test")
          end
          if has_runtime_test_scene
            add_phase_item.call("[TEST:RUNTIME]", "In-Project Runtime Test Runner (#{runtime_scene.not_nil!.basename})", "Test")
          end
        end

        tui.try &.start

        begin
          # -----------------------------------------------------------------------
          # Phase 1: Crystal Unit Specs
          # -----------------------------------------------------------------------
          if is_root_engine
            unless skip_specs
              # Phase 1a: Engine & Core Bindings Specifications
              unless skip_engine_specs
                spec_dir = root.join("spec")
                if Dir.exists?(spec_dir)
                  phase_tag = "[TEST:SPECS:ENGINE]"
                  if idx = phase_map[phase_tag]?
                    tui.try &.begin_phase(idx)
                  end
                  Core::Logger.step("Test:Specs:Engine", "Running Phase 1a: Engine specifications in spec...") unless tui
                  step_start = Time.instant
                  spec_junit_dir = test_bin_dir.join("junit_engine_specs")
                  res = Core::ProcessRunner.run_with_capture(
                    "crystal",
                    ["spec", "spec", "--junit_output=#{spec_junit_dir.to_s.gsub('\\', '/')}"],
                    chdir: root.to_s,
                    passthrough: tui.nil?,
                    on_line: tui ? ->(l : String) { tui.not_nil!.handle_stream_line(l) } : nil
                  )
                  step_dur = (Time.instant - step_start).total_seconds.round(2)
                  if idx = phase_map[phase_tag]?
                    tui.try &.finish_phase(idx, res[:status].success?, step_dur, safe_exit_code(res[:status]), res[:error_excerpt])
                  end
                  step_summary.add_phase(
                    tag: phase_tag,
                    name: "Engine Specifications (spec)",
                    category: "Spec",
                    success: res[:status].success?,
                    duration: step_dur,
                    exit_code: safe_exit_code(res[:status]),
                    error_excerpt: res[:error_excerpt]
                  )
                end
              end

              return 1 if tui.try &.aborted?

              # Phase 1b: Lapis Toolchain & CLI Specifications
              unless skip_cli_specs
                lapis_spec_dir = root.join("tools/lapis/spec")
                if Dir.exists?(lapis_spec_dir)
                  phase_tag = "[TEST:SPECS:CLI]"
                  if idx = phase_map[phase_tag]?
                    tui.try &.begin_phase(idx)
                  end
                  Core::Logger.step("Test:Specs:CLI", "Running Phase 1b: Lapis toolchain specifications in tools/lapis/spec...") unless tui
                  step_start = Time.instant
                  cli_junit_dir = test_bin_dir.join("junit_cli_specs")
                  res = Core::ProcessRunner.run_with_capture(
                    "crystal",
                    ["spec", "tools/lapis/spec", "--junit_output=#{cli_junit_dir.to_s.gsub('\\', '/')}"],
                    chdir: root.to_s,
                    passthrough: tui.nil?,
                    on_line: tui ? ->(l : String) { tui.not_nil!.handle_stream_line(l) } : nil
                  )
                  step_dur = (Time.instant - step_start).total_seconds.round(2)
                  if idx = phase_map[phase_tag]?
                    tui.try &.finish_phase(idx, res[:status].success?, step_dur, safe_exit_code(res[:status]), res[:error_excerpt])
                  end
                  step_summary.add_phase(
                    tag: phase_tag,
                    name: "Lapis CLI Specifications (tools/lapis/spec)",
                    category: "Spec",
                    success: res[:status].success?,
                    duration: step_dur,
                    exit_code: safe_exit_code(res[:status]),
                    error_excerpt: res[:error_excerpt]
                  )
                end
              end

              return 1 if tui.try &.aborted?

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
                "spec/lsp_spec.cr",
                "spec/crystal_language_spec.cr",
                "spec/platform_isolation_spec.cr",
                "spec/safety_and_bindings_spec.cr",
                "spec/features_spec.cr",
              ]

              phase_tag = "[TEST:SPECS:ROOT]"
              if idx = phase_map[phase_tag]?
                tui.try &.begin_phase(idx)
              end

              root_specs_success = true
              root_specs_dur = 0.0

              root_specs.each do |spec_file|
                return 1 if tui.try &.aborted?
                full_path = root.join(spec_file)
                if File.exists?(full_path)
                  spec_tag_name = Path.new(spec_file).basename.gsub(".cr", "").upcase
                  Core::Logger.step("Test:Specs:Root", "Running #{spec_file}...") unless tui
                  step_start = Time.instant
                  res = Core::ProcessRunner.run_with_capture(
                    "crystal",
                    ["run", spec_file],
                    chdir: root.to_s,
                    passthrough: tui.nil?,
                    on_line: tui ? ->(l : String) { tui.not_nil!.handle_stream_line(l) } : nil
                  )
                  {% if flag?(:windows) %}
                    if !res[:status].success?
                      sleep 0.5.seconds
                      res = Core::ProcessRunner.run_with_capture(
                        "crystal",
                        ["run", spec_file],
                        chdir: root.to_s,
                        passthrough: tui.nil?,
                        on_line: tui ? ->(l : String) { tui.not_nil!.handle_stream_line(l) } : nil
                      )
                    end
                  {% end %}
                  step_dur = (Time.instant - step_start).total_seconds.round(2)
                  root_specs_dur += step_dur
                  root_specs_success &&= res[:status].success?

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

              if idx = phase_map[phase_tag]?
                tui.try &.finish_phase(idx, root_specs_success, root_specs_dur.round(2), root_specs_success ? 0 : 1)
              end

              return 1 if tui.try &.aborted?

              # Phase 1d: Debugger & Crash Handler Specifications
              debugger_specs = [
                "spec/crash_handler_spec.cr",
                "spec/lldb_driver_spec.cr",
                "spec/debugger_breakpoints_spec.cr",
                "spec/lldb_integration_spec.cr",
              ]
              active_dbg_specs = debugger_specs.select { |f| File.exists?(root.join(f)) }
              if active_dbg_specs.any?
                phase_tag = "[TEST:SPECS:DEBUGGER]"
                if idx = phase_map[phase_tag]?
                  tui.try &.begin_phase(idx)
                end
                Core::Logger.step("Test:Specs:Debugger", "Running Phase 1d: Debugger and crash handler specifications...") unless tui
                step_start = Time.instant
                res = Core::ProcessRunner.run_with_capture(
                  "crystal",
                  ["spec"] + active_dbg_specs,
                  chdir: root.to_s,
                  passthrough: tui.nil?,
                  on_line: tui ? ->(l : String) { tui.not_nil!.handle_stream_line(l) } : nil
                )
                step_dur = (Time.instant - step_start).total_seconds.round(2)
                if idx = phase_map[phase_tag]?
                  tui.try &.finish_phase(idx, res[:status].success?, step_dur, safe_exit_code(res[:status]), res[:error_excerpt])
                end
                step_summary.add_phase(
                  tag: phase_tag,
                  name: "Debugger & Crash Handler Specifications",
                  category: "Spec",
                  success: res[:status].success?,
                  duration: step_dur,
                  exit_code: safe_exit_code(res[:status]),
                  error_excerpt: res[:error_excerpt]
                )
              end
            end
          else
            # Consumer Project Specifications (e.g. template, template-addon, examples)
            if has_project_specs
              phase_tag = "[TEST:SPECS]"
              if idx = phase_map[phase_tag]?
                tui.try &.begin_phase(idx)
              end
              Core::Logger.step("Test:Specs", "Running project specifications in #{target_dir.basename}/spec...") unless tui
              step_start = Time.instant
              spec_junit_dir = test_bin_dir.join("junit_specs")
              isolated_cache = test_bin_dir.join(".crystal_cache")
              # Ensure dependencies for consumer project if shard.yml exists
              if File.exists?(target_dir.join("shard.yml")) && !Dir.exists?(target_dir.join("lib/lapis"))
                if shards_exe = Core::ProcessRunner.find_executable("shards")
                  Core::Logger.step("Shards", "Installing dependencies for #{target_dir.basename}...") unless tui
                  Core::ProcessRunner.run(shards_exe, ["install"], chdir: target_dir.to_s)
                  lib_gd = target_dir.join("lib/.gdignore")
                  File.write(lib_gd, "") if Dir.exists?(target_dir.join("lib")) && !File.exists?(lib_gd)
                end
              end

              # Build environment with augmented CRYSTAL_PATH
              spec_env = {"CRYSTAL_CACHE_DIR" => isolated_cache.to_s}
              sys_path = Core::ProcessRunner.capture("crystal", ["env", "CRYSTAL_PATH"])[:output].strip rescue ""
              sep = Core::Env.windows? ? ";" : ":"
              augmented_paths = [
                target_dir.join("lib").to_s,
                root.join("src").to_s,
                root.join("lib").to_s,
              ]
              augmented_paths << sys_path unless sys_path.empty?
              spec_env["CRYSTAL_PATH"] = augmented_paths.join(sep)

              res = Core::ProcessRunner.run_with_capture(
                "crystal",
                ["spec", "--junit_output=#{spec_junit_dir.to_s.gsub('\\', '/')}"],
                env: spec_env,
                chdir: target_dir.to_s,
                passthrough: tui.nil?,
                on_line: tui ? ->(l : String) { tui.not_nil!.handle_stream_line(l) } : nil
              )
              step_dur = (Time.instant - step_start).total_seconds.round(2)
              if idx = phase_map[phase_tag]?
                tui.try &.finish_phase(idx, res[:status].success?, step_dur, safe_exit_code(res[:status]), res[:error_excerpt])
              end
              step_summary.add_phase(
                tag: phase_tag,
                name: "Project Specifications (#{target_dir.basename})",
                category: "Spec",
                success: res[:status].success?,
                duration: step_dur,
                exit_code: safe_exit_code(res[:status]),
                error_excerpt: res[:error_excerpt]
              )
            end
          end

          return 1 if tui.try &.aborted?

          # -----------------------------------------------------------------------
          # Phase 2: In-Editor Tool Tests (Headless)
          # -----------------------------------------------------------------------
          if is_root_engine && !skip_tool_tests
            if godot_exe
              phase_tag = "[TEST:TOOL_NODES]"
              if idx = phase_map[phase_tag]?
                tui.try &.begin_phase(idx)
              end
              Core::Logger.step("Test:Editor", "Running In-Editor Tool Tests (Headless Phase 2a/2b)...") unless tui
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
                ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--editor", "--path", ".", "--fixed-fps", "60", "--quit-after", "3600"],
                env: env,
                chdir: root.to_s,
                passthrough: tui.nil?,
                on_line: tui ? ->(l : String) { tui.not_nil!.handle_stream_line(l) } : nil
              )
              step_dur = (Time.instant - step_start).total_seconds.round(2)

              failed_tool_marker = [test_dir.join(".tool_tests_failed"), test_bin_dir.join(".tool_tests_failed")].find { |f| File.exists?(f) }
              passed_tool_marker = [test_dir.join(".tool_tests_passed"), test_bin_dir.join(".tool_tests_passed")].find { |f| File.exists?(f) }

              editor_success = true
              tool_err : String? = nil
              if failed_tool_marker
                Core::Logger.error("In-editor @tool tests reported failures.") unless tui
                editor_success = false
                tool_err = File.read(failed_tool_marker) rescue "In-editor @tool test failure reported in marker."
              elsif !passed_tool_marker
                editor_success = false
                tool_err = res[:error_excerpt] || "In-editor tests exited without passing (marker not found)."
              else
                Core::Logger.success("In-editor @tool tests verified successfully!") unless tui
              end

              if idx = phase_map[phase_tag]?
                tui.try &.finish_phase(idx, editor_success, step_dur, safe_exit_code(res[:status]), tool_err)
              end

              step_summary.add_phase(
                tag: phase_tag,
                name: "Headless In-Editor @tool Tests (Phase 2a/2b)",
                category: "Test",
                success: editor_success,
                duration: step_dur,
                exit_code: safe_exit_code(res[:status]),
                error_excerpt: tool_err
              )
            else
              Core::Logger.warn("Godot executable not found, skipping in-editor tests.") unless tui
            end
          end

          return 1 if tui.try &.aborted?

          # -----------------------------------------------------------------------
          # Phase 3a: Standalone Test Runner (Regular with separate .pck & DLL/SO)
          # -----------------------------------------------------------------------
          unless skip_standalone
            if has_standalone
              phase_tag = "[TEST:STANDALONE]"
              if idx = phase_map[phase_tag]?
                tui.try &.begin_phase(idx)
              end
              File.chmod(standalone_exe.to_s, 0o755) unless Core::Env.windows?
              Core::Logger.step("Test:Standalone", "Running Standalone Test Runner (Regular with separate .pck & DLL/SO: #{standalone_exe.basename})...") unless tui
              clear_markers(test_dir, test_bin_dir)
              step_start = Time.instant
              res = begin
                Core::ProcessRunner.run_with_capture(
                  standalone_exe.to_s,
                  ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--quit-after", "600", "--", "--autorun"] + extra_runtime_args,
                  chdir: test_bin_dir.to_s,
                  passthrough: tui.nil?,
                  on_line: tui ? ->(l : String) { tui.not_nil!.handle_stream_line(l) } : nil
                )
              rescue ex
                Core::Logger.error("Failed to execute regular standalone runner: #{ex.message}") unless tui
                {status: Process::Status[1], error_excerpt: ex.message}
              end
              step_dur = (Time.instant - step_start).total_seconds.round(2)

              failed_marker = [test_dir.join(".runtime_tests_failed"), test_bin_dir.join(".runtime_tests_failed")].find { |f| File.exists?(f) }
              passed_marker = [test_dir.join(".runtime_tests_passed"), test_bin_dir.join(".runtime_tests_passed")].find { |f| File.exists?(f) }

              standalone_success = true
              standalone_err : String? = nil
              if failed_marker
                Core::Logger.error("Regular standalone test runner reported failures.") unless tui
                standalone_success = false
                standalone_err = File.read(failed_marker) rescue "Runtime assertion failures reported."
              elsif !passed_marker
                standalone_success = false
                standalone_err = res[:error_excerpt] || "Standalone test runner exited without passing (marker not found)."
              else
                Core::Logger.success("Regular standalone test runner verified successfully!") unless tui
              end

              if idx = phase_map[phase_tag]?
                tui.try &.finish_phase(idx, standalone_success, step_dur, safe_exit_code(res[:status]), standalone_err)
              end

              step_summary.add_phase(
                tag: phase_tag,
                name: "Regular Standalone Test Runner (#{standalone_exe.basename})",
                category: "Test",
                success: standalone_success,
                duration: step_dur,
                exit_code: safe_exit_code(res[:status]),
                error_excerpt: standalone_err
              )
            end

            return 1 if tui.try &.aborted?

            # -----------------------------------------------------------------------
            # Phase 3b: Standalone Portable Test Runner (Embedded PCK in isolated sandbox)
            # -----------------------------------------------------------------------
            if is_root_engine && !File.exists?(portable_exe) && File.exists?(standalone_exe) && File.exists?(pck_file)
              Package.embed_pck_in_executable(standalone_exe, pck_file, portable_exe)
            end

            if is_root_engine && File.exists?(portable_exe)
              phase_tag = "[TEST:PORTABLE]"
              if idx = phase_map[phase_tag]?
                tui.try &.begin_phase(idx)
              end
              Core::Logger.step("Test:Portable", "Running Standalone Portable Test Runner (Isolated Embedded PCK without external .pck: #{portable_exe.basename})...") unless tui

              sandbox_dir = root.join("scratch/test_portable_sandbox")
              FileUtils.rm_rf(sandbox_dir) if Dir.exists?(sandbox_dir)
              FileUtils.mkdir_p(sandbox_dir)

              sandbox_exe = sandbox_dir.join("tests_portable#{Core::Env.exe_ext}")
              FileUtils.cp(portable_exe.to_s, sandbox_exe.to_s)
              File.chmod(sandbox_exe.to_s, 0o755) unless Core::Env.windows?

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
                  ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--quit-after", "600", "--", "--autorun"] + extra_runtime_args,
                  chdir: sandbox_dir.to_s,
                  passthrough: tui.nil?,
                  on_line: tui ? ->(l : String) { tui.not_nil!.handle_stream_line(l) } : nil
                )
              rescue ex
                Core::Logger.error("Failed to execute portable runner: #{ex.message}") unless tui
                {status: Process::Status[1], error_excerpt: ex.message}
              end
              step_dur = (Time.instant - step_start).total_seconds.round(2)

              failed_marker = [test_dir.join(".runtime_tests_failed"), sandbox_dir.join(".runtime_tests_failed")].find { |f| File.exists?(f) }
              passed_marker = [test_dir.join(".runtime_tests_passed"), sandbox_dir.join(".runtime_tests_passed")].find { |f| File.exists?(f) }

              portable_success = true
              portable_err : String? = nil
              if failed_marker
                Core::Logger.error("Standalone portable test runner reported failures in isolated sandbox.") unless tui
                portable_success = false
                portable_err = File.read(failed_marker) rescue "Runtime assertion failures reported."
              elsif !passed_marker
                portable_success = false
                portable_err = res[:error_excerpt] || "Portable runner exited without passing (marker not found)."
              else
                Core::Logger.success("Standalone portable test runner verified successfully in isolated sandbox!") unless tui
              end

              if idx = phase_map[phase_tag]?
                tui.try &.finish_phase(idx, portable_success, step_dur, safe_exit_code(res[:status]), portable_err)
              end

              step_summary.add_phase(
                tag: phase_tag,
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

          return 1 if tui.try &.aborted?

          # -----------------------------------------------------------------------
          # Phase 4: Runtime Test Project (via Godot CLI)
          # -----------------------------------------------------------------------
          unless skip_runtime_tests
            if godot_exe && (is_root_engine || has_runtime_test_scene)
              runtime_name = is_root_engine ? "In-Project Runtime Test Runner (main_test_runner.tscn)" : "In-Project Runtime Test Runner (#{runtime_scene.not_nil!.basename})"
              phase_tag = "[TEST:RUNTIME]"
              if idx = phase_map[phase_tag]?
                tui.try &.begin_phase(idx)
              end
              Core::Logger.step("Test:Runtime", "Running #{runtime_name}...") unless tui
              step_start = Time.instant
              cmd_args = ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--path", "."]
              cmd_args << runtime_scene.not_nil!.to_s unless is_root_engine
              cmd_args += ["--quit-after", "600", "--", "--autorun"] + extra_runtime_args

              res = begin
                Core::ProcessRunner.run_with_capture(
                  godot_exe,
                  cmd_args,
                  chdir: test_dir.to_s,
                  passthrough: tui.nil?,
                  on_line: tui ? ->(l : String) { tui.not_nil!.handle_stream_line(l) } : nil
                )
              rescue ex
                Core::Logger.error("Failed to execute runtime runner: #{ex.message}") unless tui
                {status: Process::Status[1], error_excerpt: ex.message}
              end
              step_dur = (Time.instant - step_start).total_seconds.round(2)

              failed_marker = [test_dir.join(".runtime_tests_failed"), test_bin_dir.join(".runtime_tests_failed")].find { |f| File.exists?(f) }
              passed_marker = [test_dir.join(".runtime_tests_passed"), test_bin_dir.join(".runtime_tests_passed")].find { |f| File.exists?(f) }

              runtime_success = true
              runtime_err : String? = nil
              if failed_marker
                Core::Logger.error("Runtime test runner reported failures.") unless tui
                runtime_success = false
                runtime_err = File.read(failed_marker) rescue "Runtime assertion failures reported."
              elsif !passed_marker
                runtime_success = false
                runtime_err = res[:error_excerpt] || "Runtime project exited without passing (marker not found)."
              else
                Core::Logger.success("Runtime test suite verified successfully!") unless tui
              end

              if idx = phase_map[phase_tag]?
                tui.try &.finish_phase(idx, runtime_success, step_dur, safe_exit_code(res[:status]), runtime_err)
              end

              step_summary.add_phase(
                tag: phase_tag,
                name: runtime_name,
                category: "Test",
                success: runtime_success,
                duration: step_dur,
                exit_code: safe_exit_code(res[:status]),
                error_excerpt: runtime_err
              )
            else
              if !is_root_engine && !has_runtime_test_scene
                # Consumer project does not define a runtime test scene; skipping quietly
              elsif !godot_exe
                Core::Logger.warn("Godot executable not found, skipping runtime tests.") unless tui
              end
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

          # Harvest JUnit XML test reports if available
          junit_candidates = if is_root_engine
                               [
                                 junit_path,
                                 test_bin_dir.join("junit.xml").to_s,
                                 test_dir.join("junit.xml").to_s,
                                 root.join("junit.xml").to_s,
                                 test_bin_dir.join("junit_tool_2d.xml").to_s,
                                 test_dir.join("junit_tool_2d.xml").to_s,
                                 test_bin_dir.join("junit_tool_3d.xml").to_s,
                                 test_dir.join("junit_tool_3d.xml").to_s,
                                 test_bin_dir.join("junit_engine_specs/output.xml").to_s,
                                 test_bin_dir.join("junit_cli_specs/output.xml").to_s,
                               ]
                             else
                               [
                                 junit_path,
                                 test_bin_dir.join("junit.xml").to_s,
                                 test_dir.join("junit.xml").to_s,
                               ]
                             end.compact.uniq

          junit_candidates.each do |j_cand|
            if File.exists?(j_cand) && File.size(j_cand) > 0
              step_summary.load_junit_report(j_cand)
              step_summary.add_artifact(Path.new(j_cand).basename, j_cand)
            end
          end

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
          if t = tui
            t.stop(step_summary.overall_success?)
            t.dump_results
          end
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
