---
name: lapis-dsl
description: Complete specification and authoring guide for the Lapis gameplay and engine DSL in Crystal. Covers node/node2d/node3d/gdclass/gmodule macros, unary ~ scene queries, export annotations, signals, await, lifecycle methods, @[Tool], @[RPC], and dead-pointer protection. Use when writing gameplay scripts, creating custom nodes, exposing properties to the inspector, or designing multiplayer logic in Lapis.
---

# Lapis Gameplay DSL Reference Manual

This skill is the authoritative engineering manual for writing gameplay logic, custom nodes, resources, and editor tools using the declarative **Lapis Gameplay DSL** in Crystal.

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
      <td><a href="#1-class-node-declarations"><strong>1. Class & Node Declarations</strong></a></td>
      <td>Lapis provides 5 macro directives for declaring Godot classes and mixins:</td>
      <td align="center"><code>L142–L193</code></td>
    </tr>
    <tr>
      <td><a href="#2-resolving-scene-nodes-with-unary-onready-properties"><strong>2. Resolving Scene Nodes with Unary `~` & `onready` Properties</strong></a></td>
      <td>The unary prefix ~ operator in Lapis provides idiomatic, high-performance replacements for Godot's $ and %...</td>
      <td align="center"><code>L194–L238</code></td>
    </tr>
    <tr>
      <td><a href="#3-export-annotations"><strong>3. Export Annotations</strong></a></td>
      <td>Properties annotated with @[Export...] are registered into Godot's ClassDB and displayed in the Godot Inspe...</td>
      <td align="center"><code>L239–L288</code></td>
    </tr>
    <tr>
      <td><a href="#4-signals-event-dispatch-piping"><strong>4. Signals, Event Dispatch & Piping</strong></a></td>
      <td>node Character < CharacterBody2D do</td>
      <td align="center"><code>L289–L344</code></td>
    </tr>
    <tr>
      <td><a href="#5-non-blocking-awaiting-await"><strong>5. Non-Blocking Awaiting (`await`)</strong></a></td>
      <td>Never use blocking sleep in game loops! Use await:</td>
      <td align="center"><code>L345–L369</code></td>
    </tr>
    <tr>
      <td><a href="#6-engine-lifecycle-virtual-methods"><strong>6. Engine Lifecycle Virtual Methods</strong></a></td>
      <td>node GameEntity < CharacterBody2D do</td>
      <td align="center"><code>L370–L407</code></td>
    </tr>
    <tr>
      <td><a href="#7-in-editor-tool-execution"><strong>7. In-Editor `@tool` Execution</strong></a></td>
      <td>Mark classes with @[Tool] to run them inside the Godot Editor in real time:</td>
      <td align="center"><code>L408–L431</code></td>
    </tr>
    <tr>
      <td><a href="#8-multiplayer-dsl-rpc"><strong>8. Multiplayer DSL (`@[RPC]`)</strong></a></td>
      <td>node NetworkPlayer < CharacterBody3D do</td>
      <td align="center"><code>L432–L452</code></td>
    </tr>
    <tr>
      <td><a href="#9-dead-pointer-protection-memory-safety"><strong>9. Dead-Pointer Protection & Memory Safety</strong></a></td>
      <td>Godot C++ instances can be destroyed by the engine while Crystal wrappers still hold references:</td>
      <td align="center"><code>L453–L475</code></td>
    </tr>
    <tr>
      <td><a href="#10-expressive-dependency-loading"><strong>10. Expressive Dependency Loading</strong></a></td>
      <td>Use ensure_lapis across addon files to avoid duplicate require cycles and linker errors:</td>
      <td align="center"><code>L476–L490</code></td>
    </tr>
    <tr>
      <td><a href="#11-scene-pipeline-fluent-instantiation"><strong>11. Scene Pipeline & Fluent Instantiation</strong></a></td>
      <td># 1.</td>
      <td align="center"><code>L491–L518</code></td>
    </tr>
    <tr>
      <td><a href="#12-type-safe-tweens-animation-pipeline"><strong>12. Type-Safe Tweens & Animation Pipeline</strong></a></td>
      <td># 1.</td>
      <td align="center"><code>L519–L554</code></td>
    </tr>
    <tr>
      <td><a href="#13-pattern-matching-macro-match"><strong>13. Pattern Matching Macro (`match`)</strong></a></td>
      <td>Expression-oriented pattern matching with dead-pointer checking, Variant unboxing, receiver scoping, and im...</td>
      <td align="center"><code>L555–L596</code></td>
    </tr>
    <tr>
      <td><a href="#14-scene-tree-glob-queries-receiver-scoping-metadata"><strong>14. Scene Tree Glob Queries, Receiver Scoping & Metadata</strong></a></td>
      <td># 1.</td>
      <td align="center"><code>L597–L647</code></td>
    </tr>
    <tr>
      <td><a href="#15-physics-raycasting-dead-pointer-safe-hits"><strong>15. Physics Raycasting & Dead-Pointer Safe Hits</strong></a></td>
      <td>Perform direct 2D or 3D raycasts without manual physics query parameter boilerplate:</td>
      <td align="center"><code>L648–L669</code></td>
    </tr>
    <tr>
      <td><a href="#15-timers-lifecycle-sugar"><strong>15. Timers & Lifecycle Sugar</strong></a></td>
      <td># Scoped recurring timer (auto-cancels if node is destroyed):</td>
      <td align="center"><code>L670–L689</code></td>
    </tr>
    <tr>
      <td><a href="#16-compile-time-context-aware-audio-macro-playsound"><strong>16. Compile-Time Context-Aware Audio Macro (`play_sound`)</strong></a></td>
      <td># 1.</td>
      <td align="center"><code>L690–L707</code></td>
    </tr>
    <tr>
      <td><a href="#17-upward-ancestor-search"><strong>17. Upward Ancestor Search (`<<`)</strong></a></td>
      <td>Symmetrical with the typed scene pipeline (scene > Type), << searches upward in the scene hierarchy for an...</td>
      <td align="center"><code>L708–L728</code></td>
    </tr>
    <tr>
      <td><a href="#18-fluent-groupname-dsl"><strong>18. Fluent `group(:name)` DSL</strong></a></td>
      <td>Zero-allocation stack struct (struct GroupQuery) providing clean, chainable group queries:</td>
      <td align="center"><code>L729–L761</code></td>
    </tr>
    <tr>
      <td><a href="#19-asset-loading-macros-load-preload-load-preload-with-type-inference"><strong>19. Asset Loading Macros (`load`, `preload`, `load?`, `preload?`) with Type Inference</strong></a></td>
      <td>Infer return types from file extensions at compile time and pair seamlessly with the typed scene pipeline:</td>
      <td align="center"><code>L762–L793</code></td>
    </tr>
    <tr>
      <td><a href="#20-customizable-onready-getters-setters"><strong>20. Customizable `onready` Getters & Setters</strong></a></td>
      <td>Developers can intercept assignments, attach signal listeners, clamp values, or perform custom caching simp...</td>
      <td align="center"><code>L794–L819</code></td>
    </tr>
    <tr>
      <td><a href="#21-main-thread-execution-godotonmainthread"><strong>21. Main Thread Execution (`Godot.on_main_thread`)</strong></a></td>
      <td>Dispatches a block safely to the Godot Main Thread from background OS threads or cooperative fibers:</td>
      <td align="center"><code>L820–L837</code></td>
    </tr>
    <tr>
      <td><a href="#22-authoritative-dsl-anti-patterns-no-nos-catalog"><strong>22. Authoritative DSL Anti-Patterns & No-Nos Catalog</strong></a></td>
      <td>To maintain a lean, high-signal, zero-bloat codebase, the following patterns are strictly prohibited:</td>
      <td align="center"><code>L838–L885</code></td>
    </tr>
  </tbody>
</table>

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
    damaged.emit(mitigated, 100)
  end
end
```

---

## 2. Resolving Scene Nodes with Unary `~` & `onready` Properties

The unary prefix `~` operator in Lapis provides idiomatic, high-performance replacements for Godot's `$` and `%` operators, resolving against the active thread-local `Godot::NodeContext.current` automatically scoped around all engine callbacks:

```crystal
node Player < CharacterBody2D do
  # 1. Eager onready property initialized during _ready with dead-pointer safety:
  onready sprite : Sprite2D = ~"Sprite2D"
  onready health_bar : ProgressBar = ~"%HealthBar"
  onready anim = ~"AnimationPlayer".as(AnimationPlayer)

  # 2. Idiomatic colon-typed onready with path (or legacy comma syntax):
  onready camera : Camera2D, "Pivot/Camera2D"
  onready boss_hp : ProgressBar, "%BossHealthBar"
  unique_node score_label : Label, "ScoreLabel"
  onready? particle_fx : CPUParticles2D, "VFX/Particles"

  def _ready : Void
    # 3. Direct unary ~ lookups inside methods:
    s = ~"Sprite2D"                      # Child relative path
    hp = ~"%HealthBar"                   # Scene Unique Node (% prefix)
    cam = ~"Pivot/Camera2D"              # Deep relative path
    parent_mgr = ~"../GameManager"       # Parent / sibling navigation

    # 4. Regex node queries (first match and collection):
    first_goblin = ~/goblin_\d+/         # Single node matching regex under active context
    all_enemies = nodes(/enemy_\d+/)     # All matching descendant nodes as Array(Godot::Node)

    # 5. Node direct regex search methods:
    found = self.find_child(/boss_\w+/)
    minions = self.find_children(/minion_\d+/, recursive: true)

    # 6. Typed lookup of first child matching class (get_node_or_null parity):
    if light = ~PointLight2D?
      light.energy = 1.5_f32
    end

    # 7. Direct cast:
    target = ~"TargetNode".as(Enemy)
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

## 4. Signals, Event Dispatch & Piping

```crystal
node Character < CharacterBody2D do
  # Declare signals with typed parameters
  signal health_changed(current : Int32, max_health : Int32)
  signal state_transitioned(old_state : String, new_state : String)
  signal defeated

  property health : Int32 = 100

  def apply_damage(amount : Int32) : Void
    @health -= amount
    # First-class type-safe emitter
    health_changed.emit(@health, 100)

    if @health <= 0
      defeated.emit
    end
  end

  def _ready : Void
    # 1. First-class block connection:
    defeated.connect { Godot.print("Character perished!") }

    # 2. Operator << syntax sugar:
    defeated << ->{ Godot.print("Defeated via proc!") }

    # 3. Compound operators += and -= with procs or subscriptions:
    handler = ->{ Godot.print("Handled!") }
    defeated += handler
    defeated -= handler

    # 4. Expressive 'on' macro with typed downcasting:
    on health_changed do |curr, max|
      Godot.print("HP: #{curr}/#{max}")
    end

    # 5. One-shot listeners:
    defeated.once { Godot.print("Fired only once") }

    # 6. Receiver Lifetime Tracking & Auto-Pruning:
    # Pass listener as receiver; when either emitter or receiver is destroyed,
    # the connection automatically self-prunes without manual _exit_tree boilerplate:
    defeated.connect(hud) { |args| hud.on_character_defeated }

    # 7. Signal Piping:
    # Strict pipe (>): Compile-time verified signature matching
    # Loose pipe (>>): Positional arity trimming and type downcasting
    # start_btn.pressed >> self.game_started
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

---

## 11. Scene Pipeline & Fluent Instantiation

```crystal
# 1. Preload and instantiate typed node:
hero = "res://scenes/hero.tscn" > Hero

# 2. Dynamic uncached loading:
stage = "res://levels/level_01.tscn" >> StageLevel

# 3. Add child with inline configuration returning concrete static type:
boss = parent.add_child(BossEnemy) do |b|
  b.health = 5000
  b.boss_title = "Dread Overlord"
end

# 4. PackedScene typed pipeline:
scene = Godot.load_as(Godot::PackedScene, "res://scenes/companion.tscn")
companion = scene > Companion

# 5. Fluent configuration blocks:
sword = ItemSword.new.build do |s|
  s.damage = 50
  s.rarity = :rare
end
```

---

## 12. Type-Safe Tweens & Animation Pipeline

```crystal
# 1. Fluent Chain & Parallel Pipeline DSL:
tw = tween(hero) do
  animate(:position, from: Vector2.ZERO, to: target_pos, in: 0.4.seconds)
    .trans(:cubic).ease(:out)
    .chain.animate(modulate, from: Color::RED, to: Color::BLUE, in: 0.3.seconds)
    .parallel.animate(scale, to: Vector2.new(1.2, 1.2), in: 0.3.seconds)
    .chain.animate(modulate.a, to: 0.0, in: 0.25.seconds)
end

await(tw.finished)
Godot.print("Hero entrance completed!")

# 2. Deterministic multi-frame test stepping:
tw.pause
tw.custom_step(0.1) # Advances tween timeline deterministically by delta

# 3. Quick single-property animation (implicit self):
tween(position.y, to: 150.0, in: 0.5.seconds)
tween(modulate.a, to: 0.0, in: 0.3.seconds)

# 4. Expressive builder block:
tween do
  animate :scale, to: Vector2.new(1.5_f32, 1.5_f32), duration: 0.2.seconds
  delay 0.1.seconds
  animate :position, :y, to: 0.0, duration: 0.3.seconds
end

# 5. Compile-time validated dot-navigation macro:
tween(player.position.y, to: 100.0, in: 0.4.seconds)
```

---

## 13. Pattern Matching Macro (`match`)

Expression-oriented pattern matching with dead-pointer checking, Variant unboxing, receiver scoping, and implicit variable narrowing:

```crystal
# 1. Polymorphic node downcasting with receiver scoping:
match collider do
  is Player, if: p.health < 20 do |p|
    p.take_damage(100)
  end
  is Enemy do
    apply_knockback(transform.basis.z * 15.0_f32) # Receiver scoped to Enemy!
  end
  is WorldBoundary do
    bounce_projectile!
  end
end

# 2. Implicit variable narrowing (variable is typed as the branch type inside the block):
value_text = match i do
  is Int64          do "Integer: #{i * 2}" end
  is String         do "Text: #{i.upcase}" end
  is Godot::Vector2 do "Vector: (#{i.x}, #{i.y})" end
  default           do "Unsupported Variant" end
end

# 2. Polymorphic node downcasting with dead-pointer validation:
status = match hit.collider do
  is Player do |p| "Player with HP: #{p.health}" end
  is Enemy, if: p.boss? do |b| "Boss: #{b.name}" end
  default do "Obstacle" end
end

# 3. Tuple destructuring:
match {state, on_floor?} do
  is :jump, false do apply_air_control end
  is :jump, true  do land! end
end
```

---

## 14. Scene Tree Glob Queries, Receiver Scoping & Metadata

```crystal
# 1. Streaming traversal with receiver scoping (with node yield node):
# Receiver-scoped dispatch (calls alert! and take_damage on each enemy directly):
each_node("Enemies/*", Enemy) do
  alert!
  take_damage(25)
end

# Block-pass shorthand:
each_node("Enemies/*", Enemy, &.alert!)

# Deep subtree streaming:
each_descendant(Light3D) do
  light_energy = 0.0_f32
end

# 2. Glob search returning Array:
enemies = get_nodes("Enemies/*", Enemy)
all_loot = get_nodes("**/ItemChest", ItemChest)

# 3. Expressive wildcard glob operators (*):
meshes = self * "Node/*/Mesh"                            # -> Array(Godot::Node)
typed_meshes = self * {"Node/*/Mesh", MeshInstance3D}    # -> Array(MeshInstance3D)
chained = self / "MyNodes" * "Mesh*"                     # -> Array(Godot::Node)
typed_chained = self / "MyNodes" * {"Mesh*", MeshInstance3D} # -> Array(MeshInstance3D)
regex_matches = self * /^HitBox_\d+$/                   # -> Array(Godot::Node)
typed_regex = self * {/^HitBox_\d+$/, Area3D}           # -> Array(Area3D)
# Note: * compile-time rejects nillable types (e.g. MeshInstance3D?) because queries return empty arrays, never nils.

# 4. Group inspection with String & Symbol interchangeability:
if enemy.in_group?(:bosses, :elites)
  trigger_boss_music
end

# 4. Metadata CRUD:
node.set_meta(:enemy_tier, 3)
node.set_meta("spawner_id", "wave_01")
tier = node.get_meta_i64(:enemy_tier)
id = node.get_meta_str("spawner_id")
node.remove_meta(:temporary_buff)

# 5. Hierarchy navigation:
room = ancestor(DungeonRoom)
prev_item = previous_sibling?(InventorySlot)
next_item = next_sibling?(InventorySlot)
```

---

## 15. Physics Raycasting & Dead-Pointer Safe Hits

Perform direct 2D or 3D raycasts without manual physics query parameter boilerplate:

```crystal
# 2D Raycast from global_position:
if hit = raycast_to(target_pos)
  # hit.collider dynamically verifies #alive? to prevent dead-pointer crashes:
  if enemy = hit.collider.as?(Enemy)
    enemy.take_damage(25)
  end
end

# 3D Directional Raycast:
if hit = raycast(Vector3.forward, distance: 20.0)
  point = hit.point
  normal = hit.normal
end
```

---

## 15. Timers & Lifecycle Sugar

```crystal
# Scoped recurring timer (auto-cancels if node is destroyed):
every(0.5.seconds) do |handle|
  fire_homing_missile
end

# Scoped one-shot delay:
after(2.0.seconds) do
  respawn_player
end

# Cooperative fiber condition gates:
await_until(character.on_floor?, timeout_sec: 5.0)
await_while(tween.is_running)
```

---

## 16. Compile-Time Context-Aware Audio Macro (`play_sound`)

```crystal
# 1. In Node2D: Automatically emits AudioStreamPlayer2D at global_position
play_sound "res://audio/laser.wav", pitch_scale: 1.2

# 2. In Node3D: Automatically emits AudioStreamPlayer3D at global_position
play_sound "res://audio/explosion.wav" do
  max_distance = 250.0_f32
end

# 3. In Control: Automatically emits non-spatial AudioStreamPlayer
play_sound "res://audio/ui_click.wav", volume_db: -3.0
# Sound survives on scene root even if the calling node is freed immediately!
```

---

## 17. Upward Ancestor Search (`<<`)

Symmetrical with the typed scene pipeline (`scene > Type`), `<<` searches upward in the scene hierarchy for an ancestor:

```crystal
# 1. Strict ancestor search (returns Player; raises Godot::NodeNotFoundError if missing):
player = hitbox << Player
player.take_damage(10)

# 2. Safe / Nilable ancestor search (returns Player?; returns nil if missing):
if boss = hitbox << Boss?
  boss.take_damage(100)
end

# 3. Programmatic method parity:
parent = hitbox.find_ancestor_as!(ParentNode) # -> ParentNode
opt    = hitbox.find_ancestor_as(ShieldNode)  # -> ShieldNode?
```

---

## 18. Fluent `group(:name)` DSL

Zero-allocation stack struct (`struct GroupQuery`) providing clean, chainable group queries:

```crystal
# 1. Iterate with typed receiver:
group(:enemies).each(as: Enemy) do |enemy|
  enemy.take_damage(50)
end

# 2. Collect as typed or untyped array:
enemies = group(:enemies).to_a(as: Enemy) # -> Array(Enemy)
nodes   = group(:lights).to_a             # -> Array(Godot::Node)

# 3. Fetch first member:
boss = group(:boss).first(as: Boss)       # -> Boss?
lead = group(:squad).first                # -> Godot::Node?
must_have = group(:player).first!(as: Player) # -> Player (raises if missing)

# 4. Broadcast / call_group:
group(:enemies).call("alert", player.global_position)
group(:enemies).call(:stun, 2.5)

# 5. Metrics and predicates:
if group(:enemies).empty?
  Godot.print("All enemies cleared!")
end
count = group(:loot).size
has_loot = group(:loot).any?
```

---

## 19. Asset Loading Macros (`load`, `preload`, `load?`, `preload?`) with Type Inference

Infer return types from file extensions at compile time and pair seamlessly with the typed scene pipeline:

```crystal
# 1. Cached asset preloading (PreloadCache):
const ICON         = preload("res://icon.svg")       # -> Texture2D
const PLAYER_SCENE = preload("res://player.tscn")   # -> PackedScene
const JUMP_SFX     = preload("res://sfx/jump.wav")   # -> AudioStream
const THEME_RES    = preload("res://ui_theme.tres")  # -> Resource

# 2. Dynamic runtime loading (ResourceLoader):
level_scene = load("res://scenes/level_2.tscn")      # -> PackedScene
level = load("res://scenes/level_2.tscn") > Level    # Typed scene pipeline!
hud_tex = load("res://art/hud.png")                  # -> Texture2D

# 3. Explicit casting via idiomatic .as and .as?:
custom_res = load("res://data/levels.dat").as(CustomLevelData)
maybe_res = load("res://data/optional.dat").as?(CustomLevelData)

# 4. Safe nilable asset loading (no exceptions on missing files):
opt_theme = load?("res://custom_theme.tres")         # -> Resource? (nil if not found)
opt_sfx = preload?("res://sfx/ambient.wav")          # -> AudioStream?

# 5. Nilable scene pipeline (> and >> with Type?):
# Returns nil if file missing or instantiation fails without raising an exception:
maybe_boss = "res://scenes/boss.tscn" > BossEnemy?   # -> BossEnemy?
maybe_stage = "res://scenes/bonus.tscn" >> BonusStage? # -> BonusStage?
```

---

## 20. Customizable `onready` Getters & Setters

Developers can intercept assignments, attach signal listeners, clamp values, or perform custom caching simply by defining standard methods in the node body:

```crystal
node Player < CharacterBody2D do
  onready health_bar : ProgressBar = "%HealthBar"

  # Custom setter: intercept assignments to health_bar
  def health_bar=(bar : ProgressBar?) : Void
    @health_bar = bar
    if b = bar
      b.min_value = 0.0
      b.max_value = @max_health.to_f64
    end
  end

  # Custom getter: add logging or lazy configuration
  def health_bar : ProgressBar?
    @health_bar
  end
end
```

---

## 21. Main Thread Execution (`Godot.on_main_thread`)

Dispatches a block safely to the Godot Main Thread from background OS threads or cooperative fibers:

```crystal
# Safe main-thread execution:
Godot.on_main_thread do
  get_tree.current_scene.add_child(spawned_enemy)
end

# Top-level convenience helper:
on_main_thread do
  hud.update_score(100)
end
```

---

## 22. Authoritative DSL Anti-Patterns & No-Nos Catalog

To maintain a lean, high-signal, zero-bloat codebase, the following patterns are strictly prohibited:

<table>
  <thead>
    <tr>
      <th align="left">Prohibited Pattern</th>
      <th align="left">Proposed Syntax (Rejected)</th>
      <th align="left">Why It Is Prohibited</th>
      <th align="left">Proper Lapis Alternative</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Node Input Delegation</strong></td>
      <td><code>node.input_axis</code>, <code>node.input_vector</code></td>
      <td>Pollutes the method table of all 400+ <code>Node</code> classes with input logic that belongs strictly to input polling.</td>
      <td><code>Input.axis(...)</code>, <code>Input.vector(...)</code> on <code>Godot::Input</code>.</td>
    </tr>
    <tr>
      <td><strong>Single-Object <code>if_alive</code></strong></td>
      <td><code>node.if_alive { |n| ... }</code></td>
      <td>Syntactic bloat. Adds closure allocation and cognitive overhead over a standard 1-line check.</td>
      <td><code>if node.alive? ... end</code> (idiomatic Crystal).</td>
    </tr>
    <tr>
      <td><strong>Global <code>deferred</code> Macro</strong></td>
      <td><code>deferred { ... }</code></td>
      <td>Redundant bloat. Obscures whether dispatch goes through <code>MessageQueue</code> or <code>ThreadSafety</code>.</td>
      <td><code>node.call_deferred(...)</code> or <code>Godot.on_main_thread { ... }</code>.</td>
    </tr>
    <tr>
      <td><strong>Multi-Object <code>guard_alive</code></strong></td>
      <td><code>guard_alive(a, b) { ... }</code></td>
      <td>Unnecessary magic macro. Standard boolean expressions are faster, clearer, and require zero AST expansion.</td>
      <td><code>if a.alive? && b.alive? ... end</code>.</td>
    </tr>
    <tr>
      <td><strong>Procedural Group Macros</strong></td>
      <td><code>nodes_in_group(...)</code>, <code>each_in_group(...)</code></td>
      <td>Procedural function soup. Lacks fluent chaining and ergonomics.</td>
      <td>Fluent <code>group(:name).each</code>, <code>group(:name).to_a</code> struct.</td>
    </tr>
  </tbody>
</table>

