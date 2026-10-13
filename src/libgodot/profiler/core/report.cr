# =============================================================================
# LibGodot - Zero-Allocation Profiler: Report & Error Primitives (Core Engine Tier)
# =============================================================================
# Pure structs and exception definitions for allocation audit results.
# Generates rich diagnostic messages with throughput and actionable guidance.
# =============================================================================

require "time"

module Lapis
  module Profiler
    # Represents the comprehensive audit results of an allocation profiling execution.
    struct AllocationReport
      getter name : String
      getter iterations : Int32
      getter warmup_cycles : Int32
      getter bytes_allocated : Int64
      getter duration : ::Time::Span
      getter threshold_bytes : Int64

      def initialize(
        @name : String,
        @iterations : Int32,
        @warmup_cycles : Int32,
        @bytes_allocated : Int64,
        @duration : ::Time::Span,
        @threshold_bytes : Int64 = 0_i64
      )
      end

      # Returns true if exactly zero heap bytes were allocated during the execution.
      def zero_allocation? : Bool
        @bytes_allocated == 0_i64
      end

      # Returns true if total allocations remained under the designated threshold.
      def passed? : Bool
        @bytes_allocated <= @threshold_bytes
      end

      # Calculates the average bytes allocated per loop iteration.
      def bytes_per_iteration : Float64
        return 0.0 if @iterations <= 0
        @bytes_allocated.to_f64 / @iterations.to_f64
      end

      # Calculates loop throughput in operations (iterations) per second.
      def throughput_ops_sec : Float64
        secs = @duration.total_seconds
        return 0.0 if secs <= 0.0
        @iterations.to_f64 / secs
      end

      # Generates a detailed diagnostic failure report with actionable troubleshooting steps.
      def failure_message(expected_max : Int64 = 0_i64) : String
        rate = sprintf("%.2f", bytes_per_iteration)
        dur_ms = sprintf("%.3f", @duration.total_milliseconds)
        ops_sec = sprintf("%.1f", throughput_ops_sec)
        String.build do |io|
          io << "Allocation Assertion Failed for '#{@name}'!\n"
          io << "  Expected: <= #{expected_max} bytes allocated\n"
          io << "  Actual:   #{@bytes_allocated} bytes allocated across #{@iterations} iterations (#{rate} B/iter)\n"
          io << "  Duration: #{dur_ms} ms (#{ops_sec} ops/sec, #{@warmup_cycles} warmup cycles)\n"
          io << "  Diagnosis: Hot loop violated zero-allocation policy. Check for:\n"
          io << "    - Closure variable capture (allocates heap environment)\n"
          io << "    - String interpolation or dynamic formatting\n"
          io << "    - Heap-allocated collections (Array/Hash literals)\n"
          io << "    - Boxed structs or dynamic virtual dispatch\n"
        end
      end

      # Formats a single-line summary string for logging and CLI output.
      def to_s(io : IO) : Void
        status = passed? ? "[PASS]" : "[FAIL]"
        rate = sprintf("%.2f", bytes_per_iteration)
        dur_ms = sprintf("%.2f", @duration.total_milliseconds)
        io << "#{status} #{@name}: #{@bytes_allocated}B allocated (#{@iterations} iters, #{rate} B/op, #{dur_ms}ms)"
      end
    end

    # Exception raised when a zero-allocation or bounded-allocation assertion fails.
    {% if @top_level.has_constant?(:Spec) && Spec.has_constant?(:AssertionFailed) %}
      class AllocationViolationError < ::Spec::AssertionFailed
        getter report : AllocationReport

        def initialize(@report : AllocationReport, expected_max : Int64 = 0_i64, file : String = "", line : Int32 = 0)
          super(@report.failure_message(expected_max), file, line)
        end
      end
    {% else %}
      class AllocationViolationError < Exception
        getter file : String
        getter line : Int32
        getter report : AllocationReport

        def initialize(@report : AllocationReport, expected_max : Int64 = 0_i64, @file : String = "", @line : Int32 = 0)
          full_msg = if !@file.empty? && @line > 0
                       "#{@report.failure_message(expected_max)} (at #{@file}:#{@line})"
                     else
                       @report.failure_message(expected_max)
                     end
          super(full_msg)
        end
      end
    {% end %}
  end
end
