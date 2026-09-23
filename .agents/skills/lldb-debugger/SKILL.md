---
name: lldb-debugger
description: Attaches LLDB to Godot processes, configures breakpoints, resolves symbols and PDBs, inspects threads, and debugs Windows exceptions and GDExtension bridges in LibGodot.
license: MIT
metadata:
  author: LibGodot Team
  version: "1.0.0"
  domain: debugging
  triggers: lldb, debugger, breakpoint, backtrace, crash, attach, segfault, stack overflow, exception
  role: specialist
  scope: debugging
---

# LLDB Debugging Guide for LibGodot

This skill provides step-by-step diagnostic workflows for attaching LLDB to Godot Editor instances, debugging child game processes, inspecting Crystal + C++ GDExtension symbols, and managing Windows exceptions.

---

## 1. Process Attachment Workflows

### A. Launching Godot Under LLDB Directly
To run Godot (editor or standalone game) directly from LLDB:
```bash
lldb -- godot.exe --editor --path <project_dir>
# In LLDB prompt:
(lldb) run
```

Or using the Lapis CLI:
```bash
lapis editor -p <project_dir> --lldb
lapis editor -r -p <project_dir> --lldb
```

### B. Attaching to an Active Process via PID
When Godot or a game instance is already running:
```bash
lldb
(lldb) process attach --pid <PID>
(lldb) process continue
```

On Windows, `process attach` pauses the process at `ntdll!DbgBreakPoint`. You must run `process continue` (or `c`) to resume execution.

---

## 2. Breakpoint Setting & Symbol Resolution

### A. Setting Breakpoints in Crystal Files
Always use full normalized paths or file basenames:
```text
(lldb) breakpoint set --file main.cr --line 22
(lldb) breakpoint set --file "c:/path/to/project/src/main.cr" --line 22
```

### B. Setting Breakpoints in C++ Bridge / Engine
```text
(lldb) breakpoint set --name crystal_godot_init
(lldb) breakpoint set --name crystal_godot_notification_trampoline
(lldb) breakpoint set --file crystal_bridge.cpp --line 320
```

### C. Verifying Pending vs Bound Breakpoints
If a breakpoint reports `no locations (pending)`, check loaded modules:
```text
(lldb) breakpoint list
(lldb) image list game.dll
(lldb) image list crystal_bridge.dll
```
If the module is not yet loaded, LLDB will resolve the breakpoint as soon as `LoadLibraryA` is called on the DLL.

---

## 3. Windows Exception Handling in LLDB

### A. Suppressing Foreign Injected Thread Exceptions
When LLDB attaches on Windows, `ntdll!DbgUiRemoteBreakin` touches stack guard pages, raising `0xC00000FD` (`EXCEPTION_STACK_OVERFLOW`).
To prevent LLDB from stopping on non-fatal SEH exceptions:
```text
(lldb) process handle 0xc00000fd --stop false --pass true
```

### B. Catching Access Violations and Aborts
```text
(lldb) process handle 0xc0000005 --stop true --pass false
```

---

## 4. Inspection & Backtrace Analysis

### A. Capturing Thread Backtraces
```text
(lldb) thread backtrace all
(lldb) thread backtrace
(lldb) frame select 0
(lldb) frame variable
```

### B. Inspecting Disassembly & Registers
```text
(lldb) disassemble --frame
(lldb) register read
```
