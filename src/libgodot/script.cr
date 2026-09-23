require "./script/highlighter"
require "./script/language"
require "./script/script"
require "./script/resource_format"
require "./script/lsp"

module Lapis
  # Master coordinator for first-class Crystal script support in Godot
  module ScriptIntegration
    @@lsp : CrystalLSP = CrystalLSP.instance

    def self.lsp : CrystalLSP
      @@lsp
    end

    # Returns syntax highlighting spans for a line of code
    def self.highlight_line(line : String) : Array(SyntaxSpan)
      CrystalHighlighter.highlight_line(line)
    end
  end
end

alias ScriptIntegration = Lapis::ScriptIntegration

module Godot
  alias ScriptIntegration = ::Lapis::ScriptIntegration
end
