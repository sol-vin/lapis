require "./spec_helper"
require "../src/ci"
require "yaml"

describe "Lapis Game Composite Action & Reusable Packaging Workflow (WO-040)" do
  describe "Two-Tier Lapis::CI Game Engine & Declarative Builder" do
    it "constructs GameBuildConfig via Lapis::CI.game_pipeline DSL" do
      config = Lapis::CI.game_pipeline do |ci|
        ci.game_name "celestine"
        ci.working_directory "template"
        ci.entry "src/main.cr"
        ci.godot_version "4.8-dev7"
        ci.crystal_version "1.21.0"
        ci.lapis_ref "4.8-dev7"
        ci.release true
        ci.package_game true
        ci.embed_pck true
        ci.portable true
        ci.platforms "ubuntu-latest", "windows-latest", "macos-latest"
        ci.run_specs true
        ci.run_headless true
        ci.run_benchmarks true
        ci.apt_packages "xvfb"
      end

      config.game_name.should eq("celestine")
      config.working_directory.should eq("template")
      config.entry_point.should eq("src/main.cr")
      config.godot_version.should eq("4.8-dev7")
      config.crystal_version.should eq("1.21.0")
      config.lapis_ref.should eq("4.8-dev7")
      config.release.should be_true
      config.package_game.should be_true
      config.embed_pck.should be_true
      config.portable.should be_true
      config.os_matrix.should eq(["ubuntu-latest", "windows-latest", "macos-latest"])
      config.extra_apt_packages.should eq(["xvfb"])
      config.target_branch_valid?.should be_true
    end

    it "rejects main/master as lapis_ref in GameBuildConfig#target_branch_valid?" do
      invalid_main = Lapis::CI.game_pipeline do |ci|
        ci.lapis_ref "main"
      end
      invalid_main.target_branch_valid?.should be_false

      invalid_master = Lapis::CI.game_pipeline do |ci|
        ci.lapis_ref "master"
      end
      invalid_master.target_branch_valid?.should be_false
    end

    it "audits template game project, project.godot, and export_presets.cfg cleanly" do
      root = LapisSpecHelper.repo_root
      template_dir = root.join("template")
      report = Lapis::CI::GameVerifier.verify_project(template_dir)

      report.valid?.should be_true
      report.game_name.should eq("godot_crystal_template")
      report.godot_version.should eq("4.8-dev7")
      report.entry_point.should eq("src/main.cr")
      report.project_audit.valid?.should be_true
      report.project_audit.config_version.should eq(5)
      report.project_audit.project_title.should eq("Crystal Godot Template")
      report.project_audit.main_scene.should eq("res://scenes/main.tscn")
      report.project_audit.has_embed_pck.should be_true
      report.project_audit.export_platforms.should contain("Windows Desktop")
      report.project_audit.export_platforms.should contain("Linux")
      report.project_audit.export_platforms.should contain("macOS")
      report.project_audit.export_platforms.should contain("Android")
    end

    it "renders valid caller workflow YAML for downstream Lapis games" do
      config = Lapis::CI.game_pipeline do |ci|
        ci.lapis_ref "4.8-dev7"
      end
      yaml_str = Lapis::CI::ActionGenerator.render_game_caller_workflow(config)
      parsed = YAML.parse(yaml_str)
      parsed["jobs"]["lapis-game-ci"]["uses"].as_s.should eq("sol-vin/lapis/.github/workflows/build-game.yml@4.8-dev7")
    end
  end

  describe "Composite Action `.github/actions/build-lapis-game/action.yml`" do
    it "exists and parses as valid composite GitHub Action YAML for Linux, Windows, and macOS" do
      root = LapisSpecHelper.repo_root
      action_path = root.join(".github/actions/build-lapis-game/action.yml")
      File.exists?(action_path).should be_true

      doc = YAML.parse(File.read(action_path))
      doc["name"].as_s.should contain("Lapis Game")
      doc["runs"]["using"].as_s.should eq("composite")

      inputs = doc["inputs"].as_h
      inputs.has_key?("working-directory").should be_true
      inputs.has_key?("game-name").should be_true
      inputs.has_key?("entry-point").should be_true
      inputs.has_key?("crystal-version").should be_true
      inputs.has_key?("godot-version").should be_true
      inputs.has_key?("release").should be_true
      inputs.has_key?("package-game").should be_true
      inputs.has_key?("embed-pck").should be_true
      inputs.has_key?("portable").should be_true
      inputs.has_key?("run-specs").should be_true
      inputs.has_key?("run-headless").should be_true
      inputs.has_key?("run-benchmarks").should be_true
      inputs.has_key?("install-libvlc").should be_true

      outputs = doc["outputs"].as_h
      outputs.has_key?("game-name").should be_true
      outputs.has_key?("godot-version").should be_true
      outputs.has_key?("shard-version").should be_true
      outputs.has_key?("game-library-path").should be_true
      outputs.has_key?("bridge-library-path").should be_true
      outputs.has_key?("game-executable-path").should be_true
      outputs.has_key?("game-pck-path").should be_true
      outputs.has_key?("package-archive-path").should be_true

      steps = doc["runs"]["steps"].as_a
      steps.size.should be >= 10
      step_names = steps.compact_map { |s| s["name"]?.try(&.as_s?) }
      step_names.any?(&.includes?("Install Linux Build Dependencies")).should be_true
      step_names.any?(&.includes?("Install macOS Build Dependencies")).should be_true
      step_names.any?(&.includes?("Install Windows Build Dependencies")).should be_true
      step_names.any?(&.includes?("Install Crystal Compiler")).should be_true
      step_names.any?(&.includes?("Cache Crystal Build & Shards")).should be_true
      step_names.any?(&.includes?("Run Crystal Unit Specifications")).should be_true
      step_names.any?(&.includes?("Configure Godot, Compile & Package Lapis Game (Linux & macOS)")).should be_true
      step_names.any?(&.includes?("Configure Godot, Compile & Package Lapis Game (Windows)")).should be_true
      step_names.any?(&.includes?("Validate Game Binaries, PCK & Package Archives")).should be_true
      step_names.any?(&.includes?("Headless Game Verification Smoke Test")).should be_true
    end
  end

  describe "Reusable Workflow `.github/workflows/build-game.yml`" do
    it "validates build-game.yml syntax, workflow_call trigger, and composite action wiring" do
      root = LapisSpecHelper.repo_root
      wf_path = root.join(".github/workflows/build-game.yml")
      File.exists?(wf_path).should be_true

      doc = YAML.parse(File.read(wf_path))
      on_node = doc["on"]? || doc[YAML::Any.new(true)]?
      on_node.should_not be_nil
      on_node.not_nil!["workflow_call"]?.should_not be_nil

      wf_inputs = on_node.not_nil!["workflow_call"]["inputs"].as_h
      wf_inputs["lapis-ref"]["default"].as_s.should eq("4.8-dev7")
      wf_inputs["crystal-version"]["default"].as_s.should eq("1.21.0")

      jobs = doc["jobs"].as_h
      jobs.has_key?("game-ci").should be_true
      jobs.has_key?("android-verify").should be_true

      game_steps = jobs["game-ci"]["steps"].as_a
      uses_list = game_steps.compact_map { |s| s["uses"]?.try(&.as_s?) }
      uses_list.should contain("./.github/actions/build-lapis-game")
    end
  end
end
