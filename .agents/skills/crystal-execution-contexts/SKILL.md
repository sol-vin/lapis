---
name: crystal-execution-contexts
description: >-
  Master Crystal's multithreading and fiber orchestration model using Execution Contexts (Fiber::ExecutionContext).
  Use when designing concurrent or parallel Crystal architectures, configuring thread scaling, working with Concurrent,
  Parallel, or Isolated contexts, handling work-stealing and blocking syscall thread-switching, migrating from preview MT,
  or preventing thread-affinity pitfalls in native C bindings and game engines (LibGodot).
---

# Crystal Execution Contexts Guide

This skill provides an authoritative guide to Crystal's multithreading and fiber scheduling architecture based on **Execution Contexts** (`Fiber::ExecutionContext`), introduced to replace legacy preview MT.

---

## 1. Quick Reference: Execution Context Types

Execution contexts decouple fibers from fixed OS threads, allowing custom orchestration across one to many threads.

| Context Type | Class | Parallelism | Primary Use Case | Key Behavior |
| :--- | :--- | :--- | :--- | :--- |
| **Default** | `Fiber::ExecutionContext.default` | 1 by default (dynamic) | Main application, backward compatibility | Parallel context starting at parallelism 1. Can be dynamically resized. |
| **Concurrent** | `Fiber::ExecutionContext::Concurrent` | 1 (single-threaded) | Cooperative subsystems, event loops | Fibers run concurrently to each other; never in parallel. Still runs in parallel to other contexts. |
| **Parallel** | `Fiber::ExecutionContext::Parallel` | Dynamic up to `maximum` | Heavy computation, worker pools | Fibers run concurrently and in parallel. Uses dynamic work-stealing across thread pool. |
| **Isolated** | `Fiber::ExecutionContext::Isolated` | 1 dedicated OS thread | GUI main loops, game loops, blocking C calls | Single fiber owns the system thread for its lifetime. Thread switching never occurs. |

---

## 2. Fast Setup & Configuration

### Resizing the Default Context
Applications boot with `Fiber::ExecutionContext.default` set to a parallelism of 1 (single-threaded concurrency) to preserve backward compatibility. Enable true multi-core scaling at runtime:

```crystal
# Scale across all available CPU cores:
Fiber::ExecutionContext.default.resize(maximum: System.cpu_count)

# Or support explicit environment variable configuration:
maximum = ENV["CRYSTAL_WORKERS"]?.try(&.to_i?) || System.cpu_count
Fiber::ExecutionContext.default.resize(maximum: maximum)
```

> [!NOTE]
> `CRYSTAL_WORKERS` is **no longer used automatically** by the Crystal runtime. You must manually inspect `ENV["CRYSTAL_WORKERS"]` and call `resize`.

### Spawning into Custom Contexts

```crystal
# 1. Parallel Context: scales worker threads dynamically up to maximum
parallel = Fiber::ExecutionContext::Parallel.new("Workers", maximum: 4)
parallel.spawn do
  # Parallel CPU work
end

# 2. Concurrent Context: single-threaded concurrency (no locks needed for internal invariants)
concurrent = Fiber::ExecutionContext::Concurrent.new("AudioPipeline")
concurrent.spawn do
  # Concurrent sequential tasks
end

# 3. Isolated Context: dedicated OS thread owned by single fiber
isolated = Fiber::ExecutionContext::Isolated.new("GameLoop") do
  # Blocking loop or C library calls requiring strict thread affinity
end
isolated.wait # Non-blocking wait for completion
```

---

## 3. The 3 Major Breaking Changes & Gotchas

### 1. Fibers Can Switch Threads (Work-Stealing)
In `Parallel` contexts (and resized `default`), fibers can be stolen and resumed on different OS worker threads after waiting on I/O, channels, or yielding.
- **Gotcha**: Code cannot assume `Thread.current` remains constant across fiber suspension points.
- **Fix**: Never store thread-local state or assume native thread affinity across yields in parallel contexts.

### 2. Schedulers Switch Threads on Blocking Syscalls
When a fiber invokes a blocking syscall (e.g., `getaddrinfo(3)`), the scheduler jumps to a fresh OS thread from the pool to keep executing runnable fibers while the syscall blocks.
- **Affected Contexts**: Applies to `Concurrent`, `Parallel`, and `default`.
- **Exception**: Does **NOT** occur in `Isolated` contexts.
- **Gotcha**: If external C libraries (OpenGL, Direct3D, SDL, Godot) expect calls to stay on the process main thread, scheduler switching can crash the application.
- **Fix**: Keep thread-sensitive native loops inside `Fiber::ExecutionContext::Isolated` or on Godot's Main Thread.

### 3. `spawn(same_thread: true)` is Deprecated and Raises
- In `Parallel` and `default` contexts, `spawn(same_thread: true)` raises a runtime exception:
  `Unhandled exception: Fiber::ExecutionContext::Parallel::Scheduler#spawn doesn't support same_thread:true (RuntimeError)`
- In `Concurrent` contexts, `same_thread` is a no-op.
- **Migration**:
  - If `same_thread: false`: Safely delete the argument.
  - If `same_thread: true`: Remove the argument and enforce synchronization using `Sync` primitives (or spawn into a `Concurrent` context).

---

## 4. Compilation Flags

| Flag | Purpose |
| :--- | :--- |
| *(default)* | Uses Execution Contexts with `default` parallelism 1. |
| `-Dwithout_mt` | Reverts to legacy single-threaded scheduler without multithreading support. |
| `-Dpreview_mt` | Reverts to legacy preview MT scheduler (Crystal 0.28-style fixed threads). |
| `-Dpreview_mt -Dexecution_context` | Keeps modern execution contexts active even when `-Dpreview_mt` is present. |

---

## 5. LibGodot & Game Engine Concurrency Invariants

When working with LibGodot, adhere strictly to these execution context rules:

1. **Godot SceneTree Requires Main Thread Affinity**:
   - Never mutate SceneTree nodes (`add_child`, `remove_child`, `queue_free`) from background contexts.
   - Schedulers in `Parallel` contexts switch threads; keep SceneTree operations exclusively inside Godot's main lifecycle callbacks (`_process`, `_physics_process`).
2. **Offload Heavy Work via `Parallel` Context + Buffered Channels**:
   - Run pathfinding, procedural mesh generation, or AI calculations in a `Parallel` context.
   - Send immutable results through a buffered `Channel(T).new(capacity)`.
   - Poll channels non-blockingly on the Main Thread inside `_process` using `select ... when ... else`.
3. **Use `Isolated` Context for Blocking Native Subsystems**:
   - If integrating a 3rd-party C library with blocking loops or strict thread-affinity (e.g., audio synthesizer, networking daemon), wrap it in `Fiber::ExecutionContext::Isolated`.
4. **Avoid `Sync::Mutex` on Raw OS Threads**:
   - `Sync::Mutex` suspends fibers using `ExecutionContext`. Raw OS threads (`Thread.new`) lack an execution context and will raise `NilAssertionError`. Use `::Thread::Mutex` for cross-thread synchronization.

---

## 6. Auto-Scaling & Microbenchmarks ("Slow-Parallelism")

- The execution context thread pool scales worker threads every **~100 ms**.
- **Benchmark Trap**: Microbenchmarks completing in <100ms may finish before the runtime scales beyond 1 core, creating misleading "single-threaded" results.
- **Fix**: In benchmarks or performance tests, warm up the thread pool or execute sufficient workload to allow the scheduler to scale up threads.

---

## 7. Reference Documents & Examples

- **Architecture Deep-Dive**: [`references/execution_contexts_reference.md`](./references/execution_contexts_reference.md)
- **Godot Interop & Thread Safety**: [`references/godot_interop_patterns.md`](./references/godot_interop_patterns.md)
- **Example: Isolated GUI/Worker Loop**: [`examples/isolated_gui_worker.cr`](./examples/isolated_gui_worker.cr)
- **Example: Parallel Work-Stealing Scaling**: [`examples/parallel_scaling.cr`](./examples/parallel_scaling.cr)
- **Example: Concurrent Subsystem (Lock-Free)**: [`examples/concurrent_subsystem.cr`](./examples/concurrent_subsystem.cr)
