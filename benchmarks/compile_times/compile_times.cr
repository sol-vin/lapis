# =============================================================================
# Lapis Compile-Time Benchmarks
# =============================================================================
# Benchmarks compilation latency and binary sizes across:
#   - Crystal (Debug vs Release -O3)
#   - C++ (Debug -O0 vs Release -O3)
#   - C# (.NET Debug vs Release)
#   - Rust (rustc Debug vs Release -O)
# =============================================================================

require "file_utils"

struct CompileResult
  property language : String
  property debug_ms : Float64
  property release_ms : Float64
  property debug_bytes : Int64
  property release_bytes : Int64

  def initialize(
    @language : String,
    @debug_ms : Float64 = 0.0,
    @release_ms : Float64 = 0.0,
    @debug_bytes : Int64 = 0_i64,
    @release_bytes : Int64 = 0_i64
  )
  end
end

def measure_command(cmd : String, args : Array(String), out_candidates : Array(String)) : Tuple(Float64, Int64)
  out_candidates.each { |cand| FileUtils.rm_rf(cand) if File.exists?(cand) }
  start = Time.instant
  status = Process.run(cmd, args, output: Process::Redirect::Close, error: Process::Redirect::Close)
  elapsed_ms = (Time.instant - start).total_milliseconds
  matched = out_candidates.find { |cand| File.exists?(cand) }
  size = matched ? File.size(matched) : 0_i64
  {elapsed_ms, size}
end

# Resolve base benchmarks directory robustly
base_dir = if File.exists?("benchmarks/matmul/matmul.cr")
             File.expand_path("benchmarks")
           elsif File.exists?("matmul/matmul.cr")
             Dir.current
           else
             File.expand_path(File.join(__DIR__, ".."))
           end

bin_dir = File.join(base_dir, "bin")
FileUtils.mkdir_p(bin_dir) unless Dir.exists?(bin_dir)

results = [] of CompileResult
overall_start = Time.instant

# 1. Crystal (matmul/matmul.cr or matmul/crystal/matmul.cr)
cr_candidates = [
  File.join(base_dir, "matmul", "matmul.cr"),
  File.join(base_dir, "matmul", "crystal", "matmul.cr")
]
cr_src = cr_candidates.find { |f| File.exists?(f) }
if cr_src && Process.find_executable("crystal")
  cr_dbg_bin = File.join(bin_dir, "matmul_cr_dbg.exe")
  cr_rel_bin = File.join(bin_dir, "matmul_cr_rel.exe")
  dbg_ms, dbg_sz = measure_command("crystal", ["build", cr_src, "-o", cr_dbg_bin], [cr_dbg_bin, cr_dbg_bin.sub(/\.exe$/, "")])
  rel_ms, rel_sz = measure_command("crystal", ["build", "--release", "-O3", cr_src, "-o", cr_rel_bin], [cr_rel_bin, cr_rel_bin.sub(/\.exe$/, "")])
  results << CompileResult.new("Crystal", dbg_ms, rel_ms, dbg_sz, rel_sz)
end

# 2. C++ (matmul/matmul.cpp or matmul/c++/matmul.cpp)
cpp_candidates = [
  File.join(base_dir, "matmul", "matmul.cpp"),
  File.join(base_dir, "matmul", "c++", "matmul.cpp")
]
cpp_src = cpp_candidates.find { |f| File.exists?(f) }
cxx_cmd = Process.find_executable("g++") || Process.find_executable("clang++")
if cpp_src && cxx_cmd
  cpp_dbg_bin = File.join(bin_dir, "matmul_cpp_dbg.exe")
  cpp_rel_bin = File.join(bin_dir, "matmul_cpp_rel.exe")
  dbg_ms, dbg_sz = measure_command(cxx_cmd, ["-O0", cpp_src, "-o", cpp_dbg_bin], [cpp_dbg_bin, cpp_dbg_bin.sub(/\.exe$/, "")])
  rel_ms, rel_sz = measure_command(cxx_cmd, ["-O3", cpp_src, "-o", cpp_rel_bin], [cpp_rel_bin, cpp_rel_bin.sub(/\.exe$/, "")])
  results << CompileResult.new("C++", dbg_ms, rel_ms, dbg_sz, rel_sz)
end

# 3. C# (matmul/matmul.csproj or matmul/c-sharp/matmul.csproj)
cs_candidates = [
  File.join(base_dir, "matmul", "matmul.csproj"),
  File.join(base_dir, "matmul", "c-sharp", "matmul.csproj")
]
cs_proj = cs_candidates.find { |f| File.exists?(f) }
if cs_proj && Process.find_executable("dotnet")
  cs_dbg_dir = File.join(bin_dir, "matmul_cs_dbg")
  cs_rel_dir = File.join(bin_dir, "matmul_cs_rel")
  dbg_cands = [File.join(cs_dbg_dir, "matmul_cs.dll"), File.join(cs_dbg_dir, "matmul_cs.exe"), File.join(cs_dbg_dir, "matmul.dll"), File.join(cs_dbg_dir, "matmul.exe")]
  rel_cands = [File.join(cs_rel_dir, "matmul_cs.dll"), File.join(cs_rel_dir, "matmul_cs.exe"), File.join(cs_rel_dir, "matmul.dll"), File.join(cs_rel_dir, "matmul.exe")]
  dbg_ms, dbg_sz = measure_command("dotnet", ["build", cs_proj, "-c", "Debug", "-o", cs_dbg_dir], dbg_cands)
  rel_ms, rel_sz = measure_command("dotnet", ["build", cs_proj, "-c", "Release", "-o", cs_rel_dir], rel_cands)
  results << CompileResult.new("C#", dbg_ms, rel_ms, dbg_sz, rel_sz)
end

# 4. Rust (matmul/matmul.rs or matmul/rust/matmul.rs)
rs_candidates = [
  File.join(base_dir, "matmul", "matmul.rs"),
  File.join(base_dir, "matmul", "rust", "matmul.rs")
]
rs_src = rs_candidates.find { |f| File.exists?(f) }
if rs_src && Process.find_executable("rustc")
  rs_dbg_bin = File.join(bin_dir, "matmul_rs_dbg.exe")
  rs_rel_bin = File.join(bin_dir, "matmul_rs_rel.exe")
  dbg_ms, dbg_sz = measure_command("rustc", [rs_src, "-o", rs_dbg_bin], [rs_dbg_bin, rs_dbg_bin.sub(/\.exe$/, "")])
  rel_ms, rel_sz = measure_command("rustc", ["-O", rs_src, "-o", rs_rel_bin], [rs_rel_bin, rs_rel_bin.sub(/\.exe$/, "")])
  results << CompileResult.new("Rust", dbg_ms, rel_ms, dbg_sz, rel_sz)
end

total_elapsed_ms = (Time.instant - overall_start).total_milliseconds

puts "================================================================================"
puts "  COMPILE-TIME BENCHMARKS: Debug vs Release Latency & Binary Size"
puts "================================================================================"
puts "%-12s | %14s | %14s | %12s | %12s" % ["Language", "Debug Time", "Release Time", "Debug Size", "Release Size"]
puts "-------------+----------------+----------------+--------------+--------------"
results.each do |r|
  puts "%-12s | %11.1f ms | %11.1f ms | %9.1f KB | %9.1f KB" % [
    r.language,
    r.debug_ms,
    r.release_ms,
    r.debug_bytes / 1024.0,
    r.release_bytes / 1024.0,
  ]

  # Standardized concise prefixes for HTML/XML and reports
  prefix = case r.language
           when "Crystal" then "cr"
           when "C++"     then "cpp"
           when "C#"      then "cs"
           when "Rust"    then "rs"
           else r.language.downcase.gsub(/[^a-z0-9]/, "")
           end

  # Primary standardized metrics
  puts "METRIC: #{prefix}_debug_ms=#{r.debug_ms.round(2)}"
  puts "METRIC: #{prefix}_release_ms=#{r.release_ms.round(2)}"
  puts "METRIC: #{prefix}_debug_bytes=#{r.debug_bytes}"
  puts "METRIC: #{prefix}_release_bytes=#{r.release_bytes}"

  # Backward compatibility aliases
  verbose_prefix = case r.language
                   when "Crystal" then "crystal"
                   when "C++"     then "cpp"
                   when "C#"      then "csharp"
                   when "Rust"    then "rust"
                   else prefix
                   end
  puts "METRIC: #{verbose_prefix}_debug_compile_ms=#{r.debug_ms.round(2)}"
  puts "METRIC: #{verbose_prefix}_release_compile_ms=#{r.release_ms.round(2)}"
  puts "METRIC: #{verbose_prefix}_debug_size_kb=#{(r.debug_bytes / 1024.0).round(1)}"
  puts "METRIC: #{verbose_prefix}_release_size_kb=#{(r.release_bytes / 1024.0).round(1)}"
end
puts "================================================================================"

# Primary benchmark elapsed time is Crystal release compile time or total
primary_ms = results.find { |r| r.language == "Crystal" }.try(&.release_ms) || total_elapsed_ms
puts "ELAPSED_MS: #{primary_ms.round(2)}"
