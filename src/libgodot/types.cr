module Godot
  # 2-element structure that can be used to represent 2D coordinates or vectors with 32-bit floating point precision.
  struct Vector2
    property x : Float32
    property y : Float32

    def initialize(@x : Float32 = 0.0_f32, @y : Float32 = 0.0_f32)
    end

    def initialize(x : Number, y : Number)
      @x = x.to_f32
      @y = y.to_f32
    end

    def - : Vector2
      Vector2.new(-@x, -@y)
    end

    def +(other : Vector2) : Vector2
      Vector2.new(@x + other.x, @y + other.y)
    end

    def -(other : Vector2) : Vector2
      Vector2.new(@x - other.x, @y - other.y)
    end

    def *(scalar : Number) : Vector2
      s = scalar.to_f32
      Vector2.new(@x * s, @y * s)
    end

    def *(other : Vector2) : Vector2
      Vector2.new(@x * other.x, @y * other.y)
    end

    def /(scalar : Number) : Vector2
      s = scalar.to_f32
      Vector2.new(@x / s, @y / s)
    end

    def /(other : Vector2) : Vector2
      Vector2.new(@x / other.x, @y / other.y)
    end

    def length_squared : Float32
      @x * @x + @y * @y
    end

    def length : Float32
      Math.sqrt(length_squared)
    end

    def normalized : Vector2
      l = length
      l > 0.00001_f32 ? self / l : Vector2.new(0.0_f32, 0.0_f32)
    end

    def dot(other : Vector2) : Float32
      @x * other.x + @y * other.y
    end

    def cross(other : Vector2) : Float32
      @x * other.y - @y * other.x
    end

    # Rotates this vector by the given angle in radians.
    def rotated(angle : Number) : Vector2
      c = Math.cos(angle.to_f32)
      s = Math.sin(angle.to_f32)
      Vector2.new(@x * c - @y * s, @x * s + @y * c)
    end

    # Returns the vector rotated 90 degrees counter-clockwise.
    def orthogonal : Vector2
      Vector2.new(-@y, @x)
    end

    # Alias for orthogonal.
    def perpendicular : Vector2
      orthogonal
    end

    # Returns a new vector slid along a plane defined by the given normal.
    def slide(normal : Vector2) : Vector2
      self - normal * dot(normal)
    end

    # Returns a new vector reflected from a plane defined by the given normal.
    def reflect(normal : Vector2) : Vector2
      self - normal * (2.0_f32 * dot(normal))
    end

    # Returns a new vector bounced off a plane defined by the given normal.
    def bounce(normal : Vector2) : Vector2
      -reflect(normal)
    end

    # Projects this vector onto vector b.
    def project(b : Vector2) : Vector2
      b * (dot(b) / b.length_squared)
    end

    # Returns the angle in radians of this vector with respect to the positive X-axis.
    def angle : Float32
      Math.atan2(@y, @x)
    end

    # Returns the unsigned angle in radians between this vector and other.
    def angle_to(to : Vector2) : Float32
      Math.atan2(cross(to), dot(to))
    end

    # Returns the angle in radians between this vector and the given point.
    def angle_to_point(to : Vector2) : Float32
      (to - self).angle
    end

    # Returns the distance between this vector and other.
    def distance_to(other : Vector2) : Float32
      (self - other).length
    end

    # Returns the squared distance between this vector and other.
    def distance_squared_to(other : Vector2) : Float32
      (self - other).length_squared
    end

    # Returns the normalized direction from this vector toward other.
    def direction_to(other : Vector2) : Vector2
      (other - self).normalized
    end

    # Linearly interpolates between this vector and to by weight.
    def lerp(to : Vector2, weight : Number) : Vector2
      self + (to - self) * weight.to_f32
    end

    # Spherically interpolates between this vector and to by weight.
    def slerp(to : Vector2, weight : Number) : Vector2
      start_length_sq = length_squared
      end_length_sq = to.length_squared
      if start_length_sq == 0.0_f32 || end_length_sq == 0.0_f32
        return lerp(to, weight)
      end
      start_length = Math.sqrt(start_length_sq)
      result_length = start_length + (Math.sqrt(end_length_sq) - start_length) * weight.to_f32
      ang = angle_to(to)
      rotated(ang * weight.to_f32).normalized * result_length
    end

    # Moves this vector toward to by the given delta amount, never exceeding to.
    def move_toward(to : Vector2, delta : Number) : Vector2
      diff = to - self
      len = diff.length
      len <= delta.to_f32 || len < 0.00001_f32 ? to : self + diff / len * delta.to_f32
    end

    # Clamps the vector's length to max_length.
    def limit_length(max_length : Number = 1.0) : Vector2
      l = length
      l > max_length.to_f32 && l > 0.00001_f32 ? self / l * max_length.to_f32 : self
    end

    # Clamps each component between min and max.
    def clamp(min : Vector2, max : Vector2) : Vector2
      Vector2.new(
        @x.clamp(min.x, max.x),
        @y.clamp(min.y, max.y)
      )
    end

    def abs : Vector2
      Vector2.new(@x.abs, @y.abs)
    end

    def sign : Vector2
      Vector2.new(@x.sign.to_f32, @y.sign.to_f32)
    end

    def floor : Vector2
      Vector2.new(@x.floor, @y.floor)
    end

    def ceil : Vector2
      Vector2.new(@x.ceil, @y.ceil)
    end

    def round : Vector2
      Vector2.new(@x.round, @y.round)
    end

    def is_zero_approx : Bool
      @x.abs < 0.00001_f32 && @y.abs < 0.00001_f32
    end

    def is_equal_approx(other : Vector2) : Bool
      (@x - other.x).abs < 0.00001_f32 && (@y - other.y).abs < 0.00001_f32
    end

    def is_normalized? : Bool
      (length_squared - 1.0_f32).abs < 0.0001_f32
    end

    def aspect : Float32
      @x / @y
    end

    def min(other : Vector2) : Vector2
      Vector2.new(Math.min(@x, other.x), Math.min(@y, other.y))
    end

    def max(other : Vector2) : Vector2
      Vector2.new(Math.max(@x, other.x), Math.max(@y, other.y))
    end

    def to_i : Vector2i
      Vector2i.new(@x.to_i32, @y.to_i32)
    end

    def to_s(io : IO) : Void
      io << "(" << @x << ", " << @y << ")"
    end

    ZERO = Vector2.new(0.0_f32, 0.0_f32)
    ONE  = Vector2.new(1.0_f32, 1.0_f32)
    UP   = Vector2.new(0.0_f32, -1.0_f32)
    DOWN = Vector2.new(0.0_f32, 1.0_f32)
    LEFT = Vector2.new(-1.0_f32, 0.0_f32)
    RIGHT= Vector2.new(1.0_f32, 0.0_f32)
    INF  = Vector2.new(Float32::INFINITY, Float32::INFINITY)
  end

  # 2-element structure that can be used to represent 2D grid coordinates or discrete positions with 32-bit integers.
  struct Vector2i
    property x : Int32
    property y : Int32

    def initialize(@x : Int32 = 0, @y : Int32 = 0)
    end

    def initialize(pointer : Void*)
      addr = pointer.address
      @x = (addr & 0xffffffff_u64).to_u32!.to_i32
      @y = ((addr >> 32) & 0xffffffff_u64).to_u32!.to_i32
    end

    def initialize(x : Number, y : Number)
      @x = x.to_i32
      @y = y.to_i32
    end

    def - : Vector2i
      Vector2i.new(-@x, -@y)
    end

    def +(other : Vector2i) : Vector2i
      Vector2i.new(@x + other.x, @y + other.y)
    end

    def -(other : Vector2i) : Vector2i
      Vector2i.new(@x - other.x, @y - other.y)
    end

    def *(scalar : Number) : Vector2i
      s = scalar.to_i32
      Vector2i.new(@x * s, @y * s)
    end

    def *(other : Vector2i) : Vector2i
      Vector2i.new(@x * other.x, @y * other.y)
    end

    def /(scalar : Number) : Vector2i
      s = scalar.to_i32
      Vector2i.new(@x // s, @y // s)
    end

    def /(other : Vector2i) : Vector2i
      Vector2i.new(@x // other.x, @y // other.y)
    end

    def abs : Vector2i
      Vector2i.new(@x.abs, @y.abs)
    end

    def sign : Vector2i
      Vector2i.new(@x.sign, @y.sign)
    end

    def min(other : Vector2i) : Vector2i
      Vector2i.new(Math.min(@x, other.x), Math.min(@y, other.y))
    end

    def max(other : Vector2i) : Vector2i
      Vector2i.new(Math.max(@x, other.x), Math.max(@y, other.y))
    end

    def clamp(min : Vector2i, max : Vector2i) : Vector2i
      Vector2i.new(@x.clamp(min.x, max.x), @y.clamp(min.y, max.y))
    end

    def to_v2 : Vector2
      Vector2.new(@x.to_f32, @y.to_f32)
    end

    def to_s(io : IO) : Void
      io << "(" << @x << ", " << @y << ")"
    end

    ZERO = Vector2i.new(0, 0)
    ONE  = Vector2i.new(1, 1)
    LEFT = Vector2i.new(-1, 0)
    RIGHT= Vector2i.new(1, 0)
    UP   = Vector2i.new(0, -1)
    DOWN = Vector2i.new(0, 1)
  end

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
    # Normal must be normalized.
    def slide(normal : Vector3) : Vector3
      self - normal * dot(normal)
    end

    # Rotates this vector around the given axis by the given angle in radians.
    # Uses Rodrigues' rotation formula.
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

    def is_equal_approx(other : Vector3) : Bool
      (@x - other.x).abs < 0.00001_f32 && (@y - other.y).abs < 0.00001_f32 && (@z - other.z).abs < 0.00001_f32
    end

    def is_normalized? : Bool
      (length_squared - 1.0_f32).abs < 0.0001_f32
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
    ZERO    = Vector3.new(0.0_f32, 0.0_f32, 0.0_f32)
    ONE     = Vector3.new(1.0_f32, 1.0_f32, 1.0_f32)
    UP      = Vector3.new(0.0_f32, 1.0_f32, 0.0_f32)
    DOWN    = Vector3.new(0.0_f32, -1.0_f32, 0.0_f32)
    LEFT    = Vector3.new(-1.0_f32, 0.0_f32, 0.0_f32)
    RIGHT   = Vector3.new(1.0_f32, 0.0_f32, 0.0_f32)
    FORWARD = Vector3.new(0.0_f32, 0.0_f32, -1.0_f32)
    BACK    = Vector3.new(0.0_f32, 0.0_f32, 1.0_f32)
    INF     = Vector3.new(Float32::INFINITY, Float32::INFINITY, Float32::INFINITY)
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

  # 4-element structure that can be used to represent 4D coordinates or homogeneous vectors.
  struct Vector4
    property x : Float32
    property y : Float32
    property z : Float32
    property w : Float32

    def initialize(@x : Float32 = 0.0_f32, @y : Float32 = 0.0_f32, @z : Float32 = 0.0_f32, @w : Float32 = 0.0_f32)
    end

    def initialize(pointer : Void*)
      if pointer.null?
        @x = 0.0_f32; @y = 0.0_f32; @z = 0.0_f32; @w = 0.0_f32
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

    def to_s(io : IO) : Void
      io << "(" << @x << ", " << @y << ", " << @z << ", " << @w << ")"
    end

    ZERO = Vector4.new(0.0_f32, 0.0_f32, 0.0_f32, 0.0_f32)
    ONE  = Vector4.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32)
  end

  # 4-element integer vector structure.
  struct Vector4i
    property x : Int32
    property y : Int32
    property z : Int32
    property w : Int32

    def initialize(@x : Int32 = 0, @y : Int32 = 0, @z : Int32 = 0, @w : Int32 = 0)
    end

    def initialize(pointer : Void*)
      if pointer.null?
        @x = 0; @y = 0; @z = 0; @w = 0
      else
        ptr = pointer.as(Int32*)
        @x = ptr[0]; @y = ptr[1]; @z = ptr[2]; @w = ptr[3]
      end
    end

    def initialize(x : Number, y : Number, z : Number, w : Number)
      @x = x.to_i32
      @y = y.to_i32
      @z = z.to_i32
      @w = w.to_i32
    end

    def to_s(io : IO) : Void
      io << "(" << @x << ", " << @y << ", " << @z << ", " << @w << ")"
    end

    ZERO = Vector4i.new(0, 0, 0, 0)
    ONE  = Vector4i.new(1, 1, 1, 1)
  end

  # 2D axis-aligned bounding box defined by a position and size.
  struct Rect2
    property position : Vector2
    property size : Vector2

    def initialize(@position : Vector2 = Vector2.new, @size : Vector2 = Vector2.new)
    end

    def initialize(pointer : Void*)
      if pointer.null?
        @position = Vector2.new
        @size = Vector2.new
      else
        ptr = pointer.as(Float32*)
        @position = Vector2.new(ptr[0], ptr[1])
        @size = Vector2.new(ptr[2], ptr[3])
      end
    end

    def initialize(x : Number, y : Number, width : Number, height : Number)
      @position = Vector2.new(x.to_f32, y.to_f32)
      @size = Vector2.new(width.to_f32, height.to_f32)
    end

    def to_s(io : IO) : Void
      io << "[P: " << @position << ", S: " << @size << "]"
    end
  end

  # 2D axis-aligned bounding box using integer coordinates.
  struct Rect2i
    property position : Vector2i
    property size : Vector2i

    def initialize(@position : Vector2i = Vector2i.new, @size : Vector2i = Vector2i.new)
    end

    def initialize(pointer : Void*)
      if pointer.null?
        @position = Vector2i.new
        @size = Vector2i.new
      else
        ptr = pointer.as(Int32*)
        @position = Vector2i.new(ptr[0], ptr[1])
        @size = Vector2i.new(ptr[2], ptr[3])
      end
    end

    def initialize(x : Number, y : Number, width : Number, height : Number)
      @position = Vector2i.new(x.to_i32, y.to_i32)
      @size = Vector2i.new(width.to_i32, height.to_i32)
    end

    def to_s(io : IO) : Void
      io << "[P: " << @position << ", S: " << @size << "]"
    end
  end

  # A color represented in RGBA format with 32-bit floating point precision per channel.
  struct Color
    property r : Float32
    property g : Float32
    property b : Float32
    property a : Float32

    def initialize(@r : Float32 = 1.0_f32, @g : Float32 = 1.0_f32, @b : Float32 = 1.0_f32, @a : Float32 = 1.0_f32)
    end

    def initialize(pointer : Void*)
      if pointer.null?
        @r = 1.0_f32; @g = 1.0_f32; @b = 1.0_f32; @a = 1.0_f32
      else
        ptr = pointer.as(Float32*)
        @r = ptr[0]; @g = ptr[1]; @b = ptr[2]; @a = ptr[3]
      end
    end

    def initialize(r : Number, g : Number, b : Number, a : Number = 1.0)
      @r = r.to_f32
      @g = g.to_f32
      @b = b.to_f32
      @a = a.to_f32
    end

    WHITE = Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32)
    BLACK = Color.new(0.0_f32, 0.0_f32, 0.0_f32, 1.0_f32)
    RED   = Color.new(1.0_f32, 0.0_f32, 0.0_f32, 1.0_f32)
    GREEN = Color.new(0.0_f32, 1.0_f32, 0.0_f32, 1.0_f32)
    BLUE  = Color.new(0.0_f32, 0.0_f32, 1.0_f32, 1.0_f32)
  end

  # A 2x3 matrix (2 column vectors + origin) used for 2D affine transformations.
  struct Transform2D
    property x : Vector2
    property y : Vector2
    property origin : Vector2

    def initialize(
      @x : Vector2 = Vector2.new(1.0_f32, 0.0_f32),
      @y : Vector2 = Vector2.new(0.0_f32, 1.0_f32),
      @origin : Vector2 = Vector2.new(0.0_f32, 0.0_f32)
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

    def affine_inverse : Transform2D
      det = @x.x * @y.y - @x.y * @y.x
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

    IDENTITY = Transform2D.new
  end

  # A 3x3 matrix used for 3D rotation and scale.
  struct Basis
    property x : Vector3
    property y : Vector3
    property z : Vector3

    def initialize(
      @x : Vector3 = Vector3.new(1.0_f32, 0.0_f32, 0.0_f32),
      @y : Vector3 = Vector3.new(0.0_f32, 1.0_f32, 0.0_f32),
      @z : Vector3 = Vector3.new(0.0_f32, 0.0_f32, 1.0_f32)
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

    def *(vec : Vector3) : Vector3
      Vector3.new(
        @x.dot(vec),
        @y.dot(vec),
        @z.dot(vec)
      )
    end

    def *(other : Basis) : Basis
      c0 = Vector3.new(other.x.x, other.y.x, other.z.x)
      c1 = Vector3.new(other.x.y, other.y.y, other.z.y)
      c2 = Vector3.new(other.x.z, other.y.z, other.z.z)
      Basis.new(
        Vector3.new(@x.dot(c0), @x.dot(c1), @x.dot(c2)),
        Vector3.new(@y.dot(c0), @y.dot(c1), @y.dot(c2)),
        Vector3.new(@z.dot(c0), @z.dot(c1), @z.dot(c2))
      )
    end

    def transposed : Basis
      Basis.new(
        Vector3.new(@x.x, @y.x, @z.x),
        Vector3.new(@x.y, @y.y, @z.y),
        Vector3.new(@x.z, @y.z, @z.z)
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

    def self.from_axis_angle(axis : Vector3, angle : Number) : Basis
      axis_n = axis.normalized
      cos_a = Math.cos(angle.to_f32)
      sin_a = Math.sin(angle.to_f32)
      one_minus_c = 1.0_f32 - cos_a

      x = axis_n.x
      y = axis_n.y
      z = axis_n.z

      Basis.new(
        Vector3.new(
          cos_a + x * x * one_minus_c,
          x * y * one_minus_c - z * sin_a,
          x * z * one_minus_c + y * sin_a
        ),
        Vector3.new(
          y * x * one_minus_c + z * sin_a,
          cos_a + y * y * one_minus_c,
          y * z * one_minus_c - x * sin_a
        ),
        Vector3.new(
          z * x * one_minus_c - y * sin_a,
          z * y * one_minus_c + x * sin_a,
          cos_a + z * z * one_minus_c
        )
      )
    end

    def rotated(axis : Vector3, angle : Number) : Basis
      Basis.from_axis_angle(axis, angle) * self
    end

    IDENTITY = Basis.new
  end

  # 4-element structure that represents a 3D rotation with hypercomplex numbers.
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

    def to_s(io : IO) : Void
      io << "(" << @x << ", " << @y << ", " << @z << ", " << @w << ")"
    end

    IDENTITY = Quaternion.new(0.0_f32, 0.0_f32, 0.0_f32, 1.0_f32)
  end

  # A 3D plane represented in normal-distance form (ax + by + cz = d).
  struct Plane
    property normal : Vector3
    property d : Float32

    def initialize(@normal : Vector3 = Vector3.new(0.0_f32, 1.0_f32, 0.0_f32), @d : Float32 = 0.0_f32)
    end

    def initialize(pointer : Void*)
      if pointer.null?
        @normal = Vector3.new(0.0_f32, 1.0_f32, 0.0_f32)
        @d = 0.0_f32
      else
        ptr = pointer.as(Float32*)
        @normal = Vector3.new(ptr[0], ptr[1], ptr[2])
        @d = ptr[3]
      end
    end

    def to_s(io : IO) : Void
      io << "[N: " << @normal << ", D: " << @d << "]"
    end
  end

  # An axis-aligned bounding box in 3D space.
  struct AABB
    property position : Vector3
    property size : Vector3

    def initialize(@position : Vector3 = Vector3.new, @size : Vector3 = Vector3.new)
    end

    def initialize(pointer : Void*)
      if pointer.null?
        @position = Vector3.new
        @size = Vector3.new
      else
        ptr = pointer.as(Float32*)
        @position = Vector3.new(ptr[0], ptr[1], ptr[2])
        @size = Vector3.new(ptr[3], ptr[4], ptr[5])
      end
    end

    def to_s(io : IO) : Void
      io << "[P: " << @position << ", S: " << @size << "]"
    end
  end

  # A 3x4 matrix (Basis + origin) used for 3D affine transformations.
  struct Transform3D
    property basis : Basis
    property origin : Vector3

    def initialize(@basis : Basis = Basis.new, @origin : Vector3 = Vector3.new)
    end

    def initialize(pointer : Void*)
      if pointer.null?
        @basis = Basis.new
        @origin = Vector3.new
      else
        @basis = Basis.new(pointer)
        ptr = (pointer.as(UInt8*) + sizeof(Basis)).as(Float32*)
        @origin = Vector3.new(ptr[0], ptr[1], ptr[2])
      end
    end

    def *(vec : Vector3) : Vector3
      @basis * vec + @origin
    end

    def *(other : Transform3D) : Transform3D
      Transform3D.new(@basis * other.basis, self * other.origin)
    end

    def affine_inverse : Transform3D
      inv_basis = @basis.inverse
      Transform3D.new(inv_basis, inv_basis * -@origin)
    end

    def translated(offset : Vector3) : Transform3D
      Transform3D.new(@basis, @origin + offset)
    end

    def rotated(axis : Vector3, angle : Number) : Transform3D
      rot = Basis.from_axis_angle(axis, angle)
      Transform3D.new(rot * @basis, rot * @origin)
    end

    def scaled(scale : Vector3) : Transform3D
      scale_basis = Basis.new(
        Vector3.new(scale.x, 0.0_f32, 0.0_f32),
        Vector3.new(0.0_f32, scale.y, 0.0_f32),
        Vector3.new(0.0_f32, 0.0_f32, scale.z)
      )
      Transform3D.new(scale_basis * @basis, @origin)
    end

    IDENTITY = Transform3D.new
  end
end

module Math
  # Moves `from` toward `to` by the given `delta` amount, never exceeding `to`.
  def self.move_toward(from : Float32, to : Float32, delta : Float32) : Float32
    if (to - from).abs <= delta
      to
    else
      from + (to - from).sign * delta
    end
  end

  # Moves `from` toward `to` by the given `delta` amount with 64-bit precision, never exceeding `to`.
  def self.move_toward(from : Float64, to : Float64, delta : Float64) : Float64
    if (to - from).abs <= delta
      to
    else
      from + (to - from).sign * delta
    end
  end

  # Linearly interpolates between from and to by weight.
  def self.lerp(from : Float32, to : Float32, weight : Float32) : Float32
    from + (to - from) * weight
  end

  def self.lerp(from : Float64, to : Float64, weight : Float64) : Float64
    from + (to - from) * weight
  end
end

# Top-level math constructors
def vec2(x : Number, y : Number) : Godot::Vector2
  Godot::Vector2.new(x.to_f32, y.to_f32)
end

def vec3(x : Number, y : Number, z : Number) : Godot::Vector3
  Godot::Vector3.new(x.to_f32, y.to_f32, z.to_f32)
end
