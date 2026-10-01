require "option_parser"
require "json"
require "opal"
require "../core/logger"
require "../core/env"
require "../../../../src/libgodot/debugger/binary_analyzer"

module Lapis
  module Commands
    module Analyze
      def self.print_help
        puts <<-HELP
\e[36m=== Lapis: Binary Analysis & Hardening Auditor ===\e[0m

Usage: lapis analyze <binary> [options]

Arguments:
  <binary>                   Path to binary (.dll, .so, .exe, or .dylib)

Options:
  --chart, --tui             Display visual radare2 binary metrics chart dashboard
  --json                     Output structured machine-readable JSON report
  --budget-check             Enforce section size budgets (exits with code 1 on violation)
  --quick                    Skip deep basic block analysis for faster results
  -o, --output=FILE          Write analysis report to file
  -h, --help                 Show this help screen

Examples:
  lapis analyze bin/game.dll
  lapis analyze bin/game.dll --chart
  lapis analyze bin/crystal_bridge.dll
  lapis analyze bin/game.dll --json -o report.json
  lapis analyze bin/game.dll --budget-check
HELP
      end

      def self.run(args : Array(String)) : Int32
        if args.empty? || args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        binary_path : String? = nil
        output_file : String? = nil
        mode_json = false
        mode_chart = false
        budget_check = false
        quick_mode = false

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis analyze <binary> [options]"
          opts.on("--chart", "Display visual binary metrics chart") { mode_chart = true }
          opts.on("--tui", "Display visual binary metrics chart") { mode_chart = true }
          opts.on("--json", "Output structured JSON report") { mode_json = true }
          opts.on("--budget-check", "Enforce section size budgets (fail on violation)") { budget_check = true }
          opts.on("--quick", "Fast basic analysis") { quick_mode = true }
          opts.on("-o FILE", "--output=FILE", "Save output to file") { |f| output_file = f }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
          opts.unknown_args do |before, after|
            remaining = before + after
            binary_path = remaining[0]?
          end
        end

        parser.parse(args)

        target_file = binary_path
        unless target_file && File.exists?(target_file)
          Core::Logger.error("Target binary does not exist: #{target_file || "(none specified)"}")
          return 1
        end

        Core::Logger.step("Analyze", "Running static & dynamic binary audit on #{target_file}...") unless mode_json || mode_chart

        begin
          report = Debugger::BinaryAnalyzer.analyze_file(
            file_path: target_file,
            quick: quick_mode
          )

          if mode_chart
            metrics = Opal::UI::BinaryMetrics.new(
              target_name: File.basename(target_file),
              total_size: report.efficiency.total_binary_size,
              code_size: report.efficiency.total_code_size,
              bar_char: '|'
            )

            report.efficiency.sections.each do |sec|
              is_code = sec.name.downcase.includes?("text")
              is_data = sec.name.downcase.includes?("data") || sec.name.downcase.includes?("rdata")
              metrics.add_section(sec.name, sec.size, sec.percentage, is_code: is_code, is_data: is_data)
            end

            report.efficiency.largest_functions.first(8).each do |fn|
              metrics.add_function(fn.name, fn.size)
            end

            metrics.add_hardening("DEP / NX", report.hardening.dep_enabled, "Data Execution Prevention")
            metrics.add_hardening("ASLR", report.hardening.aslr_enabled, "Address Space Layout Randomization")
            metrics.add_hardening("Relocations", report.hardening.has_relocations, "Base Relocations Table")

            buf = Opal::UI::Buffer.new(80, 24)
            metrics.render(buf, 0, 0, 80, 24)
            chart_output = buf.render_to_string(with_ansi: true)

            if out_path = output_file
              File.write(out_path, chart_output)
              Core::Logger.success("Visual chart report written to: #{out_path}")
            else
              puts chart_output
            end
            return 0
          end

          output_text = if mode_json
            report.to_json
          else
            report.format_terminal
          end

          if out_path = output_file
            File.write(out_path, output_text)
            Core::Logger.success("Analysis report written to: #{out_path}") unless mode_json
          else
            puts output_text
          end

          if budget_check
            has_budget_violation = report.efficiency.sections.any? { |s| !s.within_budget }
            if has_budget_violation
              Core::Logger.error("Budget check FAILED: One or more binary sections exceeded their size budget!") unless mode_json
              return 1
            else
              Core::Logger.success("Budget check PASSED: All sections are within allocated budgets.") unless mode_json
            end
          end

          0
        rescue ex : Exception
          Core::Logger.error("Failed to analyze binary: #{ex.message}")
          1
        end
      end
    end
  end
end
