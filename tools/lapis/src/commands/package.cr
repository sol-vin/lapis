require "../core/env"
require "../core/logger"
require "../core/process_runner"
require "../core/godot_finder"
require "./build"
require "./sync"
require "./deps"
require "compress/zip"
require "digest/sha256"
require "file_utils"
require "option_parser"

module Lapis
  module Commands
    module Package
      # Recursively zip a directory into a .zip file
      def self.zip_directory(
        source_dir : Path,
        zip_path : Path,
        strip_prefix : Path? = nil,
        exclude_patterns : Array(String) = [] of String
      )
        FileUtils.mkdir_p(zip_path.parent) unless Dir.exists?(zip_path.parent)
        File.delete(zip_path) if File.exists?(zip_path)

        prefix = strip_prefix || source_dir
        pattern = source_dir.to_s.gsub('\\', '/') + "/**/*"

        File.open(zip_path.to_s, "w") do |file|
          Compress::Zip::Writer.open(file) do |zip|
            Dir.glob(pattern).each do |item|
              next if Dir.exists?(item)

              item_path = Path.new(item).expand
              next if item_path == zip_path.expand
              next if item_path.extension == ".zip"

              rel_path = Path.new(item).relative_to(prefix).to_s.gsub('\\', '/')
              if exclude_patterns.any? { |p| rel_path.includes?(p) || rel_path.starts_with?(p) || rel_path.ends_with?(p) }
                next
              end

              File.open(item) do |io|
                zip.add(rel_path, io)
              end
            end
          end
        end

        Core::Logger.success("Packaged archive: #{zip_path.basename} (#{File.size(zip_path)} bytes)")
      end

      # Calculate SHA256 checksum of a file
      def self.sha256_file(path : Path) : String
        Digest::SHA256.hexdigest(File.read(path.to_s))
      end

      def self.safe_copy(src : Path, dst : Path)
        return unless File.exists?(src)
        return if src.expand == dst.expand
        FileUtils.mkdir_p(dst.parent) unless Dir.exists?(dst.parent)
        begin
          FileUtils.cp(src, dst)
        rescue
          # File might be locked
        end
      end

      # Embeds a Godot PCK directly into an executable binary using Godot's GDPC footer format.
      def self.embed_pck_in_executable(exe_path : Path, pck_path : Path, output_path : Path) : Bool
        return false unless File.exists?(exe_path) && File.exists?(pck_path)
        pck_size = File.size(pck_path)

        File.open(output_path.to_s, "wb") do |out_f|
          File.open(exe_path.to_s, "rb") do |in_exe|
            IO.copy(in_exe, out_f)
          end
          File.open(pck_path.to_s, "rb") do |in_pck|
            IO.copy(in_pck, out_f)
          end

          # Godot 4.x PCK footer:
          # 8 bytes: pck_size (UInt64 little-endian, size of PCK data excluding 12-byte footer)
          # 4 bytes: magic 'GDPC' (0x43504447 little-endian)
          magic = 0x43504447_u32

          io_bytes = Bytes.new(12)
          IO::ByteFormat::LittleEndian.encode(pck_size.to_u64, io_bytes[0, 8])
          IO::ByteFormat::LittleEndian.encode(magic, io_bytes[8, 4])
          out_f.write(io_bytes)
        end
        File.chmod(output_path, 0o755) unless Core::Env.windows?
        true
      rescue ex
        Core::Logger.warn("Could not embed PCK into executable: #{ex.message}")
        false
      end

      def self.package_template(root : Path, out_path : Path?, bundle_binaries : Bool = false) : Int32
        template_dir = root.join("template")
        zip_file = out_path || root.join("bin/template-project.zip")

        Core::Logger.step("Package", "Packaging starter template project...")
        Core::Env.purge_foreign_binaries(template_dir)
        excludes = [
          ".godot", ".git", ".uid", "~", "crash_dump", "test_ext.log", "template_ext.log",
          ".tmp", ".log", "shard.lock",
          "template/", "test/", "performance/", "template-addon/"
        ]
        unless bundle_binaries
          excludes << "bin/"
          excludes << "/bin/"
          excludes << "\\bin\\"
          excludes << "lib/"
          excludes << "dist/"
          excludes << ".pdb"
        end

        zip_directory(
          template_dir,
          zip_file,
          exclude_patterns: excludes
        )
        0
      end

      def self.package_template_addon(root : Path, out_path : Path?, bundle_binaries : Bool = false) : Int32
        addon_dir = root.join("template-addon")
        zip_file = out_path || root.join("bin/template-addon-project.zip")

        Core::Logger.step("Package", "Packaging addon starter template...")
        Core::Env.purge_foreign_binaries(addon_dir)
        excludes = [
          ".godot", ".git", ".uid", "~", "crash_dump", ".log", ".tmp", "shard.lock",
          "template/", "test/", "performance/", "template-addon/"
        ]
        unless bundle_binaries
          excludes << "bin/"
          excludes << "/bin/"
          excludes << "\\bin\\"
          excludes << "lib/"
          excludes << "dist/"
          excludes << ".pdb"
        end

        zip_directory(
          addon_dir,
          zip_file,
          exclude_patterns: excludes
        )
        0
      end

      def self.package_addon(
        root : Path,
        out_path : Path?,
        name : String? = nil,
        project_path : Path? = nil,
        platform : String? = nil
      ) : Int32
        base = project_path || root
        addon_name = name || "crystal_integration"
        addon_dir = base.join("addons/#{addon_name}")

        plat = platform.try(&.downcase) || Core::Env.current_platform
        default_zip = if plat && !plat.empty?
          base.join(name ? "dist/#{addon_name}-#{plat}.zip" : "bin/godot-crystal-addon-#{plat}.zip")
        else
          base.join(name ? "dist/#{addon_name}.zip" : "bin/godot-crystal-addon.zip")
        end
        zip_file = out_path || default_zip

        Core::Logger.step("Package", "Packaging #{addon_name} addon for #{plat}...")

        if plat && !plat.empty?
          stage_dir = root.join("scratch/addon_stage_#{plat}")
          FileUtils.rm_rf(stage_dir) if Dir.exists?(stage_dir)
          dest_addon = stage_dir.join("addons/#{addon_name}")
          FileUtils.mkdir_p(dest_addon)

          # Copy base addon files
          if Dir.exists?(addon_dir)
            Dir.each_child(addon_dir) do |child|
              next if child == "bin" || child.starts_with?(".") || child.ends_with?(".log")
              src_child = addon_dir.join(child)
              if File.file?(src_child)
                safe_copy(src_child, dest_addon.join(child))
              elsif Dir.exists?(src_child)
                FileUtils.cp_r(src_child.to_s, dest_addon.join(child).to_s)
              end
            end
          end

          dest_bin = dest_addon.join("bin")
          FileUtils.mkdir_p(dest_bin)

          # Bundle platform-specific lapis executable!
          lapis_candidates = [
            root.join("bin/lapis#{plat == "windows" ? ".exe" : ""}"),
            base.join("bin/lapis#{plat == "windows" ? ".exe" : ""}"),
          ]
          if (exe = Process.executable_path)
            lapis_candidates << Path.new(exe)
          end
          if lapis_found = lapis_candidates.find { |p| File.exists?(p) }
            safe_copy(lapis_found, dest_bin.join("lapis#{plat == "windows" ? ".exe" : ""}"))
            File.chmod(dest_bin.join("lapis"), 0o755) if plat != "windows" && File.exists?(dest_bin.join("lapis"))
          end

          # Bundle platform-specific plugin and bridge libraries
          src_bins = [addon_dir.join("bin"), root.join("bin"), base.join("bin")]
          case plat
          when "windows"
            ["crystal_bridge.dll", "plugin.dll", "gc.dll", "iconv-2.dll", "pcre2-8.dll", "libgodot.dll"].each do |lib_file|
              src = src_bins.compact_map { |b| b.join(lib_file) if File.exists?(b.join(lib_file)) }.first?
              safe_copy(src, dest_bin.join(lib_file)) if src
            end
          when "linux"
            ["crystal_bridge.so", "plugin.so", "libgodot.so"].each do |lib_file|
              src = src_bins.compact_map { |b| b.join(lib_file) if File.exists?(b.join(lib_file)) }.first?
              safe_copy(src, dest_bin.join(lib_file)) if src
            end
          when "macos"
            ["crystal_bridge.dylib", "plugin.dylib", "libgodot.dylib"].each do |lib_file|
              src = src_bins.compact_map { |b| b.join(lib_file) if File.exists?(b.join(lib_file)) }.first?
              safe_copy(src, dest_bin.join(lib_file)) if src
            end
          when "android"
            android_arm = addon_dir.join("bin/android/arm64-v8a")
            if Dir.exists?(android_arm)
              FileUtils.mkdir_p(dest_bin.join("android/arm64-v8a"))
              FileUtils.cp_r(android_arm.to_s, dest_bin.join("android").to_s)
            end
          end

          Core::Env.purge_foreign_binaries(dest_bin)
          zip_directory(
            dest_addon,
            zip_file,
            strip_prefix: stage_dir,
            exclude_patterns: [".godot", "~", "_loaded_", ".log"]
          )
          FileUtils.rm_rf(stage_dir) if Dir.exists?(stage_dir)
        else
          zip_directory(
            addon_dir,
            zip_file,
            strip_prefix: base,
            exclude_patterns: [".godot", "~", "_loaded_", ".log"]
          )
        end
        0
      end

      def self.package_lapis(root : Path, out_path : Path?, platform_name : String? = nil, release : Bool = false) : Int32
        plat = platform_name || (Core::Env.windows? ? "windows" : (Core::Env.macos? ? "macos" : "linux"))
        default_name = Core::Env.windows? ? "lapis-windows-x86_64.zip" : (Core::Env.macos? ? "lapis-macos.zip" : "lapis-linux-x86_64.tar.gz")
        dest_archive = out_path || root.join("bin/#{default_name}")

        Core::Logger.step("Package", "Packaging Lapis CLI toolchain for #{plat}...")
        stage_dir = root.join("scratch/lapis-#{plat}-stage")
        FileUtils.rm_rf(stage_dir) if Dir.exists?(stage_dir)
        FileUtils.mkdir_p(stage_dir)

        # Locate lapis executable
        lapis_exe = root.join("bin/lapis#{Core::Env.exe_ext}")
        lapis_exe = Path.new(Process.executable_path.not_nil!) if !File.exists?(lapis_exe) && Process.executable_path

        if File.exists?(lapis_exe)
          safe_copy(lapis_exe, stage_dir.join("lapis#{Core::Env.exe_ext}"))
          File.chmod(stage_dir.join("lapis#{Core::Env.exe_ext}"), 0o755) unless Core::Env.windows?
        else
          Core::Logger.warn("Lapis executable not found at #{lapis_exe}")
        end

        # Include bundled addon if available
        addon_src = root.join("addons/crystal_integration")
        if Dir.exists?(addon_src)
          stage_addon = stage_dir.join("addons/crystal_integration")
          FileUtils.mkdir_p(stage_addon)
          FileUtils.cp_r(addon_src.to_s, stage_addon.parent.to_s)
          Core::Env.purge_foreign_binaries(stage_addon)
        end

        # Include docs and license
        ["README.md", "LICENSE", "shard.yml"].each do |f|
          safe_copy(root.join(f), stage_dir.join(f))
        end

        if dest_archive.to_s.ends_with?(".tar.gz") || dest_archive.to_s.ends_with?(".tgz")
          FileUtils.mkdir_p(dest_archive.parent) unless Dir.exists?(dest_archive.parent)
          File.delete(dest_archive) if File.exists?(dest_archive)
          status = Core::ProcessRunner.run("tar", ["-czf", dest_archive.to_s, "-C", stage_dir.to_s, "."])
          unless status.success?
            dest_zip = Path.new(dest_archive.to_s.sub(/\.tar\.gz$/, ".zip"))
            zip_directory(stage_dir, dest_zip)
          end
        else
          zip_directory(stage_dir, dest_archive)
        end

        FileUtils.rm_rf(stage_dir) if Dir.exists?(stage_dir)
        Core::Logger.success("Packaged Lapis toolchain: #{dest_archive.basename}")
        0
      end

      def self.package_deb(root : Path, out_path : Path?, version : String? = nil, arch : String = "amd64") : Int32
        unless Core::Env.linux?
          Core::Logger.error("Target 'deb' is only available on Linux (Debian/Ubuntu). Cannot package Debian (.deb) on #{Core::Env.current_platform}.")
          return 1
        end

        pkg_ver = version || Lapis::VERSION
        pkg_ver = pkg_ver.lstrip('v')
        deb_control_ver = if pkg_ver.empty? || !pkg_ver[0].ascii_number?
          "#{Lapis::VERSION}+#{pkg_ver}"
        else
          pkg_ver
        end
        deb_file = out_path || root.join("bin/lapis_#{pkg_ver}_#{arch}.deb")

        Core::Logger.step("Package", "Packaging Debian package for Lapis v#{deb_control_ver} (#{arch})...")
        stage_dir = root.join("scratch/deb_stage_lapis_#{pkg_ver}")
        FileUtils.rm_rf(stage_dir) if Dir.exists?(stage_dir)
        FileUtils.mkdir_p(stage_dir.join("DEBIAN"))
        FileUtils.mkdir_p(stage_dir.join("usr/bin"))
        FileUtils.mkdir_p(stage_dir.join("usr/share/lapis"))
        FileUtils.mkdir_p(stage_dir.join("usr/share/doc/lapis"))

        control_content = <<-CONTROL
Package: lapis
Version: #{deb_control_ver}
Section: devel
Priority: optional
Architecture: #{arch}
Depends: crystal, lldb
Recommends: make, git, g++ | clang
Maintainer: LibGodot Crystal Contributors <https://github.com/sol-vin/lapis>
Homepage: https://github.com/sol-vin/lapis
Description: Lapis: Unified Crystal Engine Toolchain for Godot
 Lapis provides unified project management, compilation, GDExtension bindings,
 testing, and packaging for Godot games developed with Crystal.
CONTROL
        File.write(stage_dir.join("DEBIAN/control"), control_content.strip + "\n")

        lapis_src = root.join("bin/lapis")
        lapis_src = Path.new(Process.executable_path.not_nil!) if !File.exists?(lapis_src) && Process.executable_path
        if File.exists?(lapis_src)
          dest_bin = stage_dir.join("usr/bin/lapis")
          safe_copy(lapis_src, dest_bin)
          File.chmod(dest_bin, 0o755) unless Core::Env.windows?
        else
          Core::Logger.warn("Lapis Linux binary not found at #{lapis_src}")
        end

        addon_src = root.join("addons/crystal_integration")
        if Dir.exists?(addon_src)
          FileUtils.cp_r(addon_src.to_s, stage_dir.join("usr/share/lapis/addons").to_s)
          Core::Env.purge_foreign_binaries(stage_dir)
        end

        ["README.md", "LICENSE"].each do |doc|
          safe_copy(root.join(doc), stage_dir.join("usr/share/doc/lapis/#{doc}"))
        end

        FileUtils.mkdir_p(deb_file.parent) unless Dir.exists?(deb_file.parent)
        File.delete(deb_file) if File.exists?(deb_file)

        dpkg_deb = Process.find_executable("dpkg-deb")
        if dpkg_deb
          status = Core::ProcessRunner.run("dpkg-deb", ["--build", "--root-owner-group", stage_dir.to_s, deb_file.to_s])
          if status.success?
            Core::Logger.success("Successfully generated Debian package: #{deb_file.basename} (#{File.size(deb_file)} bytes)")
            FileUtils.rm_rf(stage_dir) if Dir.exists?(stage_dir)
            return 0
          else
            Core::Logger.error("dpkg-deb failed to build #{deb_file.basename}")
            return 1
          end
        else
          Core::Logger.warn("dpkg-deb not found on system. Stage directory preserved at #{stage_dir}")
          return 0
        end

        FileUtils.rm_rf(stage_dir) if Dir.exists?(stage_dir)
        0
      end

      def self.find_iscc : String?
        if path = Process.find_executable("iscc") || Process.find_executable("iscc.exe")
          return path
        end

        {% if flag?(:windows) %}
          user_profile = ENV["USERPROFILE"]? || ""
          local_app_data = ENV["LOCALAPPDATA"]? || ""
          candidates = [
            "C:\\Program Files (x86)\\Inno Setup 6\\ISCC.exe",
            "C:\\Program Files\\Inno Setup 6\\ISCC.exe",
            "C:\\Program Files (x86)\\Inno Setup 7\\ISCC.exe",
            "C:\\Program Files\\Inno Setup 7\\ISCC.exe",
            "C:\\ProgramData\\chocolatey\\bin\\iscc.exe",
            File.join(local_app_data, "Programs", "Inno Setup 6", "ISCC.exe"),
            File.join(local_app_data, "Programs", "Inno Setup 7", "ISCC.exe"),
            File.join(user_profile, "scoop", "apps", "innosetup", "current", "ISCC.exe"),
          ]
          candidates.each do |cand|
            return cand if File.exists?(cand)
          end
        {% end %}
        nil
      end

      def self.package_windows_installer(
        root : Path,
        out_path : Path?,
        version : String? = nil,
        release : Bool = false
      ) : Int32
        unless Core::Env.windows?
          Core::Logger.error("Target 'windows-installer' is only available on Windows. Current platform: #{Core::Env.current_platform}.")
          return 1
        end

        pkg_ver = version || Lapis::VERSION
        pkg_ver = pkg_ver.lstrip('v')
        dest_exe = out_path || root.join("bin/windows/lapis-setup-windows-x86_64.exe")

        Core::Logger.step("Package", "Packaging Windows Installer for Lapis v#{pkg_ver}...")
        stage_dir = root.join("scratch/installer_stage")
        FileUtils.rm_rf(stage_dir) if Dir.exists?(stage_dir)
        FileUtils.mkdir_p(stage_dir)

        # 1. Stage standalone lapis.exe
        lapis_exe = root.join("bin/lapis#{Core::Env.exe_ext}")
        lapis_exe = Path.new(Process.executable_path.not_nil!) if !File.exists?(lapis_exe) && Process.executable_path
        if File.exists?(lapis_exe)
          safe_copy(lapis_exe, stage_dir.join("lapis.exe"))
        else
          Core::Logger.warn("Lapis executable not found at #{lapis_exe}")
        end

        # 2. Stage temporary install_deps.ps1 (used by installer in {tmp} then deleted)
        deps_script = root.join("scripts/windows/install_deps.ps1")
        if File.exists?(deps_script)
          safe_copy(deps_script, stage_dir.join("install_deps.ps1"))
        end

        # 3. Stage crystalline.exe if present (for bundling into {app}\bin)
        crystalline_candidates = [
          root.join("bin/crystalline#{Core::Env.exe_ext}"),
          root.join("scratch/crystalline/bin/crystalline#{Core::Env.exe_ext}"),
        ]
        if found_sys = Process.find_executable("crystalline")
          crystalline_candidates << Path.new(found_sys)
        end

        if crystalline_exe = crystalline_candidates.find { |p| File.exists?(p) }
          safe_copy(crystalline_exe, stage_dir.join("crystalline.exe"))
          Core::Logger.info("Staged Crystalline LSP binary (#{crystalline_exe}) for installer payload")
        end

        # 4. Stage runtime DLLs (gc.dll, pcre2-8.dll, iconv-2.dll)
        ["gc.dll", "pcre2-8.dll", "iconv-2.dll"].each do |dll|
          dll_path = root.join("bin/#{dll}")
          if File.exists?(dll_path)
            safe_copy(dll_path, stage_dir.join(dll))
            Core::Logger.info("Staged runtime dependency #{dll} for installer payload")
          end
        end

        # Stage docs and license
        ["README.md", "LICENSE"].each do |doc|
          doc_path = root.join(doc)
          safe_copy(doc_path, stage_dir.join(doc)) if File.exists?(doc_path)
        end

        # 5. Compile with Inno Setup Compiler (ISCC)
        iss_path = root.join("packaging/windows/lapis_installer.iss")
        unless File.exists?(iss_path)
          Core::Logger.error("Inno Setup script not found at #{iss_path}")
          return 1
        end

        FileUtils.mkdir_p(dest_exe.parent) unless Dir.exists?(dest_exe.parent)
        File.delete(dest_exe) if File.exists?(dest_exe)

        iscc = find_iscc
        if iscc
          Core::Logger.step("Package", "Compiling Inno Setup installer via #{iscc}...")
          out_dir = dest_exe.parent.to_s.gsub('/', '\\')
          base_name = dest_exe.basename(".exe")
          args = [
            "/DAppVersion=#{pkg_ver}",
            "/DSourceDir=#{stage_dir.to_s.gsub('/', '\\')}",
            "/DOutputDir=#{out_dir}",
            "/DOutputBaseFilename=#{base_name}",
            "/Q",
            iss_path.to_s.gsub('/', '\\'),
          ]
          status = Core::ProcessRunner.run(iscc, args)
          if status.success? && File.exists?(dest_exe)
            Core::Logger.success("Successfully generated Windows installer: #{dest_exe.basename} (#{File.size(dest_exe)} bytes)")
            FileUtils.rm_rf(stage_dir) if Dir.exists?(stage_dir)
            return 0
          else
            Core::Logger.error("Inno Setup compiler failed to build #{dest_exe.basename}")
            return 1
          end
        else
          Core::Logger.warn("Inno Setup compiler ('iscc') was not found in PATH or standard directories.")
          Core::Logger.info("Tip: Install Inno Setup via 'choco install innosetup -y' or 'winget install JRSoftware.InnoSetup' to compile.")
          Core::Logger.info("Staged installer files preserved at #{stage_dir}")
          return 0
        end
      end

      def self.package_examples(root : Path, out_path : Path?, platform_name : String? = nil) : Int32
        examples_dir = root.join("examples")
        plat = platform_name || (Core::Env.windows? ? "windows" : (Core::Env.macos? ? "macos" : "linux"))
        zip_file = out_path || root.join("bin/examples-#{plat}.zip")

        Core::Logger.step("Package", "Packaging standalone examples for #{plat}...")
        Core::Env.purge_foreign_binaries(examples_dir)
        zip_directory(
          examples_dir,
          zip_file,
          exclude_patterns: [
            ".godot", ".git", "~", "crash_dump", ".log", ".tmp", ".uid",
            "_loaded_", ".pdb", "template/", "test/", "performance/", "template-addon/"
          ]
        )
        0
      end

      def self.package_tests(root : Path, out_path : Path?, platform_name : String? = nil, release : Bool = false) : Int32
        test_dir = root.join("test")
        plat = platform_name || (Core::Env.windows? ? "windows" : (Core::Env.macos? ? "macos" : "linux"))
        zip_file = out_path || root.join("bin/test-suite-#{plat}.zip")

        Core::Logger.step("Package", "Packaging standalone test runner...")
        # First ensure standalone runner is built (generates tests.exe, tests.pck, and tests_portable.exe)
        package_game(test_dir, name: "tests", release: release, force_compile: false, portable: true)

        stage_dir = root.join("scratch/tests-#{plat}-stage")
        FileUtils.rm_rf(stage_dir) if Dir.exists?(stage_dir)
        FileUtils.mkdir_p(stage_dir)

        test_bin = test_dir.join("bin")
        if Dir.exists?(test_bin)
          Dir.each_child(test_bin) do |f|
            next if f.starts_with?("~") || f.ends_with?(".log") || f.ends_with?(".pdb") || f.ends_with?(".tmp") || f.ends_with?(".TMP") || f.ends_with?(".zip") || f == "tests_portable.exe"
            src_f = test_bin.join(f)
            if File.file?(src_f)
              safe_copy(src_f, stage_dir.join(f))
            elsif Dir.exists?(src_f) && (f == "addons" || f == ".godot")
              FileUtils.cp_r(src_f.to_s, stage_dir.join(f).to_s)
            end
          end
        end

        Core::Env.purge_foreign_binaries(stage_dir)
        zip_directory(
          stage_dir,
          zip_file,
          strip_prefix: stage_dir,
          exclude_patterns: [".pdb", ".tmp", ".log", "~", "_loaded_"]
        )
        FileUtils.rm_rf(stage_dir) if Dir.exists?(stage_dir)
        0
      end

      def self.package_perf(root : Path, out_path : Path?, platform_name : String? = nil, release : Bool = false) : Int32
        perf_dir = root.join("performance")
        return 0 unless Dir.exists?(perf_dir)

        plat = platform_name || (Core::Env.windows? ? "windows" : (Core::Env.macos? ? "macos" : "linux"))
        zip_file = out_path || root.join("bin/perf-#{plat}.zip")

        Core::Logger.step("Package", "Packaging performance stress benchmark...")
        package_game(perf_dir, name: "perf", release: release, force_compile: false, embed_pck: true)

        stage_dir = root.join("scratch/perf-#{plat}-stage")
        FileUtils.rm_rf(stage_dir) if Dir.exists?(stage_dir)
        FileUtils.mkdir_p(stage_dir)

        perf_bin = perf_dir.join("bin")
        if Dir.exists?(perf_bin)
          Dir.each_child(perf_bin) do |f|
            next if f.starts_with?("~") || f.ends_with?(".log") || f.ends_with?(".pdb") || f.ends_with?(".tmp") || f.ends_with?(".TMP") || f.ends_with?(".zip") || f == "perf_portable.exe"
            src_f = perf_bin.join(f)
            if File.file?(src_f)
              safe_copy(src_f, stage_dir.join(f))
            end
          end
        end

        Core::Env.purge_foreign_binaries(stage_dir)
        zip_directory(
          stage_dir,
          zip_file,
          strip_prefix: stage_dir,
          exclude_patterns: [".pdb", ".tmp", ".log", "~", "_loaded_"]
        )
        FileUtils.rm_rf(stage_dir) if Dir.exists?(stage_dir)
        0
      end

      def self.package_game(
        project_path : Path,
        name : String? = nil,
        release : Bool = false,
        target_dir : Path? = nil,
        force_compile : Bool = false,
        embed_pck : Bool = false,
        portable : Bool = false
      ) : Int32
        root = Core::Env::ROOT_DIR
        proj_dir = project_path.expand
        game_name = name || proj_dir.basename
        bin_dir = proj_dir.join("bin")
        FileUtils.mkdir_p(bin_dir) unless Dir.exists?(bin_dir)

        Core::Logger.step("PackageGame", "Packaging playable Godot game '#{game_name}' in #{proj_dir}...")

        # 1. Ensure .gdignore
        gdignore = bin_dir.join(".gdignore")
        File.write(gdignore, "") unless File.exists?(gdignore)

        # 2. Synchronize crystal_integration addon
        root_addon = root.join("addons/crystal_integration")
        proj_addon = proj_dir.join("addons/crystal_integration")
        if Dir.exists?(root_addon) && root_addon != proj_addon
          Sync.sync_addon_directory(root_addon, proj_addon)
        end

        # 3. Ensure .godot/extension_list.cfg
        godot_cfg_dir = proj_dir.join(".godot")
        FileUtils.mkdir_p(godot_cfg_dir) unless Dir.exists?(godot_cfg_dir)
        ext_list_file = godot_cfg_dir.join("extension_list.cfg")

        all_exts = [] of String
        proj_addons_dir = proj_dir.join("addons")
        if Dir.exists?(proj_addons_dir)
          Dir.glob(proj_addons_dir.to_s.gsub('\\', '/') + "/**/*.gdextension").each do |gdext|
            rel = Path.new(gdext).relative_to(proj_dir).to_s.gsub('\\', '/')
            all_exts << "res://#{rel}"
          end
        end
        if all_exts.empty?
          all_exts << "res://addons/crystal_integration/crystal.gdextension"
        end
        File.write(ext_list_file, all_exts.join("\n") + "\n")

        # Also copy extension_list.cfg and addons to bin_dir for standalone runner
        bin_godot = bin_dir.join(".godot")
        FileUtils.mkdir_p(bin_godot) unless Dir.exists?(bin_godot)
        safe_copy(ext_list_file, bin_godot.join("extension_list.cfg"))

        if Dir.exists?(proj_addons_dir)
          dst_addons = bin_dir.join("addons")
          FileUtils.mkdir_p(dst_addons) unless Dir.exists?(dst_addons)
          Dir.each_child(proj_addons_dir) do |addon_name|
            src_addon_dir = proj_addons_dir.join(addon_name)
            next unless Dir.exists?(src_addon_dir)
            dst_addon_dir = dst_addons.join(addon_name)
            FileUtils.mkdir_p(dst_addon_dir) unless Dir.exists?(dst_addon_dir)
            Sync.sync_addon_directory(src_addon_dir, dst_addon_dir)
            src_addon_bin = src_addon_dir.join("bin")
            if Dir.exists?(src_addon_bin)
              dst_addon_bin = dst_addon_dir.join("bin")
              FileUtils.mkdir_p(dst_addon_bin) unless Dir.exists?(dst_addon_bin)
              Dir.each_child(src_addon_bin) do |b_file|
                next if b_file.starts_with?("~") || b_file.ends_with?(".log")
                if release
                  next if b_file.starts_with?("plugin.") || b_file.ends_with?(".pdb") || b_file.ends_with?(".exp") || b_file.ends_with?(".lib")
                end
                safe_copy(src_addon_bin.join(b_file), dst_addon_bin.join(b_file))
              end
            end
            Dir.glob(src_addon_dir.to_s.gsub('\\', '/') + "/*.gdextension").each do |gdext|
              safe_copy(Path.new(gdext), dst_addon_dir.join(Path.new(gdext).basename))
            end
          end
        end

        # 4. Copy runtime dependencies
        Deps.run(["-t", bin_dir.to_s])
        bridge_src = root.join("bin/#{Core::Env.bridge_file}")
        safe_copy(bridge_src, bin_dir.join(Core::Env.bridge_file))

        # 5. Compile game library if needed
        main_cr = proj_dir.join("src/main.cr")
        game_lib = bin_dir.join(Core::Env.game_file)
        needs_compile = force_compile || !File.exists?(game_lib)
        if !needs_compile && File.exists?(main_cr)
          needs_compile = File.info(main_cr).modification_time > File.info(game_lib).modification_time
        end

        if needs_compile && File.exists?(main_cr)
          source_dir = if Dir.exists?(proj_dir.join("lib/lapis/src"))
            proj_dir.join("lib/lapis/src").to_s
          elsif Dir.exists?(root.join("src"))
            root.join("src").to_s
          else
            proj_dir.join("src").to_s
          end

          code = Build.compile_binary(
            entry_path: main_cr,
            output_path: game_lib,
            link_flags: Core::Env.link_flags,
            release: release,
            source_path: source_dir
          )
          return code if code != 0
        end

        # 6. Locate Godot and create playable executable + pack
        godot_exe = Core::GodotFinder.resolve(nil)
        if godot_exe
          named_exe = bin_dir.join("#{game_name}#{Core::Env.exe_ext}")
          safe_copy(Path.new(godot_exe), named_exe)

          # Determine export preset
          preset = if Core::Env.windows?
            "Windows Desktop"
          elsif Core::Env.macos?
            "macOS"
          else
            "Linux"
          end

          pck_file = bin_dir.join("#{game_name}.pck")
          Core::Logger.step("PackageGame", "Generating standalone project pack: #{pck_file.basename}...")
          pack_status = Core::ProcessRunner.run(
            godot_exe,
            ["--headless", "--path", proj_dir.to_s, "--export-pack", preset, pck_file.to_s]
          )

          if pack_status.success? && File.exists?(pck_file)
            if Core::Env.windows?
              safe_copy(pck_file, bin_dir.join("#{game_name}.console.pck"))
            end
            Core::Logger.success("Standalone pack generated successfully!")

            # Embed PCK directly into the binary if requested or portable
            if embed_pck || portable
              portable_exe = bin_dir.join("#{game_name}_portable#{Core::Env.exe_ext}")
              if embed_pck_in_executable(named_exe, pck_file, portable_exe)
                Core::Logger.success("Embedded PCK data into portable binary: #{portable_exe.basename}!")
              end
              if embed_pck && !portable
                # If explicitly asked to embed PCK directly into main exe
                safe_copy(portable_exe, named_exe)
              end
            end
          else
            Core::Logger.warn("Failed to generate standalone pack via --export-pack, falling back.")
          end
        end

        if portable
          portable_archive = (td = target_dir) ? td.join("#{game_name}-portable.zip") : bin_dir.join("#{game_name}-portable.zip")
          Core::Logger.step("PackageGame", "Creating portable single-directory game distribution: #{portable_archive.basename}...")
          zip_directory(bin_dir, portable_archive, strip_prefix: bin_dir, exclude_patterns: [".gdignore", ".log", "~", ".tmp", ".zip"])
          Core::Logger.success("Portable package created: #{portable_archive}!")
        end

        # 7. Copy to target_dir if requested
        if (td = target_dir)
          dest_game = td.basename == game_name ? td : td.join(game_name)
          FileUtils.mkdir_p(dest_game) unless Dir.exists?(dest_game)
          Core::Logger.step("PackageGame", "Staging game into #{dest_game}...")
          Dir.each_child(bin_dir) do |item|
            src_item = bin_dir.join(item)
            if File.file?(src_item)
              safe_copy(src_item, dest_game.join(item))
            end
          end
        end

        Core::Logger.success("Playable game '#{game_name}' packaged successfully!")
        0
      end

      def self.package_release(
        output_dir : Path,
        release : Bool = true,
        skip_tests : Bool = false,
        skip_perf : Bool = false
      ) : Int32
        root = Core::Env::ROOT_DIR
        out_dir = output_dir.expand
        FileUtils.mkdir_p(out_dir) unless Dir.exists?(out_dir)

        # Wipe staging directory before building to guarantee clean release archives
        Dir.each_child(out_dir) do |item|
          p = out_dir.join(item)
          FileUtils.rm_rf(p) rescue nil
        end

        Core::Logger.step("PackageRelease", "Packaging all release archives into #{out_dir}...")

        plat = Core::Env.windows? ? "windows" : (Core::Env.macos? ? "macos" : "linux")
        package_template(root, out_dir.join("template-project.zip"))
        package_template_addon(root, out_dir.join("template-addon-project.zip"))
        package_examples(root, out_dir.join("examples-#{plat}.zip"))
        package_addon(root, out_dir.join("godot-crystal-addon.zip"))
        package_addon(root, out_dir.join("godot-crystal-addon-#{plat}.zip"), platform: plat)
        package_lapis(root, out_dir.join(Core::Env.windows? ? "lapis-windows-x86_64.zip" : (Core::Env.macos? ? "lapis-macos.zip" : "lapis-linux-x86_64.tar.gz")), platform_name: plat, release: release)

        if Core::Env.linux? && Process.find_executable("dpkg-deb")
          package_deb(root, out_dir.join("lapis_#{Lapis::VERSION}_amd64.deb"))
        end

        if Core::Env.windows? && File.exists?(root.join("packaging/windows/lapis_installer.iss"))
          package_windows_installer(root, out_dir.join("lapis-setup-windows-x86_64.exe"), version: Lapis::VERSION, release: release)
        end

        unless skip_tests
          package_tests(root, out_dir.join("test-suite-#{plat}.zip"), platform_name: plat, release: release)
        end

        unless skip_perf
          package_perf(root, out_dir.join("perf-#{plat}.zip"), platform_name: plat, release: release)
        end

        # Compute SHA256 sums across all generated release archives
        checksum_file = out_dir.join("checksums.txt")
        lines = [] of String
        Dir.glob([out_dir.to_s.gsub('\\', '/') + "/*.zip", out_dir.to_s.gsub('\\', '/') + "/*.tar.gz", out_dir.to_s.gsub('\\', '/') + "/*.deb", out_dir.to_s.gsub('\\', '/') + "/*.exe", out_dir.to_s.gsub('\\', '/') + "/*.apk"]).flatten.uniq.sort.each do |archive|
          hash = sha256_file(Path.new(archive))
          lines << "#{hash}  #{Path.new(archive).basename}"
        end
        File.write(checksum_file, lines.join("\n") + "\n")
        File.write(out_dir.join("SHA256SUMS.txt"), lines.join("\n") + "\n")

        Core::Logger.success("Release packaging complete! Generated #{lines.size} packages.")
        0
      end

      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Release & Archive Packaging Tool ===\e[0m

Usage: lapis package <target> [options]

Targets:
  game                  Package a playable standalone Godot game (PCK + runner + DLLs)
  template              Package the starter game template into template-project.zip
  template-addon        Package the addon starter template into template-addon-project.zip
  addon                 Package the official crystal_integration addon into godot-crystal-addon.zip
  lapis                 Package standalone Lapis CLI toolchain archive (zip or tar.gz)
  deb                   Package Lapis Debian (.deb) package [Linux only]
  windows-installer     Package Windows Inno Setup installer executable (.exe) [Windows only]
  examples              Package standalone examples into examples-<platform>.zip
  tests                 Package standalone test runner into tests-<platform>.zip
  perf                  Package performance benchmark into perf-<platform>.zip
  release               Build and stage all release archives with SHA-256 checksums

Options:
  -p, --project=PATH    Target Godot project path (default: .) [game only]
  --platform=NAME       Target platform name (windows, linux, macos, android)
  -n, --name=NAME       Output executable/package name [game only]
  -t, --target-dir=DIR  Staging directory for output files
  -o, --output=PATH     Explicit output archive path (.zip, .tar.gz, .deb, or .exe)
  -v, --version=VER     Package version (for deb/installer package)
  -a, --arch=ARCH       Architecture (amd64, arm64) [deb on Linux only]
  -r, --release         Package/compile in release mode
  -f, --force           Force recompilation of game binary
  --bundle-binaries     Include compiled binaries in archive (template only)
  --skip-tests          Skip packaging tests in release target
  --skip-perf           Skip packaging perf in release target
  -h, --help            Show this help screen

Examples:
  lapis package lapis
  lapis package deb
  lapis package windows-installer
  lapis package addon --platform windows
  lapis package game -p template -n MyGame -r
  lapis package release -t bin/release_dist
HELP
      end

      def self.run(args : Array(String)) : Int32
        if args.empty? || args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        target = args[0]
        output_file : String? = nil
        target_dir : String? = nil
        project_path : String? = nil
        name : String? = nil
        platform_arg : String? = nil
        version_arg : String? = nil
        arch_arg : String? = nil
        release = false
        force = false
        embed_pck = false
        portable = false
        bundle_binaries = false
        skip_tests = false
        skip_perf = false

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis package #{target} [options]"
          opts.on("-p PATH", "--project=PATH", "Project directory path or platform") { |p| project_path = p }
          opts.on("--platform=NAME", "Target platform name (windows, linux, macos, android)") { |pl| platform_arg = pl }
          opts.on("-n NAME", "--name=NAME", "Target name") { |n| name = n }
          opts.on("-t DIR", "--target-dir=DIR", "Target staging directory") { |t| target_dir = t }
          opts.on("-o PATH", "--output=PATH", "Explicit output archive path") { |o| output_file = o }
          opts.on("-v VER", "--version=VER", "Package version") { |v| version_arg = v }
          opts.on("-a ARCH", "--arch=ARCH", "Package architecture (amd64, arm64)") { |a| arch_arg = a }
          opts.on("-r", "--release", "Compile/package with optimizations") { release = true }
          opts.on("-f", "--force", "Force compilation") { force = true }
          opts.on("--embed-pck", "Embed PCK data directly into the executable binary") { embed_pck = true }
          opts.on("--portable", "Package portable distribution with embedded PCK") { portable = true; embed_pck = true }
          opts.on("--bundle-binaries", "Include compiled binaries in archive") { bundle_binaries = true }
          opts.on("--skip-tests", "Skip tests in release") { skip_tests = true }
          opts.on("--skip-perf", "Skip perf in release") { skip_perf = true }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
        end

        parser.parse(args[1..])

        root = Core::Env::ROOT_DIR
        out_path = (of = output_file) ? Path.new(of).expand : nil
        td_path = (td = target_dir) ? Path.new(td).expand : nil

        plat = platform_arg || (project_path && ["windows", "linux", "macos", "android"].includes?(project_path.to_s.downcase) ? project_path.to_s.downcase : nil) || (Core::Env.windows? ? "windows" : (Core::Env.macos? ? "macos" : "linux"))

        case target
        when "template"
          final_out = out_path || (td_path ? td_path.join("template-project.zip") : nil)
          package_template(root, final_out, bundle_binaries)
        when "template-addon", "template_addon"
          final_out = out_path || (td_path ? td_path.join("template-addon-project.zip") : nil)
          package_template_addon(root, final_out, bundle_binaries)
        when "addon"
          proj_p = (pp = project_path) && !["windows", "linux", "macos", "android"].includes?(pp.downcase) ? Path.new(pp).expand : nil
          target_plat = platform_arg || (project_path && ["windows", "linux", "macos", "android"].includes?(project_path.to_s.downcase) ? project_path.to_s.downcase : nil)
          final_out = out_path || (td_path ? td_path.join(target_plat ? "godot-crystal-addon-#{target_plat}.zip" : "godot-crystal-addon.zip") : nil)
          package_addon(root, final_out, name: name, project_path: proj_p, platform: target_plat)
        when "lapis"
          default_archive = Core::Env.windows? ? "lapis-windows-x86_64.zip" : (Core::Env.macos? ? "lapis-macos.zip" : "lapis-linux-x86_64.tar.gz")
          final_out = out_path || (td_path ? td_path.join(default_archive) : nil)
          package_lapis(root, final_out, platform_name: plat, release: release)
        when "deb"
          unless Core::Env.linux?
            Core::Logger.error("Target 'deb' is only available on Linux (Debian/Ubuntu). Current platform: #{Core::Env.current_platform}.")
            return 1
          end
          pkg_version = version_arg || Lapis::VERSION
          pkg_arch = arch_arg || "amd64"
          final_out = out_path || (td_path ? td_path.join("lapis_#{pkg_version}_#{pkg_arch}.deb") : nil)
          package_deb(root, final_out, version: pkg_version, arch: pkg_arch.to_s)
        when "windows-installer", "windows_installer", "installer"
          unless Core::Env.windows?
            Core::Logger.error("Target 'windows-installer' is only available on Windows. Current platform: #{Core::Env.current_platform}.")
            return 1
          end
          pkg_version = version_arg || Lapis::VERSION
          final_out = out_path || (td_path ? td_path.join("lapis-setup-windows-x86_64.exe") : nil)
          package_windows_installer(root, final_out, version: pkg_version, release: release)
        when "examples"
          final_out = out_path || (td_path ? td_path.join("examples-#{plat}-x86_64.zip") : nil)
          package_examples(root, final_out)
        when "tests", "test"
          final_out = out_path || (td_path ? td_path.join("test-suite-#{plat}.zip") : nil)
          package_tests(root, final_out, platform_name: plat, release: release)
        when "perf", "performance"
          final_out = out_path || (td_path ? td_path.join("perf-#{plat}.zip") : nil)
          package_perf(root, final_out, platform_name: plat, release: release)
        when "game"
          proj_str = (pp = project_path) && !["windows", "linux", "macos", "android"].includes?(pp.downcase) ? pp : "."
          proj = Path.new(proj_str).expand
          package_game(proj, name: name, release: release, target_dir: td_path, force_compile: force, embed_pck: embed_pck, portable: portable)
        when "release", "all"
          out_dir = td_path || out_path || root.join("bin/release_dist")
          package_release(out_dir, release: release, skip_tests: skip_tests, skip_perf: skip_perf)
        else
          Core::Logger.error("Unknown packaging target: '#{target}'.")
          puts
          print_help
          1
        end
      end
    end
  end
end
