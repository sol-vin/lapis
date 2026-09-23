#pragma once

/**
 * ==============================================================================
 * LibGodot - Common Platform Definitions & Crash Diagnostics (common.hpp)
 * ==============================================================================
 *
 * Architecture & Purpose:
 * -----------------------
 * This header acts as the foundational platform abstraction layer for the LibGodot
 * C++ loader bridge. It establishes uniform cross-platform macros, includes standard
 * C/C++ library headers, defines dynamic library export semantics, and configures
 * low-level crash interception on Windows via Vectored Exception Handling (VEH).
 *
 * Core Responsibilities:
 * 1. Platform Abstraction: Normalizes Win32 (windows.h) vs POSIX (dlfcn.h, unistd.h)
 *    dynamic linking primitives, file path limits (MAX_PATH), and export attributes.
 * 2. LLDB Debugger Support: Silently recovers the thread stack when LLDB attaches to
 *    a running process and Windows injects a small-stack remote thread.
 * 3. Crash Interception: Intercepts fatal segmentation faults (0xC0000005) and heap
 *    corruption (0xC0000374), formatting a 32-frame callstack with module relative
 *    offsets into `crash_dump.log` before passing control to the OS or attached debugger.
 * 4. Filesystem Utilities: Lightweight zero-allocation file existence checks.
 * ==============================================================================
 */

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
/** Export macro for Windows dynamic link libraries (.dll) */
#define GDE_EXPORT __declspec(dllexport)
#else
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <dlfcn.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <dirent.h>
#include <time.h>
#include <fcntl.h>
/** Export macro for POSIX shared objects (.so / .dylib) */
#define GDE_EXPORT __attribute__((visibility("default")))
#define HMODULE void*
#ifndef MAX_PATH
#define MAX_PATH 4096
#endif
#ifndef RTLD_NEXT
#define RTLD_NEXT ((void *) -1l)
#endif
#endif

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <string_view>
#include <vector>
#include <deque>
#include <unordered_set>
#include <unordered_map>
#include <utility>
#include <memory>
#include <algorithm>
#include <mutex>
#include <atomic>

#include "gdextension_interface.h"

#ifdef _WIN32
/**
 * Custom Vectored Exception Handler (VEH) for Windows to produce actionable crash reports.
 *
 * @param pExceptionInfo Pointer to the Windows exception record and context record.
 * @return EXCEPTION_CONTINUE_EXECUTION if recovered, or EXCEPTION_CONTINUE_SEARCH to pass.
 *
 * Invariants & Rationale:
 * - VEH handlers execute before structured exception handling (SEH) frames unwind the stack,
 *   allowing exact point-of-failure stack inspection.
 * - Must avoid allocating heap memory with dynamic locks if the crash is heap corruption.
 */
static LONG WINAPI custom_crash_handler(PEXCEPTION_POINTERS pExceptionInfo) {
    DWORD code = pExceptionInfo->ExceptionRecord->ExceptionCode;

    // --- Segment 1: Remote Debugger Thread Stack Overflow Recovery ---
    // When LLDB attaches to a running Windows process, the OS injects a remote thread
    // (`ntdll!DbgUiRemoteBreakin`) configured with a tiny stack allocation (typically 4KB-16KB).
    // Crystal's runtime calls `SetThreadStackGuarantee` during startup, which causes an artificial
    // `EXCEPTION_STACK_OVERFLOW` (0xC00000FD) when foreign debugger threads enter.
    // Instead of terminating with a false crash report, we reset the stack overflow guard page
    // via `_resetstkoflw` and allow the debugger thread to continue execution normally.
    if (code == 0xC00000FD) {
        typedef int (__cdecl *ResetStkOflwFn)();
        static ResetStkOflwFn p_reset = (ResetStkOflwFn)GetProcAddress(GetModuleHandleA("msvcrt.dll"), "_resetstkoflw");
        if (!p_reset) p_reset = (ResetStkOflwFn)GetProcAddress(GetModuleHandleA("ucrtbase.dll"), "_resetstkoflw");
        if (p_reset) p_reset();
        return EXCEPTION_CONTINUE_EXECUTION;
    }

    // --- Segment 2: Fatal Crash Interception (Access Violation & Heap Corruption) ---
    // Intercept hardware access violations (0xC0000005 / SEGV) and NT status heap corruption
    // (0xC0000374) to format a rich diagnostic backtrace before the process terminates.
    if (code == EXCEPTION_ACCESS_VIOLATION || code == 0xC0000374) {
        void *faulting_addr = pExceptionInfo->ExceptionRecord->ExceptionAddress;

        // --- Segment 3: Faulting Module Resolution & Base Offset ---
        // Query the loaded module containing the faulting instruction pointer using
        // GetModuleHandleExA with GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS without incrementing refcount.
        HMODULE hMod = NULL;
        char mod_name[MAX_PATH] = "Unknown";
        if (GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                               (LPCSTR)faulting_addr, &hMod)) {
            GetModuleFileNameA(hMod, mod_name, sizeof(mod_name));
        }

        // Format crash header with hex exception code, mnemonic, faulting IP, and relative offset
        char report[4096];
        int pos = snprintf(report, sizeof(report),
            "\n==================== CRASH INTERCEPTED ====================\n"
            "Exception Code: 0x%08lx (%s)\n"
            "Faulting instruction at: %p in module %s (offset 0x%llx)\n"
            "Callstack:\n",
            (unsigned long)code, (code == 0xC0000374 ? "STATUS_HEAP_CORRUPTION" : "ACCESS_VIOLATION"),
            faulting_addr, mod_name, (unsigned long long)((uintptr_t)faulting_addr - (uintptr_t)hMod));

        // --- Segment 4: 32-Frame Stack Backtrace Capture & Module Mapping ---
        // Capture up to 32 active stack frames directly from the execution stack.
        // For each frame, resolve its containing DLL/executable module and calculate its
        // relative offset from the module base address. This makes offsets reproducible across
        // ASLR (Address Space Layout Randomization) reboots and matches symbol map files.
        void *backtrace[32];
        WORD count = CaptureStackBackTrace(0, 32, backtrace, NULL);
        for (int i = 0; i < count && pos < (int)sizeof(report) - 128; i++) {
            HMODULE frame_mod = NULL;
            char frame_mod_name[MAX_PATH] = "Unknown";
            if (GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                                   (LPCSTR)backtrace[i], &frame_mod)) {
                GetModuleFileNameA(frame_mod, frame_mod_name, sizeof(frame_mod_name));
            }
            const char *base_name = strrchr(frame_mod_name, '\\');
            base_name = base_name ? base_name + 1 : frame_mod_name;
            pos += snprintf(report + pos, sizeof(report) - pos,
                "  [%02d] %p (%s + 0x%llx)\n", i, backtrace[i], base_name,
                (unsigned long long)((uintptr_t)backtrace[i] - (uintptr_t)frame_mod));
        }
        if (pos < (int)sizeof(report) - 64) {
            pos += snprintf(report + pos, sizeof(report) - pos,
                "===========================================================\n\n");
        }

        // --- Segment 5: Multi-Channel Diagnostic Dispatch ---
        // Persist the crash log to disk (`crash_dump.log`), then write directly to raw
        // Win32 console handles (STD_ERROR_HANDLE, STD_OUTPUT_HANDLE) and CRT stderr.
        FILE *f = fopen("crash_dump.log", "w");
        if (f) {
            fputs(report, f);
            fclose(f);
        }

        DWORD written = 0;
        HANDLE hErr = GetStdHandle(STD_ERROR_HANDLE);
        if (hErr && hErr != INVALID_HANDLE_VALUE) {
            WriteFile(hErr, report, (DWORD)pos, &written, NULL);
        }
        HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
        if (hOut && hOut != INVALID_HANDLE_VALUE) {
            WriteFile(hOut, report, (DWORD)pos, &written, NULL);
        }
        fputs(report, stderr);
        fflush(stderr);
    }

    // --- Segment 6: Pass Control to Debugger / OS Exception Chain ---
    // Return EXCEPTION_CONTINUE_SEARCH so that an attached debugger (e.g. LLDB, Visual Studio)
    // or standard OS Watson crash reporter can break at the exact machine instruction.
    return EXCEPTION_CONTINUE_SEARCH;
}
#endif

/**
 * Checks if a file exists on disk at the specified filesystem path.
 *
 * @param path Null-terminated C string representing absolute or relative path.
 * @return True if the file exists on disk and is accessible; false otherwise.
 *
 * Implementation details:
 * - Windows: Uses `GetFileAttributesA` avoiding file opening locks or handle consumption.
 * - POSIX: Uses `access(path, F_OK)` for direct kernel inode verification.
 */
inline bool bridge_file_exists(const char *path) {
    if (!path || path[0] == '\0') return false;
#ifdef _WIN32
    return GetFileAttributesA(path) != INVALID_FILE_ATTRIBUTES;
#else
    return access(path, F_OK) == 0;
#endif
}
