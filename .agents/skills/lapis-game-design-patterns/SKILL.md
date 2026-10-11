---
name: lapis-game-design-patterns
description: User-end game design patterns and gameplay architectures for developers building production games in Lapis with Crystal. Covers Entity-Component architectures via Node DSL, typed ancestor resolution, type-safe Signal Buses, Custom Resource strategies, pure union-type finite state machines, command rollback buffers, and zero-allocation object pools with dead-pointer invariants.
---

# Lapis Game Design Patterns: The Gameplay Architecture Manual

This manual provides production-grade architectural patterns and design blueprints for **game developers authoring games in Lapis with Crystal**.

> [!NOTE]
> This guide is strictly focused on **user-facing gameplay systems** (movement, combat, inventory, state machines, event buses, pooling, and scene pipelines). It intentionally omits internal engine internals (GDExtension C-API dispatch, bridge DLL compilation, or macro synthesis).

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
      <td><a href="#pattern-catalog-quick-reference"><strong>Pattern Catalog Quick Reference</strong></a></td>
      <td><table></td>
      <td align="center"><code>L75–L130</code></td>
    </tr>
    <tr>
      <td><a href="#1-entity-component-via-node-dsl-typed-ancestor-lookup"><strong>1. Entity-Component via Node DSL & Typed Ancestor Lookup</strong></a></td>
      <td>In Lapis, entities (like Player or Boss) are authored using the node macro, while specialized behaviors are...</td>
      <td align="center"><code>L131–L201</code></td>
    </tr>
    <tr>
      <td><a href="#2-type-safe-signal-bus-event-aggregator"><strong>2. Type-Safe Signal Bus & Event Aggregator</strong></a></td>
      <td>Decouple systems (like UI, Audio, Quests, and Achievements) from gameplay nodes using a centralized, static...</td>
      <td align="center"><code>L202–L245</code></td>
    </tr>
    <tr>
      <td><a href="#3-custom-resource-strategy-data-cards"><strong>3. Custom Resource Strategy & Data Cards</strong></a></td>
      <td>Custom Resources in Lapis inherit from Godot::Resource via gdclass.</td>
      <td align="center"><code>L246–L292</code></td>
    </tr>
    <tr>
      <td><a href="#4-pure-typed-state-machine-union-types-structs"><strong>4. Pure Typed State Machine (Union Types + Structs)</strong></a></td>
      <td>Rather than creating a separate Node for every state (which incurs tree traversal and memory overhead), Lap...</td>
      <td align="center"><code>L293–L347</code></td>
    </tr>
    <tr>
      <td><a href="#5-command-rollback-action-system"><strong>5. Command & Rollback Action System</strong></a></td>
      <td>Encapsulating player inputs as immutable commands enables turn-based undo/redo, network rollback simulation...</td>
      <td align="center"><code>L348–L391</code></td>
    </tr>
    <tr>
      <td><a href="#6-zero-allocation-object-pool-with-dead-pointer-safety"><strong>6. Zero-Allocation Object Pool with Dead-Pointer Safety</strong></a></td>
      <td>Repeatedly calling PackedScene.instantiate and queue_free causes native heap churn and GC pauses.</td>
      <td align="center"><code>L392–L460</code></td>
    </tr>
    <tr>
      <td><a href="#7-typed-scene-pipeline-dependency-injection"><strong>7. Typed Scene Pipeline & Dependency Injection</strong></a></td>
      <td>Lapis replaces string-based load("res://...").instantiate().as(...) with the compile-time typed scene insta...</td>
      <td align="center"><code>L461–L479</code></td>
    </tr>
    <tr>
      <td><a href="#8-fluent-tween-sequences-narrative-cutscenes"><strong>8. Fluent Tween Sequences & Narrative Cutscenes</strong></a></td>
      <td>Lapis provides fluent tweening APIs for juicy animation and fiber-driven cutscenes:</td>
      <td align="center"><code>L480–L499</code></td>
    </tr>
  </tbody>
</table>

---

## Pattern Catalog Quick Reference

<table>
  <thead>
    <tr>
      <th align="left">Pattern</th>
      <th align="left">Lapis &amp; Crystal Idiom</th>
      <th align="left">Gameplay System Purpose</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Entity-Component via Node DSL</strong></td>
      <td>Child <code>node</code> components + <code>node &lt;&lt; Parent</code> ancestor injection</td>
      <td>Modular combat, health, and movement without deep inheritance</td>
    </tr>
    <tr>
      <td><strong>Typed Event Bus</strong></td>
      <td>First-class <code>signal</code> accessors and <code>await</code> ergonomics</td>
      <td>Decoupled game-wide notifications (quests, UI, achievements)</td>
    </tr>
    <tr>
      <td><strong>Custom Resource Strategy</strong></td>
      <td><code>gdclass Card &lt; Resource</code> with virtual <code>#execute</code> methods</td>
      <td>Pluggable weapon cards, abilities, spells, and loot tables</td>
    </tr>
    <tr>
      <td><strong>Union-Type State Machine</strong></td>
      <td>Value-type structs + union types (<code>Idle | Moving | Dead</code>)</td>
      <td>Zero-allocation, compile-time verified character state transitions</td>
    </tr>
    <tr>
      <td><strong>Command &amp; Rollback</strong></td>
      <td>Immutable command structs + queue history buffer</td>
      <td>Turn-based undo/redo, network rollback, and action replay</td>
    </tr>
    <tr>
      <td><strong>Memory-Safe Object Pool</strong></td>
      <td>Recycling nodes with <code>#alive?</code> and <code>process_mode = DISABLED</code></td>
      <td>Stutter-free bullet hells and particle spawners with zero GC churn</td>
    </tr>
    <tr>
      <td><strong>Typed Scene Pipeline</strong></td>
      <td>Type operator (<code>"res://..." &gt; ClassName</code>) and <code>.configure</code></td>
      <td>Safe, type-checked scene instantiation and dependency injection</td>
    </tr>
    <tr>
      <td><strong>Fluent Tween &amp; Cutscenes</strong></td>
      <td>Chained <code>tween(...).step(...).chain</code> + cooperative fibers</td>
      <td>Juicy UI animations, camera sequences, and scripted dialogues</td>
    </tr>
  </tbody>
</table>

---

## 1. Entity-Component via Node DSL & Typed Ancestor Lookup

In Lapis, entities (like `Player` or `Boss`) are authored using the `node` macro, while specialized behaviors are encapsulated into child component nodes.

### The Ancestor Resolution (`<<`) Operator:
Instead of brittle string paths like `get_parent.as(CharacterBody2D)`, Lapis provides the typed ancestor query operator `node << TargetClass`:

```crystal
require "libgodot"

# Reusable Health Component
node HealthComponent < Node do
  @[Export]
  property max_health : Int32 = 100
  property current_health : Int32 = 100

  signal health_changed(current : Int32, max_health : Int32)
  signal died

  def _ready : Void
    @current_health = @max_health
  end

  def take_damage(amount : Int32) : Void
    return if @current_health <= 0
    @current_health = Math.max(0, @current_health - amount)
    health_changed.emit(@current_health, @max_health)
    died.emit if @current_health == 0
  end

  def heal(amount : Int32) : Void
    @current_health = Math.min(@max_health, @current_health + amount)
    health_changed.emit(@current_health, @max_health)
  end
end

# Reusable Hurtbox Component
node HurtboxComponent < Area2D do
  # Automatically resolves enclosing CharacterBody2D ancestor!
  def character : CharacterBody2D?
    self << CharacterBody2D
  end

  # Resolves sibling or parent health component
  def health : HealthComponent?
    self << HealthComponent
  end

  def receive_hit(damage_amount : Int32) : Void
    if h = health
      h.take_damage(damage_amount)
    end
  end
end

# Main Character Scene
node Player < CharacterBody2D do
  def _ready : Void
    # Find child component and connect to its death signal
    if health = self << HealthComponent
      health.died.connect do
        Godot.print("Player died!")
        queue_free
      end
    end
  end
end
```

---

## 2. Type-Safe Signal Bus & Event Aggregator

Decouple systems (like UI, Audio, Quests, and Achievements) from gameplay nodes using a centralized, statically typed Event Bus.

```crystal
# EventBus Autoload / Service
node EventBus < Node do
  # Strictly typed signals with argument types
  signal score_added(points : Int32)
  signal enemy_defeated(enemy_type : String, bounty : Int32)
  signal player_health_updated(current : Int32, max_health : Int32)
  signal game_paused(paused : Boolean)
end

# In UI or HUD node:
node ScoreDisplay < Label do
  def _ready : Void
    # Connect to event bus signals
    if bus = get_node("/root/EventBus").as?(EventBus)
      bus.score_added.connect do |points|
        self.text = "Score: #{points}"
      end
    end
  end
end
```

### Async Signal Orchestration with `await`:
Lapis supports compile-time checked `await` with built-in timeout safeguards:

```crystal
node QuestManager < Node do
  def complete_tutorial_sequence(boss : BossEnemy) : Void
    # Wait for the boss to be defeated without halting the engine loop
    await(boss.died, timeout_sec: 60.0)

    # Show celebratory dialog
    show_victory_banner
  end
end
```

---

## 3. Custom Resource Strategy & Data Cards

Custom Resources in Lapis inherit from `Godot::Resource` via `gdclass`. They can be saved as `.tres` files, edited directly in Godot's Inspector, and carry both data and polymorphic strategy methods:

```crystal
# Abstract Weapon Strategy
gdclass WeaponData < Resource do
  @[Export]
  property name : String = "Basic Blaster"

  @[Export]
  property base_damage : Int32 = 15

  @[Export]
  property cooldown : Float32 = 0.25_f32

  # Polymorphic strategy method
  def fire(user : CharacterBody2D, target_dir : Vector2) : Void
    Godot.print("Firing #{name} dealing #{base_damage} damage")
  end
end

# Concrete Strategy: Shotgun
gdclass ShotgunData < WeaponData do
  @[Export]
  property pellets : Int32 = 6

  def fire(user : CharacterBody2D, target_dir : Vector2) : Void
    Godot.print("Firing #{pellets} shotgun pellets!")
  end
end

# Equipping in Player:
node Player < CharacterBody2D do
  @[Export]
  property equipped_weapon : WeaponData?

  def perform_attack(target_dir : Vector2) : Void
    if weapon = @equipped_weapon
      weapon.fire(self, target_dir)
    end
  end
end
```

---

## 4. Pure Typed State Machine (Union Types + Structs)

Rather than creating a separate Node for every state (which incurs tree traversal and memory overhead), Lapis enables **zero-allocation, union-type state machines**:

```crystal
# Value-type states containing state-specific data
struct IdleState; end

struct RunningState
  getter direction : Vector2
  def initialize(@direction : Vector2); end
end

struct JumpingState
  getter vertical_velocity : Float32
  def initialize(@vertical_velocity : Float32); end
end

struct DeadState; end

# Static union type representing all legal states
alias HeroState = IdleState | RunningState | JumpingState | DeadState

node Hero < CharacterBody2D do
  property state : HeroState = IdleState.new

  def _physics_process(delta : Float64) : Void
    # Exhaustive pattern matching checked at compile-time
    case s = @state
    when IdleState
      handle_idle(delta)
    when RunningState
      handle_running(s.direction, delta)
    when JumpingState
      handle_jumping(s.vertical_velocity, delta)
    when DeadState
      # Completely ignore input while dead
    end
  end

  def jump : Void
    if @state.is_a?(IdleState) || @state.is_a?(RunningState)
      @state = JumpingState.new(vertical_velocity: -400.0_f32)
    end
  end
end
```

### Advantages of Union-Type FSM:
1. **Zero Garbage Collection**: Structs live inline on the stack or host node memory.
2. **Compile-Time Exhaustiveness**: Adding a new state forces the compiler to verify all `case` branches.
3. **Data Encapsulation**: Only `RunningState` contains `direction`; only `JumpingState` contains `vertical_velocity`.

---

## 5. Command & Rollback Action System

Encapsulating player inputs as immutable commands enables turn-based undo/redo, network rollback simulation, and demo replays:

```crystal
abstract struct GameCommand
  abstract def execute(hero : CharacterBody2D) : Void
  abstract def undo(hero : CharacterBody2D) : Void
end

struct MoveRelativeCommand < GameCommand
  getter delta_pos : Vector2
  def initialize(@delta_pos : Vector2); end

  def execute(hero : CharacterBody2D) : Void
    hero.position += @delta_pos
  end

  def undo(hero : CharacterBody2D) : Void
    hero.position -= @delta_pos
  end
end

class CommandRecorder
  @history = Array(GameCommand).new
  @undo_stack = Array(GameCommand).new

  def record_and_execute(cmd : GameCommand, actor : CharacterBody2D) : Void
    cmd.execute(actor)
    @history << cmd
    @undo_stack.clear
  end

  def undo(actor : CharacterBody2D) : Void
    return if @history.empty?
    cmd = @history.pop
    cmd.undo(actor)
    @undo_stack << cmd
  end
end
```

---

## 6. Zero-Allocation Object Pool with Dead-Pointer Safety

Repeatedly calling `PackedScene.instantiate` and `queue_free` causes native heap churn and GC pauses. An object pool keeps inactive nodes in memory.

### Crucial Lapis Memory Invariants:
1. **Always check `#alive?`** before re-activating a pooled node to guard against nodes freed externally.
2. Disable processing via `process_mode = PROCESS_MODE_DISABLED` when recycling.
3. Reparent or hide the node cleanly.

```crystal
node Projectile < Area2D do
  property velocity : Vector2 = Vector2.new(0.0_f32, 0.0_f32)

  def reset(spawn_pos : Vector2, travel_dir : Vector2, speed : Float32) : Void
    self.position = spawn_pos
    @velocity = travel_dir.normalized * speed
    self.visible = true
    self.process_mode = PROCESS_MODE_INHERIT
  end

  def deactivate : Void
    self.visible = false
    self.process_mode = PROCESS_MODE_DISABLED
  end

  def _physics_process(delta : Float64) : Void
    self.position += @velocity * delta.to_f32
  end
end

class ProjectilePool
  @available = Array(Projectile).new

  def initialize(@root_node : Node, @capacity : Int32 = 100)
    @capacity.times do
      proj = Godot.create(Projectile)
      proj.deactivate
      @root_node.add_child(proj)
      @available << proj
    end
  end

  def acquire(pos : Vector2, dir : Vector2, speed : Float32) : Projectile
    # Pop an alive node or create fallback
    while !@available.empty?
      node = @available.pop
      if node.alive?
        node.reset(pos, dir, speed)
        return node
      end
    end

    # Fallback if pool is exhausted
    fallback = Godot.create(Projectile)
    @root_node.add_child(fallback)
    fallback.reset(pos, dir, speed)
    fallback
  end

  def release(proj : Projectile) : Void
    return unless proj.alive?
    proj.deactivate
    @available << proj
  end
end
```

---

## 7. Typed Scene Pipeline & Dependency Injection

Lapis replaces string-based `load("res://...").instantiate().as(...)` with the compile-time typed scene instantiation operator (`>`):

```crystal
# Direct typed instantiation
bullet = "res://scenes/bullet.tscn" > Projectile
bullet.position = self.global_position
get_parent.add_child(bullet)

# Fluent configuration pattern
hero = "res://scenes/hero.tscn" > Player.configure do |p|
  p.position = Vector2.new(100.0_f32, 200.0_f32)
end
add_child(hero)
```

---

## 8. Fluent Tween Sequences & Narrative Cutscenes

Lapis provides fluent tweening APIs for juicy animation and fiber-driven cutscenes:

```crystal
node Chest < Area2D do
  def open_chest : Void
    # Fluent chained tween
    tween(self.scale, to: Vector2.new(1.2_f32, 1.2_f32))
      .duration(0.15)
      .ease_out
      .chain
      .step(self.scale, to: Vector2.new(1.0_f32, 1.0_f32))
      .duration(0.1)

    spawn_loot
  end
end
```
