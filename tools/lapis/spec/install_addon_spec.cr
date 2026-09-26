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

    it "parses owner/repo shorthand" do
      spec = Lapis::Commands::InstallAddon.parse_spec("sol-vin/crshader")
      spec.type.should eq(:github)
      spec.owner.should eq("sol-vin")
      spec.repo.should eq("crshader")
      spec.tag.should be_nil
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

    it "parses local zip archive" do
      spec = Lapis::Commands::InstallAddon.parse_spec("dist/crshader-windows.zip")
      spec.type.should eq(:local_file)
      spec.name.should eq("crshader")
    end
  end

  describe "GitHub repository and release querying" do
    it "queries GitHub release assets for sol-vin/crshader" do
      asset = Lapis::Commands::InstallAddon.find_release_asset_url("sol-vin", "crshader")
      asset.should_not be_nil
      if a = asset
        url, filename = a
        url.should contain("github.com/sol-vin/crshader/releases")
        filename.should contain("crshader")
      end
    end

    it "detects addons directory in sol-vin/crshader repository tree" do
      has_addons = Lapis::Commands::InstallAddon.repo_has_addons_dir?("sol-vin", "crshader")
      has_addons.should be_true
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
