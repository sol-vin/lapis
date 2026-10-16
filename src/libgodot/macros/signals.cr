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
  @_sig_hash_{{sig_name.id}} : UInt64 = 0_u64

  @[ZeroAllocation]
  @[HotPath]
  @[AlwaysInline]
  def {{sig_name.id}}_signal_hash : UInt64
    h = @_sig_hash_{{sig_name.id}}
    if h != 0_u64
      h
    else
      computed = ::Lapis::Core::StaticSignalTable.fnv1a_64("{{sig_name.id}}")
      @_sig_hash_{{sig_name.id}} = computed
      computed
    end
  end

  {% if param_types.size > 0 %}
    @_typed_sig_{{sig_name.id}} : ::Godot::TypedSignal({{param_types.splat}})? = nil

    @[ZeroAllocation]
    @[HotPath]
    @[AlwaysInline]
    def {{sig_name.id}} : ::Godot::TypedSignal({{param_types.splat}})
      if existing = @_typed_sig_{{sig_name.id}}
        existing
      else
        init_typed_sig_{{sig_name.id}}
      end
    end

    private def init_typed_sig_{{sig_name.id}} : ::Godot::TypedSignal({{param_types.splat}})
      sig = ::Godot::TypedSignal({{param_types.splat}}).new(self, "{{sig_name.id}}")
      @_typed_sig_{{sig_name.id}} = sig
      sig
    end

    @[ZeroAllocation]
    @[HotPath]
    @[AlwaysInline]
    def {{sig_name.id}}_slot : ::Lapis::Core::StaticSignalSlot({{param_types.splat}})
      ::Lapis::Core::StaticSignalSlot({{param_types.splat}}).from_table(
        ::Lapis::Core::StaticSignalTable.global,
        signal_target_id,
        "{{sig_name.id}}",
        {{sig_name.id}}_signal_hash
      )
    end

    @[AlwaysInline]
    def bind_{{sig_name.id}}(callback : Proc({{param_types.splat}}, R), once : Bool = false) : UInt64 forall R
      {{sig_name.id}}_slot.bind(callback, once: once)
    end

    @[AlwaysInline]
    def bind_{{sig_name.id}}(once : Bool = false, &block : ({{param_types.splat}}) -> Void) : UInt64
      {{sig_name.id}}_slot.bind(block, once: once)
    end

    @[AlwaysInline]
    def unbind_{{sig_name.id}}(token : UInt64) : Bool
      {{sig_name.id}}_slot.unbind(token)
    end

    @[AlwaysInline]
    def unbind_{{sig_name.id}}(callback : Proc({{param_types.splat}}, R)) : Bool forall R
      {{sig_name.id}}_slot.unbind(callback)
    end

    @[ZeroAllocation]
    @[HotPath]
    @[AlwaysInline]
    def emit_{{sig_name.id}}(*args : *T) : Void forall T
      if existing = @_typed_sig_{{sig_name.id}}
        existing.emit(*args)
      else
        check_alive!
        ::Godot::SignalSpy.record(self.class.name, "{{sig_name.id}}", {{ param_types.size }})
        tid = signal_target_id
        ::Lapis::Core::StaticSignalTable.global.emit_by_hash(tid, {{sig_name.id}}_signal_hash, *args)
        if ::Godot.has_untyped_signal_subscribers?(tid, "{{sig_name.id}}")
          {{sig_name.id}}.emit(*args)
        elsif !@pointer.null? && ::Godot::Bridge.available?
          ::Godot.in_typed_emit = true
          ::Godot::Bridge.emit_signal(@pointer, "{{sig_name.id}}", *args)
          ::Godot.in_typed_emit = false
        end
      end
    end
  {% else %}
    @_typed_sig_{{sig_name.id}} : ::Godot::TypedSignal()? = nil

    @[ZeroAllocation]
    @[HotPath]
    @[AlwaysInline]
    def {{sig_name.id}} : ::Godot::TypedSignal()
      if existing = @_typed_sig_{{sig_name.id}}
        existing
      else
        init_typed_sig_{{sig_name.id}}
      end
    end

    private def init_typed_sig_{{sig_name.id}} : ::Godot::TypedSignal()
      sig = ::Godot::TypedSignal().new(self, "{{sig_name.id}}")
      @_typed_sig_{{sig_name.id}} = sig
      sig
    end

    @[ZeroAllocation]
    @[HotPath]
    @[AlwaysInline]
    def {{sig_name.id}}_slot : ::Lapis::Core::StaticSignalSlot()
      ::Lapis::Core::StaticSignalSlot().from_table(
        ::Lapis::Core::StaticSignalTable.global,
        signal_target_id,
        "{{sig_name.id}}",
        {{sig_name.id}}_signal_hash
      )
    end

    @[AlwaysInline]
    def bind_{{sig_name.id}}(callback : Proc(R), once : Bool = false) : UInt64 forall R
      {{sig_name.id}}_slot.bind(callback, once: once)
    end

    @[AlwaysInline]
    def bind_{{sig_name.id}}(once : Bool = false, &block : -> Void) : UInt64
      {{sig_name.id}}_slot.bind(block, once: once)
    end

    @[AlwaysInline]
    def unbind_{{sig_name.id}}(token : UInt64) : Bool
      {{sig_name.id}}_slot.unbind(token)
    end

    @[AlwaysInline]
    def unbind_{{sig_name.id}}(callback : Proc(R)) : Bool forall R
      {{sig_name.id}}_slot.unbind(callback)
    end

    @[ZeroAllocation]
    @[HotPath]
    @[AlwaysInline]
    def emit_{{sig_name.id}} : Void
      if existing = @_typed_sig_{{sig_name.id}}
        existing.emit
      else
        check_alive!
        ::Godot::SignalSpy.record(self.class.name, "{{sig_name.id}}", 0)
        tid = signal_target_id
        ::Lapis::Core::StaticSignalTable.global.emit_by_hash(tid, {{sig_name.id}}_signal_hash)
        if ::Godot.has_untyped_signal_subscribers?(tid, "{{sig_name.id}}")
          {{sig_name.id}}.emit
        elsif !@pointer.null? && ::Godot::Bridge.available?
          ::Godot.in_typed_emit = true
          ::Godot::Bridge.emit_signal(@pointer, "{{sig_name.id}}")
          ::Godot.in_typed_emit = false
        end
      end
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

# Zero-allocation static signal connection macro binding compile-time typed procs
# or blocks directly to `StaticSignalTable` slots.
#
# Can be used both:
# 1. Declaratively at class body scope inside `node` or `gmodule`:
#    ```crystal
#    node Player < CharacterBody3D do
#      signal health_changed(new_health : Int32, max_health : Int32)
#      signal died
#
#      on_signal health_changed, ->on_health_changed(Int32, Int32)
#      on_signal :died, ->on_died, once: true
#
#      def on_health_changed(hp : Int32, max : Int32) : Void
#      end
#
#      def on_died : Void
#      end
#    end
#    ```
# 2. Imperatively inside methods or scripts:
#    ```crystal
#    on_signal player.health_changed, ->(hp : Int32, max : Int32) { ... }
#    on_signal player.health_changed_slot, handler_proc
#    on_signal player, :health_changed, handler_proc, once: true
#    on_signal player.health_changed do |hp, max|
#      ...
#    end
#    ```
macro on_signal(sig_or_target, *args, once = false, &block)
  {% if @def == nil && (@type.annotation(::GodotClass) || @type.annotation(::GodotModule)) %}
    # Declarative class-body signal binding is extracted and bound by the `node` / `gmodule` macro.
  {% elsif block && !block.body.is_a?(Nop) %}
    {% if sig_or_target.is_a?(SymbolLiteral) || sig_or_target.is_a?(StringLiteral) %}
      {% if args.size > 0 %}
        on(self.{{sig_or_target.id}}, {{args.splat}}, once: {{once}}) {{block}}
      {% else %}
        self.{{sig_or_target.id}}.bind(once: {{once}}) {{block}}
      {% end %}
    {% elsif args.size > 0 && (args[0].is_a?(StringLiteral) || args[0].is_a?(SymbolLiteral)) %}
      {% if args.size > 1 %}
        ::Lapis::Core::StaticSignalTable.global.connect(({{sig_or_target}}).signal_target_id, ({{args[0]}}).to_s, {{args[1..-1].splat}}, once: {{once}}) {{block}}
      {% else %}
        ::Lapis::Core::StaticSignalTable.global.connect(({{sig_or_target}}).signal_target_id, ({{args[0]}}).to_s, once: {{once}}) {{block}}
      {% end %}
    {% elsif args.size > 0 %}
      on({{sig_or_target}}, {{args.splat}}, once: {{once}}) {{block}}
    {% else %}
      ({{sig_or_target}}).bind(once: {{once}}) {{block}}
    {% end %}
  {% elsif args.size == 1 %}
    {% proc_arg = args[0] %}
    {% if proc_arg.is_a?(ProcPointer) && !proc_arg.obj && (@type < ::Godot::Object) %}
      {% resolved_proc = proc_arg.args.size > 0 ? "->self.#{proc_arg.name.id}(#{proc_arg.args.splat})".id : "->self.#{proc_arg.name.id}".id %}
    {% else %}
      {% resolved_proc = proc_arg %}
    {% end %}
    {% if sig_or_target.is_a?(SymbolLiteral) || sig_or_target.is_a?(StringLiteral) %}
      ::Lapis::Core::StaticSignalTable.global.bind(self.signal_target_id, ({{sig_or_target}}).to_s, {{resolved_proc}}, once: {{once}})
    {% else %}
      ({{sig_or_target}}).bind({{resolved_proc}}, once: {{once}})
    {% end %}
  {% elsif args.size >= 2 && (args[0].is_a?(StringLiteral) || args[0].is_a?(SymbolLiteral)) %}
    {% proc_arg = args[1] %}
    {% if proc_arg.is_a?(ProcPointer) && !proc_arg.obj && (@type < ::Godot::Object) %}
      {% resolved_proc = proc_arg.args.size > 0 ? "->self.#{proc_arg.name.id}(#{proc_arg.args.splat})".id : "->self.#{proc_arg.name.id}".id %}
    {% else %}
      {% resolved_proc = proc_arg %}
    {% end %}
    ::Lapis::Core::StaticSignalTable.global.bind(({{sig_or_target}}).signal_target_id, ({{args[0]}}).to_s, {{resolved_proc}}, once: {{once}})
  {% end %}
end
