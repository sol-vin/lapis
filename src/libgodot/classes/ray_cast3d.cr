module Godot
  class RayCast3D < Node3D
    @target_position : Vector3 = Vector3.new(0.0_f32, -1.0_f32, 0.0_f32)
    @enabled : Bool = true

    def target_position : Vector3
      if !@pointer.null?
        get_target_position
      else
        @target_position
      end
    end

    def target_position=(v : Vector3)
      @target_position = v
      if !@pointer.null?
        set_target_position(v)
      end
    end

    def enabled : Bool
      if !@pointer.null?
        is_enabled
      else
        @enabled
      end
    end

    def enabled=(v : Bool)
      @enabled = v
      if !@pointer.null?
        set_enabled(v)
      end
    end

    def enabled? : Bool
      enabled
    end

    def colliding? : Bool
      if !@pointer.null?
        is_colliding
      else
        false
      end
    end

    def collision_point : Vector3
      if !@pointer.null?
        get_collision_point
      else
        Vector3.new
      end
    end

    def collision_normal : Vector3
      if !@pointer.null?
        get_collision_normal
      else
        Vector3::UP
      end
    end
  end

  # Node that provides a collision shape to a CollisionObject3D.
end
