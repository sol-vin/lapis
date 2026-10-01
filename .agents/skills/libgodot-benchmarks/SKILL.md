---
name: libgodot-benchmarks
description: Build, run, profile, and package the Crystal vs GDScript performance benchmarks suite. Use when running benchmarks, analyzing execution speeds, generating visual comparison charts, or packaging benchmark artifacts.
---

# LibGodot Benchmarks Runbook: Crystal vs GDScript &amp; Native Languages

This skill governs the compilation, execution, profiling, and visualization of the comprehensive Lapis performance benchmarking suite, measuring Crystal against GDScript, C++, C#, and Rust across both computational algorithms and Godot engine operations.

---

## 1. Quick Command Reference

<table>
  <thead>
    <tr>
      <th align="left">Command / Target</th>
      <th align="left">Execution Mode</th>
      <th align="left">Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>lapis bench</code></td>
      <td>Console Streaming</td>
      <td>Runs default benchmark suite with console timing &amp; speedup multipliers</td>
    </tr>
    <tr>
      <td><code>lapis bench --tui</code></td>
      <td>Interactive TUI</td>
      <td>Runs benchmark suite inside Opal ANSI dashboard with live progress meters</td>
    </tr>
    <tr>
      <td><code>lapis bench run html</code></td>
      <td>HTML &amp; SVG Export</td>
      <td>Executes benchmarks and renders rich HTML report with interactive SVG charts</td>
    </tr>
    <tr>
      <td><code>lapis bench compare html</code></td>
      <td>Regression Diff</td>
      <td>Compares current benchmarks against historical baseline XML/HTML reports</td>
    </tr>
    <tr>
      <td><code>make benchmarks</code></td>
      <td>Root Makefile Target</td>
      <td>Compiles all benchmark binaries with <code>--release -O3</code> optimizations</td>
    </tr>
    <tr>
      <td><code>make benchmarks-run</code></td>
      <td>Root Makefile Target</td>
      <td>Executes full benchmark suite across 3 iterations</td>
    </tr>
    <tr>
      <td><code>make package-benchmarks</code></td>
      <td>Release Packaging</td>
      <td>Bundles standalone benchmark binaries and datasets into release archive</td>
    </tr>
  </tbody>
</table>

---

## 2. Benchmark Architecture &amp; Categories

Benchmarks live under `benchmarks/` and are organized into distinct evaluation domains:

<table>
  <thead>
    <tr>
      <th align="left">Category</th>
      <th align="left">Target Directory</th>
      <th align="left">What It Measures</th>
      <th align="left">Key Benchmarks</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Compute</strong></td>
      <td><code>benchmarks/compute/</code></td>
      <td>Raw CPU numerical calculation, algorithmic throughput, memory locality</td>
      <td><code>matmul</code>, <code>nbody</code>, <code>mandelbrot</code>, <code>primes</code>, <code>spectral_norm</code></td>
    </tr>
    <tr>
      <td><strong>Engine</strong></td>
      <td><code>benchmarks/engine/</code></td>
      <td>Scene tree mutation, GDExtension boundary crossing, Variant conversions</td>
      <td><code>scene_traversal</code>, <code>signals</code>, <code>node_lifecycle</code>, <code>property_get_set</code></td>
    </tr>
    <tr>
      <td><strong>Physics</strong></td>
      <td><code>benchmarks/physics/</code></td>
      <td>Raycasting, collision callbacks, physics step math</td>
      <td><code>raycast_stress</code>, <code>body_tracking_3d</code>, <code>spatial_query</code></td>
    </tr>
    <tr>
      <td><strong>Toolchain</strong></td>
      <td><code>benchmarks/toolchain/</code></td>
      <td>Virtual method dispatch overhead, dynamic typing vs static vtables</td>
      <td><code>dispatch_latency</code>, <code>box_unbox</code>, <code>reflection_cost</code></td>
    </tr>
  </tbody>
</table>

---

## 3. CLI Filtering &amp; Multi-Language Comparison

### Multi-Language Execution:
Lapis can measure Crystal against other Godot-compatible languages:
```powershell
# Run across all supported languages (Crystal, GDScript, C++, C#, Rust)
lapis bench --all-languages

# Run specific language subsets
lapis bench --languages=crystal,gdscript,cpp
```

### Filtering by Category or Name:
```powershell
# Run only compute benchmarks with 5 iterations
lapis bench --category=compute -i 5

# Run only matrix multiplication
lapis bench --filter=matmul
```

---

## 4. Visual Charting &amp; Formatting Options

The benchmark runner supports multiple reporting formats:
`--format=console,html,xml,svg,json,csv`

### Visual Console Charting:
When outputting to terminal, Lapis draws proportional bars comparing execution times:
```text
matmul (1000x1000)
  Crystal:   0.042s |████████████████████████████████            | 24.8x faster
  GDScript:  1.041s |████████████████████████████████████████████|
```

### Interactive HTML &amp; SVG Reports:
Generated in `benchmarks/results/`:
- `results.html`: Comprehensive dashboard with interactive tables, category tabs, and filterable search.
- `results.svg`: Scalable vector graphics chart comparing Crystal vs GDScript latency and speedup ratios.
- `results.xml` &amp; `results.json`: Machine-readable benchmarks for automated CI regression tracking.

---

## 5. Memory &amp; GC Allocation Profiling

To profile Boehm GC memory allocations during benchmark runs:

1. **Boehm GC Monitors**:
   - `GC.stats.heap_size`: Total allocated OS memory for the garbage-collected heap.
   - `GC.stats.total_bytes`: Cumulative bytes allocated over the lifetime of the process.
2. **Engine Performance Singletons**:
   - `Performance.get_monitor(Performance::Monitor::TIME_PROCESS)`
   - `Performance.get_monitor(Performance::Monitor::OBJECT_COUNT)`
   - `Performance.get_monitor(Performance::Monitor::MEMORY_STATIC)`
3. **Leak-Free Benchmark Assertions**:
   - Benchmarks enforce `Lapis::Test.assert_no_leak` to ensure zero memory accumulation across repeated test frames.
