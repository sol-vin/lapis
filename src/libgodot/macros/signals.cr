# Declares a custom Godot signal and generates a type-safe `emit_<signal_name>` helper method.
#
# ```
# class Player < Godot::CharacterBody3D
#   signal health_changed(new_health : Int32, max_health : Int32)
#   signal died
#
#   def take_damage(amount : Int32)
#     emit_health_changed(50, 100)
#     emit_died if amount >= 100
#   end
# end
# ```
macro signal(name_or_decl, *extra_types)
  {% if name_or_decl.is_a?(Call) %}
    {% sig_name = name_or_decl.name %}
    {% sig_args = name_or_decl.args %}
    {% param_types = [] of Nil %}
    {% emit_args = [] of Nil %}
    {% emit_pass_args = [] of Nil %}
    {% for arg in sig_args %}
      {% if arg.is_a?(TypeDeclaration) %}
        {% param_types << arg.type %}
        {% emit_args << "#{arg.var} : #{arg.type}".id %}
        {% emit_pass_args << arg.var %}
      {% else %}
        {% param_types << "String".id %}
        {% emit_args << arg %}
        {% emit_pass_args << arg %}
      {% end %}
    {% end %}
  {% else %}
    {% sig_name = name_or_decl %}
    {% param_types = extra_types %}
    {% emit_args = [] of Nil %}
    {% emit_pass_args = [] of Nil %}
    {% for type, idx in param_types %}
      {% emit_args << "arg#{idx} : #{type}".id %}
      {% emit_pass_args << "arg#{idx}".id %}
    {% end %}
  {% end %}

  # Bound signal accessor for idiomatic `await(node.{{sig_name.id}})` or `node.{{sig_name.id}}.connect { ... }`
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

  # Type-safe emission helper
  def emit_{{sig_name.id}}({{emit_args.splat}}) : Void
    emit_signal("{{sig_name.id}}"{% if emit_pass_args.size > 0 %}, {{emit_pass_args.splat}}{% end %})
  end

  {% if param_types.size == 0 %}
    # Type-safe signal listener
    def on_{{sig_name.id}}(&block : -> Void) : ::Godot::SignalSubscription
      {{sig_name.id}}.connect(&block)
    end

    # One-shot type-safe signal listener that automatically disconnects after firing once
    def on_{{sig_name.id}}_once(&block : -> Void) : ::Godot::SignalSubscription
      {{sig_name.id}}.connect(flags: ::Godot::ConnectFlags::OneShot, &block)
    end
  {% else %}
    # Type-safe signal listener with automatically converted typed parameters
    def on_{{sig_name.id}}(&block : ({{param_types.splat}}) -> Void) : ::Godot::SignalSubscription
      {{sig_name.id}}.connect(&block)
    end

    # One-shot type-safe signal listener with automatically converted typed parameters
    def on_{{sig_name.id}}_once(&block : ({{param_types.splat}}) -> Void) : ::Godot::SignalSubscription
      {{sig_name.id}}.connect(flags: ::Godot::ConnectFlags::OneShot, &block)
    end
  {% end %}
end

# Type-safe signal emitter macro.
#
# Emits signals with compile-time type verification, matching the parameter
# types and argument counts declared by the signal.
#
# ### Examples:
# ```crystal
# emit(player.health_changed, 50, 100) # Expands to player.emit_health_changed(50, 100)
# emit(player.renamed)                  # Expands to player.emit_renamed
# emit(health_changed, 50, 100)         # Inside Player: expands to emit_health_changed(50, 100)
# emit(sig, 50, 100)                    # Signal variable: expands to sig.emit(50, 100)
# ```
macro emit(signal_expr, *args)
  {% if signal_expr.is_a?(Call) %}
    {% if signal_expr.receiver %}
      {{signal_expr.receiver}}.emit_{{signal_expr.name}}({{args.splat}})
    {% else %}
      emit_{{signal_expr.name}}({{args.splat}})
    {% end %}
  {% elsif args.size > 0 && (args[0].is_a?(SymbolLiteral) || args[0].is_a?(StringLiteral)) %}
    {{signal_expr}}.emit_{{args[0].id}}({% if args.size > 1 %}{{args[1..-1].splat}}{% end %})
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

