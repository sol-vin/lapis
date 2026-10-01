require "jasper"
require "./model"
require "./markdown_converter"

module Lapis
  module Docs
    class Generator
      property src_dir : Path
      property out_dir : Path

      def initialize(src_dir : Path = Path.new("docs_src"), out_dir : Path = Path.new("src/libgodot/docs"))
        @src_dir = src_dir
        @out_dir = out_dir
      end

      # Discovers and compiles all YAML docs into Crystal code using Jasper
      def self.run(
        src_dir : Path = Path.new("docs_src"),
        out_dir : Path = Path.new("src/libgodot/docs"),
        root_docs_file : Path = Path.new("src/libgodot/docs.cr")
      ) : Bool
        is_lapis = root_docs_file.to_s.includes?("libgodot")
        ns = is_lapis ? "Lapis::Docs" : "Docs"
        config = Jasper::Config.new(
          namespace: ns,
          source_dir: src_dir.to_s,
          output_dir: out_dir.to_s,
          master_file: root_docs_file.to_s
        )
        if is_lapis
          config.add_alias("Docs").add_alias("Godot::Docs")
        end
        Jasper::Generator.new(config).run
      end

      def generate(root_docs_file : Path) : Bool
        self.class.run(@src_dir, @out_dir, root_docs_file)
      end
    end
  end
end
