# Matrix multiplication benchmark (based on kostya/benchmarks)
def matmul(a, b)
  m = a.size
  n = a[0].size
  p = b[0].size
  # Transpose
  b2 = Array.new(n) { Array.new(p, 0.0) }
  (0...n).each do |i|
    (0...p).each do |j|
      b2[j][i] = b[i][j]
    end
  end
  # Multiplication
  c = Array.new(m) { Array.new(p, 0.0) }
  c.each_with_index do |ci, i|
    ai = a[i]
    b2.each_with_index do |b2j, j|
      s = 0.0
      b2j.each_with_index do |b2jv, k|
        s += ai[k] * b2jv
      end
      ci[j] = s
    end
  end
  c
end

def matgen(n, seed)
  tmp = seed / n / n
  a = Array.new(n) { Array.new(n, 0.0) }
  (0...n).each do |i|
    (0...n).each do |j|
      a[i][j] = tmp * (i - j) * (i + j)
    end
  end
  a
end

def calc(n)
  n = n >> 1 << 1
  a = matgen(n, 1.0)
  b = matgen(n, 2.0)
  c = matmul(a, b)
  c[n >> 1][n >> 1]
end

# Self-verification
left = calc(101)
right = -18.67
if (left - right).abs > 0.1
  STDERR.puts "Verification failed: #{left} != #{right}"
  exit(1)
end

n = (ARGV[0]? || "400").to_i
start_time = Time.instant
res = calc(n)
elapsed_ms = (Time.instant - start_time).total_milliseconds

puts "RESULT: #{res}"
puts "ELAPSED_MS: #{elapsed_ms.round(2)}"
