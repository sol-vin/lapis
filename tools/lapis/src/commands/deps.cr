require "../core/env"
require "../core/logger"
require "../core/baked_file_system"
require "../core/process_runner"
require "../core/godot_finder"
require "../core/archive_security"
require "file_utils"
require "option_parser"
require "compress/zip"
require "http/client"

module Lapis
  module Commands
    module Deps
      private def self.download_file_following_redirects(url : String, dest : Path, redirects_left : Int32 = 5) : Bool
        return false if redirects_left <= 0
        HTTP::Client.get(url) do |response|
          if {301, 302, 303, 307, 308}.includes?(response.status_code)
            if loc = response.headers["Location"]?
              return download_file_following_redirects(loc, dest, redirects_left - 1)
            end
            return false
          end
          return false unless response.status_code == 200
          FileUtils.mkdir_p(dest.parent) unless Dir.exists?(dest.parent)
          File.open(dest.to_s, "wb") do |io|
            IO.copy(response.body_io, io)
          end
          true
        end
      rescue
        false
      end

      private def self.fetch_prebuilt_addon_binaries(expected_ver : String, cache_dir : Path) : Bool
        plat_suffix = if Core::Env.windows?
                        "windows-x86_64"
                      elsif Core::Env.macos?
                        "macos"
                      else
                        "linux-x86_64"
                      end
        asset_name = "godot-crystal-addon-#{plat_suffix}.zip"
        urls = [
          "https://github.com/sol-vin/lapis/releases/download/#{expected_ver}/#{asset_name}",
          "https://github.com/sol-vin/lapis/releases/latest/download/#{asset_name}",
        ].uniq

        FileUtils.mkdir_p(cache_dir) unless Dir.exists?(cache_dir)
        tmp_zip = cache_dir.join("addon_dl_#{Process.pid}_#{Time.utc.to_unix_ms}.zip")
        begin
          downloaded = urls.any? do |u|
            Core::Logger.step("Deps", "Downloading prebuilt GDExtension runtime (#{asset_name})...")
            if download_file_following_redirects(u, tmp_zip) && File.exists?(tmp_zip) && File.size(tmp_zip) > 10_000
              true
            else
              File.delete(tmp_zip) if File.exists?(tmp_zip)
              false
            end
          end
          return false unless downloaded && File.exists?(tmp_zip)

          extracted = 0
          File.open(tmp_zip.to_s, "rb") do |f|
            Compress::Zip::Reader.open(f) do |zip|
              zip.each_entry do |entry|
                val = Core::ArchiveSecurity.validate_entry_path(entry.filename, entry.dir?)
                return false unless val.valid?
                next if val.skip? || val.is_dir?
                norm = val.clean_path
                next unless norm.includes?("crystal_integration/bin/")
                sub = norm.split("crystal_integration/bin/", 2)[1]
                next if sub.empty? || sub.includes?('/')
                next unless Core::ArchiveSecurity.valid_single_name?(sub)
                dest_f = cache_dir.join(sub)
                File.open(dest_f.to_s, "wb") do |out_io|
                  IO.copy(entry.io, out_io)
                end
                File.chmod(dest_f.to_s, 0o755) unless Core::Env.windows?
                extracted += 1
              end
            end
          end
          extracted > 0
        rescue
          false
        ensure
          File.delete(tmp_zip) if File.exists?(tmp_zip)
        end
      end

      private def self.compile_bridge_fallback(proj_dir : Path, dest_bridge : Path) : Bool
        bridge_cpp = [
          proj_dir.join("lib/lapis/src/bridge/crystal_bridge.cpp"),
          Core::Env::ROOT_DIR.join("src/bridge/crystal_bridge.cpp"),
        ].find { |p| File.exists?(p) }
        return false unless bridge_cpp

        FileUtils.mkdir_p(dest_bridge.parent) unless Dir.exists?(dest_bridge.parent)
        if cxx = (Process.find_executable("g++") || Process.find_executable("clang++"))
          Core::Logger.step("Deps", "Compiling GDExtension bridge (#{dest_bridge.basename}) from embedded C++ source...")
          args = if Core::Env.macos?
                   ["-dynamiclib", "-std=c++17", "-O2", bridge_cpp.to_s, "-o", dest_bridge.to_s]
                 elsif Core::Env.windows?
                   ["-shared", "-std=c++17", "-O2", "-static-libgcc", "-static-libstdc++", bridge_cpp.to_s, "-o", dest_bridge.to_s]
                 else
                   ["-shared", "-fPIC", "-std=c++17", "-O2", bridge_cpp.to_s, "-o", dest_bridge.to_s]
                 end
          status = Core::ProcessRunner.run(cxx, args)
          return status.success? && File.exists?(dest_bridge) && File.size(dest_bridge) > 0
        elsif Core::Env.windows? && (cl = (Process.find_executable("cl.exe") || Process.find_executable("cl")))
          Core::Logger.step("Deps", "Compiling GDExtension bridge (#{dest_bridge.basename}) via MSVC...")
          status = Core::ProcessRunner.run(cl, ["/nologo", "/std:c++17", "/O2", "/EHsc", "/LD", bridge_cpp.to_s, "/Fe:#{dest_bridge}"], chdir: dest_bridge.parent.to_s)
          return status.success? && File.exists?(dest_bridge) && File.size(dest_bridge) > 0
        end
        false
      rescue
        false
      end

      private def self.compile_plugin_fallback(proj_dir : Path, dest_plugin : Path) : Bool
        plugin_cr = [
          proj_dir.join("lib/lapis/src/editor/plugin.cr"),
          Core::Env::ROOT_DIR.join("src/editor/plugin.cr"),
        ].find { |p| File.exists?(p) }
        return false unless plugin_cr
        return false unless Process.find_executable("crystal")

        lapis_src = plugin_cr.parent.parent
        lib_dir = proj_dir.join("lib")
        std_cpath = Core::ProcessRunner.capture("crystal", ["env", "CRYSTAL_PATH"])[:output].strip
        cpath = [lapis_src.to_s, lib_dir.to_s, std_cpath].reject(&.empty?).uniq.join(Core::Env.path_sep)

        FileUtils.mkdir_p(dest_plugin.parent) unless Dir.exists?(dest_plugin.parent)
        Core::Logger.step("Deps", "Compiling Godot editor integration plugin (#{dest_plugin.basename})...")
        cmd_args = ["build", plugin_cr.to_s, "-o", dest_plugin.to_s, "--link-flags", Core::Env.link_flags, "-Dlibgodot_addon", "-Deditor"]
        cmd_args << "--single-module" if Core::Env.linux?
        status = Core::ProcessRunner.run("crystal", cmd_args, env: {"CRYSTAL_PATH" => cpath}, chdir: proj_dir.to_s)
        status.success? && File.exists?(dest_plugin) && File.size(dest_plugin) > 0
      rescue
        false
      end

      # Ensures crystal_bridge.<ext> and (when need_plugin is true) plugin.<ext> plus CRT DLLs
      # are available on the host and staged into the standalone project's bin/ and addons/ directories.
      def self.ensure_bridge_and_plugin(project_dir : Path, need_plugin : Bool = true) : Void
        proj = project_dir.expand
        return if Core::Env.is_libgodot_repo?(proj)

        bridge_file = Core::Env.bridge_file
        plugin_file = Core::Env.plugin_file
        has_ci_addon = Dir.exists?(proj.join("addons/crystal_integration"))
        effective_need_plugin = need_plugin && has_ci_addon

        cand_dirs = Core::Env.candidate_runtime_dirs(proj)
        bridge_src = cand_dirs.compact_map { |d| d.join(bridge_file) if File.exists?(d.join(bridge_file)) }.first?
        plugin_src = cand_dirs.compact_map { |d| d.join(plugin_file) if File.exists?(d.join(plugin_file)) }.first?

        expected_ver = Core::GodotFinder.expected_version(proj.to_s)
        cache_dir = Core::Env.user_runtime_cache_dir(expected_ver)
        allow_auto = ENV["LAPIS_NO_AUTO_GODOT"]? != "1" && ENV["LAPIS_OFFLINE"]? != "1"

        if (bridge_src.nil? || (effective_need_plugin && plugin_src.nil?)) && allow_auto
          if fetch_prebuilt_addon_binaries(expected_ver, cache_dir)
            cand_dirs = Core::Env.candidate_runtime_dirs(proj)
            bridge_src ||= cand_dirs.compact_map { |d| d.join(bridge_file) if File.exists?(d.join(bridge_file)) }.first?
            plugin_src ||= cand_dirs.compact_map { |d| d.join(plugin_file) if File.exists?(d.join(plugin_file)) }.first?
          end
        end

        if bridge_src.nil? && ENV["LAPIS_NO_AUTO_GODOT"]? != "1"
          cached_bridge = cache_dir.join(bridge_file)
          if compile_bridge_fallback(proj, cached_bridge)
            bridge_src = cached_bridge
          end
        end

        if effective_need_plugin && plugin_src.nil? && ENV["LAPIS_NO_AUTO_GODOT"]? != "1"
          cached_plugin = cache_dir.join(plugin_file)
          if compile_plugin_fallback(proj, cached_plugin)
            plugin_src = cached_plugin
          end
        end

        proj_bin = proj.join("bin")
        FileUtils.mkdir_p(proj_bin) unless Dir.exists?(proj_bin)
        File.write(proj_bin.join(".gdignore"), "") unless File.exists?(proj_bin.join(".gdignore"))

        if bs = bridge_src
          safe_copy(bs, proj_bin.join(bridge_file))
          if has_ci_addon
            ci_bin = proj.join("addons/crystal_integration/bin")
            FileUtils.mkdir_p(ci_bin) unless Dir.exists?(ci_bin)
            safe_copy(bs, ci_bin.join(bridge_file))
          end

          addons_parent = proj.join("addons")
          if Dir.exists?(addons_parent)
            Dir.each_child(addons_parent) do |sub_name|
              next if sub_name == "crystal_integration"
              sub_dir = addons_parent.join(sub_name)
              next unless Dir.exists?(sub_dir)
              gdexts = Dir.glob(sub_dir.join("**/*.gdextension").to_s.gsub('\\', '/'))
              if gdexts.any? { |gf| (File.read(gf) rescue "").includes?("crystal_bridge") }
                sub_bin = sub_dir.join("bin")
                FileUtils.mkdir_p(sub_bin) unless Dir.exists?(sub_bin)
                safe_copy(bs, sub_bin.join(bridge_file))
              end
            end
          end
        end

        if effective_need_plugin && (ps = plugin_src)
          ci_bin = proj.join("addons/crystal_integration/bin")
          FileUtils.mkdir_p(ci_bin) unless Dir.exists?(ci_bin)
          safe_copy(ps, ci_bin.join(plugin_file))
          safe_copy(ps, proj_bin.join(plugin_file))
        end
      end

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
        proj_dir = Core::Env.find_project_dir((tb = target_bin) ? Path.new(tb).expand : root) || root
        bin_dirs = Core::Env.collect_target_bin_dirs(root, target_bin)
        candidate_dirs = (Core::Env.candidate_runtime_dirs(proj_dir) + Core::Env.candidate_runtime_dirs(root)).uniq
        is_repo = Core::Env.is_libgodot_repo?(root)

        root_bin = root.join("bin")
        if target_bin.nil? && is_repo
          FileUtils.mkdir_p(root_bin) unless Dir.exists?(root_bin)
        end

        if Core::Env.windows?
          # 1. Locate Crystal runtime DLLs (gc.dll, iconv-2.dll, pcre2-8.dll) & companion stdlib DLLs (zlib, OpenSSL)
          runtime_dlls = ["gc.dll", "iconv-2.dll", "pcre2-8.dll", "zlib1.dll", "libcrypto-3-x64.dll", "libssl-3-x64.dll"]
          candidate_dirs.each do |c_dir|
            next unless Dir.exists?(c_dir)
            Dir.each_child(c_dir) do |fn|
              lc = fn.downcase
              if (lc.starts_with?("libcrypto-") || lc.starts_with?("libssl-") || lc.starts_with?("zlib")) && lc.ends_with?(".dll")
                runtime_dlls << fn unless runtime_dlls.includes?(fn)
              end
            end
          end

          runtime_dlls.each do |dll|
            src = candidate_dirs.compact_map { |d| d.join(dll) if File.exists?(d.join(dll)) }.first?

            if src
              if target_bin.nil? && is_repo && ["gc.dll", "iconv-2.dll", "pcre2-8.dll"].includes?(dll)
                safe_copy(src, root_bin.join(dll))
              end

              bin_dirs.each do |d|
                FileUtils.mkdir_p(d) unless Dir.exists?(d)
                safe_copy(src, d.join(dll))
              end
            end
          end

          # 1b. Stage LibVLC runtime DLLs (libvlc.dll, libvlccore.dll) when project uses Emerald
          uses_emerald = Dir.exists?(proj_dir.join("addons/emerald")) ||
                         Dir.exists?(proj_dir.join("lib/emerald")) ||
                         (File.exists?(proj_dir.join("shard.yml")) && (File.read(proj_dir.join("shard.yml")) rescue "").includes?("emerald"))
          if uses_emerald
            vlc_dirs = [] of Path
            if (env_vlc = ENV["VLC_PATH"]?) && !env_vlc.empty?
              vlc_dirs << Path.new(env_vlc)
            end
            vlc_dirs << Path.new("C:\\Program Files\\VideoLAN\\VLC")
            vlc_dirs << Path.new("C:\\Program Files (x86)\\VideoLAN\\VLC")
            vlc_dirs.concat(candidate_dirs)

            ["libvlc.dll", "libvlccore.dll"].each do |vlc_dll|
              if vlc_src = vlc_dirs.compact_map { |vd| vd.join(vlc_dll) if File.exists?(vd.join(vlc_dll)) }.first?
                bin_dirs.each do |d|
                  FileUtils.mkdir_p(d) unless Dir.exists?(d)
                  safe_copy(vlc_src, d.join(vlc_dll))
                end
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

        # Ensure lib/lapis engine bindings exist for the project
        if File.exists?(proj_dir.join("shard.yml")) && !Dir.exists?(proj_dir.join("lib/lapis/src")) && !Core::Env.is_libgodot_repo?(proj_dir)
          if Core::BakedFileSystem.files_with_prefix("src").size > 0
            Core::Logger.step("Deps", "Extracting embedded Lapis engine library into #{proj_dir.basename}/lib/lapis...")
            Core::BakedFileSystem.extract_engine_lib(proj_dir.join("lib/lapis"))
          end
        end

        Core::Logger.step("Deps", "Runtime libraries verified and synced across #{bin_dirs.size} destinations")
        0
      end
    end
  end
end
