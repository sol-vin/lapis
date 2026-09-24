---
name: libgodot-benchmarks
description: >-
  Build, run, profile, and package the Crystal vs GDScript performance benchmarks suite.
  Use when running benchmarks, analyzing execution speeds, generating visual comparison charts,
  or packaging benchmark artifacts.
---

# LibGodot Benchmarks Runbook: Crystal vs GDScript

This skill outlines how to build, run, profile, and package the comprehensive Crystal vs GDScript performance benchmarking suite.

---

## 1. Fast Command Reference

Always use the root `Makefile` targets:

```bash
# Build all benchmark binaries (Release -O3 by default)
make benchmarks

# Run full benchmark suite (runs 3 iterations by default and outputs results)
make benchmarks-run

# Run with custom iteration count
make benchmarks-run ITERATIONS=5

# Package benchmark suite into release distribution archive
make package-benchmarks
```

---

## 2. Benchmark Architecture

The benchmarking suite lives in [`benchmarks/`](file:///c:/Users/Ian/Documents/libgodot/benchmarks/):
- **Crystal Targets**: Compiled standalone binaries under `benchmarks/bin/` (`matmul`, `primes`, `mandelbrot`, `nbody`, `astar_2d`, `signals`, etc.).
- **GDScript Equivalents**: Godot headless runners executing equivalent algorithmic and engine operations.
- **Unified Runner**: [`benchmarks/runner.cr`](file:///c:/Users/Ian/Documents/libgodot/benchmarks/runner.cr) coordinates subprocess execution, measures wall-clock and CPU time, and formats results.
- **Reporting Outputs**: Generated in `benchmarks/results/`:
  - `results.md`: Markdown comparison tables.
  - `results.svg`: Visual bar chart comparing Crystal vs GDScript execution times and speedup ratios.
  - `results.json` / `results.csv`: Structured data for CI metrics.

---

## 3. Running Specific Benchmarks Directly

To run a specific benchmark or subset:

```bash
cd benchmarks
# Compile specific target
make bin/matmul.exe

# Run runner with filter
./bin/runner.exe --filter matmul --iterations 3
```
