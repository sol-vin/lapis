# =============================================================================
# LibGodot - Homogeneous In-Engine Benchmarks Framework
# =============================================================================
# Provides a high-performance benchmarking DSL that can execute both inside
# the Godot editor, in standalone test runners, or be completely eliminated
# at compile time for production release builds (Steam / Itch) via -Dno_benchmarks.

module Lapis
  module Benchmark
    {% unless flag?(:no_benchmarks) %}
      enum Category
        Compute
        Engine
        Custom

        def display_name : String
          case self
          in Compute then "Compute"
          in Engine  then "Engine"
          in Custom  then "Custom"
          end
        end
      end

      record Case,
        name : String,
        category : Category,
        description : String,
        block : Proc(Int32, Nil)

      record Result,
        name : String,
        category : Category,
        iterations : Int32,
        samples_ms : Array(Float64),
        median_ms : Float64,
        min_ms : Float64,
        max_ms : Float64

      @@cases = [] of Case

      # Register a benchmark case in Crystal
      def self.register(
        name : String,
        category : Category = Category::Custom,
        description : String = "",
        &block : Int32 -> Nil
      ) : Nil
        @@cases << Case.new(name, category, description, block)
      end

      # Return all registered benchmarks
      def self.all : Array(Case)
        @@cases
      end

      # Clear benchmark registry
      def self.clear : Nil
        @@cases.clear
      end

      # Measure a single benchmark case across N iterations
      def self.run_case(c : Case, iterations : Int32 = 3) : Result
        samples = [] of Float64
        iterations.times do |iter|
          start = ::Time.instant
          c.block.call(iter)
          elapsed = (::Time.instant - start).total_milliseconds
          samples << elapsed
        end
        sorted = samples.sort
        median = sorted[sorted.size // 2]
        Result.new(c.name, c.category, iterations, samples, median, sorted.first, sorted.last)
      end

      # Run all registered benchmarks
      def self.run_all(iterations : Int32 = 3) : Array(Result)
        @@cases.map { |c| run_case(c, iterations) }
      end
    {% else %}
      # Benchmark framework completely compiled out via -Dno_benchmarks flag
      def self.register(name : String, category = nil, description = "", &block) : Nil
        # No-op in release
      end

      def self.all
        [] of Nil
      end

      def self.run_all(iterations : Int32 = 3)
        [] of Nil
      end

      def self.clear : Nil
      end
    {% end %}
  end
end
