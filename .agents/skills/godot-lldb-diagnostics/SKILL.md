---
name: godot-lldb-diagnostics
description: Diagnostic testing and debugging protocol for attaching LLDB to Godot Editor and game processes on Windows to catch crashes, segfaults, stack overflows, and cyclic recursions.
license: MIT
metadata:
  author: LibGodot Team
  version: "1.0.0"
  domain: debugging
  triggers: lldb, crash, segfault, access violation, stack overflow, editor crash, attach, hang, freeze
  role: specialist
  scope: debugging
---

# Godot & LibGodot LLDB Diagnostic Testing Workflow

This skill outlines the authoritative, repeatable workflow for capturing, diagnosing, and resolving native crashes, access violations (`0xC0000005`), stack overflows, and exceptions in the Godot Editor and compiled Crystal/C++ GDExtension binaries on Windows.

---

## 1. Architectural Architecture & Process Model

Godot has a dual-process execution model during development:
1. **Editor Process (`godot.exe --editor --path <project>`)**:
   - Runs the editor UI, dock tabs, inspector, and tool scripts.
   - Executes `EditorPlugin._build()` when clicking **Play (F5)** or **Build**.
   - Loads `plugin.dll` (Crystal editor plugin) and GDExtension bridge.
2. **Child Game Process (`godot.exe --path <project>`)**:
   - Spawned by the Editor when clicking **Play (F5)**.
   - Runs `scenes/main.tscn`, loads `game.dll`, and executes gameplay nodes.

> [!IMPORTANT]
> On Windows, attaching LLDB to the **Editor** process attaches *only* to the editor. If the game crashes in its separate spawned process, LLDB on the editor will not catch it. You must choose the target process based on where the failure occurs.

---

## 2. Process Attachment Workflows

### Workflow A: Debugging the Editor Process (In-Editor & F5 Build Crashes)

Use this workflow when the Editor freezes, hangs, or closes when opening the project or clicking Play (F5):

#### 1. Launch Godot Editor from an Interactive Terminal
Run Godot from your desktop PowerShell terminal so the GUI window appears on your interactive desktop:
```powershell
.\godot.exe --editor --path bin/test/my_game
```

#### 2. Get the Process ID (PID)
In another terminal (or via agent command):
```powershell
(Get-Process godot).Id
```

#### 3. Attach LLDB and Resume Execution
Attach LLDB using the target PID. On Windows, LLDB breaks immediately at `ntdll!DbgBreakPoint`. You must tell it to continue:
```powershell
lldb -p <PID> -o "c"
```
Or interactively inside `lldb`:
```text
(lldb) process attach --pid <PID>
(lldb) c
```

The Editor is now actively monitored.

#### 4. Trigger the Crash
Click the **Play (F5)** button or perform the action that causes the failure. When the crash occurs, **the editor will freeze** because LLDB has intercepted the exception!

---

### Workflow B: Debugging the Child Game Process Directly

If the Editor stays open but the game window closes or crashes immediately upon opening:

#### 1. Run the Game Directly Under LLDB
Launch the exact scene and project path directly under LLDB:
```powershell
lldb -- .\godot.exe --path bin/test/my_game
```

#### 2. Start Execution
Inside the LLDB prompt:
```text
(lldb) run
```

When the crash occurs, LLDB will stop directly at the faulting machine instruction.

---

## 3. Investigating the Crash in LLDB

When LLDB catches an exception, it prints:
```text
Process <PID> stopped
* thread #<N>, stop reason = Exception 0xc0000005 encountered at address <ADDR>: Access violation writing location <TARGET>
```

Execute these diagnostic commands in order:

### Step 1: Check Thread Status
List all threads to find which thread triggered the stop and what other threads are doing:
```text
(lldb) thread list
```
The active stop thread is marked with an asterisk (`* thread #57`).

### Step 2: Capture the Backtrace
Check the call stack:
```text
# Print the current thread's top 30 frames:
(lldb) thread backtrace -c 30

# Print all frames (or full trace across all threads):
(lldb) thread backtrace all
```

> [!WARNING]
> If LLDB prints thousands of frames (e.g., `frame #35413`), **you have an infinite recursion / stack overflow!**
> The access violation address (`0x...aa8`) will match `rsp - 8`, where the CPU attempted to push a return address onto a depleted stack guard page.

### Step 3: Inspect Repeating Frames in Stack Overflows
To identify the recursion cycle, inspect repeating slices of the stack:
```text
(lldb) thread backtrace -s 35385 -c 20
(lldb) thread backtrace -s 10 -c 20
```

### Step 4: Disassemble the Crash Site & Call Frames
Select the frame and inspect surrounding instructions:
```text
(lldb) frame select 0
(lldb) disassemble --frame -c 15

# Or disassemble an explicit code range:
(lldb) disassemble -s 0x7fffaf76ff80 -c 25
```

### Step 5: Read Memory and Uncaught Exception Strings
Inspect memory addresses, pointers, and ASCII/UTF-8 string literals referenced in registers (`%rip`, `%rax`, `%rcx`):
```text
# Read null-terminated string at address:
(lldb) x/s <address>

# Read hex bytes:
(lldb) x/16b <address>

# Read 64-bit pointers:
(lldb) x/16gx <address>
```

---

## 4. Common Diagnostic Patterns & Root Causes

### Pattern 1: Stack Overflow (`0xC0000005` at `rsp - 8`)
- **Symptoms**: 10,000+ frames in LLDB, `writing location <rsp-8>`.
- **Cause**: Mutual recursion between callbacks, or cyclic calls in signal emission or property getters/setters.
- **Resolution**: Break the cycle using boolean re-entrancy guards (`@@building`, `@@guard = true`) or defer dispatches.

### Pattern 2: Cyclic Recursion in Constants / Class Variables
- **Symptoms**: Thread caught in `SymInitializeW` / `strcpy_s` printing backtrace with string `"Cyclic recursion while initializing class variables and/or constants"`.
- **Cause**: Initializing a class variable (`@@var = Class.new`) or constant triggers code that accesses that same class variable or constant before initialization finishes.
- **Resolution**: Use lazy initialization with getter methods (`def self.var; @@var ||= ...; end`) rather than top-level class variable initializers.

### Pattern 3: `Fiber#execution_context cannot be nil`
- **Symptoms**: Uncaught `NilAssertionError` in background OS threads (`Thread.new`).
- **Cause**: Calling fiber-suspending IO (`stdout.gets`, unbuffered `Channel#send`, or top-level `sleep`) from a raw OS thread (`Thread.new`).
- **Resolution**: Use buffered channels (`Channel(T).new(128)`), and use `Crystal::System::Thread.sleep` instead of fiber `sleep`.

---

## 5. One-Line Diagnostic Command Quick-Reference

| Action | Command |
| :--- | :--- |
| **Launch Editor** | `.\godot.exe --editor --path bin/test/my_game` |
| **Find Godot PID** | `(Get-Process godot).Id` |
| **Attach LLDB** | `lldb -p <PID> -o "c"` |
| **Debug Game Directly** | `lldb -- .\godot.exe --path bin/test/my_game` |
| **Inspect Threads** | `(lldb) thread list` |
| **Top 30 Frames** | `(lldb) thread backtrace -c 30` |
| **Read String at Addr** | `(lldb) x/s 0x<address>` |
| **Disassemble Frame** | `(lldb) disassemble --frame -c 15` |
| **Read Registers** | `(lldb) register read` |
