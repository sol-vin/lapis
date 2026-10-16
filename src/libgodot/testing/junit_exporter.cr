module Lapis
  module Test
    class JUnitExporter
      def self.generate(results : Array(TestResult), filepath : String) : Void
        total = results.size
        failures = results.count(&.fail?)
        time_total = results.sum(&.duration_ms) / 1000.0

        by_cat = Hash(String, Array(TestResult)).new
        results.each do |r|
          (by_cat[r.category] ||= Array(TestResult).new) << r
        end

        xml = String.build do |io|
          io << "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
          io << "<testsuites name=\"Lapis Test Suite\" tests=\"#{total}\" failures=\"#{failures}\" errors=\"0\" time=\"#{time_total}\">\n"
          by_cat.each do |cat, cat_results|
            cat_failures = cat_results.count(&.fail?)
            cat_time = cat_results.sum(&.duration_ms) / 1000.0
            io << "  <testsuite name=\"#{escape_xml(cat)}\" tests=\"#{cat_results.size}\" failures=\"#{cat_failures}\" errors=\"0\" time=\"#{cat_time}\">\n"
            cat_results.each do |r|
              r_time = r.duration_ms / 1000.0
              io << "    <testcase classname=\"#{escape_xml(r.category)}\" name=\"#{escape_xml(r.name)}\" time=\"#{r_time}\""
              if r.fail?
                io << ">\n"
                io << "      <failure message=\"#{escape_xml(r.message)}\">#{escape_xml(r.message)}</failure>\n"
                io << "    </testcase>\n"
              elsif r.pending? || r.skipped?
                io << ">\n"
                io << "      <skipped message=\"#{escape_xml(r.message)}\"/>\n"
                io << "    </testcase>\n"
              else
                io << "/>\n"
              end
            end
            io << "  </testsuite>\n"
          end
          io << "</testsuites>\n"
        end

        Godot::SystemIO.write_file(filepath, xml) rescue File.write(filepath, xml)
      end

      private def self.escape_xml(str : String) : String
        str.gsub('&', "&amp;")
           .gsub('<', "&lt;")
           .gsub('>', "&gt;")
           .gsub('"', "&quot;")
           .gsub('\'', "&apos;")
      end
    end
  end
end
