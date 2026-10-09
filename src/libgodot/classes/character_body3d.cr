module Godot
  class CharacterBody3D < PhysicsBody3D
    @@mb_cb3d_is_on_wall : Void* = Pointer(Void).null
    @@mb_cb3d_is_on_ceiling : Void* = Pointer(Void).null

    @velocity : Vector3 = Vector3.new
    @up_direction : Vector3 = Vector3.new(0.0_f32, 1.0_f32, 0.0_f32)
    @floor_snap_length : Float64 = 0.1
    @floor_max_angle : Float64 = 0.785398
    @floor_stop_on_slope : Bool = true
    @floor_constant_speed : Bool = false
    @max_slides : Int64 = 4_i64

    # Returns true if the body is currently resting on a floor collider.
    def is_on_floor : Bool
      if !@pointer.null?
        Bridge.is_on_floor(@pointer)
      else
        true
      end
    end

    def on_floor? : Bool
      is_on_floor
    end

    def is_on_floor? : Bool
      is_on_floor
    end

    def is_on_wall : Bool
      if !@pointer.null?
        begin
          if @@mb_cb3d_is_on_wall.null?
            @@mb_cb3d_is_on_wall = Bridge.get_method_bind("CharacterBody3D", "is_on_wall", 36873697_i64)
          end
          res = 0_u8
          Bridge.ptrcall(@@mb_cb3d_is_on_wall, @pointer, Pointer(Pointer(Void)).null, pointerof(res).as(Void*))
          res != 0_u8
        rescue
          false
        end
      else
        false
      end
    end

    def on_wall? : Bool
      is_on_wall
    end

    def is_on_wall? : Bool
      is_on_wall
    end

    def is_on_ceiling : Bool
      if !@pointer.null?
        begin
          if @@mb_cb3d_is_on_ceiling.null?
            @@mb_cb3d_is_on_ceiling = Bridge.get_method_bind("CharacterBody3D", "is_on_ceiling", 36873697_i64)
          end
          res = 0_u8
          Bridge.ptrcall(@@mb_cb3d_is_on_ceiling, @pointer, Pointer(Pointer(Void)).null, pointerof(res).as(Void*))
          res != 0_u8
        rescue
          false
        end
      else
        false
      end
    end

    def on_ceiling? : Bool
      is_on_ceiling
    end

    def is_on_ceiling? : Bool
      is_on_ceiling
    end

    # Current linear velocity of the character body.
    def velocity : Vector3
      if !@pointer.null?
        get_velocity
      else
        @velocity
      end
    end

    def velocity=(v : Vector3)
      @velocity = v
      if !@pointer.null?
        set_velocity(v)
      end
    end

    def up_direction : Vector3
      if !@pointer.null?
        get_up_direction
      else
        @up_direction
      end
    end

    def up_direction=(v : Vector3)
      @up_direction = v
      if !@pointer.null?
        set_up_direction(v)
      end
    end

    def floor_normal : Vector3
      if !@pointer.null?
        get_floor_normal
      else
        Vector3::UP
      end
    end

    def real_velocity : Vector3
      if !@pointer.null?
        get_real_velocity
      else
        @velocity
      end
    end

    def max_slides : Int64
      if !@pointer.null?
        get_max_slides
      else
        @max_slides
      end
    end

    def max_slides=(v : Int64)
      @max_slides = v
      if !@pointer.null?
        set_max_slides(v)
      end
    end

    def floor_snap_length : Float64
      if !@pointer.null?
        get_floor_snap_length
      else
        @floor_snap_length
      end
    end

    def floor_snap_length=(v : Float64)
      @floor_snap_length = v
      if !@pointer.null?
        set_floor_snap_length(v)
      end
    end

    def floor_max_angle : Float64
      if !@pointer.null?
        get_floor_max_angle
      else
        @floor_max_angle
      end
    end

    def floor_max_angle=(v : Float64)
      @floor_max_angle = v
      if !@pointer.null?
        set_floor_max_angle(v)
      end
    end

    def floor_stop_on_slope : Bool
      if !@pointer.null?
        is_floor_stop_on_slope_enabled
      else
        @floor_stop_on_slope
      end
    end

    def floor_stop_on_slope=(v : Bool)
      @floor_stop_on_slope = v
      if !@pointer.null?
        set_floor_stop_on_slope_enabled(v)
      end
    end

    def floor_constant_speed : Bool
      if !@pointer.null?
        is_floor_constant_speed_enabled
      else
        @floor_constant_speed
      end
    end

    def floor_constant_speed=(v : Bool)
      @floor_constant_speed = v
      if !@pointer.null?
        set_floor_constant_speed_enabled(v)
      end
    end

    def slide_collision_count : Int64
      if !@pointer.null?
        get_slide_collision_count
      else
        0_i64
      end
    end

    # Moves the body along its velocity vector and handles collisions/sliding.
    def move_and_slide : Bool
      if !@pointer.null?
        Bridge.move_and_slide(@pointer)
      else
        true
      end
    end
  end

  # Camera node for 3D scenes.
end
