module Lapis
  module Docs
    # # V. Performance & Benchmarks Architecture
    #
    # Lapis features a dedicated, 1-to-1 cross-language benchmark suite comparing native compiled
    # **Crystal (GDExtension)** against **GDScript (Godot 4 Bytecode)** across algorithmic compute
    # and engine core operations.
    #
    # ### Executive Summary & Key Topics
    #
    # <table>
    #   <thead>
    #     <tr>
    #       <th>Topic</th>
    #       <th>Method / Anchor</th>
    #       <th>Description</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr>
    #       <td><strong>Key Features</strong></td>
    #       <td><code>.topic_00_key_features</code></td>
    #       <td>Core features of the benchmark suite.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Benchmark Architecture</strong></td>
    #       <td><code>.topic_01_benchmarks_architecture</code></td>
    #       <td>Design of 1-to-1 matching workloads between Crystal and GDScript.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Reporter Patterns</strong></td>
    #       <td><code>.topic_02_reporter_patterns</code></td>
    #       <td>Modular reporters emitting HTML, SVG, Markdown, JSON, and CSV metrics.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Editor vs Standalone</strong></td>
    #       <td><code>.topic_03_in_editor_vs_standalone</code></td>
    #       <td>Measuring engine debugger overhead in the editor vs lean standalone execution.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Visual Dashboards</strong></td>
    #       <td><code>.topic_04_visual_svg_and_html_dashboards</code></td>
    #       <td>Interactive dark-mode dashboards, comparative speedup charts, and CI tracking.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `performance/src/`, `tools/lapis/src/commands/perf.cr`
    # - **Interactive Report**: `docs/benchmarks.html`
    # - **Related Guides**: `Docs::O_LOW_LATENCY_INPUT_GUIDE`, `Docs::R_RELEASE_OPTIMIZATION_AND_EDITOR_STRIPPING`
    module V_PERFORMANCE_AND_BENCHMARKS
      # **Key Features**: Returns core features of the benchmark suite.
      def self.topic_00_key_features : Array(String)
        [
          "1-to-1 matching algorithmic and engine-core benchmarks between Crystal and GDScript",
          "Automated measurement of Godot in-editor execution overhead vs standalone runtime",
          "Multi-format reporting apparatus: interactive HTML, standalone SVG, Markdown, JSON, and CSV",
          "Continuous CI benchmarking and automated deployment to GitHub Pages alongside API documentation",
        ]
      end

      # **1-to-1 Benchmark Architecture**: Design of 1-to-1 matching workloads between Crystal and GDScript.
      #
      # Each benchmark tests identical algorithms implemented in both Crystal and GDScript:
      # - **Raycasting & Spatial Queries**: 100,000 ray intersections against 3D physics worlds.
      # - **A* Pathfinding**: Grid graph path searches across dense maze layouts.
      # - **Particle Kinematics**: Updating 50,000 particle positions and velocities per frame.
      # - **Procedural Terrain**: Simplex noise generation and mesh buffer generation.
      #
      # See also: `performance/src/`
      def self.topic_01_benchmarks_architecture : Nil
      end

      # **Modular Reporter Patterns**: Decoupled reporter architecture emitting HTML, SVG, and JSON metrics.
      #
      # The benchmark runner uses a decoupled reporter pattern:
      #
      # <table>
      #   <thead>
      #     <tr>
      #       <th>Reporter</th>
      #       <th>Output Artifact</th>
      #       <th>Format / Purpose</th>
      #     </tr>
      #   </thead>
      #   <tbody>
      #     <tr>
      #       <td><code>Html</code></td>
      #       <td><code>results/benchmark_report.html</code></td>
      #       <td>Interactive dark-mode web dashboard with SVG charts and KPI cards.</td>
      #     </tr>
      #     <tr>
      #       <td><code>Svg</code></td>
      #       <td><code>results/benchmark_chart.svg</code></td>
      #       <td>Scalable vector graphics bar chart with comparative speedup badges.</td>
      #     </tr>
      #     <tr>
      #       <td><code>Markdown</code></td>
      #       <td><code>results/benchmark_report.md</code></td>
      #       <td>GitHub markdown tables for release notes and PR summaries.</td>
      #     </tr>
      #     <tr>
      #       <td><code>Json</code> / <code>Csv</code></td>
      #       <td><code>results/benchmark_report.json</code></td>
      #       <td>Machine-readable metrics for automated CI regression tracking.</td>
      #     </tr>
      #   </tbody>
      # </table>
      def self.topic_02_reporter_patterns : Nil
      end

      # **In-Editor Overhead vs Standalone Execution**: Quantifying execution overhead inside the Godot Editor.
      #
      # The benchmark suite quantifies the exact performance delta between running inside
      # the Godot Editor (with debugger hooks enabled) and executing via standalone `game.exe`.
      #
      # Run benchmarks locally:
      # ```bash
      # make perf_run
      # ```
      def self.topic_03_in_editor_vs_standalone : Nil
      end

      # **Visual Dashboards & Publication**: Interactive dark-mode dashboards and comparative speedup charts.
      #
      # Benchmark results are automatically converted into SVG charts and dark-mode dashboards
      # published alongside the static manual at `docs/benchmarks.html`.
      def self.topic_04_visual_svg_and_html_dashboards : Nil
      end
    end
  end
end
