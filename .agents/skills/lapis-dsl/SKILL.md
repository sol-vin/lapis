---
name: lapis-dsl
description: Complete specification and authoring guide for the Lapis gameplay and engine DSL in Crystal. Covers node/node2d/node3d/gdclass/gmodule macros, unary ~ scene queries, export annotations, signals, await, lifecycle methods, @[Tool], @[RPC], and dead-pointer protection. Use when writing gameplay scripts, creating custom nodes, exposing properties to the inspector, or designing multiplayer logic in Lapis.
---

# Lapis Gameplay DSL Reference Manual

This skill is the authoritative engineering manual for writing gameplay logic, custom nodes, resources, and editor tools using the declarative **Lapis Gameplay DSL** in Crystal.

---

## 1. Class & Node Declarations

Lapis provides 5 macro directives for declaring Godot classes and mixins:

```crystal
require "lapis"

# 1. Explicit inheritance from any Godot engine node class
node Player < CharacterBody2D do
  @[Export]
  property speed : Float32 = 250.0_f32
end

# 2. Defaults automatically to Godot::Node
node GameManager do
  property current_score : Int32 = 0
end

# 3. Shorthand for 2D scene nodes (defaults to Godot::Node2D)
node2d Bullet do
  property velocity : Vector2 = Vector2.new(12.0_f32, 0.0_f32)
end

# 4. Shorthand for 3D spatial nodes (defaults to Godot::Node3D)
node3d Asteroid do
  property angular_velocity : Vector3 = Vector3.new(0.0_f32, 1.0_f32, 0.0_f32)
end

# 5. Non-Node ClassDB classes (Resource, RefCounted, Object)
gdclass InventoryItem < Godot::Resource do
  @[Export]
  property item_id : String = "potion_01"
  @[Export]
  property stack_limit : Int32 = 99
end

# 6. Reusable GDExtension mixins with exports, signals, and methods
gmodule DamageableMixin do
  @[Export]
  property armor_rating : Int32 = 10

  signal damaged(amount : Int32, remaining : Int32)

  def take_damage(amount : Int32) : Void
    mitigated = Math.max(1, amount - @armor_rating)
    emit_damaged(mitigated, 100)
  end
end
```

---

## 2. Resolving Scene Nodes with Unary `~`

The unary `~` operator in Lapis provides idiomatic, high-performance replacements for Godot's `$` and `%` operators:

```crystal
def _ready : Void
  # 1. Typed lookup of first child matching class
  sprite = ~AnimatedSprite2D

  # 2. String relative path child resolution
  hitbox = ~"HitboxArea/CollisionShape2D"

  # 3. Tree navigation (parents / siblings)
  camera = ~"../MainCamera"

  # 4. Scene unique node identifier (% prefix)
  health_bar = ~"%HealthBar"

  # 5. Explicit downcasting to custom user node class
  target = ~"TargetNode".as(Enemy)
  bar = ~"%HealthBar".as(ProgressBar)

  # 6. Nilable lookup (returns nil if child absent)
  optional_light = ~PointLight2D?
  if light = optional_light
    light.energy = 1.5_f32
  end
end
```

---

## 3. Export Annotations

Properties annotated with `@[Export...]` are registered into Godot's `ClassDB` and displayed in the Godot Inspector:

```crystal
node Weapon < Node2D do
  # Standard typed export
  @[Export]
  property weapon_name : String = "Plasma Rifle"

  # Numeric range slider with min, max, and step
  @[Export(range: 1.0_f32..100.0_f32, step: 0.5_f32)]
  property fire_rate : Float32 = 10.0_f32

  # Type-safe enum dropdown
  enum FireMode
    Single
    Burst
    Auto
  end

  @[ExportEnum]
  property mode : FireMode = FireMode::Single

  # File and Directory pickers with filter patterns
  @[ExportFile(filter: "*.png,*.jpg")]
  property texture_path : String = "res://assets/weapon.png"

  @[ExportDir]
  property sound_bank_dir : String = "res://audio/weapons"

  # Bitmask flags
  @[ExportFlags("Fire", "Ice", "Lightning", "Poison")]
  property elemental_flags : Int32 = 1

  # Exponential easing curve for tweens and animation curves
  @[ExportExpEasing]
  property damage_falloff : Float32 = 1.0_f32

  # In-editor tool button triggering a parameterless method
  @[ExportToolButton(title: "Reset Weapon Stats")]
  def reset_stats : Void
    @fire_rate = 10.0_f32
    @mode = FireMode::Single
  end
end
```

---

## 4. Signals & Event Dispatch

```crystal
node Character < CharacterBody2D do
  # Declare signals with typed parameters
  signal health_changed(current : Int32, max_health : Int32)
  signal state_transitioned(old_state : String, new_state : String)
  signal defeated

  property health : Int32 = 100

  def apply_damage(amount : Int32) : Void
    @health -= amount
    # Synthesized type-safe emitter helper
    emit_health_changed(@health, 100)

    if @health <= 0
      emit_defeated
    end
  end

  def _ready : Void
    # Connect signals dynamically
    defeated.connect(self, "on_character_defeated")
  end

  def on_character_defeated : Void
    Godot.print("Character has perished!")
  end
end
```

---

## 5. Non-Blocking Awaiting (`await`)

Never use blocking `sleep` in game loops! Use `await`:

```crystal
def attack_combo : Void
  # 1. Await a timer in seconds without blocking the engine loop
  await(0.2)

  # 2. Await bound signal
  await(~AnimatedSprite2D.animation_finished)

  # 3. Method syntax on bound signal
  ~AnimatedSprite2D.animation_finished.await

  # 4. Await with timeout protection (raises on expiration)
  await(target.died, timeout_sec: 5.0)

  # 5. Await classic target + signal name
  await(target, "died", timeout_sec: 5.0)
end
```

---

## 6. Engine Lifecycle Virtual Methods

```crystal
node GameEntity < CharacterBody2D do
  # Called when node enters SceneTree
  def _enter_tree : Void
  end

  # Called when node and children are ready
  def _ready : Void
  end

  # Variable frame rate step (rendering, animation, UI)
  def _process(delta : Float64) : Void
    # Spawned fibers MUST yield here cooperatively:
    Fiber.yield
  end

  # Fixed frame rate step (physics simulation)
  def _physics_process(delta : Float64) : Void
    move_and_slide
  end

  # Input events
  def _input(event : Godot::InputEvent) : Void
    if event.is_action_pressed("jump")
      velocity.y = -400.0_f32
    end
  end

  # Called when node leaves SceneTree
  def _exit_tree : Void
  end
end
```

---

## 7. In-Editor `@tool` Execution

Mark classes with `@[Tool]` to run them inside the Godot Editor in real time:

```crystal
@[Tool]
node CustomGizmo < Node2D do
  @[Export]
  property radius : Float32 = 50.0_f32

  def _process(delta : Float64) : Void
    if Godot::Engine.is_editor_hint?
      queue_redraw
    end
  end

  def _draw : Void
    draw_circle(Vector2.zero, @radius.to_f64, Color.new(1.0_f32, 0.2_f32, 0.2_f32, 0.8_f32))
  end
end
```

---

## 8. Multiplayer DSL (`@[RPC]`)

```crystal
node NetworkPlayer < CharacterBody3D do
  # Declarative RPC configuration
  @[RPC(mode: :any_peer, sync: :call_local, transfer: :unreliable_ordered, channel: 0)]
  def update_position(pos : Vector3) : Void
    self.global_position = pos
  end

  @[RPC(mode: :authority, sync: :call_local, transfer: :reliable)]
  def take_damage(amount : Int32) : Void
    # Validate authority before applying
    return unless is_multiplayer_authority?
    # Apply damage
  end
end
```

---

## 9. Dead-Pointer Protection & Memory Safety

Godot C++ instances can be destroyed by the engine while Crystal wrappers still hold references:

```crystal
# 1. Monotonic Instance Tracking & Defense
if enemy.alive?
  enemy.take_damage(10)
else
  # Enemy has been freed by Godot
end

# 2. Defensive check_alive!
# LibGodot automatically verifies instance alive state before C-API dispatches,
# raising Godot::DisposedObjectError instead of crashing with a 0xC0000005 segfault.

# 3. Ownership Invariants:
# - Parented nodes: call node.queue_free to let SceneTree deallocate them cleanly.
# - Standalone unparented nodes: MUST call node.destroy to prevent native leaks.
```

---

## 10. Expressive Dependency Loading

Use `ensure_lapis` across addon files to avoid duplicate require cycles and linker errors:

```crystal
require "../../dummy_base_dep/src/dummy_base_dep"
ensure_lapis

node StorageChest < Node2D do
  # ...
end
```
