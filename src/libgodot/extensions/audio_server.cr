module Godot
  class AudioServer < Godot::Object
    # Returns the linear volume (0.0 to 1.0) of the Master audio bus
    def self.get_master_volume : Float32
      idx = get_bus_index("Master")
      return 1.0_f32 if idx < 0
      return 0.0_f32 if is_bus_mute(idx)
      Math.exp(get_bus_volume_db(idx) * 0.11512925464970228_f32).to_f32
    end

    # Sets the linear volume (0.0 to 1.0) of the Master audio bus, muting if near zero
    def self.set_master_volume(linear_val : Float32) : Void
      idx = get_bus_index("Master")
      return if idx < 0
      val = Math.max(0.0_f32, Math.min(1.0_f32, linear_val))
      if val <= 0.001_f32
        set_bus_mute(idx, true)
      else
        set_bus_mute(idx, false)
        db = val > 0.0_f32 ? (Math.log(val) * 8.685889638065037_f32).to_f32 : -80.0_f32
        set_bus_volume_db(idx, db)
      end
    end
  end
end
