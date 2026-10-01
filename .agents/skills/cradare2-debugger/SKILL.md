---
name: cradare2-debugger
description: Native debugger, decompiler, crash forensics, and multiplayer lockstep debugging engine for Lapis and Godot using cradare2 and radare2. Covers lapis decompile, pdc/pdf, the 7 in-editor session tabs, registers, hardware watchpoints, crash forensics, and multiplayer packet auditing.
---

# `cradare2` & radare2 Native Debugger, Decompiler & Forensics Guide

This skill is the operational manual for native debugging, Ghidra decompilation, memory forensics, and multiplayer synchronization in Crystal and Godot using **[`cradare2`](https://github.com/sol-vin/cradare2)** and **radare2**.

---

## 1. Process Attachment & Launch Workflows

### Launching Under radare2 via Lapis CLI
```bash
lapis run -d                     # Run game with radare2 attached
lapis editor -d                  # Open Godot Editor under radare2
lapis editor -r -d               # Launch editor with debug attachment and log monitoring
lapis analyze bin/game.dll --chart # Interactive binary metrics chart
lapis analyze bin/game.dll --tui   # Full TUI binary inspector
```

### Attaching to an Active Process via PID
```bash
r2 -d -p <PID>
# In radare2 prompt:
[0x00007ff812345678]> dc         # Continue execution
```

---

## 2. Native Decompiler Mapping (`pdc` / `pdf`)

Lapis integrates radare2's native disassembly engine and the Ghidra decompiler plugin via `cradare2`.

### CLI Decompiler Commands
```bash
# Decompile a function to Ghidra pseudo-C
lapis decompile bin/game.dll sym.Player#_physics_process

# Side-by-side disassembly (pdf) and Ghidra pseudo-C (pdc)
lapis decompile bin/game.dll sym.Player#take_damage --side-by-side

# Filter symbols dynamically
lapis decompile bin/game.dll --filter="Player"
```

### radare2 Decompiler Primitives:
- `pdf`: Disassemble function (assembly instructions, register assignments, branching jumps).
- `pdc`: Decompile function to C pseudo-code using Ghidra decompiler.
- `pdca`: Decompile function with annotated variable types and offsets.
- `af`: Analyze function at current seek offset.
- `afl`: List all analyzed functions in binary.

---

## 3. In-Editor Radare2 Session Tabs (7 Tabs)

The Godot Editor Crystal debugger dock (`CrystalDebuggerPlugin`) provides 7 interactive tabs:

<table>
  <thead>
    <tr>
      <th align="left">Tab #</th>
      <th align="left">Tab Name</th>
      <th align="left">Shortcut</th>
      <th align="left">Function &amp; radare2 Command</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Tab 1</td>
      <td><strong>Disassembly</strong></td>
      <td><code>1</code></td>
      <td>Displays full assembly instructions via <code>pdf</code> with syntax coloring</td>
    </tr>
    <tr>
      <td>Tab 2</td>
      <td><strong>Decompiler</strong></td>
      <td><code>2</code></td>
      <td>Live Ghidra pseudo-C decompilation via <code>pdc</code></td>
    </tr>
    <tr>
      <td>Tab 3</td>
      <td><strong>Memory &amp; Hex</strong></td>
      <td><code>3</code></td>
      <td>Memory hex dump (<code>px 512</code>) around current instruction pointer</td>
    </tr>
    <tr>
      <td>Tab 4</td>
      <td><strong>Registers</strong></td>
      <td><code>4</code></td>
      <td>Live CPU registers (<code>dr=</code>): <code>RAX</code>, <code>RCX</code>, <code>RDX</code>, <code>RBX</code>, <code>RSP</code>, <code>RBP</code>, <code>RSI</code>, <code>RDI</code>, <code>RIP</code></td>
    </tr>
    <tr>
      <td>Tab 5</td>
      <td><strong>Backtrace</strong></td>
      <td><code>5</code></td>
      <td>Call stack backtrace via <code>dbt</code> showing frame addresses and symbols</td>
    </tr>
    <tr>
      <td>Tab 6</td>
      <td><strong>Watchpoints</strong></td>
      <td><code>6</code></td>
      <td>Active software breakpoints (<code>db</code>) and hardware watchpoints (<code>rw</code>)</td>
    </tr>
    <tr>
      <td>Tab 7</td>
      <td><strong>Binary Metrics</strong></td>
      <td><code>7</code></td>
      <td>Visual section distribution bar chart, top functions, and security hardening flags (<code>Opal::UI::BinaryMetrics</code>)</td>
    </tr>
  </tbody>
</table>

---

## 4. Breakpoints & Hardware Watchpoints

### Setting Source-Line Breakpoints
```text
[0x...]> dbl player.cr:42         # Set breakpoint at player.cr line 42
[0x...]> dbl                      # List active breakpoints
[0x...]> db- player.cr:42         # Delete breakpoint
```

### Setting Symbol Breakpoints
```text
[0x...]> db sym.crystal_godot_init
[0x...]> db "sym.Player#_physics_process:Float64"
```

### Hardware Watchpoints for Memory Corruption
If a variable, instance pointer, or struct address becomes corrupted:
```text
[0x...]> rw 0x0000021b3759c2f0    # Break on write to this memory address
[0x...]> dc                       # Continue execution
```
radare2 breaks immediately at the exact machine instruction performing the illegal memory write!

---

## 5. Automated Crash Forensics & Dead-Pointer Analysis

Whenever an unhandled `EXCEPTION_ACCESS_VIOLATION` (`0xC0000005`) occurs:

```
[CrashForensics] Analyzing crash state at RIP=0x7ffb2a14e210...
  Faulting Address : 0x0000000000000018 (Read Access Violation)
  Faulting Module  : game.dll (Offset: 0x4e210)
  RCX Register     : 0x0000000000000000 (Null Pointer Dereference)
  Classification   : Dead-Pointer Call on Freed Godot Node!
```

### Forensics Protocol:
1. **Inspect `RCX` and `RDI`**: Godot passes the native `this` / instance pointer in `RCX` (Windows x64) or `RDI` (Linux x64).
2. **Instance ID Verification**: Verify whether the monotonic 64-bit instance ID in `ObjectDB` still matches the object wrapper.
3. **Remedy**: Ensure the caller checks `#alive?` before dispatch, or call `check_alive!` before invoking engine methods.

---

## 6. Multiplayer Lockstep Debugging

The debugger supports concurrent multi-process debugging across a dedicated Server and multiple Clients:
- **Server Session Tab**: Attached to the host game instance (`--server`).
- **Client Session Tabs**: Attached to client instances (`--client-1`, `--client-2`).
- **Role Badges**: Server (Cyan), Client (Green/Yellow).
- **Wireshark-Style Packet Tracing**: Inspects RPC packets, transfer modes (`reliable`/`unreliable`), and channel multiplexing in real time.
