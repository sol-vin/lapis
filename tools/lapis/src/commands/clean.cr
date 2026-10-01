require "../core/env"
require "../core/logger"
require "file_utils"
require "option_parser"
require "opal"

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
  -s, --shadows         Only purge stale Windows shadow DLLs (*_loaded_*.dll/pdb)
  --docs                Also purge generated HTML documentation in docs/
  --all                 Purge build artifacts, shadow DLLs, docs/, .godot/ and .crystal/ caches
  -h, --help            Show this help screen

Examples:
  lapis clean
  lapis clean --shadows
  lapis clean --dry-run
  lapis clean --all
HELP
      end

      # Cleans only shadow DLLs and PDBs (*_loaded_*) from the target directory
      private def self.clean_shadow_dlls(dir : Path, dry_run : Bool, tracker : CleanTracker) : Void
        return unless Dir.exists?(dir)
        Dir.each_child(dir) do |child|
          if child.includes?("_loaded_")
            p = dir.join(child)
            if File.file?(p)
              size = File.size(p) rescue 0_i64
              tracker.record(p, size)
              File.delete(p) unless dry_run rescue nil
            end
          end
        end
      end

      private def self.clean_bin_dir(dir : Path, dry_run : Bool, tracker : CleanTracker, shadows_only : Bool = false) : Void
        return unless Dir.exists?(dir)
        Dir.each_child(dir) do |child|
          next if preserved_files.includes?(child)
          p = dir.join(child)
          begin
            if File.file?(p)
              if shadows_only
                next unless child.includes?("_loaded_")
              end
              size = File.size(p) rescue 0_i64
              tracker.record(p, size)
              File.delete(p) unless dry_run rescue nil
            elsif Dir.exists?(p)
              next if shadows_only
              # Critical safety invariant: Never recursively delete subprojects or git repositories (e.g. bin/crshader)
              if Dir.exists?(p.join(".git")) || File.exists?(p.join(".git")) || File.exists?(p.join(".gitkeep"))
                Core::Logger.debug("Safely preserved subproject/repository directory: #{p}")
                next
              end
              size = dir_size(p)
              tracker.record(p, size, is_dir: true)
              FileUtils.rm_rf(p) unless dry_run rescue nil
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
        record Item, path : Path, size : Int64, is_dir : Bool
        getter items_count = 0
        getter bytes_reclaimed = 0_i64
        getter items = [] of Item
        property? dry_run = false

        def initialize(@dry_run : Bool)
        end

        def record(path : Path, size : Int64, is_dir : Bool = false)
          @items_count += 1
          @bytes_reclaimed += size
          @items << Item.new(path, size, is_dir)
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
        shadows_only = args.includes?("-s") || args.includes?("--shadows")
        clean_docs = purge_all || args.includes?("--docs")

        root = Core::Env::ROOT_DIR
        tracker = CleanTracker.new(dry_run)

        action_word = dry_run ? "Analyzing" : "Cleaning"
        target_desc = shadows_only ? "stale shadow DLLs (*_loaded_*)" : "build artifacts and redundant files"
        Core::Logger.step("Clean", "#{action_word} #{target_desc} across workspace...")

        # 1. Clean bin directories across root and consumers
        target_dirs = (Core::Env.collect_target_bin_dirs(root) + [
          root.join("template-addon/dist"),
        ]).uniq

        # Only clean generated documentation if explicitly requested (--docs or --all)
        if clean_docs
          target_dirs << root.join("docs")
        end

        target_dirs.each do |d|
          clean_bin_dir(d, dry_run, tracker, shadows_only: shadows_only)
        end

        # Fast exit if only shadow DLL pruning was requested
        if shadows_only
          if dry_run
            Core::Logger.info("Dry run complete: #{tracker.items_count} shadow item(s) analyzed, #{tracker.format_bytes(tracker.bytes_reclaimed)} would be reclaimed.")
          else
            reclaimed_str = tracker.format_bytes(tracker.bytes_reclaimed)
            Core::Logger.success("Shadow libraries cleaned successfully! Reclaimed #{reclaimed_str} across #{tracker.items_count} file(s).")
          end
          return 0
        end

        # 2. Prune legacy cross-project nested directories and stray flag directories (-p)
        stray_dirs = CROSS_PROJECT_NESTED_DIRS + ["-p", "bin/-p", "template/-p", "template-addon/-p"]
        stray_dirs.each do |nested_rel|
          p = root.join(nested_rel)
          if Dir.exists?(p)
            size = dir_size(p)
            tracker.record(p, size, is_dir: true)
            FileUtils.rm_rf(p) unless dry_run rescue nil
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
          if !tracker.items.empty?
            puts
            puts Opal.style.bold.fg(:cyan).render("  📦 Reclaimable Artifacts Preview:")
            tbl = Opal::UI::Table.new(headers: ["Type", "Item", "Size"], header_fg: :cyan)
            tracker.items.first(10).each do |it|
              rel = it.path.to_s.sub(root.to_s, "").lstrip("/\\")
              type_str = it.is_dir ? "DIR" : "FILE"
              tbl.row([type_str, rel, tracker.format_bytes(it.size)])
            end
            t_buf = Opal::UI::Buffer.new(80, Math.min(tracker.items.size, 10) + 4)
            tbl.render(t_buf, 2, 0, 76, Math.min(tracker.items.size, 10) + 4)
            puts t_buf.render_to_string
            if tracker.items.size > 10
              puts "    \e[2m... and #{tracker.items.size - 10} more items\e[0m"
            end
            puts
          end
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
