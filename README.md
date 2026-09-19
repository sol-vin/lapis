# Lapis for Crystal

[![Crystal](https://img.shields.io/badge/Crystal-1.20+-black.svg?style=flat&logo=crystal)](https://crystal-lang.org)
[![Godot](https://img.shields.io/badge/Godot-4.8--dev5-blue.svg?style=flat&logo=godotengine)](https://godotengine.org)
[![Docs](https://img.shields.io/badge/Docs-Online-blueviolet.svg?style=flat)](https://sol-vin.github.io/lapis/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Lapis for Crystal** provides high-performance Crystal bindings and a bidirectional runtime integration for **Godot Engine 4.8+** using LibGodot and GDExtension. It empowers game developers to write Godot games with native machine speed, complete compile-time type safety, and Ruby-like elegance. https://youtu.be/EKMw_zQjovc

---

## Architecture: Dual-Paradigm Integration

Lapis supports two distinct execution paradigms designed for both rapid in-editor iteration and lean standalone production shipping:

```mermaid
graph TD
    subgraph Mode A: GDExtension In-Editor Workflow
        GE[Godot Editor 4.8] -->|Loads| GDX[addons/crystal_integration/crystal.gdextension]
        GDX -->|Loads| CB[bin/crystal_bridge.dll]
        CB -->|1. Initializes Boehm GC| CRT[Crystal Runtime]
        CB -->|2. Shadow loads| GDL[bin/game_loaded_pid_ts.dll]
        GDL -->|3. crystal_godot_init| REG[ClassDB & EditorHelp]
        REG -->|4. Exposes Nodes & Inspector| GE
        GE -->|F5 / Build Hook| EB[EditorPlugin._build]
        EB -->|Recompiles| GDL
    end

    subgraph Mode B: Standalone LibGodot Host Paradigm
        EXE[bin/game.exe] -->|1. Owns main Entry Point| CRTM[Crystal Boehm GC]
        EXE -->|2. In-Memory Boot| LGD[bin/libgodot.dll]
        LGD -->|3. libgodot_create_godot_instance| GINST[Godot Engine Instance]
        GINST -->|4. Pass GDExtension C-API Table| EXE
        EXE -->|5. Step Main Loop & Dispatch| WIN[Game Window & Audio]
    end
```

- **Mode A: GDExtension In-Editor Workflow (`game.dll` + `crystal_bridge.dll`)**:
  Develop inside the Godot Editor (`make editor`). The native C++ bridge boots the Boehm GC and shadow-copies `game.dll` to prevent Windows file locking. Pressing **F5** in the editor triggers live compilation and reload.
- **Mode B: Standalone LibGodot Host Paradigm (`game.exe` + `libgodot.dll`)**:
  Crystal owns `main()`, initializes its runtime natively, boots Godot in-memory, and controls the main loop for standalone shipping builds (`make game_exe`).

> Detailed architectural deep-dive is available in [`Docs::A_ARCHITECTURE`](src/libgodot/docs.cr) and [`Docs::B_COMPILATION_AND_BUILD`](src/libgodot/docs.cr).

---

## Features

- **Intuitive Node DSL**: Define Godot nodes with concise `node ClassName < ParentNode do ... end` syntax.
- **Inspector Export System**: Complete support for `@[Export]`, numeric ranges, enums, file pickers, bitmask flags, groups, categories, and tool buttons.
- **Automated Doc Comment Harvesting**: Standard Crystal `# comments` above classes, properties, signals, and methods are extracted at compile time and registered into Godot's `EditorHelp` XML database for in-editor tooltips and offline F1 Help.
- **Type-Safe Signals**: Declare signals via `signal health_changed(new_health : Int32)` with generated `emit_<signal>` helpers.
- **GDScript Interoperability**: Automatic compile-time generation of typed Crystal wrappers for project GDScript nodes and scenes (`make project_bindings`).
- **Engine Reflection & Global Singletons**: First-class access to singletons like `Godot.input`, `Godot.engine`, `Godot.audio_server`, and generated Godot classes.
- **Native In-Editor Debugging with LLDB**: Breakpoints in Godot's Script Editor gutter seamlessly synchronize with LLDB. Includes an interactive in-editor console, call stack navigation, and Multiplayer Lockstep Break coordination to eliminate peer timeout disconnects.
- **Strict Decoupling**: Clean separation between reusable library (`src/`), test suite (`test/`), and examples (`examples/`).

---

## Prerequisites & Installation

### Required Tooling
- **Crystal Compiler**: 1.14+ (or preview builds)
- **Godot Engine**: 4.3+ or 4.4+ (Standard build, 64-bit)
- **C++ Compiler**: GCC (`g++`) or Clang (for compiling the GDExtension loader bridge)
- **Make**: GNU Make
- **Lapis Toolchain**: Bundled native CLI tool (`bin/lapis`) compiled automatically by `Makefile`

### Native In-Editor Debugging Prerequisite (LLDB)
For native in-editor debugging, breakpoint synchronization, and multiplayer lockstep inspection, install **LLDB**:
- **Windows**: `scoop install llvm` or `winget install LLVM.LLVM`
- **Ubuntu / Debian**: `sudo apt install lldb`
- **Arch Linux**: `sudo pacman -S lldb`
- **macOS**: `brew install llvm` or `xcode-select --install`

---

## Documentation

- **Official Online Documentation Site**: [https://sol-vin.github.io/lapis/](https://sol-vin.github.io/lapis/)
- **Architecture & Guides in `Docs` Module**: Complete guides covering architecture, build toolchains, memory management, and concurrency are contained in [`Docs`](src/libgodot/docs.cr) (such as [`Docs::I_CONCURRENCY_FIBERS_AND_THREAD_SAFETY`](src/libgodot/docs.cr)).
- **Offline HTML API Documentation**: Generate complete API documentation locally with `make docs` (output at `docs/index.html`).
- **In-Editor Help**: Class and method descriptions are harvested at compile time and accessible directly inside Godot via `F1` or Inspector tooltips.

---

## Installation & Shard Configuration

Add Lapis to your game's `shard.yml`:

```yaml
dependencies:
  lapis:
    github: sol-vin/lapis
```

Run `shards install` to fetch the dependency.

---

## Quickstart

```crystal
require "lapis"

# Player character with physics movement, health tracking, and signals
node Player < CharacterBody3D do
  # Movement speed in meters per second
  @[Export(range: 1.0_f32..20.0_f32, step: 0.5_f32)]
  property speed : Float32 = 7.0_f32

  # Jump velocity impulse
  @[Export(range: 1.0_f32..25.0_f32, step: 0.5_f32)]
  property jump_velocity : Float32 = 8.0_f32

  # Gravitational acceleration
  @[Export(range: 1.0_f32..50.0_f32, step: 1.0_f32)]
  property gravity : Float32 = 18.0_f32

  # Maximum hit points
  @[Export(range: 10..500, step: 10)]
  property max_health : Int32 = 100

  # Emitted when the player's health changes
  signal health_changed(current : Int32, max_health : Int32)

  # Emitted when the player dies
  signal died

  # Called when node enters the active scene tree
  def _ready : Void
    @current_health = @max_health
    Godot.print("Player initialized at #{position}")
  end

  # Called every fixed physics step
  def _physics_process(delta : Float64) : Void
    vel = velocity

    unless is_on_floor
      vel.y -= @gravity * delta.to_f32
    end

    if Input.is_action_just_pressed("jump") && is_on_floor
      vel.y = @jump_velocity
    end

    input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    direction = (transform.basis * Vector3.new(input_dir.x, 0.0_f32, input_dir.y)).normalized

    if direction.length > 0.001_f32
      vel.x = direction.x * @speed
      vel.z = direction.z * @speed
    else
      vel.x = Math.move_toward(vel.x, 0.0_f32, @speed * delta.to_f32)
      vel.z = Math.move_toward(vel.z, 0.0_f32, @speed * delta.to_f32)
    end

    self.velocity = vel
    move_and_slide
  end

  # Inflicts damage on the player
  def take_damage(amount : Int32) : Void
    return if @current_health <= 0
    @current_health = Math.max(0, @current_health - amount)
    emit_health_changed(@current_health, @max_health)
    if @current_health <= 0
      emit_died
      queue_free
    end
  end
end
```

---

## Comprehensive In-Code Documentation (`Docs` Module)

Lapis features an extensive in-code documentation suite under the `Docs` module. Each submodule details internal mechanics, macro pipelines, export options, and engine caveats:

<table>
  <thead>
    <tr>
      <th align="left">Submodule</th>
      <th align="left">Topic</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><a href="src/libgodot/docs.cr"><code>Docs::A_ARCHITECTURE</code></a></td>
      <td>Dual-paradigm model, GDExtension Mode A vs Standalone LibGodot Mode B.</td>
    </tr>
    <tr>
      <td><a href="src/libgodot/docs.cr"><code>Docs::B_COMPILATION_AND_BUILD</code></a></td>
      <td>Bridge compilation, Windows shadow DLL file-locking bypass, F5 editor hook, and <code>Makefile</code> orchestration.</td>
    </tr>
    <tr>
      <td><a href="src/libgodot/docs.cr"><code>Docs::C_EXPORTS_AND_INSPECTOR</code></a></td>
      <td>All <code>@[Export*]</code> annotations, <code>PropertyInfo</code> mapping, ranges, enums, flags, categories, and buttons.</td>
    </tr>
    <tr>
      <td><a href="src/libgodot/docs.cr"><code>Docs::D_NODE_DSL_AND_SIGNALS</code></a></td>
      <td>Node macro DSL, lifecycle callbacks (<code>_ready</code>, <code>_physics_process</code>), signal registration, and scene APIs.</td>
    </tr>
    <tr>
      <td><a href="src/libgodot/docs.cr"><code>Docs::E_DOC_COMMENTS_AND_HELP</code></a></td>
      <td>Compile-time doc comment harvesting, <code>DocData</code> XML generation, and Godot offline F1 Help integration.</td>
    </tr>
    <tr>
      <td><a href="src/libgodot/docs.cr"><code>Docs::F_GDSCRIPT_INTEROP</code></a></td>
      <td>Automated compile-time GDScript bindings and Variant marshaling.</td>
    </tr>
    <tr>
      <td><a href="src/libgodot/docs.cr"><code>Docs::G_CAVEATS_AND_INTERNALS</code></a></td>
      <td>Boehm GC vs Godot memory lifecycles, threading rules, method bind caching, and Windows toolchains.</td>
    </tr>
    <tr>
      <td><a href="src/libgodot/docs.cr"><code>Docs::H_LIFECYCLE_MEMORY_AND_DEAD_POINTER_SAFETY</code></a></td>
      <td>Dead-pointer prevention, monotonic 64-bit instance IDs, O(1) liveness checks, and zero-crash <code>DisposedObjectError</code>.</td>
    </tr>
    <tr>
      <td><a href="src/libgodot/docs.cr"><code>Docs::I_CONCURRENCY_FIBERS_AND_THREAD_SAFETY</code></a></td>
      <td>Crystal fibers, background OS threads, actor channel message passing, mutexes, and main-thread SceneTree affinity.</td>
    </tr>
  </tbody>
</table>

To generate and browse the complete HTML documentation locally:
```bash
make docs
```
Then open `docs/index.html` in your browser.

---

## Build System & Commands

Build operations are orchestrated through the root `Makefile`.

<table>
  <thead>
    <tr>
      <th align="left">Command</th>
      <th align="left">Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>make all</code></td>
      <td><strong>Default Build</strong>: Compiles loader bridge, test project, examples, template, and synchronizes all DLLs.</td>
    </tr>
    <tr>
      <td><code>make run</code></td>
      <td>Launches the test suite project directly in the Godot engine.</td>
    </tr>
    <tr>
      <td><code>make editor</code></td>
      <td>Opens the test project in the Godot Editor (<code>godot.exe --editor --path test</code>).</td>
    </tr>
    <tr>
      <td><code>make test</code></td>
      <td>Runs the multi-tier automated test suite: Crystal specs, headless in-editor tool tests, runtime test project, standalone test runner (<code>--autorun</code>), and smoke tests.</td>
    </tr>
    <tr>
      <td><code>make test_standalone</code></td>
      <td>Packages and executes the standalone test runner executable (<code>tests.exe --autorun</code>) in debug or release mode.</td>
    </tr>
    <tr>
      <td><code>make docs</code></td>
      <td>Generates offline HTML documentation into <code>docs/</code>.</td>
    </tr>
    <tr>
      <td><code>make bridge</code></td>
      <td>Compiles <code>src/bridge/crystal_bridge.cpp</code> into <code>bin/crystal_bridge.dll</code>.</td>
    </tr>
    <tr>
      <td><code>make test_project</code></td>
      <td>Compiles the test suite project (<code>test/bin/game.dll</code>).</td>
    </tr>
    <tr>
      <td><code>make examples</code></td>
      <td>Compiles all showcase projects in <code>examples/</code>.</td>
    </tr>
    <tr>
      <td><code>make template</code></td>
      <td>Compiles the starter template (<code>template/bin/game.dll</code>).</td>
    </tr>
    <tr>
      <td><code>make game_exe</code></td>
      <td>Compiles standalone host executable <code>bin/game.exe</code> (Mode B).</td>
    </tr>
    <tr>
      <td><code>make sync</code></td>
      <td>Synchronizes binaries, runtime DLLs, and addons across all consumer directories.</td>
    </tr>
    <tr>
      <td><code>make clean</code></td>
      <td>Removes compiled binaries and intermediate build artifacts while preserving runtime DLLs.</td>
    </tr>
  </tbody>
</table>

### Build Options
- `RELEASE=1`: Compiles Crystal code with release optimizations (`--release -O3`) and defines `LIBGODOT_RELEASE=1` / `NDEBUG`.
- `ENTRY=<path>`: Customizes the Crystal entry file (default: `test/src/main.cr`).
- `CXX=<compiler>`: Specifies C++ compiler for the bridge (default: `g++`).

---

## Unified Lapis CLI Toolchain (`bin/lapis`)

Lapis includes a high-performance, cross-platform compiled CLI tool written in Crystal (`bin/lapis` or `bin/lapis.exe` on Windows). The toolchain replaces platform-dependent scripting with instant sub-20ms execution across Windows, Linux, and macOS:

<table>
  <thead>
    <tr>
      <th align="left">Command</th>
      <th align="left">Description &amp; Role</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>lapis build [target]</code></td>
      <td>Compiles Crystal targets (<code>game</code>, <code>plugin</code>, <code>tests</code>, <code>bench</code>) with automatic <code>CRYSTAL_PATH</code> resolution and platform-specific linker flags.</td>
    </tr>
    <tr>
      <td><code>lapis sync</code></td>
      <td>Synchronizes compiled binaries, runtime DLLs (GC, iconv, PCRE2, LibGodot), and addon manifests across all workspace consumers.</td>
    </tr>
    <tr>
      <td><code>lapis test</code></td>
      <td>Unified multi-tier test runner: executes specs, headless in-editor <code>@tool</code> tests, runtime test suites, and standalone compiled tests.</td>
    </tr>
    <tr>
      <td><code>lapis editor</code></td>
      <td>Detects Godot installation, synchronizes assets, and launches the Godot Editor with automatic build hooks.</td>
    </tr>
    <tr>
      <td><code>lapis new &lt;game|addon|example&gt; [name]</code><br><code>lapis scaffold &lt;game|addon|example&gt; [name]</code></td>
      <td>Scaffolds a new game from template (in target directory or CWD), a redistributable GDExtension addon, or a showcase example.</td>
    </tr>
    <tr>
      <td><code>lapis bind &lt;engine|project&gt;</code></td>
      <td>Generates typed Crystal API bindings for Godot engine classes and singletons (from <code>extension_api.json</code>) or custom GDScript project nodes.</td>
    </tr>
    <tr>
      <td><code>lapis package [target]</code></td>
      <td>Packages playable standalone game executables or distribution zip archives (<code>template</code>, <code>addon</code>).</td>
    </tr>
    <tr>
      <td><code>lapis deps</code></td>
      <td>Validates and synchronizes required runtime dynamic libraries and export templates across output folders.</td>
    </tr>
    <tr>
      <td><code>lapis dirs</code></td>
      <td>Verifies and creates all required build, output, and staging directories across the workspace.</td>
    </tr>
    <tr>
      <td><code>lapis install [options]</code><br><code>make install</code></td>
      <td>Installs the Lapis CLI toolchain globally into system/user <code>PATH</code> (<code>%LOCALAPPDATA%\Microsoft\WindowsApps</code> on Windows, <code>/usr/local/bin</code> or <code>~/.local/bin</code> on Unix).</td>
    </tr>
  </tbody>
</table>

Run `lapis --help` or `lapis <command> --help` for full parameter options and flags.

---

## Automation & Support Scripts (`scripts/`)

In addition to the `lapis` CLI, specialized automation scripts under `scripts/` handle platform packaging, CI pipelines, and binding generation:

### Build & Compilation Scripts

<table>
  <thead>
    <tr>
      <th align="left">Command</th>
      <th align="left">Description &amp; Role</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>lapis build</code></td>
      <td>Primary Crystal compilation driver. Compiles game libraries, editor plugins (<code>-Dlibgodot_addon</code>), dummy test addons (<code>lapis build addons</code>), or showcase examples (<code>lapis build examples</code>). Configures platform linker flags and include paths automatically.</td>
    </tr>
    <tr>
      <td><code>lapis bind engine</code></td>
      <td>Automated code generator that parses Godot's <code>extension_api.json</code> and synthesizes strongly typed Crystal classes, global enums, singletons, and method bindings into <code>src/libgodot/generated/</code>.</td>
    </tr>
    <tr>
      <td><code>lapis bind project</code></td>
      <td>Inspects custom GDScript nodes in a game project and generates typed Crystal wrapper classes for seamless cross-language interop.</td>
    </tr>
    <tr>
      <td><code>lapis new game [name]</code></td>
      <td>Scaffolds a new playable game project from the starter template in the specified directory or current working directory.</td>
    </tr>
    <tr>
      <td><code>lapis scaffold &lt;addon|example&gt;</code></td>
      <td>Scaffolds a new redistributable GDExtension addon or showcase example project.</td>
    </tr>
    <tr>
      <td><code>lapis test</code></td>
      <td>The master multi-tier test suite runner. Executes Crystal specs, in-editor <code>@tool</code> tests, standalone compiled runner (<code>tests.exe --autorun</code>), and runtime project test suites.</td>
    </tr>
    <tr>
      <td><code>lapis package &lt;target&gt;</code></td>
      <td>Creates release archives (<code>template</code>, <code>addon</code>, <code>examples</code>, <code>tests</code>, <code>perf</code>, <code>release</code>) with SHA-256 checksums, or exports a self-contained playable game package with embedded PCK and runtime DLLs (<code>lapis package game</code>).</td>
    </tr>
    <tr>
      <td><code>lapis sync</code></td>
      <td>Synchronizes compiled binaries (<code>crystal_bridge.dll</code>, <code>game.dll</code>, <code>plugin.dll</code>), runtime libraries (<code>gc.dll</code>, <code>iconv-2.dll</code>, <code>pcre2-8.dll</code>, <code>libgodot.dll</code>), and addons across all consumer projects.</td>
    </tr>
    <tr>
      <td><code>lapis deps</code></td>
      <td>Locates and copies required Crystal runtime dynamic libraries (Boehm GC, iconv, PCRE2, and LibGodot engine shared libraries) into target binary output folders.</td>
    </tr>
    <tr>
      <td><code>lapis dirs</code></td>
      <td>Ensures all required build, output, and staging directories exist across the repository workspace.</td>
    </tr>
    <tr>
      <td><code>lapis editor</code></td>
      <td>Unified Godot Editor launcher with shadow logging, auto-quit, and debugger attachment support.</td>
    </tr>
    <tr>
      <td><code>lapis setup</code></td>
      <td>Downloads and sets up the targeted Godot engine binary for development and dumps the extension API.</td>
    </tr>
    <tr>
      <td><code>lapis docs</code></td>
      <td>Generates offline HTML documentation via <code>crystal docs</code> and patches sidebar limits and styling.</td>
    </tr>
    <tr>
      <td><code>lapis clean</code></td>
      <td>Removes built binaries and caches while safely preserving runtime DLLs (<code>libgodot.dll</code>, <code>gc.dll</code>, etc.).</td>
    </tr>
    <tr>
      <td><a href="scripts/cc_wrapper.sh"><code>scripts/cc_wrapper.sh</code></a></td>
      <td>POSIX compiler wrapper script. Filters out <code>-rdynamic</code> on Linux shared library builds and localizes internal Crystal runtime symbols to prevent GNU ld/LLD version node link errors.</td>
    </tr>
  </tbody>
</table>

---

## Memory Safety, Object Lifecycle & Dead-Pointer Protection

Developing with a garbage-collected language like Crystal embedded inside a native C++ engine like Godot introduces a dual memory model hazard:
- **Crystal Boehm GC**: Manages Crystal heap objects and node wrappers (`Godot::Object`).
- **Godot ObjectDB & Reference Counting**: Manages native C++ engine nodes and refcounted resources.

### The Dangling Pointer Hazard in Cross-Language Bindings
When an object is freed on the Godot engine side or via GDScript (e.g. `queue_free()` or `target.free()`), standard C-API bindings retain a raw C++ pointer to dead memory. Subsequent operations (e.g. `target.position = new_pos`) dereference the unmapped address, triggering an immediate, fatal **segmentation fault (`ACCESS_VIOLATION / SIGSEGV`)** that crashes the game process with no traceback.

```
[ Crystal Runtime ]                          [ Godot Engine / GDScript ]
  enemy = get_node("Enemy")
  enemy.@pointer = 0x7FFE_1234  -------->     Node instance at 0x7FFE_1234
                                                  |
                                                  | GDScript: enemy.queue_free()
                                                  v
                                               ObjectDB destroys Node & frees memory!
                                               0x7FFE_1234 is now DEAD / UNMAPPED!
  enemy.position = Vector2.new(...)
        |
        v
  [ Lapis check_alive! ]
        |
        +---> Query ObjectDB for 64-bit instance ID: ID is INVALID!
        |
        +---> Marks wrapper dead (@pointer = null)
        |
        +---> Raises Godot::DisposedObjectError (Clean, catchable Crystal exception!)
              [ ZERO NATIVE CRASHES! ]
```

### How Lapis Guarantees Dead-Pointer Safety
1. **Monotonic 64-bit Instance ID Tracking**:
   Every `Godot::Object` wrapper tracks its engine-assigned `instance_id`. Because Godot's `ObjectDB` generates monotonic 64-bit IDs, newly allocated heap objects will never collide with previously freed IDs.
2. **Pre-Dispatch Liveness Check (`#check_alive!`)**:
   Before executing method dispatches or reflection calls, Lapis queries Godot's ObjectDB in O(1) time (`Bridge.is_instance_valid(instance_id)`).
3. **Graceful `DisposedObjectError` Exception**:
   If an object was destroyed by GDScript, the engine, or Crystal, Lapis marks the pointer null and immediately raises `Godot::DisposedObjectError`:
   ```crystal
   begin
     enemy.position = Vector2.new(10.0, 20.0)
   rescue ex : Godot::DisposedObjectError
     Godot.print_warn "Attempted operation on dead node (ID: #{ex.instance_id})"
   end
   ```
4. **Defensive Inspection with `#alive?` and `#destroyed?`**:
   Game logic can check entity liveness before issuing operations:
   ```crystal
   if target.alive?
     target.apply_damage(50)
   else
     active_targets.delete(target)
   end
   ```

### Quantitative Zero-Leak Verification
Lapis's test suite integrates Godot's `Performance` singleton monitors (`OBJECT_COUNT`, `OBJECT_NODE_COUNT`, `MEMORY_STATIC`) and Crystal's `GC.collect` to mathematically verify that creating, reparenting, and destroying nodes across hundreds of iterations leaves **zero memory leaks** in both Godot's ObjectDB and Crystal's heap.

---

## Native In-Editor Debugging with LLDB

Lapis features first-class native debugging directly inside the Godot Editor using **LLDB**:
- **Gutter Breakpoint Sync**: Set red breakpoints directly in Godot's Script Editor gutter; breakpoints are translated and dispatched to LLDB instantly.
- **Interactive In-Editor Panel**: Dedicated **Crystal LLDB** tab docked in the Godot Debugger panel featuring Continue (`F5`), Step Over (`F10`), Step Into (`F11`), Step Out (`Shift+F11`), call stack frame navigation, and live variable inspection.
- **Multiplayer Multi-Session Support**: Distinct session tabs with automatic role identification (`[SERVER]`, `[CLIENT 1]`, etc.) for multiple instances launched from the editor.
- **Multiplayer Lockstep Break Mode**: When any peer hits a breakpoint, all other active instances are automatically paused via cooperative interrupt to prevent network heartbeat timeouts (ENet/WebSocket/WebRTC).

### Debugging Tool Scripts (`@[Tool]`)

<table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
  <thead>
    <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
      <th style="padding: 10px 14px;">Execution Context</th>
      <th style="padding: 10px 14px;">Will Breakpoint Trigger in Editor Tab?</th>
      <th style="padding: 10px 14px;">Reason &amp; Workflow</th>
    </tr>
  </thead>
  <tbody>
    <tr style="border-bottom: 1px solid #2d3748;">
      <td style="padding: 10px 14px;"><strong>Running Game Instance (F5 / F6)</strong></td>
      <td style="padding: 10px 14px;"><strong>YES</strong></td>
      <td style="padding: 10px 14px;">The tool script runs in the child game process attached to the in-editor LLDB session.</td>
    </tr>
    <tr style="border-bottom: 1px solid #2d3748;">
      <td style="padding: 10px 14px;"><strong>Live In-Editor Viewport / Inspector</strong></td>
      <td style="padding: 10px 14px;"><strong>NO</strong></td>
      <td style="padding: 10px 14px;">
        Code executes inside the parent Godot Editor process (<code>godot.exe</code>), not a child game process.<br>
        <em>Host Deadlock Paradox</em>: An OS-level native breakpoint (<code>SIGTRAP</code>) in the editor process freezes the editor GUI thread, making it impossible to click &quot;Continue&quot; or &quot;Step&quot; in the debugger tab.<br>
        <strong>Solution</strong>: Attach an external debugger (e.g. VS Code <code>CodeLLDB</code> or terminal <code>lldb -- godot.exe --editor --path &lt;project&gt;</code>) to debug live tool scripts without freezing the debugger UI.
      </td>
    </tr>
  </tbody>
</table>

> Detailed architectural breakdown and VS Code `.vscode/launch.json` templates are documented in [`Docs::M_LLDB_NATIVE_DEBUGGING_GUIDE`](src/libgodot/docs.cr).

---

## Repository Structure

```
lapis/
├── src/                          # Reusable Lapis library (STRICTLY decoupled)
│   ├── lapis.cr                  # Library root entry point (require "lapis")
│   ├── bridge/crystal_bridge.cpp # C++ GDExtension loader bridge
│   └── libgodot/                 # Core engine C-API, macros, and generated bindings
├── tools/                        # Built-in CLI toolchain
│   └── lapis/                    # Compiled native CLI (bin/lapis)
├── test/                         # Dedicated verification and test project
├── examples/                     # Independent consumer showcase examples
├── template/                     # Clean starter template for new games
├── template-addon/               # Starter template for redistributable addons
├── addons/crystal_integration/   # Godot editor extension manifest & build hook
├── bin/                          # Output binaries, bridge DLL, and dependencies
├── spec/                         # Automated unit specifications
└── AGENTS.md                     # Agent development guidelines
```


---

## License

Distributed under the MIT License. Copyright (c) 2026 Ian and contributors.
