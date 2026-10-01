module Godot
  # A 3x3 matrix used for 3D rotation and scale with 32-bit floating point precision.
  struct Basis
    property x : Vector3
    property y : Vector3
    property z : Vector3

    def initialize(
      @x : Vector3 = Vector3.new(1.0_f32, 0.0_f32, 0.0_f32),
      @y : Vector3 = Vector3.new(0.0_f32, 1.0_f32, 0.0_f32),
      @z : Vector3 = Vector3.new(0.0_f32, 0.0_f32, 1.0_f32),
    )
    end

    def initialize(pointer : Void*)
      if pointer.null?
        @x = Vector3.new(1.0_f32, 0.0_f32, 0.0_f32)
        @y = Vector3.new(0.0_f32, 1.0_f32, 0.0_f32)
        @z = Vector3.new(0.0_f32, 0.0_f32, 1.0_f32)
      else
        ptr = pointer.as(Float32*)
        @x = Vector3.new(ptr[0], ptr[1], ptr[2])
        @y = Vector3.new(ptr[3], ptr[4], ptr[5])
        @z = Vector3.new(ptr[6], ptr[7], ptr[8])
      end
    end

    @[AlwaysInline]
    def *(vec : Vector3) : Vector3
      Vector3.new(
        @x.dot(vec),
        @y.dot(vec),
        @z.dot(vec)
      )
    end

    @[AlwaysInline]
    def tdotx(v : Vector3) : Float32
      @x.x * v.x + @y.x * v.y + @z.x * v.z
    end

    @[AlwaysInline]
    def tdoty(v : Vector3) : Float32
      @x.y * v.x + @y.y * v.y + @z.y * v.z
    end

    @[AlwaysInline]
    def tdotz(v : Vector3) : Float32
      @x.z * v.x + @y.z * v.y + @z.z * v.z
    end

    @[AlwaysInline]
    def *(other : Basis) : Basis
      Basis.new(
        Vector3.new(other.tdotx(@x), other.tdoty(@x), other.tdotz(@x)),
        Vector3.new(other.tdotx(@y), other.tdoty(@y), other.tdotz(@y)),
        Vector3.new(other.tdotx(@z), other.tdoty(@z), other.tdotz(@z))
      )
    end

    def transposed : Basis
      Basis.new(
        Vector3.new(@x.x, @y.x, @z.x),
        Vector3.new(@x.y, @y.y, @z.y),
        Vector3.new(@x.z, @y.z, @z.z)
      )
    end

    def scaled(scale : Vector3) : Basis
      Basis.new(
        @x * scale.x,
        @y * scale.y,
        @z * scale.z
      )
    end

    def determinant : Float32
      @x.x * (@y.y * @z.z - @y.z * @z.y) -
        @x.y * (@y.x * @z.z - @y.z * @z.x) +
        @x.z * (@y.x * @z.y - @y.y * @z.x)
    end

    def inverse : Basis
      det = determinant
      if det.abs < 0.00001_f32
        return Basis.new
      end
      inv_det = 1.0_f32 / det
      Basis.new(
        Vector3.new(
          (@y.y * @z.z - @y.z * @z.y) * inv_det,
          (@x.z * @z.y - @x.y * @z.z) * inv_det,
          (@x.y * @y.z - @x.z * @y.y) * inv_det
        ),
        Vector3.new(
          (@y.z * @z.x - @y.x * @z.z) * inv_det,
          (@x.x * @z.z - @x.z * @z.x) * inv_det,
          (@x.z * @y.x - @x.x * @y.z) * inv_det
        ),
        Vector3.new(
          (@y.x * @z.y - @y.y * @z.x) * inv_det,
          (@x.y * @z.x - @x.x * @z.y) * inv_det,
          (@x.x * @y.y - @x.y * @y.x) * inv_det
        )
      )
    end

    def orthonormalized : Basis
      v_x = @x.normalized
      v_y = (@y - v_x * v_x.dot(@y)).normalized
      v_z = v_x.cross(v_y)
      Basis.new(v_x, v_y, v_z)
    end

    def get_scale : Vector3
      Vector3.new(
        Math.sqrt(@x.x * @x.x + @x.y * @x.y + @x.z * @x.z),
        Math.sqrt(@y.x * @y.x + @y.y * @y.y + @y.z * @y.z),
        Math.sqrt(@z.x * @z.x + @z.y * @z.y + @z.z * @z.z)
      )
    end

    def self.looking_at(target : Vector3, up : Vector3 = Vector3::UP) : Basis
      v_z = -target.normalized
      v_x = up.cross(v_z).normalized
      v_y = v_z.cross(v_x)
      Basis.new(v_x, v_y, v_z)
    end

    @[AlwaysInline]
    def self.from_axis_angle(p_axis : Vector3, p_angle : Number) : Basis
      cosine = Math.cos(p_angle.to_f32)
      sine = Math.sin(p_angle.to_f32)
      t = 1.0_f32 - cosine

      axis_sq_x = p_axis.x * p_axis.x
      axis_sq_y = p_axis.y * p_axis.y
      axis_sq_z = p_axis.z * p_axis.z

      xyzt = p_axis.x * p_axis.y * t
      zyxs = p_axis.z * sine
      r01 = xyzt - zyxs
      r10 = xyzt + zyxs

      xyzt = p_axis.x * p_axis.z * t
      zyxs = p_axis.y * sine
      r02 = xyzt + zyxs
      r20 = xyzt - zyxs

      xyzt = p_axis.y * p_axis.z * t
      zyxs = p_axis.x * sine
      r12 = xyzt - zyxs
      r21 = xyzt + zyxs

      Basis.new(
        Vector3.new(axis_sq_x + cosine * (1.0_f32 - axis_sq_x), r01, r02),
        Vector3.new(r10, axis_sq_y + cosine * (1.0_f32 - axis_sq_y), r12),
        Vector3.new(r20, r21, axis_sq_z + cosine * (1.0_f32 - axis_sq_z))
      )
    end

    def self.from_euler(euler : Vector3) : Basis
      c = Vector3.new(Math.cos(euler.x), Math.cos(euler.y), Math.cos(euler.z))
      s = Vector3.new(Math.sin(euler.x), Math.sin(euler.y), Math.sin(euler.z))

      Basis.new(
        Vector3.new(c.y * c.z, -c.y * s.z, s.y),
        Vector3.new(s.x * s.y * c.z + c.x * s.z, -s.x * s.y * s.z + c.x * c.z, -s.x * c.y),
        Vector3.new(-c.x * s.y * c.z + s.x * s.z, c.x * s.y * s.z + s.x * c.z, c.x * c.y)
      )
    end

    def get_euler : Vector3
      pitch = Math.asin(@x.z.clamp(-1.0_f32, 1.0_f32))
      if (@x.z.abs - 1.0_f32).abs > 0.00001_f32
        yaw = Math.atan2(-@y.z, @z.z)
        roll = Math.atan2(-@x.y, @x.x)
      else
        yaw = 0.0_f32
        roll = Math.atan2(@y.x, @y.y)
      end
      Vector3.new(yaw, pitch, roll)
    end

    def rotated(axis : Vector3, angle : Number) : Basis
      Basis.from_axis_angle(axis, angle) * self
    end

    def is_equal_approx(other : Basis) : Bool
      @x.is_equal_approx(other.x) && @y.is_equal_approx(other.y) && @z.is_equal_approx(other.z)
    end

    def ==(other : Basis) : Bool
      @x == other.x && @y == other.y && @z == other.z
    end

    def !=(other : Basis) : Bool
      @x != other.x || @y != other.y || @z != other.z
    end

    def to_s(io : IO) : Void
      io << "[X: " << @x << ", Y: " << @y << ", Z: " << @z << "]"
    end

    IDENTITY = Basis.new
    FLIP_X   = Basis.new(Vector3.new(-1.0_f32, 0.0_f32, 0.0_f32), Vector3.new(0.0_f32, 1.0_f32, 0.0_f32), Vector3.new(0.0_f32, 0.0_f32, 1.0_f32))
    FLIP_Y   = Basis.new(Vector3.new(1.0_f32, 0.0_f32, 0.0_f32), Vector3.new(0.0_f32, -1.0_f32, 0.0_f32), Vector3.new(0.0_f32, 0.0_f32, 1.0_f32))
    FLIP_Z   = Basis.new(Vector3.new(1.0_f32, 0.0_f32, 0.0_f32), Vector3.new(0.0_f32, 1.0_f32, 0.0_f32), Vector3.new(0.0_f32, 0.0_f32, -1.0_f32))
  end
end
