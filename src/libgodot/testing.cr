# =============================================================================
# LibGodot - Reusable Testing Apparatus & Assertion Framework
# =============================================================================
#
# Provides an extensible, full-featured testing framework for Crystal in Godot.
# Supports standard assertion matchers, source location tracking (__FILE__, __LINE__),
# Godot domain assertions, async frame-stepping, signal awaiting with timeouts,
# signal emission assertion spies, test registration, lifecycle hooks (before_each,
# after_each), and quantitative zero-leak verification.
#
# Can be used directly in game projects, standalone test runners, redistributable
# addons, and live in-editor @tool test scripts.
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

    # Encapsulates the execution result of a single registered test case
    record TestResult, category : String, name : String, passed : Bool, message : String = "", duration_ms : Float64 = 0.0

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

    # Asserts that a SignalSpy recorded exactly the expected number of emissions
    def assert_signal_count(spy : SignalSpy, count : Int32, msg : String = "", file : String = __FILE__, line : Int32 = __LINE__)
      actual = spy.count
      if actual != count
        detail = msg.empty? ? "Expected signal '#{spy.signal_name}' to emit #{count} time(s), but emitted #{actual} time(s)" : "#{msg} (Expected #{count}, got #{actual})"
        raise AssertionError.new(detail, file, line)
      end
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
    # 3. Quantitative Zero-Leak Apparatus
    # ===========================================================================

    # Executes the provided block and asserts that Godot ObjectDB object and node counts
    # return to baseline after Boehm GC collection and frame draining.
    def assert_no_leak(max_delta_objects : Int32 = 0, name : String = "Operation", file : String = __FILE__, line : Int32 = __LINE__, &block)
      GC.collect
      skip_frames(2)
      perf = Godot::Performance.instance
      # 0 is Performance::OBJECT_COUNT, 2 is Performance::OBJECT_NODE_COUNT
      baseline_objects = perf.get_monitor(0_i64).to_i64
      baseline_nodes = perf.get_monitor(2_i64).to_i64

      yield

      GC.collect
      skip_frames(3)
      final_objects = perf.get_monitor(0_i64).to_i64
      final_nodes = perf.get_monitor(2_i64).to_i64

      delta_objects = final_objects - baseline_objects
      delta_nodes = final_nodes - baseline_nodes

      if delta_objects > max_delta_objects || delta_nodes > max_delta_objects
        detail = "Memory leak detected during '#{name}'!\n" \
                 "  Object count delta: #{delta_objects} (baseline: #{baseline_objects}, final: #{final_objects})\n" \
                 "  Node count delta: #{delta_nodes} (baseline: #{baseline_nodes}, final: #{final_nodes})"
        raise AssertionError.new(detail, file, line)
      end
    end

    # ===========================================================================
    # 4. Automatic Node Tracking & Fixtures Helper
    # ===========================================================================

    @@tracked_nodes = Array(Godot::Node).new

    # Registers a node to be automatically destroyed and cleaned up in after_each
    def track_node(node : Godot::Node) : Godot::Node
      @@tracked_nodes << node
      node
    end

    # Cleans up all tracked nodes created during a test
    def cleanup_tracked_nodes : Void
      @@tracked_nodes.reverse_each do |n|
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
      @@tracked_nodes.clear
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
    # 5. Async Frame Stepping & Timeout Mechanics
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
    # 6. Signal Recording and Spy Helper
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
    # 7. Centralized Extensible Test Registry & Lifecycle Runner
    # ===========================================================================

    class TestCase
      getter category : String
      getter name : String
      getter file : String
      getter line : Int32
      @block : (Godot::Node -> Void)

      def initialize(@category : String, @name : String, @file : String = "", @line : Int32 = 0, &@block : Godot::Node -> Void)
      end

      def execute(context_node : Godot::Node) : TestResult
        Godot.print("  [Running] [#{@category}] #{@name}...")
        start = ::Time.instant
        begin
          # Run before_each hooks
          Registry.run_before_each(@category, context_node)

          @block.call(context_node)

          duration = (::Time.instant - start).total_milliseconds
          TestResult.new(@category, @name, true, "PASS", duration)
        rescue ex : AssertionError
          duration = (::Time.instant - start).total_milliseconds
          TestResult.new(@category, @name, false, ex.message || "Assertion failed", duration)
        rescue ex : Exception
          duration = (::Time.instant - start).total_milliseconds
          Godot.print("[ERROR] #{ex.inspect_with_backtrace}")
          TestResult.new(@category, @name, false, "ERROR: #{ex.class.name}: #{ex.message}\n#{ex.backtrace.join("\n")}", duration)
        ensure
          # Run after_each hooks
          Registry.run_after_each(@category, context_node)
          # Clean up any nodes tracked via track_node during this test
          Lapis::Test.cleanup_tracked_nodes
        end
      end
    end

    class Registry
      @@tests = Array(TestCase).new
      @@before_each_hooks = Hash(String, Array(Godot::Node -> Void)).new
      @@after_each_hooks = Hash(String, Array(Godot::Node -> Void)).new

      def self.register(category : String, name : String, file : String = "", line : Int32 = 0, &block : Godot::Node -> Void)
        @@tests << TestCase.new(category, name, file, line, &block)
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
        for_category(category).each do |test|
          next if filter && !filter.empty? && !test.name.includes?(filter)
          results << test.execute(context_node)
        end
        results
      end

      def self.run_all(context_node : Godot::Node, filter : String? = nil, category_filter : String? = nil) : Array(TestResult)
        results = Array(TestResult).new
        cat_norm = category_filter ? category_filter.downcase.sub(/^test_?/, "") : nil
        @@tests.each do |test|
          if cat_norm && !cat_norm.empty?
            t_cat = test.category.downcase.sub(/^test_?/, "")
            next if t_cat != cat_norm
          end
          next if filter && !filter.empty? && !test.name.downcase.includes?(filter.downcase)
          results << test.execute(context_node)
        end
        results
      end

      def self.clear : Void
        @@tests.clear
        @@before_each_hooks.clear
        @@after_each_hooks.clear
      end
    end
  end
end

include Lapis::Test

module Godot
  alias Test = ::Lapis::Test
end

# =============================================================================
# 8. Declarative Suite & Test DSL Macros
# =============================================================================

# Modern declarative suite macro allowing grouped tests and category-scoped lifecycle hooks
macro test_suite(category, &block)
  {% for exp in block.body.expressions %}
    {% if exp.is_a?(Call) && exp.name == "test" %}
      ::Lapis::Test::Registry.register({{category}}, {{exp.args[0]}}, {{exp.filename}}, {{exp.line_number}}) do |node|
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
    {% else %}
      {{exp}}
    {% end %}
  {% end %}
end

# Base test_case macro
macro test_case(category, name, &block)
  ::Lapis::Test::Registry.register({{category}}, {{name}}, __FILE__, __LINE__) do |node|
    root = node
    {{block.body}}
  end
end

# Backwards-compatible domain-specific category macros
{% for pair in [
                 {:test_core, "Core"},
                 {:test_2d, "2D"},
                 {:test_3d, "3D"},
                 {:test_prop, "Properties"},
                 {:test_nodes, "Nodes"},
                 {:test_deferred, "Deferred"},
                 {:test_signals, "Signals"},
                 {:test_gdscript, "GDScript"},
                 {:test_mesh, "Mesh"},
                 {:test_physics, "Physics"},
                 {:test_stress, "Stress"},
                 {:test_scenes, "Scenes"},
                 {:test_concurrency, "Concurrency"},
                 {:test_macros_dsl, "MacrosDSL"},
                 {:test_reentrancy, "Reentrancy"},
                 {:test_duplication, "Duplication"},
                 {:test_callable_adv, "CallableAdv"},
                 {:test_dynamic_props, "DynamicProps"},
                 {:test_thread_safety, "ThreadSafety"},
                 {:test_polymorphism, "Polymorphism"},
                 {:test_undo_redo, "UndoRedo"},
                 {:test_standalone_portable, "StandalonePortable"},
                 {:test_shader, "Shaders"},
                 {:test_material, "Materials"},
                 {:test_geometry, "Geometry"},
                 {:test_camera, "Cameras"},
                 {:test_viewport, "Viewports"},
                 {:test_tween, "Tweens"},
                 {:test_audio_server, "AudioServer"},
                 {:test_async_testing, "AsyncTesting"},
                 {:test_dead_pointer_safety, "DeadPointerSafety"},
                 {:test_script_first_class, "ScriptFirstClass"},
                 {:test_resource_deep, "ResourceDeep"},
                 {:test_resources, "Resources"},
                 {:test_multi_addon, "MultiAddon"},
                 {:test_lifecycle, "Lifecycle"},
                 {:test_debugger, "Debugger"},
                 {:test_ui, "UI"},
                 {:test_classdb, "ClassDB"},
                 {:test_audio_anim, "AudioAnim"},
                 {:test_packed_arrays, "PackedArrays"},
                 {:test_variant_math, "VariantMath"},
                 {:test_memory_cyclic, "MemoryCyclic"},
                 {:test_servers_rid, "ServersRID"},
                 {:test_virtual_methods, "VirtualMethods"},
                 {:test_concurrency_stress, "ConcurrencyStress"},
               ] %}
  macro {{pair[0].id}}(name, &block)
    ::Lapis::Test::Registry.register({{pair[1]}}, \{{name}}, __FILE__, __LINE__) do |node|
      root = node
      \{{block.body}}
    end
  end
{% end %}
