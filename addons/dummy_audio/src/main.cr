require "lapis"

# Audio playback node implemented in Crystal for multi-addon audio testing
@[Tool]
node AudioStreamPlayerCrystal < Node do
  # Playback volume attenuation in decibels
  @[Export]
  property volume_db : Float32 = 0.0_f32

  # Target audio bus name for playback routing
  @[Export]
  property bus_name : String = "Master"

  # Indicates whether audio playback is actively streaming
  @[Export]
  property is_playing : Bool = false

  # Emitted when audio playback begins on the designated bus
  signal playback_started(bus : String)

  # Starts streaming audio playback on the configured bus
  def play_stream : Void
    @is_playing = true
    emit_playback_started(@bus_name)
  end

  # Stops the active audio stream playback
  def stop_stream : Void
    @is_playing = false
  end
end

# Editor plugin providing audio preview and bus inspection tools for LibGodot
@[Tool]
node DummyAudioPlugin < EditorPlugin do
  # Indicates whether an audio preview is currently playing in the editor
  @[Export]
  property preview_playing : Bool = false

  # Currently selected preview audio bus
  @[Export]
  property preview_bus : String = "Master"

  # Emitted when an editor audio preview completes or is stopped
  signal preview_stopped(bus : String)

  # Previews an audio stream directly inside the Godot editor
  def preview_audio_stream(stream_path : String, volume_db : Float32 = 0.0_f32) : Bool
    @preview_playing = true
    Godot.print("[DummyAudioPlugin] Previewing '#{stream_path}' at #{volume_db} dB on #{@preview_bus}")
    true
  end

  # Stops any actively playing editor audio preview stream
  def stop_all_previews : Void
    @preview_playing = false
    emit_preview_stopped(@preview_bus)
    Godot.print("[DummyAudioPlugin] Stopped all editor audio previews")
  end

  # Returns whether an audio preview is currently playing in the editor
  def is_preview_active : Bool
    @preview_playing
  end

  def _enter_tree : Void
    Godot.print("[DummyAudioPlugin] Initialized successfully in editor!")
  end

  def _exit_tree : Void
    Godot.print("[DummyAudioPlugin] Deinitialized.")
  end
end
