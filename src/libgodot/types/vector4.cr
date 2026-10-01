module Godot
  # 4-element structure that can be used to represent 4D coordinates or homogeneous vectors with 32-bit floating point precision.
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

    def - : Vector4
      Vector4.new(-@x, -@y, -@z, -@w)
    end

    def +(other : Vector4) : Vector4
      Vector4.new(@x + other.x, @y + other.y, @z + other.z, @w + other.w)
    end

    def -(other : Vector4) : Vector4
      Vector4.new(@x - other.x, @y - other.y, @z - other.z, @w - other.w)
    end

    def *(scalar : Number) : Vector4
      s = scalar.to_f32
      Vector4.new(@x * s, @y * s, @z * s, @w * s)
    end

    def *(other : Vector4) : Vector4
      Vector4.new(@x * other.x, @y * other.y, @z * other.z, @w * other.w)
    end

    def /(scalar : Number) : Vector4
      s = scalar.to_f32
      Vector4.new(@x / s, @y / s, @z / s, @w / s)
    end

    def /(other : Vector4) : Vector4
      Vector4.new(@x / other.x, @y / other.y, @z / other.z, @w / other.w)
    end

    def ==(other : Vector4) : Bool
      @x == other.x && @y == other.y && @z == other.z && @w == other.w
    end

    def !=(other : Vector4) : Bool
      @x != other.x || @y != other.y || @z != other.z || @w != other.w
    end

    def length_squared : Float32
      @x * @x + @y * @y + @z * @z + @w * @w
    end

    def length : Float32
      Math.sqrt(length_squared)
    end

    def normalized : Vector4
      l = length
      l > 0.00001_f32 ? self / l : Vector4.new(0.0_f32, 0.0_f32, 0.0_f32, 0.0_f32)
    end

    def is_normalized? : Bool
      (length_squared - 1.0_f32).abs < 0.0001_f32
    end

    def dot(other : Vector4) : Float32
      @x * other.x + @y * other.y + @z * other.z + @w * other.w
    end

    def distance_to(other : Vector4) : Float32
      (self - other).length
    end

    def distance_squared_to(other : Vector4) : Float32
      (self - other).length_squared
    end

    def direction_to(other : Vector4) : Vector4
      (other - self).normalized
    end

    def lerp(to : Vector4, weight : Number) : Vector4
      self + (to - self) * weight.to_f32
    end

    def abs : Vector4
      Vector4.new(@x.abs, @y.abs, @z.abs, @w.abs)
    end

    def sign : Vector4
      Vector4.new(@x.sign.to_f32, @y.sign.to_f32, @z.sign.to_f32, @w.sign.to_f32)
    end

    def floor : Vector4
      Vector4.new(@x.floor, @y.floor, @z.floor, @w.floor)
    end

    def ceil : Vector4
      Vector4.new(@x.ceil, @y.ceil, @z.ceil, @w.ceil)
    end

    def round : Vector4
      Vector4.new(@x.round, @y.round, @z.round, @w.round)
    end

    def min(other : Vector4) : Vector4
      Vector4.new(Math.min(@x, other.x), Math.min(@y, other.y), Math.min(@z, other.z), Math.min(@w, other.w))
    end

    def max(other : Vector4) : Vector4
      Vector4.new(Math.max(@x, other.x), Math.max(@y, other.y), Math.max(@z, other.z), Math.max(@w, other.w))
    end

    def clamp(min : Vector4, max : Vector4) : Vector4
      Vector4.new(
        @x.clamp(min.x, max.x),
        @y.clamp(min.y, max.y),
        @z.clamp(min.z, max.z),
        @w.clamp(min.w, max.w)
      )
    end

    def is_zero_approx : Bool
      @x.abs < 0.00001_f32 && @y.abs < 0.00001_f32 && @z.abs < 0.00001_f32 && @w.abs < 0.00001_f32
    end

    def is_zero_approx? : Bool
      is_zero_approx
    end

    def is_equal_approx(other : Vector4) : Bool
      (@x - other.x).abs < 0.00001_f32 && (@y - other.y).abs < 0.00001_f32 &&
        (@z - other.z).abs < 0.00001_f32 && (@w - other.w).abs < 0.00001_f32
    end

    def is_finite? : Bool
      @x.finite? && @y.finite? && @z.finite? && @w.finite?
    end

    def to_i : Vector4i
      Vector4i.new(@x.to_i32, @y.to_i32, @z.to_i32, @w.to_i32)
    end

    def to_s(io : IO) : Void
      io << "(" << @x << ", " << @y << ", " << @z << ", " << @w << ")"
    end

    ZERO = Vector4.new(0.0_f32, 0.0_f32, 0.0_f32, 0.0_f32)
    ONE  = Vector4.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32)
    INF  = Vector4.new(Float32::INFINITY, Float32::INFINITY, Float32::INFINITY, Float32::INFINITY)
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

    def - : Vector4i
      Vector4i.new(-@x, -@y, -@z, -@w)
    end

    def +(other : Vector4i) : Vector4i
      Vector4i.new(@x + other.x, @y + other.y, @z + other.z, @w + other.w)
    end

    def -(other : Vector4i) : Vector4i
      Vector4i.new(@x - other.x, @y - other.y, @z - other.z, @w - other.w)
    end

    def *(scalar : Number) : Vector4i
      s = scalar.to_i32
      Vector4i.new(@x * s, @y * s, @z * s, @w * s)
    end

    def *(other : Vector4i) : Vector4i
      Vector4i.new(@x * other.x, @y * other.y, @z * other.z, @w * other.w)
    end

    def /(scalar : Number) : Vector4i
      s = scalar.to_i32
      Vector4i.new(@x // s, @y // s, @z // s, @w // s)
    end

    def /(other : Vector4i) : Vector4i
      Vector4i.new(@x // other.x, @y // other.y, @z // other.z, @w // other.w)
    end

    def ==(other : Vector4i) : Bool
      @x == other.x && @y == other.y && @z == other.z && @w == other.w
    end

    def !=(other : Vector4i) : Bool
      @x != other.x || @y != other.y || @z != other.z || @w != other.w
    end

    def abs : Vector4i
      Vector4i.new(@x.abs, @y.abs, @z.abs, @w.abs)
    end

    def sign : Vector4i
      Vector4i.new(@x.sign, @y.sign, @z.sign, @w.sign)
    end

    def min(other : Vector4i) : Vector4i
      Vector4i.new(Math.min(@x, other.x), Math.min(@y, other.y), Math.min(@z, other.z), Math.min(@w, other.w))
    end

    def max(other : Vector4i) : Vector4i
      Vector4i.new(Math.max(@x, other.x), Math.max(@y, other.y), Math.max(@z, other.z), Math.max(@w, other.w))
    end

    def clamp(min : Vector4i, max : Vector4i) : Vector4i
      Vector4i.new(
        @x.clamp(min.x, max.x),
        @y.clamp(min.y, max.y),
        @z.clamp(min.z, max.z),
        @w.clamp(min.w, max.w)
      )
    end

    def to_v4 : Vector4
      Vector4.new(@x.to_f32, @y.to_f32, @z.to_f32, @w.to_f32)
    end

    def to_s(io : IO) : Void
      io << "(" << @x << ", " << @y << ", " << @z << ", " << @w << ")"
    end

    ZERO = Vector4i.new(0, 0, 0, 0)
    ONE  = Vector4i.new(1, 1, 1, 1)
  end
end
