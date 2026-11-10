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

    def initialize(axis : Vector3, angle : Number)
      b = Basis.from_axis_angle(axis, angle)
      @x = b.x
      @y = b.y
      @z = b.z
    end

    def initialize(q : Quaternion)
      b = Basis.from_quaternion(q)
      @x = b.x
      @y = b.y
      @z = b.z
    end

    # Returns column 0 (local X / Right axis), matching GDScript's `basis.x`
    @[AlwaysInline]
    def col_x : Vector3
      Vector3.new(@x.x, @y.x, @z.x)
    end

    @[AlwaysInline]
    def axis_x : Vector3
      col_x
    end

    def col_x=(v : Vector3) : Vector3
      @x = Vector3.new(v.x, @x.y, @x.z)
      @y = Vector3.new(v.y, @y.y, @y.z)
      @z = Vector3.new(v.z, @z.y, @z.z)
      v
    end

    def axis_x=(v : Vector3) : Vector3
      self.col_x = v
    end

    # Returns column 1 (local Y / Up axis), matching GDScript's `basis.y`
    @[AlwaysInline]
    def col_y : Vector3
      Vector3.new(@x.y, @y.y, @z.y)
    end

    @[AlwaysInline]
    def axis_y : Vector3
      col_y
    end

    def col_y=(v : Vector3) : Vector3
      @x = Vector3.new(@x.x, v.x, @x.z)
      @y = Vector3.new(@y.x, v.y, @y.z)
      @z = Vector3.new(@z.x, v.z, @z.z)
      v
    end

    def axis_y=(v : Vector3) : Vector3
      self.col_y = v
    end

    # Returns column 2 (local Z / Back axis), matching GDScript's `basis.z`
    @[AlwaysInline]
    def col_z : Vector3
      Vector3.new(@x.z, @y.z, @z.z)
    end

    @[AlwaysInline]
    def axis_z : Vector3
      col_z
    end

    def col_z=(v : Vector3) : Vector3
      @x = Vector3.new(@x.x, @x.y, v.x)
      @y = Vector3.new(@y.x, @y.y, v.y)
      @z = Vector3.new(@z.x, @z.y, v.z)
      v
    end

    def axis_z=(v : Vector3) : Vector3
      self.col_z = v
    end

    # Constructs a Basis from 3 column basis vectors (Right, Up, Back).
    @[AlwaysInline]
    def self.from_axes(col_x : Vector3, col_y : Vector3, col_z : Vector3) : Basis
      Basis.new(
        Vector3.new(col_x.x, col_y.x, col_z.x),
        Vector3.new(col_x.y, col_y.y, col_z.y),
        Vector3.new(col_x.z, col_y.z, col_z.z)
      )
    end

    # Constructs a pure scaling Basis from a Vector3 scale factor.
    @[AlwaysInline]
    def self.from_scale(scale : Vector3) : Basis
      Basis.new(
        Vector3.new(scale.x, 0.0_f32, 0.0_f32),
        Vector3.new(0.0_f32, scale.y, 0.0_f32),
        Vector3.new(0.0_f32, 0.0_f32, scale.z)
      )
    end

    # Constructs a rotation Basis from a Quaternion.
    def self.from_quaternion(q : Quaternion) : Basis
      d = q.length_squared
      return IDENTITY if d == 0.0_f32
      s = 2.0_f32 / d
      xs = q.x * s
      ys = q.y * s
      zs = q.z * s
      wx = q.w * xs
      wy = q.w * ys
      wz = q.w * zs
      xx = q.x * xs
      xy = q.x * ys
      xz = q.x * zs
      yy = q.y * ys
      yz = q.y * zs
      zz = q.z * zs

      Basis.new(
        Vector3.new(1.0_f32 - (yy + zz), xy - wz, xz + wy),
        Vector3.new(xy + wz, 1.0_f32 - (xx + zz), yz - wx),
        Vector3.new(xz - wy, yz + wx, 1.0_f32 - (xx + yy))
      )
    end

    # Converts this Basis's rotation into a unit Quaternion (Shepperd's method).
    def to_quaternion : Quaternion
      ortho = orthonormalized
      r0 = ortho.x
      r1 = ortho.y
      r2 = ortho.z
      trace = r0.x + r1.y + r2.z
      if trace > 0.0_f32
        s = Math.sqrt(trace + 1.0_f32).to_f32 * 2.0_f32
        Quaternion.new(
          (r2.y - r1.z) / s,
          (r0.z - r2.x) / s,
          (r1.x - r0.y) / s,
          0.25_f32 * s
        )
      elsif r0.x > r1.y && r0.x > r2.z
        s = Math.sqrt(1.0_f32 + r0.x - r1.y - r2.z).to_f32 * 2.0_f32
        Quaternion.new(
          0.25_f32 * s,
          (r0.y + r1.x) / s,
          (r0.z + r2.x) / s,
          (r2.y - r1.z) / s
        )
      elsif r1.y > r2.z
        s = Math.sqrt(1.0_f32 + r1.y - r0.x - r2.z).to_f32 * 2.0_f32
        Quaternion.new(
          (r0.y + r1.x) / s,
          0.25_f32 * s,
          (r1.z + r2.y) / s,
          (r0.z - r2.x) / s
        )
      else
        s = Math.sqrt(1.0_f32 + r2.z - r0.x - r1.y).to_f32 * 2.0_f32
        Quaternion.new(
          (r0.z + r2.x) / s,
          (r1.z + r2.y) / s,
          0.25_f32 * s,
          (r1.x - r0.y) / s
        )
      end
    end

    def get_rotation_quaternion : Quaternion
      to_quaternion
    end

    def slerp(to : Basis, weight : Number) : Basis
      Basis.from_quaternion(to_quaternion.slerp(to.to_quaternion, weight))
    end

    @[AlwaysInline]
    def xform(v : Vector3) : Vector3
      self * v
    end

    @[AlwaysInline]
    def xform_inv(v : Vector3) : Vector3
      Vector3.new(tdotx(v), tdoty(v), tdotz(v))
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
      c_x = Math.cos(euler.x.to_f32)
      s_x = Math.sin(euler.x.to_f32)
      c_y = Math.cos(euler.y.to_f32)
      s_y = Math.sin(euler.y.to_f32)
      c_z = Math.cos(euler.z.to_f32)
      s_z = Math.sin(euler.z.to_f32)

      Basis.new(
        Vector3.new(c_y * c_z + s_y * s_x * s_z, -c_y * s_z + s_y * s_x * c_z, s_y * c_x),
        Vector3.new(c_x * s_z, c_x * c_z, -s_x),
        Vector3.new(-s_y * c_z + c_y * s_x * s_z, s_y * s_z + c_y * s_x * c_z, c_y * c_x)
      )
    end

    def get_euler : Vector3
      m12 = @y.z
      if m12 < 0.999999_f32
        if m12 > -0.999999_f32
          Vector3.new(
            Math.asin(-m12.clamp(-1.0_f32, 1.0_f32)).to_f32,
            Math.atan2(@x.z, @z.z).to_f32,
            Math.atan2(@y.x, @y.y).to_f32
          )
        else
          Vector3.new((Math::PI * 0.5).to_f32, Math.atan2(@x.y, @x.x).to_f32, 0.0_f32)
        end
      else
        Vector3.new((-Math::PI * 0.5).to_f32, -Math.atan2(@x.y, @x.x).to_f32, 0.0_f32)
      end
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

    def self.identity : Basis
      IDENTITY
    end
  end
end
