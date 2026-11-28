module Godot
  # A 4x4 matrix (4 Vector4 columns) used for 3D projective transformations with 32-bit floating point precision.
  struct Projection
    property x : Vector4
    property y : Vector4
    property z : Vector4
    property w : Vector4

    def initialize(
      @x : Vector4 = Vector4.new(1.0_f32, 0.0_f32, 0.0_f32, 0.0_f32),
      @y : Vector4 = Vector4.new(0.0_f32, 1.0_f32, 0.0_f32, 0.0_f32),
      @z : Vector4 = Vector4.new(0.0_f32, 0.0_f32, 1.0_f32, 0.0_f32),
      @w : Vector4 = Vector4.new(0.0_f32, 0.0_f32, 0.0_f32, 1.0_f32),
    )
    end

    def initialize(pointer : Void*)
      if pointer.null?
        @x = Vector4.new(1.0_f32, 0.0_f32, 0.0_f32, 0.0_f32)
        @y = Vector4.new(0.0_f32, 1.0_f32, 0.0_f32, 0.0_f32)
        @z = Vector4.new(0.0_f32, 0.0_f32, 1.0_f32, 0.0_f32)
        @w = Vector4.new(0.0_f32, 0.0_f32, 0.0_f32, 1.0_f32)
      else
        ptr = pointer.as(Float32*)
        @x = Vector4.new(ptr[0], ptr[1], ptr[2], ptr[3])
        @y = Vector4.new(ptr[4], ptr[5], ptr[6], ptr[7])
        @z = Vector4.new(ptr[8], ptr[9], ptr[10], ptr[11])
        @w = Vector4.new(ptr[12], ptr[13], ptr[14], ptr[15])
      end
    end

    def self.identity : Projection
      Projection.new
    end

    def self.zero : Projection
      z = Vector4.new(0.0_f32, 0.0_f32, 0.0_f32, 0.0_f32)
      Projection.new(z, z, z, z)
    end

    def [](index : Int) : Vector4
      case index
      when 0 then @x
      when 1 then @y
      when 2 then @z
      when 3 then @w
      else        raise IndexError.new("Projection column index #{index} out of bounds (0..3)")
      end
    end

    def *(vec : Vector4) : Vector4
      Vector4.new(
        @x.x * vec.x + @y.x * vec.y + @z.x * vec.z + @w.x * vec.w,
        @x.y * vec.x + @y.y * vec.y + @z.y * vec.z + @w.y * vec.w,
        @x.z * vec.x + @y.z * vec.y + @z.z * vec.z + @w.z * vec.w,
        @x.w * vec.x + @y.w * vec.y + @z.w * vec.z + @w.w * vec.w
      )
    end

    def *(other : Projection) : Projection
      Projection.new(
        self * other.x,
        self * other.y,
        self * other.z,
        self * other.w
      )
    end

    def ==(other : Projection) : Bool
      @x == other.x && @y == other.y && @z == other.z && @w == other.w
    end

    def !=(other : Projection) : Bool
      !(self == other)
    end

    def to_s(io : IO) : Void
      io << "[X: " << @x << ", Y: " << @y << ", Z: " << @z << ", W: " << @w << "]"
    end

    IDENTITY = Projection.new
    ZERO     = Projection.zero
  end
end
