# =============================================================================
# Lapis GDScript Extras: Node Context Queries & Unary Tilde DSL
# =============================================================================
# Unary tilde (~) operator syntactic sugar mimicking GDScript's node lookup
# and scene interrogation patterns within an active `NodeContext`.

class String
  # Unary tilde operator on `String`: `~"NodeName"`, `~"Visuals/Sprite2D"`, or `~"%HealthBar"`.
  #
  # Resolves the path against the active `NodeContext.current`.
  #
  # ### Example:
  # ```crystal
  # def _ready : Void
  #   sprite = ~"Sprite2D"
  #   hud = ~"../HUD"
  #   unique = ~"%HealthBar"
  # end
  # ```
  def ~ : Godot::Node
    ::Godot::NodeContext.resolve_active_node(self)
  end
end

struct Godot::NodePath
  # Unary tilde operator on `Godot::NodePath`: `~(node_path!("MyNode"))`.
  #
  # Resolves the path against the active `NodeContext.current`.
  #
  # ### Example:
  # ```crystal
  # path = Godot::NodePath.new("Visuals/Sprite2D")
  # sprite = ~path
  # ```
  def ~ : Godot::Node
    ::Godot::NodeContext.resolve_active_node(self.to_s)
  end
end

class Class
  # Unary tilde operator on `Class` types: `~Sprite2D` or `~Sprite2D?`.
  #
  # Provides typed `get_node_or_null` parity, returning typed `T?` or `nil` if not found.
  #
  # ### Examples:
  # ```crystal
  # def _ready : Void
  #   if anim = ~AnimationPlayer?
  #     anim.play("idle")
  #   end
  # end
  # ```
  def ~
    ::Godot::NodeContext.resolve_active_node_or_nil(self)
  end
end

class Regex
  # Unary tilde operator on `Regex`: `~/pattern/`.
  #
  # Searches the active node context for the first child or descendant whose name matches the regex.
  # Returns `Godot::Node?` (or `nil` if no matching node is found).
  #
  # ### Example:
  # ```crystal
  # def _ready : Void
  #   if boss = ~/boss_\d+/i
  #     boss.modulate = Godot::Color.new(1.0, 0.0, 0.0)
  #   end
  # end
  # ```
  def ~ : Godot::Node?
    ::Godot::NodeContext.resolve_active_regex(self)
  end
end

class Godot::Object
  # Instance unary ~ returns self, allowing ~self or nested unary chaining
  def ~ : self
    self
  end

  # Class unary ~ returns typed instance looked up from active NodeContext (by name first, then searching children)
  def self.~ : self
    ::Godot::NodeContext.resolve_active_node_as(self)
  end
end

struct Tuple
  # Unary tilde operator on 2-element Tuples: `~{"$MyNode", MyNodeType}` or `~{"$MyNode", MyNodeType?}`.
  #
  # Automatically strips a leading `$` from GDScript-style path strings, looks up the node
  # against the active `NodeContext.current`, and casts to the specified static type.
  #
  # When given a nilable type (e.g. `MyNodeType?`), returns `nil` safely if the node is not found.
  #
  # ### Examples:
  # ```crystal
  # def _ready : Void
  #   sprite = ~{"$Sprite2D", Sprite2D}
  #   camera = ~{"Camera3D", Camera3D}
  #   unique = ~{"$%HealthBar", ProgressBar}
  #   opt_hud = ~{"$HUD", Control?}
  # end
  # ```
  def ~
    {% begin %}
      {% if T.size == 2 && (T[0] <= String || T[0] <= Symbol || T[0] <= Godot::NodePath) %}
        raw_path = self[0].to_s
        clean_path = raw_path.starts_with?('$') ? raw_path[1..] : raw_path
        ::Godot::NodeContext.resolve_active_node_path_as(clean_path, self[1])
      {% else %}
        {% raise "Unary ~ is only defined for Tuple(String | Symbol | NodePath, T.class); received #{self.class}" %}
      {% end %}
    {% end %}
  end
end

# Global query helper returning all nodes matching the regex under the active node context.
#
# ### Example:
# ```crystal
# nodes(~/coin_\d+/).each(&.queue_free)
# ```
def nodes(regex : Regex) : ::Array(Godot::Node)
  ::Godot::NodeContext.resolve_active_regex_all(regex)
end
