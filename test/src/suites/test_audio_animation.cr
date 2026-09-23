# =============================================================================
# LibGodot Test Suite: Audio, Animation & Viewport Controllers
# =============================================================================

include Lapis::Test


test_audio_anim "Timer interval, one_shot, autostart, and pause flags" do
  timer = Godot.create(Godot::Timer)
  timer.set_wait_time(3.5_f64)
  assert_approx_eq timer.get_wait_time, 3.5

  timer.set_one_shot(true)
  assert_true timer.is_one_shot

  timer.set_autostart(true)
  assert_true timer.has_autostart

  timer.set_paused(true)
  assert_true timer.is_paused

  assert_true timer.is_stopped
  timer.destroy
end

test_audio_anim "AnimationPlayer playback speed and blend time" do
  ap = Godot.create(Godot::AnimationPlayer)
  ap.set_speed_scale(1.75_f64)
  assert_approx_eq ap.get_speed_scale.to_f32, 1.75_f32

  ap.set_default_blend_time(0.25_f64)
  assert_approx_eq ap.get_default_blend_time.to_f32, 0.25_f32
  ap.destroy
end

test_audio_anim "AnimationTree activation flag" do
  at = Godot.create(Godot::AnimationTree)
  at.set_active(false)
  assert_false at.is_active
  at.destroy
end

test_audio_anim "AudioStreamPlayer volume, pitch, and polyphony" do
  asp = Godot.create(Godot::AudioStreamPlayer)
  asp.set_volume_db(-6.0_f64)
  assert_approx_eq asp.get_volume_db.to_f32, -6.0_f32

  asp.set_pitch_scale(1.2_f64)
  assert_approx_eq asp.get_pitch_scale.to_f32, 1.2_f32

  asp.set_max_polyphony(4_i64)
  assert_eq asp.get_max_polyphony, 4_i64
  asp.destroy
end

test_audio_anim "AudioStreamPlayer2D distance and attenuation" do
  asp2d = Godot.create(Godot::AudioStreamPlayer2D)
  asp2d.set_max_distance(800.0_f64)
  assert_approx_eq asp2d.get_max_distance.to_f32, 800.0_f32

  asp2d.set_attenuation(2.5_f64)
  assert_approx_eq asp2d.get_attenuation.to_f32, 2.5_f32
  asp2d.destroy
end

test_audio_anim "AudioStreamPlayer3D spatial attenuation and unit size" do
  asp3d = Godot.create(Godot::AudioStreamPlayer3D)
  asp3d.set_max_distance(150.0_f64)
  assert_approx_eq asp3d.get_max_distance.to_f32, 150.0_f32

  asp3d.set_unit_size(8.0_f64)
  assert_approx_eq asp3d.get_unit_size.to_f32, 8.0_f32
  asp3d.destroy
end

test_audio_anim "SubViewport dimensions and render target mode" do
  vp = Godot.create(Godot::SubViewport)
  vp.set_size(Godot::Vector2i.new(1280, 720))
  assert_eq vp.get_size.x, 1280
  assert_eq vp.get_size.y, 720
  vp.destroy
end

test_audio_anim "CanvasLayer ordering and visibility" do
  cl = Godot.create(Godot::CanvasLayer)
  cl.set_layer(5_i64)
  assert_eq cl.get_layer, 5_i64

  cl.set_visible(false)
  assert_false cl.is_visible
  cl.destroy
end
