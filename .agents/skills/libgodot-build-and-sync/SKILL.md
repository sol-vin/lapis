---
name: libgodot-build-and-sync
description: >-
  Build, compile, and synchronize the entire LibGodot toolchain across all consumers.
  Use when compiling the GDExtension bridge, test suite, examples, starter template,
  or resolving Windows shadow DLL file-locking.
---

# LibGodot Build & Synchronization Runbook

This skill provides step-by-step instructions for compiling, hot-reloading, and synchronizing the LibGodot toolchain across all consumers in the workspace.

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
      <td><a href="#1-cardinal-rule-always-use-make-all"><strong>1. Cardinal Rule: Always Use `make all`</strong></a></td>
      <td>Never compile subprojects or individual targets in isolation (make bridge, make test_project, or make game_...</td>
      <td align="center"><code>L60–L89</code></td>
    </tr>
    <tr>
      <td><a href="#2-multi-target-build-lifecycle-dependency-dag"><strong>2. Multi-Target Build Lifecycle & Dependency DAG</strong></a></td>
      <td>flowchart TD</td>
      <td align="center"><code>L90–L118</code></td>
    </tr>
    <tr>
      <td><a href="#3-windows-shadow-copying-hot-reload-mechanics"><strong>3. Windows Shadow Copying & Hot-Reload Mechanics</strong></a></td>
      <td>On Windows, the Win32 LoadLibraryA / LoadLibraryExW system call places a shared read lock on the loaded DLL file on disk.</td>
      <td align="center"><code>L119–L142</code></td>
    </tr>
    <tr>
      <td><a href="#4-build-targets-reference"><strong>4. Build Targets Reference</strong></a></td>
      <td><table></td>
      <td align="center"><code>L143–L198</code></td>
    </tr>
    <tr>
      <td><a href="#5-environment-variables-compiler-flags"><strong>5. Environment Variables & Compiler Flags</strong></a></td>
      <td><table></td>
      <td align="center"><code>L199–L239</code></td>
    </tr>
    <tr>
      <td><a href="#6-post-build-verification-checklist"><strong>6. Post-Build Verification Checklist</strong></a></td>
      <td>Always verify after running make all:</td>
      <td align="center"><code>L240–L246</code></td>
    </tr>
  </tbody>
</table>

---

## 1. Cardinal Rule: Always Use `make all`

**Never compile subprojects or individual targets in isolation** (`make bridge`, `make test_project`, or `make game_dll`).
Always invoke:
```bash
make all
```
Or for optimized production builds:
```bash
make all RELEASE=1
```

### Why `make all` is Mandatory:
LibGodot is a multi-consumer architecture. When code changes in `src/` or the C++ bridge, binaries must be built and synchronized across:
- `bin/`: Primary bridge, host library, CLI, and test runner artifacts
- `template/bin/`: Starter game template binaries
- `template-addon/dist/`: Redistributable addon binaries
- `examples/*/bin/`: All example showcase projects (e.g. `examples/basic_demo/bin/`)

`make all` guarantees:
1. `src/bridge/crystal_bridge.cpp` is compiled into `bin/crystal_bridge.dll`.
2. Runtime dependencies (`gc.dll`, `iconv-2.dll`, `pcre2-8.dll`, `libgodot.dll`) are verified and staged.
3. GDExtension manifests (`.gdextension`) and editor plugins are synchronized across all projects.
4. Host binaries (`bin/game.dll`, `bin/game.exe`) are compiled.
5. All showcase projects in `examples/` are compiled and synchronized.
6. Starter templates (`template/bin/game.dll`, `template-addon/dist/`) are compiled and synchronized.
7. Verification test suites execute to guarantee zero compilation or link errors.

---

## 2. Multi-Target Build Lifecycle & Dependency DAG

```mermaid
flowchart TD
  BridgeSrc["src/bridge/crystal_bridge.cpp"] -->|CXX (C++17)| BridgeDLL["bin/crystal_bridge.dll"]
  EnginePrelude["src/libgodot.cr + src/lapis.cr"] --> GameDLL["bin/game.dll"]
  HostApp["src/main.cr"] --> GameDLL
  HostApp -->|Crystal CRT| GameExe["bin/game.exe"]

  subgraph RuntimeDeps["Shared Runtime DLLs"]
    GCDLL["bin/gc.dll"]
    PCREDLL["bin/pcre2-8.dll"]
    IconvDLL["bin/iconv-2.dll"]
    GodotDLL["bin/libgodot.dll"]
  end

  subgraph Consumers["Multi-Target Consumers"]
    Template["template/bin/"]
    TemplateAddon["template-addon/dist/"]
    Examples["examples/*/bin/"]
  end

  BridgeDLL -->|make sync| Consumers
  GameDLL -->|make sync| Consumers
  RuntimeDeps -->|make sync| Consumers
```

---

## 3. Windows Shadow Copying & Hot-Reload Mechanics

On Windows, the Win32 `LoadLibraryA` / `LoadLibraryExW` system call places a shared read lock on the loaded DLL file on disk. This prevents the Crystal compiler from overwriting `game.dll` while the Godot Editor or game process is running.

### How Shadow Loading Works:
1. **Development Mode** (Default, without `RELEASE=1`):
   - When Godot loads `crystal_bridge.dll`, the bridge inspects `bin/game.dll`.
   - Instead of loading `game.dll` directly, it generates a unique timestamped filename:
     `bin/game_loaded_<PID>_<TIMESTAMP>.dll` (e.g. `bin/game_loaded_14920_1728045123.dll`).
   - The bridge copies `game.dll` to this shadow file and calls `LoadLibraryA` on the shadow copy.
   - This leaves `bin/game.dll` **unlocked on disk**, allowing the Crystal compiler to recompile freely at any time.
2. **Hot-Reload Trigger (F5 in Godot Editor)**:
   - Pressing **F5** in the Godot Editor triggers `EditorPlugin._build()` in `addons/crystal_integration/crystal_integration.gd`.
   - `crystal_integration.gd` triggers a background recompile of `bin/game.dll`.
   - Upon completion, `crystal_bridge.cpp` compares the disk timestamp of `bin/game.dll` with the currently loaded shadow DLL.
   - If newer, `crystal_bridge.cpp` unloads the old shadow DLL via `FreeLibrary`, creates a new timestamped shadow copy, calls `LoadLibraryA`, and reinitializes GDExtension ClassDB bindings.
3. **Automated Shadow Pruning**:
   - On startup, `crystal_bridge.cpp` enumerates existing `game_loaded_*.dll` files in `bin/`.
   - It checks the PID encoded in the filename. If the corresponding process is no longer running, it deletes the stale shadow file to prevent disk clutter.
4. **Production Mode (`RELEASE=1`)**:
   - When building with `RELEASE=1`, shadow loading is disabled. `game.dll` is loaded directly by the engine for zero filesystem overhead.

---

## 4. Build Targets Reference

<table>
  <thead>
    <tr>
      <th align="left">Target</th>
      <th align="left">Command</th>
      <th align="left">Purpose & Execution Details</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>All (Default)</strong></td>
      <td><code>make all</code></td>
      <td>Compiles C++ bridge, host DLLs, template, examples, syncs dependencies, and runs verification tests.</td>
    </tr>
    <tr>
      <td><strong>Release Build</strong></td>
      <td><code>make all RELEASE=1</code></td>
      <td>Compiles with release optimizations (<code>--release -O3</code>, <code>-DLIBGODOT_RELEASE=1 -DNDEBUG</code>).</td>
    </tr>
    <tr>
      <td><strong>Test Suite</strong></td>
      <td><code>make test</code></td>
      <td>Executes headless Crystal specs, editor driver tests, and runtime test runner.</td>
    </tr>
    <tr>
      <td><strong>Launch Game</strong></td>
      <td><code>make run</code></td>
      <td>Launches Godot with the host project scene (<code>scenes/main_test_runner.tscn</code>).</td>
    </tr>
    <tr>
      <td><strong>Launch Editor</strong></td>
      <td><code>make editor</code></td>
      <td>Launches the Godot Editor on the host project (<code>godot.exe --editor --path .</code>).</td>
    </tr>
    <tr>
      <td><strong>Directory Sync</strong></td>
      <td><code>make sync</code></td>
      <td>Synchronizes bridge, runtime DLLs, and addons to <code>template/</code> and <code>examples/</code>.</td>
    </tr>
    <tr>
      <td><strong>Clean</strong></td>
      <td><code>make clean</code></td>
      <td>Removes compiled game/bridge binaries while safely preserving <code>libgodot.dll</code> and runtime DLLs.</td>
    </tr>
    <tr>
      <td><strong>Documentation</strong></td>
      <td><code>make docs</code></td>
      <td>Generates offline HTML documentation in <code>docs/</code> using <code>crystal docs</code>.</td>
    </tr>
  </tbody>
</table>

---

## 5. Environment Variables & Compiler Flags

<table>
  <thead>
    <tr>
      <th align="left">Variable</th>
      <th align="left">Default Value</th>
      <th align="left">Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>RELEASE</code></td>
      <td><code>0</code></td>
      <td>Set to <code>1</code> for production optimization (<code>--release -O3</code>, disables shadow loading).</td>
    </tr>
    <tr>
      <td><code>CXX</code></td>
      <td><code>g++</code></td>
      <td>C++ compiler used to compile <code>src/bridge/crystal_bridge.cpp</code>.</td>
    </tr>
    <tr>
      <td><code>CXXFLAGS</code></td>
      <td><code>-std=c++17 -O2 -g</code></td>
      <td>C++ compiler flags for bridge (retains debug symbols for radare2).</td>
    </tr>
    <tr>
      <td><code>GODOT_BIN</code></td>
      <td><code>godot.exe</code></td>
      <td>Path to Godot engine executable for running tests and launching editor.</td>
    </tr>
    <tr>
      <td><code>CRYSTAL_PATH</code></td>
      <td><code>src;...</code></td>
      <td>Lookup path for Crystal libraries and engine bindings.</td>
    </tr>
  </tbody>
</table>

---

## 6. Post-Build Verification Checklist

Always verify after running `make all`:
1. `bin/crystal_bridge.dll` and `bin/game.dll` exist and have current timestamps.
2. `template/bin/crystal_bridge.dll` and `template/bin/game.dll` match `bin/`.
3. Running `make test` executes cleanly without link or runtime errors.
