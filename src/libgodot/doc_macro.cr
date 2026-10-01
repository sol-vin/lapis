module Godot
  # Stores accumulated XML documentation generated at compile time
  class EditorDocRegistry
    {% unless flag?(:release) || flag?(:no_doc) || flag?(:no_editor_docs) %}
      class_getter xml_documents = Array(String).new

      def self.register(xml : String) : Void
        @@xml_documents << xml
      end

      def self.load_all : Void
        return if @@xml_documents.empty?
        @@xml_documents.each do |xml|
          Bridge.load_editor_help(xml)
        end
      end
    {% else %}
      def self.register(xml : String) : Void
      end

      def self.load_all : Void
      end
    {% end %}
  end

  # Helper for safely escaping XML text and attribute content
  module XML
    def self.escape(str : String) : String
      return "" if str.empty?
      str.gsub('&', "&amp;")
        .gsub('<', "&lt;")
        .gsub('>', "&gt;")
        .gsub('"', "&quot;")
        .gsub('\'', "&apos;")
    end
  end
end

# Annotation for explicit documentation on methods, properties, or classes
annotation Doc
end
