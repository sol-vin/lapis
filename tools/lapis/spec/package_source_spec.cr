# tools/lapis/spec/package_source_spec.cr
require "./spec_helper"
require "../src/commands/install_addon"
require "compress/zip"

private def extract_flat_zip(zip_path : Path, dest_dir : Path) : Nil
  FileUtils.mkdir_p(dest_dir)
  File.open(zip_path.to_s, "rb") do |f|
    Compress::Zip::Reader.open(f) do |zip|
      zip.each_entry do |entry|
        next if entry.dir? || entry.filename.ends_with?("/")
        out_file = dest_dir.join(entry.filename)
        FileUtils.mkdir_p(out_file.parent) unless Dir.exists?(out_file.parent)
        File.open(out_file.to_s, "wb") do |io|
          IO.copy(entry.io, io)
        end
      end
    end
  end
end

describe "Lapis Source Packaging (lapis package source)" do
  it "packages flat-root source zip excluding non-source artifacts while preserving substring-named files and dotfiles" do
    LapisSpecHelper.with_temp_dir("package_source_filter_test") do |work_dir|
      proj_dir = work_dir.join("jam_project")
      res_new = LapisSpecHelper.run_lapis(["new", "game", "jam_project", "-t", proj_dir.to_s, "--skip-godot"], chdir: work_dir)
      res_new.success?.should be_true, "Scaffold failed:\n#{res_new.all_output}"

      # Create local path addon (like succ_cr / solvin-proc in LSDJam)
      local_addon = proj_dir.join("addons/local_prop")
      FileUtils.mkdir_p(local_addon.join("src"))
      FileUtils.mkdir_p(local_addon.join("bin"))
      File.write(local_addon.join("plugin.cfg"), "[plugin]\nname=\"LocalProp\"\nscript=\"plugin.gd\"\n")
      File.write(local_addon.join("plugin.gd"), "@tool\nextends EditorPlugin\n")
      File.write(local_addon.join("shard.yml"), "name: local_prop\nversion: 0.1.0\n")
      File.write(local_addon.join("src/local_prop.cr"), "module LocalProp\n  VALUE = 42\nend\n")
      File.write(local_addon.join("bin/local_prop.dll"), "compiled_addon_binary")

      # Create pure GDScript addon named 'dialogic' (contains substring 'log') with stray bin/
      dialogic_dir = proj_dir.join("addons/dialogic")
      FileUtils.mkdir_p(dialogic_dir.join("bin"))
      File.write(dialogic_dir.join("plugin.cfg"), "[plugin]\nname=\"Dialogic\"\nscript=\"plugin.gd\"\n")
      File.write(dialogic_dir.join("plugin.gd"), "@tool\nextends EditorPlugin\n")
      File.write(dialogic_dir.join("bin/gc.dll"), "stray_dll")

      # Create compilable Crystal GDExtension addon #1 (standard src/main.cr + crystal_bridge + macOS game.dylib alias)
      diorite_dir = proj_dir.join("addons/diorite_draw")
      FileUtils.mkdir_p(diorite_dir.join("src"))
      FileUtils.mkdir_p(diorite_dir.join("bin"))
      File.write(diorite_dir.join("plugin.cfg"), "[plugin]\nname=\"DioriteDraw\"\nscript=\"plugin.gd\"\n")
      File.write(diorite_dir.join("plugin.gd"), "@tool\nextends EditorPlugin\n")
      File.write(
        diorite_dir.join("diorite_draw.gdextension"),
        "[configuration]\nentry_symbol = \"crystal_library_init\"\ncompatibility_minimum = \"4.1\"\nreloadable = true\n\n[libraries]\nwindows.debug.x86_64 = \"res://addons/diorite_draw/bin/crystal_bridge.dll\"\nlinux.debug.x86_64 = \"res://addons/diorite_draw/bin/crystal_bridge.so\"\nmacos.debug = \"res://addons/diorite_draw/bin/crystal_bridge.dylib\"\n\n[dependencies]\nmacos.debug = { \"res://addons/diorite_draw/bin/game.dylib\": \"\" }\n"
      )
      File.write(
        diorite_dir.join("src/main.cr"),
        "require \"lapis\"\n\nmodule DioriteDraw\n  TAG = \"diorite_ready\"\nend\n\nnode DioriteDebugNode < Node do\nend\n"
      )
      File.write(diorite_dir.join("bin/diorite_draw.dll"), "preexisting_addon_dll")

      # Create compilable Crystal GDExtension addon #2 (depends on diorite_draw, uses shard.yml targets: & direct .gdextension without crystal_bridge)
      fx_dir = proj_dir.join("addons/custom_fx")
      FileUtils.mkdir_p(fx_dir.join("src"))
      FileUtils.mkdir_p(fx_dir.join("bin"))
      File.write(fx_dir.join("plugin.cfg"), "[plugin]\nname=\"CustomFX\"\ndependencies=[\"diorite_draw\"]\nscript=\"plugin.gd\"\n")
      File.write(fx_dir.join("plugin.gd"), "@tool\nextends EditorPlugin\n")
      File.write(fx_dir.join("shard.yml"), "name: custom_fx\nversion: 0.1.0\ntargets:\n  custom_fx:\n    main: src/fx_entry.cr\n")
      File.write(
        fx_dir.join("custom_fx.gdextension"),
        "[configuration]\nentry_symbol = \"crystal_godot_init\"\ncompatibility_minimum = \"4.1\"\n\n[libraries]\nwindows.debug.x86_64 = \"res://addons/custom_fx/bin/custom_fx.dll\"\nlinux.debug.x86_64 = \"res://addons/custom_fx/bin/libcustom_fx.so\"\nmacos.debug = \"res://addons/custom_fx/bin/libcustom_fx.dylib\"\n"
      )
      File.write(
        fx_dir.join("src/fx_entry.cr"),
        "require \"lapis\"\nrequire \"diorite_draw\"\n\nmodule CustomFx\n  COMBINED = DioriteDraw::TAG + \"_fx\"\nend\n\nnode CustomFxNode < Node do\nend\n"
      )
      File.write(fx_dir.join("bin/custom_fx.dll"), "preexisting_fx_dll")

      # Add local_prop to shard.yml and require it in src/main.cr + spec/
      shard_yml = File.read(proj_dir.join("shard.yml"))
      shard_yml = shard_yml.sub(/dependencies:\r?\n/, "dependencies:\n  local_prop:\n    path: ./addons/local_prop\n")
      File.write(proj_dir.join("shard.yml"), shard_yml)

      # Add files whose names contain 'bin', 'log', '.git' substrings, plus _dev/ and dotfiles
      FileUtils.mkdir_p(proj_dir.join("src/core"))
      File.write(proj_dir.join("src/core/input_bindings.cr"), "module InputBindings\n  READY = true\nend\n")
      main_cr = File.read(proj_dir.join("src/main.cr"))
      File.write(proj_dir.join("src/main.cr"), "require \"local_prop\"\nrequire \"./core/input_bindings\"\n" + main_cr)

      FileUtils.mkdir_p(proj_dir.join("spec"))
      File.write(
        proj_dir.join("spec/jam_spec.cr"),
        "require \"spec\"\nrequire \"local_prop\"\nrequire \"../src/core/input_bindings\"\ndescribe \"Jam\" do\n  it \"loads local_prop and input_bindings\" do\n    LocalProp::VALUE.should eq(42)\n    InputBindings::READY.should be_true\n  end\nend\n"
      )

      File.write(proj_dir.join("logo.png"), "PNG_DATA")
      FileUtils.mkdir_p(proj_dir.join("_dev"))
      File.write(proj_dir.join("_dev/GDD.md"), "# Game Design Document\n")
      FileUtils.mkdir_p(proj_dir.join("editor"))
      File.write(proj_dir.join("editor/.gdignore"), "")
      File.write(proj_dir.join(".gitattributes"), "* text=auto\n")
      FileUtils.mkdir_p(proj_dir.join(".githooks"))
      File.write(proj_dir.join(".githooks/pre-commit"), "#!/bin/sh\n")

      # Populate non-source folders & artifacts that MUST be excluded
      FileUtils.mkdir_p(proj_dir.join(".git/objects"))
      File.write(proj_dir.join(".git/HEAD"), "ref: refs/heads/main\n")
      FileUtils.mkdir_p(proj_dir.join(".godot/imported"))
      File.write(proj_dir.join(".godot/uid_cache.bin"), "CACHE")
      FileUtils.mkdir_p(proj_dir.join("log"))
      File.write(proj_dir.join("log/editor.log"), "LOG_LINE")
      FileUtils.mkdir_p(proj_dir.join("bin/trenchbroom"))
      File.write(proj_dir.join("bin/game.dll"), "GAME_DLL")
      File.write(proj_dir.join("bin/trenchbroom/TrenchBroom.exe"), "TB_EXE")
      FileUtils.mkdir_p(proj_dir.join("addons/crystal_integration/bin"))
      File.write(proj_dir.join("addons/crystal_integration/bin/crystal_bridge.dll"), "BRIDGE_DLL")
      FileUtils.mkdir_p(proj_dir.join("scratch"))
      File.write(proj_dir.join("scratch/temp.txt"), "TMP")
      File.write(proj_dir.join("godot.exe"), "ENGINE_EXE")
      File.write(proj_dir.join("game_loaded_999.dll"), "SHADOW_DLL")
      File.write(proj_dir.join("test_report.json"), "{}")
      File.write(proj_dir.join(".tool_tests_passed"), "ok")

      # Package source!
      res_pkg = LapisSpecHelper.run_lapis(["package", "source"], chdir: proj_dir)
      res_pkg.success?.should be_true, "lapis package source failed:\n#{res_pkg.all_output}"

      zip_path = proj_dir.join("bin/jam_project-source.zip")
      File.exists?(zip_path).should be_true

      entries = [] of String
      File.open(zip_path.to_s, "rb") do |f|
        Compress::Zip::Reader.open(f) do |zip|
          zip.each_entry { |e| entries << e.filename.gsub('\\', '/') }
        end
      end

      # Flat-root source files, substring-named files, _dev/, and dotfiles MUST be present
      entries.should contain("project.godot")
      entries.should contain("shard.yml")
      entries.should contain("godot-version.yml")
      entries.should contain("Makefile")
      entries.should contain("src/main.cr")
      entries.should contain("src/core/input_bindings.cr")
      entries.should contain("spec/jam_spec.cr")
      entries.should contain("addons/crystal_integration/crystal.gdextension")
      entries.should contain("addons/crystal_integration/plugin.cfg")
      entries.should contain("addons/dialogic/plugin.cfg")
      entries.should contain("addons/local_prop/shard.yml")
      entries.should contain("addons/local_prop/src/local_prop.cr")
      entries.should contain("logo.png")
      entries.should contain("_dev/GDD.md")
      entries.should contain("editor/.gdignore")
      entries.should contain(".gitignore")
      entries.should contain(".gitattributes")
      entries.should contain(".githooks/pre-commit")

      # Excluded directories & binary/temp files MUST NOT be present
      entries.any? { |e| e.starts_with?("bin/") || e.includes?("/bin/") }.should be_false
      entries.any? { |e| e.starts_with?("lib/") || e.includes?("/lib/") }.should be_false
      entries.any? { |e| e.starts_with?("log/") || e.includes?("/log/") }.should be_false
      entries.any? { |e| e.starts_with?(".godot/") || e.includes?("/.godot/") }.should be_false
      entries.any? { |e| e.starts_with?(".git/") || e.includes?("/.git/") }.should be_false
      entries.any? { |e| e.starts_with?("scratch/") }.should be_false
      entries.should_not contain("godot.exe")
      entries.should_not contain("game_loaded_999.dll")
      entries.should_not contain("test_report.json")
      entries.should_not contain(".tool_tests_passed")

      # Extract into a brand-new isolated directory with NO bin/, lib/, log/, .godot/, .git/, or godot.exe
      unzipped_dir = work_dir.join("unzipped_jam")
      extract_flat_zip(zip_path, unzipped_dir)

      Dir.exists?(unzipped_dir.join("bin")).should be_false
      Dir.exists?(unzipped_dir.join("lib")).should be_false
      Dir.exists?(unzipped_dir.join("log")).should be_false
      Dir.exists?(unzipped_dir.join(".godot")).should be_false
      Dir.exists?(unzipped_dir.join(".git")).should be_false

      # 1. Verify lapis sync + deps self-provisions lib/, bin/, and .godot/extension_list.cfg without polluting dialogic/bin
      res_sync = LapisSpecHelper.run_lapis(["sync"], chdir: unzipped_dir)
      res_sync.success?.should be_true, "lapis sync on unzipped failed:\n#{res_sync.all_output}"
      File.exists?(unzipped_dir.join(".godot/extension_list.cfg")).should be_true
      Dir.exists?(unzipped_dir.join("lib/lapis/src")).should be_true
      Dir.exists?(unzipped_dir.join("lib/local_prop/src")).should be_true
      Dir.exists?(unzipped_dir.join("addons/dialogic/bin")).should be_false

      # 2. Verify fresh unzip -> lapis build compiles all Crystal source addons AND bin/game.<ext> from scratch
      ext = Lapis::Core::Env.dll_ext
      unzipped_build = work_dir.join("unzipped_for_build")
      extract_flat_zip(zip_path, unzipped_build)
      res_build = LapisSpecHelper.run_lapis(["build"], chdir: unzipped_build)
      res_build.success?.should be_true, "lapis build on fresh unzip failed:\n#{res_build.all_output}"
      File.exists?(unzipped_build.join("bin", Lapis::Core::Env.game_file)).should be_true
      File.exists?(unzipped_build.join("addons/crystal_integration/bin", Lapis::Core::Env.game_file)).should be_true
      File.exists?(unzipped_build.join("addons/diorite_draw/bin", "diorite_draw.#{ext}")).should be_true
      File.exists?(unzipped_build.join("addons/diorite_draw/bin", Lapis::Core::Env.game_file)).should be_true
      File.exists?(unzipped_build.join("addons/diorite_draw/bin", Lapis::Core::Env.bridge_file)).should be_true
      File.exists?(unzipped_build.join("addons/custom_fx/bin", "custom_fx.#{ext}")).should be_true
      File.exists?(unzipped_build.join("addons/custom_fx/bin", Lapis::Core::Env.bridge_file)).should be_false
      Dir.exists?(unzipped_build.join("addons/local_prop/bin")).should be_false

      # 3. Verify fresh unzip -> lapis spec provisions dependencies & passes unit specs
      unzipped_spec = work_dir.join("unzipped_spec")
      extract_flat_zip(zip_path, unzipped_spec)
      res_spec = LapisSpecHelper.run_lapis(["spec", "spec/jam_spec.cr"], chdir: unzipped_spec)
      res_spec.success?.should be_true, "lapis spec on fresh unzip failed:\n#{res_spec.all_output}"
      res_spec.output.should contain("0 failures")

      # 4. Verify fresh unzip -> lapis doctor autofix remediates clean project state
      unzipped_doc = work_dir.join("unzipped_for_doctor")
      extract_flat_zip(zip_path, unzipped_doc)
      res_doc = LapisSpecHelper.run_lapis(["doctor", "autofix"], chdir: unzipped_doc, env: {"LAPIS_NO_AUTO_GODOT" => "1"})
      res_doc.success?.should be_true, "lapis doctor autofix on fresh unzip failed:\n#{res_doc.all_output}"
      File.exists?(unzipped_doc.join("bin/.gdignore")).should be_true
      File.exists?(unzipped_doc.join(".godot/extension_list.cfg")).should be_true

      # 5. Verify stale/partial lib/lapis (missing src/editor/benchmark_graph_control.cr) + stray src/libgodot/generated self-heals on sync + build
      unzipped_heal = work_dir.join("unzipped_for_heal")
      extract_flat_zip(zip_path, unzipped_heal)
      FileUtils.mkdir_p(unzipped_heal.join("lib/lapis/src/libgodot"))
      File.write(unzipped_heal.join("lib/lapis/shard.yml"), "name: lapis\nversion: 0.0.1\n")
      FileUtils.mkdir_p(unzipped_heal.join("src/libgodot/generated"))
      File.write(unzipped_heal.join("src/libgodot/generated/global_enums.cr"), "# stray generated")

      res_heal_sync = LapisSpecHelper.run_lapis(["sync"], chdir: unzipped_heal, env: {"LAPIS_NO_AUTO_GODOT" => "1"})
      res_heal_sync.success?.should be_true, "lapis sync on stale unzip failed:\n#{res_heal_sync.all_output}"
      Dir.exists?(unzipped_heal.join("src/libgodot")).should be_false
      File.exists?(unzipped_heal.join("lib/lapis/src/editor/benchmark_graph_control.cr")).should be_true
      File.exists?(unzipped_heal.join("lib/lapis/src/editor/plugin.cr")).should be_true

      res_heal_build = LapisSpecHelper.run_lapis(["build"], chdir: unzipped_heal, env: {"LAPIS_NO_AUTO_GODOT" => "1"})
      res_heal_build.success?.should be_true, "lapis build after self-heal failed:\n#{res_heal_build.all_output}"
      File.exists?(unzipped_heal.join("bin", Lapis::Core::Env.game_file)).should be_true
      File.exists?(unzipped_heal.join("addons/crystal_integration/bin", Lapis::Core::Env.bridge_file)).should be_true

      # 6. Verify consumer 'lapis setup --skip-dump' provisions lib/lapis, bridge, AND compiles all Crystal source addons without polluting project src/libgodot/generated
      unzipped_setup = work_dir.join("unzipped_for_setup")
      extract_flat_zip(zip_path, unzipped_setup)
      File.write(unzipped_setup.join("godot#{Lapis::Core::Env.exe_ext}"), "stub_godot")
      File.write(unzipped_setup.join("extension_api.json"), "{}")
      FileUtils.mkdir_p(unzipped_setup.join("src/libgodot/generated"))
      File.write(unzipped_setup.join("src/libgodot/generated/singletons.cr"), "# stray")

      res_setup = LapisSpecHelper.run_lapis(["setup", "--skip-dump"], chdir: unzipped_setup, env: {"LAPIS_NO_AUTO_GODOT" => "1"})
      res_setup.success?.should be_true, "lapis setup --skip-dump on fresh unzip failed:\n#{res_setup.all_output}"
      Dir.exists?(unzipped_setup.join("src/libgodot")).should be_false
      File.exists?(unzipped_setup.join("extension_api.json")).should be_false
      File.exists?(unzipped_setup.join("lib/lapis/src/editor/benchmark_graph_control.cr")).should be_true
      File.exists?(unzipped_setup.join("addons/crystal_integration/bin", Lapis::Core::Env.bridge_file)).should be_true
      File.exists?(unzipped_setup.join("addons/diorite_draw/bin", "diorite_draw.#{ext}")).should be_true
      File.exists?(unzipped_setup.join("addons/diorite_draw/bin", Lapis::Core::Env.game_file)).should be_true
      File.exists?(unzipped_setup.join("addons/diorite_draw/bin", Lapis::Core::Env.bridge_file)).should be_true
      File.exists?(unzipped_setup.join("addons/custom_fx/bin", "custom_fx.#{ext}")).should be_true
      if !Lapis::Core::Env.windows?
        File.exists?(unzipped_setup.join("addons/custom_fx/bin", "libcustom_fx.#{ext}")).should be_true
      end
      Dir.exists?(unzipped_setup.join("addons/local_prop/bin")).should be_false

      # Verify inspect_addon classifies compiled GDExtension addons vs pure-Crystal helper shards accurately
      diorite_info = Lapis::Commands::InstallAddon.inspect_addon(unzipped_setup.join("addons/diorite_draw"))
      diorite_info.is_recompilable.should be_true
      diorite_info.binary_status.should eq("Up-to-date")

      fx_info = Lapis::Commands::InstallAddon.inspect_addon(unzipped_setup.join("addons/custom_fx"))
      fx_info.is_recompilable.should be_true
      fx_info.binary_status.should eq("Up-to-date")

      prop_info = Lapis::Commands::InstallAddon.inspect_addon(unzipped_setup.join("addons/local_prop"))
      prop_info.is_recompilable.should be_false
      prop_info.binary_status.should eq("Linked in Game")

      ext_lines = File.read(unzipped_setup.join(".godot/extension_list.cfg")).lines.map(&.strip).reject(&.empty?)
      ext_lines.first.should eq("res://addons/crystal_integration/crystal.gdextension")
      diorite_idx = ext_lines.index("res://addons/diorite_draw/diorite_draw.gdextension").not_nil!
      fx_idx = ext_lines.index("res://addons/custom_fx/custom_fx.gdextension").not_nil!
      diorite_idx.should be < fx_idx
    end
  end
end
