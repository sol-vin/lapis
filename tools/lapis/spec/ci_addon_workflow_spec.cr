require "./spec_helper"
require "../src/ci"
require "yaml"

describe "Lapis GDExtension Addon Composite Action & Reusable CI Workflow (WO-039)" do
  describe "Two-Tier Lapis::CI Engine & Declarative Builder" do
    it "constructs AddonBuildConfig via Lapis::CI.addon_pipeline DSL" do
      config = Lapis::CI.addon_pipeline do |ci|
        ci.addon_name "diorite"
        ci.entry "src/diorite/diorite.cr"
        ci.godot_version "4.8-beta1"
        ci.crystal_version "1.21.0"
        ci.lapis_ref "4.8-beta1"
        ci.platforms "ubuntu-latest", "windows-latest"
        ci.run_specs true
        ci.run_headless true
        ci.run_benchmarks true
        ci.apt_packages "xvfb"
      end

      config.addon_name.should eq("diorite")
      config.entry_point.should eq("src/diorite/diorite.cr")
      config.godot_version.should eq("4.8-beta1")
      config.crystal_version.should eq("1.21.0")
      config.lapis_ref.should eq("4.8-beta1")
      config.os_matrix.should eq(["ubuntu-latest", "windows-latest"])
      config.extra_apt_packages.should eq(["xvfb"])
      config.target_branch_valid?.should be_true
    end

    it "rejects main/master as lapis_ref in target_branch_valid?" do
      invalid_main = Lapis::CI.addon_pipeline do |ci|
        ci.lapis_ref "main"
      end
      invalid_main.target_branch_valid?.should be_false

      invalid_master = Lapis::CI.addon_pipeline do |ci|
        ci.lapis_ref "master"
      end
      invalid_master.target_branch_valid?.should be_false
    end

    it "audits template-addon project and .gdextension manifest cleanly" do
      root = LapisSpecHelper.repo_root
      template_addon_dir = root.join("template-addon")
      report = Lapis::CI::AddonVerifier.verify_project(template_addon_dir)

      report.valid?.should be_true
      report.addon_name.should eq("crystal_addon")
      report.godot_version.should eq("4.8-beta1")
      report.entry_point.should eq("src/main.cr")
      report.manifest_audit.valid?.should be_true
      report.manifest_audit.entry_symbol.should eq("crystal_library_init")
      report.manifest_audit.platforms.should contain("windows")
      report.manifest_audit.platforms.should contain("linux")
      report.manifest_audit.platforms.should contain("macos")
    end

    it "renders valid 5-line caller workflow YAML for downstream addons" do
      config = Lapis::CI.addon_pipeline do |ci|
        ci.lapis_ref "4.8-beta1"
      end
      yaml_str = Lapis::CI::ActionGenerator.render_caller_workflow(config)
      parsed = YAML.parse(yaml_str)
      parsed["jobs"]["lapis-addon-ci"]["uses"].as_s.should eq("sol-vin/lapis/.github/workflows/reusable-lapis-ci.yml@4.8-beta1")
    end
  end

  describe "Composite Action `.github/actions/build-lapis-addon/action.yml`" do
    it "exists and parses as valid composite GitHub Action YAML" do
      root = LapisSpecHelper.repo_root
      action_path = root.join(".github/actions/build-lapis-addon/action.yml")
      File.exists?(action_path).should be_true

      doc = YAML.parse(File.read(action_path))
      doc["name"].as_s.should contain("Lapis")
      doc["runs"]["using"].as_s.should eq("composite")

      inputs = doc["inputs"].as_h
      inputs.has_key?("working-directory").should be_true
      inputs.has_key?("addon-name").should be_true
      inputs.has_key?("entry-point").should be_true
      inputs.has_key?("crystal-version").should be_true
      inputs.has_key?("godot-version").should be_true
      inputs.has_key?("release").should be_true
      inputs.has_key?("run-specs").should be_true
      inputs.has_key?("run-headless").should be_true
      inputs.has_key?("run-benchmarks").should be_true
      inputs.has_key?("install-libvlc").should be_true

      outputs = doc["outputs"].as_h
      outputs.has_key?("addon-name").should be_true
      outputs.has_key?("godot-version").should be_true
      outputs.has_key?("addon-library-path").should be_true
      outputs.has_key?("bridge-library-path").should be_true
      outputs.has_key?("gdextension-manifest").should be_true

      steps = doc["runs"]["steps"].as_a
      steps.size.should be >= 10
      step_names = steps.compact_map { |s| s["name"]?.try(&.as_s?) }
      step_names.any?(&.includes?("Install Crystal")).should be_true
      step_names.any?(&.includes?("Cache Crystal")).should be_true
      step_names.any?(&.includes?("Run Crystal Unit Specifications")).should be_true
      step_names.any?(&.includes?("Validate .gdextension Manifest")).should be_true
      step_names.any?(&.includes?("Headless Verification Smoke Test")).should be_true
    end
  end

  describe "Reusable Workflows `.github/workflows/reusable-lapis-ci.yml` & `build-addon.yml`" do
    it "validates reusable-lapis-ci.yml syntax, workflow_call trigger, and composite action wiring" do
      root = LapisSpecHelper.repo_root
      wf_path = root.join(".github/workflows/reusable-lapis-ci.yml")
      File.exists?(wf_path).should be_true

      doc = YAML.parse(File.read(wf_path))
      on_node = doc["on"]? || doc[YAML::Any.new(true)]?
      on_node.should_not be_nil
      on_node.not_nil!["workflow_call"]?.should_not be_nil

      wf_inputs = on_node.not_nil!["workflow_call"]["inputs"].as_h
      wf_inputs["lapis-ref"]["default"].as_s.should eq("4.8-beta1")
      wf_inputs["crystal-version"]["default"].as_s.should eq("1.21.0")

      jobs = doc["jobs"].as_h
      jobs.has_key?("addon-ci").should be_true
      jobs.has_key?("android-verify").should be_true

      addon_steps = jobs["addon-ci"]["steps"].as_a
      uses_list = addon_steps.compact_map { |s| s["uses"]?.try(&.as_s?) }
      uses_list.should contain("./.github/actions/build-lapis-addon")
    end

    it "validates build-addon.yml alias workflow for downstream consumers" do
      root = LapisSpecHelper.repo_root
      wf_path = root.join(".github/workflows/build-addon.yml")
      File.exists?(wf_path).should be_true

      doc = YAML.parse(File.read(wf_path))
      on_node = doc["on"]? || doc[YAML::Any.new(true)]?
      on_node.should_not be_nil
      on_node.not_nil!["workflow_call"]?.should_not be_nil
      doc["jobs"].as_h.has_key?("addon-ci").should be_true
    end
  end
end
