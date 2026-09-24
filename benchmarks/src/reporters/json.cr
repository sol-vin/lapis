require "json"
require "file_utils"
require "./base"

module Benchmarks
  module Reporters
    class Json < Base
      property output_rel_path : String = "results/benchmark_report.json"

      def name : String
        "json"
      end

      def initialize(@output_rel_path : String = "results/benchmark_report.json")
      end

      def report(results : Array(BenchmarkResult), base_dir : String) : Nil
        return if results.empty?
        metrics = results.map(&.to_metric)
        speedups = metrics.map(&.speedup)
        geo_mean = calculate_geo_mean(speedups)
        max_metric = metrics.max_by(&.speedup)

        json_str = JSON.build(indent: 2) do |json|
          json.object do
            json.field "timestamp", Time.utc.to_s
            json.field "total_benchmarks", results.size
            json.field "geometric_mean_speedup", geo_mean.round(2)
            json.field "peak_speedup", max_metric.speedup.round(2)
            json.field "peak_benchmark", max_metric.name

            json.field "benchmarks" do
              json.array do
                results.each do |r|
                  json.object do
                    json.field "name", r.name
                    json.field "category", r.category.display_name
                    json.field "description", r.description
                    json.field "crystal_ms", r.crystal_ms.round(2)
                    json.field "gdscript_ms", r.gdscript_ms.round(2)
                    json.field "speedup", r.speedup.round(2)
                    json.field "crystal_samples", r.crystal_samples
                    json.field "gdscript_samples", r.gdscript_samples
                  end
                end
              end
            end
          end
        end

        out_path = File.join(base_dir, @output_rel_path)
        FileUtils.mkdir_p(File.dirname(out_path))
        File.write(out_path, json_str)
        puts "  \e[32m[Report]\e[0m Saved JSON report to: #{out_path}"
      end
    end
  end
end
