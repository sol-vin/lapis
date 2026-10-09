module Godot
  class CharacterBody2D < PhysicsBody2D
    @velocity : Vector2 = Vector2.new
    @up_direction : Vector2 = Vector2.new(0.0_f32, -1.0_f32)
    @floor_snap_length : Float64 = 0.1
    @floor_max_angle : Float64 = 0.785398
    @floor_stop_on_slope : Bool = true
    @floor_constant_speed : Bool = false
    @max_slides : Int64 = 4_i64

    def velocity : Vector2
      if !@pointer.null?
        get_velocity
      else
        @velocity
      end
    end

    def velocity=(v : Vector2)
      @velocity = v
      if !@pointer.null?
        set_velocity(v)
      end
    end

    def up_direction : Vector2
      if !@pointer.null?
        get_up_direction
      else
        @up_direction
      end
    end

    def up_direction=(v : Vector2)
      @up_direction = v
      if !@pointer.null?
        set_up_direction(v)
      end
    end

    def floor_normal : Vector2
      if !@pointer.null?
        get_floor_normal
      else
        Vector2::UP
      end
    end

    def real_velocity : Vector2
      if !@pointer.null?
        get_real_velocity
      else
        @velocity
      end
    end

    @@mb_is_on_floor : Void* = Pointer(Void).null
    @@mb_is_on_wall : Void* = Pointer(Void).null
    @@mb_is_on_ceiling : Void* = Pointer(Void).null
    @@mb_move_and_slide : Void* = Pointer(Void).null

    def is_on_floor : Bool
      if !@pointer.null?
        begin
          if @@mb_is_on_floor.null?
            @@mb_is_on_floor = Bridge.get_method_bind("CharacterBody2D", "is_on_floor", 36873697_i64)
          end
          res = 0_u8
          Bridge.ptrcall(@@mb_is_on_floor, @pointer, Pointer(Pointer(Void)).null, pointerof(res).as(Void*))
          res != 0_u8
        rescue
          true
        end
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
          if @@mb_is_on_wall.null?
            @@mb_is_on_wall = Bridge.get_method_bind("CharacterBody2D", "is_on_wall", 36873697_i64)
          end
          res = 0_u8
          Bridge.ptrcall(@@mb_is_on_wall, @pointer, Pointer(Pointer(Void)).null, pointerof(res).as(Void*))
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
          if @@mb_is_on_ceiling.null?
            @@mb_is_on_ceiling = Bridge.get_method_bind("CharacterBody2D", "is_on_ceiling", 36873697_i64)
          end
          res = 0_u8
          Bridge.ptrcall(@@mb_is_on_ceiling, @pointer, Pointer(Pointer(Void)).null, pointerof(res).as(Void*))
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

    def move_and_slide : Bool
      if !@pointer.null?
        begin
          if @@mb_move_and_slide.null?
            @@mb_move_and_slide = Bridge.get_method_bind("CharacterBody2D", "move_and_slide", 2240911060_i64)
          end
          res = 0_u8
          Bridge.ptrcall(@@mb_move_and_slide, @pointer, Pointer(Pointer(Void)).null, pointerof(res).as(Void*))
          res != 0_u8
        rescue
          true
        end
      else
        true
      end
    end
  end

  # Base class for all 3D collision and physics objects.
end
