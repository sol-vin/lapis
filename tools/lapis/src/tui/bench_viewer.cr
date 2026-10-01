# =============================================================================
# Lapis - Dynamic Benchmark Suite Visualizer (TUI)
# =============================================================================
# Interactive visualizer for Crystal vs GDScript/C++/C#/Rust performance benchmarks
# powered by Opal's BarChart, LineGraph, and PieChart components.
# Dynamically loads benchmark XML reports, provides an in-TUI file picker, and
# supports on-demand benchmark execution.
# =============================================================================

require "opal"
require "../core/env"
require "../core/logger"
require "../commands/benchmarks"
require "../commands/benchmarks/models"
require "../commands/benchmarks/xml_handler"

module Lapis
  module TUI
    class BenchViewer
      enum Tab
        LanguageComparison
        SpeedupOverview
        CategoryDistribution
        MultiRunTrend
        GroupComparison
      end

      getter? running : Bool = true
      property active_tab : Tab = Tab::LanguageComparison
      property selected_idx : Int32 = 0
      property chart_mode : Symbol = :bar
      property? choosing_file : Bool = false
      property current_xml_path : String = ""

      getter file_dialog : Opal::UI::FileDialog
      getter metadata : Hash(String, String) = Hash(String, String).new
      getter metrics : Array(Commands::Benchmarks::BenchmarkMetric) = [] of Commands::Benchmarks::BenchmarkMetric

      def initialize(initial_xml : String? = nil)
        reports_dir = Core::Env::ROOT_DIR.join("benchmarks/reports").to_s
        reports_dir = "." unless Dir.exists?(reports_dir)
        @file_dialog = Opal::UI::FileDialog.new(initial_path: reports_dir, mode: :open_file)

        if xml = initial_xml
          load_xml_file(xml)
        else
          auto_discover_latest_report
        end
      end

      def self.run(initial_xml : String? = nil) : Nil
        new(initial_xml).run
      end

      def run : Nil
        return unless STDOUT.tty?

        driver = Opal::Terminal.default_driver
        driver.raw_mode do
          driver.enter_alternate_screen
          driver.hide_cursor
          begin
            while @running
              render(driver)
              handle_input(driver)
            end
          ensure
            driver.show_cursor
            driver.exit_alternate_screen
          end
        end
      end

      # Dynamically finds and loads the newest XML report in benchmarks/reports/
      def auto_discover_latest_report : Nil
        reports_dir = Core::Env::ROOT_DIR.join("benchmarks/reports")
        if Dir.exists?(reports_dir)
          # Check for benchmarks_latest.xml first
          latest_file = reports_dir.join("benchmarks_latest.xml")
          if File.exists?(latest_file)
            load_xml_file(latest_file.to_s)
            return
          end

          # Otherwise pick newest .xml file
          xml_files = Dir.glob(reports_dir.join("*.xml").to_s.gsub('\\', '/'))
          if !xml_files.empty?
            newest = xml_files.max_by { |f| File.info(f).modification_time rescue Time.unix(0) }
            load_xml_file(newest)
            return
          end
        end

        # Fallback: synthesize metrics from catalog if no XML is found yet
        fallback_from_catalog
      end

      def load_xml_file(path : String) : Bool
        unless File.exists?(path)
          Core::Logger.error("Benchmark XML file does not exist: #{path}")
          return false
        end

        content = File.read(path) rescue nil
        return false unless content

        begin
          meta, loaded_metrics = Commands::Benchmarks::XmlHandler.parse_xml(content)
          @metadata = meta
          @metrics = loaded_metrics
          @current_xml_path = path
          @selected_idx = 0
          true
        rescue ex
          Core::Logger.error("Failed to parse benchmark XML #{path}: #{ex.message}")
          fallback_from_catalog
          false
        end
      end

      private def fallback_from_catalog
        @metadata = {
          "version"   => "0.0.1",
          "godot"     => "4.x",
          "platform"  => Core::Env.current_platform,
          "timestamp" => Time.utc.to_s,
        }
        @current_xml_path = "(Built-in Benchmark Catalog - Press 'R' to Execute)"
        @metrics = Commands::Benchmarks.builtin_benchmarks.map do |b|
          Commands::Benchmarks::BenchmarkMetric.new(
            name: b.name,
            category: b.category,
            crystal_ms: 10.0,
            gdscript_ms: 100.0,
            speedup: 10.0,
            description: b.description,
            group_name: b.group_name
          )
        end
        @selected_idx = 0
      end

      def render_to_buffer(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        if @choosing_file
          render_file_picker(buffer, width, height)
        else
          render_dashboard(buffer, width, height)
        end
      end

      private def render(driver : Opal::Terminal::Driver)
        w, h = driver.size
        width = Math.max(80, w)
        height = Math.max(24, h)
        buffer = Opal::UI::Buffer.new(width, height)
        render_to_buffer(buffer, width, height)

        driver.write(Opal::Terminal::Screen.move_to(1, 1))
        driver.write(buffer.render_to_string(with_ansi: true))
        driver.flush
      end

      private def render_file_picker(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        buffer.put_string(2, 1, "[XML] SELECT BENCHMARK XML REPORT", fg: Opal::Color.bright_cyan, bold: true)
        buffer.put_string(2, 2, "Use ↑/↓ to navigate, Enter to load XML report, Esc to cancel", fg: Opal::Color.bright_black)
        buffer.put_string(2, 3, "─" * (width - 4), fg: Opal::Color.bright_black)

        @file_dialog.render(buffer, 2, 4, width - 4, height - 7)

        y = height - 2
        buffer.put_string(2, y, "─" * (width - 4), fg: Opal::Color.bright_black)
        buffer.put_string(2, y + 1, "Enter: Open Selected File │ Esc: Cancel File Selection", fg: Opal::Color.yellow)
      end

      private def render_dashboard(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        # 1. Header Banner & Telemetry
        buffer.put_string(2, 1, ":: LAPIS BENCHMARK SUITE VISUALIZER ::", fg: Opal::Color.bright_magenta, bold: true)

        display_file = Path.new(@current_xml_path).basename
        buffer.put_string(40, 1, "│ Report: #{display_file}", fg: Opal::Color.bright_black)

        godot_ver = @metadata["godot"]? || "4.x"
        platform = @metadata["platform"]? || Core::Env.current_platform
        total_cases = @metrics.size

        sub_info = "Platform: #{platform} │ Godot: #{godot_ver} │ Total Cases: #{total_cases}"
        buffer.put_string(2, 2, sub_info, fg: Opal::Color.cyan)

        # Tabs
        tabs = [
          {Tab::LanguageComparison, "[ 1: Multi-Language Bar ]"},
          {Tab::SpeedupOverview, "[ 2: Top Speedups ]"},
          {Tab::CategoryDistribution, "[ 3: Category Donut ]"},
          {Tab::MultiRunTrend, "[ 4: Latency Curves ]"},
          {Tab::GroupComparison, "[ 5: Comparison Groups ]"},
        ]

        tab_x = 2
        tabs.each do |tab_enum, title|
          selected = (tab_enum == @active_tab)
          fg = selected ? Opal::Color.bright_white : Opal::Color.bright_black
          bg = selected ? Opal::Color.hex("#3B4252") : Opal::Color.none
          buffer.put_string(tab_x, 3, title, fg: fg, bg: bg, bold: selected)
          tab_x += title.size + 2
        end

        buffer.put_string(2, 4, "─" * (width - 4), fg: Opal::Color.bright_black)

        # 2. Main Tab Viewport
        case @active_tab
        when Tab::LanguageComparison
          render_language_comparison(buffer, width, height)
        when Tab::SpeedupOverview
          render_speedup_overview(buffer, width, height)
        when Tab::CategoryDistribution
          render_category_distribution(buffer, width, height)
        when Tab::MultiRunTrend
          render_multi_run_trend(buffer, width, height)
        when Tab::GroupComparison
          render_group_comparison(buffer, width, height)
        end

        # 3. Footer Controls
        footer_y = height - 2
        buffer.put_string(2, footer_y - 1, "─" * (width - 4), fg: Opal::Color.bright_black)
        controls = "Tab: Switch Tab │ 1-5: Jump │ C: Chart Mode (#{@chart_mode.to_s.upcase}) │ ↑/↓: Select │ F: Pick XML │ R: Run │ Esc/Q: Back"
        buffer.put_string(2, footer_y, controls, fg: Opal::Color.bright_white)
      end

      private def render_language_comparison(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        return if @metrics.empty?
        m = @metrics[@selected_idx]? || @metrics.first

        cat_badge = "[ #{m.category.display_name} ]"
        buffer.put_string(2, 5, "Target Benchmark: #{m.name} #{cat_badge}", fg: Opal::Color.bright_yellow, bold: true)
        buffer.put_string(2, 6, "Description: #{m.description}", fg: Opal::Color.bright_black)

        chart_title = case @chart_mode
                      when :speedup then "Speedup vs GDScript 4.x (Higher is Better · Mode: SPEEDUP)"
                      when :ratio   then "Relative Latency Ratio vs Crystal 1.0x (Lower is Faster · Mode: RATIO)"
                      when :log     then "Log10 Execution Scale (ms · Mode: LOG)"
                      else               "Execution Time (ms - Lower is Faster · Mode: BAR)"
                      end

        chart = Opal::UI::BarChart.new(title: chart_title, bar_char: '█')

        base_ms = Math.max(0.001, m.crystal_ms)
        gd_ms = Math.max(0.001, m.gdscript_ms)

        case @chart_mode
        when :speedup
          chart.add("Crystal (Lapis)", m.speedup, :green, sprintf("%.1fx faster", m.speedup))
          if (cpp = m.cpp_ms) && cpp > 0.0
            chart.add("C++ (GDExtension)", gd_ms / cpp, :cyan, sprintf("%.1fx", gd_ms / cpp))
          end
          if (rs = m.rust_ms) && rs > 0.0
            chart.add("Rust (godot-rust)", gd_ms / rs, :blue, sprintf("%.1fx", gd_ms / rs))
          end
          if (cs = m.csharp_ms) && cs > 0.0
            chart.add("C# (Godot .NET)", gd_ms / cs, :magenta, sprintf("%.1fx", gd_ms / cs))
          end
          if m.gdscript_ms > 0.0
            chart.add("GDScript 4.x", 1.0, :yellow, "1.0x (Baseline)")
          end
        when :ratio
          chart.add("Crystal (Lapis)", 1.0, :green, "1.00x (Base)")
          if (cpp = m.cpp_ms) && cpp > 0.0
            chart.add("C++ (GDExtension)", cpp / base_ms, :cyan, sprintf("%.2fx", cpp / base_ms))
          end
          if (rs = m.rust_ms) && rs > 0.0
            chart.add("Rust (godot-rust)", rs / base_ms, :blue, sprintf("%.2fx", rs / base_ms))
          end
          if (cs = m.csharp_ms) && cs > 0.0
            chart.add("C# (Godot .NET)", cs / base_ms, :magenta, sprintf("%.2fx", cs / base_ms))
          end
          if m.gdscript_ms > 0.0
            chart.add("GDScript 4.x", gd_ms / base_ms, :yellow, sprintf("%.2fx", gd_ms / base_ms))
          end
        when :log
          chart.add("Crystal (Lapis)", Math.log10(base_ms + 0.1) + 2.0, :green, sprintf("%.2f ms", m.crystal_ms))
          if (cpp = m.cpp_ms) && cpp > 0.0
            chart.add("C++ (GDExtension)", Math.log10(cpp + 0.1) + 2.0, :cyan, sprintf("%.2f ms", cpp))
          end
          if (rs = m.rust_ms) && rs > 0.0
            chart.add("Rust (godot-rust)", Math.log10(rs + 0.1) + 2.0, :blue, sprintf("%.2f ms", rs))
          end
          if (cs = m.csharp_ms) && cs > 0.0
            chart.add("C# (Godot .NET)", Math.log10(cs + 0.1) + 2.0, :magenta, sprintf("%.2f ms", cs))
          end
          if m.gdscript_ms > 0.0
            chart.add("GDScript 4.x", Math.log10(gd_ms + 0.1) + 2.0, :yellow, sprintf("%.2f ms", m.gdscript_ms))
          end
        else
          # :bar mode
          chart.add("Crystal (Lapis)", m.crystal_ms, :green, sprintf("%.2f ms (1.0x)", m.crystal_ms))
          if (cpp = m.cpp_ms) && cpp > 0.0
            ratio = cpp / base_ms
            chart.add("C++ (GDExtension)", cpp, :cyan, sprintf("%.2f ms (%.2fx)", cpp, ratio))
          end
          if (rs = m.rust_ms) && rs > 0.0
            ratio = rs / base_ms
            chart.add("Rust (godot-rust)", rs, :blue, sprintf("%.2f ms (%.2fx)", rs, ratio))
          end
          if (cs = m.csharp_ms) && cs > 0.0
            ratio = cs / base_ms
            chart.add("C# (Godot .NET)", cs, :magenta, sprintf("%.2f ms (%.2fx)", cs, ratio))
          end
          if m.gdscript_ms > 0.0
            chart.add("GDScript 4.x", m.gdscript_ms, :yellow, sprintf("%.2f ms (%.2fx)", m.gdscript_ms, m.speedup))
          end
        end

        chart_w = Math.min(width - 6, 80)
        chart_h = Math.min(10, height - 14)
        chart.render(buffer, 2, 8, chart_w, chart_h)

        # Benchmark Selector List
        sel_y = 8 + chart_h + 1
        buffer.put_string(2, sel_y, "Registered Benchmarks (Use ↑ / ↓ to switch):", fg: Opal::Color.cyan, bold: true)
        max_show = height - sel_y - 4
        start_idx = Math.max(0, @selected_idx - (max_show // 2))

        @metrics[start_idx, max_show]?.try &.each_with_index do |item, offset|
          idx = start_idx + offset
          row_y = sel_y + 1 + offset
          selected = (idx == @selected_idx)
          prefix = selected ? " ► " : "   "
          fg = selected ? Opal::Color.bright_white : Opal::Color.bright_black
          bg = selected ? Opal::Color.hex("#2A2B3D") : Opal::Color.none

          speed_str = item.speedup > 1.0 ? sprintf(" [%.1fx speedup]", item.speedup) : ""
          buffer.put_string(2, row_y, "#{prefix}[#{idx + 1}] #{item.name}#{speed_str}", fg: fg, bg: bg, bold: selected)
        end
      end

      private def render_speedup_overview(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        buffer.put_string(2, 5, "Overall Crystal vs GDScript Speedup Ratios (Sorted Descending)", fg: Opal::Color.bright_yellow, bold: true)

        chart = Opal::UI::BarChart.new(title: "Speedup Factor (Higher is Better)")
        sorted = @metrics.select { |m| m.speedup > 0.0 }.sort_by(&.speedup).reverse

        max_items = Math.min(12, height - 10)
        sorted[0, max_items].each do |m|
          col = m.speedup >= 15.0 ? :green : (m.speedup >= 5.0 ? :cyan : :yellow)
          chart.add(m.name, m.speedup, col, sprintf("%.1fx", m.speedup))
        end

        chart_w = Math.min(width - 6, 80)
        chart_h = Math.min(height - 8, sorted.size + 4)
        chart.render(buffer, 2, 7, chart_w, chart_h)
      end

      private def render_category_distribution(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        buffer.put_string(2, 5, "Total Cumulative Execution Time by Benchmark Category", fg: Opal::Color.bright_yellow, bold: true)

        pie = Opal::UI::PieChart.new(title: "Execution Time by Category (ms)", donut: true)

        cat_groups = @metrics.group_by(&.category)
        cat_groups.each do |cat, items|
          total_ms = items.sum(&.crystal_ms)
          if total_ms > 0.0
            col = case cat
                  when Commands::Benchmarks::Category::Compute    then :green
                  when Commands::Benchmarks::Category::EngineCore then :cyan
                  when Commands::Benchmarks::Category::Toolchain  then :magenta
                  else                                                 :yellow
                  end
            pie.add(cat.display_name, total_ms, col, sprintf("%.1f ms", total_ms))
          end
        end

        pie_w = Math.min(width - 6, 80)
        pie_h = Math.min(height - 9, 14)
        pie.render(buffer, 2, 7, pie_w, pie_h)
      end

      private def render_multi_run_trend(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        buffer.put_string(2, 5, "Multi-Sample Latency Distribution Across Registered Suites", fg: Opal::Color.bright_yellow, bold: true)

        line_graph = Opal::UI::LineGraph.new(title: "Benchmark Case Latency (ms)")
        cr_samples = @metrics.map(&.crystal_ms)
        gd_samples = @metrics.map { |m| Math.min(m.gdscript_ms, 200.0) }

        line_graph.add_series("Crystal (ms)", cr_samples, :green)
        line_graph.add_series("GDScript (clamped 200ms)", gd_samples, :yellow)

        graph_w = Math.min(width - 6, 80)
        graph_h = Math.min(height - 9, 14)
        line_graph.render(buffer, 2, 7, graph_w, graph_h)
      end

      private def render_group_comparison(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        grouped = @metrics.group_by(&.group_name).reject { |k, v| k.nil? || k.empty? }
        if grouped.empty?
          buffer.put_string(2, 5, "No benchmark comparison groups found in current XML report.", fg: Opal::Color.bright_black)
          return
        end

        grp_names = grouped.keys.compact
        g_idx = @selected_idx.clamp(0, grp_names.size - 1)
        curr_grp_name = grp_names[g_idx]
        grp_items = grouped[curr_grp_name]
        first_m = grp_items.first

        cat_badge = "[ #{first_m.category.display_name} ]"
        chart_mode_str = @chart_mode.to_s.upcase
        buffer.put_string(2, 5, "Comparison Group: #{curr_grp_name} #{cat_badge} · Mode: #{chart_mode_str} (Press 'C' to Cycle)", fg: Opal::Color.bright_yellow, bold: true)
        buffer.put_string(2, 6, "Description: #{first_m.description} · Baseline: #{first_m.baseline_name || "Crystal"}", fg: Opal::Color.bright_black)

        # BarChart using SvgGenerator.extract_chart_rows
        chart_rows = Commands::Benchmarks::SvgGenerator.extract_chart_rows(
          grp_items,
          @chart_mode,
          baseline_name: first_m.baseline_name,
          kind: first_m.group_kind
        )

        barchart = Opal::UI::BarChart.new(title: "Group Targets Performance")
        chart_rows.each do |r|
          badge_str = r.badge || "#{r.val1.round(2)} #{r.unit}"
          col = r.is_baseline ? :cyan : (r.val1 >= 5.0 ? :green : :yellow)
          barchart.add(r.label, r.val1, col, badge_str)
        end

        chart_w = Math.min(width - 6, 80)
        chart_h = Math.min(10, height - 16)
        barchart.render(buffer, 2, 8, chart_w, chart_h)

        # Group Selector List
        sel_y = 8 + chart_h + 1
        buffer.put_string(2, sel_y, "Comparison Groups (Use ↑ / ↓ to switch):", fg: Opal::Color.cyan, bold: true)
        max_show = height - sel_y - 4
        start_idx = Math.max(0, g_idx - (max_show // 2))

        grp_names[start_idx, max_show]?.try &.each_with_index do |name, offset|
          idx = start_idx + offset
          row_y = sel_y + 1 + offset
          selected = (idx == g_idx)
          prefix = selected ? " ► " : "   "
          fg = selected ? Opal::Color.bright_white : Opal::Color.bright_black
          bg = selected ? Opal::Color.hex("#2A2B3D") : Opal::Color.none

          item_count = grouped[name]?.try(&.size) || 0
          buffer.put_string(2, row_y, "#{prefix}[#{idx + 1}] #{name} (#{item_count} benchmarks)", fg: fg, bg: bg, bold: selected)
        end
      end

      private def handle_input(driver : Opal::Terminal::Driver)
        ev = driver.read_event
        return unless ev.is_a?(Opal::Terminal::KeyEvent)

        # Global command palette shortcut
        if ev.char == '~' || ev.char == '`' || ev.matches?("ctrl+p")
          @running = false
          return
        end

        # If user is in file picker mode
        if @choosing_file
          handle_file_dialog_input(ev)
          return
        end

        case ev.name
        when "escape", "esc"
          @running = false
        when "tab"
          @active_tab = case @active_tab
                        when Tab::LanguageComparison   then Tab::SpeedupOverview
                        when Tab::SpeedupOverview      then Tab::CategoryDistribution
                        when Tab::CategoryDistribution then Tab::MultiRunTrend
                        when Tab::MultiRunTrend        then Tab::GroupComparison
                        else                                Tab::LanguageComparison
                        end
        when "up"
          @selected_idx = Math.max(0, @selected_idx - 1)
        when "down"
          @selected_idx = Math.min(@metrics.size - 1, @selected_idx + 1)
        else
          if ch = ev.char
            case ch
            when 'q', 'Q'
              @running = false
            when '1'
              @active_tab = Tab::LanguageComparison
            when '2'
              @active_tab = Tab::SpeedupOverview
            when '3'
              @active_tab = Tab::CategoryDistribution
            when '4'
              @active_tab = Tab::MultiRunTrend
            when '5'
              @active_tab = Tab::GroupComparison
            when 'c', 'C'
              modes = [:bar, :speedup, :ratio, :log]
              curr_idx = modes.index(@chart_mode) || 0
              @chart_mode = modes[(curr_idx + 1) % modes.size]
            when 'f', 'F', 'o', 'O'
              @choosing_file = true
            when 'r', 'R'
              execute_live_benchmark
            end
          end
        end
      end

      private def handle_file_dialog_input(ev : Opal::Terminal::KeyEvent)
        if ev.matches?("escape")
          @choosing_file = false
          return
        end

        if @file_dialog.handle_key(ev)
          if @file_dialog.confirmed?
            if chosen = @file_dialog.selected_path
              load_xml_file(chosen)
            end
            @choosing_file = false
          end
        end
      end

      private def execute_live_benchmark
        Opal::Terminal.default_driver.exit_alternate_screen
        puts Opal.style.bold.fg(:cyan).render("\n=== Executing Live Benchmark Suite (XML Generation) ===\n")

        Commands::Benchmarks.run([] of String)

        puts "\n\e[33mReloading updated benchmark XML report...\e[0m"
        auto_discover_latest_report
        puts "\e[32mSuccessfully updated metrics! Press Enter to return to visualizer...\e[0m"
        STDIN.gets

        Opal::Terminal.default_driver.enter_alternate_screen
      end
    end
  end
end
