module Benchmarks
  enum Category
    Compute
    EngineCore

    def display_name : String
      case self
      in Compute    then "Compute"
      in EngineCore then "EngineCore"
      end
    end
  end

  record BenchmarkCase,
    name : String,
    category : Category,
    crystal_src : String,
    crystal_bin : String,
    gdscript_src : String,
    args : Array(String),
    description : String

  record BenchmarkMetric,
    name : String,
    category : Category,
    crystal_ms : Float64,
    gdscript_ms : Float64,
    speedup : Float64,
    description : String

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
    speedup : Float64 do

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
        description: description
      )
    end
  end
end
