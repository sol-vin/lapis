# =============================================================================
# Template Custom Benchmark Example (Crystal)
# =============================================================================
# Custom benchmarks registered with Lapis::Benchmark execute in-editor,
# in standalone runners, or can be stripped in release builds (-Dno_benchmarks).

require "lapis"

count = (ARGV[0]? || "50000").to_i

Lapis::Benchmark.register("DamageCalculation", category: Lapis::Benchmark::Category::Compute, description: "Damage falloff & armor exponential decay") do |iter|
  start_time = Time.instant
  total = 0.0_f64
  count.times do |i|
    # Example gameplay formula: damage falloff & exponential decay
    distance = (i % 100).to_f64
    armor = ((i * 3) % 50).to_f64
    raw_damage = 150.0_f64
    effective_damage = (raw_damage / (1.0 + armor * 0.05)) * Math.exp(-distance * 0.02)
    total += effective_damage
  end
  elapsed_ms = (Time.instant - start_time).total_milliseconds

  Lapis::Benchmark.report_elapsed_ms(elapsed_ms)
  Lapis::Benchmark.report_metric("total_damage", total.round(2))

  if iter == 0
    puts "DamageCalculation #{count} iterations: #{total.round(2)}"
    puts "METRIC: total_damage=#{total.round(2)}"
    puts "ELAPSED_MS: #{elapsed_ms.round(2)}"
  end
end

# When executed standalone
results = Lapis::Benchmark.run_all(iterations: 3)
if res = results.first?
  puts "Result: #{res.name} median: #{res.median_ms.round(2)} ms"
end
