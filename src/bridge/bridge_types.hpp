#pragma once

#include "common.hpp"

/**
 * ==============================================================================
 * LibGodot - C-ABI Data Structures & Bridge Types
 * ==============================================================================
 */

/**
 * C-ABI POD representation of an unpacked Godot Variant value passed across the FFI boundary.
 *
 * Binary Layout Invariant:
 * Must match `struct VariantArg` in `src/libgodot/c_api.cr` byte-for-byte (64-bit alignment):
 * - `type` (int32): GDExtensionVariantType enum value.
 * - `extra_flags` (int32): Bitflags or sub-type flags (padding to 64-bit alignment).
 * - `int_val` (int64): Integer value (for bool, int, enum, and integer components).
 * - `float_val` (float64): Floating-point value (for float and double).
 * - `ptr_val` (void*): Pointer to string, Object*, or buffer.
 * - `instance_id` (uint64): Monotonic 64-bit Godot ObjectDB instance ID.
 * - `vec_val` (float[4]): Vector / Color components (x, y, z, w / r, g, b, a).
 */
struct VariantArg {
    int32_t type;
    int32_t extra_flags;
    int64_t int_val;
    double float_val;
    void *ptr_val;
    uint64_t instance_id;
    float vec_val[4];
};

/**
 * Lightweight type-tagged pointer passed into vararg signal emitters and dispatches.
 */
struct BridgeSignalArg {
    int32_t arg_type; /** GDExtensionVariantType enum */
    void *data;       /** Pointer to typed value */
};

/**
 * Autocompletion suggestion entry passed to the Godot script editor for Crystal code.
 */
struct BridgeCompletionOption {
    int64_t kind;             /** CodeCompletionKind enum */
    const char *display;      /** Display text in completion dropdown */
    const char *insert_text;  /** Code text inserted upon acceptance */
    const char *default_value;/** Default value text if applicable */
    int64_t location;         /** Code completion location index */
};

using CrystalSignalCallbackFn = void (*)(uint64_t target_id, const char *signal_name, const VariantArg *args, int arg_count);
using CrystalDeinitCallbackFn = void (*)();
using CrystalCleanupCallbackFn = void (*)();

/**
 * Class property descriptor registered into Godot's ClassDB.
 * Populated by Crystal macros for `@Export` properties and inspector groups.
 */
struct CrystalPropertyDesc {
    const char *name;         /** Property identifier (e.g., "speed", "player_name") */
    const char *type_name;    /** Godot type name (e.g., "float", "Vector3", "Node3D") */
    int variant_type;         /** GDExtensionVariantType enum representing the underlying storage */
    uint32_t hint;            /** PropertyHint enum flags (e.g., PROPERTY_HINT_RANGE) */
    const char *hint_string;  /** Formatting string for the hint (e.g., "0.0,100.0,0.1") */
    uint32_t usage;           /** PropertyUsageFlags bitmask (defaults to PROPERTY_USAGE_DEFAULT) */
};

/**
 * Parameter descriptor for a class signal.
 */
struct CrystalSignalArgDesc {
    const char *name;         /** Parameter identifier name */
    int variant_type;         /** GDExtensionVariantType of the parameter */
};

/**
 * Signal descriptor registered into Godot's ClassDB.
 * Populated by Crystal macros for `signal name(arg : Type)` declarations.
 */
struct CrystalSignalDesc {
    const char *name;                   /** Signal name (e.g., "health_changed", "died") */
    int arg_count;                      /** Number of arguments in the signal signature */
    const CrystalSignalArgDesc *args;   /** Array of argument descriptors */
};

/**
 * Class integer or enum constant registered into Godot's ClassDB.
 */
struct CrystalConstantDesc {
    const char *enum_name;     /** Name of the enum or empty string if standalone constant */
    const char *constant_name; /** Name of the constant */
    int64_t value;             /** Value of the constant */
    bool is_bitfield;          /** True if part of a bitfield flags enum */
};

struct CrystalClassDesc {
    const char *name;         /** Registered class name (e.g. "MyPlayer", "ToolTester2D") */
    const char *parent_name;  /** Native or Crystal parent class (e.g. "CharacterBody3D") */
    const char *icon_path;    /** Optional editor icon path (e.g. "res://icon.svg") */
    bool is_virtual;          /** True if class is a virtual/interface class */
    bool is_abstract;         /** True if class cannot be instantiated directly */
    bool is_tool;             /** True if marked @tool (runs in the Godot Editor) */
    bool has_ready;           /** True if the class overrides _ready() */
    bool has_process;         /** True if the class overrides _process(delta) */
    bool has_physics_process; /** True if the class overrides _physics_process(delta) */
    bool has_enter_tree;      /** True if the class overrides _enter_tree() */
    bool has_exit_tree;       /** True if the class overrides _exit_tree() */
    bool has_input;           /** True if the class overrides _input(event) */
    bool has_unhandled_input; /** True if the class overrides _unhandled_input(event) */
    bool has_unhandled_key_input; /** True if the class overrides _unhandled_key_input(event) */
    bool has_shortcut_input;  /** True if the class overrides _shortcut_input(event) */
    bool has_gui_input;       /** True if the class overrides _gui_input(event) */

    // Crystal Host Callbacks
    void* (*create_instance)(const CrystalClassDesc *desc, void *godot_object);
    void (*free_instance)(void *crystal_instance);
    void (*call_virtual)(void *crystal_instance, const char *method_name, double delta);
    void (*set_property)(void *crystal_instance, const char *prop_name, const void *val_ptr);
    void (*get_property)(void *crystal_instance, const char *prop_name, void *ret_ptr);
    int (*has_virtual_method)(const CrystalClassDesc *desc, const char *method_name);
    void (*call_virtual_with_data)(void *crystal_instance, const char *method_name, const void **args, void *ret);
    void (*call_tool_button)(void *crystal_instance, const char *button_name);

    int property_count;
    const CrystalPropertyDesc *properties;

    int signal_count;
    const CrystalSignalDesc *signals;

    int constant_count;
    const CrystalConstantDesc *constants;

    const CrystalClassDesc *parent_desc;
};

struct GenericExtensionInstance {
    GDExtensionObjectPtr godot_object;  /** Native Godot C++ Object pointer */
    void *crystal_instance;             /** Heap pointer to Crystal object */
    const CrystalClassDesc *desc;       /** Metadata descriptor for the class */
};

struct PersistentClassDesc {
    std::string name;
    std::string parent_name;
    std::string icon_path;

    std::vector<std::string> prop_names;
    std::vector<std::string> prop_type_names;
    std::vector<std::string> prop_hint_strings;
    std::vector<CrystalPropertyDesc> properties;

    std::vector<std::string> sig_names;
    std::vector<std::vector<std::string>> sig_arg_names;
    std::vector<std::vector<CrystalSignalArgDesc>> sig_args;
    std::vector<CrystalSignalDesc> signals;

    std::vector<std::string> const_enum_names;
    std::vector<std::string> const_names;
    std::vector<CrystalConstantDesc> constants;

    CrystalClassDesc desc;

    void update_from(const CrystalClassDesc *p_desc) {
        if (!p_desc) return;
        name = p_desc->name ? p_desc->name : "";
        parent_name = p_desc->parent_name ? p_desc->parent_name : "";
        icon_path = p_desc->icon_path ? p_desc->icon_path : "";

        // Copy properties
        prop_names.clear();
        prop_type_names.clear();
        prop_hint_strings.clear();
        properties.clear();

        if (p_desc->properties && p_desc->property_count > 0) {
            prop_names.resize(p_desc->property_count);
            prop_type_names.resize(p_desc->property_count);
            prop_hint_strings.resize(p_desc->property_count);
            properties.resize(p_desc->property_count);

            for (int i = 0; i < p_desc->property_count; i++) {
                prop_names[i] = p_desc->properties[i].name ? p_desc->properties[i].name : "";
                prop_type_names[i] = p_desc->properties[i].type_name ? p_desc->properties[i].type_name : "";
                prop_hint_strings[i] = p_desc->properties[i].hint_string ? p_desc->properties[i].hint_string : "";

                properties[i] = p_desc->properties[i];
                properties[i].name = prop_names[i].c_str();
                properties[i].type_name = prop_type_names[i].c_str();
                properties[i].hint_string = prop_hint_strings[i].c_str();
            }
        }

        // Copy signals
        sig_names.clear();
        sig_arg_names.clear();
        sig_args.clear();
        signals.clear();

        if (p_desc->signals && p_desc->signal_count > 0) {
            sig_names.resize(p_desc->signal_count);
            sig_arg_names.resize(p_desc->signal_count);
            sig_args.resize(p_desc->signal_count);
            signals.resize(p_desc->signal_count);

            for (int i = 0; i < p_desc->signal_count; i++) {
                sig_names[i] = p_desc->signals[i].name ? p_desc->signals[i].name : "";
                signals[i] = p_desc->signals[i];
                signals[i].name = sig_names[i].c_str();

                int ac = p_desc->signals[i].arg_count;
                if (p_desc->signals[i].args && ac > 0) {
                    sig_arg_names[i].resize(ac);
                    sig_args[i].resize(ac);
                    for (int a = 0; a < ac; a++) {
                        sig_arg_names[i][a] = p_desc->signals[i].args[a].name ? p_desc->signals[i].args[a].name : "";
                        sig_args[i][a] = p_desc->signals[i].args[a];
                        sig_args[i][a].name = sig_arg_names[i][a].c_str();
                    }
                    signals[i].args = sig_args[i].data();
                    signals[i].arg_count = ac;
                } else {
                    signals[i].args = nullptr;
                    signals[i].arg_count = 0;
                }
            }
        }

        // Copy constants
        const_enum_names.clear();
        const_names.clear();
        constants.clear();

        if (p_desc->constants && p_desc->constant_count > 0) {
            const_enum_names.resize(p_desc->constant_count);
            const_names.resize(p_desc->constant_count);
            constants.resize(p_desc->constant_count);

            for (int i = 0; i < p_desc->constant_count; i++) {
                const_enum_names[i] = p_desc->constants[i].enum_name ? p_desc->constants[i].enum_name : "";
                const_names[i] = p_desc->constants[i].constant_name ? p_desc->constants[i].constant_name : "";
                constants[i] = p_desc->constants[i];
                constants[i].enum_name = const_enum_names[i].c_str();
                constants[i].constant_name = const_names[i].c_str();
            }
        }

        desc = *p_desc;
        desc.name = name.c_str();
        desc.parent_name = parent_name.c_str();
        desc.icon_path = icon_path.empty() ? nullptr : icon_path.c_str();
        desc.properties = properties.empty() ? nullptr : properties.data();
        desc.property_count = (int)properties.size();
        desc.signals = signals.empty() ? nullptr : signals.data();
        desc.signal_count = (int)signals.size();
        desc.constants = constants.empty() ? nullptr : constants.data();
        desc.constant_count = (int)constants.size();
        desc.parent_desc = nullptr;
    }
};

struct BridgeAPI {
    int (*register_class)(const CrystalClassDesc *desc);
    GDExtensionMethodBindPtr (*get_method_bind)(const char *class_name, const char *method_name, int64_t hash);
    void (*method_bind_ptrcall)(GDExtensionMethodBindPtr method_bind, GDExtensionObjectPtr instance, const void **args, void *ret);
    void (*method_bind_call)(GDExtensionMethodBindPtr method_bind, GDExtensionObjectPtr instance, const GDExtensionConstVariantPtr *args, GDExtensionInt arg_count, GDExtensionVariantPtr ret, GDExtensionCallError *error);
    void (*load_editor_help_xml)(const char *xml);
    GDExtensionObjectPtr (*get_singleton)(const char *name);
    void* (*make_string_name)(const char *name);
    void (*free_string_name)(void *sn);
    void* (*make_string)(const char *str);
    void (*free_string)(void *s);
    void* (*make_nodepath)(const char *path);
    void (*free_nodepath)(void *np);
    void (*type_from_variant)(int type, void *dst, const void *variant);
    void (*variant_from_type)(int type, void *variant, const void *src);
    void (*log_print)(const char *msg);
    void (*log_error)(const char *desc, const char *msg, const char *func, const char *file, int line);
    void (*log_warning)(const char *desc, const char *msg, const char *func, const char *file, int line);
    void (*object_emit_signal)(GDExtensionObjectPtr instance, const char *signal_name, const BridgeSignalArg *args, int arg_count);
    void (*object_call_deferred)(GDExtensionObjectPtr instance, const char *method_name, const BridgeSignalArg *args, int arg_count);
    void (*object_call)(GDExtensionObjectPtr instance, const char *method_name, const BridgeSignalArg *args, int arg_count);
    GDExtensionObjectPtr (*node_find_child)(GDExtensionObjectPtr node, const char *pattern, bool recursive, bool owned);
    GDExtensionObjectPtr (*node_get_node)(GDExtensionObjectPtr node, const char *path);
    void (*range_set_value)(GDExtensionObjectPtr range_obj, double value);
    void (*node_rpc_config)(GDExtensionObjectPtr node, const char *method, int rpc_mode, int transfer_mode, bool call_local, int channel);
    GDExtensionObjectPtr (*resource_loader_load)(const char *path, const char *type_hint, int64_t cache_mode);
    GDExtensionObjectPtr (*packed_scene_instantiate)(GDExtensionObjectPtr scene, int64_t edit_state);
    const char* (*node_get_name)(GDExtensionObjectPtr node);
    GDExtensionObjectPtr (*classdb_construct_object)(const char *class_name);
    GDExtensionObjectPtr (*object_call_ret_object)(GDExtensionObjectPtr instance, const char *method_name, const BridgeSignalArg *args, int arg_count);
    int64_t (*object_call_ret_int)(GDExtensionObjectPtr instance, const char *method_name, const BridgeSignalArg *args, int arg_count);
    double (*object_call_ret_float)(GDExtensionObjectPtr instance, const char *method_name, const BridgeSignalArg *args, int arg_count);
    bool (*object_call_ret_bool)(GDExtensionObjectPtr instance, const char *method_name, const BridgeSignalArg *args, int arg_count);
    const char* (*object_call_ret_string)(GDExtensionObjectPtr instance, const char *method_name, const BridgeSignalArg *args, int arg_count);
    void (*object_destroy)(GDExtensionObjectPtr p_o);
    uint64_t (*object_get_instance_id)(GDExtensionConstObjectPtr p_o);
    GDExtensionObjectPtr (*object_get_instance_from_id)(uint64_t id);
    uint8_t (*is_instance_valid)(uint64_t id);
    void (*ret_string)(void *r_ret, const char *str);
    void (*ret_string_name)(void *r_ret, const char *str);
    void (*ret_packed_string_array)(void *r_ret, const char **strings, int count);
    void (*ret_dictionary_empty)(void *r_ret);
    void (*ret_array_empty)(void *r_ret);
    void (*ret_object)(void *r_ret, void *obj);
    void (*ret_ref)(void *r_ret, void *obj);
    void (*ret_variant_object)(void *r_ret, void *obj);
    void (*ret_variant_nil)(void *r_ret);
    void (*highlighter_add_span)(void *r_color_map, int64_t col, float r, float g, float b, float a);
    int (*arg_to_string)(const void *arg, char *out, int max_len);
    int (*arg_to_string_name)(const void *arg, char *out, int max_len);
    void (*ret_dictionary_validate)(void *r_ret, uint8_t valid);
    void (*ret_dictionary_complete_code)(void *r_ret);
    void (*ret_dictionary_lookup_code)(void *r_ret);
    void (*ret_dictionary_complete_code_ex)(void *r_ret, int64_t result, uint8_t force, const char *call_hint, const struct BridgeCompletionOption *options, int option_count);
    void (*ret_dictionary_lookup_code_ex)(void *r_ret, int64_t result, int64_t type, const char *class_name, const char *class_member, const char *description, const char *script_path, int64_t location);
    void (*ret_dictionary_global_class)(void *r_ret, const char *class_name, const char *base_type, const char *icon_path);
    void* (*placeholder_script_instance_create)(void *p_language, void *p_script, const void *p_owner_arg);
    int (*text_edit_get_line)(void *text_edit, int64_t line, char *out_buf, int max_len);
    void (*object_connect_signal)(GDExtensionObjectPtr instance, const char *signal_name, uint32_t flags);
    void (*object_disconnect_signal)(GDExtensionObjectPtr instance, const char *signal_name);
    void (*register_signal_callback)(CrystalSignalCallbackFn fn);
    void (*register_deinit_callback)(CrystalDeinitCallbackFn fn);
    int (*is_loader_registered)();
    void (*set_loader_registered)(int r);
    int (*is_saver_registered)();
    void (*set_saver_registered)(int r);
    int (*is_language_registered)();
    void (*set_language_registered)(int r);
    void* (*get_language_object)();
    void (*set_language_object)(void *obj);
    void (*set_reloading)(int r);
    void (*set_debugger_cleanup)(void (*fn)());
    void (*trigger_debugger_cleanup)();
    void* (*ref_get_object)(const void *ref_ptr);
    const char* (*script_get_source_code)(GDExtensionObjectPtr script_obj);
    const char* (*resource_get_path)(GDExtensionObjectPtr res_obj);
    bool (*object_is_class)(GDExtensionObjectPtr obj, const char *class_name);
    void (*register_gc_functions)(const struct BridgeGCFunctions *funcs);
    void (*get_gc_signals)(int *out_suspend, int *out_restart);
    void (*object_get_class_name)(GDExtensionObjectPtr obj, char *buf, int max_len);
    void (*log_verbose)(const char *msg);
    int (*is_verbose)();
    void (*ret_signal_list)(void *r_ret, const struct CrystalSignalDesc *signals, int signal_count);
    void (*ret_property_list)(void *r_ret, const struct CrystalPropertyDesc *props, int prop_count);
};

struct BridgeGCFunctions {
    void (*init)();
    int (*register_my_thread)(const void *sb);
    void (*unregister_my_thread)();
    int (*thread_is_registered)();
    void (*allow_register_threads)();
    int (*get_stack_base)(void *sb);
    int (*get_suspend_signal)();
    int (*get_thr_restart_signal)();
};
