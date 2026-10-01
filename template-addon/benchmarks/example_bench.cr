# =============================================================================
# Addon Custom Benchmark Example (Crystal)
# =============================================================================

require "lapis"

count = (ARGV[0]? || "20000").to_i

Lapis::Benchmark.register("AddonNodeProcessing", category: Lapis::Benchmark::Category::Engine, description: "Addon node lifecycle iteration") do |iter|
  start_time = Time.instant
  sum = 0
  count.times do |i|
    sum += (i * 3) % 17
  end
  elapsed = (Time.instant - start_time).total_milliseconds

  Lapis::Benchmark.report_elapsed_ms(elapsed)
  Lapis::Benchmark.report_metric("sum", sum.to_f64)

  if iter == 0
    puts "AddonNodeProcessing #{count} iterations: #{sum}"
    puts "METRIC: sum=#{sum}"
    puts "ELAPSED_MS: #{elapsed.round(2)}"
  end
end

results = Lapis::Benchmark.run_all(iterations: 3)
if res = results.first?
  puts "Result: #{res.name} median: #{res.median_ms.round(2)} ms"
end
