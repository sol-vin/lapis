# =============================================================================
# LibGodot - Reusable Testing Apparatus & Extended Assertion Framework
# =============================================================================
#
# Provides an extensible, full-featured testing framework for Crystal in Godot:
# - Extended assertions (comparisons, strings, collections, filesystem, signals)
# - Source location tracking (__FILE__, __LINE__)
# - Godot domain assertions (alive, disposed, refcount, instance IDs, vector math)
# - Quantitative zero-leak & orphan node verification
# - Automatic node cleanup (autofree, autoqfree, add_child_autofree)
# - Deterministic node simulation (simulate _process and _physics_process)
# - Input simulation (InputFactory & sequenced InputSender)
# - Async frame-stepping & signal awaiting with timeouts
# - Lifecycle hooks (before_all, after_all, before_each, after_each)
# - Parameterized tests, pending tests & conditional skips
# - Standard JUnit XML export (reports/junit.xml)
# - Dual-DSL compatibility (describe/it <-> test_suite/test)
# =============================================================================

module Lapis
  module Test
    extend self

    # Base exception raised on assertion failures
    class AssertionError < Exception
      getter file : String
      getter line : Int32

      def initialize(message : String, @file : String = "", @line : Int32 = 0)
        full_msg = if !@file.empty? && @line > 0
                     "#{message} (at #{@file}:#{@line})"
                   else
                     message
                   end
        super(full_msg)
      end
    end

    # Exception raised when an asynchronous operation or signal await exceeds its timeout deadline
    class TimeoutError < AssertionError
    end

    # Exception raised when a test is deliberately skipped
    class SkipTestException < Exception
    end

    # Exception raised when a test is pending implementation
    class PendingTestException < Exception
    end

    # Encapsulates the execution result of a single registered test case
    record TestResult, category : String, name : String, passed : Bool, message : String = "", duration_ms : Float64 = 0.0, status : String = "PASS" do
      def pass? : Bool
        @status == "PASS" || (@passed && @status != "FAIL")
      end

      def fail? : Bool
        !pass? && !pending? && !skipped?
      end

      def pending? : Bool
        @status == "PENDING"
      end

      def skipped? : Bool
        @status == "SKIPPED"
      end
    end

    # Marks the currently running test as pending implementation
    def pending(reason : String = "Test pending implementation") : Nil
      raise PendingTestException.new(reason)
    end

    # Conditionally skips the currently running test if condition evaluates to true
    def skip_if(condition : Bool, reason : String = "Test skipped") : Nil
      raise SkipTestException.new(reason) if condition
    end

    # ===========================================================================
    # 1. Assertion Matchers (with Source Location Tracking)
    # ===========================================================================

    # Asserts that the boolean condition evaluates to true
    def assert_true(cond : Bool, msg : String = "Expected true, got false", file : String = __FILE__, line : Int32 = __LINE__)
      raise AssertionError.new(msg, file, line) unless cond
    end

    # Asserts that the boolean condition evaluates to false
    def assert_false(cond : Bool, msg : String = "Expected false, got true", file : String = __FILE__, line : Int32 = __LINE__)
      raise AssertionError.new(msg, file, line) if cond
    end

    # Asserts that two values are equal using Crystal's == operator
    def assert_eq(actual, expected, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      if actual != expected
        detail = msg.empty? ? "Expected #{expected.inspect}, got #{actual.inspect}" : "#{msg} (Expected #{expected.inspect}, got #{actual.inspect})"
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that two values are not equal using Crystal's != operator
    def assert_ne(actual, expected, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      if actual == expected
        detail = msg.empty? ? "Expected actual not to equal #{expected.inspect}, but got equal values" : "#{msg} (Expected not #{expected.inspect})"
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that actual > expected
    def assert_gt(actual : Comparable, expected : Comparable, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      unless actual > expected
        detail = msg.empty? ? "Expected #{actual} > #{expected}" : "#{msg} (Expected #{actual} > #{expected})"
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that actual >= expected
    def assert_gte(actual : Comparable, expected : Comparable, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      unless actual >= expected
        detail = msg.empty? ? "Expected #{actual} >= #{expected}" : "#{msg} (Expected #{actual} >= #{expected})"
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that actual < expected
    def assert_lt(actual : Comparable, expected : Comparable, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      unless actual < expected
        detail = msg.empty? ? "Expected #{actual} < #{expected}" : "#{msg} (Expected #{actual} < #{expected})"
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that actual <= expected
    def assert_lte(actual : Comparable, expected : Comparable, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      unless actual <= expected
        detail = msg.empty? ? "Expected #{actual} <= #{expected}" : "#{msg} (Expected #{actual} <= #{expected})"
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that two floating-point values are approximately equal within a tolerance epsilon
    def assert_approx_eq(actual : Float32 | Float64, expected : Float32 | Float64, epsilon : Float64 = 0.001, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      diff = (actual - expected).abs
      if diff > epsilon
        detail = msg.empty? ? "Expected ~#{expected}, got #{actual} (diff #{diff})" : "#{msg} (Expected ~#{expected}, got #{actual})"
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that a value is non-nil
    def assert_not_nil(val, msg : String = "Expected non-nil value", file : String = __FILE__, line : Int32 = __LINE__)
      raise AssertionError.new(msg, file, line) if val.nil?
    end

    # Asserts that a value is nil
    def assert_nil(val, msg : String = "Expected nil value", file : String = __FILE__, line : Int32 = __LINE__)
      raise AssertionError.new(msg, file, line) unless val.nil?
    end

    # Asserts that evaluating the block raises an exception of the expected class T
    def assert_raises(klass : T.class, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__, &block) forall T
      begin
        yield
      rescue ex : T
        return ex
      rescue ex : Exception
        detail = msg.empty? ? "Expected #{T.name} to be raised, but got #{ex.class.name}: #{ex.message}" : "#{msg} (Expected #{T.name}, got #{ex.class.name})"
        raise AssertionError.new(detail, file, line)
      end
      detail = msg.empty? ? "Expected #{T.name} to be raised, but no exception was raised" : "#{msg} (Expected #{T.name})"
      raise AssertionError.new(detail, file, line)
    end

    # Asserts that a collection contains the specified item
    def assert_includes(collection, item, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      unless collection.includes?(item)
        detail = msg.empty? ? "Expected collection to include #{item.inspect}, but it was absent" : "#{msg} (Missing #{item.inspect})"
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that a numeric value is within delta of the expected value
    def assert_in_delta(actual : Number, expected : Number, delta : Number, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      diff = (actual - expected).abs
      if diff > delta
        detail = msg.empty? ? "Expected #{actual} to be within #{delta} of #{expected} (diff #{diff})" : "#{msg} (Expected #{actual} within #{delta} of #{expected})"
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that a numeric value falls within the inclusive range [min, max]
    def assert_between(actual : Number, min : Number, max : Number, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      if actual < min || actual > max
        detail = msg.empty? ? "Expected #{actual} to be between #{min} and #{max}" : "#{msg} (Expected #{actual} between #{min} and #{max})"
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that a numeric value does NOT fall within the inclusive range [min, max]
    def assert_not_between(actual : Number, min : Number, max : Number, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      if actual >= min && actual <= max
        detail = msg.empty? ? "Expected #{actual} NOT to be between #{min} and #{max}" : "#{msg} (Expected #{actual} not between #{min} and #{max})"
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that string contains the specified substring
    def assert_string_contains(str : String, substr : String, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      unless str.includes?(substr)
        detail = msg.empty? ? "Expected string to contain #{substr.inspect}, but got #{str.inspect}" : "#{msg} (Missing #{substr.inspect})"
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that string starts with the specified prefix
    def assert_string_starts_with(str : String, prefix : String, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      unless str.starts_with?(prefix)
        detail = msg.empty? ? "Expected string to start with #{prefix.inspect}, but got #{str.inspect}" : "#{msg} (Does not start with #{prefix.inspect})"
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that string ends with the specified suffix
    def assert_string_ends_with(str : String, suffix : String, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      unless str.ends_with?(suffix)
        detail = msg.empty? ? "Expected string to end with #{suffix.inspect}, but got #{str.inspect}" : "#{msg} (Does not end with #{suffix.inspect})"
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that a collection is empty
    def assert_empty(collection, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      unless collection.empty?
        detail = msg.empty? ? "Expected collection to be empty, but had size #{collection.size}" : "#{msg} (Had size #{collection.size})"
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that a collection is not empty
    def assert_not_empty(collection, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      if collection.empty?
        detail = msg.empty? ? "Expected collection not to be empty" : msg
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that a file exists on disk
    def assert_file_exists(path : String, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      exists = Godot::SystemIO.file_exists?(path) rescue File.exists?(path)
      unless exists
        detail = msg.empty? ? "Expected file to exist at '#{path}'" : "#{msg} (File missing: '#{path}')"
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that a file does not exist on disk
    def assert_file_does_not_exist(path : String, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      exists = Godot::SystemIO.file_exists?(path) rescue File.exists?(path)
      if exists
        detail = msg.empty? ? "Expected file NOT to exist at '#{path}'" : "#{msg} (File exists: '#{path}')"
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that a file is empty (0 bytes)
    def assert_file_empty(path : String, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      assert_file_exists(path, msg, file, line)
      size = File.size(path) rescue 0_i64
      if size > 0
        detail = msg.empty? ? "Expected file '#{path}' to be empty, but size was #{size} bytes" : "#{msg} (Size: #{size} bytes)"
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that a file is not empty (> 0 bytes)
    def assert_file_not_empty(path : String, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      assert_file_exists(path, msg, file, line)
      size = File.size(path) rescue 0_i64
      if size == 0
        detail = msg.empty? ? "Expected file '#{path}' not to be empty" : msg
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that actual and expected reference the exact same object
    def assert_same(actual : Reference, expected : Reference, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      unless actual.same?(expected)
        detail = msg.empty? ? "Expected identical object references (same?), but were different instances" : msg
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that actual and expected do not reference the exact same object
    def assert_not_same(actual : Reference, expected : Reference, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      if actual.same?(expected)
        detail = msg.empty? ? "Expected different object references, but both were identical instance" : msg
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that object is an instance of the given class
    def assert_is_a(obj, klass : T.class, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__) forall T
      unless obj.is_a?(T)
        detail = msg.empty? ? "Expected instance of #{T.name}, got #{obj.class.name}" : "#{msg} (Expected #{T.name}, got #{obj.class.name})"
        raise AssertionError.new(detail, file, line)
      end
    end

    # Temporarily suppresses engine error printing to stdout/stderr while evaluating the block
    def suppress_errors(&block)
      engine = Godot::Engine.instance
      prev = engine.is_printing_error_messages
      engine.set_print_error_messages(false)
      begin
        yield
      ensure
        engine.set_print_error_messages(prev)
      end
    end

    # ===========================================================================
    # 2. Godot Domain-Specific Assertions
    # ===========================================================================

    # Asserts that the Godot object is alive in ObjectDB and has not been destroyed
    def assert_alive(object : Godot::Object, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      is_alive = object.alive?
      detail = msg.empty? ? "Expected #{object.class.name} (ID: #{object.instance_id}) to be alive in ObjectDB" : msg
      assert_true(is_alive, detail, file, line)
    end

    # Asserts that the Godot object has been destroyed/freed
    def assert_disposed(object : Godot::Object, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      is_dead = !object.alive?
      detail = msg.empty? ? "Expected #{object.class.name} (ID: #{object.instance_id}) to be disposed" : msg
      assert_true(is_dead, detail, file, line)
    end

    # Asserts that an object has been freed / disposed (alias to assert_disposed)
    def assert_freed(object : Godot::Object, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      assert_disposed(object, msg, file, line)
    end

    # Asserts that an object has NOT been freed / is alive (alias to assert_alive)
    def assert_not_freed(object : Godot::Object, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      assert_alive(object, msg, file, line)
    end

    # Asserts that an instance ID is currently valid in Godot's ObjectDB
    def assert_valid_id(instance_id : UInt64 | Int64, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      valid = Godot::Object.is_instance_id_valid(instance_id.to_u64)
      detail = msg.empty? ? "Expected instance ID #{instance_id} to be valid in ObjectDB" : msg
      assert_true(valid, detail, file, line)
    end

    # Asserts that an instance ID is no longer valid in Godot's ObjectDB
    def assert_invalid_id(instance_id : UInt64 | Int64, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      valid = Godot::Object.is_instance_id_valid(instance_id.to_u64)
      detail = msg.empty? ? "Expected instance ID #{instance_id} to be invalid in ObjectDB" : msg
      assert_false(valid, detail, file, line)
    end

    # Asserts that a Godot object has a defined method
    def assert_has_method(obj : Godot::Object, method_name : String, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      obj.check_alive!
      has = obj.has_method(method_name)
      unless has
        detail = msg.empty? ? "Expected #{obj.class.name} to have method '#{method_name}'" : msg
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that a Godot node has a child node at path
    def assert_has_node(parent : Godot::Node, path : String, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      parent.check_alive!
      has = parent.has_node(path)
      unless has
        detail = msg.empty? ? "Expected node #{parent.get_name} to have child at '#{path}'" : msg
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that a Godot object has declared a signal
    def assert_has_signal(emitter : Godot::Object, signal_name : String, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      emitter.check_alive!
      has = emitter.has_signal?(signal_name)
      unless has
        detail = msg.empty? ? "Expected #{emitter.class.name} to have signal '#{signal_name}'" : msg
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that emitter's signal has active connections
    def assert_connected(emitter : Godot::Object, signal_name : String, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      emitter.check_alive!
      count = emitter.signal_connection_count(signal_name)
      if count == 0
        detail = msg.empty? ? "Expected signal '#{signal_name}' on #{emitter.class.name} to have active connections" : msg
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that emitter's signal has NO active connections
    def assert_not_connected(emitter : Godot::Object, signal_name : String, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      emitter.check_alive!
      count = emitter.signal_connection_count(signal_name)
      if count > 0
        detail = msg.empty? ? "Expected signal '#{signal_name}' on #{emitter.class.name} NOT to have connections, but had #{count}" : msg
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that a SignalSpy recorded at least one emission
    def assert_signal_emitted(spy : SignalSpy, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      unless spy.emitted?
        detail = msg.empty? ? "Expected signal '#{spy.signal_name}' to have been emitted, but count was 0" : msg
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that a SignalSpy did NOT record any emissions
    def assert_signal_not_emitted(spy : SignalSpy, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      if spy.emitted?
        detail = msg.empty? ? "Expected signal '#{spy.signal_name}' NOT to have been emitted, but emitted #{spy.count} time(s)" : msg
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that a SignalSpy recorded exactly count emissions
    def assert_signal_emit_count(spy : SignalSpy, count : Int32, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      actual = spy.count
      if actual != count
        detail = msg.empty? ? "Expected signal '#{spy.signal_name}' to emit #{count} time(s), but emitted #{actual} time(s)" : "#{msg} (Expected #{count}, got #{actual})"
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that two Vector2 values are approximately equal within epsilon
    def assert_vector_approx(actual : Godot::Vector2, expected : Godot::Vector2, epsilon : Float64 = 0.001, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      diff_x = (actual.x - expected.x).abs
      diff_y = (actual.y - expected.y).abs
      if diff_x > epsilon || diff_y > epsilon
        detail = msg.empty? ? "Expected Vector2 ~#{expected}, got #{actual}" : "#{msg} (Expected Vector2 ~#{expected}, got #{actual})"
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that two Vector3 values are approximately equal within epsilon
    def assert_vector_approx(actual : Godot::Vector3, expected : Godot::Vector3, epsilon : Float64 = 0.001, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      diff_x = (actual.x - expected.x).abs
      diff_y = (actual.y - expected.y).abs
      diff_z = (actual.z - expected.z).abs
      if diff_x > epsilon || diff_y > epsilon || diff_z > epsilon
        detail = msg.empty? ? "Expected Vector3 ~#{expected}, got #{actual}" : "#{msg} (Expected Vector3 ~#{expected}, got #{actual})"
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that two Color values are approximately equal within epsilon
    def assert_vector_approx(actual : Godot::Color, expected : Godot::Color, epsilon : Float64 = 0.001, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      diff_r = (actual.r - expected.r).abs
      diff_g = (actual.g - expected.g).abs
      diff_b = (actual.b - expected.b).abs
      diff_a = (actual.a - expected.a).abs
      if diff_r > epsilon || diff_g > epsilon || diff_b > epsilon || diff_a > epsilon
        detail = msg.empty? ? "Expected Color ~#{expected}, got #{actual}" : "#{msg} (Expected Color ~#{expected}, got #{actual})"
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that a SignalSpy recorded exactly the expected number of emissions (backwards compatibility)
    def assert_signal_count(spy : SignalSpy, count : Int32, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      assert_signal_emit_count(spy, count, msg, file, line)
    end

    # Asserts that a RefCounted instance has the expected reference count
    def assert_refcount(refcounted : Godot::RefCounted, expected : Int32, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      actual = refcounted.get_reference_count
      if actual != expected
        detail = msg.empty? ? "Expected reference count #{expected}, got #{actual} for #{refcounted.class.name}" : "#{msg} (Expected #{expected}, got #{actual})"
        raise AssertionError.new(detail, file, line)
      end
    end

    # ===========================================================================
    # 3. Quantitative Zero-Leak & Orphan Node Verification
    # ===========================================================================

    # Executes the provided block and asserts that Godot ObjectDB object and node counts
    # return to baseline after Boehm GC collection and frame draining.
    def assert_no_leak(max_delta_objects : Int32 = 0, name : String = "Operation", file : String = __FILE__, line : Int32 = __LINE__, &block)
      GC.collect
      skip_frames(2)
      perf = Godot::Performance.instance
      # Monitor 7 is ObjectCount, 9 is ObjectNodeCount
      baseline_objects = perf.get_monitor(7_i64).to_i64
      baseline_nodes = perf.get_monitor(9_i64).to_i64

      yield

      GC.collect
      skip_frames(3)
      final_objects = perf.get_monitor(7_i64).to_i64
      final_nodes = perf.get_monitor(9_i64).to_i64

      delta_objects = final_objects - baseline_objects
      delta_nodes = final_nodes - baseline_nodes

      if delta_objects > max_delta_objects || delta_nodes > max_delta_objects
        detail = "Memory leak detected during '#{name}'!\n" \
                 "  Object count delta: #{delta_objects} (baseline: #{baseline_objects}, final: #{final_objects})\n" \
                 "  Node count delta: #{delta_nodes} (baseline: #{baseline_nodes}, final: #{final_nodes})"
        raise AssertionError.new(detail, file, line)
      end
    end

    # Asserts that the block does not introduce any orphan nodes (Performance::ObjectOrphanNodeCount)
    def assert_no_new_orphans(msg : String = "", file : String = __FILE__, line : Int32 = __LINE__, &block)
      perf = Godot::Performance.instance
      # Monitor 10 is ObjectOrphanNodeCount
      baseline = perf.get_monitor(10_i64).to_i64
      yield
      current = perf.get_monitor(10_i64).to_i64
      delta = current - baseline
      if delta > 0
        detail = msg.empty? ? "Detected #{delta} orphan node(s) created (baseline: #{baseline}, current: #{current})" : "#{msg} (#{delta} new orphans)"
        raise AssertionError.new(detail, file, line)
      end
    end

    # ===========================================================================
    # 4. Automatic Node Tracking & Auto-Free Fixtures (autofree/autoqfree)
    # ===========================================================================

    class_getter tracked_nodes = Array(Godot::Node).new
    class_getter autofree_objects = Array(Godot::Object).new
    class_getter autoqfree_nodes = Array(Godot::Node).new

    # Registers a node to be automatically destroyed and cleaned up in after_each
    def track_node(node : Godot::Node) : Godot::Node
      Lapis::Test.tracked_nodes << node
      node
    end

    # Registers an object to be safely disposed at the end of the test
    def autofree(obj : T) : T forall T
      {% if T < Godot::Object %}
        Lapis::Test.autofree_objects << obj.as(Godot::Object)
      {% end %}
      obj
    end

    # Registers a node to be queue_freed at the end of the test
    def autoqfree(node : T) : T forall T
      {% if T < Godot::Node %}
        Lapis::Test.autoqfree_nodes << node.as(Godot::Node)
      {% end %}
      node
    end

    # Adds a child node to the parent and registers it for automatic queue_free
    def add_child_autofree(parent : Godot::Node, child : T) : T forall T
      {% if T < Godot::Node %}
        parent.add_child(child)
        autoqfree(child)
      {% end %}
      child
    end

    # Overload when called in test_suite where single argument node is registered
    def add_child_autofree(child : T) : T forall T
      autoqfree(child)
    end

    # Cleans up all auto-freed objects and nodes created during a test
    def cleanup_autofree : Void
      Lapis::Test.autoqfree_nodes.reverse_each do |node|
        begin
          if node.alive?
            node.queue_free
          end
        rescue
        end
      end
      Lapis::Test.autoqfree_nodes.clear

      Lapis::Test.autofree_objects.reverse_each do |obj|
        begin
          if obj.alive?
            if obj.is_a?(Godot::Node)
              node = obj.as(Godot::Node)
              if parent = node.get_parent?
                parent.remove_child(node) rescue nil
              end
            end
            if !obj.is_a?(Godot::RefCounted)
              obj.destroy rescue nil
            end
          end
        rescue
        end
      end
      Lapis::Test.autofree_objects.clear
    end

    # Alias for cleanup_autofree
    def autofree_all : Void
      cleanup_autofree
    end

    # Cleans up all tracked nodes created during a test
    def cleanup_tracked_nodes : Void
      Lapis::Test.tracked_nodes.reverse_each do |n|
        begin
          if n.alive?
            if parent = n.get_parent?
              parent.remove_child(n)
            end
            n.destroy
          end
        rescue
        end
      end
      Lapis::Test.tracked_nodes.clear
    end

    # Safely creates a node of type T, yields it to the block, and guarantees destruction
    def with_node(klass : T.class, parent : Godot::Node? = nil, &block : T -> Void) forall T
      node = Godot.create(klass)
      if parent && parent.alive?
        parent.add_child(node)
      end
      begin
        yield node
      ensure
        if node.alive?
          if parent && parent.alive?
            parent.remove_child(node) rescue nil
          end
          node.destroy rescue nil
        end
      end
    end

    # ===========================================================================
    # 5. Deterministic Node Simulation
    # ===========================================================================

    # Deterministically simulates frames of processing on a node and its recursive children
    def simulate(node : Godot::Node, frames : Int32 = 1, delta : Float64 = 0.016666666666666666, physics : Bool = false) : Void
      frames.times do
        simulate_node_step(node, delta, physics)
        Fiber.yield
      end
    end

    private def simulate_node_step(node : Godot::Node, delta : Float64, physics : Bool) : Void
      if !node.pointer.null? && node.instance_id > 0
        return unless node.alive?
        if physics
          return unless node.is_physics_processing
        else
          return unless node.is_processing
        end
      else
        return if node.explicitly_freed?
      end

      if physics
        if node.responds_to?(:_physics_process)
          node._physics_process(delta)
        elsif node.has_method("_physics_process")
          node.call("_physics_process", delta)
        end
      else
        if node.responds_to?(:_process)
          node._process(delta)
        elsif node.has_method("_process")
          node.call("_process", delta)
        end
      end

      # Recursively step children
      node.get_children.each do |child|
        simulate_node_step(child, delta, physics)
      end
    end

    # ===========================================================================
    # 6. Input Simulation & Sequencer (InputFactory & InputSender)
    # ===========================================================================

    module InputFactory
      # Generates a Godot::InputEventKey
      def self.key_event(keycode : Godot::Key | Int64, pressed : Bool = true, echo : Bool = false, shift : Bool = false, ctrl : Bool = false, alt : Bool = false) : Godot::InputEventKey
        ev = Godot.create(Godot::InputEventKey)
        ev.set_keycode(keycode.to_i64)
        ev.set_pressed(pressed)
        ev.set_echo(echo)
        ev.set_shift_pressed(shift)
        ev.set_ctrl_pressed(ctrl)
        ev.set_alt_pressed(alt)
        ev
      end

      def self.key_down(keycode : Godot::Key | Int64, shift : Bool = false, ctrl : Bool = false, alt : Bool = false) : Godot::InputEventKey
        key_event(keycode, pressed: true, shift: shift, ctrl: ctrl, alt: alt)
      end

      def self.key_up(keycode : Godot::Key | Int64, shift : Bool = false, ctrl : Bool = false, alt : Bool = false) : Godot::InputEventKey
        key_event(keycode, pressed: false, shift: shift, ctrl: ctrl, alt: alt)
      end

      # Generates a Godot::InputEventMouseButton
      def self.mouse_button_event(button_index : Godot::MouseButton | Int64, pressed : Bool = true, position : Godot::Vector2 = Godot::Vector2::ZERO) : Godot::InputEventMouseButton
        ev = Godot.create(Godot::InputEventMouseButton)
        ev.set_button_index(button_index.to_i64)
        ev.set_pressed(pressed)
        ev.set_position(position)
        ev
      end

      def self.mouse_button_down(button_index : Godot::MouseButton | Int64, position : Godot::Vector2 = Godot::Vector2::ZERO) : Godot::InputEventMouseButton
        mouse_button_event(button_index, pressed: true, position: position)
      end

      def self.mouse_button_up(button_index : Godot::MouseButton | Int64, position : Godot::Vector2 = Godot::Vector2::ZERO) : Godot::InputEventMouseButton
        mouse_button_event(button_index, pressed: false, position: position)
      end

      # Generates a Godot::InputEventMouseMotion
      def self.mouse_motion_event(position : Godot::Vector2, relative : Godot::Vector2 = Godot::Vector2::ZERO) : Godot::InputEventMouseMotion
        ev = Godot.create(Godot::InputEventMouseMotion)
        ev.set_position(position)
        ev.set_relative(relative)
        ev
      end

      # Generates a Godot::InputEventAction
      def self.action_event(action : String, pressed : Bool = true, strength : Float32 = 1.0_f32) : Godot::InputEventAction
        ev = Godot.create(Godot::InputEventAction)
        ev.set_action(action)
        ev.set_pressed(pressed)
        ev.set_strength(strength.to_f64)
        ev
      end

      def self.action_down(action : String, strength : Float32 = 1.0_f32) : Godot::InputEventAction
        action_event(action, pressed: true, strength: strength)
      end

      def self.action_up(action : String) : Godot::InputEventAction
        action_event(action, pressed: false, strength: 0.0_f32)
      end
    end

    class InputSender
      enum ActionType
        DispatchEvent
        WaitFrames
      end

      record Step, type : ActionType, event : Godot::InputEvent? = nil, frames : Int32 = 0

      @steps = Array(Step).new

      def key_down(keycode : Godot::Key | Int64, shift : Bool = false, ctrl : Bool = false, alt : Bool = false) : self
        ev = InputFactory.key_down(keycode, shift, ctrl, alt)
        @steps << Step.new(ActionType::DispatchEvent, ev)
        self
      end

      def key_up(keycode : Godot::Key | Int64, shift : Bool = false, ctrl : Bool = false, alt : Bool = false) : self
        ev = InputFactory.key_up(keycode, shift, ctrl, alt)
        @steps << Step.new(ActionType::DispatchEvent, ev)
        self
      end

      def mouse_down(button_index : Godot::MouseButton | Int64, position : Godot::Vector2 = Godot::Vector2::ZERO) : self
        ev = InputFactory.mouse_button_down(button_index, position)
        @steps << Step.new(ActionType::DispatchEvent, ev)
        self
      end

      def mouse_up(button_index : Godot::MouseButton | Int64, position : Godot::Vector2 = Godot::Vector2::ZERO) : self
        ev = InputFactory.mouse_button_up(button_index, position)
        @steps << Step.new(ActionType::DispatchEvent, ev)
        self
      end

      def action_down(action : String, strength : Float32 = 1.0_f32) : self
        ev = InputFactory.action_down(action, strength)
        @steps << Step.new(ActionType::DispatchEvent, ev)
        self
      end

      def action_up(action : String) : self
        ev = InputFactory.action_up(action)
        @steps << Step.new(ActionType::DispatchEvent, ev)
        self
      end

      def wait_frames(frames : Int32 = 1) : self
        @steps << Step.new(ActionType::WaitFrames, frames: frames)
        self
      end

      def send : Void
        input = Godot::Input.instance
        @steps.each do |step|
          case step.type
          when ActionType::DispatchEvent
            if ev = step.event
              input.parse_input_event(ev)
            end
          when ActionType::WaitFrames
            step.frames.times { Fiber.yield }
          end
        end
        @steps.clear
      end
    end

    def input_sender : InputSender
      InputSender.new
    end

    # ===========================================================================
    # 7. Async Frame Stepping & Timeout Mechanics
    # ===========================================================================

    # Cooperatively yields until the specified number of process (render/idle) frames have elapsed
    def skip_frames(count : Int32 = 1) : Void
      count.times do
        Fiber.yield
      end
    end

    # Cooperatively yields until the specified number of fixed physics frames have elapsed
    def skip_physics_frames(count : Int32 = 1) : Void
      count.times do
        Fiber.yield
      end
    end

    # Cooperatively awaits a signal on the target emitter.
    # If the signal is not received within `timeout_sec`, raises a descriptive `TimeoutError`.
    # Returns the emitted arguments as an Array(Variant).
    def await_signal(emitter : Godot::Object, signal_name : String, timeout_sec : Float64 = 2.0, file : String = __FILE__, line : Int32 = __LINE__) : ::Array(Variant)
      emitter.check_alive!
      target_id = emitter.signal_target_id
      sub = Godot.subscribe_signal(target_id, signal_name)
      if !emitter.pointer.null? && emitter.instance_id > 0
        Bridge.object_connect_signal(emitter.pointer, signal_name)
      end
      start_time = ::Time.instant
      begin
        while !sub.completed?
          if !emitter.alive?
            raise Godot::DisposedObjectError.new(target_id, "Target object was destroyed while awaiting signal '#{signal_name}'")
          end
          if (::Time.instant - start_time).total_seconds >= timeout_sec
            raise TimeoutError.new("Timed out after #{timeout_sec}s waiting for signal '#{signal_name}' on #{emitter.class.name} (ID: #{emitter.instance_id})", file, line)
          end
          Fiber.yield
        end
        sub.args
      ensure
        Godot.unsubscribe_signal(sub)
      end
    end

    # Executes the provided block and asserts that the specified signal is emitted within `timeout_sec`.
    # Returns the emitted arguments. Raises AssertionError if the signal fails to emit.
    def assert_emits(emitter : Godot::Object, signal_name : String, timeout_sec : Float64 = 2.0, file : String = __FILE__, line : Int32 = __LINE__, &block) : ::Array(Variant)
      emitter.check_alive!
      target_id = emitter.signal_target_id
      sub = Godot.subscribe_signal(target_id, signal_name)
      if !emitter.pointer.null? && emitter.instance_id > 0
        Bridge.object_connect_signal(emitter.pointer, signal_name)
      end
      start_time = ::Time.instant
      begin
        yield
        while !sub.completed?
          if !emitter.alive?
            raise Godot::DisposedObjectError.new(target_id, "Target object was destroyed while awaiting signal '#{signal_name}'")
          end
          if (::Time.instant - start_time).total_seconds >= timeout_sec
            raise AssertionError.new("Expected signal '#{signal_name}' on #{emitter.class.name} within #{timeout_sec}s, but it was not received.", file, line)
          end
          Fiber.yield
        end
        sub.args
      ensure
        Godot.unsubscribe_signal(sub)
      end
    end

    # Executes the provided block and verifies that the specified signal is NOT emitted during `duration_sec`.
    def assert_no_emit(emitter : Godot::Object, signal_name : String, duration_sec : Float64 = 0.5, file : String = __FILE__, line : Int32 = __LINE__, &block) : Void
      emitter.check_alive!
      target_id = emitter.signal_target_id
      sub = Godot.subscribe_signal(target_id, signal_name)
      if !emitter.pointer.null? && emitter.instance_id > 0
        Bridge.object_connect_signal(emitter.pointer, signal_name)
      end
      start_time = ::Time.instant
      begin
        yield
        while (::Time.instant - start_time).total_seconds < duration_sec
          if sub.completed?
            raise AssertionError.new("Expected signal '#{signal_name}' NOT to be emitted, but it fired with args: #{sub.args.inspect}", file, line)
          end
          Fiber.yield
        end
      ensure
        Godot.unsubscribe_signal(sub)
      end
    end

    # Executes a block with an active timeout watchdog, raising `TimeoutError` if it fails to finish in time
    def with_timeout(timeout_sec : Float64 = 5.0, operation_name : String = "Operation", file : String = __FILE__, line : Int32 = __LINE__, &block)
      done = false
      err : Exception? = nil
      spawn do
        begin
          yield
        rescue ex
          err = ex
        ensure
          done = true
        end
      end
      start_time = ::Time.instant
      while !done
        if (::Time.instant - start_time).total_seconds >= timeout_sec
          raise TimeoutError.new("#{operation_name} timed out after #{timeout_sec}s", file, line)
        end
        Fiber.yield
      end
      if e = err
        raise e
      end
    end

    # ===========================================================================
    # 8. Signal Recording and Spy Helper
    # ===========================================================================

    class SignalSpy
      getter emissions = Array(Array(String)).new
      getter emitter : Godot::Object
      getter signal_name : String
      @subscription : Godot::SignalSubscription? = nil

      def initialize(@emitter : Godot::Object, @signal_name : String)
        @subscription = @emitter.connect(@signal_name) do |args|
          record(args)
        end
      end

      def record(args : Enumerable)
        @emissions << args.map(&.to_s).to_a
      end

      def record(*args)
        @emissions << args.map(&.to_s).to_a
      end

      def count : Int32
        @emissions.size
      end

      def emitted? : Bool
        !@emissions.empty?
      end

      def first_args : Array(String)?
        @emissions.first?
      end

      def last_args : Array(String)?
        @emissions.last?
      end

      def clear : Void
        @emissions.clear
      end

      def disconnect : Void
        if sub = @subscription
          sub.unsubscribe
          @subscription = nil
        end
      end
    end

    # ===========================================================================
    # 9. Centralized Extensible Test Registry & Lifecycle Runner
    # ===========================================================================

    # Encapsulates a dedicated, completely isolated ephemeral Godot engine environment
    # for tests requiring cold boot execution without polluting the shared engine or project.
    class ColdBootContext
      getter sandbox_dir : String
      getter test_name : String
      getter godot_exe : String

      def initialize(@test_name : String)
        @godot_exe = resolve_godot || "godot.exe"
        unique_id = "#{::Time.utc.to_unix}_#{::Random.rand(1000..9999)}"
        safe_name = @test_name.downcase.gsub(/[^a-z0-9_]+/, "_")
        @sandbox_dir = File.expand_path("scratch/.cold_boot_#{safe_name}_#{unique_id}")
        FileUtils.mkdir_p(@sandbox_dir)

        # Write clean minimal project configuration
        project_file = File.join(@sandbox_dir, "project.godot")
        unless File.exists?(project_file)
          File.write(project_file, "config_version=5\n\n[application]\nconfig/name=\"ColdBoot_#{safe_name}\"\n")
        end
      end

      # Writes an isolated test script into the ephemeral sandbox.
      # This code only exists for this test and will NEVER be replicated across the project.
      def write_script(rel_path : String, code : String) : String
        full_path = File.join(@sandbox_dir, rel_path)
        FileUtils.mkdir_p(File.dirname(full_path))
        File.write(full_path, code)
        full_path
      end

      # Writes an isolated scene, resource, or configuration file into the sandbox.
      def write_file(rel_path : String, content : String) : String
        write_script(rel_path, content)
      end

      # Runs an isolated script in a dedicated headless Godot process with complete environment isolation.
      def run_isolated_script(script_rel_path : String, args : Array(String) = [] of String) : TestResult
        script_path = File.join(@sandbox_dir, script_rel_path)
        env = {
          "GODOT_HEADLESS"        => "1",
          "LIBGL_ALWAYS_SOFTWARE" => "1",
          "LAPIS_COLD_BOOT"       => "1",
        }
        run_args = [
          "--headless",
          "--rendering-driver", "opengl3",
          "--audio-driver", "Dummy",
          "--path", @sandbox_dir,
          "--script", script_path,
          "--"
        ] + args

        stdout = IO::Memory.new
        stderr = IO::Memory.new
        start = ::Time.instant
        begin
          status = Process.run(@godot_exe, run_args, env: env, output: stdout, error: stderr)
          duration = (::Time.instant - start).total_milliseconds
          out_str = stdout.to_s + "\n" + stderr.to_s
          success = status.success?
          status_str = success ? "PASS" : "FAIL"
          TestResult.new("ColdBoot", @test_name, success, success ? out_str.strip : "Process exited with code #{status.exit_code}: #{out_str}", duration, status_str)
        rescue ex
          duration = (::Time.instant - start).total_milliseconds
          TestResult.new("ColdBoot", @test_name, false, "Failed to launch isolated engine: #{ex.message}", duration, "FAIL")
        end
      end

      # Executes the isolated project in headless runtime mode
      def run_isolated_project(args : Array(String) = [] of String) : TestResult
        env = {
          "GODOT_HEADLESS"        => "1",
          "LIBGL_ALWAYS_SOFTWARE" => "1",
          "LAPIS_COLD_BOOT"       => "1",
        }
        run_args = [
          "--headless",
          "--rendering-driver", "opengl3",
          "--audio-driver", "Dummy",
          "--path", @sandbox_dir,
        ] + args

        stdout = IO::Memory.new
        stderr = IO::Memory.new
        start = ::Time.instant
        begin
          status = Process.run(@godot_exe, run_args, env: env, output: stdout, error: stderr)
          duration = (::Time.instant - start).total_milliseconds
          out_str = stdout.to_s + "\n" + stderr.to_s
          success = status.success?
          status_str = success ? "PASS" : "FAIL"
          TestResult.new("ColdBoot", @test_name, success, success ? out_str.strip : "Process exited with code #{status.exit_code}: #{out_str}", duration, status_str)
        rescue ex
          duration = (::Time.instant - start).total_milliseconds
          TestResult.new("ColdBoot", @test_name, false, "Failed to launch isolated engine project: #{ex.message}", duration, "FAIL")
        end
      end

      # Guarantees that ephemeral sandbox files are completely wiped upon completion.
      def cleanup : Void
        FileUtils.rm_rf(@sandbox_dir) if Dir.exists?(@sandbox_dir)
      end

      private def resolve_godot : String?
        if env_bin = ENV["GODOT_BIN"]? || ENV["GODOT"]?
          return env_bin if File.exists?(env_bin)
        end
        ["./godot.exe", "../godot.exe", "godot.exe", "./godot", "../godot", "godot"].each do |c|
          return c if File.exists?(c) || Process.find_executable(c)
        end
        nil
      end
    end

    class TestCase
      getter category : String
      getter name : String
      getter file : String
      getter line : Int32
      getter? cold_boot : Bool
      @block : (Godot::Node -> Void)?
      @cold_boot_block : (ColdBootContext -> Void)?

      def initialize(@category : String, @name : String, @file : String = "", @line : Int32 = 0, @cold_boot : Bool = false, &block : Godot::Node -> Void)
        @block = block
        @cold_boot_block = nil
      end

      def self.new_cold_boot(category : String, name : String, file : String = "", line : Int32 = 0, &block : ColdBootContext -> Void)
        tc = allocate
        tc.initialize_cold_boot(category, name, file, line, &block)
        tc
      end

      protected def initialize_cold_boot(@category : String, @name : String, @file : String = "", @line : Int32 = 0, &block : ColdBootContext -> Void)
        @cold_boot = true
        @block = nil
        @cold_boot_block = block
      end

      def execute(context_node : Godot::Node) : TestResult
        cb_str = @cold_boot ? " [COLD_BOOT]" : ""
        Godot.print("  [Running] [#{@category}] #{@name}#{cb_str}...")
        start = ::Time.instant
        begin
          # Run before_each hooks
          Registry.run_before_each(@category, context_node)

          if @cold_boot
            boot_ctx = ColdBootContext.new("#{@category}_#{@name}")
            begin
              if cb = @cold_boot_block
                cb.call(boot_ctx)
              elsif blk = @block
                blk.call(context_node)
              end
            ensure
              boot_ctx.cleanup
            end
          else
            @block.not_nil!.call(context_node)
          end

          duration = (::Time.instant - start).total_milliseconds
          TestResult.new(@category, @name, true, "PASS", duration, "PASS")
        rescue ex : PendingTestException
          duration = (::Time.instant - start).total_milliseconds
          Godot.print("  [PENDING] [#{@category}] #{@name}: #{ex.message}")
          TestResult.new(@category, @name, true, "PENDING: #{ex.message}", duration, "PENDING")
        rescue ex : SkipTestException
          duration = (::Time.instant - start).total_milliseconds
          Godot.print("  [SKIPPED] [#{@category}] #{@name}: #{ex.message}")
          TestResult.new(@category, @name, true, "SKIPPED: #{ex.message}", duration, "SKIPPED")
        rescue ex : AssertionError
          duration = (::Time.instant - start).total_milliseconds
          TestResult.new(@category, @name, false, ex.message || "Assertion failed", duration, "FAIL")
        rescue ex : Exception
          duration = (::Time.instant - start).total_milliseconds
          Godot.print("[ERROR] #{ex.inspect_with_backtrace}")
          TestResult.new(@category, @name, false, "ERROR: #{ex.class.name}: #{ex.message}\n#{ex.backtrace.join("\n")}", duration, "FAIL")
        ensure
          # Run after_each hooks
          Registry.run_after_each(@category, context_node)
          # Clean up any nodes tracked via track_node during this test
          Lapis::Test.cleanup_tracked_nodes
          # Clean up any autofree/autoqfree objects
          Lapis::Test.cleanup_autofree
        end
      end
    end

    class Registry
      @@tests = Array(TestCase).new
      @@before_all_hooks = Hash(String, Array(Godot::Node -> Void)).new
      @@after_all_hooks = Hash(String, Array(Godot::Node -> Void)).new
      @@before_each_hooks = Hash(String, Array(Godot::Node -> Void)).new
      @@after_each_hooks = Hash(String, Array(Godot::Node -> Void)).new

      def self.register(category : String, name : String, file : String = "", line : Int32 = 0, cold_boot : Bool = false, &block : Godot::Node -> Void)
        @@tests << TestCase.new(category, name, file, line, cold_boot, &block)
      end

      def self.register_cold_boot(category : String, name : String, file : String = "", line : Int32 = 0, &block : ColdBootContext -> Void)
        @@tests << TestCase.new_cold_boot(category, name, file, line, &block)
      end

      def self.before_all(category : String = "global", &block : Godot::Node -> Void)
        cat_norm = category.downcase.sub(/^test_?/, "")
        hooks = @@before_all_hooks[cat_norm] ||= Array(Godot::Node -> Void).new
        hooks << block
      end

      def self.after_all(category : String = "global", &block : Godot::Node -> Void)
        cat_norm = category.downcase.sub(/^test_?/, "")
        hooks = @@after_all_hooks[cat_norm] ||= Array(Godot::Node -> Void).new
        hooks << block
      end

      def self.before_each(category : String = "global", &block : Godot::Node -> Void)
        cat_norm = category.downcase.sub(/^test_?/, "")
        hooks = @@before_each_hooks[cat_norm] ||= Array(Godot::Node -> Void).new
        hooks << block
      end

      def self.after_each(category : String = "global", &block : Godot::Node -> Void)
        cat_norm = category.downcase.sub(/^test_?/, "")
        hooks = @@after_each_hooks[cat_norm] ||= Array(Godot::Node -> Void).new
        hooks << block
      end

      def self.run_before_all(category : String, context_node : Godot::Node)
        cat_norm = category.downcase.sub(/^test_?/, "")
        if global_hooks = @@before_all_hooks["global"]?
          global_hooks.each { |h| h.call(context_node) }
        end
        if cat_hooks = @@before_all_hooks[cat_norm]?
          cat_hooks.each { |h| h.call(context_node) }
        end
      end

      def self.run_after_all(category : String, context_node : Godot::Node)
        cat_norm = category.downcase.sub(/^test_?/, "")
        if cat_hooks = @@after_all_hooks[cat_norm]?
          cat_hooks.reverse_each { |h| h.call(context_node) rescue nil }
        end
        if global_hooks = @@after_all_hooks["global"]?
          global_hooks.reverse_each { |h| h.call(context_node) rescue nil }
        end
      end

      def self.run_before_each(category : String, context_node : Godot::Node)
        cat_norm = category.downcase.sub(/^test_?/, "")
        if global_hooks = @@before_each_hooks["global"]?
          global_hooks.each { |h| h.call(context_node) }
        end
        if cat_hooks = @@before_each_hooks[cat_norm]?
          cat_hooks.each { |h| h.call(context_node) }
        end
      end

      def self.run_after_each(category : String, context_node : Godot::Node)
        cat_norm = category.downcase.sub(/^test_?/, "")
        if cat_hooks = @@after_each_hooks[cat_norm]?
          cat_hooks.reverse_each { |h| h.call(context_node) rescue nil }
        end
        if global_hooks = @@after_each_hooks["global"]?
          global_hooks.reverse_each { |h| h.call(context_node) rescue nil }
        end
      end

      def self.all_tests : Array(TestCase)
        @@tests
      end

      def self.for_category(category : String) : Array(TestCase)
        cat_norm = category.downcase.sub(/^test_?/, "")
        @@tests.select { |t| t.category.downcase.sub(/^test_?/, "") == cat_norm }
      end

      def self.categories : Array(String)
        @@tests.map(&.category).uniq
      end

      def self.run_category(category : String, context_node : Godot::Node, filter : String? = nil) : Array(TestResult)
        results = Array(TestResult).new
        run_before_all(category, context_node)
        begin
          for_category(category).each do |test|
            next if filter && !filter.empty? && !test.name.includes?(filter)
            results << test.execute(context_node)
          end
        ensure
          run_after_all(category, context_node)
        end
        results
      end

      def self.run_all(context_node : Godot::Node, filter : String? = nil, category_filter : String? = nil) : Array(TestResult)
        results = Array(TestResult).new
        cat_norm = category_filter ? category_filter.downcase.sub(/^test_?/, "") : nil

        # Group by category to trigger category before_all/after_all lifecycle
        by_category = Hash(String, Array(TestCase)).new
        @@tests.each do |test|
          t_cat = test.category.downcase.sub(/^test_?/, "")
          if cat_norm && !cat_norm.empty?
            next if t_cat != cat_norm
          end
          next if filter && !filter.empty? && !test.name.downcase.includes?(filter.downcase)
          (by_category[test.category] ||= Array(TestCase).new) << test
        end

        by_category.each do |category, tests|
          run_before_all(category, context_node)
          begin
            tests.each do |test|
              results << test.execute(context_node)
            end
          ensure
            run_after_all(category, context_node)
          end
        end

        results
      end

      def self.clear : Void
        @@tests.clear
        @@before_all_hooks.clear
        @@after_all_hooks.clear
        @@before_each_hooks.clear
        @@after_each_hooks.clear
      end
    end

    # ===========================================================================
    # 10. JUnit XML Test Exporter
    # ===========================================================================

    class JUnitExporter
      def self.generate(results : Array(TestResult), filepath : String) : Void
        total = results.size
        failures = results.count(&.fail?)
        time_total = results.sum(&.duration_ms) / 1000.0

        by_cat = Hash(String, Array(TestResult)).new
        results.each do |r|
          (by_cat[r.category] ||= Array(TestResult).new) << r
        end

        xml = String.build do |io|
          io << "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
          io << "<testsuites name=\"Lapis Test Suite\" tests=\"#{total}\" failures=\"#{failures}\" errors=\"0\" time=\"#{time_total}\">\n"
          by_cat.each do |cat, cat_results|
            cat_failures = cat_results.count(&.fail?)
            cat_time = cat_results.sum(&.duration_ms) / 1000.0
            io << "  <testsuite name=\"#{escape_xml(cat)}\" tests=\"#{cat_results.size}\" failures=\"#{cat_failures}\" errors=\"0\" time=\"#{cat_time}\">\n"
            cat_results.each do |r|
              r_time = r.duration_ms / 1000.0
              io << "    <testcase classname=\"#{escape_xml(r.category)}\" name=\"#{escape_xml(r.name)}\" time=\"#{r_time}\""
              if r.fail?
                io << ">\n"
                io << "      <failure message=\"#{escape_xml(r.message)}\">#{escape_xml(r.message)}</failure>\n"
                io << "    </testcase>\n"
              elsif r.pending? || r.skipped?
                io << ">\n"
                io << "      <skipped message=\"#{escape_xml(r.message)}\"/>\n"
                io << "    </testcase>\n"
              else
                io << "/>\n"
              end
            end
            io << "  </testsuite>\n"
          end
          io << "</testsuites>\n"
        end

        Godot::SystemIO.write_file(filepath, xml) rescue File.write(filepath, xml)
      end

      private def self.escape_xml(str : String) : String
        str.gsub('&', "&amp;")
           .gsub('<', "&lt;")
           .gsub('>', "&gt;")
           .gsub('"', "&quot;")
           .gsub('\'', "&apos;")
      end
    end
  end
end

include Lapis::Test

module Godot
  alias Test = ::Lapis::Test
end

# =============================================================================
# 11. Declarative Suite & Test DSL Macros (with Parameterization & Lifecycle)
# =============================================================================

# Declarative suite macro allowing grouped tests, parameterized tests, and suite/case lifecycle hooks
macro test_suite(category, &block)
  {% for exp in (block.body.is_a?(Expressions) ? block.body.expressions : [block.body]) %}
    {% if exp.is_a?(Call) && exp.name == "test" %}
      {% if exp.named_args && exp.named_args.any? { |a| a.name == "params" } %}
        {% params_arg = exp.named_args.find { |a| a.name == "params" }.value %}
        {% for param, idx in params_arg %}
          ::Lapis::Test::Registry.register({{category}}, {{exp.args[0]}} + " [#{ {{param}} }]", {{exp.filename}}, {{exp.line_number}}) do |_suite_node_|
            root = _suite_node_
            {% if exp.block.args.size >= 2 %}
              {{exp.block.args[0]}} = _suite_node_
              {{exp.block.args[1]}} = {{param}}
            {% elsif exp.block.args.size == 1 %}
              {{exp.block.args[0]}} = {{param}}
            {% end %}
            {{exp.block.body}}
          end
        {% end %}
      {% elsif exp.named_args && exp.named_args.any? { |a| a.name == "cold_boot" } && exp.named_args.find { |a| a.name == "cold_boot" }.value %}
        ::Lapis::Test::Registry.register_cold_boot({{category}}, {{exp.args[0]}}, {{exp.filename}}, {{exp.line_number}}) do |_boot_|
          {% if exp.block.args.size > 0 %}
            {{exp.block.args[0]}} = _boot_
          {% else %}
            boot = _boot_
          {% end %}
          {{exp.block.body}}
        end
      {% else %}
        ::Lapis::Test::Registry.register({{category}}, {{exp.args[0]}}, {{exp.filename}}, {{exp.line_number}}) do |node|
          root = node
          {{exp.block.body}}
        end
      {% end %}
    {% elsif exp.is_a?(Call) && exp.name == "before_all" %}
      ::Lapis::Test::Registry.before_all({{category}}) do |node|
        root = node
        {{exp.block.body}}
      end
    {% elsif exp.is_a?(Call) && exp.name == "after_all" %}
      ::Lapis::Test::Registry.after_all({{category}}) do |node|
        root = node
        {{exp.block.body}}
      end
    {% elsif exp.is_a?(Call) && exp.name == "before_each" %}
      ::Lapis::Test::Registry.before_each({{category}}) do |node|
        root = node
        {{exp.block.body}}
      end
    {% elsif exp.is_a?(Call) && exp.name == "after_each" %}
      ::Lapis::Test::Registry.after_each({{category}}) do |node|
        root = node
        {{exp.block.body}}
      end
    {% elsif !exp.is_a?(Nop) %}
      {{exp}}
    {% end %}
  {% end %}
end

# Base test_case macro
macro test_case(category, name, cold_boot = false, &block)
  {% if cold_boot %}
    ::Lapis::Test::Registry.register_cold_boot({{category}}, {{name}}, __FILE__, __LINE__) do |_boot_|
      {% if block.args.size > 0 %}
        {{block.args[0]}} = _boot_
      {% else %}
        boot = _boot_
      {% end %}
      {{block.body}}
    end
  {% else %}
    ::Lapis::Test::Registry.register({{category}}, {{name}}, __FILE__, __LINE__) do |node|
      root = node
      {{block.body}}
    end
  {% end %}
end

# Dedicated declarative cold boot test macro
macro cold_boot_test(category, name, &block)
  ::Lapis::Test::Registry.register_cold_boot({{category}}, {{name}}, __FILE__, __LINE__) do |_boot_|
    {% if block.args.size > 0 %}
      {{block.args[0]}} = _boot_
    {% else %}
      boot = _boot_
    {% end %}
    {{block.body}}
  end
end
