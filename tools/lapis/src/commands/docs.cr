require "../core/env"
require "../core/logger"
require "../core/process_runner"
require "../docs/generator"
require "../docs/model"
require "../docs/indexer"
require "../tui/docs_viewer"
require "file_utils"
require "option_parser"
require "opal"

module Lapis
  module Commands
    module Docs
      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Documentation Generator & Patcher ===\e[0m

Usage:
  lapis docs [options]
  lapis docs lookup [gd|crystal|guide|stdlib] <query>
  lapis docs search <query>
  lapis docs tui [query]

Subcommands:
  lookup [context] <query>  Look up method, class, or property signatures (e.g. 'gd move_and_slide')
  search <query>            Full-text search across Godot, Crystal, and guide documentation
  tui, ui [query]           Launch full-screen interactive Terminal User Interface docs explorer

Contexts for lookup:
  gd, godot                 Query Godot engine ClassDB API using GDScript conventions
  crystal, cr               Query Crystal project nodes and methods (e.g. 'Player#take_damage')
  guide, docs               Query Lapis architectural & gameplay topic guides
  stdlib, core              Query Crystal standard library types (Fiber, Channel, Mutex)

Options:
  -o, --output=DIR          Output directory for HTML docs (default: docs)
  --src=DIR                 Source directory containing YAML docs (default: docs_src)
  --generate-only           Compile YAML docs to Crystal classes without running crystal docs
  --skip-generate           Only apply CSS/JS patches to existing docs in output directory
  --github[=REPO]           Add GitHub source links (default: sol-vin/lapis)
  --tui                     Launch interactive TUI documentation explorer
  -h, --help                Show this help screen

Examples:
  lapis docs lookup gd "CharacterBody3D.move_and_slide"
  lapis docs lookup crystal "Player#take_damage"
  lapis docs lookup stdlib "Channel"
  lapis docs lookup guide "concurrency"
  lapis docs search "physics"
  lapis docs tui
HELP
      end

      def self.patch_docs(docs_dir : Path) : Void
        css_file = docs_dir.join("css/style.css")
        js_file = docs_dir.join("js/doc.js")

        # 1. Patch CSS max-height cutoff in sidebar tree
        if File.exists?(css_file)
          css = File.read(css_file)
          if css.includes?("max-height: 1000em;") || css.includes?("max-height: none;")
            Core::Logger.step("Docs:Patch", "Setting sidebar max-height to 3000em in CSS...")
            css = css.gsub("max-height: 1000em;", "max-height: 3000em;")
            css = css.gsub("max-height: none;", "max-height: 3000em;")
            File.write(css_file, css)
            Core::Logger.success("CSS sidebar height cutoff patched to 3000em successfully!")
          end
        end

        # 2. Patch search results limit in doc.js
        if File.exists?(js_file)
          js = File.read(js_file)
          if js.includes?("CrystalDocs.MAX_RESULTS_DISPLAY = 140;")
            Core::Logger.step("Docs:Patch", "Increasing search display limit (140 to 500) in JS...")
            File.write(js_file, js.gsub("CrystalDocs.MAX_RESULTS_DISPLAY = 140;", "CrystalDocs.MAX_RESULTS_DISPLAY = 500;"))
            Core::Logger.success("Search display limit increased successfully!")
          end
        end

        # 3. Embed benchmark reports if available
        root = Core::Env::ROOT_DIR
        proj_root = docs_dir.parent
        possible_reports = [
          proj_root.join("benchmarks/reports/benchmarks.html"),
          proj_root.join("benchmarks/reports/benchmark_report.html"),
          proj_root.join("benchmarks/results/benchmark_report.html"),
        ]
        if proj_root == root
          possible_reports << root.join("benchmarks/reports/benchmarks.html")
          possible_reports << root.join("benchmarks/reports/benchmark_report.html")
          possible_reports << root.join("benchmarks/results/benchmark_report.html")
        end
        if bench_report = possible_reports.find { |p| File.exists?(p) }
          bench_dir = docs_dir.join("benchmarks")
          FileUtils.mkdir_p(bench_dir)
          FileUtils.cp(bench_report, docs_dir.join("benchmarks.html"))
          FileUtils.cp(bench_report, docs_dir.join("benchmark_report.html"))
          FileUtils.cp(bench_report, bench_dir.join("index.html"))

          # Try copying companion chart svg
          report_parent = bench_report.parent
          possible_svgs = [
            report_parent.join("benchmark_chart.svg"),
            proj_root.join("benchmarks/reports/benchmark_chart.svg"),
            proj_root.join("benchmarks/results/benchmark_chart.svg"),
          ]
          if proj_root == root
            possible_svgs << root.join("benchmarks/reports/benchmark_chart.svg")
            possible_svgs << root.join("benchmarks/results/benchmark_chart.svg")
          end
          if bench_svg = possible_svgs.find { |s| File.exists?(s) }
            FileUtils.cp(bench_svg, bench_dir.join("benchmark_chart.svg"))
            FileUtils.cp(bench_svg, docs_dir.join("benchmark_chart.svg"))
          end
          Core::Logger.success("Embedded benchmark report into documentation (#{docs_dir.join("benchmarks.html")})!")
        end
      end

      def self.lookup(args : Array(String)) : Int32
        if args.empty?
          Core::Logger.error("Specify query: lapis docs lookup [gd|crystal|guide|stdlib] <query>")
          return 1
        end

        context : ::Lapis::Docs::Context? = nil
        query_parts = [] of String

        args.each do |a|
          case a.downcase
          when "gd", "godot"
            context = ::Lapis::Docs::Context::Godot
          when "crystal", "cr"
            context = ::Lapis::Docs::Context::Crystal
          when "guide", "docs", "doc"
            context = ::Lapis::Docs::Context::Guide
          when "stdlib", "core", "std"
            context = ::Lapis::Docs::Context::Stdlib
          else
            query_parts << a
          end
        end

        query = query_parts.join(" ")
        indexer = ::Lapis::Docs::Indexer.build
        matches = indexer.lookup(context, query)

        if matches.empty?
          ctx_str = context ? " in #{context}" : ""
          Core::Logger.warn("No documentation matches found for '#{query}'#{ctx_str}.")
          return 1
        end

        matches.first(3).each_with_index do |sym, idx|
          render_symbol_card(sym)
          puts "" if idx < Math.min(3, matches.size) - 1
        end
        0
      end

      def self.search(args : Array(String)) : Int32
        if args.empty?
          Core::Logger.error("Specify search query: lapis docs search <query>")
          return 1
        end

        query = args.join(" ")
        indexer = ::Lapis::Docs::Indexer.build
        matches = indexer.search(query)

        if matches.empty?
          Core::Logger.warn("No documentation search results for '#{query}'.")
          return 0
        end

        puts Opal.style.bold.fg(:cyan).render("\n=== Documentation Search Results for '#{query}' (#{matches.size} matches) ===")
        matches.first(15).each do |s|
          badge = "[#{s.context.to_badge}:#{s.kind.to_badge}]"
          badge_color = case s.context
                        when ::Lapis::Docs::Context::Godot   then "\e[36m"
                        when ::Lapis::Docs::Context::Crystal then "\e[32m"
                        when ::Lapis::Docs::Context::Guide   then "\e[33m"
                        when ::Lapis::Docs::Context::Stdlib  then "\e[35m"
                        else                                      "\e[37m"
                        end
          puts "  #{badge_color}#{badge}\e[0m \e[1;97m#{s.full_query}\e[0m — \e[38;5;250m#{s.summary}\e[0m"
        end
        puts ""
        0
      end

      private def self.render_symbol_card(sym : ::Lapis::Docs::DocSymbol) : Void
        ctx_title = case sym.context
                    when ::Lapis::Docs::Context::Godot   then "[Godot 4.x Engine API]"
                    when ::Lapis::Docs::Context::Crystal then "[Crystal Project Node / Class]"
                    when ::Lapis::Docs::Context::Guide   then "[Lapis Architectural Guide]"
                    when ::Lapis::Docs::Context::Stdlib  then "[Crystal Core Standard Library]"
                    end

        puts "\e[38;5;240m╭──────────────────────────────────────────────────────────────────────────────╮\e[0m"
        puts "\e[38;5;240m│\e[0m \e[1;33m#{ctx_title}\e[0m \e[1;97m#{sym.full_query}\e[0m"
        if file = sym.file_path
          loc = "Defined at: #{file}#{sym.line_number ? ":#{sym.line_number}" : ""}"
          puts "\e[38;5;240m│\e[0m \e[38;5;244m#{loc}\e[0m"
        end
        puts "\e[38;5;240m╰──────────────────────────────────────────────────────────────────────────────╯\e[0m"

        if !sym.inheritance.empty?
          puts "\e[1mInheritance:\e[0m \e[36m#{sym.inheritance.join(" < ")}\e[0m\n"
        end

        puts "\e[1;96mSIGNATURE:\e[0m"
        puts "  \e[1;92m#{sym.signature}\e[0m\n"

        if !sym.params.empty?
          puts "\e[1;96mPARAMETERS:\e[0m"
          sym.params.each do |p|
            puts "  • \e[1m#{p.name}\e[0m : \e[33m#{p.type_str}\e[0m#{p.default_value ? " = #{p.default_value}" : ""}"
          end
          puts ""
        end

        if ret = sym.return_type
          puts "\e[1;96mRETURNS:\e[0m \e[36m#{ret}\e[0m\n"
        end

        desc = sym.description.empty? ? sym.summary : sym.description
        if !desc.empty?
          puts "\e[1;96mDESCRIPTION:\e[0m"
          desc.lines.first(15).each do |l|
            puts "  #{l}"
          end
          if desc.lines.size > 15
            puts "  \e[38;5;244m... (#{desc.lines.size - 15} more lines. Launch 'lapis docs tui' to read full doc)\e[0m"
          end
        end
      end

      def self.run(args : Array(String)) : Int32
        if args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        # Subcommand dispatch
        if args.first? == "lookup"
          return lookup(args[1..])
        elsif args.first? == "search"
          return search(args[1..])
        elsif args.first? == "tui" || args.first? == "ui" || args.includes?("--tui")
          clean = args.reject { |a| a == "tui" || a == "ui" || a == "--tui" }
          query = clean.first?
          TUI::DocsViewer.run(query)
          return 0
        end

        proj_path : String? = nil
        entry_path : String? = nil
        out_path : String? = nil
        src_path : String? = nil
        skip_generate = args.includes?("--skip-generate")
        generate_only = args.includes?("--generate-only")
        github_repo : String? = nil
        clean_args = [] of String
        args.each do |a|
          if a == "--github"
            github_repo = "sol-vin/lapis"
          elsif a.starts_with?("--github=")
            github_repo = a["--github=".size..-1]
          else
            clean_args << a
          end
        end

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis docs [options]"
          opts.on("-p PATH", "--path=PATH", "Project directory (default: current directory)") { |p| proj_path = p }
          opts.on("-e PATH", "--entry=PATH", "Entry source file (.cr) (default: auto-detected)") { |e| entry_path = e }
          opts.on("-o DIR", "--output=DIR", "Output directory (default: docs)") { |d| out_path = d }
          opts.on("--src=DIR", "YAML docs source directory (default: docs_src)") { |s| src_path = s }
          opts.on("--generate-only", "Compile YAML docs to Crystal classes without running crystal docs") { generate_only = true }
          opts.on("--skip-generate", "Only patch existing docs") { skip_generate = true }
          opts.on("--github", "Add GitHub source links (default: sol-vin/lapis)") { }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
        end
        parser.parse(clean_args)

        target_dir = ((pp = proj_path) ? Path.new(pp) : Path.new(Dir.current)).expand
        root = if File.exists?(target_dir.join("src/main.cr")) || Dir.exists?(target_dir.join("docs_src")) || (File.exists?(target_dir.join("shard.yml")) && !File.exists?(target_dir.join("src/libgodot.cr")))
                 target_dir
               else
                 Core::Env::ROOT_DIR
               end
        docs_dir = ((op = out_path) ? Path.new(op) : root.join("docs")).expand
        yaml_src_dir = ((sp = src_path) ? Path.new(sp) : root.join("docs_src")).expand

        # Determine documentation output directories
        out_cr_dir = if root == Core::Env::ROOT_DIR && Dir.exists?(root.join("src/libgodot"))
                       root.join("src/libgodot/docs")
                     else
                       root.join("src/docs")
                     end
        root_cr_file = if root == Core::Env::ROOT_DIR && Dir.exists?(root.join("src/libgodot"))
                         root.join("src/libgodot/docs.cr")
                       else
                         root.join("src/docs.cr")
                       end

        # 1. Compile YAML documentation to Crystal classes if docs_src exists
        if Dir.exists?(yaml_src_dir)
          Core::Logger.step("Docs:YAML", "Compiling YAML documentation from #{yaml_src_dir} -> #{out_cr_dir.relative_to(root)}...")
          success = ::Lapis::Docs::Generator.run(
            src_dir: yaml_src_dir,
            out_dir: out_cr_dir,
            root_docs_file: root_cr_file
          )
          if success
            Core::Logger.success("Synthesized Crystal doc classes and master docs.cr!")
          end
        else
          Core::Logger.info("No YAML docs source directory found at #{yaml_src_dir}.")
          Core::Logger.info("Create #{yaml_src_dir.relative_to(root)}/01_getting_started/01_overview.yml to enable automatic YAML doc synthesis.")
        end

        return 0 if generate_only

        # Determine entry point for crystal docs
        entry_file = if e = entry_path
                       e
                     elsif File.exists?(root.join("src/lapis.cr"))
                       "src/lapis.cr"
                     elsif File.exists?(root.join("src/main.cr"))
                       "src/main.cr"
                     elsif File.exists?(root.join("src/libgodot.cr"))
                       "src/libgodot.cr"
                     else
                       matches = Dir.glob(root.join("src/*.cr").to_s.tr("\\", "/"))
                       matches.first? ? Path.new(matches.first).relative_to(root).to_s : "src/main.cr"
                     end

        # 2. Run crystal docs
        unless skip_generate
          Core::Logger.step("Docs", "Generating HTML documentation from #{entry_file} -> #{docs_dir}...")
          docs_args = ["docs", entry_file, "-o", docs_dir.to_s]
          if repo = github_repo
            docs_args << "--source-url-pattern=https://github.com/#{repo}/blob/master/%{path}#L%{line}"
          end

          res = Core::ProcessRunner.run(
            "crystal",
            docs_args,
            chdir: root.to_s
          )
          unless res.success?
            Core::Logger.error("Failed to generate documentation via crystal docs.")
            return res.exit_code
          end
        end

        # 3. Patch CSS / JS / Benchmarks
        if Dir.exists?(docs_dir)
          patch_docs(docs_dir)
        end

        Core::Logger.success("Documentation generated and patched successfully in #{docs_dir}!")
        0
      end
    end
  end
end
