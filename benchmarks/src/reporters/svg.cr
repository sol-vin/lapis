require "file_utils"
require "./base"

module Benchmarks
  module Reporters
    class Svg < Base
      property output_rel_path : String = "results/benchmark_chart.svg"

      def name : String
        "svg"
      end

      def initialize(@output_rel_path : String = "results/benchmark_chart.svg")
      end

      def self.generate_svg(results : Array(BenchmarkResult)) : String
        new.generate_svg(results)
      end

      def generate_svg(results : Array(BenchmarkResult)) : String
        return "" if results.empty?
        metrics = results.map(&.to_metric)
        has_editor = metrics.any? { |m| m.editor_ms }

        svg_width = 1040
        bar_height = has_editor ? 12 : 14
        group_spacing = has_editor ? 70 : 58
        margin_top = 85
        margin_left = 175
        margin_right = 245
        chart_width = svg_width - margin_left - margin_right
        svg_height = margin_top + (metrics.size * group_spacing) + 40

        badge_width = 92
        badge_height = 24
        badge_x = svg_width - badge_width - 25

        String.build do |io|
          io << %(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{svg_width} #{svg_height}" width="#{svg_width}" height="#{svg_height}">\n)
          io << %(  <defs>\n)
          io << %(    <linearGradient id="crGrad" x1="0%" y1="0%" x2="100%" y2="0%">\n)
          io << %(      <stop offset="0%" stop-color="#00D2FF"/>\n)
          io << %(      <stop offset="100%" stop-color="#0077B6"/>\n)
          io << %(    </linearGradient>\n)
          io << %(    <linearGradient id="edGrad" x1="0%" y1="0%" x2="100%" y2="0%">\n)
          io << %(      <stop offset="0%" stop-color="#D2A8FF"/>\n)
          io << %(      <stop offset="100%" stop-color="#A371F7"/>\n)
          io << %(    </linearGradient>\n)
          io << %(    <linearGradient id="gdGrad" x1="0%" y1="0%" x2="100%" y2="0%">\n)
          io << %(      <stop offset="0%" stop-color="#FF9900"/>\n)
          io << %(      <stop offset="100%" stop-color="#CC5500"/>\n)
          io << %(    </linearGradient>\n)
          io << %(    <filter id="shadow" x="-5%" y="-5%" width="110%" height="110%">\n)
          io << %(      <feDropShadow dx="0" dy="2" stdDeviation="2" flood-color="#000000" flood-opacity="0.35"/>\n)
          io << %(    </filter>\n)
          io << %(  </defs>\n\n)

          # Background
          io << %(  <rect width="#{svg_width}" height="#{svg_height}" rx="12" fill="#0D1117"/>\n)
          io << %(  <rect width="#{svg_width}" height="#{svg_height}" rx="12" fill="none" stroke="#30363D" stroke-width="1.5"/>\n)

          # Title
          io << %(  <text x="32" y="40" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif" font-size="20" font-weight="bold" fill="#F0F3F6">Lapis Benchmark Suite: Performance Comparison</text>\n)
          subtitle = has_editor ?
            "Execution time in milliseconds (shorter is faster) · Crystal Native vs GDScript Standalone & In-Editor" :
            "Execution time in milliseconds (shorter is faster) · Release -O3 vs Headless Godot 4.8"
          io << %(  <text x="32" y="60" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif" font-size="12" fill="#8B949E">#{subtitle}</text>\n)

          # Legend
          if has_editor
            io << %(  <rect x="#{svg_width - 410}" y="32" width="12" height="12" rx="3" fill="url(#crGrad)" />\n)
            io << %(  <text x="#{svg_width - 392}" y="43" font-family="sans-serif" font-size="11" font-weight="600" fill="#E6EDF3">Crystal (Native)</text>\n)
            io << %(  <rect x="#{svg_width - 280}" y="32" width="12" height="12" rx="3" fill="url(#gdGrad)" />\n)
            io << %(  <text x="#{svg_width - 262}" y="43" font-family="sans-serif" font-size="11" font-weight="600" fill="#E6EDF3">GDScript (Standalone)</text>\n)
            io << %(  <rect x="#{svg_width - 130}" y="32" width="12" height="12" rx="3" fill="url(#edGrad)" />\n)
            io << %(  <text x="#{svg_width - 112}" y="43" font-family="sans-serif" font-size="11" font-weight="600" fill="#E6EDF3">GDScript (Editor)</text>\n)
          else
            io << %(  <rect x="#{svg_width - 240}" y="32" width="14" height="14" rx="3" fill="url(#crGrad)" />\n)
            io << %(  <text x="#{svg_width - 220}" y="44" font-family="sans-serif" font-size="12" font-weight="600" fill="#E6EDF3">Crystal</text>\n)
            io << %(  <rect x="#{svg_width - 130}" y="32" width="14" height="14" rx="3" fill="url(#gdGrad)" />\n)
            io << %(  <text x="#{svg_width - 110}" y="44" font-family="sans-serif" font-size="12" font-weight="600" fill="#E6EDF3">GDScript</text>\n)
          end

          metrics.each_with_index do |m, idx|
            group_y = margin_top + (idx * group_spacing)
            max_time = [m.crystal_ms, m.gdscript_ms, m.editor_ms || 0.0].max
            max_time = 0.001 if max_time == 0.0

            cr_w = [4, ((m.crystal_ms / max_time) * chart_width).round.to_i].max
            gd_w = [4, ((m.gdscript_ms / max_time) * chart_width).round.to_i].max

            if has_editor
              ed_time = m.editor_ms || m.gdscript_ms
              ed_w = [4, ((ed_time / max_time) * chart_width).round.to_i].max

              # Label
              io << %(  <text x="#{margin_left - 15}" y="#{group_y + 26}" text-anchor="end" font-family="sans-serif" font-size="13" font-weight="bold" fill="#F0F3F6">#{m.name}</text>\n)

              # Background tracks
              io << %(  <rect x="#{margin_left}" y="#{group_y}" width="#{chart_width}" height="#{bar_height}" rx="3" fill="#21262D"/>\n)
              io << %(  <rect x="#{margin_left}" y="#{group_y + 16}" width="#{chart_width}" height="#{bar_height}" rx="3" fill="#21262D"/>\n)
              io << %(  <rect x="#{margin_left}" y="#{group_y + 32}" width="#{chart_width}" height="#{bar_height}" rx="3" fill="#21262D"/>\n)

              # Crystal Native bar
              io << %(  <rect x="#{margin_left}" y="#{group_y}" width="#{cr_w}" height="#{bar_height}" rx="3" fill="url(#crGrad)" filter="url(#shadow)"/>\n)
              io << %(  <text x="#{margin_left + cr_w + 8}" y="#{group_y + 10}" font-family="sans-serif" font-size="11" font-weight="bold" fill="#00D2FF">#{m.crystal_ms.round(1)} ms</text>\n)

              # GDScript Standalone bar
              io << %(  <rect x="#{margin_left}" y="#{group_y + 16}" width="#{gd_w}" height="#{bar_height}" rx="3" fill="url(#gdGrad)" filter="url(#shadow)"/>\n)
              io << %(  <text x="#{margin_left + gd_w + 8}" y="#{group_y + 26}" font-family="sans-serif" font-size="11" font-weight="bold" fill="#FF9900">#{m.gdscript_ms.round(1)} ms</text>\n)

              # GDScript In-Editor bar
              io << %(  <rect x="#{margin_left}" y="#{group_y + 32}" width="#{ed_w}" height="#{bar_height}" rx="3" fill="url(#edGrad)" filter="url(#shadow)"/>\n)
              io << %(  <text x="#{margin_left + ed_w + 8}" y="#{group_y + 42}" font-family="sans-serif" font-size="11" font-weight="bold" fill="#D2A8FF">#{ed_time.round(1)} ms</text>\n)

              # Speedup badge
              badge_text = "%.1fx" % m.speedup
              badge_y = group_y + 14
              io << %(  <rect x="#{badge_x}" y="#{badge_y}" width="#{badge_width}" height="#{badge_height}" rx="12" fill="#238636" opacity="0.95"/>\n)
              io << %(  <text x="#{badge_x + (badge_width / 2)}" y="#{badge_y + 16}" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="bold" fill="#FFFFFF">#{badge_text} faster</text>\n)
            else
              # Label
              io << %(  <text x="#{margin_left - 15}" y="#{group_y + 22}" text-anchor="end" font-family="sans-serif" font-size="13" font-weight="bold" fill="#F0F3F6">#{m.name}</text>\n)

              # Background tracks
              io << %(  <rect x="#{margin_left}" y="#{group_y}" width="#{chart_width}" height="#{bar_height}" rx="4" fill="#21262D"/>\n)
              io << %(  <rect x="#{margin_left}" y="#{group_y + 18}" width="#{chart_width}" height="#{bar_height}" rx="4" fill="#21262D"/>\n)

              # Crystal bar
              io << %(  <rect x="#{margin_left}" y="#{group_y}" width="#{cr_w}" height="#{bar_height}" rx="4" fill="url(#crGrad)" filter="url(#shadow)"/>\n)
              io << %(  <text x="#{margin_left + cr_w + 8}" y="#{group_y + 11}" font-family="sans-serif" font-size="11" font-weight="bold" fill="#00D2FF">#{m.crystal_ms.round(1)} ms</text>\n)

              # GDScript bar
              io << %(  <rect x="#{margin_left}" y="#{group_y + 18}" width="#{gd_w}" height="#{bar_height}" rx="4" fill="url(#gdGrad)" filter="url(#shadow)"/>\n)
              io << %(  <text x="#{margin_left + gd_w + 8}" y="#{group_y + 29}" font-family="sans-serif" font-size="11" font-weight="bold" fill="#FF9900">#{m.gdscript_ms.round(1)} ms</text>\n)

              # Speedup badge
              badge_text = "%.1fx" % m.speedup
              badge_y = group_y + 8
              io << %(  <rect x="#{badge_x}" y="#{badge_y}" width="#{badge_width}" height="#{badge_height}" rx="12" fill="#238636" opacity="0.95"/>\n)
              io << %(  <text x="#{badge_x + (badge_width / 2)}" y="#{badge_y + 16}" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="bold" fill="#FFFFFF">#{badge_text} faster</text>\n)
            end
          end

          io << %(</svg>\n)
        end
      end

      def report(results : Array(BenchmarkResult), base_dir : String) : Nil
        return if results.empty?
        svg = generate_svg(results)
        out_path = File.join(base_dir, @output_rel_path)
        FileUtils.mkdir_p(File.dirname(out_path))
        File.write(out_path, svg)
        puts "  \e[32m[Chart]\e[0m Saved SVG visual bar chart to: #{out_path}"
      end
    end
  end
end
