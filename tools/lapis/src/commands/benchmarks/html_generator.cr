require "./models"
require "./xml_handler"
require "./svg_generator"

module Lapis
  module Commands
    module Benchmarks
      module HtmlGenerator
        record HistoryEntry,
          tag : String,
          version : String,
          godot_ver : String,
          filename : String,
          xml_filename : String,
          speedup : Float64? = nil,
          timestamp : String? = nil,
          total_ms : Float64? = nil

        record ComparisonEntry,
          prev_tag : String,
          curr_tag : String,
          filename : String

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
          prev_speedup : Float64? = nil,
          prev_total_latency : Float64? = nil,
          project_name : String = "Lapis",
          native_mode : Bool = false
        ) : String
          return "" if metrics.empty?
          is_native = native_mode || metrics.all? { |m| m.gdscript_ms <= 0.0 }
          total_latency = metrics.sum(&.crystal_ms)
          avg_latency = metrics.empty? ? 0.0 : total_latency / metrics.size
          fastest_metric = metrics.min_by?(&.crystal_ms)

          comparative_speedups = metrics.reject { |m| m.gdscript_ms <= 0.0 }.map(&.speedup).reject { |s| s <= 0.0 }
          geo_mean = comparative_speedups.empty? ? 1.0 : XmlHandler.calculate_geomean(comparative_speedups)
          max_metric = metrics.max_by(&.speedup)

          compute_metrics = metrics.select { |m| m.category == Category::Compute }
          engine_metrics = metrics.select { |m| m.category == Category::EngineCore }
          toolchain_metrics = metrics.select { |m| m.category == Category::Toolchain }
          custom_metrics = metrics.select { |m| m.category == Category::Custom }

          comp_geo = XmlHandler.calculate_geomean(compute_metrics.reject { |m| m.gdscript_ms <= 0.0 }.map(&.speedup).reject { |s| s <= 0.0 })
          eng_geo = XmlHandler.calculate_geomean(engine_metrics.reject { |m| m.gdscript_ms <= 0.0 }.map(&.speedup).reject { |s| s <= 0.0 })
          custom_geo = XmlHandler.calculate_geomean(custom_metrics.reject { |m| m.gdscript_ms <= 0.0 }.map(&.speedup).reject { |s| s <= 0.0 })

          has_editor = metrics.any? { |m| m.editor_ms }
          overhead_values = metrics.compact_map(&.editor_overhead_ratio)
          avg_overhead = overhead_values.empty? ? nil : ((overhead_values.sum / overhead_values.size - 1.0) * 100.0).round(1)

          svg_chart = SvgGenerator.generate_svg(metrics, title: title.sub(/:.*/, ": Performance Comparison"), native_mode: is_native)

          # Table row renderer
          render_rows = ->(group : Array(BenchmarkMetric)) do
            group.map do |m|
              if is_native
                %(<tr>
                  <td><strong>#{XmlHandler.escape_xml(m.name)}</strong></td>
                  <td><span class="tag-badge" style="font-size: 0.75rem;">#{XmlHandler.escape_xml(m.category.display_name)}</span></td>
                  <td style="color: var(--text-muted); font-size: 0.9rem;">#{XmlHandler.escape_xml(m.description)}</td>
                  <td class="num" style="color: var(--crystal-cyan); font-weight: 700;">#{m.crystal_ms.round(2)} ms</td>
                  <td class="num"><span class="speedup-badge" style="background: rgba(0, 210, 255, 0.15); color: var(--crystal-cyan); border-color: rgba(0, 210, 255, 0.4);">Native</span></td>
                </tr>)
              else
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

                gd_cell = if m.gdscript_ms > 0.0
                  %(<td class="num" style="color: var(--gd-amber); font-weight: 600;">#{m.gdscript_ms.round(2)} ms</td>)
                else
                  %(<td class="num" style="color: var(--text-muted); font-size: 0.85rem;">-</td>)
                end

                badge_cell = if m.gdscript_ms > 0.0
                  %(<td class="num"><span class="speedup-badge">#{m.speedup.round(1)}x faster</span></td>)
                else
                  %(<td class="num"><span class="speedup-badge" style="background: rgba(0, 210, 255, 0.15); color: var(--crystal-cyan); border-color: rgba(0, 210, 255, 0.4);">Native</span></td>)
                end

                name_html = if sg = m.subgroup
                  %(<strong>#{XmlHandler.escape_xml(m.name)}</strong> <span class="tag-badge" style="font-size: 0.7rem; margin-left: 0.4rem;">#{XmlHandler.escape_xml(sg)}</span>)
                else
                  %(<strong>#{XmlHandler.escape_xml(m.name)}</strong>)
                end

                %(<tr>
                  <td>#{name_html}</td>
                  <td style="color: var(--text-muted); font-size: 0.9rem;">#{XmlHandler.escape_xml(m.description)}</td>
                  <td class="num" style="color: var(--crystal-cyan); font-weight: 700;">#{m.crystal_ms.round(2)} ms</td>
                  #{gd_cell}
                  #{ed_cell}
                  #{badge_cell}
                </tr>)
              end
            end.join("\n")
          end

          tag_badge_html = if t = tag
            %( <span class="tag-badge">#{XmlHandler.escape_xml(t)}</span>)
          else
            ""
          end

          mode_badge_html = if is_native
            %( <span class="tag-badge" style="background: rgba(0, 210, 255, 0.12); color: var(--crystal-cyan); border-color: rgba(0, 210, 255, 0.4);">Native Benchmark</span>)
          else
            ""
          end

          progression_banner_html = if pt = prev_tag
            comp_link = "comparison_#{pt}_to_#{tag || version}.html"
            if is_native
              delta_str = if ptl = prev_total_latency
                diff = total_latency - ptl
                diff_pct = ptl > 0 ? ((diff / ptl) * 100.0).round(1) : 0.0
                if diff_pct < -1.0
                  " &bull; <strong style=\"color: #3fb950;\">#{diff_pct.abs}% faster</strong> vs #{ptl.round(2)} ms baseline"
                elsif diff_pct > 1.0
                  " &bull; <strong style=\"color: #f85149;\">+#{diff_pct}% slower</strong> vs #{ptl.round(2)} ms baseline"
                else
                  " &bull; <strong>~ parity</strong> vs #{ptl.round(2)} ms baseline"
                end
              else
                ""
              end
              %(<div class="progression-banner">
                <div>
                  <span style="font-size: 1.1rem; margin-right: 0.5rem;">⚡</span>
                  <span><strong>Release Progression:</strong> Tag <code>#{XmlHandler.escape_xml(pt)}</code> &rarr; <code>#{XmlHandler.escape_xml(tag || version)}</code>#{delta_str}</span>
                </div>
                <a href="#{comp_link}" class="btn-link">View Detailed Diff &rarr;</a>
              </div>)
            else
              delta_str = if ps = prev_speedup
                diff = geo_mean - ps
                diff_pct = ps > 0 ? ((diff / ps) * 100.0).round(1) : 0.0
                sign = diff_pct >= 0 ? "+" : ""
                " &bull; <strong>#{sign}#{diff_pct}%</strong> shift vs #{ps.round(1)}x baseline"
              else
                ""
              end
              %(<div class="progression-banner">
                <div>
                  <span style="font-size: 1.1rem; margin-right: 0.5rem;">⚡</span>
                  <span><strong>Release Progression:</strong> Tag <code>#{XmlHandler.escape_xml(pt)}</code> &rarr; <code>#{XmlHandler.escape_xml(tag || version)}</code>#{delta_str}</span>
                </div>
                <a href="#{comp_link}" class="btn-link">View Detailed Diff &rarr;</a>
              </div>)
            end
          else
            ""
          end

          # =========================================================================
          # Comparison Groups Section Construction
          # =========================================================================
          grouped_metrics = metrics.group_by { |m| m.group_name }
          comparison_groups_html = String.build do |io|
            has_groups = grouped_metrics.any? { |k, v| k && !k.empty? }
            if has_groups
              io << %(<h2 style="color: #fff; margin-top: 2.5rem; border-bottom: 2px solid var(--border); padding-bottom: 0.6rem;">Benchmark Comparison Groups</h2>\n)
              io << %(<p style="color: var(--text-muted); margin-bottom: 1.5rem; font-size: 0.95rem;">Side-by-side grouped evaluations measuring specific domain subsystems against baselines across languages and paradigms.</p>\n)

              # Language Filter Bar (Vanilla JS)
              io << %(<div class="lang-filter-bar">
                <span class="filter-label">Filter Language Target:</span>
                <button class="filter-btn active" data-lang="all">All Targets</button>
                <button class="filter-btn" data-lang="crystal">Crystal</button>
                <button class="filter-btn" data-lang="gdscript">GDScript</button>
                <button class="filter-btn" data-lang="cpp">C++</button>
                <button class="filter-btn" data-lang="rust">Rust</button>
                <button class="filter-btn" data-lang="csharp">C#</button>
              </div>\n)

              grouped_metrics.each do |grp_name, grp_items|
                next unless grp_name && !grp_name.empty?

                first_m = grp_items.first
                grp_kind = grp_items.map(&.group_kind).find { |k| k != :runtime } || first_m.group_kind
                chart_types = grp_items.map(&.chart_types).find { |ct| !ct.empty? } || first_m.chart_types
                baseline_name = first_m.baseline_name || "Crystal"
                slug = grp_name.downcase.gsub(/[^a-z0-9_]/, "_")
                has_multilang = grp_items.any? { |m| m.cpp_ms || m.rust_ms || m.csharp_ms }

                # Generate SVGs for each available chart_type
                charts_map = Hash(Symbol, String).new
                chart_types.each do |ct|
                  svg_str = SvgGenerator.generate_group_svg(grp_name, grp_items, ct, baseline_name: baseline_name, kind: grp_kind)
                  charts_map[ct] = svg_str unless svg_str.empty?
                end

                if charts_map.empty?
                  charts_map[:bar] = SvgGenerator.generate_group_svg(grp_name, grp_items, :bar, baseline_name: baseline_name, kind: grp_kind)
                end

                io << %(<div class="group-card" id="group-card-#{slug}">
                  <div class="group-header">
                    <div>
                      <h3 class="group-title">#{XmlHandler.escape_xml(grp_name)}</h3>
                      <div class="group-desc">#{XmlHandler.escape_xml(first_m.description)} &bull; Baseline: <strong>#{XmlHandler.escape_xml(baseline_name)}</strong></div>
                    </div>
                    <div class="group-header-right">
                      <div class="chart-view-selector" data-group="#{slug}">\n)

                labels = {
                  :bar              => (grp_kind == :throughput ? "Throughput" : "Latency Bar"),
                  :speedup          => "Speedup",
                  :ratio            => "Ratio",
                  :log              => "Log Scale",
                  :debug_vs_release => "Debug vs Release",
                  :size             => "Binary Size",
                  :throughput       => "Throughput",
                }
                charts_map.keys.each_with_index do |ct, c_idx|
                  btn_active = (c_idx == 0) ? "active" : ""
                  btn_label = labels[ct]? || ct.to_s.capitalize
                  io << %(                        <button class="view-btn #{btn_active}" data-view="#{ct}">#{btn_label}</button>\n)
                end

                io << %(                      </div>
                      <span class="tag-badge">#{XmlHandler.escape_xml(first_m.category.display_name)}</span>
                    </div>
                  </div>
                  <div class="group-charts-container" data-group="#{slug}">\n)

                charts_map.each_with_index do |(ct, svg_code), c_idx|
                  view_active = (c_idx == 0) ? "active" : ""
                  view_style = (c_idx == 0) ? "" : "display: none;"
                  io << %(                    <div class="group-chart-view #{view_active}" data-view="#{ct}" style="#{view_style}">
                      #{svg_code}
                    </div>\n)
                end
                io << %(                  </div>\n)

                # Detailed Table
                if grp_kind == :compile_time && (comp_m = grp_items.find { |i| i.name == "CompileTimes" } || grp_items.first?)
                  cm = comp_m.custom_metrics
                  format_size = ->(bytes : Float64?) {
                    return "-" unless bytes && bytes > 0
                    kb = bytes / 1024.0
                    kb > 1024.0 ? "#{(kb / 1024.0).round(2)} MB" : "#{kb.round(1)} KB"
                  }

                  # Crystal
                  cr_dbg_t = cm["cr_debug_ms"]? || cm["crystal_debug_compile_ms"]?
                  cr_rel_t = cm["cr_release_ms"]? || cm["crystal_release_compile_ms"]? || comp_m.crystal_ms
                  cr_dbg_sz = format_size.call(cm["cr_debug_bytes"]? || cm["crystal_debug_size_kb"]?.try(&.*(1024.0)))
                  cr_rel_sz = format_size.call(cm["cr_release_bytes"]? || cm["crystal_release_size_kb"]?.try(&.*(1024.0)))

                  # C++
                  cpp_dbg_t = cm["cpp_debug_ms"]? || cm["cpp_debug_compile_ms"]?
                  cpp_rel_t = cm["cpp_release_ms"]? || cm["cpp_release_compile_ms"]?
                  cpp_dbg_sz = format_size.call(cm["cpp_debug_bytes"]? || cm["cpp_debug_size_kb"]?.try(&.*(1024.0)))
                  cpp_rel_sz = format_size.call(cm["cpp_release_bytes"]? || cm["cpp_release_size_kb"]?.try(&.*(1024.0)))
                  cpp_ratio_str = if cpp_rel_t && cr_rel_t > 0
                    r = (cpp_rel_t / cr_rel_t).round(2)
                    r >= 1.0 ? "#{r}x slower build" : "#{(1.0 / r).round(2)}x faster build"
                  else
                    "-"
                  end

                  # C#
                  cs_dbg_t = cm["cs_debug_ms"]? || cm["csharp_debug_compile_ms"]?
                  cs_rel_t = cm["cs_release_ms"]? || cm["csharp_release_compile_ms"]?
                  cs_dbg_sz = format_size.call(cm["cs_debug_bytes"]? || cm["csharp_debug_size_kb"]?.try(&.*(1024.0)))
                  cs_rel_sz = format_size.call(cm["cs_release_bytes"]? || cm["csharp_release_size_kb"]?.try(&.*(1024.0)))
                  cs_ratio_str = if cs_rel_t && cr_rel_t > 0
                    r = (cs_rel_t / cr_rel_t).round(2)
                    r >= 1.0 ? "#{r}x slower build" : "#{(1.0 / r).round(2)}x faster build"
                  else
                    "-"
                  end

                  # Rust
                  rs_dbg_t = cm["rs_debug_ms"]? || cm["rust_debug_compile_ms"]?
                  rs_rel_t = cm["rs_release_ms"]? || cm["rust_release_compile_ms"]?
                  rs_dbg_sz = format_size.call(cm["rs_debug_bytes"]? || cm["rust_debug_size_kb"]?.try(&.*(1024.0)))
                  rs_rel_sz = format_size.call(cm["rs_release_bytes"]? || cm["rust_release_size_kb"]?.try(&.*(1024.0)))
                  rs_ratio_str = if rs_rel_t && cr_rel_t > 0
                    r = (rs_rel_t / cr_rel_t).round(2)
                    r >= 1.0 ? "#{r}x slower build" : "#{(1.0 / r).round(2)}x faster build"
                  else
                    "-"
                  end

                  io << %(<table>
                    <thead>
                      <tr>
                        <th>Toolchain / Compiler</th>
                        <th class="num">Debug Time</th>
                        <th class="num">Release Time</th>
                        <th class="num">Debug Size</th>
                        <th class="num">Release Size</th>
                        <th class="num">Release Build Ratio</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr data-target-lang="crystal">
                        <td><span class="lang-badge lang-crystal">Crystal</span> (crystal build)</td>
                        <td class="num">#{cr_dbg_t ? "#{cr_dbg_t.round(0).to_i} ms" : "-"}</td>
                        <td class="num" style="color: var(--crystal-cyan); font-weight: 700;">#{cr_rel_t.round(0).to_i} ms</td>
                        <td class="num">#{cr_dbg_sz}</td>
                        <td class="num">#{cr_rel_sz}</td>
                        <td class="num"><strong>Baseline</strong></td>
                      </tr>
                      <tr data-target-lang="cpp">
                        <td><span class="lang-badge lang-cpp">C++</span> (g++ -O3)</td>
                        <td class="num">#{cpp_dbg_t ? "#{cpp_dbg_t.round(0).to_i} ms" : "-"}</td>
                        <td class="num" style="color: #569cd6; font-weight: 700;">#{cpp_rel_t ? "#{cpp_rel_t.round(0).to_i} ms" : "-"}</td>
                        <td class="num">#{cpp_dbg_sz}</td>
                        <td class="num">#{cpp_rel_sz}</td>
                        <td class="num">#{cpp_ratio_str}</td>
                      </tr>
                      <tr data-target-lang="csharp">
                        <td><span class="lang-badge lang-csharp">C#</span> (dotnet build)</td>
                        <td class="num">#{cs_dbg_t ? "#{cs_dbg_t.round(0).to_i} ms" : "-"}</td>
                        <td class="num" style="color: #d2a8ff; font-weight: 700;">#{cs_rel_t ? "#{cs_rel_t.round(0).to_i} ms" : "-"}</td>
                        <td class="num">#{cs_dbg_sz}</td>
                        <td class="num">#{cs_rel_sz}</td>
                        <td class="num">#{cs_ratio_str}</td>
                      </tr>
                      <tr data-target-lang="rust">
                        <td><span class="lang-badge lang-rust">Rust</span> (rustc -O)</td>
                        <td class="num">#{rs_dbg_t ? "#{rs_dbg_t.round(0).to_i} ms" : "-"}</td>
                        <td class="num" style="color: #dea584; font-weight: 700;">#{rs_rel_t ? "#{rs_rel_t.round(0).to_i} ms" : "-"}</td>
                        <td class="num">#{rs_dbg_sz}</td>
                        <td class="num">#{rs_rel_sz}</td>
                        <td class="num">#{rs_ratio_str}</td>
                      </tr>
                    </tbody>
                  </table>)

                elsif has_multilang && (first_m = grp_items.first?)
                  io << %(<table>
                    <thead>
                      <tr>
                        <th>Language / Target</th>
                        <th>Implementation</th>
                        <th class="num">Latency (ms)</th>
                        <th class="num">Speedup vs GDScript</th>
                        <th class="num">Ratio vs Crystal</th>
                      </tr>
                    </thead>
                    <tbody>\n)

                  cr_ms = first_m.crystal_ms
                  gd_ms = first_m.gdscript_ms
                  cr_vs_gd = gd_ms > 0 ? (gd_ms / cr_ms).round(1) : 1.0
                  io << %(<tr data-target-lang="crystal">
                    <td><span class="lang-badge lang-crystal">Crystal</span></td>
                    <td>Native LibGodot / LLVM O3</td>
                    <td class="num" style="color: var(--crystal-cyan); font-weight: 700;">#{cr_ms.round(2)} ms</td>
                    <td class="num"><span class="speedup-badge">#{cr_vs_gd}x faster</span></td>
                    <td class="num"><strong>1.0x (Baseline)</strong></td>
                  </tr>\n)

                  if cpp_ms = first_m.cpp_ms
                    c_vs_gd = gd_ms > 0 ? (gd_ms / cpp_ms).round(1) : 1.0
                    c_ratio = cr_ms > 0 ? (cr_ms / cpp_ms).round(2) : 1.0
                    c_ratio_str = c_ratio >= 1.0 ? "#{c_ratio}x faster" : "#{(1.0 / c_ratio).round(2)}x slower"
                    io << %(<tr data-target-lang="cpp">
                      <td><span class="lang-badge lang-cpp">C++</span></td>
                      <td>GCC / Clang -O3</td>
                      <td class="num" style="color: #569cd6; font-weight: 700;">#{cpp_ms.round(2)} ms</td>
                      <td class="num"><span class="speedup-badge">#{c_vs_gd}x faster</span></td>
                      <td class="num">#{c_ratio_str}</td>
                    </tr>\n)
                  end

                  if rs_ms = first_m.rust_ms
                    r_vs_gd = gd_ms > 0 ? (gd_ms / rs_ms).round(1) : 1.0
                    r_ratio = cr_ms > 0 ? (cr_ms / rs_ms).round(2) : 1.0
                    r_ratio_str = r_ratio >= 1.0 ? "#{r_ratio}x faster" : "#{(1.0 / r_ratio).round(2)}x slower"
                    io << %(<tr data-target-lang="rust">
                      <td><span class="lang-badge lang-rust">Rust</span></td>
                      <td>rustc -O</td>
                      <td class="num" style="color: #dea584; font-weight: 700;">#{rs_ms.round(2)} ms</td>
                      <td class="num"><span class="speedup-badge">#{r_vs_gd}x faster</span></td>
                      <td class="num">#{r_ratio_str}</td>
                    </tr>\n)
                  end

                  if cs_ms = first_m.csharp_ms
                    cs_vs_gd = gd_ms > 0 ? (gd_ms / cs_ms).round(1) : 1.0
                    cs_ratio = cr_ms > 0 ? (cr_ms / cs_ms).round(2) : 1.0
                    cs_ratio_str = cs_ratio >= 1.0 ? "#{cs_ratio}x faster" : "#{(1.0 / cs_ratio).round(2)}x slower"
                    io << %(<tr data-target-lang="csharp">
                      <td><span class="lang-badge lang-csharp">C#</span></td>
                      <td>.NET 8 RyuJIT Release</td>
                      <td class="num" style="color: #d2a8ff; font-weight: 700;">#{cs_ms.round(2)} ms</td>
                      <td class="num"><span class="speedup-badge">#{cs_vs_gd}x faster</span></td>
                      <td class="num">#{cs_ratio_str}</td>
                    </tr>\n)
                  end

                  if gd_ms > 0
                    gd_ratio = cr_ms > 0 ? (gd_ms / cr_ms).round(1) : 1.0
                    io << %(<tr data-target-lang="gdscript">
                      <td><span class="lang-badge lang-gdscript">GDScript</span></td>
                      <td>Godot VM Bytecode (Headless)</td>
                      <td class="num" style="color: var(--gd-amber); font-weight: 700;">#{gd_ms.round(2)} ms</td>
                      <td class="num">1.0x (Baseline)</td>
                      <td class="num" style="color: var(--gd-amber);">#{gd_ratio}x slower than Crystal</td>
                    </tr>\n)
                  end

                  io << %(</tbody></table>)

                elsif grp_kind == :throughput
                  io << %(<table>
                    <thead>
                      <tr>
                        <th>Benchmark Case</th>
                        <th>Description</th>
                        <th class="num">Crystal Latency</th>
                        <th class="num">GDScript Latency</th>
                        <th class="num">Throughput / Custom Metrics</th>
                        <th class="num">Speedup</th>
                      </tr>
                    </thead>
                    <tbody>\n)

                  grp_items.each do |sm|
                    throughput_str = String.build do |t_io|
                      if rate = sm.custom_metrics["shaders_per_sec"]?
                        t_io << %(<span class="metric-pill">#{rate.round(0).to_i} shaders/sec</span> )
                      end
                      if rate = sm.custom_metrics["updates_per_sec"]?
                        t_io << %(<span class="metric-pill">#{(rate / 1000.0).round(1)}k uniforms/sec</span> )
                      end
                      if rate = sm.custom_metrics["graphs_per_sec"]?
                        t_io << %(<span class="metric-pill">#{rate.round(0).to_i} graphs/sec</span> )
                      end
                    end
                    throughput_str = "-" if throughput_str.empty?

                    gd_txt = sm.gdscript_ms > 0 ? "#{sm.gdscript_ms.round(2)} ms" : "-"
                    sp_txt = sm.gdscript_ms > 0 ? %(<span class="speedup-badge">#{sm.speedup.round(1)}x faster</span>) : %(<span class="speedup-badge" style="background: rgba(0, 210, 255, 0.15); color: var(--crystal-cyan); border-color: rgba(0, 210, 255, 0.4);">Native</span>)

                    io << %(<tr>
                      <td><strong>#{XmlHandler.escape_xml(sm.name)}</strong></td>
                      <td style="color: var(--text-muted); font-size: 0.9rem;">#{XmlHandler.escape_xml(sm.description)}</td>
                      <td class="num" style="color: var(--crystal-cyan); font-weight: 700;">#{sm.crystal_ms.round(2)} ms</td>
                      <td class="num" style="color: var(--gd-amber); font-weight: 600;">#{gd_txt}</td>
                      <td class="num">#{throughput_str}</td>
                      <td class="num">#{sp_txt}</td>
                    </tr>\n)
                  end

                  io << %(</tbody></table>)

                else
                  # Generic Multi-item group
                  io << %(<table>
                    <thead>
                      <tr>
                        <th>Benchmark</th>
                        <th>Description</th>
                        <th class="num">Crystal</th>
                        <th class="num">GDScript</th>
                        <th class="num">Speedup</th>
                      </tr>
                    </thead>
                    <tbody>
                      #{render_rows.call(grp_items)}
                    </tbody>
                  </table>)
                end

                io << %(</div>\n)
              end
            end
          end

          # Category Tables
          table_headers = if is_native
            %(<thead>
        <tr>
          <th>Benchmark</th>
          <th>Category</th>
          <th>Description</th>
          <th class="num">Crystal Latency</th>
          <th class="num">Type</th>
        </tr>
      </thead>)
          else
            %(<thead>
        <tr>
          <th>Benchmark</th>
          <th>Description</th>
          <th class="num">Crystal</th>
          <th class="num">GDScript</th>
          #{has_editor ? %(<th class="num">GDScript (Editor)</th>) : ""}
          <th class="num">Speedup</th>
        </tr>
      </thead>)
          end

          compute_table_html = if !compute_metrics.empty?
            %(<h2>Compute Benchmarks</h2>
    <table>
      #{table_headers}
      <tbody>
        #{render_rows.call(compute_metrics)}
      </tbody>
    </table>)
          else
            ""
          end

          engine_table_html = if !engine_metrics.empty?
            %(<h2>Engine Core & Node Benchmarks</h2>
    <table>
      #{table_headers}
      <tbody>
        #{render_rows.call(engine_metrics)}
      </tbody>
    </table>)
          else
            ""
          end

          toolchain_table_html = if !toolchain_metrics.empty?
            %(<h2>Toolchain & Compilation Benchmarks</h2>
    <table>
      #{table_headers}
      <tbody>
        #{render_rows.call(toolchain_metrics)}
      </tbody>
    </table>)
          else
            ""
          end

          custom_table_html = if !custom_metrics.empty?
            category_title = title.includes?("Lapis") ? "Custom Benchmarks" : "#{title.sub(/:.*/, "").strip} Benchmarks"
            %(<h2>#{XmlHandler.escape_xml(category_title)}</h2>
    <table>
      #{table_headers}
      <tbody>
        #{render_rows.call(custom_metrics)}
      </tbody>
    </table>)
          else
            ""
          end

          kpi_cards = String.build do |io|
            if is_native
              io << %(<div class="kpi-card">
        <span class="kpi-title">Evaluated Benchmarks</span>
        <span class="kpi-value cyan">#{metrics.size}</span>
        <span class="kpi-sub">Native Crystal test cases</span>
      </div>\n)

              if fastest = fastest_metric
                io << %(<div class="kpi-card">
        <span class="kpi-title">Fastest Case</span>
        <span class="kpi-value cyan">#{fastest.crystal_ms.round(2)} ms</span>
        <span class="kpi-sub">#{XmlHandler.escape_xml(fastest.name)}</span>
      </div>\n)
              end

              io << %(<div class="kpi-card">
        <span class="kpi-title">Average Latency</span>
        <span class="kpi-value purple">#{avg_latency.round(2)} ms</span>
        <span class="kpi-sub">Mean execution per test case</span>
      </div>\n)

              io << %(<div class="kpi-card">
        <span class="kpi-title">Total Suite Latency</span>
        <span class="kpi-value amber">#{total_latency.round(2)} ms</span>
        <span class="kpi-sub">Summed benchmark duration</span>
      </div>\n)
            else
              if !comparative_speedups.empty?
                io << %(<div class="kpi-card">
        <span class="kpi-title">Geometric Mean Speedup</span>
        <span class="kpi-value cyan">#{geo_mean.round(1)}x</span>
        <span class="kpi-sub">Across #{comparative_speedups.size} comparative benchmarks</span>
      </div>\n)
              else
                io << %(<div class="kpi-card">
        <span class="kpi-title">Benchmark Cases</span>
        <span class="kpi-value cyan">#{metrics.size}</span>
        <span class="kpi-sub">Total evaluated benchmarks</span>
      </div>\n)
              end

              if comp_geo > 0.0
                io << %(<div class="kpi-card">
        <span class="kpi-title">Pure Compute Speedup</span>
        <span class="kpi-value cyan">#{comp_geo.round(1)}x</span>
        <span class="kpi-sub">#{compute_metrics.size} numerical benchmarks</span>
      </div>\n)
              end

              if eng_geo > 0.0
                io << %(<div class="kpi-card">
        <span class="kpi-title">Engine Core Speedup</span>
        <span class="kpi-value amber">#{eng_geo.round(1)}x</span>
        <span class="kpi-sub">#{engine_metrics.size} engine API benchmarks</span>
      </div>\n)
              end

              if !grouped_metrics.empty?
                group_count = grouped_metrics.keys.compact.reject(&.empty?).size
                io << %(<div class="kpi-card">
        <span class="kpi-title">Comparison Groups</span>
        <span class="kpi-value purple">#{group_count}</span>
        <span class="kpi-sub">Grouped domain subsystems</span>
      </div>\n)
              end

              if !comparative_speedups.empty? && max_metric.speedup > 1.0
                io << %(<div class="kpi-card">
        <span class="kpi-title">Peak Speedup</span>
        <span class="kpi-value cyan">#{max_metric.speedup.round(1)}x</span>
        <span class="kpi-sub">#{XmlHandler.escape_xml(max_metric.name)}</span>
      </div>\n)
              end
            end
          end

          history_section_html = if history && !history.empty?
            hist_rows = history.map do |h|
              metric_cell = if is_native
                h.total_ms ? %(<span class="speedup-badge" style="background: rgba(0, 210, 255, 0.15); color: var(--crystal-cyan); border-color: rgba(0, 210, 255, 0.4);">#{h.total_ms.not_nil!.round(2)} ms</span>) : "-"
              else
                h.speedup ? %(<span class="speedup-badge">#{h.speedup.not_nil!.round(1)}x faster</span>) : "-"
              end
              %(<tr>
                <td><span class="tag-badge">#{XmlHandler.escape_xml(h.tag)}</span></td>
                <td>v#{XmlHandler.escape_xml(h.version)}</td>
                <td>Godot #{XmlHandler.escape_xml(h.godot_ver)}</td>
                <td class="num">#{metric_cell}</td>
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

            metric_col_name = is_native ? "Total Latency" : "GeoMean Speedup"
            %(<h2>Historical Benchmark Releases &amp; Logs</h2>
            <table>
              <thead>
                <tr>
                  <th>Tag / Release</th>
                  <th>#{XmlHandler.escape_xml(project_name)} Version</th>
                  <th>Godot Version</th>
                  <th class="num">#{metric_col_name}</th>
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
    .container { max-width: 1150px; margin: 0 auto; }
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
    .lang-badge {
      display: inline-block;
      padding: 0.2rem 0.55rem;
      border-radius: 6px;
      font-weight: 700;
      font-size: 0.82rem;
      font-family: monospace;
    }
    .lang-crystal { background: rgba(0, 210, 255, 0.18); border: 1px solid #00d2ff; color: #00d2ff; }
    .lang-cpp { background: rgba(86, 156, 214, 0.18); border: 1px solid #569cd6; color: #569cd6; }
    .lang-rust { background: rgba(222, 165, 132, 0.18); border: 1px solid #dea584; color: #dea584; }
    .lang-csharp { background: rgba(210, 168, 255, 0.18); border: 1px solid #d2a8ff; color: #d2a8ff; }
    .lang-gdscript { background: rgba(255, 153, 0, 0.18); border: 1px solid #ff9900; color: #ff9900; }
    .metric-pill {
      display: inline-block;
      background: rgba(255, 255, 255, 0.06);
      border: 1px solid var(--border);
      color: #e6edf3;
      padding: 0.15rem 0.45rem;
      border-radius: 4px;
      font-size: 0.8rem;
      font-family: monospace;
    }
    .lang-filter-bar {
      display: flex;
      align-items: center;
      gap: 0.5rem;
      flex-wrap: wrap;
      margin-bottom: 1.5rem;
      padding: 0.75rem 1rem;
      background-color: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 8px;
    }
    .filter-label {
      font-size: 0.85rem;
      color: var(--text-muted);
      font-weight: 600;
      margin-right: 0.25rem;
    }
    .filter-btn {
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid var(--border);
      color: var(--text);
      padding: 0.35rem 0.75rem;
      border-radius: 6px;
      font-size: 0.82rem;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.15s ease;
    }
    .filter-btn:hover {
      background: rgba(255, 255, 255, 0.1);
      border-color: var(--crystal-cyan);
    }
    .filter-btn.active {
      background: rgba(0, 210, 255, 0.15);
      border-color: var(--crystal-cyan);
      color: var(--crystal-cyan);
    }
    .group-card {
      background-color: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 1.5rem;
      margin-bottom: 2rem;
    }
    .group-header {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      margin-bottom: 1.25rem;
    .group-title { font-size: 1.25rem; font-weight: 700; color: #fff; margin-bottom: 0.25rem; }
    .group-desc { font-size: 0.9rem; color: var(--text-muted); }
    .group-header-right {
      display: flex;
      align-items: center;
      gap: 0.75rem;
      flex-wrap: wrap;
    }
    .chart-view-selector {
      display: flex;
      align-items: center;
      gap: 0.35rem;
      background: rgba(255, 255, 255, 0.04);
      padding: 0.25rem 0.35rem;
      border: 1px solid var(--border);
      border-radius: 6px;
    }
    .view-btn {
      background: transparent;
      border: 1px solid transparent;
      color: var(--text-muted);
      padding: 0.25rem 0.6rem;
      border-radius: 4px;
      font-size: 0.78rem;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.15s ease;
    }
    .view-btn:hover {
      color: #fff;
      background: rgba(255, 255, 255, 0.08);
    }
    .view-btn.active {
      background: rgba(0, 210, 255, 0.18);
      border-color: var(--crystal-cyan);
      color: var(--crystal-cyan);
    }
    .group-charts-container {
      margin-bottom: 1.25rem;
      border-radius: 8px;
      overflow: hidden;
      background: #0d1117;
      border: 1px solid var(--border);
    }
    .group-chart-view {
      padding: 0.5rem;
      transition: opacity 0.2s ease;
    }
    .group-chart-view svg {
      max-width: 100%;
      height: auto;
      display: block;
      margin: 0 auto;
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
      margin-bottom: 1.5rem;
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
        #{XmlHandler.escape_xml(project_name)} v#{XmlHandler.escape_xml(version)} &bull; Godot #{XmlHandler.escape_xml(godot_ver)} &bull; #{XmlHandler.escape_xml(platform.capitalize)}#{tag_badge_html}#{mode_badge_html}
      </div>
    </header>

    #{progression_banner_html}

    <div class="kpi-row">
      #{kpi_cards}
    </div>

    <div class="chart-container">
      #{svg_chart}
    </div>

    #{comparison_groups_html}

    #{compute_table_html}
    #{engine_table_html}
    #{toolchain_table_html}
    #{custom_table_html}

    #{history_section_html}

    <footer>
      Generated by Lapis &bull; #{XmlHandler.escape_xml(project_name)} Benchmark Dashboard &bull; Native High-Performance Crystal Toolchain for Godot
    </footer>

    <script>
      document.querySelectorAll('.filter-btn').forEach(function(btn) {
        btn.addEventListener('click', function() {
          document.querySelectorAll('.filter-btn').forEach(function(b) { b.classList.remove('active'); });
          btn.classList.add('active');
          var lang = btn.getAttribute('data-lang');
          document.querySelectorAll('[data-target-lang]').forEach(function(el) {
            if (lang === 'all' || el.getAttribute('data-target-lang') === lang) {
              el.style.display = '';
            } else {
              el.style.display = 'none';
            }
          });
        });
      });

      // Chart view switcher
      document.querySelectorAll('.chart-view-selector').forEach(function(selector) {
        var groupSlug = selector.getAttribute('data-group');
        var container = document.querySelector('.group-charts-container[data-group="' + groupSlug + '"]');
        if (!container) return;

        selector.querySelectorAll('.view-btn').forEach(function(btn) {
          btn.addEventListener('click', function() {
            selector.querySelectorAll('.view-btn').forEach(function(b) { b.classList.remove('active'); });
            btn.classList.add('active');
            var view = btn.getAttribute('data-view');
            container.querySelectorAll('.group-chart-view').forEach(function(cv) {
              if (cv.getAttribute('data-view') === view) {
                cv.style.display = 'block';
                cv.classList.add('active');
              } else {
                cv.style.display = 'none';
                cv.classList.remove('active');
              }
            });
          });
        });
      });
    </script>
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
          prev_tag : String? = nil,
          project_name : String = "Lapis",
          native_mode : Bool = false
        ) : String
          curr_map = curr_metrics.to_h { |m| {m.name, m} }
          prev_map = prev_metrics.to_h { |m| {m.name, m} }
          all_names = (curr_map.keys + prev_map.keys).uniq.sort

          is_native = native_mode || (curr_metrics.all? { |m| m.gdscript_ms <= 0.0 } && prev_metrics.all? { |m| m.gdscript_ms <= 0.0 })

          curr_total = curr_metrics.sum(&.crystal_ms)
          prev_total = prev_metrics.sum(&.crystal_ms)
          latency_diff_pct = prev_total > 0 ? ((curr_total - prev_total) / prev_total) * 100.0 : 0.0

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
            cat = c.try(&.category.display_name) || p.try(&.category.display_name) || "Custom"

            c_ms = c ? "#{c.crystal_ms.round(2)} ms" : "-"
            p_ms = p ? "#{p.crystal_ms.round(2)} ms" : "-"
            c_sp = c ? "#{c.speedup.round(1)}x" : "-"
            p_sp = p ? "#{p.speedup.round(1)}x" : "-"

            delta_cell = if c && p && p.crystal_ms > 0
              diff_pct = ((c.crystal_ms - p.crystal_ms) / p.crystal_ms) * 100.0
              if diff_pct < -1.0
                %(<span class="speedup-badge" style="background: rgba(35,134,54,0.25); border-color:#3fb950; color:#3fb950;">#{diff_pct.abs.round(1)}% faster</span>)
              elsif diff_pct > 1.0
                %(<span class="speedup-badge" style="background: rgba(248,81,73,0.2); border-color:#f85149; color:#f85149;">+#{diff_pct.round(1)}% slower</span>)
              else
                %(<span style="color: var(--text-muted); font-size: 0.85rem;">~ parity</span>)
              end
            else
              %(<span style="color: var(--text-muted);">-</span>)
            end

            if is_native
              %(<tr>
                <td><strong>#{XmlHandler.escape_xml(name)}</strong></td>
                <td><span class="tag-badge" style="font-size: 0.75rem;">#{XmlHandler.escape_xml(cat)}</span></td>
                <td style="color: var(--text-muted); font-size: 0.9rem;">#{XmlHandler.escape_xml(desc)}</td>
                <td class="num" style="color: var(--text-muted);">#{p_ms}</td>
                <td class="num" style="color: var(--crystal-cyan); font-weight: 700;">#{c_ms}</td>
                <td class="num">#{delta_cell}</td>
              </tr>)
            else
              %(<tr>
                <td><strong>#{XmlHandler.escape_xml(name)}</strong></td>
                <td style="color: var(--text-muted); font-size: 0.9rem;">#{XmlHandler.escape_xml(desc)}</td>
                <td class="num" style="color: var(--text-muted);">#{p_ms}</td>
                <td class="num" style="color: var(--crystal-cyan); font-weight: 700;">#{c_ms}</td>
                <td class="num" style="color: var(--text-muted);">#{p_sp}</td>
                <td class="num" style="color: var(--crystal-cyan); font-weight: 700;">#{c_sp}</td>
                <td class="num">#{delta_cell}</td>
              </tr>)
            end
          end.join("\n")

          comparison_kpis = if is_native
            diff_sign = latency_diff_pct > 0 ? "+" : ""
            diff_col = latency_diff_pct <= 0 ? "cyan" : "amber"
            status_text = latency_diff_pct < -1.0 ? "Latency reduced" : (latency_diff_pct > 1.0 ? "Latency increased" : "Parity")
            %(<div class="kpi-card">
        <span class="kpi-title">Current Total Latency</span>
        <span class="kpi-value cyan">#{curr_total.round(2)} ms</span>
        <span class="kpi-sub">#{XmlHandler.escape_xml(display_curr)}</span>
      </div>
      <div class="kpi-card">
        <span class="kpi-title">Previous Total Latency</span>
        <span class="kpi-value">#{prev_total.round(2)} ms</span>
        <span class="kpi-sub">#{XmlHandler.escape_xml(display_prev)}</span>
      </div>
      <div class="kpi-card">
        <span class="kpi-title">Progression Delta</span>
        <span class="kpi-value #{diff_col}">#{diff_sign}#{latency_diff_pct.round(1)}%</span>
        <span class="kpi-sub">#{status_text}</span>
      </div>
      <div class="kpi-card">
        <span class="kpi-title">Compared Benchmarks</span>
        <span class="kpi-value">#{all_names.size}</span>
        <span class="kpi-sub">Test cases evaluated</span>
      </div>)
          else
            sign = overall_diff_pct >= 0 ? "+" : ""
            diff_color = overall_diff_pct >= 0 ? "cyan" : "amber"
            %(<div class="kpi-card">
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
      </div>)
          end

          table_headers = if is_native
            %(<tr>
              <th>Benchmark</th>
              <th>Category</th>
              <th>Description</th>
              <th class="num">Prev Crystal</th>
              <th class="num">Curr Crystal</th>
              <th class="num">Latency Shift</th>
            </tr>)
          else
            %(<tr>
              <th>Benchmark</th>
              <th>Description</th>
              <th class="num">Prev Crystal</th>
              <th class="num">Curr Crystal</th>
              <th class="num">Prev Speedup</th>
              <th class="num">Curr Speedup</th>
              <th class="num">Crystal Shift</th>
            </tr>)
          end

          <<-HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>#{XmlHandler.escape_xml(project_name)} Benchmark Progression: #{XmlHandler.escape_xml(display_prev)} vs #{XmlHandler.escape_xml(display_curr)}</title>
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
    footer { text-align: center; color: var(--text-muted); font-size: 0.85rem; margin-top: 3rem; }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>#{XmlHandler.escape_xml(project_name)} Benchmark Progression</h1>
      <div class="subtitle">
        <a href="benchmarks.html" style="color: var(--crystal-cyan); text-decoration: none; margin-right: 0.75rem;">&larr; Back to Main Report</a> &bull;
        Comparing Baseline <strong>#{XmlHandler.escape_xml(display_prev)}</strong> &rarr; Target <strong>#{XmlHandler.escape_xml(display_curr)}</strong>
      </div>
    </header>

    <div class="kpi-row">
      #{comparison_kpis}
    </div>

    <table>
      <thead>
        #{table_headers}
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
    end
  end
end
