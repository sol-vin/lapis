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
        log_line_range : String? = nil,
        informational : Bool = false

      enum Profile
        Engine
        Template
        Addon

        def to_s : String
          case self
          in Engine   then "Engine Core"
          in Template then "Game Project / Template"
          in Addon    then "GDExtension Addon"
          end
        end

        def self.parse_profile(val : String?) : Profile
          return Profile::Engine unless val
          case val.downcase.strip
          when "template", "game", "project" then Profile::Template
          when "addon", "plugin"             then Profile::Addon
          else                                    Profile::Engine
          end
        end
      end

      record ArtifactItem,
        name : String,
        path : String,
        size_bytes : Int64

      property title : String
      property profile : Profile = Profile::Engine
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
        informational : Bool = false,
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
          log_line_range: log_line_range,
          informational: informational
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
        @phases.reject { |p| p.success || p.informational }
      end

      def informational_phases : Array(PhaseResult)
        @phases.select(&.informational)
      end

      def overall_success? : Bool
        @phases.all? { |p| p.success || p.informational } && @runtime_failed == 0
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
          md.puts "## 🚀 #{@title} — #{@platform_name} `[#{@profile.to_s}]`"
          md.puts
          case @profile
          when Profile::Engine
            md.puts "> [!NOTE]"
            md.puts "> **Lapis Engine Profile**: Validating Crystal bindings, C++ bridge loader, in-editor tool tests, and multi-addon ClassDB isolation."
          when Profile::Template
            md.puts "> [!NOTE]"
            md.puts "> **Game Project Profile**: Validating game logic, SceneTree initialization, standalone packaging, and release binaries."
          when Profile::Addon
            md.puts "> [!NOTE]"
            md.puts "> **Addon Profile**: Validating redistributable GDExtension plugin, export properties, and ClassDB interop."
          end
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
            icon = if p.informational
                     p.success ? "ℹ️" : "⚠️"
                   else
                     p.success ? "✅" : "❌"
                   end
            tag_display = p.informational ? "`#{p.tag}` *(informational)*" : "`#{p.tag}`"
            md.puts "| #{icon} | #{tag_display} | #{p.name} | #{p.category} | #{p.duration}s | #{p.exit_code} |"
          end

          # External & Ecosystem Compatibility (Informational)
          info_phases = informational_phases
          if !info_phases.empty?
            md.puts
            md.puts "---"
            md.puts
            md.puts "### 🌐 External & Ecosystem Compatibility (Informational)"
            md.puts
            md.puts "> [!NOTE]"
            md.puts "> These tests track ecosystem addons and backwards compatibility (e.g. CrShader). Failures here are diagnostic notices and do not block CI or the build pipeline."
            md.puts
            md.puts "| Status | Addon / Spec | Result | Duration | Notes / Diagnostics |"
            md.puts "| :---: | :--- | :---: | :---: | :--- |"
            info_phases.each do |ip|
              status_badge = ip.success ? "🟢 **COMPATIBLE**" : "🟡 **DIAGNOSTIC NOTICE**"
              result_str = ip.success ? "Passed" : "Diagnostic Notice (Exit #{ip.exit_code})"
              note = if ip.success
                       "All ecosystem integration assertions passed cleanly."
                     else
                       "Ecosystem spec exited with code #{ip.exit_code}. See diagnostics below."
                     end
              md.puts "| #{status_badge} | `#{ip.tag}` (#{ip.name}) | #{result_str} | #{ip.duration}s | #{note} |"
            end
            md.puts

            info_failures = info_phases.reject(&.success)
            if !info_failures.empty?
              info_failures.each do |inf|
                md.puts "<details><summary><b>🔍 Informational Diagnostics: #{inf.name}</b></summary>"
                md.puts
                if excerpt = inf.error_excerpt
                  md.puts "```text"
                  md.puts excerpt.strip
                  md.puts "```"
                end
                md.puts "</details>"
                md.puts
              end
            end
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
            json.field "profile", @profile.to_s
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
                    json.field "informational", p.informational
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

      def generate_html : String
        failures = failed_phases
        status_text = overall_success? ? "ALL PHASES PASSED" : "FAILURE (#{failures.size} failed)"
        status_color = overall_success? ? "#3fb950" : "#f85149"
        status_bg = overall_success? ? "rgba(63, 185, 80, 0.15)" : "rgba(248, 81, 73, 0.15)"

        String.build do |html|
          html.puts "<!DOCTYPE html>"
          html.puts "<html lang=\"en\">"
          html.puts "<head>"
          html.puts "  <meta charset=\"UTF-8\">"
          html.puts "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">"
          html.puts "  <title>#{@title} - #{@profile.to_s}</title>"
          html.puts "  <style>"
          html.puts "    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; background-color: #0d1117; color: #c9d1d9; margin: 0; padding: 24px; line-height: 1.5; }"
          html.puts "    .container { max-width: 1100px; margin: 0 auto; }"
          html.puts "    h1, h2, h3 { color: #f0f6fc; margin-top: 24px; margin-bottom: 12px; }"
          html.puts "    .badge { display: inline-block; padding: 4px 10px; border-radius: 20px; font-weight: 600; font-size: 13px; text-transform: uppercase; background: #{status_bg}; color: #{status_color}; border: 1px solid #{status_color}; }"
          html.puts "    .profile-pill { display: inline-block; padding: 3px 8px; border-radius: 6px; font-size: 12px; background: #21262d; color: #58a6ff; border: 1px solid #30363d; margin-left: 8px; }"
          html.puts "    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; margin: 20px 0; }"
          html.puts "    .card { background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 16px; }"
          html.puts "    .card-title { font-size: 12px; color: #8b949e; text-transform: uppercase; margin-bottom: 6px; }"
          html.puts "    .card-value { font-size: 18px; font-weight: 600; color: #f0f6fc; }"
          html.puts "    table { width: 100%; border-collapse: collapse; margin: 16px 0; background: #161b22; border: 1px solid #30363d; border-radius: 8px; overflow: hidden; }"
          html.puts "    th { background: #21262d; color: #f0f6fc; text-align: left; padding: 10px 14px; font-size: 13px; border-bottom: 1px solid #30363d; }"
          html.puts "    td { padding: 10px 14px; border-bottom: 1px solid #21262d; font-size: 13px; }"
          html.puts "    tr:last-child td { border-bottom: none; }"
          html.puts "    tr:hover { background: rgba(56, 139, 253, 0.04); }"
          html.puts "    .tag { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 12px; color: #79c0ff; }"
          html.puts "    .pass { color: #3fb950; font-weight: 600; }"
          html.puts "    .fail { color: #f85149; font-weight: 600; }"
          html.puts "    .info { color: #d29922; font-weight: 600; }"
          html.puts "    details { background: #161b22; border: 1px solid #30363d; border-radius: 6px; margin-bottom: 12px; padding: 12px; }"
          html.puts "    summary { cursor: pointer; font-weight: 600; color: #f0f6fc; outline: none; }"
          html.puts "    pre { background: #0d1117; padding: 12px; border-radius: 6px; overflow-x: auto; font-size: 12px; border: 1px solid #30363d; color: #f0883e; margin-top: 10px; }"
          html.puts "  </style>"
          html.puts "</head>"
          html.puts "<body>"
          html.puts "  <div class=\"container\">"
          html.puts "    <h1>🚀 #{@title} <span class=\"profile-pill\">#{@profile.to_s}</span></h1>"
          html.puts "    <div class=\"grid\">"
          html.puts "      <div class=\"card\"><div class=\"card-title\">Overall Status</div><div class=\"card-value\"><span class=\"badge\">#{status_text}</span></div></div>"
          html.puts "      <div class=\"card\"><div class=\"card-title\">Platform</div><div class=\"card-value\">#{@platform_name}</div></div>"
          html.puts "      <div class=\"card\"><div class=\"card-title\">Godot Engine</div><div class=\"card-value\">#{@godot_version}</div></div>"
          html.puts "      <div class=\"card\"><div class=\"card-title\">Crystal</div><div class=\"card-value\">#{@crystal_version}</div></div>"
          html.puts "      <div class=\"card\"><div class=\"card-title\">Duration</div><div class=\"card-value\">#{@total_duration.round(2)}s</div></div>"
          html.puts "    </div>"
          html.puts "    <h2>📊 Phase Progression & Trace Matrix</h2>"
          html.puts "    <table>"
          html.puts "      <thead><tr><th>Status</th><th>Phase Tag</th><th>Phase Name</th><th>Category</th><th>Duration</th><th>Exit Code</th></tr></thead>"
          html.puts "      <tbody>"
          @phases.each do |p|
            status_cls = p.informational ? "info" : (p.success ? "pass" : "fail")
            status_sym = p.informational ? (p.success ? "ℹ️ INFO" : "⚠️ NOTICE") : (p.success ? "✓ PASS" : "✗ FAIL")
            html.puts "        <tr><td class=\"#{status_cls}\">#{status_sym}</td><td class=\"tag\">#{p.tag}</td><td>#{p.name}</td><td>#{p.category}</td><td>#{p.duration}s</td><td>#{p.exit_code}</td></tr>"
          end
          html.puts "      </tbody>"
          html.puts "    </table>"

          if !failures.empty?
            html.puts "    <h2>🚨 Failure Diagnostics</h2>"
            failures.each do |f|
              html.puts "    <details open>"
              html.puts "      <summary><span class=\"fail\">[FAIL]</span> #{f.tag} - #{f.name} (Exit Code: #{f.exit_code})</summary>"
              if excerpt = f.error_excerpt
                html.puts "      <pre>#{excerpt.strip}</pre>"
              end
              html.puts "    </details>"
            end
          end

          if !@artifacts.empty?
            html.puts "    <h2>📦 Built Deliverables</h2>"
            html.puts "    <table>"
            html.puts "      <thead><tr><th>Artifact</th><th>Size</th><th>Path</th></tr></thead>"
            html.puts "      <tbody>"
            @artifacts.each do |art|
              html.puts "        <tr><td><strong>#{art.name}</strong></td><td>#{format_bytes(art.size_bytes)}</td><td class=\"tag\">#{art.path}</td></tr>"
            end
            html.puts "      </tbody>"
            html.puts "    </table>"
          end

          html.puts "  </div>"
          html.puts "</body>"
          html.puts "</html>"
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
        html_content = generate_html

        target_dirs.each do |dir|
          p = Path.new(dir)
          FileUtils.mkdir_p(p) unless Dir.exists?(p)
          File.write(p.join("test_report.md"), md_content)
          File.write(p.join("test_report.json"), json_content)
          File.write(p.join("test_report.html"), html_content)
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
