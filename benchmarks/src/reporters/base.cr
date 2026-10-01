require "../models"

module Benchmarks
  module Reporters
    abstract class Base
      abstract def name : String
      abstract def report(results : Array(BenchmarkResult), base_dir : String) : Nil

      protected def calculate_geo_mean(speedups : Array(Float64)) : Float64
        return 1.0 if speedups.empty?
        valid_speedups = speedups.map { |s| s <= 0.0 ? 1.0 : s }
        Math.exp(valid_speedups.map { |s| Math.log(s) }.sum / valid_speedups.size)
      end
    end
  end
end
