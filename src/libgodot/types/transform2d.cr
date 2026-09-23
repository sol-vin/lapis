module Godot
  # A 2x3 matrix (2 column vectors + origin) used for 2D affine transformations with 32-bit floating point precision.
  struct Transform2D
    property x : Vector2
    property y : Vector2
    property origin : Vector2

    def initialize(
      @x : Vector2 = Vector2.new(1.0_f32, 0.0_f32),
      @y : Vector2 = Vector2.new(0.0_f32, 1.0_f32),
      @origin : Vector2 = Vector2.new(0.0_f32, 0.0_f32),
    )
    end

    def initialize(pointer : Void*)
      if pointer.null?
        @x = Vector2.new(1.0_f32, 0.0_f32)
        @y = Vector2.new(0.0_f32, 1.0_f32)
        @origin = Vector2.new(0.0_f32, 0.0_f32)
      else
        ptr = pointer.as(Float32*)
        @x = Vector2.new(ptr[0], ptr[1])
        @y = Vector2.new(ptr[2], ptr[3])
        @origin = Vector2.new(ptr[4], ptr[5])
      end
    end

    def initialize(rot_radians : Number, pos : Vector2)
      c = Math.cos(rot_radians.to_f32)
      s = Math.sin(rot_radians.to_f32)
      @x = Vector2.new(c, s)
      @y = Vector2.new(-s, c)
      @origin = pos
    end

    def *(vec : Vector2) : Vector2
      Vector2.new(
        @x.x * vec.x + @y.x * vec.y + @origin.x,
        @x.y * vec.x + @y.y * vec.y + @origin.y
      )
    end

    def *(other : Transform2D) : Transform2D
      Transform2D.new(
        self * other.x,
        self * other.y,
        self * other.origin
      )
    end

    def determinant : Float32
      @x.x * @y.y - @x.y * @y.x
    end

    def affine_inverse : Transform2D
      det = determinant
      if det.abs < 0.00001_f32
        return Transform2D.new
      end
      inv_det = 1.0_f32 / det
      new_x = Vector2.new(@y.y * inv_det, -@x.y * inv_det)
      new_y = Vector2.new(-@y.x * inv_det, @x.x * inv_det)
      new_origin = Vector2.new(
        -(new_x.x * @origin.x + new_y.x * @origin.y),
        -(new_x.y * @origin.x + new_y.y * @origin.y)
      )
      Transform2D.new(new_x, new_y, new_origin)
    end

    def inverse : Transform2D
      affine_inverse
    end

    def orthonormalized : Transform2D
      v_x = @x.normalized
      v_y = (@y - v_x * v_x.dot(@y)).normalized
      Transform2D.new(v_x, v_y, @origin)
    end

    def translated(offset : Vector2) : Transform2D
      Transform2D.new(@x, @y, @origin + offset)
    end

    def rotated(angle : Number) : Transform2D
      rot = Transform2D.new(angle, Vector2.new(0.0_f32, 0.0_f32))
      self * rot
    end

    def scaled(scale : Vector2) : Transform2D
      Transform2D.new(
        Vector2.new(@x.x * scale.x, @x.y * scale.x),
        Vector2.new(@y.x * scale.y, @y.y * scale.y),
        @origin
      )
    end

    def interpolate_with(other : Transform2D, weight : Number) : Transform2D
      Transform2D.new(
        @x.lerp(other.x, weight),
        @y.lerp(other.y, weight),
        @origin.lerp(other.origin, weight)
      )
    end

    def get_rotation : Float32
      Math.atan2(@x.y, @x.x)
    end

    def get_scale : Vector2
      Vector2.new(@x.length, @y.length)
    end

    def get_origin : Vector2
      @origin
    end

    def is_equal_approx(other : Transform2D) : Bool
      @x.is_equal_approx(other.x) && @y.is_equal_approx(other.y) && @origin.is_equal_approx(other.origin)
    end

    def ==(other : Transform2D) : Bool
      @x == other.x && @y == other.y && @origin == other.origin
    end

    def !=(other : Transform2D) : Bool
      @x != other.x || @y != other.y || @origin != other.origin
    end

    def to_s(io : IO) : Void
      io << "[X: " << @x << ", Y: " << @y << ", O: " << @origin << "]"
    end

    IDENTITY = Transform2D.new
    FLIP_X   = Transform2D.new(Vector2.new(-1.0_f32, 0.0_f32), Vector2.new(0.0_f32, 1.0_f32), Vector2.new(0.0_f32, 0.0_f32))
    FLIP_Y   = Transform2D.new(Vector2.new(1.0_f32, 0.0_f32), Vector2.new(0.0_f32, -1.0_f32), Vector2.new(0.0_f32, 0.0_f32))
  end
end
