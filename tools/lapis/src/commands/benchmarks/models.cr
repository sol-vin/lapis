module Lapis
  module Commands
    module Benchmarks
      enum Category
        Compute
        EngineCore
        Toolchain
        Custom

        def display_name : String
          case self
          in Compute    then "Compute"
          in EngineCore then "EngineCore"
          in Toolchain  then "Toolchain"
          in Custom     then "Custom"
          end
        end

        def self.parse_str(str : String) : Category
          case str.downcase
          when "compute", "comp"
            Compute
          when "engine", "enginecore", "engine_core", "core"
            EngineCore
          when "toolchain", "tools", "compiler", "compilation"
            Toolchain
          else
            Custom
          end
        end
      end

      record ComparisonGroupSpec,
        name : String,
        category : Category,
        description : String,
        baseline : String,
        target_names : Array(String),
        kind : Symbol = :runtime,
        chart_types : Array(Symbol) = [:bar, :speedup, :ratio, :log]

      record BenchmarkCase,
        name : String,
        category : Category,
        crystal_src : String,
        crystal_bin : String,
        gdscript_src : String,
        args : Array(String),
        description : String,
        cpp_src : String? = nil,
        csharp_src : String? = nil,
        rust_src : String? = nil,
        group_name : String? = nil,
        group_kind : Symbol = :runtime,
        chart_types : Array(Symbol) = [:bar, :speedup, :ratio, :log],
        subgroup : String? = nil

      record BenchmarkMetric,
        name : String,
        category : Category,
        crystal_ms : Float64,
        gdscript_ms : Float64,
        speedup : Float64,
        description : String,
        editor_ms : Float64? = nil,
        editor_overhead_ratio : Float64? = nil,
        cpp_ms : Float64? = nil,
        csharp_ms : Float64? = nil,
        rust_ms : Float64? = nil,
        group_name : String? = nil,
        baseline_name : String? = nil,
        custom_metrics : Hash(String, Float64) = Hash(String, Float64).new,
        group_kind : Symbol = :runtime,
        chart_types : Array(Symbol) = [:bar, :speedup, :ratio, :log],
        subgroup : String? = nil

      record BenchmarkResult,
        benchmark : BenchmarkCase,
        crystal_samples : Array(Float64),
        gdscript_samples : Array(Float64),
        crystal_ms : Float64,
        gdscript_ms : Float64,
        crystal_min_ms : Float64,
        crystal_max_ms : Float64,
        gdscript_min_ms : Float64,
        gdscript_max_ms : Float64,
        speedup : Float64,
        editor_samples : Array(Float64) = [] of Float64,
        editor_ms : Float64? = nil,
        editor_overhead_ratio : Float64? = nil,
        cpp_ms : Float64? = nil,
        csharp_ms : Float64? = nil,
        rust_ms : Float64? = nil,
        group_name : String? = nil,
        custom_metrics : Hash(String, Float64) = Hash(String, Float64).new,
        group_kind : Symbol = :runtime,
        chart_types : Array(Symbol) = [:bar, :speedup, :ratio, :log],
        subgroup : String? = nil do
        def name : String
          benchmark.name
        end

        def category : Category
          benchmark.category
        end

        def description : String
          benchmark.description
        end

        def to_metric : BenchmarkMetric
          BenchmarkMetric.new(
            name: name,
            category: category,
            crystal_ms: crystal_ms,
            gdscript_ms: gdscript_ms,
            speedup: speedup,
            description: description,
            editor_ms: editor_ms,
            editor_overhead_ratio: editor_overhead_ratio,
            cpp_ms: cpp_ms,
            csharp_ms: csharp_ms,
            rust_ms: rust_ms,
            group_name: group_name || benchmark.group_name,
            custom_metrics: custom_metrics,
            group_kind: group_kind != :runtime ? group_kind : benchmark.group_kind,
            chart_types: !chart_types.empty? ? chart_types : benchmark.chart_types,
            subgroup: subgroup || benchmark.subgroup
          )
        end
      end
    end
  end
end
