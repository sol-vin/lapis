module Godot
  # 3-element structure that can be used to represent 3D coordinates or vectors with 32-bit floating point precision.
  struct Vector3
    property x : Float32
    property y : Float32
    property z : Float32

    def initialize(@x : Float32 = 0.0_f32, @y : Float32 = 0.0_f32, @z : Float32 = 0.0_f32)
    end

    def initialize(x : Number, y : Number, z : Number)
      @x = x.to_f32
      @y = y.to_f32
      @z = z.to_f32
    end

    def initialize(pointer : Void*)
      if pointer.null?
        @x = 0.0_f32
        @y = 0.0_f32
        @z = 0.0_f32
      else
        ptr = pointer.as(Float32*)
        @x = ptr[0]
        @y = ptr[1]
        @z = ptr[2]
      end
    end

    def - : Vector3
      Vector3.new(-@x, -@y, -@z)
    end

    def +(other : Vector3) : Vector3
      Vector3.new(@x + other.x, @y + other.y, @z + other.z)
    end

    def -(other : Vector3) : Vector3
      Vector3.new(@x - other.x, @y - other.y, @z - other.z)
    end

    def *(scalar : Number) : Vector3
      s = scalar.to_f32
      Vector3.new(@x * s, @y * s, @z * s)
    end

    def *(other : Vector3) : Vector3
      Vector3.new(@x * other.x, @y * other.y, @z * other.z)
    end

    def /(scalar : Number) : Vector3
      s = scalar.to_f32
      Vector3.new(@x / s, @y / s, @z / s)
    end

    def /(other : Vector3) : Vector3
      Vector3.new(@x / other.x, @y / other.y, @z / other.z)
    end

    def ==(other : Vector3) : Bool
      @x == other.x && @y == other.y && @z == other.z
    end

    def !=(other : Vector3) : Bool
      @x != other.x || @y != other.y || @z != other.z
    end

    def length_squared : Float32
      @x * @x + @y * @y + @z * @z
    end

    def length : Float32
      Math.sqrt(length_squared)
    end

    def normalized : Vector3
      l = length
      l > 0.00001_f32 ? self / l : Vector3.new(0.0_f32, 0.0_f32, 0.0_f32)
    end

    def dot(other : Vector3) : Float32
      @x * other.x + @y * other.y + @z * other.z
    end

    def cross(other : Vector3) : Vector3
      Vector3.new(
        @y * other.z - @z * other.y,
        @z * other.x - @x * other.z,
        @x * other.y - @y * other.x
      )
    end

    # Returns a new vector slid along a plane defined by the given normal vector.
    def slide(normal : Vector3) : Vector3
      self - normal * dot(normal)
    end

    # Rotates this vector around the given axis by the given angle in radians.
    def rotated(axis : Vector3, angle : Number) : Vector3
      k = axis.normalized
      theta = angle.to_f32
      cos_t = Math.cos(theta)
      sin_t = Math.sin(theta)
      self * cos_t + k.cross(self) * sin_t + k * (k.dot(self) * (1.0_f32 - cos_t))
    end

    # Returns a new vector reflected from a plane defined by the given normal.
    def reflect(normal : Vector3) : Vector3
      self - normal * (2.0_f32 * dot(normal))
    end

    # Returns a new vector bounced off a plane defined by the given normal.
    def bounce(normal : Vector3) : Vector3
      -reflect(normal)
    end

    # Projects this vector onto vector b.
    def project(b : Vector3) : Vector3
      b * (dot(b) / b.length_squared)
    end

    # Returns the unsigned angle in radians between this vector and other.
    def angle_to(to : Vector3) : Float32
      Math.atan2(cross(to).length, dot(to))
    end

    # Returns the signed angle in radians between this vector and other with respect to the given axis.
    def signed_angle_to(to : Vector3, axis : Vector3) : Float32
      cross_to = cross(to)
      unsigned_angle = Math.atan2(cross_to.length, dot(to))
      sgn = cross_to.dot(axis) < 0.0_f32 ? -1.0_f32 : 1.0_f32
      unsigned_angle * sgn
    end

    # Returns the distance between this vector and other.
    def distance_to(other : Vector3) : Float32
      (self - other).length
    end

    # Returns the squared distance between this vector and other.
    def distance_squared_to(other : Vector3) : Float32
      (self - other).length_squared
    end

    # Returns the normalized direction from this vector toward other.
    def direction_to(other : Vector3) : Vector3
      (other - self).normalized
    end

    # Linearly interpolates between this vector and to by weight.
    def lerp(to : Vector3, weight : Number) : Vector3
      self + (to - self) * weight.to_f32
    end

    # Spherically interpolates between this vector and to by weight.
    def slerp(to : Vector3, weight : Number) : Vector3
      start_length_sq = length_squared
      end_length_sq = to.length_squared
      if start_length_sq == 0.0_f32 || end_length_sq == 0.0_f32
        return lerp(to, weight)
      end
      start_length = Math.sqrt(start_length_sq)
      result_length = start_length + (Math.sqrt(end_length_sq) - start_length) * weight.to_f32
      ang = angle_to(to)
      if ang.abs < 0.00001_f32
        return normalized * result_length
      end
      axis = cross(to).normalized
      if axis.length_squared < 0.00001_f32
        return normalized * result_length
      end
      rotated(axis, ang * weight.to_f32).normalized * result_length
    end

    # Cubic interpolation between two vectors using pre_a and post_b tangents.
    def cubic_interpolate(b : Vector3, pre_a : Vector3, post_b : Vector3, weight : Number) : Vector3
      t = weight.to_f32
      t2 = t * t
      t3 = t2 * t
      p0 = self
      p1 = b
      p2 = pre_a
      p3 = post_b
      0.5_f32 * ((p1 * 2.0_f32) + (-p2 + p3) * t + (p2 * 2.0_f32 - p1 * 5.0_f32 + p3 * 4.0_f32 - p0) * t2 + (-p2 + p1 * 3.0_f32 - p3 * 3.0_f32 + p0) * t3)
    end

    # Bezier interpolation through control points.
    def bezier_interpolate(control_1 : Vector3, control_2 : Vector3, end_point : Vector3, t : Number) : Vector3
      u = 1.0_f32 - t.to_f32
      tt = t.to_f32 * t.to_f32
      uu = u * u
      uuu = uu * u
      ttt = tt * t.to_f32
      self * uuu + control_1 * (3.0_f32 * uu * t.to_f32) + control_2 * (3.0_f32 * u * tt) + end_point * ttt
    end

    # Moves this vector toward to by the given delta amount, never exceeding to.
    def move_toward(to : Vector3, delta : Number) : Vector3
      diff = to - self
      len = diff.length
      len <= delta.to_f32 || len < 0.00001_f32 ? to : self + diff / len * delta.to_f32
    end

    # Clamps the vector's length to max_length.
    def limit_length(max_length : Number = 1.0) : Vector3
      l = length
      l > max_length.to_f32 && l > 0.00001_f32 ? self / l * max_length.to_f32 : self
    end

    # Clamps each component between min and max.
    def clamp(min : Vector3, max : Vector3) : Vector3
      Vector3.new(
        @x.clamp(min.x, max.x),
        @y.clamp(min.y, max.y),
        @z.clamp(min.z, max.z)
      )
    end

    # Clamps each component between scalar min and max values.
    def clampf(min_val : Number, max_val : Number) : Vector3
      Vector3.new(
        @x.clamp(min_val.to_f32, max_val.to_f32),
        @y.clamp(min_val.to_f32, max_val.to_f32),
        @z.clamp(min_val.to_f32, max_val.to_f32)
      )
    end

    # Snaps vector components to nearest multiple of step.
    def snapped(step : Vector3) : Vector3
      Vector3.new(
        step.x != 0.0_f32 ? (@x / step.x + 0.5_f32).floor * step.x : @x,
        step.y != 0.0_f32 ? (@y / step.y + 0.5_f32).floor * step.y : @y,
        step.z != 0.0_f32 ? (@z / step.z + 0.5_f32).floor * step.z : @z
      )
    end

    # Returns the vector with each component modulo scalar.
    def posmod(mod_val : Number) : Vector3
      m = mod_val.to_f32
      Vector3.new(@x % m, @y % m, @z % m)
    end

    def abs : Vector3
      Vector3.new(@x.abs, @y.abs, @z.abs)
    end

    def sign : Vector3
      Vector3.new(@x.sign.to_f32, @y.sign.to_f32, @z.sign.to_f32)
    end

    def floor : Vector3
      Vector3.new(@x.floor, @y.floor, @z.floor)
    end

    def ceil : Vector3
      Vector3.new(@x.ceil, @y.ceil, @z.ceil)
    end

    def round : Vector3
      Vector3.new(@x.round, @y.round, @z.round)
    end

    def is_zero_approx : Bool
      @x.abs < 0.00001_f32 && @y.abs < 0.00001_f32 && @z.abs < 0.00001_f32
    end

    def is_zero_approx? : Bool
      is_zero_approx
    end

    def is_equal_approx(other : Vector3) : Bool
      (@x - other.x).abs < 0.00001_f32 && (@y - other.y).abs < 0.00001_f32 && (@z - other.z).abs < 0.00001_f32
    end

    def is_normalized? : Bool
      (length_squared - 1.0_f32).abs < 0.0001_f32
    end

    def is_finite? : Bool
      @x.finite? && @y.finite? && @z.finite?
    end

    def min(other : Vector3) : Vector3
      Vector3.new(Math.min(@x, other.x), Math.min(@y, other.y), Math.min(@z, other.z))
    end

    def max(other : Vector3) : Vector3
      Vector3.new(Math.max(@x, other.x), Math.max(@y, other.y), Math.max(@z, other.z))
    end

    def xz : Vector2
      Vector2.new(@x, @z)
    end

    def xy : Vector2
      Vector2.new(@x, @y)
    end

    def yz : Vector2
      Vector2.new(@y, @z)
    end

    def to_i : Vector3i
      Vector3i.new(@x.to_i32, @y.to_i32, @z.to_i32)
    end

    def to_s(io : IO) : Void
      io << "(" << @x << ", " << @y << ", " << @z << ")"
    end

    # Common constants
    ZERO         = Vector3.new(0.0_f32, 0.0_f32, 0.0_f32)
    ONE          = Vector3.new(1.0_f32, 1.0_f32, 1.0_f32)
    UP           = Vector3.new(0.0_f32, 1.0_f32, 0.0_f32)
    DOWN         = Vector3.new(0.0_f32, -1.0_f32, 0.0_f32)
    LEFT         = Vector3.new(-1.0_f32, 0.0_f32, 0.0_f32)
    RIGHT        = Vector3.new(1.0_f32, 0.0_f32, 0.0_f32)
    FORWARD      = Vector3.new(0.0_f32, 0.0_f32, -1.0_f32)
    BACK         = Vector3.new(0.0_f32, 0.0_f32, 1.0_f32)
    MODEL_FRONT  = Vector3.new(0.0_f32, 0.0_f32, -1.0_f32)
    MODEL_REAR   = Vector3.new(0.0_f32, 0.0_f32, 1.0_f32)
    MODEL_LEFT   = Vector3.new(-1.0_f32, 0.0_f32, 0.0_f32)
    MODEL_RIGHT  = Vector3.new(1.0_f32, 0.0_f32, 0.0_f32)
    MODEL_TOP    = Vector3.new(0.0_f32, 1.0_f32, 0.0_f32)
    MODEL_BOTTOM = Vector3.new(0.0_f32, -1.0_f32, 0.0_f32)
    INF          = Vector3.new(Float32::INFINITY, Float32::INFINITY, Float32::INFINITY)
  end

  # 3-element structure that can be used to represent 3D grid coordinates or discrete voxels with 32-bit integers.
  struct Vector3i
    property x : Int32
    property y : Int32
    property z : Int32

    def initialize(@x : Int32 = 0, @y : Int32 = 0, @z : Int32 = 0)
    end

    def initialize(pointer : Void*)
      if pointer.null?
        @x = 0
        @y = 0
        @z = 0
      else
        ptr = pointer.as(Int32*)
        @x = ptr[0]
        @y = ptr[1]
        @z = ptr[2]
      end
    end

    def initialize(x : Number, y : Number, z : Number)
      @x = x.to_i32
      @y = y.to_i32
      @z = z.to_i32
    end

    def - : Vector3i
      Vector3i.new(-@x, -@y, -@z)
    end

    def +(other : Vector3i) : Vector3i
      Vector3i.new(@x + other.x, @y + other.y, @z + other.z)
    end

    def -(other : Vector3i) : Vector3i
      Vector3i.new(@x - other.x, @y - other.y, @z - other.z)
    end

    def *(scalar : Number) : Vector3i
      s = scalar.to_i32
      Vector3i.new(@x * s, @y * s, @z * s)
    end

    def *(other : Vector3i) : Vector3i
      Vector3i.new(@x * other.x, @y * other.y, @z * other.z)
    end

    def /(scalar : Number) : Vector3i
      s = scalar.to_i32
      Vector3i.new(@x // s, @y // s, @z // s)
    end

    def /(other : Vector3i) : Vector3i
      Vector3i.new(@x // other.x, @y // other.y, @z // other.z)
    end

    def ==(other : Vector3i) : Bool
      @x == other.x && @y == other.y && @z == other.z
    end

    def !=(other : Vector3i) : Bool
      @x != other.x || @y != other.y || @z != other.z
    end

    def abs : Vector3i
      Vector3i.new(@x.abs, @y.abs, @z.abs)
    end

    def sign : Vector3i
      Vector3i.new(@x.sign, @y.sign, @z.sign)
    end

    def min(other : Vector3i) : Vector3i
      Vector3i.new(Math.min(@x, other.x), Math.min(@y, other.y), Math.min(@z, other.z))
    end

    def max(other : Vector3i) : Vector3i
      Vector3i.new(Math.max(@x, other.x), Math.max(@y, other.y), Math.max(@z, other.z))
    end

    def clamp(min : Vector3i, max : Vector3i) : Vector3i
      Vector3i.new(@x.clamp(min.x, max.x), @y.clamp(min.y, max.y), @z.clamp(min.z, max.z))
    end

    # Manhattan (taxicab) distance to other integer position.
    def distance_manhattan_to(other : Vector3i) : Int32
      (@x - other.x).abs + (@y - other.y).abs + (@z - other.z).abs
    end

    def to_v3 : Vector3
      Vector3.new(@x.to_f32, @y.to_f32, @z.to_f32)
    end

    def to_s(io : IO) : Void
      io << "(" << @x << ", " << @y << ", " << @z << ")"
    end

    ZERO    = Vector3i.new(0, 0, 0)
    ONE     = Vector3i.new(1, 1, 1)
    LEFT    = Vector3i.new(-1, 0, 0)
    RIGHT   = Vector3i.new(1, 0, 0)
    UP      = Vector3i.new(0, 1, 0)
    DOWN    = Vector3i.new(0, -1, 0)
    FORWARD = Vector3i.new(0, 0, -1)
    BACK    = Vector3i.new(0, 0, 1)
  end
end
