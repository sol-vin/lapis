# Lapis Benchmarks: Crystal (Native) vs GDScript

Performance benchmarks comparing native compiled Crystal against GDScript in Godot Engine 4.8+.
Algorithmic tests are based on [kostya/benchmarks](https://github.com/kostya/benchmarks), and engine core operations benchmark native scene tree, node lifecycle, material resources, and signal dispatch throughput.

## Overview

Crystal compiles directly to native machine code via LLVM with `--release -O3` optimizations and native static typing. GDScript is Godot's built-in dynamically-typed scripting language executed by Godot's bytecode virtual machine.

### Complete 1-to-1 Benchmark Suite

All benchmarks have matching, standalone tests in both Crystal (`.cr`) and GDScript (`.gd`) with identical parameters, operations, and timing metrics:

#### 1. Algorithmic & Compute Operations
- **Matmul**: Dense 2D matrix multiplication (`N=300`, Float64)
- **Primes**: Sieve of Atkin + Prefix Trie search (`Limit=500k`)
- **Brainfuck**: Tape VM & AST interpreter (`bench_quick.b`)
- **Base64**: Base64 strict encode & decode loop (`64 KiB`, 100 iter)
- **JSON**: JSON parse & 3D coordinate reduction (`10k items`)
- **NBody**: 3D orbital dynamics physics integration (Velocity-Verlet, `50k steps`)
- **BinaryTrees**: GC pressure, bottom-up binary tree allocation & depth traversal (`depth=12`)
- **Mandelbrot**: 2D coordinate escape-time fractal rasterization (`500x500`)
- **TransformMath**: Transform3D translations, rotations & Vector3 projections (`200k ops`)
- **VectorMath2D**: Vector2 lerp, dot, distance, and normalization (`500k ops`)

#### 2. Godot Engine Core Operations & Common Tasks
- **NodeLifecycle**: `Node2D` allocation, property mutation, `add_child`, `remove_child`, `free` (`20k entities`)
- **MaterialResources**: `StandardMaterial3D` allocation, property mutation, `duplicate`, refcounting (`10k resources`)
- **Signals**: Signal connection, argument marshalling & dynamic emission (`50k calls`)
- **PerlinNoise**: `FastNoiseLite` 2D Perlin noise across 500x500 grid (`250k samples`)
- **SimplexNoise**: `FastNoiseLite` 3D Simplex Smooth noise density evaluation (`100k samples`)
- **CellularNoise**: `FastNoiseLite` 2D Cellular (Voronoi) noise across 500x500 grid (`250k samples`)
- **SurfaceTool**: `SurfaceTool` procedural mesh generation with normals, colors, UVs (`10k triangles`)
- **AStar2D**: `AStar2D` pathfinding on 100x100 grid (`10k points`, 500 queries)
- **TreeTraversal**: Scene tree recursive traversal & property inspection (`20k nodes`)
- **ImageProcessing**: 512x512 `Image` procedural pixel computation & gamma blending (`262k pixels`)
- **TransformHierarchy**: 15,000 `Node3D` hierarchy transformations & global position resolution
- **NodeGroups**: 20,000 nodes partitioned into 10 groups, group assignment & queries
- **DictionaryOps**: Godot `Dictionary` 50,000 insertions and random access lookups
- **ConfigFileOps**: `ConfigFile` parsing, querying and encoding 1,000 section INI config

---

## Architecture & Reporter Design Pattern

The benchmark suite is designed to be easily extensible using the **Reporter Pattern**:

```
benchmarks/
├── src/
│   ├── models.cr               # BenchmarkCase, Category, BenchmarkResult, BenchmarkMetric
│   ├── registry.cr             # Centralized BenchmarkRegistry with 1-to-1 matching tests
│   ├── executor.cr             # Compilation, timing, and statistical measurement engine
│   └── reporters/              # Pluggable output formatters
│       ├── base.cr             # Abstract Reporter base class
│       ├── console.cr          # Formatted terminal table & ANSI comparative bar charts
│       ├── svg.cr              # Standalone SVG chart with linear gradients & speedup badges
│       ├── markdown.cr         # GitHub-flavored Markdown report
│       ├── html.cr             # Premium interactive dark-mode dashboard with KPIs
│       ├── json.cr             # Machine-readable JSON output for CI/CD automation
│       └── csv.cr              # CSV export for spreadsheet analytics
├── runner.cr                   # Ergonomic CLI entry point
└── Makefile                    # Unified build tooling
```

---

## Running Benchmarks

### Using Makefile
```bash
# Build all 12 benchmark binaries in release mode
make benchmarks

# Run benchmarks and generate all reports and charts
make benchmarks-run [ITERATIONS=3]
```

### Using Standalone CLI Runner
```bash
# Run all benchmarks with default reporters (console, svg, markdown, html, json, csv)
./bin/runner.exe

# Filter by category
./bin/runner.exe --category=engine
./bin/runner.exe --category=compute

# Filter by benchmark name
./bin/runner.exe --filter=signals

# Select specific output formats
./bin/runner.exe --format=console,html,json

# Quick console-only run
./bin/runner.exe --no-chart -i 1

# List all available benchmarks
./bin/runner.exe --list
```

### Generated Artifacts (`benchmarks/results/`)
- `benchmark_chart.svg`: Visual comparative bar chart with linear gradients and badges
- `benchmark_report.html`: Interactive dark-mode HTML performance dashboard
- `benchmark_report.md`: GitHub-formatted Markdown report
- `benchmark_report.json`: Machine-readable JSON metrics and sample distributions
- `benchmark_report.csv`: CSV table for external ingestion
