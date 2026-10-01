# Sieve of Atkin + Prefix Trie Benchmark (based on kostya/benchmarks)

class Node
  property children : Hash(Char, Node)
  property terminal : Bool

  def initialize
    @children = Hash(Char, Node).new
    @terminal = false
  end
end

class Sieve
  def initialize(limit : Int32)
    @limit = limit
    @prime = Array(Bool).new(limit + 1, false)
  end

  def to_list
    result = [2, 3]
    (5..@limit).each do |p|
      result.push(p) if @prime[p]
    end
    result
  end

  def omit_squares
    r = 5
    while r * r < @limit
      if @prime[r]
        i = r * r
        while i < @limit
          @prime[i] = false
          i += r * r
        end
      end
      r += 1
    end
    self
  end

  def step1(x, y)
    n = (4 * x * x) + (y * y)
    @prime[n] = !@prime[n] if n <= @limit && (n % 12 == 1 || n % 12 == 5)
  end

  def step2(x, y)
    n = (3 * x * x) + (y * y)
    @prime[n] = !@prime[n] if n <= @limit && n % 12 == 7
  end

  def step3(x, y)
    n = (3 * x * x) - (y * y)
    @prime[n] = !@prime[n] if x > y && n <= @limit && n % 12 == 11
  end

  def loop_y(x)
    y = 1
    while y * y < @limit
      step1(x, y)
      step2(x, y)
      step3(x, y)
      y += 1
    end
  end

  def loop_x
    x = 1
    while x * x < @limit
      loop_y(x)
      x += 1
    end
  end

  def calc
    loop_x
    omit_squares
  end
end

def generate_trie(l)
  root = Node.new
  l.each do |el|
    head = root
    el.to_s.each_char do |ch|
      head.children[ch] = Node.new unless head.children.has_key?(ch)
      head = head.children[ch]
    end
    head.terminal = true
  end
  root
end

def find(upper_bound, prefix)
  primes = Sieve.new(upper_bound).calc
  str_prefix = prefix.to_s
  head = generate_trie(primes.to_list)
  str_prefix.each_char do |ch|
    return Array(Int32).new unless head.children.has_key?(ch)
    head = head.children[ch]
  end

  queue = [{head, str_prefix}]
  result = Array(Int32).new
  until queue.empty?
    top, cur_prefix = queue.pop
    result.push(cur_prefix.to_i) if top.terminal
    top.children.each do |ch, v|
      queue.insert(0, {v, cur_prefix + ch})
    end
  end
  result.sort!
  result
end

# Self-verification
left = [2, 23, 29]
right = find(100, 2)
if left != right
  STDERR.puts "Verification failed: #{left} != #{right}"
  exit(1)
end

upper_bound = (ARGV[0]? || "1000000").to_i
prefix = (ARGV[1]? || "3233").to_i

start_time = Time.instant
res = find(upper_bound, prefix)
elapsed_ms = (Time.instant - start_time).total_milliseconds

puts "RESULT: #{res.size} primes found (first 5: #{res[0, 5]})"
puts "ELAPSED_MS: #{elapsed_ms.round(2)}"
