require "file_utils"
require "./base"

module Benchmarks
  module Reporters
    class Markdown < Base
      property output_rel_path : String = "results/benchmark_report.md"

      def name : String
        "markdown"
      end

      def initialize(@output_rel_path : String = "results/benchmark_report.md")
      end

      def report(results : Array(BenchmarkResult), base_dir : String) : Nil
        return if results.empty?
        metrics = results.map(&.to_metric)
        speedups = metrics.map(&.speedup)
        geo_mean = calculate_geo_mean(speedups)
        max_metric = metrics.max_by(&.speedup)

        compute_metrics = metrics.select { |m| m.category == Category::Compute }
        engine_metrics = metrics.select { |m| m.category == Category::EngineCore }

        has_editor = metrics.any? { |m| m.editor_ms }

        md = String.build do |io|
          io << "# Lapis Performance Report: Crystal vs GDScript Benchmarks\n\n"
          io << "Automated performance comparison between compiled **Crystal (Native GDExtension)** and **GDScript (Godot 4 Bytecode)**"
          io << " with **In-Editor Overhead Analysis**" if has_editor
          io << ".\n\n"
          io << "### Executive Summary\n\n"
          io << "- **Geometric Mean Speedup**: **#{geo_mean.round(1)}x faster**\n"
          io << "- **Peak Speedup**: **#{max_metric.speedup.round(1)}x faster** (#{max_metric.name})\n"
          io << "- **Total Benchmarks**: #{metrics.size} across Algorithmic Compute and Engine Core operations\n"
          io << "- **Optimization**: Crystal `--release -O3` vs Godot Engine Headless\n\n"

          io << "## 1. Algorithmic & Compute Benchmarks\n\n"
          if has_editor
            io << "| Benchmark | Crystal (Native) | GDScript (Standalone) | GDScript (In-Editor) | Speedup / Overhead | Description |\n"
            io << "| :--- | ---: | ---: | ---: | ---: | :--- |\n"
            compute_metrics.each do |m|
              ed_str = m.editor_ms ? "#{m.editor_ms.not_nil!.round(2)} ms" : "-"
              ov_str = if r = m.editor_overhead_ratio
                         pct = (r - 1.0) * 100.0
                         pct >= 0 ? "**#{m.speedup.round(1)}x** (+#{pct.round(0)}% ed)" : "**#{m.speedup.round(1)}x** (#{pct.round(0)}% ed)"
                       else
                         "**#{m.speedup.round(1)}x**"
                       end
              io << "| **#{m.name}** | **#{m.crystal_ms.round(2)} ms** | #{m.gdscript_ms.round(2)} ms | #{ed_str} | #{ov_str} | #{m.description} |\n"
            end
          else
            io << "| Benchmark | Crystal (Native) | GDScript (Standalone) | Speedup Factor | Description |\n"
            io << "| :--- | ---: | ---: | ---: | :--- |\n"
            compute_metrics.each do |m|
              io << "| **#{m.name}** | **#{m.crystal_ms.round(2)} ms** | #{m.gdscript_ms.round(2)} ms | **#{m.speedup.round(1)}x** | #{m.description} |\n"
            end
          end
          io << "\n"

          io << "## 2. Godot Engine Core & SceneTree Benchmarks\n\n"
          if has_editor
            io << "| Benchmark | Crystal (Native) | GDScript (Standalone) | GDScript (In-Editor) | Speedup / Overhead | Description |\n"
            io << "| :--- | ---: | ---: | ---: | ---: | :--- |\n"
            engine_metrics.each do |m|
              ed_str = m.editor_ms ? "#{m.editor_ms.not_nil!.round(2)} ms" : "-"
              ov_str = if r = m.editor_overhead_ratio
                         pct = (r - 1.0) * 100.0
                         pct >= 0 ? "**#{m.speedup.round(1)}x** (+#{pct.round(0)}% ed)" : "**#{m.speedup.round(1)}x** (#{pct.round(0)}% ed)"
                       else
                         "**#{m.speedup.round(1)}x**"
                       end
              io << "| **#{m.name}** | **#{m.crystal_ms.round(2)} ms** | #{m.gdscript_ms.round(2)} ms | #{ed_str} | #{ov_str} | #{m.description} |\n"
            end
          else
            io << "| Benchmark | Crystal (ms) | GDScript (ms) | Speedup Factor | Description |\n"
            io << "| :--- | ---: | ---: | ---: | :--- |\n"
            engine_metrics.each do |m|
              io << "| **#{m.name}** | **#{m.crystal_ms.round(2)} ms** | #{m.gdscript_ms.round(2)} ms | **#{m.speedup.round(1)}x** | #{m.description} |\n"
            end
          end
          io << "\n"

          io << "## 3. Analysis & Key Insights\n\n"
          io << "1. **Compute & Numerical Math**: Crystal demonstrates massive speedups in pure algorithm loops, AST interpreters, matrix math, and particle/physics integration due to LLVM vectorization and native unboxed memory.\n"
          io << "2. **SceneTree & Node Lifecycle**: Crystal manages scene tree nodes with low-overhead native memory handling and fast method binding dispatch.\n"
          io << "3. **Resource & Material Allocation**: Crystal creates and configures `StandardMaterial3D` resources rapidly with type-safe properties and reference counting.\n"
          io << "4. **Spatial Math Primitives**: Crystal's `Transform3D`, `Basis`, and `Vector3` value structs operate in native CPU registers without Variant boxing overhead.\n"
        end

        out_path = File.join(base_dir, @output_rel_path)
        FileUtils.mkdir_p(File.dirname(out_path))
        File.write(out_path, md)
        puts "  \e[32m[Report]\e[0m Saved Markdown report to: #{out_path}"
      end
    end
  end
end
