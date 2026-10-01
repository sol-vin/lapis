require "libgodot"

# =============================================================================
# CrShaderDemoScene - Interactive Controller for CrShader Demo
# =============================================================================
# Demonstrates 2D animated water and 3D spatial procedural plasma shaders
# authored with CrShader Crystal DSL and running inside Godot 4.
node CrShaderDemoScene < Node3D do
  onready? plasma_mesh, Godot::MeshInstance3D, "PlasmaMesh"
  onready? water_sprite, Godot::Sprite2D, "WaterSprite"
  onready? fps_label, Godot::Label, "UI/Margin/Panel/VBox/FPSLabel"

  @[Export(range: 0.1_f32..5.0_f32, step: 0.1_f32)]
  property rotation_speed : Float32 = 0.6_f32

  def _ready : Void
    Godot.print("==================================================================")
    Godot.print("  [CrShaderDemo] CrShader Showcase Demo Scene Initialized!")
    Godot.print("  [CrShaderDemo] Live 2D Water & 3D Plasma Shaders Active")
    Godot.print("==================================================================")
  end

  def _process(delta : Float64) : Void
    # Rotate 3D procedural plasma mesh
    if mesh = plasma_mesh
      mesh.rotate_y((@rotation_speed * delta.to_f32).to_f64)
    end

    # Update real-time performance metrics in UI
    if label = fps_label
      fps = delta > 0.0 ? (1.0 / delta).round.to_i : 60
      label.text = "Performance: #{fps} FPS"
    end
  end
end
