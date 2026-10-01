# tools/lapis/src/docs/indexer.cr
require "json"
require "yaml"
require "./model"
require "../core/env"
require "../core/logger"
require "opal"

module Lapis
  module Docs
    class Indexer
      getter symbols = Hash(String, DocSymbol).new
      getter symbols_by_context = Hash(Context, Array(DocSymbol)).new

      def initialize
        Context.each do |ctx|
          @symbols_by_context[ctx] = [] of DocSymbol
        end
      end

      def self.build(root : Path? = nil) : self
        target_root = root || Core::Env::ROOT_DIR
        indexer = new
        indexer.index_godot_api(target_root)
        indexer.index_crystal_project(target_root)
        indexer.index_crystal_stdlib
        indexer.index_lapis_guides(target_root)
        indexer
      end

      def add_symbol(sym : DocSymbol) : Nil
        key = "#{sym.context}:#{sym.full_query}".downcase
        @symbols[key] = sym
        @symbols_by_context[sym.context] << sym
      end

      # 1. Index Godot Engine ClassDB API from extension_api.json
      def index_godot_api(root : Path) : Nil
        candidates = [
          root.join("extension_api.json"),
          root.join("rsrc/extension_api.json"),
          Core::Env::ROOT_DIR.join("extension_api.json"),
          Core::Env::ROOT_DIR.join("rsrc/extension_api.json"),
        ]

        api_file = candidates.find { |p| File.exists?(p) }
        return unless api_file

        begin
          content = File.read(api_file)
          data = JSON.parse(content)

          if classes = data["classes"]?.try(&.as_a)
            classes.each do |c|
              c_name = c["name"]?.try(&.as_s) || ""
              next if c_name.empty?

              inherits = c["inherits"]?.try(&.as_s)
              c_desc = c["description"]?.try(&.as_s) || ""
              c_summary = c["brief_description"]?.try(&.as_s) || c_desc.lines.first? || ""

              inheritance_chain = [] of String
              inheritance_chain << inherits if inherits

              # Add Class symbol
              add_symbol(DocSymbol.new(
                context: Context::Godot,
                kind: SymbolKind::Class,
                name: c_name,
                full_query: c_name,
                signature: inherits ? "class #{c_name} extends #{inherits}" : "class #{c_name}",
                summary: c_summary,
                description: c_desc,
                inheritance: inheritance_chain
              ))

              # Add Methods
              if methods = c["methods"]?.try(&.as_a)
                methods.each do |m|
                  m_name = m["name"]?.try(&.as_s) || ""
                  next if m_name.empty?

                  ret_type = m["return_value"]?.try(&.[]?("type")).try(&.as_s) || "void"
                  m_desc = m["description"]?.try(&.as_s) || ""

                  params = [] of DocParam
                  arg_strs = [] of String
                  if args = m["arguments"]?.try(&.as_a)
                    args.each do |a|
                      a_name = a["name"]?.try(&.as_s) || "arg"
                      a_type = a["type"]?.try(&.as_s) || "Variant"
                      params << DocParam.new(a_name, a_type)
                      arg_strs << "#{a_name}: #{a_type}"
                    end
                  end

                  sig = "func #{m_name}(#{arg_strs.join(", ")}) -> #{ret_type}"

                  add_symbol(DocSymbol.new(
                    context: Context::Godot,
                    kind: SymbolKind::Method,
                    parent_name: c_name,
                    name: m_name,
                    full_query: "#{c_name}.#{m_name}",
                    signature: sig,
                    summary: m_desc.lines.first? || "",
                    description: m_desc,
                    return_type: ret_type,
                    inheritance: inheritance_chain,
                    params: params
                  ))
                end
              end

              # Add Properties
              if props = c["properties"]?.try(&.as_a)
                props.each do |p|
                  p_name = p["name"]?.try(&.as_s) || ""
                  next if p_name.empty?
                  p_type = p["type"]?.try(&.as_s) || "Variant"
                  p_desc = p["description"]?.try(&.as_s) || ""

                  add_symbol(DocSymbol.new(
                    context: Context::Godot,
                    kind: SymbolKind::Property,
                    parent_name: c_name,
                    name: p_name,
                    full_query: "#{c_name}.#{p_name}",
                    signature: "var #{p_name}: #{p_type}",
                    summary: p_desc.lines.first? || "",
                    description: p_desc,
                    return_type: p_type,
                    inheritance: inheritance_chain
                  ))
                end
              end

              # Add Signals
              if sigs = c["signals"]?.try(&.as_a)
                sigs.each do |s|
                  s_name = s["name"]?.try(&.as_s) || ""
                  next if s_name.empty?
                  s_desc = s["description"]?.try(&.as_s) || ""

                  sig_params = [] of DocParam
                  sig_arg_strs = [] of String
                  if args = s["arguments"]?.try(&.as_a)
                    args.each do |a|
                      a_name = a["name"]?.try(&.as_s) || "arg"
                      a_type = a["type"]?.try(&.as_s) || "Variant"
                      sig_params << DocParam.new(a_name, a_type)
                      sig_arg_strs << "#{a_name}: #{a_type}"
                    end
                  end

                  add_symbol(DocSymbol.new(
                    context: Context::Godot,
                    kind: SymbolKind::Signal,
                    parent_name: c_name,
                    name: s_name,
                    full_query: "#{c_name}.#{s_name}",
                    signature: "signal #{s_name}(#{sig_arg_strs.join(", ")})",
                    summary: s_desc.lines.first? || "",
                    description: s_desc,
                    inheritance: inheritance_chain,
                    params: sig_params
                  ))
                end
              end
            end
          end
        rescue ex
          Core::Logger.warn("Failed to index extension_api.json: #{ex.message}")
        end
      end

      # 2. Index Crystal Project Nodes & Methods from src/**/*.cr
      def index_crystal_project(root : Path) : Nil
        src_pattern = root.join("src/**/*.cr").to_s.gsub('\\', '/')
        Dir.glob(src_pattern).each do |file_path|
          next if file_path.includes?("/libgodot/docs/")
          next if file_path.includes?("/spec/")

          begin
            lines = File.read_lines(file_path)
            rel_file = Path.new(file_path).relative_to(root).to_s.gsub('\\', '/')

            current_class : String? = nil
            current_parent : String? = nil
            doc_comments = [] of String

            lines.each_with_index do |line, line_num|
              trimmed = line.strip

              if trimmed.starts_with?("#")
                doc_comments << trimmed.lstrip("#").strip
                next
              end

              # Check node or class declaration
              if m = trimmed.match(/^(?:node|class)\s+([A-Za-z0-9_:]+)(?:\s*<\s*([A-Za-z0-9_:]+))?/)
                current_class = m[1]
                current_parent = m[2]?
                doc_text = doc_comments.join("\n")
                doc_comments.clear

                add_symbol(DocSymbol.new(
                  context: Context::Crystal,
                  kind: SymbolKind::Node,
                  name: current_class,
                  full_query: current_class,
                  signature: current_parent ? "node #{current_class} < #{current_parent}" : "class #{current_class}",
                  summary: doc_text.lines.first? || "Crystal game node",
                  description: doc_text,
                  inheritance: current_parent ? [current_parent] : [] of String,
                  file_path: rel_file,
                  line_number: line_num + 1
                ))
                next
              end

              # Check method declaration
              if m = trimmed.match(/^def\s+(self\.)?([a-zA-Z0-9_!?=]+)(\(.*?\))?(?:\s*:\s*([a-zA-Z0-9_!?=:| ]+))?/)
                is_class_method = !m[1]?.nil?
                m_name = m[2]
                args_str = m[3]? || "()"
                ret_str = m[4]? || "Void"
                doc_text = doc_comments.join("\n")
                doc_comments.clear

                full_q = if (c = current_class)
                           is_class_method ? "#{c}.#{m_name}" : "#{c}##{m_name}"
                         else
                           m_name
                         end

                sig = "def #{is_class_method ? "self." : ""}#{m_name}#{args_str} : #{ret_str}"

                add_symbol(DocSymbol.new(
                  context: Context::Crystal,
                  kind: SymbolKind::Method,
                  parent_name: current_class,
                  name: m_name,
                  full_query: full_q,
                  signature: sig,
                  summary: doc_text.lines.first? || "",
                  description: doc_text,
                  return_type: ret_str,
                  file_path: rel_file,
                  line_number: line_num + 1
                ))
                next
              end

              # Check property declaration
              if m = trimmed.match(/^property(?:\?|!)?\s+([a-zA-Z0-9_]+)\s*:\s*([a-zA-Z0-9_!?=:| ]+)/)
                p_name = m[1]
                p_type = m[2]
                doc_text = doc_comments.join("\n")
                doc_comments.clear

                full_q = current_class ? "#{current_class}@#{p_name}" : p_name

                add_symbol(DocSymbol.new(
                  context: Context::Crystal,
                  kind: SymbolKind::Property,
                  parent_name: current_class,
                  name: p_name,
                  full_query: full_q,
                  signature: "property #{p_name} : #{p_type}",
                  summary: doc_text.lines.first? || "",
                  description: doc_text,
                  return_type: p_type,
                  file_path: rel_file,
                  line_number: line_num + 1
                ))
                next
              end

              # Check signal declaration
              if m = trimmed.match(/^signal\s+([a-zA-Z0-9_]+)(\(.*?\))?/)
                s_name = m[1]
                s_args = m[2]? || ""
                doc_text = doc_comments.join("\n")
                doc_comments.clear

                full_q = current_class ? "#{current_class}.#{s_name}" : s_name

                add_symbol(DocSymbol.new(
                  context: Context::Crystal,
                  kind: SymbolKind::Signal,
                  parent_name: current_class,
                  name: s_name,
                  full_query: full_q,
                  signature: "signal #{s_name}#{s_args}",
                  summary: doc_text.lines.first? || "",
                  description: doc_text,
                  file_path: rel_file,
                  line_number: line_num + 1
                ))
                next
              end

              # Clear doc comments on non-doc, non-empty code lines
              doc_comments.clear unless trimmed.empty?
            end
          rescue
          end
        end
      end

      # 3. Index Core Crystal Standard Library References
      def index_crystal_stdlib : Nil
        stdlib_items = [
          {
            name: "Fiber",
            sig: "class Fiber",
            sum: "Lightweight cooperative execution unit scheduled on Crystal threads.",
            desc: "Fibers yield control cooperatively. In Lapis, spawned fibers must yield via Fiber.yield in _process to prevent starving Godot's main loop.",
            methods: [
              {"yield", "def self.yield : Nil", "Yields control to another ready fiber on the execution context."},
              {"current", "def self.current : Fiber", "Returns the currently executing fiber instance."}
            ]
          },
          {
            name: "Channel(T)",
            sig: "class Channel(T)",
            sum: "Thread-safe communication queue between concurrent fibers and OS threads.",
            desc: "Cross-thread workers must use buffered channels: Channel(T).new(capacity). Avoid unbuffered channels on raw Thread.new to prevent execution context suspension panics.",
            methods: [
              {"send", "def send(value : T) : Nil", "Sends a value into the channel, blocking if capacity is full."},
              {"receive", "def receive : T", "Receives a value from the channel, blocking until data is available."},
              {"close", "def close : Nil", "Closes the channel, waking any waiting receivers with Channel::ClosedError."}
            ]
          },
          {
            name: "Thread::Mutex",
            sig: "class Thread::Mutex",
            sum: "Mutual exclusion synchronization primitive for multithreaded data structures.",
            desc: "Protects shared Crystal collections (Hash, Array) when mutated across multiple background OS worker threads.",
            methods: [
              {"synchronize", "def synchronize(&block) : U", "Acquires the mutex, yields to the given block, and releases lock on return."}
            ]
          }
        ]

        stdlib_items.each do |item|
          add_symbol(DocSymbol.new(
            context: Context::Stdlib,
            kind: SymbolKind::Class,
            name: item[:name],
            full_query: item[:name],
            signature: item[:sig],
            summary: item[:sum],
            description: item[:desc]
          ))

          item[:methods].each do |m_info|
            m_name, m_sig, m_desc = m_info
            add_symbol(DocSymbol.new(
              context: Context::Stdlib,
              kind: SymbolKind::Method,
              parent_name: item[:name],
              name: m_name,
              full_query: "#{item[:name]}##{m_name}",
              signature: m_sig,
              summary: m_desc,
              description: m_desc
            ))
          end
        end
      end

      # 4. Index Lapis Architectural & Topic Guides
      def index_lapis_guides(root : Path) : Nil
        docs_src = root.join("docs_src")
        return unless Dir.exists?(docs_src)

        Dir.glob(docs_src.join("**/*.yml").to_s.gsub('\\', '/')).each do |yml_file|
          begin
            content = File.read(yml_file)
            data = YAML.parse(content)

            id = data["id"]?.try(&.as_s) || Path.new(yml_file).basename(".yml")
            title = data["title"]?.try(&.as_s) || id.split("_").map(&.capitalize).join(" ")
            summary = data["summary"]?.try(&.as_s) || ""
            overview = data["overview"]?.try(&.as_s) || summary

            full_desc = overview
            if sections = data["sections"]?.try(&.as_a)
              full_desc += "\n\n" + sections.compact_map do |s|
                s_title = s["title"]?.try(&.as_s) || ""
                s_sum = s["summary"]?.try(&.as_s) || ""
                s_content = s["content"]?.try(&.as_s) || ""
                "### #{s_title}\n#{s_sum}\n\n#{s_content}"
              end.join("\n\n")
            end

            dir_name = Path.new(yml_file).parent.basename
            category = dir_name.sub(/^\d+_/, "")

            add_symbol(DocSymbol.new(
              context: Context::Guide,
              kind: SymbolKind::Guide,
              name: id,
              full_query: "guide:#{category}:#{id}",
              signature: "Guide [#{category}]: #{title}",
              summary: "[#{category}] #{summary}",
              description: full_desc
            ))
          rescue
          end
        end
      end

      # Symbol Lookup with context routing
      def lookup(context : Context?, query : String) : Array(DocSymbol)
        clean = query.strip
        return [] of DocSymbol if clean.empty?

        candidates = if ctx = context
                       @symbols_by_context[ctx]? || [] of DocSymbol
                     else
                       @symbols.values
                     end

        # 1. Exact match on full_query or name (case-insensitive)
        exact = candidates.select do |s|
          s.full_query.compare(clean, case_insensitive: true) == 0 ||
            s.name.compare(clean, case_insensitive: true) == 0 ||
            s.full_query.ends_with?(".#{clean}") ||
            s.full_query.ends_with?("##{clean}") ||
            s.full_query.ends_with?(":#{clean}")
        end
        return exact unless exact.empty?

        # 2. Substring match on name, full_query, signature, or summary
        clean_lower = clean.downcase
        substring_matches = candidates.select do |s|
          s.name.downcase.includes?(clean_lower) ||
            s.full_query.downcase.includes?(clean_lower) ||
            s.signature.downcase.includes?(clean_lower) ||
            s.summary.downcase.includes?(clean_lower)
        end
        return substring_matches unless substring_matches.empty?

        # 3. Fuzzy match fallback
        fuzzy_search(clean, candidates)
      end

      # Exact single symbol lookup or first match
      def find_exact(query : String, context : Context? = nil) : DocSymbol?
        results = lookup(context, query)
        results.first?
      end

      # Full-text search across symbols
      def search(query : String, context : Context? = nil) : Array(DocSymbol)
        clean = query.strip.downcase
        return [] of DocSymbol if clean.empty?

        candidates = if ctx = context
                       @symbols_by_context[ctx]? || [] of DocSymbol
                     else
                       @symbols.values
                     end

        matches = candidates.select do |s|
          s.name.downcase.includes?(clean) ||
            s.full_query.downcase.includes?(clean) ||
            s.signature.downcase.includes?(clean) ||
            s.summary.downcase.includes?(clean) ||
            s.description.downcase.includes?(clean)
        end

        matches.sort_by do |s|
          # Prioritize name matches over description matches
          if s.name.downcase == clean
            0
          elsif s.name.downcase.starts_with?(clean)
            1
          elsif s.full_query.downcase.includes?(clean)
            2
          else
            3
          end
        end
      end

      def fuzzy_search(query : String, candidates : Array(DocSymbol)) : Array(DocSymbol)
        clean = query.strip.downcase
        candidates.compact_map do |s|
          if m = Opal::Input::Fuzzy.match(clean, s.full_query.downcase)
            {s, m.score}
          else
            nil
          end
        end.sort_by { |item| -item[1] }.first(20).map { |item| item[0] }
      end
    end
  end
end
