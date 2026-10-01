# tools/lapis/spec/template_store_spec.cr
require "./spec_helper"
require "../src/core/template_store"

describe Lapis::Core::TemplateStore do
  it "serializes and deserializes TemplateManifest" do
    manifest = Lapis::Core::TemplateManifest.new(
      name: "my_rpg",
      display_name: "My RPG",
      description: "2D RPG Template",
      author: "GameDev",
      version: "1.0.0",
      created_at: "2026-10-01T00:00:00Z",
      tags: ["2d", "rpg"],
      addons: ["dummy_inventory"]
    )

    json_str = manifest.to_json
    loaded = Lapis::Core::TemplateManifest.from_json(json_str)

    loaded.name.should eq("my_rpg")
    loaded.display_name.should eq("My RPG")
    loaded.description.should eq("2D RPG Template")
    loaded.author.should eq("GameDev")
    loaded.version.should eq("1.0.0")
    loaded.tags.should eq(["2d", "rpg"])
    loaded.addons.should eq(["dummy_inventory"])
  end

  it "saves, lists, and extracts a template from global store" do
    # Create temporary template source project
    tmp_src = Path.new(Dir.tempdir).join("lapis_test_template_src_#{Process.pid}")
    FileUtils.mkdir_p(tmp_src)
    File.write(tmp_src.join("project.godot"), "config/name=\"Test Game\"\n")
    File.write(tmp_src.join("shard.yml"), "name: test_game\nversion: 0.1.0\n")
    FileUtils.mkdir_p(tmp_src.join("src"))
    File.write(tmp_src.join("src/main.cr"), "require \"libgodot\"\n")

    test_tpl_name = "test_tpl_#{Process.pid}"

    begin
      # 1. Save template into global store
      manifest = Lapis::Core::TemplateStore.save_template(
        source_dir: tmp_src,
        name: test_tpl_name,
        description: "Automated test template",
        author: "SpecSuite",
        tags: ["test", "spec"]
      )
      manifest.name.should eq(test_tpl_name)

      # 2. List templates
      templates = Lapis::Core::TemplateStore.list_templates
      templates.any? { |t| t.name == test_tpl_name }.should be_true

      # 3. Retrieve manifest
      meta = Lapis::Core::TemplateStore.get_template(test_tpl_name)
      meta.should_not be_nil
      if meta
        meta.name.should eq(test_tpl_name)
        meta.description.should eq("Automated test template")
        meta.author.should eq("SpecSuite")
        meta.tags.should eq(["test", "spec"])
      end

      # 4. Extract template into fresh destination
      tmp_dest = Path.new(Dir.tempdir).join("lapis_test_template_dest_#{Process.pid}")
      FileUtils.mkdir_p(tmp_dest)
      begin
        extracted = Lapis::Core::TemplateStore.extract_template(test_tpl_name, tmp_dest)
        extracted.should be_true

        File.exists?(tmp_dest.join("project.godot")).should be_true
        File.exists?(tmp_dest.join("shard.yml")).should be_true
        File.exists?(tmp_dest.join("src/main.cr")).should be_true
        File.read(tmp_dest.join("src/main.cr")).should eq("require \"libgodot\"\n")
      ensure
        FileUtils.rm_rf(tmp_dest.to_s) rescue nil
      end

      # 5. Export template to a zip file
      export_zip = Path.new(Dir.tempdir).join("exported_#{test_tpl_name}.lapis-template.zip")
      begin
        exported = Lapis::Core::TemplateStore.export_template(test_tpl_name, export_zip)
        exported.should be_true
        File.exists?(export_zip).should be_true
        File.size(export_zip).should be > 100

        # Import under a different name
        imported_name = "#{test_tpl_name}_imported"
        imported = Lapis::Core::TemplateStore.import_template(export_zip, custom_name: imported_name)
        imported.should_not be_nil
        Lapis::Core::TemplateStore.get_template(imported_name).should_not be_nil

        # Delete imported template
        Lapis::Core::TemplateStore.delete_template(imported_name)
      ensure
        File.delete(export_zip) rescue nil
      end

    ensure
      # Cleanup
      Lapis::Core::TemplateStore.delete_template(test_tpl_name)
      FileUtils.rm_rf(tmp_src.to_s) rescue nil
    end
  end
end
