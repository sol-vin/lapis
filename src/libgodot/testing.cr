# =============================================================================
# LibGodot - Reusable Testing Apparatus & Assertion Framework
# =============================================================================
#
# Provides an extensible, full-featured testing framework for Crystal in Godot.
# Supports standard assertion matchers, async frame-stepping, signal awaiting with
# configurable timeouts, signal emission assertion spies, and test registration.
#
# Can be used directly in game projects, standalone test runners, redistributable
# addons, and live in-editor @tool test scripts.
# =============================================================================

module Lapis
  module Test
  # Base exception raised on assertion failures
  class AssertionError < Exception
  end

  # Exception raised when an asynchronous operation or signal await exceeds its timeout deadline
  class TimeoutError < AssertionError
  end

  # Encapsulates the execution result of a single registered test case
  record TestResult, category : String, name : String, passed : Bool, message : String = "", duration_ms : Float64 = 0.0

  # ===========================================================================
  # 1. Assertion Matchers
  # ===========================================================================

  # Asserts that the boolean condition evaluates to true
  def self.assert_true(cond : Bool, msg : String = "Expected true, got false")
    raise AssertionError.new(msg) unless cond
  end

  # Asserts that the boolean condition evaluates to false
  def self.assert_false(cond : Bool, msg : String = "Expected false, got true")
    raise AssertionError.new(msg) if cond
  end

  # Asserts that two values are equal using Crystal's == operator
  def self.assert_eq(actual, expected, msg : String = "")
    if actual != expected
      detail = msg.empty? ? "Expected #{expected.inspect}, got #{actual.inspect}" : "#{msg} (Expected #{expected.inspect}, got #{actual.inspect})"
      raise AssertionError.new(detail)
    end
  end

  # Asserts that two floating-point values are approximately equal within a tolerance epsilon
  def self.assert_approx_eq(actual : Float32 | Float64, expected : Float32 | Float64, epsilon : Float64 = 0.001, msg : String = "")
    diff = (actual - expected).abs
    if diff > epsilon
      detail = msg.empty? ? "Expected ~#{expected}, got #{actual} (diff #{diff})" : "#{msg} (Expected ~#{expected}, got #{actual})"
      raise AssertionError.new(detail)
    end
  end

  # Asserts that a value is non-nil
  def self.assert_not_nil(val, msg : String = "Expected non-nil value")
    raise AssertionError.new(msg) if val.nil?
  end

  # Asserts that a value is nil
  def self.assert_nil(val, msg : String = "Expected nil value")
    raise AssertionError.new(msg) unless val.nil?
  end

  # Asserts that evaluating the block raises an exception of the expected class T
  def self.assert_raises(klass : T.class, msg : String = "", &block) forall T
    begin
      yield
    rescue ex : T
      return ex
    rescue ex : Exception
      detail = msg.empty? ? "Expected #{T.name} to be raised, but got #{ex.class.name}: #{ex.message}" : "#{msg} (Expected #{T.name}, got #{ex.class.name})"
      raise AssertionError.new(detail)
    end
    detail = msg.empty? ? "Expected #{T.name} to be raised, but no exception was raised" : "#{msg} (Expected #{T.name})"
    raise AssertionError.new(detail)
  end

  # Asserts that a collection contains the specified item
  def self.assert_includes(collection, item, msg : String = "")
    unless collection.includes?(item)
      detail = msg.empty? ? "Expected collection to include #{item.inspect}, but it was absent" : "#{msg} (Missing #{item.inspect})"
      raise AssertionError.new(detail)
    end
  end

  # Asserts that a numeric value is within delta of the expected value
  def self.assert_in_delta(actual : Number, expected : Number, delta : Number, msg : String = "")
    diff = (actual - expected).abs
    if diff > delta
      detail = msg.empty? ? "Expected #{actual} to be within #{delta} of #{expected} (diff #{diff})" : "#{msg} (Expected #{actual} within #{delta} of #{expected})"
      raise AssertionError.new(detail)
    end
  end

  # Asserts that a numeric value falls within the inclusive range [min, max]
  def self.assert_between(actual : Number, min : Number, max : Number, msg : String = "")
    if actual < min || actual > max
      detail = msg.empty? ? "Expected #{actual} to be between #{min} and #{max}" : "#{msg} (Expected #{actual} between #{min} and #{max})"
      raise AssertionError.new(detail)
    end
  end

  # Temporarily suppresses engine error printing to stdout/stderr while evaluating the block
  def self.suppress_errors(&block)
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
  # 2. Async Frame Stepping & Timeout Mechanics
  # ===========================================================================

  # Cooperatively yields until the specified number of process (render/idle) frames have elapsed
  def self.skip_frames(count : Int32 = 1) : Void
    count.times do
      Fiber.yield
    end
  end

  # Cooperatively yields until the specified number of fixed physics frames have elapsed
  def self.skip_physics_frames(count : Int32 = 1) : Void
    count.times do
      Fiber.yield
    end
  end

  # Cooperatively awaits a signal on the target emitter.
  # If the signal is not received within `timeout_sec`, raises a descriptive `TimeoutError`.
  # Returns the emitted arguments as an Array(Variant).
  def self.await_signal(emitter : Godot::Object, signal_name : String, timeout_sec : Float64 = 2.0) : ::Array(Variant)
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
          raise TimeoutError.new("Timed out after #{timeout_sec}s waiting for signal '#{signal_name}' on #{emitter.class.name} (ID: #{emitter.instance_id})")
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
  def self.assert_emits(emitter : Godot::Object, signal_name : String, timeout_sec : Float64 = 2.0, &block) : ::Array(Variant)
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
          raise AssertionError.new("Expected signal '#{signal_name}' on #{emitter.class.name} within #{timeout_sec}s, but it was not received.")
        end
        Fiber.yield
      end
      sub.args
    ensure
      Godot.unsubscribe_signal(sub)
    end
  end

  # Executes the provided block and verifies that the specified signal is NOT emitted during `duration_sec`.
  def self.assert_no_emit(emitter : Godot::Object, signal_name : String, duration_sec : Float64 = 0.5, &block) : Void
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
          raise AssertionError.new("Expected signal '#{signal_name}' NOT to be emitted, but it fired with args: #{sub.args.inspect}")
        end
        Fiber.yield
      end
    ensure
      Godot.unsubscribe_signal(sub)
    end
  end

  # Executes a block with an active timeout watchdog, raising `TimeoutError` if it fails to finish in time
  def self.with_timeout(timeout_sec : Float64 = 5.0, operation_name : String = "Operation", &block)
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
        raise TimeoutError.new("#{operation_name} timed out after #{timeout_sec}s")
      end
      Fiber.yield
    end
    if e = err
      raise e
    end
  end

  # ===========================================================================
  # 3. Signal Recording and Spy Helper
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
  # 4. Centralized Extensible Test Registry
  # ===========================================================================

  class TestCase
    getter category : String
    getter name : String
    @block : (Godot::Node -> Void)

    def initialize(@category : String, @name : String, &@block : Godot::Node -> Void)
    end

    def execute(context_node : Godot::Node) : TestResult
      Godot.print("  [Running] [#{@category}] #{@name}...")
      start = ::Time.instant
      begin
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
      end
    end
  end

  class Registry
    @@tests = Array(TestCase).new

    def self.register(category : String, name : String, &block : Godot::Node -> Void)
      @@tests << TestCase.new(category, name, &block)
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
    end
  end
  end
end

alias TestFramework = ::Lapis::Test

module Godot
  alias Test = ::Lapis::Test
end

# =============================================================================
# 5. Declarative DSL Macros
# =============================================================================

# Base test_case macro
macro test_case(category, name, &block)
  ::Lapis::Test::Registry.register({{category}}, {{name}}) do |node|
    root = node
    {{block.body}}
  end
end

# Domain-specific category macros
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
] %}
  macro {{pair[0].id}}(name, &block)
    ::Lapis::Test::Registry.register({{pair[1]}}, \{{name}}) do |node|
      root = node
      \{{block.body}}
    end
  end
{% end %}
