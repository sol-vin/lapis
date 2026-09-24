# Binary Trees Benchmark (GC pressure and recursive tree allocation)
# Adapted from The Computer Language Benchmarks Game

class TreeNode
  property left : TreeNode?
  property right : TreeNode?
  property item : Int32

  def initialize(@item : Int32, @left : TreeNode? = nil, @right : TreeNode? = nil)
  end

  def self.create(item : Int32, depth : Int32) : TreeNode
    if depth > 0
      TreeNode.new(
        item,
        TreeNode.create(2 * item - 1, depth - 1),
        TreeNode.create(2 * item, depth - 1)
      )
    else
      TreeNode.new(item)
    end
  end

  def check : Int32
    res = @item
    if l = @left
      res += l.check
    end
    if r = @right
      res -= r.check
    end
    res
  end
end

n = (ARGV[0]? || "12").to_i
min_depth = 4
max_depth = Math.max(min_depth + 2, n)
stretch_depth = max_depth + 1

start_time = Time.instant

stretch_check = TreeNode.create(0, stretch_depth).check
puts "stretch tree of depth #{stretch_depth}\t check: #{stretch_check}"

long_lived_tree = TreeNode.create(0, max_depth)

depth = min_depth
total_check = 0
while depth <= max_depth
  iterations = 1 << (max_depth - depth + min_depth)
  check = 0
  (1..iterations).each do |i|
    check += TreeNode.create(i, depth).check
    check += TreeNode.create(-i, depth).check
  end
  puts "#{iterations * 2}\t trees of depth #{depth}\t check: #{check}"
  total_check += check
  depth += 2
end

long_lived_check = long_lived_tree.check
puts "long lived tree of depth #{max_depth}\t check: #{long_lived_check}"
puts "checksum: #{stretch_check + total_check + long_lived_check}"

elapsed_ms = (Time.instant - start_time).total_milliseconds
puts "ELAPSED_MS: #{elapsed_ms.round(2)}"
