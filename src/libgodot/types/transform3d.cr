module Godot
  # A 3x4 matrix (Basis + origin) used for 3D affine transformations with 32-bit floating point precision.
  struct Transform3D
    property basis : Basis
    property origin : Vector3

    def initialize(@basis : Basis = Basis.new, @origin : Vector3 = Vector3.new)
    end

    def initialize(x : Vector3, y : Vector3, z : Vector3, @origin : Vector3)
      @basis = Basis.new(x, y, z)
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

    @[AlwaysInline]
    def *(vec : Vector3) : Vector3
      @basis * vec + @origin
    end

    @[AlwaysInline]
    def *(other : Transform3D) : Transform3D
      Transform3D.new(@basis * other.basis, self * other.origin)
    end

    def affine_inverse : Transform3D
      inv_basis = @basis.inverse
      Transform3D.new(inv_basis, inv_basis * -@origin)
    end

    def inverse : Transform3D
      affine_inverse
    end

    @[AlwaysInline]
    def translated(offset : Vector3) : Transform3D
      Transform3D.new(@basis, @origin + offset)
    end

    @[AlwaysInline]
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

    def orthonormalized : Transform3D
      Transform3D.new(@basis.orthonormalized, @origin)
    end

    def looking_at(target : Vector3, up : Vector3 = Vector3::UP) : Transform3D
      Transform3D.new(Basis.looking_at(target - @origin, up), @origin)
    end

    def interpolate_with(other : Transform3D, weight : Number) : Transform3D
      Transform3D.new(
        @basis.slerp(other.basis, weight),
        @origin.lerp(other.origin, weight)
      )
    end

    def is_equal_approx(other : Transform3D) : Bool
      @basis.is_equal_approx(other.basis) && @origin.is_equal_approx(other.origin)
    end

    def ==(other : Transform3D) : Bool
      @basis == other.basis && @origin == other.origin
    end

    def !=(other : Transform3D) : Bool
      @basis != other.basis || @origin != other.origin
    end

    def to_s(io : IO) : Void
      io << "[B: " << @basis << ", O: " << @origin << "]"
    end

    IDENTITY = Transform3D.new
    FLIP_X   = Transform3D.new(Basis::FLIP_X, Vector3.new(0.0_f32, 0.0_f32, 0.0_f32))
    FLIP_Y   = Transform3D.new(Basis::FLIP_Y, Vector3.new(0.0_f32, 0.0_f32, 0.0_f32))
    FLIP_Z   = Transform3D.new(Basis::FLIP_Z, Vector3.new(0.0_f32, 0.0_f32, 0.0_f32))
  end
end
