require "./spec_helper"
require "../src/docs/model"
require "../src/docs/generator"
require "../src/commands/benchmarks"

describe "Project Parity & Multi-Consumer Architecture" do
  describe "Template Project Documentation" do
    it "compiles template docs_src into Game::Docs hierarchy" do
      root = LapisSpecHelper.repo_root
      template_docs_src = root.join("template/docs_src")
      File.directory?(template_docs_src).should be_true

      LapisSpecHelper.with_temp_dir("template_docs_test") do |dir|
        out_dir = dir.join("src/docs")
        root_file = dir.join("src/docs.cr")

        success = Lapis::Docs::Generator.run(
          src_dir: template_docs_src,
          out_dir: out_dir,
          root_docs_file: root_file
        )
        success.should be_true

        # Verify root docs.cr
        File.exists?(root_file).should be_true
        root_content = File.read(root_file)
        root_content.should contain("module Game")
        root_content.should contain("module Docs")
        root_content.should contain("Game Quick Start:")
        root_content.should contain("1. Getting started")
        root_content.should contain("require \"./docs/a_getting_started/a_overview\"")
        root_content.should contain("require \"./docs/a_getting_started/b_gameplay_systems\"")

        # Verify generated submodules
        overview_cr = out_dir.join("a_getting_started/a_overview.cr")
        File.exists?(overview_cr).should be_true
        overview_content = File.read(overview_cr)
        overview_content.should contain("module Game")
        overview_content.should contain("module Docs")
        overview_content.should contain("module A_GETTING_STARTED")
        overview_content.should contain("module A_OVERVIEW")
        overview_content.should contain("def self.topic_01_game_architecture : Nil")
      end
    end

    it "discovers benchmarks in template/benchmarks via flat layout discovery" do
      root = LapisSpecHelper.repo_root
      template_bench_dir = root.join("template/benchmarks")
      File.directory?(template_bench_dir).should be_true

      benches = Lapis::Commands::Benchmarks.discover_benchmarks(template_bench_dir)
      benches.empty?.should be_false
      benches.map(&.name.downcase).should contain("example_bench")
    end
  end

  describe "Template Addon Project Documentation" do
    it "compiles template-addon docs_src into MyAddon::Docs hierarchy" do
      root = LapisSpecHelper.repo_root
      addon_docs_src = root.join("template-addon/docs_src")
      File.directory?(addon_docs_src).should be_true

      LapisSpecHelper.with_temp_dir("addon_docs_test") do |dir|
        out_dir = dir.join("src/docs")
        root_file = dir.join("src/docs.cr")

        success = Lapis::Docs::Generator.run(
          src_dir: addon_docs_src,
          out_dir: out_dir,
          root_docs_file: root_file
        )
        success.should be_true

        # Verify root docs.cr
        File.exists?(root_file).should be_true
        root_content = File.read(root_file)
        root_content.should contain("module MyAddon")
        root_content.should contain("module Docs")
        root_content.should contain("MyAddon Quick Start:")
        root_content.should contain("require \"./docs/a_getting_started/a_overview\"")
        root_content.should contain("require \"./docs/a_getting_started/b_custom_nodes\"")

        # Verify generated submodules
        custom_nodes_cr = out_dir.join("a_getting_started/b_custom_nodes.cr")
        File.exists?(custom_nodes_cr).should be_true
        nodes_content = File.read(custom_nodes_cr)
        nodes_content.should contain("module MyAddon")
        nodes_content.should contain("module Docs")
        nodes_content.should contain("module A_GETTING_STARTED")
        nodes_content.should contain("module B_CUSTOM_NODES")
        nodes_content.should contain("def self.topic_01_control_nodes : Nil")
      end
    end

    it "discovers benchmarks in template-addon/benchmarks" do
      root = LapisSpecHelper.repo_root
      addon_bench_dir = root.join("template-addon/benchmarks")
      File.directory?(addon_bench_dir).should be_true

      benches = Lapis::Commands::Benchmarks.discover_benchmarks(addon_bench_dir)
      benches.empty?.should be_false
      benches.map(&.name.downcase).should contain("example_bench")
    end
  end

  describe "Benchmark Discovery Edge Cases" do
    it "returns empty array without crashing when benchmarks directory has no benchmarks" do
      LapisSpecHelper.with_temp_dir("empty_bench_test") do |dir|
        benches = Lapis::Commands::Benchmarks.discover_benchmarks(dir)
        benches.should be_empty
      end
    end

    it "discovers nested subdirectory benchmarks (benchmarks/<name>/<name>.cr)" do
      LapisSpecHelper.with_temp_dir("nested_bench_test") do |dir|
        bench_sub = dir.join("complex_math")
        FileUtils.mkdir_p(bench_sub)
        File.write(bench_sub.join("complex_math.cr"), "puts 'math'")
        File.write(bench_sub.join("complex_math.gd"), "extends SceneTree")

        benches = Lapis::Commands::Benchmarks.discover_benchmarks(dir)
        benches.size.should eq(1)
        benches.first.name.should eq("Complex_math")
        benches.first.crystal_src.should eq("complex_math/complex_math.cr")
        benches.first.gdscript_src.should eq("complex_math/complex_math.gd")
      end
    end
  end

  describe "CLI Integration for Template Projects" do
    it "runs lapis benchmark -p template -l and lists Example_bench" do
      res = LapisSpecHelper.run_lapis(["benchmark", "-p", "template", "-l"])
      res.success?.should be_true
      res.output.should contain("Example_bench")
      res.output.should contain("Custom")
    end

    it "runs lapis docs -p template --generate-only and succeeds" do
      res = LapisSpecHelper.run_lapis(["docs", "-p", "template", "--generate-only"])
      res.success?.should be_true
      res.output.should contain("Synthesized Crystal doc classes and master docs.cr!")
    end

    it "runs lapis docs -p template-addon --generate-only and succeeds" do
      res = LapisSpecHelper.run_lapis(["docs", "-p", "template-addon", "--generate-only"])
      res.success?.should be_true
      res.output.should contain("Synthesized Crystal doc classes and master docs.cr!")
    end
  end
end
