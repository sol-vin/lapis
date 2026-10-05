---
name: lapis-optimization-flags
description: >-
  Use compile-time flags, binary stripping, and opt-in diagnostic instrumentation in Lapis games.
  Use when producing ultra-lean production binaries, diagnosing memory leaks, profiling virtual method latency, or tracking dead pointers.
---

# Lapis Compile-Time Optimization & Diagnostic Flags Runbook

This skill outlines how to configure compile-time switches to strip unnecessary metadata for production releases or inject zero-overhead diagnostics for runtime debugging.

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
      <td><a href="#1-quick-reference-flags-matrix"><strong>1. Quick Reference: Flags Matrix</strong></a></td>
      <td><table></td>
      <td align="center"><code>L44–L124</code></td>
    </tr>
    <tr>
      <td><a href="#2-stripping-for-lean-production-binaries"><strong>2. Stripping for Lean Production Binaries</strong></a></td>
      <td>When building for production distribution, combining compiler optimizations with metadata stripping yields...</td>
      <td align="center"><code>L125–L171</code></td>
    </tr>
    <tr>
      <td><a href="#3-opt-in-diagnostic-instrumentation"><strong>3. Opt-in Diagnostic Instrumentation</strong></a></td>
      <td>When diagnosing memory lifecycle bugs or mysterious engine crashes, enable diagnostics on demand:</td>
      <td align="center"><code>L172–L210</code></td>
    </tr>
  </tbody>
</table>

---

## 1. Quick Reference: Flags Matrix

<table>
  <thead>
    <tr>
      <th align="left">Optimization Goal</th>
      <th align="left">CLI Switch</th>
      <th align="left">Compile Flag</th>
      <th align="left">Environment Variable</th>
      <th align="left">What It Does</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Lean Production Binaries</strong></td>
      <td><code>--strip-docs</code></td>
      <td><code>-Dno_doc</code></td>
      <td><code>STRIP_DOCS=1</code></td>
      <td>Removes doc comments, XML help generation, and <code>EditorDocRegistry</code> allocations</td>
    </tr>
    <tr>
      <td><strong>Max Call Throughput</strong></td>
      <td><code>--no-thread-safety</code></td>
      <td><code>-Dfast_dispatch</code></td>
      <td><code>NO_THREAD_SAFETY=1</code></td>
      <td>Inlines zero-cost no-ops for <code>assert_main_thread!</code> on SceneTree operations</td>
    </tr>
    <tr>
      <td><strong>Exclude Test Scaffolding</strong></td>
      <td><code>--no-testing</code></td>
      <td><code>-Dno_testing</code></td>
      <td><code>NO_TESTING=1</code></td>
      <td>Removes test suites, runner panels, and benchmark apparatus from output binaries</td>
    </tr>
    <tr>
      <td><strong>External Debugger Support</strong></td>
      <td><code>--no-crash-handler</code></td>
      <td><code>-Dno_crash_handler</code></td>
      <td><code>NO_CRASH_HANDLER=1</code></td>
      <td>Disables Windows VEH handler so radare2 or Visual Studio catches unhandled faults directly</td>
    </tr>
    <tr>
      <td><strong>Multithreading Model</strong></td>
      <td><code>--preview-mt</code></td>
      <td><code>-Dpreview_mt</code></td>
      <td><code>PREVIEW_MT=1</code></td>
      <td>Enables multi-threaded execution contexts and parallel fiber scheduling</td>
    </tr>
    <tr>
      <td><strong>Object Leak Tracking</strong></td>
      <td><code>--leak-tracker</code></td>
      <td><code>-Dleak_tracker</code></td>
      <td><code>LEAK_TRACKER=1</code></td>
      <td>Tracks all <code>Godot::Object</code> allocations, call sites, and reports surviving instances</td>
    </tr>
    <tr>
      <td><strong>Method Latency Profiling</strong></td>
      <td><code>--profile-dispatches</code></td>
      <td><code>-Dprofile_dispatches</code></td>
      <td><code>PROFILE_DISPATCHES=1</code></td>
      <td>Records nanosecond timing on all virtual method dispatches into Crystal</td>
    </tr>
    <tr>
      <td><strong>Dead-Pointer History</strong></td>
      <td><code>--trace-dead-pointers</code></td>
      <td><code>-Dtrace_dead_pointers</code></td>
      <td><code>TRACE_DEAD_POINTERS=1</code></td>
      <td>Records deallocation callstacks in a ring buffer for rich <code>DisposedObjectError</code> reports</td>
    </tr>
    <tr>
      <td><strong>Signal Flow Inspection</strong></td>
      <td><code>--trace-signals</code></td>
      <td><code>-Dtrace_signals</code></td>
      <td><code>TRACE_SIGNALS=1</code></td>
      <td>Intercepts and logs all signal emissions across the SceneTree</td>
    </tr>
  </tbody>
</table>

---

## 2. Stripping for Lean Production Binaries

When building for production distribution, combining compiler optimizations with metadata stripping yields substantial binary size reductions and CPU speedups:

```bash
# Maximum production optimization
lapis build --release --strip-docs --no-thread-safety --no-testing
```
Or via Makefile:
```bash
make all RELEASE=1 STRIP_DOCS=1 NO_THREAD_SAFETY=1
```

### Measured Impact:
<table>
  <thead>
    <tr>
      <th align="left">Build Configuration</th>
      <th align="center">Binary Size (game.dll)</th>
      <th align="center">Virtual Method Latency</th>
      <th align="left">Suitability</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Development (Default)</strong></td>
      <td align="center">~32.4 MB</td>
      <td align="center">~42 ns / call</td>
      <td>Editor development, live debugging, hot reloading</td>
    </tr>
    <tr>
      <td><strong>Release (<code>--release</code>)</strong></td>
      <td align="center">~12.8 MB</td>
      <td align="center">~14 ns / call</td>
      <td>Beta testing, performance profiling</td>
    </tr>
    <tr>
      <td><strong>Lean Release (<code>--release --strip-docs --no-thread-safety</code>)</strong></td>
      <td align="center">~7.2 MB</td>
      <td align="center">~6 ns / call</td>
      <td>Production shipping, console/mobile distribution</td>
    </tr>
  </tbody>
</table>

---

## 3. Opt-in Diagnostic Instrumentation

When diagnosing memory lifecycle bugs or mysterious engine crashes, enable diagnostics on demand:

### 3.1. Tracking Object Memory Leaks (`--leak-tracker`)
```bash
lapis build --leak-tracker
```
In your code or shutdown hook:
```crystal
{% if flag?(:leak_tracker) %}
  puts "Total active Godot objects: #{Godot::Diagnostics::LeakTracker.count}"
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

### 3.3. Tracing Dead-Pointer Deallocation Sites (`--trace-dead-pointers`)
```bash
lapis build --trace-dead-pointers
```
When an object is freed by Godot or GDScript and subsequently accessed in Crystal, `Godot::DisposedObjectError` prints the exact stack trace where the object was previously freed:
```text
DisposedObjectError: Attempted to access destroyed object #1536105194213 (Enemy)
Object was previously destroyed at:
  src/combat/enemy.cr:42 in 'die'
  src/combat/battle.cr:115 in 'process_turn'
```
