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

              rel_path = Path.new(item).relative_to(prefix).to_s.gsub('\\', '/')
              if exclude_patterns.any? { |p| rel_path.includes?(p) || rel_path.starts_with?(p) }
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
        exe_size = File.size(exe_path)

        File.open(output_path.to_s, "wb") do |out_f|
          File.open(exe_path.to_s, "rb") do |in_exe|
            IO.copy(in_exe, out_f)
          end
          File.open(pck_path.to_s, "rb") do |in_pck|
            IO.copy(in_pck, out_f)
          end

          # Godot 4.x PCK footer:
          # 8 bytes: pck_offset (UInt64 little-endian)
          # 4 bytes: magic 'GDPC' (0x43504447 little-endian)
          pck_offset = exe_size.to_u64
          magic = 0x43504447_u32

          io_bytes = Bytes.new(12)
          IO::ByteFormat::LittleEndian.encode(pck_offset, io_bytes[0, 8])
          IO::ByteFormat::LittleEndian.encode(magic, io_bytes[8, 4])
          out_f.write(io_bytes)
        end
        true
      rescue ex
        Core::Logger.warn("Could not embed PCK into executable: #{ex.message}")
        false
      end

      def self.package_template(root : Path, out_path : Path?, bundle_binaries : Bool = false) : Int32
        template_dir = root.join("template")
        zip_file = out_path || root.join("bin/template-project.zip")

        Core::Logger.step("Package", "Packaging starter template project...")
        excludes = [".godot", ".git", ".uid", "~", "crash_dump", "test_ext.log", "template_ext.log"]
        unless bundle_binaries
          excludes << "bin/"
          excludes << "bin\\"
          excludes << "lib/"
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
        excludes = [".godot", ".git", ".uid", "~", "crash_dump", ".log"]
        unless bundle_binaries
          excludes << "bin/"
          excludes << "bin\\"
          excludes << "lib/"
        end

        zip_directory(
          addon_dir,
          zip_file,
          exclude_patterns: excludes
        )
        0
      end

      def self.package_addon(root : Path, out_path : Path?, name : String? = nil, project_path : Path? = nil) : Int32
        base = project_path || root
        addon_name = name || "crystal_integration"
        addon_dir = base.join("addons/#{addon_name}")
        zip_file = out_path || base.join(name ? "dist/#{addon_name}.zip" : "bin/godot-crystal-addon.zip")

        Core::Logger.step("Package", "Packaging #{addon_name} addon...")
        zip_directory(
          addon_dir,
          zip_file,
          strip_prefix: base,
          exclude_patterns: [".godot", "~", "_loaded_", ".log"]
        )
        0
      end

      def self.package_examples(root : Path, out_path : Path?, platform_name : String? = nil) : Int32
        examples_dir = root.join("examples")
        plat = platform_name || (Core::Env.windows? ? "windows" : (Core::Env.macos? ? "macos" : "linux"))
        zip_file = out_path || root.join("bin/examples-#{plat}.zip")

        Core::Logger.step("Package", "Packaging standalone examples...")
        zip_directory(
          examples_dir,
          zip_file,
          exclude_patterns: [".godot", ".git", "~", "crash_dump", ".log"]
        )
        0
      end

      def self.package_tests(root : Path, out_path : Path?, platform_name : String? = nil, release : Bool = false) : Int32
        test_dir = root.join("test")
        plat = platform_name || (Core::Env.windows? ? "windows" : (Core::Env.macos? ? "macos" : "linux"))
        zip_file = out_path || root.join("bin/test-suite-#{plat}.zip")

        Core::Logger.step("Package", "Packaging standalone test runner...")
        # First ensure standalone runner is built
        package_game(test_dir, name: "tests", release: release, force_compile: false, embed_pck: true)

        stage_dir = root.join("scratch/tests-#{plat}-stage")
        FileUtils.rm_rf(stage_dir) if Dir.exists?(stage_dir)
        FileUtils.mkdir_p(stage_dir)

        test_bin = test_dir.join("bin")
        if Dir.exists?(test_bin)
          Dir.each_child(test_bin) do |f|
            next if f.starts_with?("~") || f.ends_with?(".log")
            src_f = test_bin.join(f)
            if File.file?(src_f)
              safe_copy(src_f, stage_dir.join(f))
            elsif Dir.exists?(src_f) && (f == "addons" || f == ".godot")
              FileUtils.cp_r(src_f.to_s, stage_dir.join(f).to_s)
            end
          end
        end

        zip_directory(
          stage_dir,
          zip_file,
          strip_prefix: stage_dir
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
            next if f.starts_with?("~") || f.ends_with?(".log")
            src_f = perf_bin.join(f)
            if File.file?(src_f)
              safe_copy(src_f, stage_dir.join(f))
            end
          end
        end

        zip_directory(
          stage_dir,
          zip_file,
          strip_prefix: stage_dir
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
              embedded_exe = bin_dir.join("#{game_name}_embedded#{Core::Env.exe_ext}")
              if embed_pck_in_executable(named_exe, pck_file, embedded_exe)
                safe_copy(embedded_exe, named_exe)
                File.delete(embedded_exe) if File.exists?(embedded_exe)
                Core::Logger.success("Embedded PCK data directly into #{named_exe.basename}!")
              end
            end
          else
            Core::Logger.warn("Failed to generate standalone pack via --export-pack, falling back.")
          end
        end

        if portable
          portable_archive = (td = target_dir) ? td.join("#{game_name}-portable.zip") : bin_dir.join("#{game_name}-portable.zip")
          Core::Logger.step("PackageGame", "Creating portable single-directory game distribution: #{portable_archive.basename}...")
          zip_directory(bin_dir, portable_archive, strip_prefix: bin_dir, exclude_patterns: [".gdignore", ".log", "~", ".tmp"])
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

        Core::Logger.step("PackageRelease", "Packaging all release archives into #{out_dir}...")

        plat = Core::Env.windows? ? "windows" : (Core::Env.macos? ? "macos" : "linux")
        package_template(root, out_dir.join("template-project.zip"))
        package_template_addon(root, out_dir.join("template-addon-project.zip"))
        package_examples(root, out_dir.join("examples-#{plat}.zip"))
        package_addon(root, out_dir.join("godot-crystal-addon.zip"))

        unless skip_tests
          package_tests(root, out_dir.join("test-suite-#{plat}.zip"), platform_name: plat, release: release)
        end

        unless skip_perf
          package_perf(root, out_dir.join("perf-#{plat}.zip"), platform_name: plat, release: release)
        end

        # Compute SHA256 sums
        checksum_file = out_dir.join("checksums.txt")
        lines = [] of String
        Dir.glob(out_dir.to_s.gsub('\\', '/') + "/*.zip").sort.each do |zip|
          hash = sha256_file(Path.new(zip))
          lines << "#{hash}  #{Path.new(zip).basename}"
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
  examples              Package standalone examples into examples-<platform>.zip
  tests                 Package standalone test runner into tests-<platform>.zip
  perf                  Package performance benchmark into perf-<platform>.zip
  release               Build and stage all release archives with SHA-256 checksums

Options:
  -p, --project=PATH    Target Godot project path (default: .) [game only]
  -n, --name=NAME       Output executable/package name [game only]
  -t, --target-dir=DIR  Staging directory for output files
  -o, --output=PATH     Explicit output archive path (.zip)
  -r, --release         Package/compile in release mode
  -f, --force           Force recompilation of game binary
  --bundle-binaries     Include compiled binaries in archive (template only)
  --skip-tests          Skip packaging tests in release target
  --skip-perf           Skip packaging perf in release target
  -h, --help            Show this help screen

Examples:
  lapis package game
  lapis package game -p template -n MyGame -r
  lapis package template
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
          opts.on("-o PATH", "--output=PATH", "Explicit output .zip path") { |o| output_file = o }
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
          final_out = out_path || (td_path ? td_path.join("godot-crystal-addon.zip") : nil)
          package_addon(root, final_out, name: name, project_path: proj_p)
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
