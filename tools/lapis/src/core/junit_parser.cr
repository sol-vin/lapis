require "xml"
require "json"

module Lapis
  module Core
    module JUnitParser
      record TestCase,
        classname : String,
        name : String,
        time : Float64,
        status : String, # "passed", "failed", "skipped"
        failure_message : String? = nil,
        failure_body : String? = nil

      record TestSuite,
        name : String,
        tests : Int32,
        failures : Int32,
        errors : Int32,
        skipped : Int32,
        time : Float64,
        cases : Array(TestCase)

      class Report
        property name : String
        property total_tests : Int32
        property total_failures : Int32
        property total_errors : Int32
        property total_skipped : Int32
        property total_time : Float64
        property suites : Array(TestSuite)

        def initialize(
          @name : String = "Test Report",
          @total_tests : Int32 = 0,
          @total_failures : Int32 = 0,
          @total_errors : Int32 = 0,
          @total_skipped : Int32 = 0,
          @total_time : Float64 = 0.0,
          @suites : Array(TestSuite) = [] of TestSuite,
        )
        end

        def passed? : Bool
          @total_failures == 0 && @total_errors == 0
        end

        def total_passed : Int32
          [@total_tests - (@total_failures + @total_errors + @total_skipped), 0].max
        end

        def failed_cases : Array(TestCase)
          @suites.flat_map(&.cases).select { |c| c.status == "failed" }
        end

        def merge(other : Report) : Report
          Report.new(
            name: @name == "Test Report" ? other.name : @name,
            total_tests: @total_tests + other.total_tests,
            total_failures: @total_failures + other.total_failures,
            total_errors: @total_errors + other.total_errors,
            total_skipped: @total_skipped + other.total_skipped,
            total_time: (@total_time + other.total_time).round(3),
            suites: @suites + other.suites,
          )
        end

        def to_markdown(custom_title : String? = nil) : String
          title_text = custom_title || @name
          status_badge = passed? ? "PASS (All tests passed)" : "FAIL (#{@total_failures + @total_errors} failures)"

          String.build do |io|
            io << "## #{title_text}\n\n"
            io << "| Overall Status | Total Tests | Passed | Failed | Errors | Skipped | Total Time |\n"
            io << "| :---: | :---: | :---: | :---: | :---: | :---: | :---: |\n"
            io << "| **#{status_badge}** | **#{@total_tests}** | #{total_passed} | #{@total_failures} | #{@total_errors} | #{@total_skipped} | #{@total_time.round(3)}s |\n\n"

            if !passed?
              io << "### Test Failures\n\n"
              failed_cases.each do |fc|
                io << "> [!CAUTION]\n"
                io << "> **[#{fc.classname}] #{fc.name}**\n"
                if msg = fc.failure_message
                  io << "> #{msg.strip}\n"
                end
                if body = fc.failure_body
                  body_trimmed = body.strip
                  if !body_trimmed.empty? && body_trimmed != fc.failure_message
                    io << ">\n> ```\n"
                    body_trimmed.lines.first(10).each { |l| io << "> #{l}\n" }
                    io << "> ```\n"
                  end
                end
                io << "\n"
              end
            end

            io << "### Suite Breakdown\n\n"
            io << "| Suite / Category | Tests | Passed | Failed | Duration |\n"
            io << "| :--- | :---: | :---: | :---: | :---: |\n"
            @suites.each do |s|
              s_passed = [s.tests - (s.failures + s.errors + s.skipped), 0].max
              s_status = s.failures > 0 || s.errors > 0 ? "FAIL (#{s.failures + s.errors})" : "PASS"
              io << "| **#{s.name}** | #{s.tests} | #{s_passed} | #{s_status} | #{s.time.round(3)}s |\n"
            end
            io << "\n"
          end
        end

        def to_json : String
          JSON.build do |json|
            json.object do
              json.field "name", @name
              json.field "passed", passed?
              json.field "total_tests", @total_tests
              json.field "total_passed", total_passed
              json.field "total_failures", @total_failures
              json.field "total_errors", @total_errors
              json.field "total_skipped", @total_skipped
              json.field "total_time", @total_time
              json.field "suites" do
                json.array do
                  @suites.each do |s|
                    json.object do
                      json.field "name", s.name
                      json.field "tests", s.tests
                      json.field "failures", s.failures
                      json.field "errors", s.errors
                      json.field "skipped", s.skipped
                      json.field "time", s.time
                      json.field "cases" do
                        json.array do
                          s.cases.each do |c|
                            json.object do
                              json.field "classname", c.classname
                              json.field "name", c.name
                              json.field "time", c.time
                              json.field "status", c.status
                              json.field "failure_message", c.failure_message
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      def self.parse(xml_content : String) : Report
        doc = XML.parse(xml_content)
        report = Report.new

        # Check root <testsuites> or <testsuite>
        root_nodes = doc.xpath_nodes("/testsuites")
        if root_nodes.empty?
          root_nodes = doc.xpath_nodes("/testsuite")
        end

        if root = root_nodes.first?
          report.name = root["name"]? || "Test Report"
          report.total_tests = root["tests"]?.try(&.to_i?) || 0
          report.total_failures = root["failures"]?.try(&.to_i?) || 0
          report.total_errors = root["errors"]?.try(&.to_i?) || 0
          report.total_time = root["time"]?.try(&.to_f?) || 0.0
        end

        suite_nodes = doc.xpath_nodes("//testsuite")
        suites = [] of TestSuite

        suite_nodes.each do |s_node|
          s_name = s_node["name"]? || "Default"
          s_tests = s_node["tests"]?.try(&.to_i?) || 0
          s_failures = s_node["failures"]?.try(&.to_i?) || 0
          s_errors = s_node["errors"]?.try(&.to_i?) || 0
          s_skipped = s_node["skipped"]?.try(&.to_i?) || 0
          s_time = s_node["time"]?.try(&.to_f?) || 0.0

          cases = [] of TestCase
          s_node.xpath_nodes("testcase").each do |tc_node|
            c_classname = tc_node["classname"]? || s_name
            c_name = tc_node["name"]? || "unnamed"
            c_time = tc_node["time"]?.try(&.to_f?) || 0.0

            failure_node = tc_node.xpath_node("failure") || tc_node.xpath_node("error")
            skipped_node = tc_node.xpath_node("skipped")

            status = if failure_node
                       "failed"
                     elsif skipped_node
                       "skipped"
                     else
                       "passed"
                     end

            fail_msg = failure_node.try { |f| f["message"]? || f.text.strip }
            fail_body = failure_node.try(&.text)

            cases << TestCase.new(
              classname: c_classname,
              name: c_name,
              time: c_time,
              status: status,
              failure_message: fail_msg,
              failure_body: fail_body
            )
          end

          # If s_tests is 0, count from cases
          s_tests = cases.size if s_tests == 0
          s_failures = cases.count { |c| c.status == "failed" } if s_failures == 0 && cases.any? { |c| c.status == "failed" }
          s_skipped = cases.count { |c| c.status == "skipped" } if s_skipped == 0 && cases.any? { |c| c.status == "skipped" }

          suites << TestSuite.new(
            name: s_name,
            tests: s_tests,
            failures: s_failures,
            errors: s_errors,
            skipped: s_skipped,
            time: s_time,
            cases: cases
          )
        end

        # Recalculate totals if needed
        if report.total_tests == 0 && !suites.empty?
          report.total_tests = suites.sum(&.tests)
          report.total_failures = suites.sum(&.failures)
          report.total_errors = suites.sum(&.errors)
          report.total_skipped = suites.sum(&.skipped)
          report.total_time = suites.sum(&.time) if report.total_time == 0.0
        end

        report.suites = suites
        report
      end

      def self.parse_file(filepath : String | Path) : Report?
        path_str = filepath.to_s
        return nil unless File.exists?(path_str)
        content = File.read(path_str)
        return nil if content.strip.empty?
        parse(content)
      rescue ex
        nil
      end
    end
  end
end
