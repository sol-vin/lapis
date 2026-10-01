# tools/lapis/spec/export_templates_spec.cr
require "./spec_helper"
require "../src/commands/export_templates"

describe Lapis::Commands::ExportTemplates do
  it "resolves godot_templates_base_dir" do
    base = Lapis::Commands::ExportTemplates.godot_templates_base_dir
    base.to_s.should_not be_empty
    if Lapis::Core::Env.windows?
      base.to_s.includes?("Godot").should be_true
    end
  end

  it "normalizes target_godot_version" do
    ver = Lapis::Commands::ExportTemplates.target_godot_version
    ver.should_not be_empty
  end

  it "executes cmd_explain without errors" do
    res = Lapis::Commands::ExportTemplates.cmd_explain
    res.should eq(0)
  end

  it "executes cmd_status without errors" do
    res = Lapis::Commands::ExportTemplates.cmd_status("4.3.stable")
    res.should eq(0)
  end
end
