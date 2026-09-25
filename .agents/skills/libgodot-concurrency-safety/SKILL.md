---
name: libgodot-concurrency-safety
description: >-
  Rules, patterns, and invariants for concurrency, threading, fibers, channels,
  and dead-pointer protection in LibGodot. Use when writing asynchronous gameplay,
  background workers, or investigating thread safety issues.
---

# LibGodot Concurrency & Memory Safety Guide

This skill provides patterns and architectural rules for working safely with concurrency and memory ownership in LibGodot.

---

## The 5 Inviolable Concurrency Rules

### 1. SceneTree is Strictly Single-Threaded
**Never mutate the SceneTree from a background thread or un-yielded fiber.**
- Calling `add_child`, `remove_child`, `reparent`, or `queue_free` off the Main Thread corrupts Godot's internal child lists, causing random memory corruption and engine segmentation faults.
- All hierarchy mutations must occur on Godot's Main Thread.

### 2. Cooperative Fibers Require `Fiber.yield` in `_process`
- Godot owns the OS main loop.
- Fibers spawned via `spawn do ... end` will starve unless the main thread cooperatively yields execution slices.
- Always include `Fiber.yield` in `_process(delta)` of any node managing cooperative fibers.

### 3. Avoid Blocking Sleep in Fibers and Threads
- **In Fibers**: Top-level `sleep(duration)` relies on Crystal's event loop (LibEvent/IOCP), which Godot does not pump. Calling `sleep` causes fibers to hang indefinitely.
  - *Fix*: Use `get_tree.create_timer(duration)` or frame delta accumulators.
- **In OS Threads (`Thread.new`)**: Top-level `sleep(duration)` yields the current fiber to an `ExecutionContext`. Raw OS threads lack an execution context, raising `NilAssertionError: Fiber#execution_context cannot be nil`.
  - *Fix*: Use `Crystal::System::Thread.sleep(duration)` for genuine OS thread sleeps.

### 4. Use `Channel(T)` for Background Workers (Actor Pattern)
Offload heavy math, pathfinding grids, procedural generation, or HTTP requests to background OS threads, and communicate back to the Main Thread via `Channel(T)`.
**Always use buffered channels (`Channel(T).new(capacity)`) across OS threads.** In Crystal 1.20+, unbuffered channels (`Channel(T).new`) suspend the calling fiber when no receiver is ready; on raw OS threads (`Thread.new`), `Fiber#execution_context` is `nil`, so suspending raises `NilAssertionError: Fiber#execution_context cannot be nil`.


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

### 5. Cross-Thread Method Dispatch via `call_deferred`
When a background thread needs to trigger an action on a Godot node without waiting for a reply:
```crystal
Thread.new do
  result = compute_heavy_task()
  hud_node.call_deferred("update_score", result) # Routes through Godot MessageQueue!
end
```

### 6. Awaiting Signals and Timers (`await`)
Inside cooperative gameplay fibers (`spawn do ... end`), use `await` instead of blocking sleeps:
```crystal
spawn do
  # 1. Await duration (cooperative non-blocking delay)
  await(2.0) # Or: await(2.seconds)

  # 2. Await SceneTreeTimer or timer timeout
  timer = get_tree.create_timer(1.5)
  await(timer.timeout) # Or: await(timer)

  # 3. Style A: First-Class BoundSignal (auto-generated from `signal died`)
  enemy = get_node_as(Enemy, "Boss")
  args = await(enemy.died) # Or: enemy.died.await
  # With timeout: await(enemy.died, timeout_sec: 5.0)

  # 4. Style B: Classic Target + Signal String (ideal for dynamic/runtime signal names)
  signal_name = "died"
  args = await(enemy, signal_name) # Or: enemy.await_signal(signal_name)
  # With timeout: await(enemy, "died", timeout_sec: 5.0)

  # 5. Await engine signals via node.signal("name")
  button = get_node_as(Godot::Button, "StartButton")
  await(button.signal("pressed")) # Or: button.signal("pressed").await

  # 6. Connect and emit directly on bound signals
  enemy.health_changed.connect { |args| Godot.print("Health: #{args}") }

  Godot.print("Boss died, reward: #{args}")
end
```
Ensure `_process(delta)` calls `Fiber.yield` each frame to grant execution slices to awaiting fibers.

---

## Dead-Pointer & Object Liveness Patterns

### 1. Monotonic Instance ID Validation
Every `Godot::Object` stores its 64-bit monotonic instance ID (`@instance_id`). Godot's `ObjectDB` generates monotonic IDs that never collide with recycled heap addresses.

### 2. Check Liveness with `#alive?`
When holding cached references to nodes that might have been destroyed by GDScript or `queue_free`:
```crystal
if target.alive?
  target.position = new_pos
else
  active_targets.delete(target)
end
```

### 3. Catch `Godot::DisposedObjectError`
Operations on freed objects raise a clean, catchable Crystal exception instead of crashing the process:
```crystal
begin
  untrusted_node.do_something
rescue ex : Godot::DisposedObjectError
  Godot.print_warn "Encountered dead node (ID: #{ex.instance_id}); skipping operation."
end
```

### 4. Standalone Nodes vs Parented Nodes
- **Parented**: Owned by the SceneTree. Use `node.queue_free`.
- **Standalone Unparented**: If created via `Godot.create(...)` and not added to the tree, you **MUST** call `node.destroy` when finished to prevent native C++ memory leaks.

---

## Related Skills

- **[`crystal-execution-contexts`](../crystal-execution-contexts/SKILL.md)**: Deep dive into Crystal's execution contexts (`Fiber::ExecutionContext`), work-stealing schedulers, dynamic thread scaling, `Concurrent`, `Parallel`, and `Isolated` models.

