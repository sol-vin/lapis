module Lapis
  module Docs
    # # G. Engine Caveats, Internals & Architectural Nuances
    #
    # When building high-performance games with LibGodot, developers should understand several
    # critical architectural invariants across garbage collection, memory ownership, and threading.
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
    #       <td><strong>Memory Ownership Boundaries</strong></td>
    #       <td><code>.topic_01_memory_ownership_boundaries</code></td>
    #       <td>Boehm GC lifetime vs Godot C++ heap node and resource lifecycles.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>SceneTree Thread Affinity</strong></td>
    #       <td><code>.topic_02_thread_affinity_rules</code></td>
    #       <td>Why SceneTree mutation must stay on main thread and using call_deferred.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Method Bind Caching</strong></td>
    #       <td><code>.topic_03_ptrcall_method_bind_caching</code></td>
    #       <td>Static class variables (@@mb_*) enabling zero-overhead native ptrcalls.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Windows Toolchain Nuances</strong></td>
    #       <td><code>.topic_04_windows_runtime_nuances</code></td>
    #       <td>C-ABI exports, CRT compatibility, and runtime shadow file management.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `src/libgodot/object.cr`, `src/libgodot/binding_macros.cr`
    # - **Live Specifications**: `spec/suites/test_thread_safe_apis.cr`, `spec/suites/test_virtual_methods_dispatch.cr`
    # - **Related Guides**: `Docs::H_LIFECYCLE_MEMORY_AND_DEAD_POINTER_SAFETY`, `Docs::I_CONCURRENCY_FIBERS_AND_THREAD_SAFETY`
    module G_CAVEATS_AND_INTERNALS
      # **Memory Ownership Boundaries**: Boehm GC lifetime vs Godot C++ heap node and resource lifecycles.
      #
      # LibGodot bridges two distinct memory models:
      # - **Crystal's Boehm GC**: Manages memory allocated on the Crystal heap (strings, arrays,
      #   class instances, fibers).
      # - **Godot Engine C++ Heap**: Manages engine nodes, resources, and scenes using manual
      #   lifecycle (`Node` with `queue_free`) or reference counting (`RefCounted` / `Resource`).
      #
      # #### Critical Invariants:
      # 1. **Never store raw pointers to freed Godot nodes**: When a node is destroyed in Godot
      #    (e.g. via `queue_free`), its underlying C++ memory is deallocated. A Crystal wrapper
      #    object (`Godot::Node`) holding that pointer will become invalid. Always use `#alive?`
      #    or rely on LibGodot's `#check_alive!` before dereferencing cached node references.
      # 2. **GC Roots in Shared Libraries**: On Windows, when `game.dll` is dynamically loaded
      #    by Godot, static Crystal variables and method bindings are registered as GC roots.
      #    Always ensure large static data structures are cleared during `crystal_godot_cleanup`.
      #
      # See also: `src/libgodot/object.cr`
      def self.topic_01_memory_ownership_boundaries : Nil
      end

      # **SceneTree Thread Affinity**: Why SceneTree mutation must stay on main thread and using call_deferred.
      #
      # Godot executes rendering, physics, and main loop processing on different threads:
      # - **Main Thread**: Scene tree operations (`add_child`, `remove_child`, `reparent`, `queue_free`)
      #   **MUST** occur on the main thread. Attempting to modify the active scene tree from a
      #   background Crystal fiber or OS thread will cause fatal race conditions inside Godot's child arrays.
      # - **Physics Thread**: `_physics_process(delta)` is invoked during the fixed physics tick.
      #   Safe for kinematic movement (`move_and_slide`, velocity calculation), but avoid instantiating
      #   full scene trees here unless synchronized.
      # - **Deferred Calls**: Use `node.call_deferred("method_name", *args)` or `Godot.call_deferred` to
      #   safely marshal background worker results back onto Godot's main event thread.
      #
      # See also: `spec/suites/test_thread_safe_apis.cr`
      def self.topic_02_thread_affinity_rules : Nil
      end

      # **Method Bind Caching**: Static class variables (@@mb_*) enabling zero-overhead native ptrcalls.
      #
      # Invoking Godot methods through `Variant` reflection (`Object.call`) involves string hash lookups
      # and boxing/unboxing overhead.
      #
      # To achieve near-native C++ performance:
      # - LibGodot retrieves the raw method bind pointer via `Bridge.get_method_bind(class, method, hash)`
      #   and caches it inside a class variable (`@@mb_node_add_child`).
      # - Subsequent calls use `Bridge.ptrcall`, which executes a direct C function pointer call with
      #   arguments passed as an array of raw pointers (`Void**`), incurring zero reflection overhead.
      #
      # ```crystal
      # # Cached statically at class initialization:
      # @@mb_get_name : Void* = Bridge.get_method_bind("Node", "get_name", 2016703964_i64)
      # ```
      #
      # See also: `src/libgodot/binding_macros.cr`
      def self.topic_03_ptrcall_method_bind_caching : Nil
      end

      # **Windows Toolchain Nuances**: C-ABI exports, CRT compatibility, and runtime shadow file management.
      #
      # - **Compiler Consistency**: The loader bridge is compiled with MinGW-w64 `g++` on Windows.
      #   Crystal's LLVM toolchain targets MSVCRT / UCRT. The bridge exposes a pure C-ABI table
      #   (`extern "C"`), eliminating C++ name mangling or standard library incompatibility issues.
      # - **DLL Export Tables**: Exported functions (`crystal_library_init`, `crystal_godot_init`)
      #   are explicitly decorated with `__declspec(dllexport)` on Windows and `visibility("default")`
      #   on Linux.
      # - **Shadow Copies**: When testing or modifying game code in the editor, never manually delete
      #   active `game_loaded_*.dll` files while Godot is open; the OS will release them when Godot
      #   terminates, and the bridge will automatically clean them up.
      #
      # See also: `src/bridge/crystal_bridge.cpp`
      def self.topic_04_windows_runtime_nuances : Nil
      end
    end
  end
end
