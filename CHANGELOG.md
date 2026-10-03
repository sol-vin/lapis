# Changelog

All notable changes to the Lapis for Crystal framework are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added

#### In-Editor Action Driver ("Selenium for Godot Editor")
- **`Lapis::Editor::ActionDriver` (`src/libgodot/editor/action_driver.cr`)**:
  - Implemented comprehensive automation framework for driving Godot editor controls, viewport nodes, and UI trees.
  - CSS & XPath-style selector engines supporting IDs (`#play_button`), classes (`.Button`, `.ItemList`), hierarchical paths (`Panel > VBoxContainer > Button`), property matchers (`[name="Save"]`, `[text="Run"]`), and wildcard searches (`//Button`).
  - Input synthesis engine supporting `click`, `double_click`, `right_click`, `mouse_down`, `mouse_up`, and `mouse_move`.
  - Full keyboard automation with `type_text`, `press_key`, `key_down`, and `key_up`.
  - Multi-step interpolated `drag_and_drop(from, to, steps: 10)` for smooth UI drag operations.
  - Assertions & synchronization helpers: `wait_for(selector, timeout_sec: 5.0)`, `assert_visible`, `assert_text`, `assert_enabled`, and `assert_exists`.
  - Scene tree inspection: `dump_hierarchy` (formatted text tree) and `dump_json` (structured node metadata with class, name, path, global position, size, and visibility).

#### AI Vision Subsystem
- **`Lapis::Editor::ActionDriverVision` (`src/libgodot/editor/action_driver_vision.cr`)**:
  - Native viewport screenshots and sub-region element cropping via `crop_element(node, file_path)`.
  - Set-of-Marks AI Manifest generator via `capture_ai_manifest(output_dir)`.
  - Captures full viewport image (`full_viewport.png`), extracts individual interactive UI elements into cropped PNGs (`element_<ID>_<NAME>.png`), and generates structured `ui_manifest.json` with pixel-exact bounding boxes (`x`, `y`, `width`, `height`), node hierarchy metadata, and control classes for multimodal LLM visual inspection.

#### Remote Automation IPC Server
- **`Lapis::Editor::DriverServer` (`src/libgodot/editor/action_driver_ipc.cr`)**:
  - Localhost TCP JSON-RPC automation server running inside Godot on port 9223.
  - Exposes remote RPC endpoints: `locate`, `click`, `type`, `drag`, `dump_tree`, `capture_manifest`, and `crop`.
  - Seamlessly bridges CLI tools, test scripts, and external agents to the live running Godot editor.

#### CLI & TUI Action Driver Integration
- **`lapis driver` CLI Command (`tools/lapis/src/commands/driver.cr`)**:
  - CLI subcommands for remote editor manipulation:
    - `lapis driver click <selector>`
    - `lapis driver type <selector> <text>`
    - `lapis driver drag <source> <target>`
    - `lapis driver tree [--json]`
    - `lapis driver manifest [--out <dir>]`
    - `lapis driver repl` — interactive automation REPL with live command execution and autocomplete.
- **Double-Buffered Opal TUI Driver View (`tools/lapis/src/tui/driver_view.cr`)**:
  - Dedicated interactive terminal dashboard integrated into Lapis Hub (`[A] Action Driver Controller`).
  - Real-time connection status monitoring, interactive command prompt, and one-key quick actions:
    - `[1]` Dump Tree, `[2]` AI Manifest, `[3]` Click Inspector, `[4]` Focus Viewport, `[5]` Ping Server.
  - Scrollable activity console with ANSI color-coded status responses.

#### String Preload & Load Operators
- **Ergonomic Preload & Load Operators (`src/libgodot/extensions/resource.cr`)**:
  - `>` operator on `String` for compile-time cached preloading: `"res://scenes/player.tscn" > PackedScene`.
  - `>>` operator on `String` for dynamic runtime resource loading: `"res://assets/theme.tres" >> Theme`.
  - `PreloadCache` thread-safe singleton cache with `Godot.preload(path, T)` helper.

#### Cancellable Timer Handles
- **`TimerHandle` Lifecycle Controller (`src/libgodot/timer.cr`)**:
  - `every` and `after` now return a `TimerHandle` for fine-grained lifecycle management:
    - `handle.cancel` / `handle.stop` — immediately aborts the timer and disconnects signals.
    - `handle.pause` and `handle.resume` — temporarily freezes timer accumulation.
    - `handle.reset` — restarts timer duration from zero.
    - `handle.advance(delta)` — manually steps elapsed time forward (ideal for headless deterministic tests).
    - Status inspection: `handle.finished?`, `handle.paused?`, `handle.elapsed`, `handle.time_left`.
  - Protected callback dispatches with `#alive?` validation to eliminate dangling closures on freed nodes.

#### Hot-Reload State Preserver
- **6-Phase Transactional State Protocol (`src/libgodot/editor/state_preserver.cr`)**:
  - `Lapis::Editor::StatePreserver` preserves game/editor node state during live GDExtension DLL reloads:
    1. Pre-flight node tree validation.
    2. Recursive state snapshot serialization into JSON (`StateSnapshot`).
    3. Shadow DLL rebuild and swap.
    4. Schema drift reconciliation (handles added, removed, or altered properties without crashing).
    5. Silent hydration with signals temporarily blocked to prevent cascading event triggers.
    6. Post-reload state integrity verification.
  - Integrated into editor lifecycle via `Lapis::Editor.save_reload_state` and `Lapis::Editor.restore_reload_state`.

#### Core Engine Bindings & Spec Infrastructure
- **`Object#active?` (`src/libgodot/object.cr`)**: Unified alive-state check compatible with both live engine `ObjectDB` pointers and standalone Crystal unit test nodes.
- **`Variant#as_vector2` & `Variant#as_vector3` (`src/libgodot/variant.cr`)**: Added canonical type-conversion aliases for Vector types.
- **Standalone `Node#get_children` (`src/libgodot/extensions/node.cr`)**: Graceful fallback to `@local_children` when running under pure Crystal headless specs with null native engine pointers.
- **Specification Test Suites**:
  - `spec/preload_operator_spec.cr` — verifies `>` and `>>` operators, preload caching, and type assertions.
  - `spec/timer_handle_spec.cr` — verifies `TimerHandle` cancellation, pausing, stepping, and error suppression.
  - `spec/editor_action_driver_spec.cr` — verifies selector parsing, mouse/keyboard synthesis, tree dumping, and JSON-RPC dispatch.
  - `spec/editor_reload_state_preserver_spec.cr` — verifies 6-phase state snapshotting, schema reconciliation, and silent hydration.
