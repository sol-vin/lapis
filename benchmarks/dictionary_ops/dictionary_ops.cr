# Dictionary Operations Benchmark in Crystal
# 50,000 key-value insertions and random access lookups

require "../../src/lapis"

count = (ARGV[0]? || "50000").to_i

start_time = Time.instant
dict = Godot::Dictionary.new

count.times do |i|
  key = "entity_key_#{i}"
  dict[key] = Godot::Variant.new(i * 3)
end

hits = 0_i64
count.times do |i|
  lookup_key = "entity_key_#{(i * 7) % count}"
  if val = dict[lookup_key]?
    hits += 1_i64
  end
end

elapsed = (Time.instant - start_time).total_milliseconds
puts "DictionaryOps #{count} operations: #{elapsed.round(2)} ms (hits=#{hits})"
puts "ELAPSED_MS: #{elapsed.round(2)}"
