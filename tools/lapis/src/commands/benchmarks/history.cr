require "http/client"
require "file_utils"
require "./models"
require "./xml_handler"
require "./html_generator"
require "../../core/env"
require "../../core/logger"
require "../../core/godot_finder"

module Lapis
  module Commands
    module Benchmarks
      # Remote Baseline Fetcher
      def self.fetch_remote_baseline(version : String? = nil, tag : String? = nil, github_repo : String? = nil) : String?
        repo = github_repo
        if repo.nil? || repo.empty?
          begin
            remote_out = String.build do |io|
              Process.run("git", ["remote", "get-url", "origin"], output: io, error: Process::Redirect::Close)
            end.strip
            if m = remote_out.match(%r{github\.com[/:]([^/]+)/([^/\.]+)(?:\.git)?})
              repo = "#{m[1]}/#{m[2]}"
            end
          rescue
          end
        end
        repo ||= "sol-vin/lapis"
        parts = repo.split('/', 2)
        owner = parts[0]
        repo_name = parts.size > 1 ? parts[1] : parts[0]

        urls = [] of String
        if t = tag
          urls << "https://#{owner}.github.io/#{repo_name}/benchmarks/history/benchmarks_#{t}.xml"
          urls << "https://raw.githubusercontent.com/#{owner}/#{repo_name}/gh-pages/benchmarks/history/benchmarks_#{t}.xml"
          urls << "https://github.com/#{owner}/#{repo_name}/releases/download/#{t}/benchmarks_#{t}.xml"
        end
        if v = version
          urls << "https://#{owner}.github.io/#{repo_name}/benchmarks/history/benchmarks_#{v}.xml"
          urls << "https://raw.githubusercontent.com/#{owner}/#{repo_name}/gh-pages/benchmarks/history/benchmarks_#{v}.xml"
        end
        urls << "https://#{owner}.github.io/#{repo_name}/benchmarks/benchmarks_latest.xml"
        urls << "https://raw.githubusercontent.com/#{owner}/#{repo_name}/gh-pages/benchmarks/benchmarks_latest.xml"

        # Fallback to main lapis repo if this project is distinct
        if repo != "sol-vin/lapis"
          if t = tag
            urls << "https://sol-vin.github.io/lapis/benchmarks/history/benchmarks_#{t}.xml"
          end
          urls << "https://sol-vin.github.io/lapis/benchmarks/benchmarks_latest.xml"
        end

        urls.each do |url|
          begin
            Core::Logger.info("Attempting to fetch remote benchmark baseline from #{url}...")
            uri = URI.parse(url)
            client = HTTP::Client.new(uri)
            client.connect_timeout = 5.seconds
            client.read_timeout = 8.seconds
            response = client.get(uri.request_target)
            if response.status_code == 200 && response.body.includes?("<benchmarks")
              Core::Logger.success("Successfully fetched baseline benchmarks from GitHub Pages!")
              return response.body
            end
          rescue ex
            Core::Logger.trace("Benchmark:Fetch", "Failed fetching #{url}: #{ex.message}")
          end
        end
        nil
      end

      # Tag & History Resolution Helpers
      def self.resolve_tags(
        root : Path,
        reports_dir : Path,
        cli_tag : String? = nil,
        cli_prev_tag : String? = nil
      ) : Tuple(String, String?)
        godot_expected = Core::GodotFinder.expected_version(root.to_s)
        curr_tag = if ct = cli_tag
                     ct
                   elsif env_tag = ENV["TAG_NAME"]? || ENV["GITHUB_REF_NAME"]?
                     if env_tag.starts_with?("v") || env_tag.includes?("-dev") || env_tag.includes?(".")
                       env_tag
                     else
                       godot_expected
                     end
                   else
                     git_out = String.build do |io|
                       Process.run("git", ["describe", "--tags", "--exact-match"], output: io, error: Process::Redirect::Close)
                     end.strip rescue ""
                     if git_out.empty? || git_out.includes?("fatal")
                       git_out = String.build do |io|
                         Process.run("git", ["describe", "--tags"], output: io, error: Process::Redirect::Close)
                       end.strip rescue ""
                     end

                     if !git_out.empty? && !git_out.includes?("fatal")
                       git_out.split('-').first(2).join('-')
                     else
                       godot_expected
                     end
                   end

        prev_tag = if pt = cli_prev_tag
                     pt
                   else
                     discover_previous_tag(curr_tag, root, reports_dir)
                   end

        {curr_tag, prev_tag}
      end

      def self.discover_previous_tag(curr_tag : String, root : Path, reports_dir : Path) : String?
        search_dirs = [reports_dir, root.join("docs/benchmarks/history"), root.join("docs/benchmarks")]
        found_tags = [] of String
        search_dirs.each do |dir|
          next unless Dir.exists?(dir)
          Dir.glob(dir.to_s.gsub('\\', '/') + "/benchmarks_*.xml").each do |path|
            base = File.basename(path, ".xml")
            next if base == "benchmarks_latest"
            tag_name = base.sub(/^benchmarks_/, "")
            found_tags << tag_name unless tag_name == curr_tag || tag_name == Lapis::VERSION
          end
        end
        found_tags.uniq!

        if m = curr_tag.match(/^(.*-dev)(\d+)$/)
          prefix = m[1]
          num = m[2].to_i?
          if num && num > 1
            expected_prev = "#{prefix}#{num - 1}"
            return expected_prev if found_tags.includes?(expected_prev)
          end
        end

        begin
          out_tags = String.build do |io|
            Process.run("git", ["tag", "--sort=-creatordate"], output: io, error: Process::Redirect::Close)
          end
          tags = out_tags.lines.map(&.strip).reject(&.empty?)
          tags = tags.reject { |t| t == curr_tag || t == "latest" }
          if prev = tags.first?
            return prev
          end
        rescue
        end

        return found_tags.sort.last? if !found_tags.empty?

        if m = curr_tag.match(/^(.*-dev)(\d+)$/)
          prefix = m[1]
          num = m[2].to_i?
          return "#{prefix}#{num - 1}" if num && num > 1
        end

        nil
      end

      def self.scan_history(
        search_dirs : Array(Path),
        rel_prefix : String = ""
      ) : Tuple(Array(HtmlGenerator::HistoryEntry), Array(HtmlGenerator::ComparisonEntry))
        history = [] of HtmlGenerator::HistoryEntry
        comparisons = [] of HtmlGenerator::ComparisonEntry
        seen_tags = Set(String).new

        search_dirs.each do |dir|
          next unless Dir.exists?(dir)
          Dir.glob(dir.to_s.gsub('\\', '/') + "/benchmarks_*.xml").each do |xml_path|
            base = File.basename(xml_path, ".xml")
            next if base == "benchmarks_latest"
            tag_name = base.sub(/^benchmarks_/, "")
            next if seen_tags.includes?(tag_name)
            seen_tags << tag_name

            begin
              meta, metrics = XmlHandler.parse_xml(File.read(xml_path))
              speedups = metrics.map(&.speedup).reject { |s| s <= 0.0 }
              geo = speedups.empty? ? nil : XmlHandler.calculate_geomean(speedups).round(1)
              ver = meta["version"]? || Lapis::VERSION
              godot_v = meta["godot"]? || tag_name
              t_stamp = meta["timestamp"]?
              total_t = meta["total_ms"]?.try(&.to_f?) || (metrics.all? { |m| m.gdscript_ms <= 0.0 } ? metrics.sum(&.crystal_ms) : nil)

              html_name = "report_#{tag_name}.html"
              history << HtmlGenerator::HistoryEntry.new(
                tag: tag_name,
                version: ver,
                godot_ver: godot_v,
                filename: "#{rel_prefix}#{html_name}",
                xml_filename: "#{rel_prefix}benchmarks_#{tag_name}.xml",
                speedup: geo,
                timestamp: t_stamp,
                total_ms: total_t
              )
            rescue
            end
          end

          Dir.glob(dir.to_s.gsub('\\', '/') + "/comparison_*_to_*.html").each do |html_path|
            filename = File.basename(html_path)
            if m = filename.match(/^comparison_(.+)_to_(.+)\.html$/)
              p_tag = m[1]
              c_tag = m[2]
              comparisons << HtmlGenerator::ComparisonEntry.new(
                prev_tag: p_tag,
                curr_tag: c_tag,
                filename: "#{rel_prefix}#{filename}"
              )
            end
          end
        end

        history.sort_by!(&.tag).reverse!
        {history, comparisons}
      end
    end
  end
end
