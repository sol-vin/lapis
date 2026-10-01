require "./spec_helper"
require "../src/docs/model"
require "../src/docs/markdown_converter"
require "../src/docs/generator"

describe "Lapis Documentation Engine" do
  describe Lapis::Docs::MarkdownConverter do
    it "converts Markdown pipe tables to semantic HTML tables" do
      markdown = <<-MD
| Header 1 | Header 2 |
| :--- | :--- |
| Cell 1 | Cell 2 |
| **Bold** | `Code` |
MD

      doc_comment = Lapis::Docs::MarkdownConverter.to_doc_comments(markdown)
      doc_comment.should contain("<table>")
      doc_comment.should contain("<thead>")
      doc_comment.should contain("<th>Header 1</th>")
      doc_comment.should contain("<th>Header 2</th>")
      doc_comment.should contain("<tbody>")
      doc_comment.should contain("<td>Cell 1</td>")
      doc_comment.should contain("<td>Cell 2</td>")
      doc_comment.should contain("<td>**Bold**</td>")
      doc_comment.should contain("<td>`Code`</td>")
      doc_comment.should contain("</table>")
      doc_comment.should_not contain("| Header 1 |")
    end

    it "formats method doc comments without intermediate periods to protect Crystal docs summaries" do
      formatted = Lapis::Docs::MarkdownConverter.format_summary_line(
        "First Steps in Lapis.",
        "Detailed explanation of getting started with the engine."
      )

      # Must start with # **Title**: Description without trailing period in title
      formatted.should eq("# **First Steps in Lapis**: Detailed explanation of getting started with the engine.")
    end

    it "preserves non-table text around tables" do
      input = <<-MD
Intro paragraph before table.

| A | B |
| - | - |
| 1 | 2 |

Outro paragraph after table.
MD

      result = Lapis::Docs::MarkdownConverter.to_doc_comments(input)
      result.should contain("Intro paragraph before table.")
      result.should contain("<table>")
      result.should contain("Outro paragraph after table.")
    end
  end

  describe Lapis::Docs::Generator do
    it "compiles YAML doc files into typed Crystal classes with proper hierarchy" do
      LapisSpecHelper.with_temp_dir("docs_gen_test") do |dir|
        src_dir = dir.join("docs_src/01_getting_started")
        FileUtils.mkdir_p(src_dir)

        yaml_content = <<-YAML
id: "A_INSTALLATION"
parent_module: "A_GETTING_STARTED"
title: "Installation Guide"
summary: "Guide to installing Lapis."
sections:
  - id: "topic_01_prerequisites"
    title: "Prerequisites"
    summary: "Required system packages."
    content: |
      Install crystal and godot.
      | Package | Version |
      | :--- | :--- |
      | Crystal | 1.20+ |
YAML
        File.write(src_dir.join("01_installation.yml"), yaml_content)

        out_dir = dir.join("src/libgodot/docs")
        root_file = dir.join("src/libgodot/docs.cr")

        success = Lapis::Docs::Generator.run(
          src_dir: dir.join("docs_src"),
          out_dir: out_dir,
          root_docs_file: root_file
        )
        success.should be_true

        gen_file = out_dir.join("a_getting_started/a_installation.cr")
        File.exists?(gen_file).should be_true

        content = File.read(gen_file)
        content.should contain("module Lapis")
        content.should contain("module Docs")
        content.should contain("module A_GETTING_STARTED")
        content.should contain("module A_INSTALLATION")
        content.should contain("def self.topic_01_prerequisites : Nil")
        content.should contain("<table>")
        content.should contain("{% unless flag?(:release) %}")

        # Check root docs.cr
        File.exists?(root_file).should be_true
        root_content = File.read(root_file)
        root_content.should contain("module Lapis")
        root_content.should contain("module Docs")
        root_content.should contain("require \"./docs/a_getting_started/a_installation\"")
      end
    end
  end

  describe "CLI docs command" do
    it "prints help when --help is passed" do
      res = LapisSpecHelper.run_lapis(["docs", "--help"])
      res.success?.should be_true
      res.output.should contain("Documentation Generator & Patcher")
      res.output.should contain("--generate-only")
      res.output.should contain("--github")
    end

    it "compiles YAML docs in a standalone template project" do
      LapisSpecHelper.with_temp_dir("template_docs_test") do |dir|
        # Create minimal template project
        FileUtils.mkdir_p(dir.join("src"))
        File.write(dir.join("src/main.cr"), "require \"./**\"\nputs \"Hello\"\n")
        File.write(dir.join("shard.yml"), "name: my_game\nversion: 0.1.0\n")
        File.write(dir.join("Makefile"), "all:\n\t@echo ok\n")

        # Create docs_src
        docs_src = dir.join("docs_src/01_guide")
        FileUtils.mkdir_p(docs_src)
        File.write(docs_src.join("01_overview.yml"), <<-YAML
id: "A_OVERVIEW"
parent_module: "A_GUIDE"
title: "Game Architecture"
summary: "Overview of custom game systems."
sections:
  - id: "topic_01_setup"
    title: "Setup"
    summary: "Configuring the game."
    content: "Instructions for game setup."
YAML
        )

        res = LapisSpecHelper.run_lapis(["docs", "--generate-only"], chdir: dir)
        res.success?.should be_true
        File.exists?(dir.join("src/docs/a_guide/a_overview.cr")).should be_true
        File.exists?(dir.join("src/docs.cr")).should be_true
      end
    end
  end
end
