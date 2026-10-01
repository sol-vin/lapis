# =============================================================================
# LibGodot - Source Indexer for Lapis DSL Nodes, Exports, and Signals
# =============================================================================
# Statically scans Crystal files to harvest Godot node declarations, exported
# properties, signals, and methods for radare2 symbol flagging and source comments.

require "cradare2"
require "json"

module Lapis
  module Debugger
    # Represents a Godot class declared via `node ClassName < ParentClass do`.
    struct DeclaredNode
      include JSON::Serializable

      getter name : String
      getter parent_name : String
      getter file : String
      getter line : Int32
      getter doc_comment : String?

      def initialize(@name : String, @parent_name : String, @file : String, @line : Int32, @doc_comment : String? = nil)
      end
    end

    # Represents an exported property declared via `@[Export] property ...`.
    struct DeclaredProperty
      include JSON::Serializable

      getter node_name : String
      getter name : String
      getter type_name : String
      getter file : String
      getter line : Int32

      def initialize(@node_name : String, @name : String, @type_name : String, @file : String, @line : Int32)
      end
    end

    # Represents a signal declared via `signal name(...)`.
    struct DeclaredSignal
      include JSON::Serializable

      getter node_name : String
      getter name : String
      getter signature : String
      getter file : String
      getter line : Int32

      def initialize(@node_name : String, @name : String, @signature : String, @file : String, @line : Int32)
      end
    end

    # Static AST and DSL scanner indexing Crystal files without requiring a full compiler pass.
    class SourceIndexer
      getter nodes : Array(DeclaredNode) = [] of DeclaredNode
      getter properties : Array(DeclaredProperty) = [] of DeclaredProperty
      getter signals : Array(DeclaredSignal) = [] of DeclaredSignal

      # Indexes an individual Crystal source file.
      def index_file(path : String) : Nil
        return unless File.exists?(path)
        content = File.read(path)
        index_content(content, path)
      end

      # Indexes source content string.
      def index_content(content : String, file : String) : Nil
        current_node : String? = nil
        pending_comment : String? = nil

        content.each_line.with_index(1) do |line, line_num|
          trimmed = line.strip

          # Capture doc comments directly preceding definitions
          if trimmed.starts_with?('#')
            comment_text = trimmed.lchop('#').strip
            pending_comment = (pending_comment ? "#{pending_comment}\n#{comment_text}" : comment_text)
            next
          end

          # Match: node ClassName < ParentClass do
          if trimmed =~ /\bnode\s+([A-Za-z0-9_:]+)\s*<\s*([A-Za-z0-9_:]+)/
            class_name = $1
            parent_name = $2
            @nodes << DeclaredNode.new(class_name, parent_name, file, line_num, pending_comment)
            current_node = class_name
            pending_comment = nil
            next
          end

          # Match: signal signal_name(args...) or signal signal_name
          if current_node && (m = trimmed.match(/\bsignal\s+([A-Za-z0-9_]+)(\s*\(.*?\))?/))
            sig_name = m[1]
            sig_args = m[2]? || ""
            @signals << DeclaredSignal.new(current_node, sig_name, "#{sig_name}#{sig_args}", file, line_num)
            pending_comment = nil
            next
          end

          # Match: property prop_name : Type
          if current_node && trimmed =~ /\bproperty\s+([A-Za-z0-9_]+)\s*:\s*([A-Za-z0-9_:]+)/
            prop_name = $1
            prop_type = $2
            @properties << DeclaredProperty.new(current_node, prop_name, prop_type, file, line_num)
            pending_comment = nil
            next
          end

          # Reset pending comment if non-empty, non-definition line encountered
          pending_comment = nil unless trimmed.empty?
        end
      end

      # Recursively scans directories for .cr source files.
      def index_directory(dir_path : String) : Nil
        return unless Dir.exists?(dir_path)
        Dir.glob(File.join(dir_path, "**", "*.cr")).each do |f|
          index_file(f)
        end
      end

      # Injects indexed metadata into a live radare2 session.
      def inject_into_radare(client : Cradare2::Client) : Nil
        # Use dedicated flag space for Lapis DSL constructs
        client.flags.space("lapis") do |f|
          @nodes.each do |node|
            # Inject flag for node class definition line if lines mapping exists
            flag_name = "lapis.class.#{node.name.gsub("::", "_")}"
            # Associate source comment at file:line
            if addr = client.crystal.lines.for_line(node.file, node.line).first?.try(&.address)
              f.set(flag_name, addr)
              comment_body = "[Lapis Node] #{node.name} < #{node.parent_name}"
              comment_body += "\n#{node.doc_comment}" if node.doc_comment
              client.comments.set(addr, comment_body)
            end
          end

          @signals.each do |sig|
            flag_name = "lapis.signal.#{sig.node_name.gsub("::", "_")}.#{sig.name}"
            if addr = client.crystal.lines.for_line(sig.file, sig.line).first?.try(&.address)
              f.set(flag_name, addr)
              client.comments.set(addr, "[Lapis Signal] #{sig.node_name}##{sig.signature}")
            end
          end

          @properties.each do |prop|
            flag_name = "lapis.prop.#{prop.node_name.gsub("::", "_")}.#{prop.name}"
            if addr = client.crystal.lines.for_line(prop.file, prop.line).first?.try(&.address)
              f.set(flag_name, addr)
              client.comments.set(addr, "[Lapis Property] #{prop.node_name}##{prop.name} : #{prop.type_name}")
            end
          end
        end
      end
    end
  end
end
