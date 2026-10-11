---
name: libgodot-test-runner
description: >-
  Execute the multi-tier test suite: Crystal specs, headless in-editor @tool tests,
  and standalone runtime test projects. Use when verifying code changes, checking for
  memory leaks, or running CI verification.
---

# LibGodot Test Runner & Verification Runbook

This skill provides procedures for running and troubleshooting the complete LibGodot test infrastructure.

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
      <td><a href="#running-the-automated-test-suite"><strong>Running the Automated Test Suite</strong></a></td>
      <td>To run all automated verification suites in one command:</td>
      <td align="center"><code>L53–L65</code></td>
    </tr>
    <tr>
      <td><a href="#the-4-test-tiers"><strong>The 4 Test Tiers</strong></a></td>
      <td>### 1.</td>
      <td align="center"><code>L66–L150</code></td>
    </tr>
    <tr>
      <td><a href="#test-artifacts-and-logs"><strong>Test Artifacts and Logs</strong></a></td>
      <td>After test execution, inspect:</td>
      <td align="center"><code>L151–L160</code></td>
    </tr>
    <tr>
      <td><a href="#quantitative-zero-leak-verification"><strong>Quantitative Zero-Leak Verification</strong></a></td>
      <td>LibGodot verifies zero memory leaks using Godot's Performance singleton monitors:</td>
      <td align="center"><code>L161–L174</code></td>
    </tr>
    <tr>
      <td><a href="#radare2-cradare2-diagnostic-debugging-workflow"><strong>radare2 & `cradare2` Diagnostic & Debugging Workflow</strong></a></td>
      <td>When encountering segmentation faults (0xC0000005), invalid parameter crashes, or mysterious exits:</td>
      <td align="center"><code>L175–L203</code></td>
    </tr>
  </tbody>
</table>

---

## Running the Automated Test Suite

To run all automated verification suites in one command:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1
```
Or via Makefile:
```bash
make test
```

---

## The 4 Test Tiers

### 1. Crystal Specification Suite (`spec/`)
Executes headless Crystal specs validating language-level bindings:
- `spec/libgodot_spec.cr`: Basic node declaration, vector math, default property values.
- `spec/features_spec.cr`: DSL syntax, exported property macros, custom getters/setters.
- `spec/safety_and_bindings_spec.cr`: Boehm GC lifetime retention, dynamic scaling (220+ properties, 10+ signal args), Variant round-trips.
- `spec/boot_spec.cr`: Engine boot and initialization callbacks.

To run specs directly:
```bash
crystal spec spec/features_spec.cr spec/safety_and_bindings_spec.cr spec/libgodot_spec.cr spec/boot_spec.cr
```

### 2. In-Editor `@tool` and Script Loading Verification
Executes tool script tests and validates script resource loading inside the Godot Editor:
- Tests `ToolTester2D` and `ToolTester3D` in `scenes/main_test_runner.tscn` (or via `spec/editor_driver_spec.cr`).
- Verifies editor-only callbacks, tool buttons, and live inspector updates.
- Command executed internally:
  ```bash
  godot.exe --headless --editor --path . --quit-after 100
  ```
  Or via Crystal specs:
  ```bash
  crystal spec spec/editor_driver_spec.cr
  ```
- **In-Editor Script Loading & Clean Shutdown Verification Protocol**:
  Whenever modifying editor integration, bridge deinitialization, or resource loaders/savers, you MUST run this verification check:
  1. **Launch the Godot Editor**:
     ```powershell
     cmd /c "godot.exe --verbose --editor --path template --quit-after 50 2>&1"
     ```
  2. **Verify Script Resource Loader & Language**:
     - Ensure `ResourceFormatLoaderCrystal` correctly handles `.cr` files as `Script` / `CrystalScript` resources (not plain text files).
     - Check logs for absence of loader failures:
       - No `ERROR: No loader found for resource: res://src/main.cr (expected type: Script)`
       - No `ERROR: Condition "res.is_null()" is true. Returning: ERR_CANT_OPEN`
       - No `ERROR: Required virtual method CrystalLanguage::_... must be overridden before calling.`
  3. **Verify Clean Editor Shutdown**:
     - Check console logs upon closing the editor: must contain **ZERO** `ERROR: BUG: Unreferenced static string to 0: ...` errors.
     - Never call `.destroy` or manually unparent editor-owned UI nodes (e.g. `EditorDock` or editor titlebar buttons).
     - Never call `gd_classdb_unregister_extension_class` during process shutdown (`is_engine_shutting_down()`); Godot's engine cleanup handles ClassDB destruction automatically.
  4. **Automated Verification Command**:
     ```powershell
     powershell -File scripts/verify_editor.ps1 -Path template -QuitAfter 50
     ```

### 3. Standalone Runtime Host & Project Tests (Root Project)
Runs the full interactive test project in Godot:
- Boots `scenes/main_test_runner.tscn` containing the `RunTesterPanel` test UI.
- Executes all modular test suites in `spec/suites/`:
  - `test_2d_nodes.cr`: Sprite2D, Node2D transforms, Area2D, CollisionShape2D.
  - `test_3d_nodes.cr`: Node3D transforms, Camera3D, DirectionalLight3D.
  - `test_control_nodes.cr`: Label, Button, VBoxContainer, MarginContainer.
  - `test_meshes_materials.cr`: BoxMesh, SphereMesh, StandardMaterial3D.
  - `test_physics_shapes.cr`: BoxShape3D, SphereShape3D, physics layers.
  - `test_audio_animation.cr`: AudioStreamPlayer, AnimationPlayer.
  - `test_resources_utilities.cr`: PackedScene, ResourceLoader, ConfigFile.
  - `test_lifecycle_destruction.cr`: SceneTree reparenting, `queue_free`, `.destroy`.
  - `test_classdb_coverage.cr`: Reflection lookups and method dispatch.
  - `test_concurrency.cr`: Cooperative fibers, channels, mutexes, thread safety.
  - `test_tween_dsl.cr`: 16-pillar multi-frame deterministic tween stepping and pipeline test suite.
  - `test_signal_safety_multiframe.cr`: 7-pillar signal disconnection, dead emitter/receiver auto-pruning, and frame boundary test suite.
  - `test_destruction_and_threads_multiframe.cr`: 7-pillar queue_free frame boundary, 50-node cascade destruction, and concurrent worker thread test suite.
  - `test_dsl_edge_cases_and_leaks.cr`: 11-pillar comprehensive DSL syntax, match guards, and leak gate suite.
  - `test_dsl_helpers_and_onready.cr`: 6-pillar ancestor operator (`<<`), fluent `group(:name)` DSL, `load`/`preload` inference, and onready customization suite.
  - `test_editor_plugins_comprehensive.cr`: 8-pillar Crystal editor plugins ClassDB registration, main screen protocol, debugger session, and highlighter engine suite.
- Command executed internally:
  ```bash
  godot.exe --headless --path . --quit-after 250
  ```

### 4. Template and Example Smoke Tests
Verifies that `template/` and all projects under `examples/` boot cleanly without crashing.
- Test template runtime:
  ```bash
  godot.exe --headless --path template --quit-after 50
  ```
- Test template editor launch and script loader:
  ```bash
  godot.exe --headless --editor --path template --quit-after 50
  ```

---

## Test Artifacts and Logs

After test execution, inspect:
- `.runtime_test_results.txt` (and `bin/.runtime_test_results.txt`): Text summary of all passed and failed tests.
- `.runtime_tests_passed` (and `bin/.runtime_tests_passed`): Marker file containing `"PASS"` if all tests passed.
- `bin/test_report.json`: JSON output containing test statistics and timing.
- `bin/test_report.md`: Markdown summary of test execution.

---

## Quantitative Zero-Leak Verification

LibGodot verifies zero memory leaks using Godot's `Performance` singleton monitors:
```crystal
initial_nodes = Godot.performance.get_monitor(Godot::Performance::OBJECT_NODE_COUNT)
# ... allocate, reparent, queue_free nodes ...
Godot.gc_collect
final_nodes = Godot.performance.get_monitor(Godot::Performance::OBJECT_NODE_COUNT)
TestFramework.assert_eq final_nodes, initial_nodes, "Node count must return to baseline!"
```
If object count or static memory leaks, the test runner fails immediately.

---

## radare2 & `cradare2` Diagnostic & Debugging Workflow

When encountering segmentation faults (`0xC0000005`), invalid parameter crashes, or mysterious exits:

### 1. Launch Under radare2 via Lapis CLI
```powershell
# Debug runtime test suite with radare2 attached
lapis run --debug

# Debug Godot Editor on template project
lapis editor -p template --debug

# Decompile crash site or method to inspect assembly / pseudo-C
lapis decompile bin/game.dll "Player#_process" --side-by-side
```

### 2. Set Breakpoints & Interactive Commands in radare2
```text
# In radare2 prompt:
[0x...]> dbl player.cr:42      # Set source line breakpoint
[0x...]> dc                    # Continue execution
[0x...]> pdc                   # Decompile current function into pseudo-C
[0x...]> dbt                   # Demangled backtrace
```

### 3. Diagnose Dead Pointers and Memory Corruption
See skill `cradare2-debugger` for automated crash forensics, Godot ObjectDB monotonic instance ID validation, and multiplayer lockstep break/resume coordination.

