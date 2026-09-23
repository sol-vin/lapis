/**
 * ==============================================================================
 * LibGodot for Crystal - GDExtension Loader Bridge (crystal_bridge.cpp)
 * ==============================================================================
 *
 * Architecture & Design:
 * ----------------------
 * This file implements the native C++ GDExtension loader bridge connecting the
 * Godot Engine 4.x runtime to dynamically compiled Crystal shared libraries
 * (game.dll on Windows, game.so on Linux).
 *
 * Architectural Invariants:
 * 1. Entry Point Handshake: Exports `crystal_library_init`, the sole native symbol
 *    mandated by Godot's GDExtension specification.
 * 2. Memory Pinning: Pins the loader bridge DLL in process memory across reloads,
 *    preventing unmapping crashes while Godot's ClassDB retains function pointers.
 * 3. GC Thread Safety: Bootstraps Boehm Garbage Collector foreign thread registration
 *    before foreign engine threads call into Crystal.
 * 4. Modular Separation:
 *    - common.hpp: System headers, platform abstractions, SEH crash dumps.
 *    - gdextension_api.hpp: Cached Godot C-API function pointers and logging.
 *    - bridge_types.hpp: C-ABI data structures (VariantArg, CrystalClassDesc, BridgeAPI).
 *    - gc_support.hpp: Boehm GC foreign engine thread registration.
 *    - editor_doc.hpp: In-Editor XML Help Documentation harvester.
 *    - dispatch_signals.hpp: Method bind dispatch, Variant marshaling, CustomCallable.
 *    - extension_instance.hpp: GenericExtensionInstance lifecycle and property access.
 *    - classdb_registry.hpp: ClassDB class registration and reflection.
 *    - bridge_api.hpp: Master BridgeAPI function table and exported C API.
 *    - module_loader.hpp: Dynamic library loading, shadow copying, and hot reloading.
 * ==============================================================================
 */

#include "common.hpp"
#include "gdextension_api.hpp"
#include "bridge_types.hpp"
#include "gc_support.hpp"
#include "editor_doc.hpp"
#include "dispatch_signals.hpp"
#include "extension_instance.hpp"
#include "classdb_registry.hpp"
#include "bridge_api.hpp"
#include "module_loader.hpp"
#include "godot_version.h"

// Track active extensions sharing this bridge instance
static int g_active_extension_count = 0;

// ==============================================================================
// GDExtension Module Lifecycle Callbacks
// ==============================================================================

/**
 * Callback invoked by Godot at distinct initialization levels (CORE, SERVERS, SCENE, EDITOR).
 *
 * @param p_userdata Opaque pointer to the GDExtensionClassLibraryPtr assigned by Godot.
 * @param p_level Active engine initialization level.
 *
 * Execution Flow:
 * - Level CORE & SERVERS: No-op for high-level Crystal gameplay extensions.
 * - Level SCENE: Initializes common method binds and boots Crystal runtime (`load_crystal_game_library`).
 * - Level EDITOR: Registers deferred editor plugins/tools and flushes XML documentation into `EditorHelp`.
 */
static void initialize_crystal_module(void *p_userdata, GDExtensionInitializationLevel p_level) {
    // --- Segment 1: Library Pointer & Level Caching ---
    // Cache the active GDExtensionClassLibraryPtr from Godot's userdata. This handle is
    // required when registering classes with ClassDB to bind them to this specific extension.
    if (p_userdata) {
        g_library = (GDExtensionClassLibraryPtr)p_userdata;
    }
    g_current_init_level = p_level;
    s_is_reloading = 0;

    // --- Segment 2: SCENE Level Initialization (Runtime Bootstrapping) ---
    // Godot scene tree and core server singletons are now available.
    // Configure worker environment, resolve common Node/Object method binds, and load game.dll.
    if (p_level == GDEXTENSION_INITIALIZATION_SCENE) {
#ifndef _WIN32
        // Restrict Crystal worker threads to 1 by default in shared library mode to avoid thread storms
        setenv("CRYSTAL_WORKERS", "1", 0);
#endif
        init_common_method_binds();
        godot_log_verbose("[CrystalBridge] Initializing generic Crystal GDExtension host...");
        load_crystal_game_library((GDExtensionClassLibraryPtr)p_userdata);
    }
    // --- Segment 3: EDITOR Level Initialization (Tool & Help Registration) ---
    // In editor builds, Godot reaches this level after the main editor interface is fully booted.
    // Register tool classes (EditorPlugin, syntax highlighters) and flush doc comments into EditorHelp.
    else if (p_level == GDEXTENSION_INITIALIZATION_EDITOR) {
        register_deferred_editor_classes();
        bridge_flush_editor_help();
    }
}

#ifdef _WIN32
static bool s_handler_installed = false;
static PVOID g_veh_handler = NULL;
#endif

/**
 * Callback invoked by Godot during engine shutdown or live extension reload.
 *
 * @param p_userdata Pointer to the GDExtensionClassLibraryPtr being deinitialized.
 * @param p_level Current deinitialization level (executed in reverse order: EDITOR -> SCENE -> SERVERS -> CORE).
 *
 * Safety & Teardown Rules:
 * - Editor classes must be unregistered at EDITOR level before editor singletons are destroyed.
 * - Scene classes must be unregistered at SCENE level in reverse registration order.
 * - Deinit callbacks defined in Crystal must run before unloading the shared library.
 * - StringName caches must be preserved across reloads to avoid Godot static string pool corruption.
 */
static void deinitialize_crystal_module(void *p_userdata, GDExtensionInitializationLevel p_level) {
    // --- Segment 1: Library Handle Recovery ---
    // Recover the library pointer being unloaded, falling back to global library handle if null.
    GDExtensionClassLibraryPtr lib = (GDExtensionClassLibraryPtr)p_userdata;
    if (!lib) {
        lib = g_library;
    } else {
        g_library = lib;
    }

    // --- Segment 2: EDITOR Level Teardown ---
    // Unregister editor-specific classes from ClassDB before Godot tears down EditorInterface.
    // Classes are unregistered in reverse registration order (LIFO) to respect inheritance trees.
    if (p_level == GDEXTENSION_INITIALIZATION_EDITOR) {
        if (gd_classdb_unregister_extension_class && lib) {
            auto it_ed = g_library_editor_classes.find(lib);
            if (it_ed != g_library_editor_classes.end()) {
                for (int i = (int)it_ed->second.size() - 1; i >= 0; i--) {
                    const std::string &cname = it_ed->second[i];
                    void *sn = make_string_name(cname.c_str());
                    gd_classdb_unregister_extension_class(it_ed->first, sn);
                    g_all_registered_class_names.erase(cname);
                }
                g_library_editor_classes.erase(it_ed);
            }
        }
    }
    // --- Segment 3: SCENE Level Teardown ---
    // Execute Crystal deinitialization callbacks, then unregister all remaining scene classes.
    else if (p_level == GDEXTENSION_INITIALIZATION_SCENE) {
        // Run registered Crystal deinitialization callbacks (e.g. unregistering scripts, loader, saver, language)
        if (lib) {
            auto it = g_library_deinit_callbacks.find(lib);
            if (it != g_library_deinit_callbacks.end()) {
                for (auto fn : it->second) {
                    if (fn) fn();
                }
                g_library_deinit_callbacks.erase(it);
            }
        }

        if (gd_classdb_unregister_extension_class && lib) {
            // Unregister any remaining editor classes (e.g. in standalone mode where EDITOR level does not fire)
            auto it_ed = g_library_editor_classes.find(lib);
            if (it_ed != g_library_editor_classes.end()) {
                for (int i = (int)it_ed->second.size() - 1; i >= 0; i--) {
                    const std::string &cname = it_ed->second[i];
                    void *sn = make_string_name(cname.c_str());
                    gd_classdb_unregister_extension_class(it_ed->first, sn);
                    g_all_registered_class_names.erase(cname);
                }
                g_library_editor_classes.erase(it_ed);
            }

            // Unregister scene classes for this library in reverse registration order
            auto it_sc = g_library_scene_classes.find(lib);
            if (it_sc != g_library_scene_classes.end()) {
                for (int i = (int)it_sc->second.size() - 1; i >= 0; i--) {
                    const std::string &cname = it_sc->second[i];
                    void *sn = make_string_name(cname.c_str());
                    gd_classdb_unregister_extension_class(it_sc->first, sn);
                    g_all_registered_class_names.erase(cname);
                }
                g_library_scene_classes.erase(it_sc);
            }
        }

        // --- Segment 4: Active Extension Counter & Final Cleanup ---
        // Decrement reference count of active extensions sharing this bridge.
        // When counter reaches zero, perform global state sweep, unload game library, and reset flags.
        g_active_extension_count--;
        if (g_active_extension_count <= 0) {
            g_active_extension_count = 0;

            // Execute any fallback callbacks for extensions that did not deinit cleanly
            for (auto &pair : g_library_deinit_callbacks) {
                for (auto fn : pair.second) {
                    if (fn) fn();
                }
            }
            g_library_deinit_callbacks.clear();

            // Sweep any remaining unregistered classes across untracked library handles
            if (gd_classdb_unregister_extension_class) {
                for (auto &pair : g_library_editor_classes) {
                    for (int i = (int)pair.second.size() - 1; i >= 0; i--) {
                        void *sn = make_string_name(pair.second[i].c_str());
                        gd_classdb_unregister_extension_class(pair.first, sn);
                        g_all_registered_class_names.erase(pair.second[i]);
                    }
                }
                for (auto &pair : g_library_scene_classes) {
                    for (int i = (int)pair.second.size() - 1; i >= 0; i--) {
                        void *sn = make_string_name(pair.second[i].c_str());
                        gd_classdb_unregister_extension_class(pair.first, sn);
                        g_all_registered_class_names.erase(pair.second[i]);
                    }
                }
            }
            g_library_editor_classes.clear();
            g_library_scene_classes.clear();
            g_deferred_editor_classes.clear();
            g_editor_doc_xmls.clear();
            g_loader_registered = 0;
            g_saver_registered = 0;
            g_language_registered = 0;

            // Clean StringName cache only on process shutdown, never during hot reload
            if (!s_is_reloading) {
                bridge_cleanup_string_name_cache();
            }
            s_is_reloading = 0;
            unload_crystal_game_library();
            godot_log_verbose("[CrystalBridge] Crystal module deinitialized.");
        }
    }
}

/**
 * Validates semantic version compatibility between target engine and runtime engine.
 *
 * @param expected Null-terminated target semver string (e.g. "4.8-dev6").
 * @param actual Null-terminated active Godot version string (e.g. "4.8.dev6.official").
 * @return True if all expected version tokens match the active engine string.
 */
static inline bool bridge_version_matches(const char *expected, const char *actual) {
    if (!expected || !actual) return false;
    std::string exp_str(expected);
    std::string act_str(actual);

    // --- Segment 1: Alphanumeric Tokenizer ---
    // Normalizes version strings by stripping 'v' prefixes and treating punctuation as token separators.
    auto tokenize = [](const std::string &s) {
        std::vector<std::string> tokens;
        std::string cur;
        for (size_t i = 0; i < s.size(); ++i) {
            char c = s[i];
            if ((c == 'v' || c == 'V') && cur.empty() && i + 1 < s.size() && isdigit((unsigned char)s[i + 1])) {
                continue;
            }
            if (isalnum((unsigned char)c)) {
                cur += (char)tolower(c);
            } else {
                if (!cur.empty()) {
                    tokens.push_back(cur);
                    cur.clear();
                }
            }
        }
        if (!cur.empty()) tokens.push_back(cur);
        return tokens;
    };

    std::vector<std::string> exp_tokens = tokenize(exp_str);
    std::vector<std::string> act_tokens = tokenize(act_str);

    if (exp_tokens.empty() || act_tokens.empty()) return false;

    // --- Segment 2: Subset Token Matching ---
    // Ensures that every token specified in expected version exists in the actual version.
    for (const auto &exp : exp_tokens) {
        bool found = false;
        for (const auto &act : act_tokens) {
            if (exp == act) {
                found = true;
                break;
            }
        }
        if (!found) return false;
    }
    return true;
}

// ==============================================================================
// GDExtension Library Master Entry Point
// ==============================================================================

/**
 * Master GDExtension entry point exported from crystal_bridge.dll / .so.
 *
 * @param p_get_proc_address Godot's C-API symbol lookup function pointer.
 * @param p_library Opaque handle to the extension library assigned by the engine.
 * @param r_initialization Pointer to output struct to populate with init/deinit callbacks.
 * @return GDExtensionBool (1 for success, 0 for abort).
 */
extern "C" GDE_EXPORT GDExtensionBool crystal_library_init(
    GDExtensionInterfaceGetProcAddress p_get_proc_address,
    GDExtensionClassLibraryPtr p_library,
    GDExtensionInitialization *r_initialization
) {
    // --- Segment 1: Engine Version Verification ---
    // Enforces engine version compatibility unless explicitly bypassed by LAPIS_SKIP_VERSION_CHECK.
    // Prevents subtle ABI memory corruption caused by mismatched Godot C-API function signatures.
#ifdef LIBGODOT_TARGET_VERSION
    const char *skip_ver_env = getenv("LAPIS_SKIP_VERSION_CHECK");
    bool skip_ver = (skip_ver_env && (strcmp(skip_ver_env, "1") == 0 || strcmp(skip_ver_env, "true") == 0));
    if (!skip_ver) {
        GDExtensionInterfaceGetGodotVersion get_godot_version =
            (GDExtensionInterfaceGetGodotVersion)p_get_proc_address("get_godot_version");
        if (get_godot_version) {
            GDExtensionGodotVersion gv;
            memset(&gv, 0, sizeof(gv));
            get_godot_version(&gv);
            if (gv.string && !bridge_version_matches(LIBGODOT_TARGET_VERSION, gv.string)) {
                fprintf(stderr, "\n==================================================================\n");
                fprintf(stderr, "  [CrystalBridge] FATAL ERROR: Godot engine version mismatch!\n");
                fprintf(stderr, "  Bridge compiled for : %s\n", LIBGODOT_TARGET_VERSION);
                fprintf(stderr, "  Running Godot       : %s\n", gv.string);
                fprintf(stderr, "  Please recompile with matching engine or run 'make setup-dev'.\n");
                fprintf(stderr, "  (Set LAPIS_SKIP_VERSION_CHECK=1 to bypass)\n");
                fprintf(stderr, "==================================================================\n\n");
                return 0;
            }
        }
    }
#endif

    // --- Segment 2: Memory Pinning Across Live Reloads ---
    // When Godot reloads an extension (e.g. F5 in editor), it calls FreeLibrary on the DLL.
    // However, Godot's ClassDB and MessageQueue retain function pointers and userdata pointers
    // across reloads. If the DLL is unmapped from virtual address space, subsequent dispatches
    // immediately trigger EXCEPTION_ACCESS_VIOLATION (0xC0000005).
    // Pinning the bridge ensures the loader code and static wrappers stay resident permanently.
#ifdef _WIN32
    HMODULE hBridgeMod = NULL;
    GetModuleHandleExA(
        GET_MODULE_HANDLE_EX_FLAG_PIN | GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS,
        (LPCSTR)&crystal_library_init,
        &hBridgeMod
    );
#elif !defined(__APPLE__) && !defined(__ANDROID__)
    Dl_info dli;
    if (dladdr((void*)&crystal_library_init, &dli) && dli.dli_fname) {
        dlopen(dli.dli_fname, RTLD_NOW | RTLD_NODELETE);
    }
#endif

    g_active_extension_count++;

    // --- Segment 3: Boehm GC Bootstrapping & Thread Registration ---
    // Discover Boehm GC dynamic symbols (from gc.dll on Windows or libgc on Linux)
    // and immediately register the current engine main thread with GC.
#ifndef _WIN32
    record_main_thread();
#endif
    init_gc_library();
    ensure_gc_thread_registered();

    // --- Segment 4: Windows Crash Interceptor (VEH) Installation ---
    // Install custom vectored exception handler to capture backtraces for access violations.
#ifdef _WIN32
    if (!s_handler_installed) {
        s_handler_installed = true;
        g_veh_handler = AddVectoredExceptionHandler(1, custom_crash_handler);
    }
#else
    setenv("CRYSTAL_WORKERS", "1", 0);
#endif

    // --- Segment 5: C-API Function Pointer Resolution ---
    // Cache the root proc address function and library pointer, then resolve all required
    // GDExtension interface function pointers from Godot's C function table.
    gd_get_proc_address = p_get_proc_address;
    g_library = p_library;

    gd_string_name_new_with_utf8_chars = (GDExtensionInterfaceStringNameNewWithUtf8Chars)p_get_proc_address("string_name_new_with_utf8_chars");
    gd_string_new_with_utf8_chars = (GDExtensionInterfaceStringNewWithUtf8Chars)p_get_proc_address("string_new_with_utf8_chars");
    gd_variant_destroy = (GDExtensionInterfaceVariantDestroy)p_get_proc_address("variant_destroy");
    gd_classdb_construct_object = (GDExtensionInterfaceClassdbConstructObject)p_get_proc_address("classdb_construct_object");
    gd_object_set_instance = (GDExtensionInterfaceObjectSetInstance)p_get_proc_address("object_set_instance");
    gd_classdb_register_extension_class6 = (GDExtensionInterfaceClassdbRegisterExtensionClass6)p_get_proc_address("classdb_register_extension_class6");
    gd_classdb_unregister_extension_class = (GDExtensionInterfaceClassdbUnregisterExtensionClass)p_get_proc_address("classdb_unregister_extension_class");
    gd_classdb_register_extension_class_property = (GDExtensionInterfaceClassdbRegisterExtensionClassProperty)p_get_proc_address("classdb_register_extension_class_property");
    gd_classdb_register_extension_class_property_group = (GDExtensionInterfaceClassdbRegisterExtensionClassPropertyGroup)p_get_proc_address("classdb_register_extension_class_property_group");
    gd_classdb_register_extension_class_property_subgroup = (GDExtensionInterfaceClassdbRegisterExtensionClassPropertySubgroup)p_get_proc_address("classdb_register_extension_class_property_subgroup");
    gd_classdb_register_extension_class_integer_constant = (GDExtensionInterfaceClassdbRegisterExtensionClassIntegerConstant)p_get_proc_address("classdb_register_extension_class_integer_constant");
    gd_classdb_register_extension_class_signal = (GDExtensionInterfaceClassdbRegisterExtensionClassSignal)p_get_proc_address("classdb_register_extension_class_signal");
    gd_classdb_register_extension_class_method = (GDExtensionInterfaceClassdbRegisterExtensionClassMethod)p_get_proc_address("classdb_register_extension_class_method");
    gd_classdb_get_method_bind = (GDExtensionInterfaceClassdbGetMethodBind)p_get_proc_address("classdb_get_method_bind");
    gd_object_method_bind_ptrcall = (GDExtensionInterfaceObjectMethodBindPtrcall)p_get_proc_address("object_method_bind_ptrcall");
    gd_object_method_bind_call = (GDExtensionInterfaceObjectMethodBindCall)p_get_proc_address("object_method_bind_call");
    gd_editor_help_load_xml_from_utf8_chars = (GDExtensionsInterfaceEditorHelpLoadXmlFromUtf8Chars)p_get_proc_address("editor_help_load_xml_from_utf8_chars");
    gd_global_get_singleton = (GDExtensionInterfaceGlobalGetSingleton)p_get_proc_address("global_get_singleton");
    gd_get_variant_from_type_constructor = (GDExtensionInterfaceGetVariantFromTypeConstructor)p_get_proc_address("get_variant_from_type_constructor");
    gd_get_variant_to_type_constructor = (GDExtensionInterfaceGetVariantToTypeConstructor)p_get_proc_address("get_variant_to_type_constructor");
    gd_variant_get_type = (GDExtensionInterfaceVariantGetType)p_get_proc_address("variant_get_type");
    gd_variant_get_object_instance_id = (GDExtensionInterfaceVariantGetObjectInstanceId)p_get_proc_address("variant_get_object_instance_id");
    gd_object_get_instance_from_id = (GDExtensionInterfaceObjectGetInstanceFromId)p_get_proc_address("object_get_instance_from_id");
    gd_object_destroy = (GDExtensionInterfaceObjectDestroy)p_get_proc_address("object_destroy");
    gd_object_get_instance_id = (GDExtensionInterfaceObjectGetInstanceId)p_get_proc_address("object_get_instance_id");
    gd_object_get_class_name = (GDExtensionInterfaceObjectGetClassName)p_get_proc_address("object_get_class_name");
    gd_ref_set_object = (GDExtensionInterfaceRefSetObject)p_get_proc_address("ref_set_object");
    gd_ref_get_object = (GDExtensionInterfaceRefGetObject)p_get_proc_address("ref_get_object");
    gd_variant_stringify = (GDExtensionInterfaceVariantStringify)p_get_proc_address("variant_stringify");
    gd_string_to_utf8_chars = (GDExtensionInterfaceStringToUtf8Chars)p_get_proc_address("string_to_utf8_chars");
    gd_get_library_path = (GDExtensionInterfaceGetLibraryPath)p_get_proc_address("get_library_path");

    GDExtensionInterfaceVariantGetPtrInternalGetter get_internal = (GDExtensionInterfaceVariantGetPtrInternalGetter)p_get_proc_address("variant_get_ptr_internal_getter");
    if (get_internal) {
        gd_variant_get_internal_ptr_object = get_internal(GDEXTENSION_VARIANT_TYPE_OBJECT);
    }

    // Logging & error functions
    gd_print_error = (GDExtensionInterfacePrintError)p_get_proc_address("print_error");
    gd_print_error_with_message = (GDExtensionInterfacePrintErrorWithMessage)p_get_proc_address("print_error_with_message");
    gd_print_warning = (GDExtensionInterfacePrintWarning)p_get_proc_address("print_warning");
    gd_print_warning_with_message = (GDExtensionInterfacePrintWarningWithMessage)p_get_proc_address("print_warning_with_message");
    gd_variant_get_ptr_utility_function = (GDExtensionInterfaceVariantGetPtrUtilityFunction)p_get_proc_address("variant_get_ptr_utility_function");
    gd_variant_get_ptr_constructor = (GDExtensionInterfaceVariantGetPtrConstructor)p_get_proc_address("variant_get_ptr_constructor");
    gd_variant_get_ptr_destructor = (GDExtensionInterfaceVariantGetPtrDestructor)p_get_proc_address("variant_get_ptr_destructor");
    gd_variant_get_ptr_builtin_method = (GDExtensionInterfaceVariantGetPtrBuiltinMethod)p_get_proc_address("variant_get_ptr_builtin_method");
    gd_variant_get_ptr_keyed_setter = (GDExtensionInterfaceVariantGetPtrKeyedSetter)p_get_proc_address("variant_get_ptr_keyed_setter");

    gd_callable_custom_create2 = (GDExtensionInterfaceCallableCustomCreate2)p_get_proc_address("callable_custom_create2");
    gd_callable_custom_create = (GDExtensionInterfaceCallableCustomCreate)p_get_proc_address("callable_custom_create");
    gd_variant_new_nil = (GDExtensionInterfaceVariantNewNil)p_get_proc_address("variant_new_nil");
    gd_placeholder_script_instance_create = (GDExtensionInterfacePlaceHolderScriptInstanceCreate)p_get_proc_address("placeholder_script_instance_create");

    // --- Segment 6: Variant Destructors and Utility Builtins ---
    // Resolve type-specific destructors and utility built-in functions (print, printerr, print_verbose)
    // using Godot's 64-bit utility function hashes.
    if (gd_variant_get_ptr_destructor) {
        gd_string_destroy = gd_variant_get_ptr_destructor(GDEXTENSION_VARIANT_TYPE_STRING);
        gd_string_name_destroy = gd_variant_get_ptr_destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME);
        gd_callable_destroy = gd_variant_get_ptr_destructor(GDEXTENSION_VARIANT_TYPE_CALLABLE);
    }

    if (gd_variant_get_ptr_utility_function && gd_string_name_new_with_utf8_chars) {
        void *sn_print = make_string_name("print");
        gd_util_print = gd_variant_get_ptr_utility_function(sn_print, 2648703342ULL);
        free_string_name(sn_print);

        void *sn_printerr = make_string_name("printerr");
        gd_util_printerr = gd_variant_get_ptr_utility_function(sn_printerr, 2648703342ULL);
        free_string_name(sn_printerr);

        void *sn_print_verbose = make_string_name("print_verbose");
        gd_util_print_verbose = gd_variant_get_ptr_utility_function(sn_print_verbose, 2648703342ULL);
        free_string_name(sn_print_verbose);
    }

    if (gd_get_variant_from_type_constructor) {
        gd_variant_from_string = gd_get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_STRING);
    }

    // --- Segment 7: Return Initialization Structure ---
    // Populate the output struct with our lifecycle entry points, setting minimum level to SCENE.
    r_initialization->initialize = initialize_crystal_module;
    r_initialization->deinitialize = deinitialize_crystal_module;
    r_initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
    r_initialization->userdata = p_library;

    return 1;
}
