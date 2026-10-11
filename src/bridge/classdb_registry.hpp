#pragma once

#include "common.hpp"
#include "gdextension_api.hpp"
#include "bridge_types.hpp"
#include "gc_support.hpp"
#include "dispatch_signals.hpp"
#include "extension_instance.hpp"

/**
 * ==============================================================================
 * LibGodot - ClassDB Registration, Reflection, and Lifecycle Tracking
 * ==============================================================================
 */

static std::unordered_map<std::string, PersistentClassDesc*> g_persistent_class_descs;
static std::vector<std::pair<GDExtensionClassLibraryPtr, CrystalClassDesc*>> g_deferred_editor_classes;
static std::unordered_map<GDExtensionClassLibraryPtr, std::vector<std::string>> g_library_editor_classes;
static std::unordered_map<GDExtensionClassLibraryPtr, std::vector<std::string>> g_library_scene_classes;
static std::unordered_set<std::string> g_all_registered_class_names;
static std::unordered_set<std::string> g_classes_registered_in_current_cycle;
static std::vector<std::string> g_registered_class_order;

inline bool is_editor_system_class(const char *name) {
    if (!name) return false;
    return (strcmp(name, "CrystalIntegrationPlugin") == 0 ||
            strcmp(name, "CrystalHighlighter") == 0 ||
            strcmp(name, "CrystalDebuggerPlugin") == 0 ||
            strcmp(name, "CrystalPanel") == 0 ||
            strcmp(name, "CrystalConsoleDock") == 0 ||
            strcmp(name, "BenchmarkGraphControl") == 0 ||
            strcmp(name, "CrystalRadareSessionTab") == 0);
}

inline bool is_editor_class(const CrystalClassDesc *desc) {
    if (!desc) return false;
    if (desc->name && is_editor_system_class(desc->name)) return true;
    if (desc->parent_name && strncmp(desc->parent_name, "Editor", 6) == 0) return true;
    if (desc->parent_desc) return is_editor_class(desc->parent_desc);
    return false;
}

inline void mark_class_unregistered(const std::string &cname) {
    g_all_registered_class_names.erase(cname);
    auto pcd_it = g_persistent_class_descs.find(cname);
    if (pcd_it != g_persistent_class_descs.end()) {
        pcd_it->second->is_registered_in_classdb = false;
        pcd_it->second->registered_library = nullptr;
        pcd_it->second->registered_property_names.clear();
        pcd_it->second->registered_signal_names.clear();
        pcd_it->second->registered_constant_names.clear();
    }
}

/**
 * Checks if a class is already registered in Godot's ClassDB (either engine native or another GDExtension module).
 */
inline bool is_class_registered_in_engine(const char *name) {
    if (!name || !gd_global_get_singleton || !gd_classdb_get_method_bind || !gd_object_method_bind_ptrcall) return false;
    void *sn_cdb = make_string_name("ClassDB");
    GDExtensionObjectPtr cdb = gd_global_get_singleton(sn_cdb);
    free_string_name(sn_cdb);
    if (!cdb) return false;

    static GDExtensionMethodBindPtr mb_exists = nullptr;
    if (!mb_exists) {
        void *sn_c = make_string_name("ClassDB");
        void *sn_m = make_string_name("class_exists");
        mb_exists = gd_classdb_get_method_bind(sn_c, sn_m, 2619796661ULL);
        free_string_name(sn_c); free_string_name(sn_m);
    }
    if (!mb_exists) return false;

    void *sn_target = make_string_name(name);
    const void *args[1] = { sn_target };
    uint8_t ret = 0;
    gd_object_method_bind_ptrcall(mb_exists, cdb, args, &ret);
    free_string_name(sn_target);
    return (ret != 0);
}

inline void register_channel_methods(void *class_sn) {
    if (!gd_classdb_register_extension_class_method || !g_library) return;

    auto reg_method = [&](const char *name, int ret_type, int arg_count, const char *arg_name, int arg_type) {
        void *sn_name = make_string_name(name);
        std::string ret_name = std::string(name) + "_ret";
        GDExtensionPropertyInfo ret_info = {};
        ret_info.type = (GDExtensionVariantType)ret_type;
        ret_info.name = make_string_name(ret_name.c_str());
        ret_info.class_name = make_string_name("");
        ret_info.hint = 0;
        ret_info.hint_string = make_string("");
        ret_info.usage = 0; // PROPERTY_USAGE_NONE

        GDExtensionPropertyInfo arg_info = {};
        GDExtensionClassMethodArgumentMetadata arg_meta = GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE;
        if (arg_count > 0 && arg_name) {
            arg_info.type = (GDExtensionVariantType)arg_type;
            arg_info.name = make_string_name(arg_name);
            arg_info.class_name = make_string_name("");
            arg_info.hint = 0;
            arg_info.hint_string = make_string("");
            arg_info.usage = 0; // PROPERTY_USAGE_NONE
        }

        GDExtensionClassMethodInfo minfo = {};
        minfo.name = sn_name;
        minfo.method_userdata = (void*)name;
        minfo.call_func = channel_method_call;
        minfo.ptrcall_func = nullptr;
        minfo.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL;
        minfo.has_return_value = (ret_type != GDEXTENSION_VARIANT_TYPE_NIL) ? 1 : 0;
        minfo.return_value_info = (ret_type != GDEXTENSION_VARIANT_TYPE_NIL) ? &ret_info : nullptr;
        minfo.return_value_metadata = GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE;
        minfo.argument_count = arg_count;
        minfo.arguments_info = (arg_count > 0) ? &arg_info : nullptr;
        minfo.arguments_metadata = (arg_count > 0) ? &arg_meta : nullptr;
        minfo.default_argument_count = 0;
        minfo.default_arguments = nullptr;

        gd_classdb_register_extension_class_method(g_library, class_sn, &minfo);

        free_string_name(sn_name);
        free_string_name(ret_info.name);
        free_string_name(ret_info.class_name);
        free_string(ret_info.hint_string);
        if (arg_count > 0) {
            free_string_name(arg_info.name);
            free_string_name(arg_info.class_name);
            free_string(arg_info.hint_string);
        }
    };

    reg_method("send", GDEXTENSION_VARIANT_TYPE_BOOL, 1, "value", GDEXTENSION_VARIANT_TYPE_STRING);
    reg_method("try_send", GDEXTENSION_VARIANT_TYPE_BOOL, 1, "value", GDEXTENSION_VARIANT_TYPE_STRING);
    reg_method("receive", GDEXTENSION_VARIANT_TYPE_STRING, 0, nullptr, 0);
    reg_method("try_receive", GDEXTENSION_VARIANT_TYPE_STRING, 0, nullptr, 0);
    reg_method("close", GDEXTENSION_VARIANT_TYPE_NIL, 0, nullptr, 0);
    reg_method("size", GDEXTENSION_VARIANT_TYPE_INT, 0, nullptr, 0);
    reg_method("is_empty", GDEXTENSION_VARIANT_TYPE_BOOL, 0, nullptr, 0);
    reg_method("is_full", GDEXTENSION_VARIANT_TYPE_BOOL, 0, nullptr, 0);
    reg_method("is_closed", GDEXTENSION_VARIANT_TYPE_BOOL, 0, nullptr, 0);
}

/**
 * Internal helper that registers a Crystal class with Godot's ClassDB.
 *
 * Configures the GDExtensionClassCreationInfo6 structure with bridge callback pointers,
 * registers exported properties (and inspector groups/subgroups), signals, integer/enum
 * constants, and channel communication methods.
 *
 * @param desc Pointer to the CrystalClassDesc descriptor.
 *
 * Segments:
 * - Segment 1: Parameter validation, duplicate registration check, and StringName allocation.
 * - Segment 2: GDExtensionClassCreationInfo6 configuration with GenericExtensionInstance callbacks.
 * - Segment 3: Native ClassDB class registration (`gd_classdb_register_extension_class6`).
 * - Segment 4: Property Group & Export Property Registration.
 * - Segment 5: Signal Registration with typed parameter metadata.
 * - Segment 6: Integer and Enum Constant Registration.
 * - Segment 7: GodotChannel Method Registration & Editor/Scene Class Tracking.
 */
inline void do_classdb_register(CrystalClassDesc *desc) {
    // --- Segment 1: Validation & StringName Allocation ---
    if (!desc || !g_library) return;

    void *class_sn = make_string_name(desc->name);
    void *parent_sn = make_string_name(desc->parent_name);

    // --- Segment 2: GDExtension Class Creation Struct Setup ---
    GDExtensionClassCreationInfo6 cinfo = {};
    cinfo.is_virtual = desc->is_virtual ? 1 : 0;
    cinfo.is_abstract = desc->is_abstract ? 1 : 0;
    cinfo.is_exposed = 1;
    cinfo.is_runtime = 0;
    cinfo.icon_path = (desc->icon_path && strlen(desc->icon_path) > 0) ? make_string(desc->icon_path) : nullptr;
    cinfo.set_func = generic_class_set;
    cinfo.get_func = generic_class_get;
    cinfo.create_instance_func = generic_class_create;
    cinfo.free_instance_func = generic_class_free;
    cinfo.recreate_instance_func = generic_class_recreate;
    cinfo.get_virtual_func = nullptr;
    cinfo.get_virtual_call_data_func = generic_class_get_virtual_call_data;
    cinfo.call_virtual_with_data_func = generic_class_call_virtual_with_data;
    auto pcd_it = g_persistent_class_descs.find(desc->name);
    PersistentClassDesc *pcd = (pcd_it != g_persistent_class_descs.end()) ? pcd_it->second : nullptr;
    cinfo.class_userdata = pcd ? (void*)&pcd->desc : (void*)desc;

    // --- Segment 3: Native Engine ClassDB Registration ---
    if (!pcd || !pcd->is_registered_in_classdb) {
        gd_classdb_register_extension_class6(g_library, class_sn, parent_sn, &cinfo);
        if (pcd) {
            pcd->is_registered_in_classdb = true;
            pcd->registered_library = g_library;
        }
        if (std::find(g_registered_class_order.begin(), g_registered_class_order.end(), std::string(desc->name)) == g_registered_class_order.end()) {
            g_registered_class_order.push_back(std::string(desc->name));
        }
    }

    if (cinfo.icon_path) {
        free_string((void*)cinfo.icon_path);
    }

    // --- Segment 4: Property Group & Export Property Registration ---
    for (int i = 0; i < desc->property_count; i++) {
        const CrystalPropertyDesc &p = desc->properties[i];

        if ((p.usage & 64) && gd_classdb_register_extension_class_property_group) {
            ScopedString grp_str(p.name ? p.name : "");
            ScopedString pfx_str(p.hint_string ? p.hint_string : "");
            if (!pcd || !p.name || pcd->registered_property_names.count(p.name) == 0) {
                gd_classdb_register_extension_class_property_group(g_library, class_sn, grp_str, pfx_str);
                if (pcd && p.name) pcd->registered_property_names.insert(p.name);
            }
            continue;
        }

        if ((p.usage & 256) && gd_classdb_register_extension_class_property_subgroup) {
            ScopedString sub_str(p.name ? p.name : "");
            ScopedString pfx_str(p.hint_string ? p.hint_string : "");
            if (!pcd || !p.name || pcd->registered_property_names.count(p.name) == 0) {
                gd_classdb_register_extension_class_property_subgroup(g_library, class_sn, sub_str, pfx_str);
                if (pcd && p.name) pcd->registered_property_names.insert(p.name);
            }
            continue;
        }

        if (pcd && p.name && pcd->registered_property_names.count(p.name) > 0) {
            continue;
        }

        // Prevent duplicate registration of inherited properties on subclasses in ClassDB
        bool already_in_ancestor = false;
        std::string cur_parent = pcd ? pcd->parent_name : "";
        while (!cur_parent.empty()) {
            auto pit = g_persistent_class_descs.find(cur_parent);
            if (pit != g_persistent_class_descs.end()) {
                if (p.name && pit->second->registered_property_names.count(p.name) > 0) {
                    already_in_ancestor = true;
                    break;
                }
                cur_parent = pit->second->parent_name;
            } else {
                break;
            }
        }
        if (already_in_ancestor) {
            continue;
        }

        ScopedString hint_str(p.hint_string ? p.hint_string : "");
        GDExtensionPropertyInfo pinfo = {};
        pinfo.type = (GDExtensionVariantType)p.variant_type;
        pinfo.name = make_string_name(p.name);
        pinfo.class_name = make_string_name(p.type_name ? p.type_name : "");
        pinfo.hint = p.hint;
        pinfo.hint_string = hint_str;
        pinfo.usage = p.usage ? p.usage : 6; // PROPERTY_USAGE_DEFAULT

        void *setter_sn = make_string_name("");
        void *getter_sn = make_string_name("");

        gd_classdb_register_extension_class_property(g_library, class_sn, &pinfo, setter_sn, getter_sn);

        free_string_name(pinfo.name);
        free_string_name(pinfo.class_name);
        free_string_name(setter_sn);
        free_string_name(getter_sn);

        if (pcd && p.name) pcd->registered_property_names.insert(p.name);
    }

    // --- Segment 5: Signal Registration ---
    for (int i = 0; i < desc->signal_count; i++) {
        const CrystalSignalDesc &s = desc->signals[i];
        if (pcd && s.name && pcd->registered_signal_names.count(s.name) > 0) {
            continue;
        }

        // Prevent duplicate registration of inherited signals on subclasses in ClassDB
        bool sig_already_in_ancestor = false;
        std::string cur_sig_parent = pcd ? pcd->parent_name : "";
        while (!cur_sig_parent.empty()) {
            auto pit = g_persistent_class_descs.find(cur_sig_parent);
            if (pit != g_persistent_class_descs.end()) {
                if (s.name && pit->second->registered_signal_names.count(s.name) > 0) {
                    sig_already_in_ancestor = true;
                    break;
                }
                cur_sig_parent = pit->second->parent_name;
            } else {
                break;
            }
        }
        if (sig_already_in_ancestor) {
            continue;
        }

        void *sig_sn = make_string_name(s.name);
        std::vector<GDExtensionPropertyInfo> sargs(s.arg_count);
        for (int a = 0; a < s.arg_count; a++) {
            sargs[a].type = (GDExtensionVariantType)s.args[a].variant_type;
            sargs[a].name = make_string_name(s.args[a].name);
            sargs[a].class_name = make_string_name("");
            sargs[a].hint = 0;
            sargs[a].hint_string = make_string("");
            sargs[a].usage = 6;
        }

        gd_classdb_register_extension_class_signal(g_library, class_sn, sig_sn, sargs.data(), s.arg_count);

        free_string_name(sig_sn);
        for (int a = 0; a < s.arg_count; a++) {
            free_string_name(sargs[a].name); free_string_name(sargs[a].class_name); free_string(sargs[a].hint_string);
        }

        if (pcd && s.name) pcd->registered_signal_names.insert(s.name);
    }

    // --- Segment 6: Integer & Enum Constant Registration ---
    if (gd_classdb_register_extension_class_integer_constant) {
        for (int i = 0; i < desc->constant_count; i++) {
            const CrystalConstantDesc &c = desc->constants[i];
            if (pcd && c.constant_name && pcd->registered_constant_names.count(c.constant_name) > 0) {
                continue;
            }
            void *enum_sn = make_string_name(c.enum_name ? c.enum_name : "");
            void *const_sn = make_string_name(c.constant_name ? c.constant_name : "");
            gd_classdb_register_extension_class_integer_constant(
                g_library,
                class_sn,
                enum_sn,
                const_sn,
                (GDExtensionInt)c.value,
                c.is_bitfield ? 1 : 0
            );
            free_string_name(enum_sn);
            free_string_name(const_sn);

            if (pcd && c.constant_name) pcd->registered_constant_names.insert(c.constant_name);
        }
    }

    // --- Segment 7: GodotChannel Method Registration & Class Tracking ---
    if (strcmp(desc->name, "GodotChannel") == 0) {
        register_channel_methods(class_sn);
    }

    char log_buf[128];
    snprintf(log_buf, sizeof(log_buf), "  [ClassDB] Registered %s < %s", desc->name, desc->parent_name);
    godot_log_verbose(log_buf);

    if (g_current_init_level == GDEXTENSION_INITIALIZATION_EDITOR || is_editor_class(desc)) {
        auto &vec = g_library_editor_classes[g_library];
        if (std::find(vec.begin(), vec.end(), std::string(desc->name)) == vec.end()) {
            vec.push_back(std::string(desc->name));
        }
    } else {
        auto &vec = g_library_scene_classes[g_library];
        if (std::find(vec.begin(), vec.end(), std::string(desc->name)) == vec.end()) {
            vec.push_back(std::string(desc->name));
        }
    }

    free_string_name(class_sn);
    free_string_name(parent_sn);
}

/**
 * Registers a Crystal class, all its exported properties, and all its signals with Godot ClassDB.
 *
 * Invariants & Lifecycle:
 * - Allocates or updates an address-invariant `PersistentClassDesc` structure in process memory.
 *   Even when `game.dll` is recompiled and reloaded, the persistent descriptor's heap address
 *   remains invariant, so Godot's ClassDB never references a dangling pointer.
 * - Re-links the parent-child class hierarchy DAG across reloads.
 * - If Godot is at SCENE level, defers editor-only classes to the EDITOR initialization level.
 *
 * @param p_desc Pointer to the CrystalClassDesc exported by the compiled Crystal DLL.
 * @return 1 on success; 0 on invalid parameters.
 *
 * Segments:
 * - Segment 1: Parameter validation and persistent descriptor allocation or update.
 * - Segment 2: Bidirectional parent-child DAG relinking.
 * - Segment 3: Engine pre-registration check.
 * - Segment 4: Deferral of editor-only classes when engine is still at SCENE level.
 * - Segment 5: Execution of `do_classdb_register`.
 */
inline int bridge_register_class(const CrystalClassDesc *p_desc) {
    // --- Segment 1: Parameter Validation & Persistent Descriptor Allocation/Update ---
    if (!p_desc || !p_desc->name || !g_library) return 0;

    std::string cname = p_desc->name;
    if (g_classes_registered_in_current_cycle.count(cname) > 0) {
        return 1;
    }

    auto it = g_persistent_class_descs.find(cname);
    bool is_our_class = (it != g_persistent_class_descs.end());
    PersistentClassDesc *pcd = nullptr;
    if (is_our_class) {
        // Class was registered previously. Update persistent descriptor in-place
        // so runtime dispatches invoke the newly compiled Crystal DLL.
        pcd = it->second;
        pcd->update_from(p_desc);
        if (s_is_reloading) {
            pcd->registered_property_names.clear();
            pcd->registered_signal_names.clear();
            pcd->registered_constant_names.clear();
        }
    } else {
        // Allocate persistent descriptor whose address will remain invariant for Godot ClassDB
        pcd = new PersistentClassDesc();
        pcd->update_from(p_desc);
        g_persistent_class_descs[cname] = pcd;
        g_all_registered_class_names.insert(cname);
    }

    // --- Segment 2: Bidirectional Parent-Child DAG Relinking ---
    // Link / Re-link parent_desc if parent is in the persistent map
    if (!pcd->parent_name.empty()) {
        auto pit = g_persistent_class_descs.find(pcd->parent_name);
        if (pit != g_persistent_class_descs.end()) {
            pcd->desc.parent_desc = &pit->second->desc;
        }
    }
    // Link / Re-link any children that inherit from this class
    for (auto &pair : g_persistent_class_descs) {
        if (pair.second != pcd && pair.second->parent_name == pcd->name) {
            pair.second->desc.parent_desc = &pcd->desc;
        }
    }

    // --- Segment 3: Engine Pre-Registration Duplicate Check ---
    if (!is_our_class && is_class_registered_in_engine(p_desc->name)) {
        char log_buf[256];
        snprintf(log_buf, sizeof(log_buf), "[CrystalBridge] Error: Class '%s' already registered by engine or another extension. Skipping duplicate registration.", p_desc->name);
        godot_log_warning(log_buf, nullptr, "bridge_register_class", __FILE__, __LINE__);
        return 0;
    }

    g_classes_registered_in_current_cycle.insert(cname);

    // --- Segment 4: Editor Class Safety & Conditional Registration ---
    if (is_editor_class(&pcd->desc)) {
        if (!is_editor_active()) {
            char log_buf[128];
            snprintf(log_buf, sizeof(log_buf), "  [ClassDB] Suppressing editor class %s in non-editor host", pcd->desc.name);
            godot_log_verbose(log_buf);
            return 1;
        }
        if (g_current_init_level < GDEXTENSION_INITIALIZATION_EDITOR && pcd->desc.parent_name && !is_class_registered_in_engine(pcd->desc.parent_name)) {
            char log_buf[128];
            snprintf(log_buf, sizeof(log_buf), "  [ClassDB] Deferring editor class %s < %s to EDITOR level", pcd->desc.name, pcd->desc.parent_name);
            godot_log_verbose(log_buf);
            bool already_deferred = false;
            for (const auto &dep : g_deferred_editor_classes) {
                if (dep.second && dep.second->name && strcmp(dep.second->name, pcd->desc.name) == 0) {
                    already_deferred = true;
                    break;
                }
            }
            if (!already_deferred) {
                g_deferred_editor_classes.push_back({g_library, &pcd->desc});
            }
            return 1;
        }
    }

    // --- Segment 5: Execution of ClassDB Registration ---
    do_classdb_register(&pcd->desc);
    return 1;
}

/**
 * Registers all editor-specific classes that were deferred during SCENE initialization.
 * Invoked when Godot reaches GDEXTENSION_INITIALIZATION_EDITOR level.
 */
inline void register_deferred_editor_classes() {
    if (!g_deferred_editor_classes.empty()) {
        godot_log_verbose("[CrystalBridge] Registering deferred Editor classes at EDITOR level...");
        for (auto &pair : g_deferred_editor_classes) {
            g_library = pair.first;
            do_classdb_register(pair.second);
        }
        g_deferred_editor_classes.clear();
    }
}
