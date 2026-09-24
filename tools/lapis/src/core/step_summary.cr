require "./env"
require "./logger"
require "./junit_parser"
require "json"

module Lapis
  module Core
    class StepSummary
      record PhaseResult,
        tag : String,
        name : String,
        category : String,
        success : Bool,
        duration : Float64,
        exit_code : Int32,
        error_excerpt : String? = nil,
        details : String? = nil,
        log_line_range : String? = nil

      record ArtifactItem,
        name : String,
        path : String,
        size_bytes : Int64

      property title : String
      property platform_name : String
      property crystal_version : String
      property godot_version : String
      property phases = [] of PhaseResult
      property artifacts = [] of ArtifactItem
      property runtime_total : Int32 = 0
      property runtime_passed : Int32 = 0
      property runtime_failed : Int32 = 0
      property runtime_details = [] of String
      property total_duration : Float64 = 0.0
      property junit_report : JUnitParser::Report? = nil

      def load_junit_report(path : String | Path) : Void
        if rep = JUnitParser.parse_file(path)
          if existing = @junit_report
            @junit_report = existing.merge(rep)
          else
            @junit_report = rep
          end
          if current = @junit_report
            set_runtime_metrics(
              total: current.total_tests,
              passed: current.total_passed,
              failed: current.total_failures + current.total_errors,
              details: current.failed_cases.map { |fc| "[#{fc.classname}] #{fc.name}: #{fc.failure_message}" }
            )
          end
        end
      end

      def initialize(
        @title : String = "Lapis Workflow Status",
        godot_exe : String? = nil,
      )
        platform_arch = Core::Env.windows? ? "x86_64" : (Core::Env.macos? ? "arm64" : "x86_64")
        @platform_name = if Core::Env.windows?
                           "Windows (#{platform_arch})"
                         elsif Core::Env.macos?
                           "macOS (#{platform_arch})"
                         else
                           "Linux (#{platform_arch})"
                         end

        @crystal_version = "Crystal #{Crystal::VERSION}"
        @godot_version = "Unknown"
        if g = godot_exe
          res = Core::ProcessRunner.capture(g.to_s, ["--version"])
          @godot_version = res[:output].lines.first?.try(&.strip) || "Unknown" if res[:status].success?
        end
      end

      def add_phase(
        tag : String,
        name : String,
        category : String,
        success : Bool,
        duration : Float64,
        exit_code : Int32,
        error_excerpt : String? = nil,
        details : String? = nil,
        log_line_range : String? = nil,
      ) : Void
        @phases << PhaseResult.new(
          tag: tag,
          name: name,
          category: category,
          success: success,
          duration: duration.round(2),
          exit_code: exit_code,
          error_excerpt: error_excerpt,
          details: details,
          log_line_range: log_line_range
        )
      end

      def add_artifact(name : String, path : String | Path) : Void
        p_str = path.to_s
        size = File.exists?(p_str) ? File.size(p_str) : 0_i64
        @artifacts << ArtifactItem.new(name, p_str, size)
      end

      def set_runtime_metrics(total : Int32, passed : Int32, failed : Int32, details : Array(String) = [] of String) : Void
        @runtime_total = total
        @runtime_passed = passed
        @runtime_failed = failed
        @runtime_details = details
      end

      def failed_phases : Array(PhaseResult)
        @phases.reject(&.success)
      end

      def overall_success? : Bool
        @phases.all?(&.success) && @runtime_failed == 0
      end

      private def format_bytes(bytes : Int64) : String
        if bytes >= 1024 * 1024
          "#{(bytes.to_f / (1024 * 1024)).round(2)} MB"
        elsif bytes >= 1024
          "#{(bytes.to_f / 1024).round(1)} KB"
        else
          "#{bytes} B"
        end
      end

      def generate_markdown : String
        repo = ENV["GITHUB_REPOSITORY"]?
        run_id = ENV["GITHUB_RUN_ID"]?
        server_url = ENV["GITHUB_SERVER_URL"]? || "https://github.com"
        run_url = (repo && run_id) ? "#{server_url}/#{repo}/actions/runs/#{run_id}" : nil

        failures = failed_phases
        status_badge = overall_success? ? "🟢 **ALL PHASES PASSED**" : "🔴 **FAILURE (#{failures.size} failed)**"

        String.build do |md|
          md.puts "## 🚀 #{@title} — #{@platform_name}"
          md.puts
          md.puts "| Overall Status | Platform | Godot Engine | Crystal | Total Duration | Failure Count |"
          md.puts "| :---: | :---: | :---: | :---: | :---: | :---: |"
          md.puts "| #{status_badge} | **#{@platform_name}** | `#{@godot_version}` | `#{@crystal_version}` | **#{@total_duration.round(2)}s** | **#{failures.size}** |"
          md.puts
          if run_url
            md.puts "> 🔗 **GitHub Actions Run**: [View Complete Run Logs](#{run_url})"
            md.puts
          end

          md.puts "### 📊 Phase Progression & Trace Matrix"
          md.puts
          md.puts "| Status | Phase Tag | Phase Name | Category | Duration | Exit Code |"
          md.puts "| :---: | :--- | :--- | :--- | :---: | :---: |"
          @phases.each do |p|
            icon = p.success ? "✅" : "❌"
            md.puts "| #{icon} | `#{p.tag}` | #{p.name} | #{p.category} | #{p.duration}s | #{p.exit_code} |"
          end

          # Error Replication & Triage Panel
          if !failures.empty?
            md.puts
            md.puts "---"
            md.puts
            md.puts "### 🚨 Failure Investigation & Error Replication Panel"
            md.puts
            failures.each do |f|
              md.puts "> [!CAUTION]"
              md.puts "> **Phase `#{f.tag}` Failed** (`#{f.name}` — Exit Code `#{f.exit_code}`, Duration `#{f.duration}s`)"
              if f.log_line_range
                md.puts "> **Log Reference**: #{f.log_line_range}"
              end
              if run_url
                md.puts "> **CI Log Link**: [View Logs on GitHub Actions](#{run_url})"
              end
              md.puts

              if excerpt = f.error_excerpt
                md.puts "```text"
                md.puts "======================================================================"
                md.puts "Captured Failure Output Excerpt for #{f.tag}:"
                md.puts "----------------------------------------------------------------------"
                md.puts excerpt.strip
                md.puts "======================================================================"
                md.puts "```"
                md.puts
              end

              if details = f.details
                md.puts "<details><summary><b>🔍 Phase Error Breakdown & Context</b></summary>"
                md.puts
                md.puts "```text"
                md.puts details.strip
                md.puts "```"
                md.puts "</details>"
                md.puts
              end
            end
          end

          # Deep Diagnostics (Collapsible)
          has_runtime_data = @runtime_total > 0 || !@runtime_details.empty?
          has_artifacts = !@artifacts.empty?

          if has_runtime_data || has_artifacts
            md.puts
            md.puts "---"
            md.puts
            md.puts "### 📋 Deep Diagnostic Breakdown"
            md.puts

            if has_runtime_data
              assertions_label = "#{@runtime_passed} / #{@runtime_total} Passed"
              assertions_label += " (#{@runtime_failed} Failed)" if @runtime_failed > 0
              md.puts "<details #{"open" if @runtime_failed > 0}><summary><b>🔍 Runtime Test Assertions Breakdown (#{assertions_label})</b></summary>"
              md.puts
              md.puts "| Metric | Count |"
              md.puts "| :--- | :---: |"
              md.puts "| Total Assertions | #{@runtime_total} |"
              md.puts "| Passed | #{@runtime_passed} |"
              md.puts "| Failed | #{@runtime_failed} |"
              md.puts

              if !@runtime_details.empty?
                md.puts "```text"
                @runtime_details.each do |line|
                  md.puts line
                end
                md.puts "```"
              end
              md.puts "</details>"
              md.puts
            end

            if jrep = @junit_report
              md.puts
              md.puts "---"
              md.puts
              status_badge = jrep.passed? ? "PASS" : "FAIL (#{jrep.total_failures + jrep.total_errors} failed)"
              md.puts "<details open><summary><b>🧪 Granular Test Results (JUnit Report: #{jrep.total_passed} / #{jrep.total_tests} Passed — #{status_badge})</b></summary>"
              md.puts
              md.puts "| Suite / Category | Tests | Passed | Failed | Duration |"
              md.puts "| :--- | :---: | :---: | :---: | :---: |"
              jrep.suites.each do |s|
                s_passed = [s.tests - (s.failures + s.errors + s.skipped), 0].max
                s_status = s.failures > 0 || s.errors > 0 ? "❌ #{s.failures + s.errors} failed" : "✓ PASS"
                md.puts "| **#{s.name}** | #{s.tests} | #{s_passed} | #{s_status} | #{s.time.round(3)}s |"
              end
              md.puts
              if !jrep.passed?
                md.puts "#### 🚨 Test Failures Detail"
                md.puts
                jrep.failed_cases.each do |fc|
                  md.puts "> [!CAUTION]"
                  md.puts "> **[#{fc.classname}] #{fc.name}**"
                  md.puts "> #{fc.failure_message.to_s.strip}" if fc.failure_message
                  md.puts
                end
              end
              md.puts "</details>"
              md.puts
            end

            if has_artifacts
              md.puts "<details><summary><b>📦 Built Artifacts & Deliverables (#{@artifacts.size} files)</b></summary>"
              md.puts
              md.puts "| Artifact File | Size | Path |"
              md.puts "| :--- | :---: | :--- |"
              @artifacts.each do |art|
                md.puts "| `#{art.name}` | #{format_bytes(art.size_bytes)} | `#{art.path}` |"
              end
              md.puts "</details>"
              md.puts
            end
          end
        end
      end

      def generate_json : String
        JSON.build(indent: 2) do |json|
          json.object do
            json.field "title", @title
            json.field "platform", @platform_name
            json.field "crystal_version", @crystal_version
            json.field "godot_version", @godot_version
            json.field "duration_seconds", @total_duration
            json.field "overall_success", overall_success?
            json.field "failed_phases_count", failed_phases.size
            json.field "phases" do
              json.array do
                @phases.each do |p|
                  json.object do
                    json.field "tag", p.tag
                    json.field "name", p.name
                    json.field "category", p.category
                    json.field "success", p.success
                    json.field "duration", p.duration
                    json.field "exit_code", p.exit_code
                    json.field "error_excerpt", p.error_excerpt
                    json.field "log_line_range", p.log_line_range
                  end
                end
              end
            end
            json.field "runtime_summary" do
              json.object do
                json.field "total", @runtime_total
                json.field "passed", @runtime_passed
                json.field "failed", @runtime_failed
              end
            end
            json.field "artifacts" do
              json.array do
                @artifacts.each do |art|
                  json.object do
                    json.field "name", art.name
                    json.field "size_bytes", art.size_bytes
                    json.field "path", art.path
                  end
                end
              end
            end
          end
        end
      end

      def emit_github_annotations : Void
        failed_phases.each do |f|
          err_msg = f.error_excerpt ? f.error_excerpt.to_s.lines.first?.try(&.strip) : "Phase #{f.tag} failed with exit code #{f.exit_code}"
          puts "::error title=Phase #{f.tag} Failure (#{f.name})::#{err_msg}"
        end
      end

      def publish(target_dirs : Array(Path | String) = [] of Path, append_to_github_summary : Bool = true) : Void
        md_content = generate_markdown
        json_content = generate_json

        target_dirs.each do |dir|
          p = Path.new(dir)
          FileUtils.mkdir_p(p) unless Dir.exists?(p)
          File.write(p.join("test_report.md"), md_content)
          File.write(p.join("test_report.json"), json_content)
        end

        emit_github_annotations

        if append_to_github_summary && (gsummary = ENV["GITHUB_STEP_SUMMARY"]?)
          begin
            File.open(gsummary, "a") do |io|
              io.puts "\n"
              io.puts md_content
              io.puts "\n"
            end
            Core::Logger.info("Published enriched test report to GitHub Step Summary.")
          rescue ex
            Core::Logger.warn("Could not write to GITHUB_STEP_SUMMARY: #{ex.message}")
          end
        end
      end
    end
  end
end
