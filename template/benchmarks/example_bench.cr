# =============================================================================
# Template Custom Benchmark Example (Crystal)
# =============================================================================
# Custom benchmarks registered with Lapis::Benchmark execute in-editor,
# in standalone runners, or can be stripped in release builds (-Dno_benchmarks).

require "lapis"

count = (ARGV[0]? || "50000").to_i

# 1. Custom Pure Compute Benchmark
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

puts "DamageCalculation #{count} iterations: #{total.round(2)}"
puts "ELAPSED_MS: #{elapsed_ms.round(2)}"
