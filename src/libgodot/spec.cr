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
          success && exit_code == 0
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
        if env_bin = ENV["GODOT_BIN"]? || ENV["GODOT"]?
          return env_bin if File.exists?(env_bin)
        end
        ["./godot.exe", "godot.exe", "./godot", "godot"].each do |candidate|
          return candidate if File.exists?(candidate) || Process.find_executable(candidate)
        end
        nil
      end

      # Runs Godot in headless editor mode to execute in-editor @tool tests
      def self.run_tool_tests(project : String = ".", godot_path : String? = nil, quit_frames : Int32 = 20) : DriverResult
        exe = resolve_godot(godot_path)
        return DriverResult.new(success: false, output: "Godot executable not found", exit_code: -1) unless exe

        env = {
          "CRYSTAL_TOOL_TEST"     => "1",
          "GODOT_RUN_TOOL_TESTS"  => "1",
          "GODOT_HEADLESS"        => "1",
          "LIBGL_ALWAYS_SOFTWARE" => "1",
        }
        args = ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--editor", "--path", project, "--quit-after", quit_frames.to_s]
        stdout = IO::Memory.new
        stderr = IO::Memory.new
        begin
          status = Process.run(exe, args, env: env, output: stdout, error: stderr)
          out_str = stdout.to_s + "\n" + stderr.to_s
          passed_count = out_str.scan(/\[PASS\]/).size
          fail_count = out_str.scan(/\[FAIL\]/).size
          total_count = passed_count + fail_count

          passed_marker = [File.join(project, ".tool_tests_passed"), File.join(project, "bin/.tool_tests_passed")].any? { |f| File.exists?(f) }
          failed_marker = [File.join(project, ".tool_tests_failed"), File.join(project, "bin/.tool_tests_failed")].any? { |f| File.exists?(f) }

          success = (status.success? || passed_marker) && !failed_marker && fail_count == 0
          DriverResult.new(
            success: success,
            output: out_str,
            exit_code: status.exit_code,
            passed_count: passed_count,
            total_count: total_count
          )
        rescue ex
          DriverResult.new(
            success: false,
            output: "Failed to run editor tool tests: #{ex.message}",
            exit_code: -1
          )
        end
      end

      # Runs Godot in headless runtime mode to execute all modular runtime test suites
      def self.run_runtime_tests(project : String = ".", godot_path : String? = nil, filter : String? = nil, category : String? = nil, quit_frames : Int32 = 600) : DriverResult
        exe = resolve_godot(godot_path)
        return DriverResult.new(success: false, output: "Godot executable not found", exit_code: -1) unless exe

        env = {
          "GODOT_TEST_AUTORUN"    => "1",
          "GODOT_HEADLESS"        => "1",
          "LIBGL_ALWAYS_SOFTWARE" => "1",
        }
        args = ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--path", project, "--quit-after", quit_frames.to_s, "--", "--autorun"]
        args << "--filter=#{filter}" if filter
        args << "--category=#{category}" if category

        stdout = IO::Memory.new
        stderr = IO::Memory.new
        begin
          status = Process.run(exe, args, env: env, output: stdout, error: stderr)
          out_str = stdout.to_s + "\n" + stderr.to_s
          passed_count = out_str.scan(/✔/).size
          fail_count = out_str.scan(/✘/).size
          total_count = passed_count + fail_count

          passed_marker = [File.join(project, ".runtime_tests_passed"), File.join(project, "bin/.runtime_tests_passed")].any? { |f| File.exists?(f) }
          failed_marker = [File.join(project, ".runtime_tests_failed"), File.join(project, "bin/.runtime_tests_failed")].any? { |f| File.exists?(f) }

          success = (status.success? || passed_marker) && !failed_marker && fail_count == 0
          DriverResult.new(
            success: success,
            output: out_str,
            exit_code: status.exit_code,
            passed_count: passed_count,
            total_count: total_count
          )
        rescue ex
          DriverResult.new(
            success: false,
            output: "Failed to run runtime tests: #{ex.message}",
            exit_code: -1
          )
        end
      end
    end
  end
end
