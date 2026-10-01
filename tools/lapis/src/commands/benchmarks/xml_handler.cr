require "xml"
require "./models"

module Lapis
  module Commands
    module Benchmarks
      module XmlHandler
        def self.generate_xml(
          metrics : Array(BenchmarkMetric),
          version : String,
          godot_ver : String,
          iterations : Int32,
          platform : String,
          tag : String? = nil,
          native_mode : Bool = false
        ) : String
          is_native = native_mode || metrics.all? { |m| m.gdscript_ms <= 0.0 }
          total_ms = metrics.sum(&.crystal_ms)
          avg_ms = metrics.empty? ? 0.0 : total_ms / metrics.size

          speedups = metrics.map(&.speedup).reject { |s| s <= 0.0 }
          geomean = calculate_geomean(speedups)
          comp_geo = calculate_geomean(metrics.select { |m| m.category == Category::Compute }.map(&.speedup).reject { |s| s <= 0.0 })
          eng_geo = calculate_geomean(metrics.select { |m| m.category == Category::EngineCore }.map(&.speedup).reject { |s| s <= 0.0 })
          timestamp = ::Time.utc.to_rfc3339
          tag_attr = tag && !tag.empty? ? %( tag="#{escape_xml(tag)}") : ""
          mode_attr = is_native ? %( mode="native") : %( mode="comparative")

          String.build do |io|
            io << %(<?xml version="1.0" encoding="UTF-8"?>\n)
            io << %(<benchmarks version="#{escape_xml(version)}"#{tag_attr}#{mode_attr} timestamp="#{timestamp}" platform="#{platform}" godot="#{godot_ver}" iterations="#{iterations}">\n)
            if is_native
              io << %(  <summary total="#{metrics.size}" total_ms="#{total_ms.round(2)}" avg_ms="#{avg_ms.round(2)}" />\n)
            else
              io << %(  <summary total="#{metrics.size}" speedup_geomean="#{geomean.round(2)}" compute_geomean="#{comp_geo.round(2)}" engine_geomean="#{eng_geo.round(2)}" />\n)
            end

            metrics.each do |m|
              group_attr = m.group_name ? %( group="#{escape_xml(m.group_name.not_nil!)}") : ""
              subgroup_attr = m.subgroup ? %( subgroup="#{escape_xml(m.subgroup.not_nil!)}") : ""
              kind_attr = m.group_kind != :runtime ? %( group_kind="#{m.group_kind}") : ""
              charts_attr = !m.chart_types.empty? ? %( chart_types="#{m.chart_types.map(&.to_s).join(",")}") : ""
              base_attr = m.baseline_name ? %( baseline="#{escape_xml(m.baseline_name.not_nil!)}") : ""
              io << %(  <case name="#{escape_xml(m.name)}" category="#{escape_xml(m.category.display_name)}"#{group_attr}#{subgroup_attr}#{kind_attr}#{charts_attr}#{base_attr}>\n)
              io << %(    <description>#{escape_xml(m.description)}</description>\n)
              io << %(    <crystal ms="#{m.crystal_ms.round(2)}" />\n)
              if m.gdscript_ms > 0.0
                io << %(    <gdscript ms="#{m.gdscript_ms.round(2)}" />\n)
                io << %(    <speedup ratio="#{m.speedup.round(2)}" />\n)
              end
              if ed = m.editor_ms
                ov = m.editor_overhead_ratio ? %( overhead_ratio="#{m.editor_overhead_ratio.not_nil!.round(2)}") : ""
                io << %(    <editor ms="#{ed.round(2)}"#{ov} />\n)
              end
              if cpp = m.cpp_ms
                io << %(    <cpp ms="#{cpp.round(2)}" />\n)
              end
              if cs = m.csharp_ms
                io << %(    <csharp ms="#{cs.round(2)}" />\n)
              end
              if rs = m.rust_ms
                io << %(    <rust ms="#{rs.round(2)}" />\n)
              end
              m.custom_metrics.each do |k, v|
                io << %(    <metric key="#{escape_xml(k)}" value="#{v.round(4)}" />\n)
              end
              io << %(  </case>\n)
            end
            io << %(</benchmarks>\n)
          end
        end

        def self.parse_xml(xml_content : String) : Tuple(Hash(String, String), Array(BenchmarkMetric))
          doc = XML.parse(xml_content)
          root = doc.root
          raise "Invalid benchmarks XML root" unless root && root.name == "benchmarks"

          meta = Hash(String, String).new
          root.attributes.each do |attr|
            meta[attr.name] = attr.content
          end

          metrics = [] of BenchmarkMetric
          root.xpath_nodes("./case").each do |case_node|
            name = case_node["name"]? || "Unknown"
            cat_str = case_node["category"]? || "Custom"
            cat = Category.parse_str(cat_str)
            group_name = case_node["group"]?
            subgroup = case_node["subgroup"]?

            desc_node = case_node.xpath_node("./description")
            desc = desc_node ? desc_node.text.strip : ""

            cr_ms = 0.0
            if cr_node = case_node.xpath_node("./crystal")
              cr_ms = cr_node["ms"]?.try(&.to_f?) || 0.0
            end

            gd_ms = 0.0
            if gd_node = case_node.xpath_node("./gdscript")
              gd_ms = gd_node["ms"]?.try(&.to_f?) || 0.0
            end

            speedup = 1.0
            if sp_node = case_node.xpath_node("./speedup")
              speedup = sp_node["ratio"]?.try(&.to_f?) || (cr_ms > 0 && gd_ms > 0 ? (gd_ms / cr_ms) : 1.0)
            elsif cr_ms > 0 && gd_ms > 0
              speedup = gd_ms / cr_ms
            end

            ed_ms : Float64? = nil
            ed_ratio : Float64? = nil
            if ed_node = case_node.xpath_node("./editor")
              ed_ms = ed_node["ms"]?.try(&.to_f?)
              ed_ratio = ed_node["overhead_ratio"]?.try(&.to_f?)
            end

            cpp_ms : Float64? = nil
            if cpp_node = case_node.xpath_node("./cpp")
              cpp_ms = cpp_node["ms"]?.try(&.to_f?)
            end

            csharp_ms : Float64? = nil
            if cs_node = case_node.xpath_node("./csharp")
              csharp_ms = cs_node["ms"]?.try(&.to_f?)
            end

            rust_ms : Float64? = nil
            if rs_node = case_node.xpath_node("./rust")
              rust_ms = rs_node["ms"]?.try(&.to_f?)
            end

            custom_hash = Hash(String, Float64).new
            case_node.xpath_nodes("./metric").each do |m_node|
              if k = m_node["key"]?
                if v = m_node["value"]?.try(&.to_f?)
                  custom_hash[k] = v
                end
              end
            end

            group_kind_sym = case case_node["group_kind"]?
                             when "compile_time" then :compile_time
                             when "throughput"   then :throughput
                             else                     :runtime
                             end

            chart_types_arr = if ct_str = case_node["chart_types"]?
                                ct_str.split(',').map(&.strip).compact_map do |s|
                                  case s
                                  when "bar"              then :bar
                                  when "speedup"          then :speedup
                                  when "ratio"            then :ratio
                                  when "log"              then :log
                                  when "debug_vs_release" then :debug_vs_release
                                  when "size"             then :size
                                  when "throughput"       then :throughput
                                  else                         nil
                                  end
                                end
                              else
                                [] of Symbol
                              end
            baseline_name = case_node["baseline"]?

            # Fallback for catalog-mapped benchmarks if group_name is missing
            if group_name.nil? || group_name.empty?
              if b = Commands::Benchmarks.builtin_benchmarks.find { |c| c.name.downcase == name.downcase }
                group_name = b.group_name
                group_kind_sym = b.group_kind if group_kind_sym == :runtime
                chart_types_arr = b.chart_types if chart_types_arr.empty?
              end
            end

            # Smart inference if group_kind wasn't explicitly set
            if group_kind_sym == :runtime
              if group_name == "CompileTime" || name == "CompileTimes" || cat == Category::Toolchain || custom_hash.has_key?("cr_debug_ms") || custom_hash.has_key?("crystal_debug_compile_ms")
                group_kind_sym = :compile_time
                chart_types_arr = [:debug_vs_release, :size, :bar, :speedup] if chart_types_arr.empty?
              elsif group_name == "Shaders" || custom_hash.keys.any?(&.ends_with?("_per_sec"))
                group_kind_sym = :throughput
                chart_types_arr = [:throughput, :bar, :speedup] if chart_types_arr.empty?
              end
            end

            if chart_types_arr.empty?
              chart_types_arr = [:bar, :speedup, :ratio, :log]
            end

            metrics << BenchmarkMetric.new(
              name: name,
              category: cat,
              crystal_ms: cr_ms,
              gdscript_ms: gd_ms,
              speedup: speedup,
              description: desc,
              editor_ms: ed_ms,
              editor_overhead_ratio: ed_ratio,
              cpp_ms: cpp_ms,
              csharp_ms: csharp_ms,
              rust_ms: rust_ms,
              group_name: group_name,
              baseline_name: baseline_name,
              custom_metrics: custom_hash,
              group_kind: group_kind_sym,
              chart_types: chart_types_arr,
              subgroup: subgroup
            )
          end

          {meta, metrics}
        end

        def self.generate_comparison_xml(
          curr_metrics : Array(BenchmarkMetric),
          prev_metrics : Array(BenchmarkMetric),
          curr_ver : String,
          prev_ver : String,
          curr_tag : String? = nil,
          prev_tag : String? = nil,
          native_mode : Bool = false
        ) : String
          curr_map = curr_metrics.to_h { |m| {m.name, m} }
          prev_map = prev_metrics.to_h { |m| {m.name, m} }
          all_names = (curr_map.keys + prev_map.keys).uniq.sort

          is_native = native_mode || (curr_metrics.all? { |m| m.gdscript_ms <= 0.0 } && prev_metrics.all? { |m| m.gdscript_ms <= 0.0 })
          timestamp = ::Time.utc.to_rfc3339
          curr_tag_attr = curr_tag && !curr_tag.empty? ? %( current_tag="#{escape_xml(curr_tag)}") : ""
          prev_tag_attr = prev_tag && !prev_tag.empty? ? %( previous_tag="#{escape_xml(prev_tag)}") : ""
          mode_attr = is_native ? %( mode="native") : %( mode="comparative")

          String.build do |io|
            io << %(<?xml version="1.0" encoding="UTF-8"?>\n)
            io << %(<benchmark_comparison current_version="#{escape_xml(curr_ver)}"#{curr_tag_attr} previous_version="#{escape_xml(prev_ver)}"#{prev_tag_attr}#{mode_attr} timestamp="#{timestamp}">\n)

            if is_native
              c_tot = curr_metrics.sum(&.crystal_ms)
              p_tot = prev_metrics.sum(&.crystal_ms)
              d_pct = p_tot > 0 ? ((c_tot - p_tot) / p_tot) * 100.0 : 0.0
              io << %(  <summary total_cases="#{all_names.size}" previous_total_ms="#{p_tot.round(2)}" current_total_ms="#{c_tot.round(2)}" delta_percent="#{d_pct.round(2)}" />\n)
            else
              c_sp = curr_metrics.map(&.speedup).reject { |s| s <= 0.0 }
              p_sp = prev_metrics.map(&.speedup).reject { |s| s <= 0.0 }
              c_geo = calculate_geomean(c_sp)
              p_geo = calculate_geomean(p_sp)
              geo_diff = p_geo > 0 ? ((c_geo - p_geo) / p_geo) * 100.0 : 0.0
              io << %(  <summary total_cases="#{all_names.size}" prev_geomean="#{p_geo.round(2)}" curr_geomean="#{c_geo.round(2)}" diff_pct="#{geo_diff.round(2)}" />\n)
            end

            all_names.each do |name|
              c = curr_map[name]?
              p = prev_map[name]?
              cat = c.try(&.category.display_name) || p.try(&.category.display_name) || "Custom"
              desc = c.try(&.description) || p.try(&.description) || ""

              io << %(  <case name="#{escape_xml(name)}" category="#{escape_xml(cat)}">\n)
              io << %(    <description>#{escape_xml(desc)}</description>\n)

              if is_native
                c_ms = c ? c.crystal_ms : 0.0
                p_ms = p ? p.crystal_ms : 0.0
                diff = (p && p_ms > 0 && c) ? (((c_ms - p_ms) / p_ms) * 100.0).round(2) : 0.0
                status = if p.nil?
                           "new"
                         elsif c.nil?
                           "removed"
                         elsif diff < -1.0
                           "improved"
                         elsif diff > 1.0
                           "regressed"
                         else
                           "parity"
                         end
                io << %(    <progression prev_ms="#{p_ms.round(2)}" curr_ms="#{c_ms.round(2)}" diff_pct="#{diff}" status="#{status}" />\n)
              else
                c_sp = c ? c.speedup : 0.0
                p_sp = p ? p.speedup : 0.0
                diff = (p && p_sp > 0 && c) ? (((c_sp - p_sp) / p_sp) * 100.0).round(2) : 0.0
                status = if p.nil?
                           "new"
                         elsif c.nil?
                           "removed"
                         elsif diff > 1.0
                           "improved"
                         elsif diff < -1.0
                           "regressed"
                         else
                           "parity"
                         end
                io << %(    <progression prev_speedup="#{p_sp.round(2)}" curr_speedup="#{c_sp.round(2)}" diff_pct="#{diff}" status="#{status}" />\n)
              end
              io << %(  </case>\n)
            end

            io << %(</benchmark_comparison>\n)
          end
        end

        def self.calculate_geomean(values : Array(Float64)) : Float64
          return 0.0 if values.empty?
          log_sum = values.sum { |v| Math.log(v > 0.0 ? v : 1e-6) }
          Math.exp(log_sum / values.size)
        end

        def self.escape_xml(str : String) : String
          str.gsub('&', "&amp;").gsub('<', "&lt;").gsub('>', "&gt;").gsub('"', "&quot;").gsub('\'', "&apos;")
        end
      end
    end
  end
end
