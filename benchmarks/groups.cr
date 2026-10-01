# =============================================================================
# Lapis Canonical Benchmark Comparison Groups
# =============================================================================
# Defines grouped comparison suites testing specific hypotheses and side-by-side
# implementations across languages, toolchains, and engine subsystems.

require "../src/lapis"

module Benchmarks
  # Matrix Multiplication Comparison Group (Multi-Language)
  Lapis::Benchmark.group "MatrixMultiplication" do |g|
    g.description("Dense 2D matrix multiplication (N=300, float64) across languages")
    g.category(:compute)
    g.kind(:runtime)
    g.charts(:bar, :speedup, :ratio, :log)
    g.target("Crystal", "matmul/crystal/matmul.cr", :crystal, release_flags: ["--release", "-O3"])
    g.target("GDScript", "matmul/gdscript/matmul.gd", :gdscript)
    g.target("C++", "matmul/c++/matmul.cpp", :cpp, release_flags: ["-O3"], feature: :foreign_languages)
    g.target("C#", "matmul/c-sharp/matmul.csproj", :csharp, release_flags: ["-c", "Release"], feature: :foreign_languages)
    g.target("Rust", "matmul/rust/matmul.rs", :rust, release_flags: ["-O"], feature: :foreign_languages)
    g.baseline("Crystal")
  end

  # Sieve of Atkin + Prefix Trie (Multi-Language)
  Lapis::Benchmark.group "PrimeSieve" do |g|
    g.description("Sieve of Atkin prime generation + Prefix Trie search across languages")
    g.category(:compute)
    g.kind(:runtime)
    g.charts(:bar, :speedup, :ratio, :log)
    g.target("Crystal", "primes/crystal/primes.cr", :crystal, release_flags: ["--release", "-O3"])
    g.target("GDScript", "primes/gdscript/primes.gd", :gdscript)
    g.target("C++", "primes/c++/primes.cpp", :cpp, release_flags: ["-O3"], feature: :foreign_languages)
    g.target("C#", "primes/c-sharp/primes.csproj", :csharp, release_flags: ["-c", "Release"], feature: :foreign_languages)
    g.target("Rust", "primes/rust/primes.rs", :rust, release_flags: ["-O"], feature: :foreign_languages)
    g.baseline("Crystal")
  end

  # Mandelbrot 2D Fractal Rasterization (Multi-Language)
  Lapis::Benchmark.group "Mandelbrot" do |g|
    g.description("2D coordinate escape-time fractal rasterization (500x500) across languages")
    g.category(:compute)
    g.kind(:runtime)
    g.charts(:bar, :speedup, :ratio, :log)
    g.target("Crystal", "mandelbrot/crystal/mandelbrot.cr", :crystal, release_flags: ["--release", "-O3"])
    g.target("GDScript", "mandelbrot/gdscript/mandelbrot.gd", :gdscript)
    g.target("C++", "mandelbrot/c++/mandelbrot.cpp", :cpp, release_flags: ["-O3"], feature: :foreign_languages)
    g.target("C#", "mandelbrot/c-sharp/mandelbrot.csproj", :csharp, release_flags: ["-c", "Release"], feature: :foreign_languages)
    g.target("Rust", "mandelbrot/rust/mandelbrot.rs", :rust, release_flags: ["-O"], feature: :foreign_languages)
    g.baseline("Crystal")
  end

  # N-Body Orbital Mechanics (Multi-Language)
  Lapis::Benchmark.group "NBody" do |g|
    g.description("Velocity-Verlet numerical integration (50k steps) across languages")
    g.category(:compute)
    g.kind(:runtime)
    g.charts(:bar, :speedup, :ratio, :log)
    g.target("Crystal", "nbody/crystal/nbody.cr", :crystal, release_flags: ["--release", "-O3"])
    g.target("GDScript", "nbody/gdscript/nbody.gd", :gdscript)
    g.target("C++", "nbody/c++/nbody.cpp", :cpp, release_flags: ["-O3"], feature: :foreign_languages)
    g.target("C#", "nbody/c-sharp/nbody.csproj", :csharp, release_flags: ["-c", "Release"], feature: :foreign_languages)
    g.target("Rust", "nbody/rust/nbody.rs", :rust, release_flags: ["-O"], feature: :foreign_languages)
    g.baseline("Crystal")
  end

  # Binary Trees Allocation & GC Pressure (Multi-Language)
  Lapis::Benchmark.group "BinaryTrees" do |g|
    g.description("Bottom-up binary tree allocation, GC pressure, and depth traversal across languages")
    g.category(:compute)
    g.kind(:runtime)
    g.charts(:bar, :speedup, :ratio, :log)
    g.target("Crystal", "binarytrees/crystal/binarytrees.cr", :crystal, release_flags: ["--release", "-O3"])
    g.target("GDScript", "binarytrees/gdscript/binarytrees.gd", :gdscript)
    g.target("C++", "binarytrees/c++/binarytrees.cpp", :cpp, release_flags: ["-O3"], feature: :foreign_languages)
    g.target("C#", "binarytrees/c-sharp/binarytrees.csproj", :csharp, release_flags: ["-c", "Release"], feature: :foreign_languages)
    g.target("Rust", "binarytrees/rust/binarytrees.rs", :rust, release_flags: ["-O"], feature: :foreign_languages)
    g.baseline("Crystal")
  end

  # Compile-Time & Binary Size Comparison Group
  Lapis::Benchmark.group "CompileTime" do |g|
    g.description("Compilation latency and output binary sizes across languages (Debug vs Release)")
    g.category(:toolchain)
    g.kind(:compile_time)
    g.charts(:debug_vs_release, :size, :bar, :speedup)
    g.target("Crystal", "matmul/crystal/matmul.cr", :crystal)
    g.target("C++", "matmul/c++/matmul.cpp", :cpp, feature: :foreign_languages)
    g.target("C#", "matmul/c-sharp/matmul.csproj", :csharp, feature: :foreign_languages)
    g.target("Rust", "matmul/rust/matmul.rs", :rust, feature: :foreign_languages)
    g.baseline("Crystal")
  end

  # Shader Subsystem Comparison Group
  Lapis::Benchmark.group "Shaders" do |g|
    g.description("Shader compilation throughput, uniform parameter dispatch, and VisualShader graph assembly")
    g.category(:engine)
    g.kind(:throughput)
    g.charts(:throughput, :bar, :speedup)
    g.target("ShaderCompilation", "shader_compilation/shader_compilation.cr", :crystal)
    g.target("ShaderUniforms", "shader_uniforms/shader_uniforms.cr", :crystal)
    g.target("VisualShader", "visual_shader/visual_shader.cr", :crystal)
    g.baseline("ShaderCompilation")
  end

  # Procedural Noise Generation Comparison Group
  Lapis::Benchmark.group "ProceduralNoise" do |g|
    g.description("FastNoiseLite evaluation across Perlin, Simplex, and Cellular Voronoi noise")
    g.category(:engine)
    g.kind(:runtime)
    g.charts(:bar, :speedup, :ratio, :log)
    g.target("PerlinNoise", "perlin_noise/perlin_noise.cr", :crystal)
    g.target("SimplexNoise", "simplex_noise/simplex_noise.cr", :crystal)
    g.target("CellularNoise", "cellular_noise/cellular_noise.cr", :crystal)
    g.baseline("PerlinNoise")
  end

  # Scene Graph Operations Comparison Group
  Lapis::Benchmark.group "SceneGraph" do |g|
    g.description("Scene tree lifecycle, recursive hierarchy traversal, and group assignment")
    g.category(:engine)
    g.kind(:runtime)
    g.charts(:bar, :speedup, :ratio, :log)
    g.target("NodeLifecycle", "node_lifecycle/node_lifecycle.cr", :crystal)
    g.target("TreeTraversal", "tree_traversal/tree_traversal.cr", :crystal)
    g.target("NodeGroups", "node_groups/node_groups.cr", :crystal)
    g.baseline("NodeLifecycle")
  end

  # Crystal <-> GDScript Interop Round-Trip Stress Comparison Group
  Lapis::Benchmark.group "InteropRoundTrip" do |g|
    g.description("GDExtension boundary dispatch stress test (50,000 round-trip calls) across Variant boundary types")
    g.category(:engine)
    g.kind(:runtime)
    g.charts(:bar, :speedup, :ratio, :log)

    g.subgroup "CrystalToGDScript" do |sg|
      sg.target("Int", "interop_roundtrip/crystal/interop_roundtrip.cr", :crystal, args: ["cr_to_gd_int"])
      sg.target("Float", "interop_roundtrip/crystal/interop_roundtrip.cr", :crystal, args: ["cr_to_gd_float"])
      sg.target("String", "interop_roundtrip/crystal/interop_roundtrip.cr", :crystal, args: ["cr_to_gd_string"])
      sg.target("Vector3", "interop_roundtrip/crystal/interop_roundtrip.cr", :crystal, args: ["cr_to_gd_vector3"])
      sg.target("Node", "interop_roundtrip/crystal/interop_roundtrip.cr", :crystal, args: ["cr_to_gd_node"])
      sg.target("Dictionary", "interop_roundtrip/crystal/interop_roundtrip.cr", :crystal, args: ["cr_to_gd_dictionary"])
    end

    g.subgroup "GDScriptToCrystal" do |sg|
      sg.target("Int", "interop_roundtrip/crystal/interop_roundtrip.cr", :crystal, args: ["gd_to_cr_int"])
      sg.target("Float", "interop_roundtrip/crystal/interop_roundtrip.cr", :crystal, args: ["gd_to_cr_float"])
      sg.target("String", "interop_roundtrip/crystal/interop_roundtrip.cr", :crystal, args: ["gd_to_cr_string"])
      sg.target("Vector3", "interop_roundtrip/crystal/interop_roundtrip.cr", :crystal, args: ["gd_to_cr_vector3"])
      sg.target("Node", "interop_roundtrip/crystal/interop_roundtrip.cr", :crystal, args: ["gd_to_cr_node"])
      sg.target("Dictionary", "interop_roundtrip/crystal/interop_roundtrip.cr", :crystal, args: ["gd_to_cr_dictionary"])
    end

    g.baseline("Int")
  end
end
