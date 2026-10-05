---
name: lapis-doctor-diagnostics
description: >-
  Diagnose developer environment, toolchain prerequisites, and runtime dependencies using lapis doctor.
  Use when troubleshooting build failures, verifying Crystal/Make/Godot/radare2/Git installations, or resolving PATH and DLL issues.
---

# Lapis Doctor & Toolchain Diagnostics Runbook

This skill outlines how to use `lapis doctor` to comprehensively audit developer environments, verify toolchain prerequisites, validate runtime shared libraries, and automatically repair common misconfigurations.

---

## Table of Contents
<table>
  <thead>
    <tr>
      <th align="left">Section</th>
      <th align="left">Description</th>
      <th align="center">Lines</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><a href="#1-quick-command-reference"><strong>1. Quick Command Reference</strong></a></td>
      <td># Run standard environment diagnostics</td>
      <td align="center"><code>L49–L66</code></td>
    </tr>
    <tr>
      <td><a href="#2-the-14-core-diagnostic-categories"><strong>2. The 14 Core Diagnostic Categories</strong></a></td>
      <td>lapis doctor audits 14 distinct subsystems required for building, debugging, and packaging Lapis games:</td>
      <td align="center"><code>L67–L169</code></td>
    </tr>
    <tr>
      <td><a href="#3-automated-repair-with-lapis-doctor---fix"><strong>3. Automated Repair with `lapis doctor --fix`</strong></a></td>
      <td>When invoked with --fix, lapis doctor executes safe, non-destructive automated repairs:</td>
      <td align="center"><code>L170–L179</code></td>
    </tr>
    <tr>
      <td><a href="#4-common-diagnostics-solutions"><strong>4. Common Diagnostics & Solutions</strong></a></td>
      <td>### Scenario A: "Godot version mismatch"</td>
      <td align="center"><code>L180–L193</code></td>
    </tr>
  </tbody>
</table>

---

## 1. Quick Command Reference

```bash
# Run standard environment diagnostics
lapis doctor

# Run verbose diagnostics with full paths, environment variables, and compiler flags
lapis doctor --verbose

# Run diagnostics with automated repair routines
lapis doctor --fix

# Run diagnostics targeting a specific consumer project
lapis doctor --path examples/basic_demo
```

---

## 2. The 14 Core Diagnostic Categories

`lapis doctor` audits 14 distinct subsystems required for building, debugging, and packaging Lapis games:

<table>
  <thead>
    <tr>
      <th align="left">#</th>
      <th align="left">Category</th>
      <th align="left">Requirement</th>
      <th align="left">Verification Check & Automated Fix</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>1</td>
      <td><strong>Crystal Compiler</strong></td>
      <td>Crystal 1.10.0+ (1.20+ recommended)</td>
      <td>Executes <code>crystal --version</code>; checks <code>CRYSTAL_PATH</code>. Fix: Install via Scoop/system package manager.</td>
    </tr>
    <tr>
      <td>2</td>
      <td><strong>GNU Make</strong></td>
      <td>GNU Make 4.0+</td>
      <td>Checks <code>make --version</code>; validates parallel job support (<code>-j</code>). Fix: <code>scoop install make</code>.</td>
    </tr>
    <tr>
      <td>3</td>
      <td><strong>Godot Engine</strong></td>
      <td>Targeted Godot 4.x (e.g. 4.8-dev7)</td>
      <td>Compares engine version against <code>godot-version.yml</code>. Fix: <code>lapis setup</code>.</td>
    </tr>
    <tr>
      <td>4</td>
      <td><strong>C++ Toolchain</strong></td>
      <td>C++17 compiler (g++, clang++, cl)</td>
      <td>Validates ability to compile C++17 loader bridge. Fix: Install MinGW-w64 or Visual Studio Build Tools.</td>
    </tr>
    <tr>
      <td>5</td>
      <td><strong>Crystalline LSP</strong></td>
      <td>Crystalline binary in PATH or bin/</td>
      <td>Checks language server availability for IDE code intelligence. Fix: <code>lapis deps</code> pulls bundled binary.</td>
    </tr>
    <tr>
      <td>6</td>
      <td><strong>radare2 Debugger</strong></td>
      <td>radare2 5.8+</td>
      <td>Validates debugger and pseudo-C decompiler (<code>pdc</code>). Fix: <code>scoop install radare2</code>.</td>
    </tr>
    <tr>
      <td>7</td>
      <td><strong>Git Version Control</strong></td>
      <td>Git 2.20+</td>
      <td>Validates git executable, line endings (<code>core.autocrlf</code>), and submodules.</td>
    </tr>
    <tr>
      <td>8</td>
      <td><strong>GDExtension ABI</strong></td>
      <td>ABI version compatibility</td>
      <td>Checks <code>extension_api.json</code> checksum against engine binary. Fix: <code>lapis bind engine --dump</code>.</td>
    </tr>
    <tr>
      <td>9</td>
      <td><strong>Runtime Libraries</strong></td>
      <td><code>gc.dll</code>, <code>pcre2-8.dll</code>, <code>iconv-2.dll</code>, <code>libgodot.dll</code></td>
      <td>Verifies presence in <code>bin/</code> and all consumer folders. Fix: <code>lapis deps</code> copies missing libraries.</td>
    </tr>
    <tr>
      <td>10</td>
      <td><strong>Windows Shadowing</strong></td>
      <td>Read/Write permissions in <code>bin/</code></td>
      <td>Tests file creation and shadow DLL pruning permissions. Fix: Purges orphaned shadow files.</td>
    </tr>
    <tr>
      <td>11</td>
      <td><strong>Inno Setup Compiler</strong></td>
      <td>Inno Setup 6 (<code>ISCC.exe</code>)</td>
      <td>Searches Program Files, LocalAppData, and PATH for Windows installer creation.</td>
    </tr>
    <tr>
      <td>12</td>
      <td><strong>Addon Isolation</strong></td>
      <td>Unique ClassDB symbols</td>
      <td>Audits <code>addons/</code> manifests to guarantee no duplicate entry points or class collisions.</td>
    </tr>
    <tr>
      <td>13</td>
      <td><strong>Terminal VT100</strong></td>
      <td>ANSI color and raw mode support</td>
      <td>Validates terminal emulator capabilities for interactive Opal TUI dashboard.</td>
    </tr>
    <tr>
      <td>14</td>
      <td><strong>Shard Lockfile</strong></td>
      <td><code>shard.yml</code> and <code>shard.lock</code></td>
      <td>Validates Crystal package graph. Fix: <code>lapis shard check</code> / <code>lapis shard install</code>.</td>
    </tr>
  </tbody>
</table>

---

## 3. Automated Repair with `lapis doctor --fix`

When invoked with `--fix`, `lapis doctor` executes safe, non-destructive automated repairs:
1. **Restores Missing Runtime DLLs**: Copies `gc.dll`, `pcre2-8.dll`, `iconv-2.dll`, and `libgodot.dll` from internal caches into `bin/`, `template/bin/`, and `examples/*/bin/`.
2. **Prunes Stale Shadow DLLs**: Scans `bin/` for orphaned `game_loaded_<PID>_*.dll` files where `<PID>` is no longer alive.
3. **Synchronizes GDExtension Manifests**: Updates `.gdextension` files with matching library filenames and entry symbols.
4. **Validates Shard Dependencies**: Executes `shards check` and runs `shards install` if dependencies are missing.

---

## 4. Common Diagnostics & Solutions

### Scenario A: "Godot version mismatch"
- **Symptom**: `lapis doctor` reports Godot version 4.7-dev while project requires 4.8-dev7.
- **Solution**: Run `lapis setup` to download the officially targeted engine binary directly from Godot build servers.

### Scenario B: "Missing runtime DLL (0xC0000005 on game launch)"
- **Symptom**: Game or editor crashes immediately on startup without log output.
- **Solution**: Run `lapis deps` or `lapis doctor --fix` to stage all required DLLs into the same folder as `godot.exe` and `game.dll`.

### Scenario C: "Inno Setup Compiler (ISCC.exe) not found"
- **Symptom**: `make windows-installer` fails because `ISCC.exe` is absent.
- **Solution**: Install Inno Setup via Scoop (`scoop install inno-setup`) or Winget (`winget install JRSoftware.InnoSetup`).
