require "../core/env"
require "../core/logger"
require "../core/process_runner"
require "./install_addon"
require "file_utils"
require "option_parser"
require "yaml"
require "semantic_version"

module Lapis
  module Commands
    module ShardManager
      module VersionMatcher
        def self.parse_version(v_str : String) : SemanticVersion?
          clean = v_str.strip.lchop('v')
          parts = clean.split('.')
          while parts.size < 3
            parts << "0"
          end
          SemanticVersion.parse(parts[0..2].join('.'))
        rescue
          nil
        end

        def self.satisfies?(version_str : String, requirement : String) : Bool
          v = parse_version(version_str)
          return true unless v

          req = requirement.strip
          if req.starts_with?("~>")
            base_str = req.sub(/^~>\s*/, "")
            base_parts = base_str.lchop('v').split('.')
            base_v = parse_version(base_str)
            return false unless base_v
            if base_parts.size == 2
              v >= base_v && v.major == base_v.major
            else
              v >= base_v && v.major == base_v.major && v.minor == base_v.minor
            end
          elsif req.starts_with?(">=")
            target = parse_version(req.sub(/^>=\s*/, ""))
            target ? v >= target : false
          elsif req.starts_with?(">")
            target = parse_version(req.sub(/^>\s*/, ""))
            target ? v > target : false
          elsif req.starts_with?("<=")
            target = parse_version(req.sub(/^<=\s*/, ""))
            target ? v <= target : false
          elsif req.starts_with?("<")
            target = parse_version(req.sub(/^<\s*/, ""))
            target ? v < target : false
          elsif req.starts_with?("=")
            target = parse_version(req.sub(/^=\s*/, ""))
            target ? v == target : false
          else
            target = parse_version(req)
            target ? v == target : false
          end
        end

        def self.matches?(requirement : String, version_str : String) : Bool
          satisfies?(version_str, requirement)
        end

        def self.highest_compatible(requirements : Array(String), candidates : Array(String)) : String?
          sorted = candidates.compact_map do |c|
            if v = parse_version(c)
              {v, c}
            else
              nil
            end
          end.sort_by { |v, _c| v }.reverse

          sorted.each do |v, orig|
            compatible = requirements.all? { |req| satisfies?(orig, req) }
            return orig if compatible
          end
          nil
        end
      end

      module SectionHelper
        def self.update_entry(content : String, section_name : String, item_name : String, entry_block : String) : String
          lines = content.lines
          sec_idx = -1
          next_sec_idx = -1

          lines.each_with_index do |l, idx|
            if l =~ /^#{Regex.escape(section_name)}:\s*$/
              sec_idx = idx
            elsif sec_idx >= 0 && next_sec_idx == -1 && l =~ /^[a-zA-Z0-9_-]+:\s*$/
              next_sec_idx = idx
            end
          end

          entry_lines = entry_block.lines.map(&.rstrip).reject(&.empty?)
          if first = entry_lines.first?
            unless first.starts_with?("  ")
              entry_lines = entry_lines.map { |l| "  #{l}" }
            end
          end

          if sec_idx == -1
            return content.rstrip + "\n\n#{section_name}:\n" + entry_lines.join("\n") + "\n"
          end

          end_idx = (next_sec_idx == -1) ? lines.size : next_sec_idx
          sec_lines = lines[sec_idx...end_idx]

          item_start = -1
          item_end = -1
          sec_lines.each_with_index do |l, idx|
            next if idx == 0
            if l =~ /^  #{Regex.escape(item_name)}:\s*$/
              item_start = idx
            elsif item_start >= 0 && item_end == -1 && (l =~ /^  [a-zA-Z0-9_-]+:\s*$/ || l =~ /^[a-zA-Z0-9_-]+:\s*$/)
              item_end = idx
            end
          end

          if item_start >= 0
            item_end = sec_lines.size if item_end == -1
            sec_lines.delete_at(item_start, item_end - item_start)
            entry_lines.reverse_each { |nl| sec_lines.insert(item_start, nl) }
          else
            insert_pos = sec_lines.size
            while insert_pos > 1 && sec_lines[insert_pos - 1].strip.empty?
              insert_pos -= 1
            end
            entry_lines.reverse_each { |nl| sec_lines.insert(insert_pos, nl) }
          end

          result_lines = lines[0...sec_idx] + sec_lines + lines[end_idx..-1]
          result_lines.join("\n").rstrip + "\n"
        end

        def self.remove_entry(content : String, section_name : String, item_name : String) : String
          lines = content.lines
          sec_idx = -1
          next_sec_idx = -1

          lines.each_with_index do |l, idx|
            if l =~ /^#{Regex.escape(section_name)}:\s*$/
              sec_idx = idx
            elsif sec_idx >= 0 && next_sec_idx == -1 && l =~ /^[a-zA-Z0-9_-]+:\s*$/
              next_sec_idx = idx
            end
          end

          return content if sec_idx == -1

          end_idx = (next_sec_idx == -1) ? lines.size : next_sec_idx
          sec_lines = lines[sec_idx...end_idx]

          item_start = -1
          item_end = -1
          sec_lines.each_with_index do |l, idx|
            next if idx == 0
            if l =~ /^  #{Regex.escape(item_name)}:\s*$/
              item_start = idx
            elsif item_start >= 0 && item_end == -1 && (l =~ /^  [a-zA-Z0-9_-]+:\s*$/ || l =~ /^[a-zA-Z0-9_-]+:\s*$/)
              item_end = idx
            end
          end

          return content if item_start == -1
          item_end = sec_lines.size if item_end == -1

          sec_lines.delete_at(item_start, item_end - item_start)
          result_lines = lines[0...sec_idx] + sec_lines + lines[end_idx..-1]
          result_lines.join("\n").rstrip + "\n"
        end
      end

      record AddonRequirement,
        name : String,
        provider : Symbol,
        source : String,
        version : String? = nil,
        branch : String? = nil,
        tag : String? = nil,
        requester : String = "project"

      record ResolvedAddon,
        name : String,
        provider : Symbol,
        source : String,
        version : String?,
        branch : String?,
        tag : String?,
        all_requesters : Array(String)

      class AddonNegotiator
        def self.negotiate(requirements : Array(AddonRequirement)) : Tuple(Bool, Hash(String, ResolvedAddon), Array(String))
          grouped = Hash(String, Array(AddonRequirement)).new
          requirements.each do |req|
            grouped[req.name] ||= [] of AddonRequirement
            grouped[req.name] << req
          end
          negotiate(grouped)
        end

        def self.negotiate(requirements : Hash(String, Array(AddonRequirement))) : Tuple(Bool, Hash(String, ResolvedAddon), Array(String))
          resolved = Hash(String, ResolvedAddon).new
          errors = [] of String

          requirements.each do |name, reqs|
            first = reqs.first
            providers = reqs.map(&.provider).uniq
            if providers.size > 1
              errors << "Addon '#{name}' has conflicting provider types: #{providers.join(", ")}"
              next
            end

            requesters = reqs.map(&.requester)
            versions = reqs.compact_map(&.version).uniq

            resolved_ver : String? = nil

            if versions.empty?
              branch = reqs.compact_map(&.branch).first?
              tag = reqs.compact_map(&.tag).first?
              resolved[name] = ResolvedAddon.new(name, first.provider, first.source, nil, branch, tag, requesters)
            elsif versions.size == 1
              resolved_ver = versions.first
              resolved[name] = ResolvedAddon.new(name, first.provider, first.source, resolved_ver, nil, nil, requesters)
            else
              candidates = versions.compact_map do |v_req|
                VersionMatcher.parse_version(v_req.sub(/^[~><=\s]+/, ""))
              end.sort.reverse

              valid_candidate = candidates.find do |cand|
                cand_str = cand.to_s
                versions.all? { |req| VersionMatcher.satisfies?(cand_str, req) }
              end

              if valid_candidate
                resolved_ver = valid_candidate.to_s
                resolved[name] = ResolvedAddon.new(name, first.provider, first.source, resolved_ver, nil, nil, requesters)
              else
                errors << "Version conflict for addon '#{name}': incompatible constraints #{versions.inspect} requested by #{requesters.join(", ")}"
              end
            end
          end

          {errors.empty?, resolved, errors}
        end

        def self.negotiate_project_addons(project_dir : Path) : Tuple(Bool, Hash(String, ResolvedAddon), Array(String))
          root_shard = project_dir.join("shard.yml")
          all_reqs = Hash(String, Array(AddonRequirement)).new

          # 1. Read root shard addons
          if File.exists?(root_shard)
            root_addons = ShardManager.read_addons(root_shard)
            root_addons.each do |name, req|
              all_reqs[name] ||= [] of AddonRequirement
              all_reqs[name] << req
            end
          end

          # 2. Read installed addons' shard.yml
          addons_dir = project_dir.join("addons")
          if Dir.exists?(addons_dir)
            Dir.each_child(addons_dir) do |addon_child|
              addon_shard = addons_dir.join(addon_child, "shard.yml")
              if File.exists?(addon_shard)
                nested_addons = ShardManager.read_addons(addon_shard)
                nested_addons.each do |name, req|
                  all_reqs[name] ||= [] of AddonRequirement
                  req_with_parent = AddonRequirement.new(
                    name: req.name,
                    provider: req.provider,
                    source: req.source,
                    version: req.version,
                    branch: req.branch,
                    tag: req.tag,
                    requester: "addon:#{addon_child}"
                  )
                  all_reqs[name] << req_with_parent
                end
              end

              # Check and eliminate any nested duplicates inside addons/<parent>/addons/<child>
              nested_addons_sub = addons_dir.join(addon_child, "addons")
              if Dir.exists?(nested_addons_sub)
                Dir.each_child(nested_addons_sub) do |nested_sub|
                  Core::Logger.warn("Notice: Removing nested duplicate addon '#{nested_sub}' from inside '#{addon_child}/addons/'...")
                  FileUtils.rm_rf(nested_addons_sub.join(nested_sub))
                end
                FileUtils.rmdir(nested_addons_sub) rescue nil
              end
            end
          end

          negotiate(all_reqs)
        end
      end

      # Formats a dependency entry block for shard.yml
      def self.format_dependency_entry(
        name : String,
        spec : InstallAddon::AddonSpec,
        branch : String? = nil,
        tag : String? = nil,
        version : String? = nil,
        path_override : String? = nil,
        project_dir : Path = Path.new(Dir.current),
      ) : String
        if path_val = path_override || (spec.type == :local_dir ? spec.path : nil)
          rel_p = if path_val.starts_with?(".")
                    path_val.gsub('\\', '/')
                  else
                    p = Path.new(path_val).expand
                    if Dir.exists?(project_dir)
                      p.relative_to(project_dir.expand).to_s.gsub('\\', '/')
                    else
                      path_val.gsub('\\', '/')
                    end
                  end
          rel_p = "./#{rel_p}" unless rel_p.starts_with?(".")
          <<-YAML
  #{name}:
    path: #{rel_p}
YAML
        elsif spec.type == :gitlab
          owner = spec.owner || "gitlab-org"
          repo = spec.repo || name
          if version
            clean_ver = version.starts_with?("~>") || version.starts_with?(">=") || version.starts_with?("=") ? version : "~> #{version.lchop("v")}"
            <<-YAML
  #{name}:
    gitlab: #{owner}/#{repo}
    version: "#{clean_ver}"
YAML
          else
            ref_val = branch || tag || spec.tag || "main"
            <<-YAML
  #{name}:
    gitlab: #{owner}/#{repo}
    branch: #{ref_val}
YAML
          end
        elsif spec.type == :git
          git_url = spec.path || spec.raw.sub(/^git:/, "")
          ref_val = branch || tag || spec.tag || "master"
          <<-YAML
  #{name}:
    git: #{git_url}
    branch: #{ref_val}
YAML
        elsif version
          owner = spec.owner || "sol-vin"
          repo = spec.repo || name
          clean_ver = version.starts_with?("~>") || version.starts_with?(">=") || version.starts_with?("=") ? version : "~> #{version.lchop("v")}"
          <<-YAML
  #{name}:
    github: #{owner}/#{repo}
    version: "#{clean_ver}"
YAML
        else
          owner = spec.owner || "sol-vin"
          repo = spec.repo || name
          ref_val = branch || tag || spec.tag || "master"
          <<-YAML
  #{name}:
    github: #{owner}/#{repo}
    branch: #{ref_val}
YAML
        end
      end

      # Formats an addon entry block for shard.yml under addons:
      def self.format_addon_entry(
        name : String,
        spec : InstallAddon::AddonSpec,
        branch : String? = nil,
        tag : String? = nil,
        version : String? = nil,
        path_override : String? = nil,
        project_dir : Path = Path.new(Dir.current),
      ) : String
        format_dependency_entry(name, spec, branch, tag, version, path_override, project_dir)
      end

      # Adds or updates a dependency in shard.yml
      def self.add_dependency(
        project_dir : Path,
        name : String,
        spec : InstallAddon::AddonSpec,
        branch : String? = nil,
        tag : String? = nil,
        version : String? = nil,
        path_override : String? = nil,
      ) : Bool
        shard_path = project_dir.join("shard.yml")
        unless File.exists?(shard_path)
          FileUtils.mkdir_p(project_dir)
          proj_name = project_dir.basename.underscore
          default_content = <<-YAML
name: #{proj_name}
version: 0.1.0

dependencies:
YAML
          File.write(shard_path, default_content)
          Core::Logger.info("Initialized minimal shard.yml in #{project_dir}")
        end

        content = File.read(shard_path)
        dep_block = format_dependency_entry(name, spec, branch, tag, version, path_override, project_dir)
        new_content = SectionHelper.update_entry(content, "dependencies", name, dep_block)

        File.write(shard_path, new_content)
        Core::Logger.success("Added dependency '#{name}' to #{shard_path}")
        true
      rescue ex
        Core::Logger.error("Failed to add dependency to shard.yml: #{ex.message}")
        false
      end

      # Adds or updates an addon in shard.yml under addons:
      def self.add_addon(
        project_dir : Path,
        name : String,
        spec : InstallAddon::AddonSpec,
        branch : String? = nil,
        tag : String? = nil,
        version : String? = nil,
        path_override : String? = nil,
      ) : Bool
        shard_path = project_dir.join("shard.yml")
        unless File.exists?(shard_path)
          FileUtils.mkdir_p(project_dir)
          proj_name = project_dir.basename.underscore
          default_content = <<-YAML
name: #{proj_name}
version: 0.1.0

dependencies:

addons:
YAML
          File.write(shard_path, default_content)
          Core::Logger.info("Initialized minimal shard.yml in #{project_dir}")
        end

        content = File.read(shard_path)
        addon_block = format_addon_entry(name, spec, branch, tag, version, path_override, project_dir)
        new_content = SectionHelper.update_entry(content, "addons", name, addon_block)

        File.write(shard_path, new_content)
        Core::Logger.success("Tracked addon '#{name}' in #{shard_path} under 'addons:'")
        true
      rescue ex
        Core::Logger.error("Failed to add addon to shard.yml: #{ex.message}")
        false
      end

      # Removes a dependency from shard.yml
      def self.remove_dependency(project_dir : Path, name : String) : Bool
        shard_path = project_dir.join("shard.yml")
        return true unless File.exists?(shard_path)

        content = File.read(shard_path)
        new_content = SectionHelper.remove_entry(content, "dependencies", name)
        File.write(shard_path, new_content)
        Core::Logger.success("Removed dependency '#{name}' from #{shard_path}")
        true
      rescue ex
        Core::Logger.error("Failed to remove dependency from shard.yml: #{ex.message}")
        false
      end

      # Removes an addon from shard.yml under addons:
      def self.remove_addon(project_dir : Path, name : String) : Bool
        shard_path = project_dir.join("shard.yml")
        return true unless File.exists?(shard_path)

        content = File.read(shard_path)
        new_content = SectionHelper.remove_entry(content, "addons", name)
        File.write(shard_path, new_content)
        Core::Logger.success("Removed addon '#{name}' from #{shard_path}")
        true
      rescue ex
        Core::Logger.error("Failed to remove addon from shard.yml: #{ex.message}")
        false
      end

      # Parses addons declared in shard.yml
      def self.read_addons(shard_path : Path) : Hash(String, AddonRequirement)
        result = Hash(String, AddonRequirement).new
        begin
          return result unless File.exists?(shard_path)

          content = File.read(shard_path)
          parsed = YAML.parse(content) rescue nil
          return result unless parsed

          if addons_node = parsed["addons"]?
            if hash = addons_node.as_h?
              hash.each do |k_any, v_any|
                name = k_any.as_s? || next
                provider = :github
                source = ""
                ver : String? = nil
                branch : String? = nil
                tag : String? = nil

                if val_h = v_any.as_h?
                  if gh = val_h["github"]?.try(&.as_s?)
                    provider = :github
                    source = gh
                  elsif gl = val_h["gitlab"]?.try(&.as_s?)
                    provider = :gitlab
                    source = gl
                  elsif git = val_h["git"]?.try(&.as_s?)
                    provider = :git
                    source = git
                  elsif p = val_h["path"]?.try(&.as_s?)
                    provider = :path
                    source = p
                  end
                  ver = val_h["version"]?.try(&.as_s?)
                  branch = val_h["branch"]?.try(&.as_s?)
                  tag = val_h["tag"]?.try(&.as_s?)
                elsif str = v_any.as_s?
                  source = str
                end

                result[name] = AddonRequirement.new(
                  name: name,
                  provider: provider,
                  source: source,
                  version: ver,
                  branch: branch,
                  tag: tag,
                  requester: shard_path.basename
                )
              end
            end
          end

          result
        rescue ex
          Core::Logger.warn("Failed to parse addons from #{shard_path}: #{ex.message}")
          result
        end
      end

      # Executes shards install in target directory
      def self.run_shards_install(project_dir : Path) : Bool
        if shards_bin = Process.find_executable("shards")
          Core::Logger.step("Shards", "Resolving Crystal dependencies in #{project_dir}...")
          res = Core::ProcessRunner.capture(shards_bin, ["install"], chdir: project_dir.to_s)
          if res[:status].success?
            Core::Logger.success("Dependencies resolved successfully with 'shards install'.")
            return true
          end

          combined_output = (res[:error] + "\n" + res[:output]).strip

          # Auto-healing: Handle ambiguous dependency sources (e.g. local path vs git URL)
          if combined_output.includes?("has ambiguous sources")
            if match = combined_output.match(/shard name \(([a-zA-Z0-9_-]+)\) has ambiguous sources/)
              conflicted_shard = match[1]
              shard_path = project_dir.join("shard.yml")
              if File.exists?(shard_path)
                shard_content = File.read(shard_path)
                # Check if shard.yml has a local path for the conflicted shard
                if path_match = shard_content.match(/^[ \t]*#{Regex.escape(conflicted_shard)}:[^\r\n]*\r?\n[ \t]+path:[ \t]*([^\r\n]+)/m)
                  local_path = path_match[1].strip.gsub(/["']/, "")
                  Core::Logger.info("Resolving ambiguous dependency source for '#{conflicted_shard}' via shard.override.yml...")

                  override_path = project_dir.join("shard.override.yml")
                  override_content = if File.exists?(override_path)
                                       File.read(override_path)
                                     else
                                       "dependencies:\n"
                                     end

                  unless override_content.includes?("#{conflicted_shard}:")
                    override_content = override_content.rstrip + "\n  #{conflicted_shard}:\n    path: #{local_path}\n"
                    File.write(override_path, override_content)
                  end

                  # Ensure shard.override.yml is in .gitignore
                  gitignore_path = project_dir.join(".gitignore")
                  if File.exists?(gitignore_path)
                    gi_content = File.read(gitignore_path)
                    unless gi_content.includes?("shard.override.yml")
                      File.write(gitignore_path, gi_content.rstrip + "\nshard.override.yml\n")
                    end
                  end

                  # Retry shards install with the override in place
                  retry_res = Core::ProcessRunner.capture(shards_bin, ["install"], chdir: project_dir.to_s)
                  if retry_res[:status].success?
                    Core::Logger.success("Dependencies resolved successfully with local override.")
                    return true
                  else
                    combined_output = (retry_res[:error] + "\n" + retry_res[:output]).strip
                  end
                end
              end
            end
          end

          err_line = combined_output.lines.find { |l| l.strip.starts_with?("E:") || l.strip.starts_with?("Error") } || combined_output.lines.last? || "Unknown error"
          Core::Logger.warn("Notice: 'shards install' exited with #{res[:status].exit_code}: #{err_line.strip}")
          return false
        else
          Core::Logger.info("Tip: 'shards' executable not found in PATH. Run 'shards install' manually once installed.")
          true
        end
      rescue ex
        Core::Logger.warn("Failed to run shards install: #{ex.message}")
        false
      end

      # Executes shards prune in target directory
      def self.run_shards_prune(project_dir : Path) : Bool
        if shards_bin = Process.find_executable("shards")
          Core::Logger.step("Shards", "Pruning unused dependencies in #{project_dir}...")
          res = Core::ProcessRunner.capture(shards_bin, ["prune"], chdir: project_dir.to_s)
          return res[:status].success?
        else
          # Fallback: remove lib/<name> directly
          lib_dir = project_dir.join("lib")
          return true unless Dir.exists?(lib_dir)
          true
        end
      rescue
        false
      end

      # CLI entry point for `lapis install shard`
      def self.install(args : Array(String)) : Int32
        if args.empty? || args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        project_dir_arg : String? = nil
        branch_arg : String? = nil
        tag_arg : String? = nil
        version_arg : String? = nil
        path_arg : String? = nil
        skip_shards = false

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis install shard <specifier> [options]"
          opts.on("-p DIR", "--project=DIR", "Target project directory (default: .)") { |d| project_dir_arg = d }
          opts.on("-b BRANCH", "--branch=BRANCH", "Git branch to track") { |b| branch_arg = b }
          opts.on("-t TAG", "--tag=TAG", "Git tag to track") { |t| tag_arg = t }
          opts.on("-v VER", "--version=VER", "Shard version requirement (e.g. ~> 0.1.0)") { |v| version_arg = v }
          opts.on("--path=DIR", "Local relative path for dependency") { |d| path_arg = d }
          opts.on("--skip-shards", "Skip running 'shards install'") { skip_shards = true }
          opts.on("-h", "--help", "Show help screen") { print_help; exit 0 }
        end

        remaining = [] of String
        parser.unknown_args { |r| remaining = r }
        parser.parse(args)

        if remaining.empty?
          Core::Logger.error("Missing shard specifier (e.g. 'github:sol-vin/crshader' or 'sol-vin/crshader').")
          return 1
        end

        spec_raw = remaining[0]
        spec = InstallAddon.parse_spec(spec_raw)
        name = spec.name

        target_project = if (p = project_dir_arg) && !p.empty?
                           Path.new(p).expand
                         else
                           Path.new(Dir.current).expand
                         end

        Core::Logger.step("Install:Shard", "Adding shard '#{name}' to #{target_project}...")

        ok = add_dependency(
          target_project,
          name,
          spec,
          branch: branch_arg,
          tag: tag_arg,
          version: version_arg,
          path_override: path_arg,
        )

        unless ok
          return 1
        end

        shards_ok = true
        unless skip_shards
          shards_ok = run_shards_install(target_project)
        end

        if shards_ok
          puts "\n\e[32m✓ Shard '#{name}' installed into shard.yml!\e[0m"
          puts "  In your Crystal code, use: \e[1;36mrequire \"#{name}\"\e[0m"
          0
        else
          puts "\n\e[33m⚠ Shard '#{name}' added to shard.yml, but dependency resolution failed.\e[0m"
          puts "  Run 'shards install' manually in #{target_project} to inspect errors."
          1
        end
      end

      # CLI entry point for `lapis uninstall shard`
      def self.uninstall(args : Array(String)) : Int32
        if args.empty? || args.includes?("-h") || args.includes?("--help")
          puts "Usage: lapis uninstall shard <name> [options]"
          return 0
        end

        project_dir_arg : String? = nil
        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis uninstall shard <name> [options]"
          opts.on("-p DIR", "--project=DIR", "Target project directory (default: .)") { |d| project_dir_arg = d }
          opts.on("-h", "--help", "Show help screen") { puts opts; exit 0 }
        end

        remaining = [] of String
        parser.unknown_args { |r| remaining = r }
        parser.parse(args)

        if remaining.empty?
          Core::Logger.error("Missing shard name to uninstall.")
          return 1
        end

        name = remaining[0]
        # Clean name if given as github:owner/name or owner/name
        if name.includes?('/')
          name = name.split('/').last
        end

        target_project = if (p = project_dir_arg) && !p.empty?
                           Path.new(p).expand
                         else
                           Path.new(Dir.current).expand
                         end

        Core::Logger.step("Uninstall:Shard", "Removing shard '#{name}' from #{target_project}...")
        remove_dependency(target_project, name)
        run_shards_prune(target_project)

        # Also remove lib/<name> directly if still exists
        lib_addon = target_project.join("lib", name)
        if Dir.exists?(lib_addon)
          FileUtils.rm_rf(lib_addon)
        end

        puts "\n\e[32m✓ Shard '#{name}' uninstalled from shard.yml!\e[0m"
        0
      end

      # Structure representing an existing dependency parsed from shard.yml
      struct ShardDepInfo
        property name : String
        property source_type : String
        property source : String
        property version_req : String
        property installed : Bool

        def initialize(@name, @source_type, @source, @version_req, @installed)
        end
      end

      # Parses dependencies declared in shard.yml
      def self.read_dependencies(shard_path : Path) : Array(ShardDepInfo)
        result = [] of ShardDepInfo
        return result unless File.exists?(shard_path)

        content = File.read(shard_path)
        parsed = YAML.parse(content) rescue nil
        return result unless parsed

        proj_dir = shard_path.parent
        lib_dir = proj_dir.join("lib")

        if deps_node = parsed["dependencies"]?
          if deps_map = deps_node.as_h?
            deps_map.each do |k_node, v_node|
              name = k_node.as_s? || k_node.to_s
              installed = Dir.exists?(lib_dir.join(name))

              source_type = "unknown"
              source = "-"
              version_req = "*"

              if v_hash = v_node.as_h?
                if gh = v_hash["github"]?.try(&.as_s?)
                  source_type = "github"
                  source = gh
                elsif gl = v_hash["gitlab"]?.try(&.as_s?)
                  source_type = "gitlab"
                  source = gl
                elsif git = v_hash["git"]?.try(&.as_s?)
                  source_type = "git"
                  source = git
                elsif path = v_hash["path"]?.try(&.as_s?)
                  source_type = "path"
                  source = path
                end

                if ver = v_hash["version"]?.try(&.as_s?)
                  version_req = ver
                elsif br = v_hash["branch"]?.try(&.as_s?)
                  version_req = "branch: #{br}"
                elsif tag = v_hash["tag"]?.try(&.as_s?)
                  version_req = "tag: #{tag}"
                elsif commit = v_hash["commit"]?.try(&.as_s?)
                  version_req = "commit: #{commit[0...7]}"
                end
              elsif v_str = v_node.as_s?
                version_req = v_str
              end

              result << ShardDepInfo.new(name, source_type, source, version_req, installed)
            end
          end
        end

        result
      end

      # CLI entry point for `lapis shard list`
      def self.list(args : Array(String)) : Int32
        project_dir_arg : String? = nil
        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis shard list [options]"
          opts.on("-p DIR", "--project=DIR", "Target project directory (default: .)") { |d| project_dir_arg = d }
          opts.on("-h", "--help", "Show help screen") { puts opts; exit 0 }
        end
        parser.parse(args)

        target_project = if (p = project_dir_arg) && !p.empty?
                           Path.new(p).expand
                         else
                           Path.new(Dir.current).expand
                         end

        shard_path = target_project.join("shard.yml")
        unless File.exists?(shard_path)
          Core::Logger.error("No shard.yml found in #{target_project}")
          return 1
        end

        deps = read_dependencies(shard_path)
        if deps.empty?
          Core::Logger.info("No shard dependencies declared in #{shard_path}")
          return 0
        end

        puts
        puts Opal.style.bold.fg(:cyan).render("  📦 Crystal Shard Dependencies (#{target_project.basename}):")
        puts

        tbl = Opal::UI::Table.new(
          headers: ["Dependency", "Source Type", "Source / Repository", "Version / Branch", "Status"],
          header_fg: :cyan
        )

        deps.each do |dep|
          status_str = dep.installed ? Opal.style.fg(:green).render("Installed (lib/)") : Opal.style.fg(:yellow).render("Missing (run 'shards install')")
          tbl.row([
            Opal.style.bold.render(dep.name),
            dep.source_type,
            dep.source,
            dep.version_req,
            status_str
          ])
        end

        cols = begin
          [Opal::Terminal.default_driver.size[0] - 2, 80].max
        rescue
          100
        end

        puts tbl.to_print_s(width: cols)
        puts
        0
      end

      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Shard Dependency Manager ===\e[0m

Usage:
  lapis shard list [options]
  lapis shard install <specifier> [options]
  lapis shard uninstall <name> [options]
  lapis shard prune [options]
  lapis install shard <specifier> [options]
  lapis uninstall shard <name> [options]

Subcommands:
  list, ls                        List declared dependencies and installation status
  install, add <specifier>        Add and install a dependency
  uninstall, remove <name>        Remove a dependency and prune lib/
  prune                           Prune unused dependencies from lib/

Specifiers:
  github:owner/repo[@branch|tag]  Install from GitHub repository
  owner/repo[@branch|tag]         Shorthand GitHub repository
  path/to/local/shard             Install local shard path dependency

Options:
  -p, --project=DIR               Target project directory (default: .)
  -b, --branch=BRANCH             Git branch to track (default: master)
  -t, --tag=TAG                   Git tag to track
  -v, --version=VER               Version constraint (e.g. ~> 0.1.0)
  --path=DIR                      Local path override for dependency
  --skip-shards                   Do not execute 'shards install'
  -h, --help                      Show this help screen

Examples:
  lapis shard list
  lapis shard install github:sol-vin/carbon
  lapis shard install sol-vin/crshader@v0.1.0
  lapis shard uninstall crshader
  lapis shard prune
HELP
      end
    end
  end
end
