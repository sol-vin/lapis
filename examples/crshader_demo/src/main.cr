require "libgodot"

# =============================================================================
# CrShaderDemoScene - Interactive Controller for CrShader Demo
# =============================================================================
# Demonstrates 2D animated water and 3D spatial procedural plasma shaders
# authored with CrShader Crystal DSL and running inside Godot 4.
node CrShaderDemoScene < Node3D do
  @fps_label : Godot::Label? = nil
  @plasma_mesh : Godot::MeshInstance3D? = nil
  @water_sprite : Godot::Sprite2D? = nil
  @rotation_speed : Float32 = 0.6_f32

  def _ready : Void
    Godot.print("==================================================================")
    Godot.print("  [CrShaderDemo] CrShader Showcase Demo Scene Initialized!")
    Godot.print("  [CrShaderDemo] Live 2D Water & 3D Plasma Shaders Active")
    Godot.print("==================================================================")

    if mesh_node = get_node_or_null("PlasmaMesh")
      @plasma_mesh = mesh_node.as?(Godot::MeshInstance3D)
    end

    if sprite_node = get_node_or_null("WaterSprite")
      @water_sprite = sprite_node.as?(Godot::Sprite2D)
    end

    if label_node = get_node_or_null("UI/Margin/Panel/VBox/FPSLabel")
      @fps_label = label_node.as?(Godot::Label)
    end
  end

  def _process(delta : Float64) : Void
    # Rotate 3D procedural plasma mesh
    if mesh = @plasma_mesh
      mesh.call("rotate_y", (@rotation_speed * delta.to_f32).to_f64)
    end

    # Update real-time performance metrics in UI
    if label = @fps_label
      fps = delta > 0.0 ? (1.0 / delta).round.to_i : 60
      label.call("set_text", "Performance: #{fps} FPS")
    end
  end
end
