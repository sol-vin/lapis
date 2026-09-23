module Godot
  # Stores accumulated XML documentation generated at compile time
  class EditorDocRegistry
    class_getter xml_documents = Array(String).new

    def self.register(xml : String)
      {% unless flag?(:release) %}
        @@xml_documents << xml
      {% end %}
    end

    def self.load_all
      {% unless flag?(:release) %}
        return if @@xml_documents.empty?
        @@xml_documents.each do |xml|
          Bridge.load_editor_help(xml)
        end
      {% end %}
    end
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
