# =============================================================================
# Addon Comparison Benchmark Example (Crystal)
# =============================================================================

require "lapis"

count = (ARGV[0]? || "20000").to_i

Lapis::Benchmark.group "AddonResourceProcessing" do |g|
  g.description("Comparing resource cache queries vs direct traversal")
  g.category(:engine)
  g.kind(:runtime)
  g.charts(:bar, :speedup, :ratio, :log)

  g.subgroup "LookupMethods" do |sg|
    sg.benchmark "DirectLookup" do |iter|
      sum = 0
      count.times { |i| sum += (i * 7) % 31 }
      Lapis::Benchmark.report_metric("ops", sum.to_f64)
    end

    sg.benchmark "CachedLookup" do |iter|
      sum = 0
      cache = (0..31).to_a
      count.times { |i| sum += cache[(i * 7) % 32] }
      Lapis::Benchmark.report_metric("ops", sum.to_f64)
    end
  end

  g.baseline("DirectLookup")
end

results = Lapis::Benchmark.run_all_groups(iterations: 3)
results.each do |grp|
  puts "Group: #{grp.group_name} [#{grp.category.display_name}] Kind: #{grp.kind} Charts: #{grp.chart_types.join(",")} (Baseline: #{grp.baseline_name})"
  grp.targets.each do |t|
    puts "  %-20s %6.2f ms" % [t.name, t.median_ms]
  end
  if first = grp.targets.first?
    puts "ELAPSED_MS: #{first.median_ms.round(2)}"
  end
end
