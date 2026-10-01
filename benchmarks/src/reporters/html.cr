require "file_utils"
require "./base"
require "./svg"

module Benchmarks
  module Reporters
    class Html < Base
      property output_rel_path : String = "results/benchmark_report.html"

      def name : String
        "html"
      end

      def initialize(@output_rel_path : String = "results/benchmark_report.html")
      end

      def report(results : Array(BenchmarkResult), base_dir : String) : Nil
        return if results.empty?
        metrics = results.map(&.to_metric)
        speedups = metrics.map(&.speedup)
        geo_mean = calculate_geo_mean(speedups)
        max_metric = metrics.max_by(&.speedup)
        svg_chart = Svg.generate_svg(results)

        compute_metrics = metrics.select { |m| m.category == Category::Compute }
        engine_metrics = metrics.select { |m| m.category == Category::EngineCore }

        comp_speedups = compute_metrics.map(&.speedup)
        comp_geo = calculate_geo_mean(comp_speedups)

        eng_speedups = engine_metrics.map(&.speedup)
        eng_geo = calculate_geo_mean(eng_speedups)

        has_editor = metrics.any? { |m| m.editor_ms }
        overhead_values = metrics.compact_map(&.editor_overhead_ratio)
        avg_overhead = overhead_values.empty? ? nil : ((overhead_values.sum / overhead_values.size - 1.0) * 100.0).round(1)

        editor_kpi_card = if has_editor && avg_overhead
          sign = avg_overhead >= 0 ? "+" : ""
          <<-HTML
          <div class="kpi-card">
            <span class="kpi-title">GDScript Editor Overhead</span>
            <span class="kpi-value purple">#{sign}#{avg_overhead}%</span>
            <span class="kpi-sub">Avg In-Editor vs Standalone</span>
          </div>
          HTML
        else
          ""
        end

        table_header = if has_editor
          <<-HTML
          <tr>
            <th>Benchmark</th>
            <th>Description</th>
            <th class="num">Crystal (Native)</th>
            <th class="num">GDScript (Standalone)</th>
            <th class="num">GDScript (In-Editor)</th>
            <th class="num">Speedup</th>
          </tr>
          HTML
        else
          <<-HTML
          <tr>
            <th>Benchmark</th>
            <th>Description</th>
            <th class="num">Crystal (Native)</th>
            <th class="num">GDScript (Standalone)</th>
            <th class="num">Speedup</th>
          </tr>
          HTML
        end

        render_rows = ->(group_metrics : Array(BenchmarkMetric)) do
          group_metrics.map do |m|
            ed_cell = if has_editor
              if ed = m.editor_ms
                ov_html = if r = m.editor_overhead_ratio
                  pct = ((r - 1.0) * 100.0).round(0).to_i
                  pct >= 0 ? %(<span class="overhead-badge warn">+#{pct}%</span>) : %(<span class="overhead-badge good">#{pct}%</span>)
                else
                  ""
                end
                %(<td class="num" style="color: #d2a8ff; font-weight: 600;">#{ed.round(2)} ms #{ov_html}</td>)
              else
                %(<td class="num" style="color: var(--text-muted);">-</td>)
              end
            else
              ""
            end

            "          <tr>
            <td><strong>#{m.name}</strong></td>
            <td style=\"color: var(--text-muted); font-size: 0.9rem;\">#{m.description}</td>
            <td class=\"num\" style=\"color: var(--crystal-cyan); font-weight: 700;\">#{m.crystal_ms.round(2)} ms</td>
            <td class=\"num\" style=\"color: var(--gd-amber); font-weight: 600;\">#{m.gdscript_ms.round(2)} ms</td>
            #{ed_cell}
            <td class=\"num\"><span class=\"speedup-badge\">#{m.speedup.round(1)}x faster</span></td>
          </tr>"
          end.join("\n")
        end

        html = <<-HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Lapis Performance Report: Crystal vs GDScript</title>
  <style>
    :root {
      --bg: #0d1117;
      --card-bg: #161b22;
      --card-border: #30363d;
      --text-main: #f0f6fc;
      --text-muted: #8b949e;
      --crystal-cyan: #00d2ff;
      --crystal-blue: #0077b6;
      --gd-amber: #ff9900;
      --success-green: #238636;
      --accent: #58a6ff;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: var(--bg);
      color: var(--text-main);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      line-height: 1.6;
      padding: 40px 24px;
    }
    .container {
      max-width: 1100px;
      margin: 0 auto;
    }
    header {
      margin-bottom: 32px;
      border-bottom: 1px solid var(--card-border);
      padding-bottom: 24px;
    }
    h1 {
      font-size: 2.2rem;
      font-weight: 800;
      background: linear-gradient(135deg, #00d2ff, #58a6ff, #a371f7);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      margin-bottom: 8px;
    }
    .subtitle {
      color: var(--text-muted);
      font-size: 1.1rem;
    }
    .kpi-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(190px, 1fr));
      gap: 16px;
      margin-bottom: 36px;
    }
    .kpi-card {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 10px;
      padding: 20px;
      display: flex;
      flex-direction: column;
      box-shadow: 0 4px 12px rgba(0,0,0,0.25);
    }
    .kpi-title {
      color: var(--text-muted);
      font-size: 0.85rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      margin-bottom: 6px;
    }
    .kpi-value {
      font-size: 2.2rem;
      font-weight: 800;
      line-height: 1.1;
      margin-bottom: 4px;
    }
    .kpi-value.cyan { color: var(--crystal-cyan); }
    .kpi-value.green { color: #3fb950; }
    .kpi-value.purple { color: #d2a8ff; }
    .kpi-sub {
      color: var(--text-muted);
      font-size: 0.8rem;
    }
    .chart-container {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 12px;
      padding: 24px;
      margin-bottom: 36px;
      box-shadow: 0 4px 16px rgba(0,0,0,0.3);
      text-align: center;
      overflow-x: auto;
    }
    .chart-container svg {
      max-width: 100%;
      height: auto;
      border-radius: 8px;
      display: block;
      margin: 0 auto;
    }
    .section-title {
      font-size: 1.4rem;
      font-weight: 700;
      margin: 32px 0 16px 0;
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .badge-cat {
      font-size: 0.75rem;
      padding: 2px 8px;
      border-radius: 12px;
      font-weight: 600;
    }
    .badge-compute { background: rgba(56, 139, 253, 0.2); color: #58a6ff; border: 1px solid rgba(56, 139, 253, 0.4); }
    .badge-engine { background: rgba(187, 128, 255, 0.2); color: #d2a8ff; border: 1px solid rgba(187, 128, 255, 0.4); }
    .table-container {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 10px;
      overflow: hidden;
      margin-bottom: 32px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      text-align: left;
    }
    th, td {
      padding: 14px 18px;
      border-bottom: 1px solid var(--card-border);
    }
    th {
      background: #1c2128;
      font-weight: 600;
      font-size: 0.85rem;
      color: var(--text-muted);
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }
    tr:last-child td { border-bottom: none; }
    tr:hover td { background: rgba(255, 255, 255, 0.02); }
    td.num {
      text-align: right;
      font-variant-numeric: tabular-nums;
    }
    .speedup-badge {
      display: inline-block;
      padding: 3px 10px;
      border-radius: 12px;
      font-size: 0.85rem;
      font-weight: 700;
      background: rgba(35, 134, 54, 0.25);
      color: #3fb950;
      border: 1px solid rgba(35, 134, 54, 0.5);
      white-space: nowrap;
    }
    .overhead-badge {
      display: inline-block;
      padding: 2px 7px;
      border-radius: 10px;
      font-size: 0.75rem;
      font-weight: 600;
      margin-left: 6px;
      white-space: nowrap;
    }
    .overhead-badge.warn {
      background: rgba(210, 153, 34, 0.2);
      color: #e3b341;
      border: 1px solid rgba(210, 153, 34, 0.4);
    }
    .overhead-badge.good {
      background: rgba(56, 139, 253, 0.2);
      color: #58a6ff;
      border: 1px solid rgba(56, 139, 253, 0.4);
    }
    footer {
      text-align: center;
      color: var(--text-muted);
      font-size: 0.85rem;
      border-top: 1px solid var(--card-border);
      padding-top: 24px;
      margin-top: 40px;
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>Lapis Performance Report</h1>
      <p class="subtitle">Comprehensive 1-to-1 Benchmark Comparison: Crystal (Native GDExtension) vs GDScript (Godot 4 Bytecode)</p>
    </header>

    <div class="kpi-grid">
      <div class="kpi-card">
        <span class="kpi-title">Geometric Mean Speedup</span>
        <span class="kpi-value cyan">#{geo_mean.round(1)}x</span>
        <span class="kpi-sub">Across all #{metrics.size} benchmarks</span>
      </div>
      <div class="kpi-card">
        <span class="kpi-title">Peak Speedup</span>
        <span class="kpi-value green">#{max_metric.speedup.round(1)}x</span>
        <span class="kpi-sub">#{max_metric.name} benchmark</span>
      </div>
#{editor_kpi_card}
      <div class="kpi-card">
        <span class="kpi-title">Compute Speedup</span>
        <span class="kpi-value">#{comp_geo.round(1)}x</span>
        <span class="kpi-sub">#{compute_metrics.size} numerical & AST tests</span>
      </div>
      <div class="kpi-card">
        <span class="kpi-title">Engine Core Speedup</span>
        <span class="kpi-value">#{eng_geo.round(1)}x</span>
        <span class="kpi-sub">#{engine_metrics.size} scene, resource & signal tests</span>
      </div>
    </div>

    <div class="chart-container">
      #{svg_chart}
    </div>

    <h2 class="section-title">
      Algorithmic & Compute Benchmarks
      <span class="badge-cat badge-compute">Compute</span>
    </h2>
    <div class="table-container">
      <table>
        <thead>
#{table_header}
        </thead>
        <tbody>
#{render_rows.call(compute_metrics)}
        </tbody>
      </table>
    </div>

    <h2 class="section-title">
      Godot Engine Core & SceneTree Benchmarks
      <span class="badge-cat badge-engine">Engine Core</span>
    </h2>
    <div class="table-container">
      <table>
        <thead>
#{table_header}
        </thead>
        <tbody>
#{render_rows.call(engine_metrics)}
        </tbody>
      </table>
    </div>

    <footer>
      Generated automatically by Lapis Benchmark Runner · LibGodot for Crystal
    </footer>
  </div>
</body>
</html>
HTML

        out_path = File.join(base_dir, @output_rel_path)
        FileUtils.mkdir_p(File.dirname(out_path))
        File.write(out_path, html)
        puts "  \e[32m[Report]\e[0m Saved Interactive HTML report to: #{out_path}"
      end
    end
  end
end
