#pragma once

#include "common.hpp"
#include "gdextension_api.hpp"
#include "bridge_types.hpp"
#include "gc_support.hpp"

/**
 * ==============================================================================
 * LibGodot - Method Dispatch, Variant Marshaling, and Custom Signals
 * ==============================================================================
 */

// ==============================================================================
// String & StringName Allocation Helpers
// ==============================================================================

static std::unordered_map<std::string, void*> s_string_name_cache;
static std::mutex s_string_name_mutex;

/** Allocates and initializes a heap-backed Godot StringName instance (interned) */
inline void* make_string_name(const char *name) {
    const char *k = name ? name : "";
    std::lock_guard<std::mutex> lock(s_string_name_mutex);
    auto it = s_string_name_cache.find(k);
    if (it != s_string_name_cache.end()) {
        return it->second;
    }
    void *sn = malloc(sizeof(void*));
    gd_string_name_new_with_utf8_chars(sn, k);
    s_string_name_cache[k] = sn;
    return sn;
}

/** Destroys and frees a heap-backed Godot StringName instance (no-op: interned for engine lifetime) */
inline void free_string_name(void *sn) {
    // StringNames are interned in s_string_name_cache for engine lifetime.
    (void)sn;
}

/** Cleans up all interned heap-backed Godot StringName instances at engine shutdown (no-op: engine lifetime) */
inline void bridge_cleanup_string_name_cache() {
    // StringNames are interned in Godot's static string pool for the process lifetime.
    // Calling gd_string_name_destroy on them causes "BUG: Unreferenced static string to 0" or use-after-free crashes.
    std::lock_guard<std::mutex> lock(s_string_name_mutex);
    s_string_name_cache.clear();
}

/** Allocates and initializes a heap-backed Godot String instance */
inline void* make_string(const char *str) {
    void *s = malloc(sizeof(void*));
    gd_string_new_with_utf8_chars(s, str ? str : "");
    return s;
}

/** Destroys and frees a heap-backed Godot String instance */
inline void free_string(void *s) {
    if (!s) return;
    if (gd_string_destroy) {
        gd_string_destroy(s);
    }
    free(s);
}

/**
 * RAII wrapper for an allocated heap-backed Godot String.
 *
 * Invariants & Lifecycle:
 * - Automatically destroys the underlying Godot String (`gd_string_destroy`) and frees allocated memory.
 * - Prevents copy construction to eliminate double-free errors.
 * - Supports move construction and move assignment for clean resource transfer across scopes.
 * - Provides implicit conversion to `void*` for passing directly to Godot GDExtension API functions.
 */
struct ScopedString {
    void *ptr;
    explicit ScopedString(const char *str) : ptr(make_string(str)) {}
    explicit ScopedString(void *p) : ptr(p) {}
    ~ScopedString() {
        if (ptr) {
            free_string(ptr);
            ptr = nullptr;
        }
    }
    operator void*() const { return ptr; }
    void* get() const { return ptr; }
    ScopedString(const ScopedString&) = delete;
    ScopedString& operator=(const ScopedString&) = delete;
    ScopedString(ScopedString&& other) noexcept : ptr(other.ptr) { other.ptr = nullptr; }
    ScopedString& operator=(ScopedString&& other) noexcept {
        if (this != &other) {
            if (ptr) free_string(ptr);
            ptr = other.ptr;
            other.ptr = nullptr;
        }
        return *this;
    }
};

/**
 * RAII wrapper for an interned Godot StringName instance.
 *
 * Invariants & Lifecycle:
 * - Manages an interned StringName pointer from `make_string_name`.
 * - Prevents copying while supporting move semantics for safe scope transfers.
 * - Automatically executes cleanup hooks on scope exit.
 */
struct ScopedStringName {
    void *ptr;
    explicit ScopedStringName(const char *name) : ptr(make_string_name(name)) {}
    explicit ScopedStringName(void *p) : ptr(p) {}
    ~ScopedStringName() {
        if (ptr) {
            free_string_name(ptr);
            ptr = nullptr;
        }
    }
    operator void*() const { return ptr; }
    void* get() const { return ptr; }
    ScopedStringName(const ScopedStringName&) = delete;
    ScopedStringName& operator=(const ScopedStringName&) = delete;
    ScopedStringName(ScopedStringName&& other) noexcept : ptr(other.ptr) { other.ptr = nullptr; }
    ScopedStringName& operator=(ScopedStringName&& other) noexcept {
        if (this != &other) {
            if (ptr) free_string_name(ptr);
            ptr = other.ptr;
            other.ptr = nullptr;
        }
        return *this;
    }
};

/** Allocates and initializes a heap-backed Godot NodePath instance */
inline void* make_nodepath(const char *path) {
    if (!gd_nodepath_from_string && gd_variant_get_ptr_constructor) {
        gd_nodepath_from_string = gd_variant_get_ptr_constructor(GDEXTENSION_VARIANT_TYPE_NODE_PATH, 2);
    }
    void *np = malloc(sizeof(void*));
    memset(np, 0, sizeof(void*));
    if (gd_nodepath_from_string) {
        void *gd_str = make_string(path ? path : "");
        const GDExtensionConstTypePtr cargs[1] = { gd_str };
        gd_nodepath_from_string(np, cargs);
        free_string(gd_str);
    }
    return np;
}

/** Destroys and frees a heap-backed Godot NodePath instance */
inline void free_nodepath(void *np) {
    if (!np) return;
    if (!gd_nodepath_destroy && gd_variant_get_ptr_destructor) {
        gd_nodepath_destroy = gd_variant_get_ptr_destructor(GDEXTENSION_VARIANT_TYPE_NODE_PATH);
    }
    if (gd_nodepath_destroy) {
        gd_nodepath_destroy(np);
    }
    free(np);
}

/** Converts a Godot StringName to a C string buffer */
inline bool string_name_to_cstr(GDExtensionConstStringNamePtr sn, char *out, size_t max_len) {
    if (!sn || !out || max_len == 0) return false;
    out[0] = '\0';
    if (!gd_string_from_string_name && gd_variant_get_ptr_constructor) {
        gd_string_from_string_name = gd_variant_get_ptr_constructor(GDEXTENSION_VARIANT_TYPE_STRING, 2);
    }
    if (gd_string_from_string_name && gd_string_to_utf8_chars) {
        alignas(void*) char gd_str[8] = {};
        const GDExtensionConstTypePtr args[1] = { sn };
        gd_string_from_string_name(gd_str, args);

        int64_t len = gd_string_to_utf8_chars(gd_str, out, max_len - 1);
        if (len >= 0 && len < (int64_t)max_len) {
            out[len] = '\0';
        } else {
            out[max_len - 1] = '\0';
        }
        if (gd_string_destroy) gd_string_destroy(gd_str);
        return true;
    }
    return false;
}

// ==============================================================================
// Variant & Object Marshaling Helpers
// ==============================================================================

/**
 * Extracts a native Godot Object pointer from a Variant buffer.
 *
 * Employs a 3-tier fallback strategy to guarantee robust Object unboxing across Godot minor versions:
 * - Segment 1: Type verification and Fast Path (`variant_get_internal_ptr_object`).
 * - Segment 2: Standard API Path (`get_variant_to_type_constructor` for GDEXTENSION_VARIANT_TYPE_OBJECT).
 * - Segment 3: Instance ID Fallback (`get_object_instance_id` + `get_instance_from_id` via ObjectDB).
 *
 * @param variant Pointer to the input Variant buffer.
 * @return GDExtensionObjectPtr native engine pointer, or nullptr if unboxing fails or object is dead.
 */
inline GDExtensionObjectPtr bridge_object_from_variant(const void *variant) {
    if (!variant) return nullptr;
    if (gd_variant_get_type && gd_variant_get_type((GDExtensionConstVariantPtr)variant) != GDEXTENSION_VARIANT_TYPE_OBJECT) {
        return nullptr;
    }

    // --- Segment 1: Fast Path (Direct Internal Pointer) ---
    if (gd_variant_get_internal_ptr_object) {
        void *internal_ptr = gd_variant_get_internal_ptr_object((GDExtensionVariantPtr)variant);
        if (internal_ptr) {
            GDExtensionObjectPtr obj = *(GDExtensionObjectPtr*)internal_ptr;
            if (obj) return obj;
        }
    }

    // --- Segment 2: Standard Type-from-Variant Constructor ---
    GDExtensionObjectPtr obj = nullptr;
    if (gd_get_variant_to_type_constructor) {
        GDExtensionTypeFromVariantConstructorFunc conv = gd_get_variant_to_type_constructor(GDEXTENSION_VARIANT_TYPE_OBJECT);
        if (conv) {
            conv(&obj, (GDExtensionVariantPtr)variant);
            if (obj) return obj;
        }
    }

    // --- Segment 3: ObjectDB Instance ID Resolution Fallback ---
    if (gd_variant_get_object_instance_id && gd_object_get_instance_from_id) {
        GDObjectInstanceID id = gd_variant_get_object_instance_id(variant);
        if (id != 0) {
            return gd_object_get_instance_from_id(id);
        }
    }
    return nullptr;
}

/**
 * Unboxes a Godot Variant into a raw C/Crystal destination buffer based on variant_type.
 *
 * @param variant_type Target Godot Variant type enum.
 * @param dst Destination buffer to receive unpacked typed bytes.
 * @param variant Source Godot Variant buffer.
 *
 * Segments:
 * - Segment 1: Object pointer unboxing via 3-tier `bridge_object_from_variant`.
 * - Segment 2: String conversion using thread-local ring buffer pool to avoid allocations.
 * - Segment 3: Strict type verification for Object targets.
 * - Segment 4: Generic GDExtension type converter fallback for POD math primitives.
 */
inline void bridge_type_from_variant(int variant_type, void *dst, const void *variant) {
    if (!variant || !dst) return;

    // --- Segment 1: Object Pointer Unboxing ---
    if (variant_type == GDEXTENSION_VARIANT_TYPE_OBJECT) {
        GDExtensionObjectPtr obj = bridge_object_from_variant(variant);
        memcpy(dst, &obj, sizeof(GDExtensionObjectPtr));
        return;
    }

    // --- Segment 2: Thread-Safe Ring Buffered String Unboxing ---
    if (variant_type == GDEXTENSION_VARIANT_TYPE_STRING) {
        static thread_local std::string s_type_str_pool[8];
        static thread_local size_t s_pool_idx = 0;
        size_t idx = (s_pool_idx++) % 8;
        std::string &s_type_str = s_type_str_pool[idx];
        s_type_str.clear();

        if (gd_string_to_utf8_chars && gd_get_variant_to_type_constructor) {
            alignas(void*) char gd_str[8] = {0};
            GDExtensionTypeFromVariantConstructorFunc conv = gd_get_variant_to_type_constructor(GDEXTENSION_VARIANT_TYPE_STRING);
            if (conv) {
                conv(gd_str, (GDExtensionVariantPtr)variant);
                int64_t len = gd_string_to_utf8_chars(gd_str, nullptr, 0);
                if (len > 0) {
                    s_type_str.resize(len, '\0');
                    gd_string_to_utf8_chars(gd_str, &s_type_str[0], len);
                }
            }
            if (gd_string_destroy) gd_string_destroy(gd_str);
        }
        *(const char**)dst = s_type_str.c_str();
        return;
    }

    // --- Segment 3: Object Type Guard ---
    if (variant_type == GDEXTENSION_VARIANT_TYPE_OBJECT && gd_variant_get_type) {
        GDExtensionVariantType actual_type = gd_variant_get_type((GDExtensionConstVariantPtr)variant);
        if (actual_type != GDEXTENSION_VARIANT_TYPE_OBJECT) {
            *(void**)dst = nullptr;
            return;
        }
    }

    // --- Segment 4: Generic GDExtension Type Converter Fallback ---
    if (gd_get_variant_to_type_constructor) {
        GDExtensionTypeFromVariantConstructorFunc conv = gd_get_variant_to_type_constructor((GDExtensionVariantType)variant_type);
        if (conv) {
            conv(dst, (GDExtensionVariantPtr)variant);
        }
    }
}

/**
 * Boxes a raw C/Crystal source buffer into a Godot Variant buffer.
 *
 * @param variant_type Source type identifier.
 * @param variant Destination Godot Variant buffer.
 * @param src Pointer to the source typed value.
 *
 * Segments:
 * - Segment 1: Parameter validation.
 * - Segment 2: String boxing via temporary Godot String and `gd_variant_from_string`.
 * - Segment 3: Generic Variant-from-type constructor dispatch for POD types.
 */
inline void bridge_variant_from_type(int variant_type, void *variant, const void *src) {
    // --- Segment 1: Parameter Validation ---
    if (!variant || !src) return;

    // --- Segment 2: String Boxing ---
    if (variant_type == GDEXTENSION_VARIANT_TYPE_STRING) {
        const char *s = *(const char**)src;
        void *gd_str = make_string(s ? s : "");
        if (gd_variant_from_string) {
            gd_variant_from_string(variant, gd_str);
        }
        if (gd_string_destroy) {
            gd_string_destroy(gd_str);
        }
        free(gd_str);
        return;
    }

    // --- Segment 3: Generic Type-to-Variant Constructor Dispatch ---
    if (gd_get_variant_from_type_constructor && variant && src) {
        GDExtensionVariantFromTypeConstructorFunc conv = gd_get_variant_from_type_constructor((GDExtensionVariantType)variant_type);
        if (conv) {
            conv(variant, (GDExtensionTypePtr)src);
        }
    }
}

// ==============================================================================
// Method Bind Lookup & Invocation Helpers
// ==============================================================================

inline GDExtensionObjectPtr bridge_get_singleton(const char *name) {
    if (!gd_global_get_singleton) return nullptr;
    void *sn = make_string_name(name);
    GDExtensionObjectPtr s = gd_global_get_singleton(sn);
    free_string_name(sn);
    return s;
}

inline GDExtensionMethodBindPtr bridge_get_method_bind(const char *class_name, const char *method_name, int64_t hash) {
    if (!gd_classdb_get_method_bind) return nullptr;
    void *c_sn = make_string_name(class_name);
    void *m_sn = make_string_name(method_name);
    GDExtensionMethodBindPtr mb = gd_classdb_get_method_bind(c_sn, m_sn, hash);
    free_string_name(c_sn); free_string_name(m_sn);
    return mb;
}

inline void bridge_method_bind_ptrcall(GDExtensionMethodBindPtr method_bind, GDExtensionObjectPtr instance, const void **args, void *ret) {
    if (gd_object_method_bind_ptrcall && method_bind) {
        gd_object_method_bind_ptrcall(method_bind, instance, args, ret);
    }
}

inline void bridge_method_bind_call(GDExtensionMethodBindPtr method_bind, GDExtensionObjectPtr instance, const GDExtensionConstVariantPtr *args, GDExtensionInt arg_count, GDExtensionVariantPtr ret, GDExtensionCallError *error) {
    if (gd_object_method_bind_call && method_bind) {
        gd_object_method_bind_call(method_bind, instance, args, arg_count, ret, error);
    }
}

// ==============================================================================
// Dynamic Vararg Invocation & Signal Dispatch
// ==============================================================================

/**
 * Calls a Godot vararg method bind with a StringName first argument (such as emit_signal)
 * and an arbitrary list of typed signal/method arguments.
 *
 * @param mb Pointer to Godot's GDExtensionMethodBindPtr.
 * @param instance Target native Godot Object pointer.
 * @param first_arg_name First argument string (typically signal or method name).
 * @param args Array of typed BridgeSignalArg structs.
 * @param arg_count Number of arguments in the args array.
 *
 * Segments:
 * - Segment 1: Parameter validation and StringName boxing for first_arg_name.
 * - Segment 2: Vararg packing into stack-allocated Variant array (up to 16 arguments).
 * - Segment 3: Object method invocation via gd_object_method_bind_call.
 * - Segment 4: Variant buffer destruction and memory cleanup.
 */
inline void bridge_call_method_vararg(GDExtensionMethodBindPtr mb, GDExtensionObjectPtr instance, const char *first_arg_name, const BridgeSignalArg *args, int arg_count) {
    // --- Segment 1: Validation & StringName Boxing ---
    if (!instance || !first_arg_name || !mb || !gd_object_method_bind_call) return;

    if (!gd_variant_from_string_name && gd_get_variant_from_type_constructor) {
        gd_variant_from_string_name = gd_get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME);
    }

    void *sn = make_string_name(first_arg_name);
    alignas(void*) char var_first_arg[24];
    memset(var_first_arg, 0, sizeof(var_first_arg));
    if (gd_variant_from_string_name) {
        gd_variant_from_string_name(var_first_arg, sn);
    }

    // --- Segment 2: Vararg Variant Packing ---
    alignas(void*) char var_args[16][24];
    const void *call_args[17];
    call_args[0] = var_first_arg;

    int actual_count = (args && arg_count > 0) ? ((arg_count < 16) ? arg_count : 16) : 0;
    for (int i = 0; i < actual_count; i++) {
        memset(var_args[i], 0, sizeof(var_args[i]));
        int t = args[i].arg_type;
        const void *d = args[i].data;
        if (d) {
            if (t == 1) { // bool
                uint8_t val = *(const uint8_t*)d;
                GDExtensionVariantFromTypeConstructorFunc conv = gd_get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_BOOL);
                if (conv) conv(var_args[i], &val);
            } else if (t == 2) { // int64
                int64_t val = *(const int64_t*)d;
                GDExtensionVariantFromTypeConstructorFunc conv = gd_get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_INT);
                if (conv) conv(var_args[i], &val);
            } else if (t == 3) { // double
                double val = *(const double*)d;
                GDExtensionVariantFromTypeConstructorFunc conv = gd_get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_FLOAT);
                if (conv) conv(var_args[i], &val);
            } else if (t == 4) { // string
                void *gd_str = make_string((const char*)d);
                if (gd_variant_from_string) gd_variant_from_string(var_args[i], gd_str);
                if (gd_string_destroy) gd_string_destroy(gd_str);
                free(gd_str);
            } else if (t == 5) { // Vector2
                GDExtensionVariantFromTypeConstructorFunc conv = gd_get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_VECTOR2);
                if (conv) conv(var_args[i], (GDExtensionTypePtr)d);
            } else if (t == 6) { // Vector3
                GDExtensionVariantFromTypeConstructorFunc conv = gd_get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_VECTOR3);
                if (conv) conv(var_args[i], (GDExtensionTypePtr)d);
            } else if (t == 7) { // Object*
                GDExtensionVariantFromTypeConstructorFunc conv = gd_get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_OBJECT);
                if (conv) conv(var_args[i], (GDExtensionTypePtr)d);
            } else if (t == 8) { // Color
                GDExtensionVariantFromTypeConstructorFunc conv = gd_get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_COLOR);
                if (conv) conv(var_args[i], (GDExtensionTypePtr)d);
            }
        }
        call_args[i + 1] = var_args[i];
    }

    // --- Segment 3: Object Method Dispatch ---
    alignas(void*) char var_ret[24];
    memset(var_ret, 0, sizeof(var_ret));
    GDExtensionCallError call_err;
    gd_object_method_bind_call(mb, instance, (const GDExtensionConstVariantPtr*)call_args, actual_count + 1, var_ret, &call_err);

    // --- Segment 4: Memory Cleanup ---
    if (gd_variant_destroy) {
        gd_variant_destroy(var_ret);
        for (int i = 0; i < actual_count; i++) {
            gd_variant_destroy(var_args[i]);
        }
        gd_variant_destroy(var_first_arg);
    }
    free_string_name(sn);
}

inline void bridge_call_method_vararg_ret(GDExtensionMethodBindPtr mb, GDExtensionObjectPtr instance, const char *first_arg_name, const BridgeSignalArg *args, int arg_count, void *r_ret_variant) {
    if (!instance || !first_arg_name || !mb || !gd_object_method_bind_call) return;

    if (!gd_variant_from_string_name && gd_get_variant_from_type_constructor) {
        gd_variant_from_string_name = gd_get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME);
    }

    void *sn = make_string_name(first_arg_name);
    alignas(void*) char var_first_arg[24];
    memset(var_first_arg, 0, sizeof(var_first_arg));
    if (gd_variant_from_string_name) {
        gd_variant_from_string_name(var_first_arg, sn);
    }

    alignas(void*) char var_args[16][24];
    const void *call_args[17];
    call_args[0] = var_first_arg;

    int actual_count = (args && arg_count > 0) ? ((arg_count < 16) ? arg_count : 16) : 0;
    for (int i = 0; i < actual_count; i++) {
        memset(var_args[i], 0, sizeof(var_args[i]));
        int t = args[i].arg_type;
        const void *d = args[i].data;
        if (d) {
            if (t == 1) { // bool
                uint8_t val = *(const uint8_t*)d;
                GDExtensionVariantFromTypeConstructorFunc conv = gd_get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_BOOL);
                if (conv) conv(var_args[i], &val);
            } else if (t == 2) { // int64
                int64_t val = *(const int64_t*)d;
                GDExtensionVariantFromTypeConstructorFunc conv = gd_get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_INT);
                if (conv) conv(var_args[i], &val);
            } else if (t == 3) { // double
                double val = *(const double*)d;
                GDExtensionVariantFromTypeConstructorFunc conv = gd_get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_FLOAT);
                if (conv) conv(var_args[i], &val);
            } else if (t == 4) { // string
                void *gd_str = make_string((const char*)d);
                if (gd_variant_from_string) gd_variant_from_string(var_args[i], gd_str);
                if (gd_string_destroy) gd_string_destroy(gd_str);
                free(gd_str);
            } else if (t == 5) { // Vector2
                GDExtensionVariantFromTypeConstructorFunc conv = gd_get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_VECTOR2);
                if (conv) conv(var_args[i], (GDExtensionTypePtr)d);
            } else if (t == 6) { // Vector3
                GDExtensionVariantFromTypeConstructorFunc conv = gd_get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_VECTOR3);
                if (conv) conv(var_args[i], (GDExtensionTypePtr)d);
            } else if (t == 7) { // Object*
                GDExtensionVariantFromTypeConstructorFunc conv = gd_get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_OBJECT);
                if (conv) conv(var_args[i], (GDExtensionTypePtr)d);
            } else if (t == 8) { // Color
                GDExtensionVariantFromTypeConstructorFunc conv = gd_get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_COLOR);
                if (conv) conv(var_args[i], (GDExtensionTypePtr)d);
            }
        }
        call_args[i + 1] = var_args[i];
    }

    alignas(void*) char var_ret[24];
    memset(var_ret, 0, sizeof(var_ret));
    GDExtensionCallError call_err;
    gd_object_method_bind_call(mb, instance, (const GDExtensionConstVariantPtr*)call_args, actual_count + 1, var_ret, &call_err);

    if (r_ret_variant) {
        memcpy(r_ret_variant, var_ret, 24);
    } else if (gd_variant_destroy) {
        gd_variant_destroy(var_ret);
    }

    if (gd_variant_destroy) {
        for (int i = 0; i < actual_count; i++) {
            gd_variant_destroy(var_args[i]);
        }
        gd_variant_destroy(var_first_arg);
    }
    free_string_name(sn);
}

inline GDExtensionObjectPtr bridge_classdb_construct_object(const char *class_name) {
    if (!gd_classdb_construct_object || !class_name) return nullptr;
    void *sn = make_string_name(class_name);
    GDExtensionObjectPtr obj = gd_classdb_construct_object(sn);
    free_string_name(sn);
    return obj;
}

inline void bridge_object_destroy(GDExtensionObjectPtr p_o) {
    if (!p_o) return;
    if (gd_object_destroy) {
        gd_object_destroy(p_o);
    }
}

inline int64_t bridge_object_call_ret_int(GDExtensionObjectPtr instance, const char *method_name, const BridgeSignalArg *args, int arg_count);

inline uint64_t bridge_object_get_instance_id(GDExtensionConstObjectPtr p_o) {
    if (!p_o) return 0;
    uint64_t id = 0;
    if (gd_object_get_instance_id) {
        id = (uint64_t)gd_object_get_instance_id(p_o);
    }
    if (id != 0) return id;

    // Strategy 2: Extract instance ID from Variant representation
    if (gd_variant_get_object_instance_id && gd_get_variant_from_type_constructor) {
        alignas(void*) char var_obj[24] = {0};
        GDExtensionObjectPtr obj_ptr = (GDExtensionObjectPtr)p_o;
        bridge_variant_from_type(GDEXTENSION_VARIANT_TYPE_OBJECT, var_obj, &obj_ptr);
        id = (uint64_t)gd_variant_get_object_instance_id(var_obj);
        if (gd_variant_destroy) gd_variant_destroy(var_obj);
    }
    if (id != 0) return id;

    // Strategy 3: Fast ptrcall
    if (gd_classdb_get_method_bind && gd_object_method_bind_ptrcall) {
        if (!mb_object_get_instance_id) {
            void *sn_obj = make_string_name("Object");
            void *sn_gid = make_string_name("get_instance_id");
            mb_object_get_instance_id = gd_classdb_get_method_bind(sn_obj, sn_gid, 3905245786ULL);
            free_string_name(sn_obj); free_string_name(sn_gid);
        }
        if (mb_object_get_instance_id) {
            int64_t ret_id = 0;
            gd_object_method_bind_ptrcall(mb_object_get_instance_id, (GDExtensionObjectPtr)p_o, nullptr, &ret_id);
            id = (uint64_t)ret_id;
        }
    }
    if (id != 0) return id;

    // Strategy 4: Dynamic Object::call("get_instance_id")
    id = (uint64_t)bridge_object_call_ret_int((GDExtensionObjectPtr)p_o, "get_instance_id", nullptr, 0);
    return id;
}

inline GDExtensionObjectPtr bridge_object_get_instance_from_id(uint64_t id) {
    if (id == 0) return nullptr;
    if (gd_object_get_instance_from_id) {
        GDExtensionObjectPtr ptr = gd_object_get_instance_from_id((GDObjectInstanceID)id);
        if (ptr) return ptr;
    }
    if (!gd_util_instance_from_id && gd_variant_get_ptr_utility_function && gd_string_name_new_with_utf8_chars) {
        void *sn_ifi = make_string_name("instance_from_id");
        gd_util_instance_from_id = gd_variant_get_ptr_utility_function(sn_ifi, 1156694636ULL);
        free_string_name(sn_ifi);
    }
    if (gd_util_instance_from_id) {
        GDExtensionObjectPtr ret_obj = nullptr;
        int64_t id_i64 = (int64_t)id;
        const void *args[1] = { &id_i64 };
        gd_util_instance_from_id(&ret_obj, (const GDExtensionConstTypePtr*)args, 1);
        return ret_obj;
    }
    return nullptr;
}

inline uint8_t bridge_is_instance_valid(uint64_t id) {
    if (id == 0) return 0;
    if (gd_object_get_instance_from_id && gd_object_get_instance_from_id((GDObjectInstanceID)id) != nullptr) {
        return 1;
    }
    if (!gd_util_is_instance_id_valid && gd_variant_get_ptr_utility_function && gd_string_name_new_with_utf8_chars) {
        void *sn_iiiv = make_string_name("is_instance_id_valid");
        gd_util_is_instance_id_valid = gd_variant_get_ptr_utility_function(sn_iiiv, 2232439758ULL);
        free_string_name(sn_iiiv);
    }
    if (gd_util_is_instance_id_valid) {
        uint8_t is_valid = 0;
        int64_t id_i64 = (int64_t)id;
        const void *args[1] = { &id_i64 };
        gd_util_is_instance_id_valid(&is_valid, (const GDExtensionConstTypePtr*)args, 1);
        return is_valid != 0 ? 1 : 0;
    }
    return 0;
}

inline void bridge_object_emit_signal(GDExtensionObjectPtr instance, const char *signal_name, const BridgeSignalArg *args, int arg_count) {
    if (!instance || !signal_name || !gd_classdb_get_method_bind || !gd_object_method_bind_call) return;
    if (!mb_object_emit_signal) {
        mb_object_emit_signal = bridge_get_method_bind("Object", "emit_signal", 4047867050ULL);
    }
    if (!mb_object_emit_signal) return;
    bridge_call_method_vararg(mb_object_emit_signal, instance, signal_name, args, arg_count);
}

inline void bridge_object_call_deferred(GDExtensionObjectPtr instance, const char *method_name, const BridgeSignalArg *args, int arg_count) {
    if (!instance || !method_name || !gd_classdb_get_method_bind || !gd_object_method_bind_call) return;
    if (!mb_object_call_deferred) {
        mb_object_call_deferred = bridge_get_method_bind("Object", "call_deferred", 3400424181ULL);
    }
    if (!mb_object_call_deferred) return;
    bridge_call_method_vararg(mb_object_call_deferred, instance, method_name, args, arg_count);
}

inline void bridge_object_call(GDExtensionObjectPtr instance, const char *method_name, const BridgeSignalArg *args, int arg_count) {
    if (!instance || !method_name || !gd_classdb_get_method_bind || !gd_object_method_bind_call) return;
    if (!mb_object_call) {
        mb_object_call = bridge_get_method_bind("Object", "call", 3400424181ULL);
    }
    if (!mb_object_call) return;
    bridge_call_method_vararg(mb_object_call, instance, method_name, args, arg_count);
}

inline bool bridge_is_object_refcounted(GDExtensionObjectPtr obj) {
    if (!obj || !gd_classdb_get_method_bind || !gd_object_method_bind_ptrcall) return false;
    if (!mb_object_is_class) {
        mb_object_is_class = bridge_get_method_bind("Object", "is_class", 2619796661ULL);
    }
    if (!mb_object_is_class) return false;
    void *str_rc = make_string("RefCounted");
    const void *args[1] = { str_rc };
    uint8_t is_rc = 0;
    gd_object_method_bind_ptrcall(mb_object_is_class, obj, (const GDExtensionConstTypePtr*)args, &is_rc);
    free_string(str_rc);
    return is_rc != 0;
}

inline GDExtensionObjectPtr bridge_object_call_ret_object(GDExtensionObjectPtr instance, const char *method_name, const BridgeSignalArg *args, int arg_count) {
    if (!instance || !method_name || !gd_classdb_get_method_bind || !gd_object_method_bind_call) return nullptr;
    if (!mb_object_call) {
        mb_object_call = bridge_get_method_bind("Object", "call", 3400424181ULL);
    }
    if (!mb_object_call) return nullptr;

    alignas(void*) char var_ret[24] = {0};
    bridge_call_method_vararg_ret(mb_object_call, instance, method_name, args, arg_count, var_ret);

    GDExtensionObjectPtr ret_obj = bridge_object_from_variant(var_ret);
    if (ret_obj && bridge_is_object_refcounted(ret_obj)) {
        if (!mb_refcounted_reference) {
            mb_refcounted_reference = bridge_get_method_bind("RefCounted", "reference", 2240911060ULL);
        }
        if (mb_refcounted_reference && gd_object_method_bind_ptrcall) {
            uint8_t success = 0;
            gd_object_method_bind_ptrcall(mb_refcounted_reference, ret_obj, nullptr, &success);
        }
    }
    if (gd_variant_destroy) gd_variant_destroy(var_ret);
    return ret_obj;
}

template <typename T, GDExtensionVariantType VType>
inline T bridge_object_call_ret_pod(GDExtensionObjectPtr instance, const char *method_name, const BridgeSignalArg *args, int arg_count, T default_val = T{}) {
    if (!instance || !method_name || !gd_classdb_get_method_bind || !gd_object_method_bind_call) return default_val;
    if (!mb_object_call) {
        mb_object_call = bridge_get_method_bind("Object", "call", 3400424181ULL);
    }
    if (!mb_object_call) return default_val;

    alignas(void*) char var_ret[24] = {0};
    bridge_call_method_vararg_ret(mb_object_call, instance, method_name, args, arg_count, var_ret);

    T ret_val = default_val;
    bridge_type_from_variant(VType, &ret_val, var_ret);
    if (gd_variant_destroy) gd_variant_destroy(var_ret);
    return ret_val;
}

inline int64_t bridge_object_call_ret_int(GDExtensionObjectPtr instance, const char *method_name, const BridgeSignalArg *args, int arg_count) {
    return bridge_object_call_ret_pod<int64_t, GDEXTENSION_VARIANT_TYPE_INT>(instance, method_name, args, arg_count, (int64_t)0);
}

inline double bridge_object_call_ret_float(GDExtensionObjectPtr instance, const char *method_name, const BridgeSignalArg *args, int arg_count) {
    return bridge_object_call_ret_pod<double, GDEXTENSION_VARIANT_TYPE_FLOAT>(instance, method_name, args, arg_count, 0.0);
}

inline bool bridge_object_call_ret_bool(GDExtensionObjectPtr instance, const char *method_name, const BridgeSignalArg *args = nullptr, int arg_count = 0) {
    uint8_t ret = bridge_object_call_ret_pod<uint8_t, GDEXTENSION_VARIANT_TYPE_BOOL>(instance, method_name, args, arg_count, (uint8_t)0);
    return ret != 0;
}

inline const char* bridge_object_call_ret_string(GDExtensionObjectPtr instance, const char *method_name, const BridgeSignalArg *args = nullptr, int arg_count = 0) {
    static thread_local std::string s_call_str_storage;
    s_call_str_storage.clear();
    if (!instance || !method_name || !gd_classdb_get_method_bind || !gd_object_method_bind_call) return "";
    if (!mb_object_call) {
        mb_object_call = bridge_get_method_bind("Object", "call", 3400424181ULL);
    }
    if (!mb_object_call) return "";

    alignas(void*) char var_ret[24] = {0};
    bridge_call_method_vararg_ret(mb_object_call, instance, method_name, args, arg_count, var_ret);

    if (gd_variant_stringify && gd_string_to_utf8_chars) {
        alignas(void*) char gd_str[8] = {0};
        gd_variant_stringify(var_ret, gd_str);
        int64_t len = gd_string_to_utf8_chars(gd_str, nullptr, 0);
        if (len > 0) {
            s_call_str_storage.resize((size_t)len);
            gd_string_to_utf8_chars(gd_str, &s_call_str_storage[0], len);
        }
        if (gd_string_destroy) gd_string_destroy(gd_str);
    }
    if (gd_variant_destroy) gd_variant_destroy(var_ret);
    return s_call_str_storage.c_str();
}

// ==============================================================================
// High-Level Node Tree, Scene & Resource Helpers
// ==============================================================================

inline GDExtensionObjectPtr bridge_node_find_child(GDExtensionObjectPtr node, const char *pattern, bool recursive, bool owned) {
    if (!node || !pattern || !gd_classdb_get_method_bind || !gd_object_method_bind_ptrcall) return nullptr;
    if (!mb_node_find_child) {
        mb_node_find_child = bridge_get_method_bind("Node", "find_child", 2008217037ULL);
    }
    if (!mb_node_find_child) return nullptr;

    void *gd_str = make_string(pattern);
    uint8_t rec = recursive ? 1 : 0;
    uint8_t own = owned ? 1 : 0;
    const void *args[3] = { gd_str, &rec, &own };
    GDExtensionObjectPtr ret_node = nullptr;
    gd_object_method_bind_ptrcall(mb_node_find_child, node, args, &ret_node);

    free_string(gd_str);
    return ret_node;
}

inline GDExtensionObjectPtr bridge_node_get_node(GDExtensionObjectPtr node, const char *path) {
    if (!node || !path || !gd_classdb_get_method_bind) return nullptr;
    if (!mb_node_get_node) {
        mb_node_get_node = bridge_get_method_bind("Node", "get_node_or_null", 2734337346ULL);
    }
    if (!mb_node_get_node) return nullptr;

    if (gd_object_method_bind_ptrcall) {
        void *np = make_nodepath(path);
        const void *args[1] = { np };
        GDExtensionObjectPtr ret_node = nullptr;
        gd_object_method_bind_ptrcall(mb_node_get_node, node, args, &ret_node);
        free_nodepath(np);
        return ret_node;
    }

    if (gd_object_method_bind_call && gd_variant_from_string) {
        void *gd_str = make_string(path);
        alignas(void*) char var_str[24] = {};
        alignas(void*) char var_ret[24] = {};
        gd_variant_from_string(var_str, gd_str);

        const void *call_args[1] = { var_str };
        GDExtensionCallError call_err;
        gd_object_method_bind_call(mb_node_get_node, node, (const GDExtensionConstVariantPtr*)call_args, 1, var_ret, &call_err);

        GDExtensionObjectPtr ret_node = bridge_object_from_variant(var_ret);

        if (gd_variant_destroy) {
            gd_variant_destroy(var_str);
            gd_variant_destroy(var_ret);
        }
        free_string(gd_str);
        return ret_node;
    }

    return nullptr;
}

inline void bridge_range_set_value(GDExtensionObjectPtr range_obj, double value) {
    if (!range_obj || !gd_classdb_get_method_bind || !gd_object_method_bind_ptrcall) return;
    if (!mb_range_set_value) {
        mb_range_set_value = bridge_get_method_bind("Range", "set_value", 373806689ULL);
    }
    if (mb_range_set_value) {
        const void *args[1] = { &value };
        gd_object_method_bind_ptrcall(mb_range_set_value, range_obj, args, nullptr);
    }
}

inline void bridge_node_rpc_config(GDExtensionObjectPtr node, const char *method, int rpc_mode, int transfer_mode, bool call_local, int channel) {
    (void)rpc_mode; (void)transfer_mode; (void)call_local; (void)channel;
    if (!node || !method || !gd_classdb_get_method_bind || !gd_object_method_bind_ptrcall) return;
    if (!mb_node_rpc_config) {
        mb_node_rpc_config = bridge_get_method_bind("Node", "rpc_config", 3776071444ULL);
    }
    if (!mb_node_rpc_config) return;

    void *m_sn = make_string_name(method);
    alignas(void*) char var_config[24];
    memset(var_config, 0, sizeof(var_config));

    // Call Node.rpc_config(method, config)
    const void *args[2] = { m_sn, var_config };
    gd_object_method_bind_ptrcall(mb_node_rpc_config, node, args, nullptr);

    free_string_name(m_sn);
}

inline GDExtensionObjectPtr bridge_resource_loader_load(const char *path, const char *type_hint, int64_t cache_mode) {
    if (!path || !gd_classdb_get_method_bind || !gd_object_method_bind_call) return nullptr;
    GDExtensionObjectPtr res_loader = bridge_get_singleton("ResourceLoader");
    if (!res_loader) return nullptr;

    if (!mb_res_loader_load) {
        mb_res_loader_load = bridge_get_method_bind("ResourceLoader", "load", 3358495409ULL);
    }
    if (!mb_res_loader_load) return nullptr;

    alignas(void*) char var_path[24] = {};
    alignas(void*) char var_type[24] = {};
    alignas(void*) char var_cache[24] = {};
    alignas(void*) char var_ret[24] = {};

    void *gd_path = make_string(path);
    if (gd_variant_from_string) gd_variant_from_string(var_path, gd_path);

    void *gd_type = make_string(type_hint ? type_hint : "");
    if (gd_variant_from_string) gd_variant_from_string(var_type, gd_type);

    if (gd_get_variant_from_type_constructor) {
        GDExtensionVariantFromTypeConstructorFunc conv = gd_get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_INT);
        if (conv) conv(var_cache, &cache_mode);
    }

    const void *call_args[3] = { var_path, var_type, var_cache };
    GDExtensionCallError call_err;
    gd_object_method_bind_call(mb_res_loader_load, res_loader, (const GDExtensionConstVariantPtr*)call_args, 3, var_ret, &call_err);

    GDExtensionObjectPtr ret_obj = nullptr;
    bridge_type_from_variant(GDEXTENSION_VARIANT_TYPE_OBJECT, &ret_obj, var_ret);

    if (ret_obj && !mb_refcounted_reference) {
        mb_refcounted_reference = bridge_get_method_bind("RefCounted", "reference", 2240911060ULL);
    }
    if (ret_obj && mb_refcounted_reference && gd_object_method_bind_ptrcall) {
        uint8_t success = 0;
        gd_object_method_bind_ptrcall(mb_refcounted_reference, ret_obj, nullptr, &success);
    }

    if (gd_variant_destroy) {
        gd_variant_destroy(var_path);
        gd_variant_destroy(var_type);
        gd_variant_destroy(var_cache);
        gd_variant_destroy(var_ret);
    }
    free_string(gd_path);
    free_string(gd_type);

    return ret_obj;
}

inline GDExtensionObjectPtr bridge_packed_scene_instantiate(GDExtensionObjectPtr scene, int64_t edit_state) {
    if (!scene || !gd_classdb_get_method_bind) return nullptr;
    if (!mb_packed_scene_instantiate) {
        mb_packed_scene_instantiate = bridge_get_method_bind("PackedScene", "instantiate", 2628778455ULL);
    }
    if (!mb_packed_scene_instantiate) return nullptr;

    if (gd_object_method_bind_ptrcall) {
        int32_t state_i32 = (int32_t)edit_state;
        const void *args[1] = { &state_i32 };
        GDExtensionObjectPtr ret_node = nullptr;
        gd_object_method_bind_ptrcall(mb_packed_scene_instantiate, scene, args, &ret_node);
        if (ret_node) return ret_node;
    }

    if (gd_object_method_bind_call) {
        alignas(void*) char var_edit[24] = {};
        alignas(void*) char var_ret[24] = {};

        if (gd_get_variant_from_type_constructor) {
            GDExtensionVariantFromTypeConstructorFunc conv = gd_get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_INT);
            if (conv) conv(var_edit, &edit_state);
        }

        const void *call_args[1] = { var_edit };
        GDExtensionCallError call_err;
        gd_object_method_bind_call(mb_packed_scene_instantiate, scene, (const GDExtensionConstVariantPtr*)call_args, 1, var_ret, &call_err);

        GDExtensionObjectPtr ret_node = bridge_object_from_variant(var_ret);

        if (gd_variant_destroy) {
            gd_variant_destroy(var_edit);
            gd_variant_destroy(var_ret);
        }

        return ret_node;
    }

    return nullptr;
}

inline const char* bridge_node_get_name(GDExtensionObjectPtr node) {
    if (!node || !gd_classdb_get_method_bind || !gd_object_method_bind_ptrcall) return "";
    if (!mb_node_get_name) {
        mb_node_get_name = bridge_get_method_bind("Node", "get_name", 2002593661ULL);
    }
    if (!mb_node_get_name) return "";

    alignas(void*) char sn_buf[8] = {};
    gd_object_method_bind_ptrcall(mb_node_get_name, node, nullptr, sn_buf);

    static thread_local char s_name_buf[256];
    s_name_buf[0] = '\0';

    if (!gd_string_from_string_name && gd_variant_get_ptr_constructor) {
        gd_string_from_string_name = gd_variant_get_ptr_constructor(GDEXTENSION_VARIANT_TYPE_STRING, 2);
    }

    if (gd_string_from_string_name && gd_string_to_utf8_chars) {
        alignas(void*) char gd_str[8] = {};
        const GDExtensionConstTypePtr args[1] = { sn_buf };
        gd_string_from_string_name(gd_str, args);

        int64_t len = gd_string_to_utf8_chars(gd_str, s_name_buf, sizeof(s_name_buf) - 1);
        if (len >= 0 && len < (int64_t)sizeof(s_name_buf)) {
            s_name_buf[len] = '\0';
        }

        if (gd_string_destroy) gd_string_destroy(gd_str);
    } else if (gd_variant_stringify && gd_string_to_utf8_chars) {
        alignas(void*) char var_sn[24] = {};
        alignas(void*) char gd_str[8] = {};
        bridge_variant_from_type(GDEXTENSION_VARIANT_TYPE_STRING_NAME, var_sn, sn_buf);
        gd_variant_stringify(var_sn, gd_str);

        int64_t len = gd_string_to_utf8_chars(gd_str, s_name_buf, sizeof(s_name_buf) - 1);
        if (len >= 0 && len < (int64_t)sizeof(s_name_buf)) {
            s_name_buf[len] = '\0';
        }

        if (gd_string_destroy) gd_string_destroy(gd_str);
        if (gd_variant_destroy) gd_variant_destroy(var_sn);
    }

    return s_name_buf;
}

// ==============================================================================
// Virtual Call Return and Argument Marshalling Helpers
// ==============================================================================

inline void bridge_ret_string(void *r_ret, const char *str) {
    if (!r_ret) return;
    if (gd_string_new_with_utf8_chars) {
        gd_string_new_with_utf8_chars(r_ret, str ? str : "");
    }
}

inline void bridge_ret_string_name(void *r_ret, const char *str) {
    if (!r_ret) return;
    if (gd_string_name_new_with_utf8_chars) {
        gd_string_name_new_with_utf8_chars(r_ret, str ? str : "");
    }
}

inline void bridge_ret_packed_string_array(void *r_ret, const char **strings, int count) {
    if (!r_ret) return;
    if (!gd_packed_string_array_append && gd_variant_get_ptr_builtin_method) {
        void *sn_append = make_string_name("append");
        gd_packed_string_array_append = gd_variant_get_ptr_builtin_method(GDEXTENSION_VARIANT_TYPE_PACKED_STRING_ARRAY, sn_append, 816187996ULL);
        free_string_name(sn_append);
        if (!gd_packed_string_array_append) {
            void *sn_push_back = make_string_name("push_back");
            gd_packed_string_array_append = gd_variant_get_ptr_builtin_method(GDEXTENSION_VARIANT_TYPE_PACKED_STRING_ARRAY, sn_push_back, 816187996ULL);
            free_string_name(sn_push_back);
        }
    }
    if (gd_packed_string_array_append && strings) {
        for (int i = 0; i < count; i++) {
            alignas(void*) char gd_str[32] = {};
            if (gd_string_new_with_utf8_chars) {
                gd_string_new_with_utf8_chars(gd_str, strings[i] ? strings[i] : "");
            }
            const GDExtensionConstTypePtr args[1] = { gd_str };
            alignas(void*) uint8_t append_ret = 0;
            gd_packed_string_array_append(r_ret, args, &append_ret, 1);
            if (gd_string_destroy) gd_string_destroy(gd_str);
        }
    }
}

inline void bridge_ret_dictionary_empty(void *r_ret) {
    if (!r_ret) return;
    // In Godot virtual method calls (GDVIRTUAL_CALL) and ptrcalls, r_ret points to a container
    // already default-constructed on the caller's stack (e.g. Dictionary).
    // Invoking gd_dictionary_constructor with placement-new overwrites the existing instance and leaks DictionaryPrivate.
    // The caller's stack container is already empty by default.
}

inline void bridge_ret_array_empty(void *r_ret) {
    if (!r_ret) return;
    // In Godot virtual method calls (GDVIRTUAL_CALL) and ptrcalls, r_ret points to a container
    // already default-constructed on the caller's stack (e.g. Array or TypedArray).
    // Invoking gd_array_constructor with placement-new overwrites the existing instance, leaks ArrayPrivate,
    // and corrupts TypedArray typing metadata, causing ACCESS_VIOLATION crashes on return.
    // The caller's stack container is already empty by default.
}

inline void bridge_ret_object(void *r_ret, void *obj) {
    if (!r_ret) return;
    *(GDExtensionObjectPtr*)r_ret = (GDExtensionObjectPtr)obj;
}

static GDExtensionMethodBindPtr mb_ref_reference = nullptr;
inline void refcounted_reference(void *obj) {
    if (!obj) return;
    if (!mb_ref_reference && gd_classdb_get_method_bind) {
        void *class_sn = make_string_name("RefCounted");
        void *method_sn = make_string_name("reference");
        mb_ref_reference = gd_classdb_get_method_bind(class_sn, method_sn, 2240911060LL);
        free_string_name(class_sn);
        free_string_name(method_sn);
    }
    if (mb_ref_reference && gd_object_method_bind_ptrcall) {
        uint8_t ret = 0;
        gd_object_method_bind_ptrcall(mb_ref_reference, obj, nullptr, &ret);
    }
}

inline void bridge_ret_ref(void *r_ret, void *obj) {
    if (!r_ret) return;
    if (!obj) {
        *(void**)r_ret = nullptr;
        return;
    }
    if (gd_ref_set_object) {
        gd_ref_set_object((GDExtensionRefPtr)r_ret, (GDExtensionObjectPtr)obj);
    }
    if (*(void**)r_ret == nullptr) {
        refcounted_reference(obj);
        *(void**)r_ret = obj;
    }
}

inline bool bridge_object_is_class(GDExtensionObjectPtr obj, const char *class_name);

static GDExtensionMethodBindPtr mb_ref_init_ref = nullptr;
inline void refcounted_init_ref(void *obj) {
    if (!obj) return;
    if (!mb_ref_init_ref && gd_classdb_get_method_bind) {
        void *class_sn = make_string_name("RefCounted");
        void *method_sn = make_string_name("init_ref");
        mb_ref_init_ref = gd_classdb_get_method_bind(class_sn, method_sn, 2240911060ULL);
        free_string_name(class_sn);
        free_string_name(method_sn);
    }
    if (mb_ref_init_ref && gd_object_method_bind_ptrcall) {
        uint8_t ret = 0;
        gd_object_method_bind_ptrcall(mb_ref_init_ref, obj, nullptr, &ret);
    }
}

inline void bridge_ret_variant_object(void *r_ret, void *obj) {
    if (!r_ret) return;
    if (obj && bridge_object_is_class(obj, "RefCounted")) {
        refcounted_init_ref(obj);
    }
    bridge_variant_from_type(GDEXTENSION_VARIANT_TYPE_OBJECT, r_ret, &obj);
}

inline void bridge_ret_variant_nil(void *r_ret) {
    if (!r_ret) return;
    memset(r_ret, 0, 24);
}

inline bool has_cr_extension(const char *path) {
    if (!path) return false;
    size_t len = strlen(path);
    if (len >= 3 && (path[len - 3] == '.' && (path[len - 2] == 'c' || path[len - 2] == 'C') && (path[len - 1] == 'r' || path[len - 1] == 'R'))) {
        return true;
    }
    return false;
}

inline bool bridge_object_is_class(GDExtensionObjectPtr obj, const char *class_name);

static GDExtensionMethodBindPtr mb_resource_get_path = nullptr;
inline const char* bridge_resource_get_path(GDExtensionObjectPtr res) {
    static thread_local std::string s_path_buf;
    s_path_buf.clear();
    if (!res || !gd_classdb_get_method_bind || !gd_object_method_bind_ptrcall) return "";
    if (!bridge_object_is_class(res, "Resource")) return "";
    if (!mb_resource_get_path) {
        void *sn_res = make_string_name("Resource");
        void *sn_gp = make_string_name("get_path");
        mb_resource_get_path = gd_classdb_get_method_bind(sn_res, sn_gp, 201670096ULL);
        free_string_name(sn_res); free_string_name(sn_gp);
    }
    if (!mb_resource_get_path) return "";

    alignas(void*) char gd_str[8] = {0};
    gd_object_method_bind_ptrcall(mb_resource_get_path, res, nullptr, gd_str);
    if (gd_string_to_utf8_chars) {
        int64_t len = gd_string_to_utf8_chars(gd_str, nullptr, 0);
        if (len > 0) {
            s_path_buf.resize((size_t)len);
            gd_string_to_utf8_chars(gd_str, &s_path_buf[0], len);
        }
    }
    if (gd_string_destroy) gd_string_destroy(gd_str);
    return s_path_buf.c_str();
}

inline bool bridge_object_is_class(GDExtensionObjectPtr obj, const char *class_name) {
    if (!obj || !class_name || !gd_classdb_get_method_bind || !gd_object_method_bind_ptrcall) return false;
    if (!mb_object_is_class) {
        void *sn_obj = make_string_name("Object");
        void *sn_ic = make_string_name("is_class");
        mb_object_is_class = gd_classdb_get_method_bind(sn_obj, sn_ic, 2619796661ULL);
        free_string_name(sn_obj); free_string_name(sn_ic);
    }
    if (!mb_object_is_class) return false;

    void *sn_cls = make_string_name(class_name);
    const void *args[1] = { sn_cls };
    uint8_t ret_val = 0;
    gd_object_method_bind_ptrcall(mb_object_is_class, obj, (const GDExtensionConstTypePtr*)args, &ret_val);
    free_string_name(sn_cls);
    return ret_val != 0;
}

inline void bridge_object_get_class_name(GDExtensionObjectPtr obj, char *buf, int max_len) {
    if (!obj || !buf || max_len <= 0) {
        if (buf && max_len > 0) buf[0] = '\0';
        return;
    }
    buf[0] = '\0';
    if (gd_object_get_class_name) {
        if (g_library) {
            alignas(void*) char sn[8] = {0};
            gd_object_get_class_name(obj, g_library, sn);
            string_name_to_cstr(sn, buf, (size_t)max_len);
            free_string_name(sn);
            if (buf[0] != '\0') return;
        }
        alignas(void*) char sn_core[8] = {0};
        gd_object_get_class_name(obj, nullptr, sn_core);
        string_name_to_cstr(sn_core, buf, (size_t)max_len);
        free_string_name(sn_core);
        return;
    }
    static GDExtensionMethodBindPtr mb_get_class = nullptr;
    if (!mb_get_class && gd_classdb_get_method_bind) {
        void *sn_obj = make_string_name("Object");
        void *sn_gc = make_string_name("get_class");
        mb_get_class = gd_classdb_get_method_bind(sn_obj, sn_gc, 201670096ULL);
        free_string_name(sn_obj); free_string_name(sn_gc);
    }
    if (mb_get_class && gd_object_method_bind_ptrcall) {
        alignas(void*) char ret_str[8] = {0};
        gd_object_method_bind_ptrcall(mb_get_class, obj, nullptr, ret_str);
        if (gd_string_to_utf8_chars) {
            gd_string_to_utf8_chars(ret_str, buf, (int64_t)max_len - 1);
        }
        if (gd_string_destroy) gd_string_destroy(ret_str);
    }
}

inline void* bridge_ref_get_object(const void *ref_ptr) {
    if (!ref_ptr) return nullptr;
    if (gd_ref_get_object) {
        return gd_ref_get_object((GDExtensionConstRefPtr)ref_ptr);
    }
    return *(void**)ref_ptr;
}

inline const char* bridge_script_get_source_code(GDExtensionObjectPtr script_obj) {
    static thread_local std::string s_src_storage;
    s_src_storage.clear();
    if (!script_obj) return "";

    GDExtensionObjectPtr target = script_obj;
    // Only attempt dereferencing if script_obj is not already a Script Object
    if (!bridge_object_is_class(target, "Script") && gd_ref_get_object) {
        void *deref = gd_ref_get_object((GDExtensionConstRefPtr)script_obj);
        if (deref && bridge_object_is_class((GDExtensionObjectPtr)deref, "Script")) {
            target = (GDExtensionObjectPtr)deref;
        }
    }

    if (!bridge_object_is_class(target, "Script")) {
        return "";
    }

    static GDExtensionMethodBindPtr mb_get_source_code = nullptr;
    if (!mb_get_source_code) {
        void *sn_script = make_string_name("Script");
        void *sn_get_src = make_string_name("get_source_code");
        mb_get_source_code = gd_classdb_get_method_bind(sn_script, sn_get_src, 201670096ULL);
        free_string_name(sn_script); free_string_name(sn_get_src);
    }
    if (mb_get_source_code && gd_object_method_bind_ptrcall && gd_string_to_utf8_chars) {
        alignas(void*) char gd_str[8] = {0};
        gd_object_method_bind_ptrcall(mb_get_source_code, target, nullptr, gd_str);
        int64_t len = gd_string_to_utf8_chars(gd_str, nullptr, 0);
        if (len > 0) {
            s_src_storage.resize((size_t)len);
            gd_string_to_utf8_chars(gd_str, &s_src_storage[0], len);
        }
        if (gd_string_destroy) gd_string_destroy(gd_str);
        return s_src_storage.c_str();
    }
    return "";
}

inline std::string bridge_globalize_path(const char *path) {
    if (!path || path[0] == '\0') return "";
    if (strncmp(path, "res://", 6) != 0 && strncmp(path, "user://", 7) != 0) {
        return std::string(path);
    }
    static GDExtensionMethodBindPtr mb_globalize = nullptr;
    static GDExtensionObjectPtr s_project_settings = nullptr;
    if (!mb_globalize) {
        void *sn_ps = make_string_name("ProjectSettings");
        void *sn_gp = make_string_name("globalize_path");
        mb_globalize = gd_classdb_get_method_bind(sn_ps, sn_gp, 3135753539ULL);
        if (gd_global_get_singleton) {
            s_project_settings = gd_global_get_singleton(sn_ps);
        }
        free_string_name(sn_ps); free_string_name(sn_gp);
    }
    if (mb_globalize && s_project_settings && gd_object_method_bind_ptrcall && gd_string_to_utf8_chars) {
        void *path_str = make_string(path);
        const void *args[1] = { path_str };
        alignas(void*) char gd_ret[8] = {0};
        gd_object_method_bind_ptrcall(mb_globalize, s_project_settings, (const GDExtensionConstTypePtr*)args, gd_ret);
        free_string(path_str);
        int64_t len = gd_string_to_utf8_chars(gd_ret, nullptr, 0);
        std::string res;
        if (len > 0) {
            res.resize((size_t)len);
            gd_string_to_utf8_chars(gd_ret, &res[0], len);
        }
        if (gd_string_destroy) gd_string_destroy(gd_ret);
        if (!res.empty()) return res;
    }
    return std::string(path + (strncmp(path, "res://", 6) == 0 ? 6 : 7));
}

inline void bridge_ensure_directory_for_file(const char *file_path) {
    if (!file_path || file_path[0] == '\0') return;
    std::string dir = file_path;
    size_t slash = dir.find_last_of("/\\");
    if (slash == std::string::npos) return;
    std::string dir_path = dir.substr(0, slash);

#if defined(_WIN32) || defined(_WIN64)
    char temp[1024];
    strncpy(temp, dir_path.c_str(), sizeof(temp) - 1);
    temp[sizeof(temp) - 1] = '\0';
    for (char *p = temp + 1; *p; p++) {
        if (*p == '/' || *p == '\\') {
            char c = *p;
            *p = '\0';
            CreateDirectoryA(temp, NULL);
            *p = c;
        }
    }
    CreateDirectoryA(temp, NULL);
#else
    char temp[1024];
    strncpy(temp, dir_path.c_str(), sizeof(temp) - 1);
    temp[sizeof(temp) - 1] = '\0';
    for (char *p = temp + 1; *p; p++) {
        if (*p == '/') {
            *p = '\0';
            mkdir(temp, 0755);
            *p = '/';
        }
    }
    mkdir(temp, 0755);
#endif
}

inline void bridge_highlighter_add_span(void *r_color_map, int64_t col, float r, float g, float b, float a) {
    if (!r_color_map) return;
    if (!gd_dict_keyed_setter && gd_variant_get_ptr_keyed_setter) {
        gd_dict_keyed_setter = gd_variant_get_ptr_keyed_setter(GDEXTENSION_VARIANT_TYPE_DICTIONARY);
    }
    if (!gd_dictionary_constructor && gd_variant_get_ptr_constructor) {
        gd_dictionary_constructor = gd_variant_get_ptr_constructor(GDEXTENSION_VARIANT_TYPE_DICTIONARY, 0);
    }
    if (!gd_dict_keyed_setter || !gd_dictionary_constructor) return;

    alignas(void*) char sub_dict[8] = {};
    gd_dictionary_constructor(sub_dict, nullptr);

    alignas(void*) char var_color_str[24] = {};
    const char *color_str = "color";
    bridge_variant_from_type(GDEXTENSION_VARIANT_TYPE_STRING, var_color_str, &color_str);

    alignas(void*) char var_color_sn[24] = {};
    void *sn_color = make_string_name("color");
    bridge_variant_from_type(GDEXTENSION_VARIANT_TYPE_STRING_NAME, var_color_sn, sn_color);
    free_string_name(sn_color);

    struct { float r, g, b, a; } color_val = { r, g, b, a };
    alignas(void*) char var_color_val[24] = {};
    bridge_variant_from_type(GDEXTENSION_VARIANT_TYPE_COLOR, var_color_val, &color_val);

    gd_dict_keyed_setter(sub_dict, var_color_str, var_color_val);
    gd_dict_keyed_setter(sub_dict, var_color_sn, var_color_val);

    alignas(void*) char var_col[24] = {};
    bridge_variant_from_type(GDEXTENSION_VARIANT_TYPE_INT, var_col, &col);

    alignas(void*) char var_sub_dict[24] = {};
    bridge_variant_from_type(GDEXTENSION_VARIANT_TYPE_DICTIONARY, var_sub_dict, sub_dict);

    gd_dict_keyed_setter(r_color_map, var_col, var_sub_dict);

    if (gd_variant_destroy) {
        gd_variant_destroy(var_color_str);
        gd_variant_destroy(var_color_sn);
        gd_variant_destroy(var_color_val);
        gd_variant_destroy(var_col);
        gd_variant_destroy(var_sub_dict);
    }
    static GDExtensionPtrDestructor gd_dict_destructor = nullptr;
    if (!gd_dict_destructor && gd_variant_get_ptr_destructor) {
        gd_dict_destructor = gd_variant_get_ptr_destructor(GDEXTENSION_VARIANT_TYPE_DICTIONARY);
    }
    if (gd_dict_destructor) {
        gd_dict_destructor(sub_dict);
    }
}

inline int bridge_arg_to_string(const void *arg, char *out, int max_len) {
    if (!arg || !gd_string_to_utf8_chars) return 0;
    int64_t total_len = gd_string_to_utf8_chars((GDExtensionConstStringPtr)arg, nullptr, 0);
    if (!out || max_len <= 0) {
        return (int)total_len;
    }
    out[0] = '\0';
    if (total_len <= 0) return 0;
    int64_t len = gd_string_to_utf8_chars((GDExtensionConstStringPtr)arg, out, max_len - 1);
    if (len >= 0 && len < (int64_t)max_len) {
        out[len] = '\0';
        return (int)len;
    } else {
        out[max_len - 1] = '\0';
        return max_len - 1;
    }
}

inline int bridge_arg_to_string_name(const void *arg, char *out, int max_len) {
    if (!arg || !out || max_len <= 0) return 0;
    out[0] = '\0';
    if (string_name_to_cstr((GDExtensionConstStringNamePtr)arg, out, max_len)) {
        return (int)strlen(out);
    }
    return 0;
}

inline void dict_set_variant(void *dict, const char *key_str, int var_type, const void *val_ptr) {
    if (!dict || !key_str) return;

    if (!gd_dict_keyed_setter && gd_variant_get_ptr_keyed_setter) {
        gd_dict_keyed_setter = gd_variant_get_ptr_keyed_setter(GDEXTENSION_VARIANT_TYPE_DICTIONARY);
    }
    if (!gd_dict_keyed_setter) return;

    alignas(void*) char var_key[24] = {};
    const char *k = key_str;
    bridge_variant_from_type(GDEXTENSION_VARIANT_TYPE_STRING, var_key, &k);

    alignas(void*) char var_val[24] = {};
    bridge_variant_from_type(var_type, var_val, val_ptr);

    gd_dict_keyed_setter(dict, var_key, var_val);

    if (gd_variant_destroy) {
        gd_variant_destroy(var_key);
        gd_variant_destroy(var_val);
    }
}

inline void bridge_ret_dictionary_validate(void *r_ret, uint8_t valid) {
    if (!r_ret) return;
    uint8_t v_bool = valid;
    dict_set_variant(r_ret, "valid", GDEXTENSION_VARIANT_TYPE_BOOL, &v_bool);
}

static GDExtensionPtrBuiltInMethod gd_array_push_back = nullptr;
static GDExtensionPtrDestructor gd_array_destructor = nullptr;
static GDExtensionPtrDestructor gd_dict_destructor = nullptr;

inline void bridge_ret_dictionary_complete_code(void *r_ret) {
    if (!r_ret) return;
    int64_t v_res = 0;
    dict_set_variant(r_ret, "result", GDEXTENSION_VARIANT_TYPE_INT, &v_res);
    uint8_t v_force = 0;
    dict_set_variant(r_ret, "force", GDEXTENSION_VARIANT_TYPE_BOOL, &v_force);
    const char *v_hint = "";
    dict_set_variant(r_ret, "call_hint", GDEXTENSION_VARIANT_TYPE_STRING, &v_hint);

    // Initialize an empty Array variant for "options" so Godot engine validation succeeds
    alignas(void*) char arr_options[24] = {};
    if (!gd_array_constructor && gd_variant_get_ptr_constructor) {
        gd_array_constructor = gd_variant_get_ptr_constructor(GDEXTENSION_VARIANT_TYPE_ARRAY, 0);
    }
    if (gd_array_constructor) {
        gd_array_constructor(arr_options, nullptr);
    }
    dict_set_variant(r_ret, "options", GDEXTENSION_VARIANT_TYPE_ARRAY, arr_options);
    if (!gd_array_destructor && gd_variant_get_ptr_destructor) {
        gd_array_destructor = gd_variant_get_ptr_destructor(GDEXTENSION_VARIANT_TYPE_ARRAY);
    }
    if (gd_array_destructor) {
        gd_array_destructor(arr_options);
    }
}

inline void bridge_ret_dictionary_complete_code_ex(
    void *r_ret,
    int64_t result,
    uint8_t force,
    const char *call_hint,
    const BridgeCompletionOption *options,
    int option_count
) {
    if (!r_ret) return;
    int64_t v_res = result;
    dict_set_variant(r_ret, "result", GDEXTENSION_VARIANT_TYPE_INT, &v_res);
    uint8_t v_force = force;
    dict_set_variant(r_ret, "force", GDEXTENSION_VARIANT_TYPE_BOOL, &v_force);
    const char *v_hint = call_hint ? call_hint : "";
    dict_set_variant(r_ret, "call_hint", GDEXTENSION_VARIANT_TYPE_STRING, &v_hint);

    // Initialize an empty Array for "options"
    alignas(void*) char arr_options[24] = {};
    if (!gd_array_constructor && gd_variant_get_ptr_constructor) {
        gd_array_constructor = gd_variant_get_ptr_constructor(GDEXTENSION_VARIANT_TYPE_ARRAY, 0);
    }
    if (gd_array_constructor) {
        gd_array_constructor(arr_options, nullptr);
    }

    if (!gd_array_push_back && gd_variant_get_ptr_builtin_method) {
        void *sn_pb = make_string_name("push_back");
        gd_array_push_back = gd_variant_get_ptr_builtin_method(GDEXTENSION_VARIANT_TYPE_ARRAY, sn_pb, 3316032543ULL);
        free_string_name(sn_pb);
    }

    if (!gd_dict_destructor && gd_variant_get_ptr_destructor) {
        gd_dict_destructor = gd_variant_get_ptr_destructor(GDEXTENSION_VARIANT_TYPE_DICTIONARY);
    }
    if (!gd_array_destructor && gd_variant_get_ptr_destructor) {
        gd_array_destructor = gd_variant_get_ptr_destructor(GDEXTENSION_VARIANT_TYPE_ARRAY);
    }

    if (gd_array_push_back && options && option_count > 0) {
        for (int i = 0; i < option_count; i++) {
            alignas(void*) char opt_dict[24] = {};
            if (!gd_dictionary_constructor && gd_variant_get_ptr_constructor) {
                gd_dictionary_constructor = gd_variant_get_ptr_constructor(GDEXTENSION_VARIANT_TYPE_DICTIONARY, 0);
            }
            if (gd_dictionary_constructor) {
                gd_dictionary_constructor(opt_dict, nullptr);
            }

            int64_t k = options[i].kind;
            dict_set_variant(opt_dict, "kind", GDEXTENSION_VARIANT_TYPE_INT, &k);

            const char *disp = options[i].display ? options[i].display : "";
            dict_set_variant(opt_dict, "display", GDEXTENSION_VARIANT_TYPE_STRING, &disp);
            dict_set_variant(opt_dict, "display_text", GDEXTENSION_VARIANT_TYPE_STRING, &disp);

            const char *ins = options[i].insert_text ? options[i].insert_text : disp;
            dict_set_variant(opt_dict, "insert_text", GDEXTENSION_VARIANT_TYPE_STRING, &ins);

            const char *def_val = options[i].default_value ? options[i].default_value : "";
            dict_set_variant(opt_dict, "default_value", GDEXTENSION_VARIANT_TYPE_STRING, &def_val);

            int64_t loc = options[i].location;
            dict_set_variant(opt_dict, "location", GDEXTENSION_VARIANT_TYPE_INT, &loc);

            float font_col[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
            dict_set_variant(opt_dict, "font_color", GDEXTENSION_VARIANT_TYPE_COLOR, font_col);

            GDExtensionObjectPtr icon_obj = nullptr;
            dict_set_variant(opt_dict, "icon", GDEXTENSION_VARIANT_TYPE_OBJECT, &icon_obj);

            // Box opt_dict (Dictionary) into a 24-byte Variant before passing to Array.push_back
            alignas(void*) char var_opt_dict[24] = {};
            bridge_variant_from_type(GDEXTENSION_VARIANT_TYPE_DICTIONARY, var_opt_dict, opt_dict);

            const GDExtensionConstTypePtr pb_args[1] = { var_opt_dict };
            alignas(void*) uint8_t pb_ret = 0;
            gd_array_push_back(arr_options, pb_args, &pb_ret, 1);

            if (gd_variant_destroy) {
                gd_variant_destroy(var_opt_dict);
            }
            if (!gd_dict_destructor && gd_variant_get_ptr_destructor) {
                gd_dict_destructor = gd_variant_get_ptr_destructor(GDEXTENSION_VARIANT_TYPE_DICTIONARY);
            }
            if (gd_dict_destructor) {
                gd_dict_destructor(opt_dict);
            }
        }
    }

    dict_set_variant(r_ret, "options", GDEXTENSION_VARIANT_TYPE_ARRAY, arr_options);

    if (gd_array_destructor) {
        gd_array_destructor(arr_options);
    }
}

inline void bridge_ret_dictionary_lookup_code(void *r_ret) {
    if (!r_ret) return;
    int64_t v_res = 2; // ERR_UNAVAILABLE
    dict_set_variant(r_ret, "result", GDEXTENSION_VARIANT_TYPE_INT, &v_res);
    int64_t v_type = 0;
    dict_set_variant(r_ret, "type", GDEXTENSION_VARIANT_TYPE_INT, &v_type);
}

inline void bridge_ret_dictionary_lookup_code_ex(
    void *r_ret,
    int64_t result,
    int64_t type,
    const char *class_name,
    const char *class_member,
    const char *description,
    const char *script_path,
    int64_t location
) {
    if (!r_ret) return;
    int64_t v_res = result;
    dict_set_variant(r_ret, "result", GDEXTENSION_VARIANT_TYPE_INT, &v_res);
    int64_t v_type = type;
    dict_set_variant(r_ret, "type", GDEXTENSION_VARIANT_TYPE_INT, &v_type);
    const char *cn = class_name ? class_name : "";
    dict_set_variant(r_ret, "class_name", GDEXTENSION_VARIANT_TYPE_STRING, &cn);
    const char *cm = class_member ? class_member : "";
    dict_set_variant(r_ret, "class_member", GDEXTENSION_VARIANT_TYPE_STRING, &cm);
    const char *desc = description ? description : "";
    dict_set_variant(r_ret, "description", GDEXTENSION_VARIANT_TYPE_STRING, &desc);
    const char *sp = script_path ? script_path : "";
    dict_set_variant(r_ret, "script_path", GDEXTENSION_VARIANT_TYPE_STRING, &sp);
    int64_t v_loc = location;
    dict_set_variant(r_ret, "location", GDEXTENSION_VARIANT_TYPE_INT, &v_loc);
}

inline void bridge_ret_dictionary_global_class(void *r_ret, const char *class_name, const char *base_type, const char *icon_path) {
    if (!r_ret) return;
    if (!class_name || class_name[0] == '\0') return;
    dict_set_variant(r_ret, "name", GDEXTENSION_VARIANT_TYPE_STRING, &class_name);
    const char *b_type = (base_type && base_type[0] != '\0') ? base_type : "Node";
    dict_set_variant(r_ret, "base_type", GDEXTENSION_VARIANT_TYPE_STRING, &b_type);
    const char *i_path = icon_path ? icon_path : "";
    dict_set_variant(r_ret, "icon_path", GDEXTENSION_VARIANT_TYPE_STRING, &i_path);
}

inline void bridge_ret_signal_list(void *r_ret, const struct CrystalSignalDesc *signals, int signal_count) {
    if (!r_ret) return;
    if (!signals || signal_count <= 0) return;

    if (!gd_dictionary_constructor && gd_variant_get_ptr_constructor) {
        gd_dictionary_constructor = gd_variant_get_ptr_constructor(GDEXTENSION_VARIANT_TYPE_DICTIONARY, 0);
    }
    if (!gd_array_constructor && gd_variant_get_ptr_constructor) {
        gd_array_constructor = gd_variant_get_ptr_constructor(GDEXTENSION_VARIANT_TYPE_ARRAY, 0);
    }
    if (!gd_array_push_back && gd_variant_get_ptr_builtin_method) {
        void *sn_pb = make_string_name("push_back");
        gd_array_push_back = gd_variant_get_ptr_builtin_method(GDEXTENSION_VARIANT_TYPE_ARRAY, sn_pb, 3316032543ULL);
        free_string_name(sn_pb);
    }
    if (!gd_dict_destructor && gd_variant_get_ptr_destructor) {
        gd_dict_destructor = gd_variant_get_ptr_destructor(GDEXTENSION_VARIANT_TYPE_DICTIONARY);
    }
    if (!gd_array_destructor && gd_variant_get_ptr_destructor) {
        gd_array_destructor = gd_variant_get_ptr_destructor(GDEXTENSION_VARIANT_TYPE_ARRAY);
    }

    if (!gd_array_push_back || !gd_dictionary_constructor || !gd_array_constructor) return;

    for (int i = 0; i < signal_count; i++) {
        alignas(void*) char sig_dict[24] = {};
        gd_dictionary_constructor(sig_dict, nullptr);

        const char *s_name = signals[i].name ? signals[i].name : "";
        dict_set_variant(sig_dict, "name", GDEXTENSION_VARIANT_TYPE_STRING, &s_name);

        int64_t s_flags = 1; // METHOD_FLAG_NORMAL
        dict_set_variant(sig_dict, "flags", GDEXTENSION_VARIANT_TYPE_INT, &s_flags);

        alignas(void*) char arr_args[24] = {};
        gd_array_constructor(arr_args, nullptr);

        if (signals[i].args && signals[i].arg_count > 0) {
            for (int j = 0; j < signals[i].arg_count; j++) {
                alignas(void*) char arg_dict[24] = {};
                gd_dictionary_constructor(arg_dict, nullptr);

                const char *a_name = signals[i].args[j].name ? signals[i].args[j].name : "";
                int64_t a_type = signals[i].args[j].variant_type;
                const char *empty_str = "";
                int64_t hint_val = 0;
                int64_t usage_val = 6; // PROPERTY_USAGE_DEFAULT

                dict_set_variant(arg_dict, "name", GDEXTENSION_VARIANT_TYPE_STRING, &a_name);
                dict_set_variant(arg_dict, "type", GDEXTENSION_VARIANT_TYPE_INT, &a_type);
                dict_set_variant(arg_dict, "class_name", GDEXTENSION_VARIANT_TYPE_STRING, &empty_str);
                dict_set_variant(arg_dict, "hint", GDEXTENSION_VARIANT_TYPE_INT, &hint_val);
                dict_set_variant(arg_dict, "hint_string", GDEXTENSION_VARIANT_TYPE_STRING, &empty_str);
                dict_set_variant(arg_dict, "usage", GDEXTENSION_VARIANT_TYPE_INT, &usage_val);

                alignas(void*) char var_arg_dict[24] = {};
                bridge_variant_from_type(GDEXTENSION_VARIANT_TYPE_DICTIONARY, var_arg_dict, arg_dict);

                const GDExtensionConstTypePtr pb_arg[1] = { var_arg_dict };
                alignas(void*) uint8_t pb_ret1 = 0;
                gd_array_push_back(arr_args, pb_arg, &pb_ret1, 1);

                if (gd_variant_destroy) gd_variant_destroy(var_arg_dict);
                if (gd_dict_destructor) gd_dict_destructor(arg_dict);
            }
        }

        dict_set_variant(sig_dict, "args", GDEXTENSION_VARIANT_TYPE_ARRAY, arr_args);
        if (gd_array_destructor) gd_array_destructor(arr_args);

        alignas(void*) char arr_defargs[24] = {};
        gd_array_constructor(arr_defargs, nullptr);
        dict_set_variant(sig_dict, "default_args", GDEXTENSION_VARIANT_TYPE_ARRAY, arr_defargs);
        if (gd_array_destructor) gd_array_destructor(arr_defargs);

        alignas(void*) char ret_dict[24] = {};
        gd_dictionary_constructor(ret_dict, nullptr);
        int64_t nil_type = 0; // Variant::NIL
        dict_set_variant(ret_dict, "type", GDEXTENSION_VARIANT_TYPE_INT, &nil_type);
        dict_set_variant(sig_dict, "return", GDEXTENSION_VARIANT_TYPE_DICTIONARY, ret_dict);
        if (gd_dict_destructor) gd_dict_destructor(ret_dict);

        alignas(void*) char var_sig_dict[24] = {};
        bridge_variant_from_type(GDEXTENSION_VARIANT_TYPE_DICTIONARY, var_sig_dict, sig_dict);

        const GDExtensionConstTypePtr pb_sig[1] = { var_sig_dict };
        alignas(void*) uint8_t pb_ret2 = 0;
        gd_array_push_back(r_ret, pb_sig, &pb_ret2, 1);

        if (gd_variant_destroy) gd_variant_destroy(var_sig_dict);
        if (gd_dict_destructor) gd_dict_destructor(sig_dict);
    }
}

inline void bridge_ret_property_list(void *r_ret, const struct CrystalPropertyDesc *props, int prop_count) {
    if (!r_ret) return;
    if (!props || prop_count <= 0) return;

    if (!gd_dictionary_constructor && gd_variant_get_ptr_constructor) {
        gd_dictionary_constructor = gd_variant_get_ptr_constructor(GDEXTENSION_VARIANT_TYPE_DICTIONARY, 0);
    }
    if (!gd_array_push_back && gd_variant_get_ptr_builtin_method) {
        void *sn_pb = make_string_name("push_back");
        gd_array_push_back = gd_variant_get_ptr_builtin_method(GDEXTENSION_VARIANT_TYPE_ARRAY, sn_pb, 3316032543ULL);
        free_string_name(sn_pb);
    }
    if (!gd_dict_destructor && gd_variant_get_ptr_destructor) {
        gd_dict_destructor = gd_variant_get_ptr_destructor(GDEXTENSION_VARIANT_TYPE_DICTIONARY);
    }

    if (!gd_array_push_back || !gd_dictionary_constructor) return;

    for (int i = 0; i < prop_count; i++) {
        alignas(void*) char prop_dict[24] = {};
        gd_dictionary_constructor(prop_dict, nullptr);

        const char *p_name = props[i].name ? props[i].name : "";
        int64_t p_type = props[i].variant_type;
        const char *p_class = (props[i].type_name && props[i].variant_type == GDEXTENSION_VARIANT_TYPE_OBJECT) ? props[i].type_name : "";
        int64_t p_hint = props[i].hint;
        const char *p_hint_str = props[i].hint_string ? props[i].hint_string : "";
        int64_t p_usage = props[i].usage != 0 ? props[i].usage : 6; // PROPERTY_USAGE_DEFAULT

        dict_set_variant(prop_dict, "name", GDEXTENSION_VARIANT_TYPE_STRING, &p_name);
        dict_set_variant(prop_dict, "type", GDEXTENSION_VARIANT_TYPE_INT, &p_type);
        dict_set_variant(prop_dict, "class_name", GDEXTENSION_VARIANT_TYPE_STRING, &p_class);
        dict_set_variant(prop_dict, "hint", GDEXTENSION_VARIANT_TYPE_INT, &p_hint);
        dict_set_variant(prop_dict, "hint_string", GDEXTENSION_VARIANT_TYPE_STRING, &p_hint_str);
        dict_set_variant(prop_dict, "usage", GDEXTENSION_VARIANT_TYPE_INT, &p_usage);

        alignas(void*) char var_prop_dict[24] = {};
        bridge_variant_from_type(GDEXTENSION_VARIANT_TYPE_DICTIONARY, var_prop_dict, prop_dict);

        const GDExtensionConstTypePtr pb_prop[1] = { var_prop_dict };
        alignas(void*) uint8_t pb_ret = 0;
        gd_array_push_back(r_ret, pb_prop, &pb_ret, 1);

        if (gd_variant_destroy) gd_variant_destroy(var_prop_dict);
        if (gd_dict_destructor) gd_dict_destructor(prop_dict);
    }
}

inline int bridge_text_edit_get_line(void *text_edit, int64_t line, char *out_buf, int max_len) {
    if (!text_edit || !out_buf || max_len <= 0) return 0;
    out_buf[0] = '\0';
    if (!mb_text_edit_get_line && gd_classdb_get_method_bind) {
        void *sn_te = make_string_name("TextEdit");
        void *sn_gl = make_string_name("get_line");
        mb_text_edit_get_line = gd_classdb_get_method_bind(sn_te, sn_gl, 844755477ULL);
        free_string_name(sn_te); free_string_name(sn_gl);
    }
    if (!mb_text_edit_get_line || !gd_object_method_bind_ptrcall) return 0;

    alignas(void*) char gd_str[8] = {};
    const void *args[1] = { &line };
    gd_object_method_bind_ptrcall(mb_text_edit_get_line, (GDExtensionObjectPtr)text_edit, args, gd_str);

    int ret_len = 0;
    if (gd_string_to_utf8_chars) {
        int64_t len = gd_string_to_utf8_chars(gd_str, out_buf, max_len - 1);
        if (len >= 0 && len < (int64_t)max_len) {
            out_buf[len] = '\0';
            ret_len = (int)len;
        } else {
            out_buf[max_len - 1] = '\0';
            ret_len = max_len - 1;
        }
    }
    if (gd_string_destroy) {
        gd_string_destroy(gd_str);
    }
    return ret_len;
}

inline void* bridge_placeholder_script_instance_create(void* p_language, void* p_script, const void* p_owner_arg) {
    if (!gd_placeholder_script_instance_create) return nullptr;
    GDExtensionObjectPtr owner = nullptr;
    if (p_owner_arg) {
        owner = *(GDExtensionObjectPtr*)p_owner_arg;
        if (!owner) {
            owner = (GDExtensionObjectPtr)p_owner_arg;
        }
    }
    return gd_placeholder_script_instance_create((GDExtensionObjectPtr)p_language, (GDExtensionObjectPtr)p_script, owner);
}

// ==============================================================================
// Native Signal Connection & Custom Callable Dispatcher
// ==============================================================================

struct CustomSignalBinding {
    uint64_t target_id;
    std::string signal_name;
};

static std::vector<CrystalSignalCallbackFn> g_crystal_signal_callbacks;
static std::unordered_map<GDExtensionClassLibraryPtr, std::vector<CrystalDeinitCallbackFn>> g_library_deinit_callbacks;
static CrystalCleanupCallbackFn s_debugger_cleanup_fn = nullptr;
static int g_loader_registered = 0;
static int g_saver_registered = 0;
static int g_language_registered = 0;
static GDExtensionObjectPtr g_language_object = nullptr;
static int s_is_reloading = 0;

/**
 * Callback invoked by Godot's Callable engine when an engine signal connected via
 * `bridge_object_connect_signal` fires. Unboxes Godot Variant arguments into C-ABI
 * `VariantArg` structs and dispatches them into registered Crystal callbacks.
 *
 * @param callable_userdata Pointer to the heap-allocated CustomSignalBinding struct.
 * @param p_args Array of pointers to input Variant arguments passed by Godot.
 * @param p_argument_count Number of arguments passed.
 * @param r_return Destination Variant buffer for return value (always Nil for signals).
 * @param r_error Call error indicator populated if invocation fails.
 *
 * Segments:
 * - Segment 1: GC Thread Registration, Call Error initialization, and UserData unpacking.
 * - Segment 2: Argument vector pre-allocation and type inspection.
 * - Segment 3: Scalar and string unmarshaling (Bool, Int, Float, String, StringName, NodePath).
 * - Segment 4: Math vectors, colors, and native Object unboxing (Vector2, Rect2, Vector3, Color, Object ID).
 * - Segment 5: Signal dispatch into registered Crystal signal callbacks (`g_crystal_signal_callbacks`).
 */
inline void custom_callable_call(void *callable_userdata, const GDExtensionConstVariantPtr *p_args, GDExtensionInt p_argument_count, GDExtensionVariantPtr r_return, GDExtensionCallError *r_error) {
    // --- Segment 1: Thread Registration & Status Initialization ---
    if (r_error) {
        r_error->error = GDEXTENSION_CALL_OK;
        r_error->argument = 0;
        r_error->expected = 0;
    }
    if (r_return && gd_variant_new_nil) {
        gd_variant_new_nil(r_return);
    }
    if (!callable_userdata) return;
    ensure_gc_thread_registered();
    CustomSignalBinding *binding = (CustomSignalBinding*)callable_userdata;
    if (g_crystal_signal_callbacks.empty()) return;

    // --- Segment 2: Argument Vector Pre-allocation ---
    int count = (int)p_argument_count;
    std::vector<std::string> str_storage;
    std::vector<VariantArg> variant_args;
    if (count > 0 && p_args) {
        variant_args.resize(count);
        str_storage.reserve(count);
        for (int i = 0; i < count; i++) {
            VariantArg &arg = variant_args[i];
            memset(&arg, 0, sizeof(VariantArg));
            if (!p_args[i]) {
                arg.type = 0; // Nil
                continue;
            }
            int vt = gd_variant_get_type ? (int)gd_variant_get_type((GDExtensionConstVariantPtr)p_args[i]) : 0;
            arg.type = vt;

            // --- Segment 3: Scalar & String Unmarshaling ---
            switch (vt) {
                case GDEXTENSION_VARIANT_TYPE_NIL:
                    break;
                case GDEXTENSION_VARIANT_TYPE_BOOL: {
                    uint8_t b = 0;
                    bridge_type_from_variant(GDEXTENSION_VARIANT_TYPE_BOOL, &b, p_args[i]);
                    arg.int_val = b ? 1 : 0;
                    arg.float_val = b ? 1.0 : 0.0;
                    break;
                }
                case GDEXTENSION_VARIANT_TYPE_INT: {
                    int64_t val = 0;
                    bridge_type_from_variant(GDEXTENSION_VARIANT_TYPE_INT, &val, p_args[i]);
                    arg.int_val = val;
                    arg.float_val = (double)val;
                    break;
                }
                case GDEXTENSION_VARIANT_TYPE_FLOAT: {
                    double val = 0.0;
                    bridge_type_from_variant(GDEXTENSION_VARIANT_TYPE_FLOAT, &val, p_args[i]);
                    arg.float_val = val;
                    arg.int_val = (int64_t)val;
                    break;
                }
                case GDEXTENSION_VARIANT_TYPE_STRING:
                case GDEXTENSION_VARIANT_TYPE_STRING_NAME:
                case GDEXTENSION_VARIANT_TYPE_NODE_PATH: {
                    if (gd_variant_stringify && gd_string_to_utf8_chars && gd_string_destroy) {
                        void *gd_str = malloc(sizeof(void*));
                        gd_variant_stringify((GDExtensionConstVariantPtr)p_args[i], gd_str);
                        GDExtensionInt len = gd_string_to_utf8_chars(gd_str, nullptr, 0);
                        std::string s(len, '\0');
                        gd_string_to_utf8_chars(gd_str, &s[0], len);
                        gd_string_destroy(gd_str);
                        free(gd_str);
                        str_storage.push_back(s);
                        arg.ptr_val = (void*)str_storage.back().c_str();
                    } else {
                        str_storage.push_back("");
                        arg.ptr_val = (void*)str_storage.back().c_str();
                    }
                    break;
                }
                // --- Segment 4: Math Vectors, Colors, and Native Object Unboxing ---
                case GDEXTENSION_VARIANT_TYPE_VECTOR2: {
                    struct { float x, y; } v2 = {0, 0};
                    bridge_type_from_variant(GDEXTENSION_VARIANT_TYPE_VECTOR2, &v2, p_args[i]);
                    arg.vec_val[0] = v2.x;
                    arg.vec_val[1] = v2.y;
                    break;
                }
                case GDEXTENSION_VARIANT_TYPE_VECTOR2I: {
                    struct { int32_t x, y; } v2i = {0, 0};
                    bridge_type_from_variant(GDEXTENSION_VARIANT_TYPE_VECTOR2I, &v2i, p_args[i]);
                    arg.vec_val[0] = (float)v2i.x;
                    arg.vec_val[1] = (float)v2i.y;
                    arg.int_val = (int64_t)v2i.x;
                    arg.instance_id = (uint64_t)v2i.y;
                    break;
                }
                case GDEXTENSION_VARIANT_TYPE_RECT2: {
                    struct { float x, y, w, h; } r = {0, 0, 0, 0};
                    bridge_type_from_variant(GDEXTENSION_VARIANT_TYPE_RECT2, &r, p_args[i]);
                    arg.vec_val[0] = r.x;
                    arg.vec_val[1] = r.y;
                    arg.vec_val[2] = r.w;
                    arg.vec_val[3] = r.h;
                    break;
                }
                case GDEXTENSION_VARIANT_TYPE_VECTOR3: {
                    struct { float x, y, z; } v3 = {0, 0, 0};
                    bridge_type_from_variant(GDEXTENSION_VARIANT_TYPE_VECTOR3, &v3, p_args[i]);
                    arg.vec_val[0] = v3.x;
                    arg.vec_val[1] = v3.y;
                    arg.vec_val[2] = v3.z;
                    break;
                }
                case GDEXTENSION_VARIANT_TYPE_VECTOR3I: {
                    struct { int32_t x, y, z; } v3i = {0, 0, 0};
                    bridge_type_from_variant(GDEXTENSION_VARIANT_TYPE_VECTOR3I, &v3i, p_args[i]);
                    arg.vec_val[0] = (float)v3i.x;
                    arg.vec_val[1] = (float)v3i.y;
                    arg.vec_val[2] = (float)v3i.z;
                    break;
                }
                case GDEXTENSION_VARIANT_TYPE_COLOR: {
                    struct { float r, g, b, a; } col = {0, 0, 0, 0};
                    bridge_type_from_variant(GDEXTENSION_VARIANT_TYPE_COLOR, &col, p_args[i]);
                    arg.vec_val[0] = col.r;
                    arg.vec_val[1] = col.g;
                    arg.vec_val[2] = col.b;
                    arg.vec_val[3] = col.a;
                    break;
                }
                case GDEXTENSION_VARIANT_TYPE_OBJECT: {
                    GDExtensionObjectPtr obj = bridge_object_from_variant(p_args[i]);
                    arg.ptr_val = obj;
                    arg.instance_id = obj ? bridge_object_get_instance_id(obj) : 0;
                    break;
                }
                default: {
                    if (gd_variant_stringify && gd_string_to_utf8_chars && gd_string_destroy) {
                        void *gd_str = malloc(sizeof(void*));
                        gd_variant_stringify((GDExtensionConstVariantPtr)p_args[i], gd_str);
                        GDExtensionInt len = gd_string_to_utf8_chars(gd_str, nullptr, 0);
                        std::string s(len, '\0');
                        gd_string_to_utf8_chars(gd_str, &s[0], len);
                        gd_string_destroy(gd_str);
                        free(gd_str);
                        str_storage.push_back(s);
                        arg.ptr_val = (void*)str_storage.back().c_str();
                    } else {
                        str_storage.push_back("");
                        arg.ptr_val = (void*)str_storage.back().c_str();
                    }
                    break;
                }
            }
        }
    }

    // --- Segment 5: Signal Dispatch into Crystal Callbacks ---
    std::vector<CrystalSignalCallbackFn> callbacks = g_crystal_signal_callbacks;
    for (auto cb : callbacks) {
        if (cb) {
            cb(
                binding->target_id,
                binding->signal_name.c_str(),
                variant_args.empty() ? nullptr : variant_args.data(),
                count
            );
        }
    }
}

inline GDExtensionBool custom_callable_is_valid(void *callable_userdata) {
    if (!callable_userdata) return 0;
    return 1;
}

inline void custom_callable_free(void *callable_userdata) {
    if (callable_userdata) {
        delete (CustomSignalBinding*)callable_userdata;
    }
}

inline uint32_t custom_callable_hash(void *callable_userdata) {
    if (!callable_userdata) return 0;
    CustomSignalBinding *b = (CustomSignalBinding*)callable_userdata;
    uint32_t h = (uint32_t)(b->target_id ^ (b->target_id >> 32));
    for (char c : b->signal_name) {
        h = (h * 31) + (uint32_t)c;
    }
    return h;
}

inline GDExtensionBool custom_callable_equal(void *a, void *b) {
    if (a == b) return 1;
    if (!a || !b) return 0;
    CustomSignalBinding *ba = (CustomSignalBinding*)a;
    CustomSignalBinding *bb = (CustomSignalBinding*)b;
    return (ba->target_id == bb->target_id && ba->signal_name == bb->signal_name) ? 1 : 0;
}

inline GDExtensionBool custom_callable_less_than(void *a, void *b) {
    if (!a || !b) return 0;
    CustomSignalBinding *ba = (CustomSignalBinding*)a;
    CustomSignalBinding *bb = (CustomSignalBinding*)b;
    if (ba->target_id != bb->target_id) return ba->target_id < bb->target_id ? 1 : 0;
    return ba->signal_name < bb->signal_name ? 1 : 0;
}

inline void custom_callable_to_string(void *callable_userdata, GDExtensionBool *r_is_valid, GDExtensionStringPtr r_out) {
    (void)callable_userdata;
    if (r_is_valid) *r_is_valid = 1;
    if (gd_string_new_with_utf8_chars && r_out) {
        gd_string_new_with_utf8_chars(r_out, "CrystalSignalCallable");
    }
}

inline void bridge_register_signal_callback(CrystalSignalCallbackFn fn) {
    if (!fn) return;
    for (auto existing : g_crystal_signal_callbacks) {
        if (existing == fn) return;
    }
    g_crystal_signal_callbacks.push_back(fn);
}

inline void bridge_register_deinit_callback(CrystalDeinitCallbackFn fn) {
    if (!fn) return;
    auto &cbs = g_library_deinit_callbacks[g_library];
    for (auto existing : cbs) {
        if (existing == fn) return;
    }
    cbs.push_back(fn);
}

inline int bridge_is_loader_registered() { return g_loader_registered; }
inline void bridge_set_loader_registered(int r) { g_loader_registered = r; }
inline int bridge_is_saver_registered() { return g_saver_registered; }
inline void bridge_set_saver_registered(int r) { g_saver_registered = r; }
inline int bridge_is_language_registered() { return g_language_registered; }
inline void bridge_set_language_registered(int r) { g_language_registered = r; }
inline void* bridge_get_language_object() {
    if (g_language_object) return g_language_object;
    if (gd_global_get_singleton) {
        void *sn_engine = make_string_name("Engine");
        GDExtensionObjectPtr engine = gd_global_get_singleton(sn_engine);
        free_string_name(sn_engine);
        if (engine) {
            static GDExtensionMethodBindPtr mb_count = nullptr;
            static GDExtensionMethodBindPtr mb_get = nullptr;
            if (!mb_count) mb_count = bridge_get_method_bind("Engine", "get_script_language_count", 2455072627ULL);
            if (!mb_get) mb_get = bridge_get_method_bind("Engine", "get_script_language", 2151255799ULL);
            if (mb_count && mb_get) {
                int64_t count = 0;
                gd_object_method_bind_ptrcall(mb_count, engine, nullptr, &count);
                for (int64_t i = 0; i < count; i++) {
                    const void *args[1] = { &i };
                    GDExtensionObjectPtr lang = nullptr;
                    gd_object_method_bind_ptrcall(mb_get, engine, args, &lang);
                    if (lang) {
                        const char *ext = bridge_object_call_ret_string(lang, "get_extension");
                        if (ext && strcmp(ext, "cr") == 0) {
                            g_language_object = lang;
                            return lang;
                        }
                        const char *name = bridge_object_call_ret_string(lang, "get_name");
                        if (name && strcmp(name, "Crystal") == 0) {
                            g_language_object = lang;
                            return lang;
                        }
                        char class_name[128] = {0};
                        bridge_object_get_class_name(lang, class_name, sizeof(class_name));
                        if (strcmp(class_name, "CrystalLanguage") == 0) {
                            g_language_object = lang;
                            return lang;
                        }
                    }
                }
            }
        }
    }
    return nullptr;
}
inline void bridge_set_language_object(void *obj) { g_language_object = (GDExtensionObjectPtr)obj; }

inline void bridge_set_reloading(int reloading) { s_is_reloading = reloading; }

inline void bridge_set_debugger_cleanup(CrystalCleanupCallbackFn fn) {
    s_debugger_cleanup_fn = fn;
}

inline void bridge_trigger_debugger_cleanup() {
    if (s_debugger_cleanup_fn) {
        s_debugger_cleanup_fn();
    }
}

/**
 * Connects a native Godot engine signal to the Crystal CustomCallable bridge.
 *
 * @param instance Target native Godot Object pointer.
 * @param signal_name Signal name to connect to.
 * @param flags Godot ConnectFlags bitmask (e.g. CONNECT_DEFERRED, CONNECT_PERSIST).
 *
 * Segments:
 * - Segment 1: Parameter validation and Object instance ID resolution.
 * - Segment 2: Caching Object::connect, is_connected, disconnect, and has_signal method binds.
 * - Segment 3: Signal existence check via Object::has_signal.
 * - Segment 4: CustomCallable creation with CustomSignalBinding userdata and callback table.
 * - Segment 5: Duplicate check via Object::is_connected and connection execution.
 * - Segment 6: Temporary StringName and Callable buffer cleanup.
 */
inline void bridge_object_connect_signal(GDExtensionObjectPtr instance, const char *signal_name, uint32_t flags) {
    // --- Segment 1: Validation & Instance ID Resolution ---
    if (!instance || !signal_name || !gd_classdb_get_method_bind || !gd_object_method_bind_ptrcall) return;
    if (!gd_callable_custom_create2 && !gd_callable_custom_create) return;

    uint64_t target_id = bridge_object_get_instance_id(instance);
    if (target_id == 0) return;

    // --- Segment 2: Method Bind Caching ---
    if (!mb_object_connect) {
        void *sn_obj = make_string_name("Object");
        void *sn_conn = make_string_name("connect");
        mb_object_connect = gd_classdb_get_method_bind(sn_obj, sn_conn, 1518946055ULL);
        if (!mb_object_connect) {
            mb_object_connect = gd_classdb_get_method_bind(sn_obj, sn_conn, 1469446357ULL);
        }
        void *sn_is_conn = make_string_name("is_connected");
        mb_object_is_connected = gd_classdb_get_method_bind(sn_obj, sn_is_conn, 768136979ULL);
        void *sn_disconn = make_string_name("disconnect");
        mb_object_disconnect = gd_classdb_get_method_bind(sn_obj, sn_disconn, 1874754934ULL);
        void *sn_has_sig = make_string_name("has_signal");
        mb_object_has_signal = gd_classdb_get_method_bind(sn_obj, sn_has_sig, 2619796661ULL);

        free_string_name(sn_obj);
        free_string_name(sn_conn);
        free_string_name(sn_is_conn);
        free_string_name(sn_disconn);
        free_string_name(sn_has_sig);
    }
    if (!mb_object_connect) return;

    // --- Segment 3: Signal Existence Verification ---
    void *sn_sig = make_string_name(signal_name);

    if (mb_object_has_signal) {
        uint8_t signal_exists = 0;
        const void *has_args[1] = { sn_sig };
        gd_object_method_bind_ptrcall(mb_object_has_signal, instance, (GDExtensionConstTypePtr*)has_args, &signal_exists);
        if (!signal_exists) {
            free_string_name(sn_sig);
            return;
        }
    }

    // --- Segment 4: CustomCallable Construction ---
    CustomSignalBinding *binding = new CustomSignalBinding{ target_id, signal_name };
    alignas(void*) char callable_buf[32] = {0};

    if (gd_callable_custom_create2) {
        GDExtensionCallableCustomInfo2 info;
        memset(&info, 0, sizeof(info));
        info.callable_userdata = binding;
        info.token = g_library;
        info.object_id = 0;
        info.call_func = custom_callable_call;
        info.is_valid_func = nullptr;
        info.free_func = custom_callable_free;
        info.hash_func = custom_callable_hash;
        info.equal_func = custom_callable_equal;
        info.less_than_func = custom_callable_less_than;
        info.to_string_func = custom_callable_to_string;
        gd_callable_custom_create2(callable_buf, &info);
    } else {
        GDExtensionCallableCustomInfo info;
        memset(&info, 0, sizeof(info));
        info.callable_userdata = binding;
        info.token = g_library;
        info.object_id = 0;
        info.call_func = custom_callable_call;
        info.is_valid_func = nullptr;
        info.free_func = custom_callable_free;
        info.hash_func = custom_callable_hash;
        info.equal_func = custom_callable_equal;
        info.less_than_func = custom_callable_less_than;
        info.to_string_func = custom_callable_to_string;
        gd_callable_custom_create(callable_buf, &info);
    }

    // --- Segment 5: Duplicate Check & Signal Connection ---
    uint8_t already_connected = 0;
    if (mb_object_is_connected) {
        const void *check_args[2] = { sn_sig, callable_buf };
        gd_object_method_bind_ptrcall(mb_object_is_connected, instance, (GDExtensionConstTypePtr*)check_args, &already_connected);
    }

    if (!already_connected) {
        const void *conn_args[3] = { sn_sig, callable_buf, &flags };
        int64_t err = 0;
        gd_object_method_bind_ptrcall(mb_object_connect, instance, (GDExtensionConstTypePtr*)conn_args, &err);
    }

    // --- Segment 6: Temporary Resource Cleanup ---
    free_string_name(sn_sig);

    if (gd_callable_destroy) {
        gd_callable_destroy(callable_buf);
    }
}

/**
 * Disconnects a native Godot engine signal previously bound to Crystal CustomCallable.
 *
 * @param instance Target native Godot Object pointer.
 * @param signal_name Signal name to disconnect.
 *
 * Segments:
 * - Segment 1: Parameter validation and instance ID verification.
 * - Segment 2: Temporary Callable synthesis matching CustomSignalBinding hash/equal contract.
 * - Segment 3: Disconnection execution via Object::disconnect and cleanup.
 */
inline void bridge_object_disconnect_signal(GDExtensionObjectPtr instance, const char *signal_name) {
    // --- Segment 1: Parameter Validation ---
    if (!instance || !signal_name || !mb_object_disconnect || !gd_object_method_bind_ptrcall) return;
    uint64_t target_id = bridge_object_get_instance_id(instance);
    if (target_id == 0) return;

    // --- Segment 2: Temporary Callable Synthesis for Matching ---
    CustomSignalBinding temp_binding{ target_id, signal_name };
    alignas(void*) char callable_buf[32] = {0};
    if (gd_callable_custom_create2) {
        GDExtensionCallableCustomInfo2 info;
        memset(&info, 0, sizeof(info));
        info.callable_userdata = &temp_binding;
        info.token = g_library;
        info.object_id = 0;
        info.call_func = custom_callable_call;
        info.hash_func = custom_callable_hash;
        info.equal_func = custom_callable_equal;
        info.less_than_func = custom_callable_less_than;
        gd_callable_custom_create2(callable_buf, &info);
    } else if (gd_callable_custom_create) {
        GDExtensionCallableCustomInfo info;
        memset(&info, 0, sizeof(info));
        info.callable_userdata = &temp_binding;
        info.token = g_library;
        info.object_id = 0;
        info.call_func = custom_callable_call;
        info.hash_func = custom_callable_hash;
        info.equal_func = custom_callable_equal;
        info.less_than_func = custom_callable_less_than;
        gd_callable_custom_create(callable_buf, &info);
    }

    // --- Segment 3: Disconnection Execution & Cleanup ---
    void *sn_sig = make_string_name(signal_name);
    uint8_t is_conn = 0;
    if (mb_object_is_connected) {
        const void *check_args[2] = { sn_sig, callable_buf };
        gd_object_method_bind_ptrcall(mb_object_is_connected, instance, (GDExtensionConstTypePtr*)check_args, &is_conn);
    }
    if (is_conn) {
        const void *dis_args[2] = { sn_sig, callable_buf };
        gd_object_method_bind_ptrcall(mb_object_disconnect, instance, (GDExtensionConstTypePtr*)dis_args, nullptr);
    }
    free_string_name(sn_sig);
    if (gd_callable_destroy) {
        gd_callable_destroy(callable_buf);
    }
}

// ==============================================================================
// Tool Button Custom Callable Dispatcher
// ==============================================================================

struct ToolButtonBinding {
    GenericExtensionInstance *inst;
    uint64_t object_id;
    char prop_name[128];
};

inline void tool_button_custom_callable_call(
    void *callable_userdata,
    const GDExtensionConstVariantPtr *p_args,
    GDExtensionInt p_argument_count,
    GDExtensionVariantPtr r_return,
    GDExtensionCallError *r_error
) {
    if (r_error) {
        r_error->error = GDEXTENSION_CALL_OK;
        r_error->argument = 0;
        r_error->expected = 0;
    }
    if (r_return && gd_variant_new_nil) {
        gd_variant_new_nil(r_return);
    }
    if (!callable_userdata) return;
    ensure_gc_thread_registered();
    ToolButtonBinding *binding = (ToolButtonBinding*)callable_userdata;
    if (!binding->inst || !binding->inst->crystal_instance || !binding->inst->desc) return;

    // Check dead pointer / object alive
    if (gd_object_get_instance_from_id && binding->object_id != 0) {
        if (gd_object_get_instance_from_id((GDObjectInstanceID)binding->object_id) == nullptr) {
            return;
        }
    }

    if (binding->inst->desc->call_tool_button) {
        binding->inst->desc->call_tool_button(binding->inst->crystal_instance, binding->prop_name);
    }
}

inline GDExtensionBool tool_button_custom_callable_is_valid(void *callable_userdata) {
    if (!callable_userdata) return 0;
    ToolButtonBinding *b = (ToolButtonBinding*)callable_userdata;
    if (!b->inst || !b->inst->crystal_instance) return 0;
    if (gd_object_get_instance_from_id && b->object_id != 0) {
        if (gd_object_get_instance_from_id((GDObjectInstanceID)b->object_id) == nullptr) return 0;
    }
    return 1;
}

inline void tool_button_custom_callable_free(void *callable_userdata) {
    if (callable_userdata) {
        delete (ToolButtonBinding*)callable_userdata;
    }
}

inline uint32_t tool_button_custom_callable_hash(void *callable_userdata) {
    if (!callable_userdata) return 0;
    ToolButtonBinding *b = (ToolButtonBinding*)callable_userdata;
    uint32_t h = (uint32_t)(uintptr_t)b->inst;
    for (const char *p = b->prop_name; *p; p++) {
        h = (h * 31) + (uint8_t)*p;
    }
    return h;
}

inline GDExtensionBool tool_button_custom_callable_equal(void *a, void *b) {
    if (a == b) return 1;
    if (!a || !b) return 0;
    ToolButtonBinding *ba = (ToolButtonBinding*)a;
    ToolButtonBinding *bb = (ToolButtonBinding*)b;
    return (ba->inst == bb->inst && strcmp(ba->prop_name, bb->prop_name) == 0) ? 1 : 0;
}

inline GDExtensionBool tool_button_custom_callable_less_than(void *a, void *b) {
    if (!a || !b) return a < b;
    ToolButtonBinding *ba = (ToolButtonBinding*)a;
    ToolButtonBinding *bb = (ToolButtonBinding*)b;
    if (ba->inst != bb->inst) return ba->inst < bb->inst;
    return strcmp(ba->prop_name, bb->prop_name) < 0 ? 1 : 0;
}

inline void tool_button_custom_callable_to_string(void *callable_userdata, GDExtensionBool *r_is_valid, GDExtensionStringPtr r_out) {
    if (r_is_valid) *r_is_valid = (callable_userdata != nullptr);
    if (r_out && gd_string_new_with_utf8_chars) {
        gd_string_new_with_utf8_chars(r_out, "CrystalToolButtonCallable");
    }
}

inline void create_tool_button_callable(GenericExtensionInstance *inst, const char *prop_name, GDExtensionVariantPtr r_ret) {
    uint64_t obj_id = 0;
    if (gd_object_get_instance_id && inst->godot_object) {
        obj_id = (uint64_t)gd_object_get_instance_id(inst->godot_object);
    }
    ToolButtonBinding *binding = new ToolButtonBinding();
    binding->inst = inst;
    binding->object_id = obj_id;
    strncpy(binding->prop_name, prop_name, sizeof(binding->prop_name) - 1);
    binding->prop_name[sizeof(binding->prop_name) - 1] = '\0';

    alignas(void*) char callable_buf[32] = {0};

    if (gd_callable_custom_create2) {
        GDExtensionCallableCustomInfo2 info;
        memset(&info, 0, sizeof(info));
        info.callable_userdata = binding;
        info.token = g_library;
        info.object_id = (GDObjectInstanceID)obj_id;
        info.call_func = tool_button_custom_callable_call;
        info.is_valid_func = tool_button_custom_callable_is_valid;
        info.free_func = tool_button_custom_callable_free;
        info.hash_func = tool_button_custom_callable_hash;
        info.equal_func = tool_button_custom_callable_equal;
        info.less_than_func = tool_button_custom_callable_less_than;
        info.to_string_func = tool_button_custom_callable_to_string;
        gd_callable_custom_create2(callable_buf, &info);
    } else if (gd_callable_custom_create) {
        GDExtensionCallableCustomInfo info;
        memset(&info, 0, sizeof(info));
        info.callable_userdata = binding;
        info.token = g_library;
        info.object_id = (GDObjectInstanceID)obj_id;
        info.call_func = tool_button_custom_callable_call;
        info.is_valid_func = tool_button_custom_callable_is_valid;
        info.free_func = tool_button_custom_callable_free;
        info.hash_func = tool_button_custom_callable_hash;
        info.equal_func = tool_button_custom_callable_equal;
        info.less_than_func = tool_button_custom_callable_less_than;
        info.to_string_func = tool_button_custom_callable_to_string;
        gd_callable_custom_create(callable_buf, &info);
    }

    bridge_variant_from_type(GDEXTENSION_VARIANT_TYPE_CALLABLE, r_ret, callable_buf);
    if (gd_callable_destroy) {
        gd_callable_destroy(callable_buf);
    }
}

