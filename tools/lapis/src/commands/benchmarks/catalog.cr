require "file_utils"
require "./models"
require "../../core/env"

module Lapis
  module Commands
    module Benchmarks
      # Built-in Benchmark Catalog
      def self.builtin_benchmarks : Array(BenchmarkCase)
        [
          BenchmarkCase.new(
            "Matmul", Category::Compute,
            "matmul/crystal/matmul.cr", "bin/matmul", "matmul/gdscript/matmul.gd", ["300"],
            "Dense 2D matrix multiplication (N=300, float64)",
            cpp_src: "matmul/c++/matmul.cpp", csharp_src: "matmul/c-sharp/matmul.csproj", rust_src: "matmul/rust/matmul.rs",
            group_name: "MatrixMultiplication"
          ),
          BenchmarkCase.new(
            "Primes", Category::Compute,
            "primes/crystal/primes.cr", "bin/primes", "primes/gdscript/primes.gd", ["500000", "3233"],
            "Sieve of Atkin + Prefix Trie search (Limit=500k)",
            cpp_src: "primes/c++/primes.cpp", csharp_src: "primes/c-sharp/primes.csproj", rust_src: "primes/rust/primes.rs",
            group_name: "PrimeSieve"
          ),
          BenchmarkCase.new(
            "Mandelbrot", Category::Compute,
            "mandelbrot/crystal/mandelbrot.cr", "bin/mandelbrot", "mandelbrot/gdscript/mandelbrot.gd", ["500"],
            "2D coordinate escape-time fractal rasterization (500x500)",
            cpp_src: "mandelbrot/c++/mandelbrot.cpp", csharp_src: "mandelbrot/c-sharp/mandelbrot.csproj", rust_src: "mandelbrot/rust/mandelbrot.rs",
            group_name: "Mandelbrot"
          ),
          BenchmarkCase.new(
            "NBody", Category::Compute,
            "nbody/crystal/nbody.cr", "bin/nbody", "nbody/gdscript/nbody.gd", ["50000"],
            "3D orbital dynamics physics integration (Velocity-Verlet, 50k steps)",
            cpp_src: "nbody/c++/nbody.cpp", csharp_src: "nbody/c-sharp/nbody.csproj", rust_src: "nbody/rust/nbody.rs",
            group_name: "NBody"
          ),
          BenchmarkCase.new(
            "BinaryTrees", Category::Compute,
            "binarytrees/crystal/binarytrees.cr", "bin/binarytrees", "binarytrees/gdscript/binarytrees.gd", ["12"],
            "GC pressure, bottom-up binary tree allocation & depth traversal",
            cpp_src: "binarytrees/c++/binarytrees.cpp", csharp_src: "binarytrees/c-sharp/binarytrees.csproj", rust_src: "binarytrees/rust/binarytrees.rs",
            group_name: "BinaryTrees"
          ),
          BenchmarkCase.new("Brainfuck", Category::Compute, "brainfuck/bf.cr", "bin/bf", "brainfuck/bf.gd", ["brainfuck/bench_quick.b"], "Brainfuck AST interpreter + dynamic tape (bench_quick.b)"),
          BenchmarkCase.new("Base64", Category::Compute, "base64/base64.cr", "bin/base64", "base64/base64.gd", ["65536", "100"], "Base64 strict encode & decode loop (64 KiB, 100 iter)"),
          BenchmarkCase.new("JSON", Category::Compute, "json/json.cr", "bin/json", "json/json.gd", ["json/1.json"], "JSON parse & 3D coordinate aggregation (10k items)"),
          BenchmarkCase.new("TransformMath", Category::Compute, "transform_math/transform_math.cr", "bin/transform_math", "transform_math/transform_math.gd", ["200000"], "Transform3D translations, rotations & Vector3 projections (200k ops)"),
          BenchmarkCase.new("VectorMath2D", Category::Compute, "vector_math_2d/vector_math_2d.cr", "bin/vector_math_2d", "vector_math_2d/vector_math_2d.gd", ["500000"], "Vector2 lerp, dot, distance, and normalization across 500k ops"),
          BenchmarkCase.new("NodeLifecycle", Category::EngineCore, "node_lifecycle/node_lifecycle.cr", "bin/node_lifecycle", "node_lifecycle/node_lifecycle.gd", ["20000"], "Node2D allocation, property mutation, add_child, remove_child, free (20k)", group_name: "SceneGraph"),
          BenchmarkCase.new("MaterialResources", Category::EngineCore, "material_resources/material_resources.cr", "bin/material_resources", "material_resources/material_resources.gd", ["10000"], "StandardMaterial3D allocation, properties, duplication, refcounting (10k)"),
          BenchmarkCase.new("Signals", Category::EngineCore, "signals/signals.cr", "bin/signals", "signals/signals.gd", ["50000"], "Signal connection, argument marshalling & dynamic emission (50k calls)"),
          BenchmarkCase.new("PerlinNoise", Category::EngineCore, "perlin_noise/perlin_noise.cr", "bin/perlin_noise", "perlin_noise/perlin_noise.gd", ["500"], "FastNoiseLite 2D Perlin noise across 500x500 grid (250k samples)", group_name: "ProceduralNoise"),
          BenchmarkCase.new("SimplexNoise", Category::EngineCore, "simplex_noise/simplex_noise.cr", "bin/simplex_noise", "simplex_noise/simplex_noise.gd", ["100000"], "FastNoiseLite 3D Simplex Smooth noise across 100k samples", group_name: "ProceduralNoise"),
          BenchmarkCase.new("CellularNoise", Category::EngineCore, "cellular_noise/cellular_noise.cr", "bin/cellular_noise", "cellular_noise/cellular_noise.gd", ["500"], "FastNoiseLite 2D Cellular Voronoi noise across 500x500 grid (250k samples)", group_name: "ProceduralNoise"),
          BenchmarkCase.new("SurfaceTool", Category::EngineCore, "surface_tool/surface_tool.cr", "bin/surface_tool", "surface_tool/surface_tool.gd", ["10000"], "SurfaceTool procedural mesh generation with normals/UVs (10k triangles)"),
          BenchmarkCase.new("AStar2D", Category::EngineCore, "astar_2d/astar_2d.cr", "bin/astar_2d", "astar_2d/astar_2d.gd", ["100", "500"], "AStar2D pathfinding on 100x100 grid (10k points, 500 queries)"),
          BenchmarkCase.new("TreeTraversal", Category::EngineCore, "tree_traversal/tree_traversal.cr", "bin/tree_traversal", "tree_traversal/tree_traversal.gd", ["20000"], "Scene tree recursive traversal & property inspection (20k nodes)", group_name: "SceneGraph"),
          BenchmarkCase.new("ImageProcessing", Category::EngineCore, "image_processing/image_processing.cr", "bin/image_processing", "image_processing/image_processing.gd", ["512"], "512x512 Image procedural pixel computation and gamma blending (262k px)"),
          BenchmarkCase.new("TransformHierarchy", Category::EngineCore, "transform_hierarchy/transform_hierarchy.cr", "bin/transform_hierarchy", "transform_hierarchy/transform_hierarchy.gd", ["15000"], "15,000 Node3D hierarchy transformations & global position resolution"),
          BenchmarkCase.new("NodeGroups", Category::EngineCore, "node_groups/node_groups.cr", "bin/node_groups", "node_groups/node_groups.gd", ["20000"], "20,000 nodes partitioned into 10 groups, group assignment & queries", group_name: "SceneGraph"),
          BenchmarkCase.new("DictionaryOps", Category::EngineCore, "dictionary_ops/dictionary_ops.cr", "bin/dictionary_ops", "dictionary_ops/dictionary_ops.gd", ["50000"], "Godot Dictionary 50,000 insertions and random access lookups"),
          BenchmarkCase.new("ConfigFileOps", Category::EngineCore, "config_file/config_file.cr", "bin/config_file", "config_file/config_file.gd", ["1000"], "ConfigFile parsing, querying and encoding 1,000 section INI config"),
          BenchmarkCase.new("ShaderCompilation", Category::EngineCore, "shader_compilation/shader_compilation.cr", "bin/shader_compilation", "shader_compilation/shader_compilation.gd", ["1000"], "Shader compilation throughput across 1,000 permutations", group_name: "Shaders"),
          BenchmarkCase.new("ShaderUniforms", Category::EngineCore, "shader_uniforms/shader_uniforms.cr", "bin/shader_uniforms", "shader_uniforms/shader_uniforms.gd", ["50000"], "High-frequency uniform parameter dispatch (50k updates)", group_name: "Shaders"),
          BenchmarkCase.new("VisualShader", Category::EngineCore, "visual_shader/visual_shader.cr", "bin/visual_shader", "visual_shader/visual_shader.gd", ["200"], "VisualShader node graph creation and connection (200 graphs)", group_name: "Shaders"),
          BenchmarkCase.new("CompileTimes", Category::Toolchain, "compile_times/compile_times.cr", "bin/compile_times", "", [] of String, "Compilation latency and output binary size across Crystal, C++, C#, Rust (Debug vs Release)", group_name: "CompileTime"),
          # Interop Round-Trip Stress Cases (50,000 dispatches)
          BenchmarkCase.new("Interop_CrToGd_Int", Category::EngineCore, "interop_roundtrip/crystal/interop_roundtrip.cr", "bin/interop_roundtrip", "interop_roundtrip/gdscript/interop_roundtrip.gd", ["cr_to_gd_int", "50000"], "Crystal calling GDScript (Int64, 50k calls)", group_name: "InteropRoundTrip", subgroup: "CrystalToGDScript"),
          BenchmarkCase.new("Interop_CrToGd_Float", Category::EngineCore, "interop_roundtrip/crystal/interop_roundtrip.cr", "bin/interop_roundtrip", "interop_roundtrip/gdscript/interop_roundtrip.gd", ["cr_to_gd_float", "50000"], "Crystal calling GDScript (Float64, 50k calls)", group_name: "InteropRoundTrip", subgroup: "CrystalToGDScript"),
          BenchmarkCase.new("Interop_CrToGd_String", Category::EngineCore, "interop_roundtrip/crystal/interop_roundtrip.cr", "bin/interop_roundtrip", "interop_roundtrip/gdscript/interop_roundtrip.gd", ["cr_to_gd_string", "50000"], "Crystal calling GDScript (String, 50k calls)", group_name: "InteropRoundTrip", subgroup: "CrystalToGDScript"),
          BenchmarkCase.new("Interop_CrToGd_Vector3", Category::EngineCore, "interop_roundtrip/crystal/interop_roundtrip.cr", "bin/interop_roundtrip", "interop_roundtrip/gdscript/interop_roundtrip.gd", ["cr_to_gd_vector3", "50000"], "Crystal calling GDScript (Vector3, 50k calls)", group_name: "InteropRoundTrip", subgroup: "CrystalToGDScript"),
          BenchmarkCase.new("Interop_CrToGd_Node", Category::EngineCore, "interop_roundtrip/crystal/interop_roundtrip.cr", "bin/interop_roundtrip", "interop_roundtrip/gdscript/interop_roundtrip.gd", ["cr_to_gd_node", "50000"], "Crystal calling GDScript (Node, 50k calls)", group_name: "InteropRoundTrip", subgroup: "CrystalToGDScript"),
          BenchmarkCase.new("Interop_CrToGd_Dictionary", Category::EngineCore, "interop_roundtrip/crystal/interop_roundtrip.cr", "bin/interop_roundtrip", "interop_roundtrip/gdscript/interop_roundtrip.gd", ["cr_to_gd_dictionary", "50000"], "Crystal calling GDScript (Dictionary, 50k calls)", group_name: "InteropRoundTrip", subgroup: "CrystalToGDScript"),
          BenchmarkCase.new("Interop_GdToCr_Int", Category::EngineCore, "interop_roundtrip/crystal/interop_roundtrip.cr", "bin/interop_roundtrip", "interop_roundtrip/gdscript/interop_roundtrip.gd", ["gd_to_cr_int", "50000"], "GDScript calling Crystal (Int64, 50k calls)", group_name: "InteropRoundTrip", subgroup: "GDScriptToCrystal"),
          BenchmarkCase.new("Interop_GdToCr_Float", Category::EngineCore, "interop_roundtrip/crystal/interop_roundtrip.cr", "bin/interop_roundtrip", "interop_roundtrip/gdscript/interop_roundtrip.gd", ["gd_to_cr_float", "50000"], "GDScript calling Crystal (Float64, 50k calls)", group_name: "InteropRoundTrip", subgroup: "GDScriptToCrystal"),
          BenchmarkCase.new("Interop_GdToCr_String", Category::EngineCore, "interop_roundtrip/crystal/interop_roundtrip.cr", "bin/interop_roundtrip", "interop_roundtrip/gdscript/interop_roundtrip.gd", ["gd_to_cr_string", "50000"], "GDScript calling Crystal (String, 50k calls)", group_name: "InteropRoundTrip", subgroup: "GDScriptToCrystal"),
          BenchmarkCase.new("Interop_GdToCr_Vector3", Category::EngineCore, "interop_roundtrip/crystal/interop_roundtrip.cr", "bin/interop_roundtrip", "interop_roundtrip/gdscript/interop_roundtrip.gd", ["gd_to_cr_vector3", "50000"], "GDScript calling Crystal (Vector3, 50k calls)", group_name: "InteropRoundTrip", subgroup: "GDScriptToCrystal"),
          BenchmarkCase.new("Interop_GdToCr_Node", Category::EngineCore, "interop_roundtrip/crystal/interop_roundtrip.cr", "bin/interop_roundtrip", "interop_roundtrip/gdscript/interop_roundtrip.gd", ["gd_to_cr_node", "50000"], "GDScript calling Crystal (Node, 50k calls)", group_name: "InteropRoundTrip", subgroup: "GDScriptToCrystal"),
          BenchmarkCase.new("Interop_GdToCr_Dictionary", Category::EngineCore, "interop_roundtrip/crystal/interop_roundtrip.cr", "bin/interop_roundtrip", "interop_roundtrip/gdscript/interop_roundtrip.gd", ["gd_to_cr_dictionary", "50000"], "GDScript calling Crystal (Dictionary, 50k calls)", group_name: "InteropRoundTrip", subgroup: "GDScriptToCrystal"),
        ]
      end

      # Built-in Canonical Comparison Groups
      def self.builtin_groups : Array(ComparisonGroupSpec)
        [
          ComparisonGroupSpec.new(
            "MatrixMultiplication",
            Category::Compute,
            "Dense 2D matrix multiplication (N=300, float64) across languages",
            "Crystal",
            ["Matmul"],
            kind: :runtime,
            chart_types: [:bar, :speedup, :ratio, :log]
          ),
          ComparisonGroupSpec.new(
            "PrimeSieve",
            Category::Compute,
            "Sieve of Atkin prime generation + Prefix Trie search across languages",
            "Crystal",
            ["Primes"],
            kind: :runtime,
            chart_types: [:bar, :speedup, :ratio, :log]
          ),
          ComparisonGroupSpec.new(
            "Mandelbrot",
            Category::Compute,
            "2D coordinate escape-time fractal rasterization (500x500) across languages",
            "Crystal",
            ["Mandelbrot"],
            kind: :runtime,
            chart_types: [:bar, :speedup, :ratio, :log]
          ),
          ComparisonGroupSpec.new(
            "NBody",
            Category::Compute,
            "3D orbital dynamics physics integration (Velocity-Verlet, 50k steps) across languages",
            "Crystal",
            ["NBody"],
            kind: :runtime,
            chart_types: [:bar, :speedup, :ratio, :log]
          ),
          ComparisonGroupSpec.new(
            "BinaryTrees",
            Category::Compute,
            "Bottom-up binary tree allocation, GC pressure, and depth traversal across languages",
            "Crystal",
            ["BinaryTrees"],
            kind: :runtime,
            chart_types: [:bar, :speedup, :ratio, :log]
          ),
          ComparisonGroupSpec.new(
            "CompileTime",
            Category::Toolchain,
            "Compilation latency and output binary sizes across languages (Debug vs Release)",
            "Crystal",
            ["CompileTimes"],
            kind: :compile_time,
            chart_types: [:debug_vs_release, :size, :bar, :speedup]
          ),
          ComparisonGroupSpec.new(
            "Shaders",
            Category::EngineCore,
            "Shader compilation throughput, uniform parameter dispatch, and VisualShader graph assembly",
            "ShaderCompilation",
            ["ShaderCompilation", "ShaderUniforms", "VisualShader"],
            kind: :throughput,
            chart_types: [:throughput, :bar, :speedup]
          ),
          ComparisonGroupSpec.new(
            "ProceduralNoise",
            Category::EngineCore,
            "FastNoiseLite evaluation across Perlin, Simplex, and Cellular Voronoi noise",
            "PerlinNoise",
            ["PerlinNoise", "SimplexNoise", "CellularNoise"],
            kind: :runtime,
            chart_types: [:bar, :speedup, :ratio, :log]
          ),
          ComparisonGroupSpec.new(
            "SceneGraph",
            Category::EngineCore,
            "Scene tree lifecycle, recursive hierarchy traversal, and group assignment",
            "NodeLifecycle",
            ["NodeLifecycle", "TreeTraversal", "NodeGroups"],
            kind: :runtime,
            chart_types: [:bar, :speedup, :ratio, :log]
          ),
          ComparisonGroupSpec.new(
            "InteropRoundTrip",
            Category::EngineCore,
            "GDExtension boundary dispatch stress test (50,000 round-trip calls) across Variant boundary types",
            "Interop_CrToGd_Int",
            [
              "Interop_CrToGd_Int", "Interop_CrToGd_Float", "Interop_CrToGd_String", "Interop_CrToGd_Vector3", "Interop_CrToGd_Node", "Interop_CrToGd_Dictionary",
              "Interop_GdToCr_Int", "Interop_GdToCr_Float", "Interop_GdToCr_String", "Interop_GdToCr_Vector3", "Interop_GdToCr_Node", "Interop_GdToCr_Dictionary",
            ],
            kind: :runtime,
            chart_types: [:bar, :speedup, :ratio, :log]
          ),
        ]
      end

      def self.discover_groups(benchmarks_dir : Path) : Array(ComparisonGroupSpec)
        groups = builtin_groups.dup
        {% if @top_level.has_constant?("Lapis") && Lapis.has_constant?("Benchmark") %}
          begin
            ::Lapis::Benchmark.all_groups.each do |g|
              groups << ComparisonGroupSpec.new(
                g.name,
                Category.parse_str(g.category.display_name),
                g.description,
                g.baseline_name || "Crystal",
                g.targets.map(&.name),
                g.kind,
                g.chart_types
              ) unless groups.any? { |existing| existing.name.downcase == g.name.downcase }
            end
          rescue
          end
        {% end %}
        groups
      end

      # Discovers benchmarks in a directory (both flat benchmarks/*.cr, nested benchmarks/<name>/<name>.cr,
      # and language-partitioned benchmarks/<name>/<lang>/<name>.<ext>)
      def self.discover_benchmarks(benchmarks_dir : Path) : Array(BenchmarkCase)
        found = [] of BenchmarkCase
        builtin_by_dir = Hash(String, BenchmarkCase).new
        builtin_benchmarks.each do |b|
          dir_name = b.crystal_src.split('/').first.downcase
          builtin_by_dir[dir_name] = b
          builtin_by_dir[b.name.downcase.gsub('_', "")] = b
        end

        if Dir.exists?(benchmarks_dir)
          Dir.children(benchmarks_dir).sort.each do |entry|
            next if ["src", "bin", "reports", "results", ".godot", "obj"].includes?(entry.downcase)
            entry_path = benchmarks_dir.join(entry)

            # Subdirectory benchmarks/<entry>/
            if Dir.exists?(entry_path)
              # Check nested language directories first:
              # benchmarks/<entry>/crystal/<entry>.cr (or *.cr)
              cr_nested = entry_path.join("crystal", "#{entry}.cr")
              cr_flat = entry_path.join("#{entry}.cr")
              actual_cr : Path? = if File.exists?(cr_nested)
                                    cr_nested
                                  elsif File.exists?(cr_flat)
                                    cr_flat
                                  elsif Dir.exists?(entry_path.join("crystal"))
                                    Dir.glob(entry_path.join("crystal", "*.cr").to_s.gsub('\\', '/')).first?.try { |p| Path.new(p) }
                                  else
                                    Dir.glob(entry_path.join("*.cr").to_s.gsub('\\', '/')).first?.try { |p| Path.new(p) }
                                  end

              if actual_cr && File.exists?(actual_cr)
                # Resolve relative paths from benchmarks_dir
                rel_cr = actual_cr.to_s.sub(benchmarks_dir.to_s, "").gsub('\\', '/').lstrip('/')

                # Check GDScript
                gd_nested = entry_path.join("gdscript", "#{entry}.gd")
                gd_flat = entry_path.join("#{entry}.gd")
                rel_gd = if File.exists?(gd_nested)
                           gd_nested.to_s.sub(benchmarks_dir.to_s, "").gsub('\\', '/').lstrip('/')
                         elsif File.exists?(gd_flat)
                           gd_flat.to_s.sub(benchmarks_dir.to_s, "").gsub('\\', '/').lstrip('/')
                         else
                           ""
                         end

                # Check C++
                cpp_nested = entry_path.join("c++", "#{entry}.cpp")
                cpp_flat = entry_path.join("#{entry}.cpp")
                rel_cpp = if File.exists?(cpp_nested)
                            cpp_nested.to_s.sub(benchmarks_dir.to_s, "").gsub('\\', '/').lstrip('/')
                          elsif File.exists?(cpp_flat)
                            cpp_flat.to_s.sub(benchmarks_dir.to_s, "").gsub('\\', '/').lstrip('/')
                          else
                            nil
                          end

                # Check C#
                cs_nested_proj = entry_path.join("c-sharp", "#{entry}.csproj")
                cs_flat_proj = entry_path.join("#{entry}.csproj")
                cs_nested_cs = entry_path.join("c-sharp", "#{entry}.cs")
                cs_flat_cs = entry_path.join("#{entry}.cs")
                rel_cs = if File.exists?(cs_nested_proj)
                           cs_nested_proj.to_s.sub(benchmarks_dir.to_s, "").gsub('\\', '/').lstrip('/')
                         elsif File.exists?(cs_flat_proj)
                           cs_flat_proj.to_s.sub(benchmarks_dir.to_s, "").gsub('\\', '/').lstrip('/')
                         elsif File.exists?(cs_nested_cs)
                           cs_nested_cs.to_s.sub(benchmarks_dir.to_s, "").gsub('\\', '/').lstrip('/')
                         elsif File.exists?(cs_flat_cs)
                           cs_flat_cs.to_s.sub(benchmarks_dir.to_s, "").gsub('\\', '/').lstrip('/')
                         else
                           nil
                         end

                # Check Rust
                rs_nested = entry_path.join("rust", "#{entry}.rs")
                rs_flat = entry_path.join("#{entry}.rs")
                rel_rs = if File.exists?(rs_nested)
                           rs_nested.to_s.sub(benchmarks_dir.to_s, "").gsub('\\', '/').lstrip('/')
                         elsif File.exists?(rs_flat)
                           rs_flat.to_s.sub(benchmarks_dir.to_s, "").gsub('\\', '/').lstrip('/')
                         else
                           nil
                         end

                if match = builtin_by_dir[entry.downcase]? || builtin_by_dir[entry.downcase.gsub('_', "")]?
                  # Upgrade matched builtin with resolved on-disk paths
                  found << BenchmarkCase.new(
                    name: match.name,
                    category: match.category,
                    crystal_src: rel_cr,
                    crystal_bin: match.crystal_bin,
                    gdscript_src: !rel_gd.empty? ? rel_gd : match.gdscript_src,
                    args: match.args,
                    description: match.description,
                    cpp_src: rel_cpp || match.cpp_src,
                    csharp_src: rel_cs || match.csharp_src,
                    rust_src: rel_rs || match.rust_src,
                    group_name: match.group_name
                  )
                else
                  found << BenchmarkCase.new(
                    name: entry.capitalize,
                    category: Category::Custom,
                    crystal_src: rel_cr,
                    crystal_bin: "bin/#{entry}",
                    gdscript_src: rel_gd,
                    args: [] of String,
                    description: "Custom benchmark in #{entry}",
                    cpp_src: rel_cpp,
                    csharp_src: rel_cs,
                    rust_src: rel_rs,
                    group_name: entry.capitalize
                  )
                end
              end
            # Case 2: Flat file benchmarks/<entry>.cr (excluding runner.cr, groups.cr, and hooks.cr)
            elsif entry.ends_with?(".cr") && !["runner.cr", "groups.cr", "hooks.cr"].includes?(entry)
              base_name = entry.sub(/\.cr$/, "")
              gd_src = benchmarks_dir.join("#{base_name}.gd")
              found << BenchmarkCase.new(
                name: base_name.capitalize,
                category: Category::Custom,
                crystal_src: entry,
                crystal_bin: "bin/#{base_name}",
                gdscript_src: File.exists?(gd_src) ? "#{base_name}.gd" : "",
                args: [] of String,
                description: "Benchmark #{base_name}"
              )
            end
          end
        end

        # Only fall back to builtin_benchmarks if running in root Lapis benchmarks directory
        if found.empty? && benchmarks_dir == Core::Env::ROOT_DIR.join("benchmarks")
          builtin_benchmarks
        else
          found
        end
      end
    end
  end
end
