# =============================================================================
# LibGodot Fluent Tween & Animation DSL
# =============================================================================

require "time"

module Godot
  # Expressive builder wrapper around Godot::Tween
  class TweenBuilder
    getter tween : Tween
    getter owner : Object?

    def initialize(@tween : Tween, @owner : Object? = nil)
    end

    # Animates specified target property to destination value with optional transition and easing
    def animate(
      target : Object,
      prop : String | NodePath,
      to val : Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color,
      duration : Float64 | ::Time::Span = 0.2,
      trans : Tween::TransitionType | Int = Tween::TransitionType::TransLinear,
      ease : Tween::EaseType | Int = Tween::EaseType::EaseInOut
    ) : PropertyTweener
      dur_sec = duration.is_a?(::Time::Span) ? duration.total_seconds : duration.to_f64
      raw_val = val.is_a?(Variant) ? val.raw : val
      tweener = @tween.call_obj_as(PropertyTweener, "tween_property", target, prop.to_s, raw_val, dur_sec) || PropertyTweener.new(Pointer(Void).null)
      tweener.set_trans(trans)
      tweener.set_ease(ease)
      tweener
    end

    # Animates owner node's property to destination value (target omitted)
    def animate(
      prop : String | NodePath,
      to val : Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color,
      duration : Float64 | ::Time::Span = 0.2,
      trans : Tween::TransitionType | Int = Tween::TransitionType::TransLinear,
      ease : Tween::EaseType | Int = Tween::EaseType::EaseInOut
    ) : PropertyTweener
      target = @owner || raise "TweenBuilder has no target owner node to animate"
      animate(target, prop, to: val, duration: duration, trans: trans, ease: ease)
    end

    # Animates owner node's property using an interned symbol
    def animate(
      prop : Symbol,
      to val : Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color,
      duration : Float64 | ::Time::Span = 0.2,
      trans : Tween::TransitionType | Int = Tween::TransitionType::TransLinear,
      ease : Tween::EaseType | Int = Tween::EaseType::EaseInOut
    ) : PropertyTweener
      animate(prop.to_s, to: val, duration: duration, trans: trans, ease: ease)
    end

    # Animates owner node's sub-property using symbols (e.g. animate :position, :y, to: 150.0)
    def animate(
      prop : Symbol,
      sub_prop : Symbol,
      to val : Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color,
      duration : Float64 | ::Time::Span = 0.2,
      trans : Tween::TransitionType | Int = Tween::TransitionType::TransLinear,
      ease : Tween::EaseType | Int = Tween::EaseType::EaseInOut
    ) : PropertyTweener
      animate("#{prop}:#{sub_prop}", to: val, duration: duration, trans: trans, ease: ease)
    end

    # Delays the tween execution by the specified duration in seconds or ::Time::Span
    def delay(duration : Float64 | ::Time::Span) : IntervalTweener
      dur_sec = duration.is_a?(::Time::Span) ? duration.total_seconds : duration.to_f64
      @tween.tween_interval(dur_sec)
    end

    # Pauses until the given signal is emitted
    def await_signal(sig : TypedSignal | SignalSubscription) : AwaitTweener
      @tween.tween_await(sig.target_id)
    end
  end

  class Tween < Godot::RefCounted
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
  def tween(&block : Godot::TweenBuilder -> Void) : Godot::Tween?
    return nil if @pointer.null?
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
    trans : Godot::Tween::TransitionType | Int = Godot::Tween::TransitionType::TransLinear,
    ease : Godot::Tween::EaseType | Int = Godot::Tween::EaseType::EaseInOut
  ) : Godot::Tween?
    return nil if @pointer.null?
    t = create_tween
    dur_sec = duration.is_a?(::Time::Span) ? duration.total_seconds : duration.to_f64
    raw_val = value.is_a?(Godot::Variant) ? value.raw : value
    tweener = t.call_obj_as(Godot::PropertyTweener, "tween_property", self, property.to_s, raw_val, dur_sec)
    if tweener
      tweener.set_trans(trans)
      tweener.set_ease(ease)
    end
    t
  end

  # Overload: quick animation helper targeting an explicit external object
  def tween_to(
    target : Godot::Object,
    property : String | Godot::NodePath,
    value : Godot::Variant | Godot::Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Godot::Vector2 | Godot::Vector3 | Godot::Vector4 | Godot::Color,
    duration : Float64 | ::Time::Span = 0.2,
    trans : Godot::Tween::TransitionType | Int = Godot::Tween::TransitionType::TransLinear,
    ease : Godot::Tween::EaseType | Int = Godot::Tween::EaseType::EaseInOut
  ) : Godot::Tween?
    return nil if @pointer.null?
    t = create_tween
    dur_sec = duration.is_a?(::Time::Span) ? duration.total_seconds : duration.to_f64
    raw_val = value.is_a?(Godot::Variant) ? value.raw : value
    tweener = t.call_obj_as(Godot::PropertyTweener, "tween_property", target, property.to_s, raw_val, dur_sec)
    if tweener
      tweener.set_trans(trans)
      tweener.set_ease(ease)
    end
    t
  end

  # Overload: single symbol property animation on self (e.g. boss.tween_to(:speed, 50.0))
  def tween_to(
    property : Symbol,
    value : Godot::Variant | Godot::Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Godot::Vector2 | Godot::Vector3 | Godot::Vector4 | Godot::Color,
    duration : Float64 | ::Time::Span = 0.2,
    trans : Godot::Tween::TransitionType | Int = Godot::Tween::TransitionType::TransLinear,
    ease : Godot::Tween::EaseType | Int = Godot::Tween::EaseType::EaseInOut
  ) : Godot::Tween?
    tween_to(property.to_s, value, duration, trans, ease)
  end

  # Overload: sub-property symbol animation on self (e.g. boss.tween_to(:position, :y, 150.0))
  def tween_to(
    prop : Symbol,
    sub_prop : Symbol,
    value : Godot::Variant | Godot::Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Godot::Vector2 | Godot::Vector3 | Godot::Vector4 | Godot::Color,
    duration : Float64 | ::Time::Span = 0.2,
    trans : Godot::Tween::TransitionType | Int = Godot::Tween::TransitionType::TransLinear,
    ease : Godot::Tween::EaseType | Int = Godot::Tween::EaseType::EaseInOut
  ) : Godot::Tween?
    tween_to("#{prop}:#{sub_prop}", value, duration, trans, ease)
  end
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
