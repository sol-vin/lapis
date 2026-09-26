module Lapis
  module Docs
    # # X. Addon Architecture, Plugins & Multi-Target Execution Verification
    #
    # Lapis provides first-class support for compiling redistributable **Godot Addons & GDExtension Plugins**
    # in native Crystal. This guide documents the architectural lifecycle across the three distinct
    # execution paradigms (**Editor**, **Standalone**, and **Portable**), explains the pure-Crystal
    # in-editor test runner (eliminating separate `.tscn` test scene files), and covers multi-addon
    # isolation and packaging safety invariants.
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
    #       <td><strong>Key Features</strong></td>
    #       <td><code>.topic_00_key_features</code></td>
    #       <td>Key capabilities of Lapis plugin and addon architecture.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Execution Paradigms</strong></td>
    #       <td><code>.topic_01_execution_paradigms</code></td>
    #       <td>Architectural matrix across Editor, Standalone, and Portable modes.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Pure-Crystal Test Runner</strong></td>
    #       <td><code>.topic_02_pure_crystal_test_runner</code></td>
    #       <td>In-memory suite execution via CrystalIntegrationPlugin and Lapis::Test::Registry without .tscn files.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Dynamic ClassDB & Nodes</strong></td>
    #       <td><code>.topic_03_dynamic_classdb_and_nodes</code></td>
    #       <td>Constructing custom addon nodes and inspecting exported properties in memory.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Multi-Addon Isolation</strong></td>
    #       <td><code>.topic_04_multi_addon_isolation</code></td>
    #       <td>Single-compiler hook invariants, ClassDB namespacing, and release packaging safety.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Portable Sandboxing</strong></td>
    #       <td><code>.topic_05_portable_sandboxed_execution</code></td>
    #       <td>Single-binary portable packaging with embedded GDPC footer and companion DLL loading.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `src/libgodot/editor.cr`, `src/bridge/crystal_bridge.cpp`
    # - **Starter Templates**: `template-addon/`
    # - **Live Specifications**: `spec/addon_runner_spec.cr`, `spec/editor_driver_spec.cr`
    # - **Related Guides**: `Docs::A_ARCHITECTURE`, `Docs::Q_TESTING_FRAMEWORK_AND_EDITOR_SUITES`, `Docs::P_LAPIS_TOOLCHAIN_AND_PACKAGING`
    module X_ADDONS_AND_PLUGINS_GUIDE
      # **Key Features**: Returns key capabilities of Lapis addon and plugin architecture.
      def self.topic_00_key_features : Array(String)
        [
          "100% pure Crystal in-editor test runner integrated into CrystalIntegrationPlugin",
          "Zero .tscn requirement: dynamic in-memory suite execution and ClassDB reflection",
          "Seamless execution across Editor, Standalone, and Single-Binary Portable paradigms",
          "Multi-addon isolation preventing ClassDB symbol collisions and GC heap corruption",
          "Automatic Windows shadow loading enabling instant F5 live recompilation in the Godot Editor",
        ]
      end

      # **Execution Paradigms Matrix**: Architectural comparison across Editor, Standalone, and Portable execution modes.
      #
      # <table>
      #   <thead>
      #     <tr>
      #       <th>Dimension</th>
      #       <th>Editor Mode (<code>godot --editor</code>)</th>
      #       <th>Standalone Mode (<code>game.exe + .pck</code>)</th>
      #       <th>Portable Mode (<code>game_portable.exe</code>)</th>
      #     </tr>
      #   </thead>
      #   <tbody>
      #     <tr>
      #       <td><strong>Host Process</strong></td>
      #       <td>Godot Editor engine binary (<code>godot.exe</code>)</td>
      #       <td>Compiled executable (<code>game.exe</code>)</td>
      #       <td>Single-binary executable with GDPC footer</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Max Init Level</strong></td>
      #       <td><code>GDEXTENSION_INITIALIZATION_EDITOR</code></td>
      #       <td><code>GDEXTENSION_INITIALIZATION_SCENE</code></td>
      #       <td><code>GDEXTENSION_INITIALIZATION_SCENE</code></td>
      #     </tr>
      #     <tr>
      #       <td><strong>EditorPlugin Lifecycle</strong></td>
      #       <td>Active: <code>_enter_tree()</code> mounts docks and tools</td>
      #       <td>Inactive: stripped or omitted from runtime</td>
      #       <td>Inactive: stripped or omitted from runtime</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Test Execution</strong></td>
      #       <td>Pure Crystal runner via <code>CrystalIntegrationPlugin</code></td>
      #       <td>Modular runtime test project runner</td>
      #       <td>Sandboxed standalone execution via embedded PCK</td>
      #     </tr>
      #     <tr>
      #       <td><strong>VFS Resolution</strong></td>
      #       <td>Direct disk filesystem (<code>res://</code>)</td>
      #       <td>External <code>game.pck</code> file on disk</td>
      #       <td>Embedded PCK at executable binary tail</td>
      #     </tr>
      #     <tr>
      #       <td><strong>DLL Resolution</strong></td>
      #       <td>Timestamped shadow DLLs to prevent Windows file locking</td>
      #       <td>Direct loading from <code>addons/&lt;name&gt;/bin/</code></td>
      #       <td>Companion DLLs resolved from disk alongside portable .exe</td>
      #     </tr>
      #   </tbody>
      # </table>
      def self.topic_01_execution_paradigms : Nil
        # See table above for complete architectural comparison
      end

      # **Pure-Crystal Test Runner**: In-memory test execution without separate scene files.
      #
      # In Lapis, addon test runners are implemented 100% in Crystal inside `CrystalIntegrationPlugin`
      # (`src/libgodot/editor.cr`). Previous architectures required a dedicated `test_runner.tscn` file
      # or GDScript test runner scripts.
      #
      # ### Zero `.tscn` Invariant
      # Standalone addons like `template-addon` do not require any scene files on disk. The test runner:
      # 1. Hooks `schedule_in_editor_tool_tests` in `CrystalIntegrationPlugin#_enter_tree`.
      # 2. Applies headless editor settings (disabling TextEdit type-safe highlighting to avoid asserts).
      # 3. Executes all tests registered in `Lapis::Test::Registry` (e.g., `spec/editor/editor_spec.cr`).
      # 4. Dynamically inspects ClassDB and instantiates custom addon nodes in memory.
      # 5. Generates `.tool_tests_passed` / `.tool_tests_failed` markers and quits cleanly.
      #
      # ```crystal
      # # Registering in-editor tests without scenes (spec/editor/editor_spec.cr):
      # test_suite "Nodes" do
      #   test "CrystalAddonBanner is registered as Control" do
      #     entry = Godot::ClassRegistry.find("CrystalAddonBanner")
      #     assert_not_nil entry
      #     assert_eq entry.not_nil!.parent_name, "Control"
      #   end
      # end
      # ```
      def self.topic_02_pure_crystal_test_runner : Nil
      end

      # **Dynamic ClassDB & Node Inspection**: In-memory instantiation and property verification.
      #
      # When testing compiled addons in headless editor mode, custom nodes can be dynamically
      # constructed directly in memory without instantiating a scene:
      #
      # ```crystal
      # # Dynamically instantiate custom node from ClassDB:
      # if banner = Godot.create("CrystalAddonBanner")
      #   msg = banner.get("message").to_s
      #   Godot.print("Default message: #{msg}")
      #   banner.destroy # Free unparented standalone node
      # end
      # ```
      #
      # ### Memory Safety Rule
      # Unparented nodes created via `Godot.create` are not owned by the SceneTree. You **MUST** call
      # `node.destroy` when finished to prevent native C++ memory leaks.
      def self.topic_03_dynamic_classdb_and_nodes : Nil
      end

      # **Multi-Addon Isolation & Packaging Safety**: Preventing conflicts across multiple compiled plugins.
      #
      # Projects may include multiple Crystal addons simultaneously. Lapis maintains strict isolation:
      # - **Single Compiler Hook**: Exactly one `crystal_integration` addon owns the editor F5 compilation
      #   and build toolbar. Additional addons must never inject competing compilation hooks.
      # - **Shared Bridge Memory**: The C++ loader bridge pins itself in process memory across reloads,
      #   preventing unmapping crashes while Godot's ClassDB retains function pointers.
      # - **Dummy Addon Isolation**: Test addons (`dummy_audio`, `dummy_dialogue`, `dummy_inventory`) reside
      #   in `addons/` solely for multi-addon conflict testing and are **NEVER** shipped in release archives.
      def self.topic_04_multi_addon_isolation : Nil
      end

      # **Portable Sandboxed Execution**: Single-binary game and addon runtime verification.
      #
      # In Portable mode, game scenes and addon `.gdextension` manifests are bundled into an appended
      # PCK package terminated by Godot's 12-byte `GDPC` footer:
      # - The host executable reads `res://` directly from its own binary tail.
      # - Dynamic companion libraries (`game.dll`, `crystal_bridge.dll`, `gc.dll`) are resolved from
      #   the directory alongside the portable executable on disk.
      # - Verification specs test portable runners in isolated scratch directories without loose `.pck` files.
      def self.topic_05_portable_sandboxed_execution : Nil
      end
    end
  end
end
