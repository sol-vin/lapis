# =============================================================================
# LibGodot - Zero-Allocation Profiler: Declarative Audit Builder (DSL Tier)
# =============================================================================
# Fluent block builder yielding a configured probe context for clean, readable
# ergonomics in benchmarks, game loops, and custom test suites.
# =============================================================================

require "../core/probe"

module Lapis
  module Profiler
    # Declarative Builder DSL for configuring allocation audits and profiling runs
    class AuditBuilder
      property name : String = "Hot Loop"
      property iterations : Int32 = 1000
      property warmup_cycles : Int32 = 10
      property max_bytes : Int64 = 0_i64

      def initialize(@name : String = "Hot Loop")
      end

      # Sets the audit label or operation name
      def name(val : String) : self
        @name = val
        self
      end

      # Sets the number of measured hot loop iterations
      def iterations(val : Int32) : self
        @iterations = val
        self
      end

      # Sets the number of warm-up iterations
      def warmup(val : Int32) : self
        @warmup_cycles = val
        self
      end

      # Sets the maximum permitted bytes allocated before failing
      def max_bytes(val : Int64 | Int32) : self
        @max_bytes = val.to_i64
        self
      end

      # Runs the hot loop profiling probe and returns the resulting report
      def profile(&) : AllocationReport
        AllocationProbe.run(
          name: @name,
          iterations: @iterations,
          warmup: @warmup_cycles,
          threshold_bytes: @max_bytes
        ) do |i|
          yield i
        end
      end

      # Executes the loop and raises AllocationViolationError if any bytes were allocated
      def assert_zero_allocation(file : String = __FILE__, line : Int32 = __LINE__, &) : AllocationReport
        report = profile do |i|
          yield i
        end
        unless report.zero_allocation?
          raise AllocationViolationError.new(report, 0_i64, file, line)
        end
        report
      end

      # Executes the loop and raises AllocationViolationError if allocations exceed max_bytes
      def assert_max_allocations(max : Int64 | Int32 = @max_bytes, file : String = __FILE__, line : Int32 = __LINE__, &) : AllocationReport
        target_max = max.to_i64
        report = profile do |i|
          yield i
        end
        if report.bytes_allocated > target_max
          raise AllocationViolationError.new(report, target_max, file, line)
        end
        report
      end
    end
  end
end
