# =============================================================================
# LibGodot Fluent Tween & Animation DSL
# =============================================================================

module Godot
  # Expressive builder wrapper around Godot::Tween
  class TweenBuilder
    getter tween : Tween

    def initialize(@tween : Tween)
    end

    # Animates target property to destination value with optional transition and easing
    def animate(
      target : Object,
      prop : String | NodePath,
      to val : Variant | Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color,
      duration : Float64,
      trans : Tween::TransitionType | Int = Tween::TransitionType::TransLinear,
      ease : Tween::EaseType | Int = Tween::EaseType::EaseInOut
    ) : PropertyTweener
      var = val.is_a?(Variant) ? val : Variant.new(val)
      tweener = @tween.tween_property(target, prop, var.pointer, duration)
      tweener.set_trans(trans)
      tweener.set_ease(ease)
      tweener
    end

    # Delays the tween execution by the specified seconds
    def delay(duration : Float64) : IntervalTweener
      @tween.tween_interval(duration)
    end

    # Pauses until the given signal is emitted
    def await_signal(sig : TypedSignal | SignalSubscription) : AwaitTweener
      @tween.tween_await(sig.target_id)
    end
  end

  class Tween < Godot::RefCounted
    # Overload accepting Variant directly without requiring .pointer
    def tween_property(object : Godot::Object, property : NodePath | String, final_val : Variant, duration : Float64) : PropertyTweener
      previous_def(object, property, final_val.pointer, duration)
    end

    # Overload accepting primitive / Crystal types, wrapping in Variant automatically
    def tween_property(object : Godot::Object, property : NodePath | String, final_val : Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Vector2 | Vector3 | Vector4 | Color, duration : Float64) : PropertyTweener
      var = Variant.new(final_val)
      previous_def(object, property, var.pointer, duration)
    end
  end
end

class Godot::Node
  # Builds a tween using an expressive builder DSL
  def tween(&block : Godot::TweenBuilder -> Void) : Godot::Tween?
    return nil if @pointer.null?
    raw_tween = create_tween
    builder = Godot::TweenBuilder.new(raw_tween)
    with builder yield builder
    raw_tween
  end

  # Quick single-property animation helper
  def tween_to(
    property : String | Godot::NodePath,
    value : Godot::Variant | Godot::Object | Int32 | Int64 | Float32 | Float64 | Bool | String | Godot::Vector2 | Godot::Vector3 | Godot::Vector4 | Godot::Color,
    duration : Float64 = 0.2,
    trans : Godot::Tween::TransitionType | Int = Godot::Tween::TransitionType::TransLinear,
    ease : Godot::Tween::EaseType | Int = Godot::Tween::EaseType::EaseInOut
  ) : Godot::Tween?
    return nil if @pointer.null?
    t = create_tween
    var = value.is_a?(Godot::Variant) ? value : Godot::Variant.new(value)
    tweener = t.tween_property(self, property, var.pointer, duration)
    tweener.set_trans(trans)
    tweener.set_ease(ease)
    t
  end

  # Juice animation: scales up and bounces back to original scale
  def punch_scale(factor : Float32 = 1.2_f32, duration : Float64 = 0.15) : Godot::Tween?
    return nil if @pointer.null?
    # Supports Node2D (Vector2) or Node3D (Vector3)
    if self.responds_to?(:scale)
      current_scale = self.scale
      if current_scale.is_a?(Godot::Vector2)
        t = create_tween
        target_scale = Godot::Variant.new(current_scale * factor)
        orig_scale = Godot::Variant.new(current_scale)
        t.tween_property(self, "scale", target_scale.pointer, duration * 0.5)
        t.tween_property(self, "scale", orig_scale.pointer, duration * 0.5)
        return t
      elsif current_scale.is_a?(Godot::Vector3)
        t = create_tween
        target_scale = Godot::Variant.new(current_scale * factor)
        orig_scale = Godot::Variant.new(current_scale)
        t.tween_property(self, "scale", target_scale.pointer, duration * 0.5)
        t.tween_property(self, "scale", orig_scale.pointer, duration * 0.5)
        return t
      end
    end
    nil
  end
end
