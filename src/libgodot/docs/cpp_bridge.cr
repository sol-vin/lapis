# ==============================================================================
# LibGodot - C++ GDExtension Loader Bridge Architecture Documentation
# ==============================================================================

module Lapis
  module Docs
  # # O. C++ GDExtension Loader Bridge Architecture
  #
  # The **LibGodot C++ GDExtension Loader Bridge** (`src/bridge/`) provides the low-level,
  # native C-ABI execution bridge between the **Godot Engine 4.8+** runtime and dynamically
  # compiled **Crystal** shared libraries (`game.dll` on Windows, `game.so` on Linux).
  #
  # ---
  #
  # ### Architectural Invariants & Role
  #
  # In Godot's GDExtension architecture, the engine expects a dynamic library that exports
  # `crystal_library_init`. While Crystal can produce dynamic libraries (`--link-flags /DLL`),
  # host-driven execution (where Godot is the parent host process) poses critical runtime challenges:
  #
  # 1. **Boehm GC Thread Registration**: Foreign engine threads (Godot main thread, audio thread,
  #    rendering thread, and WorkerThreadPool workers) allocating or accessing Crystal memory
  #    crash with `EXCEPTION_ACCESS_VIOLATION` (`0xC0000005`) unless registered with Boehm GC.
  # 2. **Headerless Flat C-ABI Interface**: Crystal cannot consume complex C++ templates or
  #    Godot C++ classes directly. The bridge translates Godot's C-API function table into flat,
  #    predictable C-ABI data structures (`BridgeAPI`, `VariantArg`, `CrystalClassDesc`).
  # 3. **Windows OS DLL File-Locking & Shadow Copying**: On Windows, `LoadLibraryA` locks the DLL
  #    file on disk. The bridge creates unique timestamped shadow copies (`game_loaded_<PID>_<TS>.dll`)
  #    to leave `bin/game.dll` unlocked for continuous background compilation while the editor stays open.
  # 4. **Memory Pinning across Live Reloads**: When Godot reloads a GDExtension, it calls `FreeLibrary`
  #    on the extension DLL. Because Godot's `ClassDB` retains function pointers and instance userdata
  #    pointers, unmapping the bridge causes immediate access violations. The bridge pins itself in
  #    memory (`GET_MODULE_HANDLE_EX_FLAG_PIN` / `RTLD_NODELETE`) to remain permanent across reloads.
  #
  # ---
  #
  # ### File Map Overview
  #
  # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
  #   <thead>
  #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
  #       <th style="padding: 10px 14px;">File</th>
  #       <th style="padding: 10px 14px;">Role</th>
  #       <th style="padding: 10px 14px;">Primary Functionality</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>crystal_bridge.cpp</code></td>
  #       <td style="padding: 10px 14px;">Master Entry Point</td>
  #       <td style="padding: 10px 14px;">Exports <code>crystal_library_init</code>, manages GDExtension lifecycle levels, and coordinates module unloading.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>common.hpp</code></td>
  #       <td style="padding: 10px 14px;">Platform & Crash Diagnostics</td>
  #       <td style="padding: 10px 14px;">Win32/POSIX platform abstractions, crash interception, and backtrace generation to <code>crash_dump.log</code>.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>gdextension_api.hpp</code></td>
  #       <td style="padding: 10px 14px;">Function Pointer Table</td>
  #       <td style="padding: 10px 14px;">Dynamically resolves and caches Godot C-API function pointers from <code>p_get_proc_address</code>.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>bridge_types.hpp</code></td>
  #       <td style="padding: 10px 14px;">C-ABI Data Contracts</td>
  #       <td style="padding: 10px 14px;">Defines <code>VariantArg</code>, <code>BridgeSignalArg</code>, <code>CrystalClassDesc</code>, <code>GenericExtensionInstance</code>, and <code>BridgeAPI</code>.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>gc_support.hpp</code></td>
  #       <td style="padding: 10px 14px;">Boehm GC Thread Safety</td>
  #       <td style="padding: 10px 14px;">Dynamically discovers <code>gc.dll</code> exports and registers foreign Godot threads with the garbage collector.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>editor_doc.hpp</code></td>
  #       <td style="padding: 10px 14px;">XML Help Harvester</td>
  #       <td style="padding: 10px 14px;">Buffers XML class/property doc comments and flushes them into Godot's <code>EditorHelp</code> subsystem.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>dispatch_signals.hpp</code></td>
  #       <td style="padding: 10px 14px;">Method & Signal Dispatch</td>
  #       <td style="padding: 10px 14px;">Variant marshaling, interned StringNames, CustomCallable signal wrappers, and dynamic vararg dispatch.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>extension_instance.hpp</code></td>
  #       <td style="padding: 10px 14px;">Instance Lifecycle</td>
  #       <td style="padding: 10px 14px;">Instantiates Godot native base classes, binds Crystal objects, routes virtual methods, and handles property get/set.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>classdb_registry.hpp</code></td>
  #       <td style="padding: 10px 14px;">ClassDB Reflection</td>
  #       <td style="padding: 10px 14px;">Registers custom classes, properties, signals, constants, and defers editor-only classes to EDITOR level.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>bridge_api.hpp</code></td>
  #       <td style="padding: 10px 14px;">Exported API Assembly</td>
  #       <td style="padding: 10px 14px;">Populates global <code>BridgeAPI</code> table and defines exported C symbols for external binding.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>module_loader.hpp</code></td>
  #       <td style="padding: 10px 14px;">Dynamic Library Loader</td>
  #       <td style="padding: 10px 14px;">Discovers candidate DLLs, creates timestamped shadow copies, preloads runtime DLLs, and calls <code>crystal_godot_init</code>.</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # ---
  #
  # ### Deep Dive: Detailed File Mechanics
  #
  # #### 1. `crystal_bridge.cpp`
  # The master compilation translation unit and GDExtension library entry point.
  # - **`crystal_library_init`**: Godot passes `GDExtensionInterfaceGetProcAddress`, a library handle pointer, and an output initialization structure.
  # - **Memory Pinning**: On Windows, invokes `GetModuleHandleExA` with `GET_MODULE_HANDLE_EX_FLAG_PIN`. On Linux/POSIX, invokes `dlopen(..., RTLD_NODELETE)`. This guarantees that Godot's internal `FreeLibrary` during GDExtension reload does not unmap the loader bridge code while ClassDB retains pointers to it.
  # - **Lifecycle Levels**:
  #   - `GDEXTENSION_INITIALIZATION_CORE` & `SERVERS`: Low-level pass-through.
  #   - `GDEXTENSION_INITIALIZATION_SCENE`: Invokes `init_common_method_binds()`, prints initialization banner, and invokes `load_crystal_game_library()` to load `game.dll` and register gameplay classes.
  #   - `GDEXTENSION_INITIALIZATION_EDITOR`: Registers deferred editor classes (`EditorPlugin`, `EditorSyntaxHighlighter`) and flushes XML documentation into `EditorHelp`.
  # - **Deinitialization**: Distinguishes engine shutdown from live reload. Invokes Crystal deinitialization callbacks (`g_library_deinit_callbacks`) before tearing down classes.
  #
  # #### 2. `common.hpp`
  # Provides OS-level header imports, compiler visibility macros, and crash diagnostics:
  # - **`GDE_EXPORT`**: Translates to `__declspec(dllexport)` on MSVC/MinGW, and `__attribute__((visibility("default")))` on GCC/Clang.
  # - **Vectored Exception Handling (VEH)**: On Windows, installs `custom_crash_handler` via `AddVectoredExceptionHandler`. Upon intercepting an `EXCEPTION_ACCESS_VIOLATION` (`0xC0000005`) or `STATUS_HEAP_CORRUPTION` (`0xC0000374`), it captures a 32-frame stack backtrace using `CaptureStackBackTrace`, resolves module names and relative offsets via `GetModuleHandleExA`, writes `crash_dump.log`, and outputs the diagnostic report to stderr and stdout.
  #
  # #### 3. `gdextension_api.hpp`
  # Manages the dynamic function pointer table required to interact with Godot's C-API:
  # - Stores static function pointers populated during `crystal_library_init` (e.g. `gd_string_name_new_with_utf8_chars`, `gd_variant_destroy`, `gd_classdb_register_extension_class6`).
  # - Contains engine logging utilities: `godot_log_print` (Godot console print), `godot_log_printerr` (standard error), `godot_log_error`, and `godot_log_warning`. These ensure diagnostics route to Godot's in-editor Output and Debugger panels as well as OS stdout.
  #
  # #### 4. `bridge_types.hpp`
  # Specifies the binary layout of all data exchanged between C++ and Crystal:
  # - **`VariantArg`**: Tagged union supporting integers, floats, pointers, 64-bit instance IDs, and 4-component vector arrays (`vec_val[4]`).
  # - **`CrystalPropertyDesc`**: Describes an `@Export` property (name, Godot type string, variant type enum, property hint, hint formatting string, and usage bitflags).
  # - **`CrystalSignalDesc`**: Defines signal signature metadata and argument types.
  # - **`CrystalClassDesc`**: Master metadata descriptor containing class flags (`is_tool`, `has_process`, `has_physics_process`, etc.) and host function pointers (`create_instance`, `free_instance`, `call_virtual`, `set_property`, `get_property`).
  # - **`PersistentClassDesc`**: Deep-copies string identifiers into invariant C++ standard library buffers (`std::string`), ensuring pointers passed to Godot's `ClassDB` remain valid across hot-reload cycles.
  # - **`BridgeAPI`**: Function pointer table passed directly to `crystal_godot_init(&g_bridge_api)`.
  #
  # #### 5. `gc_support.hpp`
  # Handles multi-threading and Boehm GC integration:
  # - **Foreign Thread Registration**: Godot utilizes background worker threads (`WorkerThreadPool`), an audio server thread, and physics threads. If any of these threads allocate Crystal objects or invoke Crystal methods that trigger garbage collection, Boehm GC must know the thread's stack boundaries.
  # - **Dynamic Symbol Discovery**: Dynamically resolves `GC_init`, `GC_allow_register_threads`, `GC_get_stack_base`, and `GC_register_my_thread` from `gc.dll` or `libgc.so`.
  # - **Fast Thread-Local Cache**: Uses `thread_local bool t_gc_thread_registered` so that once a thread is registered, subsequent entries incur zero overhead.
  #
  # #### 6. `editor_doc.hpp`
  # Provides Godot's in-editor F1 Help and hover tooltip documentation system:
  # - Collects doc comments harvested by Crystal macros into XML strings.
  # - Buffers XML documents until Godot reaches `GDEXTENSION_INITIALIZATION_EDITOR`.
  # - Invokes `gd_editor_help_load_xml_from_utf8_chars` to register class and property documentation into Godot's offline documentation database.
  #
  # #### 7. `dispatch_signals.hpp`
  # Implements bidirectional method calling, Variant conversion, and CustomCallable signal dispatch:
  # - **StringName Interning (`s_string_name_cache`)**: Engine StringNames are interned for process lifetime. Destroying StringNames during runtime causes Godot's static string pool to complain with `BUG: Unreferenced static string to 0`.
  # - **Variant Unboxing**: Features multi-tiered fallback in `bridge_object_from_variant`:
  #   1. Fast internal pointer access (`gd_variant_get_internal_ptr_object`).
  #   2. Standard type constructor unboxing (`gd_get_variant_to_type_constructor`).
  #   3. Safe 64-bit instance ID resolution (`gd_variant_get_object_instance_id` + `gd_object_get_instance_from_id`).
  # - **Signal Dispatch via `CustomCallable`**: Connects Godot signals to Crystal using `callable_custom_create2` (or `callable_custom_create`). When Godot fires a signal, `custom_callable_call` converts Variant arguments into an array of `VariantArg` structs and routes them directly to Crystal's `s_crystal_signal_callback`.
  #
  # #### 8. `extension_instance.hpp`
  # Manages instance instantiation, virtual method routing, and property access:
  # - **`generic_class_create`**: Resolves the root native Godot class (e.g. `CharacterBody3D`), invokes `ClassDB` to allocate the C++ node, wraps it in `GenericExtensionInstance`, calls Crystal's `create_instance` callback, binds the instance via `gd_object_set_instance`, and auto-enables idle and physics processing.
  # - **`generic_class_recreate`**: Reconnects a Crystal instance wrapper to an existing native object during scene deserialization or reload.
  # - **Virtual Dispatch**: Dispatches `_ready`, `_process(delta)`, `_physics_process(delta)`, `_enter_tree`, `_exit_tree`, and `_build` into Crystal. Respects `@tool` annotations by checking `is_editor_active()`.
  # - **Property Get/Set**: Routes property modifications from the Godot Inspector into Crystal's `set_property` and `get_property` handlers.
  #
  # #### 9. `classdb_registry.hpp`
  # Handles registration with Godot's `ClassDB`:
  # - **`bridge_register_class`**: Registers custom Crystal nodes, exported `@Export` properties, signals, and constants.
  # - **Inspector Property Groups**: Maps property usage bitflags (64 for group, 256 for subgroup) to `gd_classdb_register_extension_class_property_group` and `subgroup`.
  # - **Deferred Editor Classes**: Classes inheriting from `EditorPlugin`, `EditorSyntaxHighlighter`, or `EditorDebuggerPlugin` cannot be registered at `SCENE` level; they are automatically queued into `g_deferred_editor_classes` and registered when Godot reaches `GDEXTENSION_INITIALIZATION_EDITOR`.
  #
  # #### 10. `bridge_api.hpp`
  # Assembles and exports the C-ABI function pointer interface:
  # - Initializes the master `g_bridge_api` struct containing all bridge function pointers.
  # - Exports external C symbols (`crystal_godot_print`, `crystal_bridge_get_api`, `crystal_bridge_set_reloading`, etc.) with `GDE_EXPORT` for foreign language interop or static linkage.
  #
  # #### 11. `module_loader.hpp`
  # Handles library discovery, runtime dependency loading, and Windows shadow copying:
  # - **Candidate Search**: Scans the bridge directory for `plugin.dll`, `game.dll`, or custom addon DLLs.
  # - **Preloading Dependencies**: On Windows, preloads runtime DLLs (`gc.dll`, `iconv-2.dll`, `pcre2-8.dll`) before loading game modules.
  # - **Shadow Copy Mechanism**: When running inside the Godot Editor (`bridge_should_use_shadow_copy()`), copies the target library to `game_loaded_<PID>_<TIMESTAMP>.dll` and loads the shadow copy via `LoadLibraryExA(..., LOAD_WITH_ALTERED_SEARCH_PATH)`.
  # - **Cleanup**: `cleanup_old_shadow_dlls` scans for and deletes temporary shadow copies from previous closed sessions.
  # - **Handoff**: Resolves `crystal_godot_init` in the loaded library and invokes it, passing `&g_bridge_api`.
  #
  module O_CPP_BRIDGE_ARCHITECTURE
    # Returns the list of all C++ bridge files documented in this module
    def self.files : Array(String)
      [
        "crystal_bridge.cpp",
        "common.hpp",
        "gdextension_api.hpp",
        "bridge_types.hpp",
        "gc_support.hpp",
        "editor_doc.hpp",
        "dispatch_signals.hpp",
        "extension_instance.hpp",
        "classdb_registry.hpp",
        "bridge_api.hpp",
        "module_loader.hpp"
      ]
    end

    # Returns architectural invariants summary
    def self.invariants : Array(String)
      [
        "Boehm GC foreign thread registration via gc_support.hpp",
        "Zero C++ header dependency in Crystal via BridgeAPI C-ABI table",
        "Windows DLL shadow copying for unlocked background recompilation",
        "Memory pinning (GET_MODULE_HANDLE_EX_FLAG_PIN) across live reloads",
        "EditorHelp XML doc comment harvesting into Godot offline help",
        "CustomCallable signal dispatching to Crystal actor fibers"
      ]
    end
  end
  end
end
