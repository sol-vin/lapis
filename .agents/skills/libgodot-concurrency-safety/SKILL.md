---
name: libgodot-concurrency-safety
description: >-
  Rules, patterns, and invariants for concurrency, threading, fibers, channels,
  and dead-pointer protection in LibGodot. Use when writing asynchronous gameplay,
  background workers, or investigating thread safety issues.
---

# LibGodot Concurrency & Memory Safety Guide

This skill provides patterns and architectural rules for working safely with concurrency, background threads, cooperative fibers, channels, and native memory ownership in LibGodot.

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
      <td><a href="#1-the-7-inviolable-concurrency-rules"><strong>1. The 7 Inviolable Concurrency Rules</strong></a></td>
      <td>### 1.</td>
      <td align="center"><code>L45–L145</code></td>
    </tr>
    <tr>
      <td><a href="#2-dead-pointer-object-liveness-invariants"><strong>2. Dead-Pointer & Object Liveness Invariants</strong></a></td>
      <td>LibGodot bridges two distinct memory models:</td>
      <td align="center"><code>L146–L169</code></td>
    </tr>
    <tr>
      <td><a href="#3-related-skills"><strong>3. Related Skills</strong></a></td>
      <td>- crystal-execution-contexts: Deep dive into Crystal's execution contexts (Fiber::ExecutionContext), work-s...</td>
      <td align="center"><code>L170–L175</code></td>
    </tr>
  </tbody>
</table>

---

## 1. The 7 Inviolable Concurrency Rules

### 1. SceneTree is Strictly Single-Threaded
**Never mutate the SceneTree from a background thread or un-yielded fiber.**
- Calling `add_child`, `remove_child`, `reparent`, or `queue_free` off the Main Thread corrupts Godot's internal child lists, causing random memory corruption and engine segmentation faults (`0xC0000005`).
- LibGodot enforces this automatically via `Godot::ThreadSafety`: off-thread calls raise `Godot::ThreadAffinityError` before any native FFI dispatch can corrupt memory.
- Use `node.defer_add_child(child)`, `node.defer_queue_free`, `node.call_deferred(...)`, or `Godot.on_main_thread { ... }` for safe cross-thread operations.
- All hierarchy mutations must occur on Godot's Main Thread.

### 2. Cooperative Fibers Require `Fiber.yield` in `_process`
- Godot controls the OS main loop.
- Fibers spawned via `spawn do ... end` will starve unless the main thread cooperatively yields execution slices.
- Always include `Fiber.yield` in `_process(delta)` of any node managing cooperative fibers.

### 3. Avoid Blocking Sleep in Fibers and Threads
- **In Fibers**: Top-level `sleep(duration)` relies on Crystal's event loop (LibEvent/IOCP), which Godot does not pump. Calling `sleep` causes fibers to hang indefinitely.
  - *Fix*: Use `get_tree.create_timer(duration)` or frame delta accumulators, or `await(duration)`.
- **In OS Threads (`Thread.new`)**: Top-level `sleep(duration)` yields the current fiber to an `ExecutionContext`. Raw OS threads lack an execution context, raising `NilAssertionError: Fiber#execution_context cannot be nil`.
  - *Fix*: Use `Crystal::System::Thread.sleep(duration)` for genuine OS thread sleeps.

### 4. Always Use Buffered Channels (`Channel(T).new(N)`) Across OS Threads
Offload heavy computation, pathfinding grids, procedural generation, or HTTP requests to background OS threads, and communicate back to the Main Thread via `Channel(T)`.

> [!IMPORTANT]
> **Crystal 1.20+ Channel Invariant**: In Crystal 1.20+, unbuffered channels (`Channel(T).new`) suspend the calling fiber when no receiver is ready; on raw OS threads (`Thread.new`), `Fiber#execution_context` is `nil`, so suspending raises `NilAssertionError: Fiber#execution_context cannot be nil`.
> Always initialize channels used across OS threads with a non-zero capacity: `Channel(T).new(capacity)`.

```crystal
class ProceduralTerrain < Godot::Node3D
  @result_channel = Channel(Array(Godot::Vector3)).new(1)

  def start_generation
    Thread.new do
      points = generate_vertices_off_thread()
      @result_channel.send(points)
    end
  end

  def _process(delta : Float64) : Void
    # Non-blocking check on Main Thread
    select
    when points = @result_channel.receive
      apply_mesh_to_scene(points) # Safe on Main Thread!
    else
      # Work still in progress
    end
  end
end
```

### 5. Cross-Thread Method Dispatch via `call_deferred` & `Godot.on_main_thread`
When a background thread needs to trigger an action on a Godot node without waiting for a reply:
```crystal
Thread.new do
  result = compute_heavy_task()
  hud_node.call_deferred("update_score", result) # Routes through Godot MessageQueue!
end
```
Or execute a closure directly on the Main Thread:
```crystal
Thread.new do
  result = compute_heavy_task()
  Godot.on_main_thread do
    hud_node.update_score(result)
  end
end
```
*Dead Target Safety*: If `hud_node` is destroyed on the main thread before the queued message is dispatched, Godot's internal `MessageQueue` safely drops the message without crashing Crystal.

### 6. Concurrent Signal Emissions & Dead-Target Auto-Pruning
Background OS threads (`Thread.new`) can safely emit signals into `Godot.notify_signal`:
- Signal subscription tables are protected by `signal_subs_mutex` (`::Thread::Mutex`).
- When a living or dead receiver is connected, `SignalSubscription` checks `receiver.alive?` and silently auto-prunes dead targets without throwing exceptions or risking race conditions.

### 7. Awaiting Signals and Timers (`await`)
Inside cooperative gameplay fibers (`spawn do ... end`), use `await` instead of blocking sleeps:
```crystal
spawn do
  # 1. Await duration (cooperative non-blocking delay)
  await(2.0) # Or: await(2.seconds)

  # 2. Await SceneTreeTimer or timer timeout
  timer = get_tree.create_timer(1.5)
  await(timer.timeout) # Or: await(timer)

  # 3. First-Class BoundSignal (auto-generated from signal declaration)
  enemy = get_node_as(Enemy, "Boss")
  args = await(enemy.died) # With timeout: await(enemy.died, timeout_sec: 5.0)

  # 4. Target + Signal String
  args = await(enemy, "died") # With timeout: await(enemy, "died", timeout_sec: 5.0)

  # 5. Await engine signals via node.signal("name")
  button = get_node_as(Godot::Button, "StartButton")
  await(button.signal("pressed"))
end
```
Ensure `_process(delta)` calls `Fiber.yield` each frame to grant execution slices to awaiting fibers.

---

## 2. Dead-Pointer & Object Liveness Invariants

LibGodot bridges two distinct memory models:
- **Crystal Boehm GC**: Collects Crystal heap objects, fibers, and wrapper instances (`Godot::Object`).
- **Godot ObjectDB & Reference Counting**: Manages native C++ engine nodes and refcounted resources.

### The Dead-Pointer Hazard
If an object is destroyed in Godot or GDScript (e.g. via `queue_free()` or `free()`), standard C-API bindings retain a raw C++ pointer to deallocated memory. Dereferencing this dead pointer causes an immediate, unrecoverable **segmentation fault (`ACCESS_VIOLATION / 0xC0000005`)** that crashes the game without a stack trace.

### Safety Invariants:
1. **Monotonic 64-bit Instance ID Tracking**:
   Every `Godot::Object` stores its 64-bit monotonic instance ID (`@instance_id`). Godot's `ObjectDB` generates monotonic IDs that never collide with recycled heap addresses.
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

## 3. Related Skills

- **[`crystal-execution-contexts`](../crystal-execution-contexts/SKILL.md)**: Deep dive into Crystal's execution contexts (`Fiber::ExecutionContext`), work-stealing schedulers, dynamic thread scaling, `Concurrent`, `Parallel`, and `Isolated` models.
- **[`cradare2-debugger`](../cradare2-debugger/SKILL.md)**: Dynamic debugging, hardware watchpoints, and dead-pointer crash forensics.
- **[`lapis-game-design-patterns`](../lapis-game-design-patterns/SKILL.md)**: User-end gameplay architecture, zero-allocation object pools, and typed signal buses.
