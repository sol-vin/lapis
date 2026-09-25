# LibGodot & Crystal Execution Contexts: Interop Patterns

This reference document defines architectural rules and interop patterns for running Crystal **Execution Contexts** alongside the Godot Engine in LibGodot.

---

## 1. Engine Threading Invariants

Godot's architecture is built on a single-threaded Main Loop for its SceneTree and node hierarchy.

```
                    ┌──────────────────────────────────────────────┐
                    │               OS Main Thread                 │
                    │   Godot Engine Main Loop & SceneTree Graph   │
                    │      _process(delta) / _physics_process      │
                    └──────────────────────┬───────────────────────┘
                                           │
                        ┌──────────────────┴──────────────────┐
                        ▼                                     ▼
        ┌───────────────────────────────┐     ┌───────────────────────────────┐
        │  Main Context (Concurrent)    │     │  Background Execution Contexts│
        │  - Game Logic Nodes           │     │  - Parallel Worker Pool       │
        │  - Fiber.yield in _process    │     │  - Isolated GUI / Native I/O  │
        │  - SceneTree Mutations        │     │  - Concurrent Audio Subsystem │
        └───────────────────────────────┘     └───────────────┬───────────────┘
                                                              │
                                       Channel(T) / call_deferred
                                                              │
                                                              ▼
                                              ┌───────────────────────────────┐
                                              │ Safe Main Thread Consumption  │
                                              └───────────────────────────────┘
```

### The Invariant Rules:
1. **SceneTree Mutation is Main-Thread Only**: Calling `add_child`, `remove_child`, `reparent`, or `queue_free` off the Main Thread corrupts Godot's internal child vector and crashes the engine.
2. **Never Run SceneTree Operations in `Parallel` Contexts**: Because `Parallel` contexts implement work-stealing, fibers can switch OS threads at runtime. A fiber interacting with Godot nodes inside a parallel context will randomly execute on a secondary worker thread, violating Godot's thread affinity checks.
3. **Never Block Godot's Main Thread**: Godot pumps the OS message loop, rendering pipeline, and input events. If the main thread blocks on synchronous I/O or a blocking lock, the window freezes.

---

## 2. Pattern 1: Parallel Background Workers with Buffered Channel

Use `Fiber::ExecutionContext::Parallel` to offload CPU-intensive tasks (e.g., procedural generation, A* pathfinding, data decompression). Return results via a buffered channel and consume them non-blockingly inside `_process`.

```crystal
require "libgodot"

class MapGenerator < Godot::Node3D
  # Channel with buffer capacity to avoid producer stalling
  @result_channel = Channel(Array(Godot::Vector3)).new(capacity: 16)
  @pool = Fiber::ExecutionContext::Parallel.new("MapWorkers", maximum: 4)

  def start_chunk_generation(chunk_coord : Godot::Vector2i) : Void
    @pool.spawn do
      # 1. Heavy computation runs across parallel worker threads
      vertices = compute_procedural_mesh(chunk_coord)

      # 2. Transmit immutable data back across contexts
      @result_channel.send(vertices)
    end
  end

  def _process(delta : Float64) : Void
    # 3. Non-blocking drain on Godot's Main Thread
    select
    when vertices = @result_channel.receive
      # 4. Safe SceneTree manipulation on Main Thread!
      mesh_instance = build_mesh_node(vertices)
      add_child(mesh_instance)
    else
      # Work still running off-thread; do not block frame rendering
    end
  end

  private def compute_procedural_mesh(coord : Godot::Vector2i) : Array(Godot::Vector3)
    # Heavy math calculation
    Array(Godot::Vector3).new
  end

  private def build_mesh_node(vertices : Array(Godot::Vector3)) : Godot::MeshInstance3D
    Godot.create(Godot::MeshInstance3D)
  end
end
```

---

## 3. Pattern 2: Isolated Context for Blocking Native C Calls

When interfacing with 3rd-party C libraries (e.g., synchronous audio synthesis, embedded database queries, external hardware drivers), use `Fiber::ExecutionContext::Isolated`. The fiber owns a dedicated OS thread and will never switch threads or interfere with Godot's main scheduler.

```crystal
require "libgodot"

class HardwareController < Godot::Node
  @isolated : Fiber::ExecutionContext::Isolated?
  @command_channel = Channel(Symbol).new(8)

  def _ready : Void
    @isolated = Fiber::ExecutionContext::Isolated.new("HardwareDeviceThread") do
      device_event_loop
    end
  end

  private def device_event_loop : Void
    # Runs exclusively on its own dedicated OS thread
    while command = @command_channel.receive?
      break if command == :shutdown
      # Safe to make blocking C syscalls:
      LibHardware.blocking_read_device()
    end
  end

  def _exit_tree : Void
    @command_channel.send(:shutdown)
    @isolated.try(&.wait) # Gracefully await thread completion on teardown
  end
end
```

---

## 4. Pattern 3: Cross-Thread Method Dispatch via `call_deferred`

When a background worker in an execution context needs to invoke a method on a Godot node without creating a dedicated return channel:

```crystal
@pool.spawn do
  processed_score = compute_score()
  # Routes through Godot's thread-safe MessageQueue to run on the Main Thread next frame:
  hud_label.call_deferred("set_text", "Score: #{processed_score}")
end
```

---

## 5. Pattern 4: Gameplay Cooperative Fibers with `await`

For gameplay sequences (cinematics, dialogue sequences, cooldowns), run cooperative fibers in the default context and yield slices during `_process`:

```crystal
class BossFight < Godot::Node3D
  def _ready : Void
    spawn do
      play_intro_cutscene()
      await(2.5) # Cooperative SceneTreeTimer await

      intro_camera.queue_free()
      boss_health_bar.visible = true

      # Await custom Godot signal
      await(boss.died)
      trigger_victory_sequence()
    end
  end

  def _process(delta : Float64) : Void
    # CRITICAL: Cooperatively yield execution slice to spawned fibers
    Fiber.yield
  end
end
```

---

## 6. Thread Safety Checklist for LibGodot

| Scenario | Anti-Pattern | Safe Pattern |
| :--- | :--- | :--- |
| **Node Instantiation & Tree Insertion** | Calling `add_child` from `Parallel.spawn` | Send result over `Channel(T)` and call `add_child` inside `_process`. |
| **Sleeping in Fibers** | Top-level `sleep(duration)` | `await(duration)` or `get_tree.create_timer(duration)`. |
| **Sleeping in Dedicated OS Threads** | Top-level `sleep(duration)` (raises `NilAssertionError`) | `Crystal::System::Thread.sleep(duration)`. |
| **Sharing Mutable Collections** | Shared `Hash`/`Array` without locks | Wrap in `::Thread::Mutex` or exchange immutable values via channels. |
| **Calling Native C API with Thread Affinity** | Running in `Parallel` context (work-stealing changes thread) | Run in `Isolated` context or on the Godot Main Thread. |
| **Checking Object Liveness** | Holding raw pointers across frames | Check `node.alive?` and catch `Godot::DisposedObjectError`. |
