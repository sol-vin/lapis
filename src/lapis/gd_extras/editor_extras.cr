# =============================================================================
# Lapis GDScript Extras: EditorPlugin, Viewport & Overlay Material Ergonomics
# =============================================================================
# High-level helpers for authoring 3D EditorPlugins, viewport overlays,
# selection managers, camera freelook guards, and unshaded gizmo materials.

module Godot
  class EditorPlugin < Node
    # Safely resolves the active `EditorInterface` singleton if running in the editor.
    def editor_interface? : Godot::EditorInterface?
      return nil if Godot::Engine.singleton_ptr.null?
      return nil unless Godot::Engine.is_editor_hint
      return nil if Godot::EditorInterface.singleton_ptr.null?
      iface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
      return nil if iface.pointer.null? || !iface.alive?
      iface
    rescue
      nil
    end

    # Safely returns the 3D editor `SubViewport` for the given viewport index (`0..3`).
    def editor_viewport_3d(index : Int32 = 0) : Godot::SubViewport?
      iface = editor_interface?
      return nil unless iface
      vp = iface.get_editor_viewport_3d(index.to_i64)
      return nil if vp.pointer.null? || !vp.alive?
      vp
    rescue
      nil
    end

    # Safely returns the active `Camera3D` inside the 3D editor `SubViewport` at `index`.
    # Can be called before any `_forward_3d_gui_input` event has fired.
    def editor_camera_3d(index : Int32 = 0) : Godot::Camera3D?
      vp = editor_viewport_3d(index)
      return nil unless vp
      cam = vp.get_camera_3d
      return nil if cam.pointer.null? || !cam.alive?
      cam
    rescue
      nil
    end

    # Returns the parent `Control` wrapping the 3D editor `SubViewport`, suitable for
    # attaching floating viewport HUD panels or click-through drawing overlays.
    def editor_viewport_control(index : Int32 = 0) : Godot::Control?
      vp = editor_viewport_3d(index)
      return nil unless vp
      parent = vp.get_parent
      return nil if parent.pointer.null? || !parent.alive?
      return nil unless parent.is_class("Control")
      Godot::Control.new(parent.pointer)
    rescue
      nil
    end

    # Returns `true` when the user is holding the Right Mouse Button in the 3D viewport
    # (Godot's standard camera freelook / fly mode), allowing editor plugins to avoid
    # intercepting `WASD`/`QE` navigation keys.
    def editor_freelook_active? : Bool
      return false if Godot::Input.singleton_ptr.null?
      Godot::Input.is_mouse_button_pressed(Godot::MouseButton::MouseButtonRight.value.to_i64)
    rescue
      false
    end

    # Checks whether `mouse_pos` (in `reference_control` local coordinates, or global
    # coordinates if `reference_control` is `nil`) lies inside a visible floating `Control`.
    # Useful inside `_forward_3d_gui_input` to let child HUD panels receive mouse clicks
    # without clicking through into the 3D viewport.
    def over_floating_control?(ctrl : Godot::Control?, mouse_pos : Godot::Vector2, reference_control : Godot::Control? = nil) : Bool
      return false if ctrl.nil? || ctrl.pointer.null? || !ctrl.alive?
      return false unless ctrl.is_visible_in_tree
      global_pos = if ref = reference_control
                     if !ref.pointer.null? && ref.alive?
                       ref.get_global_transform_with_canvas.origin + mouse_pos
                     else
                       mouse_pos
                     end
                   else
                     mouse_pos
                   end
      ctrl.get_global_rect.has_point(global_pos)
    rescue
      false
    end

    # Checks whether `mouse_pos` lies inside any visible floating `Control` in `controls`.
    def over_floating_control?(controls : Enumerable(Godot::Control?), mouse_pos : Godot::Vector2 = Godot::Vector2.zero, reference_control : Godot::Control? = nil) : Bool
      controls.any? { |c| over_floating_control?(c, mouse_pos, reference_control) }
    end

    # Clears the current scene tree selection in the Godot Editor.
    def clear_editor_selection : Void
      iface = editor_interface?
      return unless iface
      sel = iface.get_selection
      return if sel.pointer.null? || !sel.alive?
      sel.clear
    rescue
    end

    # Replaces the Godot Editor's current selection with `node` (or clears if `nil`).
    def select_editor_node(node : Godot::Node?) : Void
      iface = editor_interface?
      return unless iface
      sel = iface.get_selection
      return if sel.pointer.null? || !sel.alive?
      sel.clear
      if node && !node.pointer.null? && node.alive?
        sel.add_node(node)
      end
    rescue
    end
  end

  class StandardMaterial3D < BaseMaterial3D
    # Creates an unshaded `StandardMaterial3D` configured for 3D editor gizmos,
    # face selection overlays, or wireframe indicators without ambient/fog/shadow artifacts.
    def self.unshaded_overlay(
      color : Godot::Color,
      *,
      on_top : Bool = false,
      render_priority : Int32 = 1,
      vertex_colors : Bool = false,
      cull_disabled : Bool = true,
      alpha_transparency : Bool = true
    ) : Godot::StandardMaterial3D
      mat = Godot.create(Godot::StandardMaterial3D)
      mat.shading_mode = Godot::BaseMaterial3D::ShadingMode::ShadingModeUnshaded.value.to_i64
      mat.albedo_color = color
      if alpha_transparency || color.a < 1.0_f32
        mat.transparency = Godot::BaseMaterial3D::Transparency::TransparencyAlpha.value.to_i64
      end
      if cull_disabled
        mat.cull_mode = Godot::BaseMaterial3D::CullMode::CullDisabled.value.to_i64
      end
      mat.no_depth_test = on_top
      mat.depth_draw_mode = Godot::BaseMaterial3D::DepthDrawMode::DepthDrawDisabled.value.to_i64
      mat.disable_ambient_light = true
      mat.disable_fog = true
      mat.disable_receive_shadows = true
      mat.vertex_color_use_as_albedo = vertex_colors
      mat.render_priority = render_priority.to_i64
      mat
    end
  end

  class CanvasItem < Node
    # Draws a filled 2D polygon using a `PackedVector2Array` of screen-space points.
    def draw_colored_polygon(points : PackedVector2Array, color : Color) : Void
      return if @pointer.null? || points.size < 3
      call("draw_colored_polygon", points, color)
    end

    # Draws a filled 2D polygon using a Crystal `Array(Vector2)` of screen-space points.
    def draw_colored_polygon(points : ::Array(Vector2), color : Color) : Void
      return if @pointer.null? || points.size < 3
      draw_colored_polygon(PackedVector2Array.new(points), color)
    end

    # Draws a connected 2D polyline using a `PackedVector2Array` of screen-space points.
    def draw_polyline(points : PackedVector2Array, color : Color, width : Number = -1.0, antialiased : Bool = false) : Void
      return if @pointer.null? || points.size < 2
      call("draw_polyline", points, color, width.to_f64, antialiased)
    end

    # Draws a connected 2D polyline using a Crystal `Array(Vector2)` of screen-space points.
    def draw_polyline(points : ::Array(Vector2), color : Color, width : Number = -1.0, antialiased : Bool = false) : Void
      return if @pointer.null? || points.size < 2
      draw_polyline(PackedVector2Array.new(points), color, width, antialiased)
    end
  end
end
