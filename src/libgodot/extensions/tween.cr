# =============================================================================
# LibGodot Fluent Tween & Animation DSL
# =============================================================================

require "time"

module Godot
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
    def trans(type : Tween::TransitionType | Symbol | Int) : self
      parsed = Tween.parse_trans(type)
      ret = @tweener.set_trans(parsed)
      ret.unreference
      self
    end

    # Configures the easing curve type (e.g. :in, :out, :in_out)
    def ease(type : Tween::EaseType | Symbol | Int) : self
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

    # Chains another animation step directly on target
    def animate(
      target : Object,
      prop : String | NodePath | Symbol,
      to val : Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color,
      duration : Float64 | ::Time::Span = 0.2,
      in in_duration : (Float64 | ::Time::Span)? = nil,
      from from_val : (Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color)? = nil,
      trans : Tween::TransitionType | Symbol | Int = :linear,
      ease : Tween::EaseType | Symbol | Int = :in_out
    ) : PropertyTweenerStep
      @builder.chain.animate(target, prop, to: val, duration: duration, in: in_duration, from: from_val, trans: trans, ease: ease)
    end

    # Chains another animation on owner node directly
    def animate(
      prop : String | NodePath | Symbol,
      to val : Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color,
      duration : Float64 | ::Time::Span = 0.2,
      in in_duration : (Float64 | ::Time::Span)? = nil,
      from from_val : (Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color)? = nil,
      trans : Tween::TransitionType | Symbol | Int = :linear,
      ease : Tween::EaseType | Symbol | Int = :in_out
    ) : PropertyTweenerStep
      @builder.chain.animate(prop, to: val, duration: duration, in: in_duration, from: from_val, trans: trans, ease: ease)
    end

    # Chains sub-property animation on owner node directly
    def animate(
      prop : Symbol,
      sub_prop : Symbol,
      to val : Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color,
      duration : Float64 | ::Time::Span = 0.2,
      in in_duration : (Float64 | ::Time::Span)? = nil,
      from from_val : (Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color)? = nil,
      trans : Tween::TransitionType | Symbol | Int = :linear,
      ease : Tween::EaseType | Symbol | Int = :in_out
    ) : PropertyTweenerStep
      @builder.chain.animate(prop, sub_prop, to: val, duration: duration, in: in_duration, from: from_val, trans: trans, ease: ease)
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

    def animate(
      target : Object,
      prop : String | NodePath | Symbol,
      to val : Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color,
      duration : Float64 | ::Time::Span = 0.2,
      in in_duration : (Float64 | ::Time::Span)? = nil,
      from from_val : (Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color)? = nil,
      trans : Tween::TransitionType | Symbol | Int = :linear,
      ease : Tween::EaseType | Symbol | Int = :in_out
    ) : PropertyTweenerStep
      @builder.chain.animate(target, prop, to: val, duration: duration, in: in_duration, from: from_val, trans: trans, ease: ease)
    end

    def animate(
      prop : String | NodePath | Symbol,
      to val : Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color,
      duration : Float64 | ::Time::Span = 0.2,
      in in_duration : (Float64 | ::Time::Span)? = nil,
      from from_val : (Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color)? = nil,
      trans : Tween::TransitionType | Symbol | Int = :linear,
      ease : Tween::EaseType | Symbol | Int = :in_out
    ) : PropertyTweenerStep
      @builder.chain.animate(prop, to: val, duration: duration, in: in_duration, from: from_val, trans: trans, ease: ease)
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
      trans : Tween::TransitionType | Symbol | Int = :linear,
      ease : Tween::EaseType | Symbol | Int = :in_out
    ) : PropertyTweenerStep
      dur_val = in_duration || duration
      dur_sec = dur_val.is_a?(::Time::Span) ? dur_val.total_seconds : dur_val.to_f64
      raw_val = val.is_a?(Variant) ? val.raw : val

      prop_str = prop.to_s
      if prop_str == "alpha"
        prop_str = "modulate:a"
      end

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
      trans : Tween::TransitionType | Symbol | Int = :linear,
      ease : Tween::EaseType | Symbol | Int = :in_out
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
      trans : Tween::TransitionType | Symbol | Int = :linear,
      ease : Tween::EaseType | Symbol | Int = :in_out
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

    def set_trans(trans : Symbol) : PropertyTweener
      set_trans(Tween.parse_trans(trans))
    end

    def set_ease(ease : Symbol) : PropertyTweener
      set_ease(Tween.parse_ease(ease))
    end
  end

  class Tween < Godot::RefCounted
    # Converts transition type symbol or integer into Godot::Tween::TransitionType
    def self.parse_trans(val : TransitionType | Symbol | Int) : TransitionType
      case val
      when TransitionType
        val
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
    def self.parse_ease(val : EaseType | Symbol | Int) : EaseType
      case val
      when EaseType
        val
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

class Godot::Node
  # Builds a tween using an expressive builder DSL
  def tween(&) : Godot::Tween
    raw_tween = create_tween
    builder = Godot::TweenBuilder.new(raw_tween, self)
    with builder yield builder
    raw_tween
  end

  # Quick single-property animation helper (animates self, target omitted)
  def tween_to(
    property : String | Godot::NodePath,
    value : Godot::Variant | Godot::Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Godot::Vector2 | Godot::Vector3 | Godot::Vector4 | Godot::Color,
    duration : Float64 | ::Time::Span = 0.2,
    trans : Godot::Tween::TransitionType | Symbol | Int = Godot::Tween::TransitionType::TransLinear,
    ease : Godot::Tween::EaseType | Symbol | Int = Godot::Tween::EaseType::EaseInOut
  ) : Godot::Tween?
    return nil if @pointer.null?
    t = create_tween
    dur_sec = duration.is_a?(::Time::Span) ? duration.total_seconds : duration.to_f64
    raw_val = value.is_a?(Godot::Variant) ? value.raw : value
    tweener = t.call_obj_as(Godot::PropertyTweener, "tween_property", self, property.to_s, raw_val, dur_sec)
    if tweener
      tweener.set_trans(Godot::Tween.parse_trans(trans))
      tweener.set_ease(Godot::Tween.parse_ease(ease))
    end
    t
  end

  # Overload: quick animation helper targeting an explicit external object
  def tween_to(
    target : Godot::Object,
    property : String | Godot::NodePath,
    value : Godot::Variant | Godot::Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Godot::Vector2 | Godot::Vector3 | Godot::Vector4 | Godot::Color,
    duration : Float64 | ::Time::Span = 0.2,
    trans : Godot::Tween::TransitionType | Symbol | Int = Godot::Tween::TransitionType::TransLinear,
    ease : Godot::Tween::EaseType | Symbol | Int = Godot::Tween::EaseType::EaseInOut
  ) : Godot::Tween?
    return nil if @pointer.null?
    t = create_tween
    dur_sec = duration.is_a?(::Time::Span) ? duration.total_seconds : duration.to_f64
    raw_val = value.is_a?(Godot::Variant) ? value.raw : value
    tweener = t.call_obj_as(Godot::PropertyTweener, "tween_property", target, property.to_s, raw_val, dur_sec)
    if tweener
      tweener.set_trans(Godot::Tween.parse_trans(trans))
      tweener.set_ease(Godot::Tween.parse_ease(ease))
    end
    t
  end

  # Overload: single symbol property animation on self (e.g. boss.tween_to(:speed, 50.0))
  def tween_to(
    property : Symbol,
    value : Godot::Variant | Godot::Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Godot::Vector2 | Godot::Vector3 | Godot::Vector4 | Godot::Color,
    duration : Float64 | ::Time::Span = 0.2,
    trans : Godot::Tween::TransitionType | Symbol | Int = Godot::Tween::TransitionType::TransLinear,
    ease : Godot::Tween::EaseType | Symbol | Int = Godot::Tween::EaseType::EaseInOut
  ) : Godot::Tween?
    tween_to(property.to_s, value, duration, trans, ease)
  end

  # Overload: sub-property symbol animation on self (e.g. boss.tween_to(:position, :y, 150.0))
  def tween_to(
    prop : Symbol,
    sub_prop : Symbol,
    value : Godot::Variant | Godot::Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Godot::Vector2 | Godot::Vector3 | Godot::Vector4 | Godot::Color,
    duration : Float64 | ::Time::Span = 0.2,
    trans : Godot::Tween::TransitionType | Symbol | Int = Godot::Tween::TransitionType::TransLinear,
    ease : Godot::Tween::EaseType | Symbol | Int = Godot::Tween::EaseType::EaseInOut
  ) : Godot::Tween?
    tween_to("#{prop}:#{sub_prop}", value, duration, trans, ease)
  end
end

# Block-based tween DSL targeting specified node (e.g. tween(player) do animate(...) end)
macro tween(target, &block)
  {{ target }}.tween {{ block }}
end

# Block-based tween DSL targeting self (e.g. tween do animate(...) end)
macro tween(&block)
  self.tween {{ block }}
end

# Compile-time type-safe tween macro supporting dot-navigation (e.g. tween(boss.position.y, to: 150.0))
macro tween(property_expr, to value, in in_duration = 0.2.seconds, trans = Godot::Tween::TransitionType::TransLinear, ease = Godot::Tween::EaseType::EaseInOut)
  {%
    target = nil
    path_parts = [] of StringLiteral

    if property_expr.is_a?(Call)
      if property_expr.receiver && property_expr.receiver.is_a?(Call)
        # 2 dots: boss.position.y or self.position.y
        target = property_expr.receiver.receiver || property_expr.receiver
        path_parts << property_expr.receiver.name.stringify
        path_parts << property_expr.name.stringify
      elsif property_expr.receiver
        # 1 dot: boss.speed or self.speed
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

  # Compile-time type check: verifies that property_expr is valid on target!
  if false
    %_tc = {{ property_expr }}
  end

  {{ target }}.tween_to({{ path_str }}, {{ value }}, {{ in_duration }}, trans: {{ trans }}, ease: {{ ease }})
end
