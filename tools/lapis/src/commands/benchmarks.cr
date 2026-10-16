require "option_parser"
require "file_utils"
require "../core/env"
require "../core/logger"
require "../core/godot_finder"
require "../tui/tui"
require "opal"

require "./benchmarks/models"
require "./benchmarks/xml_handler"
require "./benchmarks/svg_generator"
require "./benchmarks/html_generator"
require "./benchmarks/catalog"
require "./benchmarks/executor"
require "./benchmarks/history"

module Lapis
  module Commands
    module Benchmarks
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
  -c, --category=CAT    Filter by category ('compute', 'engine', 'toolchain', 'custom')
  -g, --group=GROUP     Run only benchmarks within the specified comparison group
  -e, --env=ENV         Execution environment: 'standalone', 'editor', 'all' (default: standalone)
  -t, --tag=TAG         Target release tag (e.g. '4.8-dev7')
  --previous-tag=TAG    Previous baseline release tag (e.g. '4.8-dev6')
  -o, --output=PATH     Explicit output file or directory path
  --from=PATH           Input XML file for 'export html'
  --current=PATH        Current benchmark XML file for comparison
  --previous=PATH       Previous benchmark XML file for comparison
  --format=FORMATS      Comma-separated outputs: console,html,xml,svg,json,csv (default: all)
  --all-languages       Run benchmarks across all languages (Crystal, GDScript, C++, C#, Rust)
  --no-language-tests   Explicitly disable foreign language benchmark targets
  --ci                  Enable CI environment mode (runs multi-language tests automatically)
  --languages=LANGS     Comma-separated languages to execute (crystal,gdscript,cpp,csharp,rust)
  --tui                 Launch interactive terminal dashboard (TUI)
  --no-tui              Disable interactive terminal dashboard
  --no-release          Compile benchmarks in debug mode (default: release -O3)
  -l, --list            List all registered benchmarks and exit
  -L, --list-groups     List all registered comparison groups and exit
  -h, --help            Show this help screen

Examples:
  lapis benchmarks
  lapis benchmarks -g MatrixMultiplication
  lapis benchmarks -g CompileTime
  lapis benchmarks -g Shaders
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

        if subcmd == "tui"
          TUI::BenchViewer.run
          return 0
        end

        iterations = 3
        filter = ""
        category_filter : Category? = nil
        group_filter : String? = nil
        env_mode = "standalone"
        release_build = true
        from_file : String? = nil
        output_path : String? = nil
        current_xml_path : String? = nil
        prev_xml_path : String? = nil
        cli_tag : String? = nil
        cli_prev_tag : String? = nil
        cli_native = false
        cli_comparative = false
        cli_github : String? = nil
        force_html = false
        use_tui = false
        no_tui = false
        requested_formats = ["console", "html", "xml", "svg", "json", "csv"]
        is_ci_env = ENV["CI"]? == "true" || ENV["GITHUB_ACTIONS"]? == "true"
        run_foreign_languages = is_ci_env
        requested_languages : Set(String)? = nil

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

        proj_path : String? = nil
        list_benchmarks = false
        list_groups = false

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis benchmarks [command] [options]"
          opts.on("-p PATH", "--path=PATH", "Target project directory (default: current directory)") { |p| proj_path = p }
          opts.on("-i N", "--iterations=N", "Number of iterations") { |n| iterations = n.to_i? || 3 }
          opts.on("-f NAME", "--filter=NAME", "Filter by benchmark name") { |f| filter = f.downcase }
          opts.on("-c CAT", "--category=CAT", "Filter by category ('compute', 'engine', 'toolchain', 'custom')") do |cat|
            category_filter = Category.parse_str(cat)
          end
          opts.on("-g GROUP", "--group=GROUP", "Filter by comparison group name") { |g| group_filter = g }
          opts.on("-e ENV", "--env=ENV", "Environment (standalone, editor, all)") { |e| env_mode = e.downcase }
          opts.on("-t TAG", "--tag=TAG", "Target release tag (e.g. '4.8-dev6')") { |t| cli_tag = t }
          opts.on("--previous-tag=TAG", "Previous baseline release tag (e.g. '4.8-dev5')") { |pt| cli_prev_tag = pt }
          opts.on("--native", "Force pure native performance benchmark mode") { cli_native = true }
          opts.on("--comparative", "Force comparative (Crystal vs GDScript) benchmark mode") { cli_comparative = true }
          opts.on("--github=REPO", "Target GitHub repository (owner/name) for baseline discovery") { |gh| cli_github = gh }
          opts.on("-o PATH", "--output=PATH", "Output file or directory") { |o| output_path = o }
          opts.on("--from=PATH", "Input XML file for export") { |fr| from_file = fr }
          opts.on("--current=PATH", "Current benchmark XML for comparison") { |cur| current_xml_path = cur }
          opts.on("--previous=PATH", "Previous benchmark XML for comparison") { |prv| prev_xml_path = prv }
          opts.on("--format=FORMATS", "Output formats") do |fmt|
            requested_formats = fmt.split(",").map(&.strip.downcase).reject(&.empty?)
          end
          opts.on("--all-languages", "Run benchmarks across all supported languages (Crystal, GDScript, C++, C#, Rust)") { run_foreign_languages = true }
          opts.on("--no-language-tests", "Explicitly disable foreign language benchmark targets") { run_foreign_languages = false; is_ci_env = false }
          opts.on("--ci", "Run in CI mode with all language benchmarks enabled") { is_ci_env = true; run_foreign_languages = true }
          opts.on("--languages=LANGS", "Comma-separated languages to execute (crystal,gdscript,cpp,csharp,rust)") do |langs|
            langs_set = Set.new(langs.split(',').map(&.strip.downcase).reject(&.empty?))
            requested_languages = langs_set
            run_foreign_languages = true if langs_set.any? { |l| ["cpp", "c++", "csharp", "c#", "rust"].includes?(l) }
          end
          opts.on("--tui", "Enable interactive terminal dashboard") { use_tui = true }
          opts.on("--no-tui", "Disable interactive terminal dashboard") { no_tui = true }
          opts.on("--no-release", "Compile in debug mode") { release_build = false }
          opts.on("-l", "--list", "List benchmarks and exit") { list_benchmarks = true }
          opts.on("-L", "--list-groups", "List comparison groups and exit") { list_groups = true }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
        end

        parser.parse(remaining)

        root = Core::Env::ROOT_DIR
        target_dir = ((pp = proj_path) ? Path.new(pp) : Path.new(Dir.current)).expand

        unless Core::Env.is_crystal_dir?(target_dir)
          Core::Logger.warn("Warning: Directory '#{target_dir}' is not a Crystal/Lapis project (missing shard.yml or src/).")
        end

        benchmarks_dir = if Dir.exists?(target_dir.join("benchmarks"))
                           target_dir.join("benchmarks")
                         elsif Dir.exists?(root.join("benchmarks")) && proj_path.nil? && Core::Env.is_libgodot_repo?(root)
                           root.join("benchmarks")
                         else
                           target_dir.join("benchmarks")
                         end

        unless Dir.exists?(benchmarks_dir)
          Core::Logger.warn("Warning: No 'benchmarks/' directory found in '#{target_dir}'.")
          Core::Logger.info("Tip: Benchmarks must be executed from a project containing a 'benchmarks/' suite.")
          return 1
        end

        if list_groups
          groups = discover_groups(benchmarks_dir)
          puts "\nRegistered Comparison Groups (#{groups.size} total):"
          groups.each do |g|
            puts "  %-24s [%-10s] Baseline: %-12s Targets: [%s]" % [
              g.name,
              g.category.display_name,
              g.baseline,
              g.target_names.join(", "),
            ]
            puts "    \e[2m#{g.description}\e[0m"
          end
          return 0
        end

        if list_benchmarks
          cases = discover_benchmarks(benchmarks_dir)
          puts "\nRegistered Benchmarks in #{benchmarks_dir} (#{cases.size} total):"
          cases.each do |b|
            grp_badge = b.group_name ? "(Group: #{b.group_name})" : ""
            puts "  %-18s [%-10s] %-20s %s" % [b.name, b.category.display_name, grp_badge, b.description]
          end
          return 0
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
          is_native = cli_native || (!cli_comparative && (meta["mode"]? == "native" || metrics.all? { |m| m.gdscript_ms <= 0.0 }))
          html_content = HtmlGenerator.generate_report(metrics, ver, plat, godot_ver, native_mode: is_native)

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
              prev_content = fetch_remote_baseline(version: prev_tag, tag: prev_tag, github_repo: cli_github)
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

          comp_project_name = "Lapis"
          shard_path = File.exists?(target_dir.join("shard.yml")) ? target_dir.join("shard.yml") : root.join("shard.yml")
          if File.exists?(shard_path)
            shard_content = File.read(shard_path)
            if nm = shard_content.match(/^name:\s*([a-zA-Z0-9_\-]+)/m)
              raw_name = nm[1].strip
              comp_project_name = case raw_name.downcase
              when "crshader" then "CRShader"
              when "libgodot", "lapis" then "Lapis"
              else raw_name.capitalize
              end
            end
          end

          is_native_mode = cli_native || (!cli_comparative && (
            (curr_meta["mode"]? == "native") ||
            (curr_metrics.all? { |m| m.gdscript_ms <= 0.0 })
          ))

          if is_compare_html
            diff_html = HtmlGenerator.generate_comparison_html(
              curr_metrics,
              prev_metrics,
              curr_version,
              prev_version,
              curr_tag: curr_tag,
              prev_tag: prev_tag,
              project_name: comp_project_name,
              native_mode: is_native_mode
            )
            out_file = if op = output_path
                         Path.new(op).expand
                       else
                         reports_dir.join("comparison_#{diff_label_prev}_to_#{diff_label_curr}.html")
                       end
            FileUtils.mkdir_p(out_file.parent) unless Dir.exists?(out_file.parent)
            File.write(out_file, diff_html)
            Core::Logger.success("Generated comparison HTML report at #{out_file}!")
          else
            diff_xml = XmlHandler.generate_comparison_xml(
              curr_metrics,
              prev_metrics,
              curr_version,
              prev_version,
              curr_tag: curr_tag,
              prev_tag: prev_tag,
              native_mode: is_native_mode
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
        if all_cases.empty?
          Core::Logger.info("No benchmarks found in #{benchmarks_dir}.")
          Core::Logger.info("To add benchmarks, create benchmark files under benchmarks/ (e.g. benchmarks/example_bench.cr).")
          return 0
        end

        target_cases = all_cases

        # Category Filter
        if cat = category_filter
          target_cases = target_cases.select { |b| b.category == cat }
        end

        # Group Filter
        if grp = group_filter
          target_cases = target_cases.select do |b|
            b.group_name && b.group_name.not_nil!.downcase == grp.downcase
          end
        end

        # Name / Description Filter
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
        godot_ver = Core::GodotFinder.expected_version(root.to_s)

        # Check TUI activation
        enable_tui = use_tui && !no_tui
        tui : TUI::Controller? = nil
        if enable_tui
          platform_str = Core::Env.windows? ? "Windows x86_64" : (Core::Env.macos? ? "macOS arm64" : "Linux x86_64")
          tui = TUI::Controller.new("Lapis Benchmark Suite", platform_str, godot_ver)
          target_cases.each do |b|
            tui.register_phase(b.name, "[BENCH:#{b.category.display_name.upcase}]", b.name, b.category.display_name)
          end
          tui.start
        else
          puts "\e[1;35m=== Lapis Benchmark Suite ===\e[0m"
          puts "  Directory:    #{benchmarks_dir}"
          puts "  Godot Binary: #{godot_exe || "(None found, running Crystal only)"}"
          puts "  Environment:  #{env_mode.capitalize}"
          puts "  Target Tag:   \e[1;36m#{curr_tag}\e[0m#{prev_tag ? " (comparing against \e[1;33m#{prev_tag}\e[0m)" : ""}"
          puts "  Iterations:   #{iterations}"
          puts "  Optimization: #{release_build ? "Release (-O3)" : "Debug"}"
          puts "  Benchmarks:   #{target_cases.size} selected"
          puts "  Group Filter: #{group_filter || "None (All Groups)"}" if group_filter
          puts "  Foreign Langs: #{run_foreign_languages ? "Enabled (C++, C#, Rust)" : "Disabled (local default; use --all-languages or run in CI)"}"
        end

        hooks_script = benchmarks_dir.join("hooks.cr")
        if File.exists?(hooks_script)
          hook_args = ["run", hooks_script.to_s, "--", "before_suite"]
          hook_args << "--ci" if is_ci_env
          hook_args << "--all-languages" if run_foreign_languages
          Core::ProcessRunner.run("crystal", hook_args, chdir: benchmarks_dir.to_s)
        end

        results = [] of BenchmarkResult

        target_cases.each_with_index do |bench, idx|
          phase_item = tui.try(&.state.phases[idx]?)
          if phase_item
            phase_item.status = TUI::PhaseStatus::Running
          end

          on_log_proc = if t = tui
                          Proc(String, Nil).new do |msg|
                            clean = msg.gsub(/\e\[[0-9;]*m/, "")
                            phase_item.try(&.add_log_line(clean))
                            t.state.global_logs << clean
                          end
                        else
                          nil
                        end

          start_t = ::Time.instant
          res = Executor.run_case(
            bench: bench,
            iterations: iterations,
            base_dir: benchmarks_dir,
            godot_exe: godot_exe,
            release: release_build,
            env_mode: env_mode,
            run_foreign_languages: run_foreign_languages,
            is_ci: is_ci_env,
            enabled_languages: requested_languages,
            on_log: on_log_proc
          )
          elapsed_sec = (::Time.instant - start_t).total_seconds

          if phase_item
            phase_item.duration = elapsed_sec
            if res
              phase_item.status = TUI::PhaseStatus::Passed
            else
              phase_item.status = TUI::PhaseStatus::Failed
            end
          end

          results << res if res
        end

        if File.exists?(hooks_script)
          Core::ProcessRunner.run("crystal", ["run", hooks_script.to_s, "--", "after_suite"], chdir: benchmarks_dir.to_s)
        end

        if t = tui
          t.stop(!results.empty?)
          t.dump_results
        end

        return 1 if results.empty?

        metrics = results.map(&.to_metric)

        # Determine project display name & version from shard.yml if available
        project_display_name = "Lapis"
        project_version = Lapis::VERSION
        shard_path = File.exists?(target_dir.join("shard.yml")) ? target_dir.join("shard.yml") : root.join("shard.yml")
        if File.exists?(shard_path)
          shard_content = File.read(shard_path)
          if nm = shard_content.match(/^name:\s*([a-zA-Z0-9_\-]+)/m)
            raw_name = nm[1].strip
            project_display_name = case raw_name.downcase
            when "crshader" then "CRShader"
            when "libgodot", "lapis" then "Lapis"
            else raw_name.capitalize
            end
          end
          if vm = shard_content.match(/^version:\s*([0-9a-zA-Z.\-]+)/m)
            project_version = vm[1].strip
          end
        end

        is_native_mode = cli_native || (!cli_comparative && metrics.all? { |m| m.gdscript_ms <= 0.0 })

        # 1. Output XML (history, tag and latest)
        xml_content = XmlHandler.generate_xml(metrics, project_version, godot_ver, iterations, platform_name, tag: curr_tag, native_mode: is_native_mode)
        ver_xml = reports_dir.join("benchmarks_#{project_version}.xml")
        tag_xml = reports_dir.join("benchmarks_#{curr_tag}.xml")
        latest_xml = reports_dir.join("benchmarks_latest.xml")
        File.write(ver_xml, xml_content)
        File.write(tag_xml, xml_content)
        File.write(latest_xml, xml_content)
        Core::Logger.success("Saved benchmark XML: #{tag_xml.basename} & #{latest_xml.basename}")

        # 2. Check for Previous Baseline & Automatically Generate Comparison Diff
        prev_speedup : Float64? = nil
        prev_total_latency : Float64? = nil
        if pt = prev_tag
          prev_baseline_content : String? = nil
          local_prev = reports_dir.join("benchmarks_#{pt}.xml")
          docs_prev = (Dir.exists?(target_dir.join("docs")) ? target_dir : root).join("docs/benchmarks/history/benchmarks_#{pt}.xml")
          if File.exists?(local_prev)
            prev_baseline_content = File.read(local_prev)
          elsif File.exists?(docs_prev)
            prev_baseline_content = File.read(docs_prev)
          else
            prev_baseline_content = fetch_remote_baseline(version: pt, tag: pt, github_repo: cli_github)
          end

          if prev_baseline_content
            begin
              prev_meta, prev_metrics = XmlHandler.parse_xml(prev_baseline_content)
              if is_native_mode
                prev_total_latency = prev_metrics.sum(&.crystal_ms)
              else
                p_speedups = prev_metrics.map(&.speedup).reject { |s| s <= 0.0 }
                prev_speedup = XmlHandler.calculate_geomean(p_speedups) unless p_speedups.empty?
              end

              diff_html = HtmlGenerator.generate_comparison_html(
                metrics,
                prev_metrics,
                project_version,
                prev_meta["version"]? || "baseline",
                curr_tag: curr_tag,
                prev_tag: pt,
                project_name: project_display_name,
                native_mode: is_native_mode
              )
              comp_file = reports_dir.join("comparison_#{pt}_to_#{curr_tag}.html")
              File.write(comp_file, diff_html)
              Core::Logger.success("Generated auto-comparison HTML: #{comp_file.basename}")

              diff_xml = XmlHandler.generate_comparison_xml(
                metrics,
                prev_metrics,
                project_version,
                prev_meta["version"]? || "baseline",
                curr_tag: curr_tag,
                prev_tag: pt,
                native_mode: is_native_mode
              )
              comp_xml_file = reports_dir.join("comparison_#{pt}_to_#{curr_tag}.xml")
              File.write(comp_xml_file, diff_xml)
            rescue ex
              Core::Logger.warn("Could not generate automatic comparison with #{pt}: #{ex.message}")
            end
          end
        end

        # 3. Scan History Across Reports & Docs
        history_dirs = [reports_dir]
        history_dirs << target_dir.join("docs/benchmarks/history") if Dir.exists?(target_dir.join("docs/benchmarks/history"))
        history_dirs << root.join("docs/benchmarks/history") if Dir.exists?(root.join("docs/benchmarks/history")) && target_dir == root
        history, comparisons = scan_history(history_dirs.uniq)

        # 4. Output HTML Reports
        html_content = HtmlGenerator.generate_report(
          metrics,
          project_version,
          platform_name,
          godot_ver,
          title: "#{project_display_name} Benchmark Suite: Performance Report",
          tag: curr_tag,
          history: history,
          comparisons: comparisons,
          prev_tag: prev_tag,
          prev_speedup: prev_speedup,
          prev_total_latency: prev_total_latency,
          project_name: project_display_name,
          native_mode: is_native_mode
        )
        html_file = reports_dir.join("benchmark_report.html")
        tag_html = reports_dir.join("report_#{curr_tag}.html")
        File.write(html_file, html_content)
        File.write(tag_html, html_content)
        File.write(reports_dir.join("benchmarks.html"), html_content)
        Core::Logger.success("Saved benchmark HTML reports: #{html_file.basename} & #{tag_html.basename}")

        # 5. Output SVG Chart
        svg_content = SvgGenerator.generate_svg(metrics, title: "#{project_display_name} Benchmark Suite: Performance #{is_native_mode ? "Metrics" : "Comparison"}", native_mode: is_native_mode)
        svg_file = reports_dir.join("benchmark_chart.svg")
        File.write(svg_file, svg_content)
        Core::Logger.success("Saved benchmark SVG chart: #{svg_file.basename}")

        # 6. Synchronize to docs/ and docs/benchmarks/ for GitHub Pages
        docs_target = Dir.exists?(target_dir.join("docs")) ? target_dir : root
        docs_bench = docs_target.join("docs/benchmarks")
        if Dir.exists?(docs_target.join("docs"))
          FileUtils.mkdir_p(docs_bench)
          FileUtils.mkdir_p(docs_bench.join("history"))

          File.write(docs_target.join("docs/benchmarks.html"), html_content)
          File.write(docs_target.join("docs/benchmark_report.html"), html_content)
          File.write(docs_bench.join("index.html"), html_content)
          File.write(docs_bench.join("benchmark_chart.svg"), svg_content)
          File.write(docs_bench.join("benchmarks_latest.xml"), xml_content)

          File.write(docs_bench.join("history/benchmarks_#{curr_tag}.xml"), xml_content)
          File.write(docs_bench.join("history/report_#{curr_tag}.html"), html_content)
          File.write(docs_bench.join("history/benchmarks_#{project_version}.xml"), xml_content)

          Dir.glob(reports_dir.to_s.gsub('\\', '/') + "/comparison_*").each do |cf|
            FileUtils.cp(cf, docs_bench.to_s)
            FileUtils.cp(cf, docs_bench.join("history").to_s)
          end

          Core::Logger.info("Synchronized benchmark reports and logs to #{docs_bench} for GitHub Pages.")
        end

        # Console Summary & Data Visualizations with Opal
        puts "\n\e[1;32m=== Benchmark Execution Complete ===\e[0m"
        puts "  Evaluated:       #{metrics.size} benchmark cases"
        if is_native_mode
          total_ms = metrics.sum(&.crystal_ms)
          avg_ms = metrics.empty? ? 0.0 : total_ms / metrics.size
          puts "  Total Duration:  \e[1;36m#{total_ms.round(2)} ms\e[0m (Average: #{avg_ms.round(2)} ms/case)"
        else
          speedups = metrics.map(&.speedup).reject { |s| s <= 0.0 }
          geo = XmlHandler.calculate_geomean(speedups)
          puts "  GeoMean Speedup: \e[1;36m#{geo.round(1)}x faster\e[0m (Crystal vs GDScript)"
        end

        # Terminal BarChart Visualization
        chart_cases = metrics.first(8)
        if !chart_cases.empty?
          puts
          chart_title = is_native_mode ? "Duration (ms) - Lower is Faster" : "Speedup Factor (x) - Higher is Faster"
          puts Opal.style.bold.fg(:cyan).render("  📊 #{chart_title}:")
          chart = Opal::UI::BarChart.new(title: nil, bar_char: '█')
          chart_cases.each do |m|
            val = is_native_mode ? m.crystal_ms : (m.speedup > 0.0 ? m.speedup : 1.0)
            chart.add(m.name, val, color: :cyan)
          end
          puts chart.to_print_s(width: 70)
        end

        html_link = Opal.hyperlink(html_file.basename, "file://#{html_file.expand}") rescue html_file.to_s
        puts "  HTML Report:     #{html_file} (\e[1;36m#{html_link}\e[0m)"
        puts "  Tag XML Report:  #{tag_xml}\n"

        0
      end
    end
  end
end
