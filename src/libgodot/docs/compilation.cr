module Lapis
  module Docs
    # # B. Compilation, Linking & Build System
    #
    # LibGodot connects three distinct compilation layers into a unified build system:
    # 1. **C++ GDExtension Loader Bridge** (`bin/crystal_bridge.dll`)
    # 2. **Crystal Game / Test / Example DLLs** (`bin/game.dll`)
    # 3. **Godot Engine Dynamic Library** (`bin/libgodot.dll`)
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
    #       <td><strong>C++ Loader Bridge</strong></td>
    #       <td><code>.topic_01_cpp_loader_bridge</code></td>
    #       <td>Compiling <code>crystal_bridge.dll</code> with MinGW-w64/MSVC, GC init, and C-ABI flattening.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Windows Shadow Loading</strong></td>
    #       <td><code>.topic_02_windows_shadow_loading</code></td>
    #       <td>Bypassing OS file lock collisions (Windows Error 32) via timestamped DLL cloning.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Crystal Game Library</strong></td>
    #       <td><code>.topic_03_game_dll_compilation</code></td>
    #       <td>Compiling <code>game.dll</code>, exported C entry points, and ClassDB registration.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Editor Build Hook</strong></td>
    #       <td><code>.topic_04_editor_build_hook</code></td>
    #       <td>Automatic recompilation on F5/F6 via <code>EditorPlugin._build()</code>.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Workspace Synchronization</strong></td>
    #       <td><code>.topic_05_make_all_synchronization</code></td>
    #       <td>Orchestrating multi-consumer synchronization across examples, template, and tests.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `src/bridge/crystal_bridge.cpp`, `Makefile`, `addons/crystal_integration/crystal_integration.gd`
    # - **Live Specifications**: `spec/suites/test_toolchain_standalone.cr`
    # - **Starter Template**: `template/Makefile`, `template/src/main.cr`
    # - **Related Guides**: `Docs::A_ARCHITECTURE`, `Docs::W_CPP_BRIDGE_ARCHITECTURE`, `Docs::P_LAPIS_TOOLCHAIN_AND_PACKAGING`
    module B_COMPILATION_AND_BUILD
      # **C++ Loader Bridge (`crystal_bridge.dll`)**: Architecture of the native bridge handling Boehm GC init, flat C-ABI mapping, and crash protection.
      #
      # The bridge is compiled with MinGW-w64 `g++` (or MSVC / clang) into `bin/crystal_bridge.dll`:
      # ```bash
      # g++ -shared -O2 -g -I rsrc -I src/bridge src/bridge/crystal_bridge.cpp -o bin/crystal_bridge.dll -static -static-libgcc -static-libstdc++
      # ```
      #
      # #### Why a Separate C++ Loader Bridge is Necessary:
      # - **Boehm GC Bootstrapping**: Crystal dynamic libraries loaded into an external host (like `godot.exe`)
      #   do not run Crystal's native executable CRT startup. The bridge explicitly calls `GC_init()`
      #   before invoking any Crystal exported symbol.
      # - **Zero C++ Headers in Crystal**: The bridge maps Godot's complex C++ GDExtension API and function
      #   pointers into a clean, flat C-ABI structure (`BridgeAPI`), allowing Crystal to interact with Godot
      #   without C++ header dependencies.
      # - **Exception & Crash Guarding**: The bridge wraps instance dispatches in structured exception handlers,
      #   preventing unhandled engine crashes when user scripts fail.
      #
      # See also: `src/bridge/crystal_bridge.cpp`
      def self.topic_01_cpp_loader_bridge : Nil
      end

      # **Windows Shadow Loading Mechanism**: Bypassing OS file lock collisions (Windows Error 32) via timestamped DLL cloning.
      #
      # On Windows, when a process loads a DLL via `LoadLibraryA`, the operating system places an
      # exclusive shared-read lock on the file on disk. Any attempt by the Crystal compiler to overwrite
      # `game.dll` while Godot is running results in:
      # ```text
      # Error: Access is denied. (ERROR_SHARING_VIOLATION / Windows error 32)
      # ```
      #
      # #### How Shadow Loading Resolves the Conflict:
      # 1. When `crystal_bridge.dll` initializes, it checks for `LIBGODOT_RELEASE`. If absent, development mode is active.
      # 2. Before loading `bin/game.dll`, the bridge copies `bin/game.dll` to:
      #    `bin/game_loaded_<PID>_<TIMESTAMP>.dll`
      # 3. The bridge calls `LoadLibraryA` on the shadow copy, leaving `bin/game.dll` completely unlocked on disk!
      # 4. The Crystal compiler can now freely rebuild `bin/game.dll` at any time while the Godot Editor remains open.
      # 5. Old shadow copies from terminated processes are automatically pruned at startup.
      #
      # In release builds (`LIBGODOT_RELEASE=1`), shadow copying is disabled to eliminate disk I/O.
      #
      # See also: `src/bridge/crystal_bridge.cpp`
      def self.topic_02_windows_shadow_loading : Nil
      end

      # **Crystal Game Library (`game.dll`)**: Compiler flags, exported C entry points, and ClassDB registration pipeline.
      #
      # Crystal compiles user nodes, exported properties, and game systems into a dynamic library via:
      # ```bash
      # crystal build --cross-compile --link-flags="/DLL /ENTRY:_DllMainCRTStartup /EXPORT:crystal_godot_init" src/main.cr -o bin/game.dll
      # ```
      #
      # #### Exported C-ABI Entry Points:
      # - `crystal_godot_init(api : LibBridge::BridgeAPI*) : Int32`:
      #   Called by the loader bridge immediately after loading. Crystal stores the `BridgeAPI` pointer,
      #   iterates over `ClassRegistry`, registers all custom classes, properties, and signals with `ClassDB`,
      #   and loads offline XML documentation into `EditorHelp`.
      # - `crystal_godot_cleanup : Void`:
      #   Called when the library unloads during engine shutdown.
      #
      # See also: `src/libgodot/bridge.cr`
      def self.topic_03_game_dll_compilation : Nil
      end

      # **Automatic Editor Build Hook (F5/F6)**: EditorPlugin integration intercepting play actions to recompile and reload without editor restart.
      #
      # The Godot editor plugin located at `addons/crystal_integration/crystal_integration.gd`
      # intercepts Godot's play pipeline:
      # - It overrides `EditorPlugin._build()`.
      # - Whenever the developer presses **F5** (Play Project) or **F6** (Play Scene), the
      #   plugin executes `crystal build` in the background.
      # - If compilation succeeds, Godot continues launching the scene with the updated DLL.
      # - If compilation fails, the compiler error output is printed directly to the Godot Editor Output Dock,
      #   and scene launching is cleanly halted.
      #
      # See also: `addons/crystal_integration/crystal_integration.gd`
      def self.topic_04_editor_build_hook : Nil
      end

      # **Workspace Synchronization (`make all`)**: Golden build rule ensuring bridge, DLLs, and tests stay synchronized across all consumers.
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
      # > **The Golden Build Rule**: Always execute `make all` rather than partial builds to guarantee
      # > all consumer directories, templates, and bridge DLLs remain synchronized.
      #
      # See also: `Makefile`
      def self.topic_05_make_all_synchronization : Nil
      end
    end
  end
end
