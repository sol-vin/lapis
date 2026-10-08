# =============================================================================
# LibGodot Fluent Tween & Animation DSL
# =============================================================================

require "time"

module Godot
  # Type-safe easing curve enum
  enum Ease : Int64
    In = 0_i64
    Out = 1_i64
    InOut = 2_i64
    OutIn = 3_i64

    def to_ease_type : Tween::EaseType
      Tween::EaseType.new(value)
    end
  end

  # Type-safe transition curve enum
  enum Trans : Int64
    Linear = 0_i64
    Sine = 1_i64
    Quint = 2_i64
    Quart = 3_i64
    Quad = 4_i64
    Expo = 5_i64
    Elastic = 6_i64
    Cubic = 7_i64
    Circ = 8_i64
    Bounce = 9_i64
    Back = 10_i64
    Spring = 11_i64

    def to_trans_type : Tween::TransitionType
      Tween::TransitionType.new(value)
    end
  end

  # Expressive step wrapper around Godot::PropertyTweener supporting fluent chaining
  class PropertyTweenerStep
    getter tweener : PropertyTweener
    getter builder : TweenBuilder

    def initialize(@tweener : PropertyTweener, @builder : TweenBuilder)
    end

    # Sets the starting value for the tweened property
    def from(value : Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color) : self
      raw_val = value.is_a?(Variant) ? value.raw : value
      @tweener.call("from", raw_val)
      self
    end

    # Sets the starting value to the current value at runtime
    def from_current : self
      ret = @tweener.from_current
      ret.unreference
      self
    end

    # Interprets the destination value as relative to the starting value
    def as_relative : self
      ret = @tweener.as_relative
      ret.unreference
      self
    end

    # Configures the transition curve type (e.g. :cubic, :elastic, :linear)
    def trans(type : Tween::TransitionType | Trans | Symbol | Int) : self
      parsed = Tween.parse_trans(type)
      ret = @tweener.set_trans(parsed)
      ret.unreference
      self
    end

    # Configures the easing curve type (e.g. :in, :out, :in_out)
    def ease(type : Tween::EaseType | Ease | Symbol | Int) : self
      parsed = Tween.parse_ease(type)
      ret = @tweener.set_ease(parsed)
      ret.unreference
      self
    end

    # Sets a delay in seconds or ::Time::Span before this tweener executes
    def delay(duration : Float64 | ::Time::Span) : self
      dur_sec = duration.is_a?(::Time::Span) ? duration.total_seconds : duration.to_f64
      ret = @tweener.set_delay(dur_sec)
      ret.unreference
      self
    end

    # Chains sequential execution and returns the TweenBuilder for the next step
    def chain : TweenBuilder
      @builder.chain
    end

    # Sets parallel execution and returns the TweenBuilder for concurrent steps
    def parallel : TweenBuilder
      @builder.parallel
    end

    def loops(count : Int = 0) : TweenBuilder
      @builder.loops(count)
    end

    def speed_scale(scale : Float64) : TweenBuilder
      @builder.speed_scale(scale)
    end

    def pause : TweenBuilder
      @builder.pause
    end

    def play : TweenBuilder
      @builder.play
    end

    def kill : TweenBuilder
      @builder.kill
    end

    # Chains another animation step directly on target
    def animate(
      target : Object,
      prop : String | NodePath | Symbol,
      to val : Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color,
      duration : Float64 | ::Time::Span = 0.2,
      in in_duration : (Float64 | ::Time::Span)? = nil,
      from from_val : (Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color)? = nil,
      trans : Tween::TransitionType | Trans | Symbol | Int = :linear,
      ease : Tween::EaseType | Ease | Symbol | Int = :in_out
    ) : PropertyTweenerStep
      @builder.animate(target, prop, to: val, duration: duration, in: in_duration, from: from_val, trans: trans, ease: ease)
    end

    # Chains another animation on owner node directly
    def animate(
      prop : String | NodePath | Symbol,
      to val : Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color,
      duration : Float64 | ::Time::Span = 0.2,
      in in_duration : (Float64 | ::Time::Span)? = nil,
      from from_val : (Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color)? = nil,
      trans : Tween::TransitionType | Trans | Symbol | Int = :linear,
      ease : Tween::EaseType | Ease | Symbol | Int = :in_out
    ) : PropertyTweenerStep
      @builder.animate(prop, to: val, duration: duration, in: in_duration, from: from_val, trans: trans, ease: ease)
    end

    # Chains sub-property animation on owner node directly
    def animate(
      prop : Symbol,
      sub_prop : Symbol,
      to val : Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color,
      duration : Float64 | ::Time::Span = 0.2,
      in in_duration : (Float64 | ::Time::Span)? = nil,
      from from_val : (Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color)? = nil,
      trans : Tween::TransitionType | Trans | Symbol | Int = :linear,
      ease : Tween::EaseType | Ease | Symbol | Int = :in_out
    ) : PropertyTweenerStep
      @builder.animate(prop, sub_prop, to: val, duration: duration, in: in_duration, from: from_val, trans: trans, ease: ease)
    end

    # Chains an interval delay step
    def delay_step(duration : Float64 | ::Time::Span) : IntervalTweenerStep
      @builder.chain.delay(duration)
    end

    # Returns the underlying raw Godot::PropertyTweener
    def raw_tweener : PropertyTweener
      @tweener
    end

    forward_missing_to @tweener
  end

  # Expressive step wrapper around Godot::IntervalTweener supporting fluent chaining
  class IntervalTweenerStep
    getter tweener : IntervalTweener
    getter builder : TweenBuilder

    def initialize(@tweener : IntervalTweener, @builder : TweenBuilder)
    end

    def chain : TweenBuilder
      @builder.chain
    end

    def parallel : TweenBuilder
      @builder.parallel
    end

    def loops(count : Int = 0) : TweenBuilder
      @builder.loops(count)
    end

    def speed_scale(scale : Float64) : TweenBuilder
      @builder.speed_scale(scale)
    end

    def pause : TweenBuilder
      @builder.pause
    end

    def play : TweenBuilder
      @builder.play
    end

    def kill : TweenBuilder
      @builder.kill
    end

    def animate(
      target : Object,
      prop : String | NodePath | Symbol,
      to val : Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color,
      duration : Float64 | ::Time::Span = 0.2,
      in in_duration : (Float64 | ::Time::Span)? = nil,
      from from_val : (Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color)? = nil,
      trans : Tween::TransitionType | Trans | Symbol | Int = :linear,
      ease : Tween::EaseType | Ease | Symbol | Int = :in_out
    ) : PropertyTweenerStep
      @builder.animate(target, prop, to: val, duration: duration, in: in_duration, from: from_val, trans: trans, ease: ease)
    end

    def animate(
      prop : String | NodePath | Symbol,
      to val : Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color,
      duration : Float64 | ::Time::Span = 0.2,
      in in_duration : (Float64 | ::Time::Span)? = nil,
      from from_val : (Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color)? = nil,
      trans : Tween::TransitionType | Trans | Symbol | Int = :linear,
      ease : Tween::EaseType | Ease | Symbol | Int = :in_out
    ) : PropertyTweenerStep
      @builder.animate(prop, to: val, duration: duration, in: in_duration, from: from_val, trans: trans, ease: ease)
    end

    def animate(
      prop : Symbol,
      sub_prop : Symbol,
      to val : Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color,
      duration : Float64 | ::Time::Span = 0.2,
      in in_duration : (Float64 | ::Time::Span)? = nil,
      from from_val : (Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color)? = nil,
      trans : Tween::TransitionType | Trans | Symbol | Int = :linear,
      ease : Tween::EaseType | Ease | Symbol | Int = :in_out
    ) : PropertyTweenerStep
      @builder.animate(prop, sub_prop, to: val, duration: duration, in: in_duration, from: from_val, trans: trans, ease: ease)
    end

    def raw_tweener : IntervalTweener
      @tweener
    end

    forward_missing_to @tweener
  end

  # Expressive builder wrapper around Godot::Tween
  class TweenBuilder
    getter tween : Tween
    getter owner : Object?

    def initialize(@tween : Tween, @owner : Object? = nil)
    end

    # Calls Tween#chain and returns self
    def chain : self
      ret = @tween.chain
      ret.unreference
      self
    end

    # Calls Tween#chain and yields self
    def chain(&block : TweenBuilder -> Void) : self
      ret = @tween.chain
      ret.unreference
      yield self
      self
    end

    # Calls Tween#parallel and returns self
    def parallel : self
      ret = @tween.parallel
      ret.unreference
      self
    end

    # Calls Tween#parallel and yields self
    def parallel(&block : TweenBuilder -> Void) : self
      ret = @tween.parallel
      ret.unreference
      yield self
      self
    end

    # Configures loop iterations (0 = infinite)
    def loops(count : Int = 0) : self
      ret = @tween.set_loops(count.to_i64)
      ret.unreference
      self
    end

    # Sets tween speed multiplier
    def speed_scale(scale : Float64) : self
      ret = @tween.set_speed_scale(scale.to_f64)
      ret.unreference
      self
    end

    # Pauses the tween
    def pause : self
      @tween.pause
      self
    end

    # Resumes the tween
    def play : self
      @tween.play
      self
    end

    # Terminates the tween
    def kill : self
      @tween.kill
      self
    end

    # Sets default transition type on the tween
    def trans(type : Tween::TransitionType | Trans | Symbol | Int) : self
      parsed = Tween.parse_trans(type)
      ret = @tween.set_trans(parsed)
      ret.unreference
      self
    end

    # Sets default easing curve type on the tween
    def ease(type : Tween::EaseType | Ease | Symbol | Int) : self
      parsed = Tween.parse_ease(type)
      ret = @tween.set_ease(parsed)
      ret.unreference
      self
    end

    # Delays the tween execution by the specified duration in seconds or ::Time::Span
    def delay(duration : Float64 | ::Time::Span) : IntervalTweenerStep
      dur_sec = duration.is_a?(::Time::Span) ? duration.total_seconds : duration.to_f64
      tweener = @tween.tween_interval(dur_sec)
      tweener.unreference
      IntervalTweenerStep.new(tweener, self)
    end

    # Pauses until the given signal is emitted
    def await_signal(sig : TypedSignal | SignalSubscription) : AwaitTweener
      @tween.tween_await(sig.target_id)
    end

    # Animates specified target property to destination value with optional transition, easing, and starting value
    def animate(
      target : Object,
      prop : String | NodePath | Symbol,
      to val : Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color,
      duration : Float64 | ::Time::Span = 0.2,
      in in_duration : (Float64 | ::Time::Span)? = nil,
      from from_val : (Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color)? = nil,
      trans : Tween::TransitionType | Trans | Symbol | Int = :linear,
      ease : Tween::EaseType | Ease | Symbol | Int = :in_out
    ) : PropertyTweenerStep
      dur_val = in_duration || duration
      dur_sec = dur_val.is_a?(::Time::Span) ? dur_val.total_seconds : dur_val.to_f64
      raw_val = val.is_a?(Variant) ? val.raw : val

      prop_str = prop.to_s

      tweener = @tween.call_obj_as(PropertyTweener, "tween_property", target, prop_str, raw_val, dur_sec) || PropertyTweener.new(Pointer(Void).null)
      ret1 = tweener.set_trans(Tween.parse_trans(trans))
      ret1.unreference
      ret2 = tweener.set_ease(Tween.parse_ease(ease))
      ret2.unreference

      if from_val
        raw_from = from_val.is_a?(Variant) ? from_val.raw : from_val
        tweener.call("from", raw_from)
      end

      # Unreference the extra reference added by bridge_object_call_ret_object since Tween owns the tweener
      tweener.unreference

      PropertyTweenerStep.new(tweener, self)
    end

    # Animates owner node's property to destination value (target omitted)
    def animate(
      prop : String | NodePath | Symbol,
      to val : Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color,
      duration : Float64 | ::Time::Span = 0.2,
      in in_duration : (Float64 | ::Time::Span)? = nil,
      from from_val : (Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color)? = nil,
      trans : Tween::TransitionType | Trans | Symbol | Int = :linear,
      ease : Tween::EaseType | Ease | Symbol | Int = :in_out
    ) : PropertyTweenerStep
      target = @owner || raise "TweenBuilder has no target owner node to animate"
      animate(target, prop, to: val, duration: duration, in: in_duration, from: from_val, trans: trans, ease: ease)
    end

    # Animates owner node's sub-property using symbols (e.g. animate :position, :y, to: 150.0)
    def animate(
      prop : Symbol,
      sub_prop : Symbol,
      to val : Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color,
      duration : Float64 | ::Time::Span = 0.2,
      in in_duration : (Float64 | ::Time::Span)? = nil,
      from from_val : (Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color)? = nil,
      trans : Tween::TransitionType | Trans | Symbol | Int = :linear,
      ease : Tween::EaseType | Ease | Symbol | Int = :in_out
    ) : PropertyTweenerStep
      animate("#{prop}:#{sub_prop}", to: val, duration: duration, in: in_duration, from: from_val, trans: trans, ease: ease)
    end
  end

  class PropertyTweener < Godot::Tweener
    # Overload accepting Variant or primitive types for .from(...)
    def from(value : Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color) : PropertyTweener
      raw_val = value.is_a?(Variant) ? value.raw : value
      call_obj_as(PropertyTweener, "from", raw_val) || self
    end

    def set_trans(trans : Trans | Symbol | Int) : PropertyTweener
      set_trans(Tween.parse_trans(trans))
    end

    def set_ease(ease : Ease | Symbol | Int) : PropertyTweener
      set_ease(Tween.parse_ease(ease))
    end
  end

  class Tween < Godot::RefCounted
    # Converts transition type symbol or integer into Godot::Tween::TransitionType
    def self.parse_trans(val : TransitionType | Trans | Symbol | Int) : TransitionType
      case val
      when TransitionType
        val
      when Trans
        val.to_trans_type
      when Symbol
        case val
        when :linear  then TransitionType::TransLinear
        when :sine    then TransitionType::TransSine
        when :quint   then TransitionType::TransQuint
        when :quart   then TransitionType::TransQuart
        when :quad    then TransitionType::TransQuad
        when :expo    then TransitionType::TransExpo
        when :elastic then TransitionType::TransElastic
        when :cubic   then TransitionType::TransCubic
        when :circ    then TransitionType::TransCirc
        when :bounce  then TransitionType::TransBounce
        when :back    then TransitionType::TransBack
        when :spring  then TransitionType::TransSpring
        else
          TransitionType::TransLinear
        end
      when Int
        TransitionType.new(val.to_i64)
      else
        TransitionType::TransLinear
      end
    end

    # Converts ease type symbol or integer into Godot::Tween::EaseType
    def self.parse_ease(val : EaseType | Ease | Symbol | Int) : EaseType
      case val
      when EaseType
        val
      when Ease
        val.to_ease_type
      when Symbol
        case val
        when :in             then EaseType::EaseIn
        when :out            then EaseType::EaseOut
        when :in_out, :inout then EaseType::EaseInOut
        when :out_in, :outin then EaseType::EaseOutIn
        else
          EaseType::EaseInOut
        end
      when Int
        EaseType.new(val.to_i64)
      else
        EaseType::EaseInOut
      end
    end

    # Overload accepting Variant directly
    def tween_property(object : Godot::Object, property : NodePath | String, final_val : Variant, duration : Float64 | ::Time::Span) : PropertyTweener
      dur_sec = duration.is_a?(::Time::Span) ? duration.total_seconds : duration.to_f64
      call_obj_as(PropertyTweener, "tween_property", object, property.to_s, final_val.raw, dur_sec) || PropertyTweener.new(Pointer(Void).null)
    end

    # Overload accepting primitive / Crystal types
    def tween_property(object : Godot::Object, property : NodePath | String, final_val : Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color, duration : Float64 | ::Time::Span) : PropertyTweener
      dur_sec = duration.is_a?(::Time::Span) ? duration.total_seconds : duration.to_f64
      call_obj_as(PropertyTweener, "tween_property", object, property.to_s, final_val, dur_sec) || PropertyTweener.new(Pointer(Void).null)
    end
  end
end

alias Ease = Godot::Ease
alias Trans = Godot::Trans

class Godot::Node
  # Builds a tween using an expressive builder DSL
  def tween(&) : Godot::Tween
    raw_tween = create_tween
    builder = Godot::TweenBuilder.new(raw_tween, self)
    with builder yield builder
    raw_tween
  end
end

# :nodoc:
macro __rewrite_val(val)
  {% if val.is_a?(Call) && val.receiver && val.args.size == 0 && (val.name.stringify =~ /^[A-Z][a-zA-Z0-9_]*$/) %}
    {{ val.receiver }}::{{ val.name.id }}
  {% else %}
    {{ val }}
  {% end %}
end

# Block-based tween DSL targeting specified node with compile-time type verification (e.g. tween(player) do animate(...) end)
macro tween(target, &block)
  %raw_tween = {{ target }}.create_tween
  %pipeline = Godot::TweenBuilder.new(%raw_tween, {{ target }})
  {%
    exprs = block.body.is_a?(Expressions) ? block.body.expressions : [block.body]
  %}
  {% for expr in exprs %}
    {% if expr.is_a?(Assign) %}
      {{ expr }}
    {% else %}
      {%
        calls = [] of ASTNode
        curr = expr
        if curr.is_a?(Expressions)
          curr = curr.expressions.last
        end
      %}
      {% for i in 0...32 %}
        {% if curr && curr.is_a?(Call) %}
          {% calls.unshift(curr) %}
          {% if curr.receiver %}
            {%
              rec = curr.receiver
              if rec.is_a?(Expressions)
                rec = rec.expressions.last
              end
              if rec.is_a?(Call)
                curr = rec
              else
                calls.unshift(rec)
                curr = nil
              end
            %}
          {% else %}
            {% curr = nil %}
          {% end %}
        {% else %}
          {% curr = nil %}
        {% end %}
      {% end %}

      {% first_node = calls.first %}
      {% if !first_node.is_a?(Call) || first_node.receiver %}
        {{ expr }}
      {% else %}
        {% for call in calls %}
          {% if call.is_a?(Call) %}
            {% cname = call.name.stringify %}
            {% if cname == "animate" %}
              {%
                has_named_to = false
                to_val = nil
                from_val = nil
                if call.named_args && !call.named_args.is_a?(Nop)
                  call.named_args.each do |narg|
                    if narg.name.stringify == "to"
                      has_named_to = true
                      to_val = narg.value
                    elsif narg.name.stringify == "from"
                      from_val = narg.value
                    end
                  end
                end

                if has_named_to
                  if call.args.size >= 2
                    anim_target = call.args[0]
                    prop_arg = call.args[1]
                    arg_offset = 2
                  else
                    anim_target = target
                    prop_arg = call.args[0]
                    arg_offset = 1
                  end
                else
                  if call.args.size >= 4
                    anim_target = call.args[0]
                    prop_arg = call.args[1]
                    arg_offset = 2
                  else
                    anim_target = target
                    prop_arg = call.args[0]
                    arg_offset = 1
                    if to_val.nil? && call.args.size >= 2
                      to_val = call.args[1]
                    end
                  end
                end

                if prop_arg.is_a?(SymbolLiteral)
                  raise "Tween property '#{prop_arg}' must be an identifier (e.g. animate(#{prop_arg.value}, ...)), not a symbol, for compile-time type safety."
                elsif prop_arg.is_a?(StringLiteral)
                  raise "Tween property \"#{prop_arg.value}\" must be an identifier (e.g. animate(#{prop_arg.value.id}, ...)), not a string, for compile-time type safety."
                end

                if prop_arg.is_a?(Call) && prop_arg.receiver
                  prop_str = "#{prop_arg.receiver.name}:#{prop_arg.name}"
                else
                  p_name = prop_arg.name.stringify
                  if p_name == "alpha"
                    prop_str = "modulate:a"
                  else
                    prop_str = p_name
                  end
                end
              %}
              if false
                {% if prop_arg.is_a?(Call) && prop_arg.receiver %}
                  %_tc_sub = {{ anim_target }}.{{ prop_arg.receiver.name }}.{{ prop_arg.name }}
                  {% if to_val %}
                    typeof({{ anim_target }}.{{ prop_arg.receiver.name }}.{{ prop_arg.name }}).cast(__rewrite_val({{ to_val }}))
                  {% end %}
                  {% if from_val %}
                    typeof({{ anim_target }}.{{ prop_arg.receiver.name }}.{{ prop_arg.name }}).cast(__rewrite_val({{ from_val }}))
                  {% end %}
                {% else %}
                  %_tc_prop = {{ anim_target }}.{{ prop_arg.name }}
                  {% if to_val %}
                    {{ anim_target }}.{{ prop_arg.name }} = (__rewrite_val({{ to_val }}))
                  {% end %}
                  {% if from_val %}
                    {{ anim_target }}.{{ prop_arg.name }} = (__rewrite_val({{ from_val }}))
                  {% end %}
                {% end %}
              end
              {% if anim_target != target %}
                %pipeline = %pipeline.animate({{ anim_target }}, {{ prop_str }}{% for arg, idx in call.args %}{% if idx >= arg_offset %}, __rewrite_val({{ arg }}){% end %}{% end %}{% if call.named_args && !call.named_args.is_a?(Nop) %}{% for narg in call.named_args %}, {{ narg.name }}: __rewrite_val({{ narg.value }}){% end %}{% end %})
              {% else %}
                %pipeline = %pipeline.animate({{ prop_str }}{% for arg, idx in call.args %}{% if idx >= arg_offset %}, __rewrite_val({{ arg }}){% end %}{% end %}{% if call.named_args && !call.named_args.is_a?(Nop) %}{% for narg in call.named_args %}, {{ narg.name }}: __rewrite_val({{ narg.value }}){% end %}{% end %})
              {% end %}
            {% elsif call.args.size > 0 || (call.named_args && !call.named_args.is_a?(Nop) && call.named_args.size > 0) %}
              %pipeline = %pipeline.{{ call.name }}({% for arg, idx in call.args %}{% if idx > 0 %}, {% end %}__rewrite_val({{ arg }}){% end %}{% if call.named_args && !call.named_args.is_a?(Nop) %}{% for narg, idx in call.named_args %}{% if call.args.size > 0 || idx > 0 %}, {% end %}{{ narg.name }}: __rewrite_val({{ narg.value }}){% end %}{% end %})
            {% else %}
              %pipeline = %pipeline.{{ call.name }}
            {% end %}
          {% end %}
        {% end %}
      {% end %}
    {% end %}
  {% end %}
  %raw_tween
end

# Block-based tween DSL targeting self (e.g. tween do animate(...) end)
macro tween(&block)
  tween(self) {{ block }}
end

# Compile-time type-safe tween macro supporting dot-navigation (e.g. tween(boss.position.y, to: 150.0))
macro tween(property_expr, to value, in in_duration = 0.2.seconds, from from_val = nil, trans = Godot::Tween::TransitionType::TransLinear, ease = Godot::Tween::EaseType::EaseInOut)
  {%
    target = nil
    path_parts = [] of StringLiteral

    if property_expr.is_a?(Call)
      if property_expr.receiver && property_expr.receiver.is_a?(Call)
        if property_expr.receiver.receiver
          # 2 dots: boss.position.y
          target = property_expr.receiver.receiver
          path_parts << property_expr.receiver.name.stringify
          path_parts << property_expr.name.stringify
        else
          # 1 dot with Call: position.y in self
          target = "self".id
          path_parts << property_expr.receiver.name.stringify
          path_parts << property_expr.name.stringify
        end
      elsif property_expr.receiver
        # 1 dot: boss.speed
        target = property_expr.receiver
        path_parts << property_expr.name.stringify
      else
        # 0 dots: speed in self
        target = "self".id
        path_parts << property_expr.name.stringify
      end
    end
    path_str = path_parts.join(":")
  %}

  # Compile-time static type check: verifies that property_expr is valid on target and value can be assigned!
  if false
    %_tc = {{ property_expr }}
    {{ property_expr }} = (__rewrite_val({{ value }}))
    {% if from_val %}
      {{ property_expr }} = (__rewrite_val({{ from_val }}))
    {% end %}
  end

  %raw_tween = {{ target }}.create_tween
  %builder = Godot::TweenBuilder.new(%raw_tween, {{ target }})
  %builder.animate({{ path_str }}, to: {{ value }}, in: {{ in_duration }}{% if from_val %}, from: {{ from_val }}{% end %}, trans: {{ trans }}, ease: {{ ease }})
  %raw_tween
end
