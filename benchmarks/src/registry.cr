require "./models"

module Benchmarks
  class Registry
    @@benchmarks = [] of BenchmarkCase

    def self.register(bench : BenchmarkCase) : Nil
      @@benchmarks << bench
    end

    def self.all : Array(BenchmarkCase)
      @@benchmarks
    end

    def self.for_category(cat : Category) : Array(BenchmarkCase)
      @@benchmarks.select { |b| b.category == cat }
    end

    def self.find(name : String) : BenchmarkCase?
      target = name.downcase
      @@benchmarks.find { |b| b.name.downcase == target }
    end

    def self.filter(query : String) : Array(BenchmarkCase)
      return @@benchmarks if query.empty?
      target = query.downcase
      @@benchmarks.select { |b| b.name.downcase.includes?(target) || b.description.downcase.includes?(target) }
    end

    # Pre-populate complete benchmark suite with 1-to-1 Crystal and GDScript tests
    register BenchmarkCase.new(
      name: "Matmul",
      category: Category::Compute,
      crystal_src: "matmul/matmul.cr",
      crystal_bin: "bin/matmul",
      gdscript_src: "matmul/matmul.gd",
      args: ["300"],
      description: "Dense 2D matrix multiplication (N=300, float64)"
    )

    register BenchmarkCase.new(
      name: "Primes",
      category: Category::Compute,
      crystal_src: "primes/primes.cr",
      crystal_bin: "bin/primes",
      gdscript_src: "primes/primes.gd",
      args: ["500000", "3233"],
      description: "Sieve of Atkin + Prefix Trie search (Limit=500k)"
    )

    register BenchmarkCase.new(
      name: "Brainfuck",
      category: Category::Compute,
      crystal_src: "brainfuck/bf.cr",
      crystal_bin: "bin/bf",
      gdscript_src: "brainfuck/bf.gd",
      args: ["brainfuck/bench_quick.b"],
      description: "Brainfuck AST interpreter + dynamic tape (bench_quick.b)"
    )

    register BenchmarkCase.new(
      name: "Base64",
      category: Category::Compute,
      crystal_src: "base64/base64.cr",
      crystal_bin: "bin/base64",
      gdscript_src: "base64/base64.gd",
      args: ["65536", "100"],
      description: "Base64 strict encode & decode loop (64 KiB, 100 iter)"
    )

    register BenchmarkCase.new(
      name: "JSON",
      category: Category::Compute,
      crystal_src: "json/json.cr",
      crystal_bin: "bin/json",
      gdscript_src: "json/json.gd",
      args: ["json/1.json"],
      description: "JSON parse & 3D coordinate aggregation (10k items)"
    )

    register BenchmarkCase.new(
      name: "NBody",
      category: Category::Compute,
      crystal_src: "nbody/nbody.cr",
      crystal_bin: "bin/nbody",
      gdscript_src: "nbody/nbody.gd",
      args: ["50000"],
      description: "3D orbital dynamics physics integration (Velocity-Verlet, 50k steps)"
    )

    register BenchmarkCase.new(
      name: "BinaryTrees",
      category: Category::Compute,
      crystal_src: "binarytrees/binarytrees.cr",
      crystal_bin: "bin/binarytrees",
      gdscript_src: "binarytrees/binarytrees.gd",
      args: ["12"],
      description: "GC pressure, bottom-up binary tree allocation & depth traversal"
    )

    register BenchmarkCase.new(
      name: "Mandelbrot",
      category: Category::Compute,
      crystal_src: "mandelbrot/mandelbrot.cr",
      crystal_bin: "bin/mandelbrot",
      gdscript_src: "mandelbrot/mandelbrot.gd",
      args: ["500"],
      description: "2D coordinate escape-time fractal rasterization (500x500)"
    )

    register BenchmarkCase.new(
      name: "TransformMath",
      category: Category::Compute,
      crystal_src: "transform_math/transform_math.cr",
      crystal_bin: "bin/transform_math",
      gdscript_src: "transform_math/transform_math.gd",
      args: ["200000"],
      description: "Transform3D translations, rotations & Vector3 projections (200k ops)"
    )

    register BenchmarkCase.new(
      name: "NodeLifecycle",
      category: Category::EngineCore,
      crystal_src: "node_lifecycle/node_lifecycle.cr",
      crystal_bin: "bin/node_lifecycle",
      gdscript_src: "node_lifecycle/node_lifecycle.gd",
      args: ["20000"],
      description: "Node2D allocation, property mutation, add_child, remove_child, free (20k)"
    )

    register BenchmarkCase.new(
      name: "MaterialResources",
      category: Category::EngineCore,
      crystal_src: "material_resources/material_resources.cr",
      crystal_bin: "bin/material_resources",
      gdscript_src: "material_resources/material_resources.gd",
      args: ["10000"],
      description: "StandardMaterial3D allocation, properties, duplication, refcounting (10k)"
    )

    register BenchmarkCase.new(
      name: "Signals",
      category: Category::EngineCore,
      crystal_src: "signals/signals.cr",
      crystal_bin: "bin/signals",
      gdscript_src: "signals/signals.gd",
      args: ["50000"],
      description: "Signal connection, argument marshalling & dynamic emission (50k calls)"
    )
  end
end
