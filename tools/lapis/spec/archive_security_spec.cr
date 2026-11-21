require "./spec_helper"
require "../src/core/archive_security"
require "../src/core/template_store"
require "../src/commands/get"

describe Lapis::Core::ArchiveSecurity do
  describe ".validate_entry_path" do
    it "accepts normal relative archive paths and normalizes './' and redundant slashes" do
      v1 = Lapis::Core::ArchiveSecurity.validate_entry_path("addons/crshader/plugin.cfg")
      v1.valid?.should be_true
      v1.skip?.should be_false
      v1.is_dir?.should be_false
      v1.clean_path.should eq("addons/crshader/plugin.cfg")

      v2 = Lapis::Core::ArchiveSecurity.validate_entry_path("./addons//crshader///bin/.gdignore")
      v2.valid?.should be_true
      v2.clean_path.should eq("addons/crshader/bin/.gdignore")

      v3 = Lapis::Core::ArchiveSecurity.validate_entry_path("addons\\my_addon\\")
      v3.valid?.should be_true
      v3.is_dir?.should be_true
      v3.clean_path.should eq("addons/my_addon")
    end

    it "marks bare '.' and './' root directory entries as skippable without failing" do
      v = Lapis::Core::ArchiveSecurity.validate_entry_path("./")
      v.valid?.should be_true
      v.skip?.should be_true
      v.is_dir?.should be_true
    end

    it "rejects '..' traversal segments in POSIX and Windows separator forms" do
      [
        "..",
        "../evil.txt",
        "addons/../../../mtp/evil.txt",
        "addons\\..\\..\\..\\mtp\\evil.txt",
        "addons/my_addon/../../project.godot",
        "addons/my_addon/../crystal_integration/bin/game.dll",
        "repo-main/../../outside.txt",
      ].each do |malicious|
        res = Lapis::Core::ArchiveSecurity.validate_entry_path(malicious)
        res.valid?.should be_false
      end
    end

    it "rejects rooted, UNC, Windows drive-qualified, and NTFS ADS paths" do
      [
        "/etc/passwd",
        "/tmp/evil.txt",
        "\\Windows\\System32\\evil.dll",
        "\\\\attacker\\share\\payload.dll",
        "//attacker/share/payload.dll",
        "C:/Users/Public/evil.txt",
        "C:\\Users\\Public\\evil.txt",
        "C:drive_relative.txt",
        "addons/foo/plugin.cfg:$DATA",
        "addons/foo/plugin.cfg::$DATA",
      ].each do |malicious|
        res = Lapis::Core::ArchiveSecurity.validate_entry_path(malicious)
        res.valid?.should be_false
      end
    end

    it "rejects empty filenames, NUL/control bytes, invalid UTF-8, trailing dots/spaces, and DOS devices" do
      Lapis::Core::ArchiveSecurity.validate_entry_path("").valid?.should be_false
      Lapis::Core::ArchiveSecurity.validate_entry_path("addons/foo/evil\0.txt").valid?.should be_false
      Lapis::Core::ArchiveSecurity.validate_entry_path("addons/foo/evil\n.txt").valid?.should be_false
      Lapis::Core::ArchiveSecurity.validate_entry_path(String.new(Bytes[0x61, 0xFF, 0xFE])).valid?.should be_false
      Lapis::Core::ArchiveSecurity.validate_entry_path("addons/.. /evil.txt").valid?.should be_false
      Lapis::Core::ArchiveSecurity.validate_entry_path("addons/.../evil.txt").valid?.should be_false
      Lapis::Core::ArchiveSecurity.validate_entry_path("addons/foo/file. ").valid?.should be_false
      Lapis::Core::ArchiveSecurity.validate_entry_path("addons/foo/CON").valid?.should be_false
      Lapis::Core::ArchiveSecurity.validate_entry_path("addons/foo/nul.txt").valid?.should be_false
      Lapis::Core::ArchiveSecurity.validate_entry_path("addons/foo/com1.cfg").valid?.should be_false
      Lapis::Core::ArchiveSecurity.validate_entry_path("addons/foo/lpt9").valid?.should be_false
    end
  end

  describe ".valid_single_name?" do
    it "validates single directory names strictly" do
      Lapis::Core::ArchiveSecurity.valid_single_name?("crshader").should be_true
      Lapis::Core::ArchiveSecurity.valid_single_name?("my-addon_v1.2").should be_true

      Lapis::Core::ArchiveSecurity.valid_single_name?("").should be_false
      Lapis::Core::ArchiveSecurity.valid_single_name?(".").should be_false
      Lapis::Core::ArchiveSecurity.valid_single_name?("..").should be_false
      Lapis::Core::ArchiveSecurity.valid_single_name?("../escape").should be_false
      Lapis::Core::ArchiveSecurity.valid_single_name?("a/b").should be_false
      Lapis::Core::ArchiveSecurity.valid_single_name?("a\\b").should be_false
      Lapis::Core::ArchiveSecurity.valid_single_name?("C:foo").should be_false
      Lapis::Core::ArchiveSecurity.valid_single_name?("NUL").should be_false
    end
  end

  describe ".resolve_safe_destination" do
    it "resolves valid relative paths inside allowed_root and rejects escapes" do
      LapisSpecHelper.with_temp_dir("archive_sec") do |tmp|
        addons_root = tmp.join("project", "addons")
        FileUtils.mkdir_p(addons_root)

        dest = Lapis::Core::ArchiveSecurity.resolve_safe_destination(addons_root, "my_addon/plugin.cfg")
        dest.should_not be_nil
        dest.not_nil!.should eq(addons_root.expand(home: false).normalize.join("my_addon", "plugin.cfg"))

        # Root directory allowed only when allow_root_dir: true
        Lapis::Core::ArchiveSecurity.resolve_safe_destination(addons_root, "", allow_root_dir: false).should be_nil
        Lapis::Core::ArchiveSecurity.resolve_safe_destination(addons_root, "", allow_root_dir: true).should eq(addons_root.expand(home: false).normalize)

        # Traversal attempts return nil
        Lapis::Core::ArchiveSecurity.resolve_safe_destination(addons_root, "../project.godot").should be_nil
        Lapis::Core::ArchiveSecurity.resolve_safe_destination(addons_root, "../../outside.txt").should be_nil
        Lapis::Core::ArchiveSecurity.resolve_safe_destination(addons_root, "../addons_evil/file.txt").should be_nil
      end
    end

    it "rejects destination paths that traverse an existing symlink or NTFS junction" do
      LapisSpecHelper.with_temp_dir("archive_symlink") do |tmp|
        outside_dir = tmp.join("outside_secret")
        FileUtils.mkdir_p(outside_dir)

        addons_root = tmp.join("project", "addons")
        FileUtils.mkdir_p(addons_root)
        link_path = addons_root.join("linked_addon")

        link_created = false
        begin
          File.symlink(outside_dir.to_s, link_path.to_s)
          link_created = true
        rescue
          {% if flag?(:windows) %}
            # Unprivileged Windows fallback: create an NTFS directory junction via cmd mklink /J
            status = Process.run("cmd.exe", ["/c", "mklink", "/J", link_path.to_s, outside_dir.to_s])
            link_created = status.success?
          {% end %}
        end

        if link_created
          Lapis::Core::ArchiveSecurity.unsafe_existing_node?(link_path).should be_true
          Lapis::Core::ArchiveSecurity.resolve_safe_destination(addons_root, "linked_addon/evil.txt").should be_nil
        end
      end
    end
  end

  describe "sibling extractor CWE-22 hardening" do
    it "blocks Zip-Slip in Get.extract_zip atomically with zero partial writes" do
      LapisSpecHelper.with_temp_dir("get_zip_slip") do |tmp|
        zip_file = tmp.join("malicious_release.zip")
        target_dir = tmp.join("unpack_target")
        escaped_file = tmp.join("escaped_from_get.txt")

        File.open(zip_file.to_s, "wb") do |f|
          Compress::Zip::Writer.open(f) do |zip|
            zip.add("legit.txt", "safe")
            zip.add("../escaped_from_get.txt", "pwned")
          end
        end

        Lapis::Commands::Get.extract_zip(zip_file, target_dir).should be_false
        File.exists?(escaped_file).should be_false
        File.exists?(target_dir.join("legit.txt")).should be_false
      end
    end

    it "blocks Zip-Slip in TemplateStore.import_template before storing archive" do
      LapisSpecHelper.with_temp_dir("tpl_zip_slip") do |tmp|
        bad_tpl_zip = tmp.join("evil_tpl.zip")
        tpl_name = "evil_tpl_#{Process.pid}_#{rand(10000)}"

        File.open(bad_tpl_zip.to_s, "wb") do |f|
          Compress::Zip::Writer.open(f) do |zip|
            zip.add("project.godot", "config_version=5\n")
            zip.add("../../escaped_tpl.txt", "pwned")
          end
        end

        begin
          imported = Lapis::Core::TemplateStore.import_template(bad_tpl_zip, custom_name: tpl_name)
          imported.should be_nil
          Lapis::Core::TemplateStore.get_template(tpl_name).should be_nil
        ensure
          Lapis::Core::TemplateStore.delete_template(tpl_name)
        end
      end
    end
  end
end
