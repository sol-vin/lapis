#pragma once

#include "common.hpp"
#include "gdextension_api.hpp"
#include "bridge_types.hpp"
#include "editor_doc.hpp"
#include "dispatch_signals.hpp"
#include "extension_instance.hpp"
#include "classdb_registry.hpp"

/**
 * ==============================================================================
 * LibGodot - Master BridgeAPI Table Exposed to Crystal & Exported C-ABI Functions
 * ==============================================================================
 *
 * Architecture & ABI Invariant:
 * ----------------------------
 * `g_bridge_api` is the primary static dispatch table shared between the native C++
 * GDExtension loader bridge (`crystal_bridge.dll` / `.so`) and the dynamically compiled
 * Crystal game library (`game.dll` / `.so`).
 *
 * When `load_crystal_game_library` initializes the game library, it passes `&g_bridge_api`
 * to `crystal_godot_init`. The order, alignment, and function signature of every entry
 * in `g_bridge_api` MUST match `struct BridgeAPI` in `src/libgodot/c_api.cr` exactly.
 */

inline int bridge_is_verbose() {
    return is_bridge_verbose() ? 1 : 0;
}

/**
 * Master GDExtension bridge function pointer dispatch table.
 * Indexed 1:1 by Crystal's `LibGodot::BridgeAPI` struct.
 */
static BridgeAPI g_bridge_api = {
    bridge_register_class,
    bridge_get_method_bind,
    bridge_method_bind_ptrcall,
    bridge_method_bind_call,
    bridge_load_editor_help_xml,
    bridge_get_singleton,
    make_string_name,
    free_string_name,
    make_string,
    free_string,
    make_nodepath,
    free_nodepath,
    bridge_type_from_variant,
    bridge_variant_from_type,
    godot_log_print,
    godot_log_error,
    godot_log_warning,
    bridge_object_emit_signal,
    bridge_object_call_deferred,
    bridge_object_call,
    bridge_node_find_child,
    bridge_node_get_node,
    bridge_range_set_value,
    bridge_node_rpc_config,
    bridge_resource_loader_load,
    bridge_packed_scene_instantiate,
    bridge_node_get_name,
    bridge_classdb_construct_object,
    bridge_object_call_ret_object,
    bridge_object_call_ret_int,
    bridge_object_call_ret_float,
    bridge_object_call_ret_bool,
    bridge_object_call_ret_string,
    bridge_object_destroy,
    bridge_object_get_instance_id,
    bridge_object_get_instance_from_id,
    bridge_is_instance_valid,
    bridge_ret_string,
    bridge_ret_string_name,
    bridge_ret_packed_string_array,
    bridge_ret_dictionary_empty,
    bridge_ret_array_empty,
    bridge_ret_object,
    bridge_ret_ref,
    bridge_ret_variant_object,
    bridge_ret_variant_nil,
    bridge_highlighter_add_span,
    bridge_arg_to_string,
    bridge_arg_to_string_name,
    bridge_ret_dictionary_validate,
    bridge_ret_dictionary_complete_code,
    bridge_ret_dictionary_lookup_code,
    bridge_ret_dictionary_complete_code_ex,
    bridge_ret_dictionary_lookup_code_ex,
    bridge_ret_dictionary_global_class,
    bridge_placeholder_script_instance_create,
    bridge_text_edit_get_line,
    bridge_object_connect_signal,
    bridge_object_disconnect_signal,
    bridge_register_signal_callback,
    bridge_register_deinit_callback,
    bridge_is_loader_registered,
    bridge_set_loader_registered,
    bridge_is_saver_registered,
    bridge_set_saver_registered,
    bridge_is_language_registered,
    bridge_set_language_registered,
    bridge_get_language_object,
    bridge_set_language_object,
    bridge_set_reloading,
    bridge_set_debugger_cleanup,
    bridge_trigger_debugger_cleanup,
    bridge_ref_get_object,
    bridge_script_get_source_code,
    bridge_resource_get_path,
    bridge_object_is_class,
    bridge_register_gc_functions,
    bridge_get_gc_signals,
    bridge_object_get_class_name,
    godot_log_verbose,
    bridge_is_verbose
};

// ==============================================================================
// Exported C API Functions
// ==============================================================================
// Dynamically exported symbols accessible to foreign language runtimes or standalone hosts.

extern "C" {
    /** Prints message to Godot editor console and stdout */
    GDE_EXPORT inline void crystal_godot_print(const char *msg) {
        godot_log_print(msg);
    }
    /** Prints error message to Godot editor console and stderr */
    GDE_EXPORT inline void crystal_godot_printerr(const char *msg) {
        godot_log_printerr(msg);
    }
    /** Reports a structured error to Godot debugger and stderr */
    GDE_EXPORT inline void crystal_godot_error(const char *msg, const char *func, const char *file, int line) {
        godot_log_error(msg, nullptr, func, file, line);
    }
    /** Reports a structured warning to Godot debugger and stderr */
    GDE_EXPORT inline void crystal_godot_warning(const char *msg, const char *func, const char *file, int line) {
        godot_log_warning(msg, nullptr, func, file, line);
    }
    /** Emits a Godot signal on a target object with typed arguments */
    GDE_EXPORT inline void crystal_object_emit_signal(GDExtensionObjectPtr instance, const char *signal_name, const BridgeSignalArg *args, int arg_count) {
        bridge_object_emit_signal(instance, signal_name, args, arg_count);
    }
    /** Finds a child node matching pattern */
    GDE_EXPORT inline GDExtensionObjectPtr crystal_node_find_child(GDExtensionObjectPtr node, const char *pattern, bool recursive, bool owned) {
        return bridge_node_find_child(node, pattern, recursive, owned);
    }
    /** Resolves a node by NodePath */
    GDE_EXPORT inline GDExtensionObjectPtr crystal_node_get_node(GDExtensionObjectPtr node, const char *path) {
        return bridge_node_get_node(node, path);
    }
    /** Sets numerical value on a Range node */
    GDE_EXPORT inline void crystal_range_set_value(GDExtensionObjectPtr range_obj, double value) {
        bridge_range_set_value(range_obj, value);
    }
    /** Connects a Godot signal to the Crystal CustomCallable bridge */
    GDE_EXPORT inline void crystal_object_connect_signal(GDExtensionObjectPtr instance, const char *signal_name, uint32_t flags) {
        bridge_object_connect_signal(instance, signal_name, flags);
    }
    /** Disconnects a Godot signal from the Crystal CustomCallable bridge */
    GDE_EXPORT inline void crystal_object_disconnect_signal(GDExtensionObjectPtr instance, const char *signal_name) {
        bridge_object_disconnect_signal(instance, signal_name);
    }
    /** Registers a Crystal signal callback to receive dispatched signals */
    GDE_EXPORT inline void crystal_register_signal_callback(CrystalSignalCallbackFn fn) {
        bridge_register_signal_callback(fn);
    }
    /** Returns pointer to the master BridgeAPI table for Crystal FFI bootstrapping */
    GDE_EXPORT inline const BridgeAPI* crystal_bridge_get_api() {
        return &g_bridge_api;
    }
    /** Sets hot reload status flag */
    GDE_EXPORT inline void crystal_bridge_set_reloading(int reloading) {
        bridge_set_reloading(reloading);
    }
}
