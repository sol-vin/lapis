# Lapis Project Benchmarks

This directory contains standalone and comparison benchmark suites for this project.

## Running Benchmarks

```bash
# Run all discovered benchmarks
lapis benchmarks

# Run with interactive terminal dashboard
lapis benchmarks --tui

# Run specific comparison group
lapis benchmarks -g DamageFormulas

# Filter benchmarks by name
lapis benchmarks -f damage -i 5

# Export HTML report
lapis benchmarks run html
```

## Creating Benchmarks & Comparison Groups

### 1. Single Benchmark
Register an isolated benchmark in any `.cr` file under `benchmarks/`:

```crystal
require "lapis"

Lapis::Benchmark.register("InventorySorting", category: :engine, description: "QuickSort on 10,000 items") do |iter|
  # Benchmark logic here
  Lapis::Benchmark.report_metric("items_sorted", 10000.0)
end
```

### 2. Comparison Group
Group multiple benchmarks together to compare side-by-side against a baseline:

```crystal
require "lapis"

Lapis::Benchmark.group "PathfindingAlgorithms" do |g|
  g.description("Comparing 2D Grid Pathfinders on 100x100 grid")
  g.category(:engine)

  g.benchmark "AStar2D" do |iter|
    # AStar2D implementation
  end

  g.benchmark "Dijkstra" do |iter|
    # Dijkstra implementation
  end

  g.baseline("AStar2D") # Baseline reference for speedups
end
```
