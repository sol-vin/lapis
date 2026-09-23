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
 * LibGodot - Dynamic Library Loading, Shadow Copying & Hot-Reloading
 * ==============================================================================
 */


/**
 * Copies a binary file from src to dst.
 * Windows: CopyFileA with failIfExists=FALSE.
 * POSIX: Buffered open/read/write/close.
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

/** Deletes a file on disk (DeleteFileA / unlink) */
inline void bridge_delete_file(const char *path) {
#ifdef _WIN32
    DeleteFileA(path);
#else
    unlink(path);
#endif
}

/** Retrieves the OS Process ID */
inline unsigned long bridge_get_pid() {
#ifdef _WIN32
    return (unsigned long)GetCurrentProcessId();
#else
    return (unsigned long)getpid();
#endif
}

/** Retrieves high-resolution monotonic millisecond timestamp */
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
 * Loads a shared dynamic library into the current process address space.
 * Windows: LoadLibraryExA with LOAD_WITH_ALTERED_SEARCH_PATH.
 * POSIX: dlopen with RTLD_NOW | RTLD_GLOBAL.
 */
inline HMODULE bridge_load_library(const char *path) {
#ifdef _WIN32
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

/** Resolves an exported symbol address from a loaded shared library */
inline void* bridge_get_proc(HMODULE hMod, const char *proc_name) {
#ifdef _WIN32
    return (void*)GetProcAddress(hMod, proc_name);
#else
    return dlsym(hMod, proc_name);
#endif
}

/** Formats the most recent dynamic link error message into out_buf */
inline void bridge_get_last_error(char *out_buf, size_t buf_size) {
#ifdef _WIN32
    snprintf(out_buf, buf_size, "error code %lu", (unsigned long)GetLastError());
#else
    const char *err = dlerror();
    snprintf(out_buf, buf_size, "%s", err ? err : "unknown dl error");
#endif
}

/** Queries the last modification timestamp of a file on disk */
inline uint64_t get_file_mtime(const char *path) {
#ifdef _WIN32
    WIN32_FILE_ATTRIBUTE_DATA data;
    if (GetFileAttributesExA(path, GetFileExInfoStandard, &data)) {
        return ((uint64_t)data.ftLastWriteTime.dwHighDateTime << 32) | data.ftLastWriteTime.dwLowDateTime;
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

inline uint64_t bridge_get_file_mtime(const char *path) {
    if (!path || path[0] == '\0') return 0;
#ifdef _WIN32
    WIN32_FILE_ATTRIBUTE_DATA fad;
    if (GetFileAttributesExA(path, GetFileExInfoStandard, &fad)) {
        ULARGE_INTEGER uli;
        uli.LowPart = fad.ftLastWriteTime.dwLowDateTime;
        uli.HighPart = fad.ftLastWriteTime.dwHighDateTime;
        return uli.QuadPart;
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

struct LoadedModuleInfo {
    HMODULE handle;
    uint64_t mtime;
};

/** Global handle to the currently loaded Crystal game library (game.dll/so) */
static HMODULE g_hGame = NULL;
/** List of all loaded Crystal module handles (plugin.dll, game.dll, etc.) */
static std::vector<HMODULE> g_loaded_modules;
/** Set of absolute library file paths that have already been loaded */
static std::unordered_set<std::string> g_loaded_module_paths;
/** Set of crystal_godot_init entry function pointers already invoked */
static std::unordered_set<void*> g_initialized_init_fns;
/** Count of active GDExtension initializations sharing this bridge */
static int g_active_extension_count = 0;
static std::unordered_map<std::string, LoadedModuleInfo> g_loaded_modules_map;

/**
 * Unloads the Crystal game library reference.
 * Note: FreeLibrary/dlclose is intentionally NOT called. Crystal's Boehm GC
 * and runtime internals must remain resident in memory across hot-reloads;
 * subsequent builds are loaded via unique shadow library copies.
 */
inline void unload_crystal_game_library() {
    g_hGame = NULL;
    g_loaded_modules.clear();
    g_loaded_module_paths.clear();
    g_loaded_modules_map.clear();
    g_crystal_signal_callbacks.clear();
    g_initialized_init_fns.clear();
}

/**
 * Scans the bridge directory and removes stale temporary shadow copies
 * (`*_loaded_*.dll/so`) left behind by previous, closed editor sessions.
 */
inline void cleanup_old_shadow_dlls(const char *dir) {
    if (!dir || dir[0] == '\0') return;
#ifdef _WIN32
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
 * Locates, loads, and initializes the Crystal game library (game.dll / game.so / libgame.so).
 */
inline void load_crystal_game_library(GDExtensionClassLibraryPtr p_library = nullptr) {
    if (p_library) {
        g_library = p_library;
    }
    char bridge_dir[MAX_PATH] = {0};

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

    // If multiple GDExtensions share the same loaded bridge DLL/dylib in memory,
    // use gd_get_library_path to identify the specific addon directory for this extension instance.
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

    // Clean up stale shadow copies from previous editor sessions
    cleanup_old_shadow_dlls(bridge_dir);

    bool use_shadow = bridge_should_use_shadow_copy();
    uint64_t ts = bridge_get_tick_count();
    unsigned long pid = bridge_get_pid();

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

    // 1. Primary candidates sitting directly next to crystal_bridge
    if (bridge_dir[0] != '\0') {
#ifdef _WIN32
        SetDllDirectoryA(bridge_dir);
#endif
        for (size_t c = 0; c < sizeof(candidate_names) / sizeof(candidate_names[0]); c++) {
            bool is_plugin = (strstr(candidate_names[c], "plugin") != nullptr);
            if (!is_editor_active() && is_plugin) {
                continue;
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
                    // Skip system/runtime dlls and temporary shadow dlls
                    if (strstr(fd.cFileName, "crystal_bridge") == nullptr &&
                        fd.cFileName[0] != '~' &&
                        strcmp(fd.cFileName, "gc.dll") != 0 &&
                        strcmp(fd.cFileName, "iconv-2.dll") != 0 &&
                        strcmp(fd.cFileName, "pcre2-8.dll") != 0 &&
                        strcmp(fd.cFileName, "libgodot.dll") != 0 &&
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

        // Check relative project bin directory if bridge sits in addons/<name>/bin and no game/addon was found in bridge_dir
        if (!loaded_game_or_addon) {
            char rel_game_path[MAX_PATH] = {0};
            snprintf(rel_game_path, sizeof(rel_game_path), "%s%s..%s..%s..%sbin%sgame.%s",
                     bridge_dir, path_sep, path_sep, path_sep, path_sep, path_sep, shadow_ext);
            if (bridge_file_exists(rel_game_path)) {
                to_load.push_back(std::string(rel_game_path));
                loaded_game_or_addon = true;
            }
        }
    }

#ifdef _WIN32
    // Preload runtime dependencies on Windows if present
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

    // Fallback search paths if no game or addon was found yet
    if (!loaded_game_or_addon) {
#ifdef _WIN32
        const char *fallbacks[] = {
            "addons/crystal_integration/bin/plugin.dll",
            "addons/crystal_integration/bin/game.dll",
            "bin/game.dll",
            "game.dll",
            "test/bin/game.dll",
            "template/bin/game.dll"
        };
#elif defined(__ANDROID__) || defined(ANDROID)
        const char *fallbacks[] = {
            "libplugin.so",
            "libgame.so",
            "addons/crystal_integration/bin/android/arm64-v8a/libgame.so",
            "bin/android/arm64-v8a/libgame.so",
            "game.so"
        };
#elif defined(__APPLE__)
        const char *fallbacks[] = {
            "addons/crystal_integration/bin/plugin.dylib",
            "addons/crystal_integration/bin/game.dylib",
            "bin/game.dylib",
            "game.dylib",
            "bin/libgame.dylib",
            "libgame.dylib",
            "test/bin/game.dylib",
            "template/bin/game.dylib"
        };
#else
        const char *fallbacks[] = {
            "addons/crystal_integration/bin/plugin.so",
            "addons/crystal_integration/bin/game.so",
            "bin/game.so",
            "game.so",
            "test/bin/game.so",
            "template/bin/game.so"
        };
#endif
        bool fallback_loaded_game = false;
        for (size_t i = 0; i < sizeof(fallbacks) / sizeof(fallbacks[0]); i++) {
            bool is_plugin = (strstr(fallbacks[i], "plugin") != nullptr);
            if (!is_editor_active() && is_plugin) {
                continue;
            }
            if (fallback_loaded_game && !is_plugin) {
                continue;
            }
            if (bridge_file_exists(fallbacks[i])) {
                to_load.push_back(std::string(fallbacks[i]));
                if (!is_plugin) {
                    fallback_loaded_game = true;
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

        if (g_loaded_module_paths.find(canonical_path) != g_loaded_module_paths.end()) {
            continue;
        }

        HMODULE hModule = NULL;

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
#ifdef _WIN32
            // If matching .pdb exists for candidate_path (e.g. game.pdb for game.dll), copy shadow PDB
            // so LLDB / debuggers can load full symbols for the shadow DLL without locking original PDB.
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

        if (hModule) {
            g_loaded_modules_map[canonical_path] = { hModule, current_mtime };
            g_loaded_module_paths.insert(canonical_path);
            g_hGame = hModule;
            g_loaded_modules.push_back(hModule);
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
 */
inline void init_common_method_binds() {
    void *sn_node = make_string_name("Node");
    void *sn_spp = make_string_name("set_physics_process");
    void *sn_sp = make_string_name("set_process");

    mb_set_physics_process = gd_classdb_get_method_bind(sn_node, sn_spp, 2586408642);
    mb_set_process = gd_classdb_get_method_bind(sn_node, sn_sp, 2586408642);

    free_string_name(sn_node); free_string_name(sn_spp); free_string_name(sn_sp);

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

    if (gd_classdb_get_method_bind) {
        void *sn_obj = make_string_name("Object");
        void *sn_gid = make_string_name("get_instance_id");
        mb_object_get_instance_id = gd_classdb_get_method_bind(sn_obj, sn_gid, 3905245786ULL);
        free_string_name(sn_obj); free_string_name(sn_gid);
    }

    if (gd_get_variant_from_type_constructor) {
        gd_variant_from_string = gd_get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_STRING);
    }
}
