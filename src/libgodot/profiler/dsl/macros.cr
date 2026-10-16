# =============================================================================
# LibGodot - Zero-Allocation Profiler: Ergonomic Entrypoints & Helpers (DSL Tier)
# =============================================================================
# Module methods and macros providing natural, expressive hooks for hot loop audits.
# =============================================================================

require "./builder"

module Lapis
  module Profiler
    # Declares a fluent audit configuration block yielding an AuditBuilder context.
    #
    # ```crystal
    # Lapis::Profiler.audit("Vector Transformation") do |audit|
    #   audit.iterations(50_000)
    #   audit.warmup(50)
    #   audit.assert_zero_allocation do
    #     v = v.cross(up).normalized
    #   end
    # end
    # ```
    def self.audit(name : String = "Hot Loop", &block : AuditBuilder ->)
      builder = AuditBuilder.new(name)
      yield builder
    end

    # Concise one-liner for measuring a hot loop with sensible defaults.
    #
    # ```crystal
    # report = Lapis::Profiler.hot_loop("Slerp", iterations: 10_000) do |i|
    #   q3 = q1.slerp(q2, 0.5_f32)
    # end
    # ```
    def self.hot_loop(
      name : String = "Hot Loop",
      iterations : Int32 = 10_000,
      warmup : Int32 = 10,
      max_bytes : Int64 = 0_i64,
      &
    ) : AllocationReport
      AllocationProbe.run(
        name: name,
        iterations: iterations,
        warmup: warmup,
        threshold_bytes: max_bytes
      ) do |i|
        yield i
      end
    end
  end
end
