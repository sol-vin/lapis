require "./spec_helper"
require "file_utils"

describe "Lapis CLI Log Command" do
  it "displays help banner with lapis log --help" do
    res = LapisSpecHelper.run_lapis(["log", "--help"])
    res.success?.should be_true
    res.output.should contain("Lapis: Project & Toolchain Log Manager")
    res.output.should contain("Usage:")
    res.output.should contain("tail")
    res.output.should contain("view")
    res.output.should contain("clean")
    res.output.should contain("search")
    res.output.should contain("export")
    res.output.should contain("crash")
  end

  it "displays status summary of log files" do
    test_log = LapisSpecHelper.repo_root.join("log", "test_spec.log")
    FileUtils.mkdir_p(test_log.parent)
    File.write(test_log, "[INFO] [Spec] Log verification test line\n")

    res = LapisSpecHelper.run_lapis(["log"])
    res.success?.should be_true
    res.output.should contain("Lapis Diagnostic Logs")
    res.output.should contain("test_spec.log")
    res.output.should contain("Total:")

    File.delete(test_log) if File.exists?(test_log)
  end

  it "searches across logs with lapis log search" do
    test_log = LapisSpecHelper.repo_root.join("log", "test_search.log")
    FileUtils.mkdir_p(test_log.parent)
    File.write(test_log, "Line 1: Normal event\nLine 2: TargetQuerySpecialToken in trace\nLine 3: Finished\n")

    res = LapisSpecHelper.run_lapis(["log", "search", "TargetQuerySpecialToken"])
    res.success?.should be_true
    res.output.should contain("test_search.log")
    res.output.should contain("TargetQuerySpecialToken")

    File.delete(test_log) if File.exists?(test_log)
  end

  it "exports logs to a zip archive" do
    test_log = LapisSpecHelper.repo_root.join("log", "test_export.log")
    FileUtils.mkdir_p(test_log.parent)
    File.write(test_log, "[INFO] [Export] Ready to export\n")

    res = LapisSpecHelper.run_lapis(["log", "export"])
    res.success?.should be_true
    res.output.should contain("Exported")
    res.output.should contain(".zip")

    # Clean up any created zip files
    Dir.glob(LapisSpecHelper.repo_root.join("log", "lapis_logs_*.zip").to_s).each { |z| File.delete(z) rescue nil }
    File.delete(test_log) if File.exists?(test_log)
  end

  it "displays channels list with lapis log channels" do
    res = LapisSpecHelper.run_lapis(["log", "channels"])
    res.success?.should be_true
    res.output.should contain("Lapis Log Channels")
    res.output.should contain("public")
    res.output.should contain("editor")
    res.output.should contain("game")
    res.output.should contain("bridge")
  end

  it "displays filter rules with lapis log filters" do
    res = LapisSpecHelper.run_lapis(["log", "filters"])
    res.success?.should be_true
    res.output.should contain("Lapis Log Filter Rules")
    res.output.should contain("public")
    res.output.should contain("safe")
    res.output.should contain("no_spoilers")
    res.output.should contain("errors_only")
  end
end
