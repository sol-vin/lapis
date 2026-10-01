# Signals Connection & Emission Benchmark in Crystal
# Measures connecting a callable and emitting signals 50,000 times

require "../../src/lapis"

count = (ARGV[0]? || "50000").to_i

emitter = Godot::Node.new
received = 0_i64

emitter.renamed.connect do
  received += 1
end

start_time = Time.instant
count.times do
  emit(emitter.renamed)
end

elapsed = (Time.instant - start_time).total_milliseconds
puts "Signals #{count} emissions: #{received} received (#{elapsed.round(2)} ms)"
puts "ELAPSED_MS: #{elapsed.round(2)}"

emitter.free
