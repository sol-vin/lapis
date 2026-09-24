# Agent Guidelines for LibGodot

This document is the authoritative engineering and operational manual for AI agents and contributors working on the **LibGodot for Crystal** project. Every agent working in this repository must read, understand, and strictly abide by the rules, architectural invariants, and verification protocols outlined below.

---

## 1. Architectural Invariants & Directory Separation

The project maintains a strict boundary between the core engine bindings library, test projects, showcase examples, and starter templates.

```
libgodot/
├── src/                          # Reusable LibGodot library & root host application
│   ├── libgodot.cr               # Root library entry point (require "libgodot")
│   ├── lapis.cr                  # Lapis prelude & engine extensions
│   ├── main.cr                   # Root host game entry point & test runner panel
│   ├── bridge/crystal_bridge.cpp # C++ GDExtension loader bridge
│   └── libgodot/                 # Core macros, C-API, bridge, docs, and generated classes
├── spec/                         # Unified Crystal specifications & test suites
│   ├── spec_helper.cr            # Common spec helper and test nodes
│   ├── editor_driver_spec.cr     # In-editor @tool and runtime tests via EditorDriver
│   ├── suites_registry_spec.cr   # Verification of test suite registry completeness
│   ├── suites/                   # 40+ modular engine test suites
│   └── fixtures/                 # Spec test targets & fixtures
├── scenes/                       # Root Godot host project scenes (main_test_runner.tscn, etc.)
├── scripts/                      # GDScript test fixtures and interop nodes
├── project.godot                 # Root Godot host project configuration
├── addons/                       # GDExtensions & Editor Plugins
│   ├── crystal_integration/      # Official GDExtension manifest & editor build hook (shipped)
│   ├── dummy_audio/              # Test addon for multi-addon isolation (not shipped)
│   ├── dummy_dialogue/           # Test addon for dialogue isolation (not shipped)
│   ├── dummy_inventory/          # Test addon for inventory isolation (not shipped)
│   └── test_runner/              # In-editor test runner dock addon (not shipped)
├── examples/                     # Independent consumer showcase projects
│   └── basic_demo/               # Standard showcase project
├── template/                     # Starter template for new standalone games
├── template-addon/               # Starter template for redistributable Godot addons
├── bin/                          # Output binaries, bridge DLL, and shared dependencies
└── .agents/                      # Agent skills, runbooks, and customizations
```

### Architectural Rules:
1. **Root Project is the Host & Test Runner**:
   - The workspace root is a complete, runnable Godot project (`project.godot`, `scenes/`, `scripts/`).
   - The entry point for the root game host is `src/main.cr`, which compiles to `bin/game.dll` (GDExtension host/editor) and `bin/game.exe` (standalone LibGodot host).
   - `src/main.cr` mounts `@tool` in-editor testers (`ToolTester2D`, `ToolTester3D`), the interactive runtime UI panel (`RunTesterPanel`), and loads modular test suites.
2. **Unified Crystal Specifications & Test Suites in `spec/`**:
   - All tests live under `spec/`.
   - Headless unit specs (`spec/core_spec.cr`, `spec/math_spec.cr`, etc.) validate language bindings and GC behavior.
   - `spec/editor_driver_spec.cr` leverages `Lapis::Test::EditorDriver` to launch Godot headlessly and execute live in-editor tool tests and runtime test suites.
   - All 40+ modular engine test suites reside in `spec/suites/` using the unified `Lapis::Test` apparatus (`test_suite`, `test`).
3. **Addon Isolation & Packaging Safety**:
   - `addons/crystal_integration` is the official, redistributable GDExtension plugin.
   - Test dummy addons (`dummy_audio`, `dummy_dialogue`, `dummy_inventory`, `test_runner`) live in `addons/` alongside `crystal_integration` for multi-addon ClassDB conflict tests.
   - **Dummy addons are NEVER shipped**: release packaging (`package addon`, `package deb`, `package windows-installer`) strictly bundles only `crystal_integration`.
4. **`examples/` and `template/` are independent consumers**:
   - Each example and template project is a self-contained Godot project with its own `project.godot`, `shard.yml`, `Makefile`, and `scenes/`.
   - New examples must be scaffolded using `make new-example NAME=<name> [DIR=<path>]` (or `bin/lapis scaffold example <name>`).
   - New addons must be scaffolded using `make new-addon NAME=<name> [DIR=<path>] [AUTHOR="..."] [DESC="..."]` (or `bin/lapis scaffold addon <name>`).
   - All examples are compiled via `make examples`.

---

## 2. Dual-Paradigm Execution Model

LibGodot supports two distinct execution paradigms designed for both rapid in-editor iteration and lean standalone production shipping:

<table>
  <thead>
    <tr>
      <th align="left">Paradigm</th>
      <th align="left">Mode A: GDExtension In-Editor</th>
      <th align="left">Mode B: Standalone LibGodot Host</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Host Binary</strong></td>
      <td>Godot Engine (<code>godot.exe</code>)</td>
      <td>Crystal Executable (<code>bin/game.exe</code>)</td>
    </tr>
    <tr>
      <td><strong>Primary DLLs</strong></td>
      <td><code>bin/crystal_bridge.dll</code> + <code>bin/game.dll</code></td>
      <td><code>bin/libgodot.dll</code> (or <code>.so</code>)</td>
    </tr>
    <tr>
      <td><strong>GC Bootstrapping</strong></td>
      <td>Initialized by C++ loader bridge (<code>GC_init()</code>)</td>
      <td>Initialized natively by Crystal CRT</td>
    </tr>
    <tr>
      <td><strong>Hot Reloading</strong></td>
      <td>Automatic timestamped shadow DLL loading on F5 / F6</td>
      <td>Recompilation of standalone executable required</td>
    </tr>
    <tr>
      <td><strong>Primary Use Case</strong></td>
      <td>Development, editor tool scripts, level design</td>
      <td>Production shipping, headless CI, embedded runners</td>
    </tr>
  </tbody>
</table>

### Mode A Mechanics & Windows Shadow Loading:
- On Windows, loading a DLL via `LoadLibraryA` locks the file on disk, preventing the compiler from overwriting `game.dll`.
- In development mode, `crystal_bridge.cpp` creates a timestamped shadow copy (`game_loaded_<PID>_<TIMESTAMP>.dll`) and loads the shadow copy.
- This leaves `bin/game.dll` unlocked so Crystal can rebuild freely while the Godot Editor remains open.
- Pressing **F5** in the editor triggers `EditorPlugin._build()` in `addons/crystal_integration/crystal_integration.gd`, recompiling `game.dll` and reloading instantly.

---

## 3. Build Tooling, Compilation & Synchronization

### The Golden Build Rule: Always Use `make all`
- **Whenever compiling or rebuilding, agents MUST run `make all` (or `make all RELEASE=1`)**.
- **NEVER run partial build targets** (e.g. `make bridge`, `make test_project`, or `make game_dll`) in isolation without syncing.
- Running `make all` guarantees:
  1. `src/bridge/crystal_bridge.cpp` is compiled into `bin/crystal_bridge.dll`.
  2. Runtime dependencies (`gc.dll`, `iconv-2.dll`, `pcre2-8.dll`, `libgodot.dll`) are verified.
  3. GDExtension manifests and addons are updated across all projects.
  4. Test suite project (`test/bin/game.dll`) is compiled.
  5. All showcase projects in `examples/` are compiled.
  6. Starter templates (`template/bin/game.dll`, `template-addon/dist/`) are compiled.
  7. All output binaries are synchronized across `bin/`, `test/bin/`, `template/bin/`, and `examples/*/bin/`.
  8. Full test suite verification runs.
- **Monitoring Rule**: When running `make all` as a background task, agents must check its progress every 30 seconds (via `schedule` or `manage_task` status check) to actively detect progress, avoid stalls, and monitor build step transitions.

### Build Target Reference:
- `make all`: Full workspace build, synchronization, and test run.
- `make all RELEASE=1`: Full release build with `--release -O3` optimizations.
- `make test`: Executes specs, headless in-editor tool tests, and runtime test project (supports `TUI=1` or `NO_TUI=1`).
- `make run-test`: Unified test runner (`TUI=1`, `NO_TUI=1`, `UI=1`, `SKIP_SPECS=1`, etc.).
- `make run-ci-local`: Executes local GitHub Actions CI matrix harness.
- `make docs`: Generates offline HTML API documentation into `docs/` using `crystal docs`.
- `make run`: Launches the test project directly in Godot.
- `make editor`: Opens the test project in the Godot Editor (`godot.exe --editor --path test`).
- `make run-editor`: Unified Godot editor launcher (`PROJECT=<path>`, `LOG=<file>`, `QUIT=<sec>`, `LLDB=1`).
- `make debug`: Runs the test project (or `PROJECT=<path>`) under LLDB debugger.
- `make debug-editor`: Launches the Godot Editor under LLDB debugger.
- `make new-addon`: Scaffolds a new GDExtension addon (`NAME=<name>`, `DIR=<path>`, etc.).
- `make new-example`: Scaffolds a new showcase example (`NAME=<name>`, `DIR=<path>`).
- `make package-game`: Packages playable game (`PROJECT=<dir>`, `RELEASE=1`, `FORCE=1`).
- `make package-release`: Packages all release archives and checksums into `bin/release_dist/`.
- `make setup-dev`: Downloads and sets up the targeted Godot engine binary.
- `make clean`: Cleans build artifacts while safely preserving runtime DLLs (`libgodot.dll`, `gc.dll`).
- `make install`: Installs `lapis` CLI toolchain globally to system/user PATH (`INSTALL_DIR=<path>`, `PREFIX=<path>`).
- `make uninstall`: Uninstalls `lapis` CLI toolchain globally.

---

## 4. Memory Safety, Object Lifecycle & Dead-Pointer Protection

LibGodot bridges two distinct memory models:
- **Crystal Boehm GC**: Collects Crystal heap objects, fibers, and wrapper instances (`Godot::Object`).
- **Godot ObjectDB & Reference Counting**: Manages native C++ engine nodes and refcounted resources.

### The Dead-Pointer Hazard
If an object is destroyed in Godot or GDScript (e.g. via `queue_free()` or `free()`), standard C-API bindings retain a raw C++ pointer to deallocated memory. Dereferencing this dead pointer causes an immediate, unrecoverable **segmentation fault (`ACCESS_VIOLATION / 0xC0000005`)** that crashes the game without a stack trace.

### Safety Invariants Every Agent Must Maintain:
1. **Monotonic 64-bit Instance ID Tracking**:
   Every `Godot::Object` wrapper tracks its engine-assigned `@instance_id`. Godot's `ObjectDB` generates monotonic 64-bit IDs that never collide with recycled heap addresses.
2. **Always Enforce `#check_alive!`**:
   Before performing method dispatches, reflection calls, or scene operations on Godot objects, LibGodot calls `#check_alive!`. If the object was freed by Godot or GDScript, it sets `@pointer = null` and raises `Godot::DisposedObjectError`.
3. **Defensive Inspection with `#alive?` and `#destroyed?`**:
   When maintaining references to transient scene entities (enemies, bullets, UI elements), check `#alive?` before accessing them.
4. **Node Ownership Rules**:
   - Nodes added to the scene tree are owned by the tree; call `node.queue_free` to let Godot deallocate them cleanly at frame end.
   - Unparented standalone nodes created via `Godot.create(Godot::Node2D)` are **not** owned by Godot; you **MUST** call `node.destroy` when done with them to prevent native C++ memory leaks.
5. **RefCounted / Resource Rules**:
   - `RefCounted` and `Resource` instances are managed by Godot's atomic reference counter (`reference()`, `unreference()`). Never call manual `.destroy` on refcounted resources.

---

## 5. Concurrency, Fibers & Thread Safety

Godot's runtime is fundamentally single-threaded for scene graph operations. Agents writing concurrent code must follow these rules:

1. **SceneTree Modifications Must Stay on the Main Thread**:
   - **NEVER** call `add_child`, `remove_child`, `reparent`, or `queue_free` from an OS background thread (`Thread.new`) or un-yielded fiber. Doing so corrupts Godot's internal child arrays and causes engine crashes.
2. **Cooperative Fibers Require Yielding in `_process`**:
   - Godot controls the OS main loop. Spawned fibers (`spawn do ... end`) will starve unless the main thread cooperatively yields via `Fiber.yield` in `_process(delta)`.
3. **Avoid Blocking `sleep` in Fibers and Threads**:
   - **Never call top-level `sleep` in a spawned fiber**; Godot does not pump Crystal's LibEvent/IOCP event loop, so the fiber will hang indefinitely. Use Godot's `get_tree.create_timer(sec)` or frame delta accumulators instead.
   - **Never call top-level `sleep` in `Thread.new`**; in Crystal 1.20+, top-level `sleep` yields to an `ExecutionContext`, raising `NilAssertionError: Fiber#execution_context cannot be nil`. For genuine OS thread sleeps, use `Crystal::System::Thread.sleep(duration)`.
4. **Use `Channel(T)` for Background Worker Processing (Actor Pattern)**:
   - Offload heavy computation, pathfinding, or procedural generation to background OS threads (`Thread.new`).
   - Workers send immutable data back via `Channel(T)`.
   - **Always use buffered channels (`Channel(T).new(capacity)`) across OS threads.** In Crystal 1.20+, unbuffered channels (`Channel(T).new`) suspend the calling fiber when no receiver is ready; on raw OS threads (`Thread.new`), `Fiber#execution_context` is `nil`, so suspending raises `NilAssertionError: Fiber#execution_context cannot be nil`.
   - The main thread drains the channel non-blockingly during `_process(delta)` using `select ... when ... else` or after `thread.join`.
5. **Cross-Thread Dispatch via `call_deferred`**:
   - When background threads need to notify Godot nodes, use `node.call_deferred("method_name", *args)`. Godot buffers these into its thread-safe `MessageQueue` for dispatch on the main thread.
6. **Protect Shared Crystal Collections with `::Thread::Mutex`**:
   - Standard Crystal `Hash` and `Array` are not thread-safe. When caching state across threads, wrap access in `::Thread::Mutex.new`.
7. **Awaiting Signals & Timers via `await`**:
   - LibGodot supports two complementary signal awaiting paradigms:
     - **First-Class Bound Signals**: `await(enemy.died)` or `enemy.died.await` (compile-time checked, auto-generated from `signal` declarations).
     - **Classic Target & String Identifier**: `await(enemy, "died")` or `enemy.await_signal("died")` (ideal for dynamic runtime strings, RPC events, or GDScript interop).
   - Both approaches support optional timeout arguments (`timeout_sec: 5.0`).
   - Use `await(timer.timeout)`, `await(timer)`, or `await(duration_seconds)` for non-blocking delays without halting the engine main loop.
   - Awaiting fibers validate `#alive?` on every frame slice, raising `Godot::DisposedObjectError` if the target object is freed before the signal arrives.

---

## 6. Node DSL, Exports & Doc Comment Harvesting

### Node Authoring Conventions:
```crystal
require "libgodot"

# Player character with physics movement and health tracking
node Player < CharacterBody3D do
  # Movement speed in meters per second
  @[Export(range: 1.0_f32..20.0_f32, step: 0.5_f32)]
  property speed : Float32 = 7.0_f32

  # Maximum hit points
  @[Export(range: 10..500, step: 10)]
  property max_health : Int32 = 100

  # Emitted when player health changes
  signal health_changed(current : Int32, max_health : Int32)

  # Emitted when player dies
  signal died

  def _ready : Void
    Godot.print("Player initialized: #{name}")
  end

  def _physics_process(delta : Float64) : Void
    # Fixed-rate physics step
  end
end
```

### Macro Directives:
- **`node ClassName < ParentNode do ... end`**: Declares a Godot class registered in `ClassDB`.
- **`@[Export]` annotations**: Full support for ranges (`@[ExportRange]`), enums (`@[ExportEnum]`), file pickers (`@[ExportFile]`, `@[ExportDir]`), bitmasks (`@[ExportFlags]`), easing curves (`@[ExportExpEasing]`), and buttons (`@[ExportToolButton]`).
- **`signal name(arg : Type)`**: Automatically registers signal with `ClassDB` and synthesizes type-safe helper `emit_<name>(...)`.
- **`@[Tool]`**: Marks the class to execute inside the Godot Editor in real time.
- **`@[RPC]`**: Configures multiplayer network replication mode, transfer mode, and channels.
- **Automated Doc Comment Harvesting**:
  - Regular `# comments` above classes, properties, signals, and methods are extracted at compile time and registered into Godot's `EditorHelp` XML database for in-editor tooltips and offline F1 Help.

---

## 7. Testing Protocols & Quality Gates

### Multi-Tier Test Suite:
1. **Automated Specifications (`spec/` and `tools/lapis/spec/`)**:
   - **Tier 1a: Engine & Core Bindings Specs (`spec/`)**: Headless unit specs covering GC object retention, dynamic scaling (200+ properties), Variant type round-trips, and Vector math (`spec/core_spec.cr`, `spec/math_spec.cr`, `spec/safety_spec.cr`, `spec/features_spec.cr`).
   - **Tier 1b: Lapis Toolchain & CLI Specs (`tools/lapis/spec/`)**: CLI argument parsing, subcommand help dispatches, standalone execution from isolated directories using embedded `BakedFileSystem` assets, and per-platform packaging tests. Run via `make spec-cli` or `cd tools/lapis && crystal spec`.
   - **Tier 1c: Headless Architectural & Integration Specs (`spec/`)**: Standalone verification scripts for LibGodot dynamic loading, API coverage, project scaffolding integrity, and tool environment discovery.
   - **Tier 1d: In-Editor & Runtime Driver Specs (`spec/editor_driver_spec.cr`)**: Executes in-editor tool tests and runtime suites in headless Godot using `Lapis::Test::EditorDriver`.
2. **Headless In-Editor `@tool` Tests (`ToolTester2D`, `ToolTester3D`)**:
   - Run in Godot with `--headless --editor --path .` to verify editor plugins, tool button actions, and live scene instantiation.
3. **Standalone Runtime Host & Runner (`bin/game.exe`, `bin/game.dll`)**:
   - Regular and portable standalone runners executing 40+ modular test suites in `spec/suites/` using the unified `Lapis::Test` apparatus (`test_suite`, `before_each`/`after_each` lifecycle fixtures, exact source locations, Godot domain assertions).
4. **Quantitative Zero Memory Leak Verification**:
   - Standardized via `Lapis::Test.assert_no_leak`, leveraging Godot's `Performance` singleton monitors (`OBJECT_COUNT`, `OBJECT_NODE_COUNT`, `MEMORY_STATIC`) and Crystal's `GC.collect` to mathematically verify zero object or memory leaks.
5. **Interactive Terminal User Interface (TUI)**:
   - `lapis test` automatically launches an interactive double-buffered ANSI TUI dashboard on interactive terminals (or when invoked with `--tui` / `make test TUI=1`).
   - Features real-time multi-phase status checklist, live progress metrics, split-pane rolling execution logs with syntax coloring, interactive phase navigation (`↑`/`↓`/`j`/`k`), drill-down phase log inspection modals (`Enter`/`Space`), and help overlay (`?`).
   - Gracefully falls back to clean streaming output in non-TTY environments, automated CI, or when `--no-tui` / `make test NO_TUI=1` is specified.

### Quality Gate Requirements:
- **Never add shortcuts, mock classes, or fake implementations** into `libgodot` solely to make a test pass. Features must be properly implemented through Godot's GDExtension C-API and the Crystal runtime bridge.
- Before committing any changes, run `make all` (or `bin/lapis test`) and verify exit code 0.

### LLDB Diagnostic Protocols:
Whenever debugging segmentation faults (`0xC0000005`), dead pointers, memory corruption, or unexpected aborts:
1. **Always Compile Bridge with Debug Symbols**:
   - `crystal_bridge.dll` is compiled with `-g` in `Makefile` (`CXXFLAGS ?= -std=c++17 -O2 -g ...`).
2. **Use LLDB Directly**:
   - Run under LLDB via `make debug` or `make debug-editor`.
   - Run with `-Batch` to automatically capture the full backtrace (`bt`) upon any uncaught exception.
3. **Hardware Watchpoints for Memory/Stack Corruption**:
   - If memory addresses or pointers become corrupted across calls, set a hardware watchpoint at the allocation site:
     `(lldb) watchpoint set expression -s 8 -- (void**)&variable`
   - Continue execution (`c`) to have LLDB break immediately at the exact machine instruction performing the illegal write.

---

## 8. Documentation Standards

1. **Add Extended Architectural Guides to `Docs` Module**:
   - All architecture documentation, topic explanations, and caveats must be added inside `module Docs` in `src/libgodot/docs.cr` as a dummy class or module (e.g. `module J_NEW_FEATURE_GUIDE`).
   - This ensures documentation is compiled into the static docs site via `crystal docs` (`make docs`) and harvested into Godot's offline `EditorHelp` database.
2. **Never Use Markdown Pipe Tables in Docs; Always Use HTML Tables**:
   - Never use Markdown pipe table syntax (`| Header | ... |`) in doc comments or documentation files.
   - Always use standard HTML tables (`<table>`, `<thead>`, `<tr>`, `<th>`, `<tbody>`, `<td>`) to guarantee clean, error-free rendering across Crystal docs generators, web browsers, and Godot's XML documentation parser.

---

## 9. Agent Custom Skills

This repository includes specialized Antigravity agent skills in `.agents/skills/`:
- **`libgodot-build-and-sync`**: Runbook for building the complete toolchain, release builds, and multi-consumer DLL synchronization.
- **`libgodot-test-runner`**: Runbook for executing specs, headless in-editor tests, and runtime test suites.
- **`libgodot-concurrency-safety`**: Safety patterns for fibers, background OS threads, actor channels, and dead-pointer prevention.
- **`libgodot-api-generator`**: Guide for dumping Godot extension API and updating Crystal class bindings.
- **`libgodot-scaffold`**: Guide for scaffolding new showcase examples and GDExtension addons.

<!-- graft:start -->
## Graft — repo context graph

This repo is indexed in `graft/`: small linked markdown nodes that explain each
system and carry exact file:line spans, kept in sync with the code through git.

For ANY task here — understanding how something works, finding where code lives,
or scoping a change — get context from the graph before grepping or opening
source files. Re-ask freely (it's cheap) and reuse literal identifiers you
already have (symbol, error string, file name) as the query. New to this repo?
Run `graft map` first — a token-budgeted orientation (dir clusters, hubs,
hotspots), no LLM, no key.

- Run `graft ask "<your question>" --source` → ranked nodes with the relevant
  code spans inlined (each hit's ≤8-line crux by default; `--full` for whole
  definitions when the crux isn't enough). Match the tool to the task shape:
  for understanding or editing, the top node IS the answer — cite its
  `covers:` file:line spans and edit straight from `--source`. For
  exhaustive tasks ("every occurrence / every caller of this pattern"), ranked
  results are top-N, not complete — run `graft grep "<literal>"` instead
  (exhaustive over indexed files, grouped by enclosing symbol), falling back
  to raw `grep -rn` only for unindexed files.
- `graft skeleton <file>` → every definition's signature + span, ~10× cheaper
  than reading the file; use it to skim an API surface.
- `graft callers <symbol>` gives precomputed, exact edges — who calls this.
  Add `--direction out` for what it calls, or `--depth N` to walk
  transitively for the full blast radius. For structural questions, skip
  ranking and use this directly.
- Or browse: `graft/INDEX.md` lists every node; follow the links.
- Monorepos and folders of multiple repos rank fairly across sub-projects —
  hits carry `[scope/]` labels naming which one they're from. Narrow with
  `graft ask "<task>" --in <scope>/` once you know where you're working.

If a returned span is truncated ("+N more lines"), open the file at that exact
range before finalizing. Only open source files when a node genuinely lacks a
needed detail, and then at the exact file:line the node points to — never
re-read whole files.

After big code changes, refresh the graph with `graft build` (deterministic,
no API key, $0).
<!-- graft:end -->
