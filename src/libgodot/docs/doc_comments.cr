module Lapis
  module Docs
    # # E. Doc Comments & Editor Help XML Generation
    #
    # One of the most powerful features of LibGodot is its **automated compile-time
    # documentation harvesting system**. Standard Crystal doc comments (`# ...`) written
    # above classes, properties, signals, and methods are automatically parsed and registered
    # into Godot's offline `EditorHelp` documentation subsystem.
    #
    # ---
    #
    # ### How Doc Comments Flow from Crystal to Godot
    #
    # ```
    # Crystal Source Code (# Comments)
    #          │
    #          ▼ (Compile time: node macro read_file)
    # Dynamic XML Generation (<class>, <members>, <signals>)
    #          │
    #          ▼ (crystal_godot_init)
    # EditorDocRegistry.load_all
    #          │
    #          ▼ (Bridge: GDExtensionEditorHelp::load_xml_buffer)
    # Godot Editor Inspector Tooltips & F1 Help Page
    # ```
    #
    # 1. At compile time, the `node` macro executes `read_file(block.filename)`.
    # 2. It scans lines immediately preceding:
    #    - The `node ClassName` definition (class brief & full description)
    #    - Each `property` declaration (property doc comment)
    #    - Each `signal` declaration (signal description)
    #    - Each `def` method (method description)
    # 3. An in-memory XML string matching Godot's official `DocData` specification is synthesized:
    #    ```xml
    #    <?xml version="1.0" encoding="UTF-8" ?>
    #    <class name="SpinningCrystal" inherits="Area3D">
    #      <brief_description>Collectible item that rotates in 3D space</brief_description>
    #      <description>Collectible item that rotates in 3D space</description>
    #      <members>
    #        <member name="rotation_speed" type="float">Rotation rate in rad/s</member>
    #      </members>
    #      <signals>
    #        <signal name="collected">
    #          <description>Emitted when a character collects this item</description>
    #        </signal>
    #      </signals>
    #    </class>
    #    ```
    # 4. During library initialization (`crystal_godot_init`), `EditorDocRegistry.load_all`
    #    hands each XML document to `Bridge.load_editor_help(xml)`.
    # 5. The bridge invokes Godot's `GDExtensionEditorHelp::load_xml_buffer`.
    # 6. Inside the Godot Editor:
    #    - Hovering over a property in the **Inspector** displays the exact Crystal doc comment.
    #    - Pressing **F1** (Search Help) lists your custom Crystal classes alongside native Godot nodes.
    #
    # ---
    #
    # ### Example Code
    #
    # ```
    # # Floating power-up item that rotates and restores player health
    # node HealthPotion < Area3D do
    #   # Amount of health points restored upon pickup
    #   @[Export(range: 5..100, step: 5)]
    #   property heal_amount : Int32 = 25
    #
    #   # Emitted when a player body consumes this potion
    #   signal consumed(player : Node3D)
    #
    #   # Triggers consumption of the health potion
    #   def consume!(player : Node3D) : Void
    #     emit_consumed(player)
    #     queue_free
    #   end
    # end
    # ```
    module E_DOC_COMMENTS_AND_HELP
      # Dummy method for documentation visibility
      def self.schema : String
        "Godot DocData XML format (<class>, <brief_description>, <members>, <signals>, <methods>)"
      end
    end
  end
end

