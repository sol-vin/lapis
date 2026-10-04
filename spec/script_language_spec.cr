require "./spec_helper"
require "../src/libgodot/script/validator"
require "../src/libgodot/script/lsp"
require "../src/libgodot/script/language"

describe "Crystal Script Language & LSP Intelligence (Ring 1 Specs)" do
  describe Lapis::CrystalValidator do
    it "validates a well-formed Crystal node script as valid" do
      code = <<-CRYSTAL
      require "lapis"

      node Player < CharacterBody2D do
        @[Export]
        property speed : Float32 = 200.0_f32

        signal health_changed(current : Int32)

        def _ready : Void
          Godot.print("Player ready")
        end

        def _process(delta : Float64) : Void
          # In-line comment
          return if speed <= 0.0_f32
        end
      end
      CRYSTAL

      res = Lapis::CrystalValidator.validate(code)
      res.valid?.should be_true
      res.errors.should be_empty
    end

    it "detects unclosed blocks with missing 'end'" do
      code = <<-CRYSTAL
      node Enemy < Node2D do
        def attack : Void
          Godot.print("Attack")
      end
      CRYSTAL

      res = Lapis::CrystalValidator.validate(code)
      res.valid?.should be_false
      res.errors.size.should be >= 1
      res.errors.any? { |e| e.message.includes?("missing 'end'") }.should be_true
    end

    it "detects unexpected stray 'end' statements" do
      code = <<-CRYSTAL
      node Bullet < Node2D do
        def fire : Void
        end
        end
      end
      CRYSTAL

      res = Lapis::CrystalValidator.validate(code)
      res.valid?.should be_false
      res.errors.any? { |e| e.message.includes?("Unexpected 'end'") }.should be_true
    end

    it "detects unclosed parentheses and brackets" do
      code = <<-CRYSTAL
      node TestNode < Node do
        def test : Void
          arr = [1, 2, 3
        end
      end
      CRYSTAL

      res = Lapis::CrystalValidator.validate(code)
      res.valid?.should be_false
      res.errors.any? { |e| e.message.includes?("Unclosed '['") }.should be_true
    end

    it "handles postfix modifiers without requiring 'end'" do
      code = <<-CRYSTAL
      node ModifierNode < Node do
        def check : Void
          return if true
          break unless false
        end
      end
      CRYSTAL

      res = Lapis::CrystalValidator.validate(code)
      res.valid?.should be_true
      res.errors.should be_empty
    end
  end

  describe "CrystalLanguage Built-in Templates" do
    it "returns rich built-in templates for Godot script dialog" do
      templates = Lapis::CrystalLanguage.get_built_in_templates("Node")
      templates.size.should be >= 4

      names = templates.map { |t| String.new(t.name) }
      names.should contain("Standard Node")
      names.should contain("Tool Script (@[Tool])")
      names.should contain("Empty Class")
    end

    it "provides 2D movement template for CharacterBody2D" do
      templates = Lapis::CrystalLanguage.get_built_in_templates("CharacterBody2D")
      names = templates.map { |t| String.new(t.name) }
      names.should contain("Physics Movement (2D)")

      tmpl = templates.find { |t| String.new(t.name) == "Physics Movement (2D)" }.not_nil!
      content = String.new(tmpl.content)
      content.should contain("CharacterBody2D")
      content.should contain("move_and_slide")
      content.should contain("_CLASS_")
    end

    it "provides 3D movement template for CharacterBody3D" do
      templates = Lapis::CrystalLanguage.get_built_in_templates("CharacterBody3D")
      names = templates.map { |t| String.new(t.name) }
      names.should contain("Physics Movement (3D)")

      tmpl = templates.find { |t| String.new(t.name) == "Physics Movement (3D)" }.not_nil!
      content = String.new(tmpl.content)
      content.should contain("CharacterBody3D")
      content.should contain("move_and_slide")
      content.should contain("input_dir")
    end
  end

  describe "CrystalLanguage Auto-Indentation" do
    it "applies 2-space indentation to nested blocks" do
      lang = Lapis::CrystalLanguage.new
      unindented = "node MyNode < Node do\ndef hello\nif true\nGodot.print(\"Hi\")\nend\nend\nend"
      indented = lang.auto_indent_code(unindented, 0, 6)

      lines = indented.split("\n")
      lines[0].should eq("node MyNode < Node do")
      lines[1].should eq("  def hello")
      lines[2].should eq("    if true")
      lines[3].should eq("      Godot.print(\"Hi\")")
      lines[4].should eq("    end")
      lines[5].should eq("  end")
      lines[6].should eq("end")
    end
  end

  describe "CrystalLSP Notification & Diagnostics Processing" do
    it "parses and stores textDocument/publishDiagnostics notifications" do
      lsp = Lapis::CrystalLSP.instance
      raw_json = <<-JSON
      {
        "uri": "file:///path/to/my_script.cr",
        "diagnostics": [
          {
            "range": {
              "start": { "line": 4, "character": 6 },
              "end": { "line": 4, "character": 12 }
            },
            "severity": 1,
            "message": "undefined local variable or method 'my_var'"
          }
        ]
      }
      JSON

      params = JSON.parse(raw_json)
      lsp.handle_notification("textDocument/publishDiagnostics", params)

      diags = lsp.get_diagnostics("file:///path/to/my_script.cr")
      diags.should_not be_nil
      diags.not_nil!.size.should eq(1)
      diags.not_nil!.first.line.should eq(5) # 1-based index (4 + 1)
      diags.not_nil!.first.column.should eq(7)
      diags.not_nil!.first.message.should contain("undefined local variable")
    end
  end
end
