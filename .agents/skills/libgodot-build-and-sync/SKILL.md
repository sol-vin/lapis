---
name: libgodot-build-and-sync
description: >-
  Build, compile, and synchronize the entire LibGodot toolchain across all consumers.
  Use when compiling the GDExtension bridge, test suite, examples, starter template,
  or resolving Windows shadow DLL file-locking.
---

# LibGodot Build & Synchronization Runbook

This skill provides step-by-step instructions for compiling and synchronizing the LibGodot toolchain across all targets in the workspace.

## Core Rule: Always Use `make all`

Never compile subprojects or individual targets in isolation (`make bridge`, `make test_project`, `make game_dll`).
Always invoke:
```bash
make all
```
Or for optimized release builds:
```bash
make all RELEASE=1
```

### Why `make all` is Mandatory:
LibGodot utilizes a multi-consumer architecture. When code changes in `src/` or the bridge, binaries must be built and synchronized across:
- `bin/`: Primary bridge, host library, and runner artifacts
- `template/bin/`: Starter game template binaries
- `template-addon/dist/`: Redistributable addon binaries
- `examples/*/bin/`: All example showcase projects

`make all` guarantees that `crystal_bridge.dll`, `game.dll`, and runtime DLLs (`gc.dll`, `iconv-2.dll`, `pcre2-8.dll`, `libgodot.dll`) remain completely in sync.

---

## Build Targets Reference

| Target | Command | Purpose |
| :--- | :--- | :--- |
| **All (Default)** | `make all` | Compiles bridge, host test suite, examples, template, syncs all DLLs, and runs verification tests. |
| **Release Build** | `make all RELEASE=1` | Compiles with release optimizations (`--release -O3`, `-DLIBGODOT_RELEASE=1 -DNDEBUG`). |
| **Standalone Executable** | `make game_exe` | Compiles Crystal host executable `bin/game.exe` (Mode B). |
| **Addon Sync** | `make addons` | Synchronizes `addons/crystal_integration` across all consumer directories. |
| **Clean** | `make clean` | Removes compiled game/bridge binaries while preserving `libgodot.dll` and runtime DLLs. |

---

## Windows Shadow Copying & File Locking

When running inside the Godot Editor (`make editor` or `godot.exe --editor --path .`):
1. On Windows, `LoadLibraryA` locks loaded DLL files.
2. In development mode (without `RELEASE=1`), `crystal_bridge.cpp` copies `bin/game.dll` to a timestamped shadow copy: `bin/game_loaded_<PID>_<TIMESTAMP>.dll`.
3. The bridge loads the shadow copy, leaving `bin/game.dll` unlocked for recompilation.
4. **Never manually delete active `game_loaded_*.dll` files while Godot is running**.
5. When Godot exits, old shadow files are automatically pruned on the next startup.

---

## Verification After Build

Always verify that:
1. `bin/crystal_bridge.dll` and `bin/game.dll` exist and have current timestamps.
2. `test/bin/crystal_bridge.dll` and `test/bin/game.dll` match `bin/`.
3. Running `make test` executes cleanly without link or runtime errors.
