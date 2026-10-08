# =============================================================================
# LibGodot Test Suite: Multi-Frame Particles & Spatial Audio with Signal Piping
# =============================================================================

include Lapis::Test

# Receiver node to track piped callbacks from particles and audio players
node ParticlesAudioReceiver < Godot::Node do
  property finished_count : Int32 = 0
  property audio_finished_count : Int32 = 0

  def on_particles_finished : Void
    @finished_count += 1
  end

  def on_audio_finished : Void
    @audio_finished_count += 1
  end

  def reset : Void
    @finished_count = 0
    @audio_finished_count = 0
  end
end

test_suite "ParticlesAndAudioMultiFrame" do
  test "CPUParticles2D emission lifecycle, parameter configuration, and frame stepping" do
    assert_no_leak(max_delta_objects: 5, name: "CPUParticles2D multi-frame lifecycle") do
      particles = Godot.create(Godot::CPUParticles2D)
      particles.set_amount(32_i64)
      particles.set_lifetime(0.2_f64)
      particles.set_one_shot(true)
      particles.set_explosiveness_ratio(1.0_f64)
      particles.set_emitting(true)
      root.add_child(particles)

      assert_true particles.is_emitting, "CPUParticles2D should be actively emitting"
      assert_eq particles.get_amount, 32_i64

      skip_frames(5)

      # Stop emission
      particles.set_emitting(false)
      assert_false particles.is_emitting

      root.remove_child(particles)
      particles.destroy
    end
  end

  test "CPUParticles3D emission parameters and spatial bounds across multi-frame stepping" do
    assert_no_leak(max_delta_objects: 5, name: "CPUParticles3D multi-frame stepping") do
      particles3d = Godot.create(Godot::CPUParticles3D)
      particles3d.set_amount(24_i64)
      particles3d.set_lifetime(0.3_f64)
      particles3d.set_one_shot(false)
      particles3d.set_position(Godot::Vector3.new(0.0, 2.0, 0.0))
      particles3d.set_emitting(true)
      root.add_child(particles3d)

      assert_true particles3d.is_emitting
      assert_eq particles3d.get_amount, 24_i64

      skip_frames(4)

      particles3d.set_emitting(false)
      assert_false particles3d.is_emitting

      root.remove_child(particles3d)
      particles3d.destroy
    end
  end

  test "AudioStreamPlayer2D spatial attenuation, panning, and bus settings over frames" do
    assert_no_leak(max_delta_objects: 5, name: "AudioStreamPlayer2D spatial configuration") do
      player2d = Godot.create(Godot::AudioStreamPlayer2D)
      player2d.set_position(Godot::Vector2.new(150.0, 300.0))
      player2d.set_max_distance(1000.0_f64)
      player2d.set_attenuation(1.5_f64)
      player2d.set_panning_strength(1.2_f64)
      player2d.set_volume_db(-6.0_f64)
      root.add_child(player2d)

      receiver = Godot.create(ParticlesAudioReceiver)
      root.add_child(receiver)

      # Pipe finished signal to class method
      sub = (player2d.signal("finished") >> ->receiver.on_audio_finished)
      assert_true sub.connected?

      assert_approx_eq player2d.get_max_distance.to_f32, 1000.0_f32
      assert_approx_eq player2d.get_attenuation.to_f32, 1.5_f32
      assert_approx_eq player2d.get_panning_strength.to_f32, 1.2_f32
      assert_approx_eq player2d.get_volume_db.to_f32, -6.0_f32

      skip_frames(2)

      sub.unsubscribe
      root.remove_child(receiver)
      receiver.destroy
      root.remove_child(player2d)
      player2d.destroy
    end
  end
end
