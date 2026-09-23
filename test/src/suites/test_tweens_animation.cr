# =============================================================================
# LibGodot Test Suite: Tweens, AnimationPlayer & Keyframe Pipelines
# =============================================================================

include Lapis::Test

test_tween "Fluent Tween creation, transition/ease configuration, and control methods" do
  node = Godot.create(Godot::Node2D)
  root.call("add_child", node)

  tween = node.create_tween
  assert_not_nil tween
  assert_false tween.pointer.null?

  # Configure easing and transition using strongly typed Godot enums directly
  tween.set_trans(Godot::Tween::TransitionType::TransSine)
  tween.set_ease(Godot::Tween::EaseType::EaseInOut)
  tween.set_loops(3_i64)

  # Interval tweener
  int_tweener = tween.tween_interval(0.25_f64)
  assert_not_nil int_tweener

  # Control methods
  assert_true tween.is_running
  tween.pause
  assert_false tween.is_running
  tween.play
  assert_true tween.is_running
  tween.kill
  assert_false tween.is_valid

  root.call("remove_child", node)
  node.destroy
end

test_tween "AnimationPlayer, AnimationLibrary and programmatic track authoring" do
  anim_player = Godot.create(Godot::AnimationPlayer)
  anim_lib = Godot.create(Godot::AnimationLibrary)
  anim = Godot.create(Godot::Animation)

  anim.set_length(3.0_f64)
  assert_approx_eq anim.get_length.to_f32, 3.0_f32

  # Add value track using TrackType::TypeValue enum directly (-1 appends to the end)
  track_idx = anim.add_track(Godot::Animation::TrackType::TypeValue)
  assert_eq track_idx, 0_i64

  anim.track_set_path(0_i64, Godot::NodePath.new("Node2D:position"))
  assert_eq anim.track_get_path(0_i64).get_subname_count, 1_i64

  # Insert keyframes
  anim.call("track_insert_key", 0_i64, 0.0_f64, Godot::Vector2.new(0.0, 0.0), 1.0_f64)
  anim.call("track_insert_key", 0_i64, 1.5_f64, Godot::Vector2.new(150.0, 75.0), 1.0_f64)
  anim.call("track_insert_key", 0_i64, 3.0_f64, Godot::Vector2.new(300.0, 0.0), 1.0_f64)

  assert_eq anim.track_get_key_count(0_i64), 3_i64

  # Add animation to library
  anim_lib.add_animation("move_horizontal", anim)
  assert_true anim_lib.has_animation("move_horizontal")

  # Add library to player
  anim_player.add_animation_library("", anim_lib)
  assert_true anim_player.has_animation("move_horizontal")

  anim_player.destroy
end
