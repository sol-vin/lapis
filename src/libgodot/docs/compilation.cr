module Lapis
  module Docs
    # # B. Compilation, Linking & Build System
    #
    # LibGodot connects three different compilation layers into a unified build system:
    # 1. **C++ GDExtension Loader Bridge** (`src/bridge/crystal_bridge.cpp`)
    # 2. **Crystal Game / Test / Example DLLs** (`game.dll`)
    # 3. **Godot Engine Dynamic Library** (`libgodot.dll`)
    #
    # ---
    #
    # ### 1. Compiling the C++ Loader Bridge (`crystal_bridge.dll`)
    #
    # The bridge is compiled with MinGW-w64 `g++` (or MSVC / clang) into `bin/crystal_bridge.dll`:
    # ```bash
    # g++ -shared -O3 src/bridge/crystal_bridge.cpp -o bin/crystal_bridge.dll -lgc
    # ```
    #
    # Why is a separate loader bridge required?
    # - **Boehm GC Bootstrapping**: Crystal DLLs dynamically loaded into an external host
    #   process (like `godot.exe`) do not run Crystal's native executable CRT initialization.
    #   The bridge explicitly calls `GC_init()` before invoking any Crystal exported symbol.
    # - **Zero C++ Headers in Crystal**: The bridge maps Godot's complex C++ GDExtension
    #   API and function pointers into a clean, flat C-ABI structure (`BridgeAPI`), allowing
    #   Crystal to interact with Godot without any C++ header dependencies.
    # - **Exception & Crash Guarding**: The bridge wraps instance dispatches in structured
    #   guards, preventing unhandled engine crashes when user scripts fail.
    #
    # ---
    #
    # ### 2. The Shadow Copying Reload Mechanism
    #
    # Under Windows, when a process loads a DLL via `LoadLibraryA`, the operating system
    # places an exclusive shared-read lock on the file. Any attempt by the Crystal compiler
    # to overwrite `game.dll` while Godot is open results in:
    # ```
    # Error: Access is denied. (ERROR_SHARING_VIOLATION / Windows error 32)
    # ```
    #
    # To solve this, `crystal_bridge.cpp` implements **Shadow Copy Loading** in development mode:
    # 1. When `crystal_bridge.dll` initializes, it checks for `LIBGODOT_RELEASE`. If absent,
    #    shadow loading is enabled.
    # 2. Before loading `bin/game.dll`, the bridge copies `bin/game.dll` to:
    #    `bin/game_loaded_<PID>_<TIMESTAMP>.dll`
    # 3. The bridge calls `LoadLibraryA` on the shadow copy, leaving `bin/game.dll` unlocked!
    # 4. The Crystal compiler can now freely rebuild `bin/game.dll` at any time while the
    #    Godot editor is still running.
    # 5. Old shadow copies from terminated processes are automatically pruned at startup.
    #
    # In release builds (`LIBGODOT_RELEASE=1`), shadow copying is disabled to eliminate disk I/O.
    #
    # ---
    #
    # ### 3. Compiling Crystal Game Code (`game.dll`)
    #
    # Crystal compiles user nodes into a dynamic library via:
    # ```bash
    # crystal build --cross-compile --link-flags="-shared" src/main.cr -o bin/game.dll
    # ```
    #
    # Crystal exports two primary C-ABI entry points:
    # - `crystal_godot_init(api : LibBridge::BridgeAPI*) : Int32`:
    #   Called by the loader bridge immediately after loading. Crystal stores the `BridgeAPI`
    #   pointer, iterates over `ClassRegistry`, registers all custom classes, properties,
    #   and signals with `ClassDB`, and registers offline XML documentation with `EditorHelp`.
    # - `crystal_godot_cleanup : Void`:
    #   Called when the library unloads during engine shutdown.
    #
    # ---
    #
    # ### 4. Editor Build Hook (`EditorPlugin._build`)
    #
    # The Godot editor plugin located at `addons/crystal_integration/crystal_integration.gd`
    # intercepts Godot's build pipeline:
    # - It overrides `EditorPlugin._build()`.
    # - Whenever the developer presses **F5** (Play Project) or **F6** (Play Scene), the
    #   plugin executes `crystal build` in the background.
    # - If compilation succeeds, Godot continues launching the scene with the updated DLL.
    # - If compilation fails, the output is printed directly to the Godot Editor Output Dock,
    #   and scene launching is cleanly halted.
    #
    # ---
    #
    # ### 5. Build System Synchronization (`make all`)
    #
    # The root `Makefile` orchestrates compilation across the entire workspace:
    # - `make bridge`: Builds `bin/crystal_bridge.dll`.
    # - `make test_project`: Builds root `bin/game.dll` from `src/main.cr`.
    # - `make examples`: Builds all showcase projects in `examples/`.
    # - `make template`: Builds `template/bin/game.dll`.
    # - `make sync`: Synchronizes `crystal_bridge.dll`, runtime DLLs (`gc.dll`, `iconv-2.dll`,
    #   `pcre2-8.dll`), and `crystal.gdextension` across `bin/`, `template/bin/`,
    #   and `examples/*/bin/`.
    #
    # > **Rule**: Always execute `make all` rather than partial builds to guarantee all consumer
    # > directories and bridge DLLs remain synchronized.
    module B_COMPILATION_AND_BUILD
      # Dummy method for documentation visibility
      def self.rules : Array(String)
        [
          "Always use 'make all' to keep consumer DLLs in sync",
          "Bridge performs shadow copy loading on Windows to prevent file locking",
          "GC_init() is called by the bridge before Crystal code executes",
          "F5 in Godot Editor triggers addons/crystal_integration build hook",
        ]
      end
    end
  end
end

