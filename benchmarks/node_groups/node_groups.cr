# Node Groups Benchmark in Crystal
# Manages 20,000 nodes categorized into 10 groups, executing group assignment and membership queries

require "../../src/lapis"

count = (ARGV[0]? || "20000").to_i

root = Godot::Node.new
nodes = Array(Godot::Node).new(count)

groups = (0..9).map { |g| "group_#{g}" }

count.times do |i|
  n = Godot::Node.new
  n.name = "Entity_#{i}"
  root.add_child(n)
  nodes << n
end

start_time = Time.instant

nodes.each_with_index do |n, idx|
  grp = groups[idx % 10]
  n.add_to_group(grp)
end

membership_hits = 0_i64
nodes.each do |n|
  membership_hits += 1_i64 if n.is_in_group("group_3")
end

elapsed = (Time.instant - start_time).total_milliseconds
puts "NodeGroups #{count} nodes (10 groups): #{elapsed.round(2)} ms (hits=#{membership_hits})"
puts "ELAPSED_MS: #{elapsed.round(2)}"

root.free
