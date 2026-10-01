module Godot
  # 4-element structure that represents a 3D rotation with hypercomplex numbers (x, y, z, w).
  struct Quaternion
    property x : Float32
    property y : Float32
    property z : Float32
    property w : Float32

    def initialize(@x : Float32 = 0.0_f32, @y : Float32 = 0.0_f32, @z : Float32 = 0.0_f32, @w : Float32 = 1.0_f32)
    end

    def initialize(pointer : Void*)
      if pointer.null?
        @x = 0.0_f32; @y = 0.0_f32; @z = 0.0_f32; @w = 1.0_f32
      else
        ptr = pointer.as(Float32*)
        @x = ptr[0]; @y = ptr[1]; @z = ptr[2]; @w = ptr[3]
      end
    end

    def initialize(x : Number, y : Number, z : Number, w : Number)
      @x = x.to_f32
      @y = y.to_f32
      @z = z.to_f32
      @w = w.to_f32
    end

    def initialize(axis : Vector3, angle : Number)
      d = axis.length
      if d == 0.0_f32
        @x = 0.0_f32; @y = 0.0_f32; @z = 0.0_f32; @w = 1.0_f32
      else
        sin_half = Math.sin(angle.to_f64 * 0.5).to_f32
        cos_half = Math.cos(angle.to_f64 * 0.5).to_f32
        s = sin_half / d
        @x = axis.x * s
        @y = axis.y * s
        @z = axis.z * s
        @w = cos_half
      end
    end

    def - : Quaternion
      Quaternion.new(-@x, -@y, -@z, -@w)
    end

    def +(other : Quaternion) : Quaternion
      Quaternion.new(@x + other.x, @y + other.y, @z + other.z, @w + other.w)
    end

    def -(other : Quaternion) : Quaternion
      Quaternion.new(@x - other.x, @y - other.y, @z - other.z, @w - other.w)
    end

    def *(scalar : Number) : Quaternion
      s = scalar.to_f32
      Quaternion.new(@x * s, @y * s, @z * s, @w * s)
    end

    def /(scalar : Number) : Quaternion
      s = scalar.to_f32
      Quaternion.new(@x / s, @y / s, @z / s, @w / s)
    end

    def *(other : Quaternion) : Quaternion
      Quaternion.new(
        @w * other.x + @x * other.w + @y * other.z - @z * other.y,
        @w * other.y + @y * other.w + @z * other.x - @x * other.z,
        @w * other.z + @z * other.w + @x * other.y - @y * other.x,
        @w * other.w - @x * other.x - @y * other.y - @z * other.z
      )
    end

    def *(vec : Vector3) : Vector3
      u = Vector3.new(@x, @y, @z)
      s = @w
      u * (2.0_f32 * u.dot(vec)) + vec * (s * s - u.dot(u)) + u.cross(vec) * (2.0_f32 * s)
    end

    def length_squared : Float32
      @x * @x + @y * @y + @z * @z + @w * @w
    end

    def length : Float32
      Math.sqrt(length_squared.to_f64).to_f32
    end

    def normalized : Quaternion
      len = length
      if len == 0.0_f32
        IDENTITY
      else
        Quaternion.new(@x / len, @y / len, @z / len, @w / len)
      end
    end

    def is_normalized? : Bool
      (length_squared - 1.0_f32).abs < 0.0001_f32
    end

    def inverse : Quaternion
      Quaternion.new(-@x, -@y, -@z, @w)
    end

    def dot(other : Quaternion) : Float32
      @x * other.x + @y * other.y + @z * other.z + @w * other.w
    end

    def slerp(to : Quaternion, weight : Number) : Quaternion
      t = weight.to_f32
      cos_om = dot(to)
      to_copy = to

      if cos_om < 0.0_f32
        cos_om = -cos_om
        to_copy = Quaternion.new(-to.x, -to.y, -to.z, -to.w)
      end

      if (1.0_f32 - cos_om) > 0.0001_f32
        omega = Math.acos(cos_om.clamp(-1.0_f32, 1.0_f32).to_f64).to_f32
        sin_om = Math.sin(omega.to_f64).to_f32
        scale0 = Math.sin(((1.0_f32 - t) * omega).to_f64).to_f32 / sin_om
        scale1 = Math.sin((t * omega).to_f64).to_f32 / sin_om
      else
        scale0 = 1.0_f32 - t
        scale1 = t
      end

      Quaternion.new(
        scale0 * @x + scale1 * to_copy.x,
        scale0 * @y + scale1 * to_copy.y,
        scale0 * @z + scale1 * to_copy.z,
        scale0 * @w + scale1 * to_copy.w
      )
    end

    def self.from_axis_angle(axis : Vector3, angle : Number) : Quaternion
      Quaternion.new(axis, angle)
    end

    def get_axis : Vector3
      sin_half_sq = 1.0_f32 - @w * @w
      if sin_half_sq <= 0.0_f32
        Vector3::UP
      else
        inv_sin = 1.0_f32 / Math.sqrt(sin_half_sq.to_f64).to_f32
        Vector3.new(@x * inv_sin, @y * inv_sin, @z * inv_sin)
      end
    end

    def get_angle : Float32
      2.0_f32 * Math.acos(@w.clamp(-1.0_f32, 1.0_f32).to_f64).to_f32
    end

    def is_equal_approx(other : Quaternion) : Bool
      (@x - other.x).abs < 0.00001_f32 &&
        (@y - other.y).abs < 0.00001_f32 &&
        (@z - other.z).abs < 0.00001_f32 &&
        (@w - other.w).abs < 0.00001_f32
    end

    def is_finite? : Bool
      @x.finite? && @y.finite? && @z.finite? && @w.finite?
    end

    def ==(other : Quaternion) : Bool
      @x == other.x && @y == other.y && @z == other.z && @w == other.w
    end

    def !=(other : Quaternion) : Bool
      @x != other.x || @y != other.y || @z != other.z || @w != other.w
    end

    def to_s(io : IO) : Void
      io << "(" << @x << ", " << @y << ", " << @z << ", " << @w << ")"
    end

    IDENTITY = Quaternion.new(0.0_f32, 0.0_f32, 0.0_f32, 1.0_f32)
  end
end
