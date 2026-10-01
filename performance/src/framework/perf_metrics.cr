# =============================================================================
# LibGodot Performance Benchmark - Metrics Telemetry Sampler
# =============================================================================

require "lapis"

{% if flag?(:windows) %}
  @[Link("kernel32")]
  @[Link("psapi")]
  lib LibPsapi
    struct PROCESS_MEMORY_COUNTERS
      cb : UInt32
      page_fault_count : UInt32
      peak_working_set_size : LibC::SizeT
      working_set_size : LibC::SizeT
      quota_peak_paged_pool_usage : LibC::SizeT
      quota_paged_pool_usage : LibC::SizeT
      quota_peak_non_paged_pool_usage : LibC::SizeT
      quota_non_paged_pool_usage : LibC::SizeT
      pagefile_usage : LibC::SizeT
      peak_pagefile_usage : LibC::SizeT
    end

    fun GetCurrentProcess : Void*
    fun GetProcessMemoryInfo(hProcess : Void*, ppsmps : PROCESS_MEMORY_COUNTERS*, cb : UInt32) : LibC::BOOL
  end
{% end %}

module PerfFramework
  struct MetricSnapshot
    property fps : Float64
    property frame_time_ms : Float64
    property physics_time_ms : Float64
    property static_ram_mb : Float64
    property peak_ram_mb : Float64
    property crystal_gc_mb : Float64
    property crystal_gc_active_mb : Float64
    property crystal_gc_heap_mb : Float64
    property crystal_gc_free_mb : Float64
    property crystal_total_alloc_mb : Float64
    property os_working_set_mb : Float64
    property os_commit_mb : Float64
    property object_count : Int64
    property node_count : Int64
    property orphan_count : Int64
    property resource_count : Int64
    property timestamp_sec : Float64

    def initialize(
      @fps : Float64 = 0.0,
      @frame_time_ms : Float64 = 0.0,
      @physics_time_ms : Float64 = 0.0,
      @static_ram_mb : Float64 = 0.0,
      @peak_ram_mb : Float64 = 0.0,
      @crystal_gc_mb : Float64 = 0.0,
      @crystal_gc_active_mb : Float64 = 0.0,
      @crystal_gc_heap_mb : Float64 = 0.0,
      @crystal_gc_free_mb : Float64 = 0.0,
      @crystal_total_alloc_mb : Float64 = 0.0,
      @os_working_set_mb : Float64 = 0.0,
      @os_commit_mb : Float64 = 0.0,
      @object_count : Int64 = 0_i64,
      @node_count : Int64 = 0_i64,
      @orphan_count : Int64 = 0_i64,
      @resource_count : Int64 = 0_i64,
      @timestamp_sec : Float64 = 0.0,
    )
    end
  end

  class MetricsSampler
    getter baseline : MetricSnapshot
    getter current : MetricSnapshot
    @start_time : Time::Instant

    def initialize
      @start_time = Time.instant
      @baseline = sample_now
      @current = @baseline
    end

    def reset_baseline
      GC.collect
      @baseline = sample_now
    end

    def sample_now : MetricSnapshot
      perf = Godot.performance

      # Godot built-in performance monitors
      fps = perf.get_monitor(0_i64)                  # TimeFps
      time_process = perf.get_monitor(1_i64)         # TimeProcess
      time_physics = perf.get_monitor(2_i64)         # TimePhysicsProcess
      mem_static = perf.get_monitor(4_i64)           # MemoryStatic
      mem_peak = perf.get_monitor(5_i64)             # MemoryStaticMax
      obj_count = perf.get_monitor(7_i64).to_i64     # ObjectCount
      res_count = perf.get_monitor(8_i64).to_i64     # ObjectResourceCount
      node_count = perf.get_monitor(9_i64).to_i64    # ObjectNodeCount
      orphan_count = perf.get_monitor(10_i64).to_i64 # ObjectOrphanNodeCount

      # Crystal Boehm GC heap metrics
      gc_heap_mb = 0.0_f64
      gc_active_mb = 0.0_f64
      gc_free_mb = 0.0_f64
      gc_total_mb = 0.0_f64

      begin
        stats = GC.stats
        heap_bytes = stats.heap_size
        free_bytes = stats.free_bytes
        active_bytes = heap_bytes >= free_bytes ? (heap_bytes - free_bytes) : 0_u64

        gc_heap_mb = heap_bytes.to_f64 / (1024.0 * 1024.0)
        gc_free_mb = free_bytes.to_f64 / (1024.0 * 1024.0)
        gc_active_mb = active_bytes.to_f64 / (1024.0 * 1024.0)
        gc_total_mb = stats.total_bytes.to_f64 / (1024.0 * 1024.0)
      rescue
        gc_heap_mb = 0.0_f64
        gc_active_mb = 0.0_f64
      end

      # Operating System physical working set and commit metrics
      os_ws_mb = 0.0_f64
      os_commit_mb = 0.0_f64

      {% if flag?(:windows) %}
        begin
          counters = LibPsapi::PROCESS_MEMORY_COUNTERS.new
          counters.cb = sizeof(LibPsapi::PROCESS_MEMORY_COUNTERS).to_u32
          if LibPsapi.GetProcessMemoryInfo(LibPsapi.GetCurrentProcess, pointerof(counters), counters.cb) != 0
            os_ws_mb = counters.working_set_size.to_f64 / (1024.0 * 1024.0)
            os_commit_mb = counters.pagefile_usage.to_f64 / (1024.0 * 1024.0)
          end
        rescue
        end
      {% end %}

      now_sec = (Time.instant - @start_time).total_seconds

      snap = MetricSnapshot.new(
        fps: fps,
        frame_time_ms: time_process * 1000.0,
        physics_time_ms: time_physics * 1000.0,
        static_ram_mb: mem_static / (1024.0 * 1024.0),
        peak_ram_mb: mem_peak / (1024.0 * 1024.0),
        crystal_gc_mb: gc_heap_mb,
        crystal_gc_active_mb: gc_active_mb,
        crystal_gc_heap_mb: gc_heap_mb,
        crystal_gc_free_mb: gc_free_mb,
        crystal_total_alloc_mb: gc_total_mb,
        os_working_set_mb: os_ws_mb,
        os_commit_mb: os_commit_mb,
        object_count: obj_count,
        node_count: node_count,
        orphan_count: orphan_count,
        resource_count: res_count,
        timestamp_sec: now_sec
      )
      @current = snap
      snap
    end

    def ram_delta_mb : Float64
      @current.static_ram_mb - @baseline.static_ram_mb
    end

    def crystal_gc_active_delta_mb : Float64
      @current.crystal_gc_active_mb - @baseline.crystal_gc_active_mb
    end

    def crystal_gc_heap_delta_mb : Float64
      @current.crystal_gc_heap_mb - @baseline.crystal_gc_heap_mb
    end

    def os_working_set_delta_mb : Float64
      @current.os_working_set_mb - @baseline.os_working_set_mb
    end

    def node_delta : Int64
      @current.node_count - @baseline.node_count
    end

    def object_delta : Int64
      @current.object_count - @baseline.object_count
    end
  end
end
