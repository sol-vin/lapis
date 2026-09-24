require "./base"

module Benchmarks
  module Reporters
    class Console < Base
      def name : String
        "console"
      end

      def report(results : Array(BenchmarkResult), base_dir : String) : Nil
        return if results.empty?

        metrics = results.map(&.to_metric)
        speedups = metrics.map(&.speedup)
        geo_mean = calculate_geo_mean(speedups)
        peak_metric = metrics.max_by(&.speedup)

        puts "\n"
        puts "\e[1;36m========================================================================================================\e[0m"
        puts "\e[1;35m                       LAPIS BENCHMARK SUITE: CRYSTAL (NATIVE) VS GDSCRIPT                              \e[0m"
        puts "\e[1;36m========================================================================================================\e[0m"
        puts "  %-18s | %-12s | %-14s | %-14s | %s" % ["Benchmark", "Category", "Crystal (ms)", "GDScript (ms)", "Speedup Factor"]
        puts "  " + "-" * 100

        metrics.each do |m|
          cat_tag = m.category == Category::Compute ? "\e[34mCompute\e[0m" : "\e[35mEngineCore\e[0m"
          speedup_str = m.speedup >= 1.0 ? "\e[1;32m%6.1fx faster\e[0m" % m.speedup : "\e[1;33m%6.1fx slower\e[0m" % (1.0 / m.speedup)
          puts "  %-18s | %-21s | %11.2f ms | %11.2f ms | %s" % [m.name, cat_tag, m.crystal_ms, m.gdscript_ms, speedup_str]
        end

        puts "  " + "-" * 100
        puts "  \e[1mSummary:\e[0m Geometric Mean Speedup = \e[1;32m%.1fx faster\e[0m | Peak Speedup = \e[1;32m%.1fx faster\e[0m (%s)" % [
          geo_mean, peak_metric.speedup, peak_metric.name
        ]
        puts "  " + "-" * 100

        puts "\n\e[1mVisual Comparative Performance (Lower Execution Time is Faster):\e[0m\n"

        max_bar_width = 46
        metrics.each do |m|
          max_time = [m.crystal_ms, m.gdscript_ms].max
          max_time = 0.001 if max_time == 0.0

          cr_width = [1, ((m.crystal_ms / max_time) * max_bar_width).round.to_i].max
          gd_width = [1, ((m.gdscript_ms / max_time) * max_bar_width).round.to_i].max

          puts "  \e[1m#{m.name.ljust(18)}\e[0m \e[2m(#{m.description})\e[0m"
          puts "    \e[36mCrystal \e[0m : \e[36m#{"█" * cr_width}\e[0m %7.2f ms" % m.crystal_ms
          puts "    \e[33mGDScript\e[0m : \e[33m#{"█" * gd_width}\e[0m %7.2f ms (\e[1;32m%.1fx speedup\e[0m)" % [m.gdscript_ms, m.speedup]
          puts ""
        end
      end
    end
  end
end
