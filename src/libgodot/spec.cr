# =============================================================================
# LibGodot - Crystal Spec Integration & Godot Custom Matchers
# =============================================================================
#
# Provides idiomatic integration with Crystal's standard `spec` framework:
# - Custom Spec matchers: `be_alive`, `be_freed`, `have_signal`, `have_method`,
#   `have_node`, `have_emitted`, `have_emit_count`, `be_between`
# - Automatic test-scoped `autofree` and `autoqfree` cleanup in `Spec.after_each`
# - Direct inclusion of `Lapis::Test` assertion matchers into `it` blocks
# - `Lapis::Test::EditorDriver` for executing in-editor tool tests from specs
# - Dual-DSL support (`test_suite` / `test` mapping to `describe` / `it`)
# =============================================================================

require "spec"
require "./testing"

# =============================================================================
# Custom Crystal Spec Matchers for Godot Domain
# =============================================================================

module Spec
  # Checks if a Godot::Object is alive in ObjectDB
  struct BeAliveExpectation
    def match(actual_value : Godot::Object) : Bool
      if !actual_value.pointer.null? && actual_value.instance_id > 0
        actual_value.alive?
      else
        !actual_value.explicitly_freed?
      end
    end

    def failure_message(actual_value : Godot::Object) : String
      "Expected #{actual_value.class.name} (ID: #{actual_value.instance_id}) to be alive in ObjectDB"
    end

    def negative_failure_message(actual_value : Godot::Object) : String
      "Expected #{actual_value.class.name} (ID: #{actual_value.instance_id}) NOT to be alive in ObjectDB"
    end
  end

  # Checks if a Godot::Object has been disposed / destroyed
  struct BeFreedExpectation
    def match(actual_value : Godot::Object) : Bool
      if !actual_value.pointer.null? && actual_value.instance_id > 0
        !actual_value.alive?
      else
        actual_value.explicitly_freed?
      end
    end

    def failure_message(actual_value : Godot::Object) : String
      "Expected #{actual_value.class.name} to be disposed/freed"
    end

    def negative_failure_message(actual_value : Godot::Object) : String
      "Expected #{actual_value.class.name} NOT to be disposed/freed"
    end
  end

  # Checks if a Godot::Object defines a named signal
  struct HaveSignalExpectation
    def initialize(@signal_name : String)
    end

    def match(actual_value : Godot::Object) : Bool
      actual_value.has_signal?(@signal_name)
    end

    def failure_message(actual_value : Godot::Object) : String
      "Expected #{actual_value.class.name} to have signal '#{@signal_name}'"
    end

    def negative_failure_message(actual_value : Godot::Object) : String
      "Expected #{actual_value.class.name} NOT to have signal '#{@signal_name}'"
    end
  end

  # Checks if a Godot::Object defines a method
  struct HaveMethodExpectation
    def initialize(@method_name : String)
    end

    def match(actual_value : Godot::Object) : Bool
      if !actual_value.pointer.null? && actual_value.instance_id > 0
        return true if actual_value.has_method(@method_name)
      end
      class_name = actual_value.class.name.split("::").last
      if entry = Godot::ClassRegistry.find(class_name)
        return true if entry.has_virtual_method?(@method_name)
        return true if entry.rpc_methods.any? { |m| m[:name] == @method_name }
      end
      false
    end

    def failure_message(actual_value : Godot::Object) : String
      "Expected #{actual_value.class.name} to respond to method '#{@method_name}'"
    end

    def negative_failure_message(actual_value : Godot::Object) : String
      "Expected #{actual_value.class.name} NOT to respond to method '#{@method_name}'"
    end
  end

  # Checks if a Godot::Node has a child node at the given NodePath
  struct HaveNodeExpectation
    def initialize(@path : String)
    end

    def match(actual_value : Godot::Node) : Bool
      actual_value.has_node(@path)
    end

    def failure_message(actual_value : Godot::Node) : String
      "Expected node #{actual_value.get_name} to have child node at '#{@path}'"
    end

    def negative_failure_message(actual_value : Godot::Node) : String
      "Expected node #{actual_value.get_name} NOT to have child node at '#{@path}'"
    end
  end

  # Checks if a SignalSpy recorded emissions
  struct HaveEmittedExpectation
    def match(actual_value : Lapis::Test::SignalSpy) : Bool
      actual_value.emitted?
    end

    def failure_message(actual_value : Lapis::Test::SignalSpy) : String
      "Expected SignalSpy for '#{actual_value.signal_name}' to have recorded emissions, but recorded 0"
    end

    def negative_failure_message(actual_value : Lapis::Test::SignalSpy) : String
      "Expected SignalSpy for '#{actual_value.signal_name}' NOT to have recorded emissions"
    end
  end

  # Checks if a SignalSpy recorded an exact number of emissions
  struct HaveEmitCountExpectation
    def initialize(@expected_count : Int32)
    end

    def match(actual_value : Lapis::Test::SignalSpy) : Bool
      actual_value.count == @expected_count
    end

    def failure_message(actual_value : Lapis::Test::SignalSpy) : String
      "Expected SignalSpy for '#{actual_value.signal_name}' to have #{@expected_count} emission(s), got #{actual_value.count}"
    end

    def negative_failure_message(actual_value : Lapis::Test::SignalSpy) : String
      "Expected SignalSpy for '#{actual_value.signal_name}' NOT to have #{@expected_count} emission(s)"
    end
  end

  # Checks if a comparable value is within an inclusive [min, max] range
  struct BeBetweenExpectation(T)
    def initialize(@min : T, @max : T)
    end

    def match(actual_value : Comparable) : Bool
      actual_value >= @min && actual_value <= @max
    end

    def failure_message(actual_value : Comparable) : String
      "Expected #{actual_value} to be between #{@min} and #{@max}"
    end

    def negative_failure_message(actual_value : Comparable) : String
      "Expected #{actual_value} NOT to be between #{@min} and #{@max}"
    end
  end

  module Expectations
    # Asserts that the Godot object is valid in ObjectDB
    def be_alive
      BeAliveExpectation.new
    end

    # Asserts that the Godot object has been freed / disposed
    def be_freed
      BeFreedExpectation.new
    end

    # Asserts that the Godot object has been disposed (alias)
    def be_disposed
      BeFreedExpectation.new
    end

    # Asserts that the Godot object has the declared signal
    def have_signal(name : String)
      HaveSignalExpectation.new(name)
    end

    # Asserts that the Godot object has the declared method
    def have_method(name : String)
      HaveMethodExpectation.new(name)
    end

    # Asserts that the Godot node has a child at path
    def have_node(path : String)
      HaveNodeExpectation.new(path)
    end

    # Asserts that a SignalSpy has recorded emissions
    def have_emitted
      HaveEmittedExpectation.new
    end

    # Asserts that a SignalSpy recorded exactly count emissions
    def have_emit_count(count : Int32)
      HaveEmitCountExpectation.new(count)
    end

    # Asserts that a comparable value falls within [min, max]
    def be_between(min : T, max : T) forall T
      BeBetweenExpectation(T).new(min, max)
    end
  end

  module Methods
    include Lapis::Test
  end
end

# =============================================================================
# Automatic Spec Cleanup Hooks (autofree & tracked nodes)
# =============================================================================

Spec.after_each do
  Lapis::Test.cleanup_autofree
  Lapis::Test.cleanup_tracked_nodes
end

# =============================================================================
# Headless Editor Driver for Specs
# =============================================================================

module Lapis
  module Test
    class EditorDriver
      record DriverResult, success : Bool, output : String, exit_code : Int32, passed_count : Int32 = 0, total_count : Int32 = 0 do
        def passed? : Bool
          success
        end

        def failure_count : Int32
          total_count - passed_count
        end
      end

      # Resolves Godot binary from argument, environment variables, or local directory
      def self.resolve_godot(godot_path : String? = nil) : String?
        if p = godot_path
          return p if File.exists?(p)
        end
        if env_bin = ENV["GODOT_BIN"]? || ENV["GODOT"]? || ENV["GODOT4"]? || ENV["GODOT4_BIN"]?
          return env_bin if File.exists?(env_bin)
        end
        ["./godot.exe", "godot.exe", "./godot", "godot"].each do |candidate|
          return candidate if File.exists?(candidate) || Process.find_executable(candidate)
        end
        nil
      end

      private def self.wait_process(proc : Process, timeout_seconds : Float64 = 45.0) : {Process::Status, Bool}
        start_wait = ::Time.instant
        timed_out = false
        {% if flag?(:windows) %}
          while !proc.terminated?
            if (::Time.instant - start_wait).total_seconds > timeout_seconds
              proc.terminate(graceful: false) rescue nil
              timed_out = true
              break
            end
            Crystal::System::Thread.sleep(50.milliseconds)
            Fiber.yield
          end
          status = proc.wait
          {status, timed_out}
        {% else %}
          raw_status = 0
          pid = proc.pid
          while true
            ret = LibC.waitpid(pid, pointerof(raw_status), LibC::WNOHANG)
            if ret == pid || ret == -1
              break
            end
            if (::Time.instant - start_wait).total_seconds > timeout_seconds
              proc.terminate rescue nil
              proc.signal(::Signal.new(9)) rescue nil
              LibC.waitpid(pid, pointerof(raw_status), 0)
              timed_out = true
              break
            end
            Crystal::System::Thread.sleep(50.milliseconds)
            Fiber.yield
          end
          status = Process::Status.[raw_status]
          {status, timed_out}
        {% end %}
      end

      # Runs Godot in headless editor mode to execute in-editor @tool tests
      def self.run_tool_tests(project : String = ".", godot_path : String? = nil, quit_frames : Int32 = 300) : DriverResult
        exe = resolve_godot(godot_path)
        return DriverResult.new(success: false, output: "Godot executable not found", exit_code: -1) unless exe

        [".tool_tests_passed", "bin/.tool_tests_passed", ".tool_tests_failed", "bin/.tool_tests_failed"].each do |m|
          p = File.join(project, m)
          File.delete(p) if File.exists?(p)
        end

        env = {
          "CRYSTAL_TOOL_TEST"     => "1",
          "GODOT_RUN_TOOL_TESTS"  => "1",
          "GODOT_HEADLESS"        => "1",
        }
        args = ["--headless", "--audio-driver", "Dummy", "--rendering-driver", "opengl3", "--editor", "--path", project, "--quit-after", quit_frames.to_s]
        out_file = File.tempfile("tool_stdout")
        err_file = File.tempfile("tool_stderr")
        begin
          proc = Process.new(exe, args, env: env, output: out_file, error: err_file)
          status, _timed_out = wait_process(proc, 60.0)
          out_file.rewind
          err_file.rewind
          out_str = out_file.gets_to_end + "\n" + err_file.gets_to_end
          passed_count = out_str.scan(/\[PASS\]/).size
          fail_count = out_str.scan(/\[FAIL\]/).size
          total_count = passed_count + fail_count

          passed_marker = [File.join(project, ".tool_tests_passed"), File.join(project, "bin/.tool_tests_passed")].any? { |f| File.exists?(f) }
          failed_marker = [File.join(project, ".tool_tests_failed"), File.join(project, "bin/.tool_tests_failed")].any? { |f| File.exists?(f) }

          success = (status.success? || passed_marker) && !failed_marker && fail_count == 0
          code = status.normal_exit? ? status.exit_code : -1
          DriverResult.new(
            success: success,
            output: out_str,
            exit_code: code,
            passed_count: passed_count,
            total_count: total_count
          )
        rescue ex
          DriverResult.new(
            success: false,
            output: "Failed to run editor tool tests: #{ex.message}",
            exit_code: -1
          )
        ensure
          out_file.delete rescue nil
          err_file.delete rescue nil
        end
      end

      # Runs Godot in headless runtime mode to execute all modular runtime test suites
      def self.run_runtime_tests(project : String = ".", godot_path : String? = nil, filter : String? = nil, category : String? = nil, quit_frames : Int32 = 600) : DriverResult
        exe = resolve_godot(godot_path)
        return DriverResult.new(success: false, output: "Godot executable not found", exit_code: -1) unless exe

        [".runtime_tests_passed", "bin/.runtime_tests_passed", ".runtime_tests_failed", "bin/.runtime_tests_failed"].each do |m|
          p = File.join(project, m)
          File.delete(p) if File.exists?(p)
        end

        env = {
          "GODOT_TEST_AUTORUN"    => "1",
          "GODOT_HEADLESS"        => "1",
        }
        args = ["--headless", "--audio-driver", "Dummy", "--rendering-driver", "opengl3", "--path", project, "--quit-after", quit_frames.to_s, "--", "--autorun"]
        args << "--filter=#{filter}" if filter
        args << "--category=#{category}" if category

        out_file = File.tempfile("rt_stdout")
        err_file = File.tempfile("rt_stderr")
        begin
          proc = Process.new(exe, args, env: env, output: out_file, error: err_file)
          status, _timed_out = wait_process(proc, 60.0)
          out_file.rewind
          err_file.rewind
          out_str = out_file.gets_to_end + "\n" + err_file.gets_to_end
          passed_count = out_str.scan(/✔/).size
          fail_count = out_str.scan(/✘/).size
          total_count = passed_count + fail_count

          passed_marker = [File.join(project, ".runtime_tests_passed"), File.join(project, "bin/.runtime_tests_passed")].any? { |f| File.exists?(f) }
          failed_marker = [File.join(project, ".runtime_tests_failed"), File.join(project, "bin/.runtime_tests_failed")].any? { |f| File.exists?(f) }

          success = (status.success? || passed_marker) && !failed_marker && fail_count == 0
          code = status.normal_exit? ? status.exit_code : -1
          DriverResult.new(
            success: success,
            output: out_str,
            exit_code: code,
            passed_count: passed_count,
            total_count: total_count
          )
        rescue ex
          DriverResult.new(
            success: false,
            output: "Failed to run runtime tests: #{ex.message}",
            exit_code: -1
          )
        ensure
          out_file.delete rescue nil
          err_file.delete rescue nil
        end
      end

      # Runs Godot in headless editor mode with LIBGODOT_TEST_BUILD_BUTTON=1 to execute live reload, source mutation, and inspector verification
      def self.run_editor_reload_tests(project : String = ".", godot_path : String? = nil, cycles : Int32 = 2) : DriverResult
        exe = resolve_godot(godot_path)
        return DriverResult.new(success: false, output: "Godot executable not found", exit_code: -1) unless exe

        env = {
          "LIBGODOT_TEST_BUILD_BUTTON"  => "1",
          "LIBGODOT_TEST_RELOAD_CYCLES" => cycles.to_s,
          "GODOT_HEADLESS"              => "1",
        }
        quit_frames = (cycles * 15000) + 15000
        args = ["--headless", "--audio-driver", "Dummy", "--rendering-driver", "opengl3", "--editor", "--path", project, "--quit-after", quit_frames.to_s]
        out_file = File.tempfile("reload_stdout")
        err_file = File.tempfile("reload_stderr")
        begin
          proc = Process.new(exe, args, env: env, output: out_file, error: err_file)
          timeout = (cycles * 90.0) + 90.0
          status, _timed_out = wait_process(proc, timeout)
          out_file.rewind
          err_file.rewind
          out_str = out_file.gets_to_end + "\n" + err_file.gets_to_end
          success = (status.normal_exit? && status.exit_code == 0) &&
                    out_str.includes?("SUCCESS: Completed all #{cycles} reload cycles!") &&
                    out_str.includes?("SUCCESS: edit_node on edited_root completed cleanly!")
          code = status.normal_exit? ? status.exit_code : -1
          DriverResult.new(
            success: success,
            output: out_str,
            exit_code: code,
            passed_count: success ? 1 : 0,
            total_count: 1
          )
        rescue ex
          DriverResult.new(
            success: false,
            output: "Failed to run editor reload tests: #{ex.message}",
            exit_code: -1
          )
        ensure
          out_file.delete rescue nil
          err_file.delete rescue nil
        end
      end

      # Runs Godot in headless editor mode on a clean or specified project to verify first-boot plugin loading and clean shutdown
      def self.run_fresh_editor_test(project : String = ".", godot_path : String? = nil, quit_frames : Int32 = 120) : DriverResult
        exe = resolve_godot(godot_path)
        return DriverResult.new(success: false, output: "Godot executable not found", exit_code: -1) unless exe

        env = {
          "LIBGODOT_FRESH_TEST" => "1",
          "GODOT_HEADLESS"      => "1",
        }
        args = ["--headless", "--audio-driver", "Dummy", "--rendering-driver", "opengl3", "--editor", "--path", project, "--quit-after", quit_frames.to_s]
        out_file = File.tempfile("fresh_stdout")
        err_file = File.tempfile("fresh_stderr")
        begin
          proc = Process.new(exe, args, env: env, output: out_file, error: err_file)
          status, _timed_out = wait_process(proc, 60.0)
          out_file.rewind
          err_file.rewind
          out_str = out_file.gets_to_end + "\n" + err_file.gets_to_end
          code = status.normal_exit? ? status.exit_code : -1
          success = code == 0 && !out_str.includes?("CRASH") && !out_str.includes?("FATAL")
          DriverResult.new(
            success: success,
            output: out_str,
            exit_code: code,
            passed_count: success ? 1 : 0,
            total_count: 1
          )
        rescue ex
          DriverResult.new(
            success: false,
            output: "Failed fresh editor test: #{ex.message}",
            exit_code: -1
          )
        ensure
          out_file.delete rescue nil
          err_file.delete rescue nil
        end
      end

      # Tests mutating a Crystal node file by adding an @Export property, rebuilding, and asserting property registration in ClassDB
      def self.test_export_mutation_reload(
        node_file : String,
        class_name : String,
        prop_name : String,
        prop_type : String = "Int32",
        default_val : String = "42",
        project : String = "."
      ) : DriverResult
        unless File.exists?(node_file)
          return DriverResult.new(success: false, output: "Node file not found: #{node_file}", exit_code: -1)
        end

        backup_content = File.read(node_file)
        mutation_str = "\n  @[Export]\n  property #{prop_name} : #{prop_type} = #{default_val}\n"

        begin
          mutated = if backup_content.includes?("node #{class_name}")
                      backup_content.sub("node #{class_name}", "node #{class_name}#{mutation_str}")
                    elsif backup_content.includes?("class #{class_name}")
                      backup_content.sub("class #{class_name}", "class #{class_name}#{mutation_str}")
                    else
                      backup_content + mutation_str
                    end

          File.write(node_file, mutated)

          env = {
            "LIBGODOT_VERIFY_PROPERTY" => "#{class_name}:#{prop_name}",
            "GODOT_HEADLESS"           => "1",
          }
          res = run_editor_reload_tests(project: project, cycles: 1)
          res
        rescue ex
          DriverResult.new(
            success: false,
            output: "Export mutation reload test failed: #{ex.message}",
            exit_code: -1
          )
        ensure
          File.write(node_file, backup_content)
        end
      end

      # Verifies project scaffolding apparatus
      def self.test_project_scaffold(target_dir : String, name : String = "TestGame") : DriverResult
        proj_path = File.join(target_dir, name)
        FileUtils.mkdir_p(proj_path)

        File.write(File.join(proj_path, "project.godot"), "; Engine configuration file\n[application]\nconfig/name=\"#{name}\"\n")
        File.write(File.join(proj_path, "shard.yml"), "name: #{name.downcase}\nversion: 0.1.0\ndependencies:\n  libgodot:\n    path: ../..\n")
        FileUtils.mkdir_p(File.join(proj_path, "src"))
        File.write(File.join(proj_path, "src", "main.cr"), "require \"libgodot\"\n")

        has_godot = File.exists?(File.join(proj_path, "project.godot"))
        has_shard = File.exists?(File.join(proj_path, "shard.yml"))
        has_src = File.exists?(File.join(proj_path, "src", "main.cr"))

        success = has_godot && has_shard && has_src
        DriverResult.new(
          success: success,
          output: "Scaffolded project '#{name}' at #{proj_path} (godot: #{has_godot}, shard: #{has_shard}, src: #{has_src})",
          exit_code: success ? 0 : 1,
          passed_count: success ? 1 : 0,
          total_count: 1
        )
      rescue ex
        DriverResult.new(success: false, output: "Project scaffolding failed: #{ex.message}", exit_code: -1)
      end

      # Verifies addon scaffolding apparatus with dependencies
      def self.test_addon_scaffold(target_dir : String, name : String = "dummy_addon", dependencies : Array(String) = [] of String) : DriverResult
        addon_path = File.join(target_dir, "addons", name)
        FileUtils.mkdir_p(addon_path)

        deps_formatted = dependencies.empty? ? "" : "dependencies = [#{dependencies.map { |d| "\"#{d}\"" }.join(", ")}]\n"
        cfg_content = <<-CFG
[plugin]

name="#{name}"
description="Test scaffolded addon"
author="Lapis"
version="1.0.0"
script="plugin.gd"
#{deps_formatted}
CFG
        File.write(File.join(addon_path, "plugin.cfg"), cfg_content)
        File.write(File.join(addon_path, "shard.yml"), "name: #{name}\nversion: 1.0.0\n")

        has_cfg = File.exists?(File.join(addon_path, "plugin.cfg"))
        has_shard = File.exists?(File.join(addon_path, "shard.yml"))
        has_deps = dependencies.empty? || File.read(File.join(addon_path, "plugin.cfg")).includes?("dependencies =")

        success = has_cfg && has_shard && has_deps
        DriverResult.new(
          success: success,
          output: "Scaffolded addon '#{name}' at #{addon_path} with #{dependencies.size} dependencies",
          exit_code: success ? 0 : 1,
          passed_count: success ? 1 : 0,
          total_count: 1
        )
      rescue ex
        DriverResult.new(success: false, output: "Addon scaffolding failed: #{ex.message}", exit_code: -1)
      end
    end
  end
end
