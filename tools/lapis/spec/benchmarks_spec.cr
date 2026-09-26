require "./spec_helper"
require "../src/commands/benchmarks"
require "../src/commands/package"
require "../../../src/libgodot/benchmarks"

describe "Lapis Benchmarks & Installer Command Specifications" do
  it "lists all 24 registered builtin benchmarks via builtin_benchmarks" do
    benches = Lapis::Commands::Benchmarks.builtin_benchmarks
    benches.size.should eq(24)
    benches.map(&.name).should contain("Matmul")
    benches.map(&.name).should contain("Primes")
    benches.map(&.name).should contain("NodeLifecycle")
    benches.map(&.name).should contain("Signals")
  end

  it "serializes and parses benchmark XML accurately without data loss" do
    metrics = [
      Lapis::Commands::Benchmarks::BenchmarkMetric.new(
        name: "Matmul",
        category: Lapis::Commands::Benchmarks::Category::Compute,
        crystal_ms: 12.34,
        gdscript_ms: 185.12,
        speedup: 15.0,
        description: "Dense 2D matrix multiplication",
        editor_ms: 195.0,
        editor_overhead_ratio: 1.05
      ),
      Lapis::Commands::Benchmarks::BenchmarkMetric.new(
        name: "NodeLifecycle",
        category: Lapis::Commands::Benchmarks::Category::EngineCore,
        crystal_ms: 45.67,
        gdscript_ms: 220.0,
        speedup: 4.82,
        description: "Node2D lifecycle operations",
        editor_ms: nil,
        editor_overhead_ratio: nil
      ),
    ]

    xml = Lapis::Commands::Benchmarks::XmlHandler.generate_xml(
      metrics: metrics,
      version: "0.0.98",
      godot_ver: "4.8-dev6",
      iterations: 3,
      platform: "windows"
    )

    xml.should contain("<?xml version=\"1.0\"")
    xml.should contain("<benchmarks version=\"0.0.98\"")
    xml.should contain("<case name=\"Matmul\" category=\"Compute\">")
    xml.should contain("<crystal ms=\"12.34\" />")
    xml.should contain("<gdscript ms=\"185.12\" />")
    xml.should contain("<editor ms=\"195.0\" overhead_ratio=\"1.05\" />")
    xml.should contain("<case name=\"NodeLifecycle\" category=\"EngineCore\">")

    meta, parsed = Lapis::Commands::Benchmarks::XmlHandler.parse_xml(xml)
    meta["version"].should eq("0.0.98")
    meta["platform"].should eq("windows")
    meta["godot"].should eq("4.8-dev6")
    meta["iterations"].should eq("3")

    parsed.size.should eq(2)
    m1 = parsed[0]
    m1.name.should eq("Matmul")
    m1.category.should eq(Lapis::Commands::Benchmarks::Category::Compute)
    m1.crystal_ms.should eq(12.34)
    m1.gdscript_ms.should eq(185.12)
    m1.editor_ms.should eq(195.0)
    (m1.speedup >= 14.9 && m1.speedup <= 15.1).should be_true

    m2 = parsed[1]
    m2.name.should eq("NodeLifecycle")
    m2.crystal_ms.should eq(45.67)
    m2.editor_ms.should be_nil
  end

  it "generates XML comparison diff between current and previous versions" do
    prev_metrics = [
      Lapis::Commands::Benchmarks::BenchmarkMetric.new("Matmul", Lapis::Commands::Benchmarks::Category::Compute, 14.50, 185.0, 12.76, "desc"),
      Lapis::Commands::Benchmarks::BenchmarkMetric.new("Primes", Lapis::Commands::Benchmarks::Category::Compute, 50.0, 200.0, 4.0, "desc"),
    ]
    curr_metrics = [
      Lapis::Commands::Benchmarks::BenchmarkMetric.new("Matmul", Lapis::Commands::Benchmarks::Category::Compute, 12.34, 185.0, 15.0, "desc"),
      Lapis::Commands::Benchmarks::BenchmarkMetric.new("Primes", Lapis::Commands::Benchmarks::Category::Compute, 45.0, 200.0, 4.44, "desc"),
    ]

    comp_xml = Lapis::Commands::Benchmarks::XmlHandler.generate_comparison_xml(curr_metrics, prev_metrics, "0.0.98", "0.0.97")
    comp_xml.should contain("<benchmark_comparison current_version=\"0.0.98\" previous_version=\"0.0.97\"")
    comp_xml.should contain("<summary")
    comp_xml.should contain("<case name=\"Matmul\"")
    comp_xml.should contain("status=\"improved\"")
  end

  it "generates interactive HTML comparison report" do
    prev_metrics = [
      Lapis::Commands::Benchmarks::BenchmarkMetric.new("Matmul", Lapis::Commands::Benchmarks::Category::Compute, 14.50, 185.0, 12.76, "Matrix mult"),
    ]
    curr_metrics = [
      Lapis::Commands::Benchmarks::BenchmarkMetric.new("Matmul", Lapis::Commands::Benchmarks::Category::Compute, 12.34, 185.0, 15.0, "Matrix mult"),
    ]

    html = Lapis::Commands::Benchmarks::HtmlGenerator.generate_comparison_html(curr_metrics, prev_metrics, "0.0.98", "0.0.97")
    html.should contain("<!DOCTYPE html>")
    html.should contain("Lapis Benchmark Version Progression")
    html.should contain("v0.0.97")
    html.should contain("v0.0.98")
    html.should contain("Matmul")
    html.should contain("faster")
  end

  it "renders standalone HTML dashboard report from metrics" do
    metrics = [
      Lapis::Commands::Benchmarks::BenchmarkMetric.new("Matmul", Lapis::Commands::Benchmarks::Category::Compute, 12.34, 185.0, 15.0, "Matrix mult"),
    ]

    html = Lapis::Commands::Benchmarks::HtmlGenerator.generate_report(metrics, "0.0.98", "windows", "4.8")
    html.should contain("<!DOCTYPE html>")
    html.should contain("Lapis Benchmark Suite: Performance Report")
    html.should contain("Geometric Mean Speedup")
    html.should contain("Matmul")
    html.should contain("<svg")
  end

  it "exports HTML report directly from XML via CLI command" do
    scratch_dir = Path.new("scratch/spec_benchmarks").expand
    FileUtils.mkdir_p(scratch_dir)

    xml_file = scratch_dir.join("test_run.xml")
    html_file = scratch_dir.join("test_run.html")

    metrics = [
      Lapis::Commands::Benchmarks::BenchmarkMetric.new("Matmul", Lapis::Commands::Benchmarks::Category::Compute, 12.34, 185.0, 15.0, "Matrix mult"),
    ]
    xml_data = Lapis::Commands::Benchmarks::XmlHandler.generate_xml(metrics, "0.0.98", "4.8", 3, "windows")
    File.write(xml_file, xml_data)

    code = Lapis::Commands::Benchmarks.run(["export", "html", "--from=#{xml_file}", "-o", html_file.to_s])
    code.should eq(0)
    File.exists?(html_file).should be_true
    content = File.read(html_file)
    content.should contain("Lapis Benchmark Suite")
    content.should contain("Matmul")

    FileUtils.rm_rf(scratch_dir)
  end

  it "compares two XML files via CLI compare and compare html commands" do
    scratch_dir = Path.new("scratch/spec_compare").expand
    FileUtils.mkdir_p(scratch_dir)

    prev_xml = scratch_dir.join("prev.xml")
    curr_xml = scratch_dir.join("curr.xml")
    out_xml = scratch_dir.join("diff.xml")
    out_html = scratch_dir.join("diff.html")

    p_metrics = [Lapis::Commands::Benchmarks::BenchmarkMetric.new("Matmul", Lapis::Commands::Benchmarks::Category::Compute, 15.0, 180.0, 12.0, "desc")]
    c_metrics = [Lapis::Commands::Benchmarks::BenchmarkMetric.new("Matmul", Lapis::Commands::Benchmarks::Category::Compute, 12.0, 180.0, 15.0, "desc")]

    File.write(prev_xml, Lapis::Commands::Benchmarks::XmlHandler.generate_xml(p_metrics, "0.0.97", "4.8", 3, "windows"))
    File.write(curr_xml, Lapis::Commands::Benchmarks::XmlHandler.generate_xml(c_metrics, "0.0.98", "4.8", 3, "windows"))

    code_xml = Lapis::Commands::Benchmarks.run(["compare", "--current=#{curr_xml}", "--previous=#{prev_xml}", "-o", out_xml.to_s])
    code_xml.should eq(0)
    File.exists?(out_xml).should be_true
    File.read(out_xml).should contain("<benchmark_comparison")

    code_html = Lapis::Commands::Benchmarks.run(["compare", "html", "--current=#{curr_xml}", "--previous=#{prev_xml}", "-o", out_html.to_s])
    code_html.should eq(0)
    File.exists?(out_html).should be_true
    File.read(out_html).should contain("Lapis Benchmark Version Progression")

    FileUtils.rm_rf(scratch_dir)
  end

  it "registers and executes in-engine benchmarks using Lapis::Benchmark DSL" do
    Lapis::Benchmark.clear
    executed = 0

    Lapis::Benchmark.register("MathTest", category: Lapis::Benchmark::Category::Compute, description: "Unit math check") do |iter|
      executed += 1
      x = 0
      1000.times { x += 1 }
    end

    Lapis::Benchmark.all.size.should eq(1)
    results = Lapis::Benchmark.run_all(iterations: 2)
    results.size.should eq(1)
    results.first.name.should eq("MathTest")
    results.first.samples_ms.size.should eq(2)
    executed.should eq(2)

    Lapis::Benchmark.clear
  end

  it "detects project name and version in package helper" do
    template_dir = Path.new("template").expand
    if Dir.exists?(template_dir)
      name = Lapis::Commands::Package.detect_project_name(template_dir)
      name.should_not be_empty

      version = Lapis::Commands::Package.detect_project_version(template_dir)
      version.should_not be_empty
    end
  end
end
