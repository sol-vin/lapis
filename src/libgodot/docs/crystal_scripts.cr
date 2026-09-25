module Lapis
  module Docs
    # ### J. First-Class Crystal Scripts (.cr) in Godot
    #
    # LibGodot establishes `.cr` (Crystal) script files as **first-class citizens** in the Godot 4 Editor,
    # matching the native workflow of GDScript and C#.
    #
    # #### Architecture Overview
    # <table>
    #   <thead>
    #     <tr>
    #       <th>Component</th>
    #       <th>Implementation</th>
    #       <th>Purpose</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr>
    #       <td><strong>CrystalLanguage</strong></td>
    #       <td><code>Godot::CrystalLanguage &lt; ScriptLanguageExtension</code></td>
    #       <td>Registers language name, extension, templates, and code completion in <code>ScriptServer</code></td>
    #     </tr>
    #     <tr>
    #       <td><strong>CrystalScript</strong></td>
    #       <td><code>Godot::CrystalScript &lt; ScriptExtension</code></td>
    #       <td>Represents <code>.cr</code> files as Godot Script resources, exposing Inspector properties</td>
    #     </tr>
    #     <tr>
    #       <td><strong>ResourceFormatLoader</strong></td>
    #       <td><code>Godot::ResourceFormatLoaderCrystal</code></td>
    #       <td>Enables Godot's FileSystem dock and ResourceLoader to load <code>.cr</code> files directly</td>
    #     </tr>
    #     <tr>
    #       <td><strong>ResourceFormatSaver</strong></td>
    #       <td><code>Godot::ResourceFormatSaverCrystal</code></td>
    #       <td>Persists modifications in the Godot Script Editor back to <code>.cr</code> files on disk (Ctrl+S)</td>
    #     </tr>
    #     <tr>
    #       <td><strong>CrystalSyntaxHighlighter</strong></td>
    #       <td><code>Godot::CrystalHighlighter &lt; EditorSyntaxHighlighter</code></td>
    #       <td>High-performance, zero-dependency tokenizer coloring keywords, types, annotations, symbols, and comments</td>
    #     </tr>
    #     <tr>
    #       <td><strong>LSP Worker</strong></td>
    #       <td><code>Godot::CrystalLSP</code></td>
    #       <td>Sandboxed background bridge for optional Crystalline language server diagnostics</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ---
    #
    # #### 1. Built-in Script Editor Tab
    #
    # Double-clicking any `.cr` file in the Godot FileSystem dock opens the file directly inside
    # the engine's built-in **Script** workspace tab.
    # - **Zero External Dependencies**: Syntax highlighting operates independently of external daemons.
    # - **Theme Integration**: Highlights match the active Godot Editor theme colors.
    # - **Instant Save**: Pressing **Ctrl+S** in the script editor invokes `ResourceFormatSaverCrystal`, saving the file to disk.
    # - **F5 Fast Build**: Pressing **F5** automatically compiles Crystal source code into `game.dll` and reloads.
    #
    # ---
    #
    # #### 2. Inspector Property Reflection
    #
    # Nodes with attached `.cr` scripts display exported properties directly inside the Godot Inspector dock:
    # ```
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
    # When selected in the scene tree:
    # - `speed` renders as a numeric slider clamped between 50 and 1000 with step 10.
    # - `max_health` renders as an integer spinner.
    # - `health_changed` and `died` appear in the Node Signals dock.
    #
    # ---
    #
    # #### 3. Sandboxed Language Server (Crystalline)
    #
    # While built-in code completion and syntax highlighting function out-of-the-box,
    # LibGodot integrates the official `crystalline` Language Server Protocol daemon:
    # - Auto-detects `crystalline` binary in `PATH`, local `bin/`, or Lapis install directory.
    # - Bundled directly into `{app}\bin` via the Windows installer (`lapis-setup-windows-x86_64.exe`).
    # - Available via GitHub releases or automatically downloaded via `lapis setup --lsp` and `scripts/windows/install_deps.ps1`.
    # - Sandboxed in a protected background worker; if Crystalline crashes or errors, it fails gracefully without interrupting the editor.
    #
    module J_FIRST_CLASS_CRYSTAL_SCRIPTS
      def self.features : Array(String)
        [
          "Direct .cr file opening in Godot built-in Script Editor tab",
          "Pure-Crystal high-performance syntax highlighter (EditorSyntaxHighlighter)",
          "Zero-compile AST reflection for immediate Inspector property display",
          "ResourceFormatLoader and ResourceFormatSaver for seamless FileSystem and save integration",
          "Built-in code completion and symbol lookup via ScriptLanguageExtension",
          "Guarded, fail-safe Crystalline LSP daemon integration",
          "F5 / Play automatic build and shadow DLL hot reload",
        ]
      end
    end
  end
end

