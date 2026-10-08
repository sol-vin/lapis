# =============================================================================
# LibGodot Test Suite: Multi-Frame AnimationPlayer & Tween Execution with Signal Piping
# =============================================================================

include Lapis::Test

# Receiver node to track piped callbacks from AnimationPlayer and Tweens
node AnimSignalReceiver < Godot::Node do
  property finished_animations : Array(String) = Array(String).new
  property alert_count : Int32 = 0
  property tween_finished_count : Int32 = 0

  # Exact 1-argument callback: (String)
  def on_animation_finished(anim_name : String) : Void
    @finished_animations << anim_name
  end

  # 0-argument trimmed callback: ()
  def on_playback_done : Void
    @alert_count += 1
  end

  # Tween finished callback: ()
  def on_tween_finished : Void
    @tween_finished_count += 1
  end

  def reset : Void
    @finished_animations.clear
    @alert_count = 0
    @tween_finished_count = 0
  end
end

test_suite "AnimationMultiFrame" do
  test "AnimationPlayer plays track, transforms node across frames, and pipes animation_finished via >>" do
    assert_no_leak(max_delta_objects: 5, name: "AnimationPlayer multi-frame >> animation_finished") do
      target = Godot.create(Godot::Node2D)
      target.name = "AnimTarget"
      target.set_position(Godot::Vector2.new(0.0, 0.0))
      root.add_child(target)

      receiver = Godot.create(AnimSignalReceiver)
      root.add_child(receiver)

      player = Godot.create(Godot::AnimationPlayer)
      root.add_child(player)

      # Create Animation: 0.2s duration
      anim = Godot.create(Godot::Animation)
      anim.set_length(0.2_f64)
      anim.set_step(0.05_f64)

      # Track 0: Transform target position
      track_idx = anim.add_track(Godot::Animation::TrackType::TypeValue)
      anim.track_set_path(track_idx, Godot::NodePath.new("AnimTarget:position"))
      anim.call("track_insert_key", track_idx, 0.0_f64, Godot::Vector2.new(0.0, 0.0), 1.0_f64)
      anim.call("track_insert_key", track_idx, 0.2_f64, Godot::Vector2.new(100.0, 50.0), 1.0_f64)

      # Register library
      anim_lib = Godot.create(Godot::AnimationLibrary)
      anim_lib.add_animation("slide_motion", anim)
      player.add_animation_library("", anim_lib)

      # 1. Pipe animation_finished to exact 1-arg method: ->receiver.on_animation_finished(String)
      sub_exact = (player.signal("animation_finished") >> ->receiver.on_animation_finished(String))
      assert_true sub_exact.connected?

      # 2. Pipe animation_finished to 0-arg trimmed method: ->receiver.on_playback_done
      sub_trim = (player.signal("animation_finished") >> ->receiver.on_playback_done)
      assert_true sub_trim.connected?

      # Start playback and advance partially
      player.play("slide_motion")
      player.advance(0.1_f64)
      skip_frames(2)

      # Verify halfway interpolation
      pos = target.get_position
      assert_true pos.x > 10.0, "Target X should be interpolated towards 100.0, got #{pos.x}"
      assert_eq receiver.finished_animations.size, 0

      # Advance past animation duration
      player.advance(0.15_f64)
      skip_frames(2)

      # Verify callbacks triggered
      assert_true receiver.finished_animations.size >= 1, "Expected piped on_animation_finished to fire"
      assert_eq receiver.finished_animations.first, "slide_motion"
      assert_true receiver.alert_count >= 1, "Expected piped 0-arg on_playback_done to fire"

      sub_exact.unsubscribe
      sub_trim.unsubscribe

      root.remove_child(player)
      player.destroy
      root.remove_child(receiver)
      receiver.destroy
      root.remove_child(target)
      target.destroy
    end
  end

  test "Tween property interpolation and finished signal piping via >> over frames" do
    assert_no_leak(max_delta_objects: 5, name: "Tween >> on_tween_finished") do
      target = Godot.create(Godot::Node2D)
      target.set_position(Godot::Vector2.new(0.0, 0.0))
      root.add_child(target)

      receiver = Godot.create(AnimSignalReceiver)
      root.add_child(receiver)

      tw = tween(target) do
        animate(:position, to: Godot::Vector2.new(200.0_f32, 100.0_f32), duration: 0.2)
      end
      tw.pause

      sub_tween = (tw.signal("finished") >> ->receiver.on_tween_finished)
      assert_true sub_tween.connected?

      # Multi-frame custom stepping: 4 steps of 0.05s = 0.2s total duration
      4.times do
        tw.custom_step(0.05_f64)
        skip_frames(1)
      end

      # Verify destination reached
      pos = target.get_position
      assert_true pos.x > 150.0, "Tween should interpolate target position, got #{pos.x}"
      assert_true receiver.tween_finished_count >= 1, "Tween finished signal pipe should fire"

      sub_tween.unsubscribe
      tw.kill

      root.remove_child(receiver)
      receiver.destroy
      root.remove_child(target)
      target.destroy
    end
  end
end
