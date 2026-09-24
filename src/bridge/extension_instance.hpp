#pragma once

#include "common.hpp"
#include "gdextension_api.hpp"
#include "bridge_types.hpp"
#include "gc_support.hpp"
#include "dispatch_signals.hpp"

/**
 * ==============================================================================
 * LibGodot - Extension Instance Lifecycle, Property Access & Virtual Dispatch
 * ==============================================================================
 */

/**
 * Queries whether the Godot Editor is currently running (Engine.is_editor_hint()).
 * Caches the result to prevent repeated singleton and method lookups on every frame.
 */
inline bool is_editor_active() {
    static int s_cached = -1;
    if (s_cached != -1) return s_cached == 1;

    if (!gd_global_get_singleton || !gd_classdb_get_method_bind || !gd_object_method_bind_ptrcall) return false;
    void *sn_engine = make_string_name("Engine");
    GDExtensionObjectPtr engine = gd_global_get_singleton(sn_engine);
    free_string_name(sn_engine);
    if (!engine) return false;
    GDExtensionMethodBindPtr mb = bridge_get_method_bind("Engine", "is_editor_hint", 36873697);
    if (!mb) return false;
    uint8_t ret_bool = 0;
    gd_object_method_bind_ptrcall(mb, engine, nullptr, &ret_bool);
    if (ret_bool != 0) {
        s_cached = 1;
        return true;
    }
    if (g_current_init_level >= GDEXTENSION_INITIALIZATION_EDITOR) {
        s_cached = 0;
    }
    return false;
}

inline bool is_headless_display() {
    static int s_cached = -1;
    if (s_cached != -1) return s_cached == 1;
    if (!gd_global_get_singleton || !gd_classdb_get_method_bind || !gd_object_method_bind_ptrcall) return false;
    void *sn_ds = make_string_name("DisplayServer");
    GDExtensionObjectPtr ds = gd_global_get_singleton(sn_ds);
    free_string_name(sn_ds);
    if (!ds) return false;
    GDExtensionMethodBindPtr mb = bridge_get_method_bind("DisplayServer", "get_name", 201670096);
    if (!mb) return false;
    alignas(void*) char ret_str[8] = {0};
    gd_object_method_bind_ptrcall(mb, ds, nullptr, ret_str);
    char name_buf[64] = {0};
    if (gd_string_to_utf8_chars) {
        gd_string_to_utf8_chars(ret_str, name_buf, sizeof(name_buf) - 1);
    }
    if (gd_string_destroy) gd_string_destroy(ret_str);
    s_cached = (strcmp(name_buf, "headless") == 0) ? 1 : 0;
    return s_cached == 1;
}

inline bool is_editor_class_name(const char *name) {
    if (!name) return false;
    return (strncmp(name, "Editor", 6) == 0);
}

inline bool is_tool_desc(const CrystalClassDesc *desc) {
    if (!desc) return false;
    if (desc->is_tool) return true;
    const CrystalClassDesc *curr = desc;
    while (curr) {
        if (curr->is_tool || is_editor_class_name(curr->parent_name)) return true;
        curr = curr->parent_desc;
    }
    return false;
}

inline bool is_refcounted_desc(const CrystalClassDesc *desc) {
    if (!desc) return false;
    const CrystalClassDesc *curr = desc;
    while (curr) {
        if (curr->parent_name) {
            if (strcmp(curr->parent_name, "RefCounted") == 0 ||
                strcmp(curr->parent_name, "Resource") == 0 ||
                strcmp(curr->parent_name, "ResourceFormatLoader") == 0 ||
                strcmp(curr->parent_name, "ResourceFormatSaver") == 0 ||
                strcmp(curr->parent_name, "EditorSyntaxHighlighter") == 0 ||
                strcmp(curr->parent_name, "EditorDebuggerPlugin") == 0) {
                return true;
            }
        }
        curr = curr->parent_desc;
    }
    return false;
}

static std::unordered_map<void*, GenericExtensionInstance*> s_object_to_extension_instance;
static std::mutex s_object_to_ext_mutex;

static std::unordered_map<void*, std::string> s_script_source_code;
static std::unordered_map<void*, std::string> s_script_paths;
static std::mutex s_script_source_mutex;

inline void register_extension_instance(void *obj, GenericExtensionInstance *inst) {
    if (!obj || !inst) return;
    std::lock_guard<std::mutex> lock(s_object_to_ext_mutex);
    s_object_to_extension_instance[obj] = inst;
}

inline void unregister_extension_instance(void *obj) {
    if (!obj) return;
    {
        std::lock_guard<std::mutex> lock(s_object_to_ext_mutex);
        s_object_to_extension_instance.erase(obj);
    }
    {
        std::lock_guard<std::mutex> lock(s_script_source_mutex);
        s_script_source_code.erase(obj);
        s_script_paths.erase(obj);
    }
}

inline GenericExtensionInstance* find_extension_instance(void *obj) {
    if (!obj) return nullptr;
    std::lock_guard<std::mutex> lock(s_object_to_ext_mutex);
    auto it = s_object_to_extension_instance.find(obj);
    return it != s_object_to_extension_instance.end() ? it->second : nullptr;
}

/**
 * Instantiates a new Godot Object for a registered Crystal class.
 *
 * @param p_class_userdata Pointer to the CrystalClassDesc descriptor registered in ClassDB.
 * @param p_notify_postinitialize Godot post-initialize notification flag.
 * @return Raw GDExtensionObjectPtr of the newly allocated Godot C++ object.
 *
 * Internal Execution Segments:
 * - Segment 1: GC Thread Registration and Input Validation.
 * - Segment 2: Native Godot Parent Class Traversal (walking inheritance DAG to find C++ base).
 * - Segment 3: Native Engine Allocation via `gd_classdb_construct_object`.
 * - Segment 4: Bridge Wrapper Allocation and Crystal Instance Creation (`desc->create_instance`).
 * - Segment 5: Instance Association (`gd_object_set_instance`) & Global Map Registration.
 * - Segment 6: Automatic Physics and Idle Process Enabling based on class descriptor flags.
 */
inline GDExtensionObjectPtr generic_class_create(void *p_class_userdata, GDExtensionBool p_notify_postinitialize) {
    (void)p_notify_postinitialize;
    // --- Segment 1: GC Thread Registration & Validation ---
    ensure_gc_thread_registered();
    const CrystalClassDesc *desc = (const CrystalClassDesc*)p_class_userdata;
    if (!desc) return nullptr;

    // --- Segment 2: Native Godot Parent Resolution ---
    // A Crystal class can inherit from another Crystal class (e.g. Boss < Enemy < CharacterBody2D).
    // Walk up the parent_desc chain to find the root native Godot engine C++ class to instantiate.
    const CrystalClassDesc *root_desc = desc;
    int depth = 0;
    while (root_desc->parent_desc && depth++ < 32) {
        root_desc = root_desc->parent_desc;
    }
    const char *native_parent = root_desc->parent_name;
    if (!native_parent || native_parent[0] == '\0') {
        native_parent = "Object";
    }
    if (!desc->name || desc->name[0] == '\0') {
        godot_log_error("generic_class_create called with null/empty desc->name", nullptr, "generic_class_create", __FILE__, __LINE__);
        return nullptr;
    }

    // --- Segment 3: Native Engine Object Allocation ---
    void *parent_sn = make_string_name(native_parent);
    void *class_sn = make_string_name(desc->name);

    GDExtensionObjectPtr obj = gd_classdb_construct_object(parent_sn);
    if (!obj) {
        char err[128];
        snprintf(err, sizeof(err), "Failed to construct base object for %s (%s)", desc->name, native_parent);
        godot_log_error(err, nullptr, "generic_class_create", __FILE__, __LINE__);
        free_string_name(parent_sn); free_string_name(class_sn);
        return nullptr;
    }

    // --- Segment 4: Wrapper Allocation & Crystal Host Instance Creation ---
    // Allocate the GenericExtensionInstance bridge tracking struct, then invoke Crystal's
    // `create_instance` callback so Crystal allocates its GC wrapper and captures the Object pointer.
    GenericExtensionInstance *inst = new GenericExtensionInstance();
    inst->godot_object = obj;
    inst->desc = desc;
    if (desc->create_instance) {
        inst->crystal_instance = desc->create_instance(desc, obj);
    } else {
        inst->crystal_instance = nullptr;
    }

    // --- Segment 5: Instance Association & Global Map Registration ---
    // Bind the GenericExtensionInstance to Godot's C++ object via gd_object_set_instance,
    // and record the mapping in s_object_to_extension_instance for fast O(1) thread-safe lookups.
    gd_object_set_instance(obj, class_sn, (GDExtensionClassInstancePtr)inst);
    register_extension_instance(obj, inst);

    if (is_bridge_verbose()) {
        char buf[256];
        snprintf(buf, sizeof(buf), "  [GenericExtensionInstance] Created %s (godot=%p, crystal=%p)", desc->name, (void*)obj, inst->crystal_instance);
        godot_log_verbose(buf);
    }

    // --- Segment 6: Automatic Physics and Idle Process Enabling ---
    // If the class defines _physics_process or _process, auto-enable processing via ptrcall.
    // If running inside the Godot Editor, suppress processing unless the class is marked @[Tool].
    bool allow_processing = !is_editor_active() || is_tool_desc(desc);

    if (desc->has_physics_process && mb_set_physics_process && allow_processing) {
        uint8_t enabled = 1;
        const void *args[1] = { &enabled };
        gd_object_method_bind_ptrcall(mb_set_physics_process, obj, args, nullptr);
    }
    if (desc->has_process && mb_set_process && allow_processing) {
        uint8_t enabled = 1;
        const void *args[1] = { &enabled };
        gd_object_method_bind_ptrcall(mb_set_process, obj, args, nullptr);
    }

    free_string_name(parent_sn);
    free_string_name(class_sn);
    return obj;
}

/**
 * Recreates a Crystal extension instance wrapper on an existing native Godot Object.
 * Used during scene deserialization, editor reload, or hot-reload recreation.
 *
 * @param p_class_userdata Pointer to the CrystalClassDesc descriptor.
 * @param p_object Pointer to the already-allocated native Godot Object.
 * @return GDExtensionClassInstancePtr tracking pointer to the new GenericExtensionInstance.
 */
inline GDExtensionClassInstancePtr generic_class_recreate(void *p_class_userdata, GDExtensionObjectPtr p_object) {
    // --- Segment 1: Thread Registration & Instance Allocation ---
    ensure_gc_thread_registered();
    const CrystalClassDesc *desc = (const CrystalClassDesc*)p_class_userdata;
    if (!desc) return nullptr;

    GenericExtensionInstance *inst = new GenericExtensionInstance();
    inst->godot_object = p_object;
    inst->desc = desc;

    // --- Segment 2: Crystal Host Reconnection ---
    if (desc->create_instance) {
        inst->crystal_instance = desc->create_instance(desc, p_object);
    } else {
        inst->crystal_instance = nullptr;
    }

    register_extension_instance(p_object, inst);

    // --- Segment 3: Process Flag Reconfiguration ---
    bool allow_processing = !is_editor_active() || is_tool_desc(desc);

    if (desc->has_physics_process && mb_set_physics_process && allow_processing) {
        uint8_t enabled = 1;
        const void *args[1] = { &enabled };
        gd_object_method_bind_ptrcall(mb_set_physics_process, p_object, args, nullptr);
    }
    if (desc->has_process && mb_set_process && allow_processing) {
        uint8_t enabled = 1;
        const void *args[1] = { &enabled };
        gd_object_method_bind_ptrcall(mb_set_process, p_object, args, nullptr);
    }

    return (GDExtensionClassInstancePtr)inst;
}

/**
 * Frees the Crystal extension instance wrapper and invokes Crystal's free_instance callback.
 * Called by Godot when the underlying C++ Object is destroyed.
 *
 * @param p_class_userdata Pointer to the CrystalClassDesc descriptor.
 * @param p_instance Pointer to the GenericExtensionInstance being freed.
 *
 * Segments:
 * - Segment 1: Thread Registration and Logging.
 * - Segment 2: Unregistering from the global instance tracking map.
 * - Segment 3: Invoking Crystal's `free_instance` callback and deleting the C++ wrapper.
 */
inline void generic_class_free(void *p_class_userdata, GDExtensionClassInstancePtr p_instance) {
    (void)p_class_userdata;
    // --- Segment 1: Thread Registration & Diagnostics ---
    ensure_gc_thread_registered();
    GenericExtensionInstance *inst = (GenericExtensionInstance*)p_instance;
    if (inst) {
        if (is_bridge_verbose() && inst->desc) {
            char buf[256];
            snprintf(buf, sizeof(buf), "  [GenericExtensionInstance] Freed %s (godot=%p, crystal=%p)", inst->desc->name, (void*)inst->godot_object, inst->crystal_instance);
            godot_log_verbose(buf);
        }
        // --- Segment 2: Unregister from Global Tracking Map ---
        if (inst->godot_object) {
            unregister_extension_instance(inst->godot_object);
        }
        // --- Segment 3: Invoke Crystal Teardown & Delete Wrapper ---
        if (inst->desc && inst->desc->free_instance && inst->crystal_instance) {
            inst->desc->free_instance(inst->crystal_instance);
        }
        delete inst;
    }
}

/** Matches a virtual method name with or without leading underscore */
inline bool match_virtual_method(const char *name, const char *target) {
    if (!name || !target) return false;
    if (strcmp(name, target) == 0) return true;
    if (target[0] == '_' && strcmp(name, target + 1) == 0) return true;
    if (name[0] == '_' && strcmp(name + 1, target) == 0) return true;
    return false;
}

/** Unified helper for dispatching lifecycle virtual calls into Crystal */
inline void generic_dispatch_lifecycle(GenericExtensionInstance *inst, const char *method_name, double delta = 0.0) {
    if (!inst || !inst->desc || !inst->desc->call_virtual || !inst->crystal_instance) return;
    if (is_editor_active() && !is_tool_desc(inst->desc)) return;
    inst->desc->call_virtual(inst->crystal_instance, method_name, delta);
}

/** Dispatches Godot's _physics_process(delta) virtual callback into Crystal */
inline void generic_virtual_physics_process(GDExtensionClassInstancePtr p_instance, const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_ret) {
    (void)r_ret;
    ensure_gc_thread_registered();
    double delta = (p_args && p_args[0]) ? *(const double*)p_args[0] : 0.016666666666666666;
    generic_dispatch_lifecycle((GenericExtensionInstance*)p_instance, "_physics_process", delta);
}

/** Dispatches Godot's _process(delta) virtual callback into Crystal */
inline void generic_virtual_process(GDExtensionClassInstancePtr p_instance, const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_ret) {
    (void)r_ret;
    ensure_gc_thread_registered();
    double delta = (p_args && p_args[0]) ? *(const double*)p_args[0] : 0.016666666666666666;
    generic_dispatch_lifecycle((GenericExtensionInstance*)p_instance, "_process", delta);
}

/** Dispatches Godot's _ready() virtual callback into Crystal */
inline void generic_virtual_ready(GDExtensionClassInstancePtr p_instance, const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_ret) {
    (void)p_args; (void)r_ret;
    ensure_gc_thread_registered();
    generic_dispatch_lifecycle((GenericExtensionInstance*)p_instance, "_ready", 0.0);
}

/** Dispatches Godot's _enter_tree() virtual callback into Crystal */
inline void generic_virtual_enter_tree(GDExtensionClassInstancePtr p_instance, const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_ret) {
    (void)p_args; (void)r_ret;
    ensure_gc_thread_registered();
    generic_dispatch_lifecycle((GenericExtensionInstance*)p_instance, "_enter_tree", 0.0);
}

/** Dispatches Godot's _exit_tree() virtual callback into Crystal */
inline void generic_virtual_exit_tree(GDExtensionClassInstancePtr p_instance, const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_ret) {
    (void)p_args; (void)r_ret;
    ensure_gc_thread_registered();
    generic_dispatch_lifecycle((GenericExtensionInstance*)p_instance, "_exit_tree", 0.0);
}

/** Dispatches Godot's _build() virtual callback for EditorPlugin into Crystal */
inline void generic_virtual_build(GDExtensionClassInstancePtr p_instance, const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_ret) {
    (void)p_args;
    ensure_gc_thread_registered();
    GenericExtensionInstance *inst = (GenericExtensionInstance*)p_instance;
    if (!inst || !inst->desc || !inst->crystal_instance) return;
    if (r_ret) *(uint8_t*)r_ret = 1;
    if (inst->desc->call_virtual) inst->desc->call_virtual(inst->crystal_instance, "_build", 0.0);
}

/**
 * Returns a static C function pointer for core lifecycle virtual methods.
 * Called by Godot during method table initialization for registered classes.
 *
 * @param p_class_userdata Pointer to CrystalClassDesc descriptor.
 * @param p_name StringName of the virtual method queried by Godot.
 * @return GDExtensionClassCallVirtual function pointer or nullptr if not handled statically.
 *
 * Segments:
 * - Segment 1: Descriptor validation and method name string conversion.
 * - Segment 2: Fixed lifecycle method mapping (_ready, _process, _physics_process, _enter_tree, _exit_tree, _build).
 */
inline GDExtensionClassCallVirtual generic_class_get_virtual(void *p_class_userdata, GDExtensionConstStringNamePtr p_name) {
    // --- Segment 1: Descriptor Validation & String Conversion ---
    const CrystalClassDesc *desc = (const CrystalClassDesc*)p_class_userdata;
    if (!desc) return nullptr;

    char method_buf[64];
    if (!string_name_to_cstr(p_name, method_buf, sizeof(method_buf))) return nullptr;

    // --- Segment 2: Core Lifecycle Method Dispatch Pointer Matching ---
    if (desc->has_physics_process && strcmp(method_buf, "_physics_process") == 0) {
        return generic_virtual_physics_process;
    }
    if (desc->has_process && strcmp(method_buf, "_process") == 0) {
        return generic_virtual_process;
    }
    if (desc->has_ready && strcmp(method_buf, "_ready") == 0) {
        return generic_virtual_ready;
    }
    if (desc->has_enter_tree && strcmp(method_buf, "_enter_tree") == 0) {
        return generic_virtual_enter_tree;
    }
    if (desc->has_exit_tree && strcmp(method_buf, "_exit_tree") == 0) {
        return generic_virtual_exit_tree;
    }
    if (strcmp(method_buf, "_build") == 0) {
        return generic_virtual_build;
    }

    return nullptr;
}

static std::unordered_set<std::string> g_interned_virtual_methods;

/**
 * Interns a virtual method name string in a process-wide set to guarantee stable pointer lifetimes.
 * Pointers returned by this function remain valid for the lifetime of the process.
 */
inline const char* intern_virtual_method(const char *name) {
    if (!name) return nullptr;
    auto it = g_interned_virtual_methods.find(name);
    if (it != g_interned_virtual_methods.end()) {
        return it->c_str();
    }
    auto res = g_interned_virtual_methods.insert(name);
    return res.first->c_str();
}

/**
 * Resolves virtual call user data for Godot 4 virtual methods.
 * Returning a non-null pointer indicates the virtual method is implemented or overridden
 * by this Crystal class and should be dispatched to `generic_class_call_virtual_with_data`.
 *
 * @param p_class_userdata Pointer to the CrystalClassDesc descriptor.
 * @param p_name StringName of the virtual method.
 * @param p_hash Method hash (optional/ignored for GDExtension virtuals).
 * @return Stable pointer to the interned method name string if implemented, nullptr otherwise.
 *
 * Segments:
 * - Segment 1: Method name extraction from StringName.
 * - Segment 2: Standard lifecycle virtual method resolution (_ready, _process, _input, etc.).
 * - Segment 3: ScriptLanguageExtension and editor plugin class resolution (CrystalLanguage, CrystalScript, etc.).
 * - Segment 4: Dynamic virtual method query delegated to Crystal class descriptor (`has_virtual_method`).
 */
inline void* generic_class_get_virtual_call_data(void *p_class_userdata, GDExtensionConstStringNamePtr p_name, uint32_t p_hash) {
    (void)p_hash;
    // --- Segment 1: Descriptor Validation & String Conversion ---
    const CrystalClassDesc *desc = (const CrystalClassDesc*)p_class_userdata;
    if (!desc) return nullptr;

    char method_buf[128];
    if (!string_name_to_cstr(p_name, method_buf, sizeof(method_buf))) {
        godot_log_print("[CrystalBridge] generic_class_get_virtual_call_data: string_name_to_cstr FAILED");
        return nullptr;
    }

    // --- Segment 2: Built-in Engine Lifecycle Methods ---
    if (match_virtual_method(method_buf, "_ready")) {
        return desc->has_ready ? (void*)intern_virtual_method(method_buf) : nullptr;
    }
    if (match_virtual_method(method_buf, "_process")) {
        return desc->has_process ? (void*)intern_virtual_method(method_buf) : nullptr;
    }
    if (match_virtual_method(method_buf, "_physics_process")) {
        return desc->has_physics_process ? (void*)intern_virtual_method(method_buf) : nullptr;
    }
    if (match_virtual_method(method_buf, "_enter_tree")) {
        return desc->has_enter_tree ? (void*)intern_virtual_method(method_buf) : nullptr;
    }
    if (match_virtual_method(method_buf, "_exit_tree")) {
        return desc->has_exit_tree ? (void*)intern_virtual_method(method_buf) : nullptr;
    }
    if (match_virtual_method(method_buf, "_input")) {
        return desc->has_input ? (void*)intern_virtual_method(method_buf) : nullptr;
    }
    if (match_virtual_method(method_buf, "_unhandled_input")) {
        return desc->has_unhandled_input ? (void*)intern_virtual_method(method_buf) : nullptr;
    }
    if (match_virtual_method(method_buf, "_unhandled_key_input")) {
        return desc->has_unhandled_key_input ? (void*)intern_virtual_method(method_buf) : nullptr;
    }
    if (match_virtual_method(method_buf, "_shortcut_input")) {
        return desc->has_shortcut_input ? (void*)intern_virtual_method(method_buf) : nullptr;
    }
    if (match_virtual_method(method_buf, "_gui_input")) {
        return desc->has_gui_input ? (void*)intern_virtual_method(method_buf) : nullptr;
    }
    if (match_virtual_method(method_buf, "_build")) {
        return (void*)intern_virtual_method(method_buf);
    }

    // --- Segment 3: First-Class ScriptLanguageExtension and Plugin Resolution ---
    // Godot 4 requires ScriptLanguageExtension and related types to override dozens of engine virtuals.
    // Rather than dispatching dynamically across the C ABI for every probe, fast-resolve them directly.
    if (desc->name) {
        const char *norm_name = (method_buf[0] == '_') ? method_buf : nullptr;
        char prefixed[130];
        if (!norm_name) {
            prefixed[0] = '_';
            strncpy(prefixed + 1, method_buf, sizeof(prefixed) - 2);
            prefixed[sizeof(prefixed) - 1] = '\0';
            norm_name = prefixed;
        }

        if (strcmp(desc->name, "CrystalLanguage") == 0) {
            // Note: _init, _finish, _thread_enter, _thread_exit, and _frame are required by Godot's
            // ScriptLanguageExtension base class. They are intercepted at the very top of
            // generic_class_call_virtual_with_data to return immediately without registering
            // terminating threads in Boehm GC or invoking Crystal code on foreign threads.
            if (strcmp(norm_name, "_init") == 0 ||
                strcmp(norm_name, "_finish") == 0 ||
                strcmp(norm_name, "_thread_enter") == 0 ||
                strcmp(norm_name, "_thread_exit") == 0 ||
                strcmp(norm_name, "_frame") == 0 ||
                strcmp(norm_name, "_get_name") == 0 ||
                strcmp(norm_name, "_get_type") == 0 ||
                strcmp(norm_name, "_get_extension") == 0 ||
                strcmp(norm_name, "_get_recognized_extensions") == 0 ||
                strcmp(norm_name, "_get_reserved_words") == 0 ||
                strcmp(norm_name, "_is_control_flow_keyword") == 0 ||
                strcmp(norm_name, "_get_comment_delimiters") == 0 ||
                strcmp(norm_name, "_get_doc_comment_delimiters") == 0 ||
                strcmp(norm_name, "_get_string_delimiters") == 0 ||
                strcmp(norm_name, "_make_template") == 0 ||
                strcmp(norm_name, "_get_built_in_templates") == 0 ||
                strcmp(norm_name, "_is_using_templates") == 0 ||
                strcmp(norm_name, "_validate") == 0 ||
                strcmp(norm_name, "_validate_path") == 0 ||
                strcmp(norm_name, "_create_script") == 0 ||
                strcmp(norm_name, "_has_named_classes") == 0 ||
                strcmp(norm_name, "_supports_builtin_mode") == 0 ||
                strcmp(norm_name, "_supports_documentation") == 0 ||
                strcmp(norm_name, "_can_inherit_from_file") == 0 ||
                strcmp(norm_name, "_find_function") == 0 ||
                strcmp(norm_name, "_make_function") == 0 ||
                strcmp(norm_name, "_can_make_function") == 0 ||
                strcmp(norm_name, "_open_in_external_editor") == 0 ||
                strcmp(norm_name, "_overrides_external_editor") == 0 ||
                strcmp(norm_name, "_preferred_file_name_casing") == 0 ||
                strcmp(norm_name, "_complete_code") == 0 ||
                strcmp(norm_name, "_lookup_code") == 0 ||
                strcmp(norm_name, "_auto_indent_code") == 0 ||
                strcmp(norm_name, "_add_global_constant") == 0 ||
                strcmp(norm_name, "_add_named_global_constant") == 0 ||
                strcmp(norm_name, "_remove_named_global_constant") == 0 ||
                strcmp(norm_name, "_reload_all_scripts") == 0 ||
                strcmp(norm_name, "_reload_scripts") == 0 ||
                strcmp(norm_name, "_reload_tool_script") == 0 ||
                strcmp(norm_name, "_get_public_functions") == 0 ||
                strcmp(norm_name, "_get_public_constants") == 0 ||
                strcmp(norm_name, "_get_public_annotations") == 0 ||
                strcmp(norm_name, "_profiling_start") == 0 ||
                strcmp(norm_name, "_profiling_stop") == 0 ||
                strcmp(norm_name, "_profiling_set_save_native_calls") == 0 ||
                strcmp(norm_name, "_profiling_get_accumulated_data") == 0 ||
                strcmp(norm_name, "_profiling_get_frame_data") == 0 ||
                strcmp(norm_name, "_handles_global_class_type") == 0 ||
                strcmp(norm_name, "_get_global_class_name") == 0) {
                return (void*)intern_virtual_method(norm_name);
            }
        } else if (strcmp(desc->name, "ResourceFormatLoaderCrystal") == 0) {
            if (strcmp(norm_name, "_get_recognized_extensions") == 0 ||
                strcmp(norm_name, "_handles_type") == 0 ||
                strcmp(norm_name, "_get_resource_type") == 0 ||
                strcmp(norm_name, "_get_resource_script_class") == 0 ||
                strcmp(norm_name, "_load") == 0 ||
                strcmp(norm_name, "_recognize_path") == 0) {
                return (void*)intern_virtual_method(norm_name);
            }
        } else if (strcmp(desc->name, "ResourceFormatSaverCrystal") == 0) {
            if (strcmp(norm_name, "_get_recognized_extensions") == 0 ||
                strcmp(norm_name, "_recognize") == 0 ||
                strcmp(norm_name, "_recognize_path") == 0 ||
                strcmp(norm_name, "_save") == 0 ||
                strcmp(norm_name, "_set_uid") == 0) {
                return (void*)intern_virtual_method(norm_name);
            }
        } else if (strcmp(desc->name, "CrystalHighlighter") == 0) {
            if (strcmp(norm_name, "_get_name") == 0 ||
                strcmp(norm_name, "_get_supported_languages") == 0 ||
                strcmp(norm_name, "_create") == 0 ||
                strcmp(norm_name, "_get_line_syntax_highlighting") == 0 ||
                strcmp(norm_name, "_clear_highlighting_cache") == 0 ||
                strcmp(norm_name, "_update_cache") == 0) {
                return (void*)intern_virtual_method(norm_name);
            }
        } else if (strcmp(desc->name, "CrystalScript") == 0) {
            if (strcmp(norm_name, "_can_instantiate") == 0 ||
                strcmp(norm_name, "_inherits_script") == 0 ||
                strcmp(norm_name, "_get_base_script") == 0 ||
                strcmp(norm_name, "_get_global_name") == 0 ||
                strcmp(norm_name, "_get_instance_base_type") == 0 ||
                strcmp(norm_name, "_instance_create") == 0 ||
                strcmp(norm_name, "_placeholder_instance_create") == 0 ||
                strcmp(norm_name, "_placeholder_erased") == 0 ||
                strcmp(norm_name, "_instance_has") == 0 ||
                strcmp(norm_name, "_has_source_code") == 0 ||
                strcmp(norm_name, "_get_source_code") == 0 ||
                strcmp(norm_name, "_set_source_code") == 0 ||
                strcmp(norm_name, "_reload") == 0 ||
                strcmp(norm_name, "_editor_can_reload_from_file") == 0 ||
                strcmp(norm_name, "_has_method") == 0 ||
                strcmp(norm_name, "_has_static_method") == 0 ||
                strcmp(norm_name, "_get_script_method_argument_count") == 0 ||
                strcmp(norm_name, "_get_method_info") == 0 ||
                strcmp(norm_name, "_is_valid") == 0 ||
                strcmp(norm_name, "_is_tool") == 0 ||
                strcmp(norm_name, "_is_abstract") == 0 ||
                strcmp(norm_name, "_get_language") == 0 ||
                strcmp(norm_name, "_has_script_signal") == 0 ||
                strcmp(norm_name, "_get_script_signal_list") == 0 ||
                strcmp(norm_name, "_has_property_default_value") == 0 ||
                strcmp(norm_name, "_get_property_default_value") == 0 ||
                strcmp(norm_name, "_update_exports") == 0 ||
                strcmp(norm_name, "_get_script_method_list") == 0 ||
                strcmp(norm_name, "_get_script_property_list") == 0 ||
                strcmp(norm_name, "_get_member_line") == 0 ||
                strcmp(norm_name, "_get_constants") == 0 ||
                strcmp(norm_name, "_get_members") == 0 ||
                strcmp(norm_name, "_get_documentation") == 0 ||
                strcmp(norm_name, "_get_doc_class_name") == 0 ||
                strcmp(norm_name, "_get_class_icon_path") == 0 ||
                strcmp(norm_name, "_is_placeholder_fallback_enabled") == 0 ||
                strcmp(norm_name, "_get_rpc_config") == 0) {
                return (void*)intern_virtual_method(norm_name);
            }
        } else if (strcmp(desc->name, "CrystalIntegrationPlugin") == 0) {
            if (strcmp(norm_name, "_has_main_screen") == 0 ||
                strcmp(norm_name, "_get_plugin_name") == 0 ||
                strcmp(norm_name, "_get_plugin_icon") == 0 ||
                strcmp(norm_name, "_make_visible") == 0 ||
                strcmp(norm_name, "_build") == 0) {
                return (void*)intern_virtual_method(norm_name);
            }
        }
    }

    // --- Segment 4: Dynamic Virtual Method Query via Crystal Descriptor ---
    // If the method is not a known engine lifecycle or plugin method, query the Crystal class descriptor's
    // `has_virtual_method` callback. Check verbatim name, stripped underscore name, and prepended underscore name.
    if (desc->has_virtual_method) {
        if (desc->has_virtual_method(desc, method_buf)) {
            return (void*)intern_virtual_method(method_buf);
        }
        if (method_buf[0] == '_') {
            if (desc->has_virtual_method(desc, method_buf + 1)) {
                return (void*)intern_virtual_method(method_buf);
            }
        } else {
            char alt_buf[130];
            alt_buf[0] = '_';
            strncpy(alt_buf + 1, method_buf, sizeof(alt_buf) - 2);
            alt_buf[sizeof(alt_buf) - 1] = '\0';
            if (desc->has_virtual_method(desc, alt_buf)) {
                return (void*)intern_virtual_method(method_buf);
            }
        }
    }

    return nullptr;
}

/**
 * Dispatches generic Godot 4 virtual method calls with arguments and return buffers into Crystal.
 * Handles engine lifecycle callbacks, script language extensions, and user-defined virtual methods.
 *
 * @param p_instance Pointer to the GenericExtensionInstance.
 * @param p_name StringName of the virtual method (fallback if user data is null).
 * @param p_virtual_call_userdata Interned C string pointer identifying the virtual method.
 * @param p_args Array of pointers to input argument values (ptrcall ABI).
 * @param p_ret Pointer to caller-allocated return buffer (ptrcall ABI).
 *
 * Segments:
 * - Segment 1: Thread Lifecycle Guard & Fast-Path Rejection (rejecting _thread_enter, _thread_exit,
 *              _frame, _init, _finish BEFORE GC registration to prevent terminating-thread crashes).
 * - Segment 2: GC Thread Registration (ensure_gc_thread_registered) and verbose call tracing.
 * - Segment 3: Engine Lifecycle Virtuals (_ready, _process, _physics_process, _enter_tree,
 *              _exit_tree, input events, _build) with editor @[Tool] filtering.
 * - Segment 4: Script Language Extension Fast-Paths (CrystalLanguage, CrystalScript).
 * - Segment 5: Resource Loader & Saver Mechanics (ResourceFormatLoaderCrystal & ResourceFormatSaverCrystal
 *              with safe file IO and empty code truncation protection).
 * - Segment 6: Syntax Highlighter & Editor Plugin Hooks (CrystalHighlighter, CrystalIntegrationPlugin).
 * - Segment 7: Fallback Dynamic Dispatch into Crystal (inst->desc->call_virtual_with_data).
 */
inline void generic_class_call_virtual_with_data(
    GDExtensionClassInstancePtr p_instance,
    GDExtensionConstStringNamePtr p_name,
    void *p_virtual_call_userdata,
    const GDExtensionConstTypePtr *p_args,
    GDExtensionTypePtr r_ret
) {
    GenericExtensionInstance *inst = (GenericExtensionInstance*)p_instance;
    if (!inst || !inst->desc) return;

    const char *method_name = (const char*)p_virtual_call_userdata;
    char name_buf[128] = {0};
    if (!method_name && p_name) {
        string_name_to_cstr(p_name, name_buf, sizeof(name_buf));
        method_name = name_buf;
    }
    if (!method_name) return;

    // --- Segment 1: Thread Lifecycle Guard & Fast-Path Rejection ---
    // Fast-path: thread lifecycle hooks and no-op engine ticks must never touch Crystal runtime
    // or register foreign exiting threads with Boehm GC. Running GC registration or Crystal code
    // on a terminating thread (e.g. during EditorSettings saving or thread exit) causes C0000005 crashes.
    if (strcmp(method_name, "_thread_enter") == 0 || strcmp(method_name, "thread_enter") == 0 ||
        strcmp(method_name, "_thread_exit") == 0 || strcmp(method_name, "thread_exit") == 0 ||
        strcmp(method_name, "_frame") == 0 || strcmp(method_name, "frame") == 0 ||
        strcmp(method_name, "_init") == 0 || strcmp(method_name, "init") == 0 ||
        strcmp(method_name, "_finish") == 0 || strcmp(method_name, "finish") == 0) {
        return;
    }

    // --- Segment 2: Boehm GC Thread Registration & Diagnostics ---
    ensure_gc_thread_registered();

    if (is_bridge_verbose() && strcmp(method_name, "_process") != 0 && strcmp(method_name, "process") != 0 &&
        strcmp(method_name, "_physics_process") != 0 && strcmp(method_name, "physics_process") != 0) {
        char buf[256];
        snprintf(buf, sizeof(buf), "  [GenericExtensionInstance] CallVirtual %s::%s", inst->desc ? inst->desc->name : "Unknown", method_name);
        godot_log_verbose(buf);
    }

    // --- Segment 3: Engine Lifecycle Virtuals & Editor @[Tool] Filtering ---
    if (match_virtual_method(method_name, "_ready")) {
        if (is_editor_active() && !is_tool_desc(inst->desc)) return;
        if (inst->crystal_instance && inst->desc->call_virtual) inst->desc->call_virtual(inst->crystal_instance, "_ready", 0.0);
        return;
    }
    if (match_virtual_method(method_name, "_process")) {
        if (is_editor_active() && !is_tool_desc(inst->desc)) return;
        double delta = (p_args && p_args[0]) ? *(const double*)p_args[0] : 0.016666666666666666;
        if (inst->crystal_instance && inst->desc->call_virtual) inst->desc->call_virtual(inst->crystal_instance, "_process", delta);
        return;
    }
    if (match_virtual_method(method_name, "_physics_process")) {
        if (is_editor_active() && !is_tool_desc(inst->desc)) return;
        double delta = (p_args && p_args[0]) ? *(const double*)p_args[0] : 0.016666666666666666;
        if (inst->crystal_instance && inst->desc->call_virtual) inst->desc->call_virtual(inst->crystal_instance, "_physics_process", delta);
        return;
    }
    if (match_virtual_method(method_name, "_enter_tree")) {
        if (inst->crystal_instance && inst->desc->call_virtual) inst->desc->call_virtual(inst->crystal_instance, "_enter_tree", 0.0);
        return;
    }
    if (match_virtual_method(method_name, "_exit_tree")) {
        if (is_editor_active() && !is_tool_desc(inst->desc)) return;
        if (inst->crystal_instance && inst->desc->call_virtual) inst->desc->call_virtual(inst->crystal_instance, "_exit_tree", 0.0);
        return;
    }
    if (match_virtual_method(method_name, "_input") ||
        match_virtual_method(method_name, "_unhandled_input") ||
        match_virtual_method(method_name, "_unhandled_key_input") ||
        match_virtual_method(method_name, "_shortcut_input") ||
        match_virtual_method(method_name, "_gui_input")) {
        if (is_editor_active() && !is_tool_desc(inst->desc)) return;
        if (inst->crystal_instance && inst->desc->call_virtual_with_data) {
            void *event_obj = (p_args && p_args[0]) ? bridge_ref_get_object(p_args[0]) : nullptr;
            if (!event_obj && p_args && p_args[0]) {
                event_obj = *(void**)p_args[0];
            }
            const void *c_args[1] = { event_obj };
            inst->desc->call_virtual_with_data(inst->crystal_instance, method_name, c_args, r_ret);
        }
        return;
    }
    if (strcmp(method_name, "_overrides_external_editor") == 0 || strcmp(method_name, "overrides_external_editor") == 0) {
        if (r_ret) *(uint8_t*)r_ret = 0;
        return;
    }
    if (strcmp(method_name, "_build") == 0 || strcmp(method_name, "build") == 0) {
        if (r_ret) *(uint8_t*)r_ret = 1;
        if (inst->crystal_instance && inst->desc->call_virtual_with_data) {
            inst->desc->call_virtual_with_data(inst->crystal_instance, "_build", nullptr, r_ret);
        } else if (inst->crystal_instance && inst->desc->call_virtual) {
            inst->desc->call_virtual(inst->crystal_instance, "_build", 0.0);
        }
        return;
    }

    if (strcmp(method_name, "_get_plugin_icon") == 0 || strcmp(method_name, "get_plugin_icon") == 0) {
        if (is_headless_display()) {
            bridge_ret_ref(r_ret, nullptr);
            return;
        }
    }

    // --- Segment 4: Script Language Extension Fast-Paths ---
    // Fast-path virtual dispatches for Crystal script integration classes to bypass reflection overhead.
    if (inst->desc && inst->desc->name) {
        if (strcmp(inst->desc->name, "CrystalLanguage") == 0) {
            if (strcmp(method_name, "_init") == 0 || strcmp(method_name, "init") == 0) {
                return;
            }
            if (strcmp(method_name, "_finish") == 0 || strcmp(method_name, "finish") == 0) {
                return;
            }
            if (strcmp(method_name, "_get_extension") == 0 || strcmp(method_name, "get_extension") == 0) {
                bridge_ret_string(r_ret, "cr");
                return;
            }
            if (strcmp(method_name, "_get_name") == 0 || strcmp(method_name, "get_name") == 0) {
                bridge_ret_string(r_ret, "Crystal");
                return;
            }
            if (strcmp(method_name, "_get_type") == 0 || strcmp(method_name, "get_type") == 0) {
                bridge_ret_string(r_ret, "CrystalScript");
                return;
            }
            if (strcmp(method_name, "_get_recognized_extensions") == 0 || strcmp(method_name, "get_recognized_extensions") == 0) {
                const char *exts[] = { "cr" };
                bridge_ret_packed_string_array(r_ret, exts, 1);
                return;
            }
            if (strcmp(method_name, "_validate_path") == 0 || strcmp(method_name, "validate_path") == 0) {
                bridge_ret_string(r_ret, "");
                return;
            }
            if (strcmp(method_name, "_preferred_file_name_casing") == 0 || strcmp(method_name, "preferred_file_name_casing") == 0) {
                if (r_ret) *(int64_t*)r_ret = 2; // SCRIPT_NAME_CASING_SNAKE_CASE
                return;
            }
            if (strcmp(method_name, "_supports_builtin_mode") == 0 || strcmp(method_name, "supports_builtin_mode") == 0) {
                if (r_ret) *(uint8_t*)r_ret = 0;
                return;
            }
            if (strcmp(method_name, "_can_inherit_from_file") == 0 || strcmp(method_name, "can_inherit_from_file") == 0) {
                if (r_ret) *(uint8_t*)r_ret = 0;
                return;
            }
            if (strcmp(method_name, "_has_named_classes") == 0 || strcmp(method_name, "has_named_classes") == 0) {
                if (r_ret) *(uint8_t*)r_ret = 0;
                return;
            }
            if (strcmp(method_name, "_supports_documentation") == 0 || strcmp(method_name, "supports_documentation") == 0) {
                if (r_ret) *(uint8_t*)r_ret = 0;
                return;
            }
            if (strcmp(method_name, "_get_public_functions") == 0 || strcmp(method_name, "get_public_functions") == 0 ||
                strcmp(method_name, "_get_public_annotations") == 0 || strcmp(method_name, "get_public_annotations") == 0 ||
                strcmp(method_name, "_debug_get_current_stack_info") == 0 || strcmp(method_name, "debug_get_current_stack_info") == 0) {
                // In Godot, r_ret is already an initialized Array passed by the caller (e.g. ScriptLanguageExtension::get_public_functions).
                // Do not re-construct it in place.
                return;
            }
            if (strcmp(method_name, "_get_public_constants") == 0 || strcmp(method_name, "get_public_constants") == 0) {
                // In Godot, r_ret is already an initialized Dictionary passed by the caller.
                return;
            }
            if (strcmp(method_name, "_is_using_templates") == 0 || strcmp(method_name, "is_using_templates") == 0) {
                if (r_ret) *(uint8_t*)r_ret = 1;
                return;
            }
            if (strcmp(method_name, "_make_template") == 0 || strcmp(method_name, "make_template") == 0) {
                char class_name_buf[128] = "NewNode";
                char base_name_buf[128] = "Node";
                if (p_args && p_args[1] && gd_string_to_utf8_chars) {
                    gd_string_to_utf8_chars((GDExtensionConstStringPtr)p_args[1], class_name_buf, sizeof(class_name_buf) - 1);
                }
                if (p_args && p_args[2] && gd_string_to_utf8_chars) {
                    gd_string_to_utf8_chars((GDExtensionConstStringPtr)p_args[2], base_name_buf, sizeof(base_name_buf) - 1);
                }
                if (class_name_buf[0] == '\0') strcpy(class_name_buf, "NewNode");
                if (base_name_buf[0] == '\0') strcpy(base_name_buf, "Node");

                void *cs_sn = make_string_name("CrystalScript");
                GDExtensionObjectPtr script_obj = gd_classdb_construct_object(cs_sn);
                free_string_name(cs_sn);

                if (script_obj) {
                    char script_source[1024];
                    snprintf(script_source, sizeof(script_source),
                        "require \"lapis\"\n\n# %s node\nnode %s < %s do\n  def _ready : Void\n    Godot.print(\"%s initialized\")\n  end\n\n  def _process(delta : Float64) : Void\n  end\nend\n",
                        class_name_buf, class_name_buf, base_name_buf, class_name_buf);

                    static GDExtensionMethodBindPtr mb_set_source_code = nullptr;
                    if (!mb_set_source_code) {
                        mb_set_source_code = bridge_get_method_bind("Script", "set_source_code", 83702148ULL);
                    }
                    if (mb_set_source_code) {
                        alignas(void*) char src_str[8] = {0};
                        gd_string_new_with_utf8_chars(src_str, script_source);
                        const void *sc_args[1] = { src_str };
                        gd_object_method_bind_ptrcall(mb_set_source_code, script_obj, sc_args, nullptr);
                        if (gd_string_destroy) gd_string_destroy(src_str);
                    }
                    bridge_ret_ref(r_ret, script_obj);
                    return;
                }
            }
            if (strcmp(method_name, "_create_script") == 0 || strcmp(method_name, "create_script") == 0) {
                void *cs_sn = make_string_name("CrystalScript");
                GDExtensionObjectPtr script_obj = gd_classdb_construct_object(cs_sn);
                free_string_name(cs_sn);
                bridge_ret_ref(r_ret, script_obj);
                return;
            }
        }
        // --- Segment 5: Resource Loader & Saver Mechanics (.cr Scripts & Serialization) ---
        else if (strcmp(inst->desc->name, "ResourceFormatLoaderCrystal") == 0) {
            if (strcmp(method_name, "_get_recognized_extensions") == 0 || strcmp(method_name, "get_recognized_extensions") == 0) {
                const char *exts[] = { "cr" };
                bridge_ret_packed_string_array(r_ret, exts, 1);
                return;
            }
            if (strcmp(method_name, "_handles_type") == 0 || strcmp(method_name, "handles_type") == 0) {
                bool ok = false;
                if (p_args && p_args[0]) {
                    char type_buf[128] = {0};
                    bridge_arg_to_string_name(p_args[0], type_buf, sizeof(type_buf));
                    if (type_buf[0] == '\0') bridge_arg_to_string(p_args[0], type_buf, sizeof(type_buf));
                    if (type_buf[0] == '\0' || strcmp(type_buf, "Script") == 0 || strcmp(type_buf, "CrystalScript") == 0 || strcmp(type_buf, "Resource") == 0) {
                        ok = true;
                    }
                }
                if (r_ret) *(uint8_t*)r_ret = ok ? 1 : 0;
                return;
            }
            if (strcmp(method_name, "_recognize_path") == 0 || strcmp(method_name, "recognize_path") == 0) {
                bool ok = false;
                if (p_args && p_args[0]) {
                    char path_buf[512] = {0};
                    bridge_arg_to_string(p_args[0], path_buf, sizeof(path_buf));
                    if (has_cr_extension(path_buf)) {
                        ok = true;
                    }
                }
                if (r_ret) *(uint8_t*)r_ret = ok ? 1 : 0;
                return;
            }
            if (strcmp(method_name, "_get_resource_type") == 0 || strcmp(method_name, "get_resource_type") == 0) {
                char path_buf[512] = {0};
                if (p_args && p_args[0]) {
                    bridge_arg_to_string(p_args[0], path_buf, sizeof(path_buf));
                }
                if (has_cr_extension(path_buf)) {
                    bridge_ret_string(r_ret, "CrystalScript");
                } else {
                    bridge_ret_string(r_ret, "");
                }
                return;
            }
            if (strcmp(method_name, "_get_resource_script_class") == 0 || strcmp(method_name, "get_resource_script_class") == 0) {
                bridge_ret_string(r_ret, "");
                return;
            }
            if (strcmp(method_name, "_load") == 0 || strcmp(method_name, "load") == 0) {
                char path_buf[1024] = {0};
                char orig_buf[1024] = {0};
                if (p_args && p_args[0]) {
                    bridge_arg_to_string(p_args[0], path_buf, sizeof(path_buf));
                }
                if (p_args && p_args[1]) {
                    bridge_arg_to_string(p_args[1], orig_buf, sizeof(orig_buf));
                }
                const char *target_path = (orig_buf[0] != '\0') ? orig_buf : path_buf;
                std::string fs_path = bridge_globalize_path(target_path);
                if (fs_path.empty() && target_path[0] != '\0') {
                    if (strncmp(target_path, "res://", 6) == 0) {
                        fs_path = target_path + 6;
                    } else if (strncmp(target_path, "user://", 7) == 0) {
                        fs_path = target_path + 7;
                    } else {
                        fs_path = target_path;
                    }
                }

                std::string code;
                if (!fs_path.empty() && bridge_file_exists(fs_path.c_str())) {
                    FILE *f = fopen(fs_path.c_str(), "rb");
                    if (f) {
                        fseek(f, 0, SEEK_END);
                        long sz = ftell(f);
                        fseek(f, 0, SEEK_SET);
                        if (sz > 0) {
                            code.resize((size_t)sz);
                            fread(&code[0], 1, (size_t)sz, f);
                        }
                        fclose(f);
                    }
                }

                void *cs_sn = make_string_name("CrystalScript");
                GDExtensionObjectPtr script_obj = gd_classdb_construct_object(cs_sn);
                free_string_name(cs_sn);

                if (script_obj) {
                    {
                        std::lock_guard<std::mutex> lock(s_script_source_mutex);
                        s_script_source_code[script_obj] = code;
                        s_script_paths[script_obj] = target_path;
                    }

                    static GDExtensionMethodBindPtr mb_take_over_path = nullptr;
                    if (!mb_take_over_path) {
                        mb_take_over_path = bridge_get_method_bind("Resource", "take_over_path", 83702148ULL);
                    }
                    if (mb_take_over_path && target_path[0] != '\0') {
                        alignas(void*) char p_str[8] = {0};
                        gd_string_new_with_utf8_chars(p_str, target_path);
                        const void *p_args_sp[1] = { p_str };
                        gd_object_method_bind_ptrcall(mb_take_over_path, script_obj, p_args_sp, nullptr);
                        if (gd_string_destroy) gd_string_destroy(p_str);
                    }

                    // Populate the Crystal instance directly
                    GenericExtensionInstance *ext = find_extension_instance(script_obj);
                    if (ext && ext->crystal_instance && ext->desc && ext->desc->call_virtual_with_data) {
                        alignas(void*) char src_str[8] = {0};
                        gd_string_new_with_utf8_chars(src_str, code.c_str());
                        const void *sc_args[1] = { src_str };
                        ext->desc->call_virtual_with_data(ext->crystal_instance, "_set_source_code", sc_args, nullptr);
                        if (gd_string_destroy) gd_string_destroy(src_str);
                    }

                    static GDExtensionMethodBindPtr mb_set_src = nullptr;
                    if (!mb_set_src) {
                        mb_set_src = bridge_get_method_bind("Script", "set_source_code", 83702148ULL);
                    }
                    if (mb_set_src) {
                        alignas(void*) char src_str[8] = {0};
                        gd_string_new_with_utf8_chars(src_str, code.c_str());
                        const void *sc_args[1] = { src_str };
                        gd_object_method_bind_ptrcall(mb_set_src, script_obj, sc_args, nullptr);
                        if (gd_string_destroy) gd_string_destroy(src_str);
                    }

                    char log_msg[256];
                    snprintf(log_msg, sizeof(log_msg), "[ResourceFormatLoaderCrystal] Successfully loaded %s (%zu bytes)", target_path, code.size());
                    godot_log_print(log_msg);

                    bridge_ret_variant_object(r_ret, script_obj);
                    return;
                }
                bridge_ret_variant_nil(r_ret);
                return;
            }
        } else if (strcmp(inst->desc->name, "ResourceFormatSaverCrystal") == 0) {
            if (strcmp(method_name, "_get_recognized_extensions") == 0 || strcmp(method_name, "get_recognized_extensions") == 0) {
                const char *exts[] = { "cr" };
                bridge_ret_packed_string_array(r_ret, exts, 1);
                return;
            }
            if (strcmp(method_name, "_recognize") == 0 || strcmp(method_name, "recognize") == 0) {
                bool ok = false;
                if (p_args && p_args[0]) {
                    void *res_obj = bridge_ref_get_object(p_args[0]);
                    if (!res_obj) res_obj = *(void**)p_args[0];
                    if (res_obj) {
                        GenericExtensionInstance *ext = find_extension_instance(res_obj);
                        if (ext && ext->desc && strcmp(ext->desc->name, "CrystalScript") == 0) {
                            ok = true;
                        } else if (bridge_object_is_class(res_obj, "CrystalScript")) {
                            ok = true;
                        } else {
                            const char *path = bridge_resource_get_path(res_obj);
                            if (has_cr_extension(path)) {
                                ok = true;
                            } else if (bridge_object_is_class(res_obj, "Script") || bridge_object_is_class(res_obj, "ScriptExtension")) {
                                ok = true;
                            }
                        }
                    }
                }
                if (r_ret) *(uint8_t*)r_ret = ok ? 1 : 0;
                return;
            }
            if (strcmp(method_name, "_recognize_path") == 0 || strcmp(method_name, "recognize_path") == 0) {
                bool ok = false;
                // Check path string in p_args[1] (Godot 4 ResourceFormatSaver::_recognize_path(res, path))
                if (p_args && p_args[1]) {
                    char path_buf[512] = {0};
                    bridge_arg_to_string(p_args[1], path_buf, sizeof(path_buf));
                    if (path_buf[0] == '\0') bridge_arg_to_string_name(p_args[1], path_buf, sizeof(path_buf));
                    if (has_cr_extension(path_buf)) {
                        ok = true;
                    }
                }
                // Check resource object in p_args[0]
                if (!ok && p_args && p_args[0]) {
                    void *res_obj = bridge_ref_get_object(p_args[0]);
                    if (!res_obj) res_obj = *(void**)p_args[0];
                    if (res_obj) {
                        GenericExtensionInstance *ext = find_extension_instance(res_obj);
                        if (ext && ext->desc && strcmp(ext->desc->name, "CrystalScript") == 0) {
                            ok = true;
                        } else if (bridge_object_is_class(res_obj, "CrystalScript")) {
                            ok = true;
                        } else {
                            const char *path = bridge_resource_get_path(res_obj);
                            if (has_cr_extension(path)) {
                                ok = true;
                            } else if (bridge_object_is_class(res_obj, "Script") || bridge_object_is_class(res_obj, "ScriptExtension")) {
                                ok = true;
                            }
                        }
                    }
                }
                if (r_ret) *(uint8_t*)r_ret = ok ? 1 : 0;
                return;
            }
            if (strcmp(method_name, "_save") == 0 || strcmp(method_name, "save") == 0) {
                // 1. Resolve resource object
                void *res_obj = nullptr;
                if (p_args && p_args[0]) {
                    res_obj = bridge_ref_get_object(p_args[0]);
                    if (!res_obj) res_obj = *(void**)p_args[0];
                }

                // 2. Resolve target path
                char path_buf[1024] = {0};
                if (p_args && p_args[1]) {
                    bridge_arg_to_string(p_args[1], path_buf, sizeof(path_buf));
                    if (path_buf[0] == '\0') bridge_arg_to_string_name(p_args[1], path_buf, sizeof(path_buf));
                }
                if (path_buf[0] == '\0' && res_obj) {
                    const char *rpath = bridge_resource_get_path(res_obj);
                    if (rpath && rpath[0] != '\0') {
                        strncpy(path_buf, rpath, sizeof(path_buf) - 1);
                    }
                }

                // 3. Resolve source code
                std::string code;
                if (res_obj) {
                    {
                        std::lock_guard<std::mutex> lock(s_script_source_mutex);
                        auto it = s_script_source_code.find(res_obj);
                        if (it != s_script_source_code.end() && !it->second.empty()) {
                            code = it->second;
                        }
                    }
                    if (code.empty()) {
                        // Fast path: if res_obj is a CrystalScript, query the Crystal instance directly
                        GenericExtensionInstance *ext = find_extension_instance(res_obj);
                        if (ext && ext->crystal_instance && ext->desc && ext->desc->call_virtual_with_data) {
                            alignas(void*) char ret_str[8] = {0};
                            ext->desc->call_virtual_with_data(ext->crystal_instance, "_get_source_code", nullptr, ret_str);
                            if (gd_string_to_utf8_chars) {
                                int64_t len = gd_string_to_utf8_chars(ret_str, nullptr, 0);
                                if (len > 0) {
                                    code.resize((size_t)len);
                                    gd_string_to_utf8_chars(ret_str, &code[0], len);
                                }
                            }
                            if (gd_string_destroy) gd_string_destroy(ret_str);
                        }
                    }
                    if (code.empty()) {
                        const char *src = bridge_script_get_source_code(res_obj);
                        if (src && src[0] != '\0') code = src;
                    }
                }

                // 4. Globalize path
                std::string fs_path = bridge_globalize_path(path_buf);

                // 5. Truncation guard: do not overwrite existing file with empty code
                if (code.empty() && !fs_path.empty() && bridge_file_exists(fs_path.c_str())) {
                    godot_log_print("[ResourceFormatSaverCrystal] Refusing to overwrite file with empty source code");
                    if (r_ret) {
                        memset(r_ret, 0, 8);
                        *(int32_t*)r_ret = 1; // ERR_FILE_CANT_WRITE
                    }
                    return;
                }

                // 6. Ensure directory and write file
                bool write_ok = false;
                if (!fs_path.empty()) {
                    bridge_ensure_directory_for_file(fs_path.c_str());
                    FILE *f = fopen(fs_path.c_str(), "wb");
                    if (f) {
                        if (!code.empty()) {
                            fwrite(code.data(), 1, code.size(), f);
                        }
                        fclose(f);
                        write_ok = true;
                    }
                }

                if (write_ok) {
                    char log_msg[512];
                    snprintf(log_msg, sizeof(log_msg), "[ResourceFormatSaverCrystal] Successfully saved %s (%zu bytes) -> %s", path_buf, code.size(), fs_path.c_str());
                    godot_log_print(log_msg);
                    if (r_ret) {
                        memset(r_ret, 0, 8); // OK (0)
                        *(int32_t*)r_ret = 0; // OK (0)
                    }
                } else {
                    char log_msg[512];
                    snprintf(log_msg, sizeof(log_msg), "[ResourceFormatSaverCrystal] Failed to save %s -> %s", path_buf, fs_path.c_str());
                    godot_log_print(log_msg);
                    if (r_ret) {
                        memset(r_ret, 0, 8);
                        *(int32_t*)r_ret = 1; // ERR_FILE_CANT_WRITE
                    }
                }
                return;
            }
            if (strcmp(method_name, "_set_uid") == 0 || strcmp(method_name, "set_uid") == 0) {
                if (r_ret) {
                    memset(r_ret, 0, 8);
                    *(int32_t*)r_ret = 0; // OK (0)
                }
                return;
            }
        }
        // --- Segment 6: Syntax Highlighter & Editor Plugin Hooks ---
        else if (strcmp(inst->desc->name, "CrystalIntegrationPlugin") == 0) {
            if (strcmp(method_name, "_has_main_screen") == 0) {
                if (r_ret) *(uint8_t*)r_ret = 1;
                return;
            }
            if (strcmp(method_name, "_get_plugin_name") == 0) {
                bridge_ret_string(r_ret, "Crystal");
                return;
            }
            if (strcmp(method_name, "_get_plugin_icon") == 0) {
                if (inst->crystal_instance && inst->desc->call_virtual_with_data) {
                    inst->desc->call_virtual_with_data(inst->crystal_instance, "_get_plugin_icon", nullptr, r_ret);
                } else {
                    bridge_ret_ref(r_ret, nullptr);
                }
                return;
            }
            if (strcmp(method_name, "_make_visible") == 0) {
                if (inst->crystal_instance && inst->desc->call_virtual_with_data) {
                    inst->desc->call_virtual_with_data(inst->crystal_instance, "_make_visible", (const void**)p_args, r_ret);
                }
                return;
            }
        } else if (strcmp(inst->desc->name, "CrystalScript") == 0) {
            if (strcmp(method_name, "_has_source_code") == 0 || strcmp(method_name, "has_source_code") == 0) {
                if (r_ret) *(uint8_t*)r_ret = 1;
                return;
            }
            if (strcmp(method_name, "_can_instantiate") == 0 || strcmp(method_name, "can_instantiate") == 0) {
                if (r_ret) *(uint8_t*)r_ret = 1;
                return;
            }
            if (strcmp(method_name, "_is_valid") == 0 || strcmp(method_name, "is_valid") == 0) {
                if (r_ret) *(uint8_t*)r_ret = 1;
                return;
            }
            if (strcmp(method_name, "_get_source_code") == 0 || strcmp(method_name, "get_source_code") == 0) {
                std::string code;
                {
                    std::lock_guard<std::mutex> lock(s_script_source_mutex);
                    auto it = s_script_source_code.find(inst->godot_object);
                    if (it != s_script_source_code.end() && !it->second.empty()) {
                        code = it->second;
                    }
                }
                if (code.empty() && inst->crystal_instance && inst->desc->call_virtual_with_data) {
                    alignas(void*) char ret_str[8] = {0};
                    inst->desc->call_virtual_with_data(inst->crystal_instance, "_get_source_code", nullptr, ret_str);
                    if (gd_string_to_utf8_chars) {
                        int64_t len = gd_string_to_utf8_chars(ret_str, nullptr, 0);
                        if (len > 0) {
                            code.resize((size_t)len);
                            gd_string_to_utf8_chars(ret_str, &code[0], len);
                        }
                    }
                    if (gd_string_destroy) gd_string_destroy(ret_str);
                }
                if (code.empty()) {
                    std::string path;
                    {
                        std::lock_guard<std::mutex> lock(s_script_source_mutex);
                        auto it = s_script_paths.find(inst->godot_object);
                        if (it != s_script_paths.end()) path = it->second;
                    }
                    if (path.empty() && inst->godot_object) {
                        const char *rpath = bridge_resource_get_path(inst->godot_object);
                        if (rpath && rpath[0] != '\0') path = rpath;
                    }
                    if (!path.empty()) {
                        std::string fs_path = bridge_globalize_path(path.c_str());
                        if (fs_path.empty()) fs_path = path;
                        if (bridge_file_exists(fs_path.c_str())) {
                            FILE *f = fopen(fs_path.c_str(), "rb");
                            if (f) {
                                fseek(f, 0, SEEK_END);
                                long sz = ftell(f);
                                fseek(f, 0, SEEK_SET);
                                if (sz > 0) {
                                    code.resize((size_t)sz);
                                    fread(&code[0], 1, (size_t)sz, f);
                                }
                                fclose(f);
                            }
                        }
                    }
                }
                if (!code.empty()) {
                    std::lock_guard<std::mutex> lock(s_script_source_mutex);
                    s_script_source_code[inst->godot_object] = code;
                }
                bridge_ret_string(r_ret, code.c_str());
                return;
            }
            if (strcmp(method_name, "_set_source_code") == 0 || strcmp(method_name, "set_source_code") == 0) {
                std::string new_code;
                if (p_args && p_args[0] && gd_string_to_utf8_chars) {
                    int64_t len = gd_string_to_utf8_chars((GDExtensionConstStringPtr)p_args[0], nullptr, 0);
                    if (len > 0) {
                        new_code.resize((size_t)len);
                        gd_string_to_utf8_chars((GDExtensionConstStringPtr)p_args[0], &new_code[0], len);
                    }
                }
                {
                    std::lock_guard<std::mutex> lock(s_script_source_mutex);
                    s_script_source_code[inst->godot_object] = new_code;
                }
                if (inst->crystal_instance && inst->desc->call_virtual_with_data) {
                    inst->desc->call_virtual_with_data(inst->crystal_instance, method_name, (const void**)p_args, (void*)r_ret);
                }
                return;
            }
        } else if (strcmp(inst->desc->name, "CrystalHighlighter") == 0) {
            if (strcmp(method_name, "_get_name") == 0 || strcmp(method_name, "get_name") == 0) {
                bridge_ret_string(r_ret, "Crystal");
                return;
            }
            if (strcmp(method_name, "_get_supported_languages") == 0 || strcmp(method_name, "get_supported_languages") == 0) {
                const char *langs[] = { "Crystal", "cr", "CrystalScript" };
                bridge_ret_packed_string_array(r_ret, langs, 3);
                return;
            }
            if (strcmp(method_name, "_create") == 0 || strcmp(method_name, "create") == 0) {
                void *hl_sn = make_string_name("CrystalHighlighter");
                GDExtensionObjectPtr hl_obj = gd_classdb_construct_object(hl_sn);
                free_string_name(hl_sn);
                bridge_ret_ref(r_ret, hl_obj);
                return;
            }
            if (strcmp(method_name, "_clear_highlighting_cache") == 0 || strcmp(method_name, "clear_highlighting_cache") == 0 ||
                strcmp(method_name, "_update_cache") == 0 || strcmp(method_name, "update_cache") == 0) {
                return;
            }
            if (strcmp(method_name, "_get_line_syntax_highlighting") == 0 || strcmp(method_name, "get_line_syntax_highlighting") == 0) {
                if (inst->crystal_instance && inst->desc->call_virtual_with_data) {
                    inst->desc->call_virtual_with_data(inst->crystal_instance, "_get_line_syntax_highlighting", (const void**)p_args, (void*)r_ret);
                } else {
                    bridge_ret_dictionary_empty(r_ret);
                }
                return;
            }
        }
    }

    // --- Segment 7: Fallback Dynamic Dispatch into Crystal ---
    // If not handled by fast-paths, forward the method invocation, argument array, and return buffer
    // directly to the Crystal class instance via its call_virtual_with_data function pointer.
    if (inst->crystal_instance && inst->desc->call_virtual_with_data) {
        inst->desc->call_virtual_with_data(inst->crystal_instance, method_name, (const void**)p_args, (void*)r_ret);
    }
}

/**
 * Dynamic property setter called by Godot's inspector, animation player, or script bindings.
 * Matches the property name against the class descriptor hierarchy, unmarshals the input Variant
 * into a typed C/Crystal representation, and invokes the Crystal `set_property` callback.
 *
 * @param p_instance Pointer to the GenericExtensionInstance.
 * @param p_name StringName of the property being assigned.
 * @param p_value Pointer to the source Variant value.
 * @return 1 (true) if the property was matched and assigned; 0 (false) otherwise.
 *
 * Segments:
 * - Segment 1: GC Thread Registration and StringName conversion to C string.
 * - Segment 2: Class Hierarchy Traversal (walking `parent_desc` to find exported property).
 * - Segment 3: Variant Unmarshaling into raw POD buffer and invoking Crystal setter callback.
 */
inline GDExtensionBool generic_class_set(GDExtensionClassInstancePtr p_instance, GDExtensionConstStringNamePtr p_name, GDExtensionConstVariantPtr p_value) {
    // --- Segment 1: Thread Registration & Property Name Resolution ---
    ensure_gc_thread_registered();
    GenericExtensionInstance *inst = (GenericExtensionInstance*)p_instance;
    if (!inst || !inst->desc || !inst->desc->set_property || !inst->crystal_instance) return 0;

    char prop_name_buf[128];
    if (!string_name_to_cstr(p_name, prop_name_buf, sizeof(prop_name_buf))) return 0;

    // --- Segment 2: Class Hierarchy Traversal ---
    const CrystalClassDesc *curr = inst->desc;
    while (curr) {
        for (int i = 0; i < curr->property_count; i++) {
            // Ignore internal / group / category property markers (PROPERTY_USAGE_GROUP, etc.)
            if (curr->properties[i].usage & (64 | 128 | 256)) continue;
            if (strcmp(prop_name_buf, curr->properties[i].name) == 0) {
                // --- Segment 3: Variant Unmarshaling & Crystal Setter Dispatch ---
                alignas(void*) char raw_buf[128] = {};
                bridge_type_from_variant(curr->properties[i].variant_type, raw_buf, p_value);
                if (is_bridge_verbose()) {
                    char buf[256];
                    snprintf(buf, sizeof(buf), "  [GenericExtensionInstance] Set %s::%s", curr->name ? curr->name : "Object", curr->properties[i].name);
                    godot_log_verbose(buf);
                }
                inst->desc->set_property(inst->crystal_instance, curr->properties[i].name, raw_buf);
                return 1;
            }
        }
        curr = curr->parent_desc;
    }
    return 0;
}

/**
 * Dynamic property getter called by Godot's inspector, scene serialization, or script bindings.
 * Traverses the class hierarchy to find the property, invokes the Crystal `get_property` callback,
 * and marshals the resulting value into the destination Variant buffer.
 *
 * @param p_instance Pointer to the GenericExtensionInstance.
 * @param p_name StringName of the property being queried.
 * @param r_ret Pointer to the destination Variant to receive the value.
 * @return 1 (true) if the property was resolved and returned; 0 (false) otherwise.
 *
 * Segments:
 * - Segment 1: GC Thread Registration and StringName conversion to C string.
 * - Segment 2: Class Hierarchy Traversal and Tool Button (hint 39) callable synthesis.
 * - Segment 3: Invoking Crystal getter callback and marshaling POD data into Godot Variant.
 */
inline GDExtensionBool generic_class_get(GDExtensionClassInstancePtr p_instance, GDExtensionConstStringNamePtr p_name, GDExtensionVariantPtr r_ret) {
    // --- Segment 1: Thread Registration & Property Name Resolution ---
    ensure_gc_thread_registered();
    GenericExtensionInstance *inst = (GenericExtensionInstance*)p_instance;
    if (!inst || !inst->desc || !inst->desc->get_property || !inst->crystal_instance) return 0;

    char prop_name_buf[128];
    if (!string_name_to_cstr(p_name, prop_name_buf, sizeof(prop_name_buf))) return 0;

    // --- Segment 2: Class Hierarchy Traversal & Special Hint Handling ---
    const CrystalClassDesc *curr = inst->desc;
    while (curr) {
        for (int i = 0; i < curr->property_count; i++) {
            if (curr->properties[i].usage & (64 | 128 | 256)) continue;
            if (strcmp(prop_name_buf, curr->properties[i].name) == 0) {
                // Hint 39 corresponds to PROPERTY_HINT_TOOL_BUTTON; synthesize a Callable for the inspector button
                if (curr->properties[i].hint == 39) {
                    create_tool_button_callable(inst, curr->properties[i].name, r_ret);
                    return 1;
                }
                // --- Segment 3: Crystal Getter Dispatch & Variant Marshaling ---
                alignas(void*) char raw_buf[128] = {};
                inst->desc->get_property(inst->crystal_instance, curr->properties[i].name, raw_buf);
                bridge_variant_from_type(curr->properties[i].variant_type, r_ret, raw_buf);
                if (is_bridge_verbose()) {
                    char buf[256];
                    snprintf(buf, sizeof(buf), "  [GenericExtensionInstance] Get %s::%s", curr->name ? curr->name : "Object", curr->properties[i].name);
                    godot_log_verbose(buf);
                }
                return 1;
            }
        }
        curr = curr->parent_desc;
    }
    return 0;
}

/**
 * Method call dispatcher for GodotChannel inter-thread/actor communication helper objects.
 * Marshals string messages, booleans, and channel sizes across Godot's Variant ABI.
 *
 * @param method_userdata Interned C string pointer identifying the channel method name.
 * @param p_instance Pointer to the GenericExtensionInstance representing the GodotChannel.
 * @param p_args Array of pointers to Variant arguments.
 * @param p_argument_count Number of arguments passed.
 * @param r_return Destination Variant buffer for the return value.
 * @param r_error Call error indicator populated if instance is null or method fails.
 *
 * Segments:
 * - Segment 1: Thread Registration, Instance Validation, and Error Status Setup.
 * - Segment 2: Dispatch and Variant Conversion for send, try_send, receive, try_receive,
 *              close, size, is_empty, is_full, and is_closed.
 */
inline void channel_method_call(
    void *method_userdata,
    GDExtensionClassInstancePtr p_instance,
    const GDExtensionConstVariantPtr *p_args,
    GDExtensionInt p_argument_count,
    GDExtensionVariantPtr r_return,
    GDExtensionCallError *r_error
) {
    // --- Segment 1: GC Thread Registration & Instance Validation ---
    ensure_gc_thread_registered();
    GenericExtensionInstance *inst = (GenericExtensionInstance*)p_instance;
    if (!inst || !inst->desc || !inst->crystal_instance || !inst->desc->call_virtual_with_data) {
        if (r_error) r_error->error = GDEXTENSION_CALL_ERROR_INSTANCE_IS_NULL;
        return;
    }
    if (r_error) r_error->error = GDEXTENSION_CALL_OK;

    const char *mname = (const char*)method_userdata;
    if (!mname) return;

    // --- Segment 2: Channel Method Dispatch & Variant Marshaling ---
    if (strcmp(mname, "send") == 0 || strcmp(mname, "try_send") == 0) {
        const char *s_val = "";
        char str_buf[1024] = {};
        if (p_argument_count > 0 && p_args && p_args[0]) {
            const char *p_s = str_buf;
            bridge_type_from_variant(GDEXTENSION_VARIANT_TYPE_STRING, &p_s, p_args[0]);
            s_val = p_s ? p_s : "";
        }
        const void *c_args[1] = { s_val };
        uint8_t ret_bool = 0;
        inst->desc->call_virtual_with_data(inst->crystal_instance, mname, c_args, &ret_bool);
        bool b = (ret_bool != 0);
        bridge_variant_from_type(GDEXTENSION_VARIANT_TYPE_BOOL, r_return, &b);
    } else if (strcmp(mname, "receive") == 0 || strcmp(mname, "try_receive") == 0) {
        const char *ret_str = nullptr;
        inst->desc->call_virtual_with_data(inst->crystal_instance, mname, nullptr, &ret_str);
        if (ret_str) {
            bridge_variant_from_type(GDEXTENSION_VARIANT_TYPE_STRING, r_return, &ret_str);
        } else {
            if (gd_variant_new_nil) gd_variant_new_nil(r_return);
        }
    } else if (strcmp(mname, "close") == 0) {
        inst->desc->call_virtual_with_data(inst->crystal_instance, "close", nullptr, nullptr);
        if (gd_variant_new_nil) gd_variant_new_nil(r_return);
    } else if (strcmp(mname, "size") == 0) {
        int32_t ret_size = 0;
        inst->desc->call_virtual_with_data(inst->crystal_instance, "size", nullptr, &ret_size);
        int64_t ret_i64 = ret_size;
        bridge_variant_from_type(GDEXTENSION_VARIANT_TYPE_INT, r_return, &ret_i64);
    } else if (strcmp(mname, "is_empty") == 0 || strcmp(mname, "is_full") == 0 || strcmp(mname, "is_closed") == 0) {
        uint8_t ret_bool = 0;
        inst->desc->call_virtual_with_data(inst->crystal_instance, mname, nullptr, &ret_bool);
        bool b = (ret_bool != 0);
        bridge_variant_from_type(GDEXTENSION_VARIANT_TYPE_BOOL, r_return, &b);
    }
}
