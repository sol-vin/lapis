---
name: lapis-best-practices
description: Design patterns, architectural best practices, and performance guidelines for Lapis games. Use when structuring game systems, designing node hierarchies, writing custom resources, optimizing performance, or implementing multiplayer.
---

# Lapis Best Practices &amp; Game Architecture Guide

This skill outlines idiomatic design patterns, architectural paradigms, memory safety invariants, and performance optimization techniques for developing production games with Lapis and Crystal in Godot 4.

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
      <td><a href="#1-composition-over-inheritance-crystal-modules"><strong>1. Composition over Inheritance (Crystal Modules)</strong></a></td>
      <td>While Godot uses single-inheritance class hierarchies (Node &rarr; Node2D &rarr; CharacterBody2D), Crystal...</td>
      <td align="center"><code>L72–L122</code></td>
    </tr>
    <tr>
      <td><a href="#2-custom-resources-for-data-driven-design"><strong>2. Custom Resources for Data-Driven Design</strong></a></td>
      <td>Store game configurations, item schemas, dialogue trees, and skill stats in typed Resource objects rather t...</td>
      <td align="center"><code>L123–L160</code></td>
    </tr>
    <tr>
      <td><a href="#3-concurrency-amp-multithreading-actor-pattern"><strong>3. Concurrency &amp; Multithreading (Actor Pattern)</strong></a></td>
      <td>Godot's SceneTree is fundamentally single-threaded.</td>
      <td align="center"><code>L161–L245</code></td>
    </tr>
    <tr>
      <td><a href="#4-zero-leak-memory-management-amp-dead-pointers"><strong>4. Zero-Leak Memory Management &amp; Dead Pointers</strong></a></td>
      <td>Crystal's Boehm GC and Godot's ObjectDB have distinct lifecycles:</td>
      <td align="center"><code>L246–L262</code></td>
    </tr>
    <tr>
      <td><a href="#5-resilient-in-editor-tool-scripts"><strong>5. Resilient In-Editor `@tool` Scripts</strong></a></td>
      <td>When authoring tool scripts that execute live inside the Godot Editor:</td>
      <td align="center"><code>L263–L297</code></td>
    </tr>
    <tr>
      <td><a href="#6-multiplayer-networking-rpc"><strong>6. Multiplayer Networking (`@[RPC]`)</strong></a></td>
      <td>Lapis integrates directly with Godot's High-Level Multiplayer API:</td>
      <td align="center"><code>L298–L330</code></td>
    </tr>
    <tr>
      <td><a href="#7-zero-allocation-streaming-traversal-eachnode"><strong>7. Zero-Allocation Streaming Traversal (`each_node`)</strong></a></td>
      <td>Avoid collecting large Array(Node) buffers in hot gameplay loops.</td>
      <td align="center"><code>L331–L352</code></td>
    </tr>
    <tr>
      <td><a href="#8-dead-pointer-safe-physics-raycasts"><strong>8. Dead-Pointer Safe Physics Raycasts</strong></a></td>
      <td>Never store or dereference raw collider pointers across frames.</td>
      <td align="center"><code>L353–L367</code></td>
    </tr>
    <tr>
      <td><a href="#9-quantitative-zero-leak-verification-assertnoleak"><strong>9. Quantitative Zero-Leak Verification (`assert_no_leak`)</strong></a></td>
      <td>In Lapis test suites, mathematically verify zero native or GC memory leaks using Godot's Performance monitors:</td>
      <td align="center"><code>L368–L386</code></td>
    </tr>
  </tbody>
</table>

---

## 1. Composition over Inheritance (Crystal Modules)

While Godot uses single-inheritance class hierarchies (`Node` &rarr; `Node2D` &rarr; `CharacterBody2D`), Crystal modules provide zero-overhead compile-time mixins.

### Idiomatic Component Pattern:
```crystal
require "libgodot"

# Reusable component mixin
module Damageable
  @[Export]
  property max_health : Int32 = 100

  @[Export]
  property current_health : Int32 = 100

  signal health_changed(current : Int32, max : Int32)
  signal died

  def take_damage(amount : Int32) : Void
    return if current_health <= 0
    @current_health = Math.max(0, @current_health - amount)
    health_changed.emit(@current_health, @max_health)
    died.emit if @current_health == 0
  end
end

# Compose into any node class
node Player < CharacterBody2D do
  include Damageable

  def _ready : Void
    died.connect do
      Godot.print("Player #{name} has died!")
    end
  end
end

node DestructibleCrate < StaticBody2D do
  include Damageable

  def _ready : Void
    died.connect do
      queue_free
    end
  end
end
```

---

## 2. Custom Resources for Data-Driven Design

Store game configurations, item schemas, dialogue trees, and skill stats in typed `Resource` objects rather than raw dictionaries or static classes.

### Defining and Using Custom Resources:
```crystal
require "libgodot"

# Custom resource schema
gdclass ItemData < Resource do
  @[Export]
  property id : String = ""

  @[Export]
  property display_name : String = ""

  @[Export]
  property attack_bonus : Int32 = 10

  @[Export(file: "*.png,*.webp")]
  property icon_path : String = ""
end

# Node consuming the resource
node InventorySlot < Control do
  @[Export]
  property item : ItemData? = nil

  def _ready : Void
    if data = @item
      Godot.print("Loaded slot for: #{data.display_name} (+#{data.attack_bonus} ATK)")
    end
  end
end
```

---

## 3. Concurrency &amp; Multithreading (Actor Pattern)

Godot's SceneTree is fundamentally single-threaded. Never mutate nodes from background threads. Offload heavy computation to background OS threads using the **Actor Pattern** with buffered channels.

### Safe Worker Pattern:
```crystal
require "libgodot"

node WorldGenerator < Node2D do
  # Always use buffered channels across OS threads
  @work_channel = Channel(Array(Vector2)).new(capacity: 16)
  @worker_thread : Thread? = nil

  def _ready : Void
    start_background_generation
  end

  private def start_background_generation : Void
    ch = @work_channel
    @worker_thread = Thread.new do
      # Heavy background computation (procedural generation, pathfinding)
      points = Array(Vector2).new(1000) { |i| Vector2.new(i.to_f32, (i * 2).to_f32) }
      ch.send(points)
    end
  end

  def _process(delta : Float64) : Void
    # Drain channel non-blockingly on the main thread
    select
    when points = @work_channel.receive
      apply_generated_points(points)
    else
      # No work ready yet
    end

    # Cooperatively yield so spawned fibers make progress
    Fiber.yield
  end

  private def apply_generated_points(points : Array(Vector2)) : Void
    # Safely modify SceneTree on main thread
    points.each do |pt|
      marker = Godot.create(Godot::Marker2D)
      marker.position = pt
      add_child(marker)
    end
  end
end
```

### Concurrency Rules:
<table>
  <thead>
    <tr>
      <th align="left">Rule</th>
      <th align="left">Violation Hazard</th>
      <th align="left">Safe Alternative</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Main Thread Only for SceneTree</strong></td>
      <td>Memory corruption / crash calling <code>add_child</code> on OS thread</td>
      <td>Send data via <code>Channel(T)</code> or call <code>call_deferred</code></td>
    </tr>
    <tr>
      <td><strong>Always Use Buffered Channels</strong></td>
      <td>Unbuffered channel suspends fiber on OS thread &rarr; <code>NilAssertionError</code></td>
      <td><code>Channel(T).new(capacity)</code></td>
    </tr>
    <tr>
      <td><strong>Never Call Top-Level <code>sleep</code></strong></td>
      <td>Hangs fiber indefinitely or crashes OS thread</td>
      <td><code>await(duration)</code> or <code>create_timer(sec)</code></td>
    </tr>
    <tr>
      <td><strong>Yield in <code>_process</code></strong></td>
      <td>Spawned fibers starve because Godot runs the OS loop</td>
      <td><code>Fiber.yield</code> in <code>_process(delta)</code></td>
    </tr>
  </tbody>
</table>

---

## 4. Zero-Leak Memory Management &amp; Dead Pointers

Crystal's Boehm GC and Godot's ObjectDB have distinct lifecycles:

1. **SceneTree Ownership**:
   - Calling `add_child(node)` transfers ownership to Godot.
   - Calling `node.queue_free` schedules deallocation at the end of the current frame.
2. **Unparented Nodes (`Godot.create`)**:
   - Nodes created with `Godot.create(Node2D)` that are NEVER added to the tree are **not** owned by Godot.
   - You MUST call `node.destroy` when finished to prevent native C++ memory leaks.
3. **Dead-Pointer Defense**:
   - When a node is freed by Godot or GDScript, its Crystal wrapper's raw C++ pointer is dangling.
   - Always check `#alive?` on transient references (enemies, projectiles, targets).
   - Calling methods on freed objects raises `Godot::DisposedObjectError` instead of crashing with a segmentation fault (`0xC0000005`).

---

## 5. Resilient In-Editor `@tool` Scripts

When authoring tool scripts that execute live inside the Godot Editor:

```crystal
@[Tool]
node CustomGizmo2D < Node2D do
  @[Export]
  property radius : Float32 = 50.0_f32 do |val|
    @radius = val
    queue_redraw # Redraw live in editor viewport
  end

  def _ready : Void
    # Guard editor vs gameplay execution
    if Engine.is_editor_hint
      Godot.print("Initializing gizmo inside Godot Editor")
    else
      Godot.print("Initializing gizmo in gameplay runtime")
    end
  end

  def _draw : Void
    draw_circle(Vector2.zero, @radius.to_f64, Color.new(0.2, 0.8, 1.0, 0.7))
  end
end
```

### In-Editor Tool Guidelines:
- **Always Guard Runtime-Only Calls**: Use `Engine.is_editor_hint` to avoid running gameplay state, audio players, or networking in the editor.
- **Null Safety on Parent/Tree**: In the editor, nodes may be loaded standalone without an active scene tree; always check `get_tree?` before accessing singletons.
- **Trigger Redraws on Property Setters**: Wrap exported visual properties with setter blocks that call `queue_redraw` to update immediately.

---

## 6. Multiplayer Networking (`@[RPC]`)

Lapis integrates directly with Godot's High-Level Multiplayer API:

```crystal
node NetworkPlayer < CharacterBody3D do
  @[Export]
  property player_id : Int32 = 1

  # Reliable RPC called on authority only
  @[RPC(mode: :any_peer, call_local: true, transfer_mode: :reliable)]
  def request_jump : Void
    return unless is_multiplayer_authority
    velocity = Vector3.new(velocity.x, 10.0_f32, velocity.z)
    rpc("sync_position", global_position)
  end

  # Unreliable sync for continuous physics state
  @[RPC(mode: :authority, call_local: false, transfer_mode: :unreliable_ordered)]
  def sync_position(pos : Vector3) : Void
    self.global_position = pos
  end
end
```

### Multiplayer Invariants:
- Set multiplayer authority via `set_multiplayer_authority(peer_id)`.
- Use `:reliable` for state transitions, actions, and inventory changes.
- Use `:unreliable_ordered` for frequent position and velocity updates.
- Verify `is_multiplayer_authority` before processing server-authoritative logic.

---

## 7. Zero-Allocation Streaming Traversal (`each_node`)

Avoid collecting large `Array(Node)` buffers in hot gameplay loops. Use streaming iteration with receiver scoping:

```crystal
# 1. Receiver-scoped iteration (implicit `self` dispatch):
each_node("Enemies/*", Enemy) do
  alert!
  take_damage(25)
end

# 2. Block-pass shorthand for single method calls:
each_node("Enemies/*", Enemy, &.alert!)

# 3. Deep descendant search without intermediate array allocations:
each_descendant(Light3D) do
  light_energy = 0.0_f32
end
```

---

## 8. Dead-Pointer Safe Physics Raycasts

Never store or dereference raw collider pointers across frames. Always inspect colliders using the dead-pointer safe `.as?(Type)` pattern:

```crystal
if hit = raycast_to(target_pos)
  # hit.collider dynamically verifies #alive?, returning nil if destroyed:
  if enemy = hit.collider.as?(Enemy)
    enemy.take_damage(25)
  end
end
```

---

## 9. Quantitative Zero-Leak Verification (`assert_no_leak`)

In Lapis test suites, mathematically verify zero native or GC memory leaks using Godot's `Performance` monitors:

```crystal
Lapis::Test.assert_no_leak(max_delta_objects: 0) do
  # Perform repeated gameplay operations (e.g. 500 spawn & despawn cycles)
  500.times do
    node = Godot.create(Node2D)
    node.destroy
  end
end

# Verify no orphaned nodes were left in the engine tree:
Lapis::Test.assert_no_new_orphans do
  # Scene manipulation logic
end
```
