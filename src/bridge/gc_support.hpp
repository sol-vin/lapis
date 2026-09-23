#pragma once

#include "common.hpp"
#include "bridge_types.hpp"

#include <vector>
#include <mutex>
#include <atomic>

#ifndef _WIN32
#include <signal.h>
#include <pthread.h>
#endif

struct GC_stack_base {
    void *mem_base;
};

using GCGetStackBaseFn = int (*)(struct GC_stack_base *sb);
using GCRegisterMyThreadFn = int (*)(const struct GC_stack_base *sb);
using GCThreadIsRegisteredFn = int (*)(void);
using GCAllowRegisterThreadsFn = void (*)(void);
using GCInitFn = void (*)(void);
using GCIsInitCalledFn = int (*)(void);
using GCGetSuspendSignalFn = int (*)(void);
using GCGetThrRestartSignalFn = int (*)(void);
using GCUnregisterMyThreadFn = int (*)(void);

struct GCModuleEntry {
    void *handle = nullptr;
    GCGetStackBaseFn get_stack_base = nullptr;
    GCRegisterMyThreadFn register_my_thread = nullptr;
    GCUnregisterMyThreadFn unregister_my_thread = nullptr;
    GCThreadIsRegisteredFn thread_is_registered = nullptr;
    GCAllowRegisterThreadsFn allow_register_threads = nullptr;
    GCInitFn init = nullptr;
    GCGetSuspendSignalFn get_suspend_signal = nullptr;
    GCGetThrRestartSignalFn get_thr_restart_signal = nullptr;
};

static std::vector<GCModuleEntry> g_gc_modules;
static std::recursive_mutex g_gc_modules_mutex;
static thread_local size_t t_gc_registered_module_count = 0;
static void *s_cached_game_module = nullptr;

#ifndef _WIN32
#include <cstdlib>

static pthread_t g_main_thread_id = 0;
static std::atomic<bool> g_main_thread_initialized{false};

inline void record_main_thread() {
    if (!g_main_thread_initialized.load(std::memory_order_relaxed)) {
        g_main_thread_id = pthread_self();
        g_main_thread_initialized.store(true, std::memory_order_relaxed);
    }
}

inline bool is_main_thread() {
    if (!g_main_thread_initialized.load(std::memory_order_relaxed)) {
        record_main_thread();
        return true;
    }
    return pthread_equal(pthread_self(), g_main_thread_id) != 0;
}

__attribute__((constructor))
static void on_bridge_load() {
    record_main_thread();
}
#endif

inline void unregister_gc_thread() {
#if defined(_WIN32) || (defined(__APPLE__) && defined(__MACH__))
    t_gc_registered_module_count = 0;
    return;
#else
    if (is_main_thread()) {
        t_gc_registered_module_count = 0;
        return;
    }
    std::vector<GCModuleEntry> modules_snapshot;
    {
        std::lock_guard<std::recursive_mutex> lock(g_gc_modules_mutex);
        modules_snapshot = g_gc_modules;
    }
    for (const auto &mod : modules_snapshot) {
        if (mod.thread_is_registered && mod.thread_is_registered() == 0) {
            continue;
        }
        if (mod.unregister_my_thread) {
            mod.unregister_my_thread();
        }
    }
    t_gc_registered_module_count = 0;
#endif
}

struct GCThreadRegistrationGuard {
    bool active = false;
    ~GCThreadRegistrationGuard() {
        if (active) {
            active = false;
            unregister_gc_thread();
        }
    }
};
static thread_local GCThreadRegistrationGuard t_gc_registration_guard;

#ifndef _WIN32
inline void bridge_get_gc_signals(int *out_suspend, int *out_restart) {
    if (!out_suspend || !out_restart) return;
#if defined(__APPLE__)
    // On macOS, Boehm GC uses Mach kernel threads (thread_suspend/thread_resume).
    *out_suspend = 0;
    *out_restart = 0;
#elif (defined(SIGRTMIN) && defined(SIGRTMAX)) || (defined(__SIGRTMIN) && defined(__SIGRTMAX))
#if defined(SIGRTMIN)
    int rt_min = SIGRTMIN;
    int rt_max = SIGRTMAX;
#else
    int rt_min = __SIGRTMIN;
    int rt_max = __SIGRTMAX;
#endif
    // Since each GDExtension addon loads its own copy of crystal_bridge.so,
    // static variables in memory are not shared across distinct .so files.
    // We use libc's process-wide environment (shared across all .so in the process)
    // keyed by PID to coordinate unique, non-overlapping real-time signals per module.
    char env_key[64];
    snprintf(env_key, sizeof(env_key), "LIBGODOT_GC_SIGNAL_OFFSET_%d", (int)getpid());
    const char *env_val = getenv(env_key);
    int offset = (env_val && *env_val) ? atoi(env_val) : 0;
    char next_buf[16];
    snprintf(next_buf, sizeof(next_buf), "%d", offset + 1);
    setenv(env_key, next_buf, 1);

    // Boehm GC default starts at SIGRTMIN + 6.
    // Allocate distinct pairs of real-time signals for each loaded Crystal module
    // to prevent signal handler overwrites and delivery failures.
    int base = rt_min + 6 + (offset * 2);
    if (base + 1 <= rt_max) {
        *out_suspend = base;
        *out_restart = base + 1;
    } else {
        *out_suspend = 0;
        *out_restart = 0;
    }
    fprintf(stderr, "[CrystalBridge] PID %d module GC signals: suspend=%d, restart=%d (offset=%d)\n",
            (int)getpid(), *out_suspend, *out_restart, offset);
#else
    *out_suspend = 0;
    *out_restart = 0;
#endif
}
#else
inline void bridge_get_gc_signals(int *out_suspend, int *out_restart) {
    if (out_suspend) *out_suspend = 0;
    if (out_restart) *out_restart = 0;
}
#endif



inline void bridge_register_gc_functions(const BridgeGCFunctions *funcs) {
    if (!funcs) return;
    std::lock_guard<std::recursive_mutex> lock(g_gc_modules_mutex);
    for (const auto &m : g_gc_modules) {
        if (funcs->register_my_thread && m.register_my_thread == (GCRegisterMyThreadFn)funcs->register_my_thread) {
            return;
        }
    }
    GCModuleEntry entry;
    entry.init = funcs->init;
    entry.register_my_thread = (GCRegisterMyThreadFn)funcs->register_my_thread;
    entry.unregister_my_thread = (GCUnregisterMyThreadFn)funcs->unregister_my_thread;
    entry.thread_is_registered = (GCThreadIsRegisteredFn)funcs->thread_is_registered;
    entry.allow_register_threads = (GCAllowRegisterThreadsFn)funcs->allow_register_threads;
    entry.get_stack_base = (GCGetStackBaseFn)funcs->get_stack_base;
    entry.get_suspend_signal = (GCGetSuspendSignalFn)funcs->get_suspend_signal;
    entry.get_thr_restart_signal = (GCGetThrRestartSignalFn)funcs->get_thr_restart_signal;

    if (entry.allow_register_threads) entry.allow_register_threads();
    g_gc_modules.push_back(entry);
}

/**
 * Discovers and dynamically links Boehm Garbage Collector runtime symbols.
 *
 * Invariants & Thread Safety:
 * - On Windows: Resolves functions dynamically from `gc.dll` (either already loaded or via `LoadLibraryA`).
 * - On POSIX: Detects whether Boehm GC is statically linked into the game module or loaded dynamically.
 *   Enforces strict single-instance registration to prevent duplicate pthread key destructor collisions.
 * - Protects module list mutations with recursive mutex `g_gc_modules_mutex`.
 *
 * @param game_module_handle Optional handle to the loaded Crystal game shared library.
 *
 * Segments:
 * - Segment 1: Handle caching and thread synchronization.
 * - Segment 2: Windows dynamic GC library linking (`gc.dll`).
 * - Segment 3: POSIX GC candidate traversal and single-instance registration.
 */
inline void init_gc_library(void *game_module_handle = nullptr) {
    // --- Segment 1: Handle Caching & Thread Synchronization ---
    std::lock_guard<std::recursive_mutex> lock(g_gc_modules_mutex);

    if (game_module_handle) {
        s_cached_game_module = game_module_handle;
    } else {
        game_module_handle = s_cached_game_module;
    }

#ifdef _WIN32
    // --- Segment 2: Windows Dynamic GC Linking (gc.dll) ---
    HMODULE hGc = GetModuleHandleA("gc.dll");
    if (!hGc) hGc = LoadLibraryA("gc.dll");
    if (hGc) {
        bool found = false;
        for (const auto &m : g_gc_modules) {
            if (m.handle == hGc) {
                found = true;
                break;
            }
        }
        if (!found) {
            GCModuleEntry entry;
            entry.handle = hGc;
            entry.init = reinterpret_cast<GCInitFn>(GetProcAddress(hGc, "GC_init"));
            entry.allow_register_threads = reinterpret_cast<GCAllowRegisterThreadsFn>(GetProcAddress(hGc, "GC_allow_register_threads"));
            entry.get_stack_base = reinterpret_cast<GCGetStackBaseFn>(GetProcAddress(hGc, "GC_get_stack_base"));
            entry.register_my_thread = reinterpret_cast<GCRegisterMyThreadFn>(GetProcAddress(hGc, "GC_register_my_thread"));
            entry.unregister_my_thread = reinterpret_cast<GCUnregisterMyThreadFn>(GetProcAddress(hGc, "GC_unregister_my_thread"));
            entry.thread_is_registered = reinterpret_cast<GCThreadIsRegisteredFn>(GetProcAddress(hGc, "GC_thread_is_registered"));
            GCIsInitCalledFn is_init_called = reinterpret_cast<GCIsInitCalledFn>(GetProcAddress(hGc, "GC_is_init_called"));
            bool already_inited = (is_init_called && is_init_called() != 0);
            if (entry.init && !already_inited) entry.init();
            if (entry.allow_register_threads) entry.allow_register_threads();
            g_gc_modules.push_back(entry);
        }
    }
#else
    // --- Segment 3: POSIX Single-Instance GC Registration ---
    // On POSIX platforms where Boehm GC is statically linked into shared libraries,
    // registering multiple static GC instances to track the same OS threads causes
    // fatal collisions in pthread key destructors (signal 11 / SIGSEGV at address 0x18).
    // Only the primary game module should register with g_gc_modules.
    if (!g_gc_modules.empty()) {
        return;
    }

    std::vector<void*> candidates;
    if (game_module_handle) {
        candidates.push_back(game_module_handle);
    } else {
        candidates.push_back(RTLD_DEFAULT);
    }

    for (void *hCand : candidates) {
        GCRegisterMyThreadFn reg_fn = reinterpret_cast<GCRegisterMyThreadFn>(dlsym(hCand, "GC_register_my_thread"));
        if (!reg_fn) continue;

        bool already_registered = false;
        for (const auto &m : g_gc_modules) {
            if (m.register_my_thread == reg_fn) {
                already_registered = true;
                break;
            }
        }
        if (already_registered) {
            if (hCand == game_module_handle) {
                break;
            }
            continue;
        }

        GCModuleEntry entry;
        entry.handle = hCand;
        entry.register_my_thread = reg_fn;
        entry.unregister_my_thread = reinterpret_cast<GCUnregisterMyThreadFn>(dlsym(hCand, "GC_unregister_my_thread"));
        entry.init = reinterpret_cast<GCInitFn>(dlsym(hCand, "GC_init"));
        entry.allow_register_threads = reinterpret_cast<GCAllowRegisterThreadsFn>(dlsym(hCand, "GC_allow_register_threads"));
        entry.get_stack_base = reinterpret_cast<GCGetStackBaseFn>(dlsym(hCand, "GC_get_stack_base"));
        entry.thread_is_registered = reinterpret_cast<GCThreadIsRegisteredFn>(dlsym(hCand, "GC_thread_is_registered"));
        entry.get_suspend_signal = reinterpret_cast<GCGetSuspendSignalFn>(dlsym(hCand, "GC_get_suspend_signal"));
        entry.get_thr_restart_signal = reinterpret_cast<GCGetThrRestartSignalFn>(dlsym(hCand, "GC_get_thr_restart_signal"));

        GCIsInitCalledFn is_init_called = reinterpret_cast<GCIsInitCalledFn>(dlsym(hCand, "GC_is_init_called"));
        bool already_inited = (is_init_called && is_init_called() != 0);
        if (entry.init && hCand != game_module_handle && !already_inited) entry.init();
        if (entry.allow_register_threads) entry.allow_register_threads();
        g_gc_modules.push_back(entry);

        if (hCand == game_module_handle) {
            break;
        }
    }
#endif
}

/**
 * Registers the calling OS thread with Boehm Garbage Collector.
 *
 * Essential Invariant:
 * Foreign engine threads (Godot's `WorkerThreadPool`, AudioServer, PhysicsServer, or OS threads)
 * will trigger fatal segmentation faults (`0xC0000005` or signal 11) if they allocate Crystal
 * heap objects or dereference GC-managed memory before their stack boundaries are registered.
 * This function guarantees safe registration with thread-local caching for zero per-call overhead.
 *
 * Segments:
 * - Segment 1: Thread-local fast path and module snapshot acquisition.
 * - Segment 2: POSIX signal unmasking for thread suspend/restart signals.
 * - Segment 3: Native stack base pointer resolution (with OS-level fallbacks).
 * - Segment 4: Foreign thread registration and RAII unregistration guard activation.
 */
inline void ensure_gc_thread_registered() {
#ifndef _WIN32
    record_main_thread();
#endif

    // --- Segment 1: Thread-Local Fast Path & Module Snapshot Acquisition ---
    std::vector<GCModuleEntry> modules_snapshot;
    {
        std::lock_guard<std::recursive_mutex> lock(g_gc_modules_mutex);
        if (g_gc_modules.empty()) {
            init_gc_library();
        }
        if (t_gc_registered_module_count >= g_gc_modules.size() && !g_gc_modules.empty()) {
            return;
        }
        modules_snapshot = g_gc_modules;
    }
    if (modules_snapshot.empty()) {
        return;
    }

#ifndef _WIN32
    // --- Segment 2: POSIX Real-Time Signal Unmasking ---
    // Unmask Boehm GC thread suspend/restart signals on foreign threads before registering.
    sigset_t set;
    sigemptyset(&set);
#if defined(SIGRTMIN) && defined(SIGRTMAX)
    for (int sig = SIGRTMIN; sig <= SIGRTMAX; ++sig) {
        sigaddset(&set, sig);
    }
#elif defined(__SIGRTMIN) && defined(__SIGRTMAX)
    for (int sig = __SIGRTMIN; sig <= __SIGRTMAX; ++sig) {
        sigaddset(&set, sig);
    }
#endif
    for (const auto &mod : modules_snapshot) {
        if (mod.get_suspend_signal) {
            int sig = mod.get_suspend_signal();
            if (sig > 0) sigaddset(&set, sig);
        }
        if (mod.get_thr_restart_signal) {
            int sig = mod.get_thr_restart_signal();
            if (sig > 0) sigaddset(&set, sig);
        }
    }
#ifdef SIGPWR
    sigaddset(&set, SIGPWR);
#endif
#ifdef SIGXCPU
    sigaddset(&set, SIGXCPU);
#endif
    pthread_sigmask(SIG_UNBLOCK, &set, nullptr);
#endif

    // --- Segment 3: Native Stack Base Resolution ---
    struct GC_stack_base sb;
    sb.mem_base = nullptr;
    int rc = -1;

    for (const auto &mod : modules_snapshot) {
        if (mod.get_stack_base) {
            rc = mod.get_stack_base(&sb);
            if (rc == 0 && sb.mem_base != nullptr) {
                break;
            }
        }
    }

#if defined(__APPLE__)
    if (rc != 0 || sb.mem_base == nullptr) {
        sb.mem_base = pthread_get_stackaddr_np(pthread_self());
        rc = 0;
    }
#elif defined(__linux__)
    if (rc != 0 || sb.mem_base == nullptr) {
        pthread_attr_t attr;
        if (pthread_getattr_np(pthread_self(), &attr) == 0) {
            void *stack_addr = nullptr;
            size_t stack_size = 0;
            pthread_attr_getstack(&attr, &stack_addr, &stack_size);
            pthread_attr_destroy(&attr);
            if (stack_addr) {
                sb.mem_base = (void*)((uintptr_t)stack_addr + stack_size);
                rc = 0;
            }
        }
    }
#endif

    // --- Segment 4: Thread Registration & RAII Guard Activation ---
    if (rc == 0 && sb.mem_base != nullptr) {
        for (const auto &mod : modules_snapshot) {
            if (mod.register_my_thread) {
                if (mod.thread_is_registered && mod.thread_is_registered()) {
                    continue;
                }
                mod.register_my_thread(&sb);

            }
        }
        t_gc_registered_module_count = modules_snapshot.size();
#ifndef _WIN32
        if (!is_main_thread()) {
            t_gc_registration_guard.active = true;
        }
#else
        t_gc_registration_guard.active = true;
#endif
    }
}
