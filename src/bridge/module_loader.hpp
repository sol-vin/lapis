#pragma once

#include "common.hpp"
#include "gdextension_api.hpp"
#include "bridge_types.hpp"
#include "gc_support.hpp"
#include "dispatch_signals.hpp"
#include "extension_instance.hpp"
#include "classdb_registry.hpp"
#include "bridge_api.hpp"

/**
 * ==============================================================================
 * LibGodot - Dynamic Library Loading, Shadow Copying & Hot-Reloading (module_loader.hpp)
 * ==============================================================================
 *
 * Architecture & Design:
 * ----------------------
 * In Godot development workflows, game logic is frequently recompiled while the Godot
 * Editor remains open. On Windows, loading a dynamic library via standard Win32 `LoadLibraryA`
 * places a mandatory shared read-lock on the file on disk. Consequently, subsequent compiler
 * invocations fail with OS error `LNK1104: cannot open file 'bin/game.dll'`.
 *
 * The Shadow Loading Subsystem resolves this invariant:
 * 1. Timestamped Shadow Copies: Instead of loading `game.dll` directly, the loader creates
 *    a uniquely named copy (`game_loaded_<PID>_<TIMESTAMP>.dll`) in the target directory.
 * 2. Unlocked Production Binary: `bin/game.dll` remains completely unlocked on disk, allowing
 *    the Crystal compiler to rebuild the game at any moment while the Godot Editor stays running.
 * 3. Hot-Reloading Trigger: When the editor detects a build completion (or receives F5/F6),
 *    Godot calls GDExtension reload. The loader sweeps orphaned shadow files and creates a new
 *    shadow copy with the latest timestamp.
 * 4. PDB Symbol Synchronization: On Windows, debuggers like LLDB require symbol files. The loader
 *    detects companion `.pdb` files and creates matching `game_loaded_<PID>_<TIMESTAMP>.pdb` files,
 *    allowing live breakpoint resolution without locking the developer's primary PDB.
 * ==============================================================================
 */

/**
 * Copies a binary file from source path to destination path.
 *
 * @param src Null-terminated path to source file.
 * @param dst Null-terminated path to destination file.
 * @return True on success; false on failure.
 *
 * Implementation Details:
 * - Windows: Uses `CopyFileA(src, dst, FALSE)` with `bFailIfExists=FALSE` to overwrite.
 * - POSIX: Performs chunked 8KB buffer transfers via kernel `open`/`read`/`write` descriptors
 *   with octal mode `0755` preserving execution permissions.
 */
inline bool bridge_copy_file(const char *src, const char *dst) {
#ifdef _WIN32
    return CopyFileA(src, dst, FALSE) != 0;
#else
    int in_fd = open(src, O_RDONLY);
    if (in_fd < 0) return false;
    int out_fd = open(dst, O_WRONLY | O_CREAT | O_TRUNC, 0755);
    if (out_fd < 0) {
        close(in_fd);
        return false;
    }
    char buf[8192];
    ssize_t bytes;
    bool success = true;
    while ((bytes = read(in_fd, buf, sizeof(buf))) > 0) {
        if (write(out_fd, buf, bytes) != bytes) {
            success = false;
            break;
        }
    }
    close(in_fd);
    close(out_fd);
    return success && (bytes >= 0);
#endif
}

/**
 * Deletes a file on disk.
 *
 * @param path Null-terminated path of the file to remove.
 */
inline void bridge_delete_file(const char *path) {
#ifdef _WIN32
    DeleteFileA(path);
#else
    unlink(path);
#endif
}

/**
 * Retrieves the operating system Process ID (PID) for the active host process.
 *
 * @return Process identifier integer.
 */
inline unsigned long bridge_get_pid() {
#ifdef _WIN32
    return (unsigned long)GetCurrentProcessId();
#else
    return (unsigned long)getpid();
#endif
}

/**
 * Retrieves a high-resolution monotonic millisecond timestamp.
 *
 * @return Monotonic time in milliseconds since system boot.
 */
inline uint64_t bridge_get_tick_count() {
#ifdef _WIN32
    return GetTickCount64();
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ((uint64_t)ts.tv_sec * 1000ULL) + ((uint64_t)ts.tv_nsec / 1000000ULL);
#endif
}

/**
 * Loads a dynamic shared library into the current process address space.
 *
 * @param path Filesystem path to the dynamic library.
 * @return Module handle (HMODULE on Windows, void* on POSIX) or nullptr on error.
 *
 * Implementation Details:
 * - Windows: Uses `LoadLibraryExA` with `LOAD_WITH_ALTERED_SEARCH_PATH` so dependent DLLs
 *   located in the same directory as the target DLL are automatically discovered.
 * - POSIX: Uses `dlopen` with `RTLD_NOW | RTLD_LOCAL | RTLD_DEEPBIND` to prefer internal symbols.
 */
inline HMODULE bridge_load_library(const char *path) {
#ifdef _WIN32
    char abs_path[MAX_PATH] = {0};
    if (GetFullPathNameA(path, sizeof(abs_path), abs_path, NULL) > 0) {
        HMODULE h = LoadLibraryExA(abs_path, NULL, LOAD_WITH_ALTERED_SEARCH_PATH);
        if (h) return h;
    }
    HMODULE h = LoadLibraryExA(path, NULL, LOAD_WITH_ALTERED_SEARCH_PATH);
    if (!h) h = LoadLibraryA(path);
    return h;
#else
#ifdef RTLD_DEEPBIND
    return dlopen(path, RTLD_NOW | RTLD_LOCAL | RTLD_DEEPBIND);
#else
    return dlopen(path, RTLD_NOW | RTLD_LOCAL);
#endif
#endif
}

/**
 * Resolves an exported symbol address from a loaded dynamic library.
 *
 * @param hMod Loaded module handle.
 * @param proc_name Null-terminated C string of the exported function identifier.
 * @return Raw pointer to the function entry point or nullptr if not found.
 */
inline void* bridge_get_proc(HMODULE hMod, const char *proc_name) {
#ifdef _WIN32
    return (void*)GetProcAddress(hMod, proc_name);
#else
    return dlsym(hMod, proc_name);
#endif
}

/**
 * Formats the last operating system dynamic linker error into a caller-supplied buffer.
 *
 * @param out_buf Destination character buffer.
 * @param buf_size Maximum capacity of output buffer in bytes.
 */
inline void bridge_get_last_error(char *out_buf, size_t buf_size) {
#ifdef _WIN32
    DWORD err = GetLastError();
    FormatMessageA(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                   NULL, err, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
                   out_buf, (DWORD)buf_size, NULL);
#else
    const char *err = dlerror();
    if (err) {
        snprintf(out_buf, buf_size, "%s", err);
    } else {
        snprintf(out_buf, buf_size, "Unknown dlopen error");
    }
#endif
}

/**
 * Internal helper to retrieve file modification time in seconds since epoch.
 */
inline uint64_t get_file_mtime(const char *path) {
#ifdef _WIN32
    WIN32_FILE_ATTRIBUTE_DATA data;
    if (GetFileAttributesExA(path, GetFileExInfoStandard, &data)) {
        ULARGE_INTEGER uli;
        uli.LowPart = data.ftLastWriteTime.dwLowDateTime;
        uli.HighPart = data.ftLastWriteTime.dwHighDateTime;
        return (uli.QuadPart / 10000000ULL) - 11644473600ULL;
    }
    return 0;
#else
    struct stat st;
    if (stat(path, &st) == 0) {
        return (uint64_t)st.st_mtime;
    }
    return 0;
#endif
}

/** Public file modification time wrapper */
inline uint64_t bridge_get_file_mtime(const char *path) {
    return get_file_mtime(path);
}

/** Tracking structure for a dynamically loaded Crystal module */
struct LoadedModuleInfo {
    HMODULE handle;       /** OS module handle */
    uint64_t mtime;       /** Modification timestamp when loaded */
};

static HMODULE g_hGame = NULL;
static std::vector<HMODULE> g_loaded_modules;
static std::unordered_map<std::string, LoadedModuleInfo> g_loaded_modules_map;
static std::unordered_set<std::string> g_loaded_module_paths;

/**
 * Unloads all loaded Crystal game and addon modules and resets internal tracking.
 * Called when extension count reaches zero or during engine shutdown.
 */
inline void unload_crystal_game_library() {
    g_loaded_module_paths.clear();
    g_loaded_modules_map.clear();
    g_loaded_modules.clear();
    g_hGame = NULL;
}

/**
 * Scans the bridge directory and removes stale temporary shadow copies
 * (`*_loaded_*.dll/so/pdb`) left behind by closed or crashed editor sessions.
 *
 * @param dir Target directory containing bridge and game libraries.
 *
 * Safety & Segments:
 * - Segment 1: Scans for shadow DLL files matching `*_loaded_*.dll`.
 * - Segment 2: Scans for shadow PDB debug symbols matching `*_loaded_*.pdb`.
 * - Segment 3: POSIX directory iteration with `opendir`/`readdir` filtering for `_loaded_`.
 */
inline void cleanup_old_shadow_dlls(const char *dir) {
    if (!dir || dir[0] == '\0') return;
#ifdef _WIN32
    // --- Segment 1: Win32 Shadow DLL Scan & Removal ---
    char search_pattern[MAX_PATH];
    snprintf(search_pattern, sizeof(search_pattern), "%s\\*_loaded_*.dll", dir);

    WIN32_FIND_DATAA fd;
    HANDLE hFind = FindFirstFileA(search_pattern, &fd);
    if (hFind != INVALID_HANDLE_VALUE) {
        do {
            char file_path[MAX_PATH];
            snprintf(file_path, sizeof(file_path), "%s\\%s", dir, fd.cFileName);
            DeleteFileA(file_path);
        } while (FindNextFileA(hFind, &fd));
        FindClose(hFind);
    }

    // --- Segment 2: Win32 Shadow PDB Scan & Removal ---
    snprintf(search_pattern, sizeof(search_pattern), "%s\\*_loaded_*.pdb", dir);
    hFind = FindFirstFileA(search_pattern, &fd);
    if (hFind != INVALID_HANDLE_VALUE) {
        do {
            char file_path[MAX_PATH];
            snprintf(file_path, sizeof(file_path), "%s\\%s", dir, fd.cFileName);
            DeleteFileA(file_path);
        } while (FindNextFileA(hFind, &fd));
        FindClose(hFind);
    }
#else
    // --- Segment 3: POSIX Shadow Library Scan & Removal ---
    DIR *d = opendir(dir);
    if (!d) return;
    struct dirent *entry;
    while ((entry = readdir(d)) != nullptr) {
        if (strstr(entry->d_name, "_loaded_") != nullptr) {
            char file_path[MAX_PATH];
            snprintf(file_path, sizeof(file_path), "%s/%s", dir, entry->d_name);
            unlink(file_path);
        }
    }
    closedir(d);
#endif
}

/**
 * Determines whether the bridge should create a temporary shadow copy
 * (`game_loaded_<PID>_<timestamp>.dll/so`) before loading the Crystal library.
 *
 * Rules:
 * 1. Disabled on mobile/embedded targets (Android) where filesystems are sandboxed.
 * 2. Disabled in standalone game runtime (`!is_editor_active()`), where recompilation is not occurring.
 * 3. Can be explicitly disabled via `LIBGODOT_NO_SHADOW=1` or `LIBGODOT_HOT_RELOAD=0`.
 */
inline bool bridge_should_use_shadow_copy() {
#if defined(__ANDROID__) || defined(ANDROID)
    return false;
#else
    if (!is_editor_active()) {
        return false;
    }
    const char *no_shadow = getenv("LIBGODOT_NO_SHADOW");
    if (no_shadow && (strcmp(no_shadow, "1") == 0 || strcmp(no_shadow, "true") == 0)) {
        return false;
    }
    const char *hot_reload = getenv("LIBGODOT_HOT_RELOAD");
    if (hot_reload && (strcmp(hot_reload, "0") == 0 || strcmp(hot_reload, "false") == 0)) {
        return false;
    }
    return true;
#endif
}

/**
 * Locates, shadow-copies, loads, and initializes the Crystal game library (game.dll / game.so).
 *
 * @param p_library Opaque handle to the active GDExtension library.
 *
 * Internal Execution Segments:
 * - Segment 1: Resolve the bridge directory from own loaded module address.
 * - Segment 2: Query GDExtension library path via `gd_get_library_path` for multi-addon isolation.
 * - Segment 3: Clean up stale shadow copies from previous closed editor sessions.
 * - Segment 4: Construct platform-specific candidate binary names (plugin, game, addon).
 * - Segment 5: Enumerate bridge directory for any custom addon DLL/SO files.
 * - Segment 6: Fall back to project relative paths if bridge is in an addon subfolder.
 * - Segment 7: Preload Win32 runtime dependencies (gc.dll, iconv-2.dll, pcre2-8.dll).
 * - Segment 8: Canonicalize paths and filter against already loaded module sets.
 * - Segment 9: Perform timestamped shadow copy on Windows (preventing compiler file lock).
 * - Segment 10: Copy companion .pdb for LLDB source-level debugging of shadow DLL.
 * - Segment 11: Dynamic LoadLibrary, resolve `crystal_godot_init(&g_bridge_api)`, and register GC thread.
 */
inline void load_crystal_game_library(GDExtensionClassLibraryPtr p_library = nullptr) {
    if (p_library) {
        g_library = p_library;
    }
    char bridge_dir[MAX_PATH] = {0};

    // --- Segment 1: Bridge Directory Resolution ---
    // Identify the absolute filesystem directory containing this bridge binary using
    // its own function pointer address (`&load_crystal_game_library`).
#ifdef _WIN32
    HMODULE hBridge = NULL;
    if (GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, (LPCSTR)&load_crystal_game_library, &hBridge)) {
        if (GetModuleFileNameA(hBridge, bridge_dir, sizeof(bridge_dir))) {
            char *last_slash = strrchr(bridge_dir, '\\');
            if (!last_slash) last_slash = strrchr(bridge_dir, '/');
            if (last_slash) {
                *last_slash = '\0';
            }
        }
    }
#else
    Dl_info dlinfo;
    if (dladdr((void*)&load_crystal_game_library, &dlinfo) && dlinfo.dli_fname) {
        strncpy(bridge_dir, dlinfo.dli_fname, sizeof(bridge_dir) - 1);
        char *last_slash = strrchr(bridge_dir, '/');
        if (last_slash) {
            *last_slash = '\0';
        }
    }
#endif

    // --- Segment 2: GDExtension Multi-Addon Path Isolation ---
    // If multiple distinct GDExtensions share the same loaded bridge DLL in memory,
    // invoke Godot's `gd_get_library_path` on the specific library pointer to resolve
    // that addon's dedicated subfolder rather than assuming the root bridge directory.
    GDExtensionClassLibraryPtr lib_target = p_library ? p_library : g_library;
    if (gd_get_library_path && lib_target && gd_string_to_utf8_chars) {
        uint8_t gd_str_storage[64] = {0};
        GDExtensionUninitializedStringPtr gd_str = (GDExtensionUninitializedStringPtr)&gd_str_storage[0];
        gd_get_library_path(lib_target, gd_str);
        char lib_path[MAX_PATH] = {0};
        int64_t len = gd_string_to_utf8_chars((GDExtensionConstStringPtr)gd_str, lib_path, sizeof(lib_path) - 1);
        if (len >= 0 && len < (int64_t)sizeof(lib_path)) {
            lib_path[len] = '\0';
        }
        if (gd_string_destroy) {
            gd_string_destroy((GDExtensionStringPtr)gd_str);
        }

        if (lib_path[0] != '\0') {
            const char *p = lib_path;
            if (strncmp(p, "res://", 6) == 0) p += 6;

            char resolved_addon_dir[MAX_PATH] = {0};
            if (p[0] == '/' || (p[0] != '\0' && p[1] == ':')) {
                // p is already an absolute path
                strncpy(resolved_addon_dir, p, sizeof(resolved_addon_dir) - 1);
            } else {
                // Find the project root prefix from the bridge_dir path
                char *addons_pos = strstr(bridge_dir, "/addons/");
                if (!addons_pos) addons_pos = strstr(bridge_dir, "\\addons\\");
                if (addons_pos) {
                    size_t prefix_len = (size_t)(addons_pos - bridge_dir + 1); // includes trailing '/' or '\\'
                    snprintf(resolved_addon_dir, sizeof(resolved_addon_dir), "%.*s%s", (int)prefix_len, bridge_dir, p);
                } else {
                    strncpy(resolved_addon_dir, p, sizeof(resolved_addon_dir) - 1);
                }
            }

            char *slash = strrchr(resolved_addon_dir, '/');
            if (!slash) slash = strrchr(resolved_addon_dir, '\\');
            if (slash) *slash = '\0';

            // Check if resolved_addon_dir already ends with /bin or \bin
            size_t rlen = strlen(resolved_addon_dir);
            bool already_has_bin = (rlen >= 4 && (strcmp(resolved_addon_dir + rlen - 4, "/bin") == 0 || strcmp(resolved_addon_dir + rlen - 4, "\\bin") == 0));

            if (already_has_bin) {
                if (bridge_file_exists(resolved_addon_dir)) {
                    strncpy(bridge_dir, resolved_addon_dir, sizeof(bridge_dir) - 1);
                }
            } else {
                char bin_subfolder[MAX_PATH] = {0};
                snprintf(bin_subfolder, sizeof(bin_subfolder), "%s/bin", resolved_addon_dir);
                if (bridge_file_exists(bin_subfolder)) {
                    strncpy(bridge_dir, bin_subfolder, sizeof(bridge_dir) - 1);
                } else if (resolved_addon_dir[0] != '\0' && bridge_file_exists(resolved_addon_dir)) {
                    strncpy(bridge_dir, resolved_addon_dir, sizeof(bridge_dir) - 1);
                }
            }
        }
    }

    if (bridge_dir[0] != '\0') {
        char dir_log[512];
        snprintf(dir_log, sizeof(dir_log), "[CrystalBridge] Resolved bridge directory: %s", bridge_dir);
        godot_log_verbose(dir_log);
    }

    // --- Segment 3: Stale Shadow Artifact Cleanup ---
    // Remove temporary DLLs and PDBs left behind from previous engine sessions.
    cleanup_old_shadow_dlls(bridge_dir);

    bool use_shadow = bridge_should_use_shadow_copy();
    uint64_t ts = bridge_get_tick_count();
    unsigned long pid = bridge_get_pid();

    // --- Segment 4: Candidate Library Names by Platform ---
#ifdef _WIN32
    const char *candidate_names[] = { "plugin.dll", "game.dll", "crystal_addon.dll" };
    const char *path_sep = "\\";
    const char *shadow_ext = "dll";
#elif defined(__ANDROID__) || defined(ANDROID)
    const char *candidate_names[] = { "libplugin.so", "libgame.so", "libcrystal_addon.so" };
    const char *path_sep = "/";
    const char *shadow_ext = "so";
#elif defined(__APPLE__)
    const char *candidate_names[] = { "plugin.dylib", "game.dylib", "libgame.dylib", "crystal_addon.dylib" };
    const char *path_sep = "/";
    const char *shadow_ext = "dylib";
#else
    const char *candidate_names[] = { "plugin.so", "game.so", "crystal_addon.so" };
    const char *path_sep = "/";
    const char *shadow_ext = "so";
#endif

    std::vector<std::string> to_load;
    bool loaded_game_or_addon = false;

    // --- Segment 5: Primary Directory Scanning ---
    // Check candidate binaries sitting directly adjacent to crystal_bridge.
    if (bridge_dir[0] != '\0') {
#ifdef _WIN32
        SetDllDirectoryA(bridge_dir);
#endif
        for (size_t c = 0; c < sizeof(candidate_names) / sizeof(candidate_names[0]); c++) {
            bool is_plugin = (strstr(candidate_names[c], "plugin") != nullptr);
            if (!is_editor_active() && is_plugin) {
                continue; // Do not load editor plugins in standalone game runtime
            }
            if (loaded_game_or_addon && !is_plugin) {
                continue;
            }
            char test_path[MAX_PATH] = {0};
            snprintf(test_path, sizeof(test_path), "%s%s%s", bridge_dir, path_sep, candidate_names[c]);
            if (bridge_file_exists(test_path)) {
                to_load.push_back(std::string(test_path));
                if (!is_plugin) {
                    loaded_game_or_addon = true;
                }
            }
        }

        // If standard names not found, search directory for any custom addon DLL/SO
        if (to_load.empty()) {
#ifdef _WIN32
            char search_pattern[MAX_PATH];
            snprintf(search_pattern, sizeof(search_pattern), "%s\\*.dll", bridge_dir);
            WIN32_FIND_DATAA fd;
            HANDLE hFind = FindFirstFileA(search_pattern, &fd);
            if (hFind != INVALID_HANDLE_VALUE) {
                do {
                    // Skip system runtime dlls and existing shadow dlls
                    if (strstr(fd.cFileName, "crystal_bridge") == nullptr &&
                        fd.cFileName[0] != '~' &&
                        strcmp(fd.cFileName, "gc.dll") != 0 &&
                        strcmp(fd.cFileName, "iconv-2.dll") != 0 &&
                        strcmp(fd.cFileName, "pcre2-8.dll") != 0 &&
                        strcmp(fd.cFileName, "libgodot.dll") != 0 &&
                        strcmp(fd.cFileName, "plugin.dll") != 0 &&
                        strstr(fd.cFileName, "_loaded_") == nullptr) {
                        char full_path[MAX_PATH];
                        snprintf(full_path, sizeof(full_path), "%s\\%s", bridge_dir, fd.cFileName);
                        to_load.push_back(std::string(full_path));
                        loaded_game_or_addon = true;
                    }
                } while (FindNextFileA(hFind, &fd));
                FindClose(hFind);
            }
#else
            DIR *d = opendir(bridge_dir);
            if (d) {
                struct dirent *entry;
                while ((entry = readdir(d)) != nullptr) {
                    const char *name = entry->d_name;
                    size_t len = strlen(name);
                    bool is_lib = (len > 3 && strcmp(name + len - 3, ".so") == 0) ||
                                  (len > 6 && strcmp(name + len - 6, ".dylib") == 0);
                    if (is_lib &&
                        strstr(name, "crystal_bridge") == nullptr &&
                        strstr(name, "plugin") == nullptr &&
                        strstr(name, "libgc") == nullptr &&
                        strstr(name, "libpcre2") == nullptr &&
                        strstr(name, "libiconv") == nullptr &&
                        strstr(name, "libgodot") == nullptr &&
                        strstr(name, "_loaded_") == nullptr) {
                        char full_path[MAX_PATH];
                        snprintf(full_path, sizeof(full_path), "%s/%s", bridge_dir, name);
                        to_load.push_back(std::string(full_path));
                        loaded_game_or_addon = true;
                    }
                }
                closedir(d);
            }
#endif
        }

        // --- Segment 6: Relative Project Directory Traversal ---
        // If bridge sits in an addon subfolder (`addons/<name>/bin/`), check the root game binary and plugin.
        if (!loaded_game_or_addon) {
            char rel_game_path[MAX_PATH] = {0};
            snprintf(rel_game_path, sizeof(rel_game_path), "%s%s..%s..%s..%sbin%sgame.%s",
                     bridge_dir, path_sep, path_sep, path_sep, path_sep, path_sep, shadow_ext);
            if (bridge_file_exists(rel_game_path)) {
                to_load.push_back(std::string(rel_game_path));
                loaded_game_or_addon = true;
            }
        }
        if (is_editor_active()) {
            char rel_plugin_path[MAX_PATH] = {0};
            snprintf(rel_plugin_path, sizeof(rel_plugin_path), "%s%s..%s..%s..%sbin%splugin.%s",
                     bridge_dir, path_sep, path_sep, path_sep, path_sep, path_sep, shadow_ext);
            if (bridge_file_exists(rel_plugin_path)) {
                bool already_added = false;
                for (const auto &p : to_load) {
                    if (p == rel_plugin_path) {
                        already_added = true;
                        break;
                    }
                }
                if (!already_added) {
                    to_load.push_back(std::string(rel_plugin_path));
                }
            }
        }
    }

    // --- Segment 7: Windows Runtime Dependency Preloading ---
    // Ensure gc.dll, iconv-2.dll, and pcre2-8.dll are pre-loaded in memory so dynamic linkage
    // inside game.dll resolves immediately without relying on system PATH.
#ifdef _WIN32
    const char *runtime_deps[] = { "gc.dll", "iconv-2.dll", "pcre2-8.dll" };
    for (int r = 0; r < 3; r++) {
        char dep_path[MAX_PATH];
        if (bridge_dir[0] != '\0') {
            snprintf(dep_path, sizeof(dep_path), "%s\\%s", bridge_dir, runtime_deps[r]);
            LoadLibraryA(dep_path);
        }
        LoadLibraryA(runtime_deps[r]);
    }
#endif

    // --- Segment 8: Fallback Search Path Resolution ---
    bool loaded_plugin = false;
    for (const auto &p : to_load) {
        if (p.find("plugin") != std::string::npos) {
            loaded_plugin = true;
            break;
        }
    }

    if (!loaded_game_or_addon || (is_editor_active() && !loaded_plugin)) {
#ifdef _WIN32
        const char *fallbacks[] = {
            "bin/game.dll",
            "game.dll",
            "bin/plugin.dll",
            "plugin.dll",
            "template/bin/game.dll",
            "addons/crystal_integration/bin/plugin.dll",
            "addons/crystal_integration/bin/game.dll"
        };
#elif defined(__ANDROID__) || defined(ANDROID)
        const char *fallbacks[] = {
            "bin/android/arm64-v8a/libgame.so",
            "libgame.so",
            "game.so",
            "addons/crystal_integration/bin/android/arm64-v8a/libgame.so",
            "libplugin.so"
        };
#elif defined(__APPLE__)
        const char *fallbacks[] = {
            "bin/game.dylib",
            "game.dylib",
            "bin/plugin.dylib",
            "plugin.dylib",
            "bin/libgame.dylib",
            "libgame.dylib",
            "template/bin/game.dylib",
            "addons/crystal_integration/bin/plugin.dylib",
            "addons/crystal_integration/bin/game.dylib"
        };
#else
        const char *fallbacks[] = {
            "bin/game.so",
            "game.so",
            "bin/plugin.so",
            "plugin.so",
            "template/bin/game.so",
            "addons/crystal_integration/bin/plugin.so",
            "addons/crystal_integration/bin/game.so"
        };
#endif
        for (size_t i = 0; i < sizeof(fallbacks) / sizeof(fallbacks[0]); i++) {
            bool is_plugin = (strstr(fallbacks[i], "plugin") != nullptr);
            if (!is_editor_active() && is_plugin) {
                continue;
            }
            if (loaded_game_or_addon && !is_plugin) {
                continue;
            }
            if (loaded_plugin && is_plugin) {
                continue;
            }
            if (bridge_file_exists(fallbacks[i])) {
                to_load.push_back(std::string(fallbacks[i]));
                if (!is_plugin) {
                    loaded_game_or_addon = true;
                } else {
                    loaded_plugin = true;
                }
            }
        }
    }

#if defined(__ANDROID__) || defined(ANDROID)
    // On Android, if not found on filesystem, try loading directly via linker search path
    if (to_load.empty()) {
        HMODULE hSys = bridge_load_library("libgame.so");
        if (hSys) {
            godot_log_verbose("[CrystalBridge] Loaded game library via system dlopen('libgame.so')");
            g_hGame = hSys;
            g_loaded_modules.push_back(hSys);
            typedef void (*CrystalInitFn)(const BridgeAPI *api);
            CrystalInitFn init_fn = (CrystalInitFn)bridge_get_proc(hSys, "crystal_godot_init");
            if (init_fn) init_fn(&g_bridge_api);
            return;
        }
    }
#endif

    if (to_load.empty()) {
        godot_log_print("[CrystalBridge] No game or plugin library found yet. Click 'Build Crystal' in the editor to compile your project.");
        return;
    }

    typedef void (*CrystalInitFn)(const BridgeAPI *api);

    // --- Segment 9: Module Processing, Shadow Copying & Loading ---
    for (size_t i = 0; i < to_load.size(); i++) {
        const std::string &candidate_path = to_load[i];
        char canonical_path[MAX_PATH] = {0};
#ifdef _WIN32
        if (_fullpath(canonical_path, candidate_path.c_str(), MAX_PATH)) {
            for (char *p = canonical_path; *p; p++) {
                if (*p == '/') *p = '\\';
                *p = (char)tolower(*p);
            }
        } else {
            snprintf(canonical_path, sizeof(canonical_path), "%s", candidate_path.c_str());
        }
#else
        if (realpath(candidate_path.c_str(), canonical_path) == nullptr) {
            snprintf(canonical_path, sizeof(canonical_path), "%s", candidate_path.c_str());
        }
#endif
        uint64_t current_mtime = bridge_get_file_mtime(candidate_path.c_str());

        // Skip if module already loaded at current path
        if (g_loaded_module_paths.find(canonical_path) != g_loaded_module_paths.end()) {
            continue;
        }

        HMODULE hModule = NULL;

        // --- Segment 10: Shadow Copy Creation (Windows File-Lock Avoidance) ---
        if (use_shadow) {
            char shadow_path[MAX_PATH] = {0};
            do {
                snprintf(shadow_path, sizeof(shadow_path), "%s_loaded_%lu_%llu.%s", candidate_path.c_str(), pid, (unsigned long long)ts, shadow_ext);
                ts++;
            } while (bridge_file_exists(shadow_path));

            if (!bridge_copy_file(candidate_path.c_str(), shadow_path)) {
                char err_buf[256];
                bridge_get_last_error(err_buf, sizeof(err_buf));
                char log_buf[512];
                snprintf(log_buf, sizeof(log_buf), "[CrystalBridge] Copy failed from %s to %s (%s)", candidate_path.c_str(), shadow_path, err_buf);
                godot_log_error(log_buf, nullptr, "load_crystal_game_library", __FILE__, __LINE__);
            }

            // Copy companion PDB on Windows so LLDB can debug shadow DLL with full symbols
#ifdef _WIN32
            size_t c_len = candidate_path.length();
            if (c_len > 4 && candidate_path.compare(c_len - 4, 4, ".dll") == 0) {
                std::string orig_pdb = candidate_path.substr(0, c_len - 4) + ".pdb";
                if (!bridge_file_exists(orig_pdb.c_str())) {
                    // Check project bin directory if candidate is in addons/<name>/bin
                    char rel_pdb[MAX_PATH] = {0};
                    snprintf(rel_pdb, sizeof(rel_pdb), "%s%s..%s..%s..%sbin%sgame.pdb",
                             bridge_dir, path_sep, path_sep, path_sep, path_sep, path_sep);
                    if (bridge_file_exists(rel_pdb)) {
                        orig_pdb = std::string(rel_pdb);
                    }
                }
                if (bridge_file_exists(orig_pdb.c_str())) {
                    std::string shadow_pdb = std::string(shadow_path);
                    size_t s_len = shadow_pdb.length();
                    if (s_len > 4 && shadow_pdb.compare(s_len - 4, 4, ".dll") == 0) {
                        shadow_pdb = shadow_pdb.substr(0, s_len - 4) + ".pdb";
                        bridge_copy_file(orig_pdb.c_str(), shadow_pdb.c_str());
                    }
                }
            }
#endif
            hModule = bridge_load_library(shadow_path);
            if (hModule) {
                char buf[512];
                snprintf(buf, sizeof(buf), "[CrystalBridge] Loaded library from %s via shadow copy %s", candidate_path.c_str(), shadow_path);
                godot_log_verbose(buf);
            } else {
                char err_buf[256];
                bridge_get_last_error(err_buf, sizeof(err_buf));
                char log_buf[512];
                snprintf(log_buf, sizeof(log_buf), "[CrystalBridge] Failed to load library %s (%s)", shadow_path, err_buf);
                godot_log_warning(log_buf, nullptr, "load_crystal_game_library", __FILE__, __LINE__);
            }
        } else {
            // Direct loading (e.g. standalone production runner without shadow copying)
#ifdef _WIN32
            HMODULE hExisting = GetModuleHandleA(candidate_path.c_str());
            if (!hExisting) hExisting = GetModuleHandleA(canonical_path);
            if (!hExisting) {
                const char *leaf = strrchr(canonical_path, '\\');
                if (leaf) hExisting = GetModuleHandleA(leaf + 1);
            }
            if (hExisting) {
                hModule = hExisting;
            }
#else
            void *hExisting = dlopen(canonical_path, RTLD_NOLOAD | RTLD_NOW);
            if (!hExisting) hExisting = dlopen(candidate_path.c_str(), RTLD_NOLOAD | RTLD_NOW);
            if (!hExisting) {
                const char *leaf = strrchr(canonical_path, '/');
                if (leaf) hExisting = dlopen(leaf + 1, RTLD_NOLOAD | RTLD_NOW);
            }
            if (hExisting) {
                hModule = (HMODULE)hExisting;
            }
#endif
            if (!hModule) {
                hModule = bridge_load_library(candidate_path.c_str());
                if (hModule) {
                    char buf[512];
                    snprintf(buf, sizeof(buf), "[CrystalBridge] Loaded library directly from %s", candidate_path.c_str());
                    godot_log_verbose(buf);
                } else {
                    char err_buf[256];
                    bridge_get_last_error(err_buf, sizeof(err_buf));
                    char log_buf[512];
                    snprintf(log_buf, sizeof(log_buf), "[CrystalBridge] Failed to load library %s (%s)", candidate_path.c_str(), err_buf);
                    godot_log_warning(log_buf, nullptr, "load_crystal_game_library", __FILE__, __LINE__);
                }
            }
        }

        // --- Segment 11: Crystal Initialization Handshake & GC Hook ---
        if (hModule) {
            g_loaded_modules_map[canonical_path] = { hModule, current_mtime };
            g_loaded_module_paths.insert(canonical_path);
            g_hGame = hModule;
            g_loaded_modules.push_back(hModule);

            // Resolve exported crystal_godot_init entry point and pass the BridgeAPI table
            CrystalInitFn init_fn = (CrystalInitFn)bridge_get_proc(hModule, "crystal_godot_init");
            if (init_fn) {
                init_fn(&g_bridge_api);
            } else {
                godot_log_error("Failed to find 'crystal_godot_init' in loaded library", nullptr, "load_crystal_game_library", __FILE__, __LINE__);
            }
            init_gc_library(hModule);
            ensure_gc_thread_registered();
        }
    }
}

/**
 * Pre-caches frequently used Godot engine method binds and utility functions.
 * Resolves StringNames and queries ClassDB once at SCENE level to avoid per-call lookups.
 *
 * Segments:
 * - Segment 1: Caches Node process methods (`set_physics_process`, `set_process`).
 * - Segment 2: Caches global utility functions (`print`, `printerr`, `is_instance_id_valid`, `instance_from_id`).
 * - Segment 3: Caches Object reflection methods (`get_instance_id`).
 * - Segment 4: Resolves string-to-variant constructor.
 */
inline void init_common_method_binds() {
    // --- Segment 1: Node Process Controls ---
    void *sn_node = make_string_name("Node");
    void *sn_spp = make_string_name("set_physics_process");
    void *sn_sp = make_string_name("set_process");

    mb_set_physics_process = gd_classdb_get_method_bind(sn_node, sn_spp, 2586408642);
    mb_set_process = gd_classdb_get_method_bind(sn_node, sn_sp, 2586408642);

    free_string_name(sn_node);
    free_string_name(sn_spp);
    free_string_name(sn_sp);

    // --- Segment 2: Global Utility Functions ---
    if (gd_variant_get_ptr_utility_function) {
        void *sn_p = make_string_name("print");
        gd_util_print = gd_variant_get_ptr_utility_function(sn_p, 2648703342ULL);
        free_string_name(sn_p);

        void *sn_perr = make_string_name("printerr");
        gd_util_printerr = gd_variant_get_ptr_utility_function(sn_perr, 2648703342ULL);
        free_string_name(sn_perr);

        void *sn_iiiv = make_string_name("is_instance_id_valid");
        gd_util_is_instance_id_valid = gd_variant_get_ptr_utility_function(sn_iiiv, 2232439758ULL);
        free_string_name(sn_iiiv);

        void *sn_ifi = make_string_name("instance_from_id");
        gd_util_instance_from_id = gd_variant_get_ptr_utility_function(sn_ifi, 1156694636ULL);
        free_string_name(sn_ifi);
    }

    // --- Segment 3: Object Reflection Methods ---
    if (gd_classdb_get_method_bind) {
        void *sn_obj = make_string_name("Object");
        void *sn_gid = make_string_name("get_instance_id");
        mb_object_get_instance_id = gd_classdb_get_method_bind(sn_obj, sn_gid, 3905245786ULL);
        free_string_name(sn_obj);
        free_string_name(sn_gid);
    }

    // --- Segment 4: Variant Conversion Constructors ---
    if (gd_get_variant_from_type_constructor) {
        gd_variant_from_string = gd_get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_STRING);
    }
}
