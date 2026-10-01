---
name: lapis-optimization-flags
description: >-
  Use compile-time flags, binary stripping, and opt-in diagnostic instrumentation in Lapis games.
  Use when producing ultra-lean production binaries, diagnosing memory leaks, profiling virtual method latency, or tracking dead pointers.
---

# Lapis Compile-Time Optimization & Diagnostic Flags Runbook

Lapis provides a suite of compile-time switches to strip unnecessary metadata and subsystems for production, or inject zero-overhead diagnostics for debugging.

---

## 1. Quick Reference: Flags Matrix

| Optimization Goal | Flag / CLI Switch | Environment Variable | What It Does |
| :--- | :--- | :--- | :--- |
| **Lean Production Binaries** | `--strip-docs` / `-Dno_doc` | `STRIP_DOCS=1` | Removes doc comments, XML help generation, and `EditorDocRegistry` allocations |
| **Max Call Throughput** | `--no-thread-safety` / `-Dfast_dispatch` | `NO_THREAD_SAFETY=1` | Bypasses `assert_main_thread!` checks on scene graph operations |
| **Exclude Test Scaffolding** | `--no-testing` / `-Dno_testing` | `NO_TESTING=1` | Removes test suites and benchmark apparatus from output binaries |
| **External Debugger Support** | `--no-crash-handler` / `-Dno_crash_handler` | `NO_CRASH_HANDLER=1` | Disables Windows VEH handler so radare2 or Visual Studio catches unhandled faults |
| **Object Leak Tracking** | `--leak-tracker` / `-Dleak_tracker` | `LEAK_TRACKER=1` | Tracks all `Godot::Object` allocations, call sites, and reports surviving instances |
| **Method Latency Profiling** | `--profile-dispatches` / `-Dprofile_dispatches` | `PROFILE_DISPATCHES=1` | Records nanosecond timing on all virtual method dispatches into Crystal |
| **Dead-Pointer History** | `--trace-dead-pointers` / `-Dtrace_dead_pointers` | `TRACE_DEAD_POINTERS=1`| Keeps deallocation callstacks in a ring buffer for rich `DisposedObjectError` messages |
| **Signal Flow Inspection** | `--trace-signals` / `-Dtrace_signals` | `TRACE_SIGNALS=1` | Intercepts and logs all signal emissions across the scene tree |

---

## 2. Stripping for Lean Production

When preparing a production release:
```bash
# Combine release optimization with documentation stripping and thread safety bypass
lapis build --release --strip-docs --no-thread-safety
```

### Benefits:
1. **Binary Size Reduction**: Stripping doc strings and editor help XML eliminates thousands of strings from the binary `.rdata` section.
2. **CPU Instruction Efficiency**: Inlining zero-cost no-ops for `assert_main_thread!` eliminates thread-local storage (TLS) lookups and branch checks on every `add_child`, `remove_child`, or scene graph call.

---

## 3. Opt-in Diagnostic Instrumentation

When debugging memory lifecycle or performance problems, enable diagnostics on demand:

### 3.1. Tracking Object Memory Leaks (`--leak-tracker`)
```bash
lapis build --leak-tracker
```
In your code or shutdown handler:
```crystal
{% if flag?(:leak_tracker) %}
  puts "Total surviving Godot objects: #{Godot::Diagnostics::LeakTracker.count}"
  Godot::Diagnostics::LeakTracker.dump_active_objects
{% end %}
```

### 3.2. Profiling Virtual Method Latency (`--profile-dispatches`)
```bash
lapis build --profile-dispatches
```
Prints detailed invocation counts, total duration, and average latency across virtual callbacks (`_process`, `_physics_process`):
```crystal
{% if flag?(:profile_dispatches) %}
  Godot::Diagnostics::DispatchProfiler.dump_report
{% end %}
```

### 3.3. Explaining Dead Pointer Crashes (`--trace-dead-pointers`)
```bash
lapis build --trace-dead-pointers
```
When an object is freed in GDScript or Godot and later accessed in Crystal, `Godot::DisposedObjectError` displays:
```text
DisposedObjectError: Attempted to access destroyed object #1536105194213 (Enemy)
Object was previously destroyed at:
  src/combat/enemy.cr:42 in 'die'
  src/combat/battle.cr:115 in 'process_turn'
```
