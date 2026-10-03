# Declares a custom Godot signal with first-class typed signal accessors.
#
# ```
# class Player < Godot::CharacterBody3D
#   signal health_changed(new_health : Int32, max_health : Int32)
#   signal died
#
#   def take_damage(amount : Int32)
#     health_changed.emit(50, 100)
#     died.emit if amount >= 100
#   end
# end
# ```
macro signal(name_or_decl, *extra_types)
  {% if name_or_decl.is_a?(Call) %}
    {% sig_name = name_or_decl.name %}
    {% sig_args = name_or_decl.args %}
    {% param_types = [] of Nil %}
    {% for arg in sig_args %}
      {% if arg.is_a?(TypeDeclaration) %}
        {% param_types << arg.type %}
      {% else %}
        {% param_types << "String".id %}
      {% end %}
    {% end %}
  {% else %}
    {% sig_name = name_or_decl %}
    {% param_types = extra_types %}
  {% end %}

  # Bound signal accessor for idiomatic `node.{{sig_name.id}}.emit(...)`, `await(node.{{sig_name.id}})`, or `on node.{{sig_name.id}} { ... }`
  {% if param_types.size > 0 %}
    def {{sig_name.id}} : ::Godot::TypedSignal({{param_types.splat}})
      ::Godot::TypedSignal({{param_types.splat}}).new(self, "{{sig_name.id}}")
    end
  {% else %}
    def {{sig_name.id}} : ::Godot::TypedSignal()
      ::Godot::TypedSignal().new(self, "{{sig_name.id}}")
    end
  {% end %}

  # Identity setter enabling compound operator sugar (`node.{{sig_name.id}} += ->handler`, `node.{{sig_name.id}} -= ->handler`)
  def {{sig_name.id}}=(val : ::Godot::BoundSignal) : ::Godot::BoundSignal
    val
  end
end

# Type-safe signal emitter macro.
#
# Emits signals directly via `TypedSignal#emit` or `emit_signal`.
#
# ### Examples:
# ```crystal
# emit(player.health_changed, 50, 100) # Expands to player.health_changed.emit(50, 100)
# emit(player.renamed)                  # Expands to player.renamed.emit
# emit(health_changed, 50, 100)         # Inside Player: expands to health_changed.emit(50, 100)
# emit(sig, 50, 100)                    # Signal variable: expands to sig.emit(50, 100)
# ```
macro emit(signal_expr, *args)
  {% if signal_expr.is_a?(Call) %}
    {{signal_expr}}.emit({{args.splat}})
  {% elsif args.size > 0 && (args[0].is_a?(SymbolLiteral) || args[0].is_a?(StringLiteral)) %}
    {{signal_expr}}.emit_signal(({{args[0]}}).to_s, {% if args.size > 1 %}{{args[1..-1].splat}}{% end %})
  {% else %}
    {{signal_expr}}.emit({{args.splat}})
  {% end %}
end

# Expressive signal connection macro
#
# Supports:
# 1. First-class signal: `on button.pressed { do_something }`
# 2. Positional type filter: `on body_entered, Player { |p| p.collect }`
# 3. Multi-argument type filters: `on item_equipped, Player, Sword { |p, s| ... }`
# 4. Any wildcard filter: `on damage_received, Player, Any { |p, info| ... }`
# 5. One-shot execution: `on boss.died, Player, once: true { |p| ... }`
# 6. Target and signal string: `on enemy, "died" { |bounty| add_score(bounty) }`
macro on(sig_or_target, *args, once = false, &block)
  {% if once %}
    {% if args.size > 0 && (args[0].is_a?(StringLiteral) || args[0].is_a?(SymbolLiteral)) %}
      ::Godot::BoundSignal.new({{sig_or_target}}, ({{args[0]}}).to_s).once({% if args.size > 1 %}{{args[1..-1].splat}}{% end %}) {{block}}
    {% elsif args.size > 0 %}
      {{sig_or_target}}.once({{args.splat}}) {{block}}
    {% else %}
      {{sig_or_target}}.once {{block}}
    {% end %}
  {% else %}
    {% if args.size > 0 && (args[0].is_a?(StringLiteral) || args[0].is_a?(SymbolLiteral)) %}
      ::Godot::BoundSignal.new({{sig_or_target}}, ({{args[0]}}).to_s).connect({% if args.size > 1 %}{{args[1..-1].splat}}{% end %}) {{block}}
    {% elsif args.size > 0 %}
      {{sig_or_target}}.connect({{args.splat}}) {{block}}
    {% else %}
      {{sig_or_target}}.connect {{block}}
    {% end %}
  {% end %}
end
