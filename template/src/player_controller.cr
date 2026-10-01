require "lapis"

# Player controller showcasing 3D movement, property exports, and custom signals
node PlayerController < CharacterBody3D do
  # Declaratively assign player to scene tree group
  group "players"

  # Movement speed in meters per second
  @[Export(range: 1.0_f32..30.0_f32, step: 0.5_f32)]
  property speed : Float32 = 8.0_f32

  # Maximum player hit points
  @[Export(range: 10..500, step: 10)]
  property max_health : Int32 = 100

  # Current player hit points
  @[Export(range: 0..500, step: 1)]
  property current_health : Int32 = 100

  # Emitted when player health changes
  signal health_changed(current : Int32, max_health : Int32)

  # Emitted when player changes position
  signal player_moved(position : Vector3)

  def _ready : Void
    Godot.print("[LapisTemplate] PlayerController initialized: #{name} (speed: #{@speed}, health: #{@current_health}/#{@max_health})")
    emit(health_changed, @current_health, @max_health)
  end

  def _physics_process(delta : Float64) : Void
    # Sample physics processing simulation
    emit(player_moved, global_position)
  end

  # Applies damage and notifies listeners via health_changed signal
  def take_damage(amount : Int32) : Void
    @current_health = Math.max(0, @current_health - amount)
    emit(health_changed, @current_health, @max_health)
    Godot.print("[LapisTemplate] Player took #{amount} damage, remaining: #{@current_health}")
  end
end
