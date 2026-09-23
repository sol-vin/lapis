module Godot
  # ===========================================================================
  # Node2D Spatial Conveniences
  # ===========================================================================
  class Node2D
    def x : Float32
      position.x
    end

    def x=(val : Number) : Void
      self.position = Vector2.new(val.to_f32, position.y)
    end

    def y : Float32
      position.y
    end

    def y=(val : Number) : Void
      self.position = Vector2.new(position.x, val.to_f32)
    end

    def global_x : Float32
      global_position.x
    end

    def global_x=(val : Number) : Void
      self.global_position = Vector2.new(val.to_f32, global_position.y)
    end

    def global_y : Float32
      global_position.y
    end

    def global_y=(val : Number) : Void
      self.global_position = Vector2.new(global_position.x, val.to_f32)
    end

    def look_at_pos(target : Vector2) : Void
      look_at(target)
    end
  end

  # ===========================================================================
  # Node3D Spatial Conveniences
  # ===========================================================================
  class Node3D
    def x : Float32
      position.x
    end

    def x=(val : Number) : Void
      self.position = Vector3.new(val.to_f32, position.y, position.z)
    end

    def y : Float32
      position.y
    end

    def y=(val : Number) : Void
      self.position = Vector3.new(position.x, val.to_f32, position.z)
    end

    def z : Float32
      position.z
    end

    def z=(val : Number) : Void
      self.position = Vector3.new(position.x, position.y, val.to_f32)
    end

    def global_x : Float32
      global_position.x
    end

    def global_x=(val : Number) : Void
      self.global_position = Vector3.new(val.to_f32, global_position.y, global_position.z)
    end

    def global_y : Float32
      global_position.y
    end

    def global_y=(val : Number) : Void
      self.global_position = Vector3.new(global_position.x, val.to_f32, global_position.z)
    end

    def global_z : Float32
      global_position.z
    end

    def global_z=(val : Number) : Void
      self.global_position = Vector3.new(global_position.x, global_position.y, val.to_f32)
    end

    def look_at_pos(target : Vector3, up : Vector3 = Vector3::UP) : Void
      look_at(target, up)
    end
  end

  # ===========================================================================
  # Control UI Conveniences
  # ===========================================================================
  class Control
    def rect : Rect2
      Rect2.new(position, size)
    end

    def rect=(r : Rect2) : Void
      self.position = r.position
      self.size = r.size
    end

    def visible? : Bool
      is_visible
    end

    def mouse_in_rect?(screen_pos : Vector2) : Bool
      get_global_rect.has_point(screen_pos)
    end
  end
end
