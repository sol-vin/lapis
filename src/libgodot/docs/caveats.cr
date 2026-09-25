module Lapis
  module Docs
    # # G. Engine Caveats, Memory & Internals
    #
    # When building high-performance games with LibGodot, developers should be aware of several
    # critical architectural nuances spanning garbage collection, memory ownership, and threading.
    #
    # ---
    #
    # ### 1. Memory Ownership: Boehm GC vs. Godot Reference Counting
    #
    # LibGodot bridges two distinct memory models:
    # - **Crystal's Boehm GC**: Manages memory allocated on the Crystal heap (strings, arrays,
    #   class instances, fibers).
    # - **Godot Engine C++ Heap**: Manages engine nodes, resources, and scenes using manual
    #   lifecycle (`Node` with `queue_free`) or reference counting (`RefCounted` / `Resource`).
    #
    # #### Critical Rules:
    # 1. **Never store raw pointers to freed Godot nodes**: When a node is destroyed in Godot
    #    (e.g. via `queue_free`), its underlying C++ memory is deallocated. A Crystal wrapper
    #    object (`Godot::Node`) holding that pointer will become invalid. Check `is_queued_for_deletion`
    #    or null pointers before dereferencing cached node references.
    # 2. **GC Roots in Shared Libraries**: On Windows, when `game.dll` is dynamically loaded
    #    by Godot, static Crystal variables and method bindings are registered as GC roots.
    #    Always ensure large static data structures are cleared during `crystal_godot_cleanup`.
    #
    # ---
    #
    # ### 2. Thread Safety & Thread Affinity
    #
    # Godot executes rendering, physics, and main loop processing on different threads:
    # - **Main Thread**: Scene tree operations (`add_child`, `remove_child`, UI updates)
    #   **MUST** occur on the main thread. Attempting to modify the active scene tree from a
    #   background Crystal fiber will cause race conditions inside Godot's internal node lists.
    # - **Physics Thread**: `_physics_process(delta)` is invoked during the fixed physics tick.
    #   Safe for kinematic movement (`move_and_slide`, velocity calculation), but avoid
    #   instantiating full scene trees here unless synchronized.
    # - **Deferred Calls**: Use `Godot.call_deferred` to safely marshal background fiber
    #   work back onto Godot's main event thread.
    #
    # ---
    #
    # ### 3. Method Bind Pointer Caching (`@@mb_*`)
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
    # ---
    #
    # ### 4. Windows Toolchain & Runtime Nuances
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
    module G_CAVEATS_AND_INTERNALS
      # Dummy method for documentation visibility
      def self.caveats : Array(String)
        [
          "Scene tree modifications must stay on the main thread",
          "Godot Node queue_free invalidates C++ pointers; check validity before reuse",
          "Method binds are cached statically for zero-cost ptrcall dispatch",
          "Never delete active shadow copies while Godot is running",
        ]
      end
    end
  end
end

