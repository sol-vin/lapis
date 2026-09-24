require "option_parser"
require "./src/models"
require "./src/registry"
require "./src/executor"
require "./src/reporters"

# =============================================================================
# Lapis Benchmark Suite Runner (CLI Driver)
# =============================================================================

iterations = 3
filter = ""
category_filter : Benchmarks::Category? = nil
requested_formats = ["console", "svg", "markdown", "html", "json", "csv"]
release_build = true
env_mode = "standalone"
base_dir = if File.exists?("benchmarks/runner.cr")
             File.expand_path("benchmarks")
           elsif File.exists?("runner.cr")
             Dir.current
           else
             File.expand_path(File.join(__DIR__, ".."))
           end

OptionParser.parse do |opts|
  opts.banner = "Usage: benchmarks [options]"

  opts.on("-i N", "--iterations=N", "Number of iterations per benchmark (default: 3)") do |n|
    iterations = n.to_i
  end

  opts.on("-f NAME", "--filter=NAME", "Filter benchmarks by name or description") do |f|
    filter = f.downcase
  end

  opts.on("-c CAT", "--category=CAT", "Filter by category ('compute' or 'engine')") do |cat|
    category_filter = case cat.downcase
                      when "compute", "comp"
                        Benchmarks::Category::Compute
                      when "engine", "enginecore", "engine_core", "core"
                        Benchmarks::Category::EngineCore
                      else
                        STDERR.puts "Unknown category: '#{cat}' (expected 'compute' or 'engine')"
                        exit(1)
                      end
  end

  opts.on("-e ENV", "--env=ENV", "Execution environment: standalone, editor, or all (default: standalone)") do |e|
    case e.downcase
    when "standalone", "std"
      env_mode = "standalone"
    when "editor", "ed"
      env_mode = "editor"
    when "all", "both"
      env_mode = "all"
    else
      STDERR.puts "Unknown env: '#{e}' (expected 'standalone', 'editor', or 'all')"
      exit(1)
    end
  end

  opts.on("--format=FORMATS", "Comma-separated output formats: console,svg,markdown,html,json,csv (default: all)") do |fmt|
    requested_formats = fmt.split(",").map(&.strip.downcase).reject(&.empty?)
  end

  opts.on("--no-chart", "Disable file reporters (console output only)") do
    requested_formats = ["console"]
  end

  opts.on("--no-release", "Compile benchmarks in debug mode (default: release -O3)") do
    release_build = false
  end

  opts.on("-l", "--list", "List all registered benchmarks and exit") do
    puts "\nRegistered Benchmarks (#{Benchmarks::Registry.all.size} total):"
    Benchmarks::Registry.all.each do |b|
      puts "  %-18s [%-10s] %s" % [b.name, b.category.display_name, b.description]
    end
    exit(0)
  end

  opts.on("-h", "--help", "Show help and usage options") do
    puts opts
    exit(0)
  end
end

godot_exe = Benchmarks::Executor.resolve_godot(base_dir)

puts "\e[1;35m=== Lapis Benchmarks Suite ===\e[0m"
puts "  Godot Executable: #{godot_exe}"
puts "  Environment:      #{env_mode.capitalize}"
puts "  Iterations:       #{iterations}"
puts "  Optimization:     #{release_build ? "Release (-O3)" : "Debug"}"
puts "  Reporters:        #{requested_formats.join(", ")}"

target_benchmarks = Benchmarks::Registry.all

if cat = category_filter
  target_benchmarks = target_benchmarks.select { |b| b.category == cat }
end

unless filter.empty?
  target_benchmarks = target_benchmarks.select do |b|
    b.name.downcase.includes?(filter) || b.description.downcase.includes?(filter)
  end
end

if target_benchmarks.empty?
  puts "\n\e[33mNo benchmarks matched the specified filters.\e[0m"
  exit(0)
end

puts "  Benchmarks:       #{target_benchmarks.size} selected"

results = [] of Benchmarks::BenchmarkResult

target_benchmarks.each do |bench|
  if res = Benchmarks::Executor.run_case(
    bench: bench,
    iterations: iterations,
    base_dir: base_dir,
    godot_exe: godot_exe,
    release: release_build,
    env_mode: env_mode
  )
    results << res
  end
end

# Build active reporters
reporters_map = {
  "console"  => Benchmarks::Reporters::Console.new,
  "svg"      => Benchmarks::Reporters::Svg.new,
  "markdown" => Benchmarks::Reporters::Markdown.new,
  "html"     => Benchmarks::Reporters::Html.new,
  "json"     => Benchmarks::Reporters::Json.new,
  "csv"      => Benchmarks::Reporters::Csv.new,
}

active_reporters = [] of Benchmarks::Reporters::Base

requested_formats.each do |fmt|
  if rep = reporters_map[fmt]?
    active_reporters << rep
  else
    STDERR.puts "Unknown reporter format: '#{fmt}' (available: #{reporters_map.keys.join(", ")})"
  end
end

# Execute reporters
active_reporters.each do |reporter|
  reporter.report(results, base_dir)
end
