require "lapis"
require "./**"

include Godot

# In non-release builds, load in-editor test suites so they register with Lapis::Test
# and appear in the Crystal Editor Hub (Unit Test Runner tab)
{% unless flag?(:release) %}
  require "../spec/editor/**"
{% end %}

# Main root scene controller for the template project
node MainNode < Node3D do
  @[ExportMultiline]
  property welcome_message : String = "Welcome to Lapis for Crystal in Godot 4!\nHigh-performance native gameplay scripting."

  @[ExportMultiline]
  property say_text : String = "Hello! Welcome to crystal in godot!\n Written with love by sol.vin"

  # Camera orbit speed in radians per second
  @[Export(range: 0.0_f32..10.0_f32, step: 0.1_f32)]
  property orbit_speed : Float32 = 1.0_f32

  # Orbit radius (distance from the cube)
  @[Export(range: 1.0_f32..50.0_f32, step: 0.5_f32)]
  property orbit_radius : Float32 = 4.0_f32

  # Camera elevation height above the cube
  @[Export(range: -10.0_f32..20.0_f32, step: 0.5_f32)]
  property orbit_height : Float32 = 2.0_f32

  # Toggles camera orbiting around the cube
  @[Export]
  property orbit_enabled : Bool = true

  # Emitted when the template scene completes initialization
  signal initialized

  # Lazy references to child nodes with dead-pointer safety
  onready camera : Camera3D
  onready cube : MeshInstance3D
  onready particles : GPUParticles3D

  # Current accumulated orbit angle in radians
  @orbit_angle : Float64 = 0.0

  def _ready : Void
    Godot.print("[LapisTemplate] ========================================")
    Godot.print("[LapisTemplate] Starting Lapis Starter Game...")
    Godot.print("[LapisTemplate] #{welcome_message}")
    Godot.print("[LapisTemplate] #{say_text}")
    Godot.print("[LapisTemplate] ========================================")

    update_camera_orbit if @orbit_enabled

    emit(initialized)
    Godot.print("[LapisTemplate] MainNode initialization complete!")
  end

  def _process(delta : Float64) : Void
    return unless @orbit_enabled

    @orbit_angle = (@orbit_angle + @orbit_speed * delta) % (Math::PI * 2.0)
    update_camera_orbit(delta)
  end

  # Updates camera position along the orbit path and points it at the cube
  def update_camera_orbit(delta : Float64 = 0.0) : Void

    target_pos = cube.global_position
    cam_x = target_pos.x + (Math.sin(@orbit_angle) * @orbit_radius).to_f32
    cam_z = target_pos.z + (Math.cos(@orbit_angle) * @orbit_radius).to_f32
    cam_y = target_pos.y + @orbit_height
    
    # Cycle particle colors smoothly using intermediary HSV color struct
    mat = particles.draw_pass_1.surface_get_material(0).as_a(StandardMaterial3D)
    hsv = mat.albedo_color.hsv
    hsv.h = (hsv.h + delta * 0.25) % 1.0
    hsv.v = 1.0
    hsv.s = 1.0
    mat.albedo_color = hsv.to_color

    camera.global_position = Vector3.new(cam_x, cam_y, cam_z)
    camera.look_at(target_pos, Vector3::UP)
  end
end
