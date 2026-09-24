# Mandelbrot 2D Fractal Rasterization Benchmark
# Adapted from The Computer Language Benchmarks Game

size = (ARGV[0]? || "500").to_i
w = size
h = size

iter = 50
limit_sq = 4.0
checksum = 0_i64

start_time = Time.instant

h.times do |y|
  w.times do |x|
    zr = 0.0
    zi = 0.0
    cr = 2.0 * x / w - 1.5
    ci = 2.0 * y / h - 1.0

    i = 0
    tr = 0.0
    ti = 0.0
    while i < iter && (tr + ti <= limit_sq)
      zi = 2.0 * zr * zi + ci
      zr = tr - ti + cr
      tr = zr * zr
      ti = zi * zi
      i += 1
    end

    if tr + ti <= limit_sq
      checksum = (checksum + 1) & 0xFFFFFFFFFFFF_i64
    end
  end
end

elapsed_ms = (Time.instant - start_time).total_milliseconds
puts "Mandelbrot #{w}x#{h} points inside: #{checksum}"
puts "ELAPSED_MS: #{elapsed_ms.round(2)}"
