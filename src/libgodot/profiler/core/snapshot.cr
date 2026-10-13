# =============================================================================
# LibGodot - Zero-Allocation Profiler: Snapshot & Delta Primitives (Core Engine Tier)
# =============================================================================
# Pure, strongly-typed structs representing point-in-time GC statistics and deltas.
# Designed for 100% allocation-free sampling during high-throughput hot loops.
# =============================================================================

require "time"

module Lapis
  module Profiler
    # Stack-allocated point-in-time snapshot of GC memory statistics.
    # Captures Boehm GC counters without triggering any heap allocations.
    struct AllocationSnapshot
      getter total_bytes : UInt64
      getter bytes_since_gc : UInt64
      getter heap_size : UInt64
      getter free_bytes : UInt64
      getter unmapped_bytes : UInt64
      getter timestamp : ::Time::Instant

      def initialize(
        @total_bytes : UInt64,
        @bytes_since_gc : UInt64,
        @heap_size : UInt64,
        @free_bytes : UInt64,
        @unmapped_bytes : UInt64,
        @timestamp : ::Time::Instant = ::Time.instant
      )
      end

      # Captures current GC state with zero heap allocations.
      def self.capture : AllocationSnapshot
        {% if @top_level.has_constant?(:LibGC) %}
          LibGC.get_heap_usage_safe(out heap_size, out free_bytes, out unmapped_bytes, out bytes_since_gc, out total_bytes)
          AllocationSnapshot.new(
            total_bytes: total_bytes.to_u64!,
            bytes_since_gc: bytes_since_gc.to_u64!,
            heap_size: heap_size.to_u64!,
            free_bytes: free_bytes.to_u64!,
            unmapped_bytes: unmapped_bytes.to_u64!,
            timestamp: ::Time.instant
          )
        {% else %}
          stats = GC.stats
          AllocationSnapshot.new(
            total_bytes: stats.total_bytes,
            bytes_since_gc: stats.bytes_since_gc,
            heap_size: stats.heap_size,
            free_bytes: stats.free_bytes,
            unmapped_bytes: stats.unmapped_bytes,
            timestamp: ::Time.instant
          )
        {% end %}
      end

      # Computes delta between this snapshot (after) and a prior snapshot (before).
      def delta_from(prior : AllocationSnapshot) : AllocationDelta
        bytes_allocated = @total_bytes >= prior.total_bytes ? (@total_bytes - prior.total_bytes).to_i64 : 0_i64
        bytes_since_gc_delta = @bytes_since_gc.to_i64 - prior.bytes_since_gc.to_i64
        heap_size_delta = @heap_size.to_i64 - prior.heap_size.to_i64
        duration = @timestamp - prior.timestamp

        AllocationDelta.new(
          bytes_allocated: bytes_allocated,
          bytes_since_gc_delta: bytes_since_gc_delta,
          heap_size_delta: heap_size_delta,
          duration: duration
        )
      end
    end

    # Stack-allocated delta between two snapshots.
    struct AllocationDelta
      getter bytes_allocated : Int64
      getter bytes_since_gc_delta : Int64
      getter heap_size_delta : Int64
      getter duration : ::Time::Span

      def initialize(
        @bytes_allocated : Int64,
        @bytes_since_gc_delta : Int64,
        @heap_size_delta : Int64,
        @duration : ::Time::Span
      )
      end

      # Returns true if zero heap bytes were allocated during the measured window.
      def zero_allocation? : Bool
        @bytes_allocated == 0_i64
      end
    end
  end
end
