require "../core/env"
require "../core/logger"
require "../core/process_runner"
require "file_utils"
require "option_parser"

module Lapis
  module Commands
    module Docs
      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Documentation Generator & Patcher ===\e[0m

Usage: lapis docs [options]

Options:
  -o, --output=DIR      Output directory for HTML docs (default: docs)
  --skip-generate       Only apply CSS/JS patches to existing docs in output directory
  -h, --help            Show this help screen

Examples:
  lapis docs
  lapis docs -o custom_docs
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
        bench_report = root.join("benchmarks/results/benchmark_report.html")
        if File.exists?(bench_report)
          bench_dir = docs_dir.join("benchmarks")
          FileUtils.mkdir_p(bench_dir)
          FileUtils.cp(bench_report, docs_dir.join("benchmarks.html"))
          FileUtils.cp(bench_report, docs_dir.join("benchmark_report.html"))
          FileUtils.cp(bench_report, bench_dir.join("index.html"))
          bench_svg = root.join("benchmarks/results/benchmark_chart.svg")
          if File.exists?(bench_svg)
            FileUtils.cp(bench_svg, bench_dir.join("benchmark_chart.svg"))
            FileUtils.cp(bench_svg, docs_dir.join("benchmark_chart.svg"))
          end
          Core::Logger.success("Embedded benchmark report into documentation (#{docs_dir.join("benchmarks.html")})!")
        end
      end

      def self.run(args : Array(String)) : Int32
        if args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        out_path : String? = nil
        skip_generate = args.includes?("--skip-generate")

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis docs [options]"
          opts.on("-o DIR", "--output=DIR", "Output directory (default: docs)") { |d| out_path = d }
          opts.on("--skip-generate", "Only patch existing docs") { skip_generate = true }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
        end
        parser.parse(args)

        root = Core::Env::ROOT_DIR
        docs_dir = ((op = out_path) ? Path.new(op) : root.join("docs")).expand

        unless skip_generate
          Core::Logger.step("Docs", "Generating HTML documentation from src/lapis.cr -> #{docs_dir}...")
          res = Core::ProcessRunner.run(
            "crystal",
            ["docs", "src/lapis.cr", "-o", docs_dir.to_s],
            chdir: root.to_s
          )
          unless res.success?
            Core::Logger.error("Failed to generate documentation via crystal docs.")
            return res.exit_code
          end
        end

        if Dir.exists?(docs_dir)
          patch_docs(docs_dir)
        end

        Core::Logger.success("Documentation generated and patched successfully in #{docs_dir}!")
        0
      end
    end
  end
end
