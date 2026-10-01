# =============================================================================
# Template Comparison Benchmark Example (Crystal)
# =============================================================================
# Demonstrates comparing two gameplay algorithms side by side using Lapis::Benchmark.group

require "lapis"

count = (ARGV[0]? || "50000").to_i

Lapis::Benchmark.group "DamageFormulas" do |g|
  g.description("Comparing linear vs exponential damage falloff algorithms")
  g.category(:compute)
  g.kind(:runtime)
  g.charts(:bar, :speedup, :ratio, :log)

  g.subgroup "Formulas" do |sg|
    sg.benchmark "LinearFalloff" do |iter|
      total = 0.0_f64
      count.times do |i|
        dist = (i % 100).to_f64
        total += [0.0_f64, 100.0_f64 - dist * 0.8_f64].max
      end
      Lapis::Benchmark.report_metric("total_damage", total)
    end

    sg.benchmark "ExponentialFalloff" do |iter|
      total = 0.0_f64
      count.times do |i|
        dist = (i % 100).to_f64
        total += 100.0_f64 * Math.exp(-dist * 0.02_f64)
      end
      Lapis::Benchmark.report_metric("total_damage", total)
    end
  end

  g.baseline("LinearFalloff")
end

# When executed standalone, run all groups and format results
results = Lapis::Benchmark.run_all_groups(iterations: 3)
results.each do |grp|
  puts "Group: #{grp.group_name} [#{grp.category.display_name}] Kind: #{grp.kind} Charts: #{grp.chart_types.join(",")} (Baseline: #{grp.baseline_name})"
  grp.targets.each do |t|
    badge = t.speedup_vs_baseline >= 1.0 ? "#{t.speedup_vs_baseline.round(2)}x faster" : "#{(1.0 / t.speedup_vs_baseline).round(2)}x slower"
    puts "  %-20s %6.2f ms -> %s" % [t.name, t.median_ms, badge]
  end
  if first = grp.targets.first?
    puts "ELAPSED_MS: #{first.median_ms.round(2)}"
  end
end
