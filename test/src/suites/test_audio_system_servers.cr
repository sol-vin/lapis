# =============================================================================
# LibGodot Test Suite: AudioServer, Audio Buses & Spatial Audio Players
# =============================================================================

include Lapis::Test

test_audio_server "AudioServer bus management, decibel volume and mute toggles" do
  server = Godot::AudioServer.instance
  assert_not_nil server

  # Master bus inspection
  assert_true server.get_bus_count >= 1_i64
  assert_eq server.get_bus_name(0_i64), "Master"

  # Volume adjustment
  orig_vol = server.get_bus_volume_db(0_i64)
  orig_mute = server.is_bus_mute(0_i64)

  begin
    server.set_bus_volume_db(0_i64, -6.0_f32)
    assert_approx_eq server.get_bus_volume_db(0_i64), -6.0_f32, 0.1

    server.set_bus_mute(0_i64, true)
    assert_true server.is_bus_mute(0_i64)

    server.set_bus_mute(0_i64, false)
    assert_false server.is_bus_mute(0_i64)
  ensure
    server.set_bus_volume_db(0_i64, orig_vol)
    server.set_bus_mute(0_i64, orig_mute)
  end
end

test_audio_server "Dynamic audio bus creation, naming, Reverb effect routing, and teardown" do
  server = Godot::AudioServer.instance
  initial_buses = server.get_bus_count

  # Add temporary test bus
  server.add_bus(initial_buses)
  server.set_bus_name(initial_buses, "DynamicTestBus")
  assert_eq server.get_bus_name(initial_buses), "DynamicTestBus"
  assert_eq server.get_bus_index("DynamicTestBus"), initial_buses

  # Add Reverb effect
  reverb = Godot.create(Godot::AudioEffectReverb)
  reverb.set_room_size(0.75_f64)
  reverb.set_damping(0.4_f64)
  assert_approx_eq reverb.get_room_size.to_f32, 0.75_f32

  append_at_end = -1_i64
  server.add_bus_effect(initial_buses, reverb, append_at_end)
  assert_eq server.get_bus_effect_count(initial_buses), 1_i64

  ret_fx = server.get_bus_effect(initial_buses, 0_i64)
  assert_not_nil ret_fx
  assert_false ret_fx.pointer.null?

  # Remove effect & bus
  server.remove_bus_effect(initial_buses, 0_i64)
  assert_eq server.get_bus_effect_count(initial_buses), 0_i64

  server.remove_bus(initial_buses)
  assert_eq server.get_bus_count, initial_buses
end

test_audio_server "AudioStreamPlayer2D & 3D spatial properties and bus assignments" do
  player2d = Godot.create(Godot::AudioStreamPlayer2D)
  player2d.set_bus("Master")
  player2d.set_max_distance(1200.0_f32)
  player2d.set_pitch_scale(1.25_f32)
  player2d.set_volume_db(-3.0_f32)

  assert_eq player2d.get_bus, "Master"
  assert_approx_eq player2d.get_max_distance, 1200.0_f32
  assert_approx_eq player2d.get_pitch_scale, 1.25_f32
  assert_approx_eq player2d.get_volume_db, -3.0_f32
  player2d.destroy

  # 3D player
  player3d = Godot.create(Godot::AudioStreamPlayer3D)
  player3d.set_unit_size(15.0_f32)
  player3d.set_max_distance(500.0_f32)
  assert_approx_eq player3d.get_unit_size, 15.0_f32
  assert_approx_eq player3d.get_max_distance, 500.0_f32
  player3d.destroy
end
