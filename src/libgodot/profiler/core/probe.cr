# =============================================================================
# LibGodot - Zero-Allocation Profiler: Execution Probe Engine (Core Engine Tier)
# =============================================================================
# Low-level execution harness providing microsecond-precision, zero-probe-overhead
# allocation measurement across warm-up and hot loop iterations.
# =============================================================================

require "./snapshot"
require "./report"

module Lapis
  module Profiler
    module AllocationProbe
      extend self

      # Executes the given block across warm-up and measurement iterations,
      # capturing total heap bytes allocated with zero probe measurement overhead.
      #
      # Parameters:
      # - `name`: Label for the benchmark or hot loop.
      # - `iterations`: Number of hot loop iterations to execute during the measured window.
      # - `warmup`: Number of pre-run iterations to execute before taking the initial snapshot.
      # - `threshold_bytes`: Maximum allowed byte ceiling (0 for strict zero-allocation).
      #
      # The block can optionally accept the current iteration index (`idx : Int32`).
      def run(
        name : String = "Hot Loop",
        iterations : Int32 = 1000,
        warmup : Int32 = 10,
        threshold_bytes : Int64 = 0_i64,
        &
      ) : AllocationReport
        # 1. Warm-up Phase: Pre-heat branch predictors, CPU instruction caches, and runtime tables
        if warmup > 0
          w = 0
          while w < warmup
            yield w
            w += 1
          end
        end

        # 2. Preparation: Collect any warm-up debris and suppress collection during measurement
        GC.collect
        was_disabled = {% if @top_level.has_constant?(:LibGC) %} LibGC.is_disabled != 0 {% else %} false {% end %}
        GC.disable unless was_disabled

        snapshot_before = AllocationSnapshot.capture
        start_time = ::Time.instant

        # 3. Hot Execution Loop: Zero measurement overhead yielding inlined block
        begin
          idx = 0
          while idx < iterations
            yield idx
            idx += 1
          end
        ensure
          snapshot_after = AllocationSnapshot.capture
          elapsed = ::Time.instant - start_time
          GC.enable unless was_disabled
        end

        delta = snapshot_after.delta_from(snapshot_before)
        AllocationReport.new(
          name: name,
          iterations: iterations,
          warmup_cycles: warmup,
          bytes_allocated: delta.bytes_allocated,
          duration: elapsed,
          threshold_bytes: threshold_bytes
        )
      end
    end
  end
end
