require "../core/env"
require "../core/logger"
require "file_utils"
require "option_parser"

module Lapis
  module Commands
    module Clean
      def self.preserved_files : Set(String)
        if Core::Env.windows?
          Set{"libgodot.dll", "libgodot.lib", "gc.dll", "iconv-2.dll", "pcre2-8.dll", ".gitkeep"}
        elsif Core::Env.macos?
          Set{"libgodot.dylib", ".gitkeep"}
        else
          Set{"libgodot.so", ".gitkeep"}
        end
      end

      # Known cross-project nested paths created by legacy scaffolding cycles
      CROSS_PROJECT_NESTED_DIRS = [
        "template/test", "template/template", "template/template-addon", "template/performance",
        "template-addon/test", "template-addon/template", "template-addon/template-addon", "template-addon/performance",
        "test/test", "test/template", "test/template-addon", "test/performance",
        "performance/test", "performance/template", "performance/template-addon", "performance/performance",
        "examples/basic_demo/test", "examples/basic_demo/template", "examples/basic_demo/template-addon", "examples/basic_demo/performance",
      ]

      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Workspace Clean Tool ===\e[0m

Usage: lapis clean [options]

Options:
  -d, --dry-run         Preview files and space to be reclaimed without deleting
  --all                 Also purge .godot/ and .crystal/ caches, scratch/, and release_dist/
  -h, --help            Show this help screen

Examples:
  lapis clean
  lapis clean --dry-run
  lapis clean --all
HELP
      end

      private def self.clean_bin_dir(dir : Path, dry_run : Bool, tracker : CleanTracker) : Void
        return unless Dir.exists?(dir)
        Dir.each_child(dir) do |child|
          next if preserved_files.includes?(child)
          p = dir.join(child)
          begin
            if File.file?(p)
              size = File.size(p)
              tracker.record(p, size)
              File.delete(p) unless dry_run
            elsif Dir.exists?(p)
              size = dir_size(p)
              tracker.record(p, size, is_dir: true)
              FileUtils.rm_rf(p) unless dry_run
            end
          rescue ex
            Core::Logger.debug("Could not delete #{p}: #{ex.message}")
          end
        end
      end

      private def self.clean_project_caches(dir : Path, dry_run : Bool, tracker : CleanTracker) : Void
        [".godot", ".crystal"].each do |cache_name|
          cache_dir = dir.join(cache_name)
          if Dir.exists?(cache_dir)
            size = dir_size(cache_dir)
            tracker.record(cache_dir, size, is_dir: true)
            FileUtils.rm_rf(cache_dir) unless dry_run rescue nil
          end
        end
      end

      private def self.dir_size(dir : Path) : Int64
        total = 0_i64
        return total unless Dir.exists?(dir)
        Dir.glob(dir.to_s.gsub('\\', '/') + "/**/*").each do |item|
          total += File.size(item) if File.file?(item) rescue 0_i64
        end
        total
      end

      class CleanTracker
        getter items_count = 0
        getter bytes_reclaimed = 0_i64
        property? dry_run = false

        def initialize(@dry_run : Bool)
        end

        def record(path : Path, size : Int64, is_dir : Bool = false)
          @items_count += 1
          @bytes_reclaimed += size
          if @dry_run
            Core::Logger.info("  [dry-run] Would remove #{is_dir ? "directory" : "file"}: #{path.basename} (#{format_bytes(size)})")
          else
            Core::Logger.debug("Removed #{path} (#{format_bytes(size)})")
          end
        end

        def format_bytes(bytes : Int64) : String
          if bytes >= 1_073_741_824_i64
            "#{(bytes.to_f / 1_073_741_824.0).round(2)} GB"
          elsif bytes >= 1_048_576_i64
            "#{(bytes.to_f / 1_048_576.0).round(2)} MB"
          elsif bytes >= 1024_i64
            "#{(bytes.to_f / 1024.0).round(2)} KB"
          else
            "#{bytes} B"
          end
        end
      end

      def self.run(args : Array(String)) : Int32
        if args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        dry_run = args.includes?("-d") || args.includes?("--dry-run")
        purge_all = args.includes?("--all")

        root = Core::Env::ROOT_DIR
        tracker = CleanTracker.new(dry_run)

        action_word = dry_run ? "Analyzing" : "Cleaning"
        Core::Logger.step("Clean", "#{action_word} build artifacts and redundant files across workspace...")

        # 1. Clean bin directories across root and consumers
        target_dirs = (Core::Env.collect_target_bin_dirs(root) + [
          root.join("template-addon/dist"),
          root.join("docs"),
        ]).uniq

        target_dirs.each do |d|
          clean_bin_dir(d, dry_run, tracker)
        end

        # 2. Prune legacy cross-project nested directories
        CROSS_PROJECT_NESTED_DIRS.each do |nested_rel|
          p = root.join(nested_rel)
          if Dir.exists?(p)
            size = dir_size(p)
            tracker.record(p, size, is_dir: true)
            FileUtils.rm_rf(p) unless dry_run
          end
        end

        # 3. Prune stray crash logs and temporary files in consumer directories
        consumer_roots = [
          root,
          root.join("test"),
          root.join("template"),
          root.join("template-addon"),
          root.join("performance"),
        ]
        examples_dir = root.join("examples")
        if Dir.exists?(examples_dir)
          Dir.each_child(examples_dir) { |c| consumer_roots << examples_dir.join(c) if Dir.exists?(examples_dir.join(c)) }
        end

        consumer_roots.each do |c_root|
          # Stray log files
          Dir.glob(c_root.to_s.gsub('\\', '/') + "/*.log").each do |log_file|
            p = Path.new(log_file)
            size = File.size(p) rescue 0_i64
            tracker.record(p, size)
            File.delete(p) unless dry_run rescue nil
          end

          # Stray temporary files
          [c_root.join("bin"), c_root.join(".godot")].each do |target_sub|
            next unless Dir.exists?(target_sub)
            Dir.each_child(target_sub) do |child|
              if child.ends_with?(".tmp") || child.ends_with?(".TMP") || child.starts_with?("~")
                p = target_sub.join(child)
                size = File.size(p) rescue 0_i64
                tracker.record(p, size)
                File.delete(p) unless dry_run rescue nil
              end
            end
          end
        end

        # 4. Purge caches and test scratch if --all is specified
        if purge_all
          action_desc = dry_run ? "Scanning .godot/.crystal caches and scratch/..." : "Purging .godot/.crystal caches and scratch/..."
          Core::Logger.step("Clean", action_desc)
          [root, root.join("test"), root.join("template"), root.join("template-addon"), root.join("performance")].each do |proj|
            clean_project_caches(proj, dry_run, tracker)
          end

          # Clean scratch test remnants
          scratch_dir = root.join("scratch")
          if Dir.exists?(scratch_dir)
            Dir.each_child(scratch_dir) do |item|
              p = scratch_dir.join(item)
              size = Dir.exists?(p) ? dir_size(p) : (File.size(p) rescue 0_i64)
              tracker.record(p, size, is_dir: Dir.exists?(p))
              if !dry_run
                FileUtils.rm_rf(p) rescue nil
              end
            end
          end

          # Clean release_dist
          dist_dir = root.join("bin/release_dist")
          if Dir.exists?(dist_dir)
            size = dir_size(dist_dir)
            tracker.record(dist_dir, size, is_dir: true)
            FileUtils.rm_rf(dist_dir) unless dry_run rescue nil
          end
        end

        if dry_run
          Core::Logger.info("Dry run complete: #{tracker.items_count} items analyzed, #{tracker.format_bytes(tracker.bytes_reclaimed)} would be reclaimed.")
        else
          reclaimed_str = tracker.format_bytes(tracker.bytes_reclaimed)
          Core::Logger.success("Workspace cleaned successfully! Reclaimed #{reclaimed_str} across #{tracker.items_count} item(s) (runtime libraries safely preserved).")
        end
        0
      end
    end
  end
end
