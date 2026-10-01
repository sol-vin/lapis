require "../../dummy_base_dep/src/dummy_base_dep"
ensure_lapis

# =============================================================================
# Dummy Dep Weather: Dynamic Weather & Atmosphere Plugin depending on dummy_base_dep
# =============================================================================

# Weather entity mixing in DummyBaseMixin and utilizing DummyBaseUtils
@[Tool]
node DummyWeatherEntity < Node2D do
  include DummyBaseMixin

  # Active atmospheric condition name
  @[Export]
  property weather_type : String = "Clear"

  # Ambient temperature in Celsius
  @[Export]
  property temperature : Float64 = 21.0

  # Emitted when the weather condition changes
  signal weather_changed(new_type : String, new_temp : Float64)

  # Emitted when an extreme storm starts
  signal storm_alert(severity : Int32)

  def transition_weather(new_type : String, new_temp : Float64) : Void
    @weather_type = new_type
    @temperature = new_temp
    emit_weather_changed(new_type, new_temp)

    if new_type.includes?("Storm") || new_temp > 40.0 || new_temp < -10.0
      emit_storm_alert(3)
    end
  end

  def format_weather_log(action : String) : String
    DummyBaseUtils.format_action("Weather", action)
  end

  def weather_status : String
    "WeatherEntity[weather=#{@weather_type},temp=#{@temperature}C,tag=#{@shared_tag}]"
  end
end

# Editor plugin for weather system
@[Tool]
node DummyWeatherPlugin < EditorPlugin do
  signal weather_system_ready

  def _enter_tree : Void
    emit_weather_system_ready
    Godot.print("[DummyWeatherPlugin] Initialized successfully in editor!")
  end

  def _exit_tree : Void
    Godot.print("[DummyWeatherPlugin] Deinitialized.")
  end
end
