# =============================================================================
# Lapis Benchmark Lifecycle Hooks
# =============================================================================
# Standard hooks registered for toolchain validation, environment discovery,
# and artifact cleanup across benchmark executions.

require "../src/libgodot/benchmarks"

module Benchmarks
  # Detect available compilers and log active features
  Lapis::Benchmark.before_suite do |ctx|
    cxx_comp = Process.find_executable("g++") || Process.find_executable("clang++") || Process.find_executable("cl")
    has_dotnet = !Process.find_executable("dotnet").nil?
    has_rust = !Process.find_executable("rustc").nil?

    if cxx_comp
      ctx.metadata["cxx_compiler"] = cxx_comp
    end
    if has_dotnet
      ctx.metadata["dotnet"] = "available"
    end
    if has_rust
      ctx.metadata["rustc"] = "available"
    end

    if ctx.is_ci || ctx.enabled_features.includes?(:foreign_languages)
      puts "  \e[36m[Hooks]\e[0m Active Benchmark Features: #{ctx.enabled_features.join(", ")}"
      puts "  \e[36m[Hooks]\e[0m Compilers: C++=#{cxx_comp ? "yes" : "no"}, .NET=#{has_dotnet ? "yes" : "no"}, Rust=#{has_rust ? "yes" : "no"}"
    end
  end

  # Post-suite cleanup hook
  Lapis::Benchmark.after_suite do |summary, ctx|
    timing_files = Dir.glob("benchmarks/results/*_timing.json")
    timing_files.each do |f|
      File.delete(f) rescue nil
    end
  end
end

# Standalone CLI driver for hook execution
if PROGRAM_NAME.includes?("hooks.cr")
  action = ARGV[0]? || "before_suite"
  is_ci = ENV["CI"]? == "true" || ENV["GITHUB_ACTIONS"]? == "true" || ARGV.includes?("--ci")
  features = Set(Symbol).new
  features << :foreign_languages if ARGV.includes?("--all-languages") || is_ci

  ctx = Lapis::Benchmark::Context.new(
    is_ci: is_ci,
    enabled_features: features,
    base_dir: Path.new(Dir.current)
  )

  if action == "before_suite"
    Lapis::Benchmark.trigger_before_suite(ctx)
  elsif action == "after_suite"
    Lapis::Benchmark.trigger_after_suite(Lapis::Benchmark::Summary.new, ctx)
  end
end
