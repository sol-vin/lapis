require "base64"

# Base64 encode/decode benchmark (based on kostya/benchmarks)

# Self-verification
[["hello", "aGVsbG8="], ["world", "d29ybGQ="]].each do |(src, dst)|
  encoded = Base64.strict_encode(src)
  if encoded != dst
    STDERR.puts "Verification failed: #{encoded} != #{dst}"
    exit(1)
  end
  decoded = Base64.decode_string(dst)
  if decoded != src
    STDERR.puts "Verification failed: #{decoded} != #{src}"
    exit(1)
  end
end

str_size = (ARGV[0]? || "65536").to_i
tries = (ARGV[1]? || "200").to_i

str = "a" * str_size
str2 = Base64.strict_encode(str)
str3 = Base64.decode_string(str2)

if str3 != str
  STDERR.puts "Roundtrip verification failed!"
  exit(1)
end

start_time = Time.instant
s_encoded = 0_i64
tries.times do
  s_encoded += Base64.strict_encode(str).bytesize
end

s_decoded = 0_i64
tries.times do
  s_decoded += Base64.decode_string(str2).bytesize
end
elapsed_ms = (Time.instant - start_time).total_milliseconds

puts "RESULT: encoded=#{s_encoded}, decoded=#{s_decoded}"
puts "ELAPSED_MS: #{elapsed_ms.round(2)}"
