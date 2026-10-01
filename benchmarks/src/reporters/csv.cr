require "csv"
require "file_utils"
require "./base"

module Benchmarks
  module Reporters
    class Csv < Base
      property output_rel_path : String = "results/benchmark_report.csv"

      def name : String
        "csv"
      end

      def initialize(@output_rel_path : String = "results/benchmark_report.csv")
      end

      def report(results : Array(BenchmarkResult), base_dir : String) : Nil
        return if results.empty?

        csv_str = CSV.build do |csv|
          csv.row "Benchmark", "Category", "Crystal (ms)", "GDScript (ms)", "Speedup Factor", "Description"
          results.each do |r|
            csv.row(
              r.name,
              r.category.display_name,
              r.crystal_ms.round(2).to_s,
              r.gdscript_ms.round(2).to_s,
              r.speedup.round(2).to_s,
              r.description
            )
          end
        end

        out_path = File.join(base_dir, @output_rel_path)
        FileUtils.mkdir_p(File.dirname(out_path))
        File.write(out_path, csv_str)
        puts "  \e[32m[Report]\e[0m Saved CSV report to: #{out_path}"
      end
    end
  end
end
