module Lapis
  module Docs
    # # E. Doc Comments & Editor Help XML Generation
    #
    # LibGodot features an **automated compile-time documentation harvesting system**.
    # Standard Crystal doc comments (`# ...`) written above classes, properties, signals,
    # and methods are parsed at compile time and registered into Godot's offline `EditorHelp`
    # documentation subsystem for in-editor tooltips and F1 Help pages.
    #
    # ### Executive Summary & Key Topics
    #
    # <table>
    #   <thead>
    #     <tr>
    #       <th>Topic</th>
    #       <th>Method / Anchor</th>
    #       <th>Description</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr>
    #       <td><strong>Harvesting Pipeline</strong></td>
    #       <td><code>.topic_01_harvesting_pipeline</code></td>
    #       <td>Compile-time macro file reading, AST comment extraction, and XML synthesis.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>DocData XML Format</strong></td>
    #       <td><code>.topic_02_doc_data_xml_format</code></td>
    #       <td>Godot-compliant XML schema with class, brief_description, members, and signals.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Inspector Tooltips</strong></td>
    #       <td><code>.topic_03_inspector_tooltips</code></td>
    #       <td>Displaying property doc comments upon hovering over inspector controls.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>F1 Help Integration</strong></td>
    #       <td><code>.topic_04_f1_help_integration</code></td>
    #       <td>Searching and browsing custom Crystal node manuals alongside native Godot nodes.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Authoring Best Practices</strong></td>
    #       <td><code>.topic_05_authoring_best_practices</code></td>
    #       <td>Rules for writing clean docstrings, brief summaries, and avoiding XML syntax errors.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `src/libgodot/doc_macro.cr`, `src/bridge/editor_doc.hpp`
    # - **Live Specifications**: `spec/suites/test_macros_dsl.cr`
    # - **Showcase Examples**: `template/src/my_node.cr`
    # - **Related Guides**: `Docs::D_NODE_DSL_AND_SIGNALS`, `Docs::C_EXPORTS_AND_INSPECTOR`
    module E_DOC_COMMENTS_AND_HELP
      # **DocData XML Schema**: Schema specification for Godot DocData XML format.
      def self.topic_00_docdata_schema : String
        "Godot DocData XML format (<class>, <brief_description>, <members>, <signals>, <methods>)"
      end

      # **Harvesting Pipeline**: Compile-time macro file reading, AST comment extraction, and XML synthesis.
      #
      # ```text
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
      # 1. At compile time, the `node` macro inspects source lines preceding:
      #    - The `node ClassName` definition (class brief & full description)
      #    - Each `property` declaration (property description)
      #    - Each `signal` declaration (signal description)
      #    - Each `def` method (method description)
      # 2. An in-memory XML string matching Godot's official `DocData` format is synthesized.
      # 3. During `crystal_godot_init`, `EditorDocRegistry.load_all` passes each XML buffer to the engine.
      #
      # See also: `src/libgodot/doc_macro.cr`
      def self.topic_01_harvesting_pipeline : Nil
      end

      # **DocData XML Format**: Godot-compliant XML schema with class, brief_description, members, and signals.
      #
      # The synthesized XML matches Godot's internal XML help schema:
      #
      # ```xml
      # <?xml version="1.0" encoding="UTF-8" ?>
      # <class name="SpinningCrystal" inherits="Area3D">
      #   <brief_description>Collectible item that rotates in 3D space</brief_description>
      #   <description>Collectible item that rotates in 3D space and grants score upon contact.</description>
      #   <members>
      #     <member name="rotation_speed" type="float">Rotation rate in rad/s</member>
      #   </members>
      #   <signals>
      #     <signal name="collected">
      #       <description>Emitted when a character collects this item</description>
      #     </signal>
      #   </signals>
      # </class>
      # ```
      #
      # See also: `src/bridge/editor_doc.hpp`
      def self.topic_02_doc_data_xml_format : Nil
      end

      # **Inspector Tooltips**: Displaying property doc comments upon hovering over inspector controls.
      #
      # When a developer hovers over any exported property in Godot's Inspector dock,
      # Godot retrieves the description from `EditorHelp` and displays a tooltip popup:
      #
      # ```crystal
      # # Health points restored upon consuming this potion
      # @[Export(range: 5..100, step: 5)]
      # property heal_amount : Int32 = 25
      # ```
      #
      # Tooltips appear automatically without needing manual configuration.
      def self.topic_03_inspector_tooltips : Nil
      end

      # **F1 Help Integration**: Searching and browsing custom Crystal node manuals alongside native Godot nodes.
      #
      # Pressing **F1 (Search Help)** in the Godot Editor opens the native documentation browser:
      # - Custom Crystal classes appear alongside built-in nodes like `Node3D`, `CharacterBody2D`, and `Camera3D`.
      # - Method signatures, signal definitions, and property descriptions are fully searchable.
      # - Functions completely offline without internet connectivity.
      def self.topic_04_f1_help_integration : Nil
      end

      # **Authoring Best Practices**: Rules for writing clean docstrings, brief summaries, and avoiding XML syntax errors.
      #
      # - Place doc comments immediately above `node`, `property`, `signal`, and `def`.
      # - Keep the first line concise: it serves as the `<brief_description>` in Godot.
      # - Follow-up lines provide extended `<description>` context.
      # - Avoid raw XML control characters (`<`, `>`, `&`) in comment text, as they are automatically escaped.
      #
      # ```crystal
      # # Floating power-up item that rotates and restores player health
      # node HealthPotion < Area3D do
      #   # Amount of health points restored upon pickup
      #   @[Export]
      #   property heal_amount : Int32 = 25
      #
      #   # Emitted when a player body consumes this potion
      #   signal consumed(player : Node3D)
      # end
      # ```
      def self.topic_05_authoring_best_practices : Nil
      end
    end
  end
end
