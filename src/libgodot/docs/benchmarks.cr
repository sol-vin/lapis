module Lapis
  module Docs
    # # V. Performance & Benchmarks Architecture
    #
    # Lapis features a dedicated, 1-to-1 cross-language benchmark suite comparing native compiled
    # **Crystal (GDExtension)** against **GDScript (Godot 4 Bytecode)** across algorithmic compute
    # and engine core operations.
    #
    # ### Interactive Online Report
    #
    # Explore the live interactive performance report and visual charts at:
    # <a href="../benchmarks.html">https://sol-vin.github.io/lapis/benchmarks.html</a>
    #
    # ### Benchmark Architecture
    #
    # The benchmark system utilizes a modular **Reporter Design Pattern**:
    #
    # <table>
    #   <thead>
    #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
    #       <th style="padding: 10px 14px;">Reporter</th>
    #       <th style="padding: 10px 14px;">Output File</th>
    #       <th style="padding: 10px 14px;">Purpose</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>Html</code></td>
    #       <td style="padding: 10px 14px;"><code>results/benchmark_report.html</code></td>
    #       <td style="padding: 10px 14px;">Self-contained dark-mode interactive dashboard with SVG charts, KPI cards, and filters.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>Svg</code></td>
    #       <td style="padding: 10px 14px;"><code>results/benchmark_chart.svg</code></td>
    #       <td style="padding: 10px 14px;">Scalable vector graphics comparative bar chart with speedup badges and gradients.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>Markdown</code></td>
    #       <td style="padding: 10px 14px;"><code>results/benchmark_report.md</code></td>
    #       <td style="padding: 10px 14px;">GitHub-flavored markdown tables for release notes and pull request summaries.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>Json</code> / <code>Csv</code></td>
    #       <td style="padding: 10px 14px;"><code>results/benchmark_report.json</code></td>
    #       <td style="padding: 10px 14px;">Machine-readable raw metrics and sample timings for automated CI/CD tracking.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>Console</code></td>
    #       <td style="padding: 10px 14px;">Standard Output</td>
    #       <td style="padding: 10px 14px;">Terminal tables with ANSI comparative bar charts and summary statistics.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    module V_PERFORMANCE_AND_BENCHMARKS
      def self.features : Array(String)
        [
          "1-to-1 matching algorithmic and engine-core benchmarks between Crystal and GDScript",
          "Automated measurement of Godot in-editor execution overhead vs standalone runtime",
          "Multi-format reporting apparatus: interactive HTML, standalone SVG, Markdown, JSON, and CSV",
          "Continuous CI benchmarking and automated deployment to GitHub Pages alongside API documentation",
        ]
      end
    end
  end
end

