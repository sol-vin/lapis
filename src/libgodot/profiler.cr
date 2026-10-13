# =============================================================================
# LibGodot - Two-Tier Zero-Allocation Profiling & Hot Loop Assertion Framework
# =============================================================================
# Orchestrates low-level GC snapshotting and high-level declarative audit DSL.
# =============================================================================

require "./profiler/core/snapshot"
require "./profiler/core/report"
require "./profiler/core/probe"
require "./profiler/dsl/builder"
require "./profiler/dsl/macros"
