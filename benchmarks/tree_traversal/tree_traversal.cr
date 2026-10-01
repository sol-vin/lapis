# Scene Tree Traversal Benchmark in Crystal
# Builds 20,000 branched Node instances and traverses the hierarchy evaluating properties

require "../../src/lapis"

target_nodes = (ARGV[0]? || "20000").to_i

root = Godot::Node.new
root.name = "Root"

nodes_created = 1

def build_branch(parent : Godot::Node, depth : Int32, branch_factor : Int32, target : Int32, count_ptr : Pointer(Int32)) : Nil
  return if depth <= 0 || count_ptr.value >= target

  branch_factor.times do |b|
    break if count_ptr.value >= target
    child = Godot::Node.new
    child.name = "N_#{depth}_#{b}"
    parent.add_child(child)
    count_ptr.value += 1
    build_branch(child, depth - 1, branch_factor, target, count_ptr)
  end
end

build_branch(root, 9, 4, target_nodes, pointerof(nodes_created))

def traverse_dfs(node : Godot::Node) : Int64
  sum = node.name.size.to_i64
  count = node.get_child_count
  count.times do |i|
    child = node.get_child(i)
    sum += traverse_dfs(child)
  end
  sum
end

start_time = Time.instant
total_len = traverse_dfs(root)
elapsed = (Time.instant - start_time).total_milliseconds

puts "TreeTraversal #{nodes_created} nodes: #{elapsed.round(2)} ms (sum=#{total_len})"
puts "ELAPSED_MS: #{elapsed.round(2)}"

root.free
