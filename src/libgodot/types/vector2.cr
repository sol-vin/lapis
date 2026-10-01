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

    def initialize(pointer : Void*)
      if pointer.null?
        @x = 0.0_f32
        @y = 0.0_f32
      else
        ptr = pointer.as(Float32*)
        @x = ptr[0]
        @y = ptr[1]
      end
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

    def ==(other : Vector2) : Bool
      @x == other.x && @y == other.y
    end

    def !=(other : Vector2) : Bool
      @x != other.x || @y != other.y
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

    # Cubic interpolation between two vectors using pre_a and post_b tangents.
    def cubic_interpolate(b : Vector2, pre_a : Vector2, post_b : Vector2, weight : Number) : Vector2
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
    def bezier_interpolate(control_1 : Vector2, control_2 : Vector2, end_point : Vector2, t : Number) : Vector2
      u = 1.0_f32 - t.to_f32
      tt = t.to_f32 * t.to_f32
      uu = u * u
      uuu = uu * u
      ttt = tt * t.to_f32
      self * uuu + control_1 * (3.0_f32 * uu * t.to_f32) + control_2 * (3.0_f32 * u * tt) + end_point * ttt
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

    # Clamps each component between scalar min and max values.
    def clampf(min_val : Number, max_val : Number) : Vector2
      Vector2.new(
        @x.clamp(min_val.to_f32, max_val.to_f32),
        @y.clamp(min_val.to_f32, max_val.to_f32)
      )
    end

    # Snaps vector components to nearest multiple of step.
    def snapped(step : Vector2) : Vector2
      Vector2.new(
        step.x != 0.0_f32 ? (@x / step.x + 0.5_f32).floor * step.x : @x,
        step.y != 0.0_f32 ? (@y / step.y + 0.5_f32).floor * step.y : @y
      )
    end

    # Returns the vector with each component modulo scalar.
    def posmod(mod_val : Number) : Vector2
      m = mod_val.to_f32
      Vector2.new(@x % m, @y % m)
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

    def is_zero_approx? : Bool
      is_zero_approx
    end

    def is_equal_approx(other : Vector2) : Bool
      (@x - other.x).abs < 0.00001_f32 && (@y - other.y).abs < 0.00001_f32
    end

    def is_normalized? : Bool
      (length_squared - 1.0_f32).abs < 0.0001_f32
    end

    def is_finite? : Bool
      @x.finite? && @y.finite?
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

    ZERO  = Vector2.new(0.0_f32, 0.0_f32)
    ONE   = Vector2.new(1.0_f32, 1.0_f32)
    UP    = Vector2.new(0.0_f32, -1.0_f32)
    DOWN  = Vector2.new(0.0_f32, 1.0_f32)
    LEFT  = Vector2.new(-1.0_f32, 0.0_f32)
    RIGHT = Vector2.new(1.0_f32, 0.0_f32)
    INF   = Vector2.new(Float32::INFINITY, Float32::INFINITY)
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

    def ==(other : Vector2i) : Bool
      @x == other.x && @y == other.y
    end

    def !=(other : Vector2i) : Bool
      @x != other.x || @y != other.y
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

    # Manhattan (taxicab) distance to other integer position.
    def distance_manhattan_to(other : Vector2i) : Int32
      (@x - other.x).abs + (@y - other.y).abs
    end

    def to_v2 : Vector2
      Vector2.new(@x.to_f32, @y.to_f32)
    end

    def to_s(io : IO) : Void
      io << "(" << @x << ", " << @y << ")"
    end

    ZERO  = Vector2i.new(0, 0)
    ONE   = Vector2i.new(1, 1)
    LEFT  = Vector2i.new(-1, 0)
    RIGHT = Vector2i.new(1, 0)
    UP    = Vector2i.new(0, -1)
    DOWN  = Vector2i.new(0, 1)
  end
end
