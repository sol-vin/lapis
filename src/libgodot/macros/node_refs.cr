# Declares an `@onready` node property initialized from the scene tree during `_ready`.
macro onready(decl)
  {% if decl.is_a?(Assign) %}
    property {{decl.target}}? = nil
  {% elsif decl.is_a?(TypeDeclaration) %}
    property {{decl.var}} : {{decl.type}}? = nil
  {% end %}
end

# Declares a `node_ref` property initialized from the scene tree during `_ready`.
macro node_ref(decl)
  onready({{decl}})
end

# Declares a `unique_node_ref` property initialized from the scene tree during `_ready`.
macro unique_node_ref(decl)
  onready({{decl}})
end

# Creates a compile-time verified Godot::NodePath
macro node_path!(path)
  ::Godot::NodePath.new({{path}})
end

# Declares a lazy-cached node property matching Godot's `@onready` pattern.
#
# Supports:
# 1. Auto-inferred path: `onready sprite_2d, Sprite2D` (fetches "Sprite2D")
# 2. Scene Unique Node: `onready camera, Camera2D, "%MainCamera"`
# 3. Explicit path: `onready sprite, Sprite2D, "Visuals/Sprite2D"`
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

# Compact node retrieval macro (GDScript $ analog).
# Supports:
# 1. Type-inferred: `node!(Sprite2D)` -> `get_node_as("Sprite2D", Sprite2D)`
# 2. Path + Type: `node!("Visuals/Sprite2D", Sprite2D)` -> `get_node_as("Visuals/Sprite2D", Sprite2D)`
# 3. Path string: `node!("Visuals/Sprite2D")` -> `get_node("Visuals/Sprite2D")`
macro node!(path, type = nil)
  {% if type %}
    get_node_as({{path}}, {{type}})
  {% elsif path.is_a?(Path) %}
    get_node_as({{path.names.last.stringify}}, {{path}})
  {% else %}
    get_node({{path}})
  {% end %}
end

# Safe compact node retrieval macro (returns nil if not found).
macro node?(path, type = nil)
  {% if type %}
    get_node_as?({{path}}, {{type}})
  {% elsif path.is_a?(Path) %}
    get_node_as?({{path.names.last.stringify}}, {{path}})
  {% else %}
    get_node?({{path}})
  {% end %}
end

# Ultra-short aliases for node! and node?
macro n!(path, type = nil)
  node!({{path}}, {{type}})
end

macro n?(path, type = nil)
  node?({{path}}, {{type}})
end

# Compact Scene Unique Node retrieval macro (GDScript % analog).
# Supports:
# 1. Type-inferred: `unique!(ProgressBar)` -> `get_node_as("%ProgressBar", ProgressBar)`
# 2. Name + Type: `unique!("HealthBar", ProgressBar)` -> `get_node_as("%HealthBar", ProgressBar)`
# 3. Name string: `unique!("HealthBar")` -> `get_node("%HealthBar")`
macro unique!(name, type = nil)
  {% if type %}
    get_node_as(({{name}}).to_s.starts_with?('%') ? ({{name}}).to_s : "%#{{{name}}}", {{type}})
  {% elsif name.is_a?(Path) %}
    get_node_as("%" + {{name.names.last.stringify}}, {{name}})
  {% else %}
    get_node(({{name}}).to_s.starts_with?('%') ? ({{name}}).to_s : "%#{{{name}}}")
  {% end %}
end

# Safe compact Scene Unique Node retrieval macro (returns nil if not found).
macro unique?(name, type = nil)
  {% if type %}
    get_node_as?(({{name}}).to_s.starts_with?('%') ? ({{name}}).to_s : "%#{{{name}}}", {{type}})
  {% elsif name.is_a?(Path) %}
    get_node_as?("%" + {{name.names.last.stringify}}, {{name}})
  {% else %}
    get_node?(({{name}}).to_s.starts_with?('%') ? ({{name}}).to_s : "%#{{{name}}}")
  {% end %}
end

# Ultra-short aliases for unique! and unique?
macro u!(name, type = nil)
  unique!({{name}}, {{type}})
end

macro u?(name, type = nil)
  unique?({{name}}, {{type}})
end

# Declaratively assigns the node to one or more scene tree groups upon `_ready`.
#
# ```
# node Player < CharacterBody3D do
#   group "players", "flammable"
# end
# ```
macro group(*group_names)
  # Declarative registration is extracted by the `node` macro
end

# Groups exported properties in the Godot inspector.
#
# May be used standalone or as a block scoping exported properties:
# ```
# export_group "Movement", prefix: "move_" do
#   @[Export]
#   property move_speed : Float32 = 5.0_f32
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
# May be used standalone or as a block scoping exported properties:
# ```
# export_subgroup "Advanced", prefix: "adv_" do
#   @[Export]
#   property adv_friction : Float32 = 0.1_f32
# end
# ```
macro export_subgroup(name, prefix = "")
  # Declarative registration is extracted by the `node` / `resource` macro
end

macro export_subgroup(name, prefix = "", &block)
  {{ yield }}
end

# Categories group top-level inspector sections in Godot.
#
# May be used standalone or as a block scoping exported properties:
# ```
# export_category "Combat" do
#   @[Export]
#   property health : Int32 = 100
# end
# ```
macro export_category(name)
  # Declarative registration is extracted by the `node` / `resource` macro
end

macro export_category(name, &block)
  {{ yield }}
end

# Top-level await macro for intuitive GDScript-like calling syntax
# Usage:
#   await(enemy.died)
#   await(enemy.died, timeout_sec: 2.0)
#   await(enemy, "died")
#   await(enemy, "died", timeout_sec: 2.0)
#   await(timer.timeout)
#   await(timer)
#   await(1.5)
#   await(2.seconds)
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

# Cooperatively yields the current fiber while the condition evaluates to truthy.
# Usage:
#   await_while(tween.is_running)
#   await_while(character.moving?, timeout_sec: 5.0)
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

# Cooperatively yields the current fiber until the condition evaluates to truthy.
# Usage:
#   await_until(character.on_floor?)
#   await_until(resource.loaded?, timeout_sec: 10.0)
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
