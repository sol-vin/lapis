module Lapis
  module Docs
    # # A. Dual-Paradigm Architecture
    #
    # LibGodot for Crystal is designed around a **dual-paradigm architecture** that
    # provides both rapid, hot-reloading in-editor game development and lean,
    # standalone native executable production shipping:
    #
    # 1. **Mode A: GDExtension In-Editor / Runner Paradigm** (`game.dll` + `crystal_bridge.dll`)
    # 2. **Mode B: Standalone LibGodot Host Paradigm** (`game.exe` + `libgodot.dll`)
    #
    # ---
    #
    # ### Mode A: GDExtension In-Editor Workflow
    #
    # Used when creating games inside the **Godot Editor 4.8+** (`make editor`) or running
    # via the Godot engine binary (`make run`).
    #
    # In this mode:
    # - Godot is the parent host process (`godot.exe`).
    # - Godot discovers `addons/crystal_integration/crystal.gdextension` at startup.
    # - The manifest directs Godot to load `bin/crystal_bridge.dll` (a lightweight native C++ bridge).
    # - During library initialization (`crystal_library_init`):
    #   1. Godot passes its C-API function table pointer (`GDExtensionInterfaceGetProcAddress`).
    #   2. The bridge initializes the Boehm Garbage Collector (`GC_init()`) for Crystal.
    #   3. In development mode, the bridge creates a timestamped shadow copy of `game.dll`
    #      (`game_loaded_<PID>_<timestamp>.dll`) to prevent Windows OS file lock collisions.
    #   4. The bridge dynamically loads the shadow DLL via `LoadLibraryA` (or `dlopen` on Linux).
    #   5. The bridge resolves `crystal_godot_init` inside `game.dll` and hands over the
    #      `BridgeAPI` function table.
    #   6. Crystal registers custom nodes, signals, exported properties, and doc comments
    #      into Godot's `ClassDB` and `EditorHelp` subsystems.
    # - Pressing **Play (F5)** or **Play Scene (F6)** in the Godot editor invokes the
    #   `EditorPlugin._build()` hook in `addons/crystal_integration/crystal_integration.gd`,
    #   automatically recompiling `game.dll` and reloading without restarting Godot.
    #
    # ---
    #
    # ### Mode B: Standalone LibGodot Host Paradigm
    #
    # Used for standalone shipping builds (`make game_exe`), embedded deployments, or CI test runners.
    #
    # In this mode:
    # - Crystal compiles as a standalone Windows PE executable (`bin/game.exe`).
    # - Crystal owns the `main()` entry point, boots its runtime, and configures GC natively.
    # - Godot is compiled as a shared library (`bin/libgodot.dll`).
    # - Crystal loads `libgodot.dll` in-memory using `LibGodot::DynamicLoader`.
    # - Crystal invokes `libgodot_create_godot_instance(argc, argv, init_callback)`, passing
    #   its own command-line arguments and an initialization callback.
    # - Godot boots in-memory and invokes Crystal's `Scene`-level initialization callback,
    #   registering all nodes and scene hooks directly.
    # - Crystal steps the main loop, controls window initialization, and manages shutdown.
    #
    # ---
    #
    # ### Comparison Table
    #
    # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
    #   <thead>
    #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
    #       <th style="padding: 10px 14px;">Feature</th>
    #       <th style="padding: 10px 14px;">Mode A (GDExtension Bridge)</th>
    #       <th style="padding: 10px 14px;">Mode B (Standalone LibGodot)</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Host Process</strong></td>
    #       <td style="padding: 10px 14px;">Godot Engine (<code>godot.exe</code>)</td>
    #       <td style="padding: 10px 14px;">Crystal Executable (<code>game.exe</code>)</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Shared Libraries</strong></td>
    #       <td style="padding: 10px 14px;"><code>crystal_bridge.dll</code>, <code>game.dll</code></td>
    #       <td style="padding: 10px 14px;"><code>libgodot.dll</code></td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Godot Editor</strong></td>
    #       <td style="padding: 10px 14px;">Full support (Inspector, Node tree, F1 Help)</td>
    #       <td style="padding: 10px 14px;">Headless or embedded window</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Hot Reloading</strong></td>
    #       <td style="padding: 10px 14px;">Live shadow reload on F5 / F6</td>
    #       <td style="padding: 10px 14px;">Recompilation of executable required</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>GC Bootstrapping</strong></td>
    #       <td style="padding: 10px 14px;">Initialized by C++ bridge (<code>GC_init</code>)</td>
    #       <td style="padding: 10px 14px;">Initialized natively by Crystal CRT</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Target Use-Case</strong></td>
    #       <td style="padding: 10px 14px;">Development, editing, prototyping</td>
    #       <td style="padding: 10px 14px;">Standalone production distribution</td>
    #     </tr>
    #   </tbody>
    # </table>
    module A_ARCHITECTURE
      # Dummy method for documentation visibility
      def self.overview : String
        "Mode A (GDExtension) for editor iteration; Mode B (Standalone LibGodot) for production shipping."
      end
    end
  end
end

