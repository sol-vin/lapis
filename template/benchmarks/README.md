# Custom Project Benchmarks

This directory contains performance benchmarks comparing Crystal vs GDScript for gameplay mechanics and math routines.

## Running Benchmarks

Run benchmarks directly using the Lapis CLI:

```bash
# Run all benchmarks in the project
lapis benchmarks

# Run benchmarks and generate interactive HTML report
lapis benchmarks run html

# Run with custom iterations and name filter
lapis benchmarks -f damage -i 5
```

You can also run benchmarks directly inside the Godot Editor by navigating to the **Crystal** main screen dock and opening the **Benchmarks** tab.

## Release Builds & Steam / Itch Shipping

To eliminate all benchmark code and overhead from your production game release:

```bash
# Package game without benchmarks
lapis package game -r --without-benchmarks

# Package game installer without benchmarks
lapis package installer -r --without-benchmarks
```

Passing `--without-benchmarks` injects the `-Dno_benchmarks` compiler flag into the Crystal build, completely removing all benchmark closures and registrations.
