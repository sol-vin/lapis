require "../core/env"
require "../core/logger"
require "../core/process_runner"
require "../core/godot_finder"
require "file_utils"
require "option_parser"
require "xml"
require "http/client"

module Lapis
  module Commands
    module Benchmarks
      enum Category
        Compute
        EngineCore
        Custom

        def display_name : String
          case self
          in Compute    then "Compute"
          in EngineCore then "EngineCore"
          in Custom     then "Custom"
          end
        end

        def self.parse_str(str : String) : Category
          case str.downcase
          when "compute", "comp"
            Compute
          when "engine", "enginecore", "engine_core", "core"
            EngineCore
          else
            Custom
          end
        end
      end

      record BenchmarkCase,
        name : String,
        category : Category,
        crystal_src : String,
        crystal_bin : String,
        gdscript_src : String,
        args : Array(String),
        description : String

      record BenchmarkMetric,
        name : String,
        category : Category,
        crystal_ms : Float64,
        gdscript_ms : Float64,
        speedup : Float64,
        description : String,
        editor_ms : Float64? = nil,
        editor_overhead_ratio : Float64? = nil

      record BenchmarkResult,
        benchmark : BenchmarkCase,
        crystal_samples : Array(Float64),
        gdscript_samples : Array(Float64),
        crystal_ms : Float64,
        gdscript_ms : Float64,
        crystal_min_ms : Float64,
        crystal_max_ms : Float64,
        gdscript_min_ms : Float64,
        gdscript_max_ms : Float64,
        speedup : Float64,
        editor_samples : Array(Float64) = [] of Float64,
        editor_ms : Float64? = nil,
        editor_overhead_ratio : Float64? = nil do
        def name : String
          benchmark.name
        end

        def category : Category
          benchmark.category
        end

        def description : String
          benchmark.description
        end

        def to_metric : BenchmarkMetric
          BenchmarkMetric.new(
            name: name,
            category: category,
            crystal_ms: crystal_ms,
            gdscript_ms: gdscript_ms,
            speedup: speedup,
            description: description,
            editor_ms: editor_ms,
            editor_overhead_ratio: editor_overhead_ratio
          )
        end
      end

      # =========================================================================
      # XML Interchange & Parser
      # =========================================================================
      module XmlHandler
        def self.generate_xml(
          metrics : Array(BenchmarkMetric),
          version : String,
          godot_ver : String,
          iterations : Int32,
          platform : String,
          tag : String? = nil
        ) : String
          speedups = metrics.map(&.speedup).reject { |s| s <= 0.0 }
          geomean = calculate_geomean(speedups)
          comp_geo = calculate_geomean(metrics.select { |m| m.category == Category::Compute }.map(&.speedup).reject { |s| s <= 0.0 })
          eng_geo = calculate_geomean(metrics.select { |m| m.category == Category::EngineCore }.map(&.speedup).reject { |s| s <= 0.0 })
          timestamp = ::Time.utc.to_rfc3339
          tag_attr = tag && !tag.empty? ? %( tag="#{escape_xml(tag)}") : ""

          String.build do |io|
            io << %(<?xml version="1.0" encoding="UTF-8"?>\n)
            io << %(<benchmarks version="#{escape_xml(version)}"#{tag_attr} timestamp="#{timestamp}" platform="#{platform}" godot="#{godot_ver}" iterations="#{iterations}">\n)
            io << %(  <summary total="#{metrics.size}" speedup_geomean="#{geomean.round(2)}" compute_geomean="#{comp_geo.round(2)}" engine_geomean="#{eng_geo.round(2)}" />\n)
            metrics.each do |m|
              io << %(  <case name="#{escape_xml(m.name)}" category="#{m.category.display_name}">\n)
              io << %(    <description>#{escape_xml(m.description)}</description>\n)
              io << %(    <crystal ms="#{m.crystal_ms.round(2)}" />\n)
              io << %(    <gdscript ms="#{m.gdscript_ms.round(2)}" />\n)
              if ed = m.editor_ms
                ov = m.editor_overhead_ratio || 1.0
                io << %(    <editor ms="#{ed.round(2)}" overhead_ratio="#{ov.round(3)}" />\n)
              end
              io << %(    <speedup ratio="#{m.speedup.round(2)}" />\n)
              io << %(  </case>\n)
            end
            io << %(</benchmarks>\n)
          end
        end

        def self.parse_xml(xml_content : String) : Tuple(Hash(String, String), Array(BenchmarkMetric))
          doc = XML.parse(xml_content)
          root = doc.first_element_child
          metadata = Hash(String, String).new
          metrics = [] of BenchmarkMetric

          if root && root.name == "benchmarks"
            ["version", "tag", "timestamp", "platform", "godot", "iterations"].each do |attr|
              metadata[attr] = root[attr]? || ""
            end
            if metadata["tag"]?.nil? || metadata["tag"].empty?
              metadata["tag"] = metadata["version"]? || ""
            end

            root.children.each do |child|
              next unless child.name == "case"
              name = child["name"]? || "Unknown"
              cat_str = child["category"]? || "Custom"
              category = Category.parse_str(cat_str)
              desc = ""
              crystal_ms = 0.0
              gdscript_ms = 0.0
              speedup = 1.0
              editor_ms : Float64? = nil
              editor_ov : Float64? = nil

              child.children.each do |sub|
                case sub.name
                when "description"
                  desc = sub.text.strip
                when "crystal"
                  crystal_ms = sub["ms"]?.try(&.to_f?) || 0.0
                when "gdscript"
                  gdscript_ms = sub["ms"]?.try(&.to_f?) || 0.0
                when "editor"
                  editor_ms = sub["ms"]?.try(&.to_f?)
                  editor_ov = sub["overhead_ratio"]?.try(&.to_f?)
                when "speedup"
                  speedup = sub["ratio"]?.try(&.to_f?) || 1.0
                end
              end

              if speedup == 1.0 && crystal_ms > 0.0 && gdscript_ms > 0.0
                speedup = gdscript_ms / crystal_ms
              end

              metrics << BenchmarkMetric.new(
                name: name,
                category: category,
                crystal_ms: crystal_ms,
                gdscript_ms: gdscript_ms,
                speedup: speedup,
                description: desc,
                editor_ms: editor_ms,
                editor_overhead_ratio: editor_ov
              )
            end
          end

          {metadata, metrics}
        end

        def self.generate_comparison_xml(
          curr_metrics : Array(BenchmarkMetric),
          prev_metrics : Array(BenchmarkMetric),
          curr_ver : String,
          prev_ver : String,
          curr_tag : String? = nil,
          prev_tag : String? = nil
        ) : String
          curr_map = curr_metrics.to_h { |m| {m.name, m} }
          prev_map = prev_metrics.to_h { |m| {m.name, m} }
          all_names = (curr_map.keys + prev_map.keys).uniq.sort

          curr_speedups = curr_metrics.map(&.speedup).reject { |s| s <= 0.0 }
          prev_speedups = prev_metrics.map(&.speedup).reject { |s| s <= 0.0 }
          curr_geo = calculate_geomean(curr_speedups)
          prev_geo = calculate_geomean(prev_speedups)
          overall_diff_pct = prev_geo > 0 ? ((curr_geo - prev_geo) / prev_geo) * 100.0 : 0.0

          c_tag_attr = curr_tag && !curr_tag.empty? ? %( current_tag="#{escape_xml(curr_tag)}") : ""
          p_tag_attr = prev_tag && !prev_tag.empty? ? %( previous_tag="#{escape_xml(prev_tag)}") : ""

          String.build do |io|
            io << %(<?xml version="1.0" encoding="UTF-8"?>\n)
            io << %(<benchmark_comparison current_version="#{escape_xml(curr_ver)}" previous_version="#{escape_xml(prev_ver)}"#{c_tag_attr}#{p_tag_attr} timestamp="#{::Time.utc.to_rfc3339}">\n)
            io << %(  <summary current_geomean="#{curr_geo.round(2)}" previous_geomean="#{prev_geo.round(2)}" delta_percent="#{overall_diff_pct.round(1)}" />\n)
            all_names.each do |name|
              c = curr_map[name]?
              p = prev_map[name]?
              desc = c.try(&.description) || p.try(&.description) || ""
              cat = c.try(&.category.display_name) || p.try(&.category.display_name) || "Custom"

              io << %(  <case name="#{escape_xml(name)}" category="#{cat}">\n)
              io << %(    <description>#{escape_xml(desc)}</description>\n)
              if c
                io << %(    <current crystal_ms="#{c.crystal_ms.round(2)}" gdscript_ms="#{c.gdscript_ms.round(2)}" speedup="#{c.speedup.round(2)}" />\n)
              end
              if p
                io << %(    <previous crystal_ms="#{p.crystal_ms.round(2)}" gdscript_ms="#{p.gdscript_ms.round(2)}" speedup="#{p.speedup.round(2)}" />\n)
              end
              if c && p && p.crystal_ms > 0
                pct = ((c.crystal_ms - p.crystal_ms) / p.crystal_ms) * 100.0
                status = pct < -1.0 ? "improved" : (pct > 1.0 ? "regressed" : "neutral")
                io << %(    <delta crystal_ms_diff="#{(c.crystal_ms - p.crystal_ms).round(2)}" percent="#{pct.round(1)}" status="#{status}" />\n)
              end
              io << %(  </case>\n)
            end
            io << %(</benchmark_comparison>\n)
          end
        end

        def self.escape_xml(str : String) : String
          str.to_s
            .gsub('&', "&amp;")
            .gsub('<', "&lt;")
            .gsub('>', "&gt;")
            .gsub('"', "&quot;")
            .gsub('\'', "&apos;")
        end

        def self.calculate_geomean(values : Array(Float64)) : Float64
          return 0.0 if values.empty?
          log_sum = values.sum { |v| Math.log(v > 0.0 ? v : 0.0001) }
          Math.exp(log_sum / values.size)
        end
      end

      # =========================================================================
      # HTML Reporting & Visualization
      # =========================================================================
      module HtmlGenerator
        record HistoryEntry,
          tag : String,
          version : String,
          godot_ver : String,
          filename : String,
          xml_filename : String,
          speedup : Float64? = nil,
          timestamp : String? = nil

        record ComparisonEntry,
          prev_tag : String,
          curr_tag : String,
          filename : String,
          xml_filename : String? = nil,
          delta_pct : Float64? = nil

        def self.generate_report(
          metrics : Array(BenchmarkMetric),
          version : String,
          platform : String,
          godot_ver : String,
          title : String = "Lapis Benchmark Suite: Performance Report",
          tag : String? = nil,
          history : Array(HistoryEntry)? = nil,
          comparisons : Array(ComparisonEntry)? = nil,
          prev_tag : String? = nil,
          prev_speedup : Float64? = nil
        ) : String
          return "" if metrics.empty?
          speedups = metrics.map(&.speedup).reject { |s| s <= 0.0 }
          geo_mean = XmlHandler.calculate_geomean(speedups)
          max_metric = metrics.max_by(&.speedup)

          compute_metrics = metrics.select { |m| m.category == Category::Compute }
          engine_metrics = metrics.select { |m| m.category == Category::EngineCore }
          comp_geo = XmlHandler.calculate_geomean(compute_metrics.map(&.speedup).reject { |s| s <= 0.0 })
          eng_geo = XmlHandler.calculate_geomean(engine_metrics.map(&.speedup).reject { |s| s <= 0.0 })

          has_editor = metrics.any? { |m| m.editor_ms }
          overhead_values = metrics.compact_map(&.editor_overhead_ratio)
          avg_overhead = overhead_values.empty? ? nil : ((overhead_values.sum / overhead_values.size - 1.0) * 100.0).round(1)

          svg_chart = SvgGenerator.generate_svg(metrics)

          render_rows = ->(group : Array(BenchmarkMetric)) do
            group.map do |m|
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

              %(<tr>
                <td><strong>#{XmlHandler.escape_xml(m.name)}</strong></td>
                <td style="color: var(--text-muted); font-size: 0.9rem;">#{XmlHandler.escape_xml(m.description)}</td>
                <td class="num" style="color: var(--crystal-cyan); font-weight: 700;">#{m.crystal_ms.round(2)} ms</td>
                <td class="num" style="color: var(--gd-amber); font-weight: 600;">#{m.gdscript_ms.round(2)} ms</td>
                #{ed_cell}
                <td class="num"><span class="speedup-badge">#{m.speedup.round(1)}x faster</span></td>
              </tr>)
            end.join("\n")
          end

          tag_badge_html = if t = tag
            %( <span class="tag-badge">#{XmlHandler.escape_xml(t)}</span>)
          else
            ""
          end

          progression_banner_html = if pt = prev_tag
            delta_str = if ps = prev_speedup
              diff = geo_mean - ps
              diff_pct = ps > 0 ? ((diff / ps) * 100.0).round(1) : 0.0
              sign = diff_pct >= 0 ? "+" : ""
              " &bull; <strong>#{sign}#{diff_pct}%</strong> shift vs #{ps.round(1)}x baseline"
            else
              ""
            end
            comp_link = "comparison_#{pt}_to_#{tag || version}.html"
            %(<div class="progression-banner">
              <div>
                <span style="font-size: 1.1rem; margin-right: 0.5rem;">⚡</span>
                <span><strong>Release Progression:</strong> Tag <code>#{XmlHandler.escape_xml(pt)}</code> &rarr; <code>#{XmlHandler.escape_xml(tag || version)}</code>#{delta_str}</span>
              </div>
              <a href="#{comp_link}" class="btn-link">View Detailed Diff &rarr;</a>
            </div>)
          else
            ""
          end

          history_section_html = if history && !history.empty?
            hist_rows = history.map do |h|
              sp_str = h.speedup ? %(<span class="speedup-badge">#{h.speedup.not_nil!.round(1)}x faster</span>) : "-"
              %(<tr>
                <td><span class="tag-badge">#{XmlHandler.escape_xml(h.tag)}</span></td>
                <td>v#{XmlHandler.escape_xml(h.version)}</td>
                <td>Godot #{XmlHandler.escape_xml(h.godot_ver)}</td>
                <td class="num">#{sp_str}</td>
                <td>
                  <a href="#{XmlHandler.escape_xml(h.filename)}" class="report-link">HTML Report</a>
                  &bull;
                  <a href="#{XmlHandler.escape_xml(h.xml_filename)}" class="report-link" style="color: var(--text-muted);">Raw XML</a>
                </td>
              </tr>)
            end.join("\n")

            comp_list_html = if comparisons && !comparisons.empty?
              comps = comparisons.map do |c|
                %(<li><a href="#{XmlHandler.escape_xml(c.filename)}" class="report-link">Tag Comparison: <code>#{XmlHandler.escape_xml(c.prev_tag)}</code> &rarr; <code>#{XmlHandler.escape_xml(c.curr_tag)}</code></a></li>)
              end.join("\n")
              %(<div style="margin-top: 1.5rem;">
                <h3 style="font-size: 1.1rem; color: #fff; margin-bottom: 0.75rem;">Recorded Tag Comparisons:</h3>
                <ul style="list-style: square; padding-left: 1.5rem; color: var(--text-muted);">
                  #{comps}
                </ul>
              </div>)
            else
              ""
            end

            %(<h2>Historical Benchmark Releases &amp; Logs</h2>
            <table>
              <thead>
                <tr>
                  <th>Tag / Release</th>
                  <th>Lapis Version</th>
                  <th>Godot Version</th>
                  <th class="num">GeoMean Speedup</th>
                  <th>Reports &amp; Logs</th>
                </tr>
              </thead>
              <tbody>
                #{hist_rows}
              </tbody>
            </table>
            #{comp_list_html})
          else
            %(<h2>Historical Benchmark Releases &amp; Logs</h2>
            <p style="color: var(--text-muted); margin-bottom: 2rem;">No previous benchmark history recorded yet. This release establishes the baseline.</p>)
          end

          <<-HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>#{XmlHandler.escape_xml(title)}</title>
  <style>
    :root {
      --bg: #0d1117;
      --card-bg: #161b22;
      --border: #30363d;
      --text: #c9d1d9;
      --text-muted: #8b949e;
      --crystal-cyan: #00d2ff;
      --gd-amber: #ff9900;
      --accent-green: #238636;
      --accent-purple: #d2a8ff;
      --font: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background-color: var(--bg);
      color: var(--text);
      font-family: var(--font);
      padding: 2.5rem 1.5rem;
      line-height: 1.5;
    }
    .container { max-width: 1100px; margin: 0 auto; }
    header { margin-bottom: 2rem; }
    h1 { font-size: 2.2rem; font-weight: 800; color: #fff; margin-bottom: 0.5rem; }
    .subtitle { color: var(--text-muted); font-size: 1.05rem; display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap; }
    .tag-badge {
      display: inline-block;
      background: rgba(0, 210, 255, 0.15);
      border: 1px solid var(--crystal-cyan);
      color: var(--crystal-cyan);
      padding: 0.15rem 0.6rem;
      border-radius: 12px;
      font-weight: 700;
      font-size: 0.85rem;
      font-family: monospace;
    }
    .progression-banner {
      background: rgba(0, 210, 255, 0.08);
      border: 1px solid rgba(0, 210, 255, 0.35);
      border-radius: 8px;
      padding: 1rem 1.25rem;
      margin-bottom: 2rem;
      display: flex;
      align-items: center;
      justify-content: space-between;
      flex-wrap: wrap;
      gap: 0.75rem;
    }
    .btn-link {
      display: inline-block;
      background-color: var(--crystal-cyan);
      color: #0d1117;
      text-decoration: none;
      font-weight: 700;
      font-size: 0.85rem;
      padding: 0.45rem 0.9rem;
      border-radius: 6px;
      transition: opacity 0.15s;
    }
    .btn-link:hover { opacity: 0.9; }
    .report-link {
      color: var(--crystal-cyan);
      text-decoration: none;
      font-weight: 600;
    }
    .report-link:hover { text-decoration: underline; }
    .kpi-row {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 1.25rem;
      margin-bottom: 2.5rem;
    }
    .kpi-card {
      background-color: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 1.5rem;
      display: flex;
      flex-direction: column;
    }
    .kpi-title { font-size: 0.85rem; text-transform: uppercase; color: var(--text-muted); font-weight: 600; letter-spacing: 0.05em; }
    .kpi-value { font-size: 2.2rem; font-weight: 800; color: #fff; margin: 0.4rem 0; }
    .kpi-value.cyan { color: var(--crystal-cyan); }
    .kpi-value.amber { color: var(--gd-amber); }
    .kpi-value.purple { color: var(--accent-purple); }
    .kpi-sub { font-size: 0.85rem; color: var(--text-muted); }
    .chart-container {
      background-color: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 1.5rem;
      margin-bottom: 2.5rem;
      text-align: center;
      overflow-x: auto;
    }
    .chart-container svg { max-width: 100%; height: auto; display: block; margin: 0 auto; }
    h2 { font-size: 1.4rem; color: #fff; margin: 2rem 0 1rem 0; border-bottom: 1px solid var(--border); padding-bottom: 0.5rem; }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 2rem;
      background-color: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 8px;
      overflow: hidden;
    }
    th, td { padding: 0.85rem 1rem; text-align: left; border-bottom: 1px solid var(--border); font-size: 0.95rem; }
    th { background-color: rgba(255,255,255,0.03); color: var(--text-muted); font-weight: 600; font-size: 0.85rem; }
    th.num, td.num { text-align: right; }
    .speedup-badge {
      display: inline-block;
      background-color: rgba(35, 134, 54, 0.2);
      border: 1px solid var(--accent-green);
      color: #3fb950;
      padding: 0.25rem 0.6rem;
      border-radius: 20px;
      font-weight: 700;
      font-size: 0.85rem;
    }
    .overhead-badge {
      display: inline-block;
      padding: 0.15rem 0.4rem;
      border-radius: 4px;
      font-size: 0.75rem;
      font-weight: 700;
      margin-left: 0.4rem;
    }
    .overhead-badge.warn { background: rgba(210, 168, 255, 0.15); border: 1px solid #a371f7; color: #d2a8ff; }
    .overhead-badge.good { background: rgba(63, 185, 80, 0.15); border: 1px solid #238636; color: #3fb950; }
    footer { text-align: center; color: var(--text-muted); font-size: 0.85rem; margin-top: 3rem; }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>#{XmlHandler.escape_xml(title)}</h1>
      <div class="subtitle">
        Lapis v#{XmlHandler.escape_xml(version)} &bull; Godot #{XmlHandler.escape_xml(godot_ver)} &bull; #{XmlHandler.escape_xml(platform.capitalize)}#{tag_badge_html}
      </div>
    </header>

    #{progression_banner_html}

    <div class="kpi-row">
      <div class="kpi-card">
        <span class="kpi-title">Geometric Mean Speedup</span>
        <span class="kpi-value cyan">#{geo_mean.round(1)}x</span>
        <span class="kpi-sub">Across all #{metrics.size} benchmarks</span>
      </div>
      <div class="kpi-card">
        <span class="kpi-title">Pure Compute Speedup</span>
        <span class="kpi-value cyan">#{comp_geo.round(1)}x</span>
        <span class="kpi-sub">#{compute_metrics.size} numerical benchmarks</span>
      </div>
      <div class="kpi-card">
        <span class="kpi-title">Engine Core Speedup</span>
        <span class="kpi-value amber">#{eng_geo.round(1)}x</span>
        <span class="kpi-sub">#{engine_metrics.size} engine API benchmarks</span>
      </div>
      #{has_editor && avg_overhead ? %(<div class="kpi-card"><span class="kpi-title">GDScript Editor Overhead</span><span class="kpi-value purple">#{avg_overhead >= 0 ? "+" : ""}#{avg_overhead}%</span><span class="kpi-sub">In-Editor vs Standalone</span></div>) : ""}
    </div>

    <div class="chart-container">
      #{svg_chart}
    </div>

    <h2>Compute Benchmarks</h2>
    <table>
      <thead>
        <tr>
          <th>Benchmark</th>
          <th>Description</th>
          <th class="num">Crystal</th>
          <th class="num">GDScript</th>
          #{has_editor ? %(<th class="num">GDScript (Editor)</th>) : ""}
          <th class="num">Speedup</th>
        </tr>
      </thead>
      <tbody>
        #{render_rows.call(compute_metrics)}
      </tbody>
    </table>

    <h2>Engine Core & Node Benchmarks</h2>
    <table>
      <thead>
        <tr>
          <th>Benchmark</th>
          <th>Description</th>
          <th class="num">Crystal</th>
          <th class="num">GDScript</th>
          #{has_editor ? %(<th class="num">GDScript (Editor)</th>) : ""}
          <th class="num">Speedup</th>
        </tr>
      </thead>
      <tbody>
        #{render_rows.call(engine_metrics)}
      </tbody>
    </table>

    #{history_section_html}

    <footer>
      Generated by Lapis v#{XmlHandler.escape_xml(version)} &bull; Native High-Performance Crystal Toolchain for Godot
    </footer>
  </div>
</body>
</html>
HTML
        end

        def self.generate_comparison_html(
          curr_metrics : Array(BenchmarkMetric),
          prev_metrics : Array(BenchmarkMetric),
          curr_ver : String,
          prev_ver : String,
          curr_tag : String? = nil,
          prev_tag : String? = nil
        ) : String
          curr_map = curr_metrics.to_h { |m| {m.name, m} }
          prev_map = prev_metrics.to_h { |m| {m.name, m} }
          all_names = (curr_map.keys + prev_map.keys).uniq.sort

          curr_speedups = curr_metrics.map(&.speedup).reject { |s| s <= 0.0 }
          prev_speedups = prev_metrics.map(&.speedup).reject { |s| s <= 0.0 }
          curr_geo = XmlHandler.calculate_geomean(curr_speedups)
          prev_geo = XmlHandler.calculate_geomean(prev_speedups)
          overall_diff_pct = prev_geo > 0 ? ((curr_geo - prev_geo) / prev_geo) * 100.0 : 0.0

          display_prev = prev_tag && !prev_tag.empty? ? prev_tag : "v#{prev_ver}"
          display_curr = curr_tag && !curr_tag.empty? ? curr_tag : "v#{curr_ver}"

          table_rows = all_names.map do |name|
            c = curr_map[name]?
            p = prev_map[name]?
            desc = c.try(&.description) || p.try(&.description) || ""

            c_ms = c ? "#{c.crystal_ms.round(2)} ms" : "-"
            p_ms = p ? "#{p.crystal_ms.round(2)} ms" : "-"
            c_sp = c ? "#{c.speedup.round(1)}x" : "-"
            p_sp = p ? "#{p.speedup.round(1)}x" : "-"

            delta_cell = if c && p && p.crystal_ms > 0
              diff_pct = ((c.crystal_ms - p.crystal_ms) / p.crystal_ms) * 100.0
              if diff_pct < -1.0
                %(<span class="speedup-badge" style="background: rgba(35,134,54,0.25); border-color:#3fb950; color:#3fb950;">#{diff_pct.round(1)}% faster</span>)
              elsif diff_pct > 1.0
                %(<span class="speedup-badge" style="background: rgba(248,81,73,0.2); border-color:#f85149; color:#f85149;">+#{diff_pct.round(1)}% slower</span>)
              else
                %(<span style="color: var(--text-muted); font-size: 0.85rem;">~ parity</span>)
              end
            else
              %(<span style="color: var(--text-muted);">-</span>)
            end

            %(<tr>
              <td><strong>#{XmlHandler.escape_xml(name)}</strong></td>
              <td style="color: var(--text-muted); font-size: 0.9rem;">#{XmlHandler.escape_xml(desc)}</td>
              <td class="num" style="color: var(--text-muted);">#{p_ms}</td>
              <td class="num" style="color: var(--crystal-cyan); font-weight: 700;">#{c_ms}</td>
              <td class="num" style="color: var(--text-muted);">#{p_sp}</td>
              <td class="num" style="color: var(--crystal-cyan); font-weight: 700;">#{c_sp}</td>
              <td class="num">#{delta_cell}</td>
            </tr>)
          end.join("\n")

          sign = overall_diff_pct >= 0 ? "+" : ""
          diff_color = overall_diff_pct >= 0 ? "cyan" : "amber"

          <<-HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Lapis Benchmark Progression: #{XmlHandler.escape_xml(display_prev)} vs #{XmlHandler.escape_xml(display_curr)}</title>
  <style>
    :root {
      --bg: #0d1117;
      --card-bg: #161b22;
      --border: #30363d;
      --text: #c9d1d9;
      --text-muted: #8b949e;
      --crystal-cyan: #00d2ff;
      --gd-amber: #ff9900;
      --accent-green: #238636;
      --accent-purple: #d2a8ff;
      --font: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background-color: var(--bg);
      color: var(--text);
      font-family: var(--font);
      padding: 2.5rem 1.5rem;
      line-height: 1.5;
    }
    .container { max-width: 1100px; margin: 0 auto; }
    header { margin-bottom: 2rem; }
    h1 { font-size: 2.2rem; font-weight: 800; color: #fff; margin-bottom: 0.5rem; }
    .subtitle { color: var(--text-muted); font-size: 1.05rem; margin-bottom: 2rem; }
    .kpi-row {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 1.25rem;
      margin-bottom: 2.5rem;
    }
    .kpi-card {
      background-color: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 1.5rem;
      display: flex;
      flex-direction: column;
    }
    .kpi-title { font-size: 0.85rem; text-transform: uppercase; color: var(--text-muted); font-weight: 600; letter-spacing: 0.05em; }
    .kpi-value { font-size: 2.2rem; font-weight: 800; color: #fff; margin: 0.4rem 0; }
    .kpi-value.cyan { color: var(--crystal-cyan); }
    .kpi-value.amber { color: var(--gd-amber); }
    .kpi-sub { font-size: 0.85rem; color: var(--text-muted); }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 2rem;
      background-color: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 8px;
      overflow: hidden;
    }
    th, td { padding: 0.85rem 1rem; text-align: left; border-bottom: 1px solid var(--border); font-size: 0.95rem; }
    th { background-color: rgba(255,255,255,0.03); color: var(--text-muted); font-weight: 600; font-size: 0.85rem; }
    th.num, td.num { text-align: right; }
    .speedup-badge {
      display: inline-block;
      padding: 0.25rem 0.6rem;
      border-radius: 20px;
      font-weight: 700;
      font-size: 0.85rem;
    }
    footer { text-align: center; color: var(--text-muted); font-size: 0.85rem; margin-top: 3rem; }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>Lapis Benchmark Version Progression</h1>
      <div class="subtitle">
        <a href="benchmarks.html" style="color: var(--crystal-cyan); text-decoration: none; margin-right: 0.75rem;">&larr; Back to Main Report</a> &bull;
        Comparing Baseline <strong>#{XmlHandler.escape_xml(display_prev)}</strong> &rarr; Target <strong>#{XmlHandler.escape_xml(display_curr)}</strong>
      </div>
    </header>

    <div class="kpi-row">
      <div class="kpi-card">
        <span class="kpi-title">Current GeoMean Speedup</span>
        <span class="kpi-value cyan">#{curr_geo.round(1)}x</span>
        <span class="kpi-sub">#{XmlHandler.escape_xml(display_curr)}</span>
      </div>
      <div class="kpi-card">
        <span class="kpi-title">Previous GeoMean Speedup</span>
        <span class="kpi-value">#{prev_geo.round(1)}x</span>
        <span class="kpi-sub">#{XmlHandler.escape_xml(display_prev)}</span>
      </div>
      <div class="kpi-card">
        <span class="kpi-title">Progression Delta</span>
        <span class="kpi-value #{diff_color}">#{sign}#{overall_diff_pct.round(1)}%</span>
        <span class="kpi-sub">Speedup Ratio Shift</span>
      </div>
      <div class="kpi-card">
        <span class="kpi-title">Compared Benchmarks</span>
        <span class="kpi-value">#{all_names.size}</span>
        <span class="kpi-sub">Test cases evaluated</span>
      </div>
    </div>

    <table>
      <thead>
        <tr>
          <th>Benchmark</th>
          <th>Description</th>
          <th class="num">Prev Crystal</th>
          <th class="num">Curr Crystal</th>
          <th class="num">Prev Speedup</th>
          <th class="num">Curr Speedup</th>
          <th class="num">Crystal Shift</th>
        </tr>
      </thead>
      <tbody>
        #{table_rows}
      </tbody>
    </table>

    <footer>
      Generated by Lapis Toolchain &bull; Version Progression Diagnostics
    </footer>
  </div>
</body>
</html>
HTML
        end
      end

      # =========================================================================
      # SVG Chart Generator
      # =========================================================================
      module SvgGenerator
        def self.generate_svg(metrics : Array(BenchmarkMetric)) : String
          return "" if metrics.empty?
          has_editor = metrics.any? { |m| m.editor_ms }

          svg_width = 1040
          bar_height = has_editor ? 12 : 14
          group_spacing = has_editor ? 70 : 58
          margin_top = 85
          margin_left = 175
          margin_right = 245
          chart_width = svg_width - margin_left - margin_right
          svg_height = margin_top + (metrics.size * group_spacing) + 40

          String.build do |io|
            io << %(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{svg_width} #{svg_height}" width="#{svg_width}" height="#{svg_height}">\n)
            io << %(  <defs>\n)
            io << %(    <linearGradient id="crGrad" x1="0%" y1="0%" x2="100%" y2="0%"><stop offset="0%" stop-color="#00D2FF"/><stop offset="100%" stop-color="#0077B6"/></linearGradient>\n)
            io << %(    <linearGradient id="edGrad" x1="0%" y1="0%" x2="100%" y2="0%"><stop offset="0%" stop-color="#D2A8FF"/><stop offset="100%" stop-color="#A371F7"/></linearGradient>\n)
            io << %(    <linearGradient id="gdGrad" x1="0%" y1="0%" x2="100%" y2="0%"><stop offset="0%" stop-color="#FF9900"/><stop offset="100%" stop-color="#CC5500"/></linearGradient>\n)
            io << %(  </defs>\n)
            io << %(  <rect width="#{svg_width}" height="#{svg_height}" rx="12" fill="#0D1117"/>\n)
            io << %(  <rect width="#{svg_width}" height="#{svg_height}" rx="12" fill="none" stroke="#30363D" stroke-width="1.5"/>\n)
            io << %(  <text x="32" y="40" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif" font-size="20" font-weight="bold" fill="#F0F3F6">Lapis Benchmark Suite: Performance Comparison</text>\n)
            io << %(  <text x="32" y="60" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif" font-size="12" fill="#8B949E">Execution time in milliseconds (shorter is faster) &bull; Crystal Native vs GDScript</text>\n)

            metrics.each_with_index do |m, idx|
              group_y = margin_top + (idx * group_spacing)
              max_time = [m.crystal_ms, m.gdscript_ms, m.editor_ms || 0.0].max
              max_time = 0.001 if max_time == 0.0

              cr_w = [4, ((m.crystal_ms / max_time) * chart_width).round.to_i].max
              gd_w = [4, ((m.gdscript_ms / max_time) * chart_width).round.to_i].max

              io << %(  <text x="#{margin_left - 15}" y="#{group_y + 26}" text-anchor="end" font-family="sans-serif" font-size="13" font-weight="bold" fill="#F0F3F6">#{XmlHandler.escape_xml(m.name)}</text>\n)
              io << %(  <rect x="#{margin_left}" y="#{group_y}" width="#{chart_width}" height="#{bar_height}" rx="3" fill="#21262D"/>\n)
              io << %(  <rect x="#{margin_left}" y="#{group_y}" width="#{cr_w}" height="#{bar_height}" rx="3" fill="url(#crGrad)"/>\n)
              io << %(  <text x="#{margin_left + cr_w + 8}" y="#{group_y + 10}" font-family="sans-serif" font-size="11" font-weight="600" fill="#00D2FF">#{m.crystal_ms.round(2)} ms (Crystal)</text>\n)

              io << %(  <rect x="#{margin_left}" y="#{group_y + 18}" width="#{chart_width}" height="#{bar_height}" rx="3" fill="#21262D"/>\n)
              io << %(  <rect x="#{margin_left}" y="#{group_y + 18}" width="#{gd_w}" height="#{bar_height}" rx="3" fill="url(#gdGrad)"/>\n)
              io << %(  <text x="#{margin_left + gd_w + 8}" y="#{group_y + 28}" font-family="sans-serif" font-size="11" font-weight="600" fill="#FF9900">#{m.gdscript_ms.round(2)} ms (GDScript)</text>\n)

              badge_x = svg_width - 120
              io << %(  <rect x="#{badge_x}" y="#{group_y + 10}" width="95" height="24" rx="12" fill="#238636" fill-opacity="0.2" stroke="#238636" stroke-width="1"/>\n)
              io << %(  <text x="#{badge_x + 47}" y="#{group_y + 26}" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="bold" fill="#3FB950">#{m.speedup.round(1)}x faster</text>\n)
            end
            io << %(</svg>\n)
          end
        end
      end

      # =========================================================================
      # Built-in Benchmark Catalog
      # =========================================================================
      def self.builtin_benchmarks : Array(BenchmarkCase)
        [
          BenchmarkCase.new("Matmul", Category::Compute, "matmul/matmul.cr", "bin/matmul", "matmul/matmul.gd", ["300"], "Dense 2D matrix multiplication (N=300, float64)"),
          BenchmarkCase.new("Primes", Category::Compute, "primes/primes.cr", "bin/primes", "primes/primes.gd", ["500000", "3233"], "Sieve of Atkin + Prefix Trie search (Limit=500k)"),
          BenchmarkCase.new("Brainfuck", Category::Compute, "brainfuck/bf.cr", "bin/bf", "brainfuck/bf.gd", ["brainfuck/bench_quick.b"], "Brainfuck AST interpreter + dynamic tape (bench_quick.b)"),
          BenchmarkCase.new("Base64", Category::Compute, "base64/base64.cr", "bin/base64", "base64/base64.gd", ["65536", "100"], "Base64 strict encode & decode loop (64 KiB, 100 iter)"),
          BenchmarkCase.new("JSON", Category::Compute, "json/json.cr", "bin/json", "json/json.gd", ["json/1.json"], "JSON parse & 3D coordinate aggregation (10k items)"),
          BenchmarkCase.new("NBody", Category::Compute, "nbody/nbody.cr", "bin/nbody", "nbody/nbody.gd", ["50000"], "3D orbital dynamics physics integration (Velocity-Verlet, 50k steps)"),
          BenchmarkCase.new("BinaryTrees", Category::Compute, "binarytrees/binarytrees.cr", "bin/binarytrees", "binarytrees/binarytrees.gd", ["12"], "GC pressure, bottom-up binary tree allocation & depth traversal"),
          BenchmarkCase.new("Mandelbrot", Category::Compute, "mandelbrot/mandelbrot.cr", "bin/mandelbrot", "mandelbrot/mandelbrot.gd", ["500"], "2D coordinate escape-time fractal rasterization (500x500)"),
          BenchmarkCase.new("TransformMath", Category::Compute, "transform_math/transform_math.cr", "bin/transform_math", "transform_math/transform_math.gd", ["200000"], "Transform3D translations, rotations & Vector3 projections (200k ops)"),
          BenchmarkCase.new("VectorMath2D", Category::Compute, "vector_math_2d/vector_math_2d.cr", "bin/vector_math_2d", "vector_math_2d/vector_math_2d.gd", ["500000"], "Vector2 lerp, dot, distance, and normalization across 500k ops"),
          BenchmarkCase.new("NodeLifecycle", Category::EngineCore, "node_lifecycle/node_lifecycle.cr", "bin/node_lifecycle", "node_lifecycle/node_lifecycle.gd", ["20000"], "Node2D allocation, property mutation, add_child, remove_child, free (20k)"),
          BenchmarkCase.new("MaterialResources", Category::EngineCore, "material_resources/material_resources.cr", "bin/material_resources", "material_resources/material_resources.gd", ["10000"], "StandardMaterial3D allocation, properties, duplication, refcounting (10k)"),
          BenchmarkCase.new("Signals", Category::EngineCore, "signals/signals.cr", "bin/signals", "signals/signals.gd", ["50000"], "Signal connection, argument marshalling & dynamic emission (50k calls)"),
          BenchmarkCase.new("PerlinNoise", Category::EngineCore, "perlin_noise/perlin_noise.cr", "bin/perlin_noise", "perlin_noise/perlin_noise.gd", ["500"], "FastNoiseLite 2D Perlin noise across 500x500 grid (250k samples)"),
          BenchmarkCase.new("SimplexNoise", Category::EngineCore, "simplex_noise/simplex_noise.cr", "bin/simplex_noise", "simplex_noise/simplex_noise.gd", ["100000"], "FastNoiseLite 3D Simplex Smooth noise across 100k samples"),
          BenchmarkCase.new("CellularNoise", Category::EngineCore, "cellular_noise/cellular_noise.cr", "bin/cellular_noise", "cellular_noise/cellular_noise.gd", ["500"], "FastNoiseLite 2D Cellular Voronoi noise across 500x500 grid (250k samples)"),
          BenchmarkCase.new("SurfaceTool", Category::EngineCore, "surface_tool/surface_tool.cr", "bin/surface_tool", "surface_tool/surface_tool.gd", ["10000"], "SurfaceTool procedural mesh generation with normals/UVs (10k triangles)"),
          BenchmarkCase.new("AStar2D", Category::EngineCore, "astar_2d/astar_2d.cr", "bin/astar_2d", "astar_2d/astar_2d.gd", ["100", "500"], "AStar2D pathfinding on 100x100 grid (10k points, 500 queries)"),
          BenchmarkCase.new("TreeTraversal", Category::EngineCore, "tree_traversal/tree_traversal.cr", "bin/tree_traversal", "tree_traversal/tree_traversal.gd", ["20000"], "Scene tree recursive traversal & property inspection (20k nodes)"),
          BenchmarkCase.new("ImageProcessing", Category::EngineCore, "image_processing/image_processing.cr", "bin/image_processing", "image_processing/image_processing.gd", ["512"], "512x512 Image procedural pixel computation and gamma blending (262k px)"),
          BenchmarkCase.new("TransformHierarchy", Category::EngineCore, "transform_hierarchy/transform_hierarchy.cr", "bin/transform_hierarchy", "transform_hierarchy/transform_hierarchy.gd", ["15000"], "15,000 Node3D hierarchy transformations & global position resolution"),
          BenchmarkCase.new("NodeGroups", Category::EngineCore, "node_groups/node_groups.cr", "bin/node_groups", "node_groups/node_groups.gd", ["20000"], "20,000 nodes partitioned into 10 groups, group assignment & queries"),
          BenchmarkCase.new("DictionaryOps", Category::EngineCore, "dictionary_ops/dictionary_ops.cr", "bin/dictionary_ops", "dictionary_ops/dictionary_ops.gd", ["50000"], "Godot Dictionary 50,000 insertions and random access lookups"),
          BenchmarkCase.new("ConfigFileOps", Category::EngineCore, "config_file/config_file.cr", "bin/config_file", "config_file/config_file.gd", ["1000"], "ConfigFile parsing, querying and encoding 1,000 section INI config"),
        ]
      end

      # Discovers benchmarks in a directory
      def self.discover_benchmarks(benchmarks_dir : Path) : Array(BenchmarkCase)
        found = [] of BenchmarkCase
        builtin = builtin_benchmarks.to_h { |b| {b.name.downcase, b} }

        if Dir.exists?(benchmarks_dir)
          Dir.each_child(benchmarks_dir) do |entry|
            entry_path = benchmarks_dir.join(entry)
            if Dir.exists?(entry_path)
              cr_src = entry_path.join("#{entry}.cr")
              gd_src = entry_path.join("#{entry}.gd")
              if File.exists?(cr_src)
                if match = builtin[entry.downcase]?
                  found << match
                else
                  found << BenchmarkCase.new(
                    name: entry.capitalize,
                    category: Category::Custom,
                    crystal_src: "#{entry}/#{entry}.cr",
                    crystal_bin: "bin/#{entry}",
                    gdscript_src: File.exists?(gd_src) ? "#{entry}/#{entry}.gd" : "",
                    args: [] of String,
                    description: "Custom benchmark in #{entry}"
                  )
                end
              end
            end
          end
        end

        found.empty? ? builtin_benchmarks : found
      end

      # =========================================================================
      # Benchmark Subprocess Runner
      # =========================================================================
      module Executor
        def self.compile_crystal(bench : BenchmarkCase, base_dir : Path, release : Bool = true) : Bool
          bin_name = Core::Env.windows? ? "#{bench.crystal_bin}.exe" : bench.crystal_bin
          out_path = base_dir.join(bin_name)
          src_path = base_dir.join(bench.crystal_src)
          bin_dir = out_path.parent
          FileUtils.mkdir_p(bin_dir) unless Dir.exists?(bin_dir)

          needs_build = !File.exists?(out_path) || (File.info(src_path).modification_time > File.info(out_path).modification_time)
          return true unless needs_build

          cmd = "crystal"
          flags = ["build", src_path.to_s, "-o", out_path.to_s]
          if release
            flags << "--release"
            flags << "-O3"
          end

          Core::Logger.trace("Benchmark", "crystal #{flags.join(" ")}")
          res = Core::ProcessRunner.run(cmd, flags, chdir: base_dir.to_s)
          res.success? && File.exists?(out_path)
        end

        def self.run_process_and_extract_ms(cmd : String, args : Array(String), cwd : Path) : Float64?
          stdout = IO::Memory.new
          stderr = IO::Memory.new
          status = Process.run(cmd, args, chdir: cwd.to_s, output: stdout, error: stderr)
          out_str = "#{stdout.to_s}\n#{stderr.to_s}"
          if match = out_str.match(/ELAPSED_MS:\s*([0-9.]+)/)
            return match[1].to_f?
          end
          nil
        end

        def self.measure(iterations : Int32, &block : -> Float64?) : Tuple(Array(Float64), Float64, Float64, Float64)
          samples = [] of Float64
          iterations.times do
            if ms = yield
              samples << ms
            end
          end

          return { [] of Float64, 0.0, 0.0, 0.0 } if samples.empty?

          sorted = samples.sort
          median = sorted[sorted.size // 2]
          { samples, median, sorted.first, sorted.last }
        end

        def self.run_case(
          bench : BenchmarkCase,
          iterations : Int32,
          base_dir : Path,
          godot_exe : String?,
          release : Bool = true,
          env_mode : String = "standalone"
        ) : BenchmarkResult?
          puts "\n--> Running Benchmark: \e[1;36m#{bench.name}\e[0m [#{bench.category.display_name}] (\e[2m#{bench.description}\e[0m)"

          unless compile_crystal(bench, base_dir, release: release)
            Core::Logger.error("Failed to compile #{bench.crystal_src}")
            return nil
          end

          cr_bin = base_dir.join(Core::Env.windows? ? "#{bench.crystal_bin}.exe" : bench.crystal_bin)

          print "  Benchmarking Crystal... "
          cr_samples, cr_median, cr_min, cr_max = measure(iterations) do
            run_process_and_extract_ms(cr_bin.to_s, bench.args, base_dir)
          end
          puts "\e[1;32m%6.2f ms\e[0m (median of %d)" % [cr_median, cr_samples.size]

          gd_samples = [] of Float64
          gd_median = 0.0
          gd_min = 0.0
          gd_max = 0.0

          if godot_exe && !bench.gdscript_src.empty? && File.exists?(base_dir.join(bench.gdscript_src))
            print "  Benchmarking GDScript... "
            gd_args = ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--script", bench.gdscript_src, "--"] + bench.args
            gd_samples, gd_median, gd_min, gd_max = measure(iterations) do
              run_process_and_extract_ms(godot_exe, gd_args, base_dir)
            end
          end

          speedup = (cr_median > 0 && gd_median > 0) ? (gd_median / cr_median) : 1.0
          if gd_median > 0
            speedup_badge = speedup >= 1.0 ? "\e[1;32m%5.1fx faster\e[0m" % speedup : "\e[1;33m%5.1fx slower\e[0m" % (1.0 / speedup)
            puts "\e[1;33m%6.2f ms\e[0m (median of %d) -> %s" % [gd_median, gd_samples.size, speedup_badge]
          end

          ed_samples = [] of Float64
          ed_median = 0.0
          ed_overhead_ratio : Float64? = nil

          if (env_mode == "all" || env_mode == "editor") && godot_exe && !bench.gdscript_src.empty?
            print "  Benchmarking In-Editor... "
            ed_args = ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--editor", "--path", base_dir.to_s, "--script", bench.gdscript_src, "--"] + bench.args
            ed_samples, ed_median, _ed_min, _ed_max = measure(iterations) do
              run_process_and_extract_ms(godot_exe, ed_args, base_dir)
            end
            if ed_median > 0 && gd_median > 0
              ed_overhead_ratio = ed_median / gd_median
              overhead_pct = ((ed_median - gd_median) / gd_median) * 100.0
              badge = overhead_pct >= 0 ? "+%.1f%% editor overhead" % overhead_pct : "%.1f%% editor speedup" % overhead_pct
              puts "\e[1;35m%6.2f ms\e[0m (median of %d) -> %s" % [ed_median, ed_samples.size, badge]
            end
          end

          BenchmarkResult.new(
            benchmark: bench,
            crystal_samples: cr_samples,
            gdscript_samples: gd_samples,
            crystal_ms: cr_median,
            gdscript_ms: gd_median,
            crystal_min_ms: cr_min,
            crystal_max_ms: cr_max,
            gdscript_min_ms: gd_min,
            gdscript_max_ms: gd_max,
            speedup: speedup,
            editor_samples: ed_samples,
            editor_ms: (ed_median > 0 ? ed_median : nil),
            editor_overhead_ratio: ed_overhead_ratio
          )
        end
      end

      # =========================================================================
      # GitHub Pages Remote Baseline Fetcher
      # =========================================================================
      def self.fetch_remote_baseline(version : String? = nil, tag : String? = nil) : String?
        urls = [] of String
        if t = tag
          urls << "https://sol-vin.github.io/lapis/benchmarks/history/benchmarks_#{t}.xml"
          urls << "https://raw.githubusercontent.com/sol-vin/lapis/gh-pages/benchmarks/history/benchmarks_#{t}.xml"
          urls << "https://github.com/sol-vin/lapis/releases/download/#{t}/benchmarks_#{t}.xml"
        end
        if v = version
          urls << "https://sol-vin.github.io/lapis/benchmarks/history/benchmarks_#{v}.xml"
          urls << "https://raw.githubusercontent.com/sol-vin/lapis/gh-pages/benchmarks/history/benchmarks_#{v}.xml"
        end
        urls << "https://sol-vin.github.io/lapis/benchmarks/benchmarks_latest.xml"
        urls << "https://raw.githubusercontent.com/sol-vin/lapis/gh-pages/benchmarks/benchmarks_latest.xml"

        urls.each do |url|
          begin
            Core::Logger.info("Attempting to fetch remote benchmark baseline from #{url}...")
            uri = URI.parse(url)
            client = HTTP::Client.new(uri)
            client.connect_timeout = 5.seconds
            client.read_timeout = 8.seconds
            response = client.get(uri.request_target)
            if response.status_code == 200 && response.body.includes?("<benchmarks")
              Core::Logger.success("Successfully fetched baseline benchmarks from GitHub Pages!")
              return response.body
            end
          rescue ex
            Core::Logger.trace("Benchmark:Fetch", "Failed fetching #{url}: #{ex.message}")
          end
        end
        nil
      end

      # =========================================================================
      # Tag & History Resolution Helpers
      # =========================================================================

      def self.resolve_tags(
        root : Path,
        reports_dir : Path,
        cli_tag : String? = nil,
        cli_prev_tag : String? = nil
      ) : Tuple(String, String?)
        godot_expected = Core::GodotFinder.expected_version(root.to_s)
        curr_tag = if ct = cli_tag
                     ct
                   elsif env_tag = ENV["TAG_NAME"]? || ENV["GITHUB_REF_NAME"]?
                     if env_tag.starts_with?("v") || env_tag.includes?("-dev") || env_tag.includes?(".")
                       env_tag
                     else
                       godot_expected
                     end
                   else
                     git_out = String.build do |io|
                       Process.run("git", ["describe", "--tags", "--exact-match"], output: io, error: Process::Redirect::Close)
                     end.strip rescue ""
                     if git_out.empty? || git_out.includes?("fatal")
                       git_out = String.build do |io|
                         Process.run("git", ["describe", "--tags"], output: io, error: Process::Redirect::Close)
                       end.strip rescue ""
                     end

                     if !git_out.empty? && !git_out.includes?("fatal")
                       git_out.split('-').first(2).join('-')
                     else
                       godot_expected
                     end
                   end

        prev_tag = if pt = cli_prev_tag
                     pt
                   else
                     discover_previous_tag(curr_tag, root, reports_dir)
                   end

        {curr_tag, prev_tag}
      end

      def self.discover_previous_tag(curr_tag : String, root : Path, reports_dir : Path) : String?
        search_dirs = [reports_dir, root.join("docs/benchmarks/history"), root.join("docs/benchmarks")]
        found_tags = [] of String
        search_dirs.each do |dir|
          next unless Dir.exists?(dir)
          Dir.glob(dir.to_s.gsub('\\', '/') + "/benchmarks_*.xml").each do |path|
            base = File.basename(path, ".xml")
            next if base == "benchmarks_latest"
            tag_name = base.sub(/^benchmarks_/, "")
            found_tags << tag_name unless tag_name == curr_tag || tag_name == Lapis::VERSION
          end
        end
        found_tags.uniq!

        if m = curr_tag.match(/^(.*-dev)(\d+)$/)
          prefix = m[1]
          num = m[2].to_i?
          if num && num > 1
            expected_prev = "#{prefix}#{num - 1}"
            return expected_prev if found_tags.includes?(expected_prev)
          end
        end

        begin
          out_tags = String.build do |io|
            Process.run("git", ["tag", "--sort=-creatordate"], output: io, error: Process::Redirect::Close)
          end
          tags = out_tags.lines.map(&.strip).reject(&.empty?)
          tags = tags.reject { |t| t == curr_tag || t == "latest" }
          if prev = tags.first?
            return prev
          end
        rescue
        end

        return found_tags.sort.last? if !found_tags.empty?

        if m = curr_tag.match(/^(.*-dev)(\d+)$/)
          prefix = m[1]
          num = m[2].to_i?
          return "#{prefix}#{num - 1}" if num && num > 1
        end

        nil
      end

      def self.scan_history(
        search_dirs : Array(Path),
        rel_prefix : String = ""
      ) : Tuple(Array(HtmlGenerator::HistoryEntry), Array(HtmlGenerator::ComparisonEntry))
        history = [] of HtmlGenerator::HistoryEntry
        comparisons = [] of HtmlGenerator::ComparisonEntry
        seen_tags = Set(String).new

        search_dirs.each do |dir|
          next unless Dir.exists?(dir)
          Dir.glob(dir.to_s.gsub('\\', '/') + "/benchmarks_*.xml").each do |xml_path|
            base = File.basename(xml_path, ".xml")
            next if base == "benchmarks_latest"
            tag_name = base.sub(/^benchmarks_/, "")
            next if seen_tags.includes?(tag_name)
            seen_tags << tag_name

            begin
              meta, metrics = XmlHandler.parse_xml(File.read(xml_path))
              speedups = metrics.map(&.speedup).reject { |s| s <= 0.0 }
              geo = speedups.empty? ? nil : XmlHandler.calculate_geomean(speedups).round(1)
              ver = meta["version"]? || Lapis::VERSION
              godot_v = meta["godot"]? || tag_name
              t_stamp = meta["timestamp"]?

              html_name = "report_#{tag_name}.html"
              history << HtmlGenerator::HistoryEntry.new(
                tag: tag_name,
                version: ver,
                godot_ver: godot_v,
                filename: "#{rel_prefix}#{html_name}",
                xml_filename: "#{rel_prefix}benchmarks_#{tag_name}.xml",
                speedup: geo,
                timestamp: t_stamp
              )
            rescue
            end
          end

          Dir.glob(dir.to_s.gsub('\\', '/') + "/comparison_*_to_*.html").each do |html_path|
            filename = File.basename(html_path)
            if m = filename.match(/^comparison_(.+)_to_(.+)\.html$/)
              p_tag = m[1]
              c_tag = m[2]
              comparisons << HtmlGenerator::ComparisonEntry.new(
                prev_tag: p_tag,
                curr_tag: c_tag,
                filename: "#{rel_prefix}#{filename}"
              )
            end
          end
        end

        history.sort_by!(&.tag).reverse!
        {history, comparisons}
      end

      # =========================================================================
      # Subcommand Implementations
      # =========================================================================

      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Benchmark Suite & Performance Diagnostics ===\e[0m

Usage:
  lapis benchmarks [run] [options]
  lapis benchmarks run html [options]
  lapis benchmarks export html --from=FILE.xml [options]
  lapis benchmarks compare [options]
  lapis benchmarks compare html [options]

Subcommands:
  (no subcmd), run      Execute benchmarks from benchmarks/ directory (default)
  run html              Execute benchmarks and produce formatted HTML report
  export html           Render interactive HTML report from specified XML file
  compare               Compare current benchmarks against previous version (XML output)
  compare html          Compare current benchmarks against previous version (HTML output)

Options:
  -i, --iterations=N    Number of measurement iterations (default: 3)
  -f, --filter=NAME     Filter benchmarks by name or description
  -c, --category=CAT    Filter by category ('compute', 'engine', 'custom')
  -e, --env=ENV         Execution environment: 'standalone', 'editor', 'all' (default: standalone)
  -t, --tag=TAG         Target release tag (e.g. '4.8-dev6')
  --previous-tag=TAG    Previous baseline release tag (e.g. '4.8-dev5')
  -o, --output=PATH     Explicit output file or directory path
  --from=PATH           Input XML file for 'export html'
  --current=PATH        Current benchmark XML file for comparison
  --previous=PATH       Previous benchmark XML file for comparison
  --format=FORMATS      Comma-separated outputs: console,html,xml,svg,json,csv (default: all)
  --no-release          Compile benchmarks in debug mode (default: release -O3)
  -l, --list            List all registered benchmarks and exit
  -h, --help            Show this help screen

Examples:
  lapis benchmarks
  lapis benchmarks run html --tag 4.8-dev6 --previous-tag 4.8-dev5
  lapis benchmarks export html --from=benchmarks/reports/benchmarks_4.8-dev6.xml
  lapis benchmarks compare --tag 4.8-dev6 --previous-tag 4.8-dev5
  lapis benchmarks compare html
  lapis benchmarks -f matmul -i 5
HELP
      end

      def self.run(args : Array(String)) : Int32
        if args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        subcmd = args.first?
        iterations = 3
        filter = ""
        category_filter : Category? = nil
        env_mode = "standalone"
        release_build = true
        from_file : String? = nil
        output_path : String? = nil
        current_xml_path : String? = nil
        prev_xml_path : String? = nil
        cli_tag : String? = nil
        cli_prev_tag : String? = nil
        force_html = false
        requested_formats = ["console", "html", "xml", "svg", "json", "csv"]

        # Parse subcommands
        remaining = args.dup
        is_export = false
        is_compare = false
        is_compare_html = false

        if subcmd == "run"
          remaining.shift
          if remaining.first? == "html"
            remaining.shift
            force_html = true
          end
        elsif subcmd == "export"
          remaining.shift
          if remaining.first? == "html"
            remaining.shift
          end
          is_export = true
        elsif subcmd == "compare"
          remaining.shift
          if remaining.first? == "html"
            remaining.shift
            is_compare_html = true
          else
            is_compare = true
          end
        end

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis benchmarks [command] [options]"
          opts.on("-i N", "--iterations=N", "Number of iterations") { |n| iterations = n.to_i? || 3 }
          opts.on("-f NAME", "--filter=NAME", "Filter by benchmark name") { |f| filter = f.downcase }
          opts.on("-c CAT", "--category=CAT", "Filter by category ('compute', 'engine', 'custom')") do |cat|
            category_filter = Category.parse_str(cat)
          end
          opts.on("-e ENV", "--env=ENV", "Environment (standalone, editor, all)") { |e| env_mode = e.downcase }
          opts.on("-t TAG", "--tag=TAG", "Target release tag (e.g. '4.8-dev6')") { |t| cli_tag = t }
          opts.on("--previous-tag=TAG", "Previous baseline release tag (e.g. '4.8-dev5')") { |pt| cli_prev_tag = pt }
          opts.on("-o PATH", "--output=PATH", "Output file or directory") { |o| output_path = o }
          opts.on("--from=PATH", "Input XML file for export") { |fr| from_file = fr }
          opts.on("--current=PATH", "Current benchmark XML for comparison") { |cur| current_xml_path = cur }
          opts.on("--previous=PATH", "Previous benchmark XML for comparison") { |prv| prev_xml_path = prv }
          opts.on("--format=FORMATS", "Output formats") do |fmt|
            requested_formats = fmt.split(",").map(&.strip.downcase).reject(&.empty?)
          end
          opts.on("--no-release", "Compile in debug mode") { release_build = false }
          opts.on("-l", "--list", "List benchmarks and exit") do
            puts "\nRegistered Lapis Benchmarks (#{builtin_benchmarks.size} total):"
            builtin_benchmarks.each do |b|
              puts "  %-18s [%-10s] %s" % [b.name, b.category.display_name, b.description]
            end
            exit 0
          end
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
        end

        parser.parse(remaining)

        root = Core::Env::ROOT_DIR
        benchmarks_dir = if Dir.exists?(Path.new("benchmarks").expand)
                           Path.new("benchmarks").expand
                         elsif Dir.exists?(root.join("benchmarks"))
                           root.join("benchmarks")
                         else
                           Path.new(".").expand
                         end

        reports_dir = benchmarks_dir.join("reports")
        FileUtils.mkdir_p(reports_dir) unless Dir.exists?(reports_dir)

        # ---------------------------------------------------------------------
        # 1. Action: export html --from=FILE.xml
        # ---------------------------------------------------------------------
        if is_export
          input_xml = from_file || remaining.find { |arg| arg.ends_with?(".xml") }
          unless input_xml && File.exists?(input_xml)
            Core::Logger.error("Input XML file required. Usage: lapis benchmarks export html --from=somefile.xml [-o out.html]")
            return 1
          end

          Core::Logger.step("Benchmark:Export", "Parsing benchmark metrics from #{input_xml}...")
          meta, metrics = XmlHandler.parse_xml(File.read(input_xml))
          if metrics.empty?
            Core::Logger.error("No valid benchmark cases found in #{input_xml}")
            return 1
          end

          ver = meta["version"]? || Lapis::VERSION
          plat = meta["platform"]? || Core::Env.current_platform
          godot_ver = meta["godot"]? || Core::GodotFinder.expected_version(root.to_s)
          html_content = HtmlGenerator.generate_report(metrics, ver, plat, godot_ver)

          out_file = if op = output_path
                       Path.new(op).expand
                     else
                       reports_dir.join("benchmark_report.html")
                     end

          FileUtils.mkdir_p(out_file.parent) unless Dir.exists?(out_file.parent)
          File.write(out_file, html_content)
          Core::Logger.success("Exported HTML benchmark report to #{out_file} (#{File.size(out_file)} bytes)!")
          return 0
        end

        # ---------------------------------------------------------------------
        # 2. Action: compare / compare html
        # ---------------------------------------------------------------------
        if is_compare || is_compare_html
          curr_tag, prev_tag = resolve_tags(root, reports_dir, cli_tag, cli_prev_tag)

          curr_file : String? = current_xml_path
          if curr_file.nil?
            tag_xml = reports_dir.join("benchmarks_#{curr_tag}.xml")
            latest_xml = reports_dir.join("benchmarks_latest.xml")
            if File.exists?(tag_xml)
              curr_file = tag_xml.to_s
            elsif File.exists?(latest_xml)
              curr_file = latest_xml.to_s
            else
              candidates = Dir.glob(reports_dir.to_s.gsub('\\', '/') + "/benchmarks_*.xml").sort
              curr_file = candidates.last? if candidates.size > 0
            end
          end

          unless curr_file && File.exists?(curr_file)
            Core::Logger.error("Current benchmark XML not found at #{curr_file}. Run 'lapis benchmarks' first or pass --current=file.xml.")
            return 1
          end

          curr_meta, curr_metrics = XmlHandler.parse_xml(File.read(curr_file))
          curr_version = curr_meta["version"]? || Lapis::VERSION
          curr_tag = curr_meta["tag"]? || curr_tag

          prev_content : String? = nil
          prev_version = "previous"

          if p_path = prev_xml_path
            if File.exists?(p_path)
              prev_content = File.read(p_path)
            else
              Core::Logger.error("Specified previous benchmark XML not found: #{p_path}")
              return 1
            end
          else
            # Search locally for previous tag XML or older version in reports_dir or docs/benchmarks/history
            prev_file : String? = nil
            if pt = prev_tag
              possible = reports_dir.join("benchmarks_#{pt}.xml")
              docs_possible = root.join("docs/benchmarks/history/benchmarks_#{pt}.xml")
              if File.exists?(possible)
                prev_file = possible.to_s
              elsif File.exists?(docs_possible)
                prev_file = docs_possible.to_s
              end
            end

            if prev_file.nil?
              existing_xmls = Dir.glob(reports_dir.to_s.gsub('\\', '/') + "/benchmarks_*.xml").reject do |f|
                f.ends_with?("latest.xml") || f.ends_with?("#{curr_version}.xml") || (curr_tag && f.ends_with?("#{curr_tag}.xml"))
              end.sort
              prev_file = existing_xmls.last?
            end

            if prev_file && File.exists?(prev_file)
              prev_content = File.read(prev_file)
              Core::Logger.info("Using local previous benchmark baseline from #{prev_file}")
            else
              # Fetch from GitHub Pages / GitHub releases!
              prev_content = fetch_remote_baseline(version: prev_tag, tag: prev_tag)
            end
          end

          unless prev_content
            Core::Logger.warn("No previous benchmark baseline XML found locally or remotely for comparison.")
            Core::Logger.info("Current benchmark will serve as the initial baseline for future comparisons.")
            return 0
          end

          prev_meta, prev_metrics = XmlHandler.parse_xml(prev_content)
          prev_version = prev_meta["version"]? || "baseline"
          prev_tag = prev_meta["tag"]? || prev_tag

          diff_label_prev = prev_tag || prev_version
          diff_label_curr = curr_tag || curr_version

          if is_compare_html
            diff_html = HtmlGenerator.generate_comparison_html(
              curr_metrics,
              prev_metrics,
              curr_version,
              prev_version,
              curr_tag: curr_tag,
              prev_tag: prev_tag
            )
            out_file = if op = output_path
                         Path.new(op).expand
                       else
                         reports_dir.join("comparison_#{diff_label_prev}_to_#{diff_label_curr}.html")
                       end
            FileUtils.mkdir_p(out_file.parent) unless Dir.exists?(out_file.parent)
            File.write(out_file, diff_html)
            Core::Logger.success("Generated comparison HTML report at #{out_file}!")

            # Copy to docs if available
            docs_bench = root.join("docs/benchmarks")
            if Dir.exists?(root.join("docs"))
              FileUtils.mkdir_p(docs_bench.join("history"))
              File.write(docs_bench.join("comparison_#{diff_label_prev}_to_#{diff_label_curr}.html"), diff_html)
              File.write(docs_bench.join("history/comparison_#{diff_label_prev}_to_#{diff_label_curr}.html"), diff_html)
            end
          else
            diff_xml = XmlHandler.generate_comparison_xml(
              curr_metrics,
              prev_metrics,
              curr_version,
              prev_version,
              curr_tag: curr_tag,
              prev_tag: prev_tag
            )
            out_file = if op = output_path
                         Path.new(op).expand
                       else
                         reports_dir.join("comparison_#{diff_label_prev}_to_#{diff_label_curr}.xml")
                       end
            FileUtils.mkdir_p(out_file.parent) unless Dir.exists?(out_file.parent)
            File.write(out_file, diff_xml)
            Core::Logger.success("Generated comparison XML report at #{out_file}!")
          end

          return 0
        end

        # ---------------------------------------------------------------------
        # 3. Action: lapis benchmarks [run] (Default)
        # ---------------------------------------------------------------------
        curr_tag, prev_tag = resolve_tags(root, reports_dir, cli_tag, cli_prev_tag)

        all_cases = discover_benchmarks(benchmarks_dir)
        target_cases = all_cases

        if cat = category_filter
          target_cases = target_cases.select { |b| b.category == cat }
        end

        unless filter.empty?
          target_cases = target_cases.select do |b|
            b.name.downcase.includes?(filter) || b.description.downcase.includes?(filter)
          end
        end

        if target_cases.empty?
          Core::Logger.warn("No benchmarks matched the specified filters.")
          return 0
        end

        godot_exe = Core::GodotFinder.resolve(nil)
        platform_name = Core::Env.current_platform

        puts "\e[1;35m=== Lapis Benchmark Suite ===\e[0m"
        puts "  Directory:    #{benchmarks_dir}"
        puts "  Godot Binary: #{godot_exe || "(None found, running Crystal only)"}"
        puts "  Environment:  #{env_mode.capitalize}"
        puts "  Target Tag:   \e[1;36m#{curr_tag}\e[0m#{prev_tag ? " (comparing against \e[1;33m#{prev_tag}\e[0m)" : ""}"
        puts "  Iterations:   #{iterations}"
        puts "  Optimization: #{release_build ? "Release (-O3)" : "Debug"}"
        puts "  Benchmarks:   #{target_cases.size} selected"

        results = [] of BenchmarkResult

        target_cases.each do |bench|
          if res = Executor.run_case(
            bench: bench,
            iterations: iterations,
            base_dir: benchmarks_dir,
            godot_exe: godot_exe,
            release: release_build,
            env_mode: env_mode
          )
            results << res
          end
        end

        return 1 if results.empty?

        metrics = results.map(&.to_metric)
        godot_ver = Core::GodotFinder.expected_version(root.to_s)

        # 1. Output XML (history, tag and latest)
        xml_content = XmlHandler.generate_xml(metrics, Lapis::VERSION, godot_ver, iterations, platform_name, tag: curr_tag)
        ver_xml = reports_dir.join("benchmarks_#{Lapis::VERSION}.xml")
        tag_xml = reports_dir.join("benchmarks_#{curr_tag}.xml")
        latest_xml = reports_dir.join("benchmarks_latest.xml")
        File.write(ver_xml, xml_content)
        File.write(tag_xml, xml_content)
        File.write(latest_xml, xml_content)
        Core::Logger.success("Saved benchmark XML: #{tag_xml.basename} & #{latest_xml.basename}")

        # 2. Check for Previous Baseline & Automatically Generate Comparison Diff
        prev_speedup : Float64? = nil
        if pt = prev_tag
          prev_baseline_content : String? = nil
          local_prev = reports_dir.join("benchmarks_#{pt}.xml")
          docs_prev = root.join("docs/benchmarks/history/benchmarks_#{pt}.xml")
          if File.exists?(local_prev)
            prev_baseline_content = File.read(local_prev)
          elsif File.exists?(docs_prev)
            prev_baseline_content = File.read(docs_prev)
          else
            prev_baseline_content = fetch_remote_baseline(version: pt, tag: pt)
          end

          if prev_baseline_content
            begin
              prev_meta, prev_metrics = XmlHandler.parse_xml(prev_baseline_content)
              p_speedups = prev_metrics.map(&.speedup).reject { |s| s <= 0.0 }
              prev_speedup = XmlHandler.calculate_geomean(p_speedups) unless p_speedups.empty?

              diff_html = HtmlGenerator.generate_comparison_html(
                metrics,
                prev_metrics,
                Lapis::VERSION,
                prev_meta["version"]? || "baseline",
                curr_tag: curr_tag,
                prev_tag: pt
              )
              comp_file = reports_dir.join("comparison_#{pt}_to_#{curr_tag}.html")
              File.write(comp_file, diff_html)
              Core::Logger.success("Generated auto-comparison HTML: #{comp_file.basename}")

              diff_xml = XmlHandler.generate_comparison_xml(
                metrics,
                prev_metrics,
                Lapis::VERSION,
                prev_meta["version"]? || "baseline",
                curr_tag: curr_tag,
                prev_tag: pt
              )
              comp_xml_file = reports_dir.join("comparison_#{pt}_to_#{curr_tag}.xml")
              File.write(comp_xml_file, diff_xml)
            rescue ex
              Core::Logger.warn("Could not generate automatic comparison with #{pt}: #{ex.message}")
            end
          end
        end

        # 3. Scan History Across Reports & Docs
        history, comparisons = scan_history([reports_dir, root.join("docs/benchmarks/history")])

        # 4. Output HTML Reports
        html_content = HtmlGenerator.generate_report(
          metrics,
          Lapis::VERSION,
          platform_name,
          godot_ver,
          tag: curr_tag,
          history: history,
          comparisons: comparisons,
          prev_tag: prev_tag,
          prev_speedup: prev_speedup
        )
        html_file = reports_dir.join("benchmark_report.html")
        tag_html = reports_dir.join("report_#{curr_tag}.html")
        File.write(html_file, html_content)
        File.write(tag_html, html_content)
        File.write(reports_dir.join("benchmarks.html"), html_content)
        Core::Logger.success("Saved benchmark HTML reports: #{html_file.basename} & #{tag_html.basename}")

        # 5. Output SVG Chart
        svg_content = SvgGenerator.generate_svg(metrics)
        svg_file = reports_dir.join("benchmark_chart.svg")
        File.write(svg_file, svg_content)
        Core::Logger.success("Saved benchmark SVG chart: #{svg_file.basename}")

        # 6. Synchronize to docs/ and docs/benchmarks/ for GitHub Pages
        docs_bench = root.join("docs/benchmarks")
        if Dir.exists?(root.join("docs"))
          FileUtils.mkdir_p(docs_bench)
          FileUtils.mkdir_p(docs_bench.join("history"))

          # Core dashboard files
          File.write(root.join("docs/benchmarks.html"), html_content)
          File.write(docs_bench.join("index.html"), html_content)
          File.write(docs_bench.join("benchmark_chart.svg"), svg_content)
          File.write(docs_bench.join("benchmarks_latest.xml"), xml_content)

          # Tag-specific archive files
          File.write(docs_bench.join("history/benchmarks_#{curr_tag}.xml"), xml_content)
          File.write(docs_bench.join("history/report_#{curr_tag}.html"), html_content)
          File.write(docs_bench.join("history/benchmarks_#{Lapis::VERSION}.xml"), xml_content)

          # Copy any generated comparisons
          Dir.glob(reports_dir.to_s.gsub('\\', '/') + "/comparison_*").each do |cf|
            FileUtils.cp(cf, docs_bench.to_s)
            FileUtils.cp(cf, docs_bench.join("history").to_s)
          end

          Core::Logger.info("Synchronized benchmark reports and logs to docs/benchmarks/ for GitHub Pages.")
        end

        # Console Summary
        speedups = metrics.map(&.speedup).reject { |s| s <= 0.0 }
        geo = XmlHandler.calculate_geomean(speedups)
        puts "\n\e[1;32m=== Benchmark Execution Complete ===\e[0m"
        puts "  Evaluated:       #{metrics.size} benchmark cases"
        puts "  GeoMean Speedup: \e[1;36m#{geo.round(1)}x faster\e[0m (Crystal vs GDScript)"
        puts "  HTML Report:     #{html_file}"
        puts "  Tag XML Report:  #{tag_xml}\n"

        0
      end
    end
  end
end
