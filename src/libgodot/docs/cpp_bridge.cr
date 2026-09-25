module Lapis
  module Docs
    # # W. Native GDExtension C++ Loader Bridge Architecture
    #
    # The native C++ loader bridge (`bin/crystal_bridge.dll`) is the high-performance intermediary
    # connecting the Godot Engine GDExtension C-API to the Crystal game dynamic library (`bin/game.dll`).
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
    #       <td><strong>Bridge Source Files</strong></td>
    #       <td><code>.topic_00_bridge_files</code></td>
    #       <td>List of all C++ bridge header and source files.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Architecture Overview</strong></td>
    #       <td><code>.topic_01_architecture_overview</code></td>
    #       <td>Responsibilities, compilation, and zero-header C-ABI flattening.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Memory & Proc Addresses</strong></td>
    #       <td><code>.topic_02_memory_layout_and_proc_addresses</code></td>
    #       <td>GDExtensionInterface function table caching, StringName caching, and GC_init.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Shadow Loader Implementation</strong></td>
    #       <td><code>.topic_03_shadow_loader_implementation</code></td>
    #       <td>Timestamped DLL cloning, file-lock bypass, and startup garbage cleanup.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>ClassDB Registration Pipeline</strong></td>
    #       <td><code>.topic_04_classdb_registration_pipeline</code></td>
    #       <td>The 7-segment registration sequence for classes, properties, signals, and methods.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Crash & Exception Guards</strong></td>
    #       <td><code>.topic_05_exception_and_crash_guards</code></td>
    #       <td>Structured exception interception protecting the engine main loop.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `src/bridge/crystal_bridge.cpp`, `src/bridge/bridge_api.hpp`, `src/bridge/classdb_registry.hpp`
    # - **Live Specifications**: `spec/suites/test_classdb_coverage.cr`
    # - **Related Guides**: `Docs::A_ARCHITECTURE`, `Docs::B_COMPILATION_AND_BUILD`, `Docs::H_LIFECYCLE_MEMORY_AND_DEAD_POINTER_SAFETY`
    module W_CPP_BRIDGE_ARCHITECTURE
      # **Bridge Source Files**: Returns the list of all C++ bridge header and source files.
      def self.topic_00_bridge_files : Array(String)
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
        ]
      end

      # **Architecture Overview**: Responsibilities, compilation, and zero-header C-ABI flattening.
      #
      # The C++ loader bridge acts as a thin, highly optimized translation layer between Godot's
      # C++ GDExtension subsystem and Crystal:
      #
      # ```text
      # [ Godot Engine (C++) ]
      #         │ (GDExtension C-API proc address table)
      #         ▼
      # [ crystal_bridge.dll (C++) ]
      #         │ (Flat BridgeAPI struct & function pointers)
      #         ▼
      # [ game.dll (Crystal) ]
      # ```
      #
      # #### Core Responsibilities:
      # 1. Bootstrapping Boehm GC (`GC_init()`) before Crystal code executes.
      # 2. Caching GDExtension interface function pointers in global static storage.
      # 3. Providing hot-reloadable shadow DLL loading on Windows without file-locking errors.
      # 4. Exposing flat C function pointers (`BridgeAPI`) so Crystal needs zero C++ headers.
      #
      # See also: `src/bridge/crystal_bridge.cpp`
      def self.topic_01_architecture_overview : Nil
      end

      # **Memory Layout & Proc Address Table**: Function pointer table caching and GC bootstrapping.
      #
      # During `crystal_library_init`, Godot passes `GDExtensionInterfaceGetProcAddress`.
      # The bridge iterates over all required engine functions and caches them:
      # - Memory functions: `mem_alloc`, `mem_free`
      # - StringName functions: `string_name_new_with_utf8_chars`, `string_name_destroy`
      # - Object functions: `object_get_instance_id`, `object_get_instance_binding`, `object_destroy`
      # - ClassDB functions: `classdb_register_extension_class`, `classdb_register_extension_class_method`
      #
      # The populated `BridgeAPI` structure is passed to `crystal_godot_init` in `game.dll`.
      #
      # See also: `src/bridge/bridge_api.hpp`
      def self.topic_02_memory_layout_and_proc_addresses : Nil
      end

      # **Shadow Loader Implementation**: Timestamped DLL cloning and file-lock bypass for Windows.
      #
      # In development mode, `crystal_bridge.cpp` prevents Windows OS file locks on `game.dll`:
      #
      # ```cpp
      # // Timestamped shadow file generation:
      # snprintf(shadow_path, sizeof(shadow_path), "%s/game_loaded_%lu_%llu.dll",
      #          dir, GetCurrentProcessId(), GetTickCount64());
      # CopyFileA(target_dll, shadow_path, FALSE);
      # HMODULE hGame = LoadLibraryA(shadow_path);
      # ```
      #
      # At bridge initialization, stale shadow DLLs from previously terminated processes
      # are automatically identified and unlinked.
      #
      # See also: `src/bridge/crystal_bridge.cpp`
      def self.topic_03_shadow_loader_implementation : Nil
      end

      # **ClassDB Registration Pipeline**: The 7-segment sequence for registering classes and members.
      #
      # When `ClassRegistry.register_all` executes, classes register in 7 sequential phases:
      #
      # <table>
      #   <thead>
      #     <tr>
      #       <th>Segment</th>
      #       <th>Registration Phase</th>
      #       <th>Engine Functionality Exposed</th>
      #     </tr>
      #   </thead>
      #   <tbody>
      #     <tr>
      #       <td><strong>1</strong></td>
      #       <td>Class DB Registration</td>
      #       <td>Registers class name, superclass, and instance creation callbacks with Godot.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>2</strong></td>
      #       <td>Property Registration</td>
      #       <td>Registers PropertyInfo (hints, types, ranges) and getters/setters into the Inspector.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>3</strong></td>
      #       <td>Signal Registration</td>
      #       <td>Registers signal names and typed arguments for Godot/GDScript event listeners.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>4</strong></td>
      #       <td>Method Binding Registration</td>
      #       <td>Registers callable methods, return types, and virtual function dispatch hooks.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>5</strong></td>
      #       <td>RPC Endpoint Registration</td>
      #       <td>Registers multiplayer replication rules (channel, call_local, sync mode).</td>
      #     </tr>
      #     <tr>
      #       <td><strong>6</strong></td>
      #       <td>Constants & Enums Registration</td>
      #       <td>Registers enum member names and integer constants for editor reflection.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>7</strong></td>
      #       <td>Channel Methods Registration</td>
      #       <td>Registers concurrent channel methods and typed async bindings into ClassDB.</td>
      #     </tr>
      #   </tbody>
      # </table>
      #
      # See also: `src/bridge/classdb_registry.hpp`
      def self.topic_04_classdb_registration_pipeline : Nil
      end

      # **Structured Exception & Crash Guards**: Exception interception protecting the engine main loop.
      #
      # To prevent unhandled Crystal exceptions or nil dereferences from abruptly terminating
      # the Godot Editor process, virtual callback invocations are wrapped in structured guards:
      #
      # ```cpp
      # void generic_dispatch_virtual(...) {
      #     try {
      #         virtual_func(instance, args, ret);
      #     } catch (const std::exception& e) {
      #         godot_printerr("[Crystal Bridge] Unhandled exception in virtual method: %s\n", e.what());
      #     } catch (...) {
      #         godot_printerr("[Crystal Bridge] Unknown crash guarded in virtual method dispatch.\n");
      #     }
      # }
      # ```
      #
      # Errors are safely routed to Godot's Output Dock while keeping the editor responsive.
      #
      # See also: `src/bridge/extension_instance.hpp`
      def self.topic_05_exception_and_crash_guards : Nil
      end
    end

    # Backwards-compatible alias for previous guide name
    alias O_CPP_BRIDGE_ARCHITECTURE = W_CPP_BRIDGE_ARCHITECTURE
  end
end
