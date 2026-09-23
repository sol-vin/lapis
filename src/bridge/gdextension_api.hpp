#pragma once

#include "common.hpp"

/**
 * ==============================================================================
 * LibGodot - Cached GDExtension Interface Function Pointers & Diagnostic Logging
 * ==============================================================================
 */

// Master interface symbol resolver supplied by Godot
static GDExtensionInterfaceGetProcAddress gd_get_proc_address = nullptr;

// Core String / StringName / Variant Constructors & Destructors
static GDExtensionInterfaceStringNameNewWithUtf8Chars gd_string_name_new_with_utf8_chars = nullptr;
static GDExtensionInterfaceStringNewWithUtf8Chars gd_string_new_with_utf8_chars = nullptr;
static GDExtensionInterfaceVariantDestroy gd_variant_destroy = nullptr;
static GDExtensionInterfaceClassdbConstructObject gd_classdb_construct_object = nullptr;
static GDExtensionInterfaceObjectDestroy gd_object_destroy = nullptr;
static GDExtensionInterfaceRefSetObject gd_ref_set_object = nullptr;
static GDExtensionInterfaceRefGetObject gd_ref_get_object = nullptr;
static GDExtensionInterfaceObjectGetInstanceId gd_object_get_instance_id = nullptr;
static GDExtensionInterfaceObjectSetInstance gd_object_set_instance = nullptr;
static GDExtensionInterfaceObjectGetClassName gd_object_get_class_name = nullptr;

// ClassDB Registration & Reflection
static GDExtensionInterfaceClassdbRegisterExtensionClass6 gd_classdb_register_extension_class6 = nullptr;
static GDExtensionInterfaceClassdbUnregisterExtensionClass gd_classdb_unregister_extension_class = nullptr;
static GDExtensionInterfaceClassdbRegisterExtensionClassProperty gd_classdb_register_extension_class_property = nullptr;
static GDExtensionInterfaceClassdbRegisterExtensionClassPropertyGroup gd_classdb_register_extension_class_property_group = nullptr;
static GDExtensionInterfaceClassdbRegisterExtensionClassPropertySubgroup gd_classdb_register_extension_class_property_subgroup = nullptr;
static GDExtensionInterfaceClassdbRegisterExtensionClassIntegerConstant gd_classdb_register_extension_class_integer_constant = nullptr;
static GDExtensionInterfaceClassdbRegisterExtensionClassSignal gd_classdb_register_extension_class_signal = nullptr;
static GDExtensionInterfaceClassdbRegisterExtensionClassMethod gd_classdb_register_extension_class_method = nullptr;
static GDExtensionInterfaceClassdbGetMethodBind gd_classdb_get_method_bind = nullptr;
static GDExtensionInterfaceObjectMethodBindPtrcall gd_object_method_bind_ptrcall = nullptr;
static GDExtensionInterfaceObjectMethodBindCall gd_object_method_bind_call = nullptr;
static GDExtensionsInterfaceEditorHelpLoadXmlFromUtf8Chars gd_editor_help_load_xml_from_utf8_chars = nullptr;
static GDExtensionInterfaceGlobalGetSingleton gd_global_get_singleton = nullptr;
static GDExtensionInterfaceGetVariantFromTypeConstructor gd_get_variant_from_type_constructor = nullptr;
static GDExtensionInterfaceGetVariantToTypeConstructor gd_get_variant_to_type_constructor = nullptr;
static GDExtensionInterfacePlaceHolderScriptInstanceCreate gd_placeholder_script_instance_create = nullptr;

// Engine Diagnostic & Error Logging Interfaces
static GDExtensionInterfacePrintError gd_print_error = nullptr;
static GDExtensionInterfacePrintErrorWithMessage gd_print_error_with_message = nullptr;
static GDExtensionInterfacePrintWarning gd_print_warning = nullptr;
static GDExtensionInterfacePrintWarningWithMessage gd_print_warning_with_message = nullptr;
static GDExtensionInterfaceVariantGetPtrUtilityFunction gd_variant_get_ptr_utility_function = nullptr;
static GDExtensionInterfaceVariantGetPtrConstructor gd_variant_get_ptr_constructor = nullptr;
static GDExtensionInterfaceVariantGetPtrDestructor gd_variant_get_ptr_destructor = nullptr;
static GDExtensionInterfaceVariantGetPtrBuiltinMethod gd_variant_get_ptr_builtin_method = nullptr;
static GDExtensionInterfaceVariantGetPtrKeyedSetter gd_variant_get_ptr_keyed_setter = nullptr;

// Utility and Constructor Function Pointers
static GDExtensionPtrConstructor gd_nodepath_from_string = nullptr;
static GDExtensionPtrDestructor gd_nodepath_destroy = nullptr;
static GDExtensionPtrConstructor gd_string_from_string_name = nullptr;
static GDExtensionPtrUtilityFunction gd_util_print = nullptr;
static GDExtensionPtrUtilityFunction gd_util_printerr = nullptr;
static GDExtensionPtrUtilityFunction gd_util_print_verbose = nullptr;
static GDExtensionVariantFromTypeConstructorFunc gd_variant_from_string = nullptr;
static GDExtensionPtrDestructor gd_string_destroy = nullptr;
static GDExtensionPtrDestructor gd_string_name_destroy = nullptr;
static GDExtensionInterfaceVariantGetType gd_variant_get_type = nullptr;
static GDExtensionInterfaceVariantGetObjectInstanceId gd_variant_get_object_instance_id = nullptr;
static GDExtensionInterfaceObjectGetInstanceFromId gd_object_get_instance_from_id = nullptr;
static GDExtensionInterfaceVariantStringify gd_variant_stringify = nullptr;
static GDExtensionInterfaceStringToUtf8Chars gd_string_to_utf8_chars = nullptr;
static GDExtensionInterfaceGetLibraryPath gd_get_library_path = nullptr;

typedef GDExtensionVariantGetInternalPtrFunc (*GDExtensionInterfaceVariantGetPtrInternalGetter)(GDExtensionVariantType p_type);
static GDExtensionVariantGetInternalPtrFunc gd_variant_get_internal_ptr_object = nullptr;

// Library handle passed to GDExtension at initialization, required for class registration
static GDExtensionClassLibraryPtr g_library = nullptr;
static GDExtensionInitializationLevel g_current_init_level = GDEXTENSION_INITIALIZATION_SCENE;

// Custom Callable and Signal Interfaces
static GDExtensionInterfaceCallableCustomCreate2 gd_callable_custom_create2 = nullptr;
static GDExtensionInterfaceCallableCustomCreate gd_callable_custom_create = nullptr;
static GDExtensionInterfaceVariantNewNil gd_variant_new_nil = nullptr;
static GDExtensionPtrDestructor gd_callable_destroy = nullptr;

// Cached MethodBind Pointers
static GDExtensionMethodBindPtr mb_object_connect = nullptr;
static GDExtensionMethodBindPtr mb_object_is_connected = nullptr;
static GDExtensionMethodBindPtr mb_object_disconnect = nullptr;
static GDExtensionMethodBindPtr mb_object_has_signal = nullptr;
static GDExtensionMethodBindPtr mb_set_physics_process = nullptr;
static GDExtensionMethodBindPtr mb_set_process = nullptr;
static GDExtensionVariantFromTypeConstructorFunc gd_variant_from_string_name = nullptr;
static GDExtensionMethodBindPtr mb_object_get_instance_id = nullptr;
static GDExtensionPtrUtilityFunction gd_util_is_instance_id_valid = nullptr;
static GDExtensionPtrUtilityFunction gd_util_instance_from_id = nullptr;
static GDExtensionMethodBindPtr mb_object_emit_signal = nullptr;
static GDExtensionMethodBindPtr mb_object_call_deferred = nullptr;
static GDExtensionMethodBindPtr mb_object_call = nullptr;
static GDExtensionMethodBindPtr mb_object_is_class = nullptr;
static GDExtensionMethodBindPtr mb_refcounted_reference = nullptr;
static GDExtensionMethodBindPtr mb_node_find_child = nullptr;
static GDExtensionMethodBindPtr mb_node_get_node = nullptr;
static GDExtensionMethodBindPtr mb_range_set_value = nullptr;
static GDExtensionMethodBindPtr mb_node_rpc_config = nullptr;
static GDExtensionMethodBindPtr mb_res_loader_load = nullptr;
static GDExtensionMethodBindPtr mb_packed_scene_instantiate = nullptr;
static GDExtensionMethodBindPtr mb_node_get_name = nullptr;
static GDExtensionPtrConstructor gd_packed_string_array_constructor = nullptr;
static GDExtensionPtrBuiltInMethod gd_packed_string_array_append = nullptr;
static GDExtensionPtrConstructor gd_dictionary_constructor = nullptr;
static GDExtensionPtrConstructor gd_array_constructor = nullptr;
static GDExtensionPtrConstructor gd_variant_nil_constructor = nullptr;
static GDExtensionPtrKeyedSetter gd_dict_keyed_setter = nullptr;
static GDExtensionMethodBindPtr mb_text_edit_get_line = nullptr;

// ==============================================================================
// Godot Engine Diagnostic & Console Logging Helpers
// ==============================================================================

/**
 * Checks whether bridge debug/verbose logging is enabled via environment variables.
 * Caches the result in a static integer for zero-cost subsequent checks.
 *
 * @return True if LIBGODOT_VERBOSE=1 or GODOT_VERBOSE=1; false otherwise.
 */
inline bool is_bridge_verbose() {
    static int cached = -1;
    if (cached == -1) {
        const char *v1 = getenv("LIBGODOT_VERBOSE");
        const char *v2 = getenv("GODOT_VERBOSE");
        cached = ((v1 && (strcmp(v1, "1") == 0 || strcmp(v1, "true") == 0)) ||
                  (v2 && (strcmp(v2, "1") == 0 || strcmp(v2, "true") == 0))) ? 1 : 0;
    }
    return cached == 1;
}

inline void godot_log_print(const char *msg);

/**
 * Emits a diagnostic message to Godot's verbose log stream or standard output.
 * If verbose logging is enabled, routes to `godot_log_print`; otherwise routes to `gd_util_print_verbose`.
 *
 * @param msg Null-terminated string message.
 */
inline void godot_log_verbose(const char *msg) {
    if (!msg) return;

    if (is_bridge_verbose()) {
        godot_log_print(msg);
    } else if (gd_util_print_verbose && gd_variant_from_string && gd_string_new_with_utf8_chars && gd_variant_destroy) {
        alignas(void*) char gd_str[sizeof(void*)];
        gd_string_new_with_utf8_chars(gd_str, msg);
        alignas(void*) char var_buf[24];
        gd_variant_from_string(var_buf, gd_str);
        const void *args[1] = { var_buf };
        gd_util_print_verbose(nullptr, args, 1);
        gd_variant_destroy(var_buf);
        if (gd_string_destroy) {
            gd_string_destroy(gd_str);
        }
    }
}

/**
 * Emits an informational message to Godot's editor output console and standard out.
 *
 * @param msg Null-terminated string message.
 *
 * Segments:
 * - Segment 1: Parameter validation.
 * - Segment 2: Native Godot engine console dispatch via `gd_util_print`.
 * - Segment 3: Fallback standard stdout printing.
 */
inline void godot_log_print(const char *msg) {
    // --- Segment 1: Validation ---
    if (!msg) return;

    // --- Segment 2: Native Engine Console Dispatch ---
    if (gd_util_print && gd_variant_from_string && gd_string_new_with_utf8_chars && gd_variant_destroy) {
        alignas(void*) char gd_str[sizeof(void*)];
        gd_string_new_with_utf8_chars(gd_str, msg);
        alignas(void*) char var_buf[24];
        gd_variant_from_string(var_buf, gd_str);
        const void *args[1] = { var_buf };
        gd_util_print(nullptr, args, 1);
        gd_variant_destroy(var_buf);
        if (gd_string_destroy) {
            gd_string_destroy(gd_str);
        }
    } else {
        // --- Segment 3: Fallback stdout ---
        printf("%s\n", msg);
        fflush(stdout);
    }
}

/**
 * Emits an error string to Godot's editor error console and standard error stream.
 *
 * @param msg Null-terminated error message.
 *
 * Segments:
 * - Segment 1: Parameter validation.
 * - Segment 2: Native Godot engine console dispatch via `gd_util_printerr`.
 * - Segment 3: Fallback stderr printing.
 */
inline void godot_log_printerr(const char *msg) {
    // --- Segment 1: Validation ---
    if (!msg) return;

    // --- Segment 2: Native Engine Error Console Dispatch ---
    if (gd_util_printerr && gd_variant_from_string && gd_string_new_with_utf8_chars && gd_variant_destroy) {
        alignas(void*) char gd_str[sizeof(void*)];
        gd_string_new_with_utf8_chars(gd_str, msg);
        alignas(void*) char var_buf[24];
        gd_variant_from_string(var_buf, gd_str);
        const void *args[1] = { var_buf };
        gd_util_printerr(nullptr, args, 1);
        gd_variant_destroy(var_buf);
        if (gd_string_destroy) {
            gd_string_destroy(gd_str);
        }
    } else {
        // --- Segment 3: Fallback stderr ---
        fprintf(stderr, "%s\n", msg);
        fflush(stderr);
    }
}

/**
 * Logs a structured error with source file, function name, line number, and description
 * to both stderr and Godot's native debugger / crash reporting panel.
 *
 * @param desc High-level error description.
 * @param msg Detailed error message.
 * @param func Function name where the error occurred.
 * @param file Source file where the error occurred.
 * @param line Line number where the error occurred.
 */
inline void godot_log_error(const char *desc, const char *msg, const char *func, const char *file, int line) {
    const char *safe_func = (func && func[0] != '\0') ? func : "libgodot";
    const char *safe_file = (file && file[0] != '\0') ? file : "libgodot.cr";
    const char *safe_desc = desc ? desc : "Unknown error";

    fprintf(stderr, "[ERROR] %s: %s (%s:%d in %s)\n", safe_desc, msg ? msg : "", safe_file, line, safe_func);
    fflush(stderr);

    if (gd_print_error_with_message && msg && msg[0] != '\0') {
        gd_print_error_with_message(safe_desc, msg, safe_func, safe_file, line, 1);
    } else if (gd_print_error) {
        gd_print_error(safe_desc, safe_func, safe_file, line, 1);
    }
}

/**
 * Logs a structured warning with source file, function name, line number, and description
 * to both stderr and Godot's native debugger warning panel.
 *
 * @param desc High-level warning description.
 * @param msg Detailed warning message.
 * @param func Function name where the warning occurred.
 * @param file Source file where the warning occurred.
 * @param line Line number where the warning occurred.
 */
inline void godot_log_warning(const char *desc, const char *msg, const char *func, const char *file, int line) {
    const char *safe_func = (func && func[0] != '\0') ? func : "libgodot";
    const char *safe_file = (file && file[0] != '\0') ? file : "libgodot.cr";
    const char *safe_desc = desc ? desc : "Unknown warning";

    fprintf(stderr, "[WARNING] %s: %s (%s:%d in %s)\n", safe_desc, msg ? msg : "", safe_file, line, safe_func);
    fflush(stderr);

    if (gd_print_warning_with_message && msg && msg[0] != '\0') {
        gd_print_warning_with_message(safe_desc, msg, safe_func, safe_file, line, 1);
    } else if (gd_print_warning) {
        gd_print_warning(safe_desc, safe_func, safe_file, line, 1);
    }
}
