# LibGodot Testing Apparatus & Suite Guide

This directory contains the primary verification consumer and comprehensive test suite for **LibGodot for Crystal**.

---

## 1. Directory Structure

```
test/
├── src/
│   ├── main.cr                # Test suite entry point & runner node registrations
│   ├── fixtures/              # Reusable target nodes (PropertyTestTarget, etc.)
│   │   └── test_target_nodes.cr
│   ├── suites/                # 40+ modular test suites categorized by feature area
│   │   ├── test_core_builtins.cr
│   │   ├── test_2d_nodes.cr
│   │   ├── test_3d_nodes.cr
│   │   ├── test_packed_arrays_containers.cr
│   │   ├── test_variant_math_deep.cr
│   │   ├── test_memory_cyclic_refcounting.cr
│   │   ├── test_servers_low_level_rid.cr
│   │   ├── test_virtual_methods_dispatch.cr
│   │   ├── test_concurrency_multi_thread_gc.cr
│   │   └── ...
│   └── generated/             # Auto-generated project node bindings
├── scenes/                    # Godot test scenes (main_test_runner.tscn, etc.)
├── spec/                      # Fast headless Crystal unit specs (test/spec/)
└── project.godot              # Standalone Godot test project configuration
```

---

## 2. Multi-Tier Testing Hierarchy

Testing in LibGodot is divided into three distinct operational tiers:

<table>
  <thead>
    <tr>
      <th align="left">Tier</th>
      <th align="left">Purpose</th>
      <th align="left">Execution Command</th>
      <th align="left">Environment</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Tier 1: Headless Specs</strong></td>
      <td>Pure Crystal unit specs (math, vector algorithms, CLI parsing, syntax)</td>
      <td><code>make spec</code> (or <code>crystal spec test/spec tools/lapis/spec</code>)</td>
      <td>Headless, zero Godot dependencies</td>
    </tr>
    <tr>
      <td><strong>Tier 2: In-Editor Tool Tests</strong></td>
      <td>Editor tool scripts, plugins, and inspector properties (<code>ToolTester2D/3D</code>)</td>
      <td><code>lapis test --skip-specs --skip-runtime-tests</code></td>
      <td>Headless Godot Editor (<code>--editor --headless</code>)</td>
    </tr>
    <tr>
      <td><strong>Tier 3: Runtime Integration Suites</strong></td>
      <td>Deep engine bindings, ObjectDB lifecycle, signals, physics, servers, concurrency</td>
      <td><code>make all</code> or <code>lapis test</code> (or <code>make run</code> for interactive UI)</td>
      <td>Godot Runtime (GDExtension DLL / Standalone Executable)</td>
    </tr>
  </tbody>
</table>

### Separation Rule:
- If code tests pure Crystal math, algorithms, or CLI syntax without touching Godot's C-API bridge: place it in **`test/spec/`** or **`tools/lapis/spec/`**.
- If code tests engine interaction, ObjectDB, node lifecycles, Variant conversion, signals, shaders, or servers: place it in **`test/src/suites/`** using `Lapis::Test`.

---

## 3. `Lapis::Test` Apparatus & DSL

All modular test suites in `test/src/suites/` use `Lapis::Test` (provided by `src/libgodot/testing.cr`).

### Defining Test Suites
Use the declarative `test_suite` macro:

```crystal
require "../fixtures/test_target_nodes"

include Lapis::Test

test_suite "MyCategory" do
  before_each do |root|
    # Setup runs before each test in this category
  end

  after_each do |root|
    # Teardown runs after each test in this category, even upon failure
  end

  test "verifies something safely" do
    node = Godot.create(Godot::Node2D)
    assert_alive node
    node.destroy
    assert_disposed node
  end
end
```

### Assertion Reference
All assertions record exact source locations (`file:line`) for instant debugging:

- **Equality & Truth**: `assert_eq(actual, expected)`, `assert_true(cond)`, `assert_false(cond)`, `assert_approx_eq(actual, expected, epsilon)`.
- **Nil Checks**: `assert_not_nil(val)`, `assert_nil(val)`.
- **Exceptions**: `assert_raises(ErrorClass) { ... }`.
- **Godot Domain Assertions**:
  - `assert_alive(object)`: Validates that `object.alive?` is true.
  - `assert_disposed(object)`: Validates that `object.alive?` is false.
  - `assert_valid_id(instance_id)`: Validates that `Godot::Object.is_instance_id_valid(id)` is true.
  - `assert_invalid_id(instance_id)`: Validates that `Godot::Object.is_instance_id_valid(id)` is false.
  - `assert_vector_approx(v1, v2, epsilon)`: Tolerance comparison for Vector2, Vector3, Vector4, Color.
  - `assert_signal_count(spy, count)`: Verifies number of emissions recorded by a `SignalSpy`.
  - `assert_refcount(refcounted, count)`: Verifies native C++ atomic reference count.
- **Quantitative Zero-Leak Verification**:
  - `assert_no_leak(max_delta_objects: 0) { ... }`: Measures Godot `Performance::OBJECT_COUNT` and `OBJECT_NODE_COUNT`, triggers Boehm `GC.collect`, and asserts zero net object leak.

### Async & Signal Helpers
- `skip_frames(count)`: Cooperatively yields process/idle frames to fibers.
- `skip_physics_frames(count)`: Cooperatively yields physics ticks.
- `await_signal(emitter, signal_name, timeout_sec)`: Non-blocking signal await with timeout watchdog.
- `assert_emits(emitter, signal_name, timeout_sec) { ... }`: Asserts that evaluating the block emits the signal.
- `assert_no_emit(emitter, signal_name, duration_sec) { ... }`: Confirms signal silence.
- `SignalSpy.new(emitter, signal_name)`: Records emissions history, arguments, and count.

---

## 4. Running the Tests

- **Full Suite Build & Run**: `make all`
- **Unified Test Command**: `lapis test`
- **Run Specific Phase**:
  - Only Headless Specs: `lapis test --skip-tool-tests --skip-runtime-tests --skip-standalone`
  - Only In-Editor Tool Tests: `lapis test --skip-specs --skip-runtime-tests --skip-standalone`
  - Only Standalone Executable: `lapis test --skip-specs --skip-tool-tests --skip-runtime-tests`
- **Interactive UI Runner**: `make run`
  - Opens `RunTesterPanel` in Godot, displaying all 40+ test categories dynamically with one-click filtering.
