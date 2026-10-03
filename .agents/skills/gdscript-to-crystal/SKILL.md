---
name: gdscript-to-crystal
description: Complete cheatsheet, line-by-line syntax conversion, idioms, memory rules, and direct code translations from GDScript to Crystal in Lapis. Use when porting GDScript code to Crystal, explaining syntax differences, or onboarding Godot developers to Lapis.
---

# GDScript to Crystal Migration Cheatsheet & Guide

This skill is the authoritative conversion guide and Rosetta Stone for translating **Godot 4 GDScript** patterns into idiomatic **Crystal** for **Lapis**.

---

## 1. Quick Syntax Comparison Matrix

<table>
  <thead>
    <tr>
      <th align="left">GDScript Feature</th>
      <th align="left">Crystal / Lapis Equivalent</th>
      <th align="left">Notes &amp; Architectural Difference</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>class_name Player extends CharacterBody2D</code></td>
      <td><code>node Player &lt; CharacterBody2D do</code><br><code>&nbsp;&nbsp;...</code><br><code>end</code></td>
      <td>Explicit parent node class. Registers class in Godot ClassDB and synthesizes typed constructor.</td>
    </tr>
    <tr>
      <td><code>class_name GameManager extends Node</code></td>
      <td><code>node GameManager do</code><br><code>&nbsp;&nbsp;...</code><br><code>end</code></td>
      <td>Omitting the parent class defaults automatically to <code>Godot::Node</code>.</td>
    </tr>
    <tr>
      <td><code>class_name Player2D extends Node2D</code></td>
      <td><code>node2d Player2D do</code><br><code>&nbsp;&nbsp;...</code><br><code>end</code></td>
      <td>Convenience DSL macro defaulting automatically to <code>Godot::Node2D</code>.</td>
    </tr>
    <tr>
      <td><code>class_name Player3D extends Node3D</code></td>
      <td><code>node3d Player3D do</code><br><code>&nbsp;&nbsp;...</code><br><code>end</code></td>
      <td>Convenience DSL macro defaulting automatically to <code>Godot::Node3D</code>.</td>
    </tr>
    <tr>
      <td><code>class_name ItemData extends Resource</code></td>
      <td><code>gdclass ItemData &lt; Godot::Resource do</code><br><code>&nbsp;&nbsp;...</code><br><code>end</code></td>
      <td>Registers non-Node <code>Resource</code> or <code>RefCounted</code> classes in ClassDB.</td>
    </tr>
    <tr>
      <td>(GDScript shared script/mixin)</td>
      <td><code>gmodule CombatMixin do</code><br><code>&nbsp;&nbsp;&#64;&#91;Export&#93;</code><br><code>&nbsp;&nbsp;property power : Int32 = 10</code><br><code>end</code></td>
      <td>Reusable GDExtension mixin with exported properties, signals, and methods.</td>
    </tr>
    <tr>
      <td><code>$Sprite2D</code> (Typed child lookup)</td>
      <td><code>~Sprite2D</code></td>
      <td>Unary <code>~</code> on a Class looks up first child matching that type in active NodeContext.</td>
    </tr>
    <tr>
      <td><code>$&quot;Sprite2D&quot;</code> (String child lookup)</td>
      <td><code>~&quot;Sprite2D&quot;</code></td>
      <td>Unary <code>~</code> on String resolves child by relative node path.</td>
    </tr>
    <tr>
      <td><code>$&quot;../Player&quot;</code> (Parent/sibling lookup)</td>
      <td><code>~&quot;../Player&quot;</code></td>
      <td>Resolves relative path via active SceneTree NodeContext.</td>
    </tr>
    <tr>
      <td><code>%&quot;HealthBar&quot;</code> (Scene unique node)</td>
      <td><code>~&quot;%HealthBar&quot;</code></td>
      <td>Resolves scene-unique node identifier (<code>%</code> prefix).</td>
    </tr>
    <tr>
      <td><code>$SomeName as Player</code> (Explicit casting)</td>
      <td><code>~&quot;SomeName&quot;.as(Player)</code><br><code>~&quot;SomeName&quot;.as Player</code></td>
      <td>Downcasts resolved node to target typed Crystal class.</td>
    </tr>
    <tr>
      <td><code>%&quot;HealthBar&quot; as ProgressBar</code></td>
      <td><code>~&quot;%HealthBar&quot;.as(ProgressBar)</code><br><code>~&quot;%HealthBar&quot;.as ProgressBar</code></td>
      <td>Casting scene unique node to specific control type.</td>
    </tr>
    <tr>
      <td><code>get_node_or_null(&quot;Sprite2D&quot;)</code></td>
      <td><code>~Sprite2D?</code></td>
      <td>Unary <code>~</code> on nilable Class returns typed <code>Sprite2D?</code> or <code>nil</code> if absent.</td>
    </tr>
    <tr>
      <td><code>@export var speed: float = 300.0</code></td>
      <td><code>&#64;&#91;Export&#93;</code><br><code>property speed : Float32 = 300.0_f32</code></td>
      <td>Strictly typed; exposes property to Inspector.</td>
    </tr>
    <tr>
      <td><code>@export_range(1.0, 20.0, 0.5) var speed: float = 7.0</code></td>
      <td><code>&#64;&#91;Export(range: 1.0_f32..20.0_f32, step: 0.5_f32)&#93;</code><br><code>property speed : Float32 = 7.0_f32</code></td>
      <td>Configures in-editor numeric slider limits and step increments.</td>
    </tr>
    <tr>
      <td><code>@export_enum(&quot;Idle&quot;, &quot;Run&quot;, &quot;Jump&quot;) var state: int = 0</code></td>
      <td><code>enum State { Idle, Run, Jump }</code><br><code>&#64;&#91;ExportEnum&#93;</code><br><code>property state : State = State::Idle</code></td>
      <td>Type-safe Crystal enum automatically exposed as dropdown menu.</td>
    </tr>
    <tr>
      <td><code>@onready var sprite = $Sprite2D</code></td>
      <td><code>getter(sprite) { ~Sprite2D }</code></td>
      <td>Lazy memoized getter resolving child node on first access.</td>
    </tr>
    <tr>
      <td><code>signal health_changed(curr, max)</code></td>
      <td><code>signal health_changed(current : Int32, max_health : Int32)</code></td>
      <td>First-class signal accessors: <code>health_changed.emit(curr, max)</code>, <code>connect</code>, and piping (<code>&gt;</code>, <code>&gt;&gt;</code>).</td>
    </tr>
    <tr>
      <td><code>func _ready():</code></td>
      <td><code>def _ready : Void</code></td>
      <td>Called when node enters SceneTree.</td>
    </tr>
    <tr>
      <td><code>func _process(delta):</code></td>
      <td><code>def _process(delta : Float64) : Void</code></td>
      <td>Delta is <code>Float64</code>; cooperative fibers yield here via <code>Fiber.yield</code>.</td>
    </tr>
    <tr>
      <td><code>func _physics_process(delta):</code></td>
      <td><code>def _physics_process(delta : Float64) : Void</code></td>
      <td>Fixed physics tick step.</td>
    </tr>
    <tr>
      <td><code>await get_tree().create_timer(1.0).timeout</code></td>
      <td><code>await(1.0)</code><br>or <code>await(get_tree.create_timer(1.0))</code></td>
      <td>Non-blocking signal awaiting; checks <code>#alive?</code> on every frame.</td>
    </tr>
    <tr>
      <td><code>await enemy.died</code></td>
      <td><code>await(enemy.died)</code><br>or <code>enemy.died.await</code></td>
      <td>First-class bound signal awaiting with optional timeout argument.</td>
    </tr>
    <tr>
      <td><code>match val:</code><br><code>&nbsp;&nbsp;1: foo()</code><br><code>&nbsp;&nbsp;_: bar()</code></td>
      <td><code>match val do</code><br><code>&nbsp;&nbsp;is 1 do foo end</code><br><code>&nbsp;&nbsp;default do bar end</code><br><code>end</code></td>
      <td>First-class pattern matching macro supporting downcasting, variant unboxing, guards, and destructuring.</td>
    </tr>
    <tr>
      <td><code>queue_free()</code></td>
      <td><code>queue_free</code></td>
      <td>Deferred deletion by Godot engine main loop at frame end.</td>
    </tr>
    <tr>
      <td><code>Node.new()</code> (unparented)</td>
      <td><code>node = Godot.create(Node2D)</code><br><em>Must call node.destroy if unparented!</em></td>
      <td>Prevents native C++ engine memory leaks for unparented nodes.</td>
    </tr>
    <tr>
      <td><code>var dict = {&quot;key&quot;: 123}</code></td>
      <td><code>{&quot;key&quot; =&gt; 123}</code> (Crystal)<br>or <code>Godot::Dictionary</code> (Interop)</td>
      <td>Use native Crystal collections for performance; Godot variants for IPC.</td>
    </tr>
    <tr>
      <td><code>@rpc(&quot;any_peer&quot;, &quot;call_local&quot;) func hit():</code></td>
      <td><code>&#64;&#91;RPC(mode: :any_peer, sync: :call_local)&#93;</code><br><code>def hit : Void</code></td>
      <td>Multiplayer API registration with automatic packet replication.</td>
    </tr>
  </tbody>
</table>

---

## 2. Core Architectural & Idiomatic Patterns

### 1. Declaring Classes & Nodes
In GDScript, each `.gd` file typically represents a class. In Crystal/Lapis, multiple nodes can coexist cleanly in one file or across modules:

```crystal
require "lapis"

# Explicit inheritance from Godot engine classes
node Player < CharacterBody2D do
  @[Export]
  property speed : Float32 = 250.0_f32
end

# Defaulting to Godot::Node
node GameManager do
  property score : Int32 = 0
end

# Shorthand 2D node
node2d Bullet do
  property velocity : Vector2 = Vector2.new(10.0_f32, 0.0_f32)
end

# Shorthand 3D spatial node
node3d Asteroid do
  property rotation_speed : Float32 = 1.5_f32
end

# Custom Resource registered in ClassDB
gdclass InventoryItem < Godot::Resource do
  @[Export]
  property name : String = "Healing Potion"
  @[Export]
  property heal_amount : Int32 = 50
end
```

### 2. Resolving Scene Nodes with `~`
Lapis provides the expressive unary `~` operator matching GDScript's `$` and `%` operators:

```crystal
def _ready : Void
  # 1. Typed child lookup (first child of type AnimatedSprite2D)
  sprite = ~AnimatedSprite2D

  # 2. String path child lookup
  hitbox = ~"HitboxArea/CollisionShape2D"

  # 3. Relative parent or sibling lookup
  camera = ~"../MainCamera"

  # 4. Scene unique node identifier (% prefix)
  health_bar = ~"%HealthBar"

  # 5. Explicit downcasting to custom user node class
  target = ~"TargetNode".as(Enemy)
  boss_bar = ~"%BossHealth".as(ProgressBar)

  # 6. Nilable lookup (returns nil if node does not exist)
  optional_light = ~PointLight2D?
end
```

### 3. Signals & Type-Safe Dispatch
```crystal
node HealthComponent < Node do
  # Declare signals with strict types
  signal damaged(amount : Int32, remaining : Int32)
  signal died

  property current_health : Int32 = 100

  def take_damage(amount : Int32) : Void
    @current_health -= amount
    # First-class signal emission
    damaged.emit(amount, @current_health)
    if @current_health <= 0
      died.emit
    end
  end
end
```

### 4. Non-Blocking Signal Awaiting
Never use blocking `sleep` in fibers or threads! Use `await`:

```crystal
def attack_routine : Void
  # Wait 0.5 seconds without stopping engine frame loop
  await(0.5)

  # Await a bound signal
  await(~AnimatedSprite2D.animation_finished)

  # Await with timeout protection
  await(enemy.died, timeout_sec: 5.0)
end
```

### 5. Memory Safety & Dead-Pointer Protection
Godot's C++ memory model can delete nodes behind Crystal's back (e.g. via GDScript `queue_free()`).

1. **Always Check `#alive?` on transient references**:
   ```crystal
   if enemy.alive?
     enemy.take_damage(10)
   end
   ```
2. **Parented Nodes**:
   Call `node.queue_free` to let the SceneTree handle deallocation cleanly at frame end.
3. **Unparented Standalone Nodes**:
   Nodes created via `Godot.create(Node2D)` that are never added to the tree MUST be cleaned up manually via `node.destroy` to prevent native C++ memory leaks.
