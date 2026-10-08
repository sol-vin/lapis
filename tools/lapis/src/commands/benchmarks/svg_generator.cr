require "./models"
require "./xml_handler"

module Lapis
  module Commands
    module Benchmarks
      module SvgGenerator
        struct ChartRow
          property label : String
          property val1 : Float64
          property val2 : Float64?
          property unit : String
          property color1_start : String
          property color1_end : String
          property color2_start : String?
          property color2_end : String?
          property badge : String?
          property is_baseline : Bool

          def initialize(
            @label : String,
            @val1 : Float64,
            @val2 : Float64? = nil,
            @unit : String = "ms",
            @color1_start : String = "#00D2FF",
            @color1_end : String = "#0077B6",
            @color2_start : String? = nil,
            @color2_end : String? = nil,
            @badge : String? = nil,
            @is_baseline : Bool = false
          )
          end
        end

        def self.generate_svg(
          metrics : Array(BenchmarkMetric),
          title : String = "Lapis Benchmark Suite: Performance Comparison",
          native_mode : Bool = false
        ) : String
          return "" if metrics.empty?
          is_native = native_mode || metrics.all? { |m| m.gdscript_ms <= 0.0 }

          if is_native
            generate_native_svg(metrics, title)
          else
            generate_comparative_svg(metrics, title)
          end
        end

        def self.generate_native_svg(metrics : Array(BenchmarkMetric), title : String) : String
          svg_width = 1040
          bar_height = 18
          group_spacing = 46
          margin_top = 85
          margin_left = 175
          margin_right = 200
          chart_width = svg_width - margin_left - margin_right
          svg_height = margin_top + (metrics.size * group_spacing) + 30

          max_time = metrics.max_of(&.crystal_ms)
          max_time = 0.001 if max_time <= 0.0

          String.build do |io|
            io << %(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{svg_width} #{svg_height}" width="#{svg_width}" height="#{svg_height}">\n)
            io << %(  <defs>\n)
            io << %(    <linearGradient id="crGrad" x1="0%" y1="0%" x2="100%" y2="0%"><stop offset="0%" stop-color="#00D2FF"/><stop offset="100%" stop-color="#0077B6"/></linearGradient>\n)
            io << %(  </defs>\n)
            io << %(  <rect width="#{svg_width}" height="#{svg_height}" rx="12" fill="#0D1117"/>\n)
            io << %(  <rect width="#{svg_width}" height="#{svg_height}" rx="12" fill="none" stroke="#30363D" stroke-width="1.5"/>\n)
            io << %(  <text x="32" y="40" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif" font-size="20" font-weight="bold" fill="#F0F3F6">#{XmlHandler.escape_xml(title)}</text>\n)
            io << %(  <text x="32" y="60" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif" font-size="12" fill="#8B949E">Execution time in milliseconds (shorter is faster) &bull; Native High-Performance Crystal</text>\n)

            metrics.each_with_index do |m, idx|
              group_y = margin_top + (idx * group_spacing)
              cr_w = [8, ((m.crystal_ms / max_time) * chart_width).round.to_i].max

              io << %(  <text x="#{margin_left - 15}" y="#{group_y + 14}" text-anchor="end" font-family="sans-serif" font-size="13" font-weight="bold" fill="#F0F3F6">#{XmlHandler.escape_xml(m.name)}</text>\n)
              io << %(  <rect x="#{margin_left}" y="#{group_y}" width="#{chart_width}" height="#{bar_height}" rx="4" fill="#21262D"/>\n)
              io << %(  <rect x="#{margin_left}" y="#{group_y}" width="#{cr_w}" height="#{bar_height}" rx="4" fill="url(#crGrad)"/>\n)
              cr_text = "#{m.crystal_ms.round(2)} ms"
              if cr_w >= 120
                io << %(  <text x="#{margin_left + cr_w - 10}" y="#{group_y + 14}" text-anchor="end" font-family="sans-serif" font-size="11" font-weight="700" fill="#FFFFFF">#{cr_text}</text>\n)
              else
                io << %(  <text x="#{margin_left + cr_w + 10}" y="#{group_y + 14}" font-family="sans-serif" font-size="11" font-weight="700" fill="#00D2FF">#{cr_text}</text>\n)
              end

              badge_x = svg_width - 110
              io << %(  <rect x="#{badge_x}" y="#{group_y - 2}" width="85" height="22" rx="11" fill="#00D2FF" fill-opacity="0.12" stroke="#00D2FF" stroke-width="1"/>\n)
              io << %(  <text x="#{badge_x + 42}" y="#{group_y + 13}" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="600" fill="#00D2FF">#{XmlHandler.escape_xml(m.category.display_name)}</text>\n)
            end
            io << %(</svg>\n)
          end
        end

        def self.generate_comparative_svg(metrics : Array(BenchmarkMetric), title : String) : String
          svg_width = 1040
          has_editor = metrics.any? { |m| m.editor_ms }
          bar_height = has_editor ? 12 : 14
          group_spacing = has_editor ? 70 : 58
          margin_top = 85
          margin_left = 185
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
            io << %(  <text x="32" y="40" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif" font-size="20" font-weight="bold" fill="#F0F3F6">#{XmlHandler.escape_xml(title)}</text>\n)
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
              cr_text = "#{m.crystal_ms.round(2)} ms (Crystal)"
              if cr_w >= 140
                io << %(  <text x="#{margin_left + cr_w - 10}" y="#{group_y + 10}" text-anchor="end" font-family="sans-serif" font-size="11" font-weight="700" fill="#FFFFFF">#{cr_text}</text>\n)
              else
                io << %(  <text x="#{margin_left + cr_w + 8}" y="#{group_y + 10}" font-family="sans-serif" font-size="11" font-weight="600" fill="#00D2FF">#{cr_text}</text>\n)
              end

              if m.gdscript_ms > 0.0
                io << %(  <rect x="#{margin_left}" y="#{group_y + 18}" width="#{chart_width}" height="#{bar_height}" rx="3" fill="#21262D"/>\n)
                io << %(  <rect x="#{margin_left}" y="#{group_y + 18}" width="#{gd_w}" height="#{bar_height}" rx="3" fill="url(#gdGrad)"/>\n)
                gd_text = "#{m.gdscript_ms.round(2)} ms (GDScript)"
                if gd_w >= 140
                  io << %(  <text x="#{margin_left + gd_w - 10}" y="#{group_y + 28}" text-anchor="end" font-family="sans-serif" font-size="11" font-weight="700" fill="#FFFFFF">#{gd_text}</text>\n)
                else
                  io << %(  <text x="#{margin_left + gd_w + 8}" y="#{group_y + 28}" font-family="sans-serif" font-size="11" font-weight="600" fill="#FF9900">#{gd_text}</text>\n)
                end

                badge_x = svg_width - 120
                io << %(  <rect x="#{badge_x}" y="#{group_y + 10}" width="95" height="24" rx="12" fill="#238636" fill-opacity="0.2" stroke="#238636" stroke-width="1"/>\n)
                io << %(  <text x="#{badge_x + 47}" y="#{group_y + 26}" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="bold" fill="#3FB950">#{m.speedup.round(1)}x faster</text>\n)
              else
                badge_x = svg_width - 120
                io << %(  <rect x="#{badge_x}" y="#{group_y + 4}" width="95" height="24" rx="12" fill="#00D2FF" fill-opacity="0.15" stroke="#00D2FF" stroke-width="1"/>\n)
                io << %(  <text x="#{badge_x + 47}" y="#{group_y + 20}" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="bold" fill="#00D2FF">Native</text>\n)
              end
            end
            io << %(</svg>\n)
          end
        end

        # =========================================================================
        # Generic Comparison Group SVG Generator
        # =========================================================================
        def self.generate_group_svg(
          group_name : String,
          items : Array(BenchmarkMetric),
          mode : Symbol,
          baseline_name : String? = nil,
          kind : Symbol = :runtime
        ) : String
          return "" if items.empty?

          rows = extract_chart_rows(items, mode, baseline_name, kind)
          return "" if rows.empty?

          has_dual = rows.any?(&.val2)
          row_spacing = has_dual ? 52 : 40
          bar_height = has_dual ? 11 : 16

          margin_top = 70
          margin_left = 175
          margin_right = 170
          svg_width = 960
          chart_width = svg_width - margin_left - margin_right
          svg_height = margin_top + (rows.size * row_spacing) + 25

          mode_titles = {
            :bar              => "Latency Comparison (Lower is Faster)",
            :speedup          => "Speedup vs Baseline (Higher is Better)",
            :ratio            => "Normalized Ratio vs Baseline (1.0x)",
            :log              => "Logarithmic Latency Scale (Orders of Magnitude)",
            :debug_vs_release => "Compilation Time: Debug vs Release -O3",
            :size             => "Output Binary Size: Debug vs Release",
            :throughput       => "Throughput / Operations per Second (Higher is Better)",
          }
          mode_desc = mode_titles[mode]? || "Performance Comparison"

          # Calculate scale limits
          max_v1 = rows.map(&.val1).max? || 1.0
          max_v1 = 1.0 if max_v1 <= 0.0

          max_v2 = has_dual ? (rows.compact_map(&.val2).max? || 1.0) : 0.0
          max_val = [max_v1, max_v2].max
          max_val = 1.0 if max_val <= 0.0

          min_val = rows.map(&.val1).reject(&.<=(0.0)).min? || 0.1

          String.build do |io|
            io << %(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{svg_width} #{svg_height}" width="100%" height="auto" style="display: block; max-width: 100%;">\n)
            io << %(  <defs>\n)
            rows.each_with_index do |r, idx|
              io << %(    <linearGradient id="grpGrad_#{idx}_1" x1="0%" y1="0%" x2="100%" y2="0%"><stop offset="0%" stop-color="#{r.color1_start}"/><stop offset="100%" stop-color="#{r.color1_end}"/></linearGradient>\n)
              if r.val2
                c2s = r.color2_start || "#FFAA00"
                c2e = r.color2_end || "#CC7700"
                io << %(    <linearGradient id="grpGrad_#{idx}_2" x1="0%" y1="0%" x2="100%" y2="0%"><stop offset="0%" stop-color="#{c2s}"/><stop offset="100%" stop-color="#{c2e}"/></linearGradient>\n)
              end
            end
            io << %(  </defs>\n)

            # Card background
            io << %(  <rect width="#{svg_width}" height="#{svg_height}" rx="10" fill="#0D1117"/>\n)
            io << %(  <rect width="#{svg_width}" height="#{svg_height}" rx="10" fill="none" stroke="#30363D" stroke-width="1.2"/>\n)

            # Header
            io << %(  <text x="24" y="32" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif" font-size="16" font-weight="700" fill="#F0F3F6">#{XmlHandler.escape_xml(group_name)} &bull; #{XmlHandler.escape_xml(mode_desc)}</text>\n)
            baseline_label = baseline_name ? "Baseline: #{baseline_name}" : "Normalized"
            io << %(  <text x="24" y="50" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif" font-size="11" fill="#8B949E">#{XmlHandler.escape_xml(baseline_label)} &bull; Interactive view mode: #{mode}</text>\n)

            # Ratio baseline line if in :ratio mode
            if mode == :ratio
              base_x = margin_left + ((1.0 / [max_val, 2.0].max) * chart_width).round.to_i
              io << %(  <line x1="#{base_x}" y1="#{margin_top - 10}" x2="#{base_x}" y2="#{svg_height - 15}" stroke="#58A6FF" stroke-width="1.5" stroke-dasharray="3,3"/>\n)
              io << %(  <text x="#{base_x + 4}" y="#{margin_top - 4}" font-family="sans-serif" font-size="10" font-weight="600" fill="#58A6FF">1.0x Baseline</text>\n)
            end

            # Log scale guides
            if mode == :log
              log_min = Math.log10([min_val, 0.01].max)
              log_max = Math.log10([max_val, 10.0].max)
              log_range = [log_max - log_min, 0.5].max

              [-1, 0, 1, 2, 3].each do |p|
                v = 10.0 ** p
                if v >= min_val * 0.5 && v <= max_val * 2.0
                  frac = (Math.log10(v) - log_min) / log_range
                  if frac >= 0.0 && frac <= 1.0
                    gx = margin_left + (frac * chart_width).round.to_i
                    io << %(  <line x1="#{gx}" y1="#{margin_top - 5}" x2="#{gx}" y2="#{svg_height - 15}" stroke="#21262D" stroke-width="1"/>\n)
                    io << %(  <text x="#{gx}" y="#{margin_top - 8}" text-anchor="middle" font-family="sans-serif" font-size="9" fill="#8B949E">#{v >= 1.0 ? v.to_i.to_s : v.to_s} ms</text>\n)
                  end
                end
              end
            end

            # Rows
            rows.each_with_index do |r, idx|
              gy = margin_top + (idx * row_spacing)

              # Compute width for val1
              w1 = if mode == :log
                log_min = Math.log10([min_val, 0.01].max)
                log_max = Math.log10([max_val, 10.0].max)
                log_range = [log_max - log_min, 0.5].max
                frac = ([Math.log10([r.val1, 0.01].max) - log_min, 0.0].max / log_range).clamp(0.02, 1.0)
                [8, (frac * chart_width).round.to_i].max
              else
                [6, ((r.val1 / max_val) * chart_width).round.to_i].max
              end

              # Label
              io << %(  <text x="#{margin_left - 12}" y="#{gy + (has_dual ? 18 : 12)}" text-anchor="end" font-family="sans-serif" font-size="12" font-weight="600" fill="#F0F3F6">#{XmlHandler.escape_xml(r.label)}</text>\n)

              if has_dual && (v2 = r.val2)
                # Dual bars (e.g. Release vs Debug, or Crystal vs GDScript)
                w2 = [6, ((v2 / max_val) * chart_width).round.to_i].max

                # Bar 1 (Release / Primary)
                io << %(  <rect x="#{margin_left}" y="#{gy}" width="#{chart_width}" height="#{bar_height}" rx="3" fill="#21262D"/>\n)
                io << %(  <rect x="#{margin_left}" y="#{gy}" width="#{w1}" height="#{bar_height}" rx="3" fill="url(#grpGrad_#{idx}_1)"/>\n)
                t1_str = "#{r.val1.round(1)} #{r.unit} (Release)"
                if w1 >= 120
                  io << %(  <text x="#{margin_left + w1 - 8}" y="#{gy + 9}" text-anchor="end" font-family="sans-serif" font-size="10" font-weight="700" fill="#FFFFFF">#{t1_str}</text>\n)
                else
                  io << %(  <text x="#{margin_left + w1 + 6}" y="#{gy + 9}" font-family="sans-serif" font-size="10" font-weight="600" fill="#{r.color1_start}">#{t1_str}</text>\n)
                end

                # Bar 2 (Debug / Secondary)
                io << %(  <rect x="#{margin_left}" y="#{gy + bar_height + 4}" width="#{chart_width}" height="#{bar_height}" rx="3" fill="#21262D"/>\n)
                io << %(  <rect x="#{margin_left}" y="#{gy + bar_height + 4}" width="#{w2}" height="#{bar_height}" rx="3" fill="url(#grpGrad_#{idx}_2)"/>\n)
                c2_text = r.color2_start || "#FFAA00"
                t2_str = "#{v2.round(1)} #{r.unit} (Debug)"
                if w2 >= 120
                  io << %(  <text x="#{margin_left + w2 - 8}" y="#{gy + bar_height + 13}" text-anchor="end" font-family="sans-serif" font-size="10" font-weight="700" fill="#FFFFFF">#{t2_str}</text>\n)
                else
                  io << %(  <text x="#{margin_left + w2 + 6}" y="#{gy + bar_height + 13}" font-family="sans-serif" font-size="10" font-weight="600" fill="#{c2_text}">#{t2_str}</text>\n)
                end
              else
                # Single bar
                io << %(  <rect x="#{margin_left}" y="#{gy}" width="#{chart_width}" height="#{bar_height}" rx="4" fill="#21262D"/>\n)
                io << %(  <rect x="#{margin_left}" y="#{gy}" width="#{w1}" height="#{bar_height}" rx="4" fill="url(#grpGrad_#{idx}_1)"/>\n)
                val_str = "#{r.val1.round(2)} #{r.unit}"
                if w1 >= 110
                  io << %(  <text x="#{margin_left + w1 - 8}" y="#{gy + 12}" text-anchor="end" font-family="sans-serif" font-size="11" font-weight="700" fill="#FFFFFF">#{val_str}</text>\n)
                else
                  io << %(  <text x="#{margin_left + w1 + 8}" y="#{gy + 12}" font-family="sans-serif" font-size="11" font-weight="600" fill="#{r.color1_start}">#{val_str}</text>\n)
                end
              end

              # Badge on the right
              if badge = r.badge
                badge_x = svg_width - 130
                badge_bg = r.is_baseline ? "rgba(0, 210, 255, 0.12)" : "rgba(35, 134, 54, 0.15)"
                badge_border = r.is_baseline ? "#00D2FF" : "#3FB950"
                badge_text_col = r.is_baseline ? "#00D2FF" : "#3FB950"

                badge_y = has_dual ? gy + 6 : gy - 2
                io << %(  <rect x="#{badge_x}" y="#{badge_y}" width="105" height="22" rx="11" fill="#{badge_bg}" stroke="#{badge_border}" stroke-width="1"/>\n)
                io << %(  <text x="#{badge_x + 52}" y="#{badge_y + 14}" text-anchor="middle" font-family="sans-serif" font-size="10" font-weight="700" fill="#{badge_text_col}">#{XmlHandler.escape_xml(badge)}</text>\n)
              end
            end

            io << %(</svg>\n)
          end
        end

        # =========================================================================
        # Helper: Extract Chart Rows from Group Metrics
        # =========================================================================
        def self.extract_chart_rows(
          items : Array(BenchmarkMetric),
          mode : Symbol,
          baseline_name : String?,
          kind : Symbol
        ) : Array(ChartRow)
          rows = [] of ChartRow
          return rows if items.empty?

          case kind
          when :compile_time
            extract_compile_time_rows(rows, items, mode, baseline_name)
          when :throughput
            extract_throughput_rows(rows, items, mode, baseline_name)
          else
            # Default :runtime
            if items.any? { |m| m.cpp_ms || m.rust_ms || m.csharp_ms }
              extract_multilang_rows(rows, items, mode, baseline_name)
            else
              extract_multi_item_rows(rows, items, mode, baseline_name)
            end
          end

          rows
        end

        private def self.extract_compile_time_rows(
          rows : Array(ChartRow),
          items : Array(BenchmarkMetric),
          mode : Symbol,
          baseline_name : String?
        ) : Nil
          comp_m = items.find { |i| i.name == "CompileTimes" } || items.first
          cm = comp_m.custom_metrics

          toolchains = [
            {"Crystal", "cr", "#00D2FF", "#0077B6"},
            {"C++", "cpp", "#569CD6", "#2B6CB0"},
            {"Rust", "rs", "#DEA584", "#B85D32"},
            {"C#", "cs", "#D2A8FF", "#8A5CF6"},
          ]

          cr_rel = cm["cr_release_ms"]? || cm["crystal_release_compile_ms"]? || comp_m.crystal_ms
          cr_rel = 1.0 if cr_rel <= 0.0

          toolchains.each do |(tname, prefix, c1_s, c1_e)|
            rel_ms = cm["#{prefix}_release_ms"]? || (prefix == "cr" ? (cm["crystal_release_compile_ms"]? || comp_m.crystal_ms) : (prefix == "cpp" ? cm["cpp_release_compile_ms"]? : (prefix == "rs" ? cm["rust_release_compile_ms"]? : cm["csharp_release_compile_ms"]?))) || 0.0
            dbg_ms = cm["#{prefix}_debug_ms"]? || (prefix == "cr" ? cm["crystal_debug_compile_ms"]? : (prefix == "cpp" ? cm["cpp_debug_compile_ms"]? : (prefix == "rs" ? cm["rust_debug_compile_ms"]? : cm["csharp_debug_compile_ms"]?)))

            rel_bytes = cm["#{prefix}_release_bytes"]? || (prefix == "cr" ? cm["crystal_release_size_kb"]?.try(&.*(1024.0)) : (prefix == "cpp" ? cm["cpp_release_size_kb"]?.try(&.*(1024.0)) : (prefix == "rs" ? cm["rust_release_size_kb"]?.try(&.*(1024.0)) : cm["csharp_release_size_kb"]?.try(&.*(1024.0))))) || 0.0
            dbg_bytes = cm["#{prefix}_debug_bytes"]? || (prefix == "cr" ? cm["crystal_debug_size_kb"]?.try(&.*(1024.0)) : (prefix == "cpp" ? cm["cpp_debug_size_kb"]?.try(&.*(1024.0)) : (prefix == "rs" ? cm["rust_debug_size_kb"]?.try(&.*(1024.0)) : cm["csharp_debug_size_kb"]?.try(&.*(1024.0)))))

            next if rel_ms <= 0.0 && (dbg_ms.nil? || dbg_ms <= 0.0)

            is_base = (tname == (baseline_name || "Crystal"))

            case mode
            when :size
              rel_kb = (rel_bytes / 1024.0).round(1)
              dbg_kb = dbg_bytes ? (dbg_bytes / 1024.0).round(1) : nil
              rows << ChartRow.new(
                label: tname,
                val1: rel_kb,
                val2: dbg_kb,
                unit: "KB",
                color1_start: c1_s,
                color1_end: c1_e,
                badge: "#{rel_kb} KB",
                is_baseline: is_base
              )
            when :debug_vs_release
              rows << ChartRow.new(
                label: tname,
                val1: rel_ms,
                val2: dbg_ms,
                unit: "ms",
                color1_start: c1_s,
                color1_end: c1_e,
                badge: "#{rel_ms.round(0).to_i} ms",
                is_baseline: is_base
              )
            when :speedup
              ratio = rel_ms > 0 ? (cr_rel / rel_ms).round(2) : 1.0
              rows << ChartRow.new(
                label: tname,
                val1: ratio,
                unit: "x",
                color1_start: c1_s,
                color1_end: c1_e,
                badge: is_base ? "Baseline" : "#{ratio}x build",
                is_baseline: is_base
              )
            else
              # :bar, :log, :ratio
              rows << ChartRow.new(
                label: tname,
                val1: rel_ms,
                unit: "ms",
                color1_start: c1_s,
                color1_end: c1_e,
                badge: "#{rel_ms.round(0).to_i} ms",
                is_baseline: is_base
              )
            end
          end
        end

        private def self.extract_multilang_rows(
          rows : Array(ChartRow),
          items : Array(BenchmarkMetric),
          mode : Symbol,
          baseline_name : String?
        ) : Nil
          first_m = items.first
          cr_ms = first_m.crystal_ms
          gd_ms = first_m.gdscript_ms

          targets = [
            {"Crystal", cr_ms, "#00D2FF", "#0077B6"},
            {"C++", first_m.cpp_ms, "#569CD6", "#2B6CB0"},
            {"Rust", first_m.rust_ms, "#DEA584", "#B85D32"},
            {"C#", first_m.csharp_ms, "#D2A8FF", "#8A5CF6"},
            {"GDScript", gd_ms > 0 ? gd_ms : nil, "#FF9900", "#CC5500"},
          ]

          base_val = case (baseline_name || "Crystal").downcase
                     when "gdscript" then (gd_ms > 0 ? gd_ms : cr_ms)
                     else                 cr_ms
                     end
          base_val = 0.001 if base_val <= 0.0

          targets.each do |(tname, ms_val, c_start, c_end)|
            next unless ms_val && ms_val > 0.0
            is_base = (tname.downcase == (baseline_name || "Crystal").downcase)

            case mode
            when :speedup
              # Speedup vs baseline: if baseline is Crystal or GDScript
              ref = (gd_ms > 0) ? gd_ms : base_val
              sp = (ms_val > 0) ? (ref / ms_val).round(1) : 1.0
              rows << ChartRow.new(
                label: tname,
                val1: sp,
                unit: "x",
                color1_start: c_start,
                color1_end: c_end,
                badge: is_base ? "#{sp}x (Base)" : "#{sp}x faster",
                is_baseline: is_base
              )
            when :ratio
              ratio = (ms_val / base_val).round(2)
              rows << ChartRow.new(
                label: tname,
                val1: ratio,
                unit: "x",
                color1_start: c_start,
                color1_end: c_end,
                badge: is_base ? "1.0x (Base)" : "#{ratio}x",
                is_baseline: is_base
              )
            else
              # :bar, :log
              sp_str = if gd_ms > 0 && ms_val > 0
                "#{(gd_ms / ms_val).round(1)}x"
              else
                "#{ms_val.round(2)} ms"
              end
              rows << ChartRow.new(
                label: tname,
                val1: ms_val,
                unit: "ms",
                color1_start: c_start,
                color1_end: c_end,
                badge: sp_str,
                is_baseline: is_base
              )
            end
          end
        end

        private def self.extract_throughput_rows(
          rows : Array(ChartRow),
          items : Array(BenchmarkMetric),
          mode : Symbol,
          baseline_name : String?
        ) : Nil
          items.each do |m|
            found_rate = m.custom_metrics.find { |k, _v| k.ends_with?("_per_sec") || k.ends_with?("_rate") }
            rate = found_rate ? found_rate.last : (1000.0 / [m.crystal_ms, 0.001].max)

            unit = "ops/s"
            val = rate
            badge_str = "#{val.round(0).to_i} ops/s"

            if mode == :bar && rate > 0
              rows << ChartRow.new(
                label: m.name,
                val1: val,
                unit: unit,
                color1_start: "#00D2FF",
                color1_end: "#0077B6",
                badge: badge_str,
                is_baseline: (m.name == baseline_name)
              )
            elsif mode == :speedup && m.gdscript_ms > 0
              rows << ChartRow.new(
                label: m.name,
                val1: m.speedup,
                unit: "x",
                color1_start: "#3FB950",
                color1_end: "#238636",
                badge: "#{m.speedup.round(1)}x faster",
                is_baseline: false
              )
            else
              rows << ChartRow.new(
                label: m.name,
                val1: val,
                unit: unit,
                color1_start: "#00D2FF",
                color1_end: "#0077B6",
                badge: badge_str,
                is_baseline: (m.name == baseline_name)
              )
            end
          end
        end

        private def self.extract_multi_item_rows(
          rows : Array(ChartRow),
          items : Array(BenchmarkMetric),
          mode : Symbol,
          baseline_name : String?
        ) : Nil
          items.each do |m|
            is_base = (m.name == baseline_name)
            label = m.subgroup ? "#{m.subgroup} / #{m.name}" : m.name

            c1_s = "#00D2FF"
            c1_e = "#0077B6"
            if sg = m.subgroup
              case sg.downcase
              when "crystaltogdscript", "crystal_to_gdscript", "cr_to_gd"
                c1_s = "#00D2FF"
                c1_e = "#0077B6"
              when "gdscripttocrystal", "gdscript_to_crystal", "gd_to_cr"
                c1_s = "#D2A8FF"
                c1_e = "#8A5CF6"
              else
                c1_s = "#569CD6"
                c1_e = "#2B6CB0"
              end
            end

            case mode
            when :speedup
              rows << ChartRow.new(
                label: label,
                val1: m.speedup,
                unit: "x",
                color1_start: "#3FB950",
                color1_end: "#238636",
                badge: m.gdscript_ms > 0 ? "#{m.speedup.round(1)}x faster" : "Native",
                is_baseline: is_base
              )
            when :ratio
              base_m = items.find { |i| i.name == baseline_name } || items.first
              base_time = [base_m.crystal_ms, 0.001].max
              ratio = (m.crystal_ms / base_time).round(2)
              rows << ChartRow.new(
                label: label,
                val1: ratio,
                unit: "x",
                color1_start: c1_s,
                color1_end: c1_e,
                badge: is_base ? "1.0x (Base)" : "#{ratio}x",
                is_baseline: is_base
              )
            else
              # :bar, :log
              gd = m.gdscript_ms > 0 ? m.gdscript_ms : nil
              rows << ChartRow.new(
                label: label,
                val1: m.crystal_ms,
                val2: gd,
                unit: "ms",
                color1_start: c1_s,
                color1_end: c1_e,
                color2_start: "#FF9900",
                color2_end: "#CC5500",
                badge: m.speedup > 1.0 ? "#{m.speedup.round(1)}x faster" : nil,
                is_baseline: is_base
              )
            end
          end
        end
      end
    end
  end
end
