module Godot
  class Node2D < CanvasItem
    @position : Vector2 = Vector2.new
    @global_position : Vector2 = Vector2.new
    @rotation : Float32 = 0.0_f32
    @rotation_degrees : Float32 = 0.0_f32
    @global_rotation : Float32 = 0.0_f32
    @global_rotation_degrees : Float32 = 0.0_f32
    @scale : Vector2 = Vector2.new(1.0_f32, 1.0_f32)
    @global_scale : Vector2 = Vector2.new(1.0_f32, 1.0_f32)
    @skew : Float32 = 0.0_f32
    @global_skew : Float32 = 0.0_f32
    @transform : Transform2D = Transform2D.new
    @global_transform : Transform2D = Transform2D.new
    @visible : Bool = true

    def position : Vector2
      if !@pointer.null?
        get_position
      else
        @position
      end
    end

    @has_explicit_global_pos : Bool = false

    def position=(v : Vector2)
      @position = v
      if @pointer.null? && !@has_explicit_global_pos
        @global_position = v
      end
      if !@pointer.null?
        set_position(v)
      end
    end

    def global_position : Vector2
      if !@pointer.null?
        get_global_position
      else
        @global_position
      end
    end

    def global_position=(v : Vector2)
      @global_position = v
      @has_explicit_global_pos = true
      if !@pointer.null?
        set_global_position(v)
      end
    end

    def rotation : Float32
      if !@pointer.null?
        get_rotation.to_f32
      else
        @rotation
      end
    end

    def rotation=(v : Float32)
      @rotation = v
      if !@pointer.null?
        set_rotation(v.to_f64)
      end
    end

    def rotation_degrees : Float32
      if !@pointer.null?
        get_rotation_degrees.to_f32
      else
        @rotation_degrees
      end
    end

    def rotation_degrees=(v : Float32)
      @rotation_degrees = v
      if !@pointer.null?
        set_rotation_degrees(v.to_f64)
      end
    end

    def global_rotation : Float32
      if !@pointer.null?
        get_global_rotation.to_f32
      else
        @global_rotation
      end
    end

    def global_rotation=(v : Float32)
      @global_rotation = v
      if !@pointer.null?
        set_global_rotation(v.to_f64)
      end
    end

    def global_rotation_degrees : Float32
      if !@pointer.null?
        get_global_rotation_degrees.to_f32
      else
        @global_rotation_degrees
      end
    end

    def global_rotation_degrees=(v : Float32)
      @global_rotation_degrees = v
      if !@pointer.null?
        set_global_rotation_degrees(v.to_f64)
      end
    end

    def scale : Vector2
      if !@pointer.null?
        get_scale
      else
        @scale
      end
    end

    def scale=(v : Vector2)
      @scale = v
      if !@pointer.null?
        set_scale(v)
      end
    end

    def global_scale : Vector2
      if !@pointer.null?
        get_global_scale
      else
        @global_scale
      end
    end

    def global_scale=(v : Vector2)
      @global_scale = v
      if !@pointer.null?
        set_global_scale(v)
      end
    end

    def skew : Float32
      if !@pointer.null?
        get_skew.to_f32
      else
        @skew
      end
    end

    def skew=(v : Float32)
      @skew = v
      if !@pointer.null?
        set_skew(v.to_f64)
      end
    end

    def global_skew : Float32
      if !@pointer.null?
        get_global_skew.to_f32
      else
        @global_skew
      end
    end

    def global_skew=(v : Float32)
      @global_skew = v
      if !@pointer.null?
        set_global_skew(v.to_f64)
      end
    end

    def transform : Transform2D
      if !@pointer.null?
        get_transform
      else
        @transform
      end
    end

    def transform=(v : Transform2D)
      @transform = v
      if !@pointer.null?
        set_transform(v)
      end
    end

    def global_transform : Transform2D
      if !@pointer.null?
        get_global_transform
      else
        @global_transform
      end
    end

    def global_transform=(v : Transform2D)
      @global_transform = v
      if !@pointer.null?
        set_global_transform(v)
      end
    end

    def visible : Bool
      if !@pointer.null?
        is_visible
      else
        @visible
      end
    end

    def visible=(v : Bool)
      @visible = v
      if !@pointer.null?
        set_visible(v)
      end
    end

    def visible? : Bool
      visible
    end
  end

  # A 3D game object with spatial position, rotation, scale, and transform matrix.
end
