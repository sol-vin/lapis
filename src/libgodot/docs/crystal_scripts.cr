module Lapis
  module Docs
    # # J. First-Class Crystal Scripts (.cr) in Godot
    #
    # LibGodot establishes `.cr` (Crystal) script files as **first-class citizens** in the Godot 4 Editor,
    # matching the native workflow of GDScript and C#. Developers can create, edit, save, and attach
    # `.cr` scripts inside the engine with syntax highlighting and LSP diagnostics.
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
    #       <td><strong>Script Architecture</strong></td>
    #       <td><code>.topic_01_script_architecture</code></td>
    #       <td>CrystalLanguage, CrystalScript, and editor integration components.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>In-Editor Script Tab</strong></td>
    #       <td><code>.topic_02_in_editor_script_tab</code></td>
    #       <td>Editing .cr files directly in Godot with zero-dependency syntax highlighting.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Inspector Reflection</strong></td>
    #       <td><code>.topic_03_inspector_property_reflection</code></td>
    #       <td>Automatic exposure of @[Export] properties and signals on attached scripts.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Crystalline LSP Integration</strong></td>
    #       <td><code>.topic_04_crystalline_lsp_integration</code></td>
    #       <td>Sandboxed background language server diagnostics and auto-completion.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Resource Loaders & Savers</strong></td>
    #       <td><code>.topic_05_resource_loaders_and_savers</code></td>
    #       <td>ResourceFormatLoaderCrystal and ResourceFormatSaverCrystal disk sync.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `src/libgodot/script.cr`, `src/libgodot/editor.cr`
    # - **Live Specifications**: `spec/suites/test_script_first_class.cr`
    # - **Showcase Examples**: `template/src/my_node.cr`
    # - **Related Guides**: `Docs::S_IDE_INTEGRATION_AND_DEVELOPER_EXPERIENCE`, `Docs::D_NODE_DSL_AND_SIGNALS`
    module J_FIRST_CLASS_CRYSTAL_SCRIPTS
      # **Key Features & Capabilities**: Core components of the Crystal script subsystem.
      def self.topic_00_key_features : Array(String)
        [
          "First-class .cr script resource handling in Godot FileSystem and Inspector docks",
          "Built-in zero-dependency syntax highlighter matching the active editor theme",
          "Native Ctrl+S file saving via ResourceFormatSaverCrystal",
          "Sandboxed Crystalline LSP background daemon for code completion and diagnostics",
        ]
      end

      # **Script Architecture Overview**: CrystalLanguage, CrystalScript, and editor integration components.
      #
      # <table>
      #   <thead>
      #     <tr>
      #       <th>Component</th>
      #       <th>Class</th>
      #       <th>Engine Role</th>
      #     </tr>
      #   </thead>
      #   <tbody>
      #     <tr>
      #       <td><strong>Language Server</strong></td>
      #       <td><code>Godot::CrystalLanguage</code></td>
      #       <td>Registers language extension (.cr), template generators, and ScriptServer hooks.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Script Resource</strong></td>
      #       <td><code>Godot::CrystalScript</code></td>
      #       <td>Represents .cr files as Godot Script resources, exposing Inspector properties.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Resource Loader</strong></td>
      #       <td><code>Godot::ResourceFormatLoaderCrystal</code></td>
      #       <td>Loads .cr files from disk into Godot ResourceLoader.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Resource Saver</strong></td>
      #       <td><code>Godot::ResourceFormatSaverCrystal</code></td>
      #       <td>Persists modifications in Godot Script Editor back to disk on Ctrl+S.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Highlighter</strong></td>
      #       <td><code>Godot::CrystalHighlighter</code></td>
      #       <td>Zero-dependency tokenizer coloring keywords, types, annotations, and comments.</td>
      #     </tr>
      #   </tbody>
      # </table>
      #
      # See also: `src/libgodot/script.cr`
      def self.topic_01_script_architecture : Nil
      end

      # **Built-in Script Editor Tab**: Editing .cr files directly in Godot with zero-dependency syntax highlighting.
      #
      # Double-clicking any `.cr` file in the Godot FileSystem dock opens the file directly inside
      # the engine's built-in **Script** workspace tab:
      # - **Zero External Dependencies**: Syntax highlighting operates independently of external daemons.
      # - **Theme Integration**: Highlights match the active Godot Editor theme colors.
      # - **Instant Save**: Pressing **Ctrl+S** in the script editor invokes `ResourceFormatSaverCrystal`, saving the file to disk.
      # - **F5 Fast Build**: Pressing **F5** automatically compiles Crystal source code into `game.dll` and reloads.
      def self.topic_02_in_editor_script_tab : Nil
      end

      # **Inspector Property Reflection**: Automatic exposure of @[Export] properties and signals on attached scripts.
      #
      # Nodes with attached `.cr` scripts display exported properties directly inside the Godot Inspector dock:
      #
      # ```crystal
      # require "libgodot"
      #
      # node Player < CharacterBody2D do
      #   @[Export(range: 50.0_f32..1000.0_f32, step: 10.0_f32)]
      #   property speed : Float32 = 300.0_f32
      #
      #   @[Export(range: 10..500, step: 5)]
      #   property max_health : Int32 = 100
      #
      #   signal health_changed(current : Int32, max_health : Int32)
      #   signal died
      # end
      # ```
      #
      # - `speed` renders as a numeric slider clamped between 50 and 1000 with step 10.
      # - `max_health` renders as an integer spinner.
      # - `health_changed` and `died` appear in the Node Signals dock.
      #
      # See also: `spec/suites/test_script_first_class.cr`
      def self.topic_03_inspector_property_reflection : Nil
      end

      # **Sandboxed Language Server (Crystalline)**: Sandboxed background language server diagnostics and auto-completion.
      #
      # While built-in code completion and syntax highlighting function out-of-the-box,
      # LibGodot integrates the official `crystalline` Language Server Protocol daemon:
      # - Auto-detects `crystalline` binary in `PATH`, local `bin/`, or Lapis install directory.
      # - Bundled directly into `{app}\bin` via the Windows installer (`lapis-setup-windows-x86_64.exe`).
      # - Available via GitHub releases or automatically downloaded via `lapis setup --lsp`.
      # - Sandboxed in a protected background worker; if Crystalline crashes or errors, it fails gracefully without interrupting the editor.
      def self.topic_04_crystalline_lsp_integration : Nil
      end

      # **Resource Loaders & Savers**: ResourceFormatLoaderCrystal and ResourceFormatSaverCrystal disk sync.
      #
      # `ResourceFormatLoaderCrystal` and `ResourceFormatSaverCrystal` guarantee that `.cr` files
      # are treated as executable `Script` resources by the engine rather than arbitrary text files:
      # - Godot FileSystem dock detects `.cr` files as valid scripts with custom Crystal icons.
      # - Editor drag-and-drop onto scene tree nodes attaches the script seamlessly.
      #
      # See also: `src/libgodot/script.cr`
      def self.topic_05_resource_loaders_and_savers : Nil
      end
    end
  end
end
