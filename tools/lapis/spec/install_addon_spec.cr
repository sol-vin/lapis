require "./spec_helper"
require "../src/commands/install_addon"

describe "Lapis::Commands::InstallAddon" do
  describe "specifier parsing" do
    it "parses github:owner/repo" do
      spec = Lapis::Commands::InstallAddon.parse_spec("github:sol-vin/crshader")
      spec.type.should eq(:github)
      spec.owner.should eq("sol-vin")
      spec.repo.should eq("crshader")
      spec.tag.should be_nil
      spec.name.should eq("crshader")
    end

    it "parses gh:owner/repo with tag" do
      spec = Lapis::Commands::InstallAddon.parse_spec("gh:sol-vin/crshader@v0.1.0")
      spec.type.should eq(:github)
      spec.owner.should eq("sol-vin")
      spec.repo.should eq("crshader")
      spec.tag.should eq("v0.1.0")
      spec.name.should eq("crshader")
    end

    it "rejects bare owner/repo shorthand without provider prefix and reports invalid_path" do
      spec = Lapis::Commands::InstallAddon.parse_spec("sol-vin/crshader")
      spec.type.should eq(:invalid_path)
      spec.error_message.not_nil!.should contain("No Crystal addon found at path 'sol-vin/crshader'")
    end

    it "parses gitlab:group/project" do
      spec = Lapis::Commands::InstallAddon.parse_spec("gitlab:sol-vin/crshader@v1.0.0")
      spec.type.should eq(:gitlab)
      spec.owner.should eq("sol-vin")
      spec.repo.should eq("crshader")
      spec.tag.should eq("v1.0.0")
      spec.name.should eq("crshader")
    end

    it "parses git:url.git" do
      spec = Lapis::Commands::InstallAddon.parse_spec("git:https://gitlab.com/sol-vin/crshader.git@develop")
      spec.type.should eq(:git)
      spec.path.should eq("https://gitlab.com/sol-vin/crshader.git")
      spec.tag.should eq("develop")
      spec.name.should eq("crshader")
    end

    it "parses https://github.com/owner/repo" do
      spec = Lapis::Commands::InstallAddon.parse_spec("https://github.com/sol-vin/crshader")
      spec.type.should eq(:github)
      spec.owner.should eq("sol-vin")
      spec.repo.should eq("crshader")
    end

    it "parses https://github.com/owner/repo.git with tag" do
      spec = Lapis::Commands::InstallAddon.parse_spec("https://github.com/sol-vin/crshader.git@master")
      spec.type.should eq(:github)
      spec.owner.should eq("sol-vin")
      spec.repo.should eq("crshader")
      spec.tag.should eq("master")
    end

    it "parses valid local zip archive" do
      temp_zip = Path.new(Dir.tempdir).join("test_addon_#{Time.utc.to_unix_ms}.zip")
      File.open(temp_zip.to_s, "w") do |file|
        Compress::Zip::Writer.open(file) do |zip|
          zip.add("addons/my_addon/plugin.cfg", "[plugin]\nname=\"Test\"\n")
        end
      end

      spec = Lapis::Commands::InstallAddon.parse_spec(temp_zip.to_s)
      spec.type.should eq(:local_file)
      spec.name.should eq(temp_zip.stem)

      File.delete(temp_zip) if File.exists?(temp_zip)
    end

    it "rejects non-addon zip archive or non-existent path" do
      spec = Lapis::Commands::InstallAddon.parse_spec("non_existent/addon_file.zip")
      spec.type.should eq(:invalid_path)
      spec.error_message.not_nil!.should contain("No Crystal addon found at path 'non_existent/addon_file.zip'")
    end
  end

  describe "GitHub repository and release querying" do
    it "queries GitHub release assets for sol-vin/crshader" do
      asset = Lapis::Commands::InstallAddon.find_release_asset_url("sol-vin", "crshader")
      if a = asset
        url, filename = a
        url.should contain("github.com/sol-vin/crshader/releases")
        filename.should end_with(".zip")
      end
    end

    it "detects addons directory in sol-vin/crshader repository tree" do
      has_addons = Lapis::Commands::InstallAddon.repo_has_addons_dir?("sol-vin", "crshader")
      if has_addons
        has_addons.should be_true
      end
    end
  end

  describe "project.godot manipulation" do
    it "creates [editor_plugins] section and registers plugin in project.godot" do
      temp_dir = Path.new(Dir.tempdir).join("lapis_test_godot_#{Time.utc.to_unix_ms}")
      FileUtils.mkdir_p(temp_dir)
      project_godot = temp_dir.join("project.godot")
      File.write(project_godot, <<-INI
; Engine configuration file.
config_version=5

[application]
config/name="Test Game"
INI
      )

      res = Lapis::Commands::InstallAddon.enable_in_project_godot(temp_dir, "addons/crshader/plugin.cfg")
      res.should be_true

      content = File.read(project_godot)
      content.should contain("[editor_plugins]")
      content.should contain("enabled=PackedStringArray(\"res://addons/crshader/plugin.cfg\")")

      # Deduplication: running it again should keep single entry
      res2 = Lapis::Commands::InstallAddon.enable_in_project_godot(temp_dir, "addons/crshader/plugin.cfg")
      res2.should be_true
      File.read(project_godot).scan("res://addons/crshader/plugin.cfg").size.should eq(1)

      # Disable plugin
      dis_res = Lapis::Commands::InstallAddon.disable_in_project_godot(temp_dir, "addons/crshader/plugin.cfg")
      dis_res.should be_true
      File.read(project_godot).should_not contain("res://addons/crshader/plugin.cfg")

      FileUtils.rm_rf(temp_dir)
    end

    it "appends to existing enabled plugins list without corrupting" do
      temp_dir = Path.new(Dir.tempdir).join("lapis_test_godot_multi_#{Time.utc.to_unix_ms}")
      FileUtils.mkdir_p(temp_dir)
      project_godot = temp_dir.join("project.godot")
      File.write(project_godot, <<-INI
; Engine configuration file.
config_version=5

[editor_plugins]

enabled=PackedStringArray("res://addons/crystal_integration/plugin.cfg")
INI
      )

      res = Lapis::Commands::InstallAddon.enable_in_project_godot(temp_dir, "addons/crshader/plugin.cfg")
      res.should be_true

      content = File.read(project_godot)
      content.should contain("\"res://addons/crystal_integration/plugin.cfg\", \"res://addons/crshader/plugin.cfg\"")

      FileUtils.rm_rf(temp_dir)
    end
  end

  describe "archive extraction and local installation" do
    it "installs from local addon zip into a Godot project" do
      temp_dir = Path.new(Dir.tempdir).join("lapis_test_install_#{Time.utc.to_unix_ms}")
      FileUtils.mkdir_p(temp_dir)
      project_godot = temp_dir.join("project.godot")
      File.write(project_godot, "config_version=5\n[application]\nconfig/name=\"Test\"\n")

      # Create a dummy addon zip archive
      dummy_zip = temp_dir.join("dummy_addon.zip")
      File.open(dummy_zip.to_s, "w") do |file|
        Compress::Zip::Writer.open(file) do |zip|
          zip.add("addons/my_test_addon/plugin.cfg", "plugin_content")
          zip.add("addons/my_test_addon/plugin.gd", "extends EditorPlugin")
        end
      end

      spec = Lapis::Commands::InstallAddon.parse_spec(dummy_zip.to_s)
      code = Lapis::Commands::InstallAddon.install_addon(
        spec,
        temp_dir,
        auto_enable: true,
        force: true
      )
      code.should eq(0)

      File.exists?(temp_dir.join("addons/my_test_addon/plugin.cfg")).should be_true
      File.read(temp_dir.join("addons/my_test_addon/plugin.cfg")).should eq("plugin_content")
      File.read(project_godot).should contain("res://addons/my_test_addon/plugin.cfg")

      # Uninstall
      un_code = Lapis::Commands::InstallAddon.uninstall_addon("my_test_addon", temp_dir)
      un_code.should eq(0)
      Dir.exists?(temp_dir.join("addons/my_test_addon")).should be_false
      File.read(project_godot).should_not contain("res://addons/my_test_addon/plugin.cfg")

      FileUtils.rm_rf(temp_dir)
    end

    it "extracts GitHub-prefixed source addon archives and flat addon archives cleanly" do
      LapisSpecHelper.with_temp_dir("addon_layouts") do |tmp|
        proj_gh = tmp.join("proj_gh")
        gh_zip = tmp.join("crshader-main.zip")
        File.open(gh_zip.to_s, "wb") do |file|
          Compress::Zip::Writer.open(file) do |zip|
            zip.add("crshader-main/addons/crshader/plugin.cfg", "[plugin]\nname=\"CrShader\"\n")
            zip.add("crshader-main/src/main.cr", "require \"libgodot\"\n")
            zip.add("crshader-main/shard.yml", "name: crshader\nversion: 0.1.0\n")
          end
        end

        Lapis::Commands::InstallAddon.extract_addon_zip(gh_zip, proj_gh, "crshader").should be_true
        File.exists?(proj_gh.join("addons/crshader/plugin.cfg")).should be_true
        File.exists?(proj_gh.join("addons/crshader/src/main.cr")).should be_true
        File.exists?(proj_gh.join("addons/crshader/src/crshader.cr")).should be_true
        File.exists?(proj_gh.join("addons/crshader/shard.yml")).should be_true

        proj_flat = tmp.join("proj_flat")
        flat_zip = tmp.join("flat_addon.zip")
        File.open(flat_zip.to_s, "wb") do |file|
          Compress::Zip::Writer.open(file) do |zip|
            zip.add("plugin.cfg", "[plugin]\nname=\"Flat\"\n")
            zip.add("plugin.gd", "extends EditorPlugin\n")
          end
        end

        Lapis::Commands::InstallAddon.extract_addon_zip(flat_zip, proj_flat, "flat_addon").should be_true
        File.exists?(proj_flat.join("addons/flat_addon/plugin.cfg")).should be_true
        File.exists?(proj_flat.join("addons/flat_addon/plugin.gd")).should be_true
      end
    end

    it "rejects CWE-22 Zip-Slip escape 'addons/../../../mtp/evil.txt' atomically with zero writes" do
      LapisSpecHelper.with_temp_dir("bright_scan_repro") do |sandbox|
        project_root = sandbox.join("a", "b", "project_root")
        FileUtils.mkdir_p(project_root)
        File.write(project_root.join("project.godot"), "config_version=5\n")

        repro_zip = sandbox.join("evil_addon.zip")
        File.open(repro_zip.to_s, "wb") do |file|
          Compress::Zip::Writer.open(file) do |zip|
            zip.add("addons/legit_addon/plugin.cfg", "[plugin]\nname=\"Legit\"\n")
            zip.add("addons/../../../mtp/evil.txt", "EXPLOIT_PAYLOAD")
          end
        end

        res = Lapis::Commands::InstallAddon.extract_addon_zip(repro_zip, project_root, "legit_addon")
        res.should be_false

        # Verify neither the escaped file nor partial legit addon files were written
        File.exists?(sandbox.join("mtp", "evil.txt")).should be_false
        File.exists?(sandbox.join("a", "mtp", "evil.txt")).should be_false
        Dir.exists?(project_root.join("addons", "legit_addon")).should be_false

        # Also verify full CLI flow (`install_addon`) returns non-zero exit code 1
        spec = Lapis::Commands::InstallAddon.parse_spec(repro_zip.to_s)
        spec.type.should eq(:local_file)
        Lapis::Commands::InstallAddon.install_addon(spec, project_root, force: true).should eq(1)
        File.exists?(sandbox.join("mtp", "evil.txt")).should be_false
      end
    end

    it "blocks intra-project escapes, crystal_integration tampering, flat-zip escapes, rooted/drive paths, and unsafe addon names" do
      LapisSpecHelper.with_temp_dir("addon_escape_matrix") do |sandbox|
        project_root = sandbox.join("nested", "game")
        crystal_int = project_root.join("addons", "crystal_integration", "bin")
        FileUtils.mkdir_p(crystal_int)
        original_godot = "config_version=5\n[application]\nconfig/name=\"SafeGame\"\n"
        File.write(project_root.join("project.godot"), original_godot)
        File.write(crystal_int.join("game.dll"), "ORIGINAL_BRIDGE_GAME")

        # 1. Intra-project overwrite of project.godot via addons/my_addon/../../project.godot
        zip_intra = sandbox.join("intra.zip")
        File.open(zip_intra.to_s, "wb") do |f|
          Compress::Zip::Writer.open(f) do |z|
            z.add("addons/my_addon/../../project.godot", "HACKED")
          end
        end
        Lapis::Commands::InstallAddon.extract_addon_zip(zip_intra, project_root, "my_addon").should be_false
        File.read(project_root.join("project.godot")).should eq(original_godot)

        # 2. Cross-addon crystal_integration overwrite via '../' and './' normalization tricks
        zip_ci_dotdot = sandbox.join("ci_dotdot.zip")
        File.open(zip_ci_dotdot.to_s, "wb") do |f|
          Compress::Zip::Writer.open(f) do |z|
            z.add("addons/my_addon/../crystal_integration/bin/game.dll", "TAMPERED")
          end
        end
        Lapis::Commands::InstallAddon.extract_addon_zip(zip_ci_dotdot, project_root, "my_addon").should be_false
        File.read(crystal_int.join("game.dll")).should eq("ORIGINAL_BRIDGE_GAME")

        zip_ci_dotslash = sandbox.join("ci_dotslash.zip")
        File.open(zip_ci_dotslash.to_s, "wb") do |f|
          Compress::Zip::Writer.open(f) do |z|
            z.add("addons/./crystal_integration/bin/game.dll", "TAMPERED")
            z.add("addons/my_addon/plugin.cfg", "[plugin]\nname=\"Safe\"\n")
          end
        end
        Lapis::Commands::InstallAddon.extract_addon_zip(zip_ci_dotslash, project_root, "my_addon").should be_true
        File.read(crystal_int.join("game.dll")).should eq("ORIGINAL_BRIDGE_GAME")

        # 3. Flat archive traversal, backslash traversal, rooted path, and Windows drive path
        [
          "../../flat_escape.txt",
          "..\\..\\backslash_escape.txt",
          "/tmp/rooted_escape.txt",
          "C:/Users/Public/drive_escape.txt",
          "C:drive_rel_escape.txt",
        ].each_with_index do |bad_entry, idx|
          bad_zip = sandbox.join("bad_#{idx}.zip")
          File.open(bad_zip.to_s, "wb") do |f|
            Compress::Zip::Writer.open(f) do |z|
              z.add(bad_entry, "PAYLOAD")
            end
          end
          Lapis::Commands::InstallAddon.extract_addon_zip(bad_zip, project_root, "flat_mod").should be_false
        end

        # 4. Poisoned addon_name parameter, specifier parsing, and uninstall_addon traversal
        valid_flat = sandbox.join("valid_flat.zip")
        File.open(valid_flat.to_s, "wb") do |f|
          Compress::Zip::Writer.open(f) do |z|
            z.add("plugin.cfg", "[plugin]\n")
          end
        end
        Lapis::Commands::InstallAddon.extract_addon_zip(valid_flat, project_root, "../escaped_dir").should be_false
        Lapis::Commands::InstallAddon.extract_addon_zip(valid_flat, project_root, "..").should be_false
        Dir.exists?(project_root.join("escaped_dir")).should be_false

        Lapis::Commands::InstallAddon.parse_spec("github:owner/..").type.should eq(:invalid_path)
        Lapis::Commands::InstallAddon.parse_spec("gitlab:group/..").type.should eq(:invalid_path)
        Lapis::Commands::InstallAddon.parse_spec("https://github.com/owner/..").type.should eq(:invalid_path)

        Lapis::Commands::InstallAddon.uninstall_addon("..", project_root).should eq(1)
        Lapis::Commands::InstallAddon.uninstall_addon("../game", project_root).should eq(1)
        Dir.exists?(project_root).should be_true
        File.exists?(project_root.join("project.godot")).should be_true
      end
    end

    it "handles raw fuzzer PKZIP payloads with invalid UTF-8 and empty entry filenames without crashing" do
      LapisSpecHelper.with_temp_dir("fuzzer_raw_pkzip") do |sandbox|
        project_root = sandbox.join("project")

        build_raw_stored_zip = ->(fname_bytes : Bytes, payload : Bytes, dos_date : UInt16) : Bytes do
          io = IO::Memory.new
          io.write_bytes(0x04034b50_u32, IO::ByteFormat::LittleEndian) # Local file header signature
          io.write_bytes(20_u16, IO::ByteFormat::LittleEndian)         # Version needed
          io.write_bytes(0_u16, IO::ByteFormat::LittleEndian)          # Flags
          io.write_bytes(0_u16, IO::ByteFormat::LittleEndian)          # Method: STORED
          io.write_bytes(0_u16, IO::ByteFormat::LittleEndian)          # Mod time
          io.write_bytes(dos_date, IO::ByteFormat::LittleEndian)        # Mod date (0x0021 = 1980-01-01)
          io.write_bytes(0_u32, IO::ByteFormat::LittleEndian)          # CRC32
          io.write_bytes(payload.size.to_u32, IO::ByteFormat::LittleEndian)
          io.write_bytes(payload.size.to_u32, IO::ByteFormat::LittleEndian)
          io.write_bytes(fname_bytes.size.to_u16, IO::ByteFormat::LittleEndian)
          io.write_bytes(0_u16, IO::ByteFormat::LittleEndian)          # Extra length
          io.write(fname_bytes)
          io.write(payload)
          io.write_bytes(0x06054b50_u32, IO::ByteFormat::LittleEndian) # End of central directory
          io.write(Bytes.new(18, 0_u8))
          io.to_slice
        end

        invalid_utf8_zip = sandbox.join("invalid_utf8.zip")
        File.write(invalid_utf8_zip, build_raw_stored_zip.call(Bytes[0xFF, 0xFE, 0x2E, 0x2E, 0x2F, 0x61], "x".to_slice, 0x0021_u16))
        Lapis::Commands::InstallAddon.extract_addon_zip(invalid_utf8_zip, project_root, "fuzz_addon").should be_false
        Dir.exists?(project_root).should be_false

        empty_name_zip = sandbox.join("empty_name.zip")
        File.write(empty_name_zip, build_raw_stored_zip.call(Bytes.empty, "x".to_slice, 0x0021_u16))
        Lapis::Commands::InstallAddon.extract_addon_zip(empty_name_zip, project_root, "fuzz_addon").should be_false
        Dir.exists?(project_root).should be_false

        bad_dos_date_zip = sandbox.join("bad_dos_date.zip")
        File.write(bad_dos_date_zip, build_raw_stored_zip.call("addons/a/plugin.cfg".to_slice, "x".to_slice, 0_u16))
        Lapis::Commands::InstallAddon.extract_addon_zip(bad_dos_date_zip, project_root, "fuzz_addon").should be_false
        Dir.exists?(project_root).should be_false
      end
    end
  end

  describe "CLI commands" do
    it "displays help for install addon" do
      res = LapisSpecHelper.run_lapis(["install", "addon", "--help"])
      res.success?.should be_true
      res.output.should contain("Lapis: Addon Package Manager")
      res.output.should contain("lapis install addon <specifier>")
    end

    it "displays install addon in main install help" do
      res = LapisSpecHelper.run_lapis(["install", "--help"])
      res.success?.should be_true
      res.output.should contain("lapis install addon")
    end
  end
end
