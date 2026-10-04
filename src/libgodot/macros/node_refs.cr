# Declares an `@onready` node property initialized from the scene tree during `_ready`.
#
# When declared inside a `node` block, the `node` macro extracts this declaration
# and automatically populates the property during `_godot_init_onready_properties`
# immediately before `_ready` runs.
#
# ### Rationale & Mechanics:
# In GDScript, `@onready var sprite = $Sprite2D` delays initialization until the node
# and its children enter the scene tree. In Crystal, `onready` achieves identical semantics
# with full compile-time static typing and dead-pointer safety.
#
# If the right-hand side uses the unary tilde operator `~` (e.g., `~"Sprite2D"`, `~"%HealthBar"`),
# the AST unrolls cleanly at compile time so the path or unique name is extracted directly
# into `get_node_as(...)`.
#
# ### Supported Patterns:
# ```crystal
# node Player < CharacterBody2D do
#   # 1. Unary tilde with inferred type:
#   onready sprite = ~"Sprite2D".as(Sprite2D)
#
#   # 2. Typed declaration with unary tilde:
#   onready sprite : Sprite2D = ~"Sprite2D"
#
#   # 3. Scene Unique Node (% syntax):
#   onready health_bar : ProgressBar = ~"%HealthBar"
#
#   # 4. Explicit path string:
#   onready anim : AnimationPlayer = "AnimationPlayer"
# end
# ```
macro onready(decl)
  {% if decl.is_a?(Assign) %}
    property {{decl.target}}? = nil
  {% elsif decl.is_a?(TypeDeclaration) %}
    property {{decl.var}} : {{decl.type}}? = nil
  {% end %}
end

# Declares a `node_ref` property initialized from the scene tree during `_ready`.
#
# Alias to `onready(decl)`.
#
# ### Example:
# ```crystal
# node Player < CharacterBody3D do
#   node_ref camera : Camera3D = "Camera3D"
# end
# ```
macro node_ref(decl)
  onready({{decl}})
end

# Declares a `unique_node_ref` property initialized from the scene tree during `_ready`.
#
# Alias to `onready(decl)`.
#
# ### Example:
# ```crystal
# node UI < Control do
#   unique_node_ref score_label : Label = "%ScoreLabel"
# end
# ```
macro unique_node_ref(decl)
  onready({{decl}})
end

# Creates a compile-time verified Godot::NodePath
macro node_path!(path)
  ::Godot::NodePath.new({{path}})
end

# Declares a lazy-cached node property matching Godot's `@onready` pattern.
#
# Unlike eager `onready var = path` properties which initialize strictly during `_ready`,
# this macro defines a lazy getter that resolves the node on first access, caches the pointer,
# and verifies `#check_alive!` on every subsequent access to protect against dead-pointer dereferencing.
#
# ### Supported Styles:
# 1. Auto-inferred name and type: `onready sprite_2d, Sprite2D` (fetches child `"Sprite2D"`)
# 2. Scene Unique Node: `onready camera, Camera2D, "%MainCamera"`
# 3. Explicit path: `onready sprite, Sprite2D, "Visuals/Sprite2D"`
#
# ### Example:
# ```crystal
# node Enemy < CharacterBody2D do
#   onready sprite, Sprite2D, "Visuals/Sprite2D"
#   onready health_bar, ProgressBar, "%HealthBar"
#
#   def hit : Void
#     sprite.modulate = Godot::Color.new(1.0, 0.0, 0.0) # Resolves and caches sprite
#   end
# end
# ```
macro onready(name, type, path = nil)
  @{{name.id}} : {{type.id}}? = nil
  def {{name.id}} : {{type.id}}
    if (cached = @{{name.id}})
      cached.check_alive!
      return cached
    end
    {% if path %}
      found = get_node_as({{path}}, {{type.id}})
    {% else %}
      found = get_node_as({{name.id.stringify.camelcase}}, {{type.id}})
    {% end %}
    @{{name.id}} = found
    found
  end

  def {{name.id}}=(val : {{type.id}}?)
    @{{name.id}} = val
  end
end

# Declares a dead-pointer safe, lazy-cached node property matching Godot's `@onready` pattern.
#
# Supports:
# 1. Macro signature: `node_ref player, Player, "Player"`
# 2. Type declaration: `node_ref player : Player = "Player"`
# 3. Auto-inferred: `node_ref sprite_2d : Sprite2D`
macro node_ref(name_or_decl, type = nil, path = nil)
  {% if name_or_decl.is_a?(TypeDeclaration) %}
    {% v_name = name_or_decl.var %}
    {% v_type = name_or_decl.type %}
    {% v_path = name_or_decl.value ? (name_or_decl.value.is_a?(StringLiteral) ? name_or_decl.value : name_or_decl.value.id.stringify) : nil %}
    @{{v_name.id}} : {{v_type.id}}? = nil
    def {{v_name.id}} : {{v_type.id}}
      if (cached = @{{v_name.id}})
        cached.check_alive!
        return cached
      end
      {% if v_path %}
        found = get_node_as({{v_path}}, {{v_type.id}})
      {% else %}
        found = get_node_as({{v_name.id.stringify.camelcase}}, {{v_type.id}})
      {% end %}
      @{{v_name.id}} = found
      found
    end

    def {{v_name.id}}=(val : {{v_type.id}}?)
      @{{v_name.id}} = val
    end
  {% else %}
    @{{name_or_decl.id}} : {{type.id}}? = nil
    def {{name_or_decl.id}} : {{type.id}}
      if (cached = @{{name_or_decl.id}})
        cached.check_alive!
        return cached
      end
      {% if path %}
        found = get_node_as({{path}}, {{type.id}})
      {% else %}
        found = get_node_as({{name_or_decl.id.stringify.camelcase}}, {{type.id}})
      {% end %}
      @{{name_or_decl.id}} = found
      found
    end

    def {{name_or_decl.id}}=(val : {{type.id}}?)
      @{{name_or_decl.id}} = val
    end
  {% end %}
end

# Declares a lazy-cached Scene Unique Node property (Godot 4 `%Node` syntax).
#
# Examples:
# ```
# unique_node health_bar, ProgressBar      # fetches "%HealthBar"
# unique_node main_hud, CanvasLayer, "HUD" # fetches "%HUD"
# ```
macro unique_node(name, type, unique_name = nil)
  @{{name.id}} : {{type.id}}? = nil
  def {{name.id}} : {{type.id}}
    if (cached = @{{name.id}})
      cached.check_alive!
      return cached
    end
    {% if unique_name %}
      found = get_node_as(({{unique_name}}).to_s.starts_with?('%') ? ({{unique_name}}).to_s : "%#{{{unique_name}}}", {{type.id}})
    {% else %}
      found = get_node_as("%" + {{name.id.stringify.camelcase}}, {{type.id}})
    {% end %}
    @{{name.id}} = found
    found
  end

  def {{name.id}}=(val : {{type.id}}?)
    @{{name.id}} = val
  end
end

# Declares a dead-pointer safe, lazy-cached Scene Unique Node property (Godot 4 `%Node` syntax).
#
# Supports:
# 1. Macro signature: `unique_node_ref camera, Camera2D, "MainCamera"`
# 2. Type declaration: `unique_node_ref camera : Camera2D = "MainCamera"`
# 3. Auto-inferred: `unique_node_ref main_hud : CanvasLayer`
macro unique_node_ref(name_or_decl, type = nil, unique_name = nil)
  {% if name_or_decl.is_a?(TypeDeclaration) %}
    {% v_name = name_or_decl.var %}
    {% v_type = name_or_decl.type %}
    {% v_path = name_or_decl.value ? (name_or_decl.value.is_a?(StringLiteral) ? name_or_decl.value : name_or_decl.value.id.stringify) : nil %}
    @{{v_name.id}} : {{v_type.id}}? = nil
    def {{v_name.id}} : {{v_type.id}}
      if (cached = @{{v_name.id}})
        cached.check_alive!
        return cached
      end
      {% if v_path %}
        u_name = ({{v_path}}).to_s.starts_with?('%') ? ({{v_path}}).to_s : "%#{{{v_path}}}"
        found = get_node_as(u_name, {{v_type.id}})
      {% else %}
        found = get_node_as("%" + {{v_name.id.stringify.camelcase}}, {{v_type.id}})
      {% end %}
      @{{v_name.id}} = found
      found
    end

    def {{v_name.id}}=(val : {{v_type.id}}?)
      @{{v_name.id}} = val
    end
  {% else %}
    @{{name_or_decl.id}} : {{type.id}}? = nil
    def {{name_or_decl.id}} : {{type.id}}
      if (cached = @{{name_or_decl.id}})
        cached.check_alive!
        return cached
      end
      {% if unique_name %}
        u_name = ({{unique_name}}).to_s.starts_with?('%') ? ({{unique_name}}).to_s : "%#{{{unique_name}}}"
        found = get_node_as(u_name, {{type.id}})
      {% else %}
        found = get_node_as("%" + {{name_or_decl.id.stringify.camelcase}}, {{type.id}})
      {% end %}
      @{{name_or_decl.id}} = found
      found
    end

    def {{name_or_decl.id}}=(val : {{type.id}}?)
      @{{name_or_decl.id}} = val
    end
  {% end %}
end

# Declares a safe, lazy-cached node property that returns nil if missing or type mismatch.
#
# Examples:
# ```
# onready? player, PlayerController, "Player"
# onready? hud, GameHUD, "HUD"
# ```
macro onready?(name, type, path = nil)
  @{{name.id}} : {{type.id}}? = nil
  def {{name.id}} : {{type.id}}?
    if (cached = @{{name.id}})
      if cached.alive?
        return cached
      else
        @{{name.id}} = nil
      end
    end
    {% if path %}
      found = get_node_as?({{path}}, {{type.id}})
    {% else %}
      found = get_node_as?({{name.id.stringify.camelcase}}, {{type.id}})
    {% end %}
    @{{name.id}} = found
    found
  end

  def {{name.id}}=(val : {{type.id}}?)
    @{{name.id}} = val
  end
end

# Declares a safe, lazy-cached Scene Unique Node property that returns nil if missing.
#
# Examples:
# ```
# unique_node? health_bar, ProgressBar, "HealthBar"
# ```
macro unique_node?(name, type, unique_name = nil)
  @{{name.id}} : {{type.id}}? = nil
  def {{name.id}} : {{type.id}}?
    if (cached = @{{name.id}})
      if cached.alive?
        return cached
      else
        @{{name.id}} = nil
      end
    end
    {% if unique_name %}
      found = get_node_as?(({{unique_name}}).to_s.starts_with?('%') ? ({{unique_name}}).to_s : "%#{{{unique_name}}}", {{type.id}})
    {% else %}
      found = get_node_as?("%" + {{name.id.stringify.camelcase}}, {{type.id}})
    {% end %}
    @{{name.id}} = found
    found
  end

  def {{name.id}}=(val : {{type.id}}?)
    @{{name.id}} = val
  end
end

# Immediately retrieves a child node from the current node's scene hierarchy.
#
# Provides GDScript `$` parity with static type casting.
#
# ### Supported Patterns:
# 1. Type-inferred: `node!(Sprite2D)` -> looks up `"Sprite2D"` and casts to `Sprite2D`
# 2. Path with Type: `node!("Visuals/Sprite2D", Sprite2D)` -> resolves path and casts to `Sprite2D`
# 3. Path string: `node!("Visuals/Sprite2D")` -> resolves path as untyped `Godot::Node`
#
# Raises `Godot::NodeNotFoundError` if the node is not found or fails type casting.
#
# ### Example:
# ```crystal
# def _ready : Void
#   sprite = node!(Sprite2D)
#   camera = node!("Pivot/Camera3D", Camera3D)
# end
# ```
macro node!(path, type = nil)
  {% if type %}
    get_node_as({{path}}, {{type}})
  {% elsif path.is_a?(Path) %}
    get_node_as({{path.names.last.stringify}}, {{path}})
  {% else %}
    get_node({{path}})
  {% end %}
end

# Safely retrieves a child node from the current node's scene hierarchy, returning `nil` if not found.
#
# ### Supported Patterns:
# 1. Type-inferred: `node?(Sprite2D)` -> looks up `"Sprite2D"`, returns `Sprite2D?`
# 2. Path with Type: `node?("Visuals/Sprite2D", Sprite2D)` -> returns `Sprite2D?`
# 3. Path string: `node?("Visuals/Sprite2D")` -> returns `Godot::Node?`
macro node?(path, type = nil)
  {% if type %}
    get_node_as?({{path}}, {{type}})
  {% elsif path.is_a?(Path) %}
    get_node_as?({{path.names.last.stringify}}, {{path}})
  {% else %}
    get_node?({{path}})
  {% end %}
end

# Ultra-short alias for `node!(path, type)`.
macro n!(path, type = nil)
  node!({{path}}, {{type}})
end

# Ultra-short alias for `node?(path, type)`.
macro n?(path, type = nil)
  node?({{path}}, {{type}})
end

# Immediately retrieves a Scene Unique Node (Godot 4 `%Node` syntax).
#
# Automatically prepends `%` to the identifier if not already present.
#
# ### Supported Patterns:
# 1. Type-inferred: `unique!(ProgressBar)` -> looks up `"%ProgressBar"` as `ProgressBar`
# 2. Name with Type: `unique!("HealthBar", ProgressBar)` -> looks up `"%HealthBar"` as `ProgressBar`
# 3. Name string: `unique!("HealthBar")` -> looks up `"%HealthBar"` as `Godot::Node`
#
# Raises `Godot::NodeNotFoundError` if the unique node does not exist.
macro unique!(name, type = nil)
  {% if type %}
    get_node_as(({{name}}).to_s.starts_with?('%') ? ({{name}}).to_s : "%#{{{name}}}", {{type}})
  {% elsif name.is_a?(Path) %}
    get_node_as("%" + {{name.names.last.stringify}}, {{name}})
  {% else %}
    get_node(({{name}}).to_s.starts_with?('%') ? ({{name}}).to_s : "%#{{{name}}}")
  {% end %}
end

# Safely retrieves a Scene Unique Node (Godot 4 `%Node` syntax), returning `nil` if not found.
macro unique?(name, type = nil)
  {% if type %}
    get_node_as?(({{name}}).to_s.starts_with?('%') ? ({{name}}).to_s : "%#{{{name}}}", {{type}})
  {% elsif name.is_a?(Path) %}
    get_node_as?("%" + {{name.names.last.stringify}}, {{name}})
  {% else %}
    get_node?(({{name}}).to_s.starts_with?('%') ? ({{name}}).to_s : "%#{{{name}}}")
  {% end %}
end

# Ultra-short alias for `unique!(name, type)`.
macro u!(name, type = nil)
  unique!({{name}}, {{type}})
end

# Ultra-short alias for `unique?(name, type)`.
macro u?(name, type = nil)
  unique?({{name}}, {{type}})
end

# Declaratively assigns the node to one or more scene tree groups upon `_ready`.
#
# The `node` macro extracts all `group` statements and registers them automatically
# in Godot's SceneTree when the node enters the tree.
#
# ### Example:
# ```crystal
# node Player < CharacterBody3D do
#   group "players", "damageable", "interactable"
# end
# ```
macro group(*group_names)
  # Declarative registration is extracted by the `node` macro
end

# Groups exported properties under a common folding group in the Godot inspector.
#
# May be used standalone or as a block scoping exported properties.
#
# ### Example:
# ```crystal
# node Vehicle < CharacterBody3D do
#   export_group "Engine", prefix: "engine_" do
#     @[Export]
#     property engine_power : Float32 = 250.0_f32
#
#     @[Export]
#     property engine_torque : Float32 = 400.0_f32
#   end
# end
# ```
macro export_group(name, prefix = "")
  # Declarative registration is extracted by the `node` / `resource` macro
end

macro export_group(name, prefix = "", &block)
  {{ yield }}
end

# Subgroups exported properties under the current inspector group.
#
# May be used standalone or as a block scoping exported properties.
#
# ### Example:
# ```crystal
# node Character < CharacterBody3D do
#   export_group "Movement" do
#     export_subgroup "Advanced", prefix: "adv_" do
#       @[Export]
#       property adv_friction : Float32 = 0.1_f32
#     end
#   end
# end
# ```
macro export_subgroup(name, prefix = "")
  # Declarative registration is extracted by the `node` / `resource` macro
end

macro export_subgroup(name, prefix = "", &block)
  {{ yield }}
end

# Categorizes top-level inspector sections in Godot.
#
# May be used standalone or as a block scoping exported properties.
#
# ### Example:
# ```crystal
# node Boss < CharacterBody3D do
#   export_category "Combat Stats" do
#     @[Export]
#     property health : Int32 = 1000
#
#     @[Export]
#     property defense : Int32 = 50
#   end
# end
# ```
macro export_category(name)
  # Declarative registration is extracted by the `node` / `resource` macro
end

macro export_category(name, &block)
  {{ yield }}
end

# Cooperatively awaits a signal, timer, or duration without blocking the engine main thread.
#
# ### Rationale & Execution Model:
# In Godot, asynchronous gameplay events (animations, dialogue timers, death signals)
# must not block the engine's main loop (`_process` / `_physics_process`). Standard Crystal
# `sleep` suspends the entire OS thread and hangs the engine.
#
# `await` suspends only the calling Crystal fiber, polling Godot cooperatively across frame steps
# while ensuring:
# 1. Zero main thread stalling.
# 2. Dead-pointer protection: if the emitting node is freed while waiting, raises `Godot::DisposedObjectError`.
# 3. Optional timeout support with automated timeout cancellation.
#
# ### Supported Calling Forms:
# ```crystal
# # 1. First-class bound signal:
# await(enemy.died)
# await(enemy.died, timeout_sec: 5.0)
#
# # 2. Dynamic target and string signal name:
# await(boss, "phase_transition")
# await(boss, "phase_transition", timeout_sec: 10.0)
#
# # 3. SceneTree timer:
# await(get_tree.create_timer(1.5).timeout)
#
# # 4. Numeric delay in seconds:
# await(1.5)
# await(2.seconds)
# ```
macro await(target, signal_name = nil, timeout_sec = nil)
  {% if signal_name != nil && timeout_sec != nil %}
    ::Godot.await({{target}}, {{signal_name}}, timeout_sec: {{timeout_sec}})
  {% elsif signal_name != nil %}
    ::Godot.await({{target}}, {{signal_name}})
  {% elsif timeout_sec != nil %}
    ::Godot.await({{target}}, timeout_sec: {{timeout_sec}})
  {% else %}
    ::Godot.await({{target}})
  {% end %}
end

# Cooperatively yields the calling fiber while `condition` evaluates to truthy.
#
# Uses `Fiber.yield` between evaluation cycles. Supports an optional `timeout_sec`
# parameter which raises `Godot::TimeoutError` if exceeded.
#
# ### Example:
# ```crystal
# await_while(tween.is_running, timeout_sec: 3.0)
# ```
macro await_while(condition, timeout_sec = nil)
  %timeout = {{timeout_sec}}
  %start = ::Time.instant
  while {{condition}}
    Fiber.yield
    if %timeout && (::Time.instant - %start).total_seconds > %timeout
      raise Godot::TimeoutError.new("Timed out after #{%timeout}s awaiting condition to become false")
    end
  end
end

macro await_while(condition, timeout_sec, &block)
  %timeout = {{timeout_sec}}
  %start = ::Time.instant
  while {{condition}}
    {{block.body}}
    Fiber.yield
    if %timeout && (::Time.instant - %start).total_seconds > %timeout
      raise Godot::TimeoutError.new("Timed out after #{%timeout}s awaiting condition to become false")
    end
  end
end

# Cooperatively yields the calling fiber until `condition` evaluates to truthy.
#
# Uses `Fiber.yield` between evaluation cycles. Supports an optional `timeout_sec`
# parameter which raises `Godot::TimeoutError` if exceeded.
#
# ### Example:
# ```crystal
# await_until(character.on_floor?, timeout_sec: 5.0)
# ```
macro await_until(condition, timeout_sec = nil)
  %timeout = {{timeout_sec}}
  %start = ::Time.instant
  until {{condition}}
    Fiber.yield
    if %timeout && (::Time.instant - %start).total_seconds > %timeout
      raise Godot::TimeoutError.new("Timed out after #{%timeout}s awaiting condition to become true")
    end
  end
end

macro await_until(condition, timeout_sec, &block)
  %timeout = {{timeout_sec}}
  %start = ::Time.instant
  until {{condition}}
    {{block.body}}
    Fiber.yield
    if %timeout && (::Time.instant - %start).total_seconds > %timeout
      raise Godot::TimeoutError.new("Timed out after #{%timeout}s awaiting condition to become true")
    end
  end
end
