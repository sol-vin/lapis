---
name: lapis-doctor-diagnostics
description: >-
  Diagnose developer environment, toolchain prerequisites, and runtime dependencies using lapis doctor.
  Use when troubleshooting build failures, verifying Crystal/Make/Godot/radare2/Git installations, or resolving PATH and DLL issues.
---

# Lapis Doctor & Toolchain Diagnostics Runbook

The `lapis doctor` command is the automated diagnostic tool for validating the developer environment, toolchain binaries, Godot engine compatibility, and runtime library integrity.

---

## 1. Quick Command Reference

```bash
# Run standard environment diagnostics
lapis doctor

# Run verbose diagnostics with detailed paths and version outputs
lapis doctor --verbose

# Run diagnostics with automated repair suggestions
lapis doctor --fix
```

---

## 2. The 7 Core Toolchain Checks

`lapis doctor` audits 7 vital components required for full Lapis development:

### 2.1. Crystal Compiler (`crystal`)
- **Requirement**: Crystal 1.10.0 or higher.
- **Check**: Executes `crystal --version` and inspects `CRYSTAL_PATH`.
- **Troubleshooting**: If missing or outdated, install via Scoop (`scoop install crystal`) or your system package manager.

### 2.2. GNU Make (`make`)
- **Requirement**: GNU Make 4.0 or higher.
- **Check**: Verifies `make --version` and checks support for parallel execution (`-j`).
- **Troubleshooting**: On Windows, install via Scoop (`scoop install make`).

### 2.3. Godot Engine (`godot`)
- **Requirement**: Targeted Godot 4.x engine binary (e.g. 4.8-dev6).
- **Check**: Verifies local `godot.exe` or `GODOT_BIN` matches the version declared in `godot-version.yml`.
- **Troubleshooting**: Run `lapis setup` to download the officially targeted Godot binary automatically.

### 2.4. C++ Compiler (`g++` / `clang++` / `cl`)
- **Requirement**: C++17 compatible compiler for building `crystal_bridge.dll`.
- **Check**: Verifies compiler presence and flags.
- **Troubleshooting**: On Windows, ensure MinGW-w64 or MSVC is installed and in PATH.

### 2.5. Crystalline Language Server (`crystalline`)
- **Requirement**: Crystalline executable for IDE code intelligence.
- **Check**: Searches PATH and workspace `bin/` directory.
- **Troubleshooting**: Download from GitHub Releases or build via `shards build`.

### 2.6. radare2 Native Debugger (`radare2`)
- **Requirement**: radare2 for native Windows debugging, decompilation (pdc), and crash inspection.
- **Check**: Executes `radare2 -v` and tests native pseudo-C decompiler (`pdc`).
- **Troubleshooting**: Install radare2 (`scoop install radare2` or `winget install radare2.radare2`).

### 2.7. Git Version Control (`git`)
- **Requirement**: Git 2.20+ for addon installation and shard management.
- **Check**: Validates git executable and git config.

---

## 3. Runtime Dependency Auditing (`lapis deps`)

Beyond compilers, Lapis verifies required runtime shared libraries:
- **`libgodot.dll`**: The LibGodot engine shared library.
- **`crystal_bridge.dll`**: The C++ GDExtension loader bridge.
- **`gc.dll`**: Boehm-Demers-Weiser conservative Garbage Collector DLL.
- **`pcre2-8.dll`**: Regular expressions library required by Crystal CRT.
- **`iconv-2.dll`**: Character encoding conversion library.

If any runtime DLL is missing, run:
```bash
lapis deps
```
This automatically restores missing DLLs from workspace caches or embedded binary assets and synchronizes them across all destination folders.

---

## 4. Diagnosing Common Failures

### "Godot version mismatch"
- **Cause**: The Godot engine in PATH is a different minor or dev version than declared in `godot-version.yml`.
- **Fix**: Run `lapis setup` to pull the exact matching Godot build.

### "Access Violation / 0xC0000005 on DLL load"
- **Cause**: Missing dependent runtime DLL (`gc.dll` or `pcre2-8.dll`) in the same directory as `game.dll`.
- **Fix**: Run `lapis sync` or `lapis deps` to stage all dependencies next to `game.dll`.

### "Crystalline not found"
- **Cause**: Language server is not installed in PATH or `bin/`.
- **Fix**: Run `lapis ide --vscode` which configures Crystalline fallback paths automatically.
