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
        is_lapis = root_docs_file.to_s.tr("\\", "/").ends_with?("src/libgodot/docs.cr")
        ns = is_lapis ? "Lapis::Docs" : "Docs"
        config = Jasper::Config.new(
          namespace: ns,
          source_dir: src_dir.to_s,
          output_dir: out_dir.to_s,
          master_file: root_docs_file.to_s
        )
        if is_lapis
          config.add_alias("Docs")
        end
        res = Jasper::Generator.new(config).run
        if is_lapis && File.exists?(root_docs_file)
          content = File.read(root_docs_file)
          first_req = "require \"./docs/"
          if content.includes?(first_req) && !content.includes?("read_file?(\"\#{__DIR__}/docs/")
            start_idx = content.index(first_req).not_nil!
            last_req_idx = content.rindex(first_req).not_nil!
            end_idx = content.index("\n", last_req_idx) || (content.size - 1)
            sub = content[start_idx..end_idx]
            wrapped = "{% if read_file?(\"\#{__DIR__}/docs/a_getting_started/a_installation.cr\") %}\n#{sub}\n{% end %}"
            File.write(root_docs_file, content.sub(sub, wrapped))
          end
        end
        res
      end

      def generate(root_docs_file : Path) : Bool
        self.class.run(@src_dir, @out_dir, root_docs_file)
      end
    end
  end
end
