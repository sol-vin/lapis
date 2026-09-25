module Lapis
  module Docs
    # # A. Dual-Paradigm Architecture
    #
    # LibGodot for Crystal is architected around a **dual-paradigm execution model** providing
    # rapid in-editor live iteration during game development alongside lean, standalone
    # native executable generation for production distribution.
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
    #       <td><strong>Mode A: GDExtension In-Editor</strong></td>
    #       <td><code>.topic_01_mode_a_gdextension</code></td>
    #       <td>Godot-hosted development workflow with live shadow DLL reloading on F5/F6.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Mode B: Standalone Host</strong></td>
    #       <td><code>.topic_02_mode_b_standalone_host</code></td>
    #       <td>Crystal-owned native executable embedding <code>libgodot.dll</code> for production.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Comparison Matrix</strong></td>
    #       <td><code>.topic_03_comparison_matrix</code></td>
    #       <td>Side-by-side technical trade-offs across hosting, memory, and packaging.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Lifecycle Bootstrapping</strong></td>
    #       <td><code>.topic_04_lifecycle_bootstrapping</code></td>
    #       <td>Boehm GC initialization, proc address resolution, and ClassDB discovery.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `src/bridge/crystal_bridge.cpp`, `src/libgodot/bridge.cr`
    # - **Live Specifications**: `spec/suites/test_cold_boot.cr`
    # - **Showcase Examples**: `examples/basic_demo/src/main.cr`
    # - **Related Guides**: `Docs::B_COMPILATION_AND_BUILD`, `Docs::W_CPP_BRIDGE_ARCHITECTURE`
    module A_ARCHITECTURE
      # **Mode A: GDExtension In-Editor Workflow**: Godot-hosted development workflow with live shadow DLL reloading on F5/F6.
      #
      # Used during gameplay authoring, level design, and tool development inside the
      # **Godot Editor 4.8+** (`make editor`) or when launched via `make run`.
      #
      # #### Mechanics & Pipeline:
      # 1. **Parent Host**: Godot Engine (`godot.exe`) is the OS parent process.
      # 2. **Manifest Discovery**: At startup, Godot discovers `addons/crystal_integration/crystal.gdextension`.
      # 3. **Bridge Loading**: Godot loads `bin/crystal_bridge.dll` (a lightweight native C++ loader bridge).
      # 4. **Boehm GC Bootstrapping**: The loader bridge explicitly invokes `GC_init()` before any Crystal symbols run.
      # 5. **Shadow DLL Copying**: To avoid Windows OS file-locking collisions (`ERROR_SHARING_VIOLATION`),
      #    the bridge copies `bin/game.dll` to a timestamped file (`bin/game_loaded_<PID>_<TIMESTAMP>.dll`)
      #    and loads the shadow copy via `LoadLibraryA`.
      # 6. **Library Handover**: The bridge resolves `crystal_godot_init` inside `game.dll` and passes the
      #    `BridgeAPI` proc address table. Crystal registers all custom classes, exported properties,
      #    signals, and doc comments into `ClassDB` and `EditorHelp`.
      # 7. **Editor Build Hook**: Pressing **F5 (Play Project)** or **F6 (Play Scene)** executes
      #    `EditorPlugin._build()` in `addons/crystal_integration/crystal_integration.gd`, automatically
      #    rebuilding `bin/game.dll` and reloading without restarting Godot.
      #
      # See also: `spec/suites/test_cold_boot.cr`
      def self.topic_01_mode_a_gdextension : Nil
      end

      # **Mode B: Standalone Host Paradigm**: Crystal-owned native executable embedding libgodot.dll for lean production shipping.
      #
      # Used for lean, single-executable production distribution (`make game_exe`), embedded deployments,
      # and headless CI test runners.
      #
      # #### Mechanics & Pipeline:
      # 1. **Parent Host**: Crystal is the native PE/ELF executable (`bin/game.exe`), owning the OS `main()` entry point.
      # 2. **Runtime Bootstrapping**: Crystal CRT initializes natively, configuring Boehm GC and execution contexts.
      # 3. **Dynamic Library Loading**: Crystal loads `bin/libgodot.dll` in-memory using `LibGodot::DynamicLoader`.
      # 4. **Instance Creation**: Crystal calls `libgodot_create_godot_instance(argc, argv, init_callback)`,
      #    passing its command-line arguments and an initialization callback.
      # 5. **Scene Initialization**: Godot boots in-memory and invokes Crystal's Scene-level callback,
      #    registering nodes directly into `ClassDB`.
      # 6. **Main Loop Ownership**: Crystal controls window initialization, steps frames cooperatively,
      #    and handles clean engine shutdown.
      #
      # See also: `src/main.cr`
      def self.topic_02_mode_b_standalone_host : Nil
      end

      # **Paradigm Comparison Matrix**: Side-by-side technical trade-offs across hosting, memory, and packaging.
      #
      # <table>
      #   <thead>
      #     <tr>
      #       <th>Feature</th>
      #       <th>Mode A (GDExtension Bridge)</th>
      #       <th>Mode B (Standalone LibGodot)</th>
      #     </tr>
      #   </thead>
      #   <tbody>
      #     <tr>
      #       <td><strong>Host Binary</strong></td>
      #       <td>Godot Engine (<code>godot.exe</code>)</td>
      #       <td>Crystal Executable (<code>bin/game.exe</code>)</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Primary Shared Libraries</strong></td>
      #       <td><code>crystal_bridge.dll</code> + <code>game.dll</code></td>
      #       <td><code>libgodot.dll</code></td>
      #     </tr>
      #     <tr>
      #       <td><strong>Editor Integration</strong></td>
      #       <td>Full support (Inspector, Node tree, F1 Help, Tool scripts)</td>
      #       <td>Headless or embedded window</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Hot Reloading</strong></td>
      #       <td>Automatic timestamped shadow DLL reload on F5 / F6</td>
      #       <td>Recompilation of standalone executable required</td>
      #     </tr>
      #     <tr>
      #       <td><strong>GC Bootstrapping</strong></td>
      #       <td>Initialized by C++ loader bridge (<code>GC_init()</code>)</td>
      #       <td>Initialized natively by Crystal CRT</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Primary Use Case</strong></td>
      #       <td>Development, level design, editor plugins</td>
      #       <td>Lean production shipping, headless CI runner</td>
      #     </tr>
      #   </tbody>
      # </table>
      def self.topic_03_comparison_matrix : Nil
      end

      # **Lifecycle Bootstrapping & C-ABI Handover**: Boehm GC initialization, proc address resolution, and ClassDB discovery.
      #
      # Regardless of whether running in Mode A or Mode B, the handoff between native engine C++
      # and Crystal is performed through a flat, zero-overhead C-ABI structure (`BridgeAPI`):
      #
      # ```crystal
      # # Handoff symbol inside game.dll:
      # fun crystal_godot_init(api : LibBridge::BridgeAPI*) : Int32
      #   # Store function table pointer
      #   Bridge.init(api)
      #
      #   # Register all custom nodes declared via `node` macro
      #   ClassRegistry.register_all
      #
      #   # Register offline F1 Help XML doc comments
      #   EditorDocRegistry.load_all
      #   0
      # end
      # ```
      #
      # This guarantees that Crystal requires zero C++ header inclusions, while maintaining
      # maximum ptrcall execution speed.
      def self.topic_04_lifecycle_bootstrapping : Nil
      end
    end
  end
end
