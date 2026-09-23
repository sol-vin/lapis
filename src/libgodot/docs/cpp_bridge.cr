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
    # ---
    #
    # ### Inner Function Segment Mechanics & Execution Walkthroughs
    #
    # Every core function in the C++ loader bridge is partitioned into explicit numbered
    # execution segments. This guarantees robust error recovery, crystal-clear diagnostic
    # tracking during crashes, and deterministic lifecycle sequencing across OS boundaries.
    #
    # #### 1. Dynamic Library Loading: `load_crystal_game_library` (11 Segments)
    #
    # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
    #   <thead>
    #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
    #       <th style="padding: 10px 14px;">Segment</th>
    #       <th style="padding: 10px 14px;">Step Name</th>
    #       <th style="padding: 10px 14px;">Detailed Operational Behavior</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 1</strong></td>
    #       <td style="padding: 10px 14px;">Resolve Directory Paths</td>
    #       <td style="padding: 10px 14px;">Extracts directory of <code>crystal_bridge.dll</code> or executable; normalizes path separators.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 2</strong></td>
    #       <td style="padding: 10px 14px;">Locate Target Candidate</td>
    #       <td style="padding: 10px 14px;">Scans prioritized candidate list: <code>plugin.dll</code>, <code>game.dll</code>, and addon relative paths.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 3</strong></td>
    #       <td style="padding: 10px 14px;">Shadow Copy Generation</td>
    #       <td style="padding: 10px 14px;">Checks <code>bridge_should_use_shadow_copy()</code>. On Windows editor, formats unique <code>game_loaded_&lt;PID&gt;_&lt;TS&gt;.dll</code>.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 4</strong></td>
    #       <td style="padding: 10px 14px;">Copy DLL to Shadow Path</td>
    #       <td style="padding: 10px 14px;">Performs byte-for-byte file copy to shadow destination; on failure, logs diagnostic and falls back to original.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 5</strong></td>
    #       <td style="padding: 10px 14px;">Companion PDB Copying</td>
    #       <td style="padding: 10px 14px;">Copies matching <code>.pdb</code> debug database alongside shadow DLL for LLDB and VEH backtrace symbol resolution.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 6</strong></td>
    #       <td style="padding: 10px 14px;">Clean Up Stale Shadow Files</td>
    #       <td style="padding: 10px 14px;">Calls <code>cleanup_old_shadow_dlls()</code> to purge unlocked leftover shadow DLLs from previous closed sessions.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 7</strong></td>
    #       <td style="padding: 10px 14px;">Preload Runtime Dependencies</td>
    #       <td style="padding: 10px 14px;">On Windows, preloads <code>gc.dll</code>, <code>iconv-2.dll</code>, and <code>pcre2-8.dll</code> via altered search path.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 8</strong></td>
    #       <td style="padding: 10px 14px;">Dynamic Module Loading</td>
    #       <td style="padding: 10px 14px;">Calls <code>LoadLibraryExA(path, NULL, LOAD_WITH_ALTERED_SEARCH_PATH)</code> on Windows or <code>dlopen(path, RTLD_NOW|RTLD_LOCAL)</code> on POSIX.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 9</strong></td>
    #       <td style="padding: 10px 14px;">Initialize GC Library Exports</td>
    #       <td style="padding: 10px 14px;">Invokes <code>init_gc_library(mod)</code> to bind GC thread-registration hooks before invoking any Crystal code.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 10</strong></td>
    #       <td style="padding: 10px 14px;">Resolve Entry Point</td>
    #       <td style="padding: 10px 14px;">Resolves exported <code>crystal_godot_init</code> symbol; handles symbol resolution failure with formatted error.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 11</strong></td>
    #       <td style="padding: 10px 14px;">Execute Library Initialization</td>
    #       <td style="padding: 10px 14px;">Executes <code>init_fn(&amp;g_bridge_api)</code> to bootstrap Crystal runtime and register classes into ClassDB.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # #### 2. Native Instance Instantiation: `generic_class_create` (6 Segments)
    #
    # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
    #   <thead>
    #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
    #       <th style="padding: 10px 14px;">Segment</th>
    #       <th style="padding: 10px 14px;">Step Name</th>
    #       <th style="padding: 10px 14px;">Detailed Operational Behavior</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 1</strong></td>
    #       <td style="padding: 10px 14px;">Descriptor &amp; Class Lookup</td>
    #       <td style="padding: 10px 14px;">Validates class userdata descriptor and resolves root native Godot base class (e.g. <code>Node3D</code>, <code>CharacterBody3D</code>).</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 2</strong></td>
    #       <td style="padding: 10px 14px;">Allocate Native Engine Object</td>
    #       <td style="padding: 10px 14px;">Invokes <code>gd_classdb_construct_object(native_class_name)</code> to allocate engine C++ object.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 3</strong></td>
    #       <td style="padding: 10px 14px;">Allocate Bridge Wrapper</td>
    #       <td style="padding: 10px 14px;">Constructs <code>GenericExtensionInstance</code> tracking native pointer, class descriptor, and Crystal userdata reference.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 4</strong></td>
    #       <td style="padding: 10px 14px;">Crystal Instance Instantiation</td>
    #       <td style="padding: 10px 14px;">Calls <code>desc-&gt;create_instance(inst)</code> to instantiate Crystal wrapper and populate internal fields.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 5</strong></td>
    #       <td style="padding: 10px 14px;">GDExtension Instance Binding</td>
    #       <td style="padding: 10px 14px;">Binds instance via <code>gd_object_set_instance(godot_obj, class_name, inst)</code> or <code>gd_object_set_instance_binding</code>.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 6</strong></td>
    #       <td style="padding: 10px 14px;">Auto-Activate Process Hooks</td>
    #       <td style="padding: 10px 14px;">If descriptor declares <code>has_process</code> or <code>has_physics_process</code>, automatically sets engine process state active.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # #### 3. Virtual Method Dispatch: `generic_class_call_virtual_with_data` (7 Segments)
    #
    # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
    #   <thead>
    #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
    #       <th style="padding: 10px 14px;">Segment</th>
    #       <th style="padding: 10px 14px;">Step Name</th>
    #       <th style="padding: 10px 14px;">Detailed Operational Behavior</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 1</strong></td>
    #       <td style="padding: 10px 14px;">Thread Lifecycle Fast-Path Rejection</td>
    #       <td style="padding: 10px 14px;">Early-returns on <code>_thread_enter</code>, <code>_thread_exit</code>, <code>_frame</code>, <code>_init</code>, <code>_finish</code> before GC registration to prevent terminating-thread crashes.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 2</strong></td>
    #       <td style="padding: 10px 14px;">Foreign Thread GC Registration</td>
    #       <td style="padding: 10px 14px;">Calls <code>ensure_gc_thread_registered()</code> to register calling Godot thread with Boehm GC stack tracking.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 3</strong></td>
    #       <td style="padding: 10px 14px;">Core Lifecycle Virtuals</td>
    #       <td style="padding: 10px 14px;">Dispatches <code>_ready</code>, <code>_process</code>, <code>_physics_process</code>, <code>_enter_tree</code>, <code>_exit_tree</code>, and <code>_build</code>. Respects <code>is_tool</code> in editor.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 4</strong></td>
    #       <td style="padding: 10px 14px;">Script &amp; Language Extensions</td>
    #       <td style="padding: 10px 14px;">Handles <code>_get_language</code>, <code>_can_inherit_from_file</code>, <code>_handles_type</code>, and <code>_get_recognized_extensions</code>.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 5</strong></td>
    #       <td style="padding: 10px 14px;">Resource Format Loaders &amp; Savers</td>
    #       <td style="padding: 10px 14px;">Routes <code>_load</code>, <code>_save</code>, <code>_recognize</code>, and <code>_get_dependencies</code> to Crystal resource format handlers.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 6</strong></td>
    #       <td style="padding: 10px 14px;">Editor Syntax Highlighting</td>
    #       <td style="padding: 10px 14px;">Routes <code>_get_line_syntax_highlighting</code> and <code>_clear_highlighting_cache</code> for custom editor syntax engines.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 7</strong></td>
    #       <td style="padding: 10px 14px;">Fallback Dynamic Virtual Dispatch</td>
    #       <td style="padding: 10px 14px;">Invokes <code>desc-&gt;call_virtual</code> for custom virtual method handlers registered by user classes.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # #### 4. Boehm GC Multi-Threading: `ensure_gc_thread_registered` (4 Segments)
    #
    # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
    #   <thead>
    #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
    #       <th style="padding: 10px 14px;">Segment</th>
    #       <th style="padding: 10px 14px;">Step Name</th>
    #       <th style="padding: 10px 14px;">Detailed Operational Behavior</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 1</strong></td>
    #       <td style="padding: 10px 14px;">Thread-Local Fast Path</td>
    #       <td style="padding: 10px 14px;">Inspects <code>t_gc_thread_registered</code>; returns immediately (0 CPU cycles overhead) if already registered.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 2</strong></td>
    #       <td style="padding: 10px 14px;">POSIX Real-Time Signal Unmasking</td>
    #       <td style="padding: 10px 14px;">On POSIX, unmasks <code>SIGPWR</code> and <code>SIGXCPU</code> via <code>pthread_sigmask</code> so Boehm GC can suspend threads during collection.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 3</strong></td>
    #       <td style="padding: 10px 14px;">Stack Base Resolution</td>
    #       <td style="padding: 10px 14px;">Calls <code>s_GC_get_stack_base(&amp;sb)</code> to determine OS thread stack high-water mark for accurate pointer scanning.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 4</strong></td>
    #       <td style="padding: 10px 14px;">GC Registration &amp; RAII Guard</td>
    #       <td style="padding: 10px 14px;">Calls <code>s_GC_register_my_thread(&amp;sb)</code>, sets thread-local flag, and binds thread destructor for clean unregistration.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # #### 5. Signal Connection: `bridge_object_connect_signal` (6 Segments)
    #
    # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
    #   <thead>
    #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
    #       <th style="padding: 10px 14px;">Segment</th>
    #       <th style="padding: 10px 14px;">Step Name</th>
    #       <th style="padding: 10px 14px;">Detailed Operational Behavior</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 1</strong></td>
    #       <td style="padding: 10px 14px;">Target &amp; Callback Validation</td>
    #       <td style="padding: 10px 14px;">Validates object pointer, non-empty signal name, and non-null signal handler callback function pointer.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 2</strong></td>
    #       <td style="padding: 10px 14px;">Signal StringName Interning</td>
    #       <td style="padding: 10px 14px;">Constructs interned <code>GDExtensionStringNamePtr</code> using thread-safe string name cache.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 3</strong></td>
    #       <td style="padding: 10px 14px;">Custom Callable Allocation</td>
    #       <td style="padding: 10px 14px;">Allocates custom callable state binding user closure data, signal name, and <code>custom_callable_call</code> dispatch.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 4</strong></td>
    #       <td style="padding: 10px 14px;">Godot Callable Construction</td>
    #       <td style="padding: 10px 14px;">Constructs engine Callable Variant via <code>gd_callable_custom_create2</code> or fallback <code>gd_callable_custom_create</code>.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 5</strong></td>
    #       <td style="padding: 10px 14px;">Native Signal Connection</td>
    #       <td style="padding: 10px 14px;">Calls native <code>Object.connect(signal, callable, flags)</code> via Godot ptrcall dispatch interface.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 6</strong></td>
    #       <td style="padding: 10px 14px;">Cleanup &amp; Error Check</td>
    #       <td style="padding: 10px 14px;">Destroys temporary stack Variants and returns connection status boolean to Crystal caller.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # #### 6. Safe Variant Unboxing: `bridge_object_from_variant` (3 Segments)
    #
    # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
    #   <thead>
    #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
    #       <th style="padding: 10px 14px;">Segment</th>
    #       <th style="padding: 10px 14px;">Step Name</th>
    #       <th style="padding: 10px 14px;">Detailed Operational Behavior</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 1</strong></td>
    #       <td style="padding: 10px 14px;">Internal Pointer Fast Path</td>
    #       <td style="padding: 10px 14px;">Calls <code>gd_variant_get_internal_ptr_object</code>; if non-null and points to valid native object, returns immediately.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 2</strong></td>
    #       <td style="padding: 10px 14px;">Standard Constructor Unboxing</td>
    #       <td style="padding: 10px 14px;">Uses <code>gd_get_variant_to_type_constructor(GDEXTENSION_VARIANT_TYPE_OBJECT)</code> into local pointer buffer.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 3</strong></td>
    #       <td style="padding: 10px 14px;">Monotonic 64-Bit ID Fallback</td>
    #       <td style="padding: 10px 14px;">Extracts 64-bit instance ID via <code>gd_variant_get_object_instance_id</code>; validates against ObjectDB via <code>gd_object_get_instance_from_id</code> to prevent dead-pointer dereferencing.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # #### 7. ClassDB Registration: `do_classdb_register` (7 Segments)
    #
    # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
    #   <thead>
    #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
    #       <th style="padding: 10px 14px;">Segment</th>
    #       <th style="padding: 10px 14px;">Step Name</th>
    #       <th style="padding: 10px 14px;">Detailed Operational Behavior</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 1</strong></td>
    #       <td style="padding: 10px 14px;">Validation &amp; Name Interning</td>
    #       <td style="padding: 10px 14px;">Validates class descriptor; interns class name and parent class name as permanent StringNames.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 2</strong></td>
    #       <td style="padding: 10px 14px;">Class Creation Info Setup</td>
    #       <td style="padding: 10px 14px;">Fills <code>GDExtensionClassCreationInfo4</code> struct with function pointers for create, free, get/set, and virtual call.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 3</strong></td>
    #       <td style="padding: 10px 14px;">Native ClassDB Registration</td>
    #       <td style="padding: 10px 14px;">Calls <code>gd_classdb_register_extension_class6</code> (or fallback <code>gd_classdb_register_extension_class4</code>).</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 4</strong></td>
    #       <td style="padding: 10px 14px;">Property Groups &amp; Subgroups</td>
    #       <td style="padding: 10px 14px;">Iterates properties; registers Inspector group headers (usage flag 64) and subgroup headers (usage flag 256).</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 5</strong></td>
    #       <td style="padding: 10px 14px;">Exported Signals Registration</td>
    #       <td style="padding: 10px 14px;">Iterates signal descriptors; registers typed signal signatures with Godot ClassDB.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 6</strong></td>
    #       <td style="padding: 10px 14px;">Constants &amp; Enums Registration</td>
    #       <td style="padding: 10px 14px;">Iterates constant descriptors; registers integer constants and typed enums for GDScript reflection.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Segment 7</strong></td>
    #       <td style="padding: 10px 14px;">Channel Methods Registration</td>
    #       <td style="padding: 10px 14px;">Registers concurrent channel methods and typed method binds into ClassDB method table.</td>
    #     </tr>
    #   </tbody>
    # </table>
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
          "module_loader.hpp",
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
          "CustomCallable signal dispatching to Crystal actor fibers",
          "Monotonic 64-bit instance ID tracking preventing dead-pointer segfaults",
        ]
      end

      # Returns the list of major bridge functions documented with segment walkthroughs
      def self.segmented_functions : Hash(String, Int32)
        {
          "load_crystal_game_library"           => 11,
          "generic_class_create"                 => 6,
          "generic_class_call_virtual_with_data" => 7,
          "ensure_gc_thread_registered"          => 4,
          "bridge_object_connect_signal"         => 6,
          "bridge_object_from_variant"           => 3,
          "do_classdb_register"                  => 7,
        }
      end
    end
  end
end
