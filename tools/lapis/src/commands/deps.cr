require "../core/env"
require "../core/logger"
require "../core/process_runner"
require "file_utils"
require "option_parser"

module Lapis
  module Commands
    module Deps
      def self.safe_copy(src : Path | String, dst : Path | String) : Bool
        return false unless File.exists?(src)
        return true if File.expand_path(src.to_s) == File.expand_path(dst.to_s)

        begin
          dst_path = dst.to_s
          # Only copy if dst doesn't exist or size/mtime differs
          if File.exists?(dst_path)
            src_info = File.info(src)
            dst_info = File.info(dst_path)
            if src_info.size == dst_info.size && src_info.modification_time <= dst_info.modification_time
              return true
            end
          end

          dst_dir = File.dirname(dst_path)
          FileUtils.mkdir_p(dst_dir) unless Dir.exists?(dst_dir)
          FileUtils.cp(src.to_s, dst_path)
          Core::Logger.debug("Copied #{src} -> #{dst}")
          true
        rescue ex
          Core::Logger.debug("Skipped copy to #{dst} (possibly file-locked): #{ex.message}")
          false
        end
      end

      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Runtime Dependencies Manager ===\e[0m

Usage: lapis deps [options]

Options:
  -t, --target-bin=DIR  Explicit target bin directory to synchronize dependencies to
  --addon               Stage only GDExtension addon dependencies (crystal_bridge & CRT, excluding libgodot)
  -h, --help            Show this help screen

Examples:
  lapis deps
  lapis deps -t custom/game/bin
  lapis deps -t addons/my_addon/bin --addon
HELP
      end

      def self.run(args : Array(String)) : Int32
        if args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        target_bin : String? = nil
        addon_only = false
        OptionParser.parse(args) do |parser|
          parser.banner = "Usage: lapis deps [options]"
          parser.on("-t DIR", "--target-bin=DIR", "Explicit target bin directory") { |dir| target_bin = dir }
          parser.on("--addon", "Stage only GDExtension addon dependencies (crystal_bridge & CRT, excluding libgodot)") { addon_only = true }
          parser.on("-h", "--help", "Show help") { print_help; exit 0 }
        end

        if target_bin.try { |tb| tb.includes?("addons/") || tb.includes?("addons\\") }
          addon_only = true
        end

        root = Core::Env::ROOT_DIR
        bin_dirs = Core::Env.collect_target_bin_dirs(root, target_bin)
        candidate_dirs = Core::Env.candidate_runtime_dirs(root)
        is_repo = Core::Env.is_libgodot_repo?(root)

        root_bin = root.join("bin")
        if target_bin.nil? && is_repo
          FileUtils.mkdir_p(root_bin) unless Dir.exists?(root_bin)
        end

        if Core::Env.windows?
          # 1. Locate Crystal runtime DLLs (gc.dll, iconv-2.dll, pcre2-8.dll)
          runtime_dlls = ["gc.dll", "iconv-2.dll", "pcre2-8.dll"]
          runtime_dlls.each do |dll|
            src = candidate_dirs.compact_map { |d| d.join(dll) if File.exists?(d.join(dll)) }.first?

            if src
              if target_bin.nil? && is_repo
                safe_copy(src, root_bin.join(dll))
              end

              bin_dirs.each do |d|
                FileUtils.mkdir_p(d) unless Dir.exists?(d)
                safe_copy(src, d.join(dll))
              end
            end
          end

          # 2. Locate libgodot.dll (skipped for GDExtension addons)
          unless addon_only
            libgodot_src = candidate_dirs.compact_map { |d| d.join("libgodot.dll") if File.exists?(d.join("libgodot.dll")) }.first?
            unless libgodot_src
              godot_src_dll = root.join("godot-src/bin/godot.windows.template_debug.x86_64.dll")
              libgodot_src = godot_src_dll if File.exists?(godot_src_dll)
            end

            if libgodot_src
              if target_bin.nil? && is_repo
                safe_copy(libgodot_src, root_bin.join("libgodot.dll"))
              end

              bin_dirs.each do |d|
                FileUtils.mkdir_p(d) unless Dir.exists?(d)
                safe_copy(libgodot_src, d.join("libgodot.dll"))
              end
            end
          end

          # 3. Locate crystal_bridge.dll
          bridge_src = candidate_dirs.compact_map { |d| d.join(Core::Env.bridge_file) if File.exists?(d.join(Core::Env.bridge_file)) }.first?
          if bridge_src
            if target_bin.nil? && is_repo
              safe_copy(bridge_src, root_bin.join(Core::Env.bridge_file))
            end

            bin_dirs.each do |d|
              FileUtils.mkdir_p(d) unless Dir.exists?(d)
              safe_copy(bridge_src, d.join(Core::Env.bridge_file))
            end
          end

          # 4. Also libgodot.lib if present (skipped for GDExtension addons)
          unless addon_only
            libgodot_lib = candidate_dirs.compact_map { |d| d.join("libgodot.lib") if File.exists?(d.join("libgodot.lib")) }.first?
            if libgodot_lib
              if target_bin.nil? && is_repo
                safe_copy(libgodot_lib, root_bin.join("libgodot.lib"))
              end

              bin_dirs.each do |d|
                FileUtils.mkdir_p(d) unless Dir.exists?(d)
                safe_copy(libgodot_lib, d.join("libgodot.lib"))
              end
            end
          end
        else
          # Linux / macOS
          unless addon_only
            lib_file = "libgodot.#{Core::Env.dll_ext}"
            libgodot_src = candidate_dirs.compact_map { |d| d.join(lib_file) if File.exists?(d.join(lib_file)) }.first?
            if libgodot_src
              if target_bin.nil? && is_repo
                safe_copy(libgodot_src, root_bin.join(lib_file))
              end

              bin_dirs.each do |d|
                FileUtils.mkdir_p(d) unless Dir.exists?(d)
                safe_copy(libgodot_src, d.join(lib_file))
              end
            end
          end

          bridge_file = Core::Env.bridge_file
          bridge_src = candidate_dirs.compact_map { |d| d.join(bridge_file) if File.exists?(d.join(bridge_file)) }.first?
          if bridge_src
            if target_bin.nil? && is_repo
              safe_copy(bridge_src, root_bin.join(bridge_file))
            end

            bin_dirs.each do |d|
              FileUtils.mkdir_p(d) unless Dir.exists?(d)
              safe_copy(bridge_src, d.join(bridge_file))
            end
          end
        end

        Core::Logger.step("Deps", "Runtime libraries verified and synced across #{bin_dirs.size} destinations")
        0
      end
    end
  end
end
